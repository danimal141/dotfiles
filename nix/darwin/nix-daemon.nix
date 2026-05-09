{ user, ... }:

# Nix daemon の運用設定 (`nix.settings` / `nix.gc`) と、daemon / shell に
# 流す系統の `environment.variables` をまとめる。CA bundle / Homebrew の
# 禁止 formula も daemon / shell が等しく見える必要があるので近接配置。
{
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
      # primaryUser を trusted にして daemon 経由のビルド (= sudo を求めない
      # nix store 操作 / `nix build`, `nix flake update` 等) を許可する。
      # `darwin-rebuild switch` 自体は nix-darwin の仕様変更で root 必須に
      # なったため `trusted-users` でも sudo は省略できないことに注意。
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
}
