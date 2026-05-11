local opt = vim.opt

opt.encoding = "utf-8"
opt.number = true
opt.title = false
opt.showmatch = true
opt.swapfile = false
opt.backup = false
opt.ttyfast = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true
opt.backspace = { "indent", "eol", "start" }
opt.completeopt = { "menuone", "noinsert" }

opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.wrapscan = true

opt.clipboard = "unnamed"
opt.fileformats = { "unix", "dos", "mac" }
opt.fileencodings = { "utf-8", "sjis" }

opt.termguicolors = true
opt.background = "dark"
