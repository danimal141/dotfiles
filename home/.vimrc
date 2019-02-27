set encoding=utf-8
" let g:python3_host_prog = $PYENV_ROOT.'/shims/python3'

"Dein.vim
if &compatible
  set nocompatible
endif
set runtimepath^=~/.vim/dein/repos/github.com/Shougo/dein.vim/

if dein#load_state('~/.vim/dein')
  call dein#begin('~/.vim/dein')
  call dein#add('Shougo/dein.vim')

  " deoplete
  " call dein#add('Shougo/deoplete.nvim')
  " if !has('nvim')
  "   " These depend on python3
  "   call dein#add('roxma/nvim-yarp')
  "   call dein#add('roxma/vim-hug-neovim-rpc')
  " endif
  call dein#add('Shougo/neocomplcache')
  call dein#add('Shougo/neosnippet')
  call dein#add('Shougo/neosnippet-snippets')

  call dein#add('scrooloose/nerdtree')
  call dein#add('Shougo/unite.vim')
  call dein#add('Shougo/vimproc.vim', {'build' : 'make'})
  call dein#add('scrooloose/syntastic')
  call dein#add('tpope/vim-surround')
  call dein#add('vim-scripts/closetag.vim')
  call dein#add('rking/ag.vim')
  call dein#add('ctrlpvim/ctrlp.vim')
  call dein#add('airblade/vim-gitgutter')
  call dein#add('pangloss/vim-javascript')
  call dein#add('mxw/vim-jsx')
  call dein#add('kchmck/vim-coffee-script')
  call dein#add('vim-ruby/vim-ruby')
  call dein#add('vim-jp/vim-cpp')
  call dein#add('justmao945/vim-clang')
  call dein#add('slim-template/vim-slim')
  call dein#add('digitaltoad/vim-jade')
  call dein#add('fatih/vim-go')
  call dein#add('leafgarland/typescript-vim')
  " call dein#add('Quramy/tsuquyomi')
  call dein#add('plasticboy/vim-markdown')
  call dein#add('kannokanno/previm')
  call dein#add('tyru/open-browser.vim')
  call dein#add('szw/vim-tags')
  call dein#add('lambdalisue/vim-pyenv')
  call dein#add('davidhalter/jedi-vim')
  call dein#add('rust-lang/rust.vim')
  call dein#add('racer-rust/vim-racer')

  call dein#end()
  call dein#save_state()
endif
if dein#check_install()
  call dein#install()
endif

" deoplete
" if dein#tap('deoplete.nvim')
"   let g:deoplete#enable_at_startup = 1
" endif

"Colorscheme and syntax
"Refer to https://github.com/altercation/vim-colors-solarized/blob/master/README.mkd
let g:solarized_termtrans=1

filetype plugin indent on "Automatically detect file types.
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

inoremap {<Enter> {}<Left><CR><ESC><S-o>
inoremap [<Enter> []<Left><CR><ESC><S-o>
inoremap (<Enter> ()<Left><CR><ESC><S-o>

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

"Automatically set ts, tsx filetype
autocmd BufNewFile,BufRead *.ts     set filetype=typescript
autocmd BufNewFile,BufRead *.tsx    set filetype=typescript

"Setting nerdtree:
"Open nerdtree automatically
"autocmd vimenter * if !argc() | NERDTree | endif
"Display hidden file
let g:NERDTreeShowHidden = 1
"Display nerdtree when opening a new tab
let g:nerdtree_tabs_open_on_new_tab=1
"Disable vim-markdown folding configuration
let g:vim_markdown_folding_disabled = 1

"Setting neocomplcache:

"Disable AutoComplPop.
let g:acp_enableAtStartup = 0
"Use neocomplcache.
let g:neocomplcache_enable_at_startup = 1
"Use smartcase.
let g:neocomplcache_enable_smart_case = 1
"Use camel case completion.
let g:neocomplcache_enable_camel_case_completion = 1
"Use underbar completion.
let g:neocomplcache_enable_underbar_completion = 1
"Set minimum syntax keyword length.
let g:neocomplcache_min_syntax_length = 3
let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'
"Define dictionary.
let g:neocomplcache_dictionary_filetype_lists = {
\ 'default' : '',
\ 'vimshell' : $HOME.'/.vimshell_hist',
\ 'scheme' : $HOME.'/.gosh_completions'
\ }
let g:neocomplcache_force_overwrite_completefunc=1

"vim-clang
"disable auto completion for vim-clang
let g:clang_auto = 0
let g:clang_complete_auto = 0
let g:clang_auto_select = 0
let g:clang_use_library = 1
"default 'longest' can not work with neocomplete
let g:clang_c_completeopt   = 'menuone'
let g:clang_cpp_completeopt = 'menuone'

"Define keyword.
if !exists('g:neocomplcache_keyword_patterns')
  let g:neocomplcache_keyword_patterns = {}
endif
let g:neocomplcache_keyword_patterns['default'] = '\h\w*'

"For Markdown
au BufRead,BufNewFile *.md set filetype=markdown

"ctags
let g:vim_tags_project_tags_command = "/usr/local/bin/ctags -R {OPTIONS} {DIRECTORY} 2>/dev/null"
let g:vim_tags_gems_tags_command = "/usr/local/bin/ctags -R {OPTIONS} `bundle show --paths` 2>/dev/null"
