{
  config,
  lib,
  pkgs,
  dotfilesPath,
  ...
}:

# Codex CLI 設定 (~/.codex/) を home-manager で管理する。
#
#   * AGENTS.md は repo の tools/codex/AGENTS.md を指す out-of-store symlink。
#     tools/codex/AGENTS.md 自体が ../claude/CLAUDE.md への in-repo symlink な
#     ので、~/.codex/AGENTS.md → tools/codex/AGENTS.md → tools/claude/CLAUDE.md
#     の 2 段で解決する。CLAUDE.md 編集が ~/.claude/CLAUDE.md と
#     ~/.codex/AGENTS.md の両方に即反映される (同じ system instruction を共有)。
#   * agents/ は repo の tools/codex/agents/ を指す out-of-store symlink。
#     Codex 固有の custom agent を Claude Code と分離して管理する。
#   * Claude Code 向けに MDM 配布済みの gws skill は、codexGwsSkills activation
#     hook が ~/.agents/skills/ へ個別 symlink を張り Codex からも再利用する。
#     skill 本体は複製せず、配布元が無い環境では何もせず skip する。
#   * hooks.json / hooks/ は repo の tools/codex/ を指す out-of-store symlink。
#     破壊コマンド遮断ポリシーは tools/claude/hooks/ と symlink で共有し、
#     sandbox / approval の補助 guardrail として使う。
#   * rules/destructive.rules は個別 out-of-store symlink。~/.codex/rules/
#     全体は codex が承認済み allow rule を default.rules に追記する mutable 領域
#     なので symlink しない。
#   * herdr-agent-state.sh は herdr の agent-state 連携 hook。生成物だが
#     ~/.codex 直下 (mutable 領域) に落ちるため、明示的に out-of-store symlink を
#     張って tracked にする。これを省くと登録先の hooks.json (tracked) に entry
#     だけが残り、script の無い他マシンで壊れる。再生成は
#     `herdr integration install codex` の手動 bootstrap (nix/home/programs/herdr.nix)。
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
#     難しい作業用の astra.config.toml と設計相談用の sol.config.toml も同じ
#     activation hook で mutable な profile として配置する。
#   * codex binary 本体は OpenAI 公式 native installer を取得して
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
  mkCodexMcp =
    _name: v:
    { inherit (v) command args; } // lib.optionalAttrs ((v.env or { }) != { }) { inherit (v) env; };

  # codex の declarative 設定。pkgs.formats.toml で config.toml を生成し
  # codexConfig hook が mutable な実ファイルとして配置する。ベースは
  # ryoppippi/dotfiles の codex.nix。
  settings = {
    model = "gpt-5.6-luna";
    approval_policy = "on-request";
    approvals_reviewer = "auto_review";
    allow_login_shell = true;
    # approval_policy と組み合わせ、repo 内は自動実行しつつ sandbox 外だけ
    # 承認を求める。CLI の明示指定 (herdr など) がある場合はそちらを優先する。
    sandbox_mode = "workspace-write";
    model_reasoning_effort = "max";
    # /review は、実装用 Luna と別視点の Sol に分ける。
    review_model = "gpt-5.6-sol";
    web_search = "live";
    personality = "pragmatic";
    project_doc_fallback_filenames = [ "CLAUDE.md" ];
    # Codex 専用の全セッション共通指示。公式設定は inline string のみで外部
    # instruction file を受けないため、flake から確実に評価できるここを SSoT にする。
    developer_instructions = ''
      メインエージェント (Luna) が実装・調査・検証を直接実行する。
      委譲が許可されている場合は、以下の基準で必要な相談・独立検証を行う。

      * 実装、コード探索、テスト、lint、diff 確認はメインエージェントが直接実行してよい
      * 新しい構造・インターフェース、設定・データ・互換性の設計に未解決の選択や
        トレードオフがあるときは、実装前に `architect` (Sol) へ目的・制約・仮案を
        渡して相談する。既存方針に沿う機械的変更は、複数ファイルでも相談不要
      * 設計判断は Sol に相談し、Luna は確定した方針に沿って実働を進める。
        結果を左右する要件の曖昧さはユーザーに質問する
      * 独立した成果物を返せる作業だけを必要最小限の agent に委譲する。
        同じ調査を親子で重複させず、同じファイルを複数 agent に同時編集させない
      * 委譲時は役割を明示し、目的・成功条件・対象パス・必要な制約を自己完結して
        渡す。`fork_turns` が使える場合は原則 `none` とし、会話の経緯が必要な
        場合だけ履歴を引き継ぐ。結果は結論・根拠の場所・未解決点に絞って受け取る
      * 作業開始時に、依頼を検証可能な成功条件とスコープ外事項に分ける。
        自明な小変更では明示的な計画を省略してよい
      * 複数ファイルにまたがる振る舞い、実行時設定・データ・互換性、または失敗
        コストが高い変更では、実装後かつ最終回答前に `verifier` agent へ成功条件、
        変更範囲、既知の制約を渡して独立検証させる。文書・コメントだけの変更や
        自明な機械的変更は、ファイル数によらず直接検証でよい。委譲が使えない
        場合も必要な検証は直接行う
      * verifier の `FAIL` / `INCONCLUSIVE` を `PASS` と扱わない。再試行は状態を
        変更したか、新しい情報を得る目的がある場合に限る。同じ状態で同じ失敗を
        反復せず、解消できなければ証拠と阻害要因を報告する
      * 検索・ファイル読み取りは対象と範囲を絞る。大量出力はログに保存し、
        終了コード・要約・必要な失敗箇所を読む。独立検証後の同じチェックは、
        追加変更や未解決の懸念がない限り繰り返さない
      * 成功条件を満たしたら依頼外へ広げず終了する。最終回答には変更点、検証
        コマンドと結果、未検証事項または残存リスクを含める
    '';
    # subagent (multi-agent) の既定値。実装 worker は custom agent で luna / max、
    # 軽量な探索は explorer で luna / medium、設計・レビューは sol / high に分ける。
    # 未指定の subagent は luna / high とし、設計相談だけ architect agent (sol / high)
    # に委譲する。[agents] は
    # 既知フィールド以外を AgentRoleToml (custom agent 定義) として解釈するので、
    # key 名を間違えると parse error になる (`codex exec --strict-config` で検証済み)。
    agents = {
      max_concurrent_threads_per_session = 8;
      default_subagent_model = "gpt-5.6-luna";
      default_subagent_reasoning_effort = "high";
    };

    shell_environment_policy = {
      "inherit" = "all";
      # inherit=all のままでも、Codex が定める secret-like な環境変数は
      # subagent の shell に渡さない。必要な値は対象コマンドへ明示的に渡す。
      ignore_default_excludes = false;
      experimental_use_profile = false;
    };

    features = {
      goals = true;
      hooks = true;
      multi_agent = true;
    };

    tui = {
      notifications = [ "approval-requested" ];
      notification_condition = "unfocused";
    };

    notice.fast_default_opt_out = false;

    marketplaces."dx-platform-workspace" = {
      source_type = "local";
      source = "${config.home.homeDirectory}/Documents/dev/dx-platform-workspace";
    };

    plugins."github@openai-curated".enabled = true;
    plugins."dev-ops@dx-platform-workspace".enabled = true;
    plugins."setup@dx-platform-workspace".enabled = true;
    plugins."toil@dx-platform-workspace".enabled = true;
    plugins."harness@dx-platform-workspace".enabled = true;
    plugins."auto-approve@dx-platform-workspace".enabled = true;
    plugins."session-tmpdir@dx-platform-workspace".enabled = true;

    # MCP server は claude (setup-mcp.sh) と共有する tools/mcp/servers.json を
    # single source of truth として読み込む (上の mcpServers / mkCodexMcp 参照)。
    mcp_servers = lib.mapAttrs mkCodexMcp mcpServers;
  };

  # 設計・相談専用の advisor モード (`codex -p sol`)。Claude Code の opusplan
  # (Plan=Opus / 実行=Sonnet) に相当する役割分離を profile で再現する。
  # read-only sandbox により Sol セッションが実装にトークンを使わないことを
  # 構造で保証する。例外的に Sol で編集したいときは
  # `codex -p sol -s workspace-write` で明示 override する。
  # 現行 codex の profile v2 は config.toml 内の [profiles.<name>] (legacy) を
  # 拒否し、$CODEX_HOME/<name>.config.toml という別ファイルを要求する。codex は
  # profile ファイルにも [projects] trust 等の状態を追記するため、config.toml と
  # 同じく codexConfig hook で mutable な実ファイルとして毎回上書き配置する。
  solProfile = {
    model = "gpt-5.6-sol";
    model_reasoning_effort = "high";
    sandbox_mode = "read-only";
    # profile の developer_instructions は base config のものを完全に置き換える
    # (継承しない。マーカー入り rollout で検証済み)。これを書かないと sol
    # セッションが Luna root 向けの「実装は直接実行してよい」指示を継承し、
    # advisor ではなく実装者として振る舞ってしまう。
    developer_instructions = ''
      このセッションは設計・相談専用の advisor モード (Sol)。実装はしない。

      * 担当は要件整理、アーキテクチャ選択、トレードオフ分析、分解方針、
        成功条件の定義、実装計画の提示、コードレビュー
      * コードやドキュメントの編集、コミットなどファイルを変更する操作は行わず、
        sandbox 外実行の承認も求めない
      * 調査のための読み取り (コード閲覧、検索、ログ確認) は自由に行ってよい
      * 成果物は、そのまま実装セッション (Luna) に渡せる粒度の実装計画・
        設計判断としてまとめて返す
      * 実装まで依頼されたら、このセッションでは行わず通常の `codex` (Luna) での
        実行を案内する
    '';
  };

  # 難しい end-to-end 作業用の Astra root profile (`codex -p astra`)。
  # 既定を high にして、品質と token / latency のバランスを取る。最難関だけ
  # `codex -p astra -c model_reasoning_effort=max` で明示的に昇格する。
  # developer_instructions は profile 適用時に base を完全置換するため、Astra
  # root 用の完了条件、委譲、検証、停止条件をここに自己完結させる。
  astraProfile = {
    model = "gpt-6-astra";
    model_reasoning_effort = "high";
    developer_instructions = ''
      このセッションは gpt-6-astra を使う難しい実装・調査の root モード。
      Astra が設計・方針策定・統合・最終判断を担当し、実装・調査は Luna、
      検証は Sol に委譲する。

      * 作業開始時に、依頼を目的、検証可能な成功条件、スコープ外事項に分ける。
        自明な小変更では明示的な計画を省略してよい
      * ユーザーの依頼が作業を求める形で、通常の前提で安全に進められる場合は、
        確認待ちにせず明示した前提で進める。結果が変わる不足情報だけ早めに質問する
      * root が設計判断を行い、未解決のトレードオフや別視点での評価が必要な場合に
        `architect` (Sol) へ論点を絞って相談する。既存方針に沿う機械的変更は、
        複数ファイルでも相談不要。結果を左右する要件の曖昧さはユーザーに質問する
      * 委譲が許可されている場合は、実装を `worker`、調査を `explorer` (Luna)、
        検証を `verifier` (Sol) に渡す。方針と成功条件が決まったまとまりで依頼し、
        小さな操作ごとに agent を増やさない。同じ調査を親子で重複させない
      * 並列化は独立した作業だけにし、同じファイルを同時編集させない。依存する
        作業は前の結果を統合してから渡す。委譲した結果はすべて統合して完了する
      * 委譲時は役割を明示し、目的・成功条件・対象パス・必要な制約を自己完結して
        渡す。`fork_turns` が使える場合は原則 `none` とし、会話の経緯が必要な
        場合だけ履歴を引き継ぐ。結果は結論・根拠の場所・未解決点に絞って受け取る
      * 複数ファイルにまたがる振る舞い、実行時設定・データ・互換性、または失敗
        コストが高い変更では、実装後かつ最終回答前に `verifier` agent へ成功条件、
        変更範囲、既知の制約を渡して独立検証させる。文書・コメントだけの変更や
        自明な機械的変更は、ファイル数によらず直接検証でよい。委譲が使えない
        場合も必要な検証は root が直接行う
      * verifier の `FAIL` / `INCONCLUSIVE` を `PASS` と扱わない。再試行は状態を
        変更したか、新しい情報を得る目的がある場合に限る。同じ状態で同じ失敗を
        反復せず、解消できなければ証拠と阻害要因を報告する
      * 変更に必要なテスト、lint、build、diff 確認を実行する。適切なチェックが通り、
        追加変更や未解決の懸念がなければ、独立検証済みのチェックを繰り返さない
      * 検索・ファイル読み取りは対象と範囲を絞る。大量出力はログに保存し、
        終了コード・要約・必要な失敗箇所を読む
      * 成功条件を満たしたら依頼外へ広げず終了する。最終回答には変更点、検証
        コマンドと結果、未検証事項または残存リスクを含める
    '';
  };
in
{
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/codex/AGENTS.md";
  home.file.".codex/agents".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/codex/agents";
  home.file.".codex/hooks.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/codex/hooks.json";
  home.file.".codex/hooks".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/codex/hooks";
  home.file.".codex/scripts".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/codex/scripts";
  home.file.".codex/herdr-agent-state.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/codex/herdr-agent-state.sh";
  home.file.".codex/rules/destructive.rules".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/tools/codex/rules/destructive.rules";

  # apm (--target claude,codex) の skill は ~/.codex/skills/ ではなく cross-agent
  # 標準の ~/.agents/skills/ に配布され、codex がそこを auto-discover する
  # (~/.codex/skills/ は codex 内蔵の .system 専用)。通常の skill は apm が管理し、
  # MDM 配布済みの gws skill だけは下の activation hook で同じ場所へ追加する。

  # Claude Code 用 marketplace に MDM 配布済みの gws skill を Codex からも使える
  # よう ~/.agents/skills/ へ個別 symlink する。Codex は user-scope skill directory
  # と symlinked skill folder の両方を公式にサポートしている。apm install の後に
  # 実行し、apm が ~/.agents/skills/ を更新しても最終状態に link が残るようにする。
  # 配布元が無い個人端末では skip し、同名の実 directory がある場合は上書きしない。
  home.activation.codexGwsSkills = lib.hm.dag.entryAfter [ "apmInstall" ] ''
    GWS_SKILLS_SOURCE="/Library/Application Support/ClaudeCode/marketplace/gws-skills/plugins/gws/skills"
    CODEX_SKILLS_TARGET="$HOME/.agents/skills"

    if [ ! -d "$GWS_SKILLS_SOURCE" ]; then
      echo "[codexGwsSkills] skip (managed gws skills not found)"
    else
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$CODEX_SKILLS_TARGET"
      for GWS_SKILL_SOURCE in "$GWS_SKILLS_SOURCE"/gws-*; do
        [ -d "$GWS_SKILL_SOURCE" ] || continue
        GWS_SKILL_NAME="''${GWS_SKILL_SOURCE##*/}"
        GWS_SKILL_TARGET="$CODEX_SKILLS_TARGET/$GWS_SKILL_NAME"

        if [ -e "$GWS_SKILL_TARGET" ] && [ ! -L "$GWS_SKILL_TARGET" ]; then
          echo "[codexGwsSkills] skip $GWS_SKILL_NAME (non-symlink target exists)" >&2
          continue
        fi
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -sfn "$GWS_SKILL_SOURCE" "$GWS_SKILL_TARGET"
      done
    fi
  '';

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
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$HOME/.codex/sol.config.toml"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 644 \
      ${tomlFormat.generate "codex-sol-profile.toml" solProfile} "$HOME/.codex/sol.config.toml"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$HOME/.codex/astra.config.toml"
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 644 \
      ${tomlFormat.generate "codex-astra-profile.toml" astraProfile} "$HOME/.codex/astra.config.toml"
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
