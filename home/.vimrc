set encoding=utf-8
set runtimepath^=~/.vim/
" let g:python3_host_prog = $PYENV_ROOT.'/shims/python3'

" vim-plug
" Specify a directory for plugins
" - For Neovim: ~/.local/share/nvim/plugged
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')
Plug 'neoclide/coc.nvim', { 'branch': 'release' } " Extensions: https://github.com/neoclide/coc.nvim#extensions
Plug 'scrooloose/nerdtree'
Plug 'Shougo/unite.vim'
Plug 'Shougo/vimproc.vim', { 'do' : 'make' }
Plug 'vim-syntastic/syntastic'
Plug 'mtscout6/syntastic-local-eslint.vim'
Plug 'tpope/vim-surround'
Plug 'alvan/vim-closetag'
Plug 'rizzatti/dash.vim'
Plug 'rking/ag.vim'
Plug 'airblade/vim-gitgutter'
Plug 'szw/vim-tags'
Plug 'simeji/winresizer'
Plug 'tpope/vim-endwise'
Plug 'pangloss/vim-javascript', { 'for': ['javascript.jsx'] }
Plug 'maxmellon/vim-jsx-pretty', { 'for': ['javascript.jsx', 'typescript.tsx'] }
Plug 'kchmck/vim-coffee-script', { 'for': 'coffeescript' }
Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }
Plug 'vim-jp/vim-cpp', { 'for': 'clang' }
Plug 'justmao945/vim-clang', { 'for': 'clang' }
Plug 'slim-template/vim-slim', { 'for': 'slim' }
Plug 'digitaltoad/vim-jade', { 'for': 'jade' }
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries', 'for': 'go' }
" Plug 'leafgarland/typescript-vim'
" Plug 'peitalin/vim-jsx-typescript'
Plug 'plasticboy/vim-markdown', { 'for': 'markdown' }
Plug 'kannokanno/previm', { 'for': 'markdown' }
Plug 'tyru/open-browser.vim', { 'for': 'markdown' }
Plug 'lambdalisue/vim-pyenv', { 'for': 'python' }
" Plug 'davidhalter/jedi-vim'
Plug 'rust-lang/rust.vim', { 'for': 'rust' }
Plug 'racer-rust/vim-racer', { 'for': 'rust' }
Plug 'mechatroner/rainbow_csv', { 'for': 'csv' }
Plug 'udalov/kotlin-vim', { 'for': 'kotlin' }
Plug 'tpope/vim-rails', { 'for': 'ruby' }
Plug 'hashivim/vim-terraform', { 'for': 'terraform' }
Plug 'jparise/vim-graphql'
Plug 'aklt/plantuml-syntax'
Plug 'prettier/vim-prettier', {
  \ 'do': 'yarn install',
  \ 'branch': 'release/1.x',
  \ 'for': ['javascript.jsx', 'typescript.tsx', 'css', 'scss', 'json', 'markdown', 'html', 'yaml'] }
call plug#end() " Initialize plugin system

" Colorscheme and syntax
" Refer to https://github.com/altercation/vim-colors-solarized/blob/master/README.mkd
let g:solarized_termtrans=1

filetype plugin indent on " Automatically detect file types.
syntax enable

" Use new regular expression engine
" https://jameschambers.co.uk/vim-typescript-slow
set re=0

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

" Indent, Tab, Space
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set smartindent
set backspace=indent,eol,start
set cursorcolumn

highlight CursorColumn ctermbg=darkgray

inoremap {<Enter> {}<Left><CR><ESC><S-o>
inoremap [<Enter> []<Left><CR><ESC><S-o>
inoremap (<Enter> ()<Left><CR><ESC><S-o>

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
set clipboard+=unnamed,autoselect

" Cron
set backupskip+=/home/tmp/*,/private/tmp/*

" nerdtree:
" Open nerdtree automatically
" autocmd vimenter * if !argc() | NERDTree | endif
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

" closetag.vim
" filenames like *.xml, *.html, *.xhtml, ...
" These are the file extensions where this plugin is enabled.
let g:closetag_filenames = '*.html,*.xhtml,*.jsx,*.tsx'
" filenames like *.xml, *.xhtml, ...
" This will make the list of non-closing tags self-closing in the specified files.
" let g:closetag_xhtml_filenames = '*.xhtml,*.jsx'
" integer value [0|1]
" This will make the list of non-closing tags case-sensitive (e.g. `<Link>` will be closed while `<link>` won't.)
let g:closetag_emptyTags_caseSensitive = 1
" dict
" Disables auto-close if not in a "valid" region (based on filetype)
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

" Unite
" Shortcuts
nnoremap <silent> ,ub :<C-u>Unite file buffer<CR>
nnoremap <silent> ,uf  :<C-u>Unite -start-insert file_rec/async<CR>
nnoremap <silent> ,ufn  :<C-u>Unite -start-insert file/new<CR>
nnoremap <silent> ,ug  :<C-u>Unite grep -buffer-name=search-buffer<CR>
nnoremap <silent> ,ur :<C-u>Unite -buffer-name=register register<CR>

let g:unite_source_rec_max_cache_files = 3000
" let g:unite_enable_start_insert=1 " Starts with insert-mode
" let g:unite_source_history_yank_enable = 1
if executable('ag')
  let g:unite_source_grep_command = 'ag'
  let g:unite_source_grep_default_opts = '--nogroup --nocolor --column'
  let g:unite_source_grep_recursive_opt = ''
endif
try
  let g:unite_source_rec_async_command='ag --nocolor --nogroup -g ""'
  call unite#filters#matcher_default#use(['matcher_fuzzy'])
catch
endtry
