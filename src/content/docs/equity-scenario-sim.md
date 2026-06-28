---
title: "equity-scenario-sim"
description: "Cap table simulator for partnership negotiations — model deal structures, vesting schedules, milestone-based equity, and exit waterfall payouts in real-time."
section: "ecosystem"
order: 24
color: "#fb923c"
tag: "24"
lastVerified: "2026-06-28"
---

# equity-scenario-sim

**GitHub:** [Stackbilt-dev/equity-scenario-sim](https://github.com/Stackbilt-dev/equity-scenario-sim) · MIT

Part of the [Stackbilt ecosystem](/ecosystem). A sophisticated cap table simulator designed to model partnership negotiations and understand the financial impact of bringing on new partners. Adjust deal structures, vesting schedules, and performance milestones to see real-time effects on ownership percentages and exit payouts.

---

## Quick Start

```bash
git clone https://github.com/Stackbilt-dev/equity-scenario-sim.git
cd equity-scenario-sim
yarn install     # or: npm install
yarn dev         # or: npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser.

**Prerequisites:** Node.js v18+, npm v9+. Yarn recommended on Windows.

---

## Features

### Core Modeling

- **Two Partnership Paths** — compare Path A vs. Path B deal structures side by side
- **Flexible Investment Vehicles** — model priced rounds or SAFEs with custom valuations
- **Milestone-Based Vesting** — performance equity that unlocks based on real business milestones
- **Dynamic Cap Table** — live ownership distribution visualization as you adjust parameters
- **Founder Flexibility** — model multiple founders with custom equity splits

### Analysis & Planning

- **Exit Waterfall** — detailed exit scenario modeling (conservative / base / optimistic)
- **Milestone Timeline** — interactive vesting schedule visualization
- **Pool Target Planning** — set desired option pool percentage with actionable recommendations
- **Exit Payouts** — exact dollar amounts per stakeholder at different valuations

### Scenario Management

- **Save Scenarios** — store deal structures with names and descriptions
- **Scenario History** — access saved scenarios with timestamps
- **Persistent Storage** — scenarios saved in browser localStorage

---

## Safety Guardrails

Built-in warnings for common deal structure pitfalls:

| Check | Threshold |
|-------|-----------|
| Partner equity cap | Max 12% per partner |
| Employee option pool minimum | Min 8% |
| Founder concentration risk | Warn if single founder >70% |
| Founder equity disparity | Warn if disparity >3× between co-founders |

Guardrail violations appear as visual health indicators — they warn, they don't block.

---

## Use Cases

- Modeling equity splits before bringing on a new partner or co-founder
- Comparing SAFE vs. priced round structures at different cap levels
- Understanding dilution impact of a new option pool before the round
- Running exit scenarios to align expectations before closing a deal

This is a planning and negotiation tool, not legal or financial advice.
