# Stage 01: Orient to the Product

## Job

Understand the relevant product context before the first user-facing response.
Do not collect, classify, or write feedback in this stage.

## Inputs

- Layer 4 (working): the user's opening message.
- Layer 3 (reference): `../../EdubaWareVision/README.md`.
- Layer 3 (reference): `../../EdubaWareVision/CONTEXT.md`.
- Layer 3 (reference): `../../EdubaWareVision/VISION.md`.
- Layer 3 (reference): relevant files under
  `../../EdubaWareVision/architecture/`, `features/`, and `bugs/`.

## Process

1. Read the three core Atlas files listed above.
2. Extract terms, product areas, and claimed behavior from the user's message.
3. Inspect filenames in Atlas architecture, open/closed features, and open/closed
   bugs. Read only records relevant to those terms or behavior.
4. Note what the Atlas establishes, what it leaves unknown, and whether an
   existing record may already cover the feedback.
5. Respond conversationally. Briefly ground the response in the relevant
   product context, then ask the smallest useful follow-up question.

Do not expose an internal file-reading checklist to the user. Do not imply that
Atlas documentation proves the user's experience wrong.

## Output

- A context-grounded first response to the user.
- Working notes retained in conversation context for stage 2.
- No file changes.

The Atlas is read-only in this stage. Its output role begins only after the
stage 3 review gate.
