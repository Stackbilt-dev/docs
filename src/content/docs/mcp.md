---
title: "MCP Integration"
section: "platform"
order: 5
color: "#22d3ee"
tag: "05"
---

# MCP Integration

StackBilt exposes its 6-mode architecture workflow as an MCP-compliant remote server. Connect MCP-compatible agents (Claude Code, Claude Desktop, custom agents) to run architecture flows programmatically.

**Production endpoint:** `https://stackbilt.dev/mcp`

**Protocol version:** `2024-11-05`

## Authentication

MCP endpoints require Bearer token authentication, except `GET /mcp/info`.

```
Authorization: Bearer <YOUR_MCP_TOKEN>
```

## Claude Code / Claude Desktop Setup

Recommended (streamable HTTP):

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

Legacy fallback (SSE):

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

## Available Tools

| Tool | Description |
|---|---|
| `runFullFlow` | Execute the full 6-mode pipeline (PRODUCT → SPRINT) |
| `startFullFlow` | Create a flow without executing — advance modes manually |
| `advanceFlowAsync` | Advance to next pending mode asynchronously |
| `runMode` | Execute a single mode |
| `getFlowSummary` | Lightweight progress check for polling |
| `getFlowStatus` | Full flow status with full payload |
| `getFlowPackage` | Retrieve all artifacts (JSON or Markdown) |
| `getFlowLogs` | Get execution timeline |
| `resumeFlow` | Resume a paused flow |
| `recoverFlow` | Rerun from a failed mode |
| `getGovernanceStatus` | Governance validation results and persisted ADR IDs |

## Example: Run a Full Flow

```typescript
const result = await stackbilt.runFullFlow({
  input: 'Build a real-time collaboration platform for design teams',
  teamSize: 'SMALL_TEAM',
  sprintDuration: 'TWO_WEEKS',
  governance: {
    mode: 'ADVISORY',
    autoPersist: true,
    persistTags: ['collab', 'realtime']
  }
});

const pkg = await stackbilt.getFlowPackage({
  flowId: result.flowId,
  format: 'json'
});
```

## Example: Advance Modes One at a Time

For long flows, advance one mode, then poll until completion before advancing again:

```typescript
const { flowId } = await stackbilt.startFullFlow({ input: idea });

for (let i = 0; i < 6; i++) {
  await stackbilt.advanceFlowAsync({ flowId });

  // Poll lightweight summary until no mode is RUNNING
  while (true) {
    const summary = await stackbilt.getFlowSummary({ flowId });
    const running = summary.modeStatuses?.some((m) => m.status === 'RUNNING');
    if (!running) break;
    await new Promise((r) => setTimeout(r, 1500));
  }
}
```

## Governance Modes

Pass a `governance` config to validate architecture against your blessed patterns:

```typescript
governance: {
  mode: 'ENFORCED',      // PASSIVE | ADVISORY | ENFORCED
  projectId: 'my-proj',  // scope to project patterns
  autoPersist: true,     // record ADRs in governance ledger
  qualityThreshold: 85   // 0-100
}
```
