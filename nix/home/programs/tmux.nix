{ config, user, ... }:

# tmux 設定 (~/.tmux.conf, ~/.tmux_start_dir) を repo の raw text に
# out-of-store symlink で配置する。zsh.nix と同じ `mkOutOfStoreSymlink`
# パターンで、`vim ~/.tmux.conf` で開けば repo 内ファイルを直接編集できる
# (tmux 側の reload は手動)。
#
# ~/.tmux_start_dir は tmux-start (zshrc から呼ぶ自作 helper) が読む
# ディレクトリ一覧。default の 2 path (`~/Documents/dev/*` と Obsidian
# vault) を repo に commit して全 PC 共通とする。PC ごとに違う path が
# 必要になったら、その時点で個別対応する (default を更新する / その PC
# だけ symlink を解除して手書き運用に切り替える / specialArgs で host 別
# list を渡す形に発展させる、等)。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
in
{
  home.file.".tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tmux/.tmux.conf";

  home.file.".tmux_start_dir".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tmux/.tmux_start_dir";
}
