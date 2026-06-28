---
title: "AI Playbook"
description: "Battle-tested frameworks for thinking with AI — 11 reasoning frameworks, 8 Vibecoding archetypes, 48 task prompts, and drop-in Claude Code skills from the Stackbilt team."
section: "ecosystem"
order: 17
color: "#f97316"
tag: "17"
lastVerified: "2026-06-28"
---

# AI Playbook

**GitHub:** [Stackbilt-dev/ai-playbook](https://github.com/Stackbilt-dev/ai-playbook) · MIT

Part of the [Stackbilt ecosystem](/ecosystem). Distilled from 70+ real-world projects. Frameworks for thinking *with* AI — not just talking to it. Practical drop-in assets for Claude Code users and anyone building with LLMs.

**Contents:**
- 11 reasoning frameworks
- 8 Vibecoding philosophical archetypes
- 47 task prompts
- 12 Claude Code skills
- 3 CLAUDE.md templates

---

## Quick Start

**Option A — drop a Claude Code skill into your project:**

```bash
mkdir -p .claude/skills/adhd-optimize
cp ai-playbook/claude-code/skills/adhd-optimize.md .claude/skills/adhd-optimize/SKILL.md
# Then use: /adhd-optimize "Your verbose prompt here"
```

**Option B — upgrade your CLAUDE.md:**

```bash
cp ai-playbook/claude-code/examples/claude-md-adhd.md CLAUDE.md
```

**Option C — paste a framework into any AI conversation:**

```
🎯 TASK: Implement user auth
📋 CONTEXT: Cloudflare Workers, JWT, D1 database
✅ OUTPUT: Working auth middleware with tests
⚠️ CONSTRAINTS: No session storage, stateless only
```

That's the [ADHD Prompting Framework](https://github.com/Stackbilt-dev/ai-playbook/tree/main/frameworks/adhd-prompting/) — works in Claude, GPT, Gemini, anywhere.

---

## The Vibecoding System

Eight archetypal personas, each a fusion of 3+ wisdom traditions. Not prompt templates — philosophical lenses that change how the AI thinks.

| | Archetype | Essence | Fused from |
|---|-----------|---------|------------|
| 🏰 | **Clarity Architect** | Structural simplicity | Stoic Guardian + Occam's Minimalist + Cognitive Load Theory |
| 🪞 | **Direct Mirror** | Immediate insight | Zen Mirror + Phenomenological Observer + Mindful Observer |
| 🎵 | **Flow Director** | Dynamic harmony | Jazz Director + Flow Guide + Wabi-Sabi Craftsperson |
| 🧱 | **Truth Builder** | Foundational rigor | First Principles Architect + Empiricist + Falsification Challenger |
| 🔮 | **Pattern Synthesizer** | Holistic integration | Systems Synthesizer + Pattern Analyst + Gestalt Weaver |
| 🦉 | **Wisdom Guide** | Ethical integration | Confucian Guide + Circle Keeper + Prudent Synthesizer |
| 📐 | **Creative Organizer** | Aesthetic function | Bauhaus Architect + Swiss Information + Ma Gardener |
| 🧭 | **Purpose Seeker** | Authentic discovery | Sufi Seeker + Existential Clarifier + Socratic Investigator |

**How to pick:** Choose what resonates, not what sounds most useful. Combine two for complex problems.

| Situation | Recommended |
|-----------|-------------|
| Technical complexity | Truth Builder + Pattern Synthesizer |
| Creative exploration | Flow Director + Purpose Seeker |
| Overwhelming information | Clarity Architect + Creative Organizer |
| Unclear objectives | Direct Mirror + Wisdom Guide |
| Ethical considerations | Wisdom Guide + Purpose Seeker |

---

## Claude Code Skills

Drop-in [Charter](/getting-started)-compatible skills for common workflows. Copy a `SKILL.md` into `.claude/skills/<name>/` and invoke with `/<name>`.

Available skills include: `adhd-optimize`, `code-review`, `spec-writer`, `refactor-plan`, `debug-session`, `pr-description`, `test-writer`, `doc-writer`, `arch-review`, `context-builder`, `commit-helper`, and `scope-check`.

---

## Reasoning Frameworks

11 structured frameworks for common AI interaction patterns. Each is designed to be pasted directly into any AI conversation — no tooling required.

The ADHD Prompting Framework is the flagship: `🎯 TASK / 📋 CONTEXT / ✅ OUTPUT / ⚠️ CONSTRAINTS`. Forces clarity on both sides of the conversation and dramatically reduces hallucinated requirements.

---

## Who This Is For

- **Developers** using Claude Code who want to apply consistent reasoning patterns across projects
- **AI-curious practitioners** building prompting habits from first principles rather than tip lists
- **Teams** standardizing on shared frameworks for AI-assisted work

The playbook is opinionated and practice-tested. If a framework hasn't worked in production, it's not here.
