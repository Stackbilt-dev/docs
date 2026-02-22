#!/bin/bash
# Hook: Block destructive git operations that could lose work

INPUT=$(cat)

# Extract command without jq dependency
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
  COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Block git reset --hard
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: git reset --hard can destroy uncommitted work. Use git stash or git checkout for targeted reverts." >&2
  exit 2
fi

# Block git clean -f
if echo "$COMMAND" | grep -qE 'git\s+clean\s+-[a-zA-Z]*f'; then
  echo "BLOCKED: git clean -f permanently deletes untracked files. Review with git clean -n first." >&2
  exit 2
fi

# Block git checkout . (discard all changes)
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+\.\s*$'; then
  echo "BLOCKED: git checkout . discards all unstaged changes. Use git checkout -- <specific-file> instead." >&2
  exit 2
fi

exit 0
