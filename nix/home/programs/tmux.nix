{ config, user, ... }:

# tmux 設定 (~/.tmux.conf, ~/.tmux_start_dir) を repo の raw text に
# out-of-store symlink で配置する。zsh.nix と同じ `mkOutOfStoreSymlink`
# パターンで、`vim ~/.tmux.conf` で開けば repo 内ファイルを直接編集できる。
# 設定の reload は tmux 側で手動 (`tmux source ~/.tmux.conf`) が必要だが、
# ファイル更新自体は darwin-rebuild なしで即時反映される。
#
# ~/.tmux_start_dir は tmux-start (zshrc から呼ぶ自作 helper) が読むディレ
# クトリ一覧。chezmoi の machineType 分岐は move-nix で撤去したため、現状は
# 全 host 共通の path のみ。host 別の差分が必要になったら home.activation
# で append する形に拡張する。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
in
{
  home.file.".tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tmux/.tmux.conf";

  home.file.".tmux_start_dir".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tmux/.tmux_start_dir";
}
