---
title: "Compass Governance API"
description: "Compass API surface and route taxonomy. MCP endpoints, governance ledger, blessed patterns, ADR management, and JWT authentication."
section: "platform"
order: 8
color: "#22d3ee"
tag: "08"
---

# Compass Governance API

Compass is the governance system behind StackBilt. This page documents the current Compass API surface and route taxonomy implemented in the `DigitalCSA` worker.

Base URL (production): accessed via Stackbilder service binding (not a public subdomain)

## What This Covers

- Compass MCP endpoints (`/mcp`, `/mcp/info`, legacy compatibility paths)
- Canonical admin/domain route taxonomy
- JWT + JWKS auth routes
- Core governance APIs (ledger, patterns, requests, triage, validation, exhibits, agent ops)

This page is a route map and integration reference, not a full schema-level endpoint spec.

## Authentication Model

Compass uses scoped API auth for most `/api/*` routes and enforces tenant/domain boundaries in the worker:

- ecosystem scope (`ecosystem_id`)
- optional domain/project scope (`domain_id` / `project_id`)
- payload scope enforcement on write requests (`POST` / `PATCH` / `PUT`)

### MCP Authentication (`/mcp`)

Compass MCP supports:

- JWT Bearer token (primary)
- session-based follow-up requests via `mcp-session-id`
- query-token compatibility mode (deprecated; can be warn/block mode)

If no valid JWT and no session is present, Compass rejects the request.

### JWT / JWKS Routes

| Endpoint | Method | Notes |
|---|---|---|
| `/api/.well-known/jwks.json` | `GET` | Public JWKS for JWT verification |
| `/api/auth/token` | `POST` | Issue Compass JWT (requires valid API key) |
| `/api/auth/revoke` | `POST` | Revoke JWTs (admin only) |

## MCP Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/mcp/info` | `GET` | Public server info / capabilities summary |
| `/mcp` | `GET` | SSE stream (session-capable) |
| `/mcp` | `POST` | MCP JSON-RPC requests |
| `/mcp` | `DELETE` | End MCP session |
| `/mcp/*` | `GET/POST` | MCP path variants routed through the same handler |
| `/mcp-client/*` | varies | Admin-only MCP client routes (feature flagged) |

## Canonical Route Taxonomy

Compass uses a canonical route structure for admin, domain registry, and domain-scoped governance operations.

### Admin Routes (`/api/admin/*`)

Primary admin surfaces include:

- `/api/admin/keys`
- `/api/admin/domains`
- `/api/admin/repo-keys`
- `/api/admin/repo-keys/:keyId/rotate`
- `/api/admin/repo-keys/:keyId/revoke`
- `/api/admin/repo-keys/:keyId/events`
- `/api/admin/repos/:repoId/revoke-all-keys`

These routes require admin auth and apply scope checks before writes.

### Domain Registry Routes (`/api/domains`)

Admin-manageable domain registry endpoints:

- `GET/POST /api/domains`
- `GET/PATCH /api/domains/:domainId`

### Domain-Scoped Governance Routes (`/api/domains/:domainId/*`)

These routes enforce domain ownership and payload scoping.

| Endpoint Pattern | Methods | Purpose |
|---|---|---|
| `/api/domains/:domainId/ledger` | `GET`, `POST` | Ledger entries |
| `/api/domains/:domainId/tickets` | `GET`, `POST` | Governance requests/tickets |
| `/api/domains/:domainId/chat/threads` | `GET`, `POST` | Domain chat threads |
| `/api/domains/:domainId/chat/threads/:id` | `GET`, `PATCH`, `DELETE` | Thread lifecycle |
| `/api/domains/:domainId/chat/threads/:id/messages` | `POST` | Send message |
| `/api/domains/:domainId/patterns` | `GET`, `POST` | Pattern catalog |
| `/api/domains/:domainId/patterns/:id` | `GET`, `PATCH`, `DELETE` | Pattern management |
| `/api/domains/:domainId/protocols` | `GET`, `POST` | Protocols |
| `/api/domains/:domainId/protocols/:id` | `DELETE` | Protocol delete |

## Core Governance APIs (Top-Level)

Compass also exposes top-level scoped APIs (with `ecosystem_id` / `project_id` query support in many cases) for compatibility and operational workflows.

### Ledger, Patterns, Requests

- `/api/ledger`
- `/api/ledger/:id`
- `/api/ledger/temporal/valid-at`
- `/api/ledger/temporal/approaching-review`
- `/api/ledger/:id/temporal`
- `/api/patterns`
- `/api/patterns/:id`
- `/api/requests`
- `/api/requests/:id`
- `/api/requests/:id/resolve`
- `/api/requests/:id/notes`

### Triage, Audit, Validation

- `/api/triage/run`
- `/api/triage/commit` (admin)
- `/api/triage/history`
- `/api/triage/entropy`
- `/api/triage/detect`
- `/api/triage/scope`
- `/api/audit/report`
- `/api/validate`
- `/api/validate/history` (admin)
- `/api/git/validate`
- `/api/git/validations` (admin)

### Submission + Chat

- `/api/submit`
- `/api/submit/my`
- `/api/submit/status/:id`
- `/api/chat/threads`
- `/api/chat/threads/:id`
- `/api/chat/threads/:id/messages`

### Exhibits (Constitution / Policy Content)

- `/api/exhibits`
- `/api/exhibits/active/:projectId`
- `/api/exhibits/:id`
- `/api/exhibits/:id/sections`
- `/api/exhibits/:exhibitId/sections/:sectionId`

### Agent Operations (Admin)

- `/api/agent/request-action`
- `/api/agent/status/:actionId`
- `/api/agent/approve/:actionId`
- `/api/agent/audit/:actionId`
- `/api/agent/kill-switch`
- `/api/agent/actions`
- `/api/agent/operations`
- `/api/agent/cancel/:actionId`
- `/api/agent/execute/:actionId`

### Miscellaneous Operational Endpoints

- `/api/heartbeat` (proactive governance health checks)
- `/api/llm` (primary LLM route)
- `/api/gemini` (deprecated compatibility route)

## Integration Notes

- Prefer the canonical domain-scoped routes (`/api/domains/:domainId/*`) for new integrations.
- Use JWT auth for MCP clients and reuse the session header for follow-up requests.
- Treat query-token MCP auth as deprecated and migrate to header-based auth.
- For public key verification across services, use Compass JWKS (`/api/.well-known/jwks.json`).

## Related Docs

- [Ecosystem](/ecosystem)
- [MCP Integration](/mcp) (StackBilt MCP server)
- [API Reference](/api-reference) (StackBilt platform API)
