# フレームワーク別スキーマ発見パターン

フェーズ4（データ層）用のリファレンス。検出されたスタックに該当するセクションだけを読むこと。

## 目次
- Ruby on Rails
- Node.js（Prisma / TypeORM / Sequelize / Knex）
- Go（GORM / sqlx / ent）
- Python（Django / SQLAlchemy / Alembic）
- Java/Kotlin（JPA / Hibernate / Flyway）

---

## Ruby on Rails

**スキーマソース**: `db/schema.rb`（自動生成）または `db/structure.sql`

**モデル**: `app/models/*.rb`
```bash
# 全モデルのアソシエーション一覧
grep -rn "belongs_to\|has_many\|has_one\|has_and_belongs_to_many" app/models/ | sort
# STI（Single Table Inheritance）の検出
grep -rn "self.table_name\|self.inheritance_column" app/models/
# スコープの検出
grep -rn "scope :" app/models/ | head -20
# バリデーションの検出
grep -rn "validates\|validate " app/models/ | head -20
```

**マイグレーション**: `db/migrate/`
```bash
# 直近のマイグレーション（最新10件）
ls -t db/migrate/ | head -10
```

**Concern/Mixin**: `app/models/concerns/`

---

## Node.js — Prisma

**スキーマソース**: `prisma/schema.prisma`
```bash
# 全モデル
grep "^model " prisma/schema.prisma
# リレーション
grep -A2 "@relation" prisma/schema.prisma
# Enum
grep "^enum " prisma/schema.prisma
```

**マイグレーション**: `prisma/migrations/`

---

## Node.js — TypeORM

**エンティティ**: `**/entities/*.ts` または `**/*.entity.ts`
```bash
find . -name "*.entity.ts" -not -path '*/node_modules/*'
# リレーション
grep -rn "@ManyToOne\|@OneToMany\|@ManyToMany\|@OneToOne" --include="*.entity.ts"
# 特殊な型のカラム
grep -rn "@Column\|@PrimaryGeneratedColumn\|@CreateDateColumn" --include="*.entity.ts" | head -30
```

**マイグレーション**: 通常 `src/migrations/` または `migrations/`

---

## Node.js — Sequelize

**モデル**: `**/models/*.js` または `**/models/*.ts`
```bash
find . -path "*/models/*" -name "*.js" -o -name "*.ts" | grep -v node_modules
grep -rn "belongsTo\|hasMany\|hasOne\|belongsToMany" --include="*.js" --include="*.ts" | grep -v node_modules
```

---

## Node.js — Knex

**マイグレーション**: `migrations/` または `db/migrations/`
```bash
find . -path "*/migrations/*" -name "*.js" -o -name "*.ts" | grep -v node_modules | sort | tail -10
```

---

## Go — GORM

```bash
# gormタグを持つstruct定義を探す
grep -rn 'gorm:"' --include="*.go" | head -20
# モデルstructを探す
grep -rn "type.*struct" --include="*.go" | grep -iv test | head -30
```

## Go — ent

```bash
# スキーマ定義
find . -path "*/ent/schema/*" -name "*.go"
```

---

## Python — Django

**モデル**: `**/models.py` または `**/models/*.py`
```bash
find . -name "models.py" -not -path '*/venv/*' -not -path '*/.venv/*'
grep -rn "class.*models.Model" --include="*.py" | grep -v venv
# リレーション
grep -rn "ForeignKey\|ManyToManyField\|OneToOneField" --include="*.py" | grep -v venv | head -20
```

**マイグレーション**: `**/migrations/`

---

## Python — SQLAlchemy / Alembic

```bash
# モデル
grep -rn "class.*Base\|DeclarativeBase\|declarative_base" --include="*.py" | grep -v venv
# Alembicマイグレーション
find . -path "*/alembic/versions/*" -name "*.py" | sort | tail -10
```

---

## Java/Kotlin — JPA/Hibernate

```bash
# エンティティ
grep -rn "@Entity" --include="*.java" --include="*.kt" | head -20
# リレーション
grep -rn "@ManyToOne\|@OneToMany\|@ManyToMany\|@OneToOne" --include="*.java" --include="*.kt" | head -20
```

**マイグレーション**: Flyway（`db/migration/`）または Liquibase（`db/changelog/`）
