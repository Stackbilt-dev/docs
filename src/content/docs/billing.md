---
title: "Billing & Subscriptions"
description: "Stripe-powered billing for Stackbilt services. Checkout sessions, customer portal, tier management, and webhook-driven subscription lifecycle."
section: "platform"
order: 11
color: "#10b981"
tag: "11"
---

# Billing & Subscriptions

Stackbilt uses Stripe for all billing. Subscriptions are managed through edge-auth (`auth.stackbilt.dev`), which acts as the centralized billing gateway for every project in the platform.

## Plan Tiers

Flat pricing. No credits, no tokens, no per-action charges.

| | Free | Pro | Team |
|---|---|---|---|
| **Price** | $0 | $29/mo | $19/seat/mo |
| **Scaffolds/mo** | 3 | 50 | 50/seat |
| **Images/mo** | 5 | 100 | Pooled |
| **Phase 1 (deterministic)** | Yes | Yes | Yes |
| **Phase 2 (LLM polish)** | Yes | Yes | Yes |
| **Quality tiers (img-forge)** | Draft-Premium | All 5 | All 5 |
| **Stacks** | Cloudflare Workers | All supported | All supported |
| **Governance output** | Yes | Yes | Yes |

Every plan includes full governance output (threat analysis, ADRs, test plans) with every scaffold.

## Checkout Flow

### How It Works

1. User clicks "Upgrade to Pro" on `stackbilder.com/pricing`
2. The frontend calls `POST /billing/checkout` on edge-auth with the Stripe price ID
3. Edge-auth creates a Stripe Checkout session with the org's customer ID
4. User is redirected to Stripe's hosted checkout page
5. After successful payment, Stripe sends a `checkout.session.completed` webhook
6. Edge-auth updates the tenant's tier and provisions new entitlements

### REST API

```
POST https://auth.stackbilt.dev/billing/checkout
```

Requires an authenticated session with org-level `create` access.

**Request body:**

```json
{
  "orgId": "org_stackbilt",
  "priceId": "price_xxx",
  "projectId": "prop_stackbilder",
  "tenantId": "tenant-uuid",
  "successUrl": "https://stackbilder.com/settings?checkout=success",
  "cancelUrl": "https://stackbilder.com/pricing"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `orgId` | string | Yes | Organization to bill |
| `priceId` | string | Yes | Stripe price ID for the plan |
| `projectId` | string | No | Project scope (for per-project Stripe accounts) |
| `tenantId` | string | No | Tenant scope |
| `successUrl` | string | Yes | Redirect URL after successful checkout |
| `cancelUrl` | string | Yes | Redirect URL if user cancels |

**Response:**

```json
{
  "url": "https://checkout.stripe.com/c/pay/cs_xxx"
}
```

Redirect the user to the returned URL to complete checkout.

### RPC (Service Binding)

```typescript
const { url } = await env.AUTH_SERVICE.createCheckoutSession({
  orgId: "org_stackbilt",
  priceId: "price_xxx",
  successUrl: "https://stackbilder.com/settings?checkout=success",
  cancelUrl: "https://stackbilder.com/pricing",
});
```

## Customer Portal

The Stripe Customer Portal lets users manage their subscription without leaving the Stackbilt experience: update payment methods, view invoices, cancel, or change plans.

```
POST https://auth.stackbilt.dev/billing/portal
```

**Request body:**

```json
{
  "orgId": "org_stackbilt",
  "returnUrl": "https://stackbilder.com/settings"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `orgId` | string | Yes | Organization with an active billing account |
| `projectId` | string | No | Project scope (for per-project Stripe accounts) |
| `returnUrl` | string | Yes | URL to redirect to after portal session |

**Response:**

```json
{
  "url": "https://billing.stripe.com/p/session/xxx"
}
```

If the organization has no Stripe customer ID (never subscribed), the endpoint returns 403.

## Subscription Lifecycle

Edge-auth handles the full subscription lifecycle through Stripe webhooks. All webhook events are signature-verified and idempotent (duplicate events are safely ignored).

### Webhook Events

| Event | Handler |
|-------|---------|
| `checkout.session.completed` | Creates or upgrades the tenant tier, provisions entitlements, sends confirmation email |
| `customer.subscription.updated` | Reconciles tier based on the subscription's price metadata |
| `customer.subscription.deleted` | Downgrades tenant to free tier, clears subscription ID |
| `invoice.payment_failed` | Marks tenant as payment delinquent |
| `invoice.payment_succeeded` | Clears payment delinquent flag |

### Tier Reconciliation

When a subscription event arrives, edge-auth:

1. Looks up the `tier` metadata on the Stripe price object
2. Updates the tenant's tier in the database
3. If the tier changed, publishes a tier change event to the `edge-auth-tier-changes` queue
4. Downstream services (Stackbilder, img-forge) consume the queue to update their entitlement caches

Tier mapping is driven entirely by Stripe price metadata -- add `tier: "pro"` to a Stripe price, and edge-auth handles the rest.

### Payment Delinquency

When `invoice.payment_failed` fires, the tenant is marked delinquent. Delinquent tenants retain their tier but may see degraded service (e.g., warning banners, blocked new scaffolds). When payment succeeds, the delinquent flag is cleared automatically.

## Entitlements & Quotas

Each tier maps to a set of feature entitlements with monthly quotas. Entitlements are provisioned automatically when a user signs up (free tier) or when their subscription tier changes.

### Checking Quota

```typescript
const status = await env.AUTH_SERVICE.checkQuota({
  tenantId: "tenant-uuid",
  feature: "scaffolds",
  amount: 1,
});
// status.allowed, status.remaining, status.limit
```

### Consuming Quota

Quota consumption uses a two-phase commit pattern:

1. **Reserve** -- `consumeQuota` decrements the quota and returns a `reservationId`
2. **Commit or refund** -- `commitOrRefundQuota` finalizes the reservation

```typescript
// Reserve
const result = await env.AUTH_SERVICE.consumeQuota({
  tenantId: "tenant-uuid",
  feature: "scaffolds",
  amount: 1,
});

if (!result.success) {
  // Quota exceeded -- show upgrade CTA
}

// ... perform the operation ...

// Commit on success, refund on failure
await env.AUTH_SERVICE.commitOrRefundQuota(
  result.reservationId,
  operationSucceeded ? "success" : "failed",
);
```

### Viewing Entitlements

```typescript
const view = await env.AUTH_SERVICE.getEntitlements(tenantId, userId);
// view.plan, view.features.scaffolds.remaining, etc.
```

Users see "X scaffolds remaining" at 80% usage. At 100%, a hard wall with an upgrade CTA is shown.

## Fractal Billing

Edge-auth supports per-project Stripe accounts. Each project can specify its own `stripe_config` in the database with a dedicated Stripe secret key and webhook secret. This enables:

- **FoodFiles** connects to edge-auth under its own Stripe account
- **Stackbilder** uses the global Stripe account
- New projects can be onboarded with their own billing relationship

When a project has a `stripe_config`, billing operations (checkout, portal, webhook verification) use the project's Stripe credentials. When no config is present, they fall back to the global `STRIPE_SECRET_KEY`.

## Promotion Codes

Admins can create and manage Stripe promotion codes through edge-auth:

### Create a Promo Code

```typescript
const promo = await env.AUTH_SERVICE.createPromoCode({
  code: "LAUNCH50",
  percentOff: 50,
  duration: "repeating",
  durationInMonths: 3,
  maxRedemptions: 100,
});
```

### List Active Promo Codes

```typescript
const { codes } = await env.AUTH_SERVICE.listPromoCodes();
```

### Revoke a Promo Code

```typescript
await env.AUTH_SERVICE.revokePromoCode("promo_xxx");
```

Promotion codes are applied during Stripe Checkout (`allow_promotion_codes: true`). When a checkout session completes with a promo code, edge-auth logs the redemption in the `promo_redemptions` table for analytics.

## Audit Trail

Every billing operation is audit-logged with:

- **Risk level**: `EXTERNAL_SIDE_EFFECT` (Stripe interactions)
- **Principal**: The authenticated user or service making the request
- **Action**: `billing.checkout.create`, `billing.portal.create`, `stripe.webhook`, etc.
- **Outcome**: Success or failure with context
