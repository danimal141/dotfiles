---
name: companion-reading
allowed-tools: Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, Bash(python:*), Bash(python3:*), Bash(pip:*), Bash(ls:*), Bash(cat:*)
description: >
  Interactive companion reading skill for technical books (O'Reilly, etc.) from PDF input.
  Sets reading goals with the user, reads chapter-by-chapter with Q&A dialogue, and produces
  a structured Markdown learning document tied to the stated purpose.
  Use this skill whenever the user uploads a technical book PDF and wants a summary, digest,
  book notes, reading notes, or learning extraction. Also trigger when the user says things like
  "この本をまとめて", "要点を抽出して", "読書メモを作って", "book summary", "chapter summary",
  "技術書の要約", "一緒に読んで", "伴走して", or any request to systematically break down a book PDF into learnings.
  Even if the user just uploads a PDF that looks like a technical book and asks to "summarize" it,
  use this skill.
---

# Book Digest Skill（伴走型読書）

技術書PDFを対話しながら読み解き、利用者の学習目的に紐づいたMarkdownドキュメントを生成するSkill。

## Overview

このSkillは以下の流れで技術書を処理する：

1. **準備・目次抽出** — PDFから目次を取得し、書籍の構造を把握
2. **Web検索による全体像把握** — タイトル・目次をもとにWeb検索して本の主旨・背景を収集
3. **読書目的のヒアリング** — 本の主旨を利用者に伝え、学びたいことをインタラクティブに設定
4. **章ごとの伴走読書** — 各章を読み、目的に沿ったサマリを提示→質疑応答
5. **学びの統合・Markdown出力** — 対話を通じた学びを目的と紐づけ、構造的なドキュメントに仕上げる

---

## Step 0: 準備

ユーザーが添付したPDFファイルを受け取る。添付ファイルは `/mnt/user-data/uploads/` に保存される。

```bash
ls /mnt/user-data/uploads/
```

ファイル名を確認し、以降の手順では `PDF_PATH=/mnt/user-data/uploads/<ファイル名>` として参照する。
PDFが添付されていない場合は、ユーザーにPDFファイルの添付を依頼する。

必要なライブラリがインストール済みか確認する：

```bash
python3 -c "import pdfplumber; print('pdfplumber OK')" 2>/dev/null || echo "pdfplumber NOT FOUND"
```

インストールされていない場合はユーザーに確認を取ってからインストールする：

```bash
pip install pdfplumber --break-system-packages
```

---

## Step 1: 目次の抽出と書籍タイトルの取得

`scripts/extract_toc.py` を使って目次を抽出する。

```bash
python /path/to/skills/companion-reading/scripts/extract_toc.py "$PDF_PATH" --output /tmp/toc.json
cat /tmp/toc.json
```

抽出した `title`、`author`、`chapters` リストを確認する。
タイトルが取れない場合はPDFの先頭数ページを読んで推定する。

---

## Step 2: Web検索による本の主旨把握

目次とタイトルをもとにWeb検索を行い、本の概要・主旨・背景を収集する。

### 検索クエリの例
* `"[書籍タイトル]" 概要 主旨 著者`
* `"[書籍タイトル]" review summary what is this book about`
* `[著者名] [書籍タイトル] key message`

### 把握すべき情報
* 書籍が生まれた背景・問題意識
* 著者が伝えたいコアメッセージ
* 対象読者と前提知識
* 業界での位置づけ・評価

検索結果をもとに「この本の主旨」を2〜4文で要約し、次のステップでユーザーに伝える。

---

## Step 3: 読書目的のヒアリング

ユーザーに本の主旨を伝え、この本を通して学びたいことをヒアリングする。

### ユーザーへの提示例

```
「[書籍タイトル]」（著者: [著者名]）の概要を把握しました。

この本は〜という問題意識から書かれており、〜をコアメッセージとしています。
対象読者は〜で、〜の分野で広く参照されています。

目次は以下の通りです：
- 第1章: [タイトル]
- 第2章: [タイトル]
...

この本を読む目的や、特に学びたいことを教えてください。
例: 「マイクロサービスの設計パターンを実務に活かしたい」
    「チームへの導入判断の材料にしたい」
    「特定の章（3章・5章）だけ深く理解したい」
```

ユーザーの回答をもとに **読書目的** を確定する。
複数の目的がある場合は優先順位を確認する。

---

## Step 4: 章ごとの伴走読書

確定した読書目的をベースに、各章を順番に読み解く。

### 処理フロー（1章ごとに繰り返す）

**4-1. テキスト抽出**

```bash
python /path/to/skills/companion-reading/scripts/extract_chapter.py "$PDF_PATH" <start_page> <end_page>
```

**4-2. 目的に沿ったサマリを提示**

以下の構成でユーザーに説明する：

```
【第N章: [章タイトル]】

▍この章の概要
[1〜2文で章の目的と範囲]

▍読書目的「[ユーザーが設定した目的]」との関連
[目的と章の内容の接点を具体的に説明]

▍この章の主要な学び
* [学び1]: [説明]
* [学び2]: [説明]
* [学び3]: [説明]

▍著者の核心的な主張
[著者が最も伝えたいこと]

▍実践への示唆
* [目的に関連した具体的なアクション]
```

**4-3. ディスカッション**

サマリ提示後、読書目的と章の内容を踏まえたディスカッションの問いを2〜3個提示する。
問いは「自分ごと化」「批判的思考」「実践」の3軸を意識して選ぶ：

```
【この章を深めるための問い】

* [自分ごと化] 例: 「この章で紹介された〜は、あなたの現在のプロジェクトのどの場面で当てはまりますか？」
* [批判的思考] 例: 「著者の主張する〜に対して、あなたは賛成・反対どちらですか？その理由は？」
* [実践]       例: 「この章の内容を明日から取り入れるとしたら、最初の一歩は何になりそうですか？」

質問・感想があればお聞かせください。
準備ができたら「次へ」で次の章に進みます。
```

問いはその章の内容と読書目的に即して具体的に作る（汎用的な問いにしない）。
ユーザーの回答に対して丁寧に応答し、対話を深める。
「次へ」の合図があるまで次の章には進まない。

**4-4. 章の学びを記録**

対話の中で得られた気づきや補足もサマリに追記する形で内部記録する（最終出力に反映）。

### スキップ・重点化の対応

ユーザーが「この章は軽くでいい」「この章は詳しく」と言った場合は、
深さを調整して対応する。

---

## Step 5: 統合サマリと Markdown 出力

全章（またはユーザーが指定した章）の伴走が終わったら、最終ドキュメントを生成する。

### ドキュメント構造

```markdown
# [書籍タイトル] — 読書ノート

著者: [著者名]
読了日: [今日の日付]

## 読書の目的

[Step 3で設定した読書目的]

## この本の主旨

[Step 2で収集・要約した本の主旨・背景]

## 目次

[章番号と章タイトルの一覧]

---

## 章ごとの学び

### 第1章: [章タイトル]

#### 概要
[章の概要]

#### 読書目的との関連
[目的との接点]

#### 主要な学び
* [学び]: [説明]

#### 対話から得た気づき
[Q&A・対話で深まった理解や補足]

---

[以降の章も同様]

---

## 読書目的への回答

[設定した読書目的に対して、本全体を通じて得た答え・知見を整理]

## 横断テーマと構造的な理解

[複数章にまたがる重要テーマ・パターン]

## 次のアクション

* [ ] [明日から実践できること]
* [ ] [さらに調べたいトピック]
* [ ] [チームや業務に持ち帰ること]

## 関連資料・発展的な学習

[本書で言及された参考資料、関連書籍など]
```

### 出力先

ファイルを `/Users/danimal141/Documents/Obsidian/hideaki_ishii_main_vault/notes/ai_reading_logs/` に保存する。
ファイル名は `[YYYYMMDD]_[書籍タイトル].md` とする（例: `20260316_Designing Data-Intensive Applications.md`）。
日付は処理実行時の実際の日付を使用する。

---

## 注意事項

* 著作権: 原文の直接引用は最小限に留め、すべて自分の言葉で要約する
* 対話優先: ユーザーが「次へ」と言うまで次の章に進まない
* 目的への紐づけ: 常に設定した読書目的を意識し、関連が薄い箇所は軽く、関連が深い箇所は丁寧に扱う
* ページ推定: PDF構造によっては目次のページ番号とPDF物理ページ番号がずれることがある。`page_offset` を使って調整する
* 言語: 書籍が英語・その他言語であっても、サマリ・ディスカッションの問い・最終Markdownドキュメントをすべて日本語で出力する。書名・人名・技術用語など固有名詞は原語のまま使用してよい
* 進捗報告: 各章の処理開始時に進捗を報告する（例: "第3章 / 全12章 を処理中..."）
