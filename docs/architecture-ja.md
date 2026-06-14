# アーキテクチャリファレンス

[English](architecture.md) | 日本語

このリポジトリの「何がどこにあって、内部でどう繋がっているか」を引くための
リファレンス。設計思想 (なぜ declarative / 配置パターンの選択基準) は
[docs/design-philosophy-ja.md](design-philosophy-ja.md) 参照。

ディレクトリ構造の完全ツリーは
[design-philosophy-ja.md#ディレクトリ構造](design-philosophy-ja.md#ディレクトリ構造)
にある。本 doc は per-tool の内部構成を主に扱う。

## レイヤー責務 (要点)

* `flake.nix` — `darwinConfigurations.<host>` を `mkHost` で宣言。`hosts`
  attrset の各 entry に `user` (macOS account) / `gitName` / `gitEmail` を
  持ち、`mkHost` で `dotfilesPath = "/Users/${user}/Documents/dev/dotfiles"`
  を派生させて `specialArgs` 経由で全モジュールに流す (各 .nix で重複定義しない)
* `nix/darwin/` — nix-darwin (system 層)。`default.nix` が配下を一括 imports。
  flake.nix からは `./nix/darwin` 1 つを import するだけ
* `nix/home/` — home-manager (user 層)。`default.nix` が entry point、
  `programs/<tool>.nix` で 1 ファイル 1 ツール
* `tools/<tool>/` — `home.file` で symlink される raw text dotfile の置き場
* `setup.sh` — 初回 bootstrap (Xcode CLT → Nix → CA bundle → /etc 退避 →
  darwin-rebuild → mise install → LSP global → prek)

各モジュールが何を担当するか (system 層 6 ファイルの内訳 / home 層の
責務分担) は [README-ja.md#管理ツールの責務分担](../README-ja.md#管理ツールの責務分担)
を参照。

## `~/` 配置先

`home.file` 経由で home-manager が配置するもの:

* `.zshrc` `.tmux.conf` `.tmux_start_dir` `.markdownlint.jsonc` `.ctags.d/`
* `.config/{git,mise,nvim}/` (XDG)
* `.claude/` (CLAUDE.md / settings.json / hooks/ / rules/ /
  mcp-servers.json / skills/.gitignore + 動的領域 projects/ todos/
  shell-snapshots/ statsig/ ide/)
* `.codex/` (config.toml は pkgs.formats.toml 生成物を activation で mutable
  コピー / AGENTS.md → tools/codex/AGENTS.md (→ tools/claude/CLAUDE.md) symlink /
  skills/.gitignore + 動的領域 sessions/ log.json)
* `.apm/` (apm.yml / apm.lock.yaml / .gitignore + 動的領域 apm_modules/
  config.json / .claude/ / .github/)
* `.local/bin/tmux-start` (executable)
* `Library/Application Support/com.mitchellh.ghostty/config`
* `Library/Application Support/Code/User/{settings,keybindings}.json`

動的領域 (ツールが自走で書き換える dir) は home.file 対象外として ~/ 配下
の mutable directory として残す。詳細は
[design-philosophy-ja.md#動的領域の扱い](design-philosophy-ja.md#動的領域の扱い)。

## Neovim

* Plugin manager: lazy.nvim (`~/.local/share/nvim/lazy/` は home.file
  対象外、lazy.nvim 自走で書き換える領域)
* LSP / 補完: nvim-lspconfig (新 API `vim.lsp.config` + `vim.lsp.enable`)
  * nvim-cmp。Ruby は `Gemfile.lock` に `gem "ruby-lsp"` が含まれるかで
  `ruby_lsp` / `solargraph` を排他的に切替
  (`tools/nvim/lua/plugins/lsp.lua`)。各 server に `cmd` を明示して
  PATH 上に binary が無い場合は enable を skip
* Tree-sitter: nvim-treesitter (main branch、
  `tools/nvim/lua/plugins/treesitter.lua`)
* 配置: `nix/home/programs/nvim.nix` が `tools/nvim/` 全体を `~/.config/nvim`
  に 1 行で out-of-store symlink (plugin 実体は `~/.local/share/nvim/lazy/`
  に書かれるので repo は触られない)。`tools/nvim/lazy-lock.json` は tracked
  にして再現性を担保
* 構成: `tools/nvim/init.lua` から `lua/options.lua` `lua/mappings.lua`
  `lua/autocmds.lua` をロード、
  `lua/plugins/{editor,ui,cmp,lsp,format,treesitter,lang}.lua`
  が lazy.nvim spec、`after/ftplugin/<lang>.lua` が言語別 local 設定
* 社内 VPN の SSL inspection 対策: `tools/nvim/init.lua` 冒頭で
  `/etc/nix/ca-bundle.pem` を `GIT_SSL_CAINFO` / `CURL_CA_BUNDLE` /
  `SSL_CERT_FILE` に注入 (lazy.nvim の git clone と nvim-treesitter の
  curl parser ダウンロードを通すため)。deno LSP は `DENO_CERT` を別途要求

## Shell Environment

* Shell: Zsh + starship prompt (`programs.starship.settings` で declarative 管理)
* mise の zsh integration は無効化 (`enableZshIntegration = false`)、
  `tools/zsh/.zshrc` に `eval "$(mise activate zsh)"` を手書き 1 行
  (starship も同様)。これは zshrc を repo の raw text として symlink 配置
  している都合上、home-manager に zshrc 注入を許すと衝突するため

## Claude Code

* `tools/claude/skills/.gitignore` のみ tracked、APM が install する skill
  (chrome-cdp, codebase-analyzer, ...) は `~/.claude/skills/` 配下に展開され
  gitignore で ignore される (codex にも同一 skill が `~/.codex/skills/` に
  配布される。下記 Codex 参照)
* MCP server 設定は codex と共有する `tools/mcp/servers.json` を single source
  of truth とし、`tools/claude/setup-mcp.sh` を `cd tools/claude &&
  ./setup-mcp.sh` で実行して `~/.claude/mcp.json` に展開 (apply 時には自動
  実行されない)

APM の install hook / skill 取り込み手順は
[README-ja.md#claude-code-skills-via-apm](../README-ja.md#claude-code-skills-via-apm)
参照。

## Codex

* `~/.codex/config.toml` は `settings` (Nix attribute set) を
  `pkgs.formats.toml` で生成し、`codexConfig` activation hook が mutable な
  実ファイルとして毎回上書き配置する。codex 自身が起動時に `[projects]`
  trust を config.toml へ追記するため read-only symlink にはできない
  (書込が code -32603 で失敗する)。設定の編集後は `nix run .#switch` 必須
* MCP server は claude と共有する `tools/mcp/servers.json` を `codex.nix` が
  `builtins.fromJSON` で読み `mcp_servers` に展開する (single source of truth)。
  現状は `context7` / `terraform` のみ
* skill は `apm.nix` の `apm install --target claude,codex --global` で
  `~/.codex/skills/` にも配布される。`tools/codex/skills/.gitignore` のみ
  tracked で APM 産物を ignore する (claude と同パターン)
* `~/.codex/AGENTS.md` は `tools/codex/AGENTS.md` への out-of-store symlink。
  `tools/codex/AGENTS.md` 自体が `../claude/CLAUDE.md` への in-repo symlink な
  ので、claude と同じ system instruction を 1 ファイルで共有する

secrets 注入経路全体の設計は
[design-philosophy-ja.md#secrets-設計](design-philosophy-ja.md#secrets-設計)
と [README-ja.md#シークレット注入](../README-ja.md#シークレット注入) 参照。

## VSCode

`tools/vscode/` 配下の raw config を `nix/home/programs/vscode.nix` が
home-manager 経由で配置する。

* `settings.json` は `builtins.readFile + replaceStrings` で `${HOME}` を
  解決して `text =` で in-store 生成 (jsonc コメント保持)
* `keybindings.json` は out-of-store symlink (直接編集 → reload で即反映)
* extensions は `home.activation.vscodeExtensions` hook が `extensions.txt`
  と `code --list-extensions` の差分のみ install (冪等)

詳細運用 (sync.sh / UI 編集の取り込み / SSL inspection 対応) は
[docs/vscode-use-ja.md](vscode-use-ja.md) 参照。
