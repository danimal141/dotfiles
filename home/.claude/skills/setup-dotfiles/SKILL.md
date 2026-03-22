---
name: setup-dotfiles
description: >
  dotfiles全体の初期設定を対話的にガイドするスキル。
  新しいマシンへのセットアップ、既存環境の再構築、特定コンポーネントの再適用を支援する。
  「dotfilesをセットアップして」「環境構築して」「初期設定して」
  「setup-dotfilesを実行して」「新しいマシンにセットアップ」などのリクエストで発動する。
  "setup dotfiles", "initial setup", "bootstrap my environment" でも発動する。
---

# dotfiles セットアップ

このスキルは `~/.homesick/repos/dotfiles/` にあるdotfilesリポジトリを使って
開発環境全体を初期設定する。ユーザーの状況を確認しながら段階的に実行する。

## 事前確認

セットアップを始める前に、以下を確認する：

* 対象（新マシンのフルセットアップ / 既存環境の特定コンポーネントだけの再適用）
* Apple Silicon Mac か Intel Mac か（`uname -m` で確認: `arm64` / `x86_64`）
* dotfilesリポジトリがクローン済みか（`ls ~/.homesick/repos/dotfiles/` で確認）

---

## セットアップフロー

ユーザーの状況に応じて、以下のステップを必要なものだけ順に実行する。
各ステップは独立しているので、スキップ・再実行が可能。

### ステップ1: メインセットアップ（新マシン推奨）

リポジトリルートの `setup.sh` を実行する。以下を一括で行う：

* Xcode Command Line Tools のインストール
* Rosetta 2 のインストール（Apple Silicon のみ）
* Homebrew のインストール・更新
* `home/Brewfile` からパッケージを一括インストール（100+パッケージ）
* asdf で言語ランタイムをインストール（`_asdf.sh`）
* LSPサーバーをグローバルインストール
* homesick gem のインストール → dotfilesのシンボリンク作成
* VSCode の設定と拡張機能のセットアップ

```bash
cd ~/.homesick/repos/dotfiles
./setup.sh
```

注意：時間がかかる（特にBrewfileとasdf）。エラーが出ても `|| true` で続行する設計。

### ステップ2: dotfilesのシンボリンク作成のみ

`setup.sh` 実行済み、またはシンボリンクだけ更新したい場合：

```bash
homesick link dotfiles
```

`home/` 配下のファイルが `~/` にシンボリンクされる。

### ステップ3: 言語ランタイムのインストール（asdf）

asdf で以下の9言語を最新版でインストール：
ruby / nodejs / python / golang / rust / deno / terraform / kubectl / awscli

```bash
cd ~/.homesick/repos/dotfiles
./_asdf.sh
```

### ステップ4: Homebrew パッケージのインストール

```bash
brew bundle --file=~/.homesick/repos/dotfiles/home/Brewfile
```

### ステップ5: Vim / Neovim の設定

Neovim は `home/.config/nvim/init.vim` で `runtimepath` に `~/.vim` を追加し、
`~/.vimrc` を `source` することで Vim と設定を共有する。
`coc-settings.json` はシンボリンクで両者が同じファイルを参照する。

```bash
# coc-settings.json のシンボリンクを作成（未作成の場合）
ln -s ~/.vim/coc-settings.json ~/.config/nvim/coc-settings.json

# vim-plug でプラグインをインストール
vim +PlugInstall +qall
# または Neovim の場合
nvim +PlugInstall +qall
```

ファイル構成：

* `~/.vimrc` → Vim / Neovim 共通の設定
* `~/.vim/` → プラグイン・カラースキーム・ftpluginなど（Neovimも参照）
* `~/.config/nvim/init.vim` → Neovim エントリポイント（.vimrc を source）
* `~/.config/nvim/lua/telescope-config.lua` → Neovim 専用のLua設定
* `~/.vim/coc-settings.json` → CoC設定（`~/.config/nvim/coc-settings.json` へシンボリンク）

### ステップ6: Claude MCP サーバーの設定

`home/.claude/mcp-servers.yaml` に定義されたMCPサーバーをClaude Code CLIに登録する。

前提条件を確認：

* `yq` がインストール済みか: `which yq`
* `home/.claude/.env` が存在するか（`.env.example` をコピーして作成）

```bash
# .envが未作成の場合
cp ~/.homesick/repos/dotfiles/home/.claude/.env.example ~/.claude/.env
# 必要に応じてAPIキーを編集

# MCPサーバーを登録
cd ~/.homesick/repos/dotfiles/home/.claude
./setup-mcp.sh
```

登録確認：`claude mcp list`

### ステップ7: Codex の設定

`home/.codex/config.toml.template` と `.env` から設定ファイルを生成する。

```bash
# .envが未作成の場合
cp ~/.homesick/repos/dotfiles/home/.codex/.env.example ~/.codex/.env
# .envを編集してAPIキーを設定（GEMINI_API_KEY等）

# 設定ファイルを生成
cd ~/.homesick/repos/dotfiles/home/.codex
./apply-config.sh
```

### ステップ8: VSCode の設定

設定ファイルの適用と拡張機能のインストール：

```bash
# 設定・キーバインドの適用（${HOME}変数を展開してJSONを生成）
cd ~/.homesick/repos/dotfiles/vscode
./apply-settings.sh

# 拡張機能を extensions.txt からインストール
./sync-extensions.sh --install

# 現在の拡張機能を extensions.txt に保存（拡張を手動で追加した後）
./sync-extensions.sh --save

# インストール状況の確認
./sync-extensions.sh --status
```

---

## コンポーネント別 再適用コマンド早見表

| コンポーネント | コマンド |
|---|---|
| dotfilesシンボリンク | `homesick link dotfiles` |
| Brewパッケージ | `brew bundle --file=~/...dotfiles/home/Brewfile` |
| 言語ランタイム | `cd ~/...dotfiles && ./_asdf.sh` |
| Vim/Neovimプラグイン | `vim +PlugInstall +qall` |
| coc-settings シンボリンク | `ln -s ~/.vim/coc-settings.json ~/.config/nvim/coc-settings.json` |
| Claude MCP | `cd ~/...dotfiles/home/.claude && ./setup-mcp.sh` |
| Codex設定 | `cd ~/...dotfiles/home/.codex && ./apply-config.sh` |
| VSCode設定 | `cd ~/...dotfiles/vscode && ./apply-settings.sh` |
| VSCode拡張 | `cd ~/...dotfiles/vscode && ./sync-extensions.sh --install` |

---

## トラブルシューティング

### homesick コマンドが見つからない

```bash
gem install homesick
```

### asdf コマンドが見つからない

```bash
# Homebrewでインストール済みの場合、.zshrcを再読み込み
source ~/.zshrc
```

### MCP登録で `yq: command not found`

```bash
brew install yq
```

### VSCode `code` コマンドが見つからない

VSCodeのコマンドパレット（Cmd+Shift+P）→「Shell Command: Install 'code' command in PATH」を実行。

### coc-settings.json のシンボリンクが壊れている

```bash
rm ~/.config/nvim/coc-settings.json
ln -s ~/.vim/coc-settings.json ~/.config/nvim/coc-settings.json
```

### Brewfileのインストールで一部失敗した場合

```bash
brew install <package-name>
```

---

## 進め方のガイドライン

* ユーザーがどのステップから始めたいかを確認してから実行する
* 各コマンドの実行前に何をするか日本語で説明する
* エラーが発生したらすぐに内容を確認し、原因を特定してから次に進む
* 環境変数（APIキー等）の設定が必要なステップでは、ユーザーに確認を求める
* `setup.sh` の全実行は時間がかかるため、必要なステップだけ個別実行することも提案する
