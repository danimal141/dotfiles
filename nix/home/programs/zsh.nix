{ config, dotfilesPath, ... }:

# zshrc を home.file 経由で `~/.zshrc` に out-of-store symlink で配置する。
#
# `mkOutOfStoreSymlink` を使う理由:
#   * 通常の `home.file.<path>.source` は Nix store にコピーした read-only
#     ファイルへの symlink を作る。エディタで開いて編集するときに store 内の
#     ファイルを書き換えようとして失敗する。
#   * `mkOutOfStoreSymlink` は repo 内の実体ファイルへ直接 symlink を張るので
#     `vim ~/.zshrc` がそのまま repo の `tools/zsh/.zshrc` を編集することに
#     なり、`source ~/.zshrc` で即反映できる。`nix run .#switch` は不要。
#
# `dotfilesPath` を specialArgs から受け取る理由:
#   * Nix flake では `../../../tools/zsh/.zshrc` のような相対 Nix path は
#     flake source tree の Nix store コピーを指す。`toString` してもそれは
#     store path (`/nix/store/...-source/tools/zsh/.zshrc`) になり、結果として
#     `mkOutOfStoreSymlink` が store 内のコピーを target にしてしまい
#     out-of-store にならなくなる。
#   * よって repo の絶対パスを使う。flake.nix の mkHost で `dotfilesPath`
#     を 1 ヶ所宣言して specialArgs 経由で全 module に流しているので、
#     work / personal で username が違っても正しく解決される。
#   * 前提: dotfiles を `~/Documents/dev/dotfiles` に clone していること。
#     別 path を使う場合は flake.nix 側の `dotfilesPath` を変更する。
{
  home.file.".zshrc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/zsh/.zshrc";
}
