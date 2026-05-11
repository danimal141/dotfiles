local map = vim.keymap.set

map("n", ";", ":", { noremap = true })
map("n", ":", ";", { noremap = true })

map("i", "{<CR>", "{}<Left><CR><ESC><S-o>", { noremap = true })
map("i", "(<CR>", "()<Left><CR><ESC><S-o>", { noremap = true })
map("i", "[<CR>", "[]<Left><CR><ESC><S-o>", { noremap = true })

-- :nt 系の短縮 Ex command。getcmdline() と完全一致した時のみ展開して、
-- 似た先頭一致 (例: :ntfoo) との誤展開を防ぐ。
vim.cmd([[
  cnoreabbrev <expr> nt  (getcmdtype()==':' && getcmdline()==#'nt')  ? 'NvimTreeToggle'   : 'nt'
  cnoreabbrev <expr> nto (getcmdtype()==':' && getcmdline()==#'nto') ? 'NvimTreeOpen'     : 'nto'
  cnoreabbrev <expr> ntc (getcmdtype()==':' && getcmdline()==#'ntc') ? 'NvimTreeClose'    : 'ntc'
  cnoreabbrev <expr> ntf (getcmdtype()==':' && getcmdline()==#'ntf') ? 'NvimTreeFindFile' : 'ntf'
]])
