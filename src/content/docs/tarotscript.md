---
title: "TarotScript Runtime Reference"
description: "Public interface reference for the TarotScript runtime — REST API, MCP tools, authentication, agent roles, and contract schemas. Sourced from Stackbilt-dev/tarotscript."
section: "platform"
order: 3
color: "#818cf8"
tag: "03"
lastVerified: "2026-06-27"
sourceSlug: "tarotscript-reference"
---

# TarotScript Runtime Reference

**Worker:** `tarotscript-worker` — Cloudflare Worker  
**Base URL:** `https://tarotscript.com`  
**MCP Gateway access:** `https://mcp.stackbilt.dev/mcp` (see [MCP Gateway](./mcp.md))

TarotScript is the deterministic scaffold and agent consultation engine that powers the [Stackbilder platform](/platform). Part of the [Stackbilt ecosystem](/ecosystem). The platform-facing REST interface is documented in the [API Reference](/api-reference#scaffolder-flows) and [Agent Consultations](/api-reference#agent-consultations) sections.

TarotScript is a non-deterministic, context-dependent programming language built on Tarot and Hermetic mechanics. The runtime is closed-source and hosted. This page documents the **public interface** — REST endpoints, MCP tools, and contract schemas — not the language internals.

For the language syntax and spread authoring, see `docs/deck-authoring.md` and `docs/agents.md` in the tarotscript repo.

---

## Authentication

All routes except `/health` and `/spreads` require a Bearer token.

```
Authorization: Bearer <api-key>
```

In development (no `API_KEY` env var configured) all requests are accepted without a token.  
In production, a missing or invalid token returns `401`.

`X-Querent-Ids` — optional header, comma-separated querent identifiers. Used to scope readings and grimoire storage to a tenant. When omitted, the API key hash is used as the querent namespace.

---

## Core execution

### `POST /run`

Execute a `.tarot` script or a named spread against the hosted runtime.

**Request body**

| Field | Type | Required | Description |
|---|---|---|---|
| `script` | string | one of | Raw `.tarot` source to execute |
| `spreadType` | string | one of | Named spread (from `GET /spreads`) |
| `source` | string | — | Alias for `script` |
| `querent` | object | — | `{ id?, intention?, state? }` — caller context |
| `seed` | integer | — | Deterministic seed. Same seed + script = same draw order |
| `inscribe` | boolean | — | Persist result to grimoire (default: false) |
| `publish_claims` | boolean | — | Publish AEGIS provenance claims |
| `responseMode` | string | — | `"structured"` \| `"narrative"` \| `"raw"` |
| `lenient` | boolean | — | Suppress runtime errors on missing positions |

**Response** — `ReadingResult` with resolved facts, drawn cards, oracle synthesis (if spread uses `speak`), and optional `scaffold` / `receipt` fields when `inscribe: true`.

---

### `POST /classify`

Intent classification via the `intent-classify` spread. Returns a Cloudflare stack pattern recommendation from a natural-language description.

**Request body**

| Field | Type | Required | Description |
|---|---|---|---|
| `intention` | string | ✓ | Natural-language description of what to build |
| `seed` | integer | — | Deterministic seed |
| `deck` | CustomDeck | — | Inline deck to inject (overrides stack deck) |
| `deck_alias` | string | — | Alias for injected deck (required when `deck` is set) |
| `deck_ref` | string | — | R2 tenant deck slug to resolve instead of inline `deck` |

**Response**

| Field | Type | Description |
|---|---|---|
| `classification.pattern` | string | Matched stack pattern name (e.g. `"Stripe Webhook"`) |
| `classification.confidence` | string | `"high"` / `"medium"` / `"low"` |
| `classification.method` | string | `"vocab"` (Signal card threshold met) or `"relevance"` (fell through to scoring) |
| `classification.vocab_signal` | string | Name of the Signal card that scored highest |
| `classification.vocab_score` | number | Signal card score (≥ 4 triggers vocab routing) |
| `classification.runner_up_vocab_signal` | string \| null | Second-highest Signal card (v2+ receipts) |
| `classification.runner_up_vocab_score` | number \| null | Runner-up score (v2+ receipts) |
| `classification.relevance_score` | number | Raw relevance score used when vocab routing is bypassed |
| `traits` | object | Full trait vector for the matched pattern |
| `tier2_recommended` | boolean | Whether a Tier-2 scaffold is advised |

---

## Scaffold

### `POST /scaffold/codegen`

Full scaffold pipeline: classify → skeleton → codegen → envelope. Returns deployable Cloudflare Worker files, a CI/CD skeleton, and a governance envelope.

**Request body** (`ScaffoldCodegenInput`)

| Field | Type | Required | Description |
|---|---|---|---|
| `intention` | string | ✓ | What to build |
| `workerName` | string | — | Target Worker name |
| `conversationId` | string | — | Idempotency key for the run |
| `seed` | integer | — | Deterministic seed |
| `inscribe` | boolean | — | Persist to grimoire |

**Response**

```json
{
  "success": true,
  "runId": 12,
  "codegen": { "pattern": "rag-pipeline", "workerName": "my-worker", "files": [...] },
  "skeleton": [...],
  "envelope": { ... },
  "emittedFacts": { ... },
  "inferenceMetrics": { ... }
}
```

`codegen.files` and `skeleton` are arrays of `ScaffoldFile` (see [Contracts](#contracts)).

---

### `POST /scaffold/batch`

Run up to 5 scaffold codegen requests in parallel. Same shape as `/scaffold/codegen` items.

**Request body**

```json
{ "items": [ <ScaffoldCodegenInput>, ... ] }
```

Batch size limit: 5. Returns an array of results in the same order as `items`.

---

### `POST /scaffold/outcome/:runId`

Record post-deploy outcome for a scaffold run. Feeds the skeleton feedback loop (issue #313).

---

## Agents

### `POST /agents/run`

Run a C-Level agent consultation. The agent draws from its 4-deck manifest (persona, domain, governance, actions) and synthesizes a structured advisory.

**Request body**

| Field | Type | Required | Description |
|---|---|---|---|
| `role` | string | ✓ | Agent role (see below) |
| `intention` | string | ✓ | Question or context for the agent |
| `context` | object | — | `Record<string, string>` — additional facts |
| `painSignals` | string[] | — | User pain signals to weight the draw |
| `responseMode` | string | — | `"structured"` \| `"narrative"` |
| `seed` | integer | — | Deterministic seed |
| `inscribe` | boolean | — | Persist result |
| `bundle_bindings` | object | — | Fact bundle from a prior agent run to carry forward |

**Available roles**

| Role | Description |
|---|---|
| `cto` | CTO advisory — architecture, tech strategy, build/buy decisions |
| `ciso` | CISO advisory — security posture, threat model, compliance. Requires prior CTO run (`bundle_bindings`) |
| `mara` | MARA — Colony OS simulation agent |
| `sera` | Sera — TarotScript authoring agent |

---

### `POST /agents/bootstrap`

Bootstrap a new domain deck via the `deck-bootstrap-cast` spread. Produces candidate card vocabulary for a target domain.

---

### Agent loop (Durable Object)

| Method | Route | Description |
|---|---|---|
| `POST` | `/agents/loop` | Start a new agent loop session |
| `GET` | `/agents/loop/tools` | List available loop tools |
| `GET` | `/agents/loop/:id` | Get current loop state |
| `POST` | `/agents/loop/:id/tick` | Advance loop by one tick |
| `GET` | `/agents/loop/:id/stream` | SSE stream of loop events |

---

### CISO intake

| Method | Route | Description |
|---|---|---|
| `POST` | `/agents/ciso-intake` | Submit a security finding for CISO triage |
| `POST` | `/agents/ciso-finding` | Record a CISO finding after analysis |

---

## Receipt + grimoire

| Method | Route | Description |
|---|---|---|
| `GET` | `/receipt/:hash` | Retrieve a signed reading receipt by hash |
| `GET` | `/verify/:hash` | Verify receipt chain integrity |
| `GET` | `/advisory/:hash` | Get advisory output from a persisted receipt |
| `POST` | `/recall` | Query grimoire by querent + filter |
| `GET` | `/grimoire/:querentId` | List all readings for a querent |

All receipts are chain-verifiable. A `hash` field is present on every inscribed reading response. The `/verify/:hash` endpoint confirms the chain has not been tampered with.

---

## Grader

### `POST /grader/run`

Run the eval grader spread against a target artifact. Returns per-dimension scores (TaskFit, Support, Actionability), an aggregate score, and a gap report.

See also: the MCP tool `tarotscript.run_grader` (below) exposes the same grader via the standard MCP protocol.

---

## MCP tools (direct)

The worker exposes its own MCP surface at `/mcp/tools` and `/mcp/invoke`. These are peer-to-peer tools for callers that hold a direct API key and do not need the OAuth gateway.

### `GET /mcp/tools`

Returns the tool manifest.

### `POST /mcp/invoke`

```json
{ "tool": "tarotscript.run_grader", "args": { ... } }
```

**Available tools**

| Tool ID | Description |
|---|---|
| `tarotscript.run_grader` | Grade an artifact against a rubric deck. Returns findings, aggregate score, gap report, and a chain-verifiable receipt. |

**`tarotscript.run_grader` input schema (abbreviated)**

```json
{
  "graderName": "string",
  "graderVersion": "semver string",
  "case": {
    "id": "string",
    "description": "string",
    "intent": "string",
    "artifact": { "id", "kind", "content", "title?" },
    "rubricDeck": { "name", "version?" },
    "spread?": "eval-grader-cast",
    "seed?": 42,
    "expectedMinimumScore?": 0.0–1.0
  }
}
```

**MCP via gateway:** The MCP gateway at `mcp.stackbilt.dev` also exposes `scaffold_*` and `agent_*` tools backed by this worker via service bindings. See [MCP Gateway](./mcp.md).

---

## Discovery

| Method | Route | Description |
|---|---|---|
| `GET` | `/health` | Health check. Returns `{ ok: true }` |
| `GET` | `/spreads` | List all bundled spread types |
| `GET` | `/manifests/cloudflare` | Cloudflare stack scaffold manifest |
| `GET` | `/manifests/crownrot` | Crownrot game deck manifest |
| `GET` | `/decks/registry/:slug` | Retrieve a registered deck by slug |

---

## Telemetry

| Method | Route | Description |
|---|---|---|
| `GET` | `/telemetry/scaffold` | Scaffold run metrics and pattern distribution |
| `GET` | `/telemetry/classify` | Classification receipt corpus: confidence distribution, fragility surface (relevance-routed receipts), signal drift pairs. Accepts `?limit=N`. |
| `GET` | `/telemetry/sim` | Simulation run metrics |
| `GET` | `/telemetry/harness` | Harness DAG execution metrics |

Telemetry routes are auth-gated and return JSON summaries from D1 + KV aggregate queries.

---

## Harness (advanced)

### `POST /harness/run`

Raw DAG execution. Accepts a structured harness spec and executes compound multi-spread pipelines. Used internally by `/scaffold/codegen`. Prefer `/scaffold/codegen` unless you need compound DAG control.

---

## Contracts

The [`@stackbilt/contracts`](/contracts) package (published to npm) contains the Zod schemas for all structured response shapes. Docs update cadence: aligned with `@stackbilt/contracts` semver bumps.

**Key exports**

| Schema | Package path | Description |
|---|---|---|
| `ScaffoldFile` | `@stackbilt/contracts/scaffold-response` | A generated file: `{ path, content, language }` |
| `PromptContext` | `@stackbilt/contracts/scaffold-response` | Governance envelope with requirements, interfaces, threats, test plan |
| `MaterializerResult` | `@stackbilt/contracts/scaffold-response` | Full scaffold materializer output |
| `AgentRunResult` | `@stackbilt/contracts/agent-response` | Structured agent advisory output |
| `GraderRunInput` | `@stackbilt/contracts/eval` | Input schema for grader runs (mirrors MCP tool schema) |

**Usage**

```ts
import { ScaffoldFile, PromptContext } from '@stackbilt/contracts/scaffold-response';

const file = ScaffoldFile.parse(response.codegen.files[0]);
```

---

## Authority

- **Worker repo:** `Stackbilt-dev/tarotscript` (private)
- **Contracts package:** [`@stackbilt/contracts`](/contracts) on npm
- **Runtime endpoint:** `https://tarotscript.com`
- **MCP gateway docs:** [mcp.md](./mcp.md)
- **Deck authoring guide:** `docs/deck-authoring.md` in the tarotscript repo
- **Agent manifests:** `docs/agents.md` in the tarotscript repo

When contracts change shape, bump `@stackbilt/contracts` semver and open a docs PR against `Stackbilt-dev/docs` syncing this page.
