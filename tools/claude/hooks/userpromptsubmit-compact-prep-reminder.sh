#!/usr/bin/env bash

# UserPromptSubmit hook: statusline.sh が書いた warn marker を検出し、
# additionalContext で /compact-prep の提案を促す (one-shot + cooldown)。
#
# フロー:
#   statusline.sh が ctx >= 閾値 で warn marker を書く
#   → 本 hook が検出して注入 → warn 削除 + warned (cooldown) 作成
#   → compaction-recovery.sh (PostCompact) が warned を削除してリセット
#
# 注意: UserPromptSubmit で非ゼロ exit するとユーザーのプロンプト自体が破棄される
# ため、既存 hook の set -euo pipefail 慣習をあえて使わず、全経路で exit 0 する。

input=$(cat) || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || sid=""

case "$sid" in
  '' | */* | *..*) exit 0 ;;
esac

warn="/tmp/claude-compact-warn/$sid"
[ -f "$warn" ] || exit 0

pct=$(cat "$warn" 2>/dev/null) || pct=""
pct=${pct:-"60+"}

rm -f "$warn" 2>/dev/null || true

# cooldown: 同一セッションでは再通知しない (リセットは PostCompact のみ)
mkdir -p /tmp/claude-compact-warned 2>/dev/null &&
  date +%s >"/tmp/claude-compact-warned/$sid" 2>/dev/null

ctx="[COMPACT PREP REMINDER] context 使用率が ${pct}% に達した (自動 compact は 85% で発火する)。
- 作業の区切りでユーザーに /compact-prep の実行を提案せよ (一言でよい。作業は継続してよい)
- /compact-prep 完了後は /compact の実行を案内せよ
- scope 縮小や別セッション化ではなく、圧縮前の state 保存で対処せよ"

jq -n --arg ctx "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}' 2>/dev/null || true

exit 0
