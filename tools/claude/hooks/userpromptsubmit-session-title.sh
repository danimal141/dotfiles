#!/usr/bin/env bash

# UserPromptSubmit hook: 未索引のセッションを session-picker の索引に登録する。
# 最初のプロンプトがやりたいことを最も表すため、セッション開始直後に索引する
# (SessionEnd 待ちにしない)。索引済みなら即 exit するので 2 回目以降は無コスト。
#
# プロンプトが jsonl に書かれるのを待つため sleep 2 してから indexer を起動する。
# まだ書かれていなければ indexer は何もせず、次のプロンプトで再試行される。
# 生成中の重複起動は pending marker で抑止する。
#
# 注意: UserPromptSubmit の stdout は会話 context に注入されるため全て捨てる。
# fail-open: どこで失敗しても exit 0 (hook 障害で本体を止めない)

input=$(cat) || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || sid=""

# session_id を引数に渡す前に検証する (空 / パス区切り / 上位参照は捨てる)
case "$sid" in
  '' | */* | *..*) exit 0 ;;
esac

base="$HOME/.local/share/session-picker"
grep -qF "$sid" "$base/index.jsonl" 2>/dev/null && exit 0
[ -e "$base/pending/$sid" ] && exit 0

indexer=$(command -v session-indexer.py 2>/dev/null) ||
  indexer="$HOME/.local/bin/session-indexer.py"
[ -x "$indexer" ] || exit 0

mkdir -p "$base/pending" 2>/dev/null || exit 0
: >"$base/pending/$sid" 2>/dev/null || exit 0

nohup bash -c "sleep 2; '$indexer' --session '$sid' --tool claude; rm -f '$base/pending/$sid'" \
  >/dev/null 2>&1 &

exit 0
