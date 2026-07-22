#!/usr/bin/env python3
"""Stop hook: rollout を要約した日本語タイトルを thread title として付ける。

Codex は thread title を ~/.codex/state_N.sqlite の threads.title に持つ
(デフォルトは first user message、公式の rename API 無し)。内部スキーマ
なので、壊れた場合は title が更新されなくなるだけになるよう全経路
fail-open にする。命名は 1 セッション 1 回 (marker で管理)。
"""

import json
import os
import re
import shlex
import sqlite3
import subprocess
import sys
from pathlib import Path

MAX_TITLE_LEN = 50
MAX_CONTEXT_CHARS = 6000
MIN_USER_MESSAGES = 1
RECENT_MESSAGES = 3
LLM_TIMEOUT_SEC = 120
DEFAULT_NAMER_CMD = "claude -p --model haiku --no-session-persistence"

PROMPT = (
    "以下はコーディングエージェントのセッション記録の抜粋です。"
    "後からセッション一覧で内容を思い出せるように、このセッションの主題を表す"
    "25文字以内の日本語タイトルを1つだけ出力してください。"
    "タイトル本文のみを出力し、引用符・説明・前置きを付けないこと。"
)

SESSION_ID_RE = re.compile(r"^[0-9a-zA-Z-]{1,64}$")
STATE_DB_RE = re.compile(r"^state_(\d+)\.sqlite$")


def valid_session_id(session_id):
    return bool(SESSION_ID_RE.match(session_id or ""))


def sanitize_title(raw):
    line = (raw or "").strip().splitlines()[0] if (raw or "").strip() else ""
    line = re.sub(r"\s+", " ", line).strip("「」『』\"'` ")
    return line[:MAX_TITLE_LEN]


def _iter_texts(lines):
    roles = {"user_message": "user", "agent_message": "assistant"}
    for line in lines:
        try:
            obj = json.loads(line)
        except (json.JSONDecodeError, TypeError):
            continue
        payload = obj.get("payload") or {}
        role = roles.get(payload.get("type") or "") if obj.get("type") == "event_msg" else None
        text = (payload.get("message") or "").strip() if role else ""
        if role and text:
            yield role, text


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


def find_state_db(codex_home):
    best = None
    best_version = -1
    try:
        entries = list(Path(codex_home).iterdir())
    except OSError:
        return None
    for entry in entries:
        match = STATE_DB_RE.match(entry.name)
        if match and int(match.group(1)) > best_version:
            best_version = int(match.group(1))
            best = entry
    return best


def generate_title(context):
    cmd = os.environ.get("SESSION_NAMER_CMD") or DEFAULT_NAMER_CMD
    env = dict(os.environ, CLAUDE_SESSION_NAMER="1", CODEX_SESSION_NAMER="1")
    try:
        result = subprocess.run(
            shlex.split(cmd),
            input=f"{PROMPT}\n\n{context}",
            capture_output=True,
            text=True,
            timeout=LLM_TIMEOUT_SEC,
            env=env,
            cwd=os.path.expanduser("~"),
        )
    except (OSError, subprocess.SubprocessError, ValueError):
        return ""
    if result.returncode != 0:
        return ""
    return sanitize_title(result.stdout)


def fetch_thread(db_path, thread_id):
    try:
        conn = sqlite3.connect(db_path, timeout=5)
        try:
            row = conn.execute(
                "SELECT rollout_path, title, first_user_message FROM threads WHERE id = ?",
                (thread_id,),
            ).fetchone()
        finally:
            conn.close()
    except sqlite3.Error:
        return None
    return row


def update_title(db_path, thread_id, old_title, new_title):
    try:
        conn = sqlite3.connect(db_path, timeout=5)
        try:
            cur = conn.execute(
                "UPDATE threads SET title = ? WHERE id = ? AND title = ?",
                (new_title, thread_id, old_title),
            )
            conn.commit()
            return cur.rowcount > 0
        finally:
            conn.close()
    except sqlite3.Error:
        return False


def daemonize():
    """親 process では False を返し、切り離した子 process では True を返す。"""
    if os.fork() > 0:
        return False
    os.setsid()
    if os.fork() > 0:
        os._exit(0)
    devnull = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(devnull, fd)
    return True


def main():
    if os.environ.get("CLAUDE_SESSION_NAMER") or os.environ.get("CODEX_SESSION_NAMER"):
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0
    session_id = payload.get("session_id") or payload.get("thread_id") or ""
    if not valid_session_id(session_id):
        return 0
    codex_home = Path(os.environ.get("CODEX_HOME") or "~/.codex").expanduser()
    marker = codex_home / "session-namer" / session_id
    if marker.exists():
        return 0
    db_path = find_state_db(codex_home)
    if db_path is None:
        return 0
    row = fetch_thread(db_path, session_id)
    if row is None:
        return 0
    rollout_path, title, first_user_message = row
    if (title or "").strip() and (title or "").strip() != (first_user_message or "").strip():
        # 既にカスタム名が付いている (手動 rename 等) → 以後スキップ
        _write_marker(marker, title)
        return 0
    try:
        with open(rollout_path, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except (OSError, TypeError):
        return 0
    context = build_context(lines)
    if not context:
        # 会話がまだ短い。marker を書かず次の Stop で再判定する
        return 0
    # LLM 呼び出しは background で行い、turn 完了をブロックしない
    if not daemonize():
        return 0
    new_title = generate_title(context)
    if new_title and update_title(db_path, session_id, title, new_title):
        _write_marker(marker, new_title)
    os._exit(0)


def _write_marker(marker, title):
    try:
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.write_text((title or "") + "\n", encoding="utf-8")
    except OSError:
        pass


if __name__ == "__main__":
    sys.exit(main())
