#!/bin/bash
# Hook: Block npm, yarn, bun — this repo uses pnpm only (pnpm-lock.yaml)

INPUT=$(cat)

# Extract command without jq dependency
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
  COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Block alternative package managers (npm, yarn, bun)
if echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)(npm|yarn|bun)(\s|$)'; then
  echo "BLOCKED: This repository uses pnpm (pnpm-lock.yaml). Use pnpm instead of npm/yarn/bun." >&2
  exit 2
fi

exit 0
