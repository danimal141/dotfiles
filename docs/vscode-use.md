# VSCode Settings Management

This directory contains VSCode settings management files for the dotfiles repository.

## Files

- `settings.template.json` - VSCode settings template with environment variables
- `settings.bak.json` - Backup of current VSCode settings (auto-generated)
- `apply-settings.sh` - Script to apply settings from template to VSCode
- `extensions.txt` - List of VSCode extensions to install
- `sync-extensions.sh` - Script to manage VSCode extensions

## Usage

### Apply VSCode Settings

To apply the VSCode settings on a new machine or after changes:

```bash
cd ~/path/to/dotfiles/vscode
./apply-settings.sh
```

This script will:

1. Detect your OS (macOS or Linux)
2. Replace environment variables like `${HOME}` with actual values
3. Copy the processed settings to the appropriate VSCode config directory
4. Update the backup file

### Environment Variables

The template uses the following environment variables:

- `${HOME}` - Your home directory (e.g., `/Users/username` or `/home/username`)

This ensures that paths like the Kubernetes extension tools work correctly regardless of username or OS.

### Adding New Settings

1. Edit `settings.template.json` to add new settings
2. Use `${HOME}` for any paths that reference your home directory
3. Run `./apply-settings.sh` to apply the changes
4. Commit both the template and the updated script if needed

### Platform Support

- **macOS**: Settings are applied to `~/Library/Application Support/Code/User/settings.json`
- **Linux**: Settings are applied to `~/.config/Code/User/settings.json`

## Extensions Management

VSCode extensions can be synced across machines using the `sync-extensions.sh` script.

### Save Current Extensions

To save your currently installed extensions:

```bash
cd ~/path/to/dotfiles/vscode
./sync-extensions.sh --save
```

This will save all installed extensions to `extensions.txt`.

### Install Extensions

To install extensions on a new machine or sync with the saved list:

```bash
cd ~/path/to/dotfiles/vscode
./sync-extensions.sh --install
```

This will:
- Install all extensions listed in `extensions.txt`
- Skip extensions that are already installed
- Show a summary of installed/skipped/failed extensions

### Check Sync Status

To see the current sync status:

```bash
cd ~/path/to/dotfiles/vscode
./sync-extensions.sh --status
```

This will show:
- Extensions installed but not in the saved list
- Extensions in the saved list but not installed
- Total counts and sync status

### Automatic Setup

When running the main `setup.sh` script, both VSCode settings and extensions will be automatically configured:

1. Settings are applied from `settings.template.json`
2. Extensions are installed from `extensions.txt`

### Managing Extensions

1. Install new extensions through VSCode normally
2. Run `./sync-extensions.sh --save` to update the extensions list
3. Commit the updated `extensions.txt` to your dotfiles repository

## Key Bindings

This dotfiles setup includes custom key bindings defined in `keybindings.template.jsonc`. The following shortcuts are configured to improve development workflow:

### Custom Shortcuts

#### Panel Management
- **Cmd+Shift+M**: Toggle maximized panel when terminal is focused
  - Useful for maximizing terminal view during development

#### Navigation
- **Cmd+Shift+W**: Focus on Workspace Explorer
  - Quick access to file navigation
- **Cmd+Shift+C**: Collapse all folders in Explorer
  - Clean up file tree view instantly


### Customizing Key Bindings

To add or modify key bindings:

1. Edit `keybindings.template.jsonc` in the `vscode/` directory
2. Use VSCode's built-in keyboard shortcuts editor (Cmd+K Cmd+S) for reference
3. Apply changes using `./apply-settings.sh`
4. The template uses JSONC format, so comments are supported

### Example Custom Key Binding

```jsonc
{
  "key": "cmd+k cmd+t",
  "command": "workbench.action.selectTheme"
}
```

This would bind Cmd+K Cmd+T to the theme selector.
