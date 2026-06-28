---
title: "evidence-core"
description: "E-E-A-T content-quality validator — Google policy-versioned gap detection for AI-generated content. The OSS core of Evidence Engine on Stackbilder Pro."
section: "ecosystem"
order: 11
color: "#10b981"
tag: "11"
lastVerified: "2026-06-27"
---

# evidence-core

[![npm version](https://img.shields.io/npm/v/@stackbilt/evidence-core?label=evidence-core&color=10b981&style=for-the-badge)](https://www.npmjs.com/package/@stackbilt/evidence-core)

**GitHub:** [Stackbilt-dev/evidence-core](https://github.com/Stackbilt-dev/evidence-core) · Apache-2.0

Post-March 2024 Google core update and November 2024 site reputation abuse update, AI-generated content without E-E-A-T signals gets buried. Most SEO tooling emits vague guidance. `evidence-core` emits **concrete actions tied to specific Google policy versions** — exactly what's missing and what to add.

This package is the OSS core of **Evidence Engine**, a pre-publish content-quality gate available on [Stackbilder Pro](https://stackbilder.com).

---

## Install

```bash
npm install @stackbilt/evidence-core
# or
pnpm add @stackbilt/evidence-core
```

No LLM dependency — deterministic, regex-based, runs in any environment including Cloudflare Workers.

---

## Quick start

```ts
import { validateEvidence } from '@stackbilt/evidence-core';

const result = await validateEvidence({
  text: 'Your draft content here...',
  author: 'Jane Doe',
  authorBio: 'Senior content strategist with 10 years...',
  lastUpdated: '2026-04-19',
  aiDisclosure: 'AI-assisted, human-reviewed',
}, {
  policyVersion: 'google_november_2024_reputation',
});

if (result.hasGaps) {
  for (const suggestion of result.suggestions) {
    console.log(`[${suggestion.priority}] ${suggestion.pillar}:`);
    for (const action of suggestion.actions) {
      console.log(`  - ${action.action}`);
      console.log(`    e.g. ${action.examples[0]}`);
    }
  }
}
```

---

## Policy versions

| Version | When to use |
|---------|------------|
| `google_baseline_2023` | Historical comparison / legacy archive re-scoring |
| `google_march_2024_core` | Scaled content abuse + helpful content guidance; lower bar than reputation preset |
| `google_november_2024_reputation` *(default)* | Reputation-sensitive verticals (YMYL, review, how-to); adds editorial-process requirements |

You can also supply a custom `EvidencePolicy` via `options.policy`.

---

## The four pillars

Each pillar has configurable thresholds. The defaults match the selected policy version.

| Pillar | What it checks |
|--------|---------------|
| **Experience** | First-hand signals: case studies, original visuals, first-hand-experience phrases (`minCaseStudies`, `minOriginalVisuals`, `minFirstHandEvidence`) |
| **Expertise** | Substantive treatment: citations, data points, unique insights (`minCitations`, `minDataPoints`, `minUniqueInsights`) |
| **Authoritativeness** | Credibility signals: author byline, bio, external validation, editorial process (`requiresAuthorByline`, `requiresAuthorBio`, `requiresExternalValidation`, `requiresEditorialProcess`) |
| **Trustworthiness** | Transparency: last-updated date, AI disclosure, source attribution (`requiresLastUpdated`, `requiresAIDisclosure`, `requiresSourceAttribution`) |

Pillar counters use regex patterns — deterministic and fast, no LLM call. Consumers who want semantic counting can layer that on top.

---

## Gap-fill loop with `mergeEvidence`

`mergeEvidence` is the deterministic inject step. Validate → look up assets → merge → LLM redraft → re-validate.

```ts
import { validateEvidence, mergeEvidence } from '@stackbilt/evidence-core';

let draft = { text: 'Your draft...', author: 'Jane Doe', authorBio: '...' };
let result = await validateEvidence(draft);

while (result.hasGaps) {
  const assets = await queryEvidenceLibrary(result.gaps); // consumer-supplied
  draft = mergeEvidence(draft, {
    caseStudies: assets.caseStudies, // [{ title, summary, url?, date? }]
    citations:   assets.citations,   // [{ url, title?, publishedDate? }]
    visuals:     assets.visuals,     // [{ url, alt, caption? }]
    metadata:    { lastUpdated: '2026-04-19' },
  });
  draft.text = await llmRedraft(draft); // consumer-supplied
  result = await validateEvidence(draft);
}
```

`mergeEvidence` is pure and synchronous — no LLM call, no mutation of input, no null coercion (absent fields stay absent).

---

## Evidence library schema

A JSON Schema for modeling an evidence asset library (case studies, quotes, visuals, proprietary data) is exported at `@stackbilt/evidence-core/schema`:

```ts
import schema from '@stackbilt/evidence-core/schema' assert { type: 'json' };
```

Storage is left to the consumer (D1, Postgres, flat file). The schema is a reference contract for interoperability.

---

## Audit integration

The `./audit` export provides audit trail hooks shaped to be compatible with [`@stackbilt/audit-chain`](/audit-chain). No production dependency on audit-chain — consumers wire records at the application layer.

### Event types

`EvidenceAuditEvent` is a union of 8 types: `validation.started`, `validation.completed`, `gaps.detected`, `assets.merged`, `redraft.completed`, `approval.granted`, `publish.allowed`, `publish.blocked`.

### Transform functions

```ts
import { toAuditPayload, toAssetsAuditPayload } from '@stackbilt/evidence-core/audit';

// After validateEvidence()
const record = toAuditPayload(result, {
  contentId: 'article:uuid-12345',
  contentHash: sha256(content.text), // optional
  actor: 'user:operator-id',         // optional, defaults to 'system:evidence-engine'
});

// After mergeEvidence()
const assetsRecord = toAssetsAuditPayload(evidence, { contentId: 'article:uuid-12345' });
```

### Namespace conventions

| Pattern | Example |
|---------|---------|
| Default | `content:{contentId}` → `content:article-123` |
| Multi-tenant | `tenant:{tenantId}:content:{contentId}` → `tenant:t-456:content:article-123` |

Override via `ToAuditPayloadOptions.namespace`.

---

## Exported types

`ValidationResult`, `ContentInput`, `EvidencePolicy`, `EvidencePolicyVersion`, `EvidenceGap`, `EvidencePillar`, `Suggestion`, `SuggestionAction`, `MergeableEvidence`, `MergeableContent`, `SubmittedEvidence`, and more — see the [source index](https://github.com/Stackbilt-dev/evidence-core/blob/main/src/index.ts).

---

## Evidence Engine (hosted)

The hosted Pro product on [stackbilder.com](https://stackbilder.com) wraps `evidence-core` with:

- D1-backed audit history
- Pre-publish gate UI
- Tamper-evident receipts verifiable at `trust.stackbilder.com/evidence/:hash`
- REST API at `stackbilder.com/api/v1/evidence/*` (see [API Reference](/api-reference#evidence-engine))
