{ config, user, ... }:

# tmux 設定 (~/.tmux.conf, ~/.tmux_start_dir) を repo の raw text に
# out-of-store symlink で配置する。zsh.nix と同じ `mkOutOfStoreSymlink`
# パターンで、`vim ~/.tmux.conf` で開けば repo 内ファイルを直接編集できる
# (tmux 側の reload は手動)。
#
# ~/.tmux_start_dir は tmux-start (自作 helper、~/.local/bin/tmux-start)
# が読むディレクトリ一覧。default の 2 path (`~/Documents/dev/*` と
# Obsidian vault) を repo に commit して全 PC 共通とする。PC ごとに違う
# path が必要になったら、その時点で個別対応する (default を更新する /
# その PC だけ symlink を解除して手書き運用に切り替える / specialArgs で
# host 別 list を渡す形に発展させる、等)。
#
# tmux-start 本体 (bash script) も repo の tools/tmux/bin/tmux-start に置き、
# ~/.local/bin/tmux-start に symlink 配置する。executable bit は repo
# 側のファイル mode (chmod +x 済み) を out-of-store symlink 経由で読む。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
in
{
  home.file.".tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/tmux/.tmux.conf";

  home.file.".tmux_start_dir".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/tmux/.tmux_start_dir";

  home.file.".local/bin/tmux-start".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/tmux/bin/tmux-start";
}
