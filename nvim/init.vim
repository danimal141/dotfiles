" https://www.baeldung.com/linux/vim-neovim-configs#1-setting-runtimepath-and-packpath
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc

" Load Lua configurations
lua require('telescope-config')
