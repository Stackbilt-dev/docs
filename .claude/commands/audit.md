# Audit

Run a Charter governance audit of this repo and report policy coverage.

## Instructions

1. Run `npm run govern:audit` (equivalent to `charter audit`).

2. Display the full audit output. Highlight:
   - **Policy coverage**: Which required sections (commit trailers, change classification, exception path, escalation) are covered vs. missing in CLAUDE.md.
   - **Governance score**: Overall posture health.
   - **Action items**: Any gaps that need addressing.

3. For a machine-readable report, run:
   ```bash
   charter audit --format json
   ```

4. Stop after reporting. Do not auto-fix policy gaps.

## User Request

$ARGUMENTS
