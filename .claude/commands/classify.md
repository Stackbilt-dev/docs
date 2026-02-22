# Classify

Use Charter to classify a planned change and determine the correct governance trailer.

## Instructions

1. Take the user's change description (from $ARGUMENTS or ask for it).

2. Run:
   ```bash
   charter classify "<change description>"
   ```

3. Report the classification result:
   - **SURFACE**: UI/presentation only — low risk, no trailer required.
   - **LOCAL**: Logic change contained to one module — medium risk, `Governed-By` recommended.
   - **CROSS_CUTTING**: Change affects multiple systems — high risk, `Governed-By` required + architectural review.

4. If the change is CROSS_CUTTING, remind the user to add a `Governed-By` trailer to their commit message referencing the relevant governance document or PR.

5. Example commit message with trailer:
   ```
   docs(api-reference): add trial endpoints section

   Governed-By: CLAUDE.md#3-task-scoping--session-management
   ```

## User Request

$ARGUMENTS
