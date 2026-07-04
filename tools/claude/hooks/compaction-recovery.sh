#!/usr/bin/env bash

# PostCompact hook (matcher なし: manual / auto 両対応): 圧縮発生を marker file
# で記録する。PostCompact は additionalContext を返せないため、復旧指示の注入は
# userpromptsubmit-compaction-recovery.sh が次の UserPromptSubmit で行う (2 段構成)。
#
# fail-open: どこで失敗しても exit 0 (hook 障害で本体を止めない)

input=$(cat) || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || sid=""

# session_id をパス結合する前に検証する (空 / パス区切り / 上位参照は捨てる)
case "$sid" in
  '' | */* | *..*) exit 0 ;;
esac

mkdir -p /tmp/claude-compacted 2>/dev/null || exit 0
date +%s >"/tmp/claude-compacted/$sid" 2>/dev/null || true

# compact 後は閾値警告の状態をリセットする。warn (未消費の警告) を残すと
# 圧縮直後のターンで復旧指示と /compact-prep 提案が同時注入され矛盾するため、
# warned (cooldown) と合わせて両方消す。
rm -f "/tmp/claude-compact-warn/$sid" "/tmp/claude-compact-warned/$sid" 2>/dev/null || true

exit 0
