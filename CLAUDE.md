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
```

### Managing Dotfiles
```bash
# Add new dotfile - place it in home/ directory first
# Example: home/.newconfig
homesick link dotfiles  # Creates symlink ~/.newconfig -> ~/.homesick/repos/dotfiles/home/.newconfig

# Update tmux config for deprecated options
python tmux-migrate-options.py .tmux.conf
```

## Architecture

The repository follows homesick conventions:
- `home/` - Contains all dotfiles that will be symlinked to ~/
- `home/.config/` - XDG config directory (marked as subdir in .homesick_subdir)
- `setup.sh` - Main setup script that installs dependencies and links dotfiles
- `_asdf.sh` - Installs programming languages using asdf version manager

Key configurations:
- `.zshrc` - Zsh shell with vi-mode, git branch display, asdf integration
- `.vimrc` - Vim/Neovim config using vim-plug, CoC for LSP, language-specific plugins
- `.tmux.conf` - tmux with custom prefix (C-t), window management, status bar
- `Brewfile` - Homebrew packages including development tools, languages, and GUI apps

## Development Notes

- Vim uses CoC (Conquer of Completion) for LSP support
- Multiple language environments managed by asdf (Ruby, Node.js, Python, Go, Rust, etc.)
- Syntastic provides linting in Vim
- No repository-specific test commands - relies on individual language tooling
- To share coc-settings between vim and nvim: `ln -s ~/.vim/coc-settings.json ~/.config/nvim/coc-settings.json`