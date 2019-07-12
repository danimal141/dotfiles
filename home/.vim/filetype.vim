set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_check_on_wq = 0

augroup filetypedetect
  au BufRead,BufNewFile *.go setfiletype go
  au BufRead,BufNewFile *.rb setfiletype ruby
  au BufRead,BufNewFile *.js setfiletype javascript
  au BufRead,BufNewFile *.jsx setfiletype javascript
  au BufRead,BufNewFile *.ts setfiletype typescript
  au BufRead,BufNewFile *.tsx setfiletype typescript
  au BufRead,BufNewFile *.scss setfiletype scss
  au BufRead,BufNewFile *.py setfiletype python
  au BufRead,BufNewFile *.rs setfiletype rust
  au BufRead,BufNewFile *.md setfiletype markdown
  au BufNewFile,BufRead *.slimbars setfiletype slimbars
augroup END
