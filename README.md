# Dotfiles

## Requirements

* [Nix + nix-darwin](https://github.com/nix-darwin/nix-darwin) — Homebrew / macOS 設定 / Nix store CLI の declarative 管理
* [chezmoi](https://github.com/twpayne/chezmoi) — dotfile 管理 + テンプレート

## Get started

### 1. リポジトリを clone

clone 先は任意。

```shell
$ git clone git@github.com:danimal141/dotfiles.git ~/dev/dotfiles
$ cd ~/dev/dotfiles
```

### 2. `setup.sh` を実行

```shell
$ ./setup.sh             # LocalHostName から flake host を自動判定
$ ./setup.sh work        # 仕事用 Mac として明示
$ ./setup.sh personal2   # 個人 2 台目として明示
```

`setup.sh` がやること:

1. Xcode CLT インストール (Apple Silicon 専用想定なので Rosetta は入れない)
2. Nix 公式 upstream installer 実行 (既に入っていれば skip)
3. macOS Keychain から CA bundle を `/etc/nix/ca-bundle.pem` に焼き、`launchctl setenv` で nix-daemon に渡す (社内 VPN の SSL inspection 対策、個人 Mac でも害はない)
4. Nix 公式 installer が書いた `/etc/bashrc` `/etc/nix/nix.conf` を `*.before-nix-darwin` に退避 (nix-darwin の activation が「unrecognized content」を理由に abort するのを回避)
5. `sudo -E nix --extra-experimental-features 'nix-command flakes' run nix-darwin -- switch --flake ".#<hostname>"` を実行 — `nix/packages.nix` (Nix store CLI) / `nix/homebrew.nix` (brew/cask) / `nix/system.nix` (macOS 設定) が一括反映
6. `chezmoi init --apply --source "$(pwd)"` で dotfile を `~/` に展開
7. `mise install` で global ランタイムを install (`~/.config/mise/config.toml` 主、`~/.tool-versions` は legacy fallback)
8. LSP server / VSCode 拡張のセットアップ
9. `prek install` で `.git/hooks/pre-commit` を冪等に仕込む (`.pre-commit-config.yaml` がある時のみ)
10. `exec $SHELL -l` で新 shell に切り替え (PATH と chezmoi の dotfile を反映)

完走後は `which git` が `/run/current-system/sw/bin/git` を返す状態になる。

### 3. シークレット注入

`chezmoi/dot_codex/config.toml.tmpl` などで API key を `{{ env "GEMINI_API_KEY" }}` 形式で読む。1Password CLI を使う場合は `op signin` 後にテンプレを `{{ (onepasswordRead "op://Personal/...") }}` に書き換える。

age 経路を使う場合は鍵を `~/.config/age/key.txt` に置いて、`encrypted_` プレフィックス付きの chezmoi ファイルで運ぶ。

### 4. pre-commit + secretlint

API key の誤コミットを防ぐため secretlint が pre-commit hook に組み込まれている。`prek` (pre-commit の Rust 実装、drop-in 互換) を `nix/packages.nix` で配布しており、`setup.sh` の最後で `prek install` が自動実行される。手動で再 install する場合:

```shell
$ cd <repo>
$ prek install              # .git/hooks/pre-commit 設置
$ prek run --all-files      # 既存ファイルを 1 度走査 (任意)
```

secretlint 本体は hook 内の `npx -y secretlint` で初回実行時に自動 download される (= `npm install` 不要)。

### 5. 業務 repo の git identity 上書き (optional)

`~/.gitconfig` (chezmoi 管理) は `chezmoi/.chezmoi.toml.tmpl` の `[data] name` / `email` を `dot_gitconfig.tmpl` で `[user]` に流し込む。当面は work / personal どちらでも `danimal141 / hideaki.ishii1204@gmail.com` を共通で使う前提。

将来、業務 GitHub org (`speee`) の repo でだけ別 ID を使いたくなった場合のために、`hasconfig:remote.*.url:` を使った optional な上書き経路だけ仕込んでおく (yxtay/dotfiles の発想)。clone path に依存せず、業務 org の remote URL を持つ repo に対してのみ発火する:

```gitconfig
[includeIf "hasconfig:remote.*.url:git@github.com:speee/**"]
    path = ~/.gitconfig.work
[includeIf "hasconfig:remote.*.url:https://github.com/speee/**"]
    path = ~/.gitconfig.work
```

業務 ID で commit したくなったら、各 work Mac で `~/.gitconfig.work` を手書き作成する:

```shell
$ cat > ~/.gitconfig.work <<'EOF'
[user]
    name  = Your Work Name
    email = you@example.com
EOF
$ chmod 600 ~/.gitconfig.work
```

`~/.gitconfig.work` は chezmoi / git どちらでも追跡しない手書きファイル (public repo に業務メールを焼かない意図)。`Your Work Name` / `you@example.com` は placeholder なので各 work Mac で自分の業務 ID に書き換える。確認:

```shell
$ cd <speee org の clone>
$ git config user.email   # → 業務アドレスが出れば OK (~/.gitconfig.work 未作成なら個人アドレス)
$ cd <この dotfiles repo の clone>
$ git config user.email   # → 個人アドレス (hideaki.ishii1204@gmail.com)
```

### 困ったとき

* **Nix の SSL エラー (`self-signed certificate in certificate chain`)** — `setup.sh` の手順 3 が走り終わっているか (`/etc/nix/ca-bundle.pem` が 100KB 以上ある) を確認。社内 IT が新しい CA を Keychain に push した直後は bundle を再生成 (`sudo bash -c "security find-certificate ..." && sudo launchctl kickstart -k system/org.nixos.nix-daemon`)。
* **`darwin-rebuild` が「unrecognized content in /etc/...」で止まる** — そのファイルを `.before-nix-darwin` に退避してから再実行。
* **`darwin-rebuild` の Homebrew step で formula / cask 名解決に失敗** — 上流で改名 / cask 化されたものは `nix/homebrew.nix` を更新して PR。
* **業務 repo で `git config user.email` が個人 ID のまま** — `~/.gitconfig.work` が未作成 (= 当面は個人 ID 共用が既定) か、remote URL が `github.com:speee/...` 以外で `hasconfig:` の条件にマッチしていない。`git remote -v` と `~/.gitconfig.work` の存在を確認。

## 日常運用

### nix-darwin (Nix store CLI + Homebrew + macOS 設定)

CLI ツールバイナリは Nixpkgs から供給する `nix/packages.nix` と、
GUI cask や Apple 統合が必要な formulae を運ぶ `nix/homebrew.nix` の二段構え。

| 操作 | コマンド |
|---|---|
| Nix store の CLI を追加 / 削除 | `nix/packages.nix` を編集 → `darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"` |
| Homebrew 経由の brew / cask を追加 / 削除 | `nix/homebrew.nix` を編集 → 同上 |
| macOS 設定変更 | `nix/system.nix` を編集 → 同上 |
| 入力を個別更新 | `nix flake lock --update-input nixpkgs` (or `nix-darwin` / `nix-homebrew` / `llm-agents`) |
| 世代一覧 | `darwin-rebuild --list-generations` |
| 前世代に戻す | `darwin-rebuild --rollback` |

`nix/homebrew.nix` で Homebrew 側に残している主な理由:

* shell bootstrap binaries (chezmoi, mise) — `darwin-rebuild` の前段階で必要
* tap-only formulae (argoproj/tap/argocd, fujiwara/tap/tfstate-lookup, kayac/tap/ecspresso, mutagen-io/mutagen/mutagen-compose, yukiarrr/tap/ecsk, daipeihust/tap など)
* Apple / macOS 統合が brew の方が確実 (basictex, ffmpeg, imagemagick, llvm, mas)
* Node / Python ランタイム前提 (markdownlint-cli, marp-cli, repomix, pipx)
* macOS-only ツール (terminal-notifier, im-select)
* shell 本体と plugin (zsh / zsh-autosuggestions / zsh-syntax-highlighting / zsh-completions) — brew の方が startup が速い

実際の formula / cask 一覧は `nix/homebrew.nix` の `brews` / `casks` を参照。

APM (`microsoft/apm/apm`) は [`numtide/llm-agents.nix`](https://github.com/numtide/llm-agents.nix) flake 経由で Nix store 供給に切り替え済み。

注意:

* `nix flake update` (全 input 更新) は壊れた時の切り分けが困難。個別に `--update-input` で進める
* nixpkgs 追従ラグで `darwin-rebuild` が一時的に壊れることがある。動かなくなったら `--rollback` で前世代に戻し、`flake.lock` を git で前状態に巻き戻して再 switch
* GUI アプリの単独設定 (1Password / Raycast / Karabiner 等) は標準モジュール対象外。必要なら `system.defaults.CustomUserPreferences` か chezmoi 側 `defaults write` で対応

### chezmoi (dotfile)

| 操作 | コマンド |
|---|---|
| dotfile を編集 (apply 即時反映) | `chezmoi edit ~/.zshrc` |
| 変更予定を確認 | `chezmoi diff` |
| 適用 | `chezmoi apply` |
| 整合性チェック | `chezmoi verify` |
| ホームディレクトリの変更を取り込む | `chezmoi re-add ~/.zshrc` |

### mise (language runtime)

asdf を置き換えた言語ランタイム管理。global の宣言ソースは `~/.config/mise/config.toml` (= chezmoi 管理: `chezmoi/dot_config/mise/config.toml`)。プロジェクト個別の宣言は `<project>/mise.toml` または `<project>/.tool-versions` (asdf 互換) で上書きできる。

mise の解決優先度 (上ほど優先):

1. `<project>/mise.toml` | `<project>/.mise.toml`
2. `<project>/.tool-versions`
3. `~/.config/mise/config.toml` (= chezmoi 管理の global)
4. `~/.tool-versions` (= 旧 global、新 Mac では作らない)

| 操作 | コマンド |
|---|---|
| 宣言済みランタイムをまとめて install | `mise install` |
| プロジェクトに個別バージョンを fix | `mise use ruby@3.4 --pin` |
| global バージョン更新 | `chezmoi/dot_config/mise/config.toml` を編集 → `chezmoi apply` → `mise install` |
| LSP 等のシム再生成 | `mise reshim` |
| 利用可能バージョン一覧 | `mise ls-remote ruby` |

注意:

* `mise use -g <pkg>` は `~/.config/mise/config.toml` を直接書き換えるので、`chezmoi re-add ~/.config/mise/config.toml` で source に取り込まないと次の `chezmoi apply` で **巻き戻される**。global は基本的に source 側を編集する運用を推奨
* asdf の `~/.asdf/installs` は再利用不可で再ビルドが要る。Python / Ruby のビルド依存問題は同じく発生するので、precompiled binary (`mise use python@3.12` 等) を使うのが基本
* mise は activate 時に PATH 先頭にシムを差し込むので、`zshrc` の `mise activate zsh` は path-helper や Nix 側ランタイムの **後ろ** に置く

注意:

* `[edit] apply = true` のため、`chezmoi edit` で保存した瞬間に `~/` に反映される。テンプレ syntax error が `~/.zshrc` を破壊しうるので、大きな書き換えは `chezmoi diff --watch` で先に検証する
* 自動生成された `*.backup` ファイル (chezmoi の auto-rename 結果) は内容を確認してから削除する

## 新しい Mac を追加する場合

hostname 規約: 仕事用は `work`、個人用は `personal` / `personal2` / `personal3` / ... と連番で増やす。`nix-darwin` の `networking.hostName` で apply 時に LocalHostName / HostName が固定されるので、IT 部門が割り当てた元の hostname がどんな名前でも上書きされる。

1. `nix/hosts/<hostname>.nix` を作成 (`work.nix` を雛形に):

   ```nix
   { ... }:
   {
     networking.hostName = "<hostname>";
     # この host 専用の brew/cask があればここに
   }
   ```

2. `flake.nix` の `hosts` attrset に追加:

   ```nix
   hosts = {
     "work"      = { user = "hideaki.ishii"; };
     "personal"  = { user = "danimal141"; };
     "personal2" = { user = "danimal141"; };  # ← 追加
   };
   ```

3. 変更を commit & push (or 既存ブランチに rebase)

4. 新 Mac でセットアップ実行:

   ```shell
   $ ./setup.sh personal2     # ← 第 1 引数で flake host を必ず明示
   ```

   初回は IT 部門が割り当てた元の hostname のままなので `scutil --get LocalHostName` では新 host を検出できない。`setup.sh` は未知の LocalHostName のとき `work` にフォールバックする実装になっているので、**個人 Mac で引数を忘れると `work` 構成で switch されてしまう**。第 1 引数で必ず明示する。`darwin-rebuild` 完走後は LocalHostName が `<hostname>` に書き換わるので、二度目以降は `./setup.sh` 引数なしで動作する。

`chezmoi` の `machineType` は **hostname で自動判定** される:

* `hostname == "work"` → `machineType = "work"`
* `hostname` が `personal` で始まる (`personal`, `personal2` 等) → `machineType = "personal"`
* CI / devcontainer / root user → `machineType = "ephemeral"`

明示的に override したい場合は `~/.config/chezmoi/chezmoi.toml` の `[data] machineType` に直接書く。

## 管理ツールの責務分担

* nix-darwin 管理 (system / `flake.lock` で pin):
  * `nix/packages.nix` — Nix store 供給の CLI バイナリ (git, tmux, neovim, fzf, ripgrep, jq, gh, kubectl 系, APM など)
  * `nix/homebrew.nix` — bootstrap binaries / tap-only formulae / GUI cask / macOS 統合の強い formulae
  * `nix/system.nix` — macOS システム設定 (Dock / Finder / KeyRepeat / trackpad) と primary user / `users.users.<user>` 宣言
* home-manager 管理 (user 層 / `flake.lock` で pin / nix-darwin module 統合):
  * `nix/home/default.nix` — `programs.*` で型付けして書きたい user-level 設定 (現状 `programs.starship`)。バイナリは `/etc/profiles/per-user/$USER/bin/` に展開される
* chezmoi 管理 (テンプレで PC 差分を吸収):
  * `~/.zshrc` `~/.gitconfig` `~/.tmux.conf` `~/.vimrc` `~/.codex/` `~/.claude/` `~/.config/mise/config.toml` ほか主要 dotfile
  * `~/.apm/apm.yml` (APM 依存マニフェスト)
* mise 管理: 言語ランタイム (Node / Python / Ruby / Go / etc.)。global 宣言ソースは `~/.config/mise/config.toml` (chezmoi 管理) で、`mise install` がそれを読んで実体を `~/.local/share/mise/installs/` に展開
* chezmoi 管理外 (`.chezmoiignore` で除外 / そもそも追跡しない): `~/.claude/.credentials.json` など Claude Code が動的に書き換える状態系、`~/.apm/apm.lock.yaml` (apm 由来)、`~/.codex/sessions/`, `~/.codex/log.json`、`~/.vim/plugged/` など vim-plug 管理領域、`~/.config/age/`、`~/.gitconfig.work` (業務 ID 用、public repo に焼かない意図で手書き運用)、`~/.tmux_start_dir` (PC ごとに `~/.tmux_start_dir.sample` をコピーしてから編集する手書きファイル、`.gitignore` で chezmoi source 側も誤コミット防止)

PATH 解決順 (`chezmoi/dot_zshrc.tmpl`):

1. `/etc/profiles/per-user/$USER/{bin,sbin}` — home-manager のユーザプロファイル (starship など `programs.*.enable` で追加した user-level バイナリ)
2. `/run/current-system/sw/{bin,sbin}` — nix-darwin の system プロファイル (Nix 管理 CLI)
3. `/opt/homebrew/{bin,sbin}` — Homebrew (Nix 移行外の formulae / cask)
4. `$HOME/bin`, `$HOME/.local/bin`
5. mise activate がこの後で言語ランタイム shim を PATH 先頭に差し込む

home-manager の user プロファイルを system プロファイルより前に置くのは、同名バイナリで home-manager 側 (= flake.lock pin) を勝たせるため。

## Claude Code skills via APM

Claude Code のスキル群は [skilltree](https://github.com/danimal141/skilltree) にまとめ、
[APM (Agent Package Manager)](https://github.com/microsoft/apm) 経由で取り込む。

`chezmoi apply` 時に `run_onchange_after_apm-install.sh` が `apm install` を自動実行するため、
通常は手動操作不要。手動で再実行する場合は次の通り。

```shell
$ cd ~/.apm
$ apm install
```

依存スキルを追加・削除する場合は `~/.apm/apm.yml`（実体は `chezmoi/dot_apm/apm.yml`）を編集して再度 `chezmoi apply` する。
