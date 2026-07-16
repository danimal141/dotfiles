#!/usr/bin/env bash

# PostToolUse hook (matcher: ExitPlanMode): plan 承認時にセッションのタイトルを
# plan ファイルの H1 見出しで上書きする。plan の H1 はやりたいことを人間可読に
# 要約済みなので、LLM を呼ばずそのまま索引タイトルに使える。
#
# plan ファイルの path は tool_response 内の文言
# ("Your plan has been saved to: ~/.claude/plans/<slug>.md") から抽出する。
#
# fail-open: どこで失敗しても exit 0 (hook 障害で本体を止めない)

input=$(cat) || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || sid=""

# session_id を引数に渡す前に検証する (空 / パス区切り / 上位参照は捨てる)
case "$sid" in
  '' | */* | *..*) exit 0 ;;
esac

# plan path 抽出 (slug は英数とハイフンのみで空白を含まない前提)
plan=$(printf '%s' "$input" |
  grep -oE '/[A-Za-z0-9._/-]*/\.claude/plans/[A-Za-z0-9._-]+\.md' 2>/dev/null |
  head -1) || plan=""
[ -n "$plan" ] && [ -f "$plan" ] || exit 0

title=$(sed -n '/^# /{s/^# //p;q;}' "$plan" 2>/dev/null) || title=""
[ -n "$title" ] || exit 0

indexer=$(command -v session-indexer.py 2>/dev/null) ||
  indexer="$HOME/.local/bin/session-indexer.py"
[ -x "$indexer" ] || exit 0

nohup "$indexer" --session "$sid" --tool claude --title "$title" >/dev/null 2>&1 &

exit 0
