---
title: "API Reference"
section: "platform"
order: 7
color: "#c084fc"
tag: "07"
---

# API Reference

Complete reference for the StackBilt EdgeStack Architect API.

**Base URL:** `https://stackbilt.dev`

Flows created on one environment do not exist on another (separate Durable Objects).

## Authentication

All API endpoints require authentication via one of:

| Method | Header | Format |
|--------|--------|--------|
| MCP Token | `Authorization` | `Bearer <STACKBILT_MCP_TOKEN>` |
| Access Key | `X-Access-Key` | `ska_...` |
| Compass JWT | `Authorization` | `Bearer <jwt>` (RS256) |

`GET /mcp/info` is public (capability discovery / health check).

### Token Exchange

Exchange an access key for a Compass JWT that works at both StackBilt and Compass:

```bash
POST /api/auth/token
X-Access-Key: ska_...
Content-Type: application/json

{ "expires_in": 3600 }
```

Response:
```json
{ "access_token": "eyJ...", "token_type": "Bearer", "expires_in": 3600 }
```

## Flow API

### Create & Run Full Flow

```
POST /api/flow/full
```

Kickoff is asynchronous — returns `flowId` immediately. Poll `GET /api/flow/:id` for progress, or use the `getFlowSummary` MCP tool for a lightweight summary.

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
      "projectId": "your-project-id",
      "transport": "auto",
      "qualityThreshold": 80
    }
  }
}
```

**Response:**
```json
{
  "flowId": "uuid",
  "status": "RUNNING",
  "createdAt": "<ISO8601>"
}
```

### Get Flow Status (Full)

```
GET /api/flow/:id
```

Returns the complete flow state (100KB+) including all mode outputs, structured artifacts, and contradiction reports. **For lightweight polling, use the `getFlowSummary` MCP tool instead.**

### Get Flow Summary (MCP Only)

**MCP-only operation.** This summary is not available as a direct REST call. Use the `getFlowSummary` MCP tool instead. The REST equivalent for full flow state is `GET /api/flow/:id`.

The `getFlowSummary` tool returns a compact (<2KB) progress snapshot. Recommended for polling from AI agents.

```json
{
  "flowId": "abc-123",
  "status": "IN_PROGRESS",
  "currentMode": "ARCHITECT",
  "elapsed": "2m34s",
  "modes": {
    "PRODUCT": { "status": "COMPLETED", "duration": "28s", "qualityPass": true },
    "UX": { "status": "COMPLETED", "duration": "31s", "qualityPass": true },
    "ARCHITECT": { "status": "RUNNING", "duration": null, "qualityPass": false }
  },
  "contradictions": { "critical": 0, "high": 0, "coverageGaps": 0, "missingItems": 2 },
  "artifactCounts": { "requirements": 18, "risks": 5, "components": 0, "adrs": 0 },
  "usage": { "totalInputTokens": 12450, "totalOutputTokens": 8320 }
}
```

### Get Artifact (MCP Only)

**MCP-only operation.** The `/artifacts/:MODE/structured` path does not exist as a REST route. Use the `getArtifact` MCP tool to retrieve a typed JSON artifact for a single mode.

The actual REST artifact routes are:

```
GET /api/flow/:id/artifacts/:MODE
```

Returns artifact metadata for a mode. Modes: `PRODUCT`, `UX`, `RISK`, `ARCHITECT`, `TDD`, `SPRINT`.

```
GET /api/flow/:id/artifacts/:MODE/content
```

Returns chunked artifact content for a mode.

The `getArtifact` MCP tool combines these into a single typed response (2-5KB):

```json
{
  "schemaVersion": "2.0.0",
  "mode": "PRODUCT",
  "requirements": [
    { "id": "REQ-001", "text": "User authentication via JWT", "priority": "MUST", "category": "functional" }
  ],
  "entities": ["User", "Payment"],
  "slas": [{ "id": "SLA-001", "metric": "uptime", "target": "99.9%", "window": "monthly" }],
  "constraints": [{ "id": "CON-001", "type": "security", "text": "All data encrypted at rest" }],
  "confidence": { "overall": 85, "missing": ["pricing model"] }
}
```

Each mode produces sequential, referenceable IDs: `REQ-001`, `SLA-001`, `RISK-001`, `COMP-001`, `TS-001`, `ADR-001`. Downstream modes cross-reference these IDs.

### Get Flow Package

```
GET /api/flow/:id/package
```

Returns the complete structured project package (100-300KB). Supports `Accept: application/json` or `Accept: text/markdown`.

### Get Flow Quality

```
GET /api/flow/:id/quality
```

Returns concise quality checks: `grounding_pass`, `state_safety_pass`, `artifact_completeness_pass`, `overall_pass`.

### Run Single Mode

```
POST /api/flow/:MODE
```

Runs one mode against a flow context. If `flowId` is omitted, creates a new flow. Modes: `PRODUCT`, `UX`, `RISK`, `ARCHITECT`, `TDD`, `SPRINT`.

### Flow Lifecycle

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/flow/:id/advance` | POST | Advance to next pending mode |
| `/api/flow/:id/resume` | POST | Resume from last failed step |
| `/api/flow/:id/recover` | POST | Rerun failed mode + recompute downstream |
| `/api/flow/:id/cancel` | POST | Cancel a running flow |
| `/api/flow/:id/logs` | GET | Execution timeline with timestamps |
| `/api/flow/:id/codegen` | GET | `project.json` draft for codegen engine |

## Scaffold Engine

```
GET /api/flow/:id/scaffold
```

Generates a deployable Cloudflare Workers project from a completed flow.

**Prerequisites:** ARCHITECT mode must be completed.

**Content negotiation:**
- `Accept: application/json` — file manifest with `scaffoldHints` + `nextSteps`
- `Accept: application/zip` — downloadable ZIP archive

**JSON Response:**
```json
{
  "flowId": "uuid",
  "files": [
    { "path": "wrangler.toml", "content": "..." },
    { "path": "package.json", "content": "..." },
    { "path": "routes/api-gateway.ts", "content": "..." },
    { "path": "worker/event-queue.ts", "content": "..." }
  ],
  "scaffoldHints": {
    "templateType": "workers-crud-api",
    "primaryFramework": "Hono",
    "hasQueueHandlers": true,
    "hasScheduledJobs": false,
    "hasDurableObjects": false,
    "confidence": 85
  },
  "nextSteps": [
    "mkdir my-project && write each file",
    "cd my-project && npm install",
    "npx wrangler d1 create my-db",
    "npx wrangler dev",
    "npx wrangler deploy"
  ]
}
```

**Template Types:**

| Type | Description |
|------|-------------|
| `workers-crud-api` | Standard REST API with Hono routes |
| `workers-queue-consumer` | Queue-driven batch processing |
| `workers-durable-object` | Stateful Durable Object service |
| `workers-websocket` | WebSocket real-time service |
| `workers-cron` | Scheduled/cron-driven worker |
| `pages-static` | Static frontend (no Worker routes) |

**Category-aware file generation:**
- `compute`/`data`/`integration` → `routes/*.ts` (CRUD stubs)
- `async` → `worker/*-queue.ts` (queue consumer handlers)
- `security` → `worker/middleware/*.ts` (auth middleware)
- `frontend` → skipped

**Rate limiting:** 3 scaffolds per flow per 24 hours. Returns `429` if exceeded.

**Generated files:** `wrangler.toml`, `package.json`, `tsconfig.json`, `worker/index.ts`, `schema.sql` (if D1), `routes/*.ts`, `worker/*-queue.ts`, `worker/middleware/*.ts`, `README.md`, `.gitignore`, `scripts/deploy.sh`, `.charter/config.json`, `governance.md`

## Structured Artifact Contract (v2)

Each mode emits a machine-readable JSON block using the `:::ARTIFACT_JSON_START:::` delimiter. These are extracted, validated, and stored in `FlowState.structuredArtifacts`.

**Contradiction checker** runs incrementally after each mode (8 cross-mode checks):
- Every `MUST` requirement → component or `reqCoverage` in ARCHITECT
- Every PRODUCT SLA → `slaValidation` entry in TDD
- Every `CRITICAL`/`HIGH` risk → test scenario in TDD
- ARCHITECT must not use `blockedPatterns` from RISK
- Named events must appear across ARCHITECT and TDD
- SPRINT surfaces requirements with no ADR as `undecidedReqs`

## Auth & GitHub Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/auth/me` | GET | Current authenticated identity |
| `/api/auth/token` | POST | Exchange `ska_` key for Compass JWT |
| `/api/auth/better/*` | ALL | Proxies to the dedicated auth-worker service (Better Auth). Supports session management, API key authentication, and OAuth Provider plugin. Replaces the previous GitHub OAuth flow. Specific sub-routes are handled by the auth-worker and include session introspection and token management. |
| `/api/github/repos` | GET/POST | List or create GitHub repos |
| `/api/github/publish-generated` | POST | Server-side codegen + full repo publish |

## Admin Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/admin/access-keys` | POST | Issue new access key |
| `/api/admin/access-keys` | GET | List keys (filter by userId, status) |
| `/api/admin/access-keys/:id` | GET | Inspect one key |
| `/api/admin/access-keys/:id/revoke` | POST | Revoke a key |
| `/api/admin/access-keys/:id/rotate` | POST | Rotate an access key. Generates a new key and revokes the old one. Returns the new key value. |
| `/api/admin/usage/:keyId` | GET | Per-key usage dashboard. Optional `?days=N` query param to filter by time window. Returns usage metrics. |
| `/api/admin/trial/leads` | GET | List trial lead records with associated events. Query params: `limit` (number), `eventsPerLead` (number). |
| `/api/keys/groq/self` | GET/POST/DELETE | Per-user GROQ key management |
| `/api/codegen/locks/release` | POST | Release a codegen lock manually. Used to resolve stuck locks. |
| `/api/codegen/locks/sweep` | POST | Sweep expired codegen locks across all active flows. |
| `/api/codegen/audit/rollup` | POST | Trigger a codegen audit rollup. Aggregates lock and collision metrics. |

## Trial Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/trial/start` | Start a trial session. Accepts `email` in the request body. Creates a 72-hour trial with 2 flow runs. Returns trial session ID and expiry. |
| `GET` | `/api/trial/status` | Check current trial status. Returns remaining runs, expiry timestamp, and whether the trial is active. |
| `POST` | `/api/trial/upgrade-intent` | Log upgrade interest from a trial user. Accepts `email` and optional `plan` preference. |

Trial sessions are stored in LEADS KV. Each trial allows 2 flow runs within a 72-hour window.

## Feedback

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/feedback/submit` | Submit feedback (bug report, feature request, or flow quality feedback). Rate limited to 5 submissions per day per IP. Stores in LEADS KV and sends admin notification via Resend. |

**Request body fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `message` | string | yes | Feedback content |
| `type` | enum | yes | `bug` \| `feature` \| `general` \| `flow-quality` |
| `rating` | number | no | Score from 1–5 |
| `flowId` | string | no | Associated flow ID |
| `mode` | string | no | Associated flow mode |

## Contact

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/contact` | Landing page contact form submission. Accepts `email`, `team`, and `source` fields. Sends notification via Resend. |

## Billing (Stripe)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/billing/checkout` | POST | Create Stripe Checkout session |
| `/api/billing/portal` | GET | Stripe billing portal |
| `/api/webhooks/stripe` | POST | Webhook receiver (signature verified) |

## MCP Server

The MCP server exposes all 21 Flow API tools for AI agent integration. See the [MCP Integration](/mcp) page for full tool documentation.

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/mcp` | POST | Streamable HTTP transport |
| `/mcp` | GET | SSE connection |
| `/mcp/sse` | GET | Legacy SSE transport |
| `/mcp/info` | GET | Server capabilities (no auth) |

## Error Responses

| HTTP Status | Meaning |
|-------------|---------|
| `400` | Invalid request or missing flow state |
| `401` | Missing authentication |
| `403` | Invalid token |
| `404` | Flow or endpoint not found |
| `429` | Rate limit exceeded |
| `500` | Server error |

JSON-RPC errors (MCP):

| Code | Meaning |
|------|---------|
| `-32700` | Parse error |
| `-32600` | Invalid request |
| `-32601` | Method not found |
| `-32602` | Invalid params |
| `-32000` | Tool execution failed |
