# GitHub Issue実装タスク作成

GitHub IssueのURLから実装までの一連のフローを自動化します。

## 使い方

```
/project:create-task-ja
```

## 例

```
/user:create-task
GitHub IssueのURLを入力してください: https://github.com/owner/repo/issues/123
```

## 動作フロー

1. **GitHub Issue解析**
   - ユーザーから提供されたGitHub Issue URLを解析
   - GitHub MCPサーバーを使用してIssueの詳細情報を取得
   - タイトル、説明、ラベル、コメントなどを収集

2. **プランモードで実装方針作成**
   - Issueの内容を基に実装方針をプランニング
   - 技術的な課題と解決策を明確化
   - 実装に必要なステップを洗い出し
   - `/exit plan mode`で承認を得る

3. **TODOファイルへの整理**
   - プランニング結果を`.claude/work/{org}-{repo}-{issueid}-todo.md`ファイルに保存
   - 例: `.claude/work/facebook-react-12345-todo.md`
   - .claude/workフォルダがない場合は自動作成
   - 以下の形式で構造化：
   ```markdown
   # Issue #123: [Issueタイトル]

   ## 概要
   [Issueの要約]

   ## 実装方針
   [プランモードで作成した実装方針]

   ## タスクリスト
   - [ ] タスク1: [詳細]
   - [ ] タスク2: [詳細]
   - [ ] タスク3: [詳細]

   ## 技術的詳細
   [必要な技術的考慮事項]
   ```

4. **実装開始**
   - 作成したTODOファイルに基づいて実装を開始
   - TodoWriteツールを使用して進捗を管理
   - 各タスクを順次実行

## 必要な情報

- GitHub Issue URL（必須）
- リポジトリへのアクセス権限（GitHub MCP経由）

## 出力

- `.claude/work/{org}-{repo}-{issueid}-todo.md`: 実装計画と進捗管理用ファイル
- 実装されたコード/変更
