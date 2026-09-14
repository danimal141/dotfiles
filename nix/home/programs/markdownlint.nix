{ config, dotfilesPath, ... }:

# markdownlint 設定 (~/.markdownlint.jsonc) を repo の raw text に
# out-of-store symlink で配置する。zsh.nix と同じ mkOutOfStoreSymlink
# パターンで、`vim ~/.markdownlint.jsonc` で repo 内ファイルを直接
# 編集できる。
#
# このファイルは `markdownlint` CLI (手動実行) / 手元の editor から共通参照される
# グローバル設定。
{
  home.file.".markdownlint.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/markdownlint/.markdownlint.jsonc";
}
