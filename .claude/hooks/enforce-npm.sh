#!/bin/bash
# Hook: Block yarn, pnpm, bun — this repo uses npm only (package-lock.json)

INPUT=$(cat)

# Extract command without jq dependency
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
  COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Block alternative package managers
if echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)(yarn|pnpm|bun)(\s|$)'; then
  echo "BLOCKED: This repository uses npm (package-lock.json exists). Do not use yarn, pnpm, or bun." >&2
  exit 2
fi

exit 0
