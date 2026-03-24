---
title: "MCP Integration"
description: "Connect AI agents to StackBilt and Compass via Model Context Protocol. 22 native tools plus up to 47 Compass governance tools proxied through a unified MCP server."
section: "platform"
order: 5
color: "#22d3ee"
tag: "05"
---

# MCP Integration

StackBilt exposes its 6-mode architecture workflow as an MCP-compliant remote server. Connect MCP-compatible agents (Claude Code, Claude Desktop, custom agents) to run architecture flows programmatically. The server provides 22 native tools for flow and artifact management, and proxies up to 47 additional Compass governance tools — tier-gated based on your plan.

> **Note:** Compass governance tool proxying is implemented but pending activation. The 22 native tools are fully operational. See [Compass Governance](/compass-governance-api) for integration status.

**Production endpoint:** `https://stackbilt.dev/mcp`

**Protocol versions:** `2024-11-05` (SSE transport) · `2025-03-26` (Streamable HTTP transport)

## Authentication

MCP endpoints require authentication (except `GET /mcp/info`). Three methods, checked in order:

| Method | Header | Notes |
|--------|--------|-------|
| Static token | `Authorization: Bearer <STACKBILT_MCP_TOKEN>` | Admin-level, legacy `MCP_TOKEN` fallback |
| Access key | `Authorization: Bearer ska_...` or `X-Access-Key: ska_...` | Requires `ai:invoke` scope |
| Compass JWT | `Authorization: Bearer eyJ...` | RS256, verified via JWKS |

### Unified Auth (Recommended)

Exchange an access key for a JWT that works at both StackBilt and Compass:

```bash
curl -X POST https://stackbilt.dev/api/auth/token \
  -H "X-Access-Key: ska_..." \
  -H "Content-Type: application/json" \
  -d '{"expires_in": 3600}'
# Returns: { "access_token": "eyJ...", "token_type": "Bearer", "expires_in": 3600 }
```

One key, both services.

## Transport Options

| Transport | Endpoint | Method | Use Case |
|-----------|----------|--------|----------|
| **Streamable HTTP** | `/mcp` | POST | Modern clients, single request/response |
| **SSE Stream** | `/mcp` | GET | Server-pushed events, session-based |
| **Legacy SSE** | `/mcp/sse` | GET | Older 2024-11-05 clients |
| **Legacy Messages** | `/mcp/messages` | POST | POST endpoint for legacy SSE |
| **Server Info** | `/mcp/info` | GET | Capabilities discovery (no auth) |

### Session Management

For Streamable HTTP, sessions use the `Mcp-Session-Id` header:

1. First `initialize` request returns a session ID
2. Include `Mcp-Session-Id` in subsequent requests
3. `DELETE /mcp` with session ID to terminate

## Client Configuration

### Claude Code / Claude Desktop (Streamable HTTP)

```json
{
  "mcpServers": {
    "stackbilt": {
      "url": "https://stackbilt.dev/mcp",
      "transport": { "type": "streamable-http" },
      "headers": {
        "Authorization": "Bearer <YOUR_MCP_TOKEN>"
      }
    }
  }
}
```

### Legacy SSE Fallback

```json
{
  "mcpServers": {
    "stackbilt": {
      "type": "sse",
      "url": "https://stackbilt.dev/mcp",
      "headers": {
        "Authorization": "Bearer <YOUR_MCP_TOKEN>"
      }
    }
  }
}
```

### Custom MCP Client (Node.js)

```typescript
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";

const transport = new SSEClientTransport(
  new URL("https://stackbilt.dev/mcp"),
  {
    requestInit: {
      headers: { "Authorization": "Bearer <YOUR_MCP_TOKEN>" }
    }
  }
);

const client = new Client({ name: "my-agent", version: "1.0.0" });
await client.connect(transport);

const tools = await client.listTools();
const result = await client.callTool("runFullFlowAsync", {
  input: "Build a task management app with team collaboration"
});
```

## Native Tools (22)

### Flow Execution

| Tool | Description |
|------|-------------|
| `runFullFlow` | Execute full 6-mode pipeline (PRODUCT → SPRINT). May timeout on long flows. |
| `runFullFlowAsync` | Fire-and-forget full flow. Returns immediately with `flowId`. **Recommended.** |
| `startFullFlow` | Create flow without executing. Advance modes manually with `advanceFlowAsync`. |
| `advanceFlowAsync` | Run next pending mode asynchronously. Returns immediately. |
| `runMode` | Execute a single mode (e.g., just ARCHITECT). |
| `cancelFlow` | Cancel a running flow. Sets status to FAILED. |

### Flow Monitoring

| Tool | Description |
|------|-------------|
| `getFlowSummary` | Lightweight progress check (<2KB). Token usage, mode statuses, quality. **Use for polling.** |
| `getFlowStatus` | Full flow state (100KB+). Use only when you need everything. |
| `getFlowLogs` | Execution timeline with timestamps per mode. |
| `getRunQuality` | Concise quality checks: grounding, state safety, artifact completeness. |

### Artifact Retrieval

| Tool | Description |
|------|-------------|
| `getArtifact` | Structured JSON for one mode (2-5KB). **Preferred over getFlowPackage.** |
| `getFlowPackage` | Complete artifact package (100-300KB). All modes, JSON or Markdown. |
| `exportModeArtifact` | Export metadata and artifact ref handle for one mode. |
| `getArtifactContent` | Chunked prose content with cursor pagination. |
| `getFlowCodegenDraft` | `project.json` draft for codegen engine. |
| `getFlowScaffold` | Deployable Workers project (ZIP or JSON). Includes `scaffoldHints` + `nextSteps`. |

### Recovery & Governance

| Tool | Description |
|------|-------------|
| `resumeFlow` | Resume a failed flow from where it stopped. |
| `recoverFlow` | Rerun failed mode + recompute downstream. |
| `amendArtifact` | Fix specific sections by ID (70-80% fewer tokens than recoverFlow). |
| `invalidateCache` | Clear cached mode artifacts so next run regenerates. |
| `getGovernanceStatus` | Governance validation results, blessed patterns, persisted ADR IDs. |
| `submitFeedback` | Submit bug reports, feature requests, and flow quality feedback. Params: `message` (string, required), `type` (enum: bug/feature/general/flow-quality), `rating` (number 1-5, optional), `flowId` (string, optional), `mode` (string, optional). |

## Compass Governance Tools (up to 47)

The StackBilt MCP server proxies Compass governance tools through the same endpoint. When an agent calls `tools/list`, the response merges the 22 native tools above with whichever Compass tools the user's plan unlocks. Tool calls to Compass names are forwarded via a service binding -- no separate Compass connection required.

### Tier Gating

| Tier | Compass Tools | Access Level |
|------|---------------|--------------|
| **Free** | 24 tools | Read-only governance: browse ledger entries, patterns, protocols, projects, experiments, and temporal analyses. Submit requests and get advisory briefings. |
| **Pro / Enterprise** | All 47 tools (24 free + 23 pro-only) | Full governance: create and mutate ledger entries, patterns, protocols, and projects. Run LLM-powered governance, strategy, red-teaming, architecture validation, temporal analysis, change classification, experiment lifecycle, artifact quality evaluation, and codebase compliance scanning. |

### Free-Tier Tools (24)

| Category | Tools |
|----------|-------|
| Context | `set_context`, `get_context`, `get_history`, `clear_session` |
| Ledger (read-only) | `list_ledger_entries`, `get_ledger_entry`, `get_ledger_audit_stats` |
| Patterns (read-only) | `list_patterns`, `get_patterns_for_architecture` |
| Requests | `list_requests`, `submit_request`, `detect_resolved` |
| Protocols (read-only) | `list_protocols` |
| Projects (read-only) | `list_projects` |
| Decision Learning (read-only) | `find_precedents`, `get_decision_review` |
| Temporal (read-only) | `list_temporal_analyses`, `get_temporal_analysis` |
| Change Control (read-only) | `list_change_classifications` |
| Experiments (read-only) | `list_experiments`, `get_experiment` |
| Notary (read-only) | `get_project_snapshot` |
| Flow Context (read-only) | `get_flow_context` |
| Advisory | `brief` |

### Pro-Only Tools (23)

| Category | Tools |
|----------|-------|
| Advisory (LLM-powered) | `governance`, `strategy`, `drafter`, `red_team` |
| Ledger (mutations) | `create_ledger_entry`, `update_ledger_entry` |
| Patterns (mutations) | `create_pattern` |
| Requests (mutations) | `resolve_request` |
| Protocols (mutations) | `create_protocol` |
| Projects (mutations) | `create_project` |
| Architect Integration | `validate_architecture`, `persist_architecture_adr`, `set_integration_mode` |
| Temporal Analysis (LLM) | `temporal_analysis` |
| Change Control (LLM) | `classify_change` |
| Experiments (mutations) | `propose_experiment`, `update_experiment`, `review_experiment` |
| Decision Learning (mutations) | `track_outcome` |
| Quality (LLM) | `evaluate_artifact_quality` |
| Artifact Assessment (LLM) | `assess_artifact` |
| Batch Persistence | `batch_persist_records` |
| Compliance | `scan_codebase_compliance` |

### How Proxying Works

The proxy uses the Compass service binding (`CSA_MCP_URL`) to forward tool calls. Authentication is resolved automatically:

> Access-key users: the server exchanges the `ska_` key for a Compass JWT via the Token Broker, caches it, and attaches it to proxied requests.

> Admin/static-token users: the server uses the `CSA_MCP_TOKEN` environment variable directly (exchanging for a JWT if needed).

> JWT users: the existing Compass JWT is used as-is.

Tool calls that target a name not in the 22 native tools are routed to Compass if the user's tier permits. If the tool is not allowed for the tier, the server returns a standard `-32602` (invalid params) error.

## Recommended Agent Workflow

The lightweight tools enable a minimal-overhead pattern:

```
runFullFlowAsync(input)          →  ~200 bytes
  ↓
getFlowSummary(flowId) × N      →  <2KB per poll (every 10s)
  ↓
getArtifact(flowId, "PRODUCT")   →  2-5KB
getArtifact(flowId, "ARCHITECT") →  2-5KB
getArtifact(flowId, "SPRINT")    →  2-5KB
  ↓
getFlowScaffold(flowId, "json")  →  file manifest + nextSteps
  ↓
Write files to disk, deploy
```

**Total: ~10 tool calls, ~40KB downloaded.**
Previous workflow: 18+ calls, 300KB+.

### When to Use Each Tool

| Need | Use | Avoid |
|------|-----|-------|
| Start a flow | `runFullFlowAsync` | `runFullFlow` (may timeout) |
| Poll progress | `getFlowSummary` (<2KB) | `getFlowStatus` (100KB+) |
| Read one mode | `getArtifact` (2-5KB) | `getFlowPackage` (300KB) |
| Fix one section | `amendArtifact` | `recoverFlow` (reruns entire mode) |
| Get deployable code | `getFlowScaffold` | Manual file generation |

## Step-by-Step: Advance Modes Manually

For fine-grained control, advance one mode at a time:

```typescript
const { flowId } = await stackbilt.startFullFlow({ input: idea });

for (let i = 0; i < 6; i++) {
  await stackbilt.advanceFlowAsync({ flowId });

  // Poll until mode completes
  while (true) {
    const summary = await stackbilt.getFlowSummary({ flowId });
    const running = summary.modeStatuses?.some((m) => m.status === 'RUNNING');
    if (!running) break;
    await new Promise((r) => setTimeout(r, 1500));
  }
}
```

## Governance Integration

Pass a `governance` config to validate architecture against blessed patterns:

```typescript
governance: {
  mode: 'ENFORCED',          // PASSIVE | ADVISORY | ENFORCED
  projectId: 'my-proj',      // scope to project patterns
  autoPersist: true,          // record ADRs in governance ledger
  persistTags: ['api', 'v2'],
  qualityThreshold: 80,       // 0-100
  transport: 'auto',          // external_http | service_binding | auto
  transportCanaryPercent: 5   // canary rollout percentage
}
```

| Mode | Behavior |
|------|----------|
| `PASSIVE` | Log only — never blocks |
| `ADVISORY` | Warn on issues, flow continues |
| `ENFORCED` | Block on FAIL, require remediation |

Plan-tier caps: free plans are capped at PASSIVE, pro at ADVISORY, enterprise gets full ENFORCED.

### Advanced Governance Sub-configs

Three optional sub-configs extend the base governance object:

**`domainLock`** — Locks domain entities after PRODUCT mode completes, preventing drift in downstream modes.

```typescript
governance: {
  // ...base config...
  domainLock: {
    enabled: true,                        // Enable/disable domain locking
    strictness: 'strict',                 // 'strict' | 'advisory' | 'off'
    noNewEntities: true,                  // Prevent creation of new domain entities
    allowVendors: ['stripe', 'sendgrid'], // Vendor allowlist
    forbidVendors: ['twilio'],            // Vendor blocklist
    requireTerms: ['Order', 'Customer'],  // Domain terms that must appear
    forbidTerms: ['User', 'Account'],     // Domain terms that must not appear
  }
}
```

**`qualityByMode`** — Per-mode quality thresholds. Overrides the top-level `qualityThreshold` for specific execution modes, letting you enforce tighter standards on critical modes.

```typescript
governance: {
  // ...base config...
  qualityByMode: {
    ARCHITECT: 90,
    TDD: 85,
    CODE: 80,
  }
}
```

**`qualityWeighting`** — Hybrid local/CSA weighting for quality evaluation. Controls the balance between local static analysis and Compass governance scoring when computing the final quality score.

```typescript
governance: {
  // ...base config...
  qualityWeighting: {
    local: 0.4,   // Weight given to local analysis (0.0–1.0)
    csa: 0.6,     // Weight given to Compass governance scoring (0.0–1.0)
  }
}
```

All three sub-configs are independent and can be combined freely within a single governance object.

## Error Handling

All errors follow JSON-RPC 2.0 format:

| Code | Meaning |
|------|---------|
| `-32700` | Parse error (invalid JSON) |
| `-32600` | Invalid request |
| `-32601` | Method not found |
| `-32602` | Invalid params (unknown tool) |
| `-32000` | Tool execution failed |

## Best Practices

1. **Use `runFullFlowAsync`** to avoid client-side timeouts
2. **Poll with `getFlowSummary`** every 5-10 seconds (read-only, no write contention)
3. **Retrieve per-mode** with `getArtifact` instead of downloading the full package
4. **Check `usage` fields** in `getFlowSummary` for real-time token cost visibility
5. **Reuse `Mcp-Session-Id`** across requests to maintain context
6. **Cache completed flows** — package data doesn't change after completion
7. Full flows typically complete in **2-5 minutes** depending on input complexity
