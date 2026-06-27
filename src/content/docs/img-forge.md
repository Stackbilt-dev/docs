---
title: "img-forge API"
description: "AI image and video generation service — text-to-image and text-to-video with multiple quality tiers"
section: "platform"
order: 9
color: "#f472b6"
tag: "09"
---

# img-forge API

img-forge is Stackbilder's AI image and video generation service. Submit a text prompt, get back a generated image or video clip. Supports 5 quality tiers (SDXL through Gemini 3 Pro), async job queuing, and content-addressed storage on R2.

img-forge is included in all Stackbilder plans with no per-image costs. Usage counts against your monthly image quota.

**Platform UI:** [stackbilder.com/images](https://stackbilder.com/images)
**API:** `stackbilder.com/api/images/*` (authenticated, via service binding to img-forge-gateway)
**Direct gateway:** `imgforge.stackbilt.dev` (for API key / MCP access)

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
| `media_type` | string | No | `image` | `image` or `video` |
| `duration_seconds` | integer | No | — | Video duration in seconds (video only) |
| `fps` | integer | No | — | Video frame rate (video only) |
| `motion_intensity` | number | No | — | Motion amount 0.0–1.0 (video only) |
| `loop` | boolean | No | `false` | Whether the video loops (video only) |
| `output_format` | string | No | `webp` | Delivery format: `png`, `webp`, `avif` |
| `output_quality` | integer | No | `85` | Lossy compression quality 1–100 (webp/avif) |
| `output_preset` | string | No | — | Resize variant: `thumbnail`, `standard`, `hero`, `portrait` |
| `background_removal` | boolean | No | `false` | Return a `bg_removed_url` (transparent PNG, images only) |
| `openai_model` | string | No | — | Override to `gpt-image-1` or `dall-e-3` (bypasses quality_tier) |
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

**Job states:** `queued` → `processing` → `encoding` → `completed` | `failed` | `failed_encoding`

The `encoding` state applies to video jobs after AI generation completes but before the output is stored. Jobs that exceed the timeout are automatically marked `failed` (images: 60 s, videos: 120 s).

### Retrieve an Asset

```
GET /v2/assets/:id
```

Stream the generated image or video from R2. Images use SHA-256 content-addressed keys; videos use UUID-based keys (`video/{uuid}.{ext}`).

Returns the asset with `Cache-Control: public, max-age=3600`. Returns `404` if the asset does not exist.

**Range requests (video):** Supports `Range: bytes=start-end` for video seeking. Returns `206 Partial Content` with `Content-Range` and `Accept-Ranges: bytes`. Returns `416 Range Not Satisfiable` for out-of-bounds ranges.

**Image resizing:** Append `?preset=thumbnail|standard|hero|portrait` to receive a resized variant via Cloudflare Image Resizing.

### Health Check

```
GET /v2/health
```

Returns `{ "status": "ok", "version": "0.2.0" }`.

## Quality Tiers

| Tier | Provider | Model | Negative Prompt | Default Size |
|------|----------|-------|-----------------|--------------|
| `draft` | Cloudflare AI | SDXL Lightning | Yes | 1024×1024 |
| `standard` | Cloudflare AI | FLUX Klein 4B | No | 1024×768 |
| `premium` | Cloudflare AI | FLUX.2 Dev | No | 1024×768 |
| `ultra` | Google | Gemini 3.1 Flash Image Preview | No | 1024×1024 |
| `ultra_plus` | Google | Gemini 3 Pro Image Preview | No | 1024×1024 |

## MCP Tools

img-forge exposes a dedicated MCP server for AI agents. Claude Code, Cursor, or any MCP client can generate images and videos, manage variations, and check billing status during development workflows.

**Endpoint:** `https://forge-mcp.stackbilder.com/`

**Auth:** OAuth 2.1 + PKCE (recommended) or `Authorization: Bearer <sb_live_*|imgf_*>` for API key access.

### Claude Code Configuration

Add to `.mcp.json`:

```json
{
  "mcpServers": {
    "img-forge": {
      "type": "http",
      "url": "https://forge-mcp.stackbilder.com/",
      "headers": {
        "Authorization": "Bearer ${IMG_FORGE_API_KEY}"
      }
    }
  }
}
```

Set `IMG_FORGE_API_KEY` in your shell environment or Claude Code's `env` settings.

### Available Tools

| Tool | Description |
|------|-------------|
| `generate_image` | Generate or edit an image/video from a prompt (sync). Accepts all fields from `POST /v2/generate`. |
| `list_models` | List available tiers, models, and providers. No parameters. |
| `check_job` | Poll the status of an async generation job by ID. |
| `create_variation` | Generate 1–4 seeded variations of a completed job (RunwayML img2img). |
| `billing_status` | Read current tier, quota remaining, credit balance, and purchase eligibility. |
| `billing_purchase_credits` | Purchase a credit pack via saved payment method (off-session Stripe charge). |

### generate_image

Generate an image or video from a text prompt. Always returns synchronously with the completed asset URL.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Text description, 1–2000 characters |
| `quality_tier` | string | No | `standard` | `draft`, `standard`, `premium`, `ultra`, `ultra_plus` |
| `media_type` | string | No | `image` | `image` or `video` |
| `negative_prompt` | string | No | — | Exclusions (draft tier only) |
| `output_preset` | string | No | — | `thumbnail`, `standard`, `hero`, `portrait` |
| `background_removal` | boolean | No | `false` | Return a transparent PNG bg-removed URL |
| `openai_model` | string | No | — | `gpt-image-1` or `dall-e-3` |

Ultra-tier preflight: if `openai_model` is set and your ultra-tier quota is exhausted, the tool returns a `QUOTA_EXHAUSTED` error with a suggestion to run `billing_purchase_credits`.

### create_variation

Generate 1–4 seeded variations of any completed job. Seed and strength are both honored (RunwayML img2img).

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `job_id` | string | Yes | — | Completed job to vary |
| `count` | integer | No | `1` | Number of variations (1–4) |
| `variation_strength` | number | No | `0.7` | 0 = close to source, 1 = maximum deviation |
| `seed` | integer | No | — | Base seed; subsequent variations use `seed+i` |

Consumes N quota credits upfront before fanning out.

### check_job

Poll the status of a generation job.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `job_id` | string (UUID) | Yes | The job ID returned by `generate_image` |

### billing_status

Returns current billing state — quota remaining, credit balance, saved-card status, and purchase eligibility. Takes no parameters. Does not consume quota.

### billing_purchase_credits

Purchase a credit pack using your saved payment method.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `packId` | string | Yes | `starter_100` (100 cr / $9.99), `growth_500` (500 cr / $39.99), `scale_2000` (2000 cr / $129.99) |
| `idempotencyKey` | string | No | Stable key to prevent double-charge on retry |

Requires a saved payment method (`billing_status.hasSavedCard: true`) and `purchaseStatus.status: "ready"`.

## Usage Limits

Image generation is included in Stackbilder plans. Limits are enforced via invisible quotas — no credits or per-image charges.

| Plan | Monthly Images | Quality Tiers |
|------|---------------|---------------|
| Free | 5 | Draft through Premium |
| Pro | 100 | All 5 tiers |
| Team | Pooled | All 5 tiers |

Anonymous access (no auth) is rate-limited to 100 images/month per IP.

When quota is exceeded, the API returns `429`. A soft warning appears at 80% usage.

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
const TERMINAL = new Set(["completed", "failed", "failed_encoding"]);
let result = job;
while (!TERMINAL.has(result.state)) {
  await new Promise((r) => setTimeout(r, 2000));
  const pollRes = await fetch(`${GATEWAY}/v2/jobs/${job.job_id}`, {
    headers: { "Authorization": `Bearer ${API_KEY}` },
  });
  result = await pollRes.json();
}

if (result.state === "completed") {
  console.log("Asset:", result.asset_url);
}
```
