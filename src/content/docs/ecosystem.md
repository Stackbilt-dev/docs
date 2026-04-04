---
title: "Ecosystem"
description: "How Stackbilt tools work together — deterministic scaffolding, governance, image generation, and the open-source Charter CLI"
section: "ecosystem"
order: 1
color: "#c084fc"
tag: "01"
---

# Ecosystem

Stackbilt is a developer platform built on three commercial services and one open-source CLI. Together they span the full lifecycle from describing an idea to shipping a governed, production-ready codebase.

## The Three Pieces

| Tool | Role |
|------|------|
| **Charter** (`@stackbilt/cli`) | Open-source (Apache-2.0). Local + CI governance runtime, ADF context compiler, CLI gateway. |
| **Stackbilder** | Commercial. Two-phase scaffold engine: deterministic skeleton via TarotScript (~20ms, zero LLM), optional LLM polish via Cerebras. Governance output (threat analysis, ADRs, test plans) ships with every scaffold. |
| **img-forge** | Commercial. Multi-provider AI image generation across 5 quality tiers (SDXL through Gemini 3.1). |

Charter is the open-source CLI. Stackbilder and img-forge are commercial services, both included in the unified flat pricing at [stackbilder.com/pricing](https://stackbilder.com/pricing).

## Service Map

| Service | Domain | Purpose |
|---------|--------|---------|
| **Stackbilder Platform** | `stackbilder.com` | Product frontend, Astro server API routes, service binding gateway |
| **TarotScript** | `tarotscript-worker` (service binding) | Deterministic scaffold engine — intent classification, scaffold-cast spreads, grimoire persistence |
| **img-forge** | `img-forge-gateway` (service binding) | AI image generation API, async job queue, R2 image storage |
| **Auth** | `auth.stackbilt.dev` | Centralized auth — OAuth (GitHub/Google), session management, API keys, quota, billing |
| **AEGIS** | `aegis.stackbilt.dev` | Internal cognitive agent — memory, goals, task pipeline |
| **Docs** | `docs.stackbilder.com` | Documentation (this site) |
| **Blog** | `blog.stackbilder.com` | Blog and changelog |

## How They Fit Together

```
IDEA (plain language description)
  │
  ▼
Phase 1: TarotScript classify(intention)
  │  → deterministic pattern matching, ~20ms
  │
  ▼
Phase 1: TarotScript scaffold-cast(intention + pattern)
  │  → project structure, config files, .ai/ governance suite
  │  → threat-model.md, ADRs, test-plan.md
  │  → zero LLM, zero inference cost
  │
  ▼ (optional, Pro tier)
Phase 2: Cerebras LLM polish
  │  → idiomatic code generation WITHIN Phase 1 constraints
  │  → governance guardrails prevent drift
  │
  ▼
Charter: validate + drift → commit compliance
  │
  ▼
SHIPPED (governed)
```

<!-- DOCSYNC:BEGIN:charter-oss-ecosystem -->
## Charter: Local Enforcement + ADF Context Compiler

Charter runs in your terminal and CI pipeline. It validates commit trailers, scores drift against your blessed stack, and blocks merges on violations. Zero SaaS dependency — all checks are deterministic and local.

Charter also ships **ADF (Attention-Directed Format)** — a modular, AST-backed context system that replaces monolithic `.cursorrules` and `claude.md` files with compiled, trigger-routed `.ai/` modules. ADF treats LLM context as a compiled language: emoji-decorated semantic keys, typed patch operations, manifest-driven progressive disclosure, and metric ceilings with CI evidence gating.

```bash
npm install --save-dev @stackbilt/cli
npx charter setup --preset fullstack --ci github --yes
npx charter adf init    # scaffold .ai/ context directory
```

**Governance commands:** `validate`, `drift`, `audit`, `classify`, `hook install`.
**ADF commands:** `adf init`, `adf fmt`, `adf patch`, `adf bundle`, `adf sync`, `adf evidence`.
**Engine commands:** `login`, `architect`, `scaffold` — generate and write tech stacks via the Stackbilder Engine.

For quantitative analysis of ADF's impact on autonomous system architecture, see the [Context-as-Code white paper](https://github.com/Stackbilt-dev/charter/blob/main/papers/context-as-code-v1.1.md).
<!-- DOCSYNC:END:charter-oss-ecosystem -->

## Stackbilder: Two-Phase Scaffold

### Phase 1 — Deterministic Skeleton (Free tier)

TarotScript classifies your intention against a vocabulary deck, then runs a `scaffold-cast` spread that deterministically produces:

- Project structure and config files
- `.ai/threat-model.md` — STRIDE-based security threat analysis
- `.ai/adr-*.md` — Architectural decision records
- `.ai/test-plan.md` — Integration and unit test specifications
- Architectural constraints (machine-readable guardrails)

~20ms. Zero inference cost. Same input = same output.

### Phase 2 — LLM Polish (Pro tier)

Takes the Phase 1 skeleton and generates idiomatic, production-grade code using Cerebras fast inference. The key differentiator: the LLM works *within* the governance constraints from Phase 1 — guided generation, not blind generation.

### Access

- **Browser UI** at [stackbilder.com](https://stackbilder.com)
- **API** at `stackbilder.com/api/flows` (authenticated Astro server routes)
- **MCP** via the Stackbilt MCP gateway (see [MCP Integration](/mcp))

## img-forge: AI Image Generation

Multi-provider image generation across 5 quality tiers, included in your Stackbilder plan with no per-image costs.

| Tier | Provider | Model |
|------|----------|-------|
| Draft | Cloudflare AI | SDXL Lightning |
| Standard | Cloudflare AI | FLUX.2 Klein 4B |
| Premium | Cloudflare AI | FLUX.2 Dev |
| Ultra | Gemini | Gemini 2.5 Flash |
| Ultra+ | Gemini | Gemini 3.1 Flash |

See [img-forge API](/img-forge) for the full REST and MCP reference.

## Authentication

All services use edge-auth (`auth.stackbilt.dev`) for centralized authentication:

- **OAuth** — GitHub and Google sign-in via Better Auth
- **Session cookies** — `better-auth.session_token`, validated via RPC service binding
- **API keys** — `ea_*`, `sb_live_*`, `sb_test_*` prefixes for programmatic access

See [API Key Management](/api-keys) for generation, rotation, and revocation. The platform frontend (`stackbilder.com`) validates sessions via an RPC binding to edge-auth — near-zero latency, no HTTP hop.

## Pricing

Flat tiers. No credits, no tokens, no per-action charges.

| Plan | Scaffolds/mo | Images/mo | Price |
|------|-------------|-----------|-------|
| Free | 3 | 5 | $0 |
| Pro | 50 | 100 | $29/mo |
| Team | 50/seat | Pooled | $19/seat/mo |

Every plan includes full governance output. See [stackbilder.com/pricing](https://stackbilder.com/pricing) and [Billing & Subscriptions](/billing) for checkout flow and subscription management.

## Multi-Stack Roadmap

Cloudflare Workers is the currently supported stack. Coming soon:

- Vercel / Next.js
- AWS Lambda + API Gateway
- Supabase Edge Functions
- Deno Deploy

Stack expansion is tracked in the TarotScript deck system. The architecture is stack-agnostic — each target gets its own runtime deck + threat overlay + file templates.
