# GitHub Issue Implementation Task Creation

Automates the workflow from GitHub Issue URL to implementation.

## Usage

```
/project:create-task
```

## Example

```
/user:create-task
Please enter the GitHub Issue URL: https://github.com/owner/repo/issues/123
```

## Workflow

1. **GitHub Issue Analysis**
   - Parse the provided GitHub Issue URL
   - Retrieve Issue details using GitHub MCP server
   - Collect title, description, labels, comments, etc.

2. **Create Implementation Plan in Plan Mode**
   - Plan implementation approach based on Issue content
   - Clarify technical challenges and solutions
   - Identify implementation steps
   - Get approval via `/exit plan mode`

3. **Organize into TODO File**
   - Save planning results to `.claude/work/{org}-{repo}-{issueid}-todo.md`
   - Example: `.claude/work/facebook-react-12345-todo.md`
   - Automatically create .claude/work folder if it doesn't exist
   - Structure in the following format:
   ```markdown
   # Issue #123: [Issue Title]

   ## Overview
   [Issue Summary]

   ## Implementation Plan
   [Implementation approach created in plan mode]

   ## Task List
   - [ ] Task 1: [Details]
   - [ ] Task 2: [Details]
   - [ ] Task 3: [Details]

   ## Technical Details
   [Required technical considerations]
   ```

4. **Start Implementation**
   - Begin implementation based on created TODO file
   - Manage progress using TodoWrite tool
   - Execute each task sequentially

## Requirements

- GitHub Issue URL (required)
- Repository access permissions (via GitHub MCP)

## Output

- `.claude/work/{org}-{repo}-{issueid}-todo.md`: Implementation plan and progress tracking file
- Implemented code/changes
