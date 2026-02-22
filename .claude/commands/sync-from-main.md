# Sync from Main Repo

Pull updated documentation from the Edgestack-Architech repo into this docs site.

## Instructions

### Source Map

| Source Path | Target Doc |
|------------|-----------|
| `/mnt/c/Users/kover/Documents/Edgestack-Architech/docs/API.md` | `src/content/docs/api-reference.md` |
| `/mnt/c/Users/kover/Documents/Edgestack-Architech/docs/MCP.md` | `src/content/docs/mcp.md` |
| `/mnt/c/Users/kover/Documents/Edgestack-Architech/docs/ECOSYSTEM.md` | `src/content/docs/ecosystem.md` |

### Workflow

1. If the user specifies which doc to sync, only sync that one. Otherwise sync all three.

2. For each file to sync:
   a. Read the source file from the Edgestack-Architech repo.
   b. Read the current target doc page in this repo.
   c. **Preserve the frontmatter block exactly** (`title`, `section`, `order`, `color`, `tag`). Do not modify it.
   d. Replace the markdown body (everything after the frontmatter closing `---`) with updated content from the source.
   e. Adapt formatting to match this site's conventions:
      - Terminal aesthetic, concise prose
      - Code blocks with appropriate language tags
      - Tables for structured data
      - No raw HTML

3. After syncing, run `git diff --stat` and show a summary of what changed (files, lines added/removed).

4. **Do NOT commit.** Tell the user to review the changes and use `/commit` when ready.

5. If a source file does not exist at the expected path, report which file is missing and stop. Do not guess or substitute.

## User Request

$ARGUMENTS
