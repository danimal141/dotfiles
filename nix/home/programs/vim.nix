{ config, user, ... }:

# vim 設定 (~/.vimrc, ~/.vim/) を out-of-store symlink で配置する。
#
# ~/.vim/ 全体を 1 つの symlink で繋ぐと vim-plug が repo 内の
# `tools/vim/.vim/plugged/` を書き換えてしまう。サブディレクトリ単位で
# 個別に symlink して、`~/.vim/plugged/` `~/.vim/sessions/`
# `~/.vim/.netrwhist` などの動的領域は home.file 対象外で mutable の
# まま残す。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
  vimDotDir = "${dotfilesPath}/tools/vim/.vim";
in
{
  home.file = {
    ".vimrc".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/vim/.vimrc";

    ".vim/coc-settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${vimDotDir}/coc-settings.json";
    ".vim/filetype.vim".source =
      config.lib.file.mkOutOfStoreSymlink "${vimDotDir}/filetype.vim";

    ".vim/autoload".source =
      config.lib.file.mkOutOfStoreSymlink "${vimDotDir}/autoload";
    ".vim/colors".source =
      config.lib.file.mkOutOfStoreSymlink "${vimDotDir}/colors";
    ".vim/ftdetect".source =
      config.lib.file.mkOutOfStoreSymlink "${vimDotDir}/ftdetect";
    ".vim/ftplugin".source =
      config.lib.file.mkOutOfStoreSymlink "${vimDotDir}/ftplugin";
  };
}
