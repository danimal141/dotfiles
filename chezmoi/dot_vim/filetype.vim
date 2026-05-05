set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

runtime! ftdetect/*.vim

augroup filetypedetect
  au BufRead,BufNewFile *.go setfiletype go
  au BufRead,BufNewFile *.rb setfiletype ruby
  au BufRead,BufNewFile *.jsx setfiletype javascript.jsx
  au BufRead,BufNewFile *.js setfiletype javascript.jsx
  au BufRead,BufNewFile *.tsx setfiletype typescript.tsx
  au BufRead,BufNewFile *.ts setfiletype typescript.tsx
  au BufRead,BufNewFile *.scss setfiletype scss
  au BufRead,BufNewFile *.py setfiletype python
  au BufRead,BufNewFile *.rs setfiletype rust
  au BufRead,BufNewFile *.md setfiletype markdown
  au BufRead,BufNewFile *.c setfiletype clang
  au BufRead,BufNewFile *.cpp setfiletype clang
  au BufRead,BufNewFile *.yml setfiletype yaml
  au BufRead,BufNewFile *.yaml setfiletype yaml
  au BufRead,BufNewFile *.json setfiletype json
  au BufRead,BufNewFile *.kt setfiletype kotlin
  au BufRead,BufNewFile *.tf setfiletype terraform
  au BufRead,BufNewFile *.csv setfiletype csv
  au BufRead,BufNewFile *.jade setfiletype jade
  au BufRead,BufNewFile *.slim setfiletype slim
augroup END

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_check_on_wq = 0
