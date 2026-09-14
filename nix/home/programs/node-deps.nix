{
  lib,
  pkgs,
  dotfilesPath,
  ...
}:

# repo 直下の package.json / package-lock.json で pin した npm devDependencies
# (secretlint, textlint + textlint-rule-preset-ai-words-ja) を `nix run .#switch`
# の経路で node_modules/ に揃える。
#
#   * setup.sh の `npm ci` は初回 bootstrap 専用で、既に構築済みの Mac が
#     この repo を pull して switch しても走らない。textlint を使う PostToolUse
#     hook (tools/claude/hooks/posttooluse-textlint-ai-words.py) は binary 不在時
#     fail-open で黙って no-op になるため、switch 側で install を保証する。
#   * package-lock.json の sha256 を node_modules/.package-lock.sha256 に保存し、
#     差分があるときだけ `npm ci` を走らせる (冪等。apm.nix と同じ方式)。
#   * npm は mise 管理 (tools/mise/config.toml の node)。activation の PATH は
#     minimal なので mise の shim と mise 本体 (per-user profile) を明示的に足す。
#   * 社内 VPN SSL inspection 下では registry への TLS が default CA で失敗する
#     ため、/etc/nix/ca-bundle.pem があれば NODE_EXTRA_CA_CERTS に inject する。
#   * npm が無い / lock が無い環境では skip (no-op)。
{
  home.activation.npmCi = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    (
    export PATH="$HOME/.local/share/mise/shims:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/usr/bin:/bin:$PATH"

    LOCK="${dotfilesPath}/package-lock.json"
    HASH_FILE="${dotfilesPath}/node_modules/.package-lock.sha256"
    if [ ! -f "$LOCK" ]; then
      echo "[npmCi] skip (package-lock.json not found)"
      exit 0
    fi
    NPM_BIN=$(command -v npm || true)
    if [ -z "$NPM_BIN" ]; then
      echo "[npmCi] skip (npm not found in PATH)"
      exit 0
    fi
    NEW_HASH=$(${pkgs.coreutils}/bin/sha256sum "$LOCK" | ${pkgs.gawk}/bin/awk '{print $1}')
    OLD_HASH=$(${pkgs.coreutils}/bin/cat "$HASH_FILE" 2>/dev/null || echo "")
    if [ "$NEW_HASH" = "$OLD_HASH" ]; then
      echo "[npmCi] skip (package-lock.json unchanged)"
      exit 0
    fi
    if [ -f /etc/nix/ca-bundle.pem ]; then
      export NODE_EXTRA_CA_CERTS=/etc/nix/ca-bundle.pem
    fi
    echo "[npmCi] running npm ci in ${dotfilesPath} (npm=$NPM_BIN)"
    if (cd "${dotfilesPath}" && "$NPM_BIN" ci --no-audit --no-fund); then
      printf '%s\n' "$NEW_HASH" > "$HASH_FILE"
    else
      echo "[npmCi] npm ci failed (leaving hash unchanged; retried on next switch)" >&2
    fi
    )
  '';
}
