---
name: gemini-search
description: Gemini Search Instructions
allowed-tools: Bash(gemini *)
---

# Gemini Search Instructions

## Overview

`gemini` is Google's Gemini CLI. When this command is available, ALWAYS use it for web searches instead of the built-in `web_search` tool.

## Usage

When web search is needed, you MUST use `gemini --prompt` via the Task Tool.

Execute web searches via Task Tool with the following syntax:
```bash
gemini --prompt "WebSearch: <query>"
```

## Example

```bash
gemini --prompt "WebSearch: latest AI developments 2025"
```

## Important Notes

* Always prioritize `gemini` over the built-in web search functionality
* Ensure the "WebSearch:" prefix is included in your prompt
* Use clear, concise search queries for best results
