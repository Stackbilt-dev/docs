#!/bin/bash
# Hook: Block git add -A / git add . — require explicit file staging per SmartCommit rules

INPUT=$(cat)

# Extract command without jq dependency
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
  COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Block blanket git add
if echo "$COMMAND" | grep -qE 'git\s+add\s+(-A|--all|\.)(\s|$|;|&&)'; then
  echo "BLOCKED: Do not use 'git add -A', 'git add --all', or 'git add .' — stage specific files only. See CLAUDE.md Section 2 (SmartCommits)." >&2
  exit 2
fi

# Block git commit --no-verify
if echo "$COMMAND" | grep -qE 'git\s+commit.*--no-verify'; then
  echo "BLOCKED: Do not skip pre-commit hooks (--no-verify). See CLAUDE.md Section 2." >&2
  exit 2
fi

# Block force push to main
if echo "$COMMAND" | grep -qE 'git\s+push.*--force.*main|git\s+push.*-f.*main'; then
  echo "BLOCKED: Force push to main is prohibited. See CLAUDE.md Section 2." >&2
  exit 2
fi

exit 0
