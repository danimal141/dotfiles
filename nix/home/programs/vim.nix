{ config, user, ... }:

# vim 設定 (~/.vimrc, ~/.vim/) を repo に out-of-store symlink で配置する。
# zsh.nix / tmux.nix と同じ mkOutOfStoreSymlink パターン。
#
# `~/.vim/` 全体を 1 つの symlink で繋ぐと vim-plug が repo 内に
# `vim/.vim/plugged/` を書いてしまうので、サブディレクトリ単位で個別に
# symlink する。`~/.vim/plugged/` `~/.vim/sessions/` `~/.vim/.netrwhist`
# などの動的領域はここで配置せず、vim-plug や vim 自身が普通に書ける
# mutable directory として残す。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
  vimDotDir = "${dotfilesPath}/vim/.vim";
in
{
  home.file = {
    ".vimrc".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/vim/.vimrc";

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
