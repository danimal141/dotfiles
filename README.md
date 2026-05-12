# Dotfiles

`nix-darwin` + `home-manager` で macOS の system / Homebrew / dotfile を
declarative に管理する個人用 dotfiles。`nix run .#switch` (内部で
`darwin-rebuild switch --flake ".#<host>"`) の単一コマンドで反映する。

設計思想は [docs/design-philosophy.md](docs/design-philosophy.md) を参照。

## Requirements

* macOS (Apple Silicon, Sonoma 以降)
* [Nix + nix-darwin](https://github.com/nix-darwin/nix-darwin) — Homebrew /
  macOS 設定 / Nix store CLI / home-manager dotfile を一括 declarative 管理

## Get started

### 1. リポジトリを clone

clone 先は任意 (本リポジトリの module は repo の絶対 path を `/Users/<user>/
Documents/dev/dotfiles` に hardcode しているので、別 path に置く場合は
`nix/home/programs/*.nix` の `dotfilesPath` を書き換える):

```shell
git clone git@github.com:danimal141/dotfiles.git ~/Documents/dev/dotfiles
cd ~/Documents/dev/dotfiles
```

### 2. `setup.sh` を実行

```shell
./setup.sh             # LocalHostName から flake host を自動判定
./setup.sh work        # 仕事用 Mac として明示
./setup.sh personal    # 個人用 Mac として明示
```

`setup.sh` がやること:

1. Xcode CLT インストール (Apple Silicon 専用、Rosetta は入れない)
2. Nix 公式 upstream installer 実行 (既に入っていれば skip)
3. macOS Keychain から CA bundle を `/etc/nix/ca-bundle.pem` に焼き、`launchctl
   setenv` で nix-daemon に渡す (社内 VPN の SSL inspection 対策、個人 Mac
   でも害はない)
4. Nix 公式 installer が書いた `/etc/bashrc` `/etc/nix/nix.conf` を
   `*.before-nix-darwin` に退避 (nix-darwin の activation が「unrecognized
   content」を理由に abort するのを回避)
5. `sudo -E nix run nix-darwin -- switch --flake ".#<hostname>"` を実行 —
   `nix/darwin/{defaults,keyboard,nix-daemon,system,packages,homebrew}.nix`
   (system 層 / Nix store CLI / brew / cask) / `nix/home/programs/*.nix`
   (home-manager 経由の dotfile symlink + VSCode settings/keybindings/extensions
   含む) が一括反映
6. `mise install` で `~/.config/mise/config.toml` の言語 binary を実体 install
7. LSP server (typescript / pyright / ruby-lsp / gopls) を global install
8. `prek install` で `.git/hooks/pre-commit` を冪等に仕込む (secretlint hook)
9. `exec $SHELL -l` で新 shell に切り替え

完走後は `which git` が `/etc/profiles/per-user/<user>/bin/git` または
`/run/current-system/sw/bin/git` を返す状態になる。

### 3. シークレット注入

repo に secrets を tracked しない方針。注入経路は 2 つ:

#### codex (`GEMINI_API_KEY`)

`~/.codex/.env` を user 手動配置:

```shell
cp tools/codex/.env.example ~/.codex/.env
chmod 600 ~/.codex/.env
$EDITOR ~/.codex/.env       # GEMINI_API_KEY=... を埋める
```

`tools/codex/wrappers/gemini-mcp.sh` (= `~/.codex/wrappers/gemini-mcp.sh` への
symlink) が起動時に `.env` を source して `mcp-gemini-google-search` の
env として inject する。

#### work GitHub org の git identity (任意)

業務用の identity 上書きは **2 つの user 手書きファイル**で実現する。
所属組織名や業務メールが public repo に出ないよう、条件分岐 (どの remote
URL で identity を切り替えるか) と上書き値 (name / email) の両方を user
側に逃がす設計。

repo の `programs.git.includes` は `~/.gitconfig.local` を unconditional
に include するだけ (中身は何も知らない)。実際の条件分岐は
`~/.gitconfig.local` 内の `[includeIf "..."]` で user が記述し、その
include 先の `~/.gitconfig.work` に identity を書く、という二段構成。

| ファイル | 役割 | 中身 |
|---|---|---|
| `~/.gitconfig.local` | dispatcher: どの remote URL pattern で work identity に切り替えるかを宣言 | `[includeIf "hasconfig:remote.*.url:git@github.com:<your-org>/**"]` ブロック |
| `~/.gitconfig.work` | overrides: 切り替え後に適用する name / email | `[user] name = ... / email = ...` |

両者とも repo / git どちらでも追跡しない (= 個人 Mac には作らない、
work Mac でだけ存在する手書きファイル)。

##### work Mac でのセットアップ

```shell
# 1. dispatcher を作成 (org pattern を 1 行に書く)
$ cat > ~/.gitconfig.local <<'EOF'
[includeIf "hasconfig:remote.*.url:git@github.com:<your-org>/**"]
    path = ~/.gitconfig.work
[includeIf "hasconfig:remote.*.url:https://github.com/<your-org>/**"]
    path = ~/.gitconfig.work
EOF
$ chmod 600 ~/.gitconfig.local

# 2. overrides を作成 (work identity の値)
$ cat > ~/.gitconfig.work <<'EOF'
[user]
    name  = Your Work Name
    email = you@example.com
EOF
$ chmod 600 ~/.gitconfig.work
```

`<your-org>` を実際の GitHub org 名に置換、`Your Work Name` /
`you@example.com` を業務 ID に置換する。

##### 動作確認

```shell
cd <work org の repo の clone>
git config user.email   # → 業務アドレス (.gitconfig.local + .gitconfig.work 配置済みなら)
cd <この dotfiles repo>
git config user.email   # → 個人アドレス (flake.nix で宣言)
```

### 4. pre-commit + secretlint

API key の誤コミット防止に secretlint が pre-commit hook に組み込まれている。
`prek` (pre-commit の Rust 実装、drop-in 互換) を `nix/darwin/packages.nix` で配布、
`setup.sh` の最後で `prek install` が自動実行される。手動再 install:

```shell
prek install              # .git/hooks/pre-commit 設置
prek run --all-files      # 既存ファイルを 1 度走査 (任意)
```

secretlint 本体と rule preset は `package.json` / `package-lock.json` で
pin、`setup.sh` の `npm ci` で `node_modules/` に install され、hook は
`npx secretlint` でこれを参照する。

### 困ったとき

* **Nix の SSL エラー (`self-signed certificate in certificate chain`)** —
  `setup.sh` の手順 3 が走っているか (`/etc/nix/ca-bundle.pem` が 100KB
  以上ある) を確認。社内 IT が新しい CA を Keychain に push した直後は
  bundle 再生成 (`sudo bash -c "security find-certificate -a -p
  /Library/Keychains/System.keychain >> /etc/nix/ca-bundle.pem ..." && sudo
  launchctl kickstart -k system/org.nixos.nix-daemon`)
* **`darwin-rebuild` が「unrecognized content in /etc/...」で止まる** —
  該当ファイルを `.before-nix-darwin` に退避してから再実行
* **`darwin-rebuild` の Homebrew step で formula / cask 名解決失敗** —
  上流で改名 / cask 化されたものは `nix/darwin/homebrew.nix` を更新
* **業務 repo で `git config user.email` が個人 ID のまま** —
  `~/.gitconfig.local` または `~/.gitconfig.work` 未作成か、remote URL が
  `~/.gitconfig.local` 内の `hasconfig:remote.*.url:` 条件にマッチしていない。
  `git remote -v` で URL を確認し、`.gitconfig.local` の pattern に該当 org
  が入っているか、`.gitconfig.work` が存在するかをチェック

## 日常運用

### nix-darwin (system / Homebrew / dotfile すべて 1 発)

| 操作 | コマンド |
|---|---|
| 設定変更を反映 (system / brew / home-manager すべて) | `nix run .#switch` |
| 反映前に build だけ走らせて検証 | `nix run .#build` |
| `flake.lock` の全 input を更新 | `nix run .#update` |
| Nix store CLI を追加 / 削除 | `nix/darwin/packages.nix` を編集 → 上記 switch |
| Homebrew brew / cask を追加 / 削除 | `nix/darwin/homebrew.nix` を編集 → 上記 switch |
| macOS 設定変更 (Dock / Finder / NSGlobalDomain 等) | `nix/darwin/macos-defaults.nix` を編集 → 上記 switch |
| キーボード remap / 入力ソース shortcut 変更 | `nix/darwin/keyboard.nix` を編集 → 上記 switch |
| Nix daemon / GC / SSL CA bundle / 環境変数 | `nix/darwin/nix-daemon.nix` を編集 → 上記 switch |
| user 層の dotfile / `programs.*` 変更 | `nix/home/programs/<tool>.nix` を編集 → 上記 switch (raw text symlink なら switch 不要、編集即反映) |
| flake input を個別更新 | `nix flake update <input>` (例: `nixpkgs` / `nix-darwin` / `nix-homebrew` / `home-manager`) |
| 世代一覧 | `darwin-rebuild --list-generations` |
| 前世代に戻す | `darwin-rebuild --rollback` |

`nix run .#<app>` は flake.nix の `apps.aarch64-darwin.*` にある shell
wrapper で、内部的には `darwin-rebuild switch --flake ".#$(scutil --get
LocalHostName)"` を呼ぶ (= 素の `darwin-rebuild` を直接打っても等価)。
wrapper の付加価値は次の 3 点:

* `scutil --get LocalHostName` 経由で host を自動解決 (`work` / `personal`
  を 1 コマンドで兼ねる)
* TTY 実行時のみ `nix-output-monitor` (nom) で進捗を整形、AI agent
  (`CLAUDECODE` / `CODEX_SANDBOX` 等の env 検出) では生 output に切替
* `darwin-rebuild` は flake input から絶対 path で解決するので、
  `/run/current-system/sw/bin/...` が未整備の初回 bootstrap でも動く

`nix/darwin/homebrew.nix` で Homebrew 側に残している主な理由:

* tap-only formulae (argoproj/tap/argocd, fujiwara/tap/tfstate-lookup,
  kayac/tap/ecspresso, mutagen-io/mutagen/mutagen-compose 等)
* Apple / macOS 統合が brew の方が確実 (basictex, ffmpeg, imagemagick, llvm, mas)
* Node / Python ランタイム前提の CLI (markdownlint-cli, marp-cli, repomix, pipx)
* macOS-only ツール (terminal-notifier, im-select)
* shell 本体と plugin (zsh / zsh-autosuggestions / zsh-syntax-highlighting /
  zsh-completions) — brew の方が startup が速い

注意:

* `nix run .#update` (= `nix flake update` 全 input 一括) は壊れた時の
  切り分けが困難。問題発生時は個別 input 名指定 (`nix flake update <input>`)
  に切り替える
* nixpkgs 追従ラグで `darwin-rebuild` が一時的に壊れることがある。動かなく
  なったら `--rollback` で前世代に戻し、`flake.lock` を git で前状態に
  巻き戻して再 switch

### Dotfile を編集 / 追加する

raw text symlink で配置されている dotfile (zsh / tmux / vim / nvim / claude /
ghostty / ctags / mise の config.toml / markdownlint) は **`vim ~/.zshrc`
で repo 内ファイルを直接編集** することになる:

```shell
$ readlink ~/.zshrc
# → /Users/<user>/Documents/dev/dotfiles/tools/zsh/.zshrc (3-step chain で repo 到達)
$ vim ~/.zshrc            # ← repo の tools/zsh/.zshrc を編集している
$ source ~/.zshrc         # 即反映 (nix run .#switch 不要)
```

text 生成 / `programs.<tool>.settings` で配置されているもの (codex の
config.toml / git / starship 等) は `nix/home/programs/<tool>.nix` を編集 →
`nix run .#switch` で反映。

新規 dotfile を追加する場合は CLAUDE.md の「Managing Dotfiles」を参照。

### mise (language runtime)

global の宣言ソースは `~/.config/mise/config.toml` (= home-manager で repo
の `tools/mise/config.toml` に out-of-store symlink される)。プロジェクト
個別の宣言は `<project>/mise.toml` または `<project>/.tool-versions`
(asdf 互換) で上書き可能。

mise の解決優先度 (上ほど優先):

1. `<project>/mise.toml` | `<project>/.mise.toml`
2. `<project>/.tool-versions`
3. `~/.config/mise/config.toml` (= home-manager 経由 global)

| 操作 | コマンド |
|---|---|
| 宣言済みランタイムをまとめて install | `mise install` |
| プロジェクトに個別バージョンを fix | `mise use ruby@3.4 --pin` |
| global バージョン更新 | `tools/mise/config.toml` を直接編集 (= `vim ~/.config/mise/config.toml`) |
| LSP 等のシム再生成 | `mise reshim` |
| 利用可能バージョン一覧 | `mise ls-remote ruby` |

注意:

* `mise use -g <pkg>` は repo の `tools/mise/config.toml` を直接書き換えるので、
  そのまま `git diff` で変更が見える。気が向いたら commit すれば全 Mac で
  共有される
* mise は activate 時に PATH 先頭にシムを差し込むので、`zshrc` の
  `mise activate zsh` は path-helper や Nix 側ランタイムの **後ろ** に置く

## 新しい Mac を追加する場合

hostname 規約: 仕事用は `work`、個人用は `personal` / `personal2` / ... と
連番。`nix/darwin/hosts/<hostname>.nix` の `networking.hostName` で apply 時に
LocalHostName / HostName が固定されるので、IT 部門が割り当てた元の hostname
は上書きされる。

### 1. `flake.nix` の `hosts` attrset に entry 追加

```nix
hosts = {
  "work"      = { user = "hideaki.ishii"; gitName = "danimal141"; gitEmail = "..."; };
  "personal"  = { user = "danimal141";    gitName = "danimal141"; gitEmail = "..."; };
  "personal2" = { user = "danimal141";    gitName = "danimal141"; gitEmail = "..."; };  # ← 追加
};
```

### 2. `nix/darwin/hosts/<hostname>.nix` を作成 (`work.nix` を雛形に)

```nix
{ ... }:
{
  networking.hostName = "personal2";
  # この host 専用の brew/cask があればここに
}
```

### 3. 変更を commit & push

### 4. 新 Mac でセットアップ実行

```shell
./setup.sh personal2     # ← 第 1 引数で flake host を必ず明示
```

初回は IT 部門が割り当てた元の hostname のままなので `scutil --get
LocalHostName` では新 host を検出できず `setup.sh` は `work` にフォール
バックする。**個人 Mac で引数を忘れると `work` 構成で switch される**ので
第 1 引数で必ず明示する。`darwin-rebuild` 完走後は LocalHostName が
`<hostname>` に書き換わるので、二度目以降は `./setup.sh` 引数なしで動作する。

## 管理ツールの責務分担

* nix-darwin (system 層、`flake.lock` で pin、`nix/darwin/` 配下に集約):
  * `nix/darwin/packages.nix` — Nix store 供給の CLI バイナリ (git / tmux /
    neovim / fzf / ripgrep / jq / gh / kubectl 系 / apm など)
  * `nix/darwin/homebrew.nix` — tap-only formulae / GUI cask / macOS 統合
    の強い formulae
  * `nix/darwin/macos-defaults.nix` — `system.defaults.*` (Dock / Finder /
    NSGlobalDomain (KeyRepeat / 自動補完 OFF 等) / trackpad / WindowManager
    / menuExtraClock / CustomUserPreferences で Kotoeri / 言語等)
  * `nix/darwin/keyboard.nix` — `system.keyboard` で CapsLock → Control の
    HID remap、`launchd.user.agents.remap-caps-lock` で再起動跨ぎの login
    時再適用、`system.activationScripts.postActivation` で入力ソース切替
    shortcut (`AppleSymbolicHotKeys` の ID 60/61) の targeted update
  * `nix/darwin/nix-daemon.nix` — `nix.settings` (experimental-features /
    trusted-users / SSL CA bundle) と `nix.gc`、`environment.variables`
    (NIX_SSL_CERT_FILE / HOMEBREW_FORBIDDEN_FORMULAE)
  * `nix/darwin/system.nix` — `system.primaryUser` / `users.users.<user>` /
    `programs.zsh.enable = false` / `system.stateVersion` の root residual
  * `nix/darwin/default.nix` — 上記 6 ファイルを 1 つにまとめる imports。
    flake.nix は `./nix/darwin` を 1 つ import するだけで揃う
  * `nix/darwin/hosts/<hostname>.nix` — host 別 override
    (`networking.hostName` 強制 + ホスト固有 brew package)
* home-manager (user 層、nix-darwin module 統合):
  * `nix/home/programs/<tool>.nix` — 1 ファイル 1 ツールで分割。raw text
    symlink (`mkOutOfStoreSymlink`) または declarative module
    (`programs.<tool>.settings`) のいずれかで `~/` 配下を配置
  * バイナリは `/etc/profiles/per-user/$USER/bin/` に展開される
* mise (言語ランタイム):
  * 宣言ソースは `~/.config/mise/config.toml` (= home-manager 経由 = repo の
    `tools/mise/config.toml`)。`mise install` が読んで実体を `~/.local/share/mise/
    installs/` に展開
* repo 管理外 (動的領域 / secrets):
  * `~/.claude/{projects,todos,shell-snapshots,statsig,ide}/` (Claude Code
    動的領域)
  * `~/.codex/{sessions,log.json}` (codex 動的領域)
  * `~/.apm/{apm_modules,config.json,.claude,.github}` (APM 動的領域)
  * `~/.vim/{plugged,sessions,.netrwhist}` (vim-plug 動的領域)
  * `~/.local/share/nvim/{lazy,site/parser}/` (lazy.nvim と nvim-treesitter 動的領域)
  * `~/.codex/.env`, `~/.gitconfig.local`, `~/.gitconfig.work` (secrets / org 名、user 手書き)

PATH 解決順 (`tools/zsh/.zshrc`):

1. `/etc/profiles/per-user/$USER/{bin,sbin}` — home-manager のユーザプロファイル
2. `/run/current-system/sw/{bin,sbin}` — nix-darwin の system プロファイル
3. `/opt/homebrew/{bin,sbin}` — Homebrew (Nix 移行外の formulae / cask)
4. `$HOME/bin`, `$HOME/.local/bin`
5. mise activate がこの後で言語ランタイム shim を PATH 先頭に差し込む

home-manager の user プロファイルを system プロファイルより前に置くのは、
同名バイナリで home-manager 側 (= flake.lock pin) を勝たせるため。

## Claude Code skills via APM

Claude Code のスキル群は [skilltree](https://github.com/danimal141/skilltree)
にまとめ、[APM (Agent Package Manager)](https://github.com/microsoft/apm)
経由で取り込む。

`nix run .#switch` 時に `home.activation.apmInstall` hook が `~/.apm/
apm.yml` の sha256 を比較し、差分があるときだけ `apm install --target
claude` を発火する (冪等)。手動で再実行する場合:

```shell
cd ~/.apm
apm install --target claude
```

依存スキルを追加・削除する場合は `tools/apm/apm.yml` (repo 内、= `~/.apm/apm.yml`
への symlink 元) を編集して `nix run .#switch`。
