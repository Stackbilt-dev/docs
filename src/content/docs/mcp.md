---
title: "MCP Gateway — Upstream/Downstream Architecture"
description: "Architecture map for Stackbilt-dev/stackbilt-mcp-gateway — the OAuth-authenticated Cloudflare Worker at mcp.stackbilt.dev/mcp that exposes the platform's product workers as a single MCP-compliant remote server. Sibling consumer of the same backend service bindings as…"
section: "platform"
order: 5
color: "#22d3ee"
tag: "05"
lastVerified: "2026-06-19"
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
| OAuth 2.1 + PKCE (DCR) | `Authorization: Bearer <oauth-access-token>` | Recommended for end-user agent connections (Claude Desktop, Claude Code, MCP Inspector). Clients self-register via Dynamic Client Registration — no pre-issued `client_id` required. |
| Static Bearer | `Authorization: Bearer <STACKBILT_MCP_TOKEN>` | Server-to-server / CI integrations. |

### Dynamic Client Registration (DCR)

The gateway exposes a [RFC 7591](https://www.rfc-editor.org/rfc/rfc7591) Dynamic Client Registration endpoint. MCP clients that support DCR (Claude Desktop, Claude Code, MCP Inspector) register automatically on first connect — there is no static `client_id` or `client_secret` to configure in advance.

| OAuth endpoint | Path |
|---|---|
| Authorization | `https://mcp.stackbilt.dev/authorize` |
| Token | `https://mcp.stackbilt.dev/token` |
| Client Registration | `https://mcp.stackbilt.dev/register` |

**Scopes:**

| Scope | Access |
|---|---|
| `read` | `tools/list`, `tools/call` for read-only tools |
| `generate` | All mutating tools (`scaffold_create`, `image_generate`, etc.) |

**Connection settings for MCP clients:**

| Setting | Value |
|---|---|
| Transport | Streamable HTTP |
| MCP endpoint | `https://mcp.stackbilt.dev/mcp` |
| Auth type | Dynamic OAuth Client (DCR) |
| Client ID / Secret | Not applicable — issued dynamically at registration |

The gateway intentionally does **not** accept `ea_*` API keys on the `/mcp` path (those are issued from `stackbilder.com/settings` for the platform's REST API). The `/api/mcp` path accepts Bearer API keys for server-to-server use.

## Transports

| Transport | Endpoint | Method | Use Case |
|---|---|---|---|
| **Streamable HTTP** | `/mcp` | POST | Modern MCP clients, single request/response |
| **SSE Stream** | `/mcp` | GET | Server-pushed events, session-based (requires auth + `MCP-Session-Id`) |
| **Session teardown** | `/mcp` | DELETE | Terminate a session |

Streamable HTTP sessions use the `Mcp-Session-Id` header. The first `initialize` POST returns a session ID; include it on subsequent requests; `DELETE /mcp` with the session ID to terminate. Capability negotiation happens via the standard MCP `initialize` message over POST — there is no separate unauthenticated info endpoint.

## Tool catalog

| Prefix | Backend | Description |
|---|---|---|
| `scaffold_*` | `TAROTSCRIPT` | Deterministic project scaffolding, classification, GitHub publishing, CF deployment. `scaffold_create` response includes `cloudflareManifest: { status, stale, valid_until? }`. |
| `image_*` | `IMG_FORGE` | AI image generation (5 quality tiers: draft / standard / premium / ultra / ultra_plus). |
| `agent_*` | `TAROTSCRIPT` | C-level agent consultations (CTO, CISO, CFO, CPO, architect). |
| `billing_*` | `AUTH_SERVICE` | Credit balance, quota status, and autonomous credit purchase. |

`flow_*` tools were removed on 2026-06-12 (v0.1.0). `visual_*` tools are present but gated as internal-only.

For the authoritative live tool list, call `tools/list` on the gateway or read the gateway repo README (`Stackbilt-dev/stackbilt-mcp-gateway`). The `server.json` in that repo is the MCP registry entry.

## TarotScript direct MCP surface

In addition to the gateway, the `tarotscript-worker` itself exposes a peer-to-peer MCP surface at `/mcp/tools` and `/mcp/invoke` for callers that hold a direct API key and do not need OAuth.

| Tool ID | Description |
|---|---|
| `tarotscript.run_grader` | Grade an artifact against a rubric deck — returns per-dimension findings (TaskFit, Support, Actionability), aggregate score, gap report, and a chain-verifiable receipt. |

This surface is additive and orthogonal to the gateway. Use the gateway for end-user agent connections; use the direct surface for CI pipelines and server-to-server callers with a static Bearer key.

Full schema and endpoint reference: [TarotScript Runtime Reference](./tarotscript.md).

## Documentation surface

The canonical platform-side reference for the gateway is this page (`docs.stackbilder.com/mcp`). The gateway repo (`Stackbilt-dev/stackbilt-mcp-gateway`) also carries `docs/api-reference.md`, `docs/user-guide.md`, and `docs/architecture.md` for developer-facing detail. The `server.json` in the gateway repo root is the MCP registry entry published at `registry.modelcontextprotocol.io`.

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
- **Docs site page:** `https://docs.stackbilder.com/mcp`
- **Canonical platform-side reference:** `Stackbilt-dev/stackbilt-web/docs/mcp.md`
- **Manifest pointing here:** `Stackbilt-dev/docs/docs-manifest.json` v3
- **Two-consumer fractal principle:** memory `feedback_two_consumer_fractal`

When any of these contracts change shape (new service binding, new tool catalog, auth model change, transport addition, gateway URL change), update both the code and this page. Advance `lastVerified`.
