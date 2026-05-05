#!/bin/bash

JSON_INPUT=$(cat)
TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" && "$TOOL_NAME" != "Write" ]]; then
    exit 0
fi

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
    exit 0
fi

# .mdファイルのみ処理
if [[ "$FILE_PATH" != *.md ]]; then
    exit 0
fi

markdownlint --fix --config ~/.claude/.markdownlint.jsonc "$FILE_PATH" >&2

exit 0
