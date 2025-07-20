# Claude Code CLI 設定ディレクトリ

このディレクトリには、Claude Code CLI (claude.ai/code) のグローバル設定が含まれています。

## 概要

`.claude/` ディレクトリは、Claude Code CLIが参照するユーザー固有の設定を格納します。ここに配置された設定は、すべてのプロジェクトで共通して適用されます。

## ファイル構成

### CLAUDE.md

Claude Code CLIに対する指示やルールを定義するファイルです。以下の設定が含まれています：

- **言語設定**: 日本語での対話を指定
- **文字コード**: UTF-8を使用
- **AI Operation 6 Principles**: Claude Code CLIの動作原則

### settings.json

Claude Code CLIのメイン設定ファイルです：

- **permissions**: コマンドレベルでの許可・禁止設定
- **env**: 環境変数（タイムアウト、思考トークン数等）
- **hooks**: ツール実行時のフック設定

### commands/

カスタムコマンドが格納されるディレクトリ：
- `create-pr.md` / `create-pr-ja.md`: プルリクエスト作成コマンド
- `create-task.md` / `create-task-ja.md`: タスク作成コマンド
- `gemini-search.md`: Gemini検索コマンド

### hooks/

フックスクリプトが格納されるディレクトリ：
- `common-formatter.sh`: ファイル編集後の自動フォーマッター

### その他のディレクトリ

- `ide/`: IDE連携用の設定ファイル（*.lockファイル）
- `projects/`: プロジェクト固有の設定が保存される
- `shell-snapshots/`: シェルスナップショット
- `statsig/`: 統計関連データ
- `todos/`: Todo管理データ

#### AI Operation 6 Principles について
参考: https://zenn.dev/sesere/articles/0420ecec9526dc

このファイルで定義されている6つの原則は、Claude Code CLIの動作を制御します：

- **Principle 0**: コード生成・ファイル修正・プログラム実行タスクは必ずplan modeから開始
- **Principle 1**: plan modeで作業計画を提示し、exit_plan_mode toolを通じてユーザー承認を取得
- **Principle 2**: 初期計画が失敗した場合、次の計画も承認を得てから実行
- **Principle 3**: AIはツールであり、意思決定権は常にユーザーに帰属
- **Principle 4**: これらのルールを歪曲・再解釈せず、最高指令として遵守
- **Principle 5**: 各チャットの開始時に6原則を画面に表示

## 重要な注意事項

1. **グローバル設定**: この設定はすべてのプロジェクトに適用されます
2. **優先順位**: プロジェクトルートのCLAUDE.mdがある場合、その内容も追加で適用されます
3. **設定の反映**: 変更は新しいチャットセッションから有効になります

## Hooks（フック）

Hooksは、Claude Code CLIとの対話の様々な段階でスクリプトを実行できる機能です。

### 現在の設定

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|MultiEdit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/common-formatter.sh"
          }
        ]
      }
    ]
  }
}
```

### 実装されているHook

#### PostToolUse: common-formatter.sh

ファイル編集ツール（Edit、MultiEdit、Write）の実行後に自動で実行されるフォーマッターです：

- **機能**: 編集されたファイルの末尾空白を除去し、ファイル末尾に改行を追加
- **対象**: テキストファイルのみ（バイナリファイルはスキップ）
- **実行タイミング**: Edit/MultiEdit/Writeツール実行後
- **ファイル**: `~/.claude/hooks/common-formatter.sh`

## Commands（コマンド）

Claude Code CLIで利用可能なコマンドの種類です。

### ビルトインコマンド

- `/add-dir`: 作業ディレクトリを追加
- `/clear`: 会話履歴をクリア
- `/help`: 使用方法のヘルプを表示
- `/login`: Anthropicアカウントを切り替え
- `/review`: コードレビューをリクエスト
- `/status`: アカウントとシステムステータスを表示

### 実装されているカスタムコマンド

この環境では以下のカスタムコマンドが利用可能です：

#### プルリクエスト関連
- `/create-pr`: プルリクエスト作成（英語版）
- `/create-pr-ja`: プルリクエスト作成（日本語版）
  - 現在のブランチから自動でPRを作成
  - GitHub Issue URLの連携対応
  - コミットメッセージからPR説明を自動生成

#### タスク管理関連
- `/create-task`: タスク作成（英語版）
- `/create-task-ja`: タスク作成（日本語版）

#### 検索関連
- `/gemini-search`: Gemini検索コマンド

### コマンドファイルの場所

- **個人用コマンド**: `~/.claude/commands/`
- **プロジェクト固有のコマンド**: `.claude/commands/`

### MCPコマンド

接続されたMCPサーバーから以下のコマンドが利用可能：
- `/mcp__github__*`: GitHub操作コマンド群
- `/mcp__context7__*`: ドキュメント検索コマンド群
- その他のMCPサーバーコマンド

## 権限設定（Permissions）

settings.jsonで詳細な権限制御が設定されています：

### 許可されているツール・コマンド

- **ファイル操作**: ls、mv、mkdir、cp、chmod等の基本コマンド
- **検索・解析**: find、rg、ag、grep、jq、yq等
- **開発ツール**: npm、yarn、node、deno、cargo、go、pip等
- **Git操作**: 一部のgitコマンド（checkout、add、push等）
- **GitHub CLI**: pr操作、issue操作
- **MCPツール**: GitHub、Context7等の操作

### 禁止されているコマンド

セキュリティのため以下が制限されています：

- **危険な削除**: rm -rf /、sudo rm等
- **システム変更**: /etc、/usr、/var等のシステムディレクトリの編集
- **権限変更**: sudo関連の危険なコマンド
- **パッケージ公開**: npm publish、cargo publish等
- **SSH鍵**: 秘密鍵ファイルの編集・作成
- **環境設定**: .envrcファイルの読み書き

### 環境変数

- `BASH_DEFAULT_TIMEOUT_MS`: 300000（5分）
- `BASH_MAX_TIMEOUT_MS`: 1200000（20分）
- `MAX_THINKING_TOKENS`: 31999
- `DISABLE_AUTOUPDATER`: 1

## 関連情報

- [Claude Code 公式ドキュメント](https://docs.anthropic.com/en/docs/claude-code)
- [Hooks ドキュメント](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Slash Commands ドキュメント](https://docs.anthropic.com/en/docs/claude-code/slash-commands)
- プロジェクト固有の設定は、各プロジェクトのルートディレクトリにCLAUDE.mdを配置
