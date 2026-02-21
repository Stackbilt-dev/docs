# New Doc Page

Scaffold a new documentation page with correct frontmatter and content structure.

## Instructions

1. Ask the user for:
   - **Title** — the page title (e.g., "Pricing")
   - **Section** — one of: `charter`, `platform`, `ecosystem`
   - **Slug** — kebab-case filename (e.g., `pricing`)

2. Determine the next `order` number by reading existing docs:

```bash
ls src/content/docs/
```

3. Pick the next sequential order and zero-pad the tag (e.g., order 8 → tag "08").

4. Choose `color` based on section convention:
   - `charter` → `#2ea043` (green) or `#f59e0b` (amber)
   - `platform` → `#f472b6` (pink), `#22d3ee` (cyan), or `#c084fc` (purple)
   - `ecosystem` → `#c084fc` (purple)

5. Create `src/content/docs/<slug>.md` with this template:

```markdown
---
title: "<Title>"
section: "<section>"
order: <N>
color: "<color>"
tag: "<NN>"
---

# <Title>

> Brief description of what this page covers.

## Overview

Content here...
```

6. Confirm the page was created and remind the user to run `npm run dev` to preview.

## User Request

$ARGUMENTS
