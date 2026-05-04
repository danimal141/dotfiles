{ ... }:

{
  # Host-specific overrides for hideaki-ishii1 (work Mac, company-issued).
  # chezmoi auto-detects this hostname as machineType = "work".
  # Add work-only brews/casks (company VPN, internal CLI, etc.) here.
  # Cross-host packages stay in nix/homebrew.nix.
  networking.hostName = "hideaki-ishii1";
}
