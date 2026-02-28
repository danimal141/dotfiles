---
name: domain-explorer
description: >
  データベーススキーマからドメインモデルを読み解き、主要ドメインごとに
  テーブル構造・リレーション・典型的なSQL例を提示するスキル。
  schema.rb, schema.prisma, マイグレーション, DDL, schema.sql など
  あらゆるスキーマ形式に対応する。
  「ドメインを教えて」「テーブル構造を理解したい」「スキーマを解説して」
  「データモデルを把握したい」「ERを説明して」「DBの全体像」
  「このプロジェクトのデータ構造」などのリクエストで発動する。
  "explain the domain", "show me the data model", "describe the schema",
  "what tables exist", "how is the data structured" でも発動する。
---

# ドメインエクスプローラー

データベーススキーマを起点に、プロジェクトのドメインモデルを体系的に解説する。
スキーマ定義を全て読み込み、テーブルをドメイン領域ごとにグルーピングし、
各ドメインの目的・リレーション・典型的なクエリパターンをSQL例付きで提示する。

## 使うべきとき

- 初めて触るプロジェクトのデータ構造を理解したいとき
- ドメイン駆動設計（DDD）の文脈で集約境界を検討するとき
- 新メンバーにデータモデルを説明する資料が欲しいとき
- テーブル間のリレーションを可視化したいとき
- 「このテーブル何に使ってるの？」が複数テーブルに及ぶとき

## 使うべきでないとき

- 特定のSQLクエリの最適化だけが目的（通常のコーディング支援を使う）
- スキーマが存在しないプロジェクト（NoSQL専用、設定ファイルのみ等）
- 単一テーブルの定義確認（直接スキーマファイルを読めばよい）

---

## 分析フロー

### ステップ 1: スキーマ定義の発見と全量読み込み

プロジェクト内のスキーマ定義ファイルを探し、全て読み込む。

#### 探索対象（優先順）

| フレームワーク | ファイル | 備考 |
|-------------|---------|------|
| Rails | `db/schema.rb` | 最も情報量が多い。全テーブル定義が1ファイルにまとまる |
| Rails | `db/structure.sql` | SQL形式のスキーマダンプ |
| Prisma | `prisma/schema.prisma` | モデル定義とリレーションが明示的 |
| Django | `*/models.py` | 各アプリのmodels.pyを収集 |
| Laravel | `database/migrations/*.php` | マイグレーション群から復元 |
| TypeORM/MikroORM | `src/**/*entity*.ts`, `src/**/*model*.ts` | デコレータからスキーマを読む |
| Sequelize | `src/models/*.js` | define()からスキーマを読む |
| Go (sqlc/ent) | `schema/*.go`, `*.sql` | SQLまたはGoのスキーマ定義 |
| SQL直接 | `*.sql`, `migrations/*.sql` | DDLファイル群 |

```bash
# 一括探索
find . -maxdepth 5 \
  \( -name "schema.rb" -o -name "structure.sql" -o -name "schema.prisma" \
     -o -name "models.py" -o -path "*/migrations/*.sql" \
     -o -name "*.entity.ts" -o -name "schema.sql" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/vendor/*" \
  2>/dev/null
```

スキーマファイルが見つかったら、全量を読み込む。
部分的な読み込みではドメイン間の関係が見えなくなるため、
スキーマ定義については省略せず全て読む。

### ステップ 2: テーブル/モデルの一覧化と分類

読み込んだスキーマから全テーブルを一覧化し、ドメイン領域に分類する。

#### 分類の基準

- テーブル名のプレフィックス/サフィックスからの推測
  （例: `user_*` → ユーザードメイン、`order_*` → 注文ドメイン）
- 外部キー関係からの推測（密結合なテーブル群は同一ドメイン）
- 命名規則のパターン（`*_logs`, `*_histories` → 監査/ログドメイン）
- フレームワーク固有のテーブル（`ar_internal_metadata`, `schema_migrations`,
  `_prisma_migrations` 等）はインフラテーブルとして分離

#### 典型的なドメイン分類例

- 認証・認可（users, roles, permissions, sessions, oauth_*)
- コアビジネス（プロジェクト固有の中心エンティティ群）
- 決済・課金（payments, subscriptions, invoices, plans）
- 通知（notifications, notification_settings, devices）
- 監査・ログ（audit_logs, *_histories, versions）
- システム（マイグレーション管理、設定値、ジョブキュー）

### ステップ 3: ドメインごとの詳細分析

各ドメインについて以下を記述する。

#### 3a. ドメイン概要

- このドメインが扱うビジネス概念（1〜2文）
- 含まれるテーブル一覧
- 他ドメインとの関係

#### 3b. テーブル構造

各テーブルについて：
- テーブル名と目的
- 主要カラム（PK, FK, ビジネスキー, ステータス, タイムスタンプ）
- インデックス（ユニーク制約、複合インデックスは特に注目）
- ENUMやチェック制約があれば、取りうる値

#### 3c. リレーション図

ドメイン内のテーブル関係をMermaid ER図で表現する。

````markdown
```mermaid
erDiagram
    users ||--o{ orders : "has many"
    orders ||--|{ order_items : "contains"
    order_items }o--|| products : "references"
    orders ||--o| payments : "paid by"
```
````

#### 3d. 典型的なSQLクエリ例

そのドメインでよく書かれるであろうクエリを3〜5個、SQL例として提示する。
「このテーブルをどう使うか」を具体的に示すことが目的。

提示するクエリの種類：
- 基本的な一覧取得（フィルタ・ソート付き）
- リレーションを辿るJOIN
- 集計・レポート系
- ステータス遷移に関わる更新
- よくあるサブクエリパターン

例（注文ドメインの場合）：

```sql
-- ユーザーの注文履歴（最新順、関連テーブル結合）
SELECT
    o.id,
    o.status,
    o.total_amount,
    o.created_at,
    COUNT(oi.id) AS item_count
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
WHERE o.user_id = :user_id
GROUP BY o.id, o.status, o.total_amount, o.created_at
ORDER BY o.created_at DESC
LIMIT 20;

-- 月別売上集計
SELECT
    DATE_TRUNC('month', o.created_at) AS month,
    COUNT(DISTINCT o.id) AS order_count,
    SUM(o.total_amount) AS revenue,
    COUNT(DISTINCT o.user_id) AS unique_buyers
FROM orders o
WHERE o.status = 'completed'
  AND o.created_at >= :start_date
GROUP BY DATE_TRUNC('month', o.created_at)
ORDER BY month DESC;

-- 未完了注文のアラート（24時間以上放置）
SELECT o.id, o.user_id, o.status, o.created_at
FROM orders o
WHERE o.status IN ('pending', 'processing')
  AND o.created_at < NOW() - INTERVAL '24 hours'
ORDER BY o.created_at ASC;
```

SQL例の方言はプロジェクトのDBに合わせる：
- PostgreSQL: `DATE_TRUNC`, `INTERVAL '1 day'`, `::timestamp`
- MySQL: `DATE_FORMAT`, `INTERVAL 1 DAY`, `CAST()`
- SQLite: `strftime`, `datetime('now', '-1 day')`
- 不明な場合はPostgreSQL方言をデフォルトとし、冒頭に注記する

### ステップ 4: クロスドメイン分析

ドメインを横断する観点で以下を分析する。

#### 4a. ドメイン間リレーションマップ

全ドメイン間の関係をMermaid図で表現する。

````markdown
```mermaid
graph LR
    Auth[認証・認可] --> Core[コアビジネス]
    Core --> Payment[決済]
    Core --> Notification[通知]
    Core --> Audit[監査ログ]
    Payment --> Notification
```
````

#### 4b. 集約境界の推定

DDD的な観点で、どのテーブル群が1つの集約（Aggregate）を形成しそうかを推定する。
根拠は外部キー制約とカスケード設定から判断する。

#### 4c. 注目ポイント

- 多態的関連（polymorphic association）の存在
- 中間テーブル（多対多）のパターン
- STI（Single Table Inheritance）の使用
- JSONカラムの活用箇所
- ソフトデリート（`deleted_at`）の有無
- マルチテナント（`tenant_id`, `organization_id`）の構造

### ステップ 5: Serenaモード追加分析（利用可能な場合）

Serena MCPが接続されている場合、以下の追加分析を行う。

1. `mcp__serena__find_symbol` でモデルクラスの定義を特定
2. `mcp__serena__get_symbols_overview` でモデルクラスの全メソッド一覧を取得
   - スコープ、バリデーション、コールバック、カスタムメソッドを把握
3. `mcp__serena__find_referencing_symbols` で各モデルの参照元を特定
   - 「このモデルはどのサービス/コントローラから使われているか」を可視化

---

## 出力フォーマット

`.claude/reports/domain-analysis.md` に出力する。

```markdown
# ドメインモデル分析レポート

**生成日時**: YYYY-MM-DD
**リポジトリ**: 名前
**DB**: PostgreSQL / MySQL / SQLite / 不明
**スキーマソース**: db/schema.rb / prisma/schema.prisma / etc.
**テーブル総数**: N

## テーブル一覧（ドメイン別）

| ドメイン | テーブル数 | 主要テーブル |
|---------|----------|------------|
| 認証・認可 | 5 | users, roles, ... |
| コアビジネス | 12 | orders, products, ... |
| ... | ... | ... |

## ドメイン詳細

### 1. [ドメイン名]

[概要]

#### テーブル構造
[各テーブルの説明]

#### リレーション図
[Mermaid ER図]

#### 典型的なSQL
[3〜5個のクエリ例]

---

### 2. [次のドメイン名]
...

## クロスドメイン分析

### ドメイン間リレーションマップ
[Mermaid図]

### 集約境界の推定
[DDD的な分析]

### 注目ポイント
[特殊パターンの指摘]
```

---

## 実行ガイドライン

- スキーマは全量読み込む。スキーマだけはケチらない。
  テーブル定義を部分的に読むと、ドメイン間のリレーションを見落とす。
- SQL例はそのプロジェクトで実際に使われそうな実用的なものにする。
  教科書的な `SELECT * FROM users` ではなく、
  ビジネスロジックが透けて見えるクエリを書く。
- ドメイン分類に迷ったら、外部キー関係を最優先の判断基準にする。
  テーブル名の推測だけでは誤分類しやすい。
- テーブル数が100を超える場合は、まずドメイン分類の概要を示し、
  詳細分析は主要ドメイン（テーブル数上位5〜7ドメイン）に絞る。
  残りは付録で一覧だけ記載する。
- Serenaが利用可能なら、モデルクラスのメソッド一覧取得に積極的に使う。
  スキーマからは読めない「ビジネスロジック」が見えてくる。
