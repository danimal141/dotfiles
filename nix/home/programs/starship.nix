{ ... }:

# starship: shell prompt
#
# `[user] cwd (vcs)-[branch] %` 形式を declarative に宣言する。
# Nix module の型付けと flake.lock の pin が目的。
#
# enableZshIntegration を false にする理由:
# zshrc は repo の zsh/.zshrc を home.file で symlink 配置しているため、
# home-manager の zshrc 注入を許すと両者が衝突する。`eval "$(starship
# init zsh)"` の 1 行は zshrc に手書きで持たせる (mise.nix と同じ方針)。
{
  programs.starship = {
    enable = true;
    enableZshIntegration = false;

    # 出力例: [user] ~/path (git)-[main] %
    #
    # starship preset (Pure / Tokyo Night 等) を使わない理由は、既存環境
    # からの認知負荷を最小化するため。settings は必要に応じて iterate する。
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
