# Commit

Create a conventional commit for changes in this docs repo.

## Instructions

1. Run `git status` and `git diff --stat` to see what changed.

2. Determine the commit type from the changes:
   - New/modified docs in `src/content/docs/` → `docs(<slug>): <message>`
   - Component/layout changes → `feat(ui): <message>`
   - Config changes (astro, tailwind, wrangler) → `chore(config): <message>`
   - Style changes → `style(theme): <message>`
   - Multiple types → use the most significant one

3. Draft a concise commit message (1 line, <72 chars).

4. Stage the relevant files and create the commit:

```bash
git add <files>
git commit -m "<type>(<scope>): <message>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

## User Request

$ARGUMENTS
