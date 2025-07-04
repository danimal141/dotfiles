#!/bin/bash

# Hook script to remove trailing spaces from files edited by Claude Code

# Get tool name and file path from environment variables
TOOL_NAME="${TOOL_NAME:-}"
FILE_PATH="${FILE_PATH:-}"

# Only process for Edit, MultiEdit, and Write tools
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" && "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Skip if file doesn't exist
if [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# Skip binary files
if file -b --mime-type "$FILE_PATH" | grep -q "^text/"; then
    # Remove trailing spaces using sed
    sed -i '' 's/[[:space:]]*$//' "$FILE_PATH"

    # Log the action
    echo "Removed trailing spaces from: $FILE_PATH" >&2
fi

exit 0
