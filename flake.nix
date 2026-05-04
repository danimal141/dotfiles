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
      # Hostname convention: "work" for the company Mac, "personal" /
      # "personal2" / "personal3" / ... for personal Macs. nix-darwin enforces
      # the hostname via networking.hostName in each host module so chezmoi's
      # hostname-based machineType detection lines up automatically.
      #
      # 新しい Mac を追加する手順:
      #   1. nix/hosts/<hostname>.nix を作成 (work.nix を雛形に)
      #   2. 下の hosts に 1 エントリ追加
      #   3. 新 Mac で `nix run nix-darwin -- switch --flake .#<hostname>`
      hosts = {
        "work"     = { user = "hideaki.ishii"; };
        # "personal" = { user = "danimal141"; };
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
