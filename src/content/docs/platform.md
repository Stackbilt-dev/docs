---
title: "StackBilt Platform"
section: "platform"
order: 4
color: "#f472b6"
tag: "04"
---

# StackBilt Platform

StackBilt is a governance-enforced architecture planning tool that produces sprint-ready ADRs, deployable scaffolds, and structured artifacts — not vague suggestions.

## The 6-Mode Pipeline

Architecture generation runs through six sequential modes. Each mode builds on the previous, with cross-references via sequential IDs.

| Phase | Mode | Output | IDs |
|-------|------|--------|-----|
| Definition | **PRODUCT** | Product Requirements Document | REQ-001, SLA-001, CON-001 |
| Definition | **UX** | User journey maps and experience flows | UJ-001 |
| Definition | **RISK** | Risk assessment and value model | RISK-001 |
| Architecture | **ARCHITECT** | Technical blueprint: services, schemas, boundaries | COMP-001, DS-001 |
| Execution | **TDD** | Test strategy per component | TS-001 |
| Execution | **SPRINT** | Sprint-ready ADRs with dependency graph | ADR-001 |

## Structured Artifacts (v2)

Every mode emits a typed JSON artifact alongside prose. These artifacts use sequential, referenceable IDs that chain across modes:

- PRODUCT defines `REQ-001`, `SLA-001`, `CON-001`
- ARCHITECT references `reqRefs: ["REQ-001"]`, `riskRefs: ["RISK-001"]`
- TDD validates `slaRefs: ["SLA-001"]`
- SPRINT produces ADRs that trace back to components and requirements

Each artifact includes a `confidence` field with an overall score (0-100) and a `missing[]` array surfacing what the AI was not told.

## Cross-Mode Contradiction Checker

After each mode completes, an incremental checker runs 8 validation rules:

- Every `MUST` requirement has a component covering it
- Every SLA has a validation entry in TDD
- Every `CRITICAL`/`HIGH` risk has a test scenario
- ARCHITECT doesn't use technologies RISK marked as blocked
- Named events appear consistently across modes
- SPRINT surfaces requirements with no ADR

Results are available via the API as a `contradictionReport`.

## Scaffold Engine

Completed flows can generate a deployable Cloudflare Workers project (9-15 files). The scaffold engine uses category-aware routing:

| Component Category | Generated File |
|-------------------|----------------|
| compute / data / integration | `routes/*.ts` (CRUD stubs) |
| async | `worker/*-queue.ts` (queue handlers) |
| security | `worker/middleware/*.ts` (auth middleware) |
| frontend | skipped |

Template types: `workers-crud-api`, `workers-queue-consumer`, `workers-durable-object`, `workers-websocket`, `workers-cron`, `pages-static`.

Scaffolds include `scaffoldHints` (template classification + confidence score) and `nextSteps` (deployment commands).

## Governance Integration

When running a governed flow, architecture decisions are validated against blessed patterns via Compass. Violations are flagged depending on governance mode.

| Mode | Behavior | Plan Tier |
|------|----------|-----------|
| `PASSIVE` | Log only — never blocks | Free |
| `ADVISORY` | Warn on issues, flow continues | Pro |
| `ENFORCED` | Block on FAIL, require remediation | Enterprise |

Blessed patterns from Compass are injected into the ARCHITECT mode prompt automatically. Governance results (validations, persisted ADR IDs, warnings) are available via `getGovernanceStatus`.

## Output Artifacts

Each completed flow produces:

- **PRD** — structured product requirements with `REQ-001` IDs
- **Experience Maps** — user journeys and touchpoints
- **Risk Model** — value assessment, compliance flags, blocked patterns
- **Architecture Blueprint** — services, data contracts, component tree with cross-refs
- **TDD Strategy** — test surface per component with SLA validation
- **Sprint ADRs** — executable sprint plan with Architecture Decision Records
- **Scaffold** — deployable Workers project (on demand)
- **Contradiction Report** — cross-mode consistency validation

## Access

Access StackBilt via:

- **Browser UI** at [stackbilt.dev](https://stackbilt.dev) — interactive flow builder
- **MCP Server** — programmatic agent-driven workflows (see [MCP Integration](/mcp))
- **REST API** — direct HTTP integration (see [API Reference](/api-reference))
