augroup filetypedetect
  au BufRead,BufNewFile *.go setfiletype go
  au BufRead,BufNewFile *.rb setfiletype ruby
  au BufRead,BufNewFile *.scss setfiletype scss
  au BufRead,BufNewFile *.py setfiletype python
augroup END
