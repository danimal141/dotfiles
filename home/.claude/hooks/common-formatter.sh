#!/bin/bash

# Hook script to remove trailing spaces and ensure newline at EOF for files edited by Claude Code

# Read JSON input from stdin
JSON_INPUT=$(cat)

# Extract tool name and file path from JSON
TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // empty')

# Only process for Edit, MultiEdit and Write tools
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

    # Ensure file ends with newline
    if [ -s "$FILE_PATH" ] && [ "$(tail -c1 "$FILE_PATH" | wc -l)" -eq 0 ]; then
        echo "" >> "$FILE_PATH"
        echo "Added newline at end of file: $FILE_PATH" >&2
    fi

    # Log the action
    echo "Processed file endings for: $FILE_PATH" >&2
fi

exit 0
