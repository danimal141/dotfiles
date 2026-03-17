# キュレーション済みソースリスト

信頼できるテック・AI情報ソースのキュレーション済みリスト。
レポート生成時は、指定期間の情報を収集するためにこれらのソースを横断的に検索する。

## 検索戦略

各ソースカテゴリについて、ソース名・ドメインにユーザーの日付範囲と関連キーワード
（「AI」「LLM」「機械学習」「リリース」「ローンチ」など）を組み合わせた
ターゲット検索クエリを構築する。

- web_search呼び出しは合計15〜20回。個人ブログとarxivに重点配分する
- 二次報道より一次ソース（公式ブログ、arxiv）を優先
- 個人ブログはURLではなく、著者名＋トピックで検索
- 検索結果収集後、最も有望なURLにweb_fetchを使用してより詳しいコンテキストを取得
- 古い結果を避けるため、検索クエリには必ず年を含める

## ソースカテゴリと検索パターン

### カテゴリ1：テックメディア（総合ニュース）

| ソース | ドメイン | 検索クエリパターン |
|--------|---------|-------------------|
| TechCrunch | techcrunch.com | `TechCrunch AI {トピック} {月} {年}` |
| The Verge | theverge.com | `The Verge AI {トピック} {月} {年}` |
| Ars Technica | arstechnica.com | `Ars Technica AI {トピック} {月} {年}` |
| Wired | wired.com | `Wired AI {トピック} {月} {年}` |
| VentureBeat | venturebeat.com | `VentureBeat AI {トピック} {月} {年}` |

最適な用途：速報ニュース、製品ローンチ、資金調達、業界の動き。

### カテゴリ2：AI・研究特化メディア

| ソース | ドメイン | 検索クエリパターン |
|--------|---------|-------------------|
| MIT Technology Review | technologyreview.com | `MIT Technology Review AI {月} {年}` |
| Stanford HAI AI Index | aiindex.stanford.edu | `Stanford HAI AI {トピック} {年}` |
| Hugging Face Blog | huggingface.co/blog | `Hugging Face blog {月} {年}` |
| Papers With Code | paperswithcode.com | `Papers With Code SOTA {月} {年}` |

最適な用途：研究ブレイクスルー、ベンチマーク、モデルリリース、学術トレンド。

### カテゴリ2b：arxiv・論文ソース

arxivは単独カテゴリとして重点的に扱う。検索クエリを複数パターン用意し、
話題になった論文を漏らさず拾うことが目標。

| ソース | ドメイン | 検索クエリパターン |
|--------|---------|-------------------|
| arXiv（LLM・言語モデル） | arxiv.org | `arxiv LLM language model {月} {年}` |
| arXiv（エージェント・推論） | arxiv.org | `arxiv AI agent reasoning {月} {年}` |
| arXiv（効率化・学習手法） | arxiv.org | `arxiv efficient training fine-tuning {月} {年}` |
| arXiv（マルチモーダル） | arxiv.org | `arxiv multimodal vision language {月} {年}` |
| Hugging Face Daily Papers | huggingface.co/papers | `Hugging Face daily papers trending {月} {年}` |
| Semantic Scholar | semanticscholar.org | `Semantic Scholar influential AI paper {月} {年}` |

検索戦略：
- arxivは分野ごとに2〜3クエリを割り当て、合計4〜6クエリを使用
- Hugging Face Daily Papersはコミュニティの注目度指標として活用
- 論文は「引用数」より「実務者コミュニティでの反響」を重視して選定
- 可能な限りarxiv IDとリンクを記録する

最適な用途：最新研究の一次情報、実験結果、新手法の提案。

### カテゴリ3：企業公式ブログ

| ソース | ドメイン | 検索クエリパターン |
|--------|---------|-------------------|
| Google AI Blog | blog.google/technology/ai | `Google AI blog announcement {月} {年}` |
| OpenAI Blog | openai.com/blog | `OpenAI blog release {月} {年}` |
| Anthropic Blog | anthropic.com/news | `Anthropic blog Claude {月} {年}` |
| Meta AI Blog | ai.meta.com/blog | `Meta AI blog Llama {月} {年}` |

最適な用途：一次発表、モデルリリース、安全性研究、API更新。

### カテゴリ4：ビジネス・経済視点

| ソース | ドメイン | 検索クエリパターン |
|--------|---------|-------------------|
| Fortune AI Section | fortune.com | `Fortune AI business {月} {年}` |
| Bloomberg Technology | bloomberg.com/technology | `Bloomberg AI technology {月} {年}` |
| The Information | theinformation.com | `The Information AI {月} {年}` |

最適な用途：市場分析、M&A、投資トレンド、エンタープライズ導入。

### カテゴリ5：個人エンジニアブログ＆ニュースレター

#### 5a：AI・MLフォーカスの個人ブログ（最重要）

このサブカテゴリはレポートの「生々しさ」を担う。新しいモデルを実際に触った感想、
ファインチューニングの実験結果、エージェント構築の試行錯誤など、メディアでは
拾えない現場の温度感を提供する。

| 著者 | ブログURL | 専門領域 |
|------|----------|---------|
| Simon Willison | simonwillison.net | LLM実験、オープンソースAIツール、実践的AI。新モデルを即座に試して所感を書く |
| Andrej Karpathy | karpathy.bearblog.dev | AI教育、LLMトレンド、ディープラーニングの本質的解説 |
| Lilian Weng | lilianweng.github.io | AI研究サーベイ、エージェント、安全性。論文の体系的整理 |
| Sebastian Raschka | sebastianraschka.com | LLM研究、推論モデル、学習手法。論文読解と実験再現 |
| Chip Huyen | huyenchip.com | MLOps、ML基盤設計、LLMアプリケーション構築の実務 |
| Eugene Yan | eugeneyan.com | 推薦システム、LLMシステム設計、応用MLの実践知 |
| Hamel Husain | hamel.dev | LLMファインチューニング、ML開発ツール、実験レポート |
| swyx (Shawn Wang) | swyx.io | AI Engineer エコシステム、Latent Space、業界マップ作成 |
| Vicki Boykis | vickiboykis.com | ML基盤、検索・推薦、データエンジニアリングとAIの交差点 |
| Jay Alammar | jalammar.github.io | Transformer可視化、LLM内部構造の直感的解説 |
| Gwern Branwen | gwern.net | AI研究の長期分析、スケーリング則、予測・意思決定 |

検索パターン：`"{著者名}" blog {トピック} {月} {年}`
補助パターン：`"{著者名}" LLM experiment {月} {年}`

最適な用途：新モデル・ツールの第一印象、実験結果の共有、実務者の本音。

#### 5b：システム・インフラ系の個人ブログ

| 著者 | ブログURL | 専門領域 |
|------|----------|---------|
| Mitchell Hashimoto | mitchellh.com | 開発ツール、システムプログラミング、AIコーディングエージェント |
| Julia Evans | jvns.ca | Linux、ネットワーキング、低レイヤーシステム |
| Gergely Orosz | newsletter.pragmaticengineer.com | エンジニアリング文化、組織設計、業界トレンド |
| Dan Luu | danluu.com | パフォーマンス、開発者ツール、定量分析 |
| Martin Fowler | martinfowler.com | ソフトウェア設計、アーキテクチャパターン |
| Thorsten Ball | thorstenball.com | エディタ・ツール開発、言語処理系の内部構造 |
| Charity Majors | charity.wtf | オブザーバビリティ、SRE、エンジニアリングマネジメント |
| Brendan Gregg | brendangregg.com | パフォーマンスエンジニアリング、eBPF、Linux内部 |
| Cindy Sridharan | copyconstruct.medium.com | 分散システム、オブザーバビリティ、テスト |
| Rachel Kroll | rachelbythebay.com | システム管理、本番デバッグ、SRE |
| Xe Iaso | xeiaso.net | インフラ、NixOS、AI＋セキュリティ |

検索パターン：`"{著者名}" blog {トピック} {月} {年}`

最適な用途：AI以外のシステム・インフラ動向、AIがインフラに与える影響の実務者視点。

### カテゴリ6：ニュースレター＆ポッドキャスト

| ソース | 著者 | 検索クエリパターン |
|--------|------|-------------------|
| The Batch | Andrew Ng / DeepLearning.AI | `Andrew Ng The Batch {月} {年}` |
| Import AI | Jack Clark | `Import AI newsletter Jack Clark {月} {年}` |

最適な用途：週次キュレーションまとめ、ポリシーの視点、教育コンテンツ。
