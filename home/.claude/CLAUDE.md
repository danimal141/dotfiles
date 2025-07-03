# CLAUDE.md - グローバル設定

このファイルは、すべてのプロジェクトで共通して適用される設定です。
プロジェクト固有の設定は、各プロジェクトのルートディレクトリにCLAUDE.mdを作成してください。

## 最重要ルール

**必須**: すべての回答と説明は日本語で行ってください。コード内のコメントも日本語で記述してください。変数名は英語を使用してください。

## 作業フロー

### 1. 探索フェーズ（Exploration Phase）
Claude に問題に関連するファイルやドキュメントを読み込ませ、現状を理解させます。重要な点は、この段階では コードを書かせないこと です。

- タスクの要件を完全に理解する
- 関連するファイルとコンテキストを確認する
- 不明な点があれば質問する
- **この段階では実装しない**

### 2. 計画フェーズ（Planning Phase）
- 実装計画を日本語で説明する
- 必要に応じて複数の選択肢を提示する
- ユーザーの承認を得てから実装に進む

### 3. 実装フェーズ（Implementation Phase）
- 小さな変更単位で作業を進める
- 各ステップでテストを実行する
- コミットメッセージは英語で明確に記述

### 4. 反復改善フェーズ（Iteration Phase）
While the first version might be good, after 2-3 iterations it will typically look much better. Give Claude the tools to see its outputs for best results.

- 最初のバージョンで満足せず、2-3回の反復で改善する
- 実行結果を確認しながら改善を続ける

## 開発原則

### 複雑なタスクの処理
Claude Code is intentionally low-level and unopinionated, providing close to raw model access without forcing specific workflows.

- 複雑なタスクは段階的に分解する
- 各ステップで結果を確認する
- 必要に応じてサブタスクに分割する

### コードベースの学習
When onboarding to a new codebase, use Claude Code for learning and exploration. You can ask Claude the same sorts of questions you would ask another engineer on the project when pair programming.

新しいコードベースでは：
- アーキテクチャの理解から始める
- 既存のパターンとコンベンションを学ぶ
- 他のエンジニアに聞くような質問をする

## メモリ管理（CLAUDE.md）

### 階層構造
```
~/.claude/CLAUDE.md        # グローバル設定（このファイル）
./CLAUDE.md               # プロジェクト固有の設定

# 以下は必要に応じて作成（オプション）
./tests/CLAUDE.md         # テスト固有の設定
./src/frontend/CLAUDE.md  # フロントエンド固有の設定
./src/backend/CLAUDE.md   # バックエンド固有の設定
```

Claude Codeは現在のディレクトリから上位に向かって再帰的にCLAUDE.mdを探索します。
サブディレクトリのCLAUDE.mdは必須ではなく、そのディレクトリに特有のルールや
コンテキストが必要な場合にのみ作成してください。作成した場合、そのディレクトリの
ファイルを扱う時に自動的に参照されます。

### 効果的な内容
- プロジェクトの概要とゴール
- 技術スタックと依存関係
- コーディング規約とスタイルガイド
- 頻繁に使用するコマンドやワークフロー
- プロジェクト固有の注意事項

## セキュリティとパーミッション

### 基本方針
- 破壊的な操作には確認を求める
- 機密情報は環境変数で管理
- 不必要な権限は与えない

### 危険なモードの使用
use --dangerously-skip-permissions in a container without internet access

`--dangerously-skip-permissions`を使用する場合：
- インターネット接続のないコンテナ内で実行
- データ損失やシステム破壊のリスクを理解する
- 限定的なタスク（lint修正、ボイラープレート生成）のみ

## 開発のベストプラクティス

### テスト駆動開発
- テストを先に書くか、実装と同時に書く
- カバレッジよりも重要なケースを優先
- エッジケースを忘れない

### リファクタリング
- 動作するコードを得てからリファクタリング
- 小さなステップで進める
- 各ステップでテストを実行

### ドキュメント
- コードと一緒にドキュメントを更新
- 設計判断の理由を記録
- READMEは常に最新に保つ

## トラブルシューティング

問題が発生した場合：
1. エラーメッセージを注意深く読む
2. 関連するログを確認
3. 最小限の再現コードを作成
4. `think`を使って問題を分析させる
5. 必要に応じて別のアプローチを試す
