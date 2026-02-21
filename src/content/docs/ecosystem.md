---
title: "Ecosystem"
section: "ecosystem"
order: 6
color: "#c084fc"
tag: "06"
---

# Ecosystem

StackBilt is three complementary tools that work together to enforce governance across the full development lifecycle.

## The Three Pieces

| Tool | License | Role |
|---|---|---|
| **Charter** (`@stackbilt/cli`) | Apache-2.0 (open source) | Local + CI governance runtime |
| **StackBilt Architect** | Commercial | Architecture generation and ADR output |
| **Compass** | Commercial | Governance policy brain and institutional memory |

Charter is the open-source foundation. StackBilt Architect and Compass are commercial services.

## How They Fit Together

```
IDEA
  │
  ▼
Compass: governance("Can we build X?")
  │
  ├── REJECTED ──► Stop
  │
  ▼ APPROVED
StackBilt: runFullFlow(idea) → PRD + Blueprint + ADRs
  │
  ▼
Compass: red_team(architecture) → security review
  │
  ▼
Charter: validate + drift → commit and stack compliance
  │
  ▼
SHIPPED (governed)
```

## Charter: Local Enforcement

Charter runs in your terminal and CI pipeline. It validates commit trailers, scores drift against your blessed stack, and blocks merges on violations. Zero SaaS dependency — all checks are deterministic and local.

Install once, run everywhere:

```bash
npm install --save-dev @stackbilt/cli
npx charter setup --ci github --yes
```

## StackBilt Architect: Architecture Generation

The 6-mode pipeline (PRODUCT → UX → RISK → ARCHITECT → TDD → SPRINT) produces structured artifacts for each phase. Available via browser UI (trial) or MCP for agent-driven workflows.

## Compass: Policy Brain

The Compass is an AI governance agent with institutional memory — a ledger of ADRs, blessed patterns, and constitutional rules. It validates architecture decisions, runs red-team reviews, and drafts formal policy documents. Available as part of the StackBilt Pro commercial offering.

## Governance-First Development

Every significant decision flows through governance before implementation:

1. **Pre-approval** — CSA validates the idea against policy
2. **Architecture** — StackBilt generates a governed blueprint
3. **Review** — CSA red-teams the output
4. **Record** — ADRs are persisted to the ledger
5. **Commit** — Charter enforces trailer compliance at the repo level

Blessed patterns from the CSA are injected into StackBilt's ARCHITECT mode automatically when governance is enabled.
