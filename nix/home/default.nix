{ user, ... }:

# home-manager (~/ 配下を declarative に管理する Nix module) の最小モジュール。
#
# 設計上の方針:
#   * dotfile 本体 (zshrc / tmux.conf / vimrc 等) は引き続き chezmoi 側に集約。
#     home-manager は「Nix module で型付けして書く方が綺麗な user-level 設定」と
#     「flake.lock で pin したい user-level バイナリ」だけを引き受ける。
#   * 編集頻度が低く、Nix module の `programs.*` で恩恵を受けるツール (starship,
#     direnv, fzf 等) を段階的にここに移していく予定。
#
# このファイル単独では `home.packages` も `programs.*` 設定も持たない。
# flake build と darwin-rebuild の home-manager activation 経路が壊れていない
# ことだけを保証する pure infra モジュール。実際の dotfile / CLI 配布は
# 後続 PR で段階的に追加する。
{
  # nixpkgs unstable に対応する home-manager リリース。
  # nix-darwin の system.stateVersion (= 6) とは別の値で、初回設定値を pin する。
  home.stateVersion = "25.11";

  # flake から渡された user で primary user を確定。multi-user 環境ではないので
  # 1 user 固定。
  home.username = user;
  home.homeDirectory = "/Users/${user}";

  # programs.home-manager.enable = true は darwin module 統合経路では不要。
  # standalone の `home-manager` CLI を使わない (= darwin-rebuild 1 発で活性化
  # する) ため、CLI の同梱インストールを避けて冪等性を維持する。
}
