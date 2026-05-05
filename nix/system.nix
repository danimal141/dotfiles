{ user, ... }:

# macOS システム設定 + Nix / nix-darwin 自体の運用 (flake / gc / 環境変数 /
# zsh の取扱い) を宣言するモジュール。
#
# `system.defaults.*` の設計方針:
#   * **既にユーザーが手動で設定済みの項目だけ** を宣言する (= 現状を flake に
#     スナップショットして以後 drift correction させる)。
#   * **macOS デフォルトのまま使っている項目は宣言しない**。宣言すると
#     `darwin-rebuild switch` のたびに値が固定されてしまい、System Settings
#     から微調整できなくなる。あとから「これも flake で固定したい」と思った
#     ものを足していくスタイル。
#
# アプリ単体の defaults (1Password / Raycast / Karabiner 等) は引き続きスコープ外。
# 必要になったら chezmoi 側の `run_once_*.sh` で `defaults write` を流す。
{
  # `system.defaults` / nix-homebrew が「誰の defaults を書くか」を決めるための
  # primary user 宣言。multi-user 環境ではないので flake から渡された user で固定。
  system.primaryUser = user;

  system.defaults = {
    # Dock: ユーザーが手動で設定済みの 2 項目のみを宣言。
    #   tilesize は宣言しないことで macOS デフォルトを維持する。
    dock = {
      autohide = true;
      # Spaces (デスクトップ) を最近使った順に勝手に並べ替えないようにする
      mru-spaces = false;
    };

    # Trackpad: タップ-クリックと三本指ドラッグを **OFF のまま固定**。
    #   現環境境ではいずれも無効が好み、誤って System Settings から有効化されても
    #   次の switch で戻る。
    trackpad = {
      Clicking = false;
      TrackpadThreeFingerDrag = false;
    };
  };

  # zsh の rc は chezmoi 管理 (`chezmoi/dot_zshrc.tmpl`) に集約する。
  # nix-darwin が /etc/zshrc を生成すると chezmoi 側の zshrc と読み込み順で
  # 競合 (PATH 重複 / completion 多重設定) しうるため明示的に無効化する。
  programs.zsh.enable = false;

  # brew で language runtime を入れるのを物理的に禁止する。
  # 動機: Node / Python / Ruby は mise が管理する。brew が依存解決の都合で
  # 勝手に node を入れると `which node` が二つ並び、PATH 順次第でビルドが壊れる。
  # `claude` は Anthropic が npm package として配るため、brew 経由で入れたい
  # ライブラリが裏で claude も pull するケースを防ぐ目的で含める。
  #
  # NIX_SSL_CERT_FILE は社内 VPN の SSL inspection (中間者 CA) に対応するため。
  # 詳細は下の `nix.settings.ssl-cert-file` コメント参照。
  environment.variables = {
    HOMEBREW_FORBIDDEN_FORMULAE = "node python python3 pip npm pnpm yarn claude";
    NIX_SSL_CERT_FILE = "/etc/nix/ca-bundle.pem";
  };

  nix = {
    settings = {
      # flake / nix command を使うので必須
      experimental-features = [ "nix-command" "flakes" ];
      # primaryUser を trusted にして sudo なしで `darwin-rebuild` を打てるようにする
      trusted-users = [ "@admin" user ];

      # 社内 VPN が SSL inspection (中間者 CA) を挟む環境向けに、macOS Keychain
      # 由来の CA bundle を nix-daemon にも教える。ファイル本体は host で生成し
      # /etc/nix/ca-bundle.pem に置く前提:
      #
      #   sudo bash -c '
      #     security find-certificate -a -p /Library/Keychains/System.keychain > /etc/nix/ca-bundle.pem
      #     security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain >> /etc/nix/ca-bundle.pem
      #   '
      #
      # bundle を更新したら `sudo launchctl kickstart -k system/org.nixos.nix-daemon`。
      # bundle 自体は社内 CA を含むためリポジトリにはコミットしない。
      ssl-cert-file = "/etc/nix/ca-bundle.pem";
    };

    # Nix store の自動 GC: 30 日以上前の世代を毎週日曜 03:00 に削除。
    # nix-darwin の世代も対象になるため、ロールバック先がある程度長く残るよう
    # 30d は手厚めに取る。容量が逼迫したら 14d 等に短縮を検討。
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  # nix-darwin の state 互換番号。手動 migration を伴うため上げない (現時点で 6)。
  system.stateVersion = 6;
}
