# VSCode Neovim Integration Notes

English | [日本語](vscode-neovim-use-ja.md)

Current state and caveats for using VSCode's Neovim extension
(`asvetliakov.vscode-neovim`, managed via
`tools/vscode/extensions.txt`).

## How it works

The VSCode Neovim extension launches `nvim --embed` inside VSCode and
delegates normal mode / visual mode / vim motion to nvim. Insert mode,
syntax highlighting, and LSP normally stay on the VSCode side.

* VSCode owns: syntax highlight, LSP, completion, debugging, insert
  mode
* Neovim owns: normal/visual mode, motion, user keymaps

When nvim is launched via VSCode, the `vim.g.vscode` flag is set
beforehand, so branching in `init.lua` lets you trim things down for
VSCode.

## Current behavior

The current `tools/nvim/init.lua` does not branch on `vim.g.vscode`.
As a result, the VSCode-launched nvim still runs:

* lazy.nvim bootstrap (with the initial clone on first run)
* Evaluation of every spec under `tools/nvim/lua/plugins/*`
* Eager load of `lazy = false` plugins (solarized-osaka,
  nvim-treesitter, nvim-lspconfig)

In practice, the VSCode Neovim extension works fine (vim motion is
functional), but the following overhead exists:

* nvim startup is slower by the number of plugins
* nvim-lspconfig attempts to attach (potentially running alongside
  VSCode's LSP)
* nvim-cmp's completion popup does not collide with VSCode's
  suggestions (the VSCode Neovim extension hands insert mode back to
  VSCode, so nvim-cmp's trigger never fires)

If the duplicated LSP bothers you, stop nvim's side manually with
`:LspStop`, or remove the matching LSP server binary from mise / brew
for the project.

## Comparison with standalone nvim

| Feature | standalone nvim | VSCode + Neovim extension |
|---|---|---|
| Syntax highlight | nvim-treesitter / vim builtin | VSCode native |
| LSP | nvim-lspconfig + nvim-cmp | VSCode's LSP extensions |
| Completion | nvim-cmp | VSCode IntelliSense |
| File explorer | nvim-tree (`:nt`) | VSCode Explorer |
| Git | gitsigns.nvim | VSCode Git + GitLens |
| vim motion | yes | yes |
| user keymap | defined in `tools/nvim/lua/mappings.lua` | same |

## Verification

Whether the nvim extension is running inside VSCode:

```vim
:echo exists('g:vscode')   ⇒ 1 (via VSCode) or 0 (standalone)
```

Whether LSP is attached in standalone nvim (with the target buffer
open):

```vim
:checkhealth vim.lsp       ⇒ check the Active Clients section
```

## Known improvement candidates

* Add `if vim.g.vscode then return end` at the top of `init.lua` to
  skip every plugin during VSCode launches. This noticeably speeds up
  startup. However, vim motion still needs user keymaps and options,
  so a design that loads only `lua/options.lua` and
  `lua/mappings.lua` is preferred.
* Another option is to set `vscode-neovim.neovimInitVimPaths` on the
  VSCode side and keep a separate minimal init file for VSCode.

## See also

* [VSCode Neovim Extension](https://github.com/vscode-neovim/vscode-neovim)
* [`docs/vscode-use.md`](./vscode-use.md) — VSCode operations overall
* [`docs/design-philosophy.md`](./design-philosophy.md) — dotfiles
  design philosophy
