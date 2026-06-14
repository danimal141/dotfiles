#!/usr/bin/env bash

# PreToolUse(Bash) hook: `gh pr create` を /code-review 実行前に防ぐゲート。
#
# /code-review skill を走らせると pr-review-mark.sh が同 session の marker を
# 置き、このゲートが 1 回だけ解放される。CLAUDE.md / harness の指示は「努力目標」
# だが、PR 作成だけは hook で確実にブロックする (Claude Code memory doc が
# enforcement には PreToolUse hook を使えと明記)。
#
# exit 2 でツール実行をブロックし、stderr のメッセージを Claude に返す。

set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
sid=$(printf '%s' "$input" | jq -r '.session_id // "global"')
marker="/tmp/.claude-review-done-$sid"

# コマンド境界 (先頭 / ; / && / | の直後) の `gh pr create` のみを対象にする。
# 改行は事前にスペースへ潰す: BSD/GNU grep の -z 差異を避けつつ、コミットメッセージ
# や heredoc 本文の「行頭言及」を誤ブロックしない (改行を消すと前が空白の mention
# 扱いになる)。改行区切りの実コマンドは取りこぼすが、gate は soft な reminder なので
# 許容する (誤ブロックを避ける方を優先)。
cmd_line=$(printf '%s' "$cmd" | tr '\n' ' ')
if printf '%s' "$cmd_line" | grep -qE '(^|[;&|])[[:space:]]*gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
  if [ -f "$marker" ]; then
    # 1 回限り消費する (PR ごとにレビューを要求する)
    rm -f "$marker"
    exit 0
  fi
  echo 'BLOCKED: PR 作成前に /code-review で差分レビューを実行してください。' >&2
  exit 2
fi

exit 0
