---
title: "llm-providers"
description: "Multi-provider LLM abstraction layer with automatic failover, graduated circuit breakers, cost tracking, and intelligent retry. Built for Cloudflare Workers."
section: "ecosystem"
order: 14
color: "#3b82f6"
tag: "14"
lastVerified: "2026-06-28"
---

# llm-providers

[![npm version](https://img.shields.io/npm/v/@stackbilt/llm-providers?label=llm-providers&color=3b82f6&style=for-the-badge)](https://www.npmjs.com/package/@stackbilt/llm-providers)

**GitHub:** [Stackbilt-dev/llm-providers](https://github.com/Stackbilt-dev/llm-providers) · MIT

Part of the [Stackbilt ecosystem](/ecosystem). Provides the multi-provider inference layer used across the [Stackbilder platform](/platform) and available as a standalone npm package. For image generation, use [img-forge](/img-forge) — `ImageProvider` in this package is deprecated.

A multi-provider LLM abstraction layer with automatic failover, graduated circuit breakers, cost tracking, and intelligent retry. Extracted from a production orchestration platform handling 80K+ LOC. Built for Cloudflare Workers but runs anywhere with a standard `fetch` API.

---

## Install

```bash
npm install @stackbilt/llm-providers
```

Zero runtime dependencies.

---

## Quick Start

```typescript
import { LLMProviders, MODELS } from '@stackbilt/llm-providers';

const llm = new LLMProviders({
  anthropic: { apiKey: process.env.ANTHROPIC_API_KEY },
  cloudflare: { ai: env.AI },
  groq: { apiKey: process.env.GROQ_API_KEY },
  defaultProvider: 'auto',
  costOptimization: true,
  enableCircuitBreaker: true,
});

const response = await llm.generateResponse({
  messages: [{ role: 'user', content: 'Summarize the circuit breaker pattern.' }],
  maxTokens: 1000,
});

console.log(response.message);
console.log(`Provider: ${response.provider}, Cost: $${response.usage.cost}`);
```

Auto-discover from environment:

```typescript
// Scans env for ANTHROPIC_API_KEY, OPENAI_API_KEY, GROQ_API_KEY, CEREBRAS_API_KEY,
// NVIDIA_API_KEY, and the AI binding — configures only what's present
const llm = LLMProviders.fromEnv(env, { costOptimization: true, enableCircuitBreaker: true });
```

---

## Providers

| Provider | Streaming | Tools | Default model |
|----------|-----------|-------|---------------|
| **Anthropic** | Yes | Yes | `claude-haiku-4-5-20251001` |
| **OpenAI** | Yes | Yes | `gpt-4o-mini` |
| **Cloudflare Workers AI** | Yes | Selected | Catalog-driven |
| **Cerebras** | Yes | GLM, Qwen, GPT-OSS | ~2,200 tok/s |
| **Groq** | Yes | LLaMA 3.3 70B, GPT-OSS 120B | Ultra-fast inference |
| **NVIDIA NIM** | Yes | Llama, Nemotron, Mistral Large 2 | Dev-tier credits |

---

## Circuit Breaker

Each provider has a graduated 4-state circuit breaker that routes traffic away from failing providers with probabilistic degradation instead of a hard on/off switch.

| State | Behavior |
|-------|----------|
| **Closed** | 100% traffic to primary |
| **Degraded** | Probabilistic split: 90% → 70% → 40% → 10% as failures accumulate |
| **Recovering** | Success steps traffic back up one level at a time |
| **Open** | 0% traffic. After `resetTimeout` ms, failures decay and traffic resumes |

Default: 5-step curve `[1.0, 0.9, 0.7, 0.4, 0.1]`, 60s reset, 5-minute monitoring window.

In Cloudflare Workers, circuit state is per-isolate. Persist to KV/D1/Durable Objects if you need state to survive across requests:

```typescript
import { defaultCircuitBreakerManager, CreditLedger } from '@stackbilt/llm-providers';

// On request start: restore
const json = await env.LLM_STATE.get('circuit-breakers');
if (json) defaultCircuitBreakerManager.restore(json);

// On request end: persist
await env.LLM_STATE.put('circuit-breakers', defaultCircuitBreakerManager.serialize());
```

---

## Cost Tracking

```typescript
import { CreditLedger, LLMProviders } from '@stackbilt/llm-providers';

const ledger = new CreditLedger({
  budgets: [
    { provider: 'anthropic', monthlyBudget: 100, rateLimits: { rpm: 60 } },
    { provider: 'openai', monthlyBudget: 50 },
  ],
});

ledger.on((event) => {
  if (event.type === 'threshold_crossed') {
    console.warn(`${event.provider}: ${event.tier} — ${event.utilizationPct.toFixed(0)}% of budget`);
  }
});

const llm = new LLMProviders({ anthropic: { apiKey: '...' }, ledger });
```

Threshold alerts fire at 80%, 90%, 95% utilization.

---

## Tool-Use Loop

`generateResponseWithTools` owns the full `generate → parse → execute → repeat` cycle with iteration caps and cost limits:

```typescript
const result = await llm.generateResponseWithTools(
  {
    messages: [{ role: 'user', content: 'What is 2 + 2 * 3?' }],
    tools: [{ type: 'function', function: { name: 'calculate', description: '...', parameters: { type: 'object', properties: { expr: { type: 'string' } }, required: ['expr'] } } }],
  },
  {
    execute: async (name, args) => eval((args as { expr: string }).expr),
  },
  { maxIterations: 5, maxCostUSD: 0.10 }
);
```

---

## Canonical Provider Contract

The canonical boundary for downstream gateways:

```
client protocol → gateway adapter → CanonicalLLMRequest → llm-providers → vendor API
```

```typescript
import { canonicalToLLMRequest, normalizeLLMRequest, normalizeLLMResponse } from '@stackbilt/llm-providers';
```

`normalizeLLMRequest()` maps legacy aliases into the canonical shape. `normalizeLLMResponse()` provides a stable response shape with normalized routing metadata.

---

## Routing Introspection

Pre-flight routing inspection without dispatching:

```typescript
import { getRoutingInfo } from '@stackbilt/llm-providers';

const info = getRoutingInfo(
  { messages: [{ role: 'user', content: 'Call the weather tool' }], tools: [...] },
  ['cloudflare', 'cerebras', 'groq']
);

// info.useCase    → 'TOOL_CALLING'
// info.provider   → 'cerebras'
// info.model      → 'zai-glm-4.7'
// info.modelLifecycle → 'active'
```

---

## Built-in Tools (Server-Side)

Some models run tools server-side — no execute callback required:

```typescript
const res = await llm.generateResponse({
  model: MODELS.GROQ_COMPOUND,
  messages: [{ role: 'user', content: 'Find sources on topic X.' }],
  builtInTools: [{ type: 'web_search' }],
});
// res.metadata.builtInToolResults → [{type, name, results:[{title, url, content, score}]}]
```

Supported: `web_search`, `visit_website`, `browser_automation`, `code_interpreter`, `wolfram_alpha` (model-gated). Built-in tool surcharges are billed by the provider, not tracked in `TokenUsage`.

---

## Cloudflare AI Gateway

Route requests through Cloudflare AI Gateway for network-layer caching and rate-limit absorption:

```typescript
const provider = new AnthropicProvider({
  apiKey: 'sk-ant-...',
  cfGateway: { accountId: 'YOUR_ACCOUNT_ID', gatewayId: 'my-gateway' },
});
```

Composes with llm-providers' semantic routing — the factory picks provider/model, the gateway sits underneath each provider's HTTP and handles caching transparently.

---

## Streaming

```typescript
const stream = await llm.generateResponseStream({
  messages: [{ role: 'user', content: 'Tell me a story.' }],
});
const reader = stream.getReader();
while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  process.stdout.write(value);
}
```

Pre-stream HTTP errors (401, 429, 503, circuit open) fall over to the next provider before emitting the first chunk.

---

## Deprecation Notice

`ImageProvider` in this package is deprecated. Use [img-forge](/img-forge) or its MCP tools for image generation. llm-providers handles text inference and vision understanding only. `ImageProvider`, `ImageProviderConfig`, and `IMAGE_MODELS` will be removed in the next major version.
