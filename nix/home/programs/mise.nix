{ config, lib, pkgs, user, ... }:

# mise (旧 rtx) を home-manager の nixpkgs ビルドで導入する。
#
# 旧構成: nix/homebrew.nix の brews に "mise" を入れて Homebrew で管理し、
# /opt/homebrew/bin/mise を zsh 関数経由で呼んでいた。新構成では
# `programs.mise.enable` で home-manager の nixpkgs.mise を入れ、PATH 上
# で見える mise がこちらに切り替わる (`which mise` が ~/.local/state/nix/
# profiles/home-manager-path/bin/mise を返す)。
#
# enableZshIntegration を false にする理由:
# starship.nix と同じく、zshrc は repo の zsh/.zshrc を home.file で
# symlink 配置している。home-manager に zshrc 注入を許すと両者が衝突して
# 片方の設定が消えるため、`mise activate zsh` の eval 行は zsh/.zshrc に
# 手書きで 1 行持たせ続ける。
#
# global tool versions (~/.config/mise/config.toml) は repo の mise/
# config.toml に raw 配置し、out-of-store symlink で参照させる。
# `vim ~/.config/mise/config.toml` で repo 内ファイルを直接編集できる。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
in
{
  programs.mise = {
    enable = true;
    enableZshIntegration = false;
  };

  home.file.".config/mise/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/mise/config.toml";

  # mise の trust 機構対策。out-of-store symlink で ~/.config/mise/config.toml
  # を repo 内 path に向けると、mise が「~/.config 直下でない外部 config」と
  # 判定して `mise trust` を要求する。home-manager activation で 1 回 trust
  # を登録しておく (~/.local/share/mise/trusted-configs/ に hash 記録、冪等)。
  home.activation.miseTrust = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.mise}/bin/mise trust "${dotfilesPath}/mise/config.toml" \
      || echo "[miseTrust] trust failed (non-fatal)"
  '';
}
