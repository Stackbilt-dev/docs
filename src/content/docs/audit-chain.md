---
title: "audit-chain"
description: "Tamper-evident audit trail for Cloudflare Workers — SHA-256 hash chaining with R2 immutability and D1 indexing. Zero production dependencies."
section: "ecosystem"
order: 12
color: "#f59e0b"
tag: "12"
lastVerified: "2026-06-27"
---

# audit-chain

[![npm version](https://img.shields.io/npm/v/@stackbilt/audit-chain?label=audit-chain&color=f59e0b&style=for-the-badge)](https://www.npmjs.com/package/@stackbilt/audit-chain)

**GitHub:** [Stackbilt-dev/audit-chain](https://github.com/Stackbilt-dev/audit-chain) · Apache-2.0

Part of the [Stackbilt ecosystem](/ecosystem). Pairs with [`@stackbilt/evidence-core`](/evidence-core) to make E-E-A-T decisions tamper-provable, and with [worker-observability](/worker-observability) for complementary monitoring. Used in production in the [Stackbilder platform](/platform) Content Provenance API — see [Security](/security#content-provenance--audit-chain) for the full architecture.

Tamper-evident audit trail for Cloudflare Workers in under 200 lines of core logic. SHA-256 hash chaining with R2 immutability and D1 indexing. Zero production dependencies — uses only the Web Crypto API and Cloudflare bindings.

---

## How it works

Every record includes a SHA-256 hash computed from the previous record's hash plus the current record's content:

```
Record 1                Record 2                Record 3
+-----------------+     +-----------------+     +-----------------+
| prev: GENESIS   |     | prev: hash_1    |     | prev: hash_2    |
| data: {...}     |---->| data: {...}     |---->| data: {...}     |
| hash: hash_1    |     | hash: hash_2    |     | hash: hash_3    |
+-----------------+     +-----------------+     +-----------------+

hash_N = SHA-256(prev_hash_bytes + JSON.stringify(record_data))
```

**R2 is the immutable source of truth. D1 is a searchable index.** If D1 is wiped, the chain in R2 remains intact and verifiable.

---

## Setup

### 1. Install

```bash
npm install @stackbilt/audit-chain
```

### 2. Create the D1 table

```bash
npx wrangler d1 execute YOUR_DB --remote --file=node_modules/@stackbilt/audit-chain/schema.sql
```

Or copy `schema.sql` into your migrations directory.

### 3. Configure bindings

```toml
[[r2_buckets]]
binding = "AUDIT_BUCKET"
bucket_name = "your-audit-bucket"

[[d1_databases]]
binding = "AUDIT_DB"
database_name = "your-database"
database_id = "your-database-id"
```

---

## Core API

### `writeRecord(bindings, opts)`

Write a new audit record to R2 and index it in D1.

```typescript
import { writeRecord, GENESIS_HASH } from '@stackbilt/audit-chain';
import type { AuditBindings } from '@stackbilt/audit-chain';

const bindings: AuditBindings = {
  AUDIT_BUCKET: env.AUDIT_BUCKET,
  AUDIT_DB: env.AUDIT_DB,
};

const { record, newChainHead } = await writeRecord(bindings, {
  namespace:  'orders',
  chainHead:  currentHead,   // start with GENESIS_HASH for a new chain
  event_type: 'order.placed',
  actor:      'user:alice',
  payload:    { order_id: 'ord_123', total: 99.99 },
  metadata:   { ip: '203.0.113.1' },
});

// Persist newChainHead for the next write
```

**If the audit write fails, the audited action must not proceed.**

| Parameter | Type | Description |
|-----------|------|-------------|
| `namespace` | `string` | Chain namespace for isolation |
| `chainHead` | `string` | Current chain head hash |
| `event_type` | `string` | Application-defined event type |
| `actor` | `string` | Who or what caused the event |
| `payload` | `Record<string, unknown>` | Event data |
| `metadata` | `Record<string, unknown>` | Optional metadata |

Returns `{ record: AuditRecord, newChainHead: string }`.

---

### `verifyChain(bindings, namespace, opts?)`

Verify hash chain integrity for an entire namespace. Recomputes every hash, confirms no branches, rejects missing records.

```typescript
import { verifyChain } from '@stackbilt/audit-chain';

const result = await verifyChain(bindings, 'orders', {
  expectedChainHead:   currentHead,  // detect tail truncation
  expectedRecordCount: 42,           // detect missing records
});

if (!result.valid) {
  console.error(`Chain broken at ${result.broken_at}: ${result.error}`);
}
```

Returns `VerificationResult`: `{ valid, record_count, broken_at?, error? }`.

---

### `queryIndex(db, opts)`

Query the D1 index with filters.

```typescript
import { queryIndex } from '@stackbilt/audit-chain';

const rows = await queryIndex(env.AUDIT_DB, {
  namespace:  'orders',
  event_type: 'order.placed',
  actor:      'user:alice',
  after:      '2026-01-01T00:00:00Z',
  limit:      50,
});
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `namespace` | `string` | Required |
| `event_type` | `string` | Filter by event type |
| `actor` | `string` | Filter by actor |
| `after` / `before` | `string` | ISO 8601 time bounds |
| `limit` | `number` | Max results (default 100, max 1000) |
| `offset` | `number` | Pagination offset |

---

### `getRecord` / `getRecords`

Retrieve records directly from R2 (authoritative):

```typescript
const record = await getRecord(bindings, 'orders', recordId);
const all    = await getRecords(bindings, 'orders'); // sorted ascending
```

---

## Chain head management

The library does not manage the chain head — you must persist `newChainHead` and pass it back on each write. Appends for a namespace must be serialized; concurrent writers that share the same head will create a branch.

**Recommended options:**

| Storage | Notes |
|---------|-------|
| **Durable Object** | Single-writer guarantee — no race conditions. Recommended. |
| KV | Works if writes are serialized externally |
| D1 row | Fallback — query the latest record hash from the index |

If you lose the head, reconstruct it by reading the most recent R2 record and using its hash. Pass the persisted head to `verifyChain()` as `expectedChainHead` to detect missing tail records.

---

## D1 schema

```sql
CREATE TABLE IF NOT EXISTS audit_index (
  record_id        TEXT PRIMARY KEY,
  namespace        TEXT NOT NULL,
  event_type       TEXT NOT NULL,
  hash             TEXT NOT NULL,
  prev_hash        TEXT NOT NULL,
  actor            TEXT NOT NULL,
  timestamp        TEXT NOT NULL,
  payload_summary  TEXT,
  created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_namespace  ON audit_index(namespace);
CREATE INDEX IF NOT EXISTS idx_audit_event_type ON audit_index(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_actor      ON audit_index(actor);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp  ON audit_index(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_ns_ts      ON audit_index(namespace, timestamp);
```

---

## Integration with evidence-core

[`@stackbilt/evidence-core`](/evidence-core) produces content quality decisions; `audit-chain` makes them provable. The `./audit` export in evidence-core shapes records for direct use with `writeRecord()`.

```typescript
import { validateEvidence } from '@stackbilt/evidence-core';
import { toAuditPayload } from '@stackbilt/evidence-core/audit';
import { writeRecord, getChainHead } from '@stackbilt/audit-chain';

const result    = await validateEvidence(content, { policyVersion: 'google_march_2024_core' });
const auditRec  = toAuditPayload(result, { contentId, namespace: `content:${contentId}` });
const chainHead = await getChainHead(bindings, auditRec.namespace);
await writeRecord(bindings, { ...auditRec, chainHead });
```

### Canonical evidence event types

| Event type | When |
|------------|------|
| `evidence.validation.completed` | After `validateEvidence()` runs |
| `evidence.assets.merged` | After `mergeEvidence()` |
| `evidence.gaps.detected` | Missing signals identified |
| `evidence.approval.granted` | Human or policy approves publish |
| `evidence.publish.allowed` | All gates clear |
| `evidence.publish.blocked` | One or more gates failed |

---

## Design principles

- **R2 is truth, D1 is convenience.** If they diverge, R2 wins.
- **Append-only.** No update or delete operation.
- **Fail loud.** If the audit write fails, abort the audited operation.
- **Namespace isolation.** Multiple independent chains in the same R2 bucket and D1 table.
- **Zero dependencies.** Web Crypto API and Cloudflare bindings only.
