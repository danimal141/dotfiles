{ config, ... }:

# zshrc を home.file 経由で `~/.zshrc` に out-of-store symlink で配置する。
#
# `mkOutOfStoreSymlink` を使う理由:
#   * 通常の `home.file.<path>.source` は Nix store にコピーした read-only
#     ファイルへの symlink を作る。エディタで開いて編集するときに store 内の
#     ファイルを書き換えようとして失敗する。
#   * `mkOutOfStoreSymlink` は repo 内の実体ファイルへ直接 symlink を張るので
#     `vim ~/.zshrc` がそのまま `dotfiles/zsh/zshrc` を編集することになり、
#     `source ~/.zshrc` で即反映できる。darwin-rebuild は不要。
#
# Phase 1 prototype: chezmoi の dot_zshrc.tmpl とは並立するが、
# `chezmoi/.chezmoiignore` に `dot_zshrc.tmpl` を追加して chezmoi 側を抑止し、
# home-manager 側の symlink が `~/.zshrc` を所有する。1 週間運用判定して
# Phase 2 以降に進む想定。
let
  dotfilesRoot = toString ../../..;
in
{
  home.file.".zshrc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/zsh/zshrc";
}
