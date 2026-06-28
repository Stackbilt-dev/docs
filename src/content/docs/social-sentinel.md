---
title: "Social Sentinel"
description: "Privacy-first social media sentiment monitoring on Cloudflare Workers — PII redaction, Workers AI sentiment scoring, multi-tenant, Twitter/X + Google Reviews + Facebook."
section: "ecosystem"
order: 20
color: "#ec4899"
tag: "20"
lastVerified: "2026-06-28"
---

# Social Sentinel

**GitHub:** [Stackbilt-dev/social-sentinel](https://github.com/Stackbilt-dev/social-sentinel) · MIT

Part of the [Stackbilt ecosystem](/ecosystem). Privacy-first social media sentiment monitoring on Cloudflare Workers. All text is scrubbed for PII before it leaves the worker. AI sentiment scoring via Workers AI. Multi-tenant via KV-backed tenant configs. Pairs naturally with [worker-observability](/worker-observability) for alerting on sentiment trends.

---

## What It Does

Monitors Twitter/X, Google Reviews, and Facebook for brand mentions. Runs on a 15-minute cron trigger.

Pipeline per cycle:

```
┌───────────┐  ┌───────────┐  ┌───────────┐
│ Twitter/X │  │  Google   │  │ Facebook  │
│  Adapter  │  │  Reviews  │  │  Adapter  │
└─────┬─────┘  └─────┬─────┘  └─────┬─────┘
      └──────────────┼──────────────┘
                     ▼
            ┌────────────────┐
            │ PII Redaction  │  emails, phones, addresses, SSNs
            └───────┬────────┘
                    ▼
            ┌────────────────┐
            │  Workers AI    │  @cf/huggingface/distilbert-sst-2-int8
            │   Sentiment    │
            └───────┬────────┘
                    ▼
            ┌────────────────┐
            │ Batch Builder  │  up to 100 events/batch
            └───────┬────────┘
                    ▼
      POST /ingest/batch → Your HTTP Endpoint
```

**Privacy by design** — No long-term data storage. Mentions are processed in-flight and forwarded as structured metric events. Nothing sensitive is transmitted or stored.

---

## Features

- **PII redaction** — emails, phones, addresses, SSNs scrubbed before transmission
- **Real-time** — 15-minute cron trigger, continuous capture
- **Multi-platform** — Twitter/X, Google Reviews, Facebook; adding a platform is one adapter file
- **Zero-knowledge** — no persistent mention storage; process in-flight, forward as events
- **Multi-tenant** — each tenant gets independent platform credentials and processing in KV

---

## Setup

### 1. Create KV namespace

```bash
npx wrangler kv:namespace create TENANT_CONFIG
```

Update `wrangler.toml` with the returned namespace ID.

### 2. Configure a tenant

```bash
npx wrangler kv:key put --namespace-id=<KV_ID> "your-tenant-id" '{
  "tenantId": "your-tenant-id",
  "stage": "production",
  "enabled": true,
  "platforms": {
    "twitter": {
      "enabled": true,
      "bearerToken": "YOUR_TWITTER_BEARER_TOKEN",
      "searchQueries": ["your-brand OR @yourbrand"],
      "maxResults": 50
    },
    "google": {
      "enabled": false
    },
    "facebook": {
      "enabled": false
    }
  },
  "ingestEndpoint": "https://your-api.com/ingest/batch",
  "ingestAuthToken": "YOUR_INGEST_TOKEN"
}'
```

### 3. Deploy

```bash
npm install
npx wrangler deploy
```

---

## Sentiment Output

Each processed mention produces a structured event:

```json
{
  "tenantId": "your-tenant-id",
  "platform": "twitter",
  "mentionId": "tweet-id",
  "timestamp": "2026-06-28T10:00:00Z",
  "sentiment": {
    "label": "POSITIVE",
    "score": 0.87
  },
  "metadata": {
    "authorFollowers": 1200,
    "engagementScore": 45
  }
}
```

Events are batched (up to 100) and POSTed to your `ingestEndpoint`.

---

## Adding a Platform

Each platform is a single adapter file in `src/adapters/`. Implement the `PlatformAdapter` interface:

```typescript
interface PlatformAdapter {
  fetchMentions(config: PlatformConfig): Promise<RawMention[]>;
}
```

The redaction → sentiment → batch pipeline is shared across all adapters.
