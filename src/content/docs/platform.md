---
title: "Stackbilder Platform"
description: "Two-phase scaffold architecture, governance output, plan tiers, and the TarotScript deterministic engine."
section: "platform"
order: 4
color: "#f472b6"
tag: "04"
---

# Stackbilder Platform

> **Architect v2 — Active Build.** The platform is in its v2 build cycle. Docs reflect the current stable surface; new capabilities are landing continuously.

Stackbilder is a governance-enforced architecture planning tool that produces sprint-ready ADRs, deployable scaffolds, and structured artifacts — not vague suggestions. It sits at the center of the [Stackbilt ecosystem](/ecosystem), with [Charter CLI](/getting-started) handling local governance, the [MCP Gateway](/mcp) enabling agent access, and [TarotScript](/tarotscript) powering the deterministic scaffold engine. The frontend is [stackbilt-web](/stackbilt-web) (Astro 6 + React islands on Cloudflare Workers). The commercial CLI surface is [stackbilt-build](/stackbilt-build). Response contracts and scaffold schemas are exported from [@stackbilt/contracts](/contracts).

## The 6-Mode Pipeline

Architecture generation runs through six sequential modes. Each mode builds on the previous, with cross-references via sequential IDs.

| Phase | Mode | Output | IDs |
|-------|------|--------|-----|
| Definition | **PRODUCT** | Product Requirements Document | REQ-001, SLA-001, CON-001 |
| Definition | **UX** | User journey maps and experience flows | UJ-001 |
| Definition | **RISK** | Risk assessment and value model | RISK-001 |
| Architecture | **ARCHITECT** | Technical blueprint: services, schemas, boundaries | COMP-001, DS-001 |
| Execution | **TDD** | Test strategy per component | TS-001 |
| Execution | **SPRINT** | Sprint-ready ADRs with dependency graph | ADR-001 |

## Structured Artifacts (v2)

Every mode emits a typed JSON artifact alongside prose. These artifacts use sequential, referenceable IDs that chain across modes:

- PRODUCT defines `REQ-001`, `SLA-001`, `CON-001`
- ARCHITECT references `reqRefs: ["REQ-001"]`, `riskRefs: ["RISK-001"]`
- TDD validates `slaRefs: ["SLA-001"]`
- SPRINT produces ADRs that trace back to components and requirements

Each artifact includes a `confidence` field with an overall score (0-100) and a `missing[]` array surfacing what the AI was not told.

## Cross-Mode Contradiction Checker

After each mode completes, an incremental checker runs 8 validation rules:

- Every `MUST` requirement has a component covering it
- Every SLA has a validation entry in TDD
- Every `CRITICAL`/`HIGH` risk has a test scenario
- ARCHITECT doesn't use technologies RISK marked as blocked
- Named events appear consistently across modes
- SPRINT surfaces requirements with no ADR

Results are available via the API as a `contradictionReport`.

## Scaffold Engine

Completed flows can generate a deployable Cloudflare Workers project (9-15 files). The scaffold engine uses category-aware routing:

| Component Category | Generated File |
|-------------------|----------------|
| compute / data / integration | `routes/*.ts` (CRUD stubs) |
| async | `worker/*-queue.ts` (queue handlers) |
| security | `worker/middleware/*.ts` (auth middleware) |
| frontend | skipped |

Template types: `workers-crud-api`, `workers-queue-consumer`, `workers-durable-object`, `workers-websocket`, `workers-cron`, `pages-static`.

Scaffolds include `scaffoldHints` (template classification + confidence score) and `nextSteps` (deployment commands).

## Governance Integration

Governance is embedded directly in the scaffold pipeline rather than a separate service binding. Architecture decisions are validated against blessed patterns inline as each mode runs; violations are flagged depending on governance mode.

| Mode | Behavior | Plan Tier |
|------|----------|-----------|
| `PASSIVE` | Log only — never blocks | Free |
| `ADVISORY` | Warn on issues, flow continues | Pro |
| `ENFORCED` | Block on FAIL, require remediation | Team |

Blessed-pattern enforcement runs as part of the ARCHITECT mode. Governance results (validations, persisted ADR IDs, warnings) are available via `getGovernanceStatus` on the flow response.

### Advanced Governance Configurations

Team plans unlock additional governance options:

- **Domain Locking** (`domainLock`) — Locks domain entities after PRODUCT mode to prevent drift. Supports strictness levels, entity creation controls, and vendor allow/block lists.
- **Per-Mode Quality Thresholds** (`qualityByMode`) — Set different minimum quality scores per execution mode.

## Plan Tiers & Quotas

Every account is associated with a plan tier that determines rate limits and feature access.

| Quota | Free | Pro | Team |
|-------|------|-----|------|
| Scaffolds per month | 3 | 50 | 50/seat |
| Images per month | 5 | 100 | Pooled |

## AI Model Routing

The platform applies a model policy per request. Provider/model selection is tier-aware. Phase 1 scaffolds use deterministic [TarotScript](/tarotscript) (no LLM). Phase 2 (Pro/Team) adds an LLM polish pass via Cerebras. Image generation runs through [img-forge](/img-forge) (5 quality tiers, Cloudflare/OpenAI/Gemini providers).

## Output Artifacts

Each completed flow produces:

- **PRD** — structured product requirements with `REQ-001` IDs
- **Experience Maps** — user journeys and touchpoints
- **Risk Model** — value assessment, compliance flags, blocked patterns
- **Architecture Blueprint** — services, data contracts, component tree with cross-refs
- **TDD Strategy** — test surface per component with SLA validation
- **Sprint ADRs** — executable sprint plan with Architecture Decision Records
- **Scaffold** — deployable Workers project (on demand)
- **Contradiction Report** — cross-mode consistency validation

## Content Provenance

The Content Provenance API validates AI-generated or AI-assisted content against E-E-A-T criteria and returns a cryptographic audit receipt. Each receipt is hash-chained to the previous one — tampering with any record invalidates every record that follows it in the chain.

**Endpoint:** `POST /api/provenance/validate`  
**Auth:** Bearer token (same credential as platform API)  
**Response fields:** `validation` (gap report + suggestions), `audit_record_id` (UUIDv4), `chain_head` (current SHA-256 chain head)

Validation checks four pillars — Experience, Expertise, Authoritativeness, Trustworthiness — against the Google November 2024 site reputation policy by default. Each gap includes severity, a count of what was found vs. required, and actionable remediation examples.

Receipts can be independently verified at `trust.stackbilder.com/evidence/:hash`.

The underlying libraries — [`@stackbilt/evidence-core`](/evidence-core) and [`@stackbilt/audit-chain`](/audit-chain) — are both Apache-2.0 and available on npm. See [Security](/security#content-provenance--audit-chain) for the full architecture.

## Access

Access Stackbilder via three sibling consumers — same backends, different transports:

- **Browser UI** at [stackbilder.com](https://stackbilder.com) — interactive flow builder for human users
- **REST API** at `stackbilder.com/api/*` — direct HTTP integration (Charter CLI, server-to-server, CI; see [API Reference](/api-reference)). Same Worker serves both the UI and the API.
- **MCP gateway** at `mcp.stackbilt.dev/mcp` — OAuth-authenticated MCP Worker for AI agents (Claude Code, Claude Desktop, custom MCP clients). Sibling deployable that proxies to the same backend product workers (TarotScript, img-forge, stackbilt-engine, stackbilt-deployer). See [MCP Gateway](/mcp).
