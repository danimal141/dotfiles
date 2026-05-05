{ user, ... }:

# macOS システム全体の設定 (Dock / Finder / KeyRepeat / trackpad / Nix 自体の挙動)。
#
# `darwin-rebuild switch` 一発で「OS の挙動」も復元できる状態にするためのモジュール。
# 直接 `defaults write com.apple.dock autohide -bool true` 等を叩く運用は
# 差分が追えずロールバックも効かないので、すべてここに集約する。
#
# スコープの境界:
#   * 含む: 全ユーザー / システム共通の defaults、Nix 自体の運用 (gc, flakes)
#   * 含まない: アプリ単位の defaults (1Password, Raycast, Karabiner 等)。
#     必要なら chezmoi 側 `run_once_*.sh` で `defaults write` を流す方針。
#     nix-darwin の `system.defaults.CustomUserPreferences` も使えるが、
#     アプリ側の plist スキーマが頻繁に変わるため運用が脆い。
{
  # `system.defaults` / GUI 設定の適用先ユーザーを宣言。
  # multi-user 環境ではないので flake から渡された user で固定する。
  system.primaryUser = user;

  system.defaults = {
    dock = {
      autohide = true;
      # Spaces の自動並べ替えを止める (画面切り替えで Space が動くと混乱)
      mru-spaces = false;
      tilesize = 48;
    };

    finder = {
      AppleShowAllFiles = true;
      FXEnableExtensionChangeWarning = false;
      ShowPathbar = true;
    };

    NSGlobalDomain = {
      # キーリピート: Apple 製の最速設定。Apple の UI で設定すると 15 が下限だが、
      # nix-darwin 経由なら 1〜 まで指定できる。15 / 2 は実機で痛くない最速ライン。
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      # vim ユーザー向け: 長押しでアクセント記号メニューを出さず、ただのリピートにする
      ApplePressAndHoldEnabled = false;
      AppleShowAllExtensions = true;
    };

    trackpad = {
      Clicking = true;
      # 三本指ドラッグ (システム環境設定からは消えたが内部 API で生きている)
      TrackpadThreeFingerDrag = true;
    };
  };

  # zsh の rc は chezmoi 管理 (`home/dot_zshrc.tmpl`) に集約する。
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
