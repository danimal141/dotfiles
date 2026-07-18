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

* secrets は tracked file に置かない (`~/.gitconfig.local` /
  `~/.gitconfig.work` は user 側で配置)
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
* herdr の設定は `tools/herdr/config.toml` が source of truth
  (`~/.config/herdr/config.toml` へ symlink)。live reload されるので switch は
  不要 (`herdr server reload-config` か prefix+shift+r)。`herdr channel set` /
  `herdr config reset-keys` は config.toml を書き換えて repo を直接汚すので
  使わない。更新は `brew upgrade herdr` (herdr は Homebrew 管理下の binary を
  検出して self-update を拒否する)。なお `herdr config check` は TOML の構文しか
  見ず未知キーや不正な theme 名を検出しないため、キー追加時は
  `herdr --default-config` と突き合わせる
* herdr の agent-state 連携は `herdr integration install claude` / `... codex`
  の手動 bootstrap。Claude Code を全終了してから実行し、`git diff` で確認して
  即 commit する (起動中の Claude Code は settings.json を書き戻して外部追加の
  hook を落とす)。生成物は tools/claude/hooks/ と tools/codex/ に落ちて tracked
  になる。installer は絶対パスを書くので `$HOME` / `~` に正規化する (work と
  personal で user 名が違う)。追随は `herdr integration status`
* herdr server は `nix/darwin/herdr.nix` の `launchd.user.agents.herdr-server`
  で login 時常駐 (KeepAlive)。boot 直後に server が居らず初回 `herdr-start` が
  `detached from server` を出す問題への対処。`brew services start herdr` は
  併用禁止 (launchd plist が二重化し socket 衝突)。初回だけ既存 ad-hoc server を
  `herdr server stop` で止めてから `nix run .#switch` する
* Neovim の LSP は各 server に `cmd` を明示し、PATH 上に binary が無い
  場合は enable を skip する設計 (`tools/nvim/lua/plugins/lsp.lua`)
* セッション自動命名 hook (`tools/claude/hooks/session-namer.py` /
  `tools/codex/hooks/session-namer.py`) は Claude の transcript jsonl
  (`ai-title` レコード) と Codex の `~/.codex/state_N.sqlite`
  (`threads.title`) という内部フォーマットに依存する (公式 API 無し、
  fail-open)。ツール更新で命名されなくなったら書き込み先を再調査する。
  タイトル生成コマンドは env `SESSION_NAMER_CMD` で差し替え可能

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
