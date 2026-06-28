---
title: "bildy"
description: "Local-first LLM gateway for Claude Code — routes cheap turns to Groq/Cloudflare Workers AI, keeps Claude for the hard parts. Shadow mode shows projected savings before you go live."
section: "ecosystem"
order: 22
color: "#84cc16"
tag: "22"
lastVerified: "2026-06-28"
---

# bildy

**GitHub:** [Stackbilt-dev/bildy](https://github.com/Stackbilt-dev/bildy) · MIT

Part of the [Stackbilt ecosystem](/ecosystem). One command that connects Claude Code (or Codex) to your own API keys and routes cheap turns to Cloudflare Workers AI, Groq, or Cerebras — keeping Claude in reserve for what only Claude can do. Powered by [llm-providers](/llm-providers) routing logic under the hood.

macOS and Linux (WSL2 for Windows).

```bash
bildy
```

Picks the tool. Starts the gateway if needed. Sets the environment. You get the shell back when the session exits.

---

## Why

Every Claude Code session has turns that don't need frontier intelligence — "summarize this file", "draft this function", "plan the next step". These turns cost the same as the ones where Claude actually has to reason.

bildy intercepts each request, classifies the cognitive load, and routes:

- **planning / code_draft / summary** → Cloudflare Workers AI, Groq, or Cerebras (fast, cheap)
- **tool_loop / long_context** → Anthropic (Claude for the hard parts)

**Shadow mode** is on by default — logs what *would* route while sending everything to Anthropic. After a real session, check `/shadow/stats` to see projected savings before going live.

---

## Setup

```bash
git clone https://github.com/Stackbilt-dev/bildy.git
cd bildy && npm install

# Add at least one provider key
export GROQ_API_KEY=gsk_...           # free tier — start here
export CEREBRAS_API_KEY=csk-...       # optional
export ANTHROPIC_API_KEY=sk-ant-...   # for fallback / tool-heavy turns

# Point Claude Code at the gateway
export ANTHROPIC_BASE_URL=http://localhost:8787
export ANTHROPIC_API_KEY=local-dev-key

# Start the gateway + launch Claude Code
npm run start &
claude
```

Or use the guided wizard:

```bash
npm run install:global   # symlinks bildy + bildy-gw into ~/.local/bin
source ~/.bashrc
bildy init               # guided setup
bildy                    # launch picker
```

---

## Routing Table

| Route class | Signal | Default provider order |
|---|---|---|
| `tool_loop` | `tool_result` in message history | cloudflare → anthropic → openai → groq → cerebras |
| `long_context` | Estimated input >12k tokens | nvidia → groq → anthropic → openai → cloudflare |
| `planning` | Tools present, no tool loop yet | cloudflare → groq → cerebras → nvidia |
| `code_draft` | Code generation intent, no tool loop | cloudflare → groq → cerebras → nvidia |
| `summary` | Summarize / explain / extract | cloudflare → cerebras → groq |
| `fallback_safe` | Unknown | cloudflare → groq → cerebras |

Provider order matters — first compatible provider wins. The gateway picks the model from the provider's catalog by use case, not a hardcoded name.

---

## Shadow Mode

The gateway runs in shadow mode by default: it logs what *would* be routed but still sends everything to Anthropic. Check savings projections at `http://localhost:8787/shadow/stats` after a real session. When you're satisfied with the routing decisions, disable shadow mode to start saving.

---

## Configuration

bildy writes keys to `.env` in the clone directory. If the interactive wizard fails to detect your shell profile, use the manual env setup above and copy-paste the exports into your shell config.

If bildy breaks your shell, you keep both pieces. This is built for a specific solodev workflow — check the issues list before filing a new one.
