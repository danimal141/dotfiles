{ config, lib, pkgs, user, ... }:

# APM (Agent Package Manager) 設定 (~/.apm/) を home-manager で管理する。
#
#   * apm.yml / apm.lock.yaml / .gitignore を repo の raw text に
#     out-of-store symlink で配置 (`vim ~/.apm/apm.yml` で repo 内
#     ファイルを直接編集できる)。apm install が apm.lock.yaml を更新
#     すると repo 側のファイルが書き換わるので、`git status` で diff が
#     見える = 期待通りの運用。
#   * apm_modules/ config.json などの apm が動的に作る領域は home.file
#     対象外として ~/.apm/ 直下に普通に書ける mutable directory として残す。
#   * activation hook は apm.yml の hash を ~/.apm/.apm.yml.hash に保存し、
#     差分があり apm command が PATH にあるときだけ `apm install --target
#     claude` を実行する。冪等で、apm 未インストール環境では skip する。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
  apmDir = "${dotfilesPath}/tools/apm";
in
{
  home.file.".apm/apm.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${apmDir}/apm.yml";
  home.file.".apm/apm.lock.yaml".source =
    config.lib.file.mkOutOfStoreSymlink "${apmDir}/apm.lock.yaml";
  home.file.".apm/.gitignore".source =
    config.lib.file.mkOutOfStoreSymlink "${apmDir}/.gitignore";

  home.activation.apmInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # home-manager の activation hook はデフォルト PATH に nix-darwin の
    # system profile (/run/current-system/sw/bin) を含まない。apm は
    # nix-darwin の environment.systemPackages 経由でそこに居るため、
    # PATH に明示的に足してから command -v で解決する。
    export PATH="/run/current-system/sw/bin:$PATH"

    HASH_FILE="$HOME/.apm/.apm.yml.hash"
    NEW_HASH=$(${pkgs.coreutils}/bin/sha256sum "$HOME/.apm/apm.yml" | ${pkgs.gawk}/bin/awk '{print $1}')
    OLD_HASH=$(${pkgs.coreutils}/bin/cat "$HASH_FILE" 2>/dev/null || echo "")
    APM_BIN=$(command -v apm || true)
    if [ "$NEW_HASH" != "$OLD_HASH" ] && [ -n "$APM_BIN" ]; then
      echo "[apmInstall] running apm install --target claude (apm=$APM_BIN)"
      (cd "$HOME/.apm" && $DRY_RUN_CMD "$APM_BIN" install --target claude)
      echo "$NEW_HASH" > "$HASH_FILE"
    else
      echo "[apmInstall] skip (hash unchanged or apm missing; apm=$APM_BIN)"
    fi
  '';
}
