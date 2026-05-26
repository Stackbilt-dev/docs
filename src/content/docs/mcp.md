---
title: "MCP Gateway — Upstream/Downstream Architecture"
description: "Architecture map for Stackbilt-dev/stackbilt-mcp-gateway — the OAuth-authenticated Cloudflare Worker at mcp.stackbilt.dev/mcp that exposes the platform's product workers as a single MCP-compliant remote server. Sibling consumer of the same backend service bindings as…"
section: "platform"
order: 5
color: "#22d3ee"
tag: "05"
lastVerified: "2026-05-26"
sourceSlug: "mcp-gateway-architecture"
---

## What this is

The **Stackbilt MCP Gateway** is a Cloudflare Worker that exposes the platform's product backends as a single MCP-compliant remote server, OAuth-authenticated. It's the third leg of Stackbilder's three-consumer fractal: the same backend service bindings power the web UI on `stackbilder.com`, the Charter CLI, and the gateway. The gateway exists so MCP-native agents (Claude Code, Claude Desktop, custom MCP clients) get a single OAuth endpoint without taking a dependency on the web UI's session model.

**Endpoint:** `https://mcp.stackbilt.dev/mcp`

**Repo:** `Stackbilt-dev/stackbilt-mcp-gateway`

**Stack:** Cloudflare Worker built on `@modelcontextprotocol/sdk` and `@cloudflare/workers-oauth-provider`. Listed on the official MCP registry at `registry.modelcontextprotocol.io`.

## Topology

```
                          ┌────────────────────────┐
                          │  AI agent / LM       │
                          │  Claude Code,        │
                          │  Claude Desktop,     │
                          │  custom MCP clients  │
                          └──────────┬───────────┘
                                     │ OAuth + MCP (Streamable HTTP / SSE)
                                     ▼
                          ┌────────────────────────┐
                          │  mcp.stackbilt.dev   │
                          │  (gateway Worker)    │
                          └──────────┬───────────┘
                                     │ Service Bindings (in-colo, no HTTP)
                                     ▼
        ┌──────────────────────────────────────────┐
        │  Backend product Workers (shared by all consumers) │
        │   │                                                 │
        │   ├─ edge-auth         (AUTH_SERVICE)               │
        │   ├─ tarotscript-worker (TAROTSCRIPT, scaffold_*)    │
        │   ├─ img-forge-mcp     (IMG_FORGE,    image_*)      │
        │   ├─ stackbilt-engine  (ENGINE,       arch flows)   │
        │   └─ stackbilt-deployer (DEPLOYER,    CF deploy)    │
        └──────────────────────────────────────────┘
                                     ▲
                                     │ Service Bindings (parallel sibling consumers)
        ┌──────────────────────────┐      ┌────────────────────┐
        │  stackbilder.com         │      │  Charter CLI       │
        │  (web UI + REST API)     │      │  (charter blast,   │
        │  human users +           │      │   charter surface) │
        │  ea_* API key callers    │      │  CI / local dev    │
        └──────────────────────────┘      └────────────────────┘
```

**Key invariant:** the gateway and `stackbilder.com` are siblings, not parent/child. Both are CF Workers; both hold parallel service bindings to the same backend product workers; both route through `edge-auth` for entitlements + quota. A tenant's Pro tier is consistent across whichever consumer they use.

## Service-binding map

Authoritative source: `Stackbilt-dev/stackbilt-mcp-gateway/wrangler.toml`.

| Binding | Backend Worker | Tool prefix on the gateway | What it routes |
|---|---|---|---|
| `AUTH_SERVICE` | `edge-auth` (entrypoint `AuthEntrypoint`) | (used internally) | Tenant resolution, API-key validation, OAuth grant storage in OAUTH_KV, entitlement checks, quota reservation |
| `TAROTSCRIPT` | `tarotscript-worker` | `scaffold_*` | Deterministic project scaffolding, classification, GitHub publishing, CF deployment hand-off |
| `IMG_FORGE` | `img-forge-mcp` | `image_*` | AI image generation (multi-provider, multi-tier) |
| `ENGINE` | `stackbilt-engine` | (architecture flows) | Architecture mode pipeline (PRODUCT → SPRINT) — distinct from `tarotscript-worker`'s scaffold path |
| `DEPLOYER` | `stackbilt-deployer` | (deploy flows) | Cloudflare Workers deployment, D1 provisioning, DNS via API |

## Authentication

| Method | Header | Use case |
|---|---|---|
| OAuth 2.1 + PKCE | `Authorization: Bearer <oauth-access-token>` | Recommended for end-user agent connections (Claude Desktop, Claude Code). Issued via `@cloudflare/workers-oauth-provider`. Tokens stored in `OAUTH_KV`. |
| Static Bearer | `Authorization: Bearer <STACKBILT_MCP_TOKEN>` | Server-to-server / CI integrations. |

The gateway intentionally does **not** accept `ea_*` API keys (those are issued from `stackbilder.com/settings` for the platform's REST API). Agent flows go through OAuth so the user can grant scoped consent.

## Transports

| Transport | Endpoint | Method | Use Case |
|---|---|---|---|
| **Streamable HTTP** | `/mcp` | POST | Modern MCP clients, single request/response |
| **SSE Stream** | `/mcp` | GET | Server-pushed events, session-based |
| **Server Info** | `/mcp/info` | GET | Capabilities discovery (no auth required) |

Streamable HTTP sessions use the `Mcp-Session-Id` header. First `initialize` request returns a session ID; include it on subsequent requests; `DELETE /mcp` with the session ID to terminate.

## Tool catalog state

The gateway's tool surface is **migrating** at the time of this writing:

- Legacy `flow_*` tools (architecture mode pipeline) — still bound, but the gateway repo's README marks them DEPRECATED and they're being replaced by deterministic `scaffold_*` tools (TarotScript-backed).
- `scaffold_*` tools — the canonical replacement for `flow_*`. Faster (~20ms structure, ~2s with oracle prose), no LLM calls for file generation.
- `image_*` tools — stable, route through `img-forge-mcp`.

For the live tool catalog, query `tools/list` against the gateway directly, or read the gateway repo README. Do **not** treat any frozen tool listing as authoritative — the surface is in flux.

## Documentation surface

The canonical platform-side reference for the gateway is `Stackbilt-dev/stackbilt-web/docs/mcp.md` (rendered at `docs.stackbilt.dev/mcp`). The docs site sources this page from `stackbilt-web` per `docs-manifest.json` v3 (`Stackbilt-dev/docs@2bcd7cc`). The gateway repo's own `docs/mcp.md` is currently stale (still describes the decommissioned `stackbilt.dev/mcp` endpoint with Compass JWT auth and the deprecated `flow_*` tool catalog as canonical) — left for the gateway team to refresh.

## What was deprecated

This architecture replaces an earlier topology where:

- The gateway lived behind `stackbilt.dev/mcp` (the `stackbilt.dev` domain now 301-redirects to `stackbilder.com`; `stackbilder.com/mcp/info` returns 404)
- A third auth method, **Compass JWT**, was accepted (Compass was removed as a standalone product per `stackbilt-web/CLAUDE.md`; its governance logic is being absorbed into `stackbilt-engine`)
- A separate **Compass Service Adapter (CSA)** transport mode existed for routing inside the platform (no longer relevant)
- Cross-Compass unified-auth via `stackbilt.dev/api/auth/token` (endpoint dead)

The `Stackbilt-dev/edgestack_v2` repo, which previously hosted the canonical `mcp.md` doc on its way to the docs site, is deprecated for documentation purposes and excluded from `docs-manifest.json` v3.

## Two-consumer fractal in concrete form

The `feedback_two_consumer_fractal` memory describes the principle: "Every product surface must work for both Human users AND LM agents. UI is one consumer of the API; MCP gateway + Charter CLI are siblings." The MCP gateway is the concrete instance:

- Same backend product Workers as `stackbilder.com`
- Same `AUTH_SERVICE` for entitlements
- Same quota model
- Different transport (MCP), different auth (OAuth), different consumer (LM agents)

A new feature lands by adding a route on `stackbilder.com` (the canonical contract); the gateway gains parity by exposing it as an MCP tool that calls the same backend service binding. The web UI is the human surface; the gateway is the agent surface.

## Authority

- **Gateway repo:** `Stackbilt-dev/stackbilt-mcp-gateway`
- **Wrangler config (binding map):** `Stackbilt-dev/stackbilt-mcp-gateway/wrangler.toml`
- **Public registry:** `registry.modelcontextprotocol.io` (search: `stackbilt`)
- **Docs site page:** `https://docs.stackbilt.dev/mcp`
- **Canonical platform-side reference:** `Stackbilt-dev/stackbilt-web/docs/mcp.md`
- **Manifest pointing here:** `Stackbilt-dev/docs/docs-manifest.json` v3
- **Two-consumer fractal principle:** memory `feedback_two_consumer_fractal`

When any of these contracts change shape (new service binding, new tool catalog, auth model change, transport addition, gateway URL change), update both the code and this page. Advance `last_verified`.
