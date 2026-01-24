set encoding=utf-8
set runtimepath^=~/.vim/

" vim-plug
" Specify a directory for plugins
" - For Neovim: ~/.local/share/nvim/plugged
" - Avoid using standard Vim directory names like 'plugin'

call plug#begin('~/.vim/plugged')
Plug 'Shougo/vimproc.vim', { 'do' : 'make' }
Plug 'tpope/vim-surround'
Plug 'alvan/vim-closetag'
Plug 'jremmen/vim-ripgrep'
Plug 'airblade/vim-gitgutter'
Plug 'szw/vim-tags'
Plug 'preservim/tagbar'
Plug 'simeji/winresizer'
Plug 'tpope/vim-endwise'
" Plug 'github/copilot.vim'

if !exists('g:vscode')
  " Extensions: https://github.com/neoclide/coc.nvim#extensions
  Plug 'scrooloose/nerdtree'
  Plug 'neoclide/coc.nvim', { 'branch': 'release' }
  Plug 'vim-syntastic/syntastic'
  Plug 'mtscout6/syntastic-local-eslint.vim'
  Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries', 'for': 'go' }
  Plug 'rust-lang/rust.vim', { 'for': 'rust' }
  Plug 'racer-rust/vim-racer', { 'for': 'rust' }
  Plug 'justmao945/vim-clang', { 'for': 'clang' }
  Plug 'hashivim/vim-terraform', { 'for': 'terraform' }
  Plug 'prettier/vim-prettier', {
    \ 'do': 'yarn install',
    \ 'branch': 'release/1.x',
    \ 'for': ['javascript.jsx', 'typescript.tsx', 'javascript', 'typescript', 'css', 'scss', 'json', 'markdown', 'html', 'yaml']
  \ }
  \" Syntax highlighting plugins (redundant in VSCode)
  Plug 'pangloss/vim-javascript', { 'for': ['javascript.jsx'] }
  Plug 'maxmellon/vim-jsx-pretty', { 'for': ['javascript.jsx', 'typescript.tsx'] }
  Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }
  Plug 'vim-jp/vim-cpp', { 'for': 'clang' }
  Plug 'slim-template/vim-slim', { 'for': 'slim' }
  Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }
  Plug 'previm/previm'
  Plug 'tyru/open-browser.vim'
  Plug 'udalov/kotlin-vim', { 'for': 'kotlin' }
  Plug 'tpope/vim-rails', { 'for': 'ruby' }
  Plug 'jparise/vim-graphql'
  Plug 'aklt/plantuml-syntax'
  Plug 'mechatroner/rainbow_csv', { 'for': 'csv' }

  " telescope.nvim (Neovim only)
  if has('nvim')
    Plug 'nvim-lua/plenary.nvim'
    Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.8' }
  endif
endif
call plug#end() " Initialize plugin system

" Colorscheme and syntax
" Refer to https://github.com/altercation/vim-colors-solarized/blob/master/README.mkd
let g:solarized_termtrans=1

" Automatically detect file types.
filetype plugin indent on

" Use new regular expression engine
" https://jameschambers.co.uk/vim-typescript-slow
set re=0

syntax enable
set notermguicolors
set background=dark
colorscheme solarized

set number
set notitle
set showmatch
set noswapfile
set eol
set ttyfast
set nobackup
set noswapfile
set noreadonly
set modifiable
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set smartindent
set backspace=indent,eol,start

if !has('nvim')
  set ttymouse=xterm2
endif

" Complementation
" Brackets
inoremap {<Enter> {}<Left><CR><ESC><S-o>
inoremap (<Enter> ()<Left><CR><ESC><S-o>
inoremap [<Enter> []<Left><CR><ESC><S-o>
" https://qiita.com/totto2727/items/d0844c79f97ab601f13b
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<CR>"

" Behaves like IDE
" https://note.com/yasukotelin/n/na87dc604e042
set showmatch
set completeopt=menuone,noinsert

" HighlitTrailingSpaces
augroup HighlightTrailingSpaces
  autocmd!
  autocmd VimEnter,WinEnter,ColorScheme * highlight TrailingSpaces term=underline guibg=Red ctermbg=Red
  autocmd VimEnter,WinEnter * match TrailingSpaces /\s\+$/
augroup END

" Delete Spaces on save
autocmd BufWritePre * :%s/\s\+$//ge

" Search
set incsearch
set ignorecase
set smartcase
set wrapscan

" For clipboard
if has('nvim')
  set clipboard=unnamed
else
  set clipboard=unnamed,autoselect
endif

" nerdtree:
" Display hidden file
let g:NERDTreeShowHidden = 1
" Display nerdtree when opening a new tab
let g:nerdtree_tabs_open_on_new_tab=1

" ctags
" Also should setup:
" https://github.com/tpope/gem-ctags
" https://github.com/tpope/rbenv-ctags
let g:vim_tags_project_tags_command = "/usr/local/bin/ctags -R {OPTIONS} {DIRECTORY} 2>/dev/null"
let g:vim_tags_gems_tags_command = "/usr/local/bin/ctags -R {OPTIONS} `bundle show --paths` 2>/dev/null"

" universal-ctags
" Reference: https://qiita.com/aratana_tamutomo/items/59fb4c377863a385e032
set fileformats=unix,dos,mac
set fileencodings=utf-8,sjis
set tags=.tags;$HOME
let g:vim_tags_main_file = '.tags'

" tagbar
" default: width=40
let g:tagbar_width = 30
let g:tagbar_autoshowtag = 1
nnoremap <silent> tt :TagbarToggle<CR>
set statusline=%F%m%r%h%w\%=%{tagbar#currenttag('[%s]','')}\[Pos=%v,%l]\[Len=%L]

" closetag.vim
let g:closetag_filenames = '*.html,*.xhtml,*.jsx,*.tsx'
let g:closetag_emptyTags_caseSensitive = 1
let g:closetag_regions = {
  \ 'typescript.tsx': 'jsxRegion,tsxRegion',
  \ 'javascript.jsx': 'jsxRegion',
\ }
" Shortcut for closing tags, default is '>'
let g:closetag_shortcut = '>'
" Add > at current position without closing the current tag, default is ''
let g:closetag_close_shortcut = '<leader>>'

" winresizer
let g:winresizer_vert_resize = 2
let g:winresizer_horiz_resize = 2

" vim-prettier
let g:prettier#config#semi = 'false'
let g:prettier#config#single_quote = 'true'
let g:prettier#config#trailing_comma = 'all'

" For US keyboard
nnoremap ; :
nnoremap : ;

" im-select
" when finishing insert mode, automatically swith the keyboard input method
" depends on `google-japanese-ime` and `im-select`
let g:im_select_default = 'com.google.inputmethod.Japanese.Roman'
if executable('im-select')
  autocmd InsertLeave * :call system('im-select com.google.inputmethod.Japanese.Roman')
  autocmd CmdlineLeave * :call system('im-select com.google.inputmethod.Japanese.Roman')
endif

" COC
let g:coc_global_extensions = [
  \ 'coc-yaml',
  \ 'coc-toml',
  \ 'coc-html',
  \ 'coc-htmlhint',
  \ 'coc-git',
  \ 'coc-json',
  \ 'coc-tsserver',
  \ 'coc-solargraph',
  \ 'coc-jedi',
  \ 'coc-rls',
  \ 'coc-go',
  \ 'coc-css',
  \ 'coc-vetur',
  \ 'coc-sh',
  \ 'coc-sql',
  \ 'coc-docker',
  \ 'coc-graphql',
  \ 'coc-dictionary',
  \ 'coc-deno',
  \ 'coc-lists'
\ ]

" How to set ctrl+n and ctrl+p to up or down list

" Neovim uses Telescope (configured in lua/telescope-config.lua)
if !has('nvim')
  nnoremap <C-p> :CocList files <CR>
endif
