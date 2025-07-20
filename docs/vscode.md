# VSCode 設定管理

このdotfilesリポジトリのVSCode設定管理システムです。設定とエクステンションを統一的に管理し、新しいマシンでの環境構築を自動化します。

## 概要

VSCode設定管理システムの特徴：

- **テンプレートベース設定**: 環境変数を使用した設定の動的適用
- **クロスプラットフォーム対応**: macOS/Linuxで自動的にパスを調整
- **エクステンション管理**: インストール済みエクステンションの同期
- **キーバインディング**: カスタムショートカットの管理

## ファイル構成

### 設定ファイル

- `settings.template.jsonc` - VSCode設定テンプレート（環境変数使用）
- `keybindings.template.jsonc` - キーバインディング設定テンプレート
- `extensions.txt` - インストール対象エクステンション一覧（60個）

### スクリプト

- `apply-settings.sh` - 設定適用スクリプト
- `sync-extensions.sh` - エクステンション同期スクリプト

### ドキュメント

- `README.md` - 詳細な使用方法（英語）

## セットアップ

### 初回セットアップ

メインのsetup.shスクリプト実行時に自動で以下が実行されます：

1. VSCode設定の適用
2. エクステンションの一括インストール

### 手動セットアップ

```bash
cd ~/path/to/dotfiles/home/vscode

# 設定を適用
./apply-settings.sh

# エクステンションをインストール
./sync-extensions.sh --install
```

## 主要設定内容

### エディタ設定

- **フォント**: Source Han Code JP, Menlo, Monaco
- **フォントサイズ**: 11pt
- **タブサイズ**: 言語別設定（Ruby/JS/TS: 2, Python/Go: 4）
- **ワードラップ**: 有効
- **ミニマップ**: 無効
- **パンくずリスト**: 無効

### テーマと外観

- **カラーテーマ**: Solarized Dark
- **アイコンテーマ**: VSCode Icons
- **アクティビティバー**: 非表示
- **スタートアップエディタ**: なし

### 言語別設定

#### Ruby
- **フォーマッター**: Ruby LSP (Shopify)
- **バージョン管理**: asdf
- **フォーマット**: 保存時自動実行

#### JavaScript/TypeScript
- **フォーマッター**: Prettier
- **タブサイズ**: 2スペース
- **フォーマット**: 保存時自動実行

#### Python
- **フォーマッター**: Python標準
- **タブサイズ**: 4スペース
- **フォーマット**: 保存時自動実行

#### YAML
- **フォーマッター**: Red Hat YAML
- **CloudFormation**: カスタムタグ対応

## エクステンション管理

### インストール済みエクステンション（抜粋）

#### 必須ツール
- **Anthropic Claude Code**: Claude Code CLI連携
- **GitHub Copilot**: AI支援コーディング
- **GitLens**: Git拡張機能

#### 言語サポート
- **Ruby Extensions Pack**: Ruby開発環境
- **Go**: Go言語サポート
- **Python**: Python開発環境
- **Deno**: Deno/Node.js開発

#### ユーティリティ
- **VSCode Neovim**: Vim操作モード
- **Prettier**: コードフォーマッター
- **Docker**: コンテナ開発
- **Kubernetes Tools**: K8s管理

### エクステンション同期

```bash
# 現在のエクステンションを保存
./sync-extensions.sh --save

# 保存されたエクステンションをインストール
./sync-extensions.sh --install

# 同期状況を確認
./sync-extensions.sh --status
```

## キーバインディング

### カスタムショートカット

- **Cmd+Shift+M**: ターミナルフォーカス時にパネル最大化切り替え
- **Cmd+Shift+W**: Workspace Explorerにフォーカス
- **Cmd+Shift+C**: エクスプローラーのフォルダを全て折りたたみ

## プラットフォーム対応

### macOS
- 設定場所: `~/Library/Application Support/Code/User/`
- Kubernetes Tools: ARM64対応パス

### Linux
- 設定場所: `~/.config/Code/User/`
- 自動的にLinux環境を検出

## 環境変数

テンプレートファイルで使用される環境変数：

- `${HOME}`: ユーザーホームディレクトリ
  - Kubernetesツールのパス指定
  - ワークスペース設定

## メンテナンス

### 新しい設定の追加

1. `settings.template.jsonc`を編集
2. パスが必要な場合は`${HOME}`を使用
3. `./apply-settings.sh`で適用
4. 変更をコミット

### 新しいエクステンションの追加

1. VSCodeで通常通りエクステンションをインストール
2. `./sync-extensions.sh --save`で保存
3. `extensions.txt`の変更をコミット

## トラブルシューティング

### よくある問題

1. **'code'コマンドが見つからない**
   - VSCodeでCmd+Shift+P → "Shell Command: Install 'code' command in PATH"

2. **設定が反映されない**
   - `./apply-settings.sh`を再実行
   - VSCodeを再起動

3. **エクステンションのインストールが失敗**
   - VSCode Marketplaceの接続を確認
   - `./sync-extensions.sh --status`で状況確認

### 必要なツール

- **VSCode CLI**: エクステンション管理用
- **yq**: YAML処理用
- **bash**: スクリプト実行用

## 関連情報

- [VSCode 設定リファレンス](https://code.visualstudio.com/docs/getstarted/settings)
- [VSCode キーバインディング](https://code.visualstudio.com/docs/getstarted/keybindings)
- [dotfiles セットアップガイド](../setup.sh)
