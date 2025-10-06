# Claude MCP Manager

A tool for safely managing Claude Code CLI's MCP (Model Context Protocol) server configurations with Git.

## Overview

This tool enables:

- Managing MCP configurations with YAML files
- Separate management of environment variables (API keys, etc.) with `.env` files
- Bulk execution of `claude mcp add` commands

## Setup

### 1. Install Required Tools

```bash
# Install yq (YAML parser)
brew install yq
```

### 2. Configure Environment Variables (if needed)

```bash
cd home/.claude
cp .env.example .env
# Edit the .env file to set required API keys
```

### 3. Add MCP Servers

```bash
cd home/.claude && ./setup-mcp.sh
```

## File Structure

All files are located in `home/.claude/` directory:

- `mcp-servers.yaml` - File defining MCP configurations (Git-managed)
- `.env.example` - Environment variable template (Git-managed)
- `.env` - Actual environment variables (Git-ignored)
- `setup-mcp.sh` - Script to apply MCP configurations

## Usage

### Adding a New MCP Server

1. Add new server configuration to `home/.claude/mcp-servers.yaml`
2. Add environment variables to `home/.claude/.env` if needed
3. Run `cd home/.claude && ./setup-mcp.sh`

### Configuration Example

```yaml
servers:
  context7:
    command: npx
    args:
      - "-y"
      - "@upstash/context7-mcp"
    env: {}
```

## Important Notes

- Never commit the `.env` file to Git as it contains sensitive information
- Configurations are added as project-scoped settings using the `--scope project` option
