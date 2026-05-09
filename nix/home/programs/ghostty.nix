{ config, user, ... }:

# Ghostty (terminal) 設定。`~/Library/Application Support/com.mitchellh.ghostty
# /config` を repo の raw text に out-of-store symlink で配置する。
#
# `Application Support` のスペース文字を含む path だが、Nix の string では
# そのまま扱える (mkOutOfStoreSymlink は path 文字列を quoting して渡す)。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
in
{
  home.file."Library/Application Support/com.mitchellh.ghostty/config".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/ghostty/config";
}
