# CLAUDE.md

> This project uses [ADF](https://github.com/Stackbilt-dev/charter) for AI agent context management.
> All stack rules, constraints, and architectural guidance live in `.ai/`.
> **Do not duplicate ADF rules here.**

See `.ai/manifest.adf` for the module routing manifest.

## Environment
- ### Staging Rules
- **NEVER stage whitespace-only or line-ending-only changes.** Only intentional content modifications are allowed.
- Before staging, run `git diff` to inspect changes. If a file contains only whitespace/formatting diffs, exclude it with `git reset HEAD <file>`.
- When in doubt, use `git diff --check` to detect whitespace errors.
### Atomic Commit Workflow
When the working tree contains multiple untracked or modified files, follow this procedure:
1. **Survey**: Run `git status` to see all changes.
2. **Chunk**: Group changes into logical atomic commits (e.g., one commit per doc page, one for config, one for components). Never lump unrelated changes into a single commit.
3. **Preview**: For each proposed commit, output `git diff --stat` showing exactly which files and how many lines are affected.
4. **Propose**: Present the commit message for user approval. Format:
   ```
   <type>: <concise description>
   ```
   Types: `docs`, `feat`, `fix`, `refactor`, `chore`, `style`.
5. **Wait**: Do NOT execute `git commit` until the user explicitly approves the message.
6. **Commit**: Stage only the files in the approved chunk, commit, then proceed to the next chunk if approved.
### Prohibitions
- Never run `git add -A` or `git add .` without first reviewing every file in the diff.
- Never amend a commit unless the user explicitly requests it.
- Never force-push to `main`.
- Never skip pre-commit hooks (`--no-verify`).
---
