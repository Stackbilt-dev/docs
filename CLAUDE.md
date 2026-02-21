# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

---

# StackBilt Docs

Public documentation site for the StackBilt platform, Charter CLI, and Compass governance system.

## Tech Stack

- **Framework**: Astro 5.x (static output)
- **Styling**: Tailwind CSS 3.4 with custom `sb-*` design tokens
- **Markdown**: MDX integration + Shiki syntax highlighting (github-dark-default)
- **Deployment**: Cloudflare Workers Static Assets (`wrangler deploy`)
- **Content**: Astro Content Collections with typed frontmatter (Zod schema)

## Project Structure

```
├── src/
│   ├── content/
│   │   ├── config.ts          # Content collection schema (Zod)
│   │   └── docs/              # Markdown doc pages
│   │       ├── getting-started.md
│   │       ├── cli-reference.md
│   │       ├── ci-integration.md
│   │       ├── platform.md
│   │       ├── mcp.md
│   │       ├── ecosystem.md
│   │       └── api-reference.md
│   ├── components/
│   │   ├── Breadcrumbs.astro
│   │   ├── PrevNext.astro
│   │   ├── Search.astro
│   │   ├── Sidebar.astro
│   │   └── TableOfContents.astro
│   ├── layouts/
│   │   └── DocsLayout.astro
│   ├── pages/
│   │   ├── index.astro        # Redirects to /getting-started
│   │   └── [...slug].astro    # Dynamic doc page renderer
│   └── styles/
│       └── global.css         # Terminal-aesthetic design system
├── public/
│   └── favicon.svg
├── astro.config.mjs
├── tailwind.config.mjs
├── wrangler.toml              # Workers static assets config
├── package.json
└── tsconfig.json
```

## Content Schema

Every doc page in `src/content/docs/` requires this frontmatter:

```yaml
---
title: "Page Title"       # Displayed in sidebar, breadcrumb, search
section: "charter"         # Grouping: charter | platform | ecosystem
order: 1                   # Numeric sort order (determines sidebar + prev/next nav)
color: "#2ea043"           # Hex color for tag dot, sidebar highlight, breadcrumb tint
tag: "01"                  # Display tag shown in sidebar + search results
---
```

### Current Doc Map

| Order | File | Title | Section | Color |
|-------|------|-------|---------|-------|
| 1 | getting-started.md | Getting Started | charter | `#2ea043` (green) |
| 2 | cli-reference.md | CLI Reference | charter | `#f59e0b` (amber) |
| 3 | ci-integration.md | CI Integration | charter | `#f59e0b` (amber) |
| 4 | platform.md | StackBilt Platform | platform | `#f472b6` (pink) |
| 5 | mcp.md | MCP Integration | platform | `#22d3ee` (cyan) |
| 6 | ecosystem.md | Ecosystem | ecosystem | `#c084fc` (purple) |
| 7 | api-reference.md | API Reference | platform | `#c084fc` (purple) |

### Section Color Conventions

- **charter** (open source CLI docs): green `#2ea043` or amber `#f59e0b`
- **platform** (StackBilt product docs): pink `#f472b6`, cyan `#22d3ee`, or purple `#c084fc`
- **ecosystem** (cross-service docs): purple `#c084fc`

## Design System

### Color Tokens (`sb-*` namespace in Tailwind)

| Token | Hex | Usage |
|-------|-----|-------|
| `sb-bg` | `#050508` | Page background |
| `sb-surface` | `#0a0e16` | Cards, code blocks |
| `sb-hover` | `#0f1420` | Hover states |
| `sb-border` | `#1a2030` | Borders |
| `sb-text-1` | `#e6edf3` | Primary text |
| `sb-text-2` | `#b8c0cc` | Secondary text |
| `sb-muted` | `#5c6370` | Muted/label text |
| `sb-dim` | `#353b47` | Dimmed elements |
| `sb-faint` | `#1c2028` | Subtle backgrounds |
| `sb-amber` | `#f5a623` | Primary accent (links, headings, highlights) |

### Typography

- **Headings**: Inter (sans-serif)
- **Body**: Inter (sans-serif), 0.875rem, 1.75 line-height
- **Code/Terminal**: SF Mono, Cascadia Code, JetBrains Mono
- **H2 style**: Uppercase, terminal font, amber, 0.08em tracking

### Visual Identity

- Dark-only terminal aesthetic (no light mode)
- Amber as primary accent throughout
- Code blocks have terminal chrome (dot decorations)
- Lists use `>` prefix (unordered) and zero-padded numbers (ordered)
- Ambient diagonal grid overlay at 0.02 opacity

## Commands

```bash
npm run dev          # Astro dev server (hot reload)
npm run build        # Build static HTML to dist/
npm run preview      # Preview via wrangler dev (local Workers)
npm run deploy       # Build + deploy to Cloudflare Workers
```

## Adding a New Doc Page

1. Create `src/content/docs/<slug>.md` with required frontmatter
2. Set `order` to the next available number
3. Choose `section` and `color` per conventions above
4. Set `tag` to zero-padded order (e.g., `"08"`)
5. The page auto-appears in sidebar, search, and prev/next nav

## Conventions

- **Component filenames**: PascalCase (e.g., `Sidebar.astro`)
- **Doc filenames**: kebab-case (e.g., `api-reference.md`)
- **CSS classes**: Use `sb-*` Tailwind tokens, avoid raw hex values
- **No light mode**: All styling assumes dark background
- **Static output only**: No SSR, no server endpoints, no dynamic routes at runtime

## Related Repos

| Repo | Purpose |
|------|---------|
| **Edgestack-Architech** | Main StackBilt platform (Workers backend + React frontend) |
| **stackbilt_docs_v2** | This repo — public documentation site |
