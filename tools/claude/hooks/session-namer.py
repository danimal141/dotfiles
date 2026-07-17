#!/usr/bin/env python3
"""SessionEnd hook: transcript を要約した日本語タイトルをセッション名として付ける。

resume picker のタイトルは transcript jsonl 内の
{"type":"ai-title","aiTitle":...,"sessionId":...} レコード (最後のものが有効)。
/rename や plan 承認による明示的な名前は agent-name レコードに残るため、
それがあるセッションは上書きしない (内部フォーマット、公式 API 無し)。
壊れた場合は名前が付かなくなるだけになるよう、全経路 fail-open にする。
"""

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

PROMPT = (
    "以下はコーディングエージェントのセッション記録の抜粋です。"
    "後からセッション一覧で内容を思い出せるように、このセッションの主題を表す"
    "25文字以内の日本語タイトルを1つだけ出力してください。"
    "タイトル本文のみを出力し、引用符・説明・前置きを付けないこと。"
)

SESSION_ID_RE = re.compile(r"^[0-9a-zA-Z-]{1,64}$")


def valid_session_id(session_id):
    return bool(SESSION_ID_RE.match(session_id or ""))


def sanitize_title(raw):
    line = (raw or "").strip().splitlines()[0] if (raw or "").strip() else ""
    line = re.sub(r"\s+", " ", line).strip("「」『』\"'` ")
    return line[:MAX_TITLE_LEN]


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


def title_record(session_id, title):
    record = {"type": "ai-title", "aiTitle": title, "sessionId": session_id}
    return json.dumps(record, ensure_ascii=False, separators=(",", ":"))


def has_agent_name(lines):
    for line in lines:
        try:
            obj = json.loads(line)
        except (json.JSONDecodeError, TypeError):
            continue
        if obj.get("type") == "agent-name" and obj.get("agentName"):
            return True
    return False


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
    session_id = payload.get("session_id") or ""
    transcript_path = payload.get("transcript_path") or ""
    if not valid_session_id(session_id) or not os.path.isfile(transcript_path):
        return 0
    try:
        with open(transcript_path, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except OSError:
        return 0
    if has_agent_name(lines):
        return 0
    context = build_context(lines)
    if not context:
        return 0
    # LLM 呼び出しは background で行い、claude 本体の終了をブロックしない
    # (追記も本体終了後になるので transcript の write race も避けられる)
    if not daemonize():
        return 0
    title = generate_title(context)
    if title:
        try:
            with open(transcript_path, "a", encoding="utf-8") as f:
                f.write(title_record(session_id, title) + "\n")
        except OSError:
            pass
    os._exit(0)


if __name__ == "__main__":
    sys.exit(main())
