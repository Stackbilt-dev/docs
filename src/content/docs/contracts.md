---
title: "contracts"
description: "Ontology-Driven Design for TypeScript — define your domain once with Zod, generate D1 migrations, Hono routes, typed SDK clients, OpenAPI specs, and test fixtures."
section: "ecosystem"
order: 19
color: "#e879f9"
tag: "19"
lastVerified: "2026-06-28"
---

# contracts

[![npm version](https://img.shields.io/npm/v/@stackbilt/contracts?label=contracts&color=e879f9&style=for-the-badge)](https://www.npmjs.com/package/@stackbilt/contracts)

**GitHub:** [Stackbilt-dev/contracts](https://github.com/Stackbilt-dev/contracts) · MIT

Part of the [Stackbilt ecosystem](/ecosystem). Pragmatic [Ontology-Driven Design](https://en.wikipedia.org/wiki/Ontology-based_data_management) for TypeScript — TypeScript + Zod instead of RDF/OWL/SHACL. Define your domain once; generate D1 migrations, Hono route handlers, typed SDK clients, OpenAPI specs, and test fixtures from a single contract definition.

The `@stackbilt/contracts` package on npm also exports the Zod schemas for all [TarotScript](/tarotscript) structured response shapes (`ScaffoldFile`, `PromptContext`, `AgentRunResult`, `GraderRunInput`, etc.) — these are the canonical types for integrating with the scaffold and agent APIs.

---

## Install

```bash
npm install @stackbilt/contracts zod
```

---

## Quick Start

Define a contract:

```typescript
import { z } from 'zod';
import { defineContract } from '@stackbilt/contracts';

const TaskContract = defineContract({
  name: 'Task',
  version: '1.0.0',
  description: 'A work item with lifecycle management',

  schema: z.object({
    id: z.string().uuid(),
    userId: z.string(),
    title: z.string().min(1).max(200),
    status: z.enum(['open', 'in_progress', 'done']),
    createdAt: z.string().datetime(),
  }),

  operations: {
    create: {
      input: z.object({ userId: z.string(), title: z.string().min(1).max(200) }),
      output: 'self',
      emits: ['task.created'],
    },
    complete: {
      input: z.object({ id: z.string().uuid() }),
      output: 'self',
      transition: { from: 'in_progress', to: 'done' },
      emits: ['task.completed'],
    },
  },

  states: {
    field: 'status',
    initial: 'open',
    transitions: {
      open:        { start: 'in_progress' },
      in_progress: { complete: 'done' },
      done:        {},
    },
  },

  surfaces: {
    api: {
      basePath: '/api/tasks',
      routes: {
        create:   { method: 'POST', path: '/' },
        list:     { method: 'GET',  path: '/' },
        get:      { method: 'GET',  path: '/:id' },
        complete: { method: 'POST', path: '/:id/complete' },
      },
    },
    db: {
      table: 'tasks',
      indexes: ['idx_task_user(user_id, status)'],
    },
  },

  authority: {
    create: { requires: 'authenticated' },
    list:   { requires: 'public' },
    get:    { requires: 'public' },
  },
});
```

---

## What Gets Generated

From a single `defineContract()` call:

| Output | What |
|--------|------|
| **D1 migration** | `CREATE TABLE tasks (...)` with correct types, constraints, and indexes |
| **Hono route handler** | Typed `GET /api/tasks`, `POST /api/tasks`, `POST /api/tasks/:id/complete` |
| **SDK client** | Typed `TaskClient.create()`, `.complete()`, `.list()`, `.get()` |
| **OpenAPI spec** | Full 3.1 spec with request/response schemas, authority annotations |
| **Test fixtures** | Valid and invalid examples for each operation |

---

## TarotScript Schema Exports

`@stackbilt/contracts` is also the canonical home of all [TarotScript](/tarotscript) response types:

```typescript
import { ScaffoldFile, PromptContext } from '@stackbilt/contracts/scaffold-response';
import { AgentRunResult } from '@stackbilt/contracts/agent-response';
import { GraderRunInput } from '@stackbilt/contracts/eval';

// Parse a scaffold response
const file = ScaffoldFile.parse(response.codegen.files[0]);
```

| Schema | Import path | Description |
|--------|-------------|-------------|
| `ScaffoldFile` | `@stackbilt/contracts/scaffold-response` | Generated file: `{ path, content, language }` |
| `PromptContext` | `@stackbilt/contracts/scaffold-response` | Governance envelope with requirements, interfaces, threats, test plan |
| `MaterializerResult` | `@stackbilt/contracts/scaffold-response` | Full scaffold materializer output |
| `AgentRunResult` | `@stackbilt/contracts/agent-response` | Structured agent advisory output |
| `GraderRunInput` | `@stackbilt/contracts/eval` | Input schema for grader runs |

Docs update cadence: aligned with `@stackbilt/contracts` semver bumps. When contracts change shape, bump the semver and open a docs PR syncing the [TarotScript reference](/tarotscript).

---

## Design Goals

- **TypeScript + Zod instead of RDF/OWL** — same centralized-knowledge goals, zero XML
- **Same goals as ODD** — grounded reasoning, zero inference, one definition drives all surfaces
- **No codegen binary** — generation happens at import time via the TypeScript module system
- **Cloudflare-native** — generated SQL targets D1, generated routes target Hono + Workers
