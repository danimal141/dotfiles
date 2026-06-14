# Preferred Tools

専用ツール (Read / Grep / Glob 等) が使える場面では**そちらを最優先**する
(harness / CLAUDE.md の指示が上位)。その上で、**シェルを使うとき**は標準コマンド
より以下を優先する (このマシンに導入済みのもの):

| Tool  | Replaces | 用途                   |
| ----- | -------- | ---------------------- |
| `rg`  | grep     | 高速検索               |
| `fd`  | find     | ファイル検索           |
| `bat` | cat      | シンタックスハイライト |
| `jq`  | -        | JSON 処理              |
| `gh`  | git      | GitHub 操作 (PR/issue) |
| `fzf` | -        | あいまい選択           |

導入されていないツール (`eza` / `delta` / `sd` 等) は前提にしない。`command -v`
で存在を確認できないものはフォールバックする。
