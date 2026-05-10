{ config, dotfilesPath, ... }:

# Universal Ctags 設定。`~/.ctags.d/` 配下のファイルが ctags 起動時に
# 自動 load される (XDG-like なルックアップ)。`exclude.ctags` で global な
# `--exclude=` patterns (node_modules / dist / .git / package.json /
# yarn.lock) を宣言する。
{
  home.file.".ctags.d/exclude.ctags".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/ctags/exclude.ctags";
}
