# Claude MCP Manager

A tool for safely managing MCP (Model Context Protocol) server configurations for Claude Code CLI using Git.

## Overview

This tool enables you to:
- Manage MCP configurations using YAML files
- Separate environment variables (API keys, etc.) in `.env` files
- Execute `claude mcp add` commands in batch

## Setup

### 1. Install Required Tools

```bash
# Install yq (YAML parser)
brew install yq
```

### 2. Configure Environment Variables (if needed)

```bash
cp .env.example .env
# Edit the .env file to set required API keys
```

### 3. Add MCP Servers

```bash
./setup-mcp.sh
```

## File Structure

- `mcp-servers.yaml` - Define MCP configurations (tracked by Git)
- `.env.example` - Environment variable template (tracked by Git)
- `.env` - Actual environment variables (ignored by Git)
- `setup-mcp.sh` - Script to apply MCP configurations
- `.gitignore` - Git exclusion settings

## Usage

### Adding a New MCP Server

1. Add new server configuration to `mcp-servers.yaml`
2. Add environment variables to `.env` if needed
3. Run `./setup-mcp.sh`

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

## Command Options

```bash
# Add servers with user scope (default)
./setup-mcp.sh

# Add servers with project scope
./setup-mcp.sh -s project
```

## Currently Configured Servers

- **context7**: Documentation retrieval tool
- **playwright**: Browser automation tool
- **gemini-google-search**: Google search tool (using Gemini API)
- **github**: GitHub operations tool

## Security Notes

- Never commit `.env` file to Git as it contains sensitive information like API keys
- Use `.env.example` as a template to document required environment variables
- All API keys should be stored in `.env` and referenced in `mcp-servers.yaml`

## Troubleshooting

If you encounter issues:
1. Ensure `claude` CLI is installed and configured
2. Verify `yq` is installed (`brew install yq`)
3. Check that `.env` file exists and contains required API keys
4. Ensure `mcp-servers.yaml` has valid YAML syntax

## Contributing

When adding new MCP servers:
1. Add the configuration to `mcp-servers.yaml`
2. Document any required environment variables in `.env.example`
3. Test the configuration with `./setup-mcp.sh`
4. Update this README if necessary