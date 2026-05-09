{ config, user, ... }:

# Claude Code CLI 設定 (~/.claude/) を out-of-store symlink で配置する。
#
# ~/.claude/ 全体を 1 つの symlink にしてしまうと Claude Code が動的に
# 書き換える `projects/` `todos/` `shell-snapshots/` `statsig/` `ide/` が
# repo 内に流れ込む。declarative に管理したい部分だけ個別 symlink にして、
# 動的領域は home.file 対象外で mutable のまま残す。
#
# skills/ 配下は `.gitignore` のみ symlink で配置し、APM (apm.yml 経由)
# が install する skill ディレクトリ群 (chrome-cdp/ 等) は対象外。
# skills/.gitignore 自体が APM 産物を ignore する役割を果たす。
#
# setup-mcp.sh は ~/.claude には配置せず、repo 内で `cd tools/claude &&
# ./setup-mcp.sh` で直接呼ぶ運用。
let
  dotfilesPath = "/Users/${user}/Documents/dev/dotfiles";
  claudeDir = "${dotfilesPath}/tools/claude";
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
