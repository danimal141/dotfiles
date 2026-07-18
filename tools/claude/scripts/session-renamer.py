#!/usr/bin/env python3
"""セッション日本語リネーム: 日本語タイトルがないセッションに agent-name を付ける。

agent-name は ai-title より picker で優先されるため、Claude Code の
built-in 命名に上書きされない。内部フォーマット依存、fail-open。

Usage:
  ~/.claude/scripts/session-renamer.py                # dry-run (対象一覧)
  ~/.claude/scripts/session-renamer.py --apply        # 実行
  ~/.claude/scripts/session-renamer.py --apply --all  # 全プロジェクト対象
"""

import argparse
import json
import os
import re
import shlex
import subprocess
import sys

MAX_TITLE_LEN = 50
MAX_CONTEXT_CHARS = 6000
MIN_USER_MESSAGES = 2
RECENT_MESSAGES = 3
LLM_TIMEOUT_SEC = 120
DEFAULT_NAMER_CMD = "claude -p --model haiku --no-session-persistence"
PROJECTS_DIR = os.path.expanduser("~/.claude/projects")

PROMPT = (
    "以下はコーディングエージェントのセッション記録の抜粋です。"
    "後からセッション一覧で内容を思い出せるように、このセッションの主題を表す"
    "25文字以内の日本語タイトルを1つだけ出力してください。"
    "タイトル本文のみを出力し、引用符・説明・前置きを付けないこと。"
)

JP_RE = re.compile(r"[　-鿿]")
SESSION_ID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
)


def has_japanese(text):
    return bool(JP_RE.search(text or ""))


def cwd_to_project_dir():
    encoded = re.sub(r"[/.]", "-", os.getcwd())
    d = os.path.join(PROJECTS_DIR, encoded)
    return d if os.path.isdir(d) else None


def get_titles(lines):
    agent_name = ""
    ai_title = ""
    for line in lines:
        try:
            obj = json.loads(line)
        except (json.JSONDecodeError, TypeError):
            continue
        if obj.get("type") == "agent-name" and obj.get("agentName"):
            agent_name = obj["agentName"]
        if obj.get("type") == "ai-title":
            ai_title = obj.get("aiTitle", "")
    return agent_name, ai_title


def needs_rename(lines):
    agent_name, ai_title = get_titles(lines)
    if agent_name:
        return False, agent_name
    if has_japanese(ai_title):
        return False, ai_title
    return True, ai_title


def _message_text(obj):
    content = (obj.get("message") or {}).get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(
            item.get("text", "")
            for item in content
            if isinstance(item, dict) and item.get("type") == "text"
        )
    return ""


def _iter_texts(lines):
    for line in lines:
        try:
            obj = json.loads(line)
        except (json.JSONDecodeError, TypeError):
            continue
        if obj.get("type") not in ("user", "assistant") or obj.get("isSidechain"):
            continue
        text = _message_text(obj).strip()
        if text:
            yield obj["type"], text


def build_context(lines):
    texts = list(_iter_texts(lines))
    user_count = sum(1 for role, _ in texts if role == "user")
    if user_count < MIN_USER_MESSAGES:
        return None
    per_message = MAX_CONTEXT_CHARS // (RECENT_MESSAGES + 1)
    first_user = next(text for role, text in texts if role == "user")
    parts = ["[最初の依頼]", first_user[:per_message], "[直近のやり取り]"]
    parts += [
        f"{role}: {text[:per_message]}" for role, text in texts[-RECENT_MESSAGES:]
    ]
    return "\n".join(parts)[:MAX_CONTEXT_CHARS]


def sanitize_title(raw):
    line = (raw or "").strip().splitlines()[0] if (raw or "").strip() else ""
    line = re.sub(r"\s+", " ", line).strip("「」『』\"'` ")
    return line[:MAX_TITLE_LEN]


def generate_title(context):
    cmd = os.environ.get("SESSION_NAMER_CMD") or DEFAULT_NAMER_CMD
    try:
        result = subprocess.run(
            shlex.split(cmd),
            input=f"{PROMPT}\n\n{context}",
            capture_output=True,
            text=True,
            timeout=LLM_TIMEOUT_SEC,
        )
    except (OSError, subprocess.SubprocessError, ValueError):
        return ""
    return sanitize_title(result.stdout) if result.returncode == 0 else ""


def write_rename(transcript_path, session_id, title):
    records = [
        json.dumps(
            {"type": "agent-name", "agentName": title, "sessionId": session_id},
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        json.dumps(
            {"type": "ai-title", "aiTitle": title, "sessionId": session_id},
            ensure_ascii=False,
            separators=(",", ":"),
        ),
    ]
    with open(transcript_path, "a", encoding="utf-8") as f:
        for r in records:
            f.write(r + "\n")


def scan_project(project_dir):
    targets = []
    for fname in os.listdir(project_dir):
        if not fname.endswith(".jsonl"):
            continue
        session_id = fname[:-6]
        if not SESSION_ID_RE.match(session_id):
            continue
        fpath = os.path.join(project_dir, fname)
        try:
            with open(fpath, encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except OSError:
            continue
        rename_needed, current_title = needs_rename(lines)
        if not rename_needed:
            continue
        context = build_context(lines)
        if not context:
            continue
        targets.append((fpath, session_id, current_title, context))
    return targets


def main():
    parser = argparse.ArgumentParser(description="セッション日本語リネーム")
    parser.add_argument("--apply", action="store_true", help="実際にリネーム実行")
    parser.add_argument("--all", action="store_true", help="全プロジェクト対象")
    args = parser.parse_args()

    if args.all:
        project_dirs = [
            os.path.join(PROJECTS_DIR, d)
            for d in os.listdir(PROJECTS_DIR)
            if os.path.isdir(os.path.join(PROJECTS_DIR, d))
        ]
    else:
        project_dir = cwd_to_project_dir()
        if not project_dir:
            print(f"プロジェクト未検出: {os.getcwd()}", file=sys.stderr)
            return 1
        project_dirs = [project_dir]

    targets = []
    for pd in project_dirs:
        targets.extend(scan_project(pd))

    if not targets:
        print("リネーム対象なし")
        return 0

    print(f"対象: {len(targets)} セッション")
    for _, sid, current, _ in targets:
        print(f"  {sid[:8]}... {current or '(タイトルなし)'}")

    if not args.apply:
        print("\n--apply で実行")
        return 0

    print()
    ok = fail = 0
    for fpath, sid, current, context in targets:
        title = generate_title(context)
        if not title:
            print(f"  x {sid[:8]}... 生成失敗")
            fail += 1
            continue
        try:
            write_rename(fpath, sid, title)
        except OSError as e:
            print(f"  x {sid[:8]}... 書込失敗: {e}")
            fail += 1
            continue
        print(f"  o {sid[:8]}... {current or '(なし)'} -> {title}")
        ok += 1

    print(f"\n完了: {ok} 成功, {fail} 失敗")
    return 0


if __name__ == "__main__":
    sys.exit(main())
