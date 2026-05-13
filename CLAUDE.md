# CLAUDE.md

このファイルは Claude Code (claude.ai/code) がこのリポジトリで作業する際の
ガイドです。

## Repository Overview

`nix-darwin` + `home-manager` で macOS の system / Homebrew / dotfile を
declarative に管理する dotfiles リポジトリ。`flake.nix` の
`darwinConfigurations.<host>` を `nix run .#switch` (内部で
`darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"`) で
適用する単一経路。

設計思想の詳細は `docs/design-philosophy.md` を参照。

## Essential Commands

### Setup and Installation

```bash
# 初回 bootstrap (新規 Mac)
./setup.sh                  # LocalHostName から flake host を自動判定
./setup.sh work             # work host を明示
./setup.sh personal         # personal host を明示

# 日常的な反映 (system 設定 / Homebrew / home-manager dotfile すべて 1 発)。
# `nix run .#switch` の wrapper 内で sudo + nom (interactive 時のみ) +
# hostname 自動解決をやってくれるので普段はこちらを推奨。素の
# `darwin-rebuild switch` 直叩きでも結果は同じ。
nix run .#switch                                                   # wrapper
darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"    # 素叩き

# build / update も同 wrapper 系列で揃える
nix run .#build      # apply せず dry-build (評価エラーや build 失敗の事前検出)
nix run .#update     # flake.lock 全 input を更新

# mise で global tool versions を実体 install (~/.config/mise/config.toml 参照)
mise install

# Claude MCP server を更新したいとき (apply 時には自動実行されない)
cd claude && ./setup-mcp.sh

# VSCode の UI 編集を repo に取り込む (extensions のみ、settings は手動同期)
cd tools/vscode && ./sync.sh --save
```

### Managing Dotfiles

新規 dotfile を追加するときの手順:

1. `tools/<tool>/` ディレクトリに raw file を置く
   (例: `tools/mytool/config.toml`)
2. `nix/home/programs/<tool>.nix` を作成し、`home.file."<path>".source` を
   `mkOutOfStoreSymlink "${dotfilesPath}/tools/<tool>/config.toml"` で配置
3. `nix/home/default.nix` の `imports` リストに `./programs/<tool>.nix` を追加
4. `nix run .#switch`

raw symlink でなく declarative module (`programs.<tool>.settings`) で書く方が
綺麗な場合 (型付きで pin したい)、step 2 を `programs.<tool>.{enable,settings}`
形式にする。判断軸は `docs/design-philosophy.md` 参照。

### Common Development Commands

このリポジトリ自体には特別な build / test コマンドはない。各言語ツールチェイン
を mise 経由で使う。

## Architecture

* `flake.nix` — `darwinConfigurations.<host>` を `mkHost` でホスト分宣言。
  `hosts` attrset の各 entry に `user` (macOS account) / `gitName` /
  `gitEmail` を持ち、`mkHost` で `dotfilesPath = "/Users/${user}/Documents/dev/dotfiles"`
  を派生させて `specialArgs` 経由で全モジュールに流す (各 .nix で重複定義しない)
* `nix/darwin/` — nix-darwin (system 層) のモジュール群。`default.nix` が
  配下を一括 imports。flake.nix からは `./nix/darwin` 1 つを import する
  だけで以下 6 ファイルが組み合わさる:
  * `macos-defaults.nix` — `system.defaults.*` (Dock / Finder / NSGlobalDomain /
    trackpad / WindowManager / menuExtraClock / CustomUserPreferences で
    Kotoeri / 言語等)
  * `keyboard.nix` — `system.keyboard` で CapsLock → Control の HID remap、
    再起動跨ぎの永続化のため `launchd.user.agents.remap-caps-lock` で login
    時に再適用、`system.activationScripts.postActivation` で
    `AppleSymbolicHotKeys` の入力ソース切替 shortcut (ID 60/61) のみ
    `defaults write -dict-add` で targeted update
  * `nix-daemon.nix` — `nix.settings` (experimental-features / trusted-users
    / 社内 VPN 用 SSL CA bundle) と `nix.gc`、daemon / shell に流す
    `environment.variables` (NIX_SSL_CERT_FILE / HOMEBREW_FORBIDDEN_FORMULAE)
  * `system.nix` — `system.primaryUser` / `users.users.<user>` /
    `programs.zsh.enable = false` / `system.stateVersion` の root residual
  * `packages.nix` — Nix store CLI (`environment.systemPackages`)
  * `homebrew.nix` — GUI cask + tap-only / Apple-integrated formulae
    (Brewfile で Nix declarative 対応外のもの)
* `nix/darwin/hosts/<hostname>.nix` — per-host overrides
  (`networking.hostName` 強制 + ホスト固有 brew package)
* `nix/home/default.nix` — home-manager の entry point (imports + home meta)
* `nix/home/programs/<tool>.nix` — 1 ファイル 1 ツールで分割
* `tools/<tool>/` — `home.file` で symlink される raw text dotfile の置き場
  (`tools/{zsh,tmux,nvim,claude,codex,apm,mise,markdownlint,ghostty,ctags,vscode}/`)
* `setup.sh` — 初回 bootstrap (Xcode CLT → Nix → CA bundle → /etc 退避 →
  darwin-rebuild → mise install → LSP global → prek)
* `tmux-migrate-options.py` — tmux deprecated option 移行 utility

主要 dotfile の `~/` 配置先:

* `.zshrc` `.tmux.conf` `.tmux_start_dir` `.markdownlint.jsonc` `.ctags.d/`
* `.config/{git,mise,nvim}/` (XDG)
* `.claude/` (CLAUDE.md / settings.json / hooks/ / rules/ / mcp-servers.yaml /
  skills/.gitignore + 動的領域 projects/ todos/ shell-snapshots/ statsig/ ide/)
* `.codex/` (config.toml は text 生成 / wrappers / AGENTS.md →
  tools/claude/CLAUDE.md symlink + 動的領域 sessions/ log.json)
* `.apm/` (apm.yml / apm.lock.yaml / .gitignore + 動的領域 apm_modules/
  config.json / .claude/ / .github/)
* `.local/bin/tmux-start` (executable)
* `Library/Application Support/com.mitchellh.ghostty/config`

## Development Notes

### Neovim

* Plugin manager: lazy.nvim (`~/.local/share/nvim/lazy/` は home.file
  対象外、lazy.nvim 自走で書き換える領域)
* LSP / 補完: nvim-lspconfig (新 API `vim.lsp.config` + `vim.lsp.enable`)
  * nvim-cmp。Ruby は `Gemfile.lock` に `gem "ruby-lsp"` が含まれるか
  で `ruby_lsp` / `solargraph` を排他的に切替 (`tools/nvim/lua/plugins/lsp.lua`)。
  各 server に `cmd` を明示して PATH 上に binary が無い場合は enable を skip
* Tree-sitter: nvim-treesitter (main branch、`tools/nvim/lua/plugins/treesitter.lua`)
* 配置: `nix/home/programs/nvim.nix` が `tools/nvim/` 全体を `~/.config/nvim`
  に 1 行で out-of-store symlink (plugin 実体は `~/.local/share/nvim/lazy/` に
  書かれるので repo は触られない)。`tools/nvim/lazy-lock.json` は tracked
  にして再現性を担保
* 構成: `tools/nvim/init.lua` から `lua/options.lua` `lua/mappings.lua`
  `lua/autocmds.lua` をロード、`lua/plugins/{editor,ui,cmp,lsp,format,treesitter,lang}.lua`
  が lazy.nvim spec、`after/ftplugin/<lang>.lua` が言語別 local 設定
* 社内 VPN の SSL inspection 対策: `tools/nvim/init.lua` 冒頭で
  `/etc/nix/ca-bundle.pem` を `GIT_SSL_CAINFO` / `CURL_CA_BUNDLE` /
  `SSL_CERT_FILE` に注入 (lazy.nvim の git clone と nvim-treesitter の
  curl parser ダウンロードを通すため)

### Shell Environment

* Shell: Zsh + starship prompt (`programs.starship.settings` で declarative 管理)
* mise の zsh integration は無効化 (`enableZshIntegration = false`)、
  `tools/zsh/.zshrc` に `eval "$(mise activate zsh)"` を手書き 1 行
  (starship も同様)。これは zshrc を repo の raw text として symlink 配置
  している都合上、home-manager に zshrc 注入を許すと衝突するため

### Claude Code

* `tools/claude/skills/.gitignore` のみ tracked、APM が install する skill
  (chrome-cdp, codebase-analyzer, ...) は `~/.claude/skills/` 配下に展開され
  gitignore で ignore される
* MCP server 設定は `tools/claude/mcp-servers.yaml` に手書き、
  `tools/claude/setup-mcp.sh` を `cd tools/claude && ./setup-mcp.sh` で実行
  して `~/.claude/mcp.json` に展開 (apply 時には自動実行されない)

### Codex

* `~/.codex/config.toml` は home-manager の `text =` で生成 (user 変数で
  wrapper 絶対パスを補完)。raw 編集即反映の体験は失うので、編集後は
  `nix run .#switch` 必須
* `GEMINI_API_KEY` は `~/.codex/.env` (gitignore 対象、user 手動配置) を
  wrapper (`tools/codex/wrappers/gemini-mcp.sh`) が起動時に source して
  `mcp-gemini-google-search` の env として inject
* `~/.codex/AGENTS.md` は `tools/claude/CLAUDE.md` への out-of-store symlink
  (両者で同じ system instruction を共有)

### APM

* `tools/apm/apm.yml` を編集 → `nix run .#switch` で `home.activation.apmInstall`
  hook が `~/.apm/apm.yml` の sha256 を比較し、差分があるときだけ
  `apm install --target claude` を発火 (冪等)。`~/.apm/.apm.yml.hash` で
  state 追跡

### secrets

repo は public 想定で運用しているため secrets を tracked file に置かない。
2 経路で注入:

* `~/.codex/.env` (codex `GEMINI_API_KEY`): `tools/codex/.env.example` を
  `cp ~/.codex/.env` で配置して値を埋める。wrapper が起動時に source
* `~/.gitconfig.local` + `~/.gitconfig.work` (work GitHub org の git
  identity): 2 ファイル合わせて条件分岐 + 上書き値を user 側で記述する。
  repo の `programs.git.includes` は `~/.gitconfig.local` を unconditional
  に include するだけで、所属 org 名は repo に出さない設計。詳細は README
  の「業務 git identity 上書き」セクション

将来 sops-nix / agenix で declarative にしたい場合は独立 task で。

### VSCode

`tools/vscode/` 配下に raw config を置き、`nix/home/programs/vscode.nix`
が home-manager 経由で配置・install する:

* `settings.json` は `tools/vscode/settings.jsonc` を `builtins.readFile +
  replaceStrings` で `${HOME}` を `/Users/${user}` に解決して `text =` で
  in-store 生成 (jsonc コメントは保持される)。編集は `tools/vscode/settings.jsonc`
  を直接、反映は `nix run .#switch` で再 eval
* `keybindings.json` は `tools/vscode/keybindings.jsonc` への out-of-store
  symlink。`vim ~/Library/Application\ Support/Code/User/keybindings.json`
  で repo 内ファイル直接編集 → VSCode reload (Cmd+R) で即反映
* extensions は `home.activation.vscodeExtensions` hook が
  `tools/vscode/extensions.txt` を読んで `code --list-extensions` 差分のみ
  `code --install-extension --force` する冪等動作。社内 VPN SSL inspection
  対策で `NODE_EXTRA_CA_CERTS=/etc/nix/ca-bundle.pem` を hook 内で export
* UI で extension を追加した時は `cd tools/vscode && ./sync.sh --save` で
  `extensions.txt` を実状態に sync して commit

## Documentation

* `docs/design-philosophy.md` — 設計思想 (nix-darwin + home-manager 一本化方針)
* `docs/vscode-use.md` / `docs/vscode-neovim-use.md` — VSCode 運用
* `README.md` — bootstrap / 日常運用 / 新マシン追加
