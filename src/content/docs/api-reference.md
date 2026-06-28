---
title: "API Reference"
description: "Complete REST API reference for the unified Stackbilder platform on stackbilder.com — Evidence Engine, Worker Observability, Consultations, Flows, Images, billing, account, and authentication."
section: "platform"
order: 7
color: "#c084fc"
tag: "07"
---

# Stackbilder Platform API Reference

**Base URL:** `https://stackbilder.com`
**Last updated:** 2026-05-02
**Worker:** stackbilt-web (Astro SSR on Cloudflare, 47 API route files / 60 HTTP method handlers bundled in one worker)

All API routes live at `/api/*` paths on `stackbilder.com`. They are Astro server-side endpoints compiled into the stackbilt-web Cloudflare Worker at deploy time. There is no separate API worker. Cross-worker concerns (authentication, [TarotScript](/tarotscript) execution, [img-forge](/img-forge) rendering, CodeBeast ledger) are handled via Cloudflare service bindings from inside this worker.

The API is the canonical contract for all four consumer types: the web UI at `/app/*`, the [MCP gateway](/mcp), the [Charter CLI](/getting-started), and direct API consumers. No consumer is privileged. For platform architecture and plan tiers, see [Stackbilder Platform](/platform). For the full ecosystem context, see [Ecosystem](/ecosystem).

---

## Table of contents

- [Authentication](#authentication)
- [Common patterns](#common-patterns)
- [Service bindings](#service-bindings)
- [Reference](#reference)
  - [Health & meta](#health--meta)
  - [Authentication & account](#authentication--account)
  - [API keys](#api-keys)
  - [Usage](#usage)
  - [Agent consultations](#agent-consultations)
  - [Evidence Engine](#evidence-engine)
  - [Trust Page](#trust-page)
  - [Scaffolder (Flows)](#scaffolder-flows)
  - [Images](#images)
  - [Worker observability](#worker-observability)
  - [Billing](#billing)
  - [Marketing & support](#marketing--support)
  - [Telemetry](#telemetry)
  - [MCP server](#mcp-server)
  - [Admin](#admin)

---

## Authentication

Two auth modes:

| Mode | How | Use |
|---|---|---|
| Session cookie | `better-auth.session_token` (dev) or `__Secure-better-auth.session_token` (prod) | Web UI from a logged-in browser |
| API key | `Authorization: Bearer ea_*` | CLI, MCP, server-to-server, CI |

Routes typically accept **either** unless noted. A handful (admin endpoints, form-handling helpers) restrict to one mode.

For API keys, resolve your identity with `GET /api/account/me` — useful for CLIs, MCP callers, and for determining the `orgId` used in entitlement checks.

Mint an API key from the web UI at `/settings` or via `POST /api/keys`.

---

## Common patterns

### Identity scope — split-by-policy contract

Per edge-auth's split-by-policy contract (receipt `cbfcacecda58e33be77f9cd2b6afb142ecd18a2b30a68a31906658a723d5c16e`):

- **Org-level scope** — SKU, tier, plan, features, Trust Page ownership. Every entitlement check uses `user.orgId`.
- **Per-resource scope** — quota attribution, D1 row tenant_id, rate-limit keys. Uses `user.tenantId || user.orgId || user.id`.

This is why API-key auth (where `tenantId` is typically null) and session auth (where `tenantId` is the current tenant) resolve to the same org-level answer for entitlements but different values for per-resource scopes.

### Error response shape

Most routes return JSON errors in this shape:

```json
{ "error": "human-readable message", "code": "machine_code_optional", "upgrade": "/pricing_optional" }
```

Codes you'll see in practice:

- `already_subscribed` — 409 on checkout when the tenant already has a paid subscription
- `cross_tenant_conflict` — 409 on trust/slug or bundle write when another tenant owns it
- `cross_tenant_forbidden` — 403 on delete when another tenant owns it
- `library_limit` — 402 on Evidence library when at tier cap
- `no_stripe_customer` — 422 on billing portal when no customer exists
- `evidence_gap_fill_requires_pro` — 402 when tier isn't pro/team
- `evidence_gap_fill_rate_limited` — 429 on 30/hr defense rate limit
- `evidence_gap_fill_quota_exceeded` — 429 on edge-auth quota
- `empty_library` — 400 on gap-fill when no assets exist for tenant

### Rate limits

| Route family | Limit | Source |
|---|---|---|
| `/api/billing/checkout` | 10/hr per user | stackbilt-web |
| `/api/billing/downgrade` | 5/hr per user | stackbilt-web |
| `/api/v1/evidence/gap-fill` | 30/hr per tenant | stackbilt-web (defense layer) |
| `/api/v1/evidence/gap-fill` | `evidence_gap_fills` quota | edge-auth |
| `/api/agents/*` | `scaffolds` quota | edge-auth |
| `/api/flows/*` | `scaffolds` quota | edge-auth |
| `/api/images/generate` | `images` quota | edge-auth |
| `/api/contact` | 3/hr per IP | stackbilt-web |
| `/api/subscribe` | 5/hr per IP | stackbilt-web |
| `/api/support/tickets` | 5/hr per user | stackbilt-web |
| `/api/scaffold/preview` | 10/min per IP | stackbilt-web |
| `/api/mcp` tools | 5–10/min per isolate | stackbilt-web |

---

## Service bindings

The worker uses these Cloudflare service bindings to reach sibling workers (RPC / Fetcher over internal network):

| Binding | Target | Purpose |
|---|---|---|
| `AUTH_SERVICE` | edge-auth | Sessions, API keys, entitlements, quotas, Stripe integration |
| `TAROTSCRIPT` | tarotscript-worker | Agent consultations, scaffold harness, receipt signing |
| `IMG_FORGE` | img-forge-gateway | Image generation |
| `CODEBEAST` | codebeast | /decide receipts ledger (Trust Page governance timeline) |

Plus direct bindings: `OBSERVE_DB`, `TRUST_DB`, `EVIDENCE_DB` (D1), `TRUST_BUNDLES` (R2).

---

# Reference

## Health & meta

### `GET /api/health`

**Purpose:** Public liveness and dependency health check for external uptime monitors.

**Auth:** None

**Success responses:**
```ts
// 200 OK (healthy) or 503 (degraded)
{
  status: "healthy" | "degraded",
  checks: {
    auth_service: { status: "pass" | "fail", latency_ms: number },
    tarotscript:  { status: "pass" | "fail", latency_ms: number },
    img_forge:    { status: "pass" | "fail", latency_ms: number }
  },
  latency_ms: number,
  timestamp: string
}
```

**Example:**
```bash
curl https://stackbilder.com/api/health
```

**Source:** `src/pages/api/health.ts`

**Notes:** Probes AUTH_SERVICE, TAROTSCRIPT, IMG_FORGE bindings.

---

## Authentication & account

### `GET /api/auth/relay`

**Purpose:** OAuth session relay — receives session token from auth.stackbilt.dev after OAuth callback, sets secure cookie, redirects to target page.

**Auth:** None

**Query params:**
- `token` (required) — Session token from auth service
- `redirect` (optional) — Target path after login; default `/dashboard`. Validated as safe relative path.

**Response:** 302 redirect with `Set-Cookie: better-auth.session_token=...`

Redirects to `/login` if no token, or `/dashboard` if redirect is unsafe.

**Notes:** Called by edge-auth during SSO flow. Cookie is HttpOnly, Secure, SameSite=Lax, 7-day Max-Age.

**Source:** `src/pages/api/auth/relay.ts`

---

### `GET /api/account/me`

**Purpose:** Introspect the authenticated caller's identity — `{ userId, orgId, tenantId, email }`.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:**
```ts
// 200 OK
{
  userId: string,
  orgId: string | null,
  tenantId: string | null,
  email: string | null  // empty when using API key auth
}
```

**Error responses:**
- `401` — no valid session or API key

**Example:**
```bash
curl -H "Authorization: Bearer ea_YOUR_KEY" https://stackbilder.com/api/account/me
```

**Source:** `src/pages/api/account/me.ts`

**Notes:** Used by Charter CLI (`charter whoami`), MCP tools for caller identity, and for determining the `orgId` used in `CONSULT_DOGFOOD_ORGS` or entitlement checks.

---

### `POST /api/account/name`

**Purpose:** Update the authenticated user's display name.

**Auth:** Session cookie only

**Request body:**
```ts
{ name: string }  // 0–100 chars; empty string clears
```

**Success responses:**
```ts
// 200 OK
{ ok: true, name: string | null }
```

**Error responses:**
- `400` — invalid JSON or name exceeds 100 chars
- `401` — not authenticated
- `403` — session token invalid or insufficient permissions (forwarded from AUTH_SERVICE)
- `502` — AUTH_SERVICE unavailable

**Notes:** Forwards session token to `AUTH_SERVICE.updateUser()` for server-side ownership verification.

**Source:** `src/pages/api/account/name.ts`

---

## API keys

### `GET /api/keys`

**Purpose:** List the authenticated user's API keys (masked).

**Auth:** Session cookie only

**Success responses:**
```ts
// 200 OK
[
  {
    id: string,
    name: string,
    maskedKey: string,  // last 4 chars shown
    createdAt: string,
    lastUsed: string | null
  }
]
```

**Source:** `src/pages/api/keys/index.ts`

---

### `POST /api/keys`

**Purpose:** Generate a new API key.

**Auth:** Session cookie only

**Request body:**
```ts
{ name: string }  // required, non-empty
```

**Success responses:**
```ts
// 201 Created
{ id: string, name: string, key: string, createdAt: string }
```

The full `key` (format `ea_*`) is returned once; save it now — it cannot be retrieved later.

**Error responses:**
- `400` — name missing or empty
- `401` — not authenticated

**Source:** `src/pages/api/keys/index.ts`

---

### `DELETE /api/keys/:id`

**Purpose:** Revoke an API key.

**Auth:** Session cookie only

**Success responses:** `204 No Content`

**Source:** `src/pages/api/keys/[id].ts`

---

## Usage

### `GET /api/usage`

**Purpose:** Current quota usage and tier for the authenticated user.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:**
```ts
// 200 OK
{
  scaffolds: { used: number, limit: number },
  images:    { used: number, limit: number },
  tier: "free" | "pro" | "team",
  cycle_ends_at: string  // ISO 8601
}
```

Tier limits: `free` = 3 scaffolds / 5 images, `pro`/`team` = 50 scaffolds / 100 images.

**Notes:** SKU/tier is org-level per edge-auth split-by-policy contract. Defaults to free tier if AUTH_SERVICE lookup fails or tenant not provisioned.

**Source:** `src/pages/api/usage.ts`

---

## Agent consultations

Structured C-level agent consultations powered by TarotScript. Both CTO and CISO receive signed receipts independently verifiable at `https://verify.stackbilt.dev/<hash>`.

### `POST /api/agents/run`

**Purpose:** Execute an agent consultation — returns structured analysis + guidance + receipt.

**Auth:** Session cookie or `Bearer ea_*`

**Request body:**
```ts
{
  role: string,                        // cto, ciso, cfo, cmo, cpo, architect
  intention: string,                   // what decision or question
  context?: Record<string, unknown>,   // optional structured context
  painSignals?: string[],              // optional pain points
  responseMode?: "symbolic" | "natural" | "structured-only",
  seed?: number                        // optional for deterministic results
}
```

**Success responses:**
- `200 OK` — `AgentRunResultType` from `@stackbilt/contracts/agent-response` (or its stackbilt-web mirror at `src/contracts/agent-response.ts`): `{ schema_version, success, role, response, symbolicResponse, analysis, guidance?, receipt, responseMode, metadata, envelope? }`

**Error responses:**
- `400` — "role and intention are required"
- `401` — Unauthorized
- `429` — `{ error, upgrade: "/pricing" }` — scaffolds quota exceeded
- `502` — upstream TarotScript error

**Example:**
```bash
curl -X POST https://stackbilder.com/api/agents/run \
  -H "Authorization: Bearer ea_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "role": "cto",
    "intention": "Evaluate Cloudflare Workers vs AWS Lambda for a multi-region edge API",
    "context": { "stage": "seed", "teamSize": "2_5" }
  }'
```

**Source:** `src/pages/api/agents/run.ts`

**Notes:** Forwards to tarotscript `/agents/run` with `inscribe: true` so receipts persist to D1 for verification. Consumes one `scaffolds` quota credit. CTO runs keep claims private (`publish_claims` not set); CISO intake flow opts in via `/ciso-intake` route below.

---

### `POST /api/agents/ciso-intake`

**Purpose:** Structured CISO posture intake — returns a signed Trust Bundle receipt or a refusal with remediation guidance.

**Auth:** Session cookie or `Bearer ea_*`

**Request body:** `CisoIntakePayload` (see `src/contracts/ciso-intake.ts`)

```ts
{
  schemaVersion: 1,
  companyProfile: {
    name: string,
    employeeCount: number,
    foundingDate: string,               // ISO date YYYY-MM-DD
    fundingStage: "pre-seed" | "seed" | "series-a" | "series-b" | "series-c" | "growth" | "bootstrap" | "public",
    customerTypes: ("smb" | "mid-market" | "enterprise" | "consumer" | "government" | "nonprofit" | "other")[],
    dataResidency: ("us" | "eu" | "uk" | "ca" | "apac" | "latam" | "global")[]
  },
  techStack: {
    cloudProvider: CloudProvider[],     // aws | gcp | azure | cloudflare | vercel | fly | digitalocean | on-prem | hybrid | other
    compute: Compute[],                 // containers | serverless | vm | kubernetes | workers | lambda | cloud-run | ec2 | edge-functions | other
    database: Database[],               // postgres | mysql | mongodb | dynamodb | firestore | d1 | cloudflare-kv | redis | sqlite | spanner | other
    monitoring: Monitoring[],           // datadog | new-relic | sentry | honeycomb | grafana | cloudflare-analytics | workers-analytics | splunk | none | other
    cicd: CiCd[]                        // github-actions | gitlab-ci | circleci | jenkins | cloudflare-pages | vercel | manual | wrangler | other
  },
  dataHandled: ("pii" | "phi" | "pci" | "financial" | "biometric" | "credentials" | "health" | "none")[],
  controlBaseline: {
    mfa:                 { scope: "universal" | "privileged-only" | "partial" | "none", owner: string, notes?: string },
    encryptionAtRest:    { algo:  "aes-256" | "aes-128" | "customer-managed-keys" | "cloud-provider-default" | "none", owner: string, notes?: string },
    encryptionInTransit: { tlsVersion: "tls-1.3" | "tls-1.2" | "tls-1.1" | "tls-1.0" | "legacy" | "none", owner: string, notes?: string },
    iam:                 { model: "least-privilege" | "role-based" | "attribute-based" | "flat" | "ad-hoc" | "none", owner: string, notes?: string },
    logging:             { retentionDays: number, centralized: boolean, owner: string, notes?: string },
    workstationSecurity: { screenLock: boolean, diskEncryption: boolean, edr: boolean, owner: string, notes?: string },
    passwordManager:     { tool: string, coverage: "universal" | "partial" | "none", owner: string, notes?: string },
    peerReview:          { model: "peer" | "single-maintainer" | "multi-agent" | "automated-only" | "none", owner: string, notes?: string }
  },
  subprocessors: Array<{
    name: string,
    purpose: string,
    dataAccess: SubprocessorDataAccess[],  // pii | phi | pci | financial | biometric | credentials | health | logs | telemetry | metadata | billing | support | none
    jurisdiction: string,
    dpaSigned: boolean
  }>,
  incidentHistory: Array<{
    date: string,
    severity: "low" | "medium" | "high" | "critical",
    scope: string,
    resolution: string
  }>,
  certifications: {
    soc2:     { status: CertStatus, lastAudit?: string },
    iso27001: { status: CertStatus, lastAudit?: string },
    penTest:  { status: CertStatus, lastAudit?: string, scope?: string }
  },  // CertStatus = "none" | "in-progress" | "scheduled" | "type-i" | "type-ii" | "certified" | "completed"
  compensatingControls: Array<{ gap: string, mitigation: string, owner: string }>
}
```

**Success responses:**
```ts
// 200 OK — accepted
{
  accepted: true,
  refusal: {
    refused: false,
    findings: Array<{
      id: string, path: string,
      description: string, remediation: string,
      recoveredBy?: { gap: string, owner: string }
    }>,
    summary: string
  },
  receipt: {
    hash: string,
    verifyUrl: string,              // path — full URL: https://verify.stackbilt.dev<verifyUrl>
    claimsSchemaVersion: number
  },
  seed: number,
  latencyMs: number
}
```

**Error responses:**
- `400` — Invalid JSON or Zod validation error from TarotScript
- `401` — Unauthorized
- `422` — refused on unrecovered instant-disqualifier:
  ```ts
  { refused: true, summary: string, findings: Array<{ id, path, description, remediation }> }
  ```
- `429` — scaffolds quota exceeded with `upgrade: "/pricing"`
- `502` — upstream TarotScript error

**Source:** `src/pages/api/agents/ciso-intake.ts`

**Notes:** Zod-validated on the TarotScript side (tarotscript#203). Consumes one `scaffolds` quota credit. Refusal runs server-side and is authoritative — client-side disqualifier detection in CisoConsultation.tsx is UX-only. Successful receipts can be registered to a Trust Page slug via `POST /api/trust/slugs` for public publication at `trust.stackbilder.com/<slug>`.

---

### `POST /api/agents/bootstrap`

**Purpose:** Deck research — analyze domain gaps and assign research methodology tier.

**Auth:** Session cookie or `Bearer ea_*`

**Request body:**
```ts
{
  role: string,                 // cto | ciso | cfo | cmo | cpo | architect
  domain?: string,              // optional domain or business context
  internalSignals?: string[]    // optional internal signal / pain data
}
```

**Success responses:**
- `200 OK` — `BootstrapResultType` with methodology metadata (signalType, signalClass, gapType, gapClass, researchStrategy, researchType, evidenceBar, tierAssignment, methodologyConfidence)

**Error responses:**
- `400` — "role is required"
- `401` — Unauthorized
- `429` — scaffolds quota exceeded
- `502` — upstream TarotScript error

**Source:** `src/pages/api/agents/bootstrap.ts`

**Notes:** Consumes one `scaffolds` quota credit.

---

### `GET /api/agents/:role/memory`

**Purpose:** Query agent memory state (zone counts, entropy, recent cards) for a specific role.

**Auth:** Session cookie or `Bearer ea_*`

**Path params:**
- `role` — cto | ciso | cfo | cmo | cpo | architect

**Success responses:**
- `200 OK` — `MemoryQueryResultType`: `{ role, exists, tick?, zones: { discard, deck, metaInsight, identity }, entropy: { shannonDiversity, elementCounts, depletionRatio, transCapacity, totalCards }, recentMemories?, updatedAt? }`

**Error responses:**
- `400` — "role is required"
- `401` — Unauthorized
- `502` — upstream TarotScript error

**Source:** `src/pages/api/agents/[role]/memory.ts`

**Notes:** Read-only; does NOT consume quota. Use to monitor agent memory saturation.

---

## Evidence Engine

E-E-A-T content quality tooling backed by [`@stackbilt/evidence-core`](/evidence-core) (Apache-2.0, usable standalone). See AEGIS wiki `evidence-engine-gap-fill-architecture` for full architecture.

### `POST /api/v1/evidence/validate`

**Purpose:** Run E-E-A-T validation against content. Deterministic (no LLM, no library access).

**Auth:** Session cookie or `Bearer ea_*`

**Request body:**
```ts
{
  content: ContentInput | string,            // required; bare string wraps to { body: string }
  policyVersion?: "google_november_2024_reputation"  // default
}
```
Max JSON payload: 128 KiB.

**Success responses:**
```ts
// 200 OK
{
  validationId: string,
  cached: boolean,          // true if returned from 1-hour dedup cache
  score: number,            // 0-100, equal-weight active policy requirements satisfied
  hasGaps: boolean,
  gapCount: number,
  policyVersion: string,
  policyName: string,
  gaps: Array<{
    pillar: "Experience" | "Expertise" | "Authoritativeness" | "Trustworthiness",
    type?: string,
    description: string,
    severity?: string
  }>,
  suggestions: string[]
}
```

**Error responses:**
- `400` — `{ error: "content is required" | "invalid_json" | "Unknown evidence policy version ..." }`
- `401` — session invalid / tenant resolution failed
- `413` — `{ error: "payload_too_large", limit: 131072 }`
- `429` — `{ error: "evidence_validation_quota_exceeded", upgrade: "/pricing" }`

**Notes:** Dedup cache: identical `(tenant, content, policy)` within 1 hour returns cached `validationId` without consuming quota or writing a new audit row. Input hash is SHA-256 of normalized payload.

**Source:** `src/pages/api/v1/evidence/validate.ts`

---

### `POST /api/v1/evidence/gap-fill`

**Purpose:** Iterative evidence gap-fill loop — validate → match library assets → merge → LLM revise → re-validate. Pro-gated.

**Auth:** Session cookie or `Bearer ea_*`; **Pro/Team only** (402 otherwise)

**Request body:**
```ts
{
  content: ContentInput | string,
  policyVersion?: string,                    // default "google_november_2024_reputation"
  maxIterations?: number,                    // clamped 1–5, default 3
  targetPillars?: EvidencePillar[],
  assetPreferences?: {
    domains?: EvidenceDomain[],
    types?: EvidenceAssetType[]
  }
}
```
Max JSON payload: 128 KiB.

**Success responses:**
```ts
// 200 OK
{
  gapFillId: string,
  iterations: number,
  initialGaps: number,
  finalGaps: number,
  converged: boolean,        // true iff finalGaps === 0
  revised: ContentInput,
  iterationLog: Array<{
    iteration: number,
    gapsBefore: number, gapsAfter: number,
    assetsInjected: string[],
    llmCallCostEstimate: number,
    note?: string
  }>,
  creditsUsed: number,       // USD, accrued from canonical llm-providers TokenUsage.inputTokens/outputTokens
  gapFillHash: string,       // SHA-256 of canonical projection bound into v2.2 receipts (#115)
  bailReason?: "max_iterations" | "cost_ceiling" | "llm_bail" | "schema_drift"  // omitted if converged
}
```

**Error responses:**
- `400` — `{ error: "content is required" | "invalid_json" | "empty_library" | ... }`
- `401` — session invalid / tenant resolution failed
- `402` — `{ error: "evidence_gap_fill_requires_pro", upgrade: "/pricing" }`
- `413` — `{ error: "payload_too_large", limit: 131072 }`
- `429` — rate-limit (30/hr) OR `evidence_gap_fill_quota_exceeded`
- `502` — LLM provider misconfiguration, LLM failure, asset match DB failure, or `gap_fill_persist_failed`

**Source:** `src/pages/api/v1/evidence/gap-fill.ts`. Loop + persistence helpers live in `src/lib/evidence-gap-fill.ts` so `/attest` can run the same path with `runGapFill: true`.

**Notes:**
- Pro/team only (plan lookup via `user.orgId`).
- 30/hr per-tenant rate limit + `evidence_gap_fills` quota from edge-auth.
- $0.25 cost ceiling per request; LLM model = Cerebras GLM-4.7.
- Fast-path: if initial validation finds 0 gaps, returns immediately with no LLM spend.
- Asset matching: pillar→type heuristic, ordered by `usage_count ASC, created_at DESC`; up to 6 assets per iteration.
- **Persisted (#115):** every successful run writes an `evidence_gap_fills` row with the canonical iteration log + `gap_fill_hash`. The hash is the binding the v2.2 receipt commits to, and the row is what `getGapFillForPublicRender` re-hashes for the trust-page render.
- **Calibration telemetry (#95 item 1):** every run writes a summary row to `OBSERVE_DB.traces` with `worker_name = "internal:evidence-gap-fill"` and `trace_id = gapFillId`. `root_attrs` JSON captures iterations, gap counts, bail reason, and credits used. Hidden from user-facing Observe endpoints via `INTERNAL_WORKER_SQL_FILTER`. Fail-soft — telemetry errors are logged and swallowed. Per-iteration spans are deferred to item 6.

---

### `POST /api/v1/evidence/attest`

**Purpose:** Composite "survived adversarial review" pipeline. One call runs initial validate → critique + revise → optional gap-fill polish → final validate → signed publish receipt. Pro/Team only.

**Auth:** Session cookie or `Bearer ea_*`; **Pro/Team only** (402 otherwise)

**Request body:**
```ts
{
  content: ContentInput | string,
  publicPayload: Record<string, unknown>,    // tenant-authored projection returned by /verify
  policyVersion?: string,                    // default "google_november_2024_reputation"
  approvedPlan?: string[],                   // optional Collaborative Planning v2.1
  runGapFill?: boolean,                      // #115 — opt into v2.2 polish + binding
  gapFillOptions?: {
    maxIterations?: number,
    targetPillars?: EvidencePillar[],
    assetPreferences?: { domains?: string[], types?: string[] }
  }
}
```

**Success response (201):**
```ts
{
  receiptHash: string,                       // 64-hex HMAC; lookup key on trust.stackbilder.com/evidence/:hash
  verifyUrl: string, verifyJsonUrl: string,
  receiptVersion: "2" | "2.1" | "2.2",       // 2.2 when runGapFill bound; 2.1 with approvedPlan; 2 critique-only
  policyVersion: string,
  contentHash: string,
  publishedAt: number,
  revised: ContentInput,                     // post-pipeline content the receipt's HMAC binds
  planHash?: string,                         // present on v2.1+
  gapFillHash?: string,                      // present on v2.2 only
  gapFillSkipped?: "empty_library" | "loop_failed",  // runGapFill requested but stage skipped → falls through to v2.1/v2
  pipelineSummary: {
    initialGaps: number, finalGaps: number,
    attacksLogged: number, revisedDiffersFromInput: boolean,
    bailReasons: string[],
    gapFill?: { iterations, initialGaps, finalGaps, assetsInjected, bailReason? }
  },
  creditsUsed: number                        // sum of critique + (optional) gap-fill USD
}
```

**Error responses:**
- `400` — `{ error: "content is required" | "invalid_public_payload" | "invalid_approved_plan" | "Unknown evidence policy version ..." }`
- `401` — session invalid / tenant resolution failed
- `402` — `{ error: "evidence_attest_pro_required", upgrade: "/pricing" }`
- `413` — `{ error: "payload_too_large" | "public_payload_too_large", limit: ... }`
- `429` — `{ error: "evidence_attest_rate_limited" }` (20/hr) | `evidence_validations_quota_exceeded` | `evidence_gap_fills_quota_exceeded`
- `409` — `{ error: "receipt_conflict" }` (HMAC collision — vanishingly rare)
- `502` — `{ error: "attest_failed", at: "initial_validate" | "critique" | "critique_persist" | "final_validate" | "validation_persist" | "publish_insert" }` | `attest_critique_bailed`

**Quota cost:** 1 `evidence_validations` per call. With `runGapFill: true`, +1 `evidence_gap_fills`. Defense rate-limit is 20/hr per tenant; the LLM cost-multiplier of the polish pass is bundled into that allowance — no separate cap.

**Receipt versions:**
- `v2` (DB `receipt_version=2`) — critique only
- `v2.1` (DB `receipt_version=3`) — adds `planHash` from `approvedPlan`
- `v2.2` (DB `receipt_version=4`, **#115**) — adds `gapFillHash`. The matching `evidence_gap_fills` row stores the canonical iteration log; `getGapFillForPublicRender` re-hashes and compares before the trust page renders the section.

**Source:** `src/pages/api/v1/evidence/attest.ts`. Receipt primitives in `src/lib/evidence-receipts.ts`; gap-fill loop in `src/lib/evidence-gap-fill.ts`.

---

### `GET /api/v1/evidence/library`

**Purpose:** List tenant's evidence assets with optional filtering.

**Auth:** Session cookie or `Bearer ea_*`

**Query params:**
- `type` (optional) — one of: `case_study` | `customer_quote` | `expert_quote` | `original_visual` | `proprietary_data` | `first_hand_experience` | `technical_diagram` | `research_finding`
- `domain` (optional) — one of: `medical` | `legal` | `financial` | `technology` | `marketing` | `business` | `education` | `health_wellness` | `food` | `food_science` | `food_regulation` | `ecommerce` | `real_estate` | `automotive` | `general`
- `limit` (optional) — 1–100, default 20
- `cursor` (optional) — opaque pagination cursor from prior `nextCursor` response

**Success responses:**
```ts
// 200 OK
{
  assets: AssetResponse[],   // id, type, title, content, domains[], tags[], qualityScore, verificationStatus, authorName, authorBio, sourceUrl, usageCount, createdAt, updatedAt
  nextCursor?: string        // present if more results
}
```

**Error responses:**
- `400` — invalid type/domain enum or malformed cursor
- `401` — session invalid / tenant resolution failed

**Source:** `src/pages/api/v1/evidence/library/index.ts`

**Notes:** Tenant-scoped (per-resource scoping, `user.tenantId || user.orgId || user.id`). Cursor is base64-encoded `(createdAt, id)` tuple, DESC order.

---

### `POST /api/v1/evidence/library`

**Purpose:** Create a new evidence asset.

**Auth:** Session cookie or `Bearer ea_*`; **tier-gated** (Free: 0 cap, Pro/Team: 50 cap)

**Request body:**
```ts
{
  type: EvidenceAssetType,               // required
  title: string,                         // required, 10–200 chars
  content: Record<string, unknown>,      // required, opaque JSON
  domains: EvidenceDomain[],             // required, non-empty
  tags?: string[],
  qualityScore?: number | null,          // 0–100 or null
  verificationStatus?: "verified" | "unverified" | "pending" | "disputed",
  authorName?: string,
  authorBio?: string,
  sourceUrl?: string
}
```
Max JSON payload: 128 KiB.

**Success responses:**
- `201 Created` — `{ asset: AssetResponse }`

**Error responses:**
- `400` — `{ error: "invalid_json" | "invalid_input", errors?: [{ field, message }] }`
- `401` — session invalid / tenant resolution failed
- `402` — `{ error: "library_limit", tier, limit, current, upgrade: "/pricing" }`
- `413` — `{ error: "payload_too_large", limit: 131072 }`
- `502` — D1 batch insert failure

**Notes:** Post-insert capacity enforcement via atomic D1 batch — INSERT + COUNT + optional compensating DELETE. Safe for concurrent writers at cap boundary.

**Source:** `src/pages/api/v1/evidence/library/index.ts`

---

### `GET /api/v1/evidence/library/:id`

**Purpose:** Retrieve a single evidence asset.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:** `200 OK` — `{ asset: AssetResponse }`

**Error responses:** `400` invalid id | `401` | `404` (or cross-tenant — same response to avoid leaking existence)

**Source:** `src/pages/api/v1/evidence/library/[id].ts`

---

### `PUT /api/v1/evidence/library/:id`

**Purpose:** Partial or full update of an evidence asset.

**Auth:** Session cookie or `Bearer ea_*`

**Request body:** Same shape as POST, all fields optional.
Max JSON payload: 128 KiB.

**Success responses:** `200 OK` — `{ asset: AssetResponse }`

**Error responses:** `400` invalid input | `401` | `404` | `413` payload too large | `502` batch update failure

**Notes:** If `domains` change, join table is re-synced atomically. `updated_at` always refreshes.

**Source:** `src/pages/api/v1/evidence/library/[id].ts`

---

### `DELETE /api/v1/evidence/library/:id`

**Purpose:** Remove an evidence asset and its domain join rows.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:** `200 OK` — `{ id, deleted: true }`

**Error responses:** `400` | `401` | `404` | `502`

**Source:** `src/pages/api/v1/evidence/library/[id].ts`

---

## Trust Page

Slug→hash admin API that backs `trust.stackbilder.com/<slug>`. Ownership is **org-level** per split-by-policy contract. See AEGIS wiki `trust-page-governance-timeline-architecture` and `trust-bundle-storage-architecture`.

### `GET /api/trust/slugs`

**Purpose:** List all trust slugs owned by the caller's org.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:**
```ts
// 200 OK
{
  tenantId: string,   // historical name; semantically the orgId
  slugs: Array<{
    slug: string,
    current_hash: string,     // 64-char lowercase hex
    tenant_id: string,
    created_at: string,
    updated_at: string
  }>
}
```

**Notes:** Cross-tenant listing not supported.

**Source:** `src/pages/api/trust/slugs/index.ts`

---

### `POST /api/trust/slugs`

**Purpose:** Create or update a slug → receipt-hash mapping.

**Auth:** Session cookie or `Bearer ea_*`

**Request body:**
```ts
{
  slug: string,    // 1–64 lowercase alphanumeric chars, optional interior hyphens
  hash: string     // 64-char lowercase hex (SHA-256 receipt hash)
}
```

**Success responses:**
- `200 OK` — updated existing slug; returns row
- `201 Created` — created new slug; returns row

**Error responses:**
- `400` — malformed body, invalid slug format, or invalid hash format
- `401` — no auth
- `409` — `{ error: "...", code: "cross_tenant_conflict" }` — slug owned by a different org

**Example:**
```bash
curl -X POST https://stackbilder.com/api/trust/slugs \
  -H "Authorization: Bearer ea_YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"slug":"acme-corp","hash":"<64-char hex>"}'
```

**Source:** `src/pages/api/trust/slugs/index.ts`

**Notes:** Slug and hash normalized to lowercase. First-come, first-owned at the org level. Idempotent: same org re-POSTing the same slug updates `current_hash` + `updated_at`.

---

### `GET /api/trust/slugs/:slug`

**Purpose:** Fetch a single slug row if the caller's org owns it.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:** `200 OK` — single slug row

**Error responses:** `400` invalid slug | `401` | `404` (not found OR owned by another org — no existence-leak)

**Source:** `src/pages/api/trust/slugs/[slug].ts`

---

### `DELETE /api/trust/slugs/:slug`

**Purpose:** Remove a slug mapping.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:** `204 No Content`

**Error responses:**
- `400` invalid slug
- `401` no auth
- `403` `{ error, code: "cross_tenant_forbidden" }` — exists but owned elsewhere (explicit permission signal)
- `404` slug doesn't exist at all

**Source:** `src/pages/api/trust/slugs/[slug].ts`

---

### `GET /api/trust/bundle/:hash`

**Purpose:** List Trust Bundle artifact metadata for a receipt hash (bytes not included).

**Auth:** Session cookie or `Bearer ea_*`

**Path params:** `hash` — 64-char lowercase hex

**Success responses:**
```ts
// 200 OK
{
  receipt_hash: string,
  artifacts: Array<{
    receipt_hash, artifact_slug, tenant_id,
    content_hash,    // sha256 of the artifact bytes
    mime_type, byte_size,
    display_name, excerpt: string | null,
    signed: 0 | 1,
    created_at: string
  }>,
  count: number
}
```

**Notes:** Tenant-scoped. Cross-tenant receipts return an empty list (not 403).

**Source:** `src/pages/api/trust/bundle/[hash]/index.ts`

---

### `GET /api/trust/bundle/:hash/:slug`

**Purpose:** Fetch a single artifact's manifest row (metadata only).

**Auth:** Session cookie or `Bearer ea_*`

**Path params:** `hash` + artifact `slug`

**Success responses:** `200 OK` — single BundleArtifactRow

**Error responses:** `400` invalid | `401` | `404` (not found or cross-tenant)

**Notes:** Artifact bytes are served from the public route `/trust/:slug/bundle/:artifact_slug` (not the admin API).

**Source:** `src/pages/api/trust/bundle/[hash]/[slug].ts`

---

### `POST /api/trust/bundle/:hash/:slug`

**Purpose:** Upload or overwrite an artifact for a Trust Bundle.

**Auth:** Session cookie or `Bearer ea_*`

**Path params:** `hash` + artifact `slug`

**Request headers (required):**
- `Content-Type` — real MIME type of the artifact. Allowed: `application/pdf`, JSON (`application/json`, `application/ld+json`, `application/schema+json`), text (`text/plain`, `text/markdown`, `text/csv`), zip/xlsx, or legacy `application/vnd.ms-excel`.
- `X-Display-Name` — human-readable artifact name, max 120 chars.

**Request headers (optional):**
- `X-Excerpt` — one-paragraph card summary, max 500 chars.
- `X-Signed: true` — artifact embeds its own signature (e.g. signed PDF).

**Request body:** Raw artifact bytes, max 10 MiB. The API validates file signatures for PDFs, zip/xlsx, legacy XLS, JSON, and text-like formats before writing to R2.

**Success responses:**
- `200 OK` — updated — `{ row, content_hash, created: false }`
- `201 Created` — created — `{ row, content_hash, created: true }`

**Error responses:**
- `400` — invalid hash, invalid slug, missing/empty body, missing/oversized `X-Display-Name`, oversized `X-Excerpt`, or invalid `Content-Type`
- `401` — no auth
- `413` — artifact exceeds 10 MiB
- `409` — `{ error, code: "cross_tenant_conflict" }`
- `415` — unsupported MIME type or declared type does not match artifact bytes

**Known artifact slugs** (informational; not enforced): `posture-overview`, `stride-threat-model`, `data-flow`, `ir-plan`, `shared-responsibility`, `subprocessors`, `caiq-lite`, `oscal-json`.

**Notes:** R2 write occurs first (keyed `<hash>/<slug>`), then D1. Safe to retry — R2 puts are idempotent per key. `content_hash` is threaded into tarotscript receipt signing to enable tamper detection.

**Source:** `src/pages/api/trust/bundle/[hash]/[slug].ts`

---

### `DELETE /api/trust/bundle/:hash/:slug`

**Purpose:** Remove an artifact — deletes R2 object, then D1 manifest row.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:** `204 No Content`

**Error responses:**
- `403` — artifact exists, owned by another tenant
- `404` — not found (or invalid hash/slug format)

**Source:** `src/pages/api/trust/bundle/[hash]/[slug].ts`

---

## Scaffolder (Flows)

Stackbilder's original product — deterministic governed scaffold output optionally polished with LLM Oracle.

### `POST /api/flows`

**Purpose:** Create a new scaffold — classify intent, run scaffold-cast spread, optionally run Oracle polish.

**Auth:** Session cookie or `Bearer ea_*`

**Request body:**
```ts
{
  intention: string,       // required, non-empty
  project_type?: string,   // default "api"
  oracle?: boolean         // true to run Oracle LLM polish (Pro/Team only)
}
```

**Success responses:**
```ts
// 201 Created
{
  id: string,              // receipt hash
  classification: { pattern: string, confidence: string },
  traits: Record<string, string>,
  tier2_recommended: boolean,
  output: string,
  facts: Record<string, unknown>
}
```

**Error responses:** `400` | `401` | `429` quota exceeded with `upgrade: "/pricing"` | `502`

**Notes:** Consumes one `scaffolds` quota credit. Oracle runs only if `body.oracle === true` AND tier is pro/team. Oracle result persists to `SESSION` KV with 90-day TTL under key `oracle:<id>`.

**Source:** `src/pages/api/flows/index.ts`

---

### `GET /api/flows`

**Purpose:** List the user's scaffolds from the TarotScript grimoire.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:**
```ts
// 200 OK
{
  flows: Array<{
    id: string, intention: string,
    project_type: string,
    status: "completed",
    created_at: string
  }>
}
```

**Notes:** Filters grimoire by `spreadType: "ScaffoldCast" | "scaffold-cast"`. Gracefully returns empty array on upstream error.

**Source:** `src/pages/api/flows/index.ts`

---

### `GET /api/flows/:id`

**Purpose:** Full scaffold detail — governance, files, next steps, Oracle status.

**Auth:** Session cookie or `Bearer ea_*`

**Path params:** `id` — receipt hash

**Success responses:**
```ts
// 200 OK
{
  id, intention, project_type, status, created_at, seed,
  governance: { threat_model, adr, test_plan },
  scaffold:   { files: Array<{ path, content, role }> },
  next_steps: string[],
  output,
  oracle_enhanced: boolean,
  oracle_summary: string
}
```

File `role` values: `scaffold` | `config` | `governance` | `test` | `doc`.

**Error responses:** `401` | `404` | `502`

**Source:** `src/pages/api/flows/[id].ts`

---

### `GET /api/flows/:id/oracle`

**Purpose:** Retrieve persisted Oracle enhancement status/result for an existing scaffold.

**Auth:** Session cookie or `Bearer ea_*`

**Path params:** `id` — receipt hash

**Success responses:**
```ts
// 200 OK, not enhanced yet
{ enhanced: false }

// 200 OK, enhanced result persisted
{ enhanced: true, files, summary }
```

**Error responses:**
- `401` — Unauthorized

**Source:** `src/pages/api/flows/[id]/oracle.ts`

**Notes:** Reads `SESSION` KV key `oracle:<id>`. Does not enforce Pro/Team; it only reports whether an already-persisted result exists.

---

### `POST /api/flows/:id/oracle`

**Purpose:** Trigger LLM Oracle polish on an existing scaffold; persist enhanced files to KV.

**Auth:** Session cookie or `Bearer ea_*`; **Pro/Team only**

**Path params:** `id` — receipt hash

**Success responses:**
- `200 OK` — `{ enhanced: true, files, summary }`

**Error responses:**
- `401` — Unauthorized
- `403` — `{ error: "Oracle requires a Pro subscription", upgrade_url: "/pricing" }`
- `404` — flow not found
- `422` — flow has no prompt context (predates Oracle support)
- `502` — TarotScript or Oracle service error

**Source:** `src/pages/api/flows/[id]/oracle.ts`

**Notes:** Persists result to `SESSION` KV at `oracle:<id>` with 90-day TTL. Idempotent — returns cached result if already enhanced.

---

## Images

### `GET /api/images`

**Purpose:** List user's generated image jobs.

**Auth:** Session cookie or `Bearer ea_*`

**Query params:**
- `limit` (default 20), `offset` (default 0), `state` (optional filter, e.g. `completed`, `pending`)

**Success responses:**
```ts
// 200 OK
{ images: Array<{ id, prompt, quality_tier, status, image_url, created_at }> }
```

**Source:** `src/pages/api/images/index.ts`

---

### `POST /api/images/generate`

**Purpose:** Create a new image generation job.

**Auth:** Session cookie or `Bearer ea_*`

**Request body:**
```ts
{
  prompt: string,              // required
  quality_tier?: string,       // default "standard"
  negative_prompt?: string
}
```

**Success responses:**
```ts
// 201 Created
{ id, job_id, state, original_prompt, final_prompt, asset_url, created_at }
```

**Error responses:** `400` | `401` | `429` images quota exceeded with `upgrade: "/pricing"` | `502`

**Notes:** Consumes one `images` quota credit.

**Source:** `src/pages/api/images/generate.ts`

---

### `GET /api/images/:id`

**Purpose:** Retrieve single image job status.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:** `200 OK` — `{ id, prompt, quality_tier, status, image_url, error, created_at }`

**Source:** `src/pages/api/images/[id].ts`

---

### `DELETE /api/images/:id`

**Purpose:** Delete an image job (cascades to img-forge asset cleanup).

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:** `204 No Content`

**Error responses:** `401` | `404` | `409` conflict (e.g. still processing) | `502`

**Source:** `src/pages/api/images/[id].ts`

---

## Worker observability

Pro feature backed by [`@stackbilt/worker-observability`](/worker-observability) (Apache-2.0, installable standalone). See the [worker-observability docs](/worker-observability) for the OSS library and [Stackbilder Platform](/platform) for the hosted dashboard.

**Internal telemetry filter.** All user-facing read endpoints in this section (`/summary`, `/traces`, `/traces/:id`) apply `INTERNAL_WORKER_SQL_FILTER` from `src/lib/observe.ts` — `worker_name NOT LIKE 'internal:%'`. stackbilt-web writes internal calibration telemetry (e.g. evidence gap-fill runs per #95) directly to `OBSERVE_DB` using the `internal:*` prefix so those rows never surface as phantom workers in a tenant's Observe UI. If you add a new user-facing query that reads `traces`/`spans`/`logs` by `worker_name`, apply this filter.

### `POST /api/observe/ingest`

**Purpose:** Unified batch telemetry ingest — metrics, spans, logs, alerts — from `@stackbilt/worker-observability` consumers.

**Auth:** Session cookie or `Bearer ea_*`; **Pro-gated**

**Request body:**
```ts
{
  service: string,              // worker name (required)
  metrics?: MetricPoint[],      // { name, value, unit, timestamp, tags, type: "counter" | "gauge" | "histogram" | "summary" }
  spans?: TraceSpan[],          // { traceId, spanId, operationName, service, startTime, endTime, duration, status, attributes, events }
  logs?: LogEntry[],            // { timestamp, level: "debug" | "info" | "warn" | "error" | "fatal", message, context, error, metadata }
  alerts?: AlertIncident[]      // { id, rule: { name, severity }, status: "firing" | "resolved", startTime, endTime, value, message, metadata }
}
```

**Success responses:** `202 Accepted` — `{ ok: true }`

**Error responses:**
- `400` — missing `service` field, empty payload, or invalid JSON
- `401` — no auth
- `413` — payload exceeds 64 KB
- `403` — `{ error, tier, limit, upgrade }` — worker count cap reached for tier (Free 1 / Pro 5 / Team 20)
- `429` — `{ error, tier, dailyLimit, used, upgrade, retryable: false }` — daily event budget exhausted (Free 10K / Pro 500K / Team 2M per worker per day)
- `502` — DB failure

**Notes:** Retention: Free 24h / Pro 30d / Team 30d. Writes to `OBSERVE_DB` D1. Root spans (no `parentSpanId`) upserted to `traces`; all spans inserted to `spans`. All records include `expires_at` for TTL cleanup (hourly cron).

**Source:** `src/pages/api/observe/ingest.ts`

---

### `GET /api/observe/summary`

**Purpose:** Per-worker summary stats (error rate, p95 latency, request count) over a time range.

**Auth:** Session cookie or `Bearer ea_*`

**Query params:**
- `range` — `1h` | `6h` | `24h` (default) | `7d` | `30d`
- `worker` (optional) — filter to specific worker name

**Success responses:**
```ts
// 200 OK
{
  workers: Array<{
    worker_name, total_traces, error_count, error_rate,
    avg_duration_ms, p95_duration_ms, last_seen
  }>,
  range: string
}
```

**Notes:** p95 computed client-side (D1 lacks PERCENTILE_CONT).

**Source:** `src/pages/api/observe/summary.ts`

---

### `GET /api/observe/traces`

**Purpose:** Paginated trace list with filters.

**Auth:** Session cookie or `Bearer ea_*`

**Query params:**
- `range` — time window (default `24h`)
- `worker` (optional) — filter by worker
- `status` (optional) — `ok` | `error`
- `limit` (default 50, max 200), `offset` (default 0)

**Success responses:**
```ts
// 200 OK
{
  traces: Array<{ trace_id, worker_name, status, started_at, finished_at, duration_ms, error_msg }>,
  total: number
}
```

**Source:** `src/pages/api/observe/traces/index.ts`

---

### `GET /api/observe/traces/:id`

**Purpose:** Full trace detail with correlated spans + logs.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:**
```ts
// 200 OK
{
  trace: { ... },
  spans: Array<{ span_id, trace_id, parent_span_id, operation, service, start_time, end_time, duration_ms, status, attributes, events }>,
  logs:  Array<{ id, level, message, ts, error }>
}
```

**Error responses:** `400` missing id | `401` | `404`

**Source:** `src/pages/api/observe/traces/[id].ts`

---

### `GET /api/observe/alerts`

**Purpose:** List fired and resolved alert incidents.

**Auth:** Session cookie or `Bearer ea_*`

**Query params:**
- `status` (optional) — `firing` | `resolved`; omit for all

**Success responses:**
```ts
// 200 OK
{
  alerts: Array<{
    id, worker_name, rule_name, severity, status,
    message, value, started_at, ended_at
  }>
}
```

**Notes:** `ended_at` is null for active alerts. Returns up to 100 rows ordered by `started_at DESC`.

**Source:** `src/pages/api/observe/alerts.ts`

---

## Billing

**⚠️ Live-mode Stripe** (account `acct_1T8cxHL8cDQ0gdtT`) since 2026-04-11. All billing routes hit real customers.

### `POST /api/billing/checkout`

**Purpose:** Create a Stripe Checkout session. Two modes: legacy Pro tier, or SKU (CISO Trust Bundle / Hosting, CTO Consultation).

**Auth:** Session cookie or `Bearer ea_*`

**Request body:**
```ts
// Empty body → legacy Pro flow (uses STRIPE_PRO_PRICE_ID)
{}

// OR SKU flow:
{ productKey: "ciso-trust-bundle" | "ciso-trust-page-hosting" | "cto-consultation" }
```

**Success responses:** `200 OK` — `{ url: string }` (Stripe Checkout session URL)

**Error responses:**
- `400` — invalid productKey, returns `accepted: [...]`
- `401` — Unauthorized
- `409` — `{ error, code: "already_subscribed", currentTier }` (legacy Pro pre-flight only)
- `429` — `{ error: "Too many checkout attempts" }` (10/hr)
- `502` — upstream Stripe/edge-auth error

**SKU catalog (as of 2026-04-19):**

| productKey | Price | Mode |
|---|---|---|
| `ciso-trust-bundle` | $499 one-time | payment |
| `ciso-trust-page-hosting` | $149/mo | subscription |
| `cto-consultation` | gated / not priced | — |

CISO SKUs are invite-gated at the edge-auth layer (server-side `CISO_INVITE_ALLOWLIST_ORGS` secret).

**Source:** `src/pages/api/billing/checkout.ts`

---

### `POST /api/billing/portal`

**Purpose:** Create a Stripe Billing Portal session for subscription management.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:** `200 OK` — `{ url: string }`

**Error responses:**
- `401` — Unauthorized
- `422` — `{ error, code: "no_stripe_customer" }` — no Stripe customer (admin override, comp account, or lapsed sub)
- `502` — upstream error

**Source:** `src/pages/api/billing/portal.ts`

---

### `POST /api/billing/downgrade`

**Purpose:** Downgrade tenant to free tier. Handles active subscription (cancel at period end), admin override, or past-due.

**Auth:** Session cookie or `Bearer ea_*`

**Success responses:**
```ts
// 200 OK
{
  ok: boolean,
  previousTier: "free" | "pro" | "team",
  stripeAction: "canceled" | "no_subscription" | "already_canceled",
  effectiveAt: string,
  noop: boolean
}
```

- `canceled` — active Stripe sub scheduled for cancellation; tier stays until `effectiveAt`
- `no_subscription` — admin override or comp account; immediate tier flip
- `already_canceled` — reconciling a dangling `stripe_subscription_id`; immediate flip

**Error responses:**
- `400` — `"You're already on the free plan."` (short-circuit when tier is already free)
- `401` — Unauthorized
- `403` — `{ error: "Forbidden: ..." }` — ownership/role denial from edge-auth
- `429` — 5/hr rate limit
- `502` — upstream error

**Source:** `src/pages/api/billing/downgrade.ts`

**Notes:** Idempotent. Safe to call repeatedly.

---

### `GET /api/billing/promos`

**Purpose:** List all promotion codes (admin endpoint).

**Auth:** Session cookie

**Success responses:** `200 OK` — `{ codes: Array<{ id, code, percentOff, duration, maxRedemptions, timesRedeemed, active }> }`

**Source:** `src/pages/api/billing/promos.ts`

---

### `POST /api/billing/promos`

**Purpose:** Create a new promotion code.

**Auth:** Session cookie

**Request body:**
```ts
{
  code: string,
  percentOff: number,                                 // 1–100
  duration: "once" | "repeating" | "forever",
  durationInMonths?: number,
  maxRedemptions?: number
}
```

**Success responses:** `201 Created` — `{ id, code, couponId }`

**Error responses:** `400` invalid | `401` | `502`

**Notes:** Code is uppercased on submission.

**Source:** `src/pages/api/billing/promos.ts`

---

### `DELETE /api/billing/promos/:id`

**Purpose:** Revoke a promo code.

**Auth:** Session cookie

**Success responses:** `204 No Content`

**Error responses:** `401` | `502`

**Source:** `src/pages/api/billing/promos/[id].ts`

---

## Marketing & support

### `POST /api/scaffold/preview`

**Purpose:** Anonymous scaffold preview (Phase 1 only — no LLM, deterministic). Used by the public homepage hero.

**Auth:** None (rate-limited by IP)

**Request body:**
```ts
{ intention: string }
```

**Success responses:**
```ts
// 200 OK
{
  classification: { pattern: string, confidence: string },
  traits: Record<string, string>,
  tier2_recommended: boolean,
  governance: { threat_model, adr, test_plan },
  files: string[]
}
```

**Error responses:** `400` missing/empty intention | `429` 10/min per IP | `502` upstream TarotScript

**Source:** `src/pages/api/scaffold/preview.ts`

---

### `POST /api/contact`

**Purpose:** Public contact form → Resend email to admin@stackbilt.dev.

**Auth:** None (rate-limited)

**Request body:** `{ email: string, message: string (10+ chars) }`

**Success responses:** `200 OK` — `{ ok: true }`

**Error responses:** `400` invalid | `429` 3/hr per IP | `502` Resend error | `503` Resend not configured

**Source:** `src/pages/api/contact.ts`

---

### `POST /api/subscribe`

**Purpose:** Newsletter signup → Resend audience.

**Auth:** None (rate-limited)

**Request body:** `{ email: string }`

**Success responses:** `200 OK` — `{ ok: true }`

**Error responses:** `400` invalid email | `429` 5/hr per IP | `502` Resend error

**Source:** `src/pages/api/subscribe.ts`

**Notes:** Gracefully accepts signup even if Resend not configured (returns 200). Sends welcome email to subscriber + admin notification.

---

### `POST /api/support/tickets`

**Purpose:** In-app bug/support ticket. Auto-triaged via TarotScript `triage-cast` spread.

**Auth:** Session cookie

**Request body:**
```ts
{
  message: string,        // 10–5000 chars
  url?: string,
  userAgent?: string
}
```

**Success responses:** `200 OK` — `{ ok: true, triage: { category?, urgency? } }`

**Error responses:** `400` invalid | `401` | `429` 5/hr per user | `502` Resend delivery failed

**Source:** `src/pages/api/support/tickets.ts`

**Notes:** TarotScript classifies category, urgency, sentiment, complexity, and escalation flag. Email sent to admin@stackbilt.dev with full classification. Best-effort — delivers ticket even if classification fails.

---

## Telemetry

### `POST /api/csp-report`

**Purpose:** Public CSP violation report endpoint. Logs to console, persists to `OBSERVE_DB` with 30-day retention.

**Auth:** None

**Request body:** Browser-standard CSP report shape (document-uri, violated-directive, etc.)

**Success responses:** Always `204 No Content` (swallows all errors)

**Notes:** Visible via `wrangler tail`. Filters reports missing document-uri or violated-directive (ignores scanner garbage).

**Source:** `src/pages/api/csp-report.ts`

---

### `POST /api/errors`

**Purpose:** Client-side error telemetry (from React ErrorBoundary components) → Worker console.

**Auth:** None

**Request body:** `{ type?, component?, message?, url?, timestamp? }`

**Success responses:** `204 No Content`

**Error responses:** `413` payload exceeds 8 KB

**Notes:** Truncates `message` and `url` to 500 chars.

**Source:** `src/pages/api/errors.ts`

---

## MCP server

### `POST /api/mcp` / `GET /api/mcp`

**Purpose:** JSON-RPC 2.0 MCP server exposing admin Cloudflare tools (analytics, inventory, cost forecasting).

**Auth:**
- `POST` — Session cookie or `Bearer ea_*`, admin-only
- `GET` — Public (tool discovery)

**POST request body:**
```ts
{
  jsonrpc: "2.0",
  id: number | string | null,
  method: "initialize" | "tools/list" | "tools/call" | "ping" | "notifications/initialized",
  params?: {
    name?: string,                      // for tools/call
    arguments?: Record<string, unknown> // for tools/call
  }
}
```

**POST success:**
```ts
{
  jsonrpc: "2.0",
  id: ...,
  result: { /* method-dependent; tools/call returns { content: [{ type: "text", text }], isError? } */ }
}
```

**JSON-RPC error codes:**
- `-32700` parse error | `-32600` invalid request | `-32601` method not found | `-32602` invalid params | `-32000` unauthorized

**Tools available:** `cf_worker_analytics`, `cf_resource_inventory`, `cf_cost_estimate`, `cf_cost_forecast`

**Rate limits:** 10/min (analytics, inventory, estimate); 5/min (forecast)

**Source:** `src/pages/api/mcp/index.ts`

**Notes:** Server info — name=`stackbilt-cf-admin`, version=0.1.0, protocolVersion=2024-11-05. Each tool backed by 5-min KV cache to bound CF API cost.

---

## Admin

All admin routes require a session with an admin user (`admin@stackbilt.dev` or equivalent). Admin check lives in `src/lib/auth.ts::isAdmin`.

### `GET /api/admin/cf/inventory`

**Purpose:** List all Cloudflare resources (Workers, D1, R2, KV) owned by the configured account.

**Auth:** Admin-only

**Success responses:**
```ts
// 200 OK
{
  configured: true,
  inventory: {
    workers:     string[],
    d1Databases: Array<{ name, uuid }>,
    r2Buckets:   string[],
    kvNamespaces: Array<{ title, id }>,
    counts: { workers, d1, r2, kv }
  }
}
```

**Graceful error:** `200 OK { configured: false, message, inventory: null }` when CF integration not configured.

**Error responses:** `401` | `403` not admin | `502` CF API error

**Notes:** Env vars: `CF_ANALYTICS_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN` (falls back to CF_ANALYTICS_TOKEN). Uses 4 parallel CF REST calls. KV-backed cache, 5-min TTL.

**Source:** `src/pages/api/admin/cf/inventory.ts`

---

### `GET /api/admin/cf/cost-estimate`

**Purpose:** Estimate monthly Cloudflare cost from a 1–30 day worker-request sample.

**Auth:** Admin-only

**Query params:** `days` (optional, 1–30, default 7)

**Success responses:**
```ts
// 200 OK
{
  configured: true,
  estimate: {
    period: string,
    dailyRequests, monthlyRequests,
    freeTier: Array<{ resource, used, limit, unit, pctUsed, overage, estimatedCost }>,
    totalEstimatedMonthlyCost: number,
    note: string
  }
}
```

**Source:** `src/pages/api/admin/cf/cost-estimate.ts`

**Notes:** Only Worker Requests wired up; D1/R2/KV cost constants exist but CF billing API returns 403. 5-min KV cache per `(accountId, days)`.

---

### `GET /api/admin/cf/forecast`

**Purpose:** Cost forecast over 7/14/30-day rolling windows.

**Auth:** Admin-only

**Success responses:** `200 OK` — `{ configured: true, forecast: { window7d, window14d, window30d } }`

**Notes:** Fan-out to 3 GraphQL calls — 5-min internal KV cache prevents repeat work. MCP-layer rate limit is **5/min** (not 10) due to expense.

**Source:** `src/pages/api/admin/cf/forecast.ts`

---

### `GET /api/admin/cf/worker-analytics`

**Purpose:** Top 50 Workers by request volume over 1–30 days, with error counts and CPU time.

**Auth:** Admin-only

**Query params:** `days` (optional, 1–30, default 7)

**Success responses:**
```ts
// 200 OK
{
  configured: true,
  days: number,
  workers: Array<{ scriptName, requests, errors, cpuTimeMs }>
}
```

**Source:** `src/pages/api/admin/cf/worker-analytics.ts`

**Notes:** GraphQL `workersInvocationsAdaptive`, filtered by `datetime_gt`, ordered by `sum_requests_DESC`. 5-min KV cache.

---

### `GET /api/admin/export-scaffolds`

**Purpose:** Bulk export scaffold flow data (grimoire readings + receipts + Oracle enhancements) for audit and recursive improvement.

**Auth:** Admin-only (session cookie or `ea_*`)

**Success responses:**
```ts
// 200 OK
// Content-Disposition: attachment; filename="scaffold-export-YYYY-MM-DD.json"
{
  count: number,
  scaffolds: Array<{
    id, intention, classification, projectType,
    governance: { threatModel, adr, testPlan },
    files: Array<{ path, content, role }>,
    oracleEnhanced: boolean,
    oracleFiles: [...],
    oracleSummary,
    seed, createdAt
  }>
}
```

**Error responses:** `401` | `403` not admin | `500` upstream | `502` KV read error

**Source:** `src/pages/api/admin/export-scaffolds.ts`

**Notes:** Iterates all scaffolds in tarotscript grimoire (`/grimoire/<userId>?limit=100`), fetches full receipts, merges Oracle data from `SESSION` KV under `oracle:<hash>`. Uses `Promise.allSettled` — skips failed receipt fetches.

---

## Appendix

### Related docs

- [Stackbilder Platform](/platform) — 6-mode pipeline, governance tiers, scaffold engine
- [MCP Gateway](/mcp) — OAuth-authenticated agent access to the same backend workers
- [TarotScript Runtime](/tarotscript) — deterministic scaffold and agent consultation engine
- [img-forge API](/img-forge) — image generation REST API and MCP tools
- [evidence-core](/evidence-core) — OSS E-E-A-T validation library powering the Evidence Engine
- [audit-chain](/audit-chain) — OSS tamper-evident audit log backing the Trust Page
- [worker-observability](/worker-observability) — OSS monitoring library for Cloudflare Workers
- [Security](/security) — supply chain controls, MCP tool risk classification, vulnerability reporting
- [Charter CLI](/getting-started) — governance CLI that integrates with this API
- [Ecosystem](/ecosystem) — full overview of all Stackbilt tools
