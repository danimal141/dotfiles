{ user, ... }:

# macOS システム設定 + Nix / nix-darwin 自体の運用 (flake / gc / 環境変数 /
# zsh の取扱い) を宣言するモジュール。
#
# `system.defaults.*` の設計方針: **既にユーザーが手動で設定済みの項目だけ**
# を宣言して以後 drift correction させる。macOS デフォルトのままで満足
# している項目は宣言しない (宣言すると System Settings からの微調整が
# `darwin-rebuild switch` で巻き戻されるため)。
#
# アプリ単体の defaults (1Password / Raycast / Karabiner 等) はスコープ外。
# 必要になったら `system.defaults.CustomUserPreferences` か手動
# `defaults write` で対応する。
{
  # `system.defaults` / nix-homebrew が「誰の defaults を書くか」を決めるための
  # primary user 宣言。multi-user 環境ではないので flake から渡された user で固定。
  system.primaryUser = user;

  # nix-darwin に user 本体を宣言する。home-manager の darwin module は
  # `users.users.<name>.home` から home directory を引くため、これ無しだと
  # home.homeDirectory が null として merge され「is not of type absolute path」
  # で activation が落ちる。home-manager 統合の前提条件。
  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
  };

  system.defaults = {
    dock = {
      autohide = true;
      # Spaces (デスクトップ) を最近使った順に勝手に並べ替えないようにする
      mru-spaces = false;
    };

    # タップ-クリック / 三本指ドラッグを OFF で固定 (誤って System Settings
    # で有効化されても次の switch で戻る)。
    trackpad = {
      Clicking = false;
      TrackpadThreeFingerDrag = false;
    };
  };

  # zsh の rc は repo の `zsh/.zshrc` を home.file で `~/.zshrc` に symlink
  # 配置する (nix/home/programs/zsh.nix)。nix-darwin が /etc/zshrc を生成
  # すると home-manager 側の zshrc と読み込み順で競合 (PATH 重複 /
  # completion 多重設定) しうるため、system 側 zsh module は無効化する。
  programs.zsh.enable = false;

  # HOMEBREW_FORBIDDEN_FORMULAE: language runtime (node / python / ruby) は
  # mise が管理する。brew の依存解決が裏で node を pull すると PATH 順次第で
  # ビルドが壊れるため物理的に禁止する。`claude` は Anthropic 公式の npm
  # package で同様の二重 install を避けたいので含める。
  #
  # NIX_SSL_CERT_FILE: 社内 VPN の SSL inspection 対策 (下の
  # `nix.settings.ssl-cert-file` と同じ bundle を user shell にも見せる)。
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

      # 社内 VPN の SSL inspection (中間者 CA) 対策。bundle は setup.sh が
      # macOS Keychain から `/etc/nix/ca-bundle.pem` に焼き出す。社内 CA を
      # 含むため bundle 自体はリポジトリに commit しない。bundle を更新した
      # ときは `sudo launchctl kickstart -k system/org.nixos.nix-daemon`。
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
