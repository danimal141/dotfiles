set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_check_on_wq = 0

augroup filetypedetect
  au BufRead,BufNewFile *.go setfiletype go
  au BufRead,BufNewFile *.rb setfiletype ruby
  au BufRead,BufNewFile *.js setfiletype javascript.jsx
  au BufRead,BufNewFile *.jsx setfiletype javascript.jsx
  au BufRead,BufNewFile *.ts setfiletype typescript.tsx
  au BufRead,BufNewFile *.tsx setfiletype typescript.tsx
  au BufRead,BufNewFile *.scss setfiletype scss
  au BufRead,BufNewFile *.py setfiletype python
  au BufRead,BufNewFile *.rs setfiletype rust
  au BufRead,BufNewFile *.md setfiletype markdown
  au BufRead,BufNewFile *.c setfiletype clang
  au BufRead,BufNewFile *.cpp setfiletype clang
  au BufRead,BufNewFile *.yml setfiletype yaml
  au BufRead,BufNewFile *.yaml setfiletype yaml
augroup END
