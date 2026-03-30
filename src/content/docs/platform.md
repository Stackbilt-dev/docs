---
title: "Stackbilder Platform"
description: "Two-phase scaffold architecture, governance output, plan tiers, and the TarotScript deterministic engine."
section: "platform"
order: 4
color: "#f472b6"
tag: "04"
---

# Stackbilder Platform

Stackbilder generates governed, production-ready codebases from plain-language descriptions. The architecture uses a two-phase approach: a deterministic skeleton with governance output (Phase 1), and optional LLM-powered code polish (Phase 2).

## Two-Phase Architecture

### Phase 1: Deterministic Skeleton (TarotScript)

Your intention is processed in two deterministic steps:

1. **Classify** — TarotScript maps your description against a vocabulary deck, producing a pattern classification (e.g., "stripe", "github", "mcp", "rest") with confidence scoring.

2. **Scaffold-Cast** — A deterministic spread generates the full project skeleton: file structure, config files, and the `.ai/` governance suite.

**Performance:** ~20ms. Zero inference cost. Same input = same output.

**Output includes:**
- Project structure and configuration
- `.ai/threat-model.md` — STRIDE-based security threat analysis specific to your architecture
- `.ai/adr-*.md` — Architectural decision records with context, alternatives, and consequences
- `.ai/test-plan.md` — Integration and unit test specifications with coverage targets
- Architectural constraints — machine-readable guardrails for Phase 2

### Phase 2: LLM Polish (Pro tier)

Takes the Phase 1 skeleton and generates idiomatic, production-grade code using Cerebras fast inference. The differentiator: the LLM works *within* the governance constraints from Phase 1.

Phase 2 is optional and only available on Pro and Team plans.

## Governance Output

Every scaffold ships with governance — it's not a separate product or add-on. The `.ai/` directory is generated deterministically in Phase 1.

| File | Content |
|------|---------|
| `threat-model.md` | STRIDE analysis: spoofing, tampering, repudiation, information disclosure, denial of service, elevation of privilege — specific to your architecture |
| `adr-*.md` | Architectural decision records: the "why" behind non-obvious choices, with alternatives considered |
| `test-plan.md` | Test specifications: integration scenarios, unit test targets, coverage goals, framework recommendations |
| `constraints.json` | Machine-readable guardrails that Phase 2 LLM must respect |

## Plan Tiers

Flat pricing. No credits, no tokens, no per-action charges.

| | Free | Pro | Team |
|---|---|---|---|
| **Price** | $0 | $29/mo | $19/seat/mo |
| **Scaffolds/mo** | 3 | 50 | 50/seat |
| **Images/mo** | 5 | 100 | Pooled |
| **Phase 1** | Yes | Yes | Yes |
| **Phase 2 (LLM polish)** | No | Yes | Yes |
| **Quality tiers (img-forge)** | Draft-Premium | All 5 | All 5 |
| **Stacks** | Cloudflare Workers | All supported | All supported |
| **Governance output** | Yes | Yes | Yes |

Usage is enforced via invisible quotas through edge-auth. Users see "X scaffolds remaining" at 80% usage, with a hard wall and upgrade CTA at 100%.

## Supported Stacks

Cloudflare Workers is the currently available stack. Multi-stack expansion is on the roadmap:

| Stack | Status |
|-------|--------|
| Cloudflare Workers (D1, KV, R2, DO) | Available |
| Vercel / Next.js (App Router, Edge Runtime) | Roadmap |
| AWS Lambda (API Gateway, DynamoDB) | Roadmap |
| Supabase Edge Functions (Postgres) | Roadmap |
| Deno Deploy (Fresh, KV) | Roadmap |

## API

Stackbilder exposes server-side API routes at `stackbilder.com/api/*`. These call TarotScript and img-forge via Cloudflare service bindings (zero HTTP hop, same-colo execution).

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/flows` | GET | List user's scaffold flows |
| `/api/flows` | POST | Classify + scaffold-cast a new flow |
| `/api/flows/:id` | GET | Get flow detail (artifacts, governance, scaffold) |
| `/api/images/generate` | POST | Create an image generation job |
| `/api/images` | GET | List user's image jobs |
| `/api/images/:id` | GET | Get image job status |

All API routes require authentication via `better-auth.session_token` cookie. Session validation runs through an RPC binding to edge-auth.

See [API Reference](/api-reference) for full request/response documentation.

## Access

- **Browser** at [stackbilder.com](https://stackbilder.com)
- **API** at `stackbilder.com/api/*` (authenticated server routes)
- **MCP** via the Stackbilt MCP gateway (see [MCP Integration](/mcp))
