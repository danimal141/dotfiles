# VSCode Settings Management

This directory contains VSCode settings management files for the dotfiles repository.

## Files

- `settings.template.json` - VSCode settings template with environment variables
- `settings.bak.json` - Backup of current VSCode settings (auto-generated)
- `apply-settings.sh` - Script to apply settings from template to VSCode

## Usage

### Apply VSCode Settings

To apply the VSCode settings on a new machine or after changes:

```bash
cd ~/path/to/dotfiles/home/vscode
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
