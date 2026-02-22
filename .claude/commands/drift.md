# Drift

Run Charter drift detection to identify architectural drift from the blessed stack.

## Instructions

1. Run `npm run govern:drift` (equivalent to `charter drift --ci`).

2. Parse the output:
   - **No drift**: Report "No architectural drift detected." and stop.
   - **Drift detected**: List each drifted pattern with:
     - What changed
     - Which file(s) are affected
     - The drift score vs. the minimum threshold (currently 0.7)
   - Suggest whether this is intentional evolution (needs a `Governed-By` trailer) or accidental drift (should be reverted).

3. For a path-scoped scan:
   ```bash
   charter drift --path <dir> --ci
   ```

4. Do not auto-revert changes. Report and wait for user decision.

## User Request

$ARGUMENTS
