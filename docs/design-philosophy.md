# 設計思想: nix-darwin + home-manager 一本化

このリポジトリは **nix-darwin + home-manager の二段構成**で運用している。
`~/` 配下の設定ファイルもすべて home-manager で declarative に配置するのが
現状の方針。

## TL;DR

新しい設定を追加するとき、置き場所の判断は次の 1 軸でほぼ決まる。

* nixpkgs に対応 module (`programs.<tool>`) があり、設定が複雑 → home-manager の
  `programs.*` で declarative に書く (例: starship / git / mise / markdownlint)
* それ以外 (raw text の dotfile を編集体験を保ったまま運用したい) → repo の
  `<tool>/` 配下に raw text を置き、`home.file.<path>.source` を
  `mkOutOfStoreSymlink` で symlink 配置する (例: zshrc / tmux.conf / vimrc /
  claude config / nvim / ctags / ghostty / mise/config.toml)

両者の決定的な違いは「編集してから反映までの操作」:

| 配置方式 | 反映操作 |
|---|---|
| `home.file` + `mkOutOfStoreSymlink` (out-of-store) | repo 内ファイルを編集 → 即反映 (`source ~/.zshrc` のような shell reload) |
| `home.file` + `text =` (in-store 生成) / `programs.<tool>.settings` | 編集 → `darwin-rebuild switch` で再反映 |

`mkOutOfStoreSymlink` を使う場合、`~/.zshrc` は repo 内ファイルへの symlink
になるので、`vim ~/.zshrc` を開けば repo を直接編集している状態になる。
chezmoi の `[edit] apply = true` 相当の編集体験を nix で実現できている。

## ディレクトリ構造

```
dotfiles/
├── flake.nix                      # darwinConfigurations.{work,personal,...}
├── flake.lock
├── nix/
│   ├── system.nix                 # macOS defaults / nix gc / SSL CA
│   ├── packages.nix               # Nix store CLI
│   ├── homebrew.nix               # GUI cask + tap-only / Apple-integrated formulae
│   ├── hosts/
│   │   ├── work.nix               # networking.hostName 強制 (per host)
│   │   └── personal.nix
│   └── home/
│       ├── default.nix            # imports + home.{stateVersion,username,homeDirectory}
│       └── programs/              # 1 ファイル 1 ツール
│           ├── zsh.nix            # ~/.zshrc symlink
│           ├── git.nix            # programs.git + ignores + includeIf
│           ├── tmux.nix           # ~/.tmux.conf, ~/.tmux_start_dir, ~/.local/bin/tmux-start
│           ├── vim.nix            # ~/.vimrc + サブディレクトリ symlink (plugged/ 除く)
│           ├── nvim.nix           # ~/.config/nvim/* (vim と coc-settings 共有)
│           ├── claude.nix         # ~/.claude/* (動的領域除く)
│           ├── codex.nix          # ~/.codex/* (config は text 生成、wrapper は symlink)
│           ├── apm.nix            # ~/.apm/* + home.activation.apmInstall hook
│           ├── mise.nix           # programs.mise + ~/.config/mise/config.toml + miseTrust hook
│           ├── markdownlint.nix   # ~/.markdownlint.jsonc symlink
│           ├── starship.nix       # programs.starship.settings
│           ├── ghostty.nix        # ~/Library/Application Support/com.mitchellh.ghostty/config
│           └── ctags.nix          # ~/.ctags.d/exclude.ctags
├── zsh/.zshrc
├── tmux/{.tmux.conf, .tmux_start_dir, bin/tmux-start}
├── vim/{.vimrc, .vim/{coc-settings.json, filetype.vim, autoload, colors, ftdetect, ftplugin}}
├── nvim/{init.vim, lua/telescope-config.lua}
├── claude/{CLAUDE.md, settings.json, mcp-servers.yaml, hooks/, rules/, skills/.gitignore, .env.example, setup-mcp.sh}
├── codex/{wrappers/gemini-mcp.sh, .env.example}
├── apm/{apm.yml, apm.lock.yaml, .gitignore}
├── mise/config.toml
├── markdownlint/.markdownlint.jsonc
├── ghostty/config
├── ctags/exclude.ctags
├── setup.sh                       # 初回 bootstrap
├── vscode/                        # VSCode は repo 直下に独立 (Nix 管理外)
└── docs/                          # 設計ドキュメント
```

## 三つの配置パターン

### A. out-of-store symlink (大半の dotfile)

`home.file."<path>".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/<tool>/<file>"` の形。
repo の絶対 path を user 変数 (`/Users/${user}/Documents/dev/dotfiles`) で構築し、
`~/<path>` から repo を直接 symlink する。

* **編集体験**: `vim ~/.zshrc` で repo 内ファイルを開いて編集 → `source ~/.zshrc` で即反映
* **darwin-rebuild 不要**: ファイルの中身変更だけなら symlink target の中身が変わるだけ
* **使い所**: zshrc / tmux.conf / vimrc / claude config / nvim / ghostty / etc.

### B. text 生成 (text =)

`home.file."<path>".text = ''...''`。home-manager が Nix store に実体ファイルを
焼き、`~/<path>` をそこへの symlink にする。

* **使い所**: Nix の `${user}` などで内容を user/host 別にレンダリングしたい場合 (例: codex
  `config.toml` の wrapper 絶対パス)
* **トレードオフ**: 編集には `nix/home/programs/<tool>.nix` の `text = ''...''` を書き換え
  → `darwin-rebuild switch` が必要

### C. declarative module (programs.\*)

`programs.<tool>.{enable, settings, ...}`。home-manager が module を解釈して
適切な path に出力する。

* **使い所**: nixpkgs に対応 module があり、設定構造を Nix の attrset で書く方が
  bracket / quote 地獄を避けられる場合 (starship / git / mise)
* **トレードオフ**: 同上 (`darwin-rebuild` 必要)。raw text と比較して編集即反映の
  cycle が遅い

## 動的領域の扱い

ツールが自走で書き換える領域 (Claude Code の `~/.claude/projects/`, codex の
`~/.codex/sessions/`, vim-plug の `~/.vim/plugged/`, apm の `~/.apm/apm_modules/`)
は **home.file 対象外**として ~/ 配下に普通の mutable directory として残す。
home-manager は配置に介入しない。

これにより:

* ツール側の自走書き換えと home-manager の symlink 配置が衝突しない
* `darwin-rebuild` 後にも user data が消えない
* repo に dynamic な内容が流入しない (= git status が綺麗)

## secrets 設計

repo は public 想定で運用しているため secrets を tracked file に置かない。
注入経路は 2 種類:

* **wrapper script + .env** (codex の `GEMINI_API_KEY`):
  `~/.codex/.env` (gitignore 不要 = repo 外配置) を user が手動配置し、
  wrapper (`codex/wrappers/gemini-mcp.sh`) が起動時に source して child process
  に env として inject する。
* **手書き includeIf 上書き** (work git identity):
  `~/.gitconfig.work` (repo 外、user 手書き) を `programs.git.includes` の
  `hasconfig:remote.*.url:` 条件で speee org の repo にだけ apply する。

両者とも repo に `.env.example` のみ tracked。新マシンでは copy + 値埋めの
手動 1 ステップ。将来 sops-nix / agenix で declarative にしたければ独立 task。

## ホスト別分岐

work / personal で `user` (macOS account name) と git identity (`gitName` /
`gitEmail`) が違うので、`flake.nix` の `hosts` attrset で 1 entry / host
として宣言:

```nix
hosts = {
  "work"     = { user = "hideaki.ishii"; gitName = "danimal141"; gitEmail = "..."; };
  "personal" = { user = "danimal141";    gitName = "danimal141"; gitEmail = "..."; };
};
```

`mkHost` がこれらを `specialArgs` 経由で全モジュール (system / home /
hosts/<hostname>.nix) に流す。マシン追加は 1 entry 足すだけ。

`networking.hostName` は `nix/hosts/<hostname>.nix` で強制 (IT 部門が払い出す
hostname を上書き)、`scutil --get LocalHostName` を flake host の真実源にする。

## activation hooks

home-manager の `home.activation.<name>` で apply 時に副作用を打てる。
現状 2 つ:

* `apmInstall` (apm.nix): `~/.apm/apm.yml` の sha256 を `~/.apm/.apm.yml.hash`
  に保存し、差分があるときだけ `apm install --target claude` を実行 (冪等)
* `miseTrust` (mise.nix): repo path の `mise/config.toml` を mise の trust
  store に登録 (out-of-store symlink で外部 path 扱いになる対策)

両者とも `pkgs.<tool>` で binary パスを直接呼ぶ (PATH 依存を避ける)。
apm は nix-darwin の `environment.systemPackages` 経由で居るので
`/run/current-system/sw/bin` への PATH export を追加している。
