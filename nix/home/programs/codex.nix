{ config, lib, pkgs, user, dotfilesPath, ... }:

# Codex CLI 設定 (~/.codex/) を home-manager で管理する。
#
#   * GEMINI_API_KEY は ~/.codex/.env (repo 外、user 手動配置) に書き、
#     wrapper script (~/.codex/wrappers/gemini-mcp.sh = repo の
#     tools/codex/wrappers/gemini-mcp.sh) が起動時に source して inject する。
#     secrets を tracked file から完全分離する設計。
#   * AGENTS.md は repo の tools/claude/CLAUDE.md を直接指す out-of-store
#     symlink。CLAUDE.md 編集が ~/.claude/CLAUDE.md と ~/.codex/AGENTS.md
#     の両方に即反映される (両者で同じ system instruction を共有したい意図)。
#   * config.toml は read-only symlink にできない。codex は起動時に
#     [projects] trust_level を config.toml へ追記するが、home.file の
#     `text =` 生成は nix store の read-only file への symlink になるため、
#     trust 書込が code -32603 (failed to persist config) で失敗する。
#     そこで declarative テンプレート (model / MCP server 設定) を nix store に
#     持ち、codexConfig activation hook で ~/.codex/config.toml へ mutable な
#     実ファイルとしてコピーする。テンプレートの sha256 が変わった時だけ上書き
#     し (apmInstall と同方式)、それ以外は codex が書いた [projects] trust を
#     温存する。上書き時は trust が一旦消えるが、次回 codex 起動で書込可能な
#     ため自動再登録される (プロンプトが 1 度出るだけでエラーにならない)。
#     user 変数 (wrapper 絶対パス) はテンプレート生成時に展開される。
#   * codex binary 本体は OpenAI 公式 native installer
#     (curl -fsSL https://chatgpt.com/codex/install.sh | sh) で
#     ~/.local/bin/codex に配置する (claude.nix と同じ運用)。日常的な
#     version 更新は codex 内蔵の auto-update が担い、switch hook は
#     「未 install のときだけ install」を保証する。brew formula (codex) は
#     homebrew.nix から外したが cleanup="none" のため実機には残り得る。
#     tools/zsh の PATH 順で ~/.local/bin が /opt/homebrew/bin より勝つので
#     native が優先される (手動 `brew uninstall codex` で完全に除去可)。
let
  homePath = "/Users/${user}";
  codexDir = "${dotfilesPath}/tools/codex";
  wrapperHomePath = "${homePath}/.codex/wrappers/gemini-mcp.sh";

  # codex 用 config.toml の declarative テンプレート (model / MCP server 設定)。
  # codexConfig hook が mutable な実ファイルとして配置し codex の [projects]
  # 追記を許可する。中身を変えると次回 switch で上書きされる。
  configTemplate = pkgs.writeText "codex-config.toml" ''
    model = "gpt-5-codex"
    model_reasoning_effort = "high"
    hide_agent_reasoning = true
    network_access = true

    notify = ["bash", "-lc", "afplay /System/Library/Sounds/Ping.aiff"]

    [tools]
    web_search = true

    [mcp_servers.aws-documentation]
    command = "uvx"
    args = ["awslabs.aws-documentation-mcp-server@latest"]

    [mcp_servers.aws-documentation.env]
    FASTMCP_LOG_LEVEL = "ERROR"

    [mcp_servers.context7]
    command = "npx"
    args = ["-y", "@upstash/context7-mcp"]

    # GEMINI_API_KEY は wrapper が ~/.codex/.env から inject する。
    # ここに secrets を書かない (tracked file に secret を残さない方針)。
    [mcp_servers.gemini-google-search]
    command = "${wrapperHomePath}"

    [mcp_servers.gemini-google-search.env]
    GEMINI_MODEL = "gemini-2.5-flash"

    [mcp_servers.playwright]
    command = "npx"
    args = ["-y", "@playwright/mcp@latest"]

    [mcp_servers.serena]
    command = "uvx"
    args = ["--from", "git+https://github.com/oraios/serena", "serena", "start-mcp-server", "--context", "ide-assistant"]

    [mcp_servers.terraform]
    command = "docker"
    args = ["run", "-i", "--rm", "hashicorp/terraform-mcp-server"]
  '';
in
{
  home.file.".codex/wrappers/gemini-mcp.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${codexDir}/wrappers/gemini-mcp.sh";

  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/claude/CLAUDE.md";

  home.file.".codex/.env.example".source =
    config.lib.file.mkOutOfStoreSymlink "${codexDir}/.env.example";

  # config.toml を mutable な実ファイルとして配置する (read-only symlink だと
  # codex の trust 書込が code -32603 で失敗する。冒頭コメント参照)。
  # テンプレートの sha256 が変わった時だけ上書きし、それ以外は codex が書いた
  # [projects] trust を温存する。coreutils は activation の minimal PATH に
  # 無いので絶対パスで呼ぶ。~/.codex は他の home.file symlink で linkGeneration
  # 時に作られるため entryAfter linkGeneration とする。
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    (
    DST="$HOME/.codex/config.toml"
    STAMP="$HOME/.codex/.config-template.sha256"
    NEW_SHA=$(${pkgs.coreutils}/bin/sha256sum "${configTemplate}" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
    OLD_SHA=$(${pkgs.coreutils}/bin/cat "$STAMP" 2>/dev/null || true)

    if [ ! -e "$DST" ] || [ "$OLD_SHA" != "$NEW_SHA" ]; then
      # 前世代の read-only symlink が残っている場合に備え実体を除去してから
      # 書く (symlink のまま install すると read-only target へ書込み失敗しうる)。
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$DST"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 644 "${configTemplate}" "$DST"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/tee "$STAMP" <<< "$NEW_SHA" >/dev/null
      echo "[codexConfig] config.toml をテンプレートから更新 (codex が trust 等を追記可能)"
    else
      echo "[codexConfig] skip (template unchanged)"
    fi
    )
  '';

  home.activation.codexInstall = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # claudeCodeInstall と同様、activation hook の minimal な PATH では
    # install.sh が絶対パス無しで呼ぶ標準 CLI (curl / shasum / uname / sed /
    # awk / mkdir 等) を解決できないため、Nix store 系と Apple 標準を通す。
    #
    # ただし claude.nix とは違い、末尾に $PATH を足さず /opt/homebrew/bin を
    # 意図的に除外する。codex の install.sh は:
    #   1. `command -v codex` が /opt/homebrew/bin/codex を返すと「brew 管理の
    #      既存 install」と判定し conflict 処理に入る
    #   2. ~/.local/bin が PATH に無いと判断すると profile (~/.zshrc 等) に
    #      `export PATH=...` ブロックを追記する
    # を行う。(1) は brew codex を検出させない、(2) は ~/.local/bin を PATH に
    # 含めて early-return させる、ことで両方回避する。後者を汚すと raw symlink
    # の tools/zsh/.zshrc に書き込まれてしまうため重要。
    #
    # activation script は全 hook を単一ファイルに inline 展開し set -eu で
    # 実行するため、top-level の `return` は不正
    # (return: can only `return' from a function or sourced script) になり、
    # set -e で activation 全体が中断する。hook 本体を subshell で囲み
    # early-exit は `exit` で表現する。subshell で囲むことで、上記の意図的に
    # 制限した PATH ($PATH を足さない) も後続 hook へ漏れない。
    (
    export PATH="/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"

    CODEX_BIN="$HOME/.local/bin/codex"
    # 既に install 済みなら何もしない。version 更新は codex 内蔵の auto-update
    # に任せ、switch hook は「初回 install のみ保証」する。
    if [ -x "$CODEX_BIN" ]; then
      echo "[codexInstall] skip (already installed at $CODEX_BIN)"
      exit 0
    fi

    CURL_BIN=$(command -v curl || true)
    if [ -z "$CURL_BIN" ]; then
      echo "[codexInstall] skip (curl not found in PATH)" >&2
      exit 0
    fi

    # 社内 VPN SSL inspection 下では curl の default CA bundle で TLS 検証が
    # 失敗するため、/etc/nix/ca-bundle.pem があれば inject する
    # (claudeCodeInstall / apmInstall と同じ経路)。bundle が無い環境では無影響。
    if [ -f /etc/nix/ca-bundle.pem ]; then
      export SSL_CERT_FILE=/etc/nix/ca-bundle.pem
      export CURL_CA_BUNDLE=/etc/nix/ca-bundle.pem
    fi

    # prompt を出さず非対話で完結させる (conflict 検出時も既存を残す挙動)。
    export CODEX_NON_INTERACTIVE=true

    echo "[codexInstall] installing codex native binary..."
    # `curl | sh` の stdin パイプは使わない。home-manager の activation は
    # pipefail を有効にしないため、SSL inspection 等で curl が失敗して空を
    # 吐いても sh 側が exit 0 で正常終了し、未 install なのに「installed」と
    # 誤報告してしまう (FAILED が出ない偽陽性)。installer を一旦ファイルに
    # 落として curl の終了ステータスを直接 if で検査し、DL 成功時のみ実行する。
    INSTALLER=$(mktemp)
    if ! "$CURL_BIN" -fsSL https://chatgpt.com/codex/install.sh -o "$INSTALLER"; then
      echo "[codexInstall] FAILED to download installer (will retry next switch)" >&2
      rm -f "$INSTALLER"
      exit 0
    fi
    if $DRY_RUN_CMD sh "$INSTALLER"; then
      echo "[codexInstall] installed at $CODEX_BIN"
    else
      echo "[codexInstall] FAILED (will retry next switch)" >&2
    fi
    rm -f "$INSTALLER"
    )
  '';
}
