{ config, user, ... }:

# Claude Code CLI 設定 (~/.claude/) を repo の raw text に out-of-store symlink
# で配置する。zsh.nix / vim.nix と同じ mkOutOfStoreSymlink パターン。
#
# `~/.claude/` 全体を 1 つの symlink で繋ぐと、Claude Code が動的に書き換える
# `projects/` `todos/` `shell-snapshots/` `statsig/` `ide/` などが repo 内に
# 流れ込む。vim.nix と同様に「declarative に管理したい部分」だけ個別 symlink
# にして、動的領域は home.file 対象外として ~/.claude/ 直下に普通に書ける
# mutable directory として残す。
#
# `skills/` 配下も同様: `.gitignore` のみ symlink で配置し、APM が apm.yml
# 経由で install する skill ディレクトリ群 (chrome-cdp/ など) は home.file
# 対象外。`skills/.gitignore` 自体が APM 産物を ignore する役割を果たす。
#
# setup-mcp.sh は ~/.claude には配置せず、repo の `claude/setup-mcp.sh` を
# 直接呼ぶ運用 (`cd claude && ./setup-mcp.sh`) を維持する。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
  claudeDir = "${dotfilesPath}/claude";
in
{
  home.file = {
    ".claude/CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeDir}/CLAUDE.md";
    ".claude/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeDir}/settings.json";
    ".claude/mcp-servers.yaml".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeDir}/mcp-servers.yaml";
    ".claude/.env.example".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeDir}/.env.example";

    ".claude/hooks".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeDir}/hooks";
    ".claude/rules".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeDir}/rules";

    ".claude/skills/.gitignore".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeDir}/skills/.gitignore";
  };
}
