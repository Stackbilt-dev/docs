---
title: "Ecosystem"
section: "ecosystem"
order: 6
color: "#c084fc"
tag: "06"
---

# Ecosystem

StackBilt is three complementary tools that enforce governance across the full development lifecycle.

## The Three Pieces

| Tool | License | Role |
|------|---------|------|
| **Charter** (`@stackbilt/cli`) | Apache-2.0 (open source) | Local + CI governance runtime |
| **StackBilt Architect** | Commercial | Architecture generation, scaffold engine, structured artifacts |
| **Compass** | Commercial | Governance policy brain, institutional memory, ADR ledger |

Charter is the open-source foundation. StackBilt Architect and Compass are commercial services.

## Service Map

| Service | URL | Purpose |
|---------|-----|---------|
| **StackBilt** | `stackbilt.dev` | Architecture generation, MCP server, scaffold engine |
| **Compass** | `compass.stackbilt.dev` | Governance enforcement, blessed patterns, ADR ledger |
| **Img Forge** | `img-forge-mcp.kurt-543.workers.dev` | AI image generation for documentation |

## How They Fit Together

```
IDEA
  │
  ▼
Compass: governance("Can we build X?")
  │
  ├── REJECTED ──► Stop
  │
  ▼ APPROVED
StackBilt: runFullFlowAsync(idea)
  → PRODUCT → UX → RISK → ARCHITECT → TDD → SPRINT
  │
  ▼
Compass: red_team(architecture) → security review
  │
  ▼
StackBilt: getFlowScaffold(flowId) → deployable project
  │
  ▼
Charter: validate + drift → commit and stack compliance
  │
  ▼
SHIPPED (governed)
```

## Charter: Local Enforcement

Charter runs in your terminal and CI pipeline. It validates commit trailers, scores drift against your blessed stack, and blocks merges on violations. Zero SaaS dependency — all checks are deterministic and local.

```bash
npm install --save-dev @stackbilt/cli
npx charter setup --preset fullstack --ci github --yes
```

Key commands: `charter validate`, `charter drift`, `charter audit`, `charter classify`, `charter hook install`.

## StackBilt Architect: Architecture + Scaffold

The 6-mode pipeline (PRODUCT → UX → RISK → ARCHITECT → TDD → SPRINT) produces structured artifacts with cross-referenced IDs. After completion, the scaffold engine generates a deployable Cloudflare Workers project.

Available via:
- **Browser UI** at [stackbilt.dev](https://stackbilt.dev) (interactive)
- **MCP server** at `stackbilt.dev/mcp` (agent-driven, 19 tools)
- **REST API** at `stackbilt.dev/api/flow/*` (direct HTTP)

### Lightweight Agent Pattern

The recommended agent workflow downloads ~40KB total (down from 300KB+):

```
runFullFlowAsync → getFlowSummary polls → getArtifact per mode → getFlowScaffold
```

## Compass: Policy Brain

Compass is an AI governance agent with institutional memory — a ledger of ADRs, blessed patterns, and constitutional rules. It validates architecture decisions, runs red-team reviews, and drafts formal policy documents.

### Governance Modes by Plan

| Plan | Max Mode | Behavior |
|------|----------|----------|
| Free | `PASSIVE` | Log only — never blocks |
| Pro | `ADVISORY` | Warn on issues, flow continues |
| Enterprise | `ENFORCED` | Block on FAIL, require remediation |

When governance mode is capped by plan tier, a soft upsell prompt appears in the `governanceState` response.

### Blessed Patterns

Compass maintains a ledger of approved technology patterns. These are injected into StackBilt's ARCHITECT prompt automatically when governance is enabled. Example:

- Compute: Cloudflare Workers (not AWS Lambda)
- Database: Cloudflare D1 (not PostgreSQL)
- Cache: Cloudflare KV (not Redis)
- Queue: Cloudflare Queues (not SQS)

### CSA Transport Modes

Communication between StackBilt and Compass supports multiple transports:

| Transport | Description |
|-----------|-------------|
| `external_http` | Public HTTPS MCP endpoint (default) |
| `service_binding` | Internal Worker binding (when configured) |
| `auto` | Canary split between HTTP and binding |

Canary rollout percentage is configurable per-flow or via environment default.

## Governance-First Development

Every significant decision flows through governance before implementation:

1. **Pre-approval** — Compass validates the idea against policy
2. **Architecture** — StackBilt generates a governed blueprint with blessed patterns
3. **Review** — Compass red-teams the architecture output
4. **Record** — ADRs are persisted to the governance ledger (when `autoPersist: true`)
5. **Scaffold** — StackBilt generates deployable project files
6. **Commit** — Charter enforces `Governed-By:` trailer compliance at the repo level
7. **CI** — Charter blocks merges on drift violations

## Authentication Across Services

### Unified Auth (Recommended)

One access key works at both StackBilt and Compass:

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
  "edgestack": { "url": "https://stackbilt.dev/mcp", "token": "EDGESTACK_MCP_TOKEN" },
  "compass": { "url": "https://compass.stackbilt.dev/mcp", "token": "CSA_MCP_TOKEN" },
  "imgforge": { "url": "https://img-forge-mcp.kurt-543.workers.dev/mcp", "token": "IMGFORGE_MCP_TOKEN" }
}
```
