---
title: "edge-auth"
description: "Stackbilt auth and payment worker — session/API-key validation, Stripe billing, entitlements, and quota. RPC-based service binding consumed by all platform workers."
section: "platform"
order: 26
color: "#f43f5e"
tag: "26"
lastVerified: "2026-06-28"
---

# edge-auth

**GitHub:** Stackbilt-dev/edge-auth (private) · TypeScript

The auth and payment worker for the [Stackbilt ecosystem](/ecosystem). All session validation, API key checks, billing flows, and entitlement reads across the platform route through edge-auth via Cloudflare service binding RPC — no other worker holds Stripe credentials or manages auth state directly.

Powered by [Better Auth](https://better-auth.com) + D1. OAuth 2.1, SSO, and API key auth supported.

---

## Auth

### Session Validation

Two paths in `validateSession()`:

1. **Session cookie** — `better-auth.session_token` (dev) / `__Secure-better-auth.session_token` (prod) → validated via RPC
2. **API key** — `Authorization: Bearer ea_*` → `validateApiKey()` RPC

Edge auth middleware runs at the nearest Cloudflare POP via the `AUTH_SERVICE` service binding — no origin round-trip for auth checks.

### API Keys

API keys use the `ea_*` prefix. Each key resolves to a `userId`, `orgId`, and `plan` tier. Callers can use `GET /api/account/me` on the platform API to retrieve caller identity — useful for tier-aware routing in CI scripts and agent workflows.

img-forge API keys use the `imgf_*` prefix and are validated via a separate RPC path on the same service.

---

## RPC Interface

All consumers (stackbilt-web, img-forge, tarotscript, codebeast) reach edge-auth via Cloudflare service binding, not HTTP. The binding is `AUTH_SERVICE`.

Key RPC methods:

| Method | Description |
|--------|-------------|
| `validateSession(cookie)` | Validate a session cookie, return user + plan |
| `validateApiKey(key)` | Validate an `ea_*` or `imgf_*` API key, return user + plan |
| `getEntitlements(userId)` | Return current plan tier, feature flags, quota state |
| `createCheckoutSession(userId, plan)` | Create a Stripe Checkout URL for plan upgrade |
| `createPortalSession(userId)` | Create a Stripe Billing Portal URL |
| `downgradeToFree(userId)` | Cancel active subscription; returns `canceled`, `no_subscription`, or `already_canceled` |

---

## Billing

Stripe is in **live mode** (`acct_1T8cxHL8cDQ0gdtT`). All Stripe API calls live in edge-auth — consuming workers hold no Stripe credentials.

### Checkout Flow

`createCheckoutSession()` performs a pre-flight `getEntitlements()` check and returns `409 {code: "already_subscribed"}` if the tenant is already on a paid tier. Otherwise returns a Stripe Checkout URL.

### Portal Flow

`createPortalSession()` returns a Stripe Billing Portal URL. Returns `422` with actionable copy if the tenant has no Stripe customer record (comp/admin/lapsed accounts).

### Downgrade Flow

`downgradeToFree()` has three outcomes:

| Outcome | Meaning |
|---------|---------|
| `canceled` | Active subscription scheduled to cancel at period end; tier stays Pro/Agency until `effectiveAt` |
| `no_subscription` | Admin/comp account; immediate tier flip |
| `already_canceled` | Dangling `stripe_subscription_id`; immediate tier flip |

Stripe webhooks are handled entirely by edge-auth — there is no webhook handler in any consuming worker.

---

## Storage

- **D1** — user records, session state, API key metadata, subscription state
- **KV** — rate-limit state, entitlement cache

---

## Auth Flow (OAuth)

OAuth sign-in (GitHub, Google) is handled at `auth.stackbilt.dev`. On completion, a session cookie is issued and the user is redirected back to the originating platform.

SSO is available on Pro and Agency tiers.

---

## Consumers

| Worker | Binding | Uses |
|--------|---------|------|
| [stackbilt-web](/stackbilt-web) | `AUTH_SERVICE` | Session/API key validation, billing, entitlements |
| [img-forge](/img-forge) | `AUTH_SERVICE` | `imgf_*` key validation, quota |
| [tarotscript](/tarotscript) | *(via platform routing)* | Plan-tier enforcement |
| [codebeast](/codebeast) | `AUTH_SERVICE` | Identity on review sessions |
