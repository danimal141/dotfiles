{
  config,
  lib,
  pkgs,
  dotfilesPath,
  ...
}:

# Claude Code CLI 設定 (~/.claude/) と native binary 本体を管理する。
#
# ~/.claude/ 全体を 1 つの symlink にしてしまうと Claude Code が動的に
# 書き換える `projects/` `todos/` `shell-snapshots/` `statsig/` `ide/` が
# repo 内に流れ込む。declarative に管理したい部分だけ個別 symlink にして、
# 動的領域は home.file 対象外で mutable のまま残す。
#
# skills/ 配下は `.gitignore` のみ symlink で配置し、APM (apm.yml 経由)
# が install する skill ディレクトリ群 (chrome-cdp/ 等) は対象外。
# skills/.gitignore 自体が APM 産物を ignore する役割を果たす。
#
# setup-mcp.sh は ~/.claude には配置せず、repo 内で `cd tools/claude &&
# ./setup-mcp.sh` で直接呼ぶ運用。
#
# claude binary 本体は Anthropic 公式 native installer を取得して
# ~/.local/bin/claude に配置する。brew cask (claude-code) も宣言上は残しているが、
# tools/zsh の PATH 順で ~/.local/bin が /opt/homebrew/bin より勝つように設定して
# native を優先させる。日常的なバージョン更新は native binary 内蔵の
# auto-update が担う (switch では「未 install のときだけ install」を保証)。
let
  claudeDir = "${dotfilesPath}/tools/claude";
in
{
  home.file = {
    ".claude/CLAUDE.md".source = config.lib.file.mkOutOfStoreSymlink "${claudeDir}/CLAUDE.md";
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${claudeDir}/settings.json";
    # MCP server 定義は codex と共有する tools/mcp/servers.json を single
    # source of truth とする (情報用ミラー。実際の登録は setup-mcp.sh が repo
    # の同ファイルを直接読んで `claude mcp add` する)。
    ".claude/mcp-servers.json".source =
      config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/mcp/servers.json";
    ".claude/.env.example".source = config.lib.file.mkOutOfStoreSymlink "${claudeDir}/.env.example";

    ".claude/hooks".source = config.lib.file.mkOutOfStoreSymlink "${claudeDir}/hooks";
    ".claude/rules".source = config.lib.file.mkOutOfStoreSymlink "${claudeDir}/rules";

    ".claude/skills/.gitignore".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeDir}/skills/.gitignore";
  };

  home.activation.claudeCodeInstall = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # home-manager の activation hook はデフォルト PATH が極めて minimal で、
    # Nix store 系も /usr/bin 系も含まない。install.sh は内部で curl /
    # shasum / sysctl / cut / sed / mkdir 等の標準 CLI を絶対パス無しで呼ぶため、
    # 解決経路を網羅的に通す:
    #   * /run/current-system/sw/bin  — nix-darwin systemPackages (curl 等)
    #   * /usr/bin, /usr/sbin, /bin, /sbin — Apple 標準 (shasum, sysctl, cut 等)
    # apmInstall は pkgs.coreutils の sha256sum を絶対パスで呼ぶので
    # /run/current-system/sw/bin だけで足りたが、install.sh は外部 script
    # のため絶対パス置換が効かない。
    #
    # activation script は全 hook を単一ファイルに inline 展開し set -eu で
    # 実行するため、top-level の `return` は不正
    # (return: can only `return' from a function or sourced script) になり、
    # set -e で activation 全体が中断して後続 hook (codexInstall 等) に
    # 到達しない。hook 本体を subshell で囲み early-exit は `exit` で表現する。
    # 併せて export (PATH / SSL_CERT_FILE) を後続 hook へ漏らさない。
    (
    export PATH="/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

    CLAUDE_BIN="$HOME/.local/bin/claude"
    # 既に install 済みなら何もしない。日常の version 更新は claude binary
    # 内蔵の auto-update に任せ、switch hook は「初回 install のみ保証」する。
    if [ -x "$CLAUDE_BIN" ]; then
      echo "[claudeCodeInstall] skip (already installed at $CLAUDE_BIN)"
      exit 0
    fi

    CURL_BIN=$(command -v curl || true)
    if [ -z "$CURL_BIN" ]; then
      echo "[claudeCodeInstall] skip (curl not found in PATH)" >&2
      exit 0
    fi

    # 社内 VPN SSL inspection 下では curl の default CA bundle で TLS 検証が
    # 失敗するため、/etc/nix/ca-bundle.pem があれば inject する。
    # zshrc の apm wrapper / apmInstall hook と同じ経路。bundle が無い環境
    # (CI 等) では skip して無影響。
    if [ -f /etc/nix/ca-bundle.pem ]; then
      export SSL_CERT_FILE=/etc/nix/ca-bundle.pem
      export CURL_CA_BUNDLE=/etc/nix/ca-bundle.pem
    fi

    echo "[claudeCodeInstall] installing claude code native binary..."
    # install.sh は最新版を取得 → ~/.claude/downloads/ に DL → checksum 検証
    # → `claude install` で ~/.local/bin/claude に launcher を配置、までを
    # 自動で行う。失敗時は何も書かず次回 switch で再試行できる。
    #
    # `curl | bash` のパイプは使わず、installer を一旦ファイルに落として curl の
    # 終了ステータスを直接 if で検査し、DL 成功時のみ実行する。SSL inspection 等で
    # curl が失敗したら DL を破棄して FAILED を出し次回 switch で再試行する。
    # パイプの終了ステータス解釈に頼らず DL の完全成功を独立に確認するため。
    INSTALLER=$(mktemp)
    if ! "$CURL_BIN" -fsSL https://claude.ai/install.sh -o "$INSTALLER"; then
      echo "[claudeCodeInstall] FAILED to download installer (will retry next switch)" >&2
      rm -f "$INSTALLER"
      exit 0
    fi
    if $DRY_RUN_CMD bash "$INSTALLER"; then
      echo "[claudeCodeInstall] installed at $CLAUDE_BIN"
    else
      echo "[claudeCodeInstall] FAILED (will retry next switch)" >&2
    fi
    rm -f "$INSTALLER"
    )
  '';

  # settings.json は raw symlink で live-edit 可能なまま、switch 時に JSON schema
  # 検証だけ行う中間案 (live-edit の快適さを保ちつつ壊れた設定を早期検知)。
  # settings.json 先頭の `$schema` (schemastore) を読み check-jsonschema で検証
  # する。remote schema を fetch するため非ブロッキングにし、失敗 (network 障害 /
  # schema 不整合) は警告のみで activation を止めない。check-jsonschema は取得した
  # schema を cache するので 2 回目以降の switch は速い。linkGeneration 後に
  # ~/.claude/settings.json (symlink) が存在することに依存する。
  home.activation.claudeSettingsValidate = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    SETTINGS="$HOME/.claude/settings.json"
    if [ -f "$SETTINGS" ]; then
      SCHEMA=$(${pkgs.jq}/bin/jq -r '.["$schema"] // empty' "$SETTINGS")
      if [ -n "$SCHEMA" ]; then
        # 社内 VPN SSL inspection 下では schema fetch の TLS 検証が失敗するため
        # /etc/nix/ca-bundle.pem があれば inject する (他 hook と同経路)。
        if [ -f /etc/nix/ca-bundle.pem ]; then
          export SSL_CERT_FILE=/etc/nix/ca-bundle.pem
          export REQUESTS_CA_BUNDLE=/etc/nix/ca-bundle.pem
        fi
        if $DRY_RUN_CMD ${pkgs.check-jsonschema}/bin/check-jsonschema --schemafile "$SCHEMA" "$SETTINGS"; then
          echo "[claudeSettingsValidate] settings.json OK"
        else
          echo "[claudeSettingsValidate] WARN: settings.json schema 検証に失敗 (non-blocking)" >&2
        fi
      fi
    fi
  '';
}
