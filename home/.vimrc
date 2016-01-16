" NeoBundle
set nocompatible " be iMproved
filetype off

if has('vim_starting')
  set runtimepath+=~/.vim/bundle/neobundle.vim
  call neobundle#rc(expand('~/.vim/bundle/'))
endif

"Plugins
NeoBundle 'Shougo/neobundle.vim'
NeoBundle 'Shougo/unite.vim'
NeoBundle 'Shougo/neocomplcache'
NeoBundle 'Shougo/neosnippet'
NeoBundle 'scrooloose/syntastic'
NeoBundle 'scrooloose/nerdtree'
NeoBundle 'tpope/vim-surround'
NeoBundle 'vim-scripts/closetag.vim'
NeoBundle 'rking/ag.vim'
NeoBundle 'airblade/vim-gitgutter'
NeoBundle 'jelera/vim-javascript-syntax'
NeoBundle 'kchmck/vim-coffee-script'
NeoBundle 'burnettk/vim-angular'
NeoBundle 'vim-ruby/vim-ruby'
NeoBundle 'vim-jp/vim-cpp'
NeoBundle 'slim-template/vim-slim'
NeoBundle 'tpope/vim-markdown'
NeoBundle 'digitaltoad/vim-jade'
NeoBundle 'mrtazz/simplenote.vim'

"If there are uninstalled bundles found on startup,
"this will conveniently prompt you to install them.
NeoBundleCheck

"Automatically detect file types.
filetype plugin indent on

"Colorscheme and syntax
"Refer to https://github.com/altercation/vim-colors-solarized/blob/master/README.mkd
let g:solarized_termtrans=1

syntax enable
set background=dark
colorscheme solarized

set number
set title
set showmatch
set noswapfile
set eol

"Indent, Tab, Space
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set smartindent
set backspace=indent,eol,start
set cursorcolumn
highlight CursorColumn ctermbg=darkgray

"HighlitTrailingSpaces
augroup HighlightTrailingSpaces
  autocmd!
  autocmd VimEnter,WinEnter,ColorScheme * highlight TrailingSpaces term=underline guibg=Red ctermbg=Red
  autocmd VimEnter,WinEnter * match TrailingSpaces /\s\+$/
augroup END

"Delete Spaces on save
autocmd BufWritePre * :%s/\s\+$//ge

"Search
set incsearch
set ignorecase
set smartcase
set wrapscan

"For clipboard
set clipboard+=unnamed,autoselect

"Automatically set slimbars filetype
autocmd BufRead,BufNewFile *.slimbars setlocal filetype=slim

"Setting nerdtree:

"Display hidden file
let g:NERDTreeShowHidden = 1

"Display nerdtree when opening a new tab
let g:nerdtree_tabs_open_on_new_tab=1

"Setting neocomplcache:

"Disable AutoComplPop.
let g:acp_enableAtStartup = 0
" Use neocomplcache.
let g:neocomplcache_enable_at_startup = 1
" Use smartcase.
let g:neocomplcache_enable_smart_case = 1
" Use camel case completion.
let g:neocomplcache_enable_camel_case_completion = 1
" Use underbar completion.
let g:neocomplcache_enable_underbar_completion = 1
" Set minimum syntax keyword length.
let g:neocomplcache_min_syntax_length = 3
let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'

"Define dictionary.
let g:neocomplcache_dictionary_filetype_lists = {
    \ 'default' : '',
    \ 'vimshell' : $HOME.'/.vimshell_hist',
    \ 'scheme' : $HOME.'/.gosh_completions'
        \ }

"Define keyword.
if !exists('g:neocomplcache_keyword_patterns')
    let g:neocomplcache_keyword_patterns = {}
endif
let g:neocomplcache_keyword_patterns['default'] = '\h\w*'

"For Simplenote
if filereadable(expand('~/.simplenoterc'))
  source ~/.simplenoterc
endif
