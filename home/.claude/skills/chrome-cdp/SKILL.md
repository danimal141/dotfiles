---
name: chrome-cdp
description: >
  ローカルのChromeブラウザセッションと対話するスキル。
  ユーザーがChromeで開いているページの検査、デバッグ、操作を明示的に依頼した場合にのみ使用する。
  「ブラウザを見て」「ページを確認して」「スクリーンショットを撮って」
  「Chromeのタブを操作して」「アクセシビリティツリーを見せて」
  「この要素をクリックして」「ページを開いて」などのリクエストで発動する。
  "inspect the page", "take a screenshot", "check the browser",
  "click this element", "debug in Chrome" でも発動する。
---

# Chrome CDP

軽量なChrome DevTools Protocol CLI。WebSocketで直接接続する。
Puppeteer不要、100以上のタブに対応、即座に接続。

## 前提条件

* Chrome（またはChromium、Brave、Edge、Vivaldi）でリモートデバッグが有効化されていること：
  `chrome://inspect/#remote-debugging` を開いてスイッチをONにする
* Node.js 22以上（組み込みのWebSocketを使用）
* ブラウザの `DevToolsActivePort` が標準外の場所にある場合は、
  `CDP_PORT_FILE` 環境変数にフルパスを設定する

## コマンド

すべてのコマンドは `scripts/cdp.mjs` を使用する。
`<target>` は `list` で表示されるtargetIdの一意なプレフィックス。
`list` の出力に表示される完全なプレフィックスをコピーして使う（例: `6BE827FA`）。
CLIは曖昧なプレフィックスを拒否する。

### 開いているページの一覧表示
scripts/cdp.mjs list

### スクリーンショットの撮影
scripts/cdp.mjs shot <target> [file]

ビューポートのみをキャプチャする。折り返し以下のコンテンツが必要な場合は、
先に `eval` でスクロールすること。
出力にはページのDPRと座標変換のヒントが含まれる（下記「座標系」を参照）。

### アクセシビリティツリーのスナップショット
scripts/cdp.mjs snap <target>

### JavaScriptの実行
scripts/cdp.mjs eval <target> <expr>

> 注意: DOM が変化しうる複数の `eval` 呼び出しにまたがって
> インデックスベースの選択（`querySelectorAll(...)[i]`）を使用しないこと。

### その他のコマンド
scripts/cdp.mjs html    <target> [selector]
scripts/cdp.mjs nav     <target> <url>
scripts/cdp.mjs net     <target>
scripts/cdp.mjs click   <target> <selector>
scripts/cdp.mjs clickxy <target> <x> <y>
scripts/cdp.mjs type    <target> <text>
scripts/cdp.mjs loadall <target> <selector> [ms]
scripts/cdp.mjs evalraw <target> <method> [json]
scripts/cdp.mjs open    [url]
scripts/cdp.mjs stop    [target]

## 座標系
`shot` はネイティブ解像度で画像を保存する：画像ピクセル = CSSピクセル × DPR。
CDPの入力イベント（`clickxy` 等）は CSSピクセル を受け取る。
CSSピクセル = スクリーンショットの画像ピクセル / DPR

## Tips
* ページ構造の把握には `html` より `snap --compact` を優先する。
* クロスオリジンiframe内のテキスト入力には `type` を使う（evalではなく）。
  先に `click` / `clickxy` でフォーカスしてから `type` する。
* Chromeはタブへの初回アクセス時に「デバッグを許可」モーダルを1回表示する。
