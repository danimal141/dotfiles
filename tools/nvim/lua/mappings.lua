local map = vim.keymap.set

map("n", ";", ":", { noremap = true })
map("n", ":", ";", { noremap = true })

map("i", "{<CR>", "{}<Left><CR><ESC><S-o>", { noremap = true })
map("i", "(<CR>", "()<Left><CR><ESC><S-o>", { noremap = true })
map("i", "[<CR>", "[]<Left><CR><ESC><S-o>", { noremap = true })

-- :nt は「nvim-tree を開く + 全ディレクトリを collapse」をまとめて実行する
-- ユーザー定義コマンドにエイリアスする。初回は collapse 状態で開き、
-- 探索後にもう一度 :nt を叩けば整理された状態にリセットできる。
-- getcmdline() と完全一致した時のみ展開して :ntfoo 等の誤展開を防ぐ。
vim.api.nvim_create_user_command("Nt", function()
  local api = require("nvim-tree.api")
  api.tree.open()
  api.tree.collapse_all()
end, { desc = "Open NvimTree and collapse all directories" })

vim.cmd([[
  cnoreabbrev <expr> nt (getcmdtype()==':' && getcmdline()==#'nt') ? 'Nt' : 'nt'
]])
