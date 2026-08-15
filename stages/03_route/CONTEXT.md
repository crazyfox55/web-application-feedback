# Stage 03: Route to the Atlas

## Job

Decide which single durable Atlas artifact, if any, should change because of the
confirmed feedback record, then write that approved artifact to the Atlas.

## Inputs

- Layer 4 (working): the confirmed feedback record from stage 2.
- Layer 3 (reference): `references/artifact-routing.md`.
- Layer 3 (reference): `../../EdubaWareVision/CONTEXT.md`.
- Layer 3 (reference): Atlas templates and relevant existing Atlas records.

## Process

1. Verify the feedback against relevant Atlas vision, architecture, features,
   bugs, and rationale. Do not equate user confirmation with product acceptance
   or technical verification.
2. Use `references/artifact-routing.md` to select one primary outcome.
3. Prefer updating an existing Atlas artifact over creating a duplicate.
4. Tell the user the exact artifact you propose to change, or that no Atlas
   change is justified yet, and explain why.
5. Obtain user approval before changing the Atlas.
6. Write the final artifact under `../../EdubaWareVision/`. Apply the matching
   Atlas template or preserve the schema of an existing record. Link the Atlas
   artifact to the Workbench feedback record.
7. Add an **Atlas routing** section to the feedback record with the outcome,
   link, status, and unresolved validation work.

Do not change multiple Atlas artifact types to make the feedback appear more
complete. Record follow-up work instead.

## Review Gate

No Atlas mutation occurs until the user has seen and approved the proposed
artifact choice.

## Output

One of:

- one new or updated final artifact in `../../EdubaWareVision/` plus a backlink
   from the feedback record;
- an updated feedback record marked `feedback-only`, `needs-validation`,
  `duplicate`, or `declined`, with no Atlas mutation.
