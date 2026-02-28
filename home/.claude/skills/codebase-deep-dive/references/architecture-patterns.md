# アーキテクチャパターン検出ガイド

フェーズ2（アーキテクチャマップ）用のリファレンス。
以下のヒューリスティクスを使って、使用されているアーキテクチャパターンを特定する。

## クイック検出マトリクス

| シグナル | パターン |
|----------|----------|
| `app/models/`, `app/controllers/`, `app/views/` | MVC（Rails系） |
| `domain/`, `application/`, `infrastructure/` | クリーンアーキテクチャ / DDD |
| `features/X/`, `modules/X/`（各々にmodel+view+controller） | フィーチャーベース |
| `packages/`, `apps/` がルートにある | モノレポ |
| `services/`, `microservices/` | サービス指向 |
| `pages/`, `app/` + `api/` ルート | Next.js / フルスタックJS |
| `cmd/`, `internal/`, `pkg/` | Go標準レイアウト |
| `src/main/`, `src/test/` | Java/Gradle/Maven |

## モノレポ検出

```bash
# Turborepo
ls turbo.json 2>/dev/null
# Nx
ls nx.json 2>/dev/null
# Lerna
ls lerna.json 2>/dev/null
# pnpm workspaces
grep "packages" pnpm-workspace.yaml 2>/dev/null
# yarn workspaces
jq '.workspaces' package.json 2>/dev/null
```

## サービス間通信の検出

```bash
# REST/HTTPによるサービス間呼び出し
grep -rn "localhost:\|127.0.0.1:\|service_url\|SERVICE_URL\|INTERNAL_API" \
  --include="*.rb" --include="*.ts" --include="*.go" --include="*.py" \
  | grep -v test | grep -v node_modules | head -20

# gRPC
find . -name "*.proto" | head -10

# メッセージキュー
grep -rn "SQS\|RabbitMQ\|Kafka\|NATS\|Redis.*pub\|Redis.*sub\|Sidekiq\|Bull\|BullMQ" \
  --include="*.rb" --include="*.ts" --include="*.js" --include="*.go" --include="*.py" \
  | grep -v node_modules | grep -v test | head -20

# イベント駆動
grep -rn "EventEmitter\|emit(\|on(\|subscribe\|publish\|ActiveSupport::Notifications" \
  --include="*.rb" --include="*.ts" --include="*.js" \
  | grep -v node_modules | grep -v test | head -20
```

## インフラパターン

```bash
# コンテナオーケストレーション
ls docker-compose.yml docker-compose.*.yml 2>/dev/null
ls -d k8s/ kubernetes/ helm/ charts/ 2>/dev/null

# IaC（Infrastructure as Code）
ls -d terraform/ infra/ infrastructure/ cdk/ 2>/dev/null
find . -name "*.tf" -maxdepth 3 | head -5

# CI/CD
ls .github/workflows/*.yml .gitlab-ci.yml .circleci/config.yml Jenkinsfile 2>/dev/null

# サーバーレス
ls serverless.yml sam-template.yaml 2>/dev/null
find . -name "*.lambda.*" -o -name "*handler*" | grep -v node_modules | head -10
```

## よくあるアンチパターン（フラグすべきもの）

- **神クラス/神ファイル**: ソースファイルが500行を超えるもの
- **循環依存**: サービスが互いにインポートし合っている
- **関心事の混在**: コントローラ/ハンドラ内にDBクエリが直接書かれている
- **抽象化の欠如**: SDK呼び出し（AWS、Stripeなど）がサービスクラスにラップされず
  ビジネスロジック全体に散在している
- **設定の散乱**: 環境変数が集中的なconfigモジュールではなく、
  多数のファイルから直接参照されている
