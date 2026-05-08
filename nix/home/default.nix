{ user, ... }:

# home-manager (~/ 配下を declarative に管理する Nix module)。
#
# Phase 1 (move-nix) 以降の方針:
#   * `home.file` で raw text dotfile (zshrc 等) を `mkOutOfStoreSymlink` で
#     `~/` に symlink 配置する。中身は repo 内のままなので編集体験は維持される
#     (vim で開いて即 source できる)。
#   * Nix module の `programs.*` で型付けして書く方が綺麗なツール (starship,
#     direnv 等) は home-manager で declarative に書く。境界は移行と共に育てる。
#   * 移植は `./programs/<tool>.nix` で 1 ファイル 1 ツールに分割する。
#     prototype (Phase 1) では zsh のみ。Phase 2 以降で順次拡張する。
{
  imports = [
    ./programs/zsh.nix
    ./programs/git.nix
    ./programs/tmux.nix
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

  # ----------------------------------------------------------------------------
  # starship: shell prompt
  # ----------------------------------------------------------------------------
  # 旧 zsh prompt は `vcs_info` ベースで `[user] cwd (vcs)-[branch] %` 形式を
  # 出していた。starship に置き換えて宣言的に再現しつつ、Nix module の型付け
  # と `flake.lock` での pin を取りに行く。
  programs.starship = {
    enable = true;

    # zsh integration (= ~/.zshrc に `eval "$(starship init zsh)"` を注入) は
    # 無効化する。zsh の rc は chezmoi 管理 (`chezmoi/dot_zshrc.tmpl`) で集約
    # しているため、home-manager に zshrc 注入を許すと両者が衝突する。
    # eval 行は chezmoi 側で 1 行手書きする。
    enableZshIntegration = false;

    # 旧 vcs_info prompt のミニマル再現:
    #   [user] ~/path (git)-[main] %
    #
    # starship preset (Pure / Tokyo Night 等) を使わない理由は、既存環境からの
    # 認知負荷を最小化するため。慣れたら `programs.starship.settings` を user
    # 自身が iterate していけば良い。
    settings = {
      add_newline = false;

      format = "[\\[$username\\]]($style) $directory$git_branch$character";

      username = {
        show_always = true;
        format = "[\\[$user\\]]($style)";
        style_user = "green";
      };

      directory = {
        truncation_length = 3;
        format = "[$path]($style) ";
      };

      git_branch = {
        symbol = "";
        # starship の format string で escape が必要なのは ( ) [ ] $ \ のみ。
        # `-` は通常文字扱いで escape 不要 (`\-` だと parser error)。
        format = "[\\(git\\)-\\[$branch\\]]($style) ";
        style = "yellow";
      };

      # 元 prompt の `%#` (root: #, user: %) を再現
      character = {
        success_symbol = "[%](magenta)";
        error_symbol = "[%](red)";
      };
    };
  };
}
