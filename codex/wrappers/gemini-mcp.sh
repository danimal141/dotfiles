#!/usr/bin/env bash
# codex MCP server wrapper for mcp-gemini-google-search.
#
# 旧 chezmoi/dot_codex/config.toml.tmpl では `{{ env "GEMINI_API_KEY" }}` で
# secret を tracked file に展開していた。Nix 化に伴い secret を tracked から
# 切り離す方針へ変更:
#
#   * tracked: codex/config.toml (secrets 除去済み、wrapper を呼ぶだけ)
#   * untracked: ~/.codex/.env (gitignore で repo 外配置、user が手動で埋める)
#
# このスクリプトは codex の MCP server 起動経路から呼ばれ、~/.codex/.env を
# source して GEMINI_API_KEY 等を環境変数に注入してから npx 経由で
# mcp-gemini-google-search を起動する。
#
# 配置: home-manager (nix/home/programs/codex.nix) が ~/.codex/wrappers/
# gemini-mcp.sh を repo の codex/wrappers/gemini-mcp.sh への out-of-store
# symlink として配置する。実行属性は repo 側の chmod 755 を保つ。
set -euo pipefail

env_file="$HOME/.codex/.env"
if [ -f "$env_file" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$env_file"
  set +a
fi

exec npx -y mcp-gemini-google-search
