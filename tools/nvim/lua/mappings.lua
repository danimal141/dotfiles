local map = vim.keymap.set

map("n", ";", ":", { noremap = true })
map("n", ":", ";", { noremap = true })

map("i", "{<CR>", "{}<Left><CR><ESC><S-o>", { noremap = true })
map("i", "(<CR>", "()<Left><CR><ESC><S-o>", { noremap = true })
map("i", "[<CR>", "[]<Left><CR><ESC><S-o>", { noremap = true })

-- :nt を NvimTreeOpen の短縮 Ex command として登録。
-- getcmdline() と完全一致した時のみ展開して :ntfoo 等の誤展開を防ぐ。
vim.cmd([[
  cnoreabbrev <expr> nt (getcmdtype()==':' && getcmdline()==#'nt') ? 'NvimTreeOpen' : 'nt'
]])
