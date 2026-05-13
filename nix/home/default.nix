{ user, ... }:

# home-manager (~/ 配下を declarative に管理する Nix module)。
#
# 方針:
#   * `home.file` で raw text dotfile (zshrc 等) を `mkOutOfStoreSymlink` で
#     `~/` に symlink 配置する。中身は repo 内のままなので編集体験は維持される
#     (エディタで開いて即 source できる)。
#   * Nix module の `programs.*` で型付けして書く方が綺麗なツール (starship,
#     mise 等) は home-manager で declarative に書く。
#   * 1 ファイル 1 ツールで `./programs/<tool>.nix` に分割。新規ツールは
#     必ずこちらに新ファイルを足し、imports に追加する。
{
  imports = [
    ./programs/zsh.nix
    ./programs/sheldon.nix
    ./programs/git.nix
    ./programs/tmux.nix
    ./programs/nvim.nix
    ./programs/claude.nix
    ./programs/codex.nix
    ./programs/apm.nix
    ./programs/mise.nix
    ./programs/markdownlint.nix
    ./programs/starship.nix
    ./programs/ghostty.nix
    ./programs/ctags.nix
    ./programs/vscode.nix
  ];

  # nixpkgs unstable に対応する home-manager リリース。
  # nix-darwin の system.stateVersion (= 6) とは別の値で、初回設定値を pin する。
  home.stateVersion = "25.11";

  # flake から渡された user で primary user を確定。multi-user 環境ではないので
  # 1 user 固定。
  home.username = user;
  home.homeDirectory = "/Users/${user}";

  # programs.home-manager.enable = true は darwin module 統合経路では不要。
  # standalone の `home-manager` CLI を使わない (= darwin-rebuild 1 発で活性化
  # する) ため、CLI の同梱インストールを避けて冪等性を維持する。
}
