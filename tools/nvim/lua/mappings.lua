local map = vim.keymap.set

map("n", ";", ":", { noremap = true })
map("n", ":", ";", { noremap = true })

map("i", "{<CR>", "{}<Left><CR><ESC><S-o>", { noremap = true })
map("i", "(<CR>", "()<Left><CR><ESC><S-o>", { noremap = true })
map("i", "[<CR>", "[]<Left><CR><ESC><S-o>", { noremap = true })
