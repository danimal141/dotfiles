# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository managed by chezmoi. Configuration files live in `chezmoi/` (declared via `.chezmoiroot`) using chezmoi naming (`dot_*` -> `~/.<name>`, `private_*`, `executable_*`, etc.) and are materialized into the user's home directory via `chezmoi apply`.

## Essential Commands

### Setup and Installation

```bash
# Initial setup (run from repository root)
./setup.sh                  # auto-detect host from LocalHostName
./setup.sh work             # explicitly target the work host
./setup.sh personal2        # explicitly target personal2

# Apply dotfiles after editing (chezmoi)
chezmoi apply

# Apply Nix store CLI / Homebrew packages / macOS settings (nix-darwin)
darwin-rebuild switch --flake ".#$(scutil --get LocalHostName)"

# Install language runtimes via mise (replaces asdf, reads ~/.tool-versions)
mise install

# Setup MCP servers for Claude (one-shot, after editing chezmoi/dot_claude/mcp-servers.yaml)
cd chezmoi/dot_claude && ./setup-mcp.sh

# Setup VSCode with extensions and settings
cd vscode && ./apply-settings.sh && ./sync-extensions.sh
```

### Managing Dotfiles

```bash
# Add new dotfile - place it in chezmoi/ with chezmoi naming
# (e.g. chezmoi/dot_newconfig, chezmoi/dot_config/foo/bar)
# then run `chezmoi apply` to materialize ~/.newconfig from the source

# Update tmux config for deprecated options
python tmux-migrate-options.py chezmoi/dot_tmux.conf > chezmoi/dot_tmux.conf.new
mv chezmoi/dot_tmux.conf.new chezmoi/dot_tmux.conf

# Sync VSCode extensions from current installation
cd vscode && ./sync-extensions.sh

# Apply VSCode settings and keybindings templates
cd vscode && ./apply-settings.sh

# Update Claude MCP server configurations
cd chezmoi/dot_claude && ./setup-mcp.sh
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

The repository follows chezmoi conventions:

- `chezmoi/` - chezmoi source root (declared via `.chezmoiroot`)
- `chezmoi/dot_config/` - materialized as `~/.config/`
- `chezmoi/dot_claude/` - materialized as `~/.claude/` (Claude Code CLI configuration)
- `chezmoi/dot_codex/` - materialized as `~/.codex/` (Codex CLI configuration; `config.toml.tmpl` is a chezmoi template)
- `chezmoi/dot_apm/` - materialized as `~/.apm/` (APM dependency manifest for skill management)
- `chezmoi/.chezmoi.toml.tmpl` - per-host config (name / email / machineType auto-detection)
- `chezmoi/.chezmoiignore` - paths chezmoi must NOT manage (apps that rewrite ~/  at runtime)
- `chezmoi/.chezmoiscripts/darwin/` - hooks that run on macOS during `chezmoi apply`
- `setup.sh` - first-time bootstrap (Nix install -> darwin-rebuild -> chezmoi init -> mise install)
- `tmux-migrate-options.py` - Utility to migrate deprecated tmux options
- `docs/` - Documentation directory with user guides
- `vscode/` - VSCode configuration management tools (NOT chezmoi-managed; lives at repo root)

Key configurations (materialized paths in `~/`):

- `.zshrc` - Zsh shell with vi-mode keybindings, git branch in prompt, mise integration
- `.vimrc` - Vim/Neovim config using vim-plug, CoC for LSP, Syntastic for linting
- `.tmux.conf` - tmux with custom prefix (C-t), 256 color support, mouse support
- `.gitconfig` - Git configuration with user settings and aliases
- `.gitignore` - Global gitignore patterns
- `.markdownlint.jsonc` - Global markdownlint config (used by Claude hook, pre-commit hooks, editors)
- `nix/packages.nix` - CLI tools served from the Nix store (`flake.lock` で pin)
- `nix/homebrew.nix` - GUI cask + bootstrap binaries + tap-only / Apple-integrated formulae
- `nix/system.nix` - macOS system defaults (Dock / Finder / KeyRepeat / trackpad)
- `nix/hosts/<hostname>.nix` - per-host overrides (work / personal / personal2 ...)
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
- Path management: Apple Silicon Homebrew (`/opt/homebrew`) only; `/usr/local/bin` is kept for non-Homebrew installers (Docker Desktop, VSCode, Cursor) that drop shims there
- Key bindings: Vi-mode with common Emacs bindings in insert mode

### Language Management

- mise manages multiple language versions (Ruby, Node.js, Python, Go, Rust, Deno, Terraform, kubectl, AWS CLI). Reads `~/.tool-versions` for asdf compatibility; `mise.toml` is preferred for new projects.
- Languages are installed per-project via `mise install`; precompiled binaries (mise's `core` plugins) avoid the openssl/libyaml build pitfalls common with asdf.

### Claude Configuration

- `chezmoi/dot_claude/` - source for `~/.claude/` (Claude Code CLI configuration). Tracked files:
  - `CLAUDE.md` - Global user instructions for Claude (in Japanese)
  - `settings.json` - Claude CLI settings and preferences
  - `commands/` - Custom slash commands for Claude
  - `hooks/` - Shell hooks for Claude operations
  - `rules/` - Authoring rules (e.g., `markdown.md`)
  - `mcp-servers.yaml` - MCP server configurations
  - `dot_env.example` - Environment variables template (materialized as `~/.claude/.env.example`)
  - `setup-mcp.sh` - one-shot script to materialize MCP server configs
  - `skills/` - Local + APM-managed skills (APM-installed dirs are gitignored via `dot_gitignore`)

### Codex Configuration

- `chezmoi/dot_codex/` - source for `~/.codex/`:
  - `config.toml.tmpl` - chezmoi template; secrets are injected via `{{ env "..." }}` from shell env or 1Password CLI
  - `dot_env.example` - environment variables template (materialized as `~/.codex/.env.example`)
  - `symlink_AGENTS.md` - chezmoi symlink directive

### APM Configuration

- `chezmoi/dot_apm/apm.yml` - APM dependency manifest (= `~/.apm/apm.yml`)
- `chezmoi/.chezmoiscripts/darwin/run_onchange_after_apm-install.sh.tmpl` - hash-based hook that runs `apm install --target claude` whenever `apm.yml` changes, integrating skills into `~/.claude/skills/`

### VSCode Management

- `vscode/` - lives at **repo root**, NOT under `chezmoi/`. Holds settings/keybinding templates and an extension list:
  - `apply-settings.sh` - Script to apply VSCode settings templates
  - `sync-extensions.sh` - Script to sync VSCode extensions
  - `extensions.txt` - List of installed VSCode extensions
  - `settings.template.jsonc` - VSCode settings template
  - `keybindings.template.jsonc` - VSCode keybindings template

### Documentation

- `docs/` - Comprehensive documentation:
  - `design-philosophy.md` - Design philosophy: how nix and chezmoi are split
  - `claude-mcp-manager-use.md` - Claude MCP Manager usage guide
  - `claude-use.md` - Claude usage patterns and best practices
  - `vscode.md` - VSCode configuration and workflow documentation
