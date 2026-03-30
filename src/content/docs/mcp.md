---
title: "MCP Integration"
description: "Connect AI agents to Stackbilder via Model Context Protocol. Scaffold tools, image generation, and flow management through a unified MCP server."
section: "platform"
order: 5
color: "#22d3ee"
tag: "05"
---

# MCP Integration

Stackbilder exposes scaffold creation, image generation, and flow management as MCP-compliant tools. Connect MCP-compatible agents (Claude Code, Claude Desktop, custom agents) to generate governed codebases and images programmatically.

**Production endpoint:** `https://stackbilder.com/mcp` *(MCP gateway — routes to TarotScript, img-forge, and Stackbilder backends)*

**Protocol versions:** `2024-11-05` (SSE transport) · `2025-03-26` (Streamable HTTP transport)

## Authentication

MCP endpoints require authentication (except `GET /mcp/info`). Three methods, checked in order:

| Method | Header | Notes |
|--------|--------|-------|
| Static token | `Authorization: Bearer <STACKBILT_MCP_TOKEN>` | Admin-level, legacy `MCP_TOKEN` fallback |
| Access key | `Authorization: Bearer ska_...` or `X-Access-Key: ska_...` | Requires `ai:invoke` scope |
| Compass JWT | `Authorization: Bearer eyJ...` | RS256, verified via JWKS |

### Unified Auth (Recommended)

Sign in via OAuth at `stackbilder.com/login` (GitHub or Google). The session cookie authenticates all MCP requests automatically.

For programmatic access, use API keys (`ea_*`, `sb_live_*`) issued through edge-auth.

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
      "url": "https://stackbilder.com/mcp",
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
      "url": "https://stackbilder.com/mcp",
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
  new URL("https://stackbilder.com/mcp"),
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

## Governance

Governance output (threat analysis, ADRs, test plans) is generated automatically as part of the scaffold process — not via separate governance tools. The `.ai/` directory ships with every scaffold created through `scaffold_create` or the flow tools.

For Team plans, shared governance policies can be configured via the settings page at `stackbilder.com/settings`.

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
