# SmartCommit

Create atomic, conventional commits following the SmartCommit workflow defined in CLAUDE.md.

## Instructions

### Phase 1: Survey

1. Run `git status` to see all untracked and modified files. Never use `-uall`.
2. Run `git diff` to inspect all changes.
3. Run `git diff --check` to detect whitespace errors.

### Phase 2: Filter

4. Identify any files with **whitespace-only or line-ending-only changes**. These MUST be excluded — do not stage them. If found, run `git checkout -- <file>` to discard those changes and tell the user which files were excluded and why.

### Phase 3: Chunk

5. If multiple unrelated changes exist, group them into **logical atomic commits**. Each commit should represent one logical change (e.g., one doc page update, one config change, one component fix). Never lump unrelated changes into a single commit.

### Phase 4: Classify (Charter)

6. For each proposed commit chunk, run Charter to classify the change:
   ```bash
   charter classify "<brief description of what this commit changes>"
   ```
   - **SURFACE** — no trailer needed
   - **LOCAL** — add `Governed-By: CLAUDE.md` recommended
   - **CROSS_CUTTING** — add `Governed-By: CLAUDE.md#<section>` required

### Phase 5: Preview & Approve

7. For each proposed commit, present:
   - `git diff --stat` showing exactly which files and line counts
   - Charter classification result
   - The proposed commit message. Format:
     ```
     <type>(<scope>): <message>

     Governed-By: CLAUDE.md        ← include if LOCAL or CROSS_CUTTING
     Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
     ```
   - Types: `docs`, `feat`, `fix`, `refactor`, `chore`, `style`
   - Scopes for this repo:
     - Doc page slug (e.g., `docs(mcp): update tool count`)
     - `ui` for component/layout changes
     - `config` for astro/tailwind/wrangler/charter config
     - `theme` for style changes
     - `ci` for deployment/build pipeline changes
     - `govern` for Charter governance changes

8. **STOP and wait for user approval.** Do NOT execute `git commit` until the user explicitly approves.

### Phase 6: Commit

9. Stage ONLY the approved files:
   ```bash
   git add <specific-files>
   ```
   Never use `git add -A` or `git add .`.

10. Create the commit. The Charter commit-msg hook will validate the trailer:
    ```bash
    git commit -m "<type>(<scope>): <message>

    Governed-By: CLAUDE.md
    Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
    ```

11. Run `git status` to confirm success.

12. If there are remaining chunks, repeat from Phase 4 for the next chunk. Otherwise, state completion and stop.

## User Request

$ARGUMENTS
