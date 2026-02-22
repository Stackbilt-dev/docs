# Validate

Run Charter governance validation against recent commits.

## Instructions

1. Run `npm run govern:validate` (equivalent to `charter validate --ci`).

2. Parse the output:
   - **Pass**: Report "Governance validation passed." and stop.
   - **Warnings** (citationStrictness is WARN): List each warned commit, explain what trailer is missing (`Governed-By` or `Resolves-Request`), and tell the user which commits need amending.
   - **Failures**: Report the specific violation and block any pending deploy. Suggest how to fix (add the required trailer to the commit message, or use `charter classify "<change>" ` to determine the correct trailer).

3. If the user wants to validate a specific range, run:
   ```bash
   charter validate --range <ref>..<ref> --ci
   ```

4. Do NOT auto-amend commits. Report findings and wait.

## User Request

$ARGUMENTS
