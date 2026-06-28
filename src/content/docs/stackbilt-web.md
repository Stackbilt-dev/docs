---
title: "stackbilt-web"
description: "Unified Stackbilder platform frontend — Astro 6 + React islands on Cloudflare Workers. Powers stackbilder.com."
section: "platform"
order: 6
color: "#a78bfa"
tag: "06"
lastVerified: "2026-06-28"
---

# stackbilt-web

**GitHub:** [Stackbilt-dev/stackbilt-web](https://github.com/Stackbilt-dev/stackbilt-web) (private) · TypeScript

The Astro 6 + React islands frontend that powers [stackbilder.com](/platform). Part of the [Stackbilt ecosystem](/ecosystem) — the user-facing surface that composes [TarotScript](/tarotscript) (scaffold + agents), [img-forge](/img-forge) (image generation), [worker-observability](/worker-observability) (Observe dashboard), and [evidence-core](/evidence-core) (Trust Verifier) via Cloudflare service bindings.

---

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | Astro 6 (SSR, Cloudflare adapter) |
| UI | React 19 islands |
| Styling | Tailwind CSS (`ind-*` design tokens) |
| Runtime | Cloudflare Workers + D1 + KV + R2 |
| Auth | edge-auth (service binding RPC) |
| Types | TypeScript throughout |

---

## Architecture

**Island discipline** — one React island per complex page; Astro components for everything else. Server Islands stream personalized content (credit balance, recent activity) without client-side fetch.

**Route tiers:**

| Tier | Routes | Auth |
|------|--------|------|
| Public SSR / prerendered | `/`, `/pricing`, `/login`, `/register` | None |
| Anonymous preview | `POST /api/scaffold/preview` | None (TarotScript Phase 1) |
| Authenticated app | `/dashboard`, `/flows/*`, `/images/*`, `/observe`, `/settings` | Session cookie or `Bearer ea_*` |
| Trust verifier | `trust.stackbilder.com/…` | Public read |

Edge auth middleware validates sessions at the nearest POP via `AUTH_SERVICE` RPC — no origin round-trip.

---

## Domain Strategy

| Domain | Service | Repo |
|--------|---------|------|
| `stackbilder.com` | Platform frontend (this repo) | stackbilt-web |
| `api.stackbilt.dev` | Backend API | edgestack-v2 *(deprecated)* |
| `auth.stackbilt.dev` | Auth + billing | [edge-auth](/edge-auth) |
| `docs.stackbilt.dev` | Documentation | [Stackbilt-dev/docs](https://github.com/Stackbilt-dev/docs) |
| `blog.stackbilt.dev` | Blog | [roundtable](/roundtable) |
| `trust.stackbilder.com` | Trust page verifier | stackbilt-web (subdomain) |
| `mcp.stackbilt.dev/mcp` | MCP gateway | stackbilt-mcp-gateway |

---

## Tools

| Tool | Routes | Tier |
|------|--------|------|
| **Stackbilder** — scaffold generator | `/flows/*`, hero preview | Free + Pro |
| **[img-forge](/img-forge)** — multi-provider AI images | `/images/*` | Free + Pro |
| **Observe** — [worker observability](/worker-observability) | `/observe`, `/api/observe/*` | Pro |
| **Consultations** — CTO + CISO AI advisors | `/agents/{cto,ciso}` | Pro (dogfood-gated) |
| **Operator Playbooks** | `/app/playbooks` | Pro |
| **Trust Verifier** | `trust.stackbilder.com/…` | Public |

Sidebar groups: **Build** (Flows, Images) · **Operate** (Observe, Playbooks) · **Advise** (CISO, CTO).

---

## Service Bindings

| Binding | Service | Purpose |
|---------|---------|---------|
| `AUTH_SERVICE` | edge-auth | Session/API-key validation, billing, entitlements |
| `TAROTSCRIPT` | tarotscript-worker | Default/CISO agent runtime + scaffold/Oracle engine |
| `IMG_FORGE` | img-forge-gateway | AI image generation |
| `CODEBEAST` | codebeast | Code review + signed `/decide` receipts (Trust Page) |
| `OBSERVE_DB` | D1: stackbilt-observe | Worker observability telemetry |
| `TRUST_DB` | D1: stackbilt-trust | Trust page publications + evidence receipts |
| `AGENT_RECEIPTS_DB` | D1: stackbilt-agent-receipts | First-party local agent runtime receipts |
| `EVIDENCE_DB` | D1: stackbilt-evidence | Evidence library assets |
| `TRUST_BUNDLES` | R2: trust-bundles | Trust Bundle storage |
| `SESSION` | KV | Rate-limit state + Oracle result caching |

Bindings accessed via `getEnv()` in `src/lib/bindings.ts`. Do not use `locals.runtime.env` — removed in Astro v6.

---

## Auth

Two paths in `validateSession()` (`src/lib/auth.ts`):

1. **API key** — `Authorization: Bearer ea_*` → `AUTH_SERVICE.validateApiKey()` RPC
2. **Session cookie** — `better-auth.session_token` (dev) / `__Secure-better-auth.session_token` (prod) → `AUTH_SERVICE.validateSession()` RPC

---

## Billing

Stripe is in **live mode** as of 2026-04-11 (`acct_1T8cxHL8cDQ0gdtT`). All Stripe API calls live in edge-auth — stackbilt-web holds no Stripe credentials and reaches billing exclusively via `AUTH_SERVICE` RPC.

**Flows:**

- **Checkout** — `POST /api/billing/checkout` → pre-flight `getEntitlements()` check returns 409 `{code: "already_subscribed"}` for paid tiers → `AUTH_SERVICE.createCheckoutSession()` → Stripe Checkout URL.
- **Portal** — `POST /api/billing/portal` → `AUTH_SERVICE.createPortalSession()` → Stripe Billing Portal URL. Returns 422 with actionable copy if the tenant has no Stripe customer (comp/admin/lapsed).
- **Downgrade** — `POST /api/billing/downgrade` → `AUTH_SERVICE.downgradeToFree()` → three outcomes:
  - `canceled` — active sub scheduled to cancel at period end; tier stays Pro/Team until `effectiveAt`
  - `no_subscription` — admin/comp account; immediate tier flip
  - `already_canceled` — dangling `stripe_subscription_id`; immediate tier flip

Webhooks are handled entirely by **edge-auth** — there is no webhook handler in this repo.

Upgrade surfaces (`/pricing`, `/dashboard`, `/settings`, `UsageCard`) POST directly to `/api/billing/checkout` for authed Free users. `/pricing` SSR-branches CTAs on session state: anonymous → signup, authed Free → direct checkout, authed on current tier → disabled "Current plan" badge.

---

## Security

### Headers

Middleware (`src/middleware/index.ts`) sets on all responses:

| Header | Value |
|--------|-------|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `Content-Security-Policy-Report-Only` | Full policy; `report-uri /api/csp-report` |

CSP is currently **Report-Only**. Flip to enforcing `Content-Security-Policy` after a clean 24–48h window. Policy allows `'self'`, GA4, Cloudflare Analytics, and Google Fonts. `img-src` is permissive (`https:`) until all image origins are audited.

`POST /api/csp-report` logs browser-reported violations to `console.error` (visible via `wrangler tail`).

### Asset Proxy

`/v2/assets/[...path]` proxies authenticated img-forge asset requests:

- Rejects paths containing `..` or `\` (400)
- Requires `validateSession()` (401 for unauthenticated)
- `Cache-Control: private, max-age=3600` (no cross-identity edge caching)

The `/img-forge` showcase page bypasses the proxy — images resolve at SSR time via the service binding as base64 data URIs so anonymous visitors can see the gallery.

---

## Evidence Engine (Pro)

The hosted Evidence Engine wraps [`evidence-core`](/evidence-core) with D1-backed storage, a gap-fill LLM loop, tamper-evident receipts, and a Pro-gated UI. OSS library docs are in [evidence-core](/evidence-core); this section covers only the stackbilt-web layer.

### Routes

| Route | Purpose |
|-------|---------|
| `/app/evidence` | Workspace — compose, attest, manage drafts |
| `/app/evidence/compose` | Lazy-human pipeline: validate → gap-fill → attest |
| `/app/evidence/library` | Asset CRUD (Pro-gated; free → `/pricing?gate=evidence-library`) |
| `/api/v1/evidence/*` | REST API backing all three UI surfaces |

### Pipeline

Compose → gap-fill → attest → trust page:

1. **Validate** — `evidence-core` scores content 0–100 against the selected Google policy version; detects gaps per EEAT pillar.
2. **Gap-fill** — LLM polish loop (shared helper `src/lib/evidence-gap-fill.ts`). Injects library assets, redrafts, re-validates. Each run costs 1 `evidence_gap_fills` reservation. Monthly cap: 50 runs/mo for Pro/Team; free tier is gate-closed.
3. **Attest** — creates an `evidence_publications` row with a `receipt_version` hash chain. `/api/v1/evidence/attest` accepts `runGapFill: true` to merge steps 2 + 3 in one call.
4. **Trust page** — verifiable at `trust.stackbilder.com/evidence/:hash`. Re-hashes the row on render; surfaces as `tampered` on mismatch.

### Receipt versions

| Version | Product label | Adds |
|---------|--------------|------|
| v1 | — | Baseline |
| v2 | — | `critique_hash` |
| v3 | v2.1 | `plan_hash` (Collaborative Planning) |
| v4 | v2.2 | `gap_fill_hash` binding the gap-fill pass |

Unknown receipt versions surface as `tampered` — never silently downgrade to v1. See `src/lib/evidence-receipts.ts:verifyRow`.

### Evidence library

Pro-gated (free → `/pricing?gate=evidence-library`). Dogfood users on free-tier org get the Pro cap. Asset `content` shape: `{ text: "..." }` for all 8 types.

| Tier | Asset cap |
|------|-----------|
| Free | 0 |
| Pro | 50 |
| Team | 50 |

`LIBRARY_ASSET_LIMITS` in `src/lib/evidence-library.ts` is the single source of truth.

### Domain vocabulary

Evidence library assets are tagged with a domain. Food content uses three:

| Tag | Covers |
|-----|--------|
| `food` | Recipes, cuisine, food history, grocery content, creator-facing food narratives |
| `food_science` | Flavor chemistry, nutrition, food technology, academic research |
| `food_regulation` | FDA/USDA/CFR citations, labeling law, food-safety regulation |

### Internal telemetry

Gap-fill runs write a trace row to `OBSERVE_DB` under the `internal:evidence-gap-fill` worker name. The `INTERNAL_WORKER_SQL_FILTER` prevents these rows from surfacing in tenant Observe UIs.

---

## Observe (Pro)

The Observe dashboard wraps [`worker-observability`](/worker-observability) with D1-backed storage and a Pro-gated live UI. OSS client docs are in [worker-observability](/worker-observability); this section covers the server side.

### ODD architecture

Three pillars define the D1 schema and query surfaces:

| Pillar | Purpose | Tables |
|--------|---------|--------|
| **Observability** | Execution-level visibility | `traces`, `metrics` |
| **Debugging** | Causal trace + log correlation | `spans`, `logs` |
| **Diagnostics** | Failure patterns + alerting | `alert_incidents` |

Two cost-guard tables: `registered_workers` (worker cap) and `ingest_quotas` (daily event budget).

### COGS containment

D1 writes cost $1.00/M rows; each user request generates ~10 rows. Caps enforced at ingest:

| Tier | Workers | Events/day/worker | Retention | Worst-case COGS |
|------|---------|-------------------|-----------|-----------------|
| Free | 1 | 10K | 24h | ~$0.10/mo |
| Pro ($29) | 5 | 500K | 30d | ~$15/mo |
| Team ($99) | 20 | 2M | 30d | ~$60/mo |

`checkAndRegisterWorker()` returns 403 on worker cap; `checkAndIncrementEventBudget()` returns 429 on daily budget exceeded. Caps are defined in `TIER_LIMITS` in `src/lib/observe.ts`.

### API endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/observe/ingest` | Unified batch ingest: `{ service, metrics?, spans?, logs?, alerts? }`. Pro-gated. 64KB limit. |
| `GET` | `/api/observe/summary` | Per-worker stats: error rate, p95, request count |
| `GET` | `/api/observe/traces` | Paginated trace list with filters |
| `GET` | `/api/observe/traces/:id` | Trace detail with spans + correlated logs |
| `GET` | `/api/observe/alerts` | Alert incidents list |

All read endpoints apply `INTERNAL_WORKER_SQL_FILTER` (`worker_name NOT LIKE 'internal:%'`) — internal rows never appear in tenant UIs. Any new Observe query touching `traces`/`spans`/`logs` by worker_name **must** apply this filter.

### Retention

Hourly cron trigger → `src/worker.ts:handleScheduled()` batch-deletes expired rows across all 5 telemetry tables (cap: 10K deletes per table per run). All rows carry `expires_at` for tier-aware TTL.

---

## Consultations (CTO + CISO)

CTO and CISO AI advisors. Live as of 2026-04-20, Pro + dogfood-gated.

### Route tree

`/agents/[role]` is the canonical public entry point. It resolves auth and entitlement, then redirects:

| State | Redirect |
|-------|---------|
| Entitled (Pro/Team/dogfood) | `/app/consult/[role]` |
| Unauthenticated | `/consult/[role]` |
| Authenticated but not entitled | `/consult/[role]?gate=<reason>` |

`/app/consult/[role]` is the authenticated session UI. `/consult/[role]` is the public marketing/gate page. `/agents/[role]` should be used in all external links — it handles the redirect logic so the destination stays stable as entitlement rules change.

### Sidebar

Consultations is one tools registry entry (`src/lib/tools.ts`) but renders as two sidebar leaves under **Advise**: CISO and CTO, each pointing to `/agents/ciso` and `/agents/cto` respectively.

---

## Development

```bash
pnpm dev              # Local dev (Astro + workerd)
pnpm build            # Production build
pnpm deploy           # Build + deploy to Cloudflare
pnpm typecheck        # tsc --noEmit
```

Local dev requires a valid Cloudflare auth token (Wrangler remote proxy). If the dev server is slow, deploy to preview instead — `pnpm deploy` is faster in practice.

Secrets are managed via `wrangler secret put`. Each secret rotation triggers a worker redeploy — plan secret rotations accordingly.

---

## Testing

Playwright E2E against production (`stackbilder.com`). Two browser projects: `chromium` (1280×800) and `mobile` (390×844).

| Suite | Command | Coverage |
|-------|---------|----------|
| All | `pnpm test` | Full suite |
| Hero | `pnpm test:hero` | Scaffold flow + error states |
| Hero evals | `pnpm test:hero-evals` | Deterministic quality gate |
| Navigation | `pnpm test:nav` | Navigation, SEO, 404, OG tags |
| Funnel | `pnpm test:funnel` | Signup → paid conversion |
| Visual | `pnpm test:visual` | Golden screenshot regression |
| API key | `pnpm test:api-key` | API key auth (needs `STACKBILT_API_KEY` env) |

Run `pnpm test:update-snapshots` after any intentional visual change.

---

## Key Conventions

**Scaffold starter presets** — `/flows/new` accepts `?starter=<key>` to pre-fill the CreateFlow form. Keys: `saas_api`, `dashboard_app`, `ai_chatbot`, `edge_api`. Used by the dashboard welcome grid, RecentActivity empty state, and CreateFlow chips row.

**Evidence receipts** — `evidence_publications.receipt_version` is versioned (v1–v4 / "v2.2"). Unknown versions surface as `tampered`, never silently downgrade. See `src/lib/evidence-receipts.ts`.

**Internal observability writes** — stackbilt-web writes calibration telemetry to `OBSERVE_DB` using the `internal:*` worker-name prefix so internal rows never appear in tenant Observe UIs. Apply `INTERNAL_WORKER_SQL_FILTER` to any new user-facing Observe query.
