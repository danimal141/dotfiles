{ ... }:

# 仕事用 Mac のホストモジュール。
#
# IT 部門が払い出す hostname (例: hideaki-ishii1) は社内ポリシーで都度変わる
# ことがある。`networking.hostName = "work"` を宣言することで、
# `darwin-rebuild switch` 時に LocalHostName / HostName が必ず "work" に揃い、
# `nix run nix-darwin -- switch --flake .#work` の bootstrap が元 hostname
# に依存せず常に同じコマンドで通る。
#
# 仕事用専用の brew/cask (社内 VPN クライアント、社内専用ツール 等) を
# 入れたい場合はこのファイルに `homebrew.brews = [ ... ];` を足す。
# 全ホスト共通のものは `nix/homebrew.nix` 側に書く。
{
  networking.hostName = "work";
}
