# New Doc Page

Scaffold a new documentation page with correct frontmatter and content structure.

## Instructions

1. If the user has not provided all of the following, ask for them:
   - **Title** — the page title (e.g., "Pricing")
   - **Section** — one of: `charter`, `platform`, `ecosystem`
   - **Slug** — kebab-case filename (e.g., `pricing`)

2. Determine the next `order` number by reading the frontmatter of all existing docs in `src/content/docs/`. Do NOT use `ls` — read the files to get order values and find the next available integer.

3. Zero-pad the tag (order 8 → tag `"08"`, order 12 → tag `"12"`).

4. Choose `color` based on section convention:
   - `charter` → `#2ea043` (green) or `#f59e0b` (amber)
   - `platform` → `#f472b6` (pink), `#22d3ee` (cyan), or `#c084fc` (purple)
   - `ecosystem` → `#c084fc` (purple)

   Ask the user which color if the section has multiple options.

5. Create `src/content/docs/<slug>.md` with this template:

```markdown
---
title: "<Title>"
section: "<section>"
order: <N>
color: "<color>"
tag: "<NN>"
---

Brief description of what this page covers.

## Overview

Content here...
```

6. Validate that the frontmatter conforms to the schema in `src/content/config.ts` by reading that file and checking field types.

7. Confirm what was created. Remind the user to run `npm run dev` to preview. Then stop — do not write additional content or propose next steps.

## User Request

$ARGUMENTS
