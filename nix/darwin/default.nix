{ ... }:

# nix-darwin の system 層モジュールを束ねる entry point。flake.nix からは
# `./nix/darwin` を 1 つ import するだけで、ここから配下の機能別ファイルへ
# 展開される。
#
# 分割方針:
#   * `macos-defaults.nix` — `system.defaults.*` (Dock / Finder /
#     NSGlobalDomain / trackpad / WindowManager / menuExtraClock /
#     CustomUserPreferences)
#   * `keyboard.nix` — `system.keyboard` の HID remap、login 時に再適用する
#     LaunchAgent、`AppleSymbolicHotKeys` の targeted update
#   * `herdr.nix` — herdr server を常駐させる `launchd.user.agents.herdr-server`
#     (boot 直後の `detached from server` を防ぐ。`brew services` 併用禁止)
#   * `nix-daemon.nix` — `nix.settings` / `nix.gc` / Nix daemon が見える
#     `environment.variables` (HOMEBREW_FORBIDDEN_FORMULAE / NIX_SSL_CERT_FILE)
#   * `system.nix` — `system.primaryUser` / `users.users` / `programs.zsh.enable
#     = false` / `system.stateVersion` の root residual
#   * `packages.nix` — `environment.systemPackages` (Nix store CLI 群)
#   * `homebrew.nix` — `homebrew.*` (tap / brew / cask 宣言)
#
# host 個別 (`networking.hostName` など) の override は `./hosts/<host>.nix`
# を flake.nix から host 名指定で import している。本 default.nix では
# host 別ファイルは取り込まない (flake.nix で `mkHost` が動的に解決する
# パターンを維持)。
{
  imports = [
    ./macos-defaults.nix
    ./keyboard.nix
    ./herdr.nix
    ./nix-daemon.nix
    ./system.nix
    ./packages.nix
    ./homebrew.nix
  ];
}
