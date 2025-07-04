#!/bin/bash

# Hook script to format code files edited by Claude Code
# Supports: Ruby, JavaScript, TypeScript, Go, Rust, Python, Terraform

# Read JSON input from stdin
JSON_INPUT=$(cat)

# Debug logging
echo "[DEBUG] Hook called at $(date)" >> /tmp/claude-hook-debug.log
echo "[DEBUG] JSON input: $JSON_INPUT" >> /tmp/claude-hook-debug.log

# Extract tool name and file path from JSON
TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // empty')

echo "[DEBUG] Extracted TOOL_NAME=$TOOL_NAME" >> /tmp/claude-hook-debug.log
echo "[DEBUG] Extracted FILE_PATH=$FILE_PATH" >> /tmp/claude-hook-debug.log

# Only process for Edit, MultiEdit, and Write tools
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" && "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Security: Validate file path to prevent directory traversal
if [[ "$FILE_PATH" == *".."* ]] || [[ "$FILE_PATH" == *"~"* ]]; then
    echo "Error: Invalid file path detected" >&2
    exit 1
fi

# Security: Only process files in current working directory or subdirectories
if [[ ! "$FILE_PATH" =~ ^/ ]]; then
    # Relative path - make it absolute
    FILE_PATH="$(pwd)/$FILE_PATH"
fi

# Security: Verify file is within allowed directories
CWD=$(pwd)
REAL_FILE_PATH=$(realpath "$FILE_PATH" 2>/dev/null || echo "")
if [[ -z "$REAL_FILE_PATH" ]] || [[ ! "$REAL_FILE_PATH" == "$CWD"* ]]; then
    echo "Error: File is outside current working directory" >&2
    exit 1
fi

# Skip if file doesn't exist
if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Get file extension
EXTENSION="${FILE_PATH##*.}"
BASENAME=$(basename "$FILE_PATH")

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Format based on file extension
case "$EXTENSION" in
    rb)
        # Ruby - use prettier if available
        if command_exists npx && npx prettier --version >/dev/null 2>&1; then
            echo "Formatting Ruby file with prettier: $FILE_PATH" >&2
            npx prettier --plugin=@prettier/plugin-ruby --write "$FILE_PATH" 2>/dev/null || true
        fi
        ;;

    js|jsx|ts|tsx)
        # JavaScript/TypeScript - use prettier
        if command_exists npx && npx prettier --version >/dev/null 2>&1; then
            echo "Formatting JavaScript/TypeScript file with prettier: $FILE_PATH" >&2
            npx prettier --write "$FILE_PATH" 2>/dev/null || true
        fi
        ;;

    go)
        # Go - use gofmt
        if command_exists gofmt; then
            echo "Formatting Go file with gofmt: $FILE_PATH" >&2
            gofmt -w "$FILE_PATH" 2>/dev/null || true
        fi
        ;;

    py)
        # Python - use ruff
        if command_exists uvx && uvx ruff --version >/dev/null 2>&1; then
            echo "Formatting Python file with ruff: $FILE_PATH" >&2
            uvx ruff format "$FILE_PATH" 2>/dev/null || true
        fi
        ;;

    tf|tfvars)
        # Terraform - use terraform fmt
        if command_exists terraform; then
            echo "Formatting Terraform file with terraform fmt: $FILE_PATH" >&2
            # terraform fmt requires working from the directory containing the file
            (cd "$(dirname "$FILE_PATH")" && terraform fmt "$(basename "$FILE_PATH")" 2>/dev/null) || true
        fi
        ;;

    *)
        # No formatter for this file type
        ;;
esac

exit 0
