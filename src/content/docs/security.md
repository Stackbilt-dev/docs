---
title: "Security"
description: "Stackbilt's security posture: zero trust architecture, supply chain governance, phantom dependency detection, MCP tool risk classification, and vulnerability reporting."
section: "platform"
order: 9
color: "#ef4444"
tag: "09"
---

# Security

> **Policy status:** Adopted 2026-03-27, updated 2026-03-31. Applies to all repositories under the Stackbilt-dev organization.

## Architecture: Edge-First Zero Trust

Stackbilt runs entirely on Cloudflare Workers' V8 isolate execution environment. This provides a hard security boundary by design:

- **No filesystem access.** Workers execute in isolated V8 contexts with no ability to traverse host infrastructure.
- **No persistent processes.** No SSH, no servers to patch, no long-running daemons to compromise.
- **TLS everywhere.** All production traffic is HTTPS via Cloudflare. No exceptions.
- **No tracking.** No analytics SDKs, no advertising networks, no third-party tracking scripts.

### Core Principles

- **Server Sovereignty:** The server is the ultimate authority. AI models and agents are advisory; security decisions are enforced at the execution layer, never at the prompt layer.
- **Zero Trust Context:** Every input — prompts, tool outputs, model reasoning — is treated as an untrusted payload. The system remains secure even if an agent's internal state is compromised.
- **Capability Minimalism:** Tools are designed with narrow schemas and explicit intent to limit the blast radius of any single capability.
- **Deterministic Governance:** Security outcomes must be predictable and explainable. Ambiguity in a security check is treated as a defect.

### Multi-Tenant Isolation

Cross-tenant data leakage is treated as a critical severity issue regardless of technical complexity. The system uses uniform denial responses to prevent metadata inference or timing attacks — an unauthorized entity cannot distinguish between a resource that does not exist and one they lack permission to access.

## Supply Chain Governance

Dependency management is a first-class security requirement. Two incidents in March 2026 underscore why:

- **LiteLLM (TeamPCP):** Attackers compromised mutable Git tags on the Trivy security scanner to exfiltrate credentials from CI environments. Demonstrated that version tags are not trust anchors.
- **axios (March 31, 2026):** Attackers compromised a lead maintainer's npm account (`jasonsaayman`), bypassed the project's OIDC trusted publishing pipeline via a legacy CLI token, and published `axios@1.14.1` with a single change: a phantom dependency (`plain-crypto-js`) containing a cross-platform RAT. The malicious package self-destructed after execution, overwriting its own `package.json` with a clean copy. Detection window was approximately 3 hours.

Stackbilt had zero exposure to the axios attack — we use the native `fetch` API exclusively and carry no HTTP client dependencies — but the attack validates every control listed below.

### Dependency Classification

| Tier | Description | Requirements |
|------|-------------|-------------|
| **Critical** | Credentials, auth, crypto | Hash-pinned lockfiles; manual review of all version bumps; no auto-merging |
| **Standard** | Frameworks, build tools | Lockfile-pinned; automated patch updates with CI gates; monthly audits |
| **Transient** | Dev-only packages | Lockfile-pinned; auto-merge permitted for patch/minor with passing CI |

### Enforced Practices

- **Deterministic installs:** All CI pipelines use `npm ci` or `pnpm install --frozen-lockfile`. Floating installs are prohibited.
- **SHA-pinned GitHub Actions:** All Actions are pinned to full 40-character commit SHAs. Mutable version tags (`@v4`, `@latest`) are prohibited.
- **Step-scoped secrets:** Workflow-level secret environment variables are prohibited. Secrets are scoped to the minimum required step.
- **Lockfile diffing on every PR:** Any change to `package-lock.json` or `pnpm-lock.yaml` triggers manual review. New transitive dependencies are flagged.
- **Phantom dependency detection:** Every entry in `dependencies` must correspond to an actual `import` or `require` in source code. Dependencies that appear only in `package.json` without a source-level reference are treated as suspicious and investigated before merge.
- **Postinstall script auditing:** New or modified `postinstall`, `preinstall`, or `prepare` hooks in any dependency are flagged during review. Lifecycle scripts are the primary execution vector in npm supply chain attacks.

### Publishing Integrity

Stackbilt npm packages (when published) use GitHub Actions OIDC trusted publishing exclusively. Long-lived npm tokens are prohibited. This eliminates the attack vector exploited in the axios compromise, where a stolen CLI token was used to bypass the project's CI-based publishing pipeline.

### Native-First Dependency Philosophy

Where platform APIs exist, we use them. Cloudflare Workers provide `fetch`, `crypto`, `streams`, and `WebSocket` natively. We do not depend on npm packages for capabilities the runtime already provides. This is not just a performance choice — it eliminates entire categories of supply chain risk. The axios attack could not have affected Stackbilt because we never had a reason to install an HTTP client library.

## MCP Tool Risk Classification

Every tool exposed through the Model Context Protocol declares a risk level that determines enforcement logic:

| Level | Classification | Enforcement |
|-------|---------------|-------------|
| 1 | **READ_ONLY** | Data retrieval. Passive audit, sampled logs. |
| 2 | **LOCAL_MUTATION** | Local state changes. Active logging with trace-id. |
| 3 | **EXTERNAL_SIDE_EFFECT** | External API interaction. Rate-limit checks, service token validation. |
| 4 | **ECOSYSTEM_IMPACT** | Cross-service or cross-tenant effects. Human-in-the-loop confirmation required. |

Tools follow a "One Tool = One Explicit Capability" pattern. Tools must not perform multiple unrelated actions or infer missing intent.

## Autonomous Agent Safety

Stackbilt operates autonomous AI agents for code generation, testing, and infrastructure tasks. These agents are governed by a four-layer safety architecture:

1. **Hard stops:** Runtime hooks block destructive operations (`rm -rf`, `git push --force`, `DROP TABLE`, production deploys), secret access, and interactive prompts.
2. **Soft stops:** Mission brief constraints injected into agent system prompts with explicit directory and file-scope permissions.
3. **Blast radius containment:** Every autonomous task runs on an isolated branch (`auto/{category}/{task-id}`). Integration happens only through reviewed pull requests. Concurrent task limits (5 per repo, 8 per day) prevent merge conflict storms.
4. **Authority levels:** Tasks are classified as `operator` (full access), `auto_safe` (docs/tests/research — PR is the approval gate), or `proposed` (requires human approval before execution).
5. **Churn detection:** Self-improvement tasks are blocked from re-touching files modified by other autonomous tasks within the last 14 days, preventing oscillation loops.

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Email: **security@stackbilt.dev**

| Severity | Acknowledgement | Fix Target |
|----------|----------------|------------|
| Critical (active exploitation, data exposure) | 24 hours | 7 days |
| High (exploitable with effort) | 48 hours | 14 days |
| Medium / Low | 5 business days | Next release cycle |

These are targets, not SLAs. Stackbilt is a solo-founder operation — response times reflect that reality honestly. Critical issues affecting user data will always be prioritized above everything else.

### Scope

This policy covers all software published under the Stackbilt-dev GitHub organization, including Stackbilder, img-forge, Charter, and all supporting services.

### Out of Scope

- Denial of service against free-tier services (Cloudflare handles DDoS)
- Rate limiting bypass on non-authenticated endpoints (unless it enables data access)
- Missing security headers on non-production deployments
- Vulnerabilities in third-party dependencies where Stackbilt is not the upstream maintainer (report those upstream; let us know if we should pin or patch)

### Disclosure Policy

- We practice **coordinated disclosure** with a minimum 90-day window (30 days for critical).
- We credit reporters in release notes unless you prefer anonymity.
- We do not pursue legal action against good-faith security researchers acting within this policy.

### Contact

- **Primary:** security@stackbilt.dev
- **Fallback:** admin@stackbilt.dev
