# Sync from Main Repo

Pull updated API, MCP, or ecosystem documentation from the main EdgeStack Architect repo into this docs site.

## Instructions

1. Read the source file from the main repo at `/mnt/c/Users/kover/Documents/Edgestack-Architech/docs/`:
   - `API.md` → updates `src/content/docs/api-reference.md`
   - `MCP.md` → updates `src/content/docs/mcp.md`
   - `ECOSYSTEM.md` → updates `src/content/docs/ecosystem.md`

2. If the user specifies which doc to sync, only sync that one. Otherwise sync all three.

3. For each file:
   - Read the source from the main repo
   - Read the current doc in this repo
   - Preserve the frontmatter (title, section, order, color, tag) from the existing doc
   - Replace the markdown body with updated content from the source
   - Adapt formatting to match this site's conventions (terminal aesthetic, concise prose)

4. Show a diff summary of what changed.

## User Request

$ARGUMENTS
