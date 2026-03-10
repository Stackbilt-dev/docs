---
title: "img-forge API"
description: "AI image generation service — text-to-image with multiple quality tiers"
section: "platform"
order: 9
color: "#f472b6"
tag: "09"
---

# img-forge API

img-forge is StackBilt's AI image generation service. Submit a text prompt, get back a generated image. Supports multiple quality tiers (Stable Diffusion XL through Gemini), async job queuing, and content-addressed image storage on R2.

**Gateway:** `https://imgforge.stackbilt.dev`
**MCP Server:** `https://img-forge-mcp.blue-pine-edf6.workers.dev/mcp`

## Authentication

img-forge supports three auth paths, checked in order by the gateway middleware.

### API Key

Include your key in the `Authorization` header or `X-API-Key` header:

```bash
curl -X POST https://imgforge.stackbilt.dev/v2/generate \
  -H "Authorization: Bearer imgf_your_key_here" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "A mountain landscape at sunset"}'
```

API keys use the `imgf_` prefix followed by 64 hex characters. You receive the raw key once at creation — store it securely.

### OAuth 2.1 (MCP Clients)

The MCP server acts as both Authorization Server and Resource Server using `@cloudflare/workers-oauth-provider`. MCP clients follow the standard OAuth 2.1 + PKCE flow:

1. Discover endpoints via `/.well-known/oauth-authorization-server`
2. Register dynamically at `/register` (RFC 7591)
3. Redirect to `/authorize` with PKCE challenge
4. User logs in via Better Auth and grants consent
5. Exchange auth code for access token at `/token`

**Token lifetimes:** Access token 1 hour, refresh token 30 days.
**Scopes:** `generate`, `read`

First-time users are auto-provisioned with a free-tier tenant and 100 images/month entitlement on consent approval.

### Anonymous

No credentials required. Rate-limited to 100 images/month per IP address.

## REST API

### Generate an Image

```
POST /v2/generate
```

Submit a generation request. Returns immediately with a job ID (async) or waits for completion (sync).

**Request body:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Text description, 1–2000 characters |
| `negative_prompt` | string | No | — | Things to exclude (effective on `draft` tier only) |
| `quality_tier` | string | No | `standard` | `draft`, `standard`, `premium`, `ultra`, `ultra_plus` |
| `sync` | boolean | No | `false` | Wait for completion before responding |
| `idempotency_key` | string | No | — | Deduplication key (24h TTL) |

**Example (async):**

```bash
curl -X POST https://imgforge.stackbilt.dev/v2/generate \
  -H "Authorization: Bearer imgf_your_key" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Isometric pixel art of a cloud server room",
    "quality_tier": "premium"
  }'
```

**Response (`202 Accepted`):**

```json
{
  "job_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "state": "queued",
  "original_prompt": "Isometric pixel art of a cloud server room",
  "final_prompt": "...",
  "enhancement_logic": "...",
  "asset_url": null,
  "error": null,
  "created_at": "2026-03-04T12:00:00.000Z",
  "completed_at": null
}
```

When `sync: true`, the response is `201 Created` with `state: "completed"` and `asset_url` populated.

### Poll Job Status

```
GET /v2/jobs/:id
```

Check the state of a generation job. Jobs are scoped to the authenticated tenant.

**Response:**

```json
{
  "job_id": "a1b2c3d4-...",
  "state": "completed",
  "original_prompt": "...",
  "final_prompt": "...",
  "enhancement_logic": "...",
  "asset_url": "/v2/assets/sha256hash",
  "error": null,
  "created_at": "2026-03-04T12:00:00.000Z",
  "completed_at": "2026-03-04T12:00:08.000Z"
}
```

**Job states:** `queued` → `processing` → `completed` | `failed`

Jobs that remain in `processing` for more than 60 seconds are automatically marked `failed` with a timeout error.

### Retrieve an Image

```
GET /v2/assets/:id
```

Stream the generated image from R2. Images are content-addressed by SHA-256 hash.

Returns `image/png` with `Cache-Control: public, max-age=3600`. Returns `404` if the asset does not exist.

### Health Check

```
GET /v2/health
```

Returns `{ "status": "ok", "version": "0.2.0" }`.

## Quality Tiers

| Tier | Provider | Model | Negative Prompt | Default Size |
|------|----------|-------|-----------------|--------------|
| `draft` | Cloudflare AI | Stable Diffusion XL Lightning | Yes | 1024×1024 |
| `standard` | Cloudflare AI | FLUX.2 Klein 4B | No | 1024×768 |
| `premium` | Cloudflare AI | FLUX.2 Dev | No | 1024×768 |
| `ultra` | Gemini | Gemini 2.5 Flash Image | No | 1024×1024 |
| `ultra_plus` | Gemini | Gemini 3.1 Flash Image Preview | No | 1024×1024 |

## MCP Tools

Connect MCP-compatible agents to img-forge for programmatic image generation.

**Endpoint:** `https://img-forge-mcp.blue-pine-edf6.workers.dev/mcp`

### Claude Code Configuration

Add to your MCP settings:

```json
{
  "mcpServers": {
    "img-forge": {
      "url": "https://img-forge-mcp.blue-pine-edf6.workers.dev/mcp"
    }
  }
}
```

### generate_image

Generate an image from a text prompt. Requires `generate` scope.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Text description, 1–2000 characters |
| `quality_tier` | enum | No | `standard` | `draft`, `standard`, `premium`, `ultra`, `ultra_plus` |
| `negative_prompt` | string | No | — | Exclusions (effective on `draft` tier only) |

The MCP tool always uses sync mode — it returns the completed image URL directly.

### list_models

List all available quality tiers with their providers, models, and default sizes. Requires `read` scope. Takes no parameters.

### check_job

Check the status of a generation job. Requires `read` scope.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `job_id` | string (UUID) | Yes | The job ID to check |

## Rate Limits

| Auth Method | Quota | Period | Enforcement |
|-------------|-------|--------|-------------|
| Anonymous | 100 images | Calendar month | Per IP, via KV |
| API key (free tier) | 100 images | Calendar month | Per tenant, via D1 entitlements |
| OAuth / MCP (free tier) | 100 images | Calendar month | Per tenant, via D1 entitlements |

When quota is exceeded, the API returns `429` with error code `QUOTA_EXCEEDED` (authenticated) or `RATE_LIMITED` (anonymous).

## Tenant Management

Authenticated users can manage their API keys through tenant endpoints.

### Create Tenant

```
POST /v2/tenants
```

Requires a Better Auth session. Returns the raw API key **once** — it cannot be retrieved again.

```json
{
  "tenant_id": "uuid",
  "api_key": "imgf_...",
  "api_key_prefix": "imgf_abcd1234",
  "scopes": ["generate", "read"],
  "tier": "free"
}
```

### List Tenants

```
GET /v2/tenants
```

Returns all tenants for the authenticated user. Does not include raw API keys, only prefixes.

### Rotate API Key

```
POST /v2/tenants/:id/rotate
```

Invalidates the current key and returns a new one.

### Check Usage

```
GET /v2/tenants/:id/usage
```

Returns active entitlements and total job count:

```json
{
  "tenant_id": "...",
  "tier": "free",
  "total_jobs": 12,
  "entitlements": [
    {
      "type": "standard",
      "quota_limit": 100,
      "quota_used": 12,
      "remaining": 88,
      "period_start": "2026-03-01T00:00:00Z",
      "period_end": "2026-03-31T23:59:59Z",
      "source": "img-forge-free"
    }
  ]
}
```

## TypeScript Example

```typescript
const GATEWAY = "https://imgforge.stackbilt.dev";
const API_KEY = "imgf_your_key_here";

// Generate (async)
const genRes = await fetch(`${GATEWAY}/v2/generate`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${API_KEY}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    prompt: "A neon-lit cyberpunk alleyway",
    quality_tier: "premium",
  }),
});
const job = await genRes.json();
console.log("Job ID:", job.job_id);

// Poll until complete
let result = job;
while (result.state !== "completed" && result.state !== "failed") {
  await new Promise((r) => setTimeout(r, 2000));
  const pollRes = await fetch(`${GATEWAY}/v2/jobs/${job.job_id}`, {
    headers: { "Authorization": `Bearer ${API_KEY}` },
  });
  result = await pollRes.json();
}

if (result.state === "completed") {
  console.log("Image:", `${GATEWAY}${result.asset_url}`);
}
```
