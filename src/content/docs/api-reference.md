---
title: "API Reference"
description: "REST API reference for Stackbilder. Flow lifecycle, artifact retrieval, scaffold generation, and authentication endpoints."
section: "platform"
order: 7
color: "#c084fc"
tag: "07"
---

# API Reference

Complete reference for the StackBilt Stackbilder Architect API.

**Base URL:** `https://stackbilt.dev`

Flows created on one environment do not exist on another (separate Durable Objects).

## Authentication

Authentication is endpoint-specific. Most protected endpoints accept one of:

| Method | Header | Format |
|--------|--------|--------|
| MCP Token | `Authorization` | `Bearer <STACKBILT_MCP_TOKEN>` |
| Access Key | `X-Access-Key` | `ska_...` |
| Compass JWT | `Authorization` | `Bearer <jwt>` (RS256) |

`GET /mcp/info` is public (capability discovery / health check).

Public/special-auth exceptions include:

- `POST /api/webhooks/stripe` (Stripe signature-verified webhook)
- `POST /api/trial/start` (public trial bootstrap)
- `GET /api/trial/status` and `POST /api/trial/upgrade-intent` (trial token required, not access key)
- `POST /api/self-serve/access-key` (public self-serve key issuance)
- `POST /api/feedback/submit` and `POST /api/contact`

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
| `/api/self-serve/access-key` | POST | Public self-serve `ska_` key issuance (rate limited, email-based) |
| `/api/github/repos` | GET/POST | List or create GitHub repos |
| `/api/github/publish` | POST | Publish a project to GitHub |
| `/api/github/publish-generated` | POST | Server-side codegen + full repo publish |

## Admin Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/admin/access-keys` | POST | Issue new access key |
| `/api/admin/access-keys` | GET | List keys (filter by userId, status) |
| `/api/admin/access-keys/:id` | GET | Inspect one key |
| `/api/admin/access-keys/:id/link-compass` | POST | Provision/link Compass seat credentials for an existing access key |
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
| `POST` | `/api/trial/start` | Start a trial session. Accepts `email` in the request body. Creates a 72-hour trial with 2 flow runs. Returns a `trialToken`, usage counters, and expiry. |
| `GET` | `/api/trial/status` | Check current trial status. Returns remaining runs, expiry timestamp, and whether the trial is active. |
| `POST` | `/api/trial/upgrade-intent` | Log upgrade intent for the current trial token. Accepts optional `trigger` and `note`. |

`POST /api/trial/start` returns a `trialToken` plus usage counters (`runsAllowed`, `runsUsed`, `runsRemaining`) and `expiresAt`.

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

The MCP server exposes 22 tools for AI agent integration (flow execution/inspection plus related platform operations like feedback and artifact amendment). See the [MCP Integration](/mcp) page for full tool documentation.

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/mcp` | POST | Streamable HTTP transport |
| `/mcp` | GET | SSE connection |
| `/mcp/sse` | GET | Legacy SSE transport |
| `/mcp/info` | GET | Server capabilities (no auth) |

## Engine API (Deterministic)

The StackBilt Engine is a standalone Cloudflare Worker that provides deterministic (zero-LLM) stack selection, scoring, scaffolding, and governance. All responses are computed from a static catalog of technology primitives and rule-based compatibility analysis -- no AI inference calls.

**Base URL:** `https://engine.stackbilt.dev`

**Auth:** Most endpoints are public. Endpoints that return the full `approved` tier catalog require a valid API key via `Authorization: Bearer <key>`. Without auth, results are filtered to the `blessed` tier.

### GET /health

Returns service status, version, catalog size, and the list of available endpoints.

```json
{
  "status": "ok",
  "version": "0.3.0",
  "engine": "tarotscript-deck",
  "catalog": 42,
  "endpoints": ["/build", "/build/variants", "/scaffold", "/score", "/guidance", "/assess", "/catalog", "/health"]
}
```

### GET /catalog

Returns the technology primitives catalog. Supports optional query filters.

| Param | Type | Description |
|-------|------|-------------|
| `category` | string | Filter by category: `Compute`, `Storage`, `Interface`, `Fabric` |
| `tier` | string | Filter by tier: `blessed` or `approved` |

```json
{
  "primitives": [
    {
      "id": 1,
      "name": "Workers",
      "category": "Compute",
      "element": "Edge",
      "maturity": "stable",
      "tier": "blessed",
      "traits": ["serverless", "v8-isolate"],
      "keywords": { "upright": ["fast", "scalable"], "reversed": ["cold-start", "limited-runtime"] },
      "cloudflareNative": true
    }
  ],
  "total": 42
}
```

### POST /build

Generates a deterministic technology stack from a natural-language project description. Parses requirements, selects primitives via spread positions, analyzes compatibility, and produces scaffold files.

**Request:**
```json
{
  "description": "A REST API for managing invoices with Stripe webhooks",
  "constraints": { "needsAuth": true, "needsDatabase": true },
  "tier": "blessed",
  "seed": 12345,
  "skip_auth": false,
  "skip_frontend": true,
  "skip_queue": false,
  "skip_cache": false,
  "pattern": "rest-api",
  "routes": ["/invoices", "/webhooks/stripe"],
  "integrations": ["stripe-webhook"],
  "project_name": "invoice-api"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | string | yes | Natural-language project description |
| `constraints` | object | no | Explicit requirement flags (`needsAuth`, `needsDatabase`, `needsCache`, `needsQueue`, `needsStorage`, `needsCron`, `needsRealtime`, `cloudflareOnly`, `framework`, `database`) |
| `tier` | string | no | `blessed` (default) or `all` |
| `seed` | number | no | Deterministic seed; defaults to hash of description |
| `skip_auth` | boolean | no | Omit auth position from spread |
| `skip_frontend` | boolean | no | Omit framework position from spread |
| `skip_queue` | boolean | no | Omit queue position from spread |
| `skip_cache` | boolean | no | Omit cache position from spread |
| `pattern` | string | no | Integration pattern override (`rest-api`, `discord-bot`, `stripe-webhook`, `github-webhook`, `mcp-server`, `queue-consumer`, `cron-worker`) |
| `routes` | string[] | no | Explicit route list |
| `integrations` | string[] | no | Explicit integration list |
| `project_name` | string | no | Override derived project name |

Skip flags are also auto-detected from the description via NLP (e.g., "backend only" sets `skip_frontend`).

**Response:** Returns a `StackResult` with the selected primitives, compatibility analysis, scaffold files, seed, and receipt hash.

### POST /build/variants

Generates multiple stack variants for the same description, each with a different seed. Returns all variants plus a comparison with a recommendation.

**Request:**
```json
{
  "description": "A queue-driven image processing pipeline",
  "count": 3,
  "tier": "blessed"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | string | yes | Natural-language project description |
| `count` | number | yes | Number of variants (2-10) |
| `constraints` | object | no | Same constraint flags as `/build` |
| `tier` | string | no | `blessed` (default) or `all` |
| `skip_*` | boolean | no | Same skip flags as `/build` |

**Response:**
```json
{
  "variants": [ "...StackResult[]" ],
  "comparison": {
    "bestIndex": 1,
    "averageScore": 0.82,
    "scoreRange": [0.75, 0.91],
    "recommendation": {
      "variantIndex": 1,
      "reason": "Variant 1 scores 0.91 with zero tensions"
    }
  }
}
```

### POST /scaffold

Same request body as `/build`. Returns the stack with scaffold files in a `files[]` array format suitable for the MCP gateway, plus metadata about the generated project.

**Response:**
```json
{
  "files": [
    { "path": "wrangler.toml", "content": "..." },
    { "path": "package.json", "content": "..." },
    { "path": "src/index.ts", "content": "..." }
  ],
  "stack": [
    { "name": "Workers", "position": "runtime", "category": "Compute", "element": "Edge", "orientation": "upright", "traits": ["serverless"] }
  ],
  "compatibility_score": 0.85,
  "seed": 12345,
  "receipt": "sha256:...",
  "project_name": "invoice-api",
  "pattern": "rest-api",
  "routes": ["/invoices"],
  "integrations": ["stripe-webhook"]
}
```

### POST /score

Score an existing technology stack for compatibility. Provide position-name pairs; the engine resolves them against the catalog, runs compatibility analysis, and suggests swaps for any tensions.

**Request:**
```json
{
  "stack": [
    { "position": "runtime", "name": "Workers" },
    { "position": "database", "name": "D1" },
    { "position": "cache", "name": "KV" }
  ],
  "complexity": "standard"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `stack` | array | yes | Array of `{ position, name }` pairs |
| `complexity` | string | yes | `simple`, `standard`, or `complex` |

**Response:** Returns the resolved stack, compatibility pairs with scores, and swap suggestions where tensions exist.

```json
{
  "stack": [ "...DrawnTech[]" ],
  "compatibility": {
    "pairs": [ { "positions": ["runtime", "database"], "techs": ["Workers", "D1"], "relationship": "SYMP", "score": 2, "description": "..." } ],
    "totalScore": 6,
    "normalizedScore": 0.85,
    "dominant": "Edge",
    "tensions": []
  },
  "suggestions": []
}
```

### POST /guidance

Fetch governance guidance for a flow mode. Returns context hints, constraint overrides, and quality thresholds based on blessed architectural patterns.

**Request:**
```json
{
  "mode": "ARCHITECT",
  "tier": "blessed",
  "governanceMode": "ADVISORY"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `mode` | string | yes | Flow mode (e.g., `ARCHITECT`, `SPRINT`, `RISK`) |
| `tier` | string | no | `blessed` (default) or `all` |
| `governanceMode` | string | no | `PASSIVE`, `ADVISORY` (default), or `ENFORCED` |

**Response:**
```json
{
  "contextHints": ["Use Hono or plain fetch handler for routing", "..."],
  "constraintOverrides": {},
  "qualityThresholds": { "structure_completeness": 70, "blueprint_schema_validity": 80, "content_substance": 60 },
  "guidanceVersion": "1.0.0"
}
```

### POST /assess

Assess the quality of a flow artifact against governance thresholds. Returns a score, per-dimension breakdown, and actionable feedback.

**Request:**
```json
{
  "mode": "ARCHITECT",
  "tier": "blessed",
  "governanceMode": "ENFORCED",
  "artifact": {
    "content": "...artifact content string..."
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `mode` | string | yes | Flow mode being assessed |
| `tier` | string | no | `blessed` (default) or `all` |
| `governanceMode` | string | no | `PASSIVE`, `ADVISORY` (default), or `ENFORCED` |
| `artifact` | object | yes | Object with a `content` string field |

**Response:**
```json
{
  "score": 78,
  "dimensions": { "structure_completeness": 80, "blueprint_schema_validity": 75, "content_substance": 72 },
  "feedback": ["Consider adding error handling patterns", "Missing rate limiting strategy"],
  "assessmentId": "assess_abc123"
}
```

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
