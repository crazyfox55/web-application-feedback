# Stage 02: Converse and Record

## Job

Understand the user's experience well enough to create a feedback record they
recognize as accurate. Capture a feature request in the Atlas as a rough draft
as soon as it is usable, before the conversation is finished.

## Inputs

- Layer 4 (working): the complete conversation and stage 1 working notes.
- Layer 3 (reference): templates under `../../feedback/`.
- Layer 3 (reference): relevant existing records under `../../feedback/`.
- Layer 3 (reference): `../../EdubaWareVision/templates/feature.md` and
  existing files under `../../EdubaWareVision/features/drafts/`.

## Process

1. Let the user's language lead. Separate what they observed, what they wanted,
   and any implementation they suggested.
2. Ask one to three focused questions at a time. Explore only gaps that affect
   understanding: the user's goal, current behavior, expected outcome, impact,
   circumstances, evidence, and important constraints.
3. Reflect uncertainty explicitly. Do not diagnose a bug or promise a feature
   during the conversation.
4. Search existing feedback for the same need or observation. Add evidence to a
   related record when that preserves the user's distinct context; otherwise
   prepare a new record.
5. Write the feedback record as soon as its classification is clear, with
   **Status:** `draft`: `feature-requests/` for a desired capability,
   `issue-reports/` for observed unexpected behavior, or `general/` when
   neither classification is justified. Name it `NNN-short-slug.md` with the
   next free number, checked immediately before writing. Update it as the
   conversation continues.
6. As soon as a feature request has a recognizable need and desired outcome,
   even a rough one, publish an Atlas draft in the same turn without asking:
   write `../../EdubaWareVision/features/drafts/<short-slug>.md` from the Atlas
   feature template, starting with the draft banner below, then publish that
   path as described in `../../CLAUDE.md`. Update an existing draft for the
   same need instead of adding another. Republish whenever the draft improves.
   Record the draft path in the feedback record, and
   report both as `../../CLAUDE.md` **Reporting** requires.
7. Summarize the feedback in plain language, including the desired outcome and
   unresolved questions. Ask the user to confirm or correct the summary.
8. After confirmation, set the record's **Status:** to `validated`, update
   any Atlas draft to match and change its banner status to
   `confirmed-feedback`, and republish it.

Draft banner:

```markdown
> **Draft: rough estimate, not an accepted feature.** Captured from Workbench
> feedback before triage. Status: unconfirmed. Source: Workbench
> https://chat.eduba.io/workbenches/<workbench-id>/chats, record
> `feedback/feature-requests/NNN-short-slug.md` (not in this repository).
```

Fill `<workbench-id>` as `../../CLAUDE.md` **Source Reference in Atlas
Files** describes. Name the record as plain text; never link to `feedback/`.

Keep quotations or close paraphrases under **User account**. Put agent analysis
under **Workbench interpretation**. Never rewrite an inference as something the
user said.

## Review Gate

The user must confirm or correct the summary before the record is finalized and
before stage 3 begins. Drafts do not wait for this gate, and publishing never
needs a separate confirmation.

## Output

- One confirmed record under `../../feedback/`, or an evidence update to an
  existing record.
- For a feature request, a published draft under
  `../../EdubaWareVision/features/drafts/`.
- The paths to both carried into stage 3.
