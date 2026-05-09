{ ... }:

# 個人用 Mac (主機) のホストモジュール。
#
# `networking.hostName = "personal"` を宣言することで、apply 時に
# LocalHostName / HostName が "personal" に固定される。
#
# 個人用 PC を増やすときは `personal2` / `personal3` ... と連番にし、
# それぞれ `nix/hosts/<hostname>.nix` を作って `flake.nix` の hosts attrset
# にエントリを追加する。
#
# 個人用 PC 専用の brew/cask (ゲーム / 趣味ツール 等) を入れたい場合は
# このファイルに `homebrew.brews = [ ... ];` を足す。
{
  networking.hostName = "personal";
}
