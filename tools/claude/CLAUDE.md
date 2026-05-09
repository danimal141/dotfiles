# Personal Preferences

## Workflow
* 複雑な変更は plan mode で計画を立ててから実行
* 一度に1つの変更に集中する
* 変更前にファイルを読んで理解してから着手
* コマンド実行の許可を私に確認する時は、コマンドの説明を日本語で簡潔に出力

## Code Reading
* コードリーディング時、LSP が利用可能か最初に確認する（対象言語のソースファイルに documentSymbol を1回試行）
* LSP が利用可能かつ必要なライブラリがインストール済みなら、grep/ファイル直読みより LSP を優先する
  * 定義元の特定: goToDefinition
  * 参照箇所の追跡: findReferences
  * ファイル構造の把握: documentSymbol（ファイル全体を読まずに構造を把握でき効率的）
  * 型情報の確認: hover
* LSP が利用不可の場合は grep / ファイル直読みにフォールバック

## Code Style
* TypeScript strict mode
* イミュータブルなデータ構造を優先的に活用
* 早期リターンでネストを減らす
* 自己文書化コード（コメントより明確な命名）

## Testing
* テスト駆動開発（TDD）を基本とする
* 振る舞いをテスト、実装詳細はテストしない
* テストが失敗することを確認してから実装

## Git
* Conventional Commits 形式（feat/fix/docs/refactor/chore）
* 小さく頻繁なコミット
* コミットメッセージは変更内容と理由を含める

## Communication
* 不明点は推測せず確認する
* 複雑なタスクは計画を提示してから実行
* 学んだことはその場で共有
