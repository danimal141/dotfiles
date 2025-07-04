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

# Template file path
TEMPLATE_FILE="$SCRIPT_DIR/settings.template.json"
TARGET_FILE="$VSCODE_CONFIG_DIR/settings.json"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Replace ${HOME} with actual home directory
# Using sed with a delimiter that won't appear in paths
sed "s|\${HOME}|$HOME|g" "$TEMPLATE_FILE" > "$TARGET_FILE"

echo "VSCode settings applied successfully!"
echo "Template: $TEMPLATE_FILE"
echo "Applied to: $TARGET_FILE"

# Also update the backup file if we're in the dotfiles repo
if [ -f "$SCRIPT_DIR/settings.bak.json" ]; then
    cp "$TARGET_FILE" "$SCRIPT_DIR/settings.bak.json"
    echo "Backup updated: $SCRIPT_DIR/settings.bak.json"
fi