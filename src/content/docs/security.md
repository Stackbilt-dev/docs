---
title: "Security"
description: "Stackbilt's security posture: zero trust architecture, supply chain governance, dependency pinning, MCP tool risk classification, and vulnerability reporting."
section: "platform"
order: 9
color: "#ef4444"
tag: "09"
---

# Security

> **Policy status:** Adopted 2026-03-27. Applies to all repositories under the Stackbilt-dev organization.

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

Dependency management is a first-class security requirement. The March 2026 LiteLLM supply chain attack demonstrated that transitive dependencies — libraries required by your tools but not directly managed by your team — are a primary attack vector in AI-driven development.

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

1. **Hard stops:** Runtime hooks block destructive operations (`rm -rf`, `git push --force`, `DROP TABLE`, production deploys).
2. **Soft stops:** Mission brief constraints injected into agent system prompts.
3. **Blast radius containment:** Every autonomous task runs on an isolated branch (`auto/{task-id}`). Integration happens only through reviewed pull requests.
4. **Authority levels:** Tasks are classified as `operator` (full access), `auto_safe` (docs/tests/research only), or `proposed` (requires human approval).

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
