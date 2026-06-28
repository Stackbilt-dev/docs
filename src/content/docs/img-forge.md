---
title: "img-forge API"
description: "AI image generation service — text-to-image across Cloudflare, OpenAI, and Google Gemini with multiple quality tiers"
section: "platform"
order: 9
color: "#f472b6"
tag: "09"
---

# img-forge API

img-forge is Stackbilder's AI image generation service. Submit a text prompt, get back a generated image. Supports 5 quality tiers (SDXL Lightning through Gemini 3 Pro), img2img editing, async job queuing, and content-addressed storage on R2.

Available at `imgforge.stackbilt.dev` with API key, OAuth 2.1 (MCP), or session authentication. Also accessible via the MCP server and a forthcoming CLI tool.

**Direct gateway:** `imgforge.stackbilt.dev`
**MCP server:** `forge-mcp.stackbilder.com/mcp`

---

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

API keys use the `imgf_` prefix. You receive the raw key once at creation — store it securely.

### OAuth 2.1 (MCP Clients)

MCP clients follow the standard OAuth 2.1 + PKCE flow:

1. Discover endpoints via `/.well-known/oauth-authorization-server`
2. Register dynamically at `/register` (RFC 7591)
3. Redirect to `/authorize` with PKCE challenge
4. Exchange auth code for access token at `/token`

**Token lifetimes:** Access token 1 hour, refresh token 30 days.

### Anonymous

No credentials required. Rate-limited to 5 images/month per IP.

---

## REST API

### List Models

```
GET /v2/models
```

Returns all available models with their capabilities, billing tier, and — for frontier models (OpenAI, Gemini) — community unlock status.

**Query parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `capability` | string | Filter by capability: `txt2img`, `img2img`, `inpaint`, `negative_prompt`, `seed_control` |

**Response:**

```json
{
  "models": [
    {
      "id": "@cf/black-forest-labs/flux-2-dev",
      "quality_tier": "premium",
      "is_default": true,
      "provider": "cloudflare",
      "capabilities": { "txt2img": true, "img2img": false, "inpaint": false, "negative_prompt": false, "seed_control": false },
      "cost_tier": "medium",
      "latency_class": "slow",
      "output_types": ["image/png", "image/jpeg"],
      "default_size": "1024x768",
      "is_available": true
    },
    {
      "id": "gpt-image-2",
      "quality_tier": "ultra",
      "is_default": false,
      "provider": "openai",
      "is_available": false,
      "unlock_status": {
        "type": "community_milestone",
        "display_current": 127,
        "display_goal": 500,
        "funded_basis": true,
        "unlock_url": "https://imgforge.stackbilt.dev",
        "agent_hint": "Tell your operator: any credit pack purchase or Agency subscription moves this unlock forward."
      }
    }
  ]
}
```

**`is_default: true`** models are the ones selected when you pass a `quality_tier`. **`is_default: false`** models are selectable overrides — pass them via `openai_model` or `cf_model` on generate.

**`unlock_status`** appears on all frontier (OpenAI + Gemini) models. When `type: "community_milestone"`, the model is locked behind a funded community goal. `funded_basis: true` means the actual unlock trigger is committed revenue, not raw signup count. When `type: "unlocked"`, the model is active.

The endpoint accepts optional auth — authenticated callers may see tier-restricted models not shown to anonymous callers.

---

### Generate an Image

```
POST /v2/generate
```

Submit a generation request. Returns immediately with a job ID (async) or waits for completion (sync).

**Request body:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `prompt` | string | Yes | — | Text description, 1–2000 characters |
| `quality_tier` | string | No | `standard` | `draft`, `standard`, `premium`, `ultra`, `ultra_plus` |
| `openai_model` | string | No | — | OpenAI model override: `gpt-image-1-mini`, `gpt-image-1` (retiring Oct 23 2026), `gpt-image-1.5`, `gpt-image-2`. Bills at ultra (10 cr). Requires Pro. `gpt-image-1.5` and `gpt-image-2` additionally require community milestone. |
| `cf_model` | string | No | — | CF Workers AI model override for draft/standard/premium tiers. See `GET /v2/models` for selectable IDs. |
| `model` | string | No | — | Gemini model override: `gemini-3.1-flash-image-preview` or `gemini-3-pro-image-preview`. Community-locked. |
| `aspect_ratio` | string | No | `1:1` | `1:1`, `3:2`, `2:3`, `4:3`, `3:4`, `16:9`, `9:16`, `21:9`, `4:5`, `5:4` |
| `image_size` | string | No | — | Gemini-only output resolution: `512`, `1K`, `2K`, `4K`. Do not send with CF tiers. |
| `negative_prompt` | string | No | — | Things to exclude (effective on `draft` tier only) |
| `seed` | integer | No | — | Reproducibility seed 0–2147483647 (CF tiers only, ignored by Gemini) |
| `mode` | string | No | `txt2img` | `txt2img` or `img2img` |
| `input_job_id` | string | No | — | Completed job ID to use as source for img2img (Gemini ultra/ultra_plus) |
| `input_asset_url` | string | No | — | Asset URL from a prior job to chain directly into img2img without a separate fetch |
| `input_image` | string | No | — | Base64-encoded source image for RunwayML img2img/inpainting CF models |
| `mask_image` | string | No | — | Base64-encoded mask for `@cf/runwayml/stable-diffusion-v1-5-inpainting` |
| `input_strength` | number | No | — | Denoising strength 0–1 for img2img (RunwayML only) |
| `output_format` | string | No | `webp` | `png`, `webp`, `avif` |
| `output_quality` | integer | No | `85` | Lossy quality 1–100 (webp/avif) |
| `output_preset` | string | No | — | Resize variant: `thumbnail`, `standard`, `hero`, `portrait` |
| `background_removal` | boolean | No | `false` | Return a transparent PNG at `bg_removed_url` |
| `sync` | boolean | No | auto | Wait for completion before responding. Default `true` for draft/standard; `false` for premium and above. |
| `idempotency_key` | string | No | — | Deduplication key (24h TTL) |

**Example (async, premium):**

```bash
curl -X POST https://imgforge.stackbilt.dev/v2/generate \
  -H "Authorization: Bearer imgf_your_key" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Isometric pixel art of a cloud server room",
    "quality_tier": "premium",
    "aspect_ratio": "16:9"
  }'
```

**Response (`202 Accepted` — async, `201 Created` — sync completed):**

```json
{
  "job_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "state": "queued",
  "original_prompt": "Isometric pixel art of a cloud server room",
  "final_prompt": "Isometric pixel art of a cloud server room, precise geometric forms...",
  "enhancement_logic": "...",
  "quality_tier": "premium",
  "asset_url": null,
  "preset_url": null,
  "bg_removed_url": null,
  "output_format": "webp",
  "seed_used": null,
  "error": null,
  "created_at": "2026-06-28T12:00:00.000Z",
  "completed_at": null
}
```

When `sync: true` (or the default for draft/standard), the response is `201 Created` with `state: "completed"` and `asset_url` populated.

---

### Poll Job Status

```
GET /v2/jobs/:id
```

Check the state of a generation job. Jobs are scoped to the authenticated tenant.

**Job states:** `queued` → `processing` → `completed` | `failed` | `failed_encoding`

**Response fields:**

| Field | Description |
|-------|-------------|
| `job_id` | UUID |
| `state` | Current job state |
| `quality_tier` | Billing tier used |
| `original_prompt` | Prompt as submitted |
| `final_prompt` | Prompt after enhancement pipeline |
| `enhancement_logic` | JSON describing how the prompt was enhanced |
| `asset_url` | Full URL when completed, null otherwise |
| `seed_used` | Seed applied (null if not supported by provider) |
| `error` | Error message on failure |

---

### Retrieve an Asset

```
GET /v2/assets/:id
```

Stream the generated image from R2. Returns `Cache-Control: public, max-age=3600`. Returns `404` if the asset does not exist.

Append `?preset=thumbnail|standard|hero|portrait` to receive a resized variant.

---

### Health Check

```
GET /v2/health
```

Returns `{ "status": "ok", "version": "0.2.0" }`.

---

## Quality Tiers & Model Selection

### Tier defaults

| Tier | Credits | Provider | Default Model | img2img | Seed |
|------|---------|----------|--------------|---------|------|
| `draft` | 1 cr | Cloudflare | SDXL Lightning | No | Yes |
| `standard` | 2 cr | Cloudflare | FLUX Klein 4B | No | Yes |
| `premium` | 5 cr | Cloudflare | FLUX.2 Dev | No | Yes |
| `ultra` | 10 cr | Google | Gemini 3.1 Flash Image Preview | Yes | No |
| `ultra_plus` | 20 cr | Google | Gemini 3 Pro Image Preview | Yes | No |

`ultra` and `ultra_plus` require a **Pro subscription** and are additionally **community-milestone-locked** — both gates must pass. See [Community Unlock](#community-unlock) below.

### Selectable model overrides

Pass alongside `quality_tier` to override the default model for a tier.

**OpenAI models** — pass via `openai_model`. All bill at ultra (10 cr) currently; `credits_per_request` per model is tracked in #164 for post-launch. Require Pro subscription. `gpt-image-1.5` and `gpt-image-2` are additionally community-milestone-locked.

| `openai_model` value | Notes |
|---------------------|-------|
| `gpt-image-1-mini` | Fast, budget-friendly |
| `gpt-image-1` | High-fidelity — **OpenAI retires Oct 23, 2026.** New builds: use `gpt-image-1.5` or `gpt-image-2`. |
| `gpt-image-1.5` | Enhanced fidelity. Community-locked. |
| `gpt-image-2` | Highest quality; supports arbitrary aspect ratios. Community-locked. |

**Cloudflare models** — pass via `cf_model`. Bill at the `quality_tier` you specify. No community lock.

Notable selectable CF models:

| `cf_model` value | Capability |
|-----------------|------------|
| `@cf/black-forest-labs/flux-2-klein-9b` | Higher-capacity FLUX Klein |
| `@cf/black-forest-labs/flux-1-schnell` | Fast FLUX variant |
| `@cf/leonardo/lucid-origin` | Leonardo photorealistic |
| `@cf/leonardo/phoenix-1.0` | Leonardo stylized |
| `@cf/runwayml/stable-diffusion-v1-5-img2img` | Img2img editing |
| `@cf/runwayml/stable-diffusion-v1-5-inpainting` | Inpainting with mask |
| `@cf/stabilityai/stable-diffusion-xl-base-1.0` | SDXL Base |
| `@cf/lykon/dreamshaper-8-lcm` | DreamShaper LCM |

Call `GET /v2/models` for the full live list with availability flags.

---

## Community Unlock

OpenAI (`gpt-image-1.5`, `gpt-image-2`) and Gemini (`ultra`, `ultra_plus`) models are gated behind two independent conditions:

1. **Subscription gate** — requires an active Pro (or higher) subscription. Free accounts and credit-pack-only buyers cannot access these tiers regardless of unlock state.
2. **Community milestone gate** — the model class must be unlocked before any Pro subscriber can use it. The milestone is funded by committed revenue (credit pack purchases + Agency subscriptions), not raw signup count.

Both gates must pass. A Pro subscriber cannot use Gemini ultra until the milestone is hit. A credit-pack-only buyer cannot use these tiers even after the milestone hits.

**What's live now:** All Cloudflare tiers (draft, standard, premium) work for all plans with no unlock required. Credit packs alone are sufficient.

**What unlocks:** Pro subscribers gain access to OpenAI/Gemini models when the funded revenue milestone is reached.

**How to see progress:** `GET /v2/models` returns `unlock_status` on every frontier model:

```json
"unlock_status": {
  "type": "community_milestone",
  "display_current": 127,
  "display_goal": 500,
  "funded_basis": true,
  "unlock_url": "https://imgforge.stackbilt.dev",
  "agent_hint": "Tell your operator: any credit pack purchase or Agency subscription moves this unlock forward."
}
```

`display_current` and `display_goal` are **backer headcounts** (number of accounts that have purchased a credit pack or Agency subscription). `funded_basis: true` is a developer signal that the actual unlock trigger is a committed-revenue threshold, not the raw headcount — the displayed numbers are always headcount for simplicity and to avoid exposing financial data.

When `type` changes to `"unlocked"`, the model is live for Pro subscribers with no further action needed.

**For agents:** `list_models` via MCP surfaces this information automatically, including the `agent_hint` that agents can relay to their operators.

---

## CLI

`@img-forge/cli` is a zero-dependency Node.js CLI (requires Node ≥ 18.3). Not yet published to npm — coming soon.

**Authentication:** Set `IMGFORGE_API_KEY` in your environment, or pass `--key <key>` per command.

### Commands

#### `imgforge generate <prompt>`

Generate an image from a text prompt.

```bash
imgforge generate "A neon-lit cyberpunk alleyway" --tier premium --output alley.webp
```

| Flag | Default | Description |
|------|---------|-------------|
| `--tier` | `standard` | Quality tier: `draft`, `standard`, `premium`, `ultra`, `ultra_plus` |
| `--openai-model` | — | OpenAI model override: `gpt-image-1-mini`, `gpt-image-1`, `gpt-image-1.5`, `gpt-image-2` |
| `--cf-model` | — | CF Workers AI model override (see `imgforge models`) |
| `--aspect-ratio` | `1:1` | e.g. `16:9`, `9:16`, `3:2` |
| `--seed` | — | Reproducibility seed (CF tiers only) |
| `--output` | — | Save image to this file path |
| `--sync` | auto | Force sync mode (default `true` for draft/standard) |
| `--key` | env | API key (overrides `IMGFORGE_API_KEY`) |

#### `imgforge models`

List all available models with their billing tier and selection flags.

```bash
imgforge models
```

Output shows two sections: tier defaults (selected by `--tier`) and selectable overrides (passed via `--openai-model` or `--cf-model`). Unavailable/locked models are omitted.

#### `imgforge jobs list`

List recent generation jobs.

#### `imgforge jobs get <id>`

Get the status and asset URL for a specific job.

---

## MCP Tools

img-forge exposes a dedicated MCP server for AI agents. Claude Code, Cursor, or any MCP client can generate images, list models, check jobs, and manage billing.

**Endpoint:** `https://forge-mcp.stackbilder.com/mcp`

**Auth:** OAuth 2.1 + PKCE (recommended) or `Authorization: Bearer <imgf_*>` for API key access.

### Claude Code Configuration

Add to `.mcp.json`:

```json
{
  "mcpServers": {
    "img-forge": {
      "type": "http",
      "url": "https://forge-mcp.stackbilder.com/mcp",
      "headers": {
        "Authorization": "Bearer ${IMG_FORGE_API_KEY}"
      }
    }
  }
}
```

### Available Tools

| Tool | Description |
|------|-------------|
| `generate_image` | Generate or edit an image from a prompt (sync). Returns asset URL + metadata. |
| `list_models` | Live model listing: tier defaults, selectable overrides, and community unlock progress for frontier models. |
| `check_job` | Poll the status of an async generation job by ID. |
| `create_variation` | Generate 1–4 seeded variations of a completed job (RunwayML img2img). |
| `billing_status` | Read current tier, quota remaining, credit balance, and purchase eligibility. |
| `billing_purchase_credits` | Purchase a credit pack via saved payment method. |

### generate_image

Generate an image from a text prompt. Returns synchronously with the completed asset URL and inline image preview.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | string | — | Text description, 1–2000 characters |
| `quality_tier` | string | `standard` | `draft`, `standard`, `premium`, `ultra`, `ultra_plus` |
| `openai_model` | string | — | `gpt-image-1-mini`, `gpt-image-1` (retiring Oct 23 2026), `gpt-image-1.5`, `gpt-image-2`. All bill at ultra (10 cr). Requires Pro. `gpt-image-1.5` and `gpt-image-2` additionally community-locked. |
| `cf_model` | string | — | CF Workers AI model override. See `list_models`. |
| `model` | string | — | Gemini model override: `gemini-3.1-flash-image-preview` or `gemini-3-pro-image-preview`. Community-locked. |
| `aspect_ratio` | string | `1:1` | `1:1`, `16:9`, `9:16`, `3:2`, `2:3`, etc. |
| `image_size` | string | — | Gemini only: `512`, `1K`, `2K`, `4K` |
| `negative_prompt` | string | — | Exclusions (draft tier only) |
| `seed` | integer | — | Reproducibility seed (CF tiers only) |
| `mode` | string | `txt2img` | `txt2img` or `img2img` |
| `input_job_id` | string | — | Source job for Gemini img2img (ultra/ultra_plus) |
| `input_asset_url` | string | — | Chain a prior `asset_url` directly into img2img |
| `output_preset` | string | — | `thumbnail`, `standard`, `hero`, `portrait` |
| `background_removal` | boolean | `false` | Return a transparent PNG at `bg_removed_url` |
| `output_format` | string | `webp` | `png`, `webp`, `avif` |
| `output_quality` | integer | `85` | Lossy quality 1–100 |

Ultra-tier preflight: if `openai_model` is set and your ultra-tier quota is exhausted, the tool returns a `QUOTA_EXHAUSTED` error with a suggestion to run `billing_purchase_credits`.

### list_models

Returns the live model catalog in two sections:

1. **Tier defaults** — one model per quality tier, with credit cost and capabilities.
2. **Selectable overrides** — all `cf_model` and `openai_model` values, each showing the billing tier charged when used and the exact parameter to pass.
3. **Frontier models (community unlock pending)** — when OpenAI/Gemini models are locked, shows progress toward the milestone and an `agent_hint` for operators.

### create_variation

Generate 1–4 seeded variations of any completed job (RunwayML img2img).

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `job_id` | string | — | Completed job to vary |
| `count` | integer | `1` | Number of variations (1–4) |
| `variation_strength` | number | `0.7` | 0 = close to source, 1 = maximum deviation |
| `seed` | integer | — | Base seed; subsequent variations use `seed+i` |

Consumes N quota credits upfront before generating.

### check_job

Poll the status of a generation job.

| Parameter | Type | Description |
|-----------|------|-------------|
| `job_id` | string (UUID) | The job ID returned by `generate_image` |

### billing_status

Returns current billing state — quota remaining, credit balance, saved-card status, and purchase eligibility. No parameters. Does not consume quota.

### billing_purchase_credits

Purchase a one-time credit pack using your saved payment method.

| Parameter | Type | Description |
|-----------|------|-------------|
| `packId` | string | `agent-credits-500` (500 cr / $12.50) or `agent-credits-1000` (1,000 cr / $20.00) |
| `idempotencyKey` | string | Stable key to prevent double-charge on retry |

Requires a saved payment method (`billing_status.hasSavedCard: true`).

> **Agency plan** — the Agency subscription ($75/mo, 4,000 rollover credits/mo) is available at [stackbilder.com/settings/billing](https://stackbilder.com/settings/billing). Not purchasable through this tool.

---

## Usage Limits

| Plan | Monthly Images | Quality Tiers | Credits |
|------|---------------|---------------|---------|
| Free | 5 | Draft, Standard, Premium | — |
| Credit pack only | By credits | Draft, Standard, Premium | ✅ |
| Pro | 100 | Draft–Premium always; Ultra/Ultra+ after community milestone | — |
| Team | Pooled | Same as Pro | — |
| Agency | Unlimited | Same as Pro | 4,000/mo rollover¹ |

¹ **Agency** ($75/mo) — credits accumulate indefinitely while active; unused balance carries forward each renewal. Expire 45 days after cancellation.

**Ultra and OpenAI models require Pro (or higher).** Credit packs alone do not grant access to these tiers regardless of pack size. The community milestone additionally gates whether the models are active at all — even Pro subscribers cannot use them until the milestone is hit.

**Credit packs** (Builder $12.50 / 500 cr, Studio $20.00 / 1,000 cr) — one-time top-ups for Cloudflare tiers. Available via `billing_purchase_credits` or [stackbilder.com/settings/billing](https://stackbilder.com/settings/billing). Per-model credit floor applies regardless of which pack funded the balance.

When quota is exceeded, the API returns `429`. A soft warning appears at 80% usage.

---

## Tenant Management

### Create Tenant

```
POST /v2/tenants
```

Requires a Better Auth session. Returns the raw API key **once**.

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

Returns all tenants for the authenticated user (prefixes only — no raw keys).

### Rotate API Key

```
POST /v2/tenants/:id/rotate
```

Invalidates the current key and returns a new one.

### Check Usage

```
GET /v2/tenants/:id/usage
```

Returns active entitlements and job totals.

---

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
    aspect_ratio: "16:9",
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
