#!/usr/bin/env bash
# codex MCP server wrapper for mcp-gemini-google-search.
#
# secrets を tracked file に置かないため、~/.codex/.env (repo 外、user
# 手動配置) を起動時に source して GEMINI_API_KEY 等を環境変数に注入して
# から npx 経由で mcp-gemini-google-search を起動する。
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
