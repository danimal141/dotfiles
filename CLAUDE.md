# CLAUDE.md

このファイルは Claude Code (claude.ai/code) がこのリポジトリで作業する
際のガイドです。

## Repository Overview

`nix-darwin` + `home-manager` で macOS の system / Homebrew / dotfile を
declarative に管理する dotfiles リポジトリ。`nix run .#switch` (内部で
`darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"`) で
適用する単一経路。

## 新規 dotfile 追加手順

1. `tools/<tool>/` に raw file を置く
2. `nix/home/programs/<tool>.nix` を作成し、`home.file."<path>".source` を
   `mkOutOfStoreSymlink "${dotfilesPath}/tools/<tool>/..."` で配置
3. `nix/home/default.nix` の `imports` に追加
4. `nix run .#switch`

raw symlink vs declarative module (`programs.<tool>.{enable,settings}`)
の判断軸は [docs/design-philosophy-ja.md](docs/design-philosophy-ja.md)
参照。

## 作業時の注意点

* secrets は tracked file に置かない (`~/.codex/.env` /
  `~/.gitconfig.local` / `~/.gitconfig.work` は user 側で配置)
* `tools/zsh/.zshrc` は raw text symlink。home-manager の zshrc 注入を
  有効化すると衝突する
* `tools/nvim/lazy-lock.json` は tracked にして再現性を担保
* MCP server 設定変更は `cd tools/claude && ./setup-mcp.sh` を手動実行
  (`nix run .#switch` 時には自動実行されない)
* Google IME の keymap は `tools/google-ime/keymap.tsv` (Kotoeri preset) を
  source of truth とし `~/.config/google-ime/keymap.tsv` に symlink される。
  反映は Google IME 環境設定 → 一般 → キー設定の選択 → カスタム → 編集 →
  インポート で同 path を 1 度指定する手動 bootstrap が必要 (mozc は
  config1.db = binary protobuf に keymap を畳み込むため watch path 無し)
* `tools/apm/apm.yml` を編集したら `nix run .#switch` で sha256 比較
  hook が発火 (冪等)
* Neovim の LSP は各 server に `cmd` を明示し、PATH 上に binary が無い
  場合は enable を skip する設計 (`tools/nvim/lua/plugins/lsp.lua`)

## ドキュメント

* [README-ja.md](README-ja.md) — bootstrap / 日常運用 / コマンド /
  secrets / APM
* [docs/architecture-ja.md](docs/architecture-ja.md) — ファイル構造 /
  モジュール責務 / per-tool 内部構成
* [docs/design-philosophy-ja.md](docs/design-philosophy-ja.md) — 設計
  思想 / 配置パターン / activation メカニクス
* [docs/vscode-use-ja.md](docs/vscode-use-ja.md) /
  [docs/vscode-neovim-use-ja.md](docs/vscode-neovim-use-ja.md) — VSCode 運用

各 doc は英語版 (`<name>.md`) と日本語版 (`<name>-ja.md`) を並走させて
いるが、日本語版を読めば十分。
