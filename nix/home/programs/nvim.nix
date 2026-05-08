{ config, user, ... }:

# Neovim 設定。Vim の `~/.vimrc` を共有する設計のため init.vim は
# `source ~/.vimrc` を呼ぶだけの薄いラッパで、`~/.config/nvim/lua/`
# 配下に nvim 固有の plugin 設定 (telescope-config.lua) を持つ。
#
# coc-settings.json は repo の vim/.vim/coc-settings.json に統一して、
# `~/.vim/coc-settings.json` (vim.nix で配置) と `~/.config/nvim/
# coc-settings.json` の両方が同じ実体ファイルを指す。これにより vim と
# nvim で CoC の language server 設定が常に一致する。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
  nvimDir = "${dotfilesPath}/nvim";
in
{
  home.file = {
    ".config/nvim/init.vim".source =
      config.lib.file.mkOutOfStoreSymlink "${nvimDir}/init.vim";
    ".config/nvim/lua/telescope-config.lua".source =
      config.lib.file.mkOutOfStoreSymlink "${nvimDir}/lua/telescope-config.lua";
    ".config/nvim/coc-settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/vim/.vim/coc-settings.json";
  };
}
