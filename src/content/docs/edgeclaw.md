---
title: "EdgeClaw"
description: "OpenClaw on Cloudflare Workers — persistent personal AI assistant via Durable Objects + Workers AI. Deploy in 5 minutes. Telegram, Slack, HTTP."
section: "ecosystem"
order: 21
color: "#14b8a6"
tag: "21"
lastVerified: "2026-06-28"
---

# EdgeClaw

**GitHub:** [Stackbilt-dev/edgeclaw](https://github.com/Stackbilt-dev/edgeclaw) · MIT

Part of the [Stackbilt ecosystem](/ecosystem). [OpenClaw](https://github.com/openclaw/openclaw) on Cloudflare Workers — persistent personal AI assistant running on Durable Objects + Workers AI. No server. No machine to babysit. 300 edges. Deploy in 5 minutes.

For the full production cognitive kernel with multi-tier memory, autonomous goals, and scheduled tasks, see [AEGIS Core](/aegis-core). EdgeClaw is the clean deployable template for personal use — same Cloudflare primitives, packaged for solo deployment.

---

## What This Is

OpenClaw runs as a local daemon: SQLite state, a long-running process, your own hardware for LLM inference. EdgeClaw takes that model to the edge:

| OpenClaw (local) | EdgeClaw (CF Workers) |
|---|---|
| SQLite per agent | Durable Object per agent (SQLite-backed) |
| Local daemon | DO hibernation — always available, no idle cost |
| LanceDB vector memory | Vectorize (coming) |
| LLM API calls | Workers AI (Llama 4 Scout) |
| Channel socket listeners | Incoming webhooks |
| `~/.openclaw/` filesystem | KV + R2 |

---

## Deploy in 5 Minutes

```bash
git clone https://github.com/Stackbilt-dev/edgeclaw
cd edgeclaw && npm install

# Create KV namespace
npx wrangler kv:namespace create edgeclaw-skills
# Paste the returned id into wrangler.toml → kv_namespaces[0].id

# Deploy
npx wrangler deploy

# Set your channel secrets
npx wrangler secret put TELEGRAM_BOT_TOKEN
npx wrangler secret put TELEGRAM_SECRET

# Wire Telegram webhook
curl "https://api.telegram.org/bot<TOKEN>/setWebhook" \
  -d "url=https://edgeclaw.<your-subdomain>.workers.dev/channels/telegram&secret_token=<SECRET>"
```

Message your bot and it responds.

---

## Channels

| Channel | Status | Setup |
|---------|--------|-------|
| Telegram | Ready | `wrangler secret put TELEGRAM_BOT_TOKEN` + setWebhook |
| Slack | Ready | `wrangler secret put SLACK_SIGNING_SECRET SLACK_BOT_TOKEN` |
| HTTP REST | Ready | `POST /chat` — for testing and integrations |
| WhatsApp | Coming soon | — |
| Discord | Coming soon | — |

---

## Architecture

```
Channel webhook → Hono router → AgentSession DO (per user)
                                      ↓
                               Workers AI (Llama 4 Scout)
                                      ↓
                          SQLite history + KV memory
```

Each user gets their own `AgentSession` Durable Object — persistent conversation history, isolated state, hibernation when idle (no compute cost). Workers AI handles inference free on Cloudflare's network.

---

## Adding Skills

Skills are functions registered on the `AgentSession`. Drop a file in `src/skills/` and import it in `agent-session.ts`. Skills can read/write KV, call external APIs, or query D1. The model invokes them via tool use.

---

## EdgeClaw vs. AEGIS Core

| | EdgeClaw | [AEGIS Core](/aegis-core) |
|---|---|---|
| **Purpose** | Personal assistant, 5-min deploy | Production cognitive kernel |
| **Memory** | SQLite history + KV | Multi-tier (working/episodic/semantic/long-term) |
| **Goals** | None | Autonomous goals + dreaming cycles |
| **Governance** | None | ADF-governed, MCP native |
| **Audience** | Solo deployment | Production platform |

Start with EdgeClaw. Graduate to AEGIS when you need the full system.
