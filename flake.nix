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
      mkHost = { hostname, system ? "aarch64-darwin", user ? "hideaki.ishii" }:
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
                user = user;
                autoMigrate = true;
              };
            }
          ];
        };
    in
    {
      darwinConfigurations."hideaki-ishii1" = mkHost {
        hostname = "hideaki-ishii1";
      };

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-rfc-style;
    };
}
