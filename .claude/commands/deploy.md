# Deploy

Run the pre-deployment runbook and deploy to Cloudflare Workers.

## Instructions

### Step 1: Build Verification

1. Run `npm run build` and capture the full output.
2. If the build **succeeds with zero errors**:
   - Report: "Build passed. `dist/` ready."
   - Proceed to Step 2.
3. If the build **fails**:
   - Read the error output carefully.
   - Diagnose the root cause. Classify it as one of:
     - **Astro compilation error** (bad imports, missing components, invalid frontmatter)
     - **Tailwind config issue** (unknown utility, missing token)
     - **Content schema violation** (frontmatter doesn't match Zod schema in `src/content/config.ts`)
     - **Missing dependency** (module not found)
   - Report the diagnosis to the user.
   - **Do NOT proceed to deployment.** Stop and wait for instructions.
4. If the build produces **warnings** about missing frontmatter fields, broken imports, or deprecated APIs:
   - Report each warning.
   - Ask the user whether to proceed or fix first.

### Step 2: Environment Selection

5. Determine the target environment:
   - If the user said "staging", "stage", or "preview" → use `npm run deploy:staging`
   - If the user said "production", "prod", or "deploy" → use `npm run deploy`
   - If the user did not specify → **default to staging** and confirm:
     > "No environment specified. Deploying to **staging**. Confirm, or say 'production' for prod."
   - **Wait for confirmation before deploying to production.**

### Step 3: Deploy

6. Run the deploy command for the selected environment.
7. Report the deployment result (success or failure).
8. If deployment fails, diagnose the Wrangler error and report. Do NOT retry without user instruction.

## User Request

$ARGUMENTS
