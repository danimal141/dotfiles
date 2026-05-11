{ config, dotfilesPath, ... }:

# Neovim 設定。tools/nvim/ 全体を ~/.config/nvim に out-of-store symlink で
# 配置する。lazy.nvim の plugin 実体は ~/.local/share/nvim/lazy/ に書かれる
# ため repo 内 (tools/nvim/) は触られない。lazy-lock.json は repo 内
# tools/nvim/lazy-lock.json に書き戻されるので tracked にして再現性を担保。
let
  nvimDir = "${dotfilesPath}/tools/nvim";
in
{
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink nvimDir;
}
