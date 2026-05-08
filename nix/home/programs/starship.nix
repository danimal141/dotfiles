{ ... }:

# starship: shell prompt
#
# 旧 zsh prompt は `vcs_info` ベースで `[user] cwd (vcs)-[branch] %` 形式を
# 出していた。starship に置き換えて宣言的に再現しつつ、Nix module の型付け
# と `flake.lock` での pin を取りに行く。
#
# enableZshIntegration を false にする理由:
# zshrc は repo の zsh/.zshrc を home.file で symlink 配置している。
# home-manager に zshrc 注入を許すと両者が衝突するため、`eval "$(starship
# init zsh)"` の 1 行は zshrc に手書きで持たせ続ける (mise.nix と統一の方針)。
{
  programs.starship = {
    enable = true;
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
