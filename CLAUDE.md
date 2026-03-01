# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.
These rules override all default behavior. Follow them exactly as written.

---

# StackBilt Docs

Public documentation site for the StackBilt platform, Charter CLI, and Compass governance system.

---

## 1. Tech Stack & Environment Constraints

This is a **static-output Astro documentation site** styled with Tailwind CSS and deployed to Cloudflare's edge network via Wrangler.

| Layer | Technology | Version |
|-------|-----------|---------|
| Framework | Astro | 5.x |
| Styling | Tailwind CSS | 3.4 (`sb-*` design tokens) |
| Markdown | MDX + Shiki (`github-dark-default`) | via `@astrojs/mdx` |
| Content | Astro Content Collections | Zod-typed frontmatter |
| Deployment | Cloudflare Workers Static Assets | Wrangler 4.x |
| Governance | Charter CLI (`@stackbilt/cli`) | 0.4.2 |

### Package Manager

**npm is the package manager for this repository.** A `package-lock.json` lockfile exists at the project root. Before executing any install or script command:

1. Confirm `package-lock.json` exists (never `yarn.lock`, `pnpm-lock.yaml`, or `bun.lockb`).
2. Use `npm` for all commands — `npm install`, `npm run <script>`, `npx`.
3. Never run `yarn`, `pnpm`, or `bun` in this repository.

### Runtime Constraints

- **Static output only.** No SSR, no server endpoints, no dynamic routes at runtime.
- **Dark-only.** All styling assumes dark background. No light mode.
- **CSS classes** must use `sb-*` Tailwind tokens. Never use raw hex values.

---

## 2. Charter Governance

This repo uses the **Charter CLI** (`@stackbilt/cli`) for local-first governance enforcement. Charter is StackBilt's own OSS compliance toolkit — this repo is itself a governed Charter consumer.

### Configuration

- **Baseline**: `.charter/config.json` — stack preset `worker`, drift threshold 0.7
- **Git hook**: `.githooks/commit-msg` — validates governance trailers on every commit
- **CI gate**: `.github/workflows/charter-governance.yml` — runs on every PR to `main`
- **Citation strictness**: `WARN` (non-blocking initially; tighten to `FAIL` when team is ready)

### Charter Commands

```bash
npm run govern              # Display governance posture snapshot
npm run govern:validate     # Validate governance trailers in recent commits
npm run govern:audit        # Full policy coverage audit
npm run govern:drift        # Detect architectural drift
npm run govern:doctor       # Validate Charter config
```

### Governance Trailers

Commits must include a `Governed-By` trailer when changes are **LOCAL** or **CROSS_CUTTING** scope:

```
docs(mcp): add submitFeedback tool

Governed-By: CLAUDE.md#2-charter-governance
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Use `charter classify "<change>"` to determine the correct scope before committing. **SURFACE**-only changes (UI tweaks, typo fixes) do not require a trailer.

### Skills

| Skill | What it does |
|-------|-------------|
| `/classify` | Run `charter classify` on a planned change to determine scope |
| `/validate` | Run `charter validate --ci` and report trailer compliance |
| `/audit` | Run `charter audit` and report policy coverage |
| `/drift` | Run `charter drift --ci` and report architectural drift |

---

## 3. Git & Version Control Hygiene (SmartCommits)

### Staging Rules

- **NEVER stage whitespace-only or line-ending-only changes.** Only intentional content modifications are allowed.
- Before staging, run `git diff` to inspect changes. If a file contains only whitespace/formatting diffs, exclude it with `git reset HEAD <file>`.
- When in doubt, use `git diff --check` to detect whitespace errors.

### Atomic Commit Workflow

When the working tree contains multiple untracked or modified files, follow this procedure:

1. **Survey**: Run `git status` to see all changes.
2. **Chunk**: Group changes into logical atomic commits (e.g., one commit per doc page, one for config, one for components). Never lump unrelated changes into a single commit.
3. **Preview**: For each proposed commit, output `git diff --stat` showing exactly which files and how many lines are affected.
4. **Propose**: Present the commit message for user approval. Format:
   ```
   <type>: <concise description>
   ```
   Types: `docs`, `feat`, `fix`, `refactor`, `chore`, `style`.
5. **Wait**: Do NOT execute `git commit` until the user explicitly approves the message.
6. **Commit**: Stage only the files in the approved chunk, commit, then proceed to the next chunk if approved.

### Prohibitions

- Never run `git add -A` or `git add .` without first reviewing every file in the diff.
- Never amend a commit unless the user explicitly requests it.
- Never force-push to `main`.
- Never skip pre-commit hooks (`--no-verify`).

---

## 4. Task Scoping & Session Management (Sprint Discipline)

Every interaction is a **focused sprint** scoped to a single deliverable.

### Rules

1. **One task, one outcome.** Do not combine content updates + deployment + tooling in one session.
2. **Stop-and-confirm.** When done, state exactly what was delivered. Do not auto-start the next task or suggest improvements.
3. **Sprint-ready tasks only.** Every task must have a concrete, verifiable outcome achievable in one session.
4. **Diagnose before fixing.** For build or rendering issues, identify the root cause before editing files.
5. **No scope creep.** If a task reveals adjacent work (e.g., a broken link discovered while editing a page), note it and stop. Do not fix it unless the user requests it.
6. **No chaining.** After completing a deliverable, do not propose or begin the next task. Wait for the user.

### Documentation Update Sessions

When updating doc pages in `src/content/docs/`:

- Read the target file before editing.
- Preserve existing frontmatter (`title`, `section`, `order`, `color`, `tag`) unless the user explicitly requests changes.
- Validate that edits do not break the Content Collection schema defined in `src/content/config.ts`.

---

## 5. Quality Assurance & Deployment Pipeline

### Pre-Deployment Runbook

Before running any deploy command, follow this sequence exactly:

```
Step 1: npm run build          # Verify Astro build succeeds locally
Step 2: Inspect build output   # Check dist/ for expected pages
Step 3: npm run deploy         # Only if Step 1 passed cleanly
```

### Rules

1. **Build before deploy.** Never run `npm run deploy` or `npm run deploy:staging` without first confirming `npm run build` (equivalently, `astro build`) succeeds with zero errors.
2. **Diagnose before retry.** If the build fails, read the error output and identify whether it is an Astro compilation error, a Tailwind config issue, a content schema violation, or a missing dependency. Fix the root cause before re-running.
3. **No deploy on red.** If the build produces warnings about missing frontmatter fields, broken imports, or deprecated APIs, resolve them before deploying.
4. **Staging first.** When the user has not specified an environment, prefer `npm run deploy:staging` over `npm run deploy` and confirm with the user before targeting production.

### Available Scripts

```bash
npm run dev              # Astro dev server (hot reload)
npm run build            # Build static HTML to dist/
npm run preview          # Preview via wrangler dev (local Workers)
npm run deploy           # Build + deploy to Cloudflare Workers (production)
npm run deploy:staging   # Build + deploy to Cloudflare Workers (staging)
```

---

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
| 8 | compass-governance-api.md | Compass Governance API | platform | `#22d3ee` (cyan) |

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
