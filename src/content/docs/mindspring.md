---
title: "MindSpring"
description: "Cloudflare-native source intelligence backend for Knowledge Notebooks — semantic search over AI conversation exports with RAG chat, v2 workspaces, and multipart ingestion."
section: "ecosystem"
order: 15
color: "#8b5cf6"
tag: "15"
lastVerified: "2026-06-28"
---

# MindSpring

**GitHub:** [Stackbilt-dev/mindspring](https://github.com/Stackbilt-dev/mindspring) · MIT

Part of the [Stackbilt ecosystem](/ecosystem). Cloudflare-native source intelligence backend for Knowledge Notebooks. Integrates with [AEGIS Core](/aegis-core) via NDJSON thread ingestion — AEGIS `conversation-facts` write pipelines are compatible with MindSpring's simple upload path.

MindSpring operates in a hybrid mode:

- **v1** (`/api/*`) — production-ready conversation archive ingestion, semantic search, and RAG chat over ChatGPT/Claude exports
- **v2** (`/api/v2/workspaces/:workspaceId/notebooks/*`) — workspace-scoped Knowledge Notebooks with sources, ingestion jobs, scoped retrieval, chat, and persisted artifacts

---

## Architecture

```
Browser (SPA) → Hono API (Cloudflare Worker)
                    ├── Vectorize (vector storage + semantic search)
                    ├── R2 (raw file storage)
                    ├── Workers AI (embeddings + DeepSeek R1 RAG)
                    ├── Queue (async ingestion pipeline)
                    └── KV (state, auth, conversation text, telemetry)
```

Single Worker deployment — API and static frontend served together. Fully Cloudflare-native (Vectorize, not Qdrant). Streaming JSON parser handles files up to 1GB+ without memory bloat. Zero external runtime dependencies beyond Hono.

---

## Quick Start

### 1. Clone and create resources

```bash
git clone https://github.com/Stackbilt-dev/mindspring.git
cd mindspring && npm install

# KV namespace
wrangler kv namespace create MINDSPRING_KV
wrangler kv namespace create MINDSPRING_KV --preview

# R2 bucket
wrangler r2 bucket create mindspring-uploads

# Vectorize index (1024-dim, cosine)
wrangler vectorize create mindspring-conversations --dimensions=1024 --metric=cosine

# Queue + DLQ
wrangler queues create mindspring-ingestion
wrangler queues create mindspring-ingestion-dlq
```

Paste the KV namespace IDs into `wrangler.toml`, then deploy:

```bash
wrangler deploy
```

### 2. Bootstrap an API key

```bash
wrangler kv key put --binding KV "apikey:your-initial-admin-key" \
  '{"name":"bootstrap","scope":"admin","createdAt":"2025-01-01T00:00:00Z","lastUsedAt":null,"revoked":false}' \
  --preview false --remote
```

Use this admin key to create scoped keys via `POST /api/auth/keys`.

---

## Auth Model

API keys have hierarchical scope:

| Scope | Access |
|-------|--------|
| `read` | Search, browse, stats, health |
| `ingest` | `read` + upload and trigger ingestion |
| `admin` | `ingest` + key management and telemetry |

Pass as `Authorization: Bearer <key>` or `X-API-Key: <key>`.

---

## API Overview

### v2 Knowledge Notebooks

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/v2/workspaces/:wId/notebooks` | Create notebook |
| `GET` | `/api/v2/workspaces/:wId/notebooks` | List notebooks |
| `PATCH` | `/api/v2/workspaces/:wId/notebooks/:nId` | Update metadata/instructions |
| `DELETE` | `/api/v2/workspaces/:wId/notebooks/:nId` | Soft-delete |
| `POST` | `/api/v2/workspaces/:wId/notebooks/:nId/sources` | Register source from uploaded file |
| `POST` | `/api/v2/workspaces/:wId/notebooks/:nId/search` | Notebook-scoped semantic search |
| `POST` | `/api/v2/workspaces/:wId/notebooks/:nId/chat` | Notebook-scoped chat with citations |
| `POST` | `/api/v2/workspaces/:wId/notebooks/:nId/artifacts` | Create artifact (`briefing_doc`, `faq_glossary`, `implementation_plan`, `world_bible`) |
| `GET` | `/api/v2/workspaces/:wId/notebooks/:nId/artifacts/:aId` | Get artifact detail (includes `stale` flag) |

### Search & Chat (v1)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/search?q=<query>` | Semantic search. Params: `q`, `limit` (max 100), `threshold` (0–1) |
| `POST` | `/api/chat` | RAG chat. Body: `{"question": "...", "history": [...]}` |
| `GET` | `/api/conversations` | Browse all conversations |
| `GET` | `/api/conversations/:id/similar` | Find similar conversations |

### Upload & Ingestion

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/uploads/simple` | Direct upload for files under 5MB |
| `POST` | `/api/uploads` | Initiate multipart upload for large files |
| `POST` | `/api/uploads/:id/complete` | Finalize and start ingestion |
| `GET` | `/api/uploads/:id/status` | Poll ingestion progress |

Full OpenAPI 3.1 spec in [`openapi.yaml`](https://github.com/Stackbilt-dev/mindspring/blob/main/openapi.yaml).

---

## Supported Formats

| Source | Format |
|--------|--------|
| **ChatGPT** | `conversations.json` from Settings > Data Controls > Export |
| **Claude** | JSON exports with `chat_messages` arrays |
| **NDJSON threads** | AEGIS `conversation-facts` write pipeline output |

Both array (`[{...}]`) and object (`{"key": {...}}`) JSON root formats are supported.

---

## Large File Handling

Files are handled without buffering in Worker memory:

1. Files under 5MB: simple upload path. Larger files: R2 multipart (50MB chunks, uploaded sequentially with progress tracking)
2. Streaming JSON parser reads from R2 chunk-by-chunk — peak memory is ~2× the largest single conversation object
3. Progress checkpointed to KV after every 100 conversations — Queue redelivers on CPU limits, ingestion resumes from checkpoint
4. Embeddings via Workers AI (`@cf/baai/bge-large-en-v1.5`, 1024 dims), sub-batched at 96

---

## RAG Chat

DeepSeek R1 (`@cf/deepseek-ai/deepseek-r1-distill-qwen-32b`) running on Workers AI:

1. Question is embedded and used to retrieve top 8 conversations from Vectorize
2. Retrieved conversations are packed into ~4K token context window
3. DeepSeek R1 reasons across conversations and synthesizes an answer with citations
4. Supports up to 4 turns of multi-turn history
5. Collapsible reasoning blocks — see the model's chain of thought or hide it

---

## Rate Limits

| Endpoint group | Limit |
|---------------|-------|
| Search / browse / conversations | 60 req/min per key |
| Chat (RAG) | 20 req/min per key |
| Upload mutations | 20 req/min per key |

Rate limit headers on every response: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`.

---

## Frontend

Vanilla HTML/CSS/JS SPA served as static assets from the same Worker. No build step.

- **Search** — semantic search with score bars and staggered card animations
- **Chat** — RAG chat with collapsible reasoning blocks and source citations
- **Upload** — drag-and-drop with multipart chunking and real-time progress
- **Detail** — full conversation view with similar conversation discovery
- **Settings** — API key configuration and system health dashboard

Design system: "Infrastructure Noir" — Midnight Console, Architectural Tan, Visionary Purple, System Green, Cloudflare Cyan. Typography: Syne / DM Sans / JetBrains Mono.
