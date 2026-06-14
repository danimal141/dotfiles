# Web Fetch Strategy

Web コンテンツ取得は次の順で試す。失敗 (403 / timeout / abort) したら次へ進む:

1. **WebFetch tool** — まず標準の WebFetch
2. **curl fallback** — 403 のとき `curl -sL -A "claude-code/1.0" <url>` で再試行。
   多くの 403 は default User-Agent への Cloudflare ブロックが原因
3. **chrome-cdp skill** — 描画やログインが要るページはローカル Chrome を操作する
   chrome-cdp skill を使う
4. **Chrome DevTools / Playwright MCP** — `mcp__chrome-devtools__*` /
   `mcp__playwright__*` でナビゲートして読む

ライブラリ / フレームワーク / SDK の API ドキュメントは、上記より先に
context7 (`mcp__context7__*`) を優先する。
