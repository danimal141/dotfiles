# VSCode Neovim 連携メモ

VSCode の Neovim extension (`asvetliakov.vscode-neovim`、`tools/vscode/
extensions.txt` で managed) を使うときの現状と注意点。

## 仕組み

VSCode Neovim extension は VSCode 内で `nvim --embed` を起動し、normal
mode / visual mode / vim motion の処理を nvim に委譲する。insert mode と
syntax highlight / LSP は VSCode 側で扱うのが通常の運用。

* VSCode 担当: syntax highlight、LSP、補完、debug、insert mode
* Neovim 担当: normal/visual mode、motion、ユーザー keymap

VSCode 経由で nvim が起動した場合、`vim.g.vscode` flag が事前に set
されるので、init.lua 側で分岐すれば VSCode 用に軽量化できる。

## 現状の挙動

現在の `tools/nvim/init.lua` には `vim.g.vscode` 分岐が入っていない。
そのため VSCode 起動の nvim でも以下が走る:

* lazy.nvim bootstrap (初回 clone あり)
* `tools/nvim/lua/plugins/*` の全 spec を評価
* `lazy = false` の plugin (solarized-osaka, nvim-treesitter, nvim-lspconfig)
  は eager load

実用上は VSCode の Neovim extension は問題なく動く (vim motion は機能)
が、以下のオーバーヘッドがある:

* nvim 起動が plugin 数分だけ遅い
* nvim-lspconfig が attach を試みる (VSCode の LSP と二重に走る可能性)
* nvim-cmp の補完 popup が VSCode の suggest と被ることはない (VSCode
  Neovim extension が insert mode を VSCode 側に渡すため、nvim-cmp の
  trigger 自体が走らない)

LSP 二重起動が気になる場合は `:LspStop` で nvim 側を手動停止、もしくは
project に対応する LSP server バイナリを mise / brew から外す。

## standalone nvim との比較

| 機能 | standalone nvim | VSCode + Neovim extension |
|---|---|---|
| Syntax highlight | nvim-treesitter / vim builtin | VSCode native |
| LSP | nvim-lspconfig + nvim-cmp | VSCode の LSP extension |
| 補完 | nvim-cmp | VSCode IntelliSense |
| File explorer | nvim-tree (`:nt`) | VSCode Explorer |
| Git | gitsigns.nvim | VSCode Git + GitLens |
| vim motion | あり | あり |
| user keymap | `tools/nvim/lua/mappings.lua` で定義 | 同上 |

## 検証

VSCode 内で nvim extension が動いているか:

```vim
:echo exists('g:vscode')   ⇒ 1 (VSCode 経由) または 0 (standalone)
```

standalone nvim で LSP が attach しているか (詳細は対象 buffer を開いた
状態で):

```vim
:checkhealth vim.lsp       ⇒ Active Clients セクションを確認
```

## 既知の改善候補

* `init.lua` 冒頭で `if vim.g.vscode then return end` 分岐を入れて
  VSCode 起動時に plugin 全 skip。これで起動が体感速くなる。
  ただし vim motion 用に必要な user keymap / options だけは残したいので、
  `lua/options.lua` と `lua/mappings.lua` だけは load する設計が望ましい。
* VSCode side で `vscode-neovim.neovimInitVimPaths` を設定して、VSCode
  専用の minimal init を別ファイルに分けるアプローチも選択肢。

## 関連

* [VSCode Neovim Extension](https://github.com/vscode-neovim/vscode-neovim)
* [`docs/vscode-use.md`](./vscode-use.md) — VSCode 全般の運用
* [`docs/design-philosophy.md`](./design-philosophy.md) — dotfiles の設計思想
