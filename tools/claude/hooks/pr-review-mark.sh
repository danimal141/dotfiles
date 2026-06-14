#!/usr/bin/env bash

# PostToolUse(Skill) hook: code-review skill の実行を記録し、同 session の
# PR 作成ゲート (pr-review-gate.sh) を 1 回解放する marker を置く。
#
# Skill tool の入力フィールドは版により skill / skillName のどちらもあり得るため
# 両方を見る。marker は session_id でスコープし、レビューしたセッション内でのみ
# 有効にする。

set -euo pipefail

input=$(cat)
skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // .tool_input.skillName // ""')
sid=$(printf '%s' "$input" | jq -r '.session_id // "global"')

if [ "$skill" = "code-review" ]; then
  touch "/tmp/.claude-review-done-$sid"
fi

exit 0
