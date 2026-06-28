---
title: "Ecosystem"
description: "How Stackbilt tools work together — deterministic scaffolding, governance, image generation, and the open-source Charter CLI"
section: "ecosystem"
order: 1
color: "#c084fc"
tag: "01"
---

# Ecosystem

Stackbilder is built on multiple complementary tools that enforce governance across the full development lifecycle.

## The Pieces

| Tool | License | Role |
|------|---------|------|
| **[Charter](/getting-started)** (`@stackbilt/cli`) — [CLI Reference](/cli-reference) | Apache-2.0 (open source) | Local + CI governance runtime with ADF context compiler |
| **[AEGIS Core](/aegis-core)** (`@stackbilt/aegis-core`) | Apache-2.0 (open source) | Persistent AI agent framework — multi-tier memory, autonomous goals, dreaming cycles, MCP native |
| **[evidence-core](/evidence-core)** (`@stackbilt/evidence-core`) | Apache-2.0 (open source) | E-E-A-T gap detection and scoring library. Three policy presets (Google Nov 2024 default). Usable standalone. |
| **[audit-chain](/audit-chain)** (`@stackbilt/audit-chain`) | Apache-2.0 (open source) | Domain-agnostic tamper-evident audit logging for Cloudflare Workers (R2 + D1). SHA-256 hash-chained records. |
| **[worker-observability](/worker-observability)** ([GitHub](https://github.com/Stackbilt-dev/worker-observability)) | Apache-2.0 (open source) | ODD-driven telemetry SDK for Cloudflare Workers. Metrics, traces, spans, SLI/SLO. Not yet published to npm — install from source. |
| **[Stackbilder](/platform)** | Commercial | Unified platform on `stackbilder.com` — architecture generation, scaffold engine, Evidence Engine, Content Provenance, Worker Observability, Consultations, [img-forge](/img-forge) |

Charter and AEGIS are the open-source foundations. Stackbilder is the commercial platform that wraps them.

## Service Map

| Service | URL | Purpose |
|---------|-----|---------|
| **Stackbilder** | `stackbilder.com` | Unified platform Worker — UI, REST API, scaffold engine, governance, Evidence Engine, Observability |
| **Auth** | `auth.stackbilt.dev` | Authentication service (Better Auth + D1, OAuth, SSO) — service binding from Stackbilder |
| **img-forge** | `imgforge.stackbilt.dev` | Multi-provider image generation gateway — service binding from Stackbilder |
| **MCP gateway** | `mcp.stackbilt.dev/mcp` | OAuth-authenticated MCP Worker that proxies to [TarotScript](/tarotscript) / [img-forge](/img-forge) / Engine / Deployer. Sibling consumer of the platform's product workers (see [MCP Gateway](/mcp)) |
| **Trust verifier** | `trust.stackbilder.com/evidence/:hash` | Public Evidence Engine receipt verifier (anti-probe semantics) |

## How They Fit Together

```
                                      ┌──────────────────────┐
                                      │  AI agent / LM       │
                                      │  (Claude Code, etc.) │
                                      └──────────┬───────────┘
                                                 │  OAuth + MCP
                                                 ▼
                                      ┌──────────────────────┐
                                      │  mcp.stackbilt.dev   │
   ┌─ human ─►─ stackbilder.com ──┐   │   (MCP gateway)      │
   │              (web UI + API)  │   └──────────┬───────────┘
   │                              │              │
   │                              ▼              ▼
   │                     ┌─────────────────────────────────────┐
   │                     │  Backend product Workers            │
   │                     │  ─ tarotscript-worker (scaffold)    │
   │                     │  ─ img-forge-mcp                    │
   │                     │  ─ stackbilt-engine (architecture)  │
   │                     │  ─ stackbilt-deployer (CF deploy)   │
   │                     │  ─ edge-auth (entitlements + quota) │
   │                     └─────────────────────────────────────┘
   │
   └─ CLI ─►─ Charter (charter blast / surface) ──► same backends via API
```

A single user prompt — "build me an X" — flows through whichever consumer is closest:

```
IDEA
  │
  ▼
runFullFlowAsync(idea)              ← invoked from web UI, MCP tool, or REST
  → PRODUCT → UX → RISK → ARCHITECT → TDD → SPRINT
       │
       └── inline governance: blessed-pattern enforcement,
           red-team review, ADR persistence (Pro/Team tiers)
  │
  ▼
getFlowScaffold(flowId) → deployable project
  │
  ▼
Charter: validate + drift → commit and stack compliance
  │
  ▼
SHIPPED (governed)
```

<!-- DOCSYNC:BEGIN:charter-oss-ecosystem -->
## Charter: Local Enforcement + ADF Context Compiler

Charter runs in your terminal and CI pipeline. It validates commit trailers, scores drift against your blessed stack, and blocks merges on violations. Zero SaaS dependency - all checks are deterministic and local.

Charter also ships **ADF (Attention-Directed Format)** - a modular, AST-backed context system that replaces monolithic `.cursorrules` and `claude.md` files with compiled, trigger-routed `.ai/` modules. ADF treats LLM context as a compiled language: emoji-decorated semantic keys, typed patch operations, manifest-driven progressive disclosure, and metric ceilings with CI evidence gating.

```bash
npm install --save-dev @stackbilt/cli
npx charter bootstrap --preset fullstack --ci github --yes
npx charter adf init    # scaffold .ai/ context directory
```

**Governance commands:** `bootstrap`, `validate`, `drift`, `audit`, `classify`, `hook install`, `score`, `serve`, `context-refresh`.
**ADF commands:** `adf init`, `adf fmt`, `adf patch`, `adf create`, `adf bundle`, `adf sync`, `adf evidence`, `adf migrate`, `adf metrics`.

See the [CLI Reference](/cli-reference) for full flag and option documentation, or the [Charter Kit guide](/getting-started) for quickstart and conceptual overview.

For quantitative analysis of ADF's impact on autonomous system architecture, see the [Context-as-Code white paper](https://github.com/Stackbilt-dev/charter/blob/main/papers/context-as-code-v1.1.md).
<!-- DOCSYNC:END:charter-oss-ecosystem -->

## Stackbilder: Architecture + Scaffold + Trust

The 6-mode pipeline (PRODUCT → UX → RISK → ARCHITECT → TDD → SPRINT) produces structured artifacts with cross-referenced IDs. After completion, the scaffold engine generates a deployable Cloudflare Workers project. On Pro/Team, additional capabilities run alongside the scaffold pipeline:

- **Evidence Engine** — content E-E-A-T validation and tamper-evident receipts (`stackbilder.com/api/v1/evidence/*`, see [API Reference](/api-reference#evidence-engine))
- **Worker Observability** — hosted telemetry ingest + dashboard
- **Consultations** — CISO and CTO advisory flows backed by structured prompts and receipt-bound deliverables
- **Inline governance** — blessed-pattern enforcement, red-team review, ADR persistence (replaces the previously-standalone Compass service binding)

Available via:
- **Browser UI** at [stackbilder.com](https://stackbilder.com) (interactive, human users)
- **REST API** at `stackbilder.com/api/*` (direct HTTP — Charter CLI, server-to-server, CI; see [API Reference](/api-reference))
- **MCP gateway** at `mcp.stackbilt.dev/mcp` (OAuth-authenticated agent access; routes scaffold/image/deploy tools to the same backend Workers — see [MCP Gateway](/mcp))

See the [Stackbilder Platform](/platform) docs for the full 6-mode pipeline, governance tiers, and scaffold engine details. For security architecture and supply chain controls, see [Security](/security).

### Lightweight Agent Pattern

The recommended agent workflow downloads ~40KB total (down from 300KB+):

```
runFullFlowAsync → getFlowSummary polls → getArtifact per mode → getFlowScaffold
```

### Governance Modes by Plan

| Plan | Max Mode | Behavior |
|------|----------|----------|
| Free | `PASSIVE` | Log only — never blocks |
| Pro | `ADVISORY` | Warn on issues, flow continues |
| Team | `ENFORCED` | Block on FAIL, require remediation |

When governance mode is capped by plan tier, a soft upsell prompt appears in the `governanceState` response.

### Blessed Patterns

The platform maintains a ledger of approved technology patterns. These are injected into the ARCHITECT prompt automatically when governance is enabled. Example:

- Compute: Cloudflare Workers (not AWS Lambda)
- Database: Cloudflare D1 (not PostgreSQL)
- Cache: Cloudflare KV (not Redis)
- Queue: Cloudflare Queues (not SQS)

## Worker Observability: ODD-Driven Monitoring

`worker-observability` is the OSS library ([Apache-2.0, GitHub](https://github.com/Stackbilt-dev/worker-observability)) — not yet published to npm; install from source. The hosted Pro product on stackbilder.com wraps it with D1 storage and a dashboard.

### ODD Pillars (Observability → Debugging → Diagnostics)

| Pillar | Signal | Library class | D1 tables |
|--------|--------|---------------|-----------|
| Observability | Metrics, request counts, health | `MetricsCollector`, `Logger` | `traces`, `metrics` |
| Debugging | Traces, spans, correlated logs | `Tracer`, `Span` | `spans`, `logs` |
| Diagnostics | Alerts, SLI/SLO status | `AlertManager`, `SLIMonitor` | `alert_incidents` |

### Tier Gating

| Feature | Free | Pro ($29/mo) |
|---------|------|-------------|
| Retention | 24h | 30d |
| Workers | 1 | Unlimited |
| Traces + logs | Health status only | Full drilldown |
| SLI/SLO tracking | — | Yes |
| Alert history | — | Yes |

### Integration (3 lines)

> The package is not yet published to npm. Install directly from GitHub:
> ```bash
> npm install github:Stackbilt-dev/worker-observability
> ```

```ts
import { createMonitoring } from '@stackbilt/worker-observability';
const obs = createMonitoring({
  service: 'my-worker',
  version: '1.0.0',
  stackbilt: {
    endpoint: 'https://stackbilder.com/api/observe/ingest',
    token: env.STACKBILT_TOKEN,
  },
});
```

## Governance-First Development

Every significant decision flows through governance before implementation:

1. **Pre-approval** — Stackbilder validates the idea against policy during the PRODUCT/RISK modes
2. **Architecture** — Stackbilder generates a governed blueprint with blessed patterns injected into ARCHITECT
3. **Review** — Inline red-team review runs against the architecture output
4. **Record** — ADRs are persisted to the governance ledger (when `autoPersist: true`)
5. **Scaffold** — Stackbilder generates deployable project files
6. **Commit** — Charter enforces `Governed-By:` trailer compliance at the repo level
7. **Evidence** — Charter validates ADF metric ceilings (`adf evidence --auto-measure --ci`)
8. **CI** — Charter blocks merges on drift violations or metric ceiling breaches

## All Repositories

The complete Stackbilt-dev organization — public and private. For private repos, this page is the SoT for documentation.

### Core Governance

| Repo | Visibility | Package | Docs |
|------|-----------|---------|------|
| [charter](https://github.com/Stackbilt-dev/charter) | Public | `@stackbilt/cli` | [Charter Kit](/getting-started) · [CLI Reference](/cli-reference) |
| [evidence-core](https://github.com/Stackbilt-dev/evidence-core) | Public | `@stackbilt/evidence-core` | [evidence-core](/evidence-core) |
| [audit-chain](https://github.com/Stackbilt-dev/audit-chain) | Public | `@stackbilt/audit-chain` | [audit-chain](/audit-chain) |
| [worker-observability](https://github.com/Stackbilt-dev/worker-observability) | Public | *(install from GitHub)* | [worker-observability](/worker-observability) |

### Agent Infrastructure

| Repo | Visibility | Docs |
|------|-----------|------|
| [aegis-oss](https://github.com/Stackbilt-dev/aegis-oss) | Public | [AEGIS Core](/aegis-core) |
| [mindspring](https://github.com/Stackbilt-dev/mindspring) | Public | [MindSpring](/mindspring) |
| [edgeclaw](https://github.com/Stackbilt-dev/edgeclaw) | Public | [EdgeClaw](/edgeclaw) |
| [cc-taskrunner](https://github.com/Stackbilt-dev/cc-taskrunner) | Public | [cc-taskrunner](/cc-taskrunner) |

### Infrastructure Libraries

| Repo | Visibility | Package | Docs |
|------|-----------|---------|------|
| [llm-providers](https://github.com/Stackbilt-dev/llm-providers) | Public | `@stackbilt/llm-providers` | [llm-providers](/llm-providers) |
| [feature-flags](https://github.com/Stackbilt-dev/feature-flags) | Public | `@stackbilt/feature-flags` | [feature-flags](/feature-flags) |
| [contracts](https://github.com/Stackbilt-dev/contracts) | Public | `@stackbilt/contracts` | [contracts](/contracts) |

### Platform (Private)

| Repo | Visibility | Docs |
|------|-----------|------|
| stackbilt-web | Private | [stackbilt-web](/stackbilt-web) · [Stackbilder Platform](/platform) |
| tarotscript | Private | [TarotScript](/tarotscript) |
| img-forge | Private | [img-forge](/img-forge) |
| stackbilt-mcp-gateway | Private | [MCP Gateway](/mcp) |
| edge-auth | Private | [edge-auth](/edge-auth) |
| codebeast | Private | [CodeBeast](/codebeast) |
| roundtable | Private | [Roundtable](/roundtable) |
| [stackbilt-build](https://github.com/Stackbilt-dev/stackbilt-build) | Public | [stackbilt-build](/stackbilt-build) |
| edgestack-v2 | Private | *(deprecated)* |

### Developer Tools

| Repo | Visibility | Docs |
|------|-----------|------|
| [bildy](https://github.com/Stackbilt-dev/bildy) | Public | [bildy](/bildy) |
| [ai-playbook](https://github.com/Stackbilt-dev/ai-playbook) | Public | [AI Playbook](/ai-playbook) |

### Standalone Apps

| Repo | Visibility | Docs |
|------|-----------|------|
| [social-sentinel](https://github.com/Stackbilt-dev/social-sentinel) | Public | [Social Sentinel](/social-sentinel) |
| [n8n-transpiler](https://github.com/Stackbilt-dev/n8n-transpiler) | Public | [n8n-transpiler](/n8n-transpiler) |
| [equity-scenario-sim](https://github.com/Stackbilt-dev/equity-scenario-sim) | Public | [equity-scenario-sim](/equity-scenario-sim) |

### This Site

| Repo | Visibility | URL |
|------|-----------|-----|
| [docs](https://github.com/Stackbilt-dev/docs) | Public | [docs.stackbilder.com](https://docs.stackbilder.com) |

---

## Authentication

Stackbilder issues two credential types, both accepted at every endpoint:

- **Session cookie** — `better-auth.session_token`, set during OAuth sign-in (GitHub, Google) at [auth.stackbilt.dev](https://auth.stackbilt.dev). Used by the browser UI.
- **API key** — `Authorization: Bearer ea_*`, issued from `/settings`. Used by Charter CLI, server-to-server pipelines, and MCP-style consumers.

API key resolution: `GET /api/account/me` returns the caller's identity (userId, orgId, plan) — useful for tier-aware routing in CI scripts.
