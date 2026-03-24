---
title: "Compass Governance"
description: "Compass MCP-server-backed governance service — 47 tools, tier gating, ledger, patterns, drift scanning, and EdgeStack integration."
section: "platform"
order: 8
color: "#22d3ee"
tag: "08"
---

# Compass Governance

Compass is a full MCP-server-backed governance service running on Cloudflare Workers. It provides institutional memory, blessed pattern enforcement, ADR ledger management, drift scanning, temporal analysis, and LLM-powered advisory capabilities through 47 MCP tools.

**Public endpoint:** `https://compass.stackbilt.dev/mcp`

**Protocol:** MCP 2025-03-26 (Streamable HTTP) + SSE fallback

> **Integration Status: Pending Activation**
>
> Compass is live as a standalone MCP server and can be connected to directly by any MCP client. The EdgeStack flow-pipeline integration (GovernanceClient, quality gating, automatic ADR persistence) is code-complete but not yet active in production — the `CSA_MCP_TOKEN` credential has not been configured. Flows currently run with local-only quality evaluation. All architecture described below is accurate to the codebase and will activate once the credential is set.

## Architecture

Compass runs as an independent Cloudflare Worker (`compass`) with its own data layer. EdgeStack connects via Cloudflare Service Binding (`CSA_SERVICE` bound to `digital-csa`) for zero-latency internal calls, or via external HTTP to `compass.stackbilt.dev/mcp` as fallback.

```
Agent (Claude Code / Desktop)
  │
  └── MCP ──► compass.stackbilt.dev/mcp
                │
                ├── CompassMcpAgentV3 (Durable Object — stateful sessions)
                ├── CompassBrainDO (autonomous action queue, hash-chained audit)
                ├── D1 (compass-db — ledger, patterns, protocols, projects)
                ├── R2 (csa-audit — immutable audit records)
                ├── KV (COMPASS_ACTIONS — action envelopes)
                └── Analytics Engine (MCP_ANALYTICS — tool call observability)

EdgeStack (FlowDO)
  │
  └── Service Binding (CSA_SERVICE → digital-csa)
        │
        └── GovernanceClient ──► Compass MCP tools via JSON-RPC 2.0
```

## MCP Tools by Domain

Compass exposes 47 tools organized across 14 domains. Each tool is tier-gated: free-tier users get read-only access, pro/enterprise users unlock mutations and LLM-powered analysis.

### Context Management

| Tool | Tier | Description |
|------|------|-------------|
| `set_context` | Free | Inject project context (files, decisions, constraints) for the session. Up to 500KB |
| `get_context` | Free | View current session context |
| `get_history` | Free | Retrieve conversation history from this session |
| `clear_session` | Free | Clear conversation history and context |

### Advisory (LLM-Powered)

| Tool | Tier | Description |
|------|------|-------------|
| `brief` | Free | Translate technical content for non-technical stakeholders |
| `governance` | Pro | Check authority against governance exhibits, validate requests, detect boundary violations |
| `strategy` | Pro | Strategic architectural advice, precedent setting for edge cases |
| `drafter` | Pro | Generate ADRs, SOPs, policies in governed voice |
| `red_team` | Pro | Hostile security and architecture review |

### Ledger (ADRs, Policies, SOPs)

| Tool | Tier | Description |
|------|------|-------------|
| `list_ledger_entries` | Free | Query ledger entries with filters |
| `get_ledger_entry` | Free | Get single entry by ID with full content |
| `get_ledger_audit_stats` | Free | Aggregated statistics (counts by type, project, status) |
| `create_ledger_entry` | Pro | Create ADR, policy, SOP, or ruling. Can atomically create linked pattern |
| `update_ledger_entry` | Pro | Update entry status (ACTIVE, SUPERSEDED, ARCHIVED) |
| `batch_persist_records` | Pro | Batch-persist up to 20 ledger entries atomically with per-record validation |

### Blessed Patterns

| Tool | Tier | Description |
|------|------|-------------|
| `list_patterns` | Free | Query blessed patterns with ecosystem + project override resolution |
| `get_patterns_for_architecture` | Free | Retrieve patterns for architecture planning (pre-approved tech stack) |
| `create_pattern` | Pro | Create pattern with category, solution, rationale, and anti-patterns |

### Governance Requests

| Tool | Tier | Description |
|------|------|-------------|
| `list_requests` | Free | List governance requests with status and project filters |
| `submit_request` | Free | Submit formal governance request for triage |
| `detect_resolved` | Free | Detect requests silently completed by matching against recent entries |
| `resolve_request` | Pro | Resolve request with summary and optional linked ledger entry |

### Protocols (RFCs)

| Tool | Tier | Description |
|------|------|-------------|
| `list_protocols` | Free | List protocols/RFCs with search and project filters |
| `create_protocol` | Pro | Create protocol (RFC) with title, description, and content |

### Projects

| Tool | Tier | Description |
|------|------|-------------|
| `list_projects` | Free | List all projects (optionally include inactive) |
| `create_project` | Pro | Create new project with name and description |

### Architect Integration

| Tool | Tier | Description |
|------|------|-------------|
| `validate_architecture` | Pro | Validate blueprint against blessed patterns. Returns PASS/WARN/FAIL with violations |
| `persist_architecture_adr` | Pro | Persist ADR from SPRINT mode into governance ledger with flow traceability |
| `set_integration_mode` | Pro | Toggle governance mode: PASSIVE, ADVISORY, ENFORCED |

### Decision Learning

| Tool | Tier | Description |
|------|------|-------------|
| `find_precedents` | Free | Search past governance decisions with confidence scores |
| `get_decision_review` | Free | Generate decision review for a period (week, month, quarter) |
| `track_outcome` | Pro | Record outcome of a governance decision for learning |

### Temporal Analysis (4D Lens)

| Tool | Tier | Description |
|------|------|-------------|
| `list_temporal_analyses` | Free | List past temporal analyses with filters |
| `get_temporal_analysis` | Free | Get specific temporal analysis by ID |
| `temporal_analysis` | Pro | Apply 4D lens: 1yr/3yr horizons, locked-in futures, invisible debt |

### Change Control

| Tool | Tier | Description |
|------|------|-------------|
| `list_change_classifications` | Free | List past change classifications by class, status, or recommendation |
| `classify_change` | Pro | Classify change as SURFACE/LOCAL/CROSS_CUTTING. Auto-triggers temporal analysis for cross-cutting |

### Experiments

| Tool | Tier | Description |
|------|------|-------------|
| `list_experiments` | Free | List experiments with status and project filters |
| `get_experiment` | Free | Get experiment by ID with full details |
| `propose_experiment` | Pro | Propose experiment with hypothesis and success criteria (sandbox-only scope) |
| `update_experiment` | Pro | Advance lifecycle: PROPOSED, APPROVED, RUNNING, REVIEWING, PROMOTED, REJECTED |
| `review_experiment` | Pro | Analyze results and generate structured change package for promotion |

### Notary and Quality

| Tool | Tier | Description |
|------|------|-------------|
| `get_project_snapshot` | Free | Export governance receipt (ledger, patterns, constraints) for a project |
| `evaluate_artifact_quality` | Pro | Evaluate artifact specificity. Issues NOTARY_STAMP ledger entry on PASS |
| `assess_artifact` | Pro | Unified quality + architecture assessment. Runs evaluation and optional validation in parallel. 64KB artifact limit |

### Drift Scanning

| Tool | Tier | Description |
|------|------|-------------|
| `scan_codebase_compliance` | Pro | Scan file content for state drift against active governance patterns. Returns drift score and violations |

### Flow Context

| Tool | Tier | Description |
|------|------|-------------|
| `get_flow_context` | Free | Per-mode governance context for EdgeStack flows. Deterministic (no LLM). Returns patterns, constraints, ledger summaries filtered per mode. Includes version hash for cache invalidation |

## Tier Gating

Tool access is controlled by plan tier. The gating logic lives in EdgeStack (`compass-tier-config.ts`) and is applied before forwarding calls to Compass.

| Plan | Tool Access | Governance Mode Cap |
|------|-------------|---------------------|
| **Free** | 24 read-only tools (context, ledger reads, pattern reads, project snapshots, precedent search) | PASSIVE |
| **Pro** | All 47 tools (+ 23 pro-only: mutations, LLM advisory, drift scanning, architecture validation) | ADVISORY |
| **Enterprise** | All 47 tools | ENFORCED |

Free-tier users get full read access to governance data. They can browse patterns, query the ledger, search precedents, and submit requests. They cannot create entries, validate architecture, or invoke LLM-powered tools.

## EdgeStack Integration

> **Not yet active.** The GovernanceClient is fully implemented but disabled in production — `CSA_MCP_TOKEN` is not set, so all governance calls return early without contacting Compass. Flows complete using local-only quality evaluation. The integration below describes the designed behavior that will activate once the credential is configured.

EdgeStack calls Compass tools through the `GovernanceClient` class, which handles transport selection, retry logic, circuit breaking, and session management.

### Service Binding

In production, EdgeStack connects via Cloudflare Service Binding for zero-network-hop calls:

```toml
# Edgestack-Architech/wrangler.toml (production)
[[env.production.services]]
binding = "CSA_SERVICE"
service = "digital-csa"
```

The binding name is `CSA_SERVICE`. The service name is `digital-csa` (historical name, predates the Compass rebrand).

### Transport Selection

The `GovernanceClient` supports three transport modes, configurable via `CSA_TRANSPORT`:

| Mode | Behavior |
|------|----------|
| `external_http` | Always use `https://compass.stackbilt.dev/mcp` |
| `service_binding` | Always use the `CSA_SERVICE` binding (falls back to HTTP if binding unavailable) |
| `auto` | Canary-based: routes a configurable percentage (`CSA_CANARY_PERCENT`) through the service binding, remainder through HTTP |

Production currently runs at `CSA_CANARY_PERCENT = 100` (all traffic routed through the service binding).

### What EdgeStack Calls

During a flow execution, the `GovernanceClient` calls these Compass MCP tools:

```
Before ARCHITECT mode:
  get_flow_context(projectId, modes, categories)   → patterns, constraints, ledger summaries
  get_patterns_for_architecture(projectId)          → blessed stack patterns

After ARCHITECT mode:
  validate_architecture(blueprint, projectId)       → PASS / WARN / FAIL

After each mode:
  assess_artifact(artifact, mode, projectId)        → quality score + notary stamp
  evaluate_artifact_quality(artifact, projectId)     → structured quality feedback

After SPRINT mode:
  persist_architecture_adr(adrs, flowId, projectId) → ledger writes
  batch_persist_records(entries)                     → bulk ADR persistence
```

### Circuit Breaking

The `GovernanceClient` includes per-flow and per-mode call budgets. If Compass is unresponsive or returning errors, the circuit opens and all subsequent calls in that flow return gracefully without blocking the pipeline.

| Config | Default | Purpose |
|--------|---------|---------|
| `CSA_TIMEOUT_MS` | 10,000 | Per-call timeout |
| `CSA_RETRY_MAX_ATTEMPTS` | 3 | Max retries per tool call |
| `CSA_THROTTLE_MAX_INFLIGHT` | 8 | Max concurrent in-flight calls |

## Infrastructure

Compass runs on Cloudflare's edge with a full persistence stack:

| Resource | Binding | Purpose |
|----------|---------|---------|
| D1 Database | `DB` (`compass-db`) | Ledger entries, patterns, protocols, projects, temporal analyses, experiments, change classifications, decision learning |
| R2 Bucket | `COMPASS_AUDIT` (`csa-audit`) | Immutable append-only audit records |
| KV Namespace | `COMPASS_ACTIONS` | Agent action envelopes and status (ADR-207) |
| Durable Object | `CompassMcpAgentV3` | Stateful MCP sessions (SQLite-backed) |
| Durable Object | `CompassBrainDO` | Autonomous action queue with hash-chained audit |
| Durable Object | `MCPClientDO` | Outbound MCP client connections |
| Analytics Engine | `MCP_ANALYTICS` (`mcp_tool_calls`) | Tool call observability (ADR-022) |

### Cron Triggers

Five scheduled tasks run on UTC cron triggers:

| Schedule | Task |
|----------|------|
| `0 2 * * *` (2 AM daily) | Audit cleanup (90-day retention) |
| `0 3 * * *` (3 AM daily) | Pattern aggregation (decision learning) |
| `0 4 * * *` (4 AM daily) | Governance heartbeat (pattern drift, staleness, conflicts) |
| `0 5 * * *` (5 AM daily) | Agent reconciliation (stale action cleanup) |
| `0 9 * * 1` (Mon 9 AM) | Weekly decision review |

### Citation System

Compass includes a deterministic citation system for governance responses. All advisory tool outputs reference specific ledger entries, patterns, and protocols by ID. The system operates in three strictness phases:

| Phase | Behavior |
|-------|----------|
| `PERMISSIVE` | Log citation violations |
| `WARN` | Show banners on violations (current default) |
| `STRICT` | Reject responses with invalid citations |

## Client Configuration

### Claude Code / Claude Desktop

```json
{
  "mcpServers": {
    "compass": {
      "url": "https://compass.stackbilt.dev/mcp",
      "transport": { "type": "streamable-http" },
      "headers": {
        "Authorization": "Bearer <YOUR_TOKEN>"
      }
    }
  }
}
```

### Unified Auth

Use a StackBilt access key to get a JWT that works at both StackBilt and Compass:

```bash
curl -X POST https://stackbilt.dev/api/auth/token \
  -H "X-Access-Key: ska_..." \
  -H "Content-Type: application/json" \
  -d '{"expires_in": 3600}'
```

The returned JWT is RS256-signed. Compass verifies it via JWKS at `compass.stackbilt.dev/api/.well-known/jwks.json`.

## Governance Modes

Governance mode determines how violations affect the flow pipeline:

| Mode | Behavior | Plan Cap |
|------|----------|----------|
| `PASSIVE` | Log only -- never blocks | Free |
| `ADVISORY` | Warn on issues, flow continues | Pro |
| `ENFORCED` | Block on FAIL, require remediation | Enterprise |

Pass a governance config when starting a flow to control enforcement:

```typescript
governance: {
  mode: 'ADVISORY',
  projectId: 'my-project',
  autoPersist: true,
  qualityThreshold: 80,
  transport: 'auto',
  transportCanaryPercent: 100
}
```

## Related Docs

- [MCP Integration](/mcp) -- StackBilt MCP server (22 tools for flow execution)
- [Platform](/platform) -- 6-mode pipeline, scaffold engine, plan tiers
- [Ecosystem](/ecosystem) -- How Compass fits into the StackBilt service map
