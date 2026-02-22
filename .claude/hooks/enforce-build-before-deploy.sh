#!/bin/bash
# Hook: Prevent direct wrangler deploy without going through npm run deploy (which includes astro build)
# The npm scripts already chain build+deploy, but this catches raw wrangler deploy calls.

INPUT=$(cat)

# Extract command without jq dependency
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
  COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Block raw wrangler deploy (should use npm run deploy which chains astro build first)
if echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)(npx\s+)?wrangler\s+deploy'; then
  # Allow if it's part of npm run deploy (which already includes astro build)
  if echo "$COMMAND" | grep -qE 'npm\s+run\s+deploy'; then
    exit 0
  fi
  echo "BLOCKED: Do not run wrangler deploy directly. Use 'npm run deploy' or 'npm run deploy:staging' which includes astro build verification. See CLAUDE.md Section 4." >&2
  exit 2
fi

exit 0
