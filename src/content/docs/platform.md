---
title: "StackBilt Platform"
section: "platform"
order: 4
color: "#f472b6"
tag: "04"
---

# StackBilt Platform

StackBilt is a governance-enforced architecture planning tool that produces sprint-ready ADRs, not vague suggestions.

## The 6-Mode Pipeline

Architecture generation runs through six sequential modes. Each mode builds on the previous.

| Phase | Mode | Output |
|---|---|---|
| Definition | **PRODUCT** | Product Requirements Document (PRD) |
| Definition | **UX** | User journey maps and experience flows |
| Definition | **RISK** | Risk assessment and value model |
| Architecture | **ARCHITECT** | Technical blueprint: services, schemas, component boundaries |
| Execution | **TDD** | Test strategy per component |
| Execution | **SPRINT** | Sprint-ready ADRs with dependency graph |

## Governance Integration

When running a governed flow, architecture decisions are automatically validated against your blessed patterns before the ARCHITECT mode output is finalized. Violations are flagged as PASS / WARN / FAIL depending on the governance mode.

| Mode | Behavior |
|---|---|
| `PASSIVE` | Log only — never blocks |
| `ADVISORY` | Warn on issues, flow continues |
| `ENFORCED` | Block on FAIL, require remediation |

## Output Artifacts

Each flow produces:

- **PRD** — structured product requirements
- **Experience Maps** — user journeys and touchpoints
- **Risk Model** — value assessment and compliance flags
- **Architecture Blueprint** — services, data contracts, component tree
- **TDD Strategy** — test surface per component
- **Sprint ADRs** — executable sprint plan with Architecture Decision Records

## Trial Access

Start a free trial to run two complete stack flows end-to-end. Trial terms (including payment requirements) follow current pricing policy.
