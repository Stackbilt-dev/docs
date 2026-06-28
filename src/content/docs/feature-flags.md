---
title: "feature-flags"
description: "Edge-native feature flag system for Cloudflare Workers — <5ms evaluation, canary deployments, A/B testing, per-tenant overrides, and Hono middleware. KV-backed."
section: "ecosystem"
order: 18
color: "#22c55e"
tag: "18"
lastVerified: "2026-06-28"
---

# feature-flags

[![npm version](https://img.shields.io/npm/v/@stackbilt/feature-flags?label=feature-flags&color=22c55e&style=for-the-badge)](https://www.npmjs.com/package/@stackbilt/feature-flags)

**GitHub:** [Stackbilt-dev/feature-flags](https://github.com/Stackbilt-dev/feature-flags) · MIT

Part of the [Stackbilt ecosystem](/ecosystem). High-performance feature flag system for Cloudflare Workers with `<5ms` evaluation latency. KV-backed, Hono middleware included, audit logging built in.

---

## Install

```bash
npm install @stackbilt/feature-flags
```

Add KV namespaces to `wrangler.toml`:

```toml
[[kv_namespaces]]
binding = "FEATURE_FLAGS_KV"
id = "your-flags-kv-id"

[[kv_namespaces]]
binding = "FEATURE_FLAGS_CACHE"
id = "your-cache-kv-id"
```

---

## Quick Start

```typescript
import { createProductionFeatureFlags, createFeatureFlagMiddleware } from '@stackbilt/feature-flags';
import { Hono } from 'hono';

const app = new Hono();
const flagSystem = createProductionFeatureFlags(env);

app.use('*', createFeatureFlagMiddleware({ manager: flagSystem.manager }));

app.get('/api/data', async (c) => {
  const flags = c.get('featureFlags');
  const useNew = await flags.isEnabled('new_feature');
  return c.json({ data: useNew ? getNewData() : getLegacyData() });
});
```

---

## Flag Types

### Boolean flags

Simple on/off toggles:

```typescript
await manager.createFlag({ key: 'dark_mode', type: 'boolean', enabled: true });
const isOn = await flags.isEnabled('dark_mode');
```

### Percentage rollouts

Consistent user assignment across requests:

```typescript
await manager.createFlag({
  key: 'new_dashboard',
  type: 'percentage',
  percentage: 25, // 25% of users
});
```

### Variant flags (A/B/n testing)

```typescript
await manager.createFlag({
  key: 'checkout_flow',
  type: 'variant',
  variants: [
    { key: 'control', weight: 50 },
    { key: 'streamlined', weight: 30 },
    { key: 'one_page', weight: 20 },
  ],
});

const variant = await flags.getVariant('checkout_flow');
// Returns 'control' | 'streamlined' | 'one_page' based on user hash
```

---

## Canary Deployments

Staged rollouts with automatic advancement:

```typescript
import { createCanaryFlags } from '@stackbilt/feature-flags';

const { gradualRollout, canaryConfig } = createCanaryFlags();
await manager.createFlag(gradualRollout);

// Start at 5%, auto-advance through stages: 5% → 10% → 25% → 50% → 100%
await manager.startCanaryDeployment('gradual_rollout_feature', canaryConfig);

// Manual advance
await manager.updateCanaryDeployment('gradual_rollout_feature', { percentage: 25 });

// Emergency rollback
await manager.stopCanaryDeployment('gradual_rollout_feature');
```

---

## Tenant Overrides

Per-tenant flag values for multi-tenant deployments:

```typescript
// Override for a specific tenant
await manager.setTenantOverride('tenant-123', 'new_feature', true);

// Evaluate with tenant context
const flags = manager.forTenant('tenant-123');
const isOn = await flags.isEnabled('new_feature'); // uses override
```

---

## Rule Engine

Target by tenant, user, IP, custom attributes, or time windows:

```typescript
await manager.createFlag({
  key: 'beta_feature',
  type: 'boolean',
  rules: [
    { attribute: 'plan', operator: 'equals', value: 'pro', result: true },
    { attribute: 'country', operator: 'in', value: ['US', 'CA'], result: true },
    { attribute: 'created_at', operator: 'after', value: '2026-01-01', result: false },
  ],
  default: false,
});
```

---

## Admin API

REST endpoints for flag management (auth-gated):

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/flags` | List all flags |
| `POST` | `/flags` | Create a flag |
| `PATCH` | `/flags/:key` | Update a flag |
| `DELETE` | `/flags/:key` | Delete a flag |
| `GET` | `/flags/:key/metrics` | Evaluation counts + variant distribution |
| `POST` | `/flags/:key/canary/start` | Start canary deployment |
| `POST` | `/flags/:key/canary/stop` | Rollback canary |

---

## Metrics

Evaluation metrics per flag:

```typescript
const metrics = await manager.getMetrics('checkout_flow');
// {
//   evaluations: 42000,
//   variants: { control: 21200, streamlined: 12600, one_page: 8200 },
//   p50LatencyMs: 2.1, p99LatencyMs: 4.8
// }
```

All flag changes are written to an audit log in KV with timestamps and actor identity.
