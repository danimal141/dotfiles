# Pull Request Creation from Current Branch

Automates the pull request creation workflow for the current branch by analyzing git commits.

## Usage

```
/user:create-pr
```

## Example

```
/user:create-pr
Please provide the following information:
1. GitHub Issue URL (optional): https://github.com/owner/repo/issues/123
2. Target branch (default: main/master): develop
```

## Workflow

1. **Current Branch Analysis**
   - Get current branch name using git
   - Analyze commits between current branch and target branch
   - Extract commit messages using `git log target..HEAD`
   - Automatically generate work summary from commits

2. **GitHub Issue Integration** (if URL provided)
   - Parse the provided GitHub Issue URL
   - Retrieve Issue details using GitHub MCP server
   - Link PR to the Issue

3. **Pull Request Preparation**
   - Generate PR title based on:
     - Branch name pattern (e.g., feature/xxx → "Add xxx feature")
     - First commit message if branch name is generic
     - Issue title if Issue URL is provided
   - Create comprehensive PR description:
     - Auto-generated summary from commit messages
     - Related Issue information (if provided)
   - Determine target branch (use provided or default)

4. **Create Pull Request**
   - Push current branch to remote if needed
   - Create PR using GitHub CLI (`gh pr create`)
   - Include formatted description with:
     ```markdown
     ## Summary
     [Auto-generated from commit messages]
     - Implemented feature X
     - Fixed bug Y
     - Refactored component Z

     ## Related Issue
     https://github.com/owner/repo/issues/123 (if applicable)
     ```
   - Return PR URL for user reference

## Requirements

- Git repository with GitHub remote
- Current branch with commits to merge
- GitHub CLI (`gh`) configured
- Repository access permissions

## Output

- Created pull request URL
- Link between PR and Issue (if applicable)
