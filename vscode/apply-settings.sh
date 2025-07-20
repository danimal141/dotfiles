#!/bin/bash

# VSCode settings apply script
# This script applies VSCode settings from template to the appropriate location

# Determine OS and VSCode config path
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"
else
    # Linux
    VSCODE_CONFIG_DIR="$HOME/.config/Code/User"
fi

# Create directory if it doesn't exist
mkdir -p "$VSCODE_CONFIG_DIR"

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Template file paths
SETTINGS_TEMPLATE="$SCRIPT_DIR/settings.template.jsonc"
SETTINGS_TARGET="$VSCODE_CONFIG_DIR/settings.json"
KEYBINDINGS_TEMPLATE="$SCRIPT_DIR/keybindings.template.jsonc"
KEYBINDINGS_TARGET="$VSCODE_CONFIG_DIR/keybindings.json"

# Check if settings template exists
if [ ! -f "$SETTINGS_TEMPLATE" ]; then
    echo "Error: Settings template file not found: $SETTINGS_TEMPLATE"
    exit 1
fi

# Replace ${HOME} with actual home directory in settings
# Using sed with a delimiter that won't appear in paths
sed "s|\${HOME}|$HOME|g" "$SETTINGS_TEMPLATE" > "$SETTINGS_TARGET"

echo "VSCode settings applied successfully!"
echo "Template: $SETTINGS_TEMPLATE"
echo "Applied to: $SETTINGS_TARGET"

# Apply keybindings if template exists
if [ -f "$KEYBINDINGS_TEMPLATE" ]; then
    sed "s|\${HOME}|$HOME|g" "$KEYBINDINGS_TEMPLATE" > "$KEYBINDINGS_TARGET"
    echo ""
    echo "VSCode keybindings applied successfully!"
    echo "Template: $KEYBINDINGS_TEMPLATE"
    echo "Applied to: $KEYBINDINGS_TARGET"
fi

# Also update the backup file if we're in the dotfiles repo
if [ -f "$SCRIPT_DIR/settings.bak.json" ]; then
    cp "$SETTINGS_TARGET" "$SCRIPT_DIR/settings.bak.json"
    echo "Backup updated: $SCRIPT_DIR/settings.bak.json"
fi
