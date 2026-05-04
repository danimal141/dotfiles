# Dotfiles

## Requirements

* [Nix + nix-darwin](https://github.com/nix-darwin/nix-darwin) (Step B 以降、Homebrew / macOS 設定の declarative 管理)
* [chezmoi](https://github.com/twpayne/chezmoi) (Step A 以降、dotfile 管理 + テンプレート)
* [homesick](https://github.com/technicalpickles/homesick) (legacy paths only、完全解除は後続 PR)

## Get started

### 1. リポジトリを clone

```shell
$ mkdir -p ~/.homesick/repos && cd ~/.homesick/repos
$ git clone git@github.com:danimal141/dotfiles.git
$ cd dotfiles
```

### 2. Nix を install

```shell
$ sh <(curl -L https://nixos.org/nix/installer)

# Flakes 有効化
$ mkdir -p ~/.config/nix
$ echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### 3. nix-darwin を apply (Homebrew / brew / cask / macOS 設定)

Brewfile の宣言を `nix/homebrew.nix` に移植済み。`darwin-rebuild switch` 一発で全部入る。

```shell
$ nix run nix-darwin -- switch --flake ".#$(scutil --get LocalHostName)"

# 二度目以降は darwin-rebuild が PATH に居る
$ darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"
```

`onActivation.cleanup = "check"` の状態で動作確認後、`nix/homebrew.nix` を編集して `cleanup = "uninstall"` に切り替えると「宣言から外したパッケージが自動 uninstall」が有効になる。

### 4. chezmoi 用 config を作成

`home/.chezmoi.toml.tmpl` は対話プロンプト (`promptStringOnce`) を使う。Bash 越しに init する場合は config を直接書いてもよい。

```shell
$ mkdir -p ~/.config/chezmoi
$ cat > ~/.config/chezmoi/chezmoi.toml <<EOF
sourceDir = "$HOME/.homesick/repos/dotfiles"

[data]
    name = "<your name>"
    email = "<your email>"
    machineType = "personal"  # or "work" / "ephemeral"

[edit]
    apply = true
EOF
```

### 5. dotfiles を展開

```shell
$ chezmoi diff --no-pager
$ chezmoi apply
```

`chezmoi apply` 時に `home/.chezmoiscripts/darwin/run_onchange_after_apm-install.sh.tmpl` が走り、APM の skill 群が install される。

### 6. シークレット注入

`home/dot_codex/config.toml.tmpl` などで API key を `{{ env "GEMINI_API_KEY" }}` 形式で読む。1Password CLI を使う場合は `op signin` 後にテンプレを `{{ (onepasswordRead "op://Personal/...") }}` に書き換える。

age 経路を使う場合は鍵を `~/.config/age/key.txt` に置いて、`encrypted_` プレフィックス付きの chezmoi ファイルで運ぶ。

### 7. pre-commit + secretlint を有効化

API key の誤コミットを防ぐため secretlint が pre-commit に組み込まれている。

```shell
$ cd ~/.homesick/repos/dotfiles
$ npm install
$ pre-commit install        # or `prek install`
```

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

## 管理ツールの責務分担 (Step A〜C 完了時点)

* nix-darwin 管理:
  * `nix/packages.nix` — Nix store 供給の CLI バイナリ (git, tmux, neovim, fzf, ripgrep, jq, gh, kubectl 系, APM など、`flake.lock` で pin)
  * `nix/homebrew.nix` — bootstrap binaries / tap-only formulae / GUI cask / macOS 統合の強い formulae
  * `nix/system.nix` — macOS システム設定 (Dock / Finder / KeyRepeat / trackpad)
* chezmoi 管理: `~/.zshrc` `~/.gitconfig` `~/.tmux.conf` `~/.vimrc` `~/.codex/` `~/.claude/` ほか主要設定 (PC ごとの差分は tmpl で吸収)
* mise 管理: 言語ランタイム (Node / Python / Ruby / Go / etc.)
* homesick 経由 (chezmoi 管理外、`.chezmoiignore` で除外): `~/.claude/.env`, `~/.claude/.markdownlint.jsonc`, `~/.apm/apm.lock.yaml` など

PATH 解決順 (`home/dot_zshrc.tmpl`):

1. `/run/current-system/sw/bin` — Nix store (nix-darwin が管理する CLI)
2. `/opt/homebrew/bin` — Homebrew (Nix 移行外の formulae / cask)
3. `$HOME/bin`, `$HOME/.local/bin`
4. mise activate がこの後で言語ランタイム shim を PATH 先頭に差し込む

homesick の完全解除と `home/.zshrc` 等の重複ファイル削除、`.homesick_subdir` 削除は **後続の別 PR** で扱う。

## Claude Code skills via APM

Claude Code のスキル群は [skilltree](https://github.com/danimal141/skilltree) にまとめ、
[APM (Agent Package Manager)](https://github.com/microsoft/apm) 経由で取り込む。

`chezmoi apply` 時に `run_onchange_after_apm-install.sh` が `apm install` を自動実行するため、
通常は手動操作不要。手動で再実行する場合は次の通り。

```shell
$ cd ~/.apm
$ apm install
```

依存スキルを追加・削除する場合は `~/.apm/apm.yml`（実体は `home/dot_apm/apm.yml`）を編集して再度 `chezmoi apply` する。
