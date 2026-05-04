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

### nix-darwin (Homebrew + macOS 設定)

| 操作 | コマンド |
|---|---|
| パッケージ追加 / 削除 | `nix/homebrew.nix` を編集 → `darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"` |
| macOS 設定変更 | `nix/system.nix` を編集 → 同上 |
| 入力を個別更新 | `nix flake lock --update-input nixpkgs` (or `nix-darwin` / `nix-homebrew`) |
| 世代一覧 | `darwin-rebuild --list-generations` |
| 前世代に戻す | `darwin-rebuild --rollback` |

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

注意:

* `[edit] apply = true` のため、`chezmoi edit` で保存した瞬間に `~/` に反映される。テンプレ syntax error が `~/.zshrc` を破壊しうるので、大きな書き換えは `chezmoi diff --watch` で先に検証する
* 自動生成された `*.backup` ファイル (chezmoi の auto-rename 結果) は内容を確認してから削除する

## 新しい Mac を追加する場合

1. 新 Mac で hostname を確認:

   ```shell
   $ scutil --get LocalHostName
   ```

2. `nix/hosts/<hostname>.nix` を作成 (`hideaki-ishii1.nix` を雛形に):

   ```nix
   { ... }:
   {
     networking.hostName = "<hostname>";
     # この host 専用の brew/cask があればここに
   }
   ```

3. `flake.nix` の `hosts` attrset に追加:

   ```nix
   hosts = {
     "hideaki-ishii1" = { user = "hideaki.ishii"; };
     "personal-mbp"   = { user = "danimal141"; };  # ← 追加
   };
   ```

4. 変更を commit & push (or 既存ブランチに rebase)

5. 新 Mac でセットアップ実行:

   ```shell
   $ ./setup.sh
   ```

`chezmoi` の `machineType` は **`whoami` の出力で自動判定** される:

* `whoami == "hideaki.ishii"` (会社管理 Mac) → `machineType = "work"`
* それ以外 (例: `whoami == "danimal141"`) → `machineType = "personal"`

明示的に override したい場合は `~/.config/chezmoi/chezmoi.toml` の `[data] machineType` に直接書く。

## 並走モード (Step A〜B 時点)

* nix-darwin 管理: Homebrew (CLI / cask)、macOS システム設定
* chezmoi 管理: `~/.zshrc` `~/.gitconfig` `~/.tmux.conf` `~/.vimrc` `~/.codex/` `~/.claude/` ほか主要設定
* homesick 経由 (chezmoi 管理外、`.chezmoiignore` で除外): `~/.claude/.env`, `~/.claude/.markdownlint.jsonc`, `~/.apm/apm.lock.yaml` など

`home/Brewfile` は brew bundle 由来の旧管理経路として残置 (Step C で削除予定)。Step B 完了後は **`nix/homebrew.nix` のみ** を編集する。

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
