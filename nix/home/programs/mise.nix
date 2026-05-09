{ config, lib, pkgs, user, ... }:

# mise (language runtime manager) を home-manager の nixpkgs ビルドで導入。
# binary は `/etc/profiles/per-user/<user>/bin/mise` に配置される。
#
# enableZshIntegration を false にする理由:
# zshrc は repo の tools/zsh/.zshrc を home.file で symlink 配置しているため、
# home-manager の zshrc 注入を許すと両者が衝突する。`mise activate zsh` の
# eval 行は zsh/.zshrc に手書きで 1 行持たせる (starship.nix と同じ方針)。
#
# global tool versions (~/.config/mise/config.toml) は repo の
# tools/mise/config.toml への out-of-store symlink。`vim ~/.config/mise/config.toml`
# で repo 内ファイルを直接編集できる。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
in
{
  programs.mise = {
    enable = true;
    enableZshIntegration = false;
  };

  home.file.".config/mise/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/mise/config.toml";

  # mise の trust 機構対策。out-of-store symlink で ~/.config/mise/config.toml
  # を repo 内 path に向けると、mise が「~/.config 直下でない外部 config」と
  # 判定して `mise trust` を要求する。home-manager activation で 1 回 trust
  # を登録しておく (~/.local/share/mise/trusted-configs/ に hash 記録、冪等)。
  home.activation.miseTrust = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.mise}/bin/mise trust "${dotfilesPath}/tools/mise/config.toml" \
      || echo "[miseTrust] trust failed (non-fatal)"
  '';
}
