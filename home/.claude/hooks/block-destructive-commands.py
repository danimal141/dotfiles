#!/usr/bin/env python3
"""PreToolUse hook: 破壊的コマンドをブロックする.

カテゴリ: IaC, ファイル破壊, Git 破壊, DB 破壊, コンテナ/K8s 破壊, 機密ファイルアクセス
マッチ時は stderr にメッセージを出力し exit 2 でブロック。
"""

import json
import re
import sys

DESTRUCTIVE_PATTERNS = [
    # --- IaC ---
    (re.compile(r"(terraform|tofu)\s+destroy"), "IaC: destroy は禁止"),
    (
        re.compile(r"(terraform|tofu)\s+apply\s+.*-auto-approve"),
        "IaC: -auto-approve 付き apply は禁止",
    ),
    # --- ファイル破壊 ---
    (re.compile(r"rm\s+.*-[a-zA-Z]*r[a-zA-Z]*.*-[a-zA-Z]*f"), "ファイル: rm -rf は禁止"),
    (re.compile(r"rm\s+.*-[a-zA-Z]*f[a-zA-Z]*.*-[a-zA-Z]*r"), "ファイル: rm -rf は禁止"),
    (re.compile(r"rm\s+.*-[a-zA-Z]*rf"), "ファイル: rm -rf は禁止"),
    (re.compile(r"rm\s+.*-[a-zA-Z]*fr"), "ファイル: rm -rf は禁止"),
    # --- Git 破壊 ---
    (
        re.compile(r"git\s+push\s+.*--force(?!-with-lease)"),
        "Git: --force push は禁止 (--force-with-lease を使用してください)",
    ),
    (
        re.compile(r"git\s+push\s+.*\s-f(?:\s|$)"),
        "Git: -f push は禁止 (--force-with-lease を使用してください)",
    ),
    (re.compile(r"git\s+reset\s+--hard"), "Git: reset --hard は禁止"),
    (re.compile(r"git\s+clean\s+.*-[a-zA-Z]*f"), "Git: clean -f は禁止"),
    (re.compile(r"git\s+branch\s+.*-D"), "Git: branch -D は禁止 (-d を使用してください)"),
    # --- DB 破壊 ---
    (
        re.compile(r"DROP\s+(TABLE|DATABASE|SCHEMA)", re.IGNORECASE),
        "DB: DROP TABLE/DATABASE/SCHEMA は禁止",
    ),
    (re.compile(r"TRUNCATE\s+TABLE", re.IGNORECASE), "DB: TRUNCATE TABLE は禁止"),
    (
        re.compile(r"DELETE\s+FROM\s+\S+\s*;", re.IGNORECASE),
        "DB: WHERE なし DELETE は禁止",
    ),
    # --- コンテナ/K8s 破壊 ---
    (re.compile(r"docker\s+system\s+prune"), "Docker: system prune は禁止"),
    (
        re.compile(r"kubectl\s+delete\s+(namespace|node)"),
        "K8s: namespace/node の削除は禁止",
    ),
    # --- 機密ファイルアクセス ---
    (
        re.compile(r"(cat|head|tail|less|more)\s+.*\.(env|pem|key|p12|pfx)"),
        "機密ファイル: .env/証明書/鍵ファイルの読み取りは禁止",
    ),
    (
        re.compile(r"(cat|head|tail|less|more)\s+.*\.ssh/"),
        "機密ファイル: SSH ディレクトリの読み取りは禁止",
    ),
    (
        re.compile(r"(cat|head|tail|less|more)\s+.*(credentials|\.aws/|\.gnupg/)"),
        "機密ファイル: AWS/GnuPG 認証情報の読み取りは禁止",
    ),
    (
        re.compile(r"(cp|mv|tee|sed\s+-i|>\s*\S*terraform\.tfstate).*terraform\.tfstate"),
        "Terraform: state ファイルへの書き込みは禁止",
    ),
    (
        re.compile(r"terraform\s+state\s+(rm|mv|push|replace-provider)"),
        "Terraform: state の破壊的操作は禁止",
    ),
]


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    command = data.get("tool_input", {}).get("command", "")
    if not command:
        sys.exit(0)

    for pattern, message in DESTRUCTIVE_PATTERNS:
        if pattern.search(command):
            print(
                f"BLOCKED: {message}: {command}",
                file=sys.stderr,
            )
            sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
