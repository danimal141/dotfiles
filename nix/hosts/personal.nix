{ ... }:

{
  # Host module for the primary personal Mac.
  # nix-darwin sets LocalHostName / HostName to "personal" on apply, which lets
  # chezmoi auto-detect machineType = "personal" via hostname.
  # Add personal-only brews/casks (games, hobby tooling, etc.) here; cross-host
  # packages stay in nix/homebrew.nix.
  networking.hostName = "personal";
}
