---
title: "CI Integration"
section: "charter"
order: 3
color: "#f59e0b"
tag: "03"
---

# CI Integration

Charter integrates with GitHub Actions via a reusable workflow template.

## Setup

```bash
charter setup --ci github --yes
```

This writes `.github/workflows/governance.yml` to your repo.

## What the Workflow Does

On every push and pull request, the CI workflow runs:

1. `charter validate --ci` — checks all commits in the push for governance trailers
2. `charter drift --ci` — scans for blessed-stack deviations
3. `charter audit --format json` — captures governance posture snapshot

If `charter validate` exits `1`, the check fails and the merge is blocked.

## Example Workflow Output

```
✓ 12 commits validated
✓ All Governed-By trailers resolved
✓ No policy violations (exit 0)

✓ No blessed-stack deviations · compliance: 100%
```

## Adding Governed-By Trailers

Every commit should carry a `Governed-By:` trailer referencing an ADR or decision ID:

```
feat(auth): add JWT refresh endpoint

Implements token refresh per ADR-042.

Governed-By: ADR-042
```

Use `charter hook install --commit-msg` to install a git hook that prompts for or normalizes trailers at commit time.

## Environment Variables

No secrets required for local governance checks. The governance workflow is fully local/static — no external API calls.
