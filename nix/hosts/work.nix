{ ... }:

{
  # Host module for the company-issued Mac.
  # nix-darwin will rename LocalHostName / HostName to "work" on apply, which in
  # turn lets chezmoi auto-detect machineType = "work" via hostname.
  # Add work-only brews/casks (VPN client, internal CLI, etc.) here; cross-host
  # packages stay in nix/homebrew.nix.
  networking.hostName = "work";
}
