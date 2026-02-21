---
title: "API Reference"
section: "platform"
order: 7
color: "#c084fc"
tag: "07"
---

# API Reference

Complete reference for the StackBilt EdgeStack Architect API.

## Authentication

All API endpoints require authentication via one of:

| Method | Header | Format |
|--------|--------|--------|
| MCP Token | `Authorization` | `Bearer <STACKBILT_MCP_TOKEN>` |
| Access Key | `X-Access-Key` | `ska_...` |
| Compass JWT | `Authorization` | `Bearer <jwt>` |

`GET /mcp/info` is public and can be used for capability discovery/health checks.

## Flow API

### Create & Run Full Flow

```bash
POST /api/flow/full
```

**Request:**
```json
{
  "input": "Description of your system to architect",
  "config": {
    "sprint": {
      "teamSize": "SMALL_TEAM",
      "sprintDuration": "TWO_WEEKS"
    },
    "governance": {
      "mode": "ADVISORY",
      "projectId": "your-project-id"
    }
  }
}
```

**Response:**
```json
{
  "flowId": "uuid",
  "status": "RUNNING",
  "createdAt": "<ISO8601_TIMESTAMP>"
}
```

### Get Flow Status

```bash
GET /api/flow/:id
```

Returns the full flow state including all mode outputs, structured artifacts, and contradiction reports.

### Get Flow Summary (Lightweight)

```bash
GET /api/flow/:id/summary
```

Returns a compact (<2KB) progress summary with mode statuses, token usage, and artifact counts. Recommended for polling.

### Get Structured Artifact

```bash
GET /api/flow/:id/artifacts/:MODE/structured
```

Returns the typed JSON artifact for a single mode (2-5KB typical). Available modes: `PRODUCT`, `UX`, `RISK`, `ARCHITECT`, `TDD`, `SPRINT`.

### Get Flow Package

```bash
GET /api/flow/:id/package
```

Returns the complete structured project package (100-300KB). Supports `Accept: application/json` or `Accept: text/markdown`.

### Generate Scaffold

```bash
GET /api/flow/:id/scaffold
```

Generates a deployable Cloudflare Workers project from a completed flow. Supports `Accept: application/json` (file manifest) or `Accept: application/zip` (archive).

## MCP Server

The MCP server exposes all Flow API tools for AI agent integration.

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/mcp` | POST | Streamable HTTP transport |
| `/mcp` | GET | SSE connection |
| `/mcp/sse` | GET | Legacy SSE transport |
| `/mcp/info` | GET | Server capabilities (no auth) |

### Recommended Tool Usage

| Need | Use | Avoid |
|------|-----|-------|
| Poll progress | `getFlowSummary` (<2KB) | `getFlowStatus` (100KB+) |
| Read one mode | `getArtifact` (2-5KB) | `getFlowPackage` (300KB) |
| Start a flow | `runFullFlowAsync` | `runFullFlow` (may timeout) |
| Fix a section | `amendArtifact` | `recoverFlow` (reruns entire mode) |

### Client Configuration

```json
{
  "mcpServers": {
    "stackbilt": {
      "url": "https://stackbilt.dev/mcp",
      "transport": { "type": "streamable-http" },
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN"
      }
    }
  }
}
```
