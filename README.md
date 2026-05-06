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

1. Xcode CLT / Rosetta インストール
2. Nix 公式 upstream installer 実行 (既に入っていれば skip)
3. macOS Keychain から CA bundle を `/etc/nix/ca-bundle.pem` に焼き、`launchctl setenv` で nix-daemon に渡す (社内 VPN の SSL inspection 対策、個人 Mac でも害はない)
4. Nix 公式 installer が書いた `/etc/bashrc` `/etc/nix/nix.conf` を `*.before-nix-darwin` に退避 (nix-darwin の activation が「unrecognized content」を理由に abort するのを回避)
5. `sudo -E nix --extra-experimental-features 'nix-command flakes' run nix-darwin -- switch --flake ".#<hostname>"` を実行 — `nix/packages.nix` (Nix store CLI) / `nix/homebrew.nix` (brew/cask) / `nix/system.nix` (macOS 設定) が一括反映
6. `chezmoi init --apply --source "$(pwd)"` で dotfile を `~/` に展開
7. `mise install` で `~/.tool-versions` の言語ランタイムを install
8. LSP server / VSCode 拡張のセットアップ
9. `exec $SHELL -l` で新 shell に切り替え (PATH と chezmoi の dotfile を反映)

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

### 困ったとき

* **Nix の SSL エラー (`self-signed certificate in certificate chain`)** — `setup.sh` の手順 3 が走り終わっているか (`/etc/nix/ca-bundle.pem` が 100KB 以上ある) を確認。社内 IT が新しい CA を Keychain に push した直後は bundle を再生成 (`sudo bash -c "security find-certificate ..." && sudo launchctl kickstart -k system/org.nixos.nix-daemon`)。
* **`darwin-rebuild` が「unrecognized content in /etc/...」で止まる** — そのファイルを `.before-nix-darwin` に退避してから再実行。
* **`brew bundle` が cask 名で失敗** — Homebrew 側で改名 / cask 化されたものは `nix/homebrew.nix` を更新して PR。

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
* tap-only formulae (FairwindsOps/pluto, fujiwara/tfstate-lookup, k1LoW/tbls, kayac/ecspresso, mutagen-io, yukiarrr/ecsk)
* Apple / macOS 統合が brew の方が確実 (basictex, ffmpeg, imagemagick, llvm, mas, gdb)
* Node / Python ランタイム前提 (markdownlint-cli, marp-cli, repomix, pipx)
* macOS-only ツール (terminal-notifier, im-select)
* shell 本体と plugin (zsh / zsh-autosuggestions / zsh-syntax-highlighting / zsh-completions) — brew の方が startup が速い

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

asdf を置き換えた言語ランタイム管理。`~/.tool-versions` (asdf 互換) を読むので既存プロジェクトはそのまま動く。

| 操作 | コマンド |
|---|---|
| プロジェクト依存をまとめて install | `mise install` |
| 個別バージョンを fix | `mise use ruby@3.4 --pin` |
| グローバル install (`~/.tool-versions`) | `mise use -g node@22` |
| LSP 等のシム再生成 | `mise reshim` |
| 利用可能バージョン一覧 | `mise ls-remote ruby` |

注意:

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
     "personal"  = { user = "danimal141"; };  # ← 追加
   };
   ```

3. 変更を commit & push (or 既存ブランチに rebase)

4. 新 Mac でセットアップ実行:

   ```shell
   $ ./setup.sh
   ```

   初回は `nix run nix-darwin -- switch --flake .#<hostname>` で hostname を指定する (元の hostname と一致しないため scutil で検出できない)。`darwin-rebuild` 実行後は LocalHostName が `<hostname>` に変わるので、二度目以降は `setup.sh` の `scutil --get LocalHostName` 経由で動作する。

`chezmoi` の `machineType` は **hostname で自動判定** される:

* `hostname == "work"` → `machineType = "work"`
* `hostname` が `personal` で始まる (`personal`, `personal2` 等) → `machineType = "personal"`
* CI / devcontainer / root user → `machineType = "ephemeral"`

明示的に override したい場合は `~/.config/chezmoi/chezmoi.toml` の `[data] machineType` に直接書く。

## 管理ツールの責務分担

* nix-darwin 管理:
  * `nix/packages.nix` — Nix store 供給の CLI バイナリ (git, tmux, neovim, fzf, ripgrep, jq, gh, kubectl 系, APM など、`flake.lock` で pin)
  * `nix/homebrew.nix` — bootstrap binaries / tap-only formulae / GUI cask / macOS 統合の強い formulae
  * `nix/system.nix` — macOS システム設定 (Dock / Finder / KeyRepeat / trackpad)
* chezmoi 管理: `~/.zshrc` `~/.gitconfig` `~/.tmux.conf` `~/.vimrc` `~/.codex/` `~/.claude/` ほか主要設定 (PC ごとの差分は tmpl で吸収)
* mise 管理: 言語ランタイム (Node / Python / Ruby / Go / etc.)
* chezmoi 管理外 (`.chezmoiignore` で除外): `~/.claude/.env`, `~/.claude/.markdownlint.jsonc`, `~/.apm/apm.lock.yaml` などツールが動的に書き換えるファイル群

PATH 解決順 (`chezmoi/dot_zshrc.tmpl`):

1. `/run/current-system/sw/bin` — Nix store (nix-darwin が管理する CLI)
2. `/opt/homebrew/bin` — Homebrew (Nix 移行外の formulae / cask)
3. `$HOME/bin`, `$HOME/.local/bin`
4. mise activate がこの後で言語ランタイム shim を PATH 先頭に差し込む

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
