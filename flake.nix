# Step B の目的:
#   Homebrew パッケージ (brew / cask) と macOS システム設定を nix-darwin で
#   宣言的に管理し、`darwin-rebuild switch` 一発で同期する状態に持っていく。
#
#   Brewfile + brew bundle 運用では:
#     * 「宣言から外したら自動 uninstall」が効かない (cleanup フラグなし)
#     * macOS の defaults (Dock / KeyRepeat / trackpad) は別系統で管理が必要
#     * 世代単位のロールバックが効かない
#   nix-darwin に寄せることで上記すべてが `flake.nix` 配下に集約される。
#
# 構成上の方針:
#   * `inputs` は最小限。nixpkgs-unstable に追従し、nix-darwin / nix-homebrew は
#     `nixpkgs.follows = "nixpkgs"` で nixpkgs を共有して store 重複を避ける。
#   * ホスト追加コストを下げるため `hosts` を attrset で持ち、`mkHost` で
#     `darwinConfigurations.<hostname>` に展開する。
#   * `nix/system.nix` / `nix/homebrew.nix` を全ホスト共通モジュールとして配置し、
#     ホスト個別差分のみ `nix/hosts/<hostname>.nix` に書く。
{
  description = "danimal141 dotfiles - chezmoi + nix-darwin";

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
    # 引き継げるため、移行時に Homebrew を再導入する必要がない。
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, nix-homebrew }:
    let
      # Hostname 規約:
      #   "work"     — 仕事用 Mac
      #   "personal" / "personal2" / "personal3" / ... — 個人用 Mac
      #
      # nix-darwin の `networking.hostName` を各ホストモジュールに書くことで、
      # apply 時に LocalHostName / HostName が必ず上記規約名で固定される。
      # IT 部門が払い出した個別 hostname (例: hideaki-ishii1) に左右されないため、
      # chezmoi 側の hostname ベース machineType 判定もこのリストと整合する。
      #
      # 新しい Mac を追加する手順:
      #   1. nix/hosts/<hostname>.nix を作成 (work.nix を雛形に)
      #   2. 下の hosts に 1 エントリ追加
      #   3. 新 Mac で `nix run nix-darwin -- switch --flake .#<hostname>`
      hosts = {
        "work"     = { user = "hideaki.ishii"; };
        "personal" = { user = "danimal141"; };
      };

      # ホスト attrset を `darwinConfigurations` に展開するヘルパー。
      # specialArgs で `user` / `hostname` を全モジュールに渡し、各モジュールで
      # `{ user, ... }` のように受け取れるようにする。
      mkHost = hostname: { user, system ? "aarch64-darwin" }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit user hostname; };
          modules = [
            ./nix/system.nix
            ./nix/homebrew.nix
            (./nix/hosts + "/${hostname}.nix")

            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                # Apple Silicon 専用想定。Intel Mac は Rosetta なしで動かす。
                enableRosetta = false;
                inherit user;
                # 既存の手動 Homebrew インストールを乗っ取る (再構築不要)
                autoMigrate = true;
              };
            }
          ];
        };
    in
    {
      darwinConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;

      # `nix fmt` 用フォーマッタ。RFC スタイルで nix ファイルを揃える。
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-rfc-style;
    };
}
