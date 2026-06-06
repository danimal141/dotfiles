{ config, lib, pkgs, dotfilesPath, ... }:

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
#     claude --global` を実行する。`--global` で skill を user scope
#     (~/.claude/skills/) に展開する (これがないと cwd 下の
#     ~/.apm/.claude/skills/ に project scope で入ってしまう)。冪等で、
#     apm 未インストール環境では skip する。
#   * apm の GitHub clone は GITHUB_APM_PAT / GITHUB_TOKEN を要求するため、
#     `gh` が PATH にあれば `gh auth token` の出力を GITHUB_APM_PAT に
#     export してから install を呼ぶ。secret を repo / zshrc に書かない経路。
#     `gh auth login` の事前実行が前提。
let
  apmDir = "${dotfilesPath}/tools/apm";
in
{
  home.file.".apm/apm.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${apmDir}/apm.yml";
  home.file.".apm/apm.lock.yaml".source =
    config.lib.file.mkOutOfStoreSymlink "${apmDir}/apm.lock.yaml";
  home.file.".apm/.gitignore".source =
    config.lib.file.mkOutOfStoreSymlink "${apmDir}/.gitignore";

  home.activation.apmInstall = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # home-manager の activation hook はデフォルト PATH に nix-darwin の
    # system profile (/run/current-system/sw/bin) を含まない。apm は
    # nix-darwin の environment.systemPackages 経由でそこに居るため、
    # PATH に明示的に足してから command -v で解決する。
    export PATH="/run/current-system/sw/bin:$PATH"

    HASH_FILE="$HOME/.apm/.apm.yml.hash"
    # apm.yml は linkGeneration 後に symlink 配置されるが、初回など
    # ファイルが存在しない場合は skip する。
    if [ ! -f "$HOME/.apm/apm.yml" ]; then
      echo "[apmInstall] skip (apm.yml not found)"
      return 0
    fi
    NEW_HASH=$(${pkgs.coreutils}/bin/sha256sum "$HOME/.apm/apm.yml" | ${pkgs.gawk}/bin/awk '{print $1}')
    OLD_HASH=$(${pkgs.coreutils}/bin/cat "$HASH_FILE" 2>/dev/null || echo "")
    APM_BIN=$(command -v apm || true)
    GH_BIN=$(command -v gh || true)
    if [ "$NEW_HASH" != "$OLD_HASH" ] && [ -n "$APM_BIN" ]; then
      # gh が PATH にあれば `gh auth token` から動的に token を取得して
      # GITHUB_APM_PAT に流す。apm 自身は env var しか見ないため、
      # `gh auth login` だけでは clone 認証が通らない問題を埋める経路。
      if [ -n "$GH_BIN" ]; then
        GH_TOKEN_VAL=$("$GH_BIN" auth token 2>/dev/null || true)
        if [ -n "$GH_TOKEN_VAL" ]; then
          export GITHUB_APM_PAT="$GH_TOKEN_VAL"
        fi
      fi
      echo "[apmInstall] running apm install --target claude --global (apm=$APM_BIN)"
      # 成功時のみ hash を記録する。失敗時 (GitHub clone 認証失敗 / network
      # 障害 等) に hash を書くと、以降「hash 一致 → installed」と誤判定して
      # 失敗を隠してしまうため、exit code を必ず check する。
      # --parallel-downloads 1 で直列化する。apm の dep が同一 mono-repo
      # (例: danimal141/skilltree) を共有する場合、default 4 並列だと
      # `git clone --bare` が同一 repo に対して同時実行され、exit 128 で
      # 落ちる現象が再現する (skilltree 全 skill が単一 repo にぶら下がる
      # 構成のため毎回踏む)。並列度を 1 にしても 1 件目の clone 後は
      # apm 内 cache に乗るため後続は即時 (cached) となり実時間ほぼ不変。
      if (cd "$HOME/.apm" && $DRY_RUN_CMD "$APM_BIN" install --target claude --global --parallel-downloads 1); then
        echo "$NEW_HASH" > "$HASH_FILE"
      else
        echo "[apmInstall] FAILED (hash not recorded; will retry next switch)" >&2
      fi
    else
      echo "[apmInstall] skip (hash unchanged or apm missing; apm=$APM_BIN)"
    fi
  '';
}
