---
title: "worker-observability"
description: "Edge-native observability for Cloudflare Workers — health checks, structured logging, metrics, distributed tracing, SLI/SLO monitoring, alerting, and redaction. Zero production dependencies."
section: "ecosystem"
order: 13
color: "#06b6d4"
tag: "13"
lastVerified: "2026-06-27"
---

# worker-observability

**GitHub:** [Stackbilt-dev/worker-observability](https://github.com/Stackbilt-dev/worker-observability) · Apache-2.0 · v0.3.0

> **Not yet published to npm.** Install directly from GitHub:
> ```bash
> npm install github:Stackbilt-dev/worker-observability
> ```

Part of the [Stackbilt ecosystem](/ecosystem). Pairs naturally with [`@stackbilt/audit-chain`](/audit-chain) for tamper-evident audit logs and [`@stackbilt/evidence-core`](/evidence-core) for content quality signals. The hosted Pro product on [Stackbilder](/platform) wraps this library with D1-backed storage and a live dashboard.

A complete monitoring stack extracted from a production orchestration platform. Zero production dependencies — uses only the Web Crypto API and Cloudflare bindings.

---

## Quick start

`createMonitoring` initializes all modules at once with a shared redaction policy:

```typescript
import { createMonitoring, createMonitoringMiddleware } from '@stackbilt/worker-observability';

const monitoring = createMonitoring({
  service:         'my-worker',
  version:         '1.0.0',
  environment:     'production',
  analyticsEngine: env.ANALYTICS,  // optional: Cloudflare Analytics Engine binding
  enableTracing:   true,
  enableSLOs:      true,
  enableAlerting:  true,
  stackbilt: {
    endpoint: 'https://stackbilder.com/api/observe/ingest',
    token:    env.STACKBILT_TOKEN,  // optional: export to Stackbilder Pro dashboard
  },
});

monitoring.logger.info('Worker started');
monitoring.metrics.increment('requests.total');
monitoring.errorTracker.track(new Error('something broke'));
```

---

## Modules

| Module | Class / factory | Purpose |
|--------|----------------|---------|
| Health Checks | `HealthChecker`, `HealthAggregator` | Dependency probes, D1/DO/service binding checks, weighted aggregate |
| Structured Logging | `createLogger` | JSON logging, child loggers, multiple outputs |
| Metrics | `MetricsCollector`, `BusinessMetrics` | Counters, gauges, histograms, timers, pluggable exporters |
| Tracing | `Tracer` | W3C Trace Context, span-based, context propagation |
| Error Tracking | `InMemoryErrorTracker`, `CircuitBreaker` | Aggregation, circuit breaker, exponential backoff |
| SLI/SLO | `SLIMonitor` | Availability, latency, error rate objectives + error budget |
| Alerting | `AlertManager` | Threshold rules, Slack/webhook/email/PagerDuty channels |
| Redaction | `Redactor` | Credential and PII field masking — enabled by default |
| Dashboard | `createHTMLDashboard`, `DashboardAggregator` | Self-contained HTML monitoring page |

---

## Health Checks

```typescript
import { HealthChecker, commonChecks, createHealthEndpoint } from '@stackbilt/worker-observability';

const checker = new HealthChecker({ service: 'my-worker', version: '1.0.0', startTime: Date.now() });

checker.register('database',     commonChecks.database(env.DB));
checker.register('counter-do',   commonChecks.durableObject(env.COUNTER, 'health'));
checker.register('auth-service', commonChecks.serviceBinding(env.AUTH, 'auth'));
checker.register('cache', async () => ({ name: 'cache', status: 'healthy', timestamp: Date.now() }));

// Register an external dependency probe
checker.registerDependency({ name: 'stripe-api', type: 'api', url: 'https://api.stripe.com/v1', timeout: 3000, critical: true });

// Expose as a /health route handler
const healthHandler = createHealthEndpoint(checker);
```

`HealthAggregator` combines multiple checkers with weighted scoring:

```typescript
const aggregator = new HealthAggregator();
aggregator.registerService('api',    apiChecker,    1.0);
aggregator.registerService('worker', workerChecker, 0.5);

const { status, score } = await aggregator.getAggregatedHealth();
// { status: 'healthy', score: 0.92, services: [...] }
```

---

## Structured Logging

```typescript
import { createLogger, JSONOutput } from '@stackbilt/worker-observability';

const logger = createLogger({ service: 'my-worker', minLevel: 'info', output: new JSONOutput() });

logger.info('Request received', { path: '/api/users' });
logger.error('Query failed', new Error('timeout'), { table: 'users' });

// Child loggers inherit parent context
const reqLogger = logger.child({ requestId: 'abc-123', userId: 'user-1' });
reqLogger.info('Processing request');
```

Available outputs: `JSONOutput`, `ConsoleOutput`, `CloudflareAnalyticsOutput`.

---

## Metrics

```typescript
import { MetricsCollector } from '@stackbilt/worker-observability';

const metrics = new MetricsCollector({ service: 'my-worker', flushInterval: 30000 });

metrics.increment('requests.total', 1, { method: 'GET' });
metrics.gauge('connections.active', 42);
metrics.histogram('request.duration', 150, 'milliseconds', { path: '/api' });

const end = metrics.startTimer('db.query', { table: 'users' });
await db.query('SELECT ...');
end();

const result = await metrics.measure('api.call', () => fetch('https://api.example.com'));
```

Available exporters: `ConsoleExporter`, `CloudflareAnalyticsExporter`, `DatadogMetricsExporter`.

`BusinessMetrics` adds pre-built patterns for workflow tracking, agent token usage, and cost monitoring:

```typescript
const biz = new BusinessMetrics(metrics);
biz.workflowCreated('tenant-1', 'data-pipeline', 'wf-123');
biz.agentTokensUsed('tenant-1', 'claude-sonnet-4-6', 'anthropic', 1500);
biz.computeCost('tenant-1', 'inference', 0.003);
```

---

## Distributed Tracing

W3C Trace Context propagation with span-based tracing:

```typescript
import { Tracer, trace } from '@stackbilt/worker-observability';

const tracer = new Tracer({ service: 'my-worker', sampling: 1.0 });

// Async helper
const result = await trace(tracer, 'db-query', async (span) => {
  span.setAttributes({ 'db.statement': 'SELECT ...' });
  return await db.query('SELECT ...');
});

// Context propagation across service calls
const parentCtx = tracer.extract(request.headers);
const childSpan  = tracer.startSpan('downstream-call', { parent: parentCtx });
tracer.inject(childSpan.getContext(), outgoingHeaders);
```

Available exporters: `ConsoleTraceExporter`, `CloudflareTraceExporter`.

---

## Error Tracking

```typescript
import { InMemoryErrorTracker, CircuitBreaker, withErrorTracking } from '@stackbilt/worker-observability';

const tracker = new InMemoryErrorTracker();
tracker.track(new Error('connection reset'), { requestId: 'abc-123' });

// Circuit breaker: 5 failures → open for 60s, 2 successes to close
const breaker = new CircuitBreaker(5, 60000, 2);
const result = await breaker.execute(() => fetch('https://api.example.com'));
console.log(breaker.getState()); // 'closed' | 'open' | 'half-open'

// Wrap with automatic tracking
const data = await withErrorTracking(tracker, () => riskyOperation());
```

---

## SLI/SLO Monitoring

```typescript
import { SLIMonitor, AvailabilitySLI, LatencySLI, ErrorRateSLI, createStandardSLOs } from '@stackbilt/worker-observability';

const monitor = new SLIMonitor(metrics);
monitor.registerSLI(new AvailabilitySLI(metrics, 'my-worker'));
monitor.registerSLI(new LatencySLI(metrics, 'my-worker', 500));   // 500ms target
monitor.registerSLI(new ErrorRateSLI(metrics, 'my-worker', 1));   // 1% error budget

createStandardSLOs('my-worker').forEach(slo => monitor.registerSLO(slo));

const status = await monitor.getSLOStatus();
for (const [id, s] of status) {
  console.log(`${id}: ${s.status} — error budget remaining: ${s.errorBudget.remaining}%`);
}
```

---

## Alert Manager

```typescript
import { AlertManager, createStandardAlerts } from '@stackbilt/worker-observability';

const alertManager = new AlertManager(metrics, { service: 'my-worker', environment: 'production' });
createStandardAlerts('my-worker').forEach(rule => alertManager.registerRule(rule));

// Register a Slack channel
alertManager.registerChannel({
  id: 'slack', name: 'Ops Slack', type: 'slack',
  config: { webhook_url: 'https://hooks.slack.com/...' }, enabled: true,
});
```

Supported channel types: `slack`, `webhook`, `email`, `pagerduty`.

---

## Redaction

Enabled by default on all signal pathways (logs, traces, metric tags, egress payloads).

**Default deny-list covers:**
- HTTP credential headers (`authorization`, `cookie`, `x-api-key`, `x-auth-token`, etc.)
- Any field name containing `token`, `secret`, `password`, `api_key`, `bearer`, `private_key`
- Session identifiers (`session`, `session_id`, `session_token`)
- PII email fields — broad substring match with a keep-list for non-PII variants (`email_verified`, `email_template_id`, etc.)
- Client IPs (GDPR Article 4(1)): `client_ip`, `cf-connecting-ip`, `x-forwarded-for`, `true-client-ip`, etc.

Matching is case-insensitive. Field **names** remain visible; only values are replaced with `[REDACTED]`.

> **Known limitation:** The redactor operates on field names, not values. Secrets interpolated into log message strings are not caught. Use structured logging — separate message + metadata fields.

```typescript
import { Redactor } from '@stackbilt/worker-observability';

// Default — covers common credentials and PII
const r = new Redactor();
r.redact({ headers: { authorization: 'Bearer abc' } });
// → { headers: { authorization: '[REDACTED]' } }

// Extend with service-specific fields
const custom = new Redactor({
  patterns:    [/^x-stripe-signature$/i, /customer[-_]?id/i],
  fieldNames:  ['X-Internal-Audit-Token'],
  keepPatterns: [/^email_campaign$/i],
});
```

Redaction is enforced at two layers: per-signal on generation, and again at egress in `StackbiltCloudExporter` before the HTTPS POST to `stackbilder.com/api/observe/ingest`.

---

## Hono middleware

```typescript
import { metricsMiddleware, tracingMiddleware, createMonitoringMiddleware } from '@stackbilt/worker-observability';

app.use('*', metricsMiddleware(metrics));
app.use('*', tracingMiddleware(tracer));
// or all at once:
const middlewares = createMonitoringMiddleware({ logger, metrics, tracer });
```

---

## Cloudflare Analytics Engine

Several exporters write to Analytics Engine for zero-cost metric storage. Bind a dataset in `wrangler.toml`:

```toml
[[analytics_engine_datasets]]
binding = "ANALYTICS"
```

Then pass it to `createMonitoring({ analyticsEngine: env.ANALYTICS })`. The `CloudflareAnalyticsOutput`, `CloudflareAnalyticsExporter`, and `CloudflareTraceExporter` all consume this binding.

---

## Hosted dashboard (Stackbilder Pro)

The hosted product on [stackbilder.com](https://stackbilder.com) wraps this library with D1-backed telemetry storage and a live dashboard. Set the `stackbilt` config block in `createMonitoring` to export from your Worker to the hosted ingest endpoint. See [API Reference](/api-reference) for the ingest API.
