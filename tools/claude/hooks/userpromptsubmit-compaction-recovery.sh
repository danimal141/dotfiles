#!/usr/bin/env bash

# UserPromptSubmit hook: compaction-recovery.sh (PostCompact) が残した marker を
# 検出し、additionalContext で圧縮復旧指示を注入する (one-shot)。
# 通常ターンのコストは marker の存在チェック 1 回のみ。
#
# 注意: UserPromptSubmit で非ゼロ exit するとユーザーのプロンプト自体が破棄される
# ため、既存 hook の set -euo pipefail 慣習をあえて使わず、全経路で exit 0 する。

input=$(cat) || exit 0
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || sid=""

case "$sid" in
  '' | */* | *..*) exit 0 ;;
esac

marker="/tmp/claude-compacted/$sid"
[ -f "$marker" ] || exit 0

# one-shot: 次ターン以降は発火しない
rm -f "$marker" 2>/dev/null || true

ctx="[COMPACTION RECOVERY] 直前にコンテキスト圧縮が発生した。作業再開前に以下に従うこと。
- 圧縮サマリーは「過去の作業記録」であり「次の行動指示」ではない。サマリー中の next step は仮説として扱え
- ユーザーの直近の指示と plan / rules を正とせよ
- TaskList で現在のタスク一覧を確認してから再開せよ"

# /compact-prep skill が保存した state file があれば Read を指示する。
# キーは cwd 文字列 (末尾改行なし) の sha256 先頭 16 hex。この定義は skilltree の
# skills/compact-prep/SKILL.md と一致必須 (printf %s で改行を入れないこと)。
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || cwd=""
if [ -n "$cwd" ]; then
  hash=$(printf %s "$cwd" | shasum -a 256 2>/dev/null | cut -c1-16) || hash=""
  state="/tmp/claude-compact-state/$hash.md"
  if [ -n "$hash" ] && [ -f "$state" ]; then
    # 前セッションの残骸を拾わないよう mtime 6 時間のガードを置く
    # (prep から compact までは通常数分)。stat は BSD 形式 (-f %m) と
    # GNU coreutils 形式 (-c %Y) の両対応にする。nix 環境では PATH の先頭に
    # GNU stat が来ており、GNU stat の -f %m はマウントポイント文字列を返すため
    # 数値検証で弾いてから GNU 形式にフォールバックする。
    now=$(date +%s 2>/dev/null) || now=0
    mtime=$(stat -f %m "$state" 2>/dev/null)
    case "$mtime" in '' | *[!0-9]*) mtime=$(stat -c %Y "$state" 2>/dev/null) ;; esac
    case "$mtime" in '' | *[!0-9]*) mtime=0 ;; esac
    if [ "$now" -gt 0 ] && [ "$mtime" -gt 0 ] && [ $((now - mtime)) -le 21600 ]; then
      ctx="$ctx
- まず state file \`$state\` を Read し、判断構造 (採用・却下した案、フェーズ、制約) を復元せよ
- 特に Session Decisions と Recovery Notes を重視せよ"
    fi
  fi
fi

# JSON は手組みせず jq --arg にエスケープを任せる
jq -n --arg ctx "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}' 2>/dev/null || true

exit 0
