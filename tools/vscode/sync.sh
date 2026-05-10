#!/bin/bash

# VSCode extensions sync utility (--save / --status)。
#
# install 経路は home-manager (nix/home/programs/vscode.nix) の
# `home.activation.vscodeExtensions` hook が担うので、このスクリプトは
# UI から手動で追加した extension を repo に取り込む reverse-sync と
# diff 表示だけを残す。

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EXTENSIONS_FILE="$SCRIPT_DIR/extensions.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTION]"
    echo "Manage VSCode extensions for dotfiles"
    echo ""
    echo "Options:"
    echo "  --save      Save currently installed extensions to extensions.txt"
    echo "  --status    Show status (compare installed vs saved)"
    echo "  --help      Show this help message"
    echo ""
    echo "Note: install は home-manager (nix run .#switch) が冪等に実行する。"
    echo ""
    echo "Examples:"
    echo "  $0 --save       # Save current extensions"
    echo "  $0 --status     # Check sync status"
}

# Function to check if VSCode CLI is available
check_vscode_cli() {
    if ! command -v code &> /dev/null; then
        echo -e "${RED}Error: 'code' command not found. Please install VSCode and add it to PATH.${NC}"
        echo "On macOS: Open VSCode, press Cmd+Shift+P, and run 'Shell Command: Install 'code' command in PATH'"
        exit 1
    fi
}

# Function to save extensions
save_extensions() {
    echo "Saving installed extensions to $EXTENSIONS_FILE..."

    # Get list of installed extensions
    code --list-extensions > "$EXTENSIONS_FILE"

    local count=$(wc -l < "$EXTENSIONS_FILE")
    echo -e "${GREEN}✓ Saved $count extensions to extensions.txt${NC}"
}

# Function to show status
show_status() {
    echo "VSCode Extensions Status"
    echo "========================"

    if [ ! -f "$EXTENSIONS_FILE" ]; then
        echo -e "${RED}Error: extensions.txt not found${NC}"
        echo "Run '$0 --save' to create it"
        exit 1
    fi

    # Get lists
    local temp_installed=$(mktemp)
    local temp_saved=$(mktemp)

    code --list-extensions | sort > "$temp_installed"
    sort "$EXTENSIONS_FILE" > "$temp_saved"

    # Extensions only in installed (not saved)
    local only_installed=$(comm -23 "$temp_installed" "$temp_saved")
    if [ -n "$only_installed" ]; then
        echo -e "\n${YELLOW}Extensions installed but not saved:${NC}"
        echo "$only_installed" | sed 's/^/  /'
    fi

    # Extensions only in saved (not installed)
    local only_saved=$(comm -13 "$temp_installed" "$temp_saved")
    if [ -n "$only_saved" ]; then
        echo -e "\n${RED}Extensions saved but not installed:${NC}"
        echo "$only_saved" | sed 's/^/  /'
    fi

    # Count synced extensions
    local synced_count=$(comm -12 "$temp_installed" "$temp_saved" | wc -l)
    local installed_count=$(wc -l < "$temp_installed")
    local saved_count=$(wc -l < "$temp_saved")

    echo -e "\n${GREEN}Synced extensions: $synced_count${NC}"
    echo "Total installed: $installed_count"
    echo "Total saved: $saved_count"

    # Clean up
    rm "$temp_installed" "$temp_saved"

    # Show sync status
    if [ -z "$only_installed" ] && [ -z "$only_saved" ]; then
        echo -e "\n${GREEN}✓ Extensions are fully synced${NC}"
    else
        echo -e "\n${YELLOW}⚠ Extensions are not fully synced${NC}"
        if [ -n "$only_installed" ]; then
            echo "  Run '$0 --save' to save new extensions"
        fi
        if [ -n "$only_saved" ]; then
            echo "  Run 'nix run .#switch' to install missing extensions"
        fi
    fi
}

# Main script
check_vscode_cli

case "${1:-}" in
    --save)
        save_extensions
        ;;
    --status)
        show_status
        ;;
    --help|-h|"")
        show_usage
        ;;
    *)
        echo -e "${RED}Error: Unknown option '$1'${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac