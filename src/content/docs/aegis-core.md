---
title: "AEGIS Core"
description: "Persistent AI agent framework for Cloudflare Workers — multi-tier memory, autonomous goals, dreaming cycles, MCP native. Deploy standalone or extend via createAegisApp()."
section: "ecosystem"
order: 10
color: "#6366f1"
tag: "10"
lastVerified: "2026-06-27"
---

# AEGIS Core

[![npm version](https://img.shields.io/npm/v/@stackbilt/aegis-core?label=aegis-core&color=6366f1&style=for-the-badge)](https://www.npmjs.com/package/@stackbilt/aegis-core)

**A persistent AI agent framework for Cloudflare Workers.**  
**GitHub:** [Stackbilt-dev/aegis-oss](https://github.com/Stackbilt-dev/aegis-oss) · Apache-2.0

Part of the [Stackbilt ecosystem](/ecosystem) alongside [Charter CLI](/getting-started), [evidence-core](/evidence-core), [audit-chain](/audit-chain), and [worker-observability](/worker-observability). For a lightweight personal assistant on the same Cloudflare primitives, see [EdgeClaw](/edgeclaw). [MindSpring](/mindspring) integrates with AEGIS via the `conversation-facts` NDJSON ingestion pipeline.

Unlike chat-based AI tools that forget between sessions, AEGIS maintains persistent identity, memory, and state across every interaction. It runs on the Cloudflare Workers free tier with Workers AI as the base inference path. Claude and Groq are optional executor upgrades.

---

## Two ways to use

**Standalone** — clone, configure, deploy. Full agent in minutes.

**Dependency** — `pnpm add @stackbilt/aegis-core` and compose your own agent using `createAegisApp()`.

---

## Core capabilities

| Capability | What it does |
|-----------|-------------|
| **Cognitive Kernel** | Intent classification → executor dispatch. Workers AI primary; Claude and Groq optional upgrades. Procedural memory routing learns which executor fits which task. |
| **Multi-Tier Memory** | Episodic (events), semantic (facts), procedural (skills), narrative (story arcs). Memory consolidates, decays, and strengthens over time. |
| **Autonomous Goals** | Set goals with standing orders. AEGIS pursues them on a schedule, tracks progress, surfaces blockers, and reports results. |
| **Dreaming Cycle** | Nightly self-reflection over conversation history. Discovers patterns, consolidates knowledge, proposes new tools. PRISM synthesis finds cross-domain connections across memory facts. |
| **Runtime Dynamic Tools** | Create reusable prompt-template tools at runtime — during conversations or via self-improvement. Stored in D1. Auto-promoted at 20 uses. TTL + GC lifecycle. |
| **Entropy Detection** | Monitors for ghost tasks (>7d stale), dormant goals (>14d), stale agenda items. Calculates system entropy score. Surfaced in the daily digest. |
| **MCP Server** | 20+ tools exposed via the Model Context Protocol. Connect any MCP-compatible client (Claude Code, Cursor, Codex). |
| **Content Pipeline** | Scheduled content generation and social media drip posting via AT Protocol. |
| **ADF Governance** | `.ai/` config files control behavior, constraints, and architectural rules. Version-controlled agent configuration — see [Charter CLI](/getting-started). |

---

## Standalone deploy

```bash
git clone https://github.com/Stackbilt-dev/aegis-oss.git
cd aegis-oss/web
pnpm install

# Configure
cp wrangler.toml.example wrangler.toml          # fill in account_id, database_id
cp src/operator/config.example.ts src/operator/config.ts  # customize identity

# Set up D1
npx wrangler d1 create my-agent
npx wrangler d1 execute my-agent --file=schema.sql

# Auth token
npx wrangler secret put AEGIS_TOKEN   # random bearer token

# Deploy
pnpm deploy
```

Visit your deployed URL and authenticate with `AEGIS_TOKEN`. For terminal access:

```bash
AEGIS_HOST=your-worker.workers.dev AEGIS_TOKEN=your-token npx @stackbilt/aegis-core --quick
```

---

## Use as a dependency

```bash
pnpm add @stackbilt/aegis-core
```

```ts
import { createAegisApp } from '@stackbilt/aegis-core';

const aegis = createAegisApp({
  operator: myConfig,
  routes: [{ prefix: '/', router: myRoutes }],
  scheduledTasks: [myCustomTask],
});

export default {
  fetch: aegis.app.fetch,
  scheduled: (e, env, ctx) => ctx.waitUntil(aegis.runScheduled(buildEdgeEnv(env))),
};
```

Core provides: kernel, memory, dispatch, base routes, MCP server, 26 scheduled task slots.  
You provide: operator config, custom routes, integrations, secrets.

### Extension interfaces

| Interface | Purpose |
|-----------|---------|
| `ScheduledTaskPlugin` | Add cron-driven background work |
| `ExecutorPlugin` | Register a new LLM executor |
| `RoutePlugin` | Mount custom Hono routes |
| `McpToolPlugin` | Expose additional MCP tools |

---

## Scheduled tasks

AEGIS ships with 26 scheduled tasks (cron `0 * * * *`). Key tasks:

| Task | Cadence | What it does |
|------|---------|-------------|
| Dreaming | Daily | Conversation review → memory facts, new tools, persona updates, PRISM synthesis |
| Goals | Non-SI hours | Autonomous goal execution with standing orders |
| Consolidation | Hourly | Memory dedup and decay |
| Entropy detection | Hourly | Ghost tasks, dormant goals, stale agenda surfaced to digest |
| Self-improvement | 6h | Multi-repo codebase scan → issues/PRs |
| Daily digest | 09 UTC | Operator brief email |

---

## Executors

| Executor | Cost | When to use |
|----------|------|------------|
| Workers AI | Free (included) | Default. Handles most queries. |
| Groq | Paid (per token) | Speed-sensitive tasks, function calling |
| Claude (Anthropic) | Paid (per token) | Complex reasoning, long context, code |

The kernel classifies intent and routes to the appropriate executor. Procedural memory learns routing patterns over time.

---

## MCP server

AEGIS exposes a Model Context Protocol server at `/mcp` on your deployed worker. For the Stackbilt-hosted MCP gateway that connects agents to the broader platform (scaffolding, img-forge, architecture flows), see [MCP Gateway](/mcp).

Connect Claude Code or any MCP client to AEGIS directly:

```json
{
  "mcpServers": {
    "aegis": {
      "url": "https://your-worker.workers.dev/mcp",
      "headers": { "Authorization": "Bearer <AEGIS_TOKEN>" }
    }
  }
}
```

Tools include: memory read/write, agenda management, goal CRUD, conversation history, cc_task queue, wiki, and dynamic tool invocation.

---

## Secrets

| Secret | Required | Purpose |
|--------|----------|---------|
| `AEGIS_TOKEN` | Yes | Bearer token for all authenticated routes |
| `ANTHROPIC_API_KEY` | No | Claude executor |
| `GROQ_API_KEY` | No | Groq executor |
| `RESEND_API_KEY` | No | Outbound email (daily digest, heartbeat) |

Workers AI requires no key — it's available natively in the Workers runtime.
