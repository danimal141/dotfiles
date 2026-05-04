# Dotfiles

## Requirements

* [chezmoi](https://github.com/twpayne/chezmoi) (primary, Step A 以降)
* [homesick](https://github.com/technicalpickles/homesick) (legacy paths only — 完全解除は後続 PR)
* [Homebrew](https://brew.sh/)

## Get started

### 1. リポジトリを clone

`~/.homesick/repos/dotfiles` は homesick と互換のパスとして引き続き使う。

```shell
$ mkdir -p ~/.homesick/repos && cd ~/.homesick/repos
$ git clone git@github.com:danimal141/dotfiles.git
```

### 2. ツール群を Homebrew で install

`home/Brewfile` に chezmoi / age / 1password-cli / APM を含む全依存が宣言されている。

```shell
$ brew bundle --file=~/.homesick/repos/dotfiles/home/Brewfile
```

### 3. chezmoi 用 config を作成

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

対話的にやる場合は次のコマンドで `~/.config/chezmoi/chezmoi.toml` が生成される。

```shell
$ chezmoi init --source ~/.homesick/repos/dotfiles
```

### 4. ~/ に dotfiles を展開

```shell
$ chezmoi diff --no-pager   # 変更内容を確認
$ chezmoi apply             # 実体ファイルとして配置
```

`chezmoi apply` 時に `home/.chezmoiscripts/darwin/run_onchange_after_apm-install.sh.tmpl` が走り、APM の skill 群が install される。

### 5. シークレット注入

`home/dot_codex/config.toml.tmpl` などで API key を `{{ env "GEMINI_API_KEY" }}` 形式で読む。1Password CLI を使う場合は `op signin` 後にテンプレを `{{ (onepasswordRead "op://Personal/...") }}` に書き換える。

age 経路を使う場合は鍵を `~/.config/age/key.txt` に置いて、`encrypted_` プレフィックス付きの chezmoi ファイルで運ぶ。

### 6. pre-commit + secretlint を有効化

API key の誤コミットを防ぐため secretlint が pre-commit に組み込まれている。

```shell
$ cd ~/.homesick/repos/dotfiles
$ npm install
$ pre-commit install        # or `prek install`
```

## 並走モード (Step A 完了時点)

現状は **chezmoi と homesick が並走** している。

* chezmoi 管理: `~/.zshrc` `~/.gitconfig` `~/.tmux.conf` `~/.vimrc` `~/.codex/` `~/.claude/` ほか主要設定
* homesick 経由 (chezmoi 管理外、`.chezmoiignore` で除外): `~/.claude/.env`, `~/.claude/.markdownlint.jsonc`, `~/.apm/apm.lock.yaml`, `~/.apm/.gitignore` など

`chezmoi apply` を一度走らせると、homesick の symlink は chezmoi 管理対象パスでは実体ファイルに上書きされるため、それ以降 `homesick link` を再実行すると衝突する。Step A 完了後は **chezmoi のみ** を使う運用が前提。

homesick の完全解除と `home/.zshrc` 等の重複ファイル削除、`.homesick_subdir` 削除は **後続の別 PR** で扱う。

## chezmoi の日常運用

| 操作 | コマンド |
|---|---|
| dotfile を編集 (apply 即時反映) | `chezmoi edit ~/.zshrc` |
| 変更予定を確認 | `chezmoi diff` |
| 適用 | `chezmoi apply` |
| 整合性チェック | `chezmoi verify` |
| ホームディレクトリの変更を取り込む | `chezmoi re-add ~/.zshrc` |

注意点:

* `[edit] apply = true` のため、`chezmoi edit` で保存した瞬間に `~/` に反映される。テンプレ syntax error が `~/.zshrc` を破壊しうるので、大きな書き換えは `chezmoi diff --watch` で先に検証する。
* 自動生成された `*.backup` ファイル (chezmoi の auto-rename 結果) は内容を確認してから削除する。

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
