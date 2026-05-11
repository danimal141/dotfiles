local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local trailing = augroup("HighlightTrailingSpaces", { clear = true })
autocmd({ "VimEnter", "WinEnter", "ColorScheme" }, {
  group = trailing,
  callback = function()
    vim.api.nvim_set_hl(0, "TrailingSpaces", { bg = "Red" })
  end,
})
autocmd({ "VimEnter", "WinEnter" }, {
  group = trailing,
  command = [[match TrailingSpaces /\s\+$/]],
})

autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    local view = vim.fn.winsaveview()
    pcall(vim.cmd, [[%s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

if vim.fn.executable("im-select") == 1 then
  local imgroup = augroup("ImSelect", { clear = true })
  local source = "com.google.inputmethod.Japanese.Roman"
  autocmd({ "InsertLeave", "CmdlineLeave" }, {
    group = imgroup,
    callback = function()
      vim.fn.jobstart({ "im-select", source }, { detach = true })
    end,
  })
end
