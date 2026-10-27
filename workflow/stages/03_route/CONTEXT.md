# Stage 03: Route to the Atlas

## Job

Decide which single durable Atlas artifact, if any, should change because of the
confirmed feedback record, then write and publish that artifact in the same
turn.

## Inputs

- Layer 4 (working): the confirmed feedback record and any Atlas draft from
  stage 2.
- Layer 3 (reference): `references/artifact-routing.md`.
- Layer 3 (reference): `../../EdubaWareVision/CONTEXT.md`.
- Layer 3 (reference): Atlas templates and relevant existing Atlas records.

## Process

1. Verify the feedback against relevant Atlas vision, architecture, features,
   bugs, and rationale. Do not equate user confirmation with product acceptance
   or technical verification.
2. Use `references/artifact-routing.md` to select one primary outcome.
3. Prefer updating an existing Atlas artifact over creating a duplicate.
4. Write the artifact under `../../EdubaWareVision/` in this turn. Apply the
   matching Atlas template or preserve the schema of an existing record. Link
   the Atlas artifact to the Workbench feedback record. To promote a draft,
   move it from `features/drafts/` to `features/open/` and remove the draft
   banner. When no durable change is justified, keep the draft and set its
   banner status to the outcome (`feedback-only`, `needs-validation`,
   `duplicate` of a linked record, or `declined`).
5. Publish immediately, without asking the user: run
   `bash .how-to-setup/configure-git.sh publish "<message>" <path>...` from
   the workspace root in the same Bash command as the bootstrap `export`
   lines. Include both paths of a move. If the script reports `UNPUBLISHED`,
   the change is kept and published by the next bootstrap: record the status
   as `pending-publish`.
6. Tell the user what you published and why, or that no durable change is
   justified yet and why.
7. Add an **Atlas routing** section to the feedback record with the outcome,
   link, status, and unresolved validation work.

Do not change multiple Atlas artifact types to make the feedback appear more
complete. Record follow-up work instead.

## No Publish Gate

Stage 3 has no approval step. The stage 2 confirmation is the user's review;
do not ask for a second confirmation before writing or publishing.

## Output

One of:

- one new or updated final artifact in `../../EdubaWareVision/` plus a backlink
   from the feedback record;
- an updated feedback record marked `feedback-only`, `needs-validation`,
  `duplicate`, or `declined`, with no durable Atlas change beyond updating
  the status of its draft.
