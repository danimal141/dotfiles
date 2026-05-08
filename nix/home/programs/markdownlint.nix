{ config, user, ... }:

# markdownlint 設定 (~/.markdownlint.jsonc) を repo の raw text に
# out-of-store symlink で配置する。zsh.nix と同じ mkOutOfStoreSymlink
# パターンで、`vim ~/.markdownlint.jsonc` で repo 内ファイルを直接
# 編集できる。
#
# このファイルは Claude Code hook (claude/hooks/markdownlint-checker.sh)
# / pre-commit / 手元の editor から共通参照されるグローバル設定。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
in
{
  home.file.".markdownlint.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/markdownlint/.markdownlint.jsonc";
}
