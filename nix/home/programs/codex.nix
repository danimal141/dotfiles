{ config, user, ... }:

# Codex CLI 設定 (~/.codex/) を home-manager で管理する。
#
# 旧 chezmoi 構成 (chezmoi/dot_codex/) との差分:
#   * config.toml の `{{ env "GEMINI_API_KEY" }}` template 展開を廃止し、
#     secrets を tracked file から完全分離。GEMINI_API_KEY は
#     ~/.codex/.env (gitignore で repo 外配置、.env.example をコピーして
#     user が手動で埋める) に書き、wrapper script (~/.codex/wrappers/
#     gemini-mcp.sh = repo の codex/wrappers/gemini-mcp.sh) が起動時に
#     source して inject する。
#   * AGENTS.md は chezmoi の symlink_AGENTS.md (../.claude/CLAUDE.md への
#     relative symlink) を踏襲しつつ、新方針では repo の claude/CLAUDE.md
#     を直接指す out-of-store symlink にする。CLAUDE.md 編集が両方に即
#     反映される (codex の AGENTS.md は ~/.claude/CLAUDE.md と同一内容で
#     運用したい意図を維持)。
#   * config.toml は user 変数 (wrapper 絶対パス) を含むため home.file の
#     `text =` で生成する。raw 編集即反映の体験は失うが、codex MCP server
#     の追加・変更は頻度が低く、darwin-rebuild trigger を許容する。
let
  homePath = "/Users/${user}";
  dotfilesPath = "${homePath}/Documents/dev/dotfiles";
  codexDir = "${dotfilesPath}/codex";
  wrapperHomePath = "${homePath}/.codex/wrappers/gemini-mcp.sh";
in
{
  home.file.".codex/config.toml".text = ''
    model = "gpt-5-codex"
    model_reasoning_effort = "high"
    hide_agent_reasoning = true
    network_access = true

    notify = ["bash", "-lc", "afplay /System/Library/Sounds/Ping.aiff"]

    [tools]
    web_search = true

    [mcp_servers.aws-documentation]
    command = "uvx"
    args = ["awslabs.aws-documentation-mcp-server@latest"]

    [mcp_servers.aws-documentation.env]
    FASTMCP_LOG_LEVEL = "ERROR"

    [mcp_servers.context7]
    command = "npx"
    args = ["-y", "@upstash/context7-mcp"]

    # GEMINI_API_KEY は wrapper が ~/.codex/.env から inject する。
    # ここに secrets を書かない (tracked file に secret を残さない方針)。
    [mcp_servers.gemini-google-search]
    command = "${wrapperHomePath}"

    [mcp_servers.gemini-google-search.env]
    GEMINI_MODEL = "gemini-2.5-flash"

    [mcp_servers.playwright]
    command = "npx"
    args = ["-y", "@playwright/mcp@latest"]

    [mcp_servers.serena]
    command = "uvx"
    args = ["--from", "git+https://github.com/oraios/serena", "serena", "start-mcp-server", "--context", "ide-assistant"]

    [mcp_servers.terraform]
    command = "docker"
    args = ["run", "-i", "--rm", "hashicorp/terraform-mcp-server"]
  '';

  home.file.".codex/wrappers/gemini-mcp.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${codexDir}/wrappers/gemini-mcp.sh";

  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/claude/CLAUDE.md";

  home.file.".codex/.env.example".source =
    config.lib.file.mkOutOfStoreSymlink "${codexDir}/.env.example";
}
