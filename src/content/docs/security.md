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

Email: **admin@stackbilt.dev**

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

- **Primary:** admin@stackbilt.dev
- **GitHub Security Advisory:** `https://github.com/Stackbilt-dev/{repo}/security/advisories/new` (preferred for per-repo coordinated disclosure)

## Outbound Disclosure — Filing Against Stackbilt-dev Public Repositories

The policy above governs **inbound** reports — external researchers finding bugs in our software. This section governs **outbound** disclosure — findings discovered by Stackbilt itself (operators, internal agents, automated audits) against our own public repositories.

Stackbilt runs adversarial internal audits against its own code. When findings land against a public repository, the filing channel depends on severity and exploitability.

### Channel Routing Matrix

| Finding class | Public repo | Private repo |
|---|---|---|
| **Critical / High exploitable** | Private disclosure only — GitHub Security Advisory on the target repo, or email `admin@stackbilt.dev`. Never a public GH issue until a fix lands and the embargo window elapses. | Public GH issue OK (repo is private). Normal internal triage. |
| **Medium, exploitable** | Private disclosure (same channels as above). | Public GH issue OK. |
| **Medium, hardening / defense-in-depth** | Public GH issue OK with the scrub rules below. | Public GH issue OK. |
| **Low / docs / test coverage / refactor** | Public GH issue OK with the scrub rules below. | Public GH issue OK. |

Severity classification follows the same definitions used for inbound reports: Critical = active exploitation or data exposure path, High = exploitable with effort, Medium = requires specific conditions or low impact, Low = hardening / hygiene / no direct exploitation path.

### Neutral-Filer Rule

Public GitHub issues filed by Stackbilt operators or internal agents against Stackbilt-dev public repositories **must not**:

- Identify the filer as an internal AI agent, automated review bot, or any named internal tooling
- Include session footers such as "Filed by X during audit session" or "Part of internal review cluster"
- Reference internal memory stores, internal policy documents, or private `CLAUDE.md` files
- Cross-reference other internal audits, findings, or issue clusters across private repositories
- Imply the existence of any internal review capability beyond what is documented in the public [ecosystem overview](/ecosystem)

Public filings should read as if contributed by an external security researcher or a maintainer doing routine hygiene review. Technical content is the point; framing is not.

### Reference Framing Rules

When writing a public issue, cite:

- Published RFCs (RFC 6749, RFC 7636, RFC 7519, etc.)
- OWASP guidance and Top 10 entries
- Cloudflare Workers documentation at `developers.cloudflare.com`
- Published npm packages and public GitHub repositories
- Commits and issues in other **public** Stackbilt-dev repositories

Do **not** cite:

- Private repository commits or issue numbers
- Internal policy docs or CLAUDE.md files
- Internal agent memory, internal incident postmortems, or internal architecture notes
- Sibling private services as the justification for a finding ("because we also do this in X") where X is private

### Scrub List — Identifiers That Must Not Appear in Public Artifacts

The following classes of identifier must not appear in any public GH issue, public commit message, public PR, public GHSA draft body, or any other publicly-visible artifact:

- **Private repository names.** The authoritative public allowlist lives in the [machine-readable manifest](https://docs.stackbilt.dev/ecosystem/repo-visibility.json). Repositories not listed there are private by default and must not be referenced by name in public. The manifest contains only the positive (public) list — the private list is **not published**. Internal agents generate their private-name deny-regex dynamically at session start by calling `gh api orgs/Stackbilt-dev/repos --paginate` with authenticated credentials; the deny-list is held in memory only and never persisted to a public-visible location.
- **Internal tool names and agent handles** not documented in the public [ecosystem overview](/ecosystem). If the ecosystem doc doesn't name it, it is not safe to name publicly.
- **Private commit SHAs** — never cite a commit hash from a private repository in a public context.
- **Private service binding identifiers** — internal wrangler binding names, service binding entry points, and internal RPC contracts.
- **Internal incident descriptions** — references to past outages, postmortems, or security incidents unless they have been publicly published.
- **Customer names and non-public pricing details** — only the public pricing tiers at [stackbilder.com/pricing](https://stackbilder.com/pricing) may be referenced.

### Cross-Repo Chain Rule

If a finding in a public repository exploitability-chains with a bug or misconfiguration in a private repository, the combined chain **must not** be described in any public channel. Either:

1. Route the entire finding privately (GHSA + email) and include the chain analysis in the private write-up, or
2. File only the public-repo-scoped portion publicly, treating the chain as embargoed until both legs are fixed.

The decision of "can this be filed publicly" happens against the *public-only* framing of the finding. If a reasonable reader of the public filing could reconstruct the private chain, the public filing must be rewritten or withheld.

### Approval Gate for Agent-Filed Public Issues

Autonomous agents (CodeBeast, cc-taskrunner, and any future governance automation) are permitted to file issues against **private** Stackbilt-dev repositories without human approval, following internal triage rules. Filings against **public** Stackbilt-dev repositories require explicit operator approval per-filing — no agent may autonomously `gh issue create` or `gh api security-advisories` against a public repo.

The approval flow:

1. Agent drafts the finding with public framing applied from the start (not "full version then scrub")
2. Agent looks up target repo visibility against `repo-visibility.json`
3. Agent applies scrub-list regex to the draft; any match blocks the filing and surfaces the match to the operator
4. Agent presents the drafted issue body, severity classification, and channel routing decision to the operator
5. Operator approves, edits, or rejects
6. On approval, the agent files via the operator's credentials or via the approved automation surface, and writes the filing action to the disclosure audit log

### Disclosure Audit Log

Every filing action by an internal agent against a Stackbilt-dev repository (public or private) is written to a persistent audit log. The log records: target repo, finding severity, channel routing decision, scrub result, operator approval status (for public filings), final published URL, and timestamp. The log is the authoritative trail for "did we ever leak something we shouldn't have" — it enables after-the-fact review and policy calibration.

### Policy Enforcement

This outbound-disclosure policy is enforced by:

1. **Internal agent pre-flight filters** — filing-capable agents load the [public visibility manifest](https://docs.stackbilt.dev/ecosystem/repo-visibility.json) and generate their private-name scrub list dynamically at session start, then re-check before each filing action.
2. **Operator judgment** — operators filing manually apply the same rules by hand; when in doubt, route privately.
3. **After-the-fact review** — the disclosure audit log is reviewed periodically to catch drift between policy and practice.

Violations of this policy are treated as incidents. A public filing that names a private repository, exposes an internal agent, or leaks cross-repo chain information is a security-relevant mistake even if no external attacker acts on it, because the leaked information is already indexed by public search and archival systems the moment it ships.

### Policy Authoring Rule

**This policy document must pass its own scrub filter.**

Any revision to this policy, to [`repo-visibility.json`](https://docs.stackbilt.dev/ecosystem/repo-visibility.json), to the [ecosystem overview](/ecosystem), or to any other publicly-visible Stackbilt-dev documentation artifact must be authored with the outbound disclosure rules applied from the start — not written in full detail and scrubbed after. The authoring context is the highest-risk context for accidental disclosure, because the author has the most private context loaded at exactly the moment they are writing public-facing text.

This rule exists because the first draft of this policy — written on 2026-04-10 during the policy's creation session — attempted to publish:

1. A `repo-visibility.json` manifest listing every private Stackbilt-dev repository by name. Because private repo names are not externally enumerable via the GitHub API without authenticated access, publishing such a manifest would have converted "private repos exist but their names are not known to external observers" into "here is the complete roster of every internal project." This is a strictly worse disclosure than leaking any individual file — repo enumeration is reconnaissance, and reconnaissance is the first step of any external attack.
2. A dual-repo section in the ecosystem documentation that explicitly named private commercial extensions alongside their OSS cores.
3. A scrub-list reference in the policy body pointing readers at the leaky manifest as an "authoritative list."

All three were caught in a pre-commit review pass before anything was pushed to the remote. No disclosure occurred. But the near-miss validates the rule: the approval gate that this policy mandates for agent-filed public artifacts applies with equal force to policy documents themselves. The author of any policy revision must perform the same pre-flight scrub — against the same rules — that agents perform before filing.

**Practical implications for future policy revisions:**

1. Policy revisions to this document must be reviewed by a second pair of eyes (operator or peer reviewer) before merging, with the explicit task of verifying no private identifiers have been introduced.
2. Changes to [`repo-visibility.json`](https://docs.stackbilt.dev/ecosystem/repo-visibility.json) that add or remove repositories must be verified against the live GitHub API (`gh api orgs/Stackbilt-dev/repos`) to ensure no private repo has been accidentally added to the public allowlist.
3. The dual-repo section in ecosystem documentation must only name the OSS core of each capability. Commercial extensions exist, are referenced abstractly, and are never publicly named.
4. The phrase "the scrub list" refers to a dynamically-generated in-memory artifact, never to a persisted public file. Any proposed policy revision that attempts to publish the scrub list itself must be rejected at review.
5. Policy drafts should be committed first to a feature branch (never directly to `main`) and reviewed as a diff against the current policy before merging, so that changes are visible and auditable.
