#!/usr/bin/env bash

# statusline スクリプト (hook ではない。settings.json の statusLine.command が呼ぶ)。
# hooks/ に置くのは、このディレクトリ全体が ~/.claude/hooks へ symlink 済みで
# ファイル追加が即反映されるため。
#
# 役割:
#   1. ミニマル表示: [モデル名] ディレクトリ名 | ctx NN%
#   2. context 使用率が閾値以上なら warn marker を書く
#      (userpromptsubmit-compact-prep-reminder.sh が検出して /compact-prep を提案する)
#
# stdout の 1 行目が statusline 表示になるため、どんな入力でも必ず 1 行出力する。

# 通知閾値。CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=85 (自動 compact 発火点) の 25pt 手前で
# 通知し、区切りの良いところまで作業を続けてから /compact-prep する余裕を残す。
WARN_THRESHOLD=60

input=$(cat) || input=""

model=$(printf '%s' "$input" | jq -r '.model.display_name // "claude"' 2>/dev/null) || model="claude"
dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // ""' 2>/dev/null) || dir=""
pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0 | floor' 2>/dev/null) || pct=0
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || sid=""

case "$pct" in '' | *[!0-9]*) pct=0 ;; esac
base=${dir##*/}

if [ "$pct" -ge "$WARN_THRESHOLD" ]; then
  printf '[%s] %s | \033[33mctx %s%%\033[0m\n' "$model" "${base:-?}" "$pct"
else
  printf '[%s] %s | ctx %s%%\n' "$model" "${base:-?}" "$pct"
fi

# warn marker: 閾値以上かつ未通知 (warned なし) かつ未書込 (warn なし) のときだけ書く。
# statusline は高頻度で呼ばれるため、既存チェックで冪等にする。
case "$sid" in
  '' | */* | *..*) exit 0 ;;
esac
if [ "$pct" -ge "$WARN_THRESHOLD" ] &&
  [ ! -f "/tmp/claude-compact-warned/$sid" ] &&
  [ ! -f "/tmp/claude-compact-warn/$sid" ]; then
  mkdir -p /tmp/claude-compact-warn 2>/dev/null &&
    printf '%s\n' "$pct" >"/tmp/claude-compact-warn/$sid" 2>/dev/null
fi

exit 0
