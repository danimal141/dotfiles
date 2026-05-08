# CLAUDE.md

このファイルは Claude Code (claude.ai/code) がこのリポジトリで作業する際の
ガイドです。

## Repository Overview

`nix-darwin` + `home-manager` で macOS の system / Homebrew / dotfile を
declarative に管理する dotfiles リポジトリ。`flake.nix` の
`darwinConfigurations.<host>` を `darwin-rebuild switch` で適用する単一経路。

設計思想の詳細は `docs/design-philosophy.md` を参照。

## Essential Commands

### Setup and Installation

```bash
# 初回 bootstrap (新規 Mac)
./setup.sh                  # LocalHostName から flake host を自動判定
./setup.sh work             # work host を明示
./setup.sh personal         # personal host を明示

# 日常的な反映 (system 設定 / Homebrew / home-manager dotfile すべて 1 発)
darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"

# mise で global tool versions を実体 install (~/.config/mise/config.toml 参照)
mise install

# Claude MCP server を更新したいとき (apply 時には自動実行されない)
cd claude && ./setup-mcp.sh

# VSCode の拡張 / 設定を sync
cd vscode && ./apply-settings.sh && ./sync-extensions.sh
```

### Managing Dotfiles

新規 dotfile を追加するときの手順:

1. `<tool>/` ディレクトリ (repo root) に raw file を置く
   (例: `mytool/config.toml`)
2. `nix/home/programs/<tool>.nix` を作成し、`home.file."<path>".source` を
   `mkOutOfStoreSymlink "${dotfilesPath}/<tool>/config.toml"` で配置
3. `nix/home/default.nix` の `imports` リストに `./programs/<tool>.nix` を追加
4. `darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"`

raw symlink でなく declarative module (`programs.<tool>.settings`) で書く方が
綺麗な場合 (型付きで pin したい)、step 2 を `programs.<tool>.{enable,settings}`
形式にする。判断軸は `docs/design-philosophy.md` 参照。

### Common Development Commands

このリポジトリ自体には特別な build / test コマンドはない。各言語ツールチェイン
を mise 経由で使う。

## Architecture

* `flake.nix` — `darwinConfigurations.<host>` を `mkHost` でホスト分宣言。
  `hosts` attrset の各 entry に `user` (macOS account) / `gitName` /
  `gitEmail` を持ち、`specialArgs` で全モジュールに流す
* `nix/system.nix` — macOS system defaults (Dock / Trackpad / KeyRepeat /
  primary user / nix gc / SSL CA bundle)
* `nix/packages.nix` — Nix store CLI (環境 systemPackages)
* `nix/homebrew.nix` — GUI cask + tap-only / Apple-integrated formulae
  (Brewfile で Nix declarative 対応外のもの)
* `nix/hosts/<hostname>.nix` — per-host overrides (`networking.hostName` 強制 +
  ホスト固有 brew package)
* `nix/home/default.nix` — home-manager の entry point (imports + home meta)
* `nix/home/programs/<tool>.nix` — 1 ファイル 1 ツールで分割
* `<tool>/` (repo root に複数) — `home.file` で symlink される raw text
  dotfile の置き場 (zsh / tmux / vim / nvim / claude / codex / apm / mise /
  markdownlint / ghostty / ctags)
* `setup.sh` — 初回 bootstrap (Xcode CLT → Nix → CA bundle → /etc 退避 →
  darwin-rebuild → mise install → LSP global → VSCode → prek)
* `vscode/` — repo root 直下に独立 (Nix 管理外、`apply-settings.sh` /
  `sync-extensions.sh` で運用)
* `tmux-migrate-options.py` — tmux deprecated option 移行 utility

主要 dotfile の `~/` 配置先:

* `.zshrc` `.tmux.conf` `.tmux_start_dir` `.vimrc` `.markdownlint.jsonc` `.ctags.d/`
* `.config/{git,mise,nvim}/` (XDG)
* `.claude/` (CLAUDE.md / settings.json / hooks/ / rules/ / mcp-servers.yaml /
  skills/.gitignore + 動的領域 projects/ todos/ shell-snapshots/ statsig/ ide/)
* `.codex/` (config.toml は text 生成 / wrappers / AGENTS.md → claude/CLAUDE.md
  symlink + 動的領域 sessions/ log.json)
* `.apm/` (apm.yml / apm.lock.yaml / .gitignore + 動的領域 apm_modules/
  config.json / .claude/ / .github/)
* `.local/bin/tmux-start` (executable)
* `Library/Application Support/com.mitchellh.ghostty/config`

## Development Notes

### Vim/Neovim

* Plugin manager: vim-plug (`~/.vim/plugged/` は home.file 対象外、vim-plug
  自走で書き換える領域)
* LSP: CoC (`~/.vim/coc-settings.json`)。nvim も同じ実体を共有 (`~/.config/
  nvim/coc-settings.json` は repo の `vim/.vim/coc-settings.json` への symlink)
* Lua plugin (telescope) は `nvim/lua/telescope-config.lua` で nvim 専用

### Shell Environment

* Shell: Zsh + starship prompt (`programs.starship.settings` で declarative 管理)
* mise の zsh integration は無効化 (`enableZshIntegration = false`)、`zsh/.zshrc`
  に `eval "$(mise activate zsh)"` を手書き 1 行 (starship も同様)。これは
  zshrc を repo の raw text として symlink 配置している都合上、home-manager
  に zshrc 注入を許すと衝突するため

### Claude Code

* `claude/skills/.gitignore` のみ tracked、APM が install する skill (chrome-cdp,
  codebase-analyzer, ...) は `~/.claude/skills/` 配下に展開され gitignore で
  ignore される
* MCP server 設定は `claude/mcp-servers.yaml` に手書き、`claude/setup-mcp.sh`
  を `cd claude && ./setup-mcp.sh` で実行して `~/.claude/mcp.json` に展開
  (apply 時には自動実行されない)

### Codex

* `~/.codex/config.toml` は home-manager の `text =` で生成 (user 変数で
  wrapper 絶対パスを補完)。raw 編集即反映の体験は失うので、編集後は
  `darwin-rebuild` 必須
* `GEMINI_API_KEY` は `~/.codex/.env` (gitignore 対象、user 手動配置) を
  wrapper (`codex/wrappers/gemini-mcp.sh`) が起動時に source して
  `mcp-gemini-google-search` の env として inject
* `~/.codex/AGENTS.md` は `claude/CLAUDE.md` への out-of-store symlink (両者で
  同じ system instruction を共有)

### APM

* `apm/apm.yml` を編集 → `darwin-rebuild switch` で `home.activation.apmInstall`
  hook が `~/.apm/apm.yml` の sha256 を比較し、差分があるときだけ
  `apm install --target claude` を発火 (冪等)。`~/.apm/.apm.yml.hash` で
  state 追跡

### secrets

repo は public 想定で運用しているため secrets を tracked file に置かない。
2 経路で注入:

* `~/.codex/.env` (codex `GEMINI_API_KEY`): `codex/.env.example` を
  `cp ~/.codex/.env` で配置して値を埋める。wrapper が起動時に source
* `~/.gitconfig.work` (work GitHub org の git identity): repo 外手書き、
  `programs.git.includes` の `hasconfig:remote.*.url:` 条件で speee org の
  repo にだけ apply

将来 sops-nix / agenix で declarative にしたい場合は独立 task で。

### VSCode

`vscode/` は repo root 直下に独立 (Nix 管理外)。`apply-settings.sh` /
`sync-extensions.sh` で運用。`extensions.txt` で拡張一覧を track。

## Documentation

* `docs/design-philosophy.md` — 設計思想 (nix-darwin + home-manager 一本化方針)
* `docs/vscode-use.md` / `docs/vscode-neovim-use.md` — VSCode 運用
* `README.md` — bootstrap / 日常運用 / 新マシン追加
