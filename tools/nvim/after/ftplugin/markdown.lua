vim.opt_local.foldmethod = "manual"

-- nvim 0.12.2 が runtime/lib に markdown / markdown_inline parser を bundle
-- しており、ensure_installed から外しても markdown buffer で自動 attach される。
-- この parser が 0.12 内部 API で "attempt to call method 'range' (a nil
-- value)" を投げるため、attach 後すぐに停止して vim builtin syntax にフォール
-- バックさせる。長期的には nvim-treesitter main branch 移行で解消予定。
pcall(vim.treesitter.stop, 0)

