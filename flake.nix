{
  description = "danimal141 dotfiles - chezmoi + nix-darwin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, nix-homebrew }:
    let
      # 新しい Mac を追加する手順:
      #   1. 新 Mac で `scutil --get LocalHostName` で hostname を確認
      #   2. nix/hosts/<hostname>.nix を作成 (hideaki-ishii1.nix を雛形に)
      #   3. 下の hosts に 1 エントリ追加
      #   4. 新 Mac で `nix run nix-darwin -- switch --flake .#<hostname>`
      hosts = {
        "hideaki-ishii1" = { user = "hideaki.ishii"; };
        # "personal-mbp"   = { user = "danimal141"; };
      };

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
                enableRosetta = false;
                inherit user;
                autoMigrate = true;
              };
            }
          ];
        };
    in
    {
      darwinConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-rfc-style;
    };
}
