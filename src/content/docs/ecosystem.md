---
title: "Ecosystem"
description: "How Stackbilt tools work together across the development lifecycle"
section: "ecosystem"
order: 1
color: "#c084fc"
tag: "01"
---

# Ecosystem

Stackbilt is a unified developer platform with four complementary systems spanning the full development lifecycle — from stack selection to governed deployment.

## The Four Pieces

| Tool | License | Role |
|------|---------|------|
| **Charter** (`@stackbilt/cli`) | Apache-2.0 (open source) | Local + CI governance runtime, ADF context compiler, CLI gateway to the engine |
| **Stackbilder Engine** | Commercial | Deterministic tech stack builder — 52-primitive catalog, compatibility scoring, scaffold generation. Zero LLM. |
| **Stackbilder Platform** | Commercial | AI-powered architecture generation, 6-mode flow pipeline, structured artifacts |
| **Compass** | Commercial | Governance policy brain, institutional memory, ADR ledger |

Charter is the open-source CLI. The engine, platform, and Compass are commercial services.

## Service Map

| Service | URL / Worker | Purpose |
|---------|-----|---------|
| **Stackbilt Platform** | `stackbilt.dev` | Architecture generation, MCP server, flow pipeline |
| **Stackbilt Engine** | `stackbilt-engine` | Deterministic stack builder (52-card tech deck, compatibility matrix, scaffold templates) |
| **Compass** | `compass.stackbilt.dev/mcp` | Governance enforcement, blessed patterns, ADR ledger *(standalone MCP server live; EdgeStack integration pending activation)* |
| **Auth** | `auth.stackbilt.dev` | Centralized auth — API keys, JWT, SSO, Stripe billing, PAYG credit packs |
| **img-forge** | `imgforge.stackbilt.dev` | AI image generation API (multi-model, MCP + OAuth 2.1) |
| **MCP Gateway** | `mcp.stackbilt.dev/mcp` | Unified OAuth-authenticated MCP endpoint — routes tool calls to TarotScript, img-forge, and Stackbilder backends with scaffold pipeline tools |
| **AEGIS** | `aegis.stackbilt.dev` | Persistent cognitive agent — memory, goals, task pipeline, dreaming cycle |

## How They Fit Together

```
IDEA
  │
  ▼
Engine: build(description) → deterministic stack selection (zero LLM)
  │  52-primitive catalog, compatibility scoring, scaffold template
  │
  ▼
Compass: governance("Can we build X?")
  │
  ├── REJECTED ──► Stop
  │
  ▼ APPROVED
Platform: runFullFlowAsync(idea + engine stack)
  → PRODUCT → UX → RISK → ARCHITECT → TDD → SPRINT
  │
  ▼
Compass: red_team(architecture) → security review
  │
  ▼
Platform: getFlowScaffold(flowId) → deployable project
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
npx charter setup --preset fullstack --ci github --yes
npx charter adf init    # scaffold .ai/ context directory
```

**Governance commands:** `validate`, `drift`, `audit`, `classify`, `hook install`.
**ADF commands:** `adf init`, `adf fmt`, `adf patch`, `adf bundle`, `adf sync`, `adf evidence`.
**Engine commands:** `login`, `architect`, `scaffold` — generate and write tech stacks via the Stackbilder Engine.

For quantitative analysis of ADF's impact on autonomous system architecture, see the [Context-as-Code white paper](https://github.com/Stackbilt-dev/charter/blob/main/papers/context-as-code-v1.1.md).
<!-- DOCSYNC:END:charter-oss-ecosystem -->

## Stackbilder: Architecture + Scaffold

The 6-mode pipeline (PRODUCT → UX → RISK → ARCHITECT → TDD → SPRINT) produces structured artifacts with cross-referenced IDs. After completion, the scaffold engine generates a deployable Cloudflare Workers project.

Available via:
- **Browser UI** at [stackbilt.dev](https://stackbilt.dev) (interactive)
- **MCP server** at `stackbilt.dev/mcp` (agent-driven, 22 native tools + up to 54 Compass governance tools, tier-gated)
- **REST API** at `stackbilt.dev/api/flow/*` (direct HTTP)

### Lightweight Agent Pattern

The recommended agent workflow downloads ~40KB total (down from 300KB+):

```
runFullFlowAsync → getFlowSummary polls → getArtifact per mode → getFlowScaffold
```

## Compass: Policy Brain

For current Compass routes, auth endpoints, and MCP integration surfaces, see [Compass Governance API](/compass-governance-api).

Compass is an AI governance agent with institutional memory — a ledger of ADRs, blessed patterns, and constitutional rules. It validates architecture decisions, runs red-team reviews, and drafts formal policy documents.

### Governance Modes by Plan

| Plan | Max Mode | Behavior |
|------|----------|----------|
| Free | `PASSIVE` | Log only — never blocks |
| Pro | `ADVISORY` | Warn on issues, flow continues |
| Enterprise | `ENFORCED` | Block on FAIL, require remediation |

When governance mode is capped by plan tier, a soft upsell prompt appears in the `governanceState` response.

### Blessed Patterns

Compass maintains a ledger of approved technology patterns. These are injected into Stackbilder's ARCHITECT prompt automatically when governance is enabled. Example:

- Compute: Cloudflare Workers (not AWS Lambda)
- Database: Cloudflare D1 (not PostgreSQL)
- Cache: Cloudflare KV (not Redis)
- Queue: Cloudflare Queues (not SQS)

### CSA Transport Modes

Communication between Stackbilder and Compass supports multiple transports:

| Transport | Description |
|-----------|-------------|
| `external_http` | Public HTTPS MCP endpoint |
| `service_binding` | Internal Worker binding (when configured) |
| `auto` | Canary split between HTTP and binding based on `CSA_CANARY_PERCENT` |

**Current production state:** `CSA_TRANSPORT = "auto"` with `CSA_CANARY_PERCENT = "100"`. Because the `CSA_SERVICE` binding is configured in production, 100% of requests route to the internal service binding first. If the binding fails, the client automatically falls back to `external_http`. Canary percentage is configurable per-flow or via environment default.

## MCP Gateway

The MCP Gateway (`mcp.stackbilt.dev/mcp`) is a unified OAuth-authenticated entry point for agent clients. A single connection routes tool calls to multiple backend product workers via Cloudflare Service Bindings.

| Backend | Tool Prefix | Tools |
|---------|-------------|-------|
| **TarotScript** | `scaffold_*` | `scaffold_create`, `scaffold_classify`, `scaffold_publish`, `scaffold_deploy`, `scaffold_import`, `scaffold_status` |
| **img-forge** | `image_*` | `image_generate`, `image_list_models`, `image_check_job` |
| **Stackbilder** | `flow_*` | `flow_create`, `flow_status`, `flow_summary`, `flow_quality`, `flow_governance`, `flow_advance`, `flow_recover` |

Authentication is OAuth 2.1 with PKCE (GitHub SSO, Google SSO, or email/password). Every tool declares a risk level (`READ_ONLY`, `LOCAL_MUTATION`, `EXTERNAL_MUTATION`) per the Security Constitution. Structured audit logging with secret redaction ships to a Cloudflare Queue.

### Scaffold Pipeline (E2E)

The TarotScript scaffold pipeline is the primary creation path — zero LLM for file generation, ~20ms for structure, ~2s with oracle prose:

```
scaffold_create → structured facts + deployable project files
  → scaffold_publish → GitHub repo with atomic initial commit
  → git clone → npm install → npx wrangler deploy → live Worker
```

## Governance-First Development

Every significant decision flows through governance before implementation:

1. **Pre-approval** — Compass validates the idea against policy
2. **Architecture** — Stackbilder generates a governed blueprint with blessed patterns
3. **Review** — Compass red-teams the architecture output
4. **Record** — ADRs are persisted to the governance ledger (when `autoPersist: true`)
5. **Scaffold** — Stackbilder generates deployable project files
6. **Commit** — Charter enforces `Governed-By:` trailer compliance at the repo level
7. **Evidence** — Charter validates ADF metric ceilings (`adf evidence --auto-measure --ci`)
8. **CI** — Charter blocks merges on drift violations or metric ceiling breaches

## Authentication Across Services

### Unified Auth (Recommended)

One access key works at both Stackbilder and Compass:

```bash
# Exchange ska_ key for a JWT
curl -X POST https://stackbilt.dev/api/auth/token \
  -H "X-Access-Key: ska_..." \
  -d '{"expires_in": 3600}'
# Use the returned JWT at either service
```

### Service-to-Service

For automated pipelines, each service has its own token:

```json
{
  "stackbilder": { "url": "https://stackbilt.dev/mcp", "token": "STACKBILDER_MCP_TOKEN" },
  "compass": { "url": "https://stackbilt.dev/mcp", "transport": "service_binding", "token": "CSA_MCP_TOKEN" },
  "imgforge": { "url": "https://imgforge.stackbilt.dev/mcp", "token": "IMGFORGE_MCP_TOKEN" },
  "gateway": { "url": "https://mcp.stackbilt.dev/mcp", "note": "Unified OAuth endpoint — routes to all backends above" }
}
```
