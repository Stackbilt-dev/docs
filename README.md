# Stackbilt Docs

Source for [docs.stackbilder.com](https://docs.stackbilder.com) — the source-of-truth documentation portal for the [Stackbilt-dev](https://github.com/Stackbilt-dev) ecosystem.

Covers every public and private repo in the org: platform workers, OSS libraries, agent infrastructure, developer tools, and standalone apps.

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | Astro 7.0.3 (static output) |
| Styling | Tailwind CSS |
| Runtime | Cloudflare Workers (via Wrangler) |
| Governance | Charter CLI (`@stackbilt/cli`) + ADF (`.ai/`) |
| Pre-commit | `pnpm build` — build must pass before every commit |

## Local development

```bash
pnpm install
pnpm dev          # http://localhost:4321
```

## Build and deploy

```bash
pnpm build        # Astro static build → dist/
pnpm deploy       # build + wrangler deploy + IndexNow ping
pnpm preview      # wrangler dev against the built dist/
```

Deployed to `docs.stackbilder.com` (canonical) and `docs.stackbilt.dev` (legacy redirect — remove after transition completes).

## Content structure

All documentation lives in `src/content/docs/*.md`. Each file requires this frontmatter:

```markdown
---
title: "Page title"
description: "One-line description for SEO and Open Graph"
section: "platform" | "ecosystem" | "charter"
order: 10             # controls sidebar sort order
color: "#22d3ee"      # accent color used in the UI
tag: "10"             # zero-padded string version of order
lastVerified: "2026-06-28"
---
```

Routes are dynamic — `src/pages/[...slug].astro` reads `getCollection('docs')` via `getStaticPaths()`. Adding an `.md` file here automatically creates its route at `/{slug}`.

## Adding a page

1. Create `src/content/docs/{slug}.md` with valid frontmatter
2. Run `pnpm build` to verify it compiles clean (the pre-commit hook does this automatically)
3. Link to it from related pages and from the `ecosystem.md` All Repositories table

## Docs sync pipeline

Some pages are pulled from source repos rather than hand-authored here. The sync pipeline is defined in `docs-manifest.json` and executed by `scripts/docs-sync.sh`.

```bash
# Sync all sources, build, and deploy
GITHUB_TOKEN=ghp_... ./scripts/docs-sync.sh

# Dry run — shows what would change, no writes
GITHUB_TOKEN=ghp_... ./scripts/docs-sync.sh --dry-run

# Sync one source only
GITHUB_TOKEN=ghp_... ./scripts/docs-sync.sh --source charter

# Generate missing pages from source code via headless Claude
GITHUB_TOKEN=ghp_... ./scripts/docs-sync.sh --generate
```

Pages not in `docs-manifest.json` are hand-authored directly in this repo.

## Governance

This repo is governed by [Charter CLI](https://github.com/Stackbilt-dev/charter). Pre-commit hooks enforce build validity; CI validates drift and ADF metric ceilings.

```bash
pnpm govern:validate   # charter validate --ci
pnpm govern:drift      # charter drift --ci
pnpm verify:adf        # ADF metric ceiling check
```

ADF context modules live in `.ai/`. See `.ai/manifest.adf` for module routing.

## Sitemap

The sitemap at `docs.stackbilder.com/sitemap-index.xml` is generated at build time. Each page's `<lastmod>` is derived from the file's last git commit timestamp.
