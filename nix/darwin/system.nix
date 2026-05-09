{ user, ... }:

# nix-darwin の root identity と state metadata を宣言する residual モジュール。
#
# 担当する責務:
#   * `system.primaryUser` — `system.defaults` / nix-homebrew が「誰の defaults
#     を書くか」を決めるための primary user 宣言
#   * `users.users.<user>` — home-manager の darwin module が
#     `users.users.<name>.home` から home directory を引くための前提宣言
#   * `programs.zsh.enable = false` — repo の `zsh/.zshrc` を home.file 経由で
#     直接配置するため、nix-darwin 側 zsh module は OFF にして衝突回避
#   * `system.stateVersion` — nix-darwin の state 互換番号
#
# 「macOS defaults / keyboard / Nix daemon settings」のような大きい topic は
# それぞれ defaults.nix / keyboard.nix / nix-daemon.nix に分かれている。
# このファイルはそこに収まらない system 層 root の小物の receptacle。
{
  # `system.defaults` / nix-homebrew が「誰の defaults を書くか」を決めるための
  # primary user 宣言。multi-user 環境ではないので flake から渡された user で固定。
  system.primaryUser = user;

  # nix-darwin に user 本体を宣言する。home-manager の darwin module は
  # `users.users.<name>.home` から home directory を引くため、これ無しだと
  # home.homeDirectory が null として merge され「is not of type absolute path」
  # で activation が落ちる。home-manager 統合の前提条件。
  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
  };

  # zsh の rc は repo の `zsh/.zshrc` を home.file で `~/.zshrc` に symlink
  # 配置する (nix/home/programs/zsh.nix)。nix-darwin が /etc/zshrc を生成
  # すると home-manager 側の zshrc と読み込み順で競合 (PATH 重複 /
  # completion 多重設定) しうるため、system 側 zsh module は無効化する。
  programs.zsh.enable = false;

  # nix-darwin の state 互換番号。手動 migration を伴うため上げない (現時点で 6)。
  system.stateVersion = 6;
}
