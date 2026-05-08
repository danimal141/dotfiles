{ config, user, ... }:

# tmux 設定 (~/.tmux.conf) を repo の raw text に out-of-store symlink で
# 配置する。zsh.nix と同じ `mkOutOfStoreSymlink` パターンで、
# `vim ~/.tmux.conf` で開けば repo 内ファイルを直接編集できる。
# 設定の reload は tmux 側で手動 (`tmux source ~/.tmux.conf`) が必要だが、
# ファイル更新自体は darwin-rebuild なしで即時反映される。
#
# ~/.tmux_start_dir は意図的に home-manager 管理外に置く:
#   * tmux-start (zshrc から呼ぶ自作 helper) が読むディレクトリ一覧で、
#     PC ごとに開きたい path が違う (work / personal で repo 配置場所や
#     Obsidian vault が異なる)。
#   * これを repo に commit すると PC 横断で同じ path が配布されてしまう。
#   * よって各 PC で `~/.tmux_start_dir` を手書きする運用にする。
#     repo には tmux/.tmux_start_dir.sample をテンプレとして commit。
#   * global gitignore (`chezmoi/dot_gitignore`) で `.tmux_start_dir` を
#     ignore して、誤って他 repo に track されないよう保護。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
in
{
  home.file.".tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tmux/.tmux.conf";
}
