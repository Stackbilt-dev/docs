# Build

Run the Astro build and diagnose any errors.

## Instructions

1. Run `npm run build` and capture the full output.

2. If the build **succeeds**:
   - Report: "Build passed."
   - List the pages generated in `dist/` if relevant.
   - Stop.

3. If the build **fails**:
   - Read the error output.
   - Classify the error:
     - **Astro compilation error** — bad imports, missing components, syntax errors
     - **Tailwind config issue** — unknown utility class, missing `sb-*` token
     - **Content schema violation** — frontmatter doesn't match Zod schema in `src/content/config.ts`
     - **Missing dependency** — module not found, run `npm install`
   - Report the diagnosis with the exact error message and affected file.
   - Suggest a specific fix.
   - **Do NOT auto-fix.** Wait for user approval.

## User Request

$ARGUMENTS
