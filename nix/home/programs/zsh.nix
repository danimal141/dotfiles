{ config, user, ... }:

# zshrc を home.file 経由で `~/.zshrc` に out-of-store symlink で配置する。
#
# `mkOutOfStoreSymlink` を使う理由:
#   * 通常の `home.file.<path>.source` は Nix store にコピーした read-only
#     ファイルへの symlink を作る。エディタで開いて編集するときに store 内の
#     ファイルを書き換えようとして失敗する。
#   * `mkOutOfStoreSymlink` は repo 内の実体ファイルへ直接 symlink を張るので
#     `vim ~/.zshrc` がそのまま repo の `zsh/.zshrc` を編集することになり、
#     `source ~/.zshrc` で即反映できる。darwin-rebuild は不要。
#
# パスを **絶対パス文字列** で渡す理由:
#   * Nix flake では `../../zsh/.zshrc` のような相対 Nix path は flake source
#     tree の Nix store コピーを指す。`toString` してもそれは store path
#     (`/nix/store/...-source/zsh/.zshrc`) になり、結果として
#     `mkOutOfStoreSymlink` が store 内のコピーを target にしてしまい
#     out-of-store にならなくなる。
#   * よって repo の絶対パスを文字列でハードコードする。`user` は specialArgs
#     経由で host から流れてくるので、work / personal で username が違っても
#     正しいパスに解決される。
#   * 前提: dotfiles を `~/Documents/dev/dotfiles` に clone していること。
#     別パスを使うマシンが出てきたら specialArgs に `dotfilesPath` を追加して
#     flake.nix 側で吸収する想定。
{
  home.file.".zshrc".source =
    config.lib.file.mkOutOfStoreSymlink
      "/Users/${user}/Documents/dev/dotfiles/zsh/.zshrc";
}
