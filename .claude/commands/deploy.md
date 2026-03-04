# Deploy

Build and deploy to Cloudflare Workers with automatic credential handling.

## Instructions

### Step 1: Source Credentials

1. Read `.dev.vars` at the project root.
2. Extract `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
3. If the file is missing or credentials are not found, stop and tell the user.

### Step 2: Build Verification

4. Run `npm run build` and capture full output.
5. If the build **succeeds with zero errors**:
   - Report: "Build passed. Proceeding to deploy."
   - Proceed to Step 3.
6. If the build **fails**:
   - Diagnose the root cause (Astro compilation, Tailwind config, content schema, missing dependency).
   - Report the diagnosis. **Do NOT proceed to deployment.** Stop and wait.
7. If the build produces **warnings** (missing frontmatter, broken imports, deprecated APIs):
   - Report each warning. Ask whether to proceed or fix first.

### Step 3: Environment Selection

8. Determine target from user arguments (`$ARGUMENTS`):
   - `staging`, `stage`, `preview` → use `npm run deploy:staging`
   - `production`, `prod`, `live`, or no argument → use `npm run deploy`
   - When deploying to production with no explicit argument, proceed without asking (this is the default target for this project).

### Step 4: Deploy

9. Run the deploy command with credentials injected:
   ```
   CLOUDFLARE_API_TOKEN=<token> CLOUDFLARE_ACCOUNT_ID=<account_id> npm run deploy
   ```
10. Report the deployment result including the live URL.
11. The production URL is: **https://docs.stackbilt.dev**
12. The workers.dev URL is: **https://stackbilt-docs.blue-pine-edf6.workers.dev**
13. If deployment fails, diagnose the Wrangler error. Do NOT retry without user instruction.

## User Request

$ARGUMENTS
