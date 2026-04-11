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
| **TarotScript** | internal service binding | Deterministic scaffold engine — intent classification, scaffold-cast spreads, grimoire persistence |
| **img-forge** | internal service binding | AI image generation API, async job queue, R2 image storage |
| **Auth** | `auth.stackbilt.dev` | Centralized auth — OAuth (GitHub/Google), session management, API keys, quota, billing |
| **AEGIS** | `aegis.stackbilt.dev` | Persistent AI agent framework — see [aegis-oss](https://github.com/Stackbilt-dev/aegis-oss) |
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

All services use Stackbilt Auth (`auth.stackbilt.dev`) for centralized authentication:

- **OAuth** — GitHub and Google sign-in via Better Auth
- **Session cookies** — `better-auth.session_token`, validated via RPC service binding
- **API keys** — `ea_*`, `sb_live_*`, `sb_test_*` prefixes for programmatic access

The platform frontend (`stackbilder.com`) validates sessions via an RPC binding to the Stackbilt Auth service — near-zero latency, no HTTP hop.

## Pricing

Flat tiers. No credits, no tokens, no per-action charges.

| Plan | Scaffolds/mo | Images/mo | Price |
|------|-------------|-----------|-------|
| Free | 3 | 5 | $0 |
| Pro | 50 | 100 | $29/mo |
| Team | 50/seat | Pooled | $19/seat/mo |

Every plan includes full governance output. See [stackbilder.com/pricing](https://stackbilder.com/pricing).

## Open Source Libraries

Beyond Charter and the commercial services, Stackbilt maintains a set of edge-native open source libraries. They are standalone, composable, and deliberately scoped — each solves one problem Cloudflare Workers developers hit repeatedly.

| Library | Repo | Purpose |
|---|---|---|
| **Charter CLI** | [Stackbilt-dev/charter](https://github.com/Stackbilt-dev/charter) | Governance runtime, ADF context compiler, CLI gateway (Apache-2.0) |
| **Stackbilt MCP Gateway** | [Stackbilt-dev/stackbilt-mcp-gateway](https://github.com/Stackbilt-dev/stackbilt-mcp-gateway) | OAuth-authenticated MCP gateway routing to Stackbilt platform services |
| **AEGIS (OSS framework)** | [Stackbilt-dev/aegis-oss](https://github.com/Stackbilt-dev/aegis-oss) | Persistent AI agent framework for Workers — multi-tier memory, goals, dreaming cycles, MCP native |
| **llm-providers** | [Stackbilt-dev/llm-providers](https://github.com/Stackbilt-dev/llm-providers) | Multi-LLM failover with circuit breakers, cost tracking, intelligent retry |
| **worker-observability** | [Stackbilt-dev/worker-observability](https://github.com/Stackbilt-dev/worker-observability) | Edge-native observability — health checks, structured logging, metrics, tracing, SLI/SLO monitoring |
| **audit-chain** | [Stackbilt-dev/audit-chain](https://github.com/Stackbilt-dev/audit-chain) | Tamper-evident audit trail via SHA-256 hash chaining with R2 immutability and D1 indexing |
| **feature-flags** | [Stackbilt-dev/feature-flags](https://github.com/Stackbilt-dev/feature-flags) | KV-backed feature flags — per-tenant, canary rollouts, A/B conditions, Hono middleware |
| **contracts** | [Stackbilt-dev/contracts](https://github.com/Stackbilt-dev/contracts) | Stackbilt Contract Ontology Layer — ODD-driven code generation from TypeScript+Zod contracts |
| **cc-taskrunner** | [Stackbilt-dev/cc-taskrunner](https://github.com/Stackbilt-dev/cc-taskrunner) | Autonomous task queue for Claude Code with safety hooks, branch isolation, PR creation |
| **Social Sentinel** | [Stackbilt-dev/social-sentinel](https://github.com/Stackbilt-dev/social-sentinel) | Privacy-first social sentiment monitoring — PII redaction, Workers AI sentiment analysis |
| **Mindspring** | [Stackbilt-dev/mindspring](https://github.com/Stackbilt-dev/mindspring) | Semantic search for AI conversation exports — upload, embed, search, RAG chat |
| **n8n-transpiler** | [Stackbilt-dev/n8n-transpiler](https://github.com/Stackbilt-dev/n8n-transpiler) | n8n automation JSON → deployable Workers transpiler |
| **equity-scenario-sim** | [Stackbilt-dev/equity-scenario-sim](https://github.com/Stackbilt-dev/equity-scenario-sim) | Cap table simulator for partnership negotiations |
| **ai-playbook** | [Stackbilt-dev/ai-playbook](https://github.com/Stackbilt-dev/ai-playbook) | AI interaction frameworks, philosophical archetypes, context engineering patterns |

All libraries live under the [`Stackbilt-dev`](https://github.com/Stackbilt-dev) GitHub organization. Contributions welcome — see each repo's `CONTRIBUTING.md` and `SECURITY.md`.

## OSS Core ↔ Commercial Extension Pattern

Some capabilities in the Stackbilt ecosystem ship as a public OSS core with a commercial productization built on top. The OSS core is the canonical, publicly-named reference implementation — that's what gets documented, discussed, contributed to, and written about. Commercial extensions are implementation details: they are not publicly named, not separately documented, and not referenced in public artifacts.

A concrete example: [`aegis-oss`](https://github.com/Stackbilt-dev/aegis-oss) is the full persistent AI agent framework for Cloudflare Workers — multi-tier memory, autonomous goals, dreaming cycles, MCP native. It is the canonical AEGIS and is fully open source under its repository license. The commercial Stackbilt platform builds additional integrations and productization on top of that core. When referring to "AEGIS" in any public context — blog posts, GitHub issues, conference talks, external documentation, social media — the reference is to `aegis-oss`. Commercial extensions exist but are not separately named, advertised, or linked publicly.

This convention serves two purposes:

1. **OSS clarity.** Contributors, users, and researchers engage with one canonical repo per capability. There is no ambiguity about "which version are we talking about."
2. **Moat protection.** Commercial productization is kept out of public discussion, which prevents feature leaks and competitive mapping of the commercial surface.

Internal contributors — including autonomous agents filing issues or drafting documentation — must follow the same convention. Public artifacts reference the OSS core only. See [Outbound Disclosure](/security/#outbound-disclosure--filing-against-stackbilt-dev-public-repositories) for the full authoring rules.

## Multi-Stack Roadmap

Cloudflare Workers is the currently supported stack. Coming soon:

- Vercel / Next.js
- AWS Lambda + API Gateway
- Supabase Edge Functions
- Deno Deploy

Stack expansion is tracked in the TarotScript deck system. The architecture is stack-agnostic — each target gets its own runtime deck + threat overlay + file templates.
