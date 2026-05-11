-- Neovim entry point. lazy.nvim bootstrap + module loading.

-- 社内 VPN の SSL inspection 環境で git の TLS verify を通すため、
-- nix-daemon.nix が配置する /etc/nix/ca-bundle.pem を子プロセス git の
-- CA bundle として継承させる (lazy.nvim bootstrap clone と plugin install
-- の両方が git を呼ぶ)。
if (vim.uv or vim.loop).fs_stat("/etc/nix/ca-bundle.pem") then
  vim.env.GIT_SSL_CAINFO = "/etc/nix/ca-bundle.pem"
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("options")
require("mappings")
require("autocmds")

require("lazy").setup("plugins", {
  install = { colorscheme = { "habamax" } },
  checker = { enabled = false },
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})
