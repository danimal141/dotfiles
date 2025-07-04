# Claude MCP Manager

Claude Code CLIのMCP（Model Context Protocol）サーバー設定をGitで安全に管理するためのツールです。

## 概要

このツールを使うことで：

- MCP設定をYAMLファイルで管理
- 環境変数（APIキーなど）を`.env`ファイルで分離管理
- `claude mcp add`コマンドを一括実行

## セットアップ

### 1. 必要なツールのインストール

```bash
# yqのインストール（YAMLパーサー）
brew install yq
```

### 2. 環境変数の設定（必要に応じて）

```bash
cp .env.example .env
# .envファイルを編集して必要なAPIキーを設定
```

### 3. MCPサーバーの追加

```bash
./setup-mcp.sh
```

## ファイル構成

- `mcp-servers.yaml` - MCP設定を定義するファイル（Git管理対象）
- `.env.example` - 環境変数のテンプレート（Git管理対象）
- `.env` - 実際の環境変数（Git管理対象外）
- `setup-mcp.sh` - MCP設定を適用するスクリプト
- `.gitignore` - Git除外設定

## 使い方

### 新しいMCPサーバーを追加する

1. `mcp-servers.yaml`に新しいサーバー設定を追加
2. 必要に応じて`.env`に環境変数を追加
3. `./setup-mcp.sh`を実行

### 設定例

```yaml
servers:
  context7:
    command: npx
    args:
      - "-y"
      - "@upstash/context7-mcp"
    env: {}
```

## 注意事項

- `.env`ファイルには機密情報が含まれるため、絶対にGitにコミットしないでください
- `--scope project`オプションでプロジェクト単位の設定として追加されます
