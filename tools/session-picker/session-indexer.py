#!/usr/bin/env python3
"""Claude Code / Codex のセッション jsonl からタイトル索引を作る。

索引: ~/.local/share/session-picker/index.jsonl (append-only、同一 id は最終行が勝つ)
タイトルの優先順位:
  1. --title 指定 (plan 確定時に H1 を流用する PostToolUse hook 経由。索引済みでも上書き)
  2. Claude Code が jsonl に保存する ai-title エントリ (無料・即時)
  3. `claude -p --model haiku` による生成 (Codex 全般 / ai-title 無しの Claude)
  4. 最初のユーザー発話の先頭 30 字 (オフライン等の fallback、generated=false で再試行対象)

起動トリガーは UserPromptSubmit hook (最初のプロンプト直後、未索引のときのみ) と
plan 確定時の PostToolUse hook、および sr 起動時の catch-up (Codex / 取りこぼし)。

元の jsonl には一切書き込まない。パース不能なセッションは skip する (indexer は落とさない)。
"""

import argparse
import fcntl
import json
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

MARKER = "[session-picker:title]"
INDEX_DIR = Path.home() / ".local/share/session-picker"
INDEX_FILE = INDEX_DIR / "index.jsonl"
LOCK_FILE = INDEX_DIR / "catch-up.lock"
CLAUDE_PROJECTS = Path.home() / ".claude/projects"
CODEX_SESSIONS = Path.home() / ".codex/sessions"
EXCERPT_LIMIT = 2000  # LLM に渡す抜粋の上限 (bytes ではなく chars)
PREVIEW_LIMIT = 300
FALLBACK_TITLE_LEN = 30
TITLE_TIMEOUT_SEC = 60
SHORT_SESSION_LEN = 20  # これ以下なら発話自体をタイトルにする (LLM を呼ばない)
GENERATE_WORKERS = 4

# Claude のユーザーエントリのうち slash command 等のラッパーを弾く接頭辞
CLAUDE_SKIP_PREFIXES = (
    "<command-",  # <command-name> / <command-message> 等
    "<local-command-",
    "Caveat:",
)


def log(msg: str) -> None:
    print(f"session-indexer: {msg}", file=sys.stderr)


# ---------------------------------------------------------------- jsonl 解析


def iter_jsonl(path: Path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue
    except OSError as e:
        log(f"read failed: {path}: {e}")


def claude_user_texts(obj) -> str | None:
    """Claude の user エントリから地のテキストを取り出す。対象外なら None。"""
    if obj.get("type") != "user" or obj.get("isSidechain") or obj.get("isMeta"):
        return None
    # 対話セッションのみ索引する。`claude -p` (sdk-cli) は hook や script 起因が
    # ほとんどで resume 対象にならない (field 自体が無い旧形式は許容する)
    if obj.get("entrypoint", "cli") != "cli":
        return None
    content = obj.get("message", {}).get("content")
    if isinstance(content, str):
        text = content
    elif isinstance(content, list):
        parts = [p.get("text", "") for p in content if isinstance(p, dict) and p.get("type") == "text"]
        text = "\n".join(p for p in parts if p)
    else:
        return None
    text = text.strip()
    if not text or text.startswith(CLAUDE_SKIP_PREFIXES):
        return None
    return text


def parse_claude(path: Path) -> dict | None:
    """Claude セッションを {cwd, started, ai_title, texts} に要約。対象外は None。"""
    ai_title = None
    texts = []
    cwd = None
    started = None
    for obj in iter_jsonl(path):
        if obj.get("type") == "ai-title" and obj.get("aiTitle"):
            ai_title = obj["aiTitle"]
            continue
        # cwd / started はテキスト採否と独立に最初の user エントリから取る
        # (slash command だけのセッションでも cwd filter を効かせるため)
        if cwd is None and obj.get("type") == "user" and not obj.get("isSidechain"):
            cwd = obj.get("cwd")
            started = obj.get("timestamp")
        text = claude_user_texts(obj)
        if text is None:
            continue
        if MARKER in text:
            return None  # タイトル生成が作ったセッション自身は索引しない
        if len(texts) < 5:
            texts.append(text)
    # slash command だけのセッションは地のテキストが 0 件になるが、ai-title が
    # あれば索引する。どちらも無いもの (warmup 等) だけ除外する
    if not texts and not ai_title:
        return None
    return {"cwd": cwd or "", "started": started or "", "ai_title": ai_title, "texts": texts}


def parse_codex(path: Path) -> dict | None:
    """Codex セッションを同じ形に要約。subagent セッションは None。"""
    meta = None
    texts = []
    for obj in iter_jsonl(path):
        if meta is None:
            if obj.get("type") != "session_meta":
                return None  # 先頭が session_meta でないファイルは対象外
            meta = obj.get("payload", {})
            if "subagent" in json.dumps(meta.get("source", "")) or meta.get("thread_source") == "subagent":
                return None
            continue
        if obj.get("type") != "event_msg":
            continue
        payload = obj.get("payload", {})
        if payload.get("type") != "user_message":
            continue
        text = (payload.get("message") or "").strip()
        # <user_instructions> / <environment_context> 等の注入ブロックは除外
        if not text or text.startswith("<"):
            continue
        if MARKER in text:
            return None
        if len(texts) < 5:
            texts.append(text)
    if meta is None or not texts:
        return None
    sid = meta.get("id") or meta.get("session_id")
    if not sid:
        return None
    return {
        "id": sid,
        "cwd": meta.get("cwd", ""),
        "started": meta.get("timestamp", ""),
        "ai_title": None,
        "texts": texts,
    }


# ---------------------------------------------------------------- タイトル生成


def find_claude_bin() -> str | None:
    return shutil.which("claude") or (
        str(Path.home() / ".local/bin/claude")
        if (Path.home() / ".local/bin/claude").exists()
        else None
    )


def generate_title(texts: list[str]) -> str | None:
    claude_bin = find_claude_bin()
    if not claude_bin:
        return None
    excerpt = "\n---\n".join(texts)[:EXCERPT_LIMIT]
    prompt = (
        f"{MARKER} 次の AI コーディングセッション冒頭のユーザー発話の抜粋を読み、"
        "内容が分かる 15〜20 字程度の日本語タイトルを付けてください。"
        "タイトルのみを 1 行で出力し、引用符や記号の装飾は付けないでください。\n\n"
        f"{excerpt}"
    )
    try:
        result = subprocess.run(
            [claude_bin, "-p", "--model", "haiku", prompt],
            capture_output=True,
            text=True,
            timeout=TITLE_TIMEOUT_SEC,
        )
    except (subprocess.TimeoutExpired, OSError) as e:
        log(f"title generation failed: {e}")
        return None
    if result.returncode != 0:
        log(f"title generation failed: {result.stderr.strip()[:200]}")
        return None
    title = result.stdout.strip().splitlines()
    return title[0].strip()[:40] if title and title[0].strip() else None


def fallback_title(texts: list[str]) -> str:
    first_line = texts[0].splitlines()[0]
    return first_line[:FALLBACK_TITLE_LEN]


# ---------------------------------------------------------------- 索引 I/O


def load_index() -> dict:
    entries = {}
    if INDEX_FILE.exists():
        for obj in iter_jsonl(INDEX_FILE):
            if obj.get("id"):
                entries[obj["id"]] = obj
    return entries


def append_entry(entry: dict) -> None:
    INDEX_DIR.mkdir(parents=True, exist_ok=True)
    with open(INDEX_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def build_entry(tool: str, sid: str, path: Path, parsed: dict) -> dict:
    title = parsed["ai_title"]
    generated = title is not None
    if title is None and len("".join(parsed["texts"])) <= SHORT_SESSION_LEN:
        title = fallback_title(parsed["texts"])
        generated = True  # 発話自体が十分タイトルなので再生成不要
    if title is None:
        title = generate_title(parsed["texts"])
        generated = title is not None
    if title is None:
        title = fallback_title(parsed["texts"])
    return {
        "id": sid,
        "tool": tool,
        "cwd": parsed["cwd"],
        "started": parsed["started"],
        "mtime": int(path.stat().st_mtime),
        "title": title,
        "preview": "\n---\n".join(parsed["texts"])[:PREVIEW_LIMIT],
        "generated": generated,
    }


# ---------------------------------------------------------------- 走査


def iter_sessions():
    """(tool, session_id or None, path) を列挙。codex の id は parse 後に確定する。"""
    if CLAUDE_PROJECTS.is_dir():
        for path in CLAUDE_PROJECTS.glob("*/*.jsonl"):
            yield "claude", path.stem, path
    if CODEX_SESSIONS.is_dir():
        for path in CODEX_SESSIONS.glob("**/rollout-*.jsonl"):
            yield "codex", None, path


def index_one(
    tool: str, sid: str | None, path: Path, existing: dict, force_title: str | None = None
) -> bool:
    parsed = parse_claude(path) if tool == "claude" else parse_codex(path)
    if parsed is None:
        return False
    sid = sid or parsed.get("id")
    if not sid:
        return False
    prev = existing.get(sid)
    if force_title is not None:
        # plan の H1 等、確定タイトルでの上書き。索引済みでも append する
        parsed["ai_title"] = force_title.strip()[:60]
    elif prev is not None and prev.get("generated"):
        return False  # 索引済み (fallback タイトルのものだけ再試行する)
    entry = build_entry(tool, sid, path, parsed)
    if force_title is None and prev is not None and not entry["generated"]:
        return False  # fallback → fallback の上書きは無意味
    append_entry(entry)
    existing[sid] = entry
    return True


def catch_up() -> int:
    INDEX_DIR.mkdir(parents=True, exist_ok=True)
    lock = open(LOCK_FILE, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        log("another catch-up is running; skip")
        return 0
    existing = load_index()
    todo = []
    for tool, sid, path in iter_sessions():
        if sid is not None and existing.get(sid, {}).get("generated"):
            continue  # ファイルを開かずに skip (claude は filename = id)
        parsed = parse_claude(path) if tool == "claude" else parse_codex(path)
        if parsed is None:
            continue
        sid = sid or parsed.get("id")
        if not sid or existing.get(sid, {}).get("generated"):
            continue
        todo.append((tool, sid, path, parsed))
    count = 0
    with ThreadPoolExecutor(max_workers=GENERATE_WORKERS) as pool:
        futures = {
            pool.submit(build_entry, tool, sid, path, parsed): sid
            for tool, sid, path, parsed in todo
        }
        for future in as_completed(futures):
            sid = futures[future]
            try:
                entry = future.result()
            except Exception as e:  # 1 セッションの失敗で全体を止めない
                log(f"index failed: {sid}: {e}")
                continue
            if sid in existing and not entry["generated"]:
                continue  # fallback → fallback の上書きは無意味
            append_entry(entry)
            count += 1
            if count % 20 == 0:
                log(f"progress: {count}/{len(todo)}")
    return count


def index_single(tool: str, sid: str, force_title: str | None = None) -> bool:
    if tool == "claude":
        matches = list(CLAUDE_PROJECTS.glob(f"*/{sid}.jsonl"))
    else:
        matches = [p for p in CODEX_SESSIONS.glob("**/rollout-*.jsonl") if sid in p.name]
    if not matches:
        log(f"session not found: {tool} {sid}")
        return False
    return index_one(
        tool, sid if tool == "claude" else None, matches[0], load_index(), force_title
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--session", metavar="ID", help="単一セッションを索引する")
    mode.add_argument("--catch-up", action="store_true", help="索引に無いセッションを一括処理する")
    parser.add_argument("--tool", choices=["claude", "codex"], default="claude")
    parser.add_argument("--title", help="タイトルを生成せずこの値で上書きする (plan の H1 等)")
    args = parser.parse_args()

    if args.catch_up:
        count = catch_up()
        log(f"indexed {count} session(s)")
        return 0
    return 0 if index_single(args.tool, args.session, args.title) else 1


if __name__ == "__main__":
    sys.exit(main())
