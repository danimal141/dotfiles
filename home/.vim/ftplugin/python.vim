setlocal tabstop=4
setlocal shiftwidth=4
setlocal expandtab
setlocal autoindent
setlocal formatoptions=croql

let python_highlight_all=1

" Use the below highlight group when displaying bad whitespace is desired.
highlight BadWhitespace ctermbg=red guibg=red

" Display tabs at the beginning of a line in Python mode as bad.
au BufRead,BufNewFile *.py,*.pyw match BadWhitespace /^\t\+/

" Make trailing whitespace be flagged as bad.
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

"let s:python_path = system('python -', 'import sys;sys.stdout.write(",".join(sys.path))')
"python3 <<EOF
"import sys
"import vim
"python_paths = vim.eval('s:python_path').split(',')
"for path in python_paths:
"    if not path in sys.path:
"        sys.path.insert(0, path)
"EOF

