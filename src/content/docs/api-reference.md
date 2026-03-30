---
title: "API Reference"
description: "REST API reference for Stackbilder. Flow creation, scaffold retrieval, image generation, and authentication."
section: "platform"
order: 7
color: "#c084fc"
tag: "07"
---

# API Reference

Complete reference for the Stackbilder platform API.

**Base URL:** `https://stackbilder.com`

All API routes are Astro server endpoints that call backend services (TarotScript, img-forge) via Cloudflare service bindings. No separate API domain — frontend and API share one worker.

## Authentication

All `/api/*` endpoints require an authenticated session. Authentication is handled via the `better-auth.session_token` cookie, set during OAuth sign-in through edge-auth (`auth.stackbilt.dev`).

### Session Flow

1. User clicks "Sign in with GitHub" (or Google) on `stackbilder.com/login`
2. Redirects to `auth.stackbilt.dev/auth/sign-in/github`
3. OAuth callback sets `better-auth.session_token` cookie
4. All subsequent API requests include the cookie automatically

### Session Validation

The platform validates sessions via an RPC binding to edge-auth (`EdgeAuthEntrypoint.validateSession`). This runs in the same Cloudflare colo with near-zero latency.

**Session claims returned:**

```json
{
  "userId": "string",
  "email": "string",
  "orgId": "string | null",
  "expiresAt": 1234567890
}
```

## Flows API

### Create a Flow

```
POST /api/flows
```

Classifies the intention via TarotScript, then runs a `scaffold-cast` spread to generate the project skeleton and governance output.

**Request body:**

```json
{
  "intention": "A REST API for managing subscriptions with Stripe",
  "project_type": "api"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `intention` | string | Yes | Plain-language description of what to build |
| `project_type` | string | No | `saas`, `api`, `dashboard`, `cli`, `library`, `marketplace` (default: `api`) |

**Response (`201 Created`):**

```json
{
  "id": "sha256-hash",
  "classification": {
    "pattern": "stripe",
    "confidence": "high"
  },
  "traits": {
    "route_shape": "REST CRUD + webhooks",
    "verification": "Stripe signature verification",
    "bindings": "D1, KV",
    "framework": "Hono"
  },
  "tier2_recommended": false,
  "output": "...",
  "facts": { ... }
}
```

### List Flows

```
GET /api/flows
```

Returns scaffold-cast readings from the TarotScript grimoire for the authenticated user.

**Response:**

```json
{
  "flows": [
    {
      "id": "sha256-hash",
      "intention": "A REST API for...",
      "project_type": "api",
      "status": "completed",
      "created_at": "2026-03-29T12:00:00Z"
    }
  ]
}
```

### Get Flow Detail

```
GET /api/flows/:id
```

Returns the full flow including governance artifacts, scaffold output, and classification facts.

**Response:**

```json
{
  "id": "sha256-hash",
  "intention": "A REST API for...",
  "project_type": "api",
  "status": "completed",
  "created_at": "2026-03-29T12:00:00Z",
  "seed": 12345,
  "artifacts": { ... },
  "governance": {
    "threats": "## STRIDE Analysis\nT-001: ...",
    "adrs": "## Decision\nUse cookie-based sessions...",
    "test_plan": "## Integration Tests\ntest_auth_flow: ..."
  },
  "scaffold": {
    "files": { "src/index.ts": "...", "wrangler.toml": "..." },
    "download_url": ""
  },
  "output": "..."
}
```

## Images API

### Generate an Image

```
POST /api/images/generate
```

Creates an image generation job via img-forge. The request is delegated through a service binding with the user's ID for tenant-scoped access.

**Request body:**

```json
{
  "prompt": "A cyberpunk cityscape at sunset",
  "quality_tier": "premium",
  "negative_prompt": "blurry, low quality"
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Text description, 1-2000 characters |
| `quality_tier` | string | No | `standard` | `draft`, `standard`, `premium`, `ultra`, `ultra_plus` |
| `negative_prompt` | string | No | — | Things to exclude (effective on `draft` tier only) |

**Response (`201 Created`):**

```json
{
  "id": "uuid",
  "job_id": "uuid",
  "state": "queued",
  "original_prompt": "A cyberpunk cityscape at sunset",
  "final_prompt": "A cyberpunk cityscape at sunset, masterpiece, best quality...",
  "asset_url": null,
  "created_at": "2026-03-29T12:00:00Z"
}
```

### List Images

```
GET /api/images
```

Returns image jobs for the authenticated user.

**Query parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | number | 20 | Max 100 |
| `offset` | number | 0 | Pagination offset |
| `state` | string | — | Filter: `queued`, `processing`, `completed`, `failed` |

**Response:**

```json
{
  "images": [
    {
      "id": "uuid",
      "prompt": "A cyberpunk cityscape...",
      "quality_tier": "premium",
      "status": "completed",
      "image_url": "/v2/assets/sha256hash",
      "created_at": "2026-03-29T12:00:00Z"
    }
  ]
}
```

### Get Image Status

```
GET /api/images/:id
```

Check the status of a specific image generation job.

**Response:**

```json
{
  "id": "uuid",
  "prompt": "...",
  "quality_tier": "premium",
  "status": "completed",
  "image_url": "/v2/assets/sha256hash",
  "error": null,
  "created_at": "2026-03-29T12:00:00Z"
}
```

**Job states:** `queued` → `processing` → `completed` | `failed`

Jobs stuck in `processing` for more than 60 seconds are automatically marked `failed`.

## Quality Tiers (img-forge)

| Tier | Provider | Model | Neg. Prompt | Default Size |
|------|----------|-------|-------------|--------------|
| `draft` | Cloudflare AI | SDXL Lightning | Yes | 1024x1024 |
| `standard` | Cloudflare AI | FLUX.2 Klein 4B | No | 1024x768 |
| `premium` | Cloudflare AI | FLUX.2 Dev | No | 1024x768 |
| `ultra` | Gemini | Gemini 2.5 Flash | No | 1024x1024 |
| `ultra_plus` | Gemini | Gemini 3.1 Flash | No | 1024x1024 |

## Error Responses

All errors return JSON:

```json
{
  "error": "Description of what went wrong"
}
```

| Status | Meaning |
|--------|---------|
| `400` | Invalid request (missing/invalid parameters) |
| `401` | No valid session (redirect to /login) |
| `404` | Resource not found |
| `502` | Backend service error (TarotScript or img-forge unavailable) |

## Architecture Notes

- API routes are Astro server endpoints (`src/pages/api/*.ts`)
- TarotScript is called via `TAROTSCRIPT` service binding (Fetcher)
- img-forge is called via `IMG_FORGE` service binding (Fetcher) with `X-Service-Binding` secret for delegated auth
- Session validation uses `AUTH_SERVICE` RPC binding to edge-auth (`EdgeAuthEntrypoint`)
- All three bindings run in the same Cloudflare colo — zero HTTP hops
