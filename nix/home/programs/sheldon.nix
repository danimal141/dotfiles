{
  config,
  lib,
  pkgs,
  dotfilesPath,
  ...
}:

# sheldon (Rust 製 zsh プラグインマネージャー) の binary 配置と設定 symlink。
#
#   * binary は home.packages 経由で `/etc/profiles/per-user/<user>/bin/sheldon`
#     に配置。zshrc の `eval "$(sheldon source)"` で plugin を一括 source する。
#   * plugins.toml は repo の tools/sheldon/plugins.toml を out-of-store symlink で
#     ~/.config/sheldon/plugins.toml に配置。`vim ~/.config/sheldon/plugins.toml`
#     で repo を直接編集 → 新 shell で即反映 (`sheldon lock` 後に必要なら新 shell)。
#   * sheldonLock activation hook が plugins.toml の hash を比較して差分があるとき
#     だけ `sheldon lock` を発火し、`~/.local/share/sheldon/repos/` 配下に plugin
#     を clone する (apm.nix の apmInstall と同じパターン、冪等)。
#
# `programs.sheldon.enable` (home-manager module) を使わない理由:
#   plugin 宣言を Nix attrset で書くタイプで、TOML 直編集の即反映体験が崩れる
#   (編集即反映は本リポジトリの設計思想 A の核。docs/design-philosophy.md 参照)。
let
  sheldonDir = "${dotfilesPath}/tools/sheldon";
in
{
  home.packages = [ pkgs.sheldon ];

  home.file.".config/sheldon/plugins.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${sheldonDir}/plugins.toml";

  home.activation.sheldonLock = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    HASH_FILE="$HOME/.local/share/sheldon/.plugins.toml.hash"
    PLUGINS_TOML="${sheldonDir}/plugins.toml"
    NEW_HASH=$(${pkgs.coreutils}/bin/sha256sum "$PLUGINS_TOML" | ${pkgs.gawk}/bin/awk '{print $1}')
    OLD_HASH=$(${pkgs.coreutils}/bin/cat "$HASH_FILE" 2>/dev/null || echo "")
    if [ "$NEW_HASH" != "$OLD_HASH" ]; then
      echo "[sheldonLock] running sheldon lock"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$HOME/.local/share/sheldon"
      $DRY_RUN_CMD ${pkgs.sheldon}/bin/sheldon lock
      echo "$NEW_HASH" > "$HASH_FILE"
    else
      echo "[sheldonLock] skip (hash unchanged)"
    fi
  '';
}
