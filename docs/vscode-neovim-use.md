# VSCode Neovim Integration Guide

This document explains how the VSCode Neovim extension is configured in this dotfiles repository to avoid conflicts and optimize performance.

## Overview

This repository uses the [VSCode Neovim extension](https://marketplace.visualstudio.com/items?itemName=asvetliakov.vscode-neovim) (`asvetliakov.vscode-neovim`) to integrate Neovim's modal editing capabilities with VSCode's language support features.

### Architecture

The extension runs Neovim in headless mode in the background and creates a clear division of responsibilities:

- **VSCode handles**: Syntax highlighting, LSP features, IntelliSense, debugging, insert mode
- **Neovim handles**: Normal mode, visual mode, vim motions, and custom key mappings

## Configuration Strategy

### Conditional Plugin Loading

To prevent conflicts between VSCode's native features and Neovim plugins, certain plugins are conditionally loaded based on the environment:

```vim
if !exists('g:vscode')
  " Load plugins that conflict with VSCode features
  Plug 'neoclide/coc.nvim', { 'branch': 'release' }
  Plug 'vim-syntastic/syntastic'
  " ... additional LSP and syntax plugins
endif
```

> **Note**: See the complete configuration in [`home/.vimrc`](../home/.vimrc) (lines 9-39). The conditional block includes all plugins that would conflict with VSCode's native features.

**When VSCode Neovim extension is active:**
- `g:vscode` variable is automatically set
- CoC (Conquer of Completion) is disabled
- Syntastic linting is disabled
- VSCode's native LSP and linting take precedence

**When using standalone Neovim:**
- `g:vscode` variable doesn't exist
- All plugins load normally
- Full CoC functionality is available

## Feature Comparison

| Feature | Standalone Neovim | VSCode + Neovim |
|---------|-------------------|------------------|
| Syntax Highlighting | Neovim/Treesitter | VSCode native |
| LSP Support | CoC extensions | VSCode extensions |
| Autocompletion | CoC | VSCode IntelliSense |
| Linting | Syntastic | VSCode linters |
| File Explorer | NERDTree | VSCode Explorer |
| Git Integration | vim-gitgutter | VSCode Git + GitLens |
| Vim Motions | Full support | Full support |
| Custom Keymaps | Full support | Full support |

## Settings That Work in Both Environments

### Basic Vim Settings
```vim
set tabstop=2
set shiftwidth=2
set expandtab
set number
set ignorecase
set smartcase
set clipboard=unnamed
```

### Custom Key Mappings
```vim
nnoremap ; :
nnoremap : ;
nnoremap <C-p> :CocList files <CR>  " Only works in standalone Neovim
```

## Setup Instructions

### 1. Install Required Extensions

VSCode extensions that complement this setup:
- `asvetliakov.vscode-neovim` - Core Neovim integration
- `shopify.ruby-lsp` - Ruby language support
- `golang.go` - Go language support
- `ms-python.python` - Python language support
- `esbenp.prettier-vscode` - Code formatting

### 2. Apply Configuration Changes

After modifying `.vimrc`, restart VSCode or run:
```vim
:PlugClean
:PlugInstall
```

### 3. Verify Setup

**In VSCode with Neovim extension:**
```vim
:echo exists('g:vscode')  " Should return 1
:CocInfo                  " Should show CoC is not active
```

**In standalone Neovim:**
```vim
:echo exists('g:vscode')  " Should return 0
:CocInfo                  " Should show CoC status and extensions
```

## Performance Benefits

This configuration provides several performance improvements when using VSCode:

1. **Reduced Memory Usage**: No duplicate LSP servers running
2. **Faster Startup**: Fewer plugins to initialize in VSCode context
3. **No Conflicts**: Single source of truth for language features
4. **Better Stability**: VSCode's mature LSP implementations

## Troubleshooting

### CoC Still Active in VSCode
- Verify `g:vscode` variable exists: `:echo exists('g:vscode')`
- Restart VSCode completely
- Check that the conditional plugin loading syntax is correct

### Language Features Not Working
- Ensure appropriate VSCode extensions are installed
- Check VSCode's Output panel for LSP errors
- Verify language servers are properly configured in VSCode settings

### Vim Motions Not Working
- Confirm VSCode Neovim extension is enabled
- Check for conflicting VSCode keybindings
- Restart VSCode and try again

## Best Practices

1. **Use VSCode for Language Features**: Rely on VSCode's extensions for LSP, debugging, and language-specific tools
2. **Use Neovim for Editing**: Leverage vim motions, text objects, and custom commands
3. **Avoid Duplicate Plugins**: Don't install both VSCode extensions and equivalent Neovim plugins
4. **Test Both Environments**: Ensure configurations work in both VSCode and standalone Neovim

## Related Documentation

- [VSCode Neovim Extension README](https://github.com/vscode-neovim/vscode-neovim)
- [CoC.nvim Documentation](https://github.com/neoclide/coc.nvim)
- [Project's vim configuration](../home/.vimrc)
- [VSCode settings template](../vscode/settings.template.jsonc)
