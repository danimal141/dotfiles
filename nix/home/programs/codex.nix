{ config, lib, pkgs, dotfilesPath, ... }:

# Codex CLI 設定 (~/.codex/) を home-manager で管理する。
#
#   * AGENTS.md は repo の tools/codex/AGENTS.md を指す out-of-store symlink。
#     tools/codex/AGENTS.md 自体が ../claude/CLAUDE.md への in-repo symlink な
#     ので、~/.codex/AGENTS.md → tools/codex/AGENTS.md → tools/claude/CLAUDE.md
#     の 2 段で解決する。CLAUDE.md 編集が ~/.claude/CLAUDE.md と
#     ~/.codex/AGENTS.md の両方に即反映される (同じ system instruction を共有)。
#   * config.toml は read-only symlink にできない。codex は起動時に
#     [projects] trust_level を config.toml へ追記するが、home.file の symlink
#     は nix store の read-only file を指すため、trust 書込が code -32603
#     (failed to persist config) で失敗する。そこで settings を Nix の
#     attribute set として持ち (pkgs.formats.toml で config.toml を生成)、
#     codexConfig activation hook で ~/.codex/config.toml へ mutable な実
#     ファイルとして毎回上書きする。switch ごとに codex が書いた [projects]
#     trust は消えるが、次回 codex 起動で書込可能なため自動再登録される
#     (プロンプトが 1 度出るだけでエラーにならない)。switch 頻度は低く実害は
#     小さい。user 変数 (wrapper 絶対パス) は settings 内で値として渡せる。
#     settings のベースは ryoppippi/dotfiles の codex.nix を踏襲している。
#   * codex binary 本体は OpenAI 公式 native installer
#     (curl -fsSL https://chatgpt.com/codex/install.sh | sh) で
#     ~/.local/bin/codex に配置する (claude.nix と同じ運用)。日常的な
#     version 更新は codex 内蔵の auto-update が担い、switch hook は
#     「未 install のときだけ install」を保証する。brew formula (codex) は
#     homebrew.nix から外したが cleanup="none" のため実機には残り得る。
#     tools/zsh の PATH 順で ~/.local/bin が /opt/homebrew/bin より勝つので
#     native が優先される (手動 `brew uninstall codex` で完全に除去可)。
let
  tomlFormat = pkgs.formats.toml { };

  # MCP server は claude (setup-mcp.sh) と single source of truth を共有する。
  # tools/mcp/servers.json を path literal で eval-pure に読み込む
  # (dotfilesPath 文字列の readFile は flake purity を壊しうるため、flake store
  # に取り込まれる相対 path literal を使う。codex.nix は nix/home/programs/ 配下
  # なので repo root へは ../../../)。env が空のときは TOML に空テーブルを出さない
  # よう omit し、生成される [mcp_servers] を従来と同一に保つ。
  mcpServers = (builtins.fromJSON (builtins.readFile ../../../tools/mcp/servers.json)).servers;
  mkCodexMcp = _name: v:
    { inherit (v) command args; }
    // lib.optionalAttrs ((v.env or { }) != { }) { inherit (v) env; };

  # codex の declarative 設定。pkgs.formats.toml で config.toml を生成し
  # codexConfig hook が mutable な実ファイルとして配置する。ベースは
  # ryoppippi/dotfiles の codex.nix。
  settings = {
    model = "gpt-5.5";
    approval_policy = "on-request";
    approvals_reviewer = "auto_review";
    allow_login_shell = true;
    model_reasoning_effort = "high";
    web_search_request = true;
    personality = "pragmatic";
    service_tier = "standard";
    project_doc_fallback_filenames = [ "CLAUDE.md" ];

    shell_environment_policy = {
      "inherit" = "all";
      experimental_use_profile = false;
    };

    features = {
      goals = true;
      multi_agent = true;
      terminal_resize_reflow = true;
    };

    notice.fast_default_opt_out = false;

    plugins."github@openai-curated".enabled = true;

    # MCP server は claude (setup-mcp.sh) と共有する tools/mcp/servers.json を
    # single source of truth として読み込む (上の mcpServers / mkCodexMcp 参照)。
    mcp_servers = lib.mapAttrs mkCodexMcp mcpServers;
  };
in
{
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/codex/AGENTS.md";

  # skills/ 配下は claude (apm.nix の --target claude,codex) が install する
  # skill ディレクトリ群が入る。claude.nix と同様 .gitignore のみ symlink で
  # 配置し、apm 産物を ignore する。
  home.file.".codex/skills/.gitignore".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/codex/skills/.gitignore";

  # config.toml を mutable な実ファイルとして毎回上書き配置する (read-only
  # symlink だと codex の trust 書込が code -32603 で失敗する。冒頭コメント
  # 参照)。前世代の read-only symlink が残っていても install が辿らないよう先に
  # 除去する。coreutils は activation の minimal PATH に無いので絶対パスで呼ぶ。
  # ~/.codex は自前で mkdir し home.file の link 順に依存しない。
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$HOME/.codex"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$HOME/.codex/config.toml"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 644 \
      ${tomlFormat.generate "codex-config.toml" settings} "$HOME/.codex/config.toml"
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
    # hook 本体を subshell で囲む理由は claudeCodeInstall と同じ (hook は
    # inline 展開され set -e で実行されるため top-level の `return` が使えず、
    # early-exit を `exit` で書く)。加えて上記の意図的に制限した PATH
    # ($PATH を足さない) を後続 hook へ漏らさない効果もある。
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
    # `curl | sh` のパイプは使わず、installer を一旦ファイルに落として curl の
    # 終了ステータスを直接 if で検査し、DL 成功時のみ実行する。SSL inspection 等で
    # curl が失敗したら DL を破棄して FAILED を出し次回 switch で再試行する。
    # パイプの終了ステータス解釈に頼らず DL の完全成功を独立に確認するため。
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
