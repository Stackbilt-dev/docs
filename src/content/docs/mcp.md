---
title: "MCP Integration"
description: "Connect AI agents to Stackbilder via Model Context Protocol. Scaffold tools, image generation, and flow management through a unified MCP server."
section: "platform"
order: 5
color: "#22d3ee"
tag: "05"
---

# MCP Gateway

The Stackbilder platform exposes its product workers (scaffold engine, image generation, deployer) as a single MCP-compliant remote server. AI agents (Claude Code, Claude Desktop, custom MCP clients) connect once and gain access to multiple Stackbilt product workers through one OAuth-authenticated endpoint.

**Production endpoint:** `https://mcp.stackbilt.dev/mcp`

**Repo:** [`Stackbilt-dev/stackbilt-mcp-gateway`](https://github.com/Stackbilt-dev/stackbilt-mcp-gateway) — Cloudflare Worker built on `@modelcontextprotocol/sdk` and `@cloudflare/workers-oauth-provider`.

**MCP Registry:** Listed at [`registry.modelcontextprotocol.io`](https://registry.modelcontextprotocol.io/v0.1/servers?search=stackbilt).

## Why a separate Worker

The MCP gateway is a **sibling consumer** of the same backend product workers that power `stackbilder.com`. It is not a feature *of* `stackbilder.com` — it is its own deployable, with its own auth, its own KV namespace, and its own rate limiting. This matches the [two-consumer fractal](https://github.com/Stackbilt-dev/stackbilt-web/blob/main/CLAUDE.md): every product surface should work for both human users (via the web UI) and LM agents (via MCP / API key / CLI). The gateway exists so MCP-native agents have a single OAuth endpoint without taking a dependency on the web UI's session model.

## Architecture — what the gateway routes to

The gateway holds Cloudflare Service Bindings to each product Worker; tool calls are routed to the appropriate backend by the gateway's tool registry.

| Backend Worker | Service binding | Tool prefix | Purpose |
|---|---|---|---|
| **edge-auth** | `AUTH_SERVICE` | (used internally) | Tenant resolution, API-key validation, OAuth grant storage |
| **tarotscript-worker** | `TAROTSCRIPT` | `scaffold_*` | Deterministic project scaffolding, classification, GitHub publishing |
| **img-forge-mcp** | `IMG_FORGE` | `image_*` | AI image generation (multi-provider, multi-tier) |
| **stackbilt-engine** | `ENGINE` | (architecture flows) | Architecture mode pipeline (PRODUCT → SPRINT) |
| **stackbilt-deployer** | `DEPLOYER` | (deploy flows) | Cloudflare Workers deployment, D1 provisioning, DNS via API |

Token billing, quota reservation, and rate limiting all flow through `AUTH_SERVICE` — the same edge-auth surface used by `stackbilder.com`. A tenant's Pro tier on the web UI is the same Pro tier when calling tools through the gateway.

## Authentication

Two methods, in order of preference:

| Method | Header | Notes |
|---|---|---|
| OAuth 2.1 + PKCE | `Authorization: Bearer <oauth-access-token>` | Issued via `@cloudflare/workers-oauth-provider`. Recommended for end-user agent connections (Claude Desktop, Claude Code). |
| Static Bearer | `Authorization: Bearer <STACKBILT_MCP_TOKEN>` | Server-to-server / CI integrations. |

API keys (`ea_*`) issued from `stackbilder.com/settings` are accepted at the platform's REST API but are *not* the canonical credential for the MCP gateway. Use OAuth for human-in-the-loop agent flows.

## Transports

| Transport | Endpoint | Method | Use Case |
|---|---|---|---|
| **Streamable HTTP** | `/mcp` | POST | Modern MCP clients, single request/response |
| **SSE Stream** | `/mcp` | GET | Server-pushed events, session-based |
| **Server Info** | `/mcp/info` | GET | Capabilities discovery (no auth required) |

Streamable HTTP sessions use the `Mcp-Session-Id` header — the first `initialize` request returns a session ID; include it on subsequent requests; `DELETE /mcp` with the session ID to terminate.

## Client configuration

### Claude Code / Claude Desktop

```json
{
  "mcpServers": {
    "stackbilt": {
      "url": "https://mcp.stackbilt.dev/mcp",
      "transport": { "type": "streamable-http" }
    }
  }
}
```

OAuth flow runs on first connection; the Worker handles `/.well-known/oauth-authorization-server` discovery and the standard authorization-code + PKCE exchange.

### Custom MCP client (Node.js)

```typescript
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const transport = new StreamableHTTPClientTransport(
  new URL("https://mcp.stackbilt.dev/mcp")
);

const client = new Client({ name: "my-agent", version: "1.0.0" });
await client.connect(transport);

const tools = await client.listTools();
```

## Tool catalog

The gateway's tool surface is migrating: legacy `flow_*` tools (architecture pipeline) are being superseded by the deterministic `scaffold_*` family backed by TarotScript. For the live tool catalog, query `tools/list` against the gateway directly, or read the [gateway repo README](https://github.com/Stackbilt-dev/stackbilt-mcp-gateway/blob/main/README.md) for the current binding map and tool descriptions. Per-tool docs live in the gateway repo's `docs/` directory.

## Error handling

All errors follow JSON-RPC 2.0 format:

| Code | Meaning |
|---|---|
| `-32700` | Parse error (invalid JSON) |
| `-32600` | Invalid request |
| `-32601` | Method not found |
| `-32602` | Invalid params (unknown tool) |
| `-32000` | Tool execution failed |
| `-32001` | Unauthorized (token invalid or expired) |

## Observability

Every gateway tool call emits a row to the platform's audit log via `AUTH_SERVICE`. Token billing and rate-limit events flow through the same edge-auth surface as the REST API, so a tenant's quota usage on `stackbilder.com` and via the MCP gateway are consolidated into one entitlement.

## See also

- [API Reference](/api-reference) — REST API surface on `stackbilder.com/api/*` (the same backends are reachable via direct HTTP)
- [Ecosystem](/ecosystem) — how the gateway sits alongside the web UI and Charter CLI as siblings of the platform API
- [Platform](/platform) — the scaffold pipeline the gateway proxies into
