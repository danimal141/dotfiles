# nix-darwin で macOS / Homebrew / Nix store の CLI を宣言的に管理するための
# トップレベル flake。
#
# Brewfile + brew bundle / 手動の `defaults write` 運用では次が成立しない:
#   * 「宣言から外したら自動 uninstall」(cleanup フラグなし)
#   * macOS defaults (Dock / KeyRepeat / trackpad) の宣言的同期
#   * 世代単位のロールバック
#   * 別 Mac で同一バイナリが入る保証 (brew 最新追従なのでバージョンが揺らぐ)
# これらを `darwin-rebuild switch` 一発で揃え、CLI バイナリは Nixpkgs から
# `flake.lock` で pin することで再現性を担保する。
#
# 構成上の方針:
#   * `inputs` は最小限。nixpkgs-unstable に追従し、子 input は
#     `nixpkgs.follows = "nixpkgs"` で nixpkgs を共有して store 重複を避ける。
#   * ホスト追加コストを下げるため `hosts` を attrset で持ち、`mkHost` で
#     `darwinConfigurations.<hostname>` に展開する。
#   * モジュールは `nix/system.nix` (macOS settings) / `nix/packages.nix`
#     (Nix store CLI) / `nix/homebrew.nix` (brew/cask) の三層に分割し、
#     ホスト個別差分のみ `nix/hosts/<hostname>.nix` に書く。
{
  description = "danimal141 dotfiles - nix-darwin + home-manager";

  inputs = {
    # nixpkgs-unstable: nix-darwin と組み合わせる際に安定リリースより追従が
    # 速く、Homebrew 補完が必要な領域 (新しい cask 等) で詰まりにくい。
    # 個別 input は `nix flake lock --update-input nixpkgs` で更新する想定。
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-homebrew: Homebrew のインストール / brew / cask 宣言を nix-darwin の
    # モジュールとして扱う。`autoMigrate = true` で既存の手動 brew インストールも
    # 引き継げる。
    #
    # Fork commit に pin。nix-homebrew 側の Homebrew/brew 追従が遅れると
    # cask metadata の schema 変更で fetch が壊れることがあるため、
    # lock 更新時は upstream main へ戻せるか確認する。
    nix-homebrew = {
      url = "github:matinzd/nix-homebrew/a3b7269392d2b8379434fc3d4d3694c92e9e2278";
    };

    # APM (microsoft/apm) は本家 nixpkgs に未収録。numtide が提供する
    # `llm-agents.nix` flake に APM を含む LLM 周辺ツールが daily auto-update
    # で packaging されているので、これを inputs に取り込んで `nix/packages.nix`
    # から `inputs.llm-agents.packages.${system}.apm` として参照する。
    # `nixpkgs.follows` で nixpkgs を共有し、Nix store を重複させない。
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # home-manager: ~/ 配下 (= user-level) の declarative 管理モジュール。
    # nixpkgs-unstable に合わせるため、release branch ではなく master の特定
    # commit を pin する。
    home-manager = {
      url = "github:nix-community/home-manager/00ed86e58bb6979a7921859fd1615d19382eac5c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, nix-homebrew, llm-agents, home-manager }:
    let
      # Hostname 規約:
      #   "work"     — 仕事用 Mac
      #   "personal" / "personal2" / "personal3" / ... — 個人用 Mac
      #
      # nix-darwin の `networking.hostName` を各ホストモジュールに書くことで、
      # apply 時に LocalHostName / HostName が必ず上記規約名で固定される。
      # IT 部門が払い出した個別 hostname (例: hideaki-ishii1) に左右されない。
      #
      # 新しい Mac を追加する手順:
      #   1. nix/hosts/<hostname>.nix を作成 (work.nix を雛形に)
      #   2. 下の hosts に 1 エントリ追加
      #   3. 新 Mac で `nix run nix-darwin -- switch --flake .#<hostname>`
      hosts = {
        "work" = {
          user = "hideaki.ishii";
          gitName = "danimal141";
          gitEmail = "hideaki.ishii1204@gmail.com";
        };
        "personal" = {
          user = "danimal141";
          gitName = "danimal141";
          gitEmail = "hideaki.ishii1204@gmail.com";
        };
      };

      # ホスト attrset を `darwinConfigurations` に展開するヘルパー。
      # specialArgs で `user` / `hostname` / `gitName` / `gitEmail` /
      # `dotfilesPath` / `inputs` を全モジュールに渡す:
      #   `user`         — `nix/system.nix` が primaryUser に使う
      #   `hostname`     — モジュール内で host 別判定したい場合の保険 (現状未使用)
      #   `gitName` / `gitEmail` — `nix/home/programs/git.nix` の identity に使う
      #   `dotfilesPath` — repo の絶対 path。`nix/home/programs/*.nix` が
      #     `mkOutOfStoreSymlink` の引数や `builtins.readFile` の引数に使う。
      #     1 ヶ所宣言にして全 module に流すことで重複定義を避ける。
      #   `inputs`       — `nix/packages.nix` が llm-agents.packages を参照する
      # Apple Silicon 専用想定なので system は aarch64-darwin に固定。
      # Intel Mac (x86_64-darwin) サポートが必要になったら関数引数に戻す。
      mkHost = hostname: { user, gitName, gitEmail }:
        let
          dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
        in
        nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit user hostname gitName gitEmail dotfilesPath inputs; };
          modules = [
            # nix/darwin/default.nix が defaults / keyboard / nix-daemon /
            # system.nix (residual) / packages.nix / homebrew.nix を一括 imports。
            # 機能ごとの分割理由は `nix/darwin/default.nix` の header を参照。
            ./nix/darwin
            (./nix/darwin/hosts + "/${hostname}.nix")

            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                # `enableRosetta` は module default = false なので明示しない。
                # Apple Silicon 前提なので x86_64 brew は走らせない。
                inherit user;
                # 既存の手動 Homebrew インストールを乗っ取る (再構築不要)
                autoMigrate = true;
              };
            }

            # home-manager を nix-darwin module として統合する。
            # `darwin-rebuild switch` 1 発で system 層 (nix-darwin) と user 層
            # (home-manager) の activation が連動し、setup.sh の linear flow を
            # 崩さない。standalone の `home-manager switch` を別途呼ぶ運用は
            # 採らない (= bootstrap が複雑化する)。
            home-manager.darwinModules.home-manager
            {
              # useGlobalPkgs: home-manager が独自の pkgs を評価せず、
              #   nix-darwin の nixpkgs を共有 (= store 重複と評価コストの回避)。
              # useUserPackages: `home.packages` が `/etc/profiles/per-user/<user>/`
              #   に install される (= `nix-env -i` 経路ではなく activation 経由)。
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${user} = import ./nix/home;
              # home-manager 側のモジュールにも host の specialArgs を渡す
              # (system 層と整合)。`gitName` / `gitEmail` は
              # `nix/home/programs/git.nix` が消費する。
              home-manager.extraSpecialArgs = { inherit user gitName gitEmail dotfilesPath; };
              # home.file で配置される ~/.zshrc 等が「既に手で書かれた状態」で
              # 衝突する初回 apply で `Existing file would be clobbered` の
              # activation 中断を避ける。`<path>.backup` にリネームして
              # symlink を貼り直すので、初回以降は副作用ゼロ。
              home-manager.backupFileExtension = "backup";
            }
          ];
        };
      # `apps.<system>.<name>` 経由で expose する shell script の生成に使う pkgs。
      # `nix run .#<name>` が走るたびに評価されるので legacyPackages で十分
      # (overlay や config 拡張が無い純 nixpkgs)。Apple Silicon 専用想定。
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;

      # AI agent (Claude Code / Codex / Gemini CLI 等) から呼ばれた時は
      # nix-output-monitor (nom) のような TTY-rich な出力を抑制する。
      # nom は ANSI escape を多用して live-update する仕様で、PTY なしの
      # subprocess (= AI agent から見た tool execution) では文字化けや
      # 巨大ログ量で context を浪費するため。
      isAgentCheck = ''
        IS_AI_AGENT=false
        for var in CLAUDE_CODE CLAUDECODE CODEX_SANDBOX CODEX_THREAD_ID GEMINI_CLI OPENCODE AUGMENT_AGENT GOOSE_PROVIDER CURSOR_AGENT AI_AGENT; do
          eval "val=\''${!var:-}"
          if [ -n "$val" ]; then
            IS_AI_AGENT=true
            break
          fi
        done
      '';

      # `pkgs.writeShellScript` で書いた shell を `nix run` から呼べる
      # `apps.*` 形式に包む。`darwin-rebuild` 等は flake input から絶対 path で
      # 解決し、PATH に依存しない (= 初回 bootstrap でも動く)。
      # `meta.description` は `nix flake show` での一覧表示用。
      mkApp = name: description: script: {
        type = "app";
        program = toString (pkgs.writeShellScript name script);
        meta = { inherit description; };
      };

      # 現在の Mac の hostname を `darwinConfigurations.<host>` の host 名に
      # 揃えるための shell snippet。`scutil --get LocalHostName` は
      # nix-darwin が apply 時に強制した名前 (work / personal / ...) を返す。
      hostnameSnippet = ''HOST=$(/usr/sbin/scutil --get LocalHostName)'';

      darwinRebuild = "${nix-darwin.packages.aarch64-darwin.darwin-rebuild}/bin/darwin-rebuild";
    in
    {
      darwinConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;

      # `nix fmt` 用フォーマッタ。RFC スタイルで nix ファイルを揃える。
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-rfc-style;

      # ============================================================
      # `nix run .#<name>` で呼べる日常運用 utility
      # ============================================================
      # 設計方針:
      #   * ホスト判定は実行時に `scutil --get LocalHostName` で動的解決
      #     (= work / personal を 1 つの app で兼ねる)。
      #   * darwin-rebuild は flake input の `nix-darwin.packages` から
      #     絶対 path で呼ぶ。`/run/current-system/sw/bin/...` 経由だと
      #     初回 bootstrap (= まだ system が build されていない) で
      #     PATH 解決できないため。
      #   * AI agent 環境では nom 連携をスキップ (上の `isAgentCheck` 参照)。
      apps.aarch64-darwin = {
        # `nix run .#switch` — system 設定を build + activate。
        # 日常運用の主役 (元の `darwin-rebuild switch --flake ...` 直叩きを置換)。
        #
        # `sudo -v` で先に credential cache を埋めてから本体を起動する。
        # `sudo darwin-rebuild ... |& nom` の `|&` は sudo の password
        # prompt (stderr) ごと nom に流すため、`-v` を挟まないと prompt が
        # nom UI に呑み込まれてユーザーが入力タイミングを見失う。
        switch = mkApp "darwin-switch" "Build and activate the darwin configuration for this host" ''
          set -eo pipefail
          ${isAgentCheck}
          ${hostnameSnippet}
          echo "Switching darwin configuration: .#$HOST"
          sudo -v
          if [ "$IS_AI_AGENT" = true ]; then
            sudo ${darwinRebuild} switch --flake ".#$HOST"
          else
            sudo ${darwinRebuild} switch --flake ".#$HOST" |& ${pkgs.nix-output-monitor}/bin/nom
          fi
          echo "Done!"
        '';

        # `nix run .#build` — system 設定を build (activate せず dry-run)。
        # apply 前に評価エラーや build 失敗を検出する用途。
        build = mkApp "darwin-build" "Dry-build the darwin configuration without activating" ''
          set -eo pipefail
          ${isAgentCheck}
          ${hostnameSnippet}
          echo "Building darwin configuration: .#$HOST"
          if [ "$IS_AI_AGENT" = true ]; then
            nix build ".#darwinConfigurations.$HOST.system"
          else
            ${pkgs.nix-output-monitor}/bin/nom build ".#darwinConfigurations.$HOST.system"
          fi
          echo "Build successful. Run 'nix run .#switch' to apply."
        '';

        # `nix run .#update` — flake.lock を更新 (全 input)。
        # 個別 input だけ更新したい場合は通常の `nix flake update <input>` を使う。
        update = mkApp "flake-update" "Update flake.lock for all inputs" ''
          set -eo pipefail
          echo "Updating flake.lock..."
          nix flake update
          echo "Done. Run 'nix run .#switch' to apply changes."
        '';
      };
    };
}
