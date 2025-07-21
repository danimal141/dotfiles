# Claude Code CLI Configuration Directory

This directory contains global configurations for Claude Code CLI (claude.ai/code).

## Overview

The `.claude/` directory stores user-specific configurations that Claude Code CLI references. Settings placed here are applied across all projects.

## File Structure

### CLAUDE.md

A file that defines instructions and rules for Claude Code CLI. It includes the following settings:

- **Language Settings**: Specifies Japanese for interactions
- **Character Encoding**: Uses UTF-8
- **AI Operation 5 Principles**: Operating principles for Claude Code CLI

### settings.json

The main configuration file for Claude Code CLI:

- **permissions**: Command-level allow/deny settings
- **env**: Environment variables (timeouts, thinking token counts, etc.)
- **hooks**: Hook configurations for tool execution

### commands/

Directory containing custom commands:
- `create-pr.md` / `create-pr-ja.md`: Pull request creation commands
- `create-task.md` / `create-task-ja.md`: Task creation commands
- `gemini-search.md`: Gemini search command

### hooks/

Directory containing hook scripts:
- `common-formatter.sh`: Automatic formatter after file editing

### Other Directories

- `ide/`: IDE integration configuration files (*.lock files)
- `projects/`: Project-specific settings are saved here
- `shell-snapshots/`: Shell snapshots
- `statsig/`: Statistics-related data
- `todos/`: Todo management data

#### About AI Operation 5 Principles
The five principles defined in this file control the behavior of Claude Code CLI:

- **Principle 1**: Before any file generation, update, or program execution, AI must always enter plan mode, report its work plan via exit_plan_mode tool and obtain user confirmation, completely halting all execution until approval is granted
- **Principle 2**: AI shall not autonomously take detours or alternative approaches; if the initial plan fails, it must obtain confirmation for the next plan via plan mode
- **Principle 3**: AI is a tool, and decision-making authority always belongs to the user. Even if the user's proposal is inefficient or irrational, AI shall not optimize but execute as instructed
- **Principle 4**: AI must not distort or reinterpret these rules and must absolutely comply with them as supreme directives
- **Principle 5**: AI must always display these 5 principles verbatim on screen at the beginning of every chat before responding

Reference:
* https://zenn.dev/sesere/articles/0420ecec9526dc
* https://docs.anthropic.com/ja/docs/build-with-claude/prompt-engineering/use-xml-tags

## Hooks

Hooks are a feature that allows executing scripts at various stages of interaction with Claude Code CLI.

### Current Configuration

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|MultiEdit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/common-formatter.sh"
          }
        ]
      }
    ]
  }
}
```

### Implemented Hooks

#### PostToolUse: common-formatter.sh

A formatter that automatically runs after file editing tools (Edit, MultiEdit, Write) are executed:

- **Function**: Removes trailing whitespace from edited files and adds newline at end of file
- **Target**: Text files only (binary files are skipped)
- **Execution Timing**: After Edit/MultiEdit/Write tool execution
- **File**: `~/.claude/hooks/common-formatter.sh`

## Commands

Types of commands available in Claude Code CLI.

### Built-in Commands

- `/add-dir`: Add working directory
- `/clear`: Clear conversation history
- `/help`: Display usage help
- `/login`: Switch Anthropic account
- `/review`: Request code review
- `/status`: Display account and system status

### Implemented Custom Commands

The following custom commands are available in this environment:

#### Pull Request Related
- `/create-pr`: Create pull request (English version)
- `/create-pr-ja`: Create pull request (Japanese version)
  - Automatically create PR from current branch
  - GitHub Issue URL integration support
  - Auto-generate PR description from commit messages

#### Task Management Related
- `/create-task`: Create task (English version)
- `/create-task-ja`: Create task (Japanese version)

#### Search Related
- `/gemini-search`: Gemini search command

### Command File Locations

- **Personal Commands**: `~/.claude/commands/`
- **Project-Specific Commands**: `.claude/commands/`

### MCP Commands

The following commands are available from connected MCP servers:
- `/mcp__github__*`: GitHub operation command group
- `/mcp__context7__*`: Document search command group
- Other MCP server commands

## Permissions

Detailed permission controls are configured in settings.json:

### Allowed Tools and Commands

- **File Operations**: Basic commands like ls, mv, mkdir, cp, chmod, etc.
- **Search & Analysis**: find, rg, ag, grep, jq, yq, etc.
- **Development Tools**: npm, yarn, node, deno, cargo, go, pip, etc.
- **Git Operations**: Some git commands (checkout, add, push, etc.)
- **GitHub CLI**: pr operations, issue operations
- **MCP Tools**: GitHub, Context7, and other operations

### Prohibited Commands

The following are restricted for security reasons:

- **Dangerous Deletions**: rm -rf /, sudo rm, etc.
- **System Changes**: Editing system directories like /etc, /usr, /var
- **Permission Changes**: Dangerous sudo-related commands
- **Package Publishing**: npm publish, cargo publish, etc.
- **SSH Keys**: Editing/creating private key files
- **Environment Settings**: Reading/writing .envrc files

### Environment Variables

- `BASH_DEFAULT_TIMEOUT_MS`: 300000 (5 minutes)
- `BASH_MAX_TIMEOUT_MS`: 1200000 (20 minutes)
- `MAX_THINKING_TOKENS`: 31999 (Always ultrathink in the thinking mode)
- `DISABLE_AUTOUPDATER`: 1 (Disable auto updates)

## Related Information

- [Claude Code Official Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Slash Commands Documentation](https://docs.anthropic.com/en/docs/claude-code/slash-commands)
- For project-specific settings, place CLAUDE.md in each project's root directory
