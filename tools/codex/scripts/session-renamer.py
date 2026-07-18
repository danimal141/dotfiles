#!/usr/bin/env python3
"""Codex セッション日本語リネーム: title が first_user_message のままの
CLI セッションに日本語タイトルを付ける。

~/.codex/state_N.sqlite の threads.title を直接 UPDATE する。
内部スキーマ依存、fail-open。

Usage:
  ~/.codex/scripts/session-renamer.py          # dry-run (対象一覧)
  ~/.codex/scripts/session-renamer.py --apply  # 実行
"""

import argparse
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

STATE_DB_RE = re.compile(r"^state_(\d+)\.sqlite$")


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


def _iter_texts(lines):
    roles = {"user_message": "user", "agent_message": "assistant"}
    for line in lines:
        try:
            obj = json.loads(line)
        except (json.JSONDecodeError, TypeError):
            continue
        payload = obj.get("payload") or {}
        role = (
            roles.get(payload.get("type") or "")
            if obj.get("type") == "event_msg"
            else None
        )
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


def fetch_targets(db_path):
    try:
        conn = sqlite3.connect(db_path, timeout=5)
        rows = conn.execute(
            "SELECT id, rollout_path, title, first_user_message FROM threads "
            "WHERE archived = 0 AND source = 'cli' AND title = first_user_message"
        ).fetchall()
        conn.close()
    except sqlite3.Error:
        return []
    targets = []
    for tid, rollout_path, title, _ in rows:
        if not rollout_path or not os.path.isfile(rollout_path):
            continue
        try:
            with open(rollout_path, encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except OSError:
            continue
        context = build_context(lines)
        if not context:
            continue
        targets.append((tid, title, context))
    return targets


def update_title(db_path, thread_id, old_title, new_title):
    try:
        conn = sqlite3.connect(db_path, timeout=5)
        cur = conn.execute(
            "UPDATE threads SET title = ? WHERE id = ? AND title = ?",
            (new_title, thread_id, old_title),
        )
        conn.commit()
        ok = cur.rowcount > 0
        conn.close()
        return ok
    except sqlite3.Error:
        return False


def main():
    parser = argparse.ArgumentParser(description="Codex セッション日本語リネーム")
    parser.add_argument("--apply", action="store_true", help="実際にリネーム実行")
    args = parser.parse_args()

    codex_home = Path(os.environ.get("CODEX_HOME") or "~/.codex").expanduser()
    db_path = find_state_db(codex_home)
    if db_path is None:
        print("state DB が見つかりません", file=sys.stderr)
        return 1

    targets = fetch_targets(db_path)
    if not targets:
        print("リネーム対象なし")
        return 0

    print(f"対象: {len(targets)} セッション (DB: {db_path.name})")
    for tid, title, _ in targets:
        label = title[:50] if title else "(タイトルなし)"
        print(f"  {tid[:8]}... {label}")

    if not args.apply:
        print("\n--apply で実行")
        return 0

    print()
    ok = fail = 0
    for tid, old_title, context in targets:
        title = generate_title(context)
        if not title:
            print(f"  x {tid[:8]}... 生成失敗")
            fail += 1
            continue
        if update_title(db_path, tid, old_title, title):
            print(f"  o {tid[:8]}... {old_title[:30]} -> {title}")
            ok += 1
        else:
            print(f"  x {tid[:8]}... DB 更新失敗")
            fail += 1

    print(f"\n完了: {ok} 成功, {fail} 失敗")
    return 0


if __name__ == "__main__":
    sys.exit(main())
