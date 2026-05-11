-- Neovim entry point. lazy.nvim bootstrap + module loading.

-- 社内 VPN の SSL inspection 環境で外部通信の TLS verify を通すため、
-- nix-daemon.nix が配置する /etc/nix/ca-bundle.pem を子プロセスに継承
-- させる。git は GIT_SSL_CAINFO、curl は CURL_CA_BUNDLE を見る
-- (nvim-treesitter は curl で parser tar.gz を取りに行く)。SSL_CERT_FILE
-- は OpenSSL を直接使う Python / Ruby などのフォールバック用。
if (vim.uv or vim.loop).fs_stat("/etc/nix/ca-bundle.pem") then
  vim.env.GIT_SSL_CAINFO = "/etc/nix/ca-bundle.pem"
  vim.env.CURL_CA_BUNDLE = "/etc/nix/ca-bundle.pem"
  vim.env.SSL_CERT_FILE = "/etc/nix/ca-bundle.pem"
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
