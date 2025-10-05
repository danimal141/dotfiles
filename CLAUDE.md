# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository managed by homesick. All configuration files are stored in the `home/` directory and symlinked to the user's home directory.

## Essential Commands

### Setup and Installation

```bash
# Initial setup (run from repository root)
./setup.sh

# Link dotfiles after adding new files
homesick link dotfiles

# Install/update Homebrew packages
brew bundle --file=home/Brewfile

# Install programming languages via asdf
./_asdf.sh

# Setup MCP servers for Claude
cd claude-mcp-manager && ./setup-mcp.sh

# Setup Codex configuration
cd home/.codex && cp .env.example .env
# Edit .env to add your API keys, then:
cd home/.codex && ./apply-config.sh

# Setup VSCode with extensions and settings
cd vscode && ./apply-settings.sh && ./sync-extensions.sh
```

### Managing Dotfiles

```bash
# Add new dotfile - place it in home/ directory first
# Example: home/.newconfig
homesick link dotfiles  # Creates symlink ~/.newconfig -> ~/.homesick/repos/dotfiles/home/.newconfig

# Update tmux config for deprecated options
python tmux-migrate-options.py home/.tmux.conf > home/.tmux.conf.new
mv home/.tmux.conf.new home/.tmux.conf

# Sync VSCode extensions from current installation
cd vscode && ./sync-extensions.sh

# Apply VSCode settings and keybindings templates
cd vscode && ./apply-settings.sh

# Update Claude MCP server configurations
cd claude-mcp-manager && ./setup-mcp.sh

# Update Codex configuration
cd home/.codex && ./apply-config.sh
```

### Common Development Commands

```bash
# No repository-specific build/test commands - use language-specific tools:
# Ruby: bundle install, rake test
# Node.js: npm install, npm test
# Python: pip install -r requirements.txt, pytest
# Go: go mod download, go test
# Rust: cargo build, cargo test
```

## Architecture

The repository follows homesick conventions:

- `home/` - Contains all dotfiles that will be symlinked to ~/
- `home/.config/` - XDG config directory (marked as subdir in .homesick_subdir)
- `home/.claude/` - Claude Code CLI configuration directory with user settings and commands
- `home/.codex/` - Codex CLI configuration directory with template-based config management
- `.homesick_subdir` - Declares `.config` as a subdirectory for proper symlinking
- `setup.sh` - Main setup script that installs dependencies and links dotfiles
- `_asdf.sh` - Installs programming languages using asdf version manager
- `tmux-migrate-options.py` - Utility to migrate deprecated tmux options
- `docs/` - Documentation directory with user guides
- `vscode/` - VSCode configuration management tools
- `claude-mcp-manager/` - Tool for managing Claude Code CLI's MCP servers

Key configurations:

- `.zshrc` - Zsh shell with vi-mode keybindings, git branch in prompt, asdf integration
- `.vimrc` - Vim/Neovim config using vim-plug, CoC for LSP, Syntastic for linting
- `.tmux.conf` - tmux with custom prefix (C-t), 256 color support, mouse support
- `.gitconfig` - Git configuration with user settings and aliases
- `.gitignore` - Global gitignore patterns
- `Brewfile` - Comprehensive Homebrew packages (100+ packages) including development tools, CLI utilities, GUI apps, and specialized tools
- `.vim/coc-settings.json` - CoC configuration for language servers
- `.config/nvim/` - Neovim configuration with symlinked coc-settings.json
- `.ctags.d/` - Universal Ctags configuration directory

## Development Notes

### Vim/Neovim Setup

- Plugin manager: vim-plug
- LSP support: CoC (Conquer of Completion)
- Linting: Syntastic with local eslint support
- Language plugins: Go, Ruby, JavaScript/TypeScript, Rust, Terraform, etc.
- To share coc-settings between vim and nvim: `ln -s ~/.vim/coc-settings.json ~/.config/nvim/coc-settings.json`

### Shell Environment

- Shell: Zsh with custom prompt showing git branch
- Path management: Handles both Intel (/usr/local) and Apple Silicon (/opt/homebrew) Homebrew installations
- Key bindings: Vi-mode with common Emacs bindings in insert mode

### Language Management

- asdf manages multiple language versions (Ruby, Node.js, Python, Go, Rust, Deno, Terraform, kubectl, AWS CLI)
- Languages are installed globally to latest version by default

### Claude MCP Manager

- `claude-mcp-manager/` - Tool for managing Claude Code CLI's MCP (Model Context Protocol) servers
- `mcp-servers.yaml` - MCP server configurations (Git-managed)
- `setup-mcp.sh` - Script to apply MCP configurations
- Setup: `cd claude-mcp-manager && ./setup-mcp.sh`
- Manages MCP servers for Claude Code CLI with environment variable support

### Claude Configuration

- `home/.claude/` - Claude Code CLI configuration directory containing:
  - `CLAUDE.md` - Global user instructions for Claude (in Japanese)
  - `settings.json` - Claude CLI settings and preferences
  - `commands/` - Custom slash commands for Claude
  - `hooks/` - Shell hooks for Claude operations
  - `ide/` - IDE-specific configurations
  - `projects/` - Project-specific Claude configurations
  - `shell-snapshots/` - Saved shell state snapshots
  - `statsig/` - Analytics and statistics data
  - `todos/` - Task management data (77+ saved todo lists)

### Codex Configuration

- `home/.codex/` - Codex CLI configuration directory with template-based management:
  - `config.toml.template` - Configuration template (Git-managed)
  - `config.toml` - Generated configuration file (gitignored)
  - `.env.example` - Environment variables template (Git-managed)
  - `.env` - Actual environment variables with API keys (gitignored)
  - `apply-config.sh` - Script to generate config.toml from template
  - Setup: Copy `.env.example` to `.env`, add your API keys, then run `./apply-config.sh`
  - This approach keeps sensitive API keys out of Git while managing MCP server configurations

### VSCode Management

- `vscode/` - VSCode configuration and extension management:
  - `apply-settings.sh` - Script to apply VSCode settings templates
  - `sync-extensions.sh` - Script to sync VSCode extensions
  - `extensions.txt` - List of installed VSCode extensions
  - `settings.template.jsonc` - VSCode settings template
  - `keybindings.template.jsonc` - VSCode keybindings template

### Documentation

- `docs/` - Comprehensive documentation:
  - `claude-mcp-manager.md` - Claude MCP Manager usage guide
  - `claude-use.md` - Claude usage patterns and best practices
  - `vscode.md` - VSCode configuration and workflow documentation
