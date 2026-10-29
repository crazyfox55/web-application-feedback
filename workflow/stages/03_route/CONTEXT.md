# Stage 03: Route to the Atlas

## Job

Apply the promotion rules in `references/artifact-routing.md` to the
confirmed feedback record, then write and publish the selected Atlas artifact
in the same turn.

## Inputs

- Layer 4 (working): the confirmed feedback record and any Atlas draft from
  stage 2.
- Layer 3 (reference): `references/artifact-routing.md`.
- Layer 3 (reference): `../../EdubaWareVision/CONTEXT.md`.
- Layer 3 (reference): Atlas templates and relevant existing Atlas records.

## Process

1. Check the feedback against relevant Atlas vision, architecture, features,
   bugs, and rationale, and look for an existing record that owns it.
2. Select the outcome with the promotion rules in
   `references/artifact-routing.md`. They decide; do not offer the user a
   choice or defer the decision.
3. Write the artifact under `../../EdubaWareVision/` in this turn. Apply the
   matching Atlas template or preserve the schema of an existing record. Name
   its source with the workbench URL and record file name as plain text, as
   `../../CLAUDE.md` **Source Reference in Atlas Files** requires; never a
   relative link to `feedback/`, and never copy the record into the Atlas.
   To promote a feature draft, move it from `features/drafts/` to
   `features/open/` and replace the draft banner; to promote an issue, write `bugs/open/<short-slug>.md` from
   `templates/bug.md`. Before writing either, run
   `bash .how-to-setup/configure-git.sh check-slug <path>` with the bootstrap
   `export` lines; if it prints `EXISTS bugs/open/...` or
   `EXISTS features/open/...`, update that file instead of creating another
   (an `EXISTS features/drafts/...` line is the draft to move). Start a promoted artifact with the needs-validation
   banner unless its behavior or need is already verified or accepted. When no
   promotion rule matches, set the draft banner status to the outcome.
4. Publish immediately, without asking: run
   `bash .how-to-setup/configure-git.sh publish "<message>" <path>...` from
   the workspace root in the same Bash command as the bootstrap `export`
   lines. Include both paths of a move.
5. Report as `../../CLAUDE.md` requires: what was promoted and why, or which
   promotion criterion is missing; then the Workbench/Atlas block with the
   `VERIFIED` hash or the `FAILED` reason.
6. Set the feedback record's **Status:** to `promoted <hash>` (the `VERIFIED`
   hash), `duplicate <Atlas path>`, `declined`, `feedback-only`, or
   `failed <reason>` after exit 75-77, and fill its **Atlas routing** section
   with the Atlas path and validation still needed.

Needs-validation banner:

```markdown
> **Needs validation.** Promoted from Workbench feedback on YYYY-MM-DD
> (Workbench https://chat.eduba.io/workbenches/<workbench-id>/chats, record
> `feedback/<folder>/NNN-short-slug.md`). Not yet verified:
> <what is missing, e.g. logs, team reproduction, product decision>.
```

Write the **Source feedback** line under the summary in the same plain-text
form, replacing any relative `../feedback/` link carried over from a draft.

Do not change multiple Atlas artifact types to make the feedback appear more
complete. Record follow-up work instead.

## No Publish Gate

Stage 3 has no approval step. The stage 2 confirmation is the user's review;
do not ask for a second confirmation before writing or publishing.

## Output

One of:

- one new, promoted, or updated artifact in `../../EdubaWareVision/` plus a
  backlink from the feedback record;
- an updated feedback record with **Status:** `feedback-only`, `duplicate`,
  or `declined`, with no durable Atlas change beyond updating the status of its
  draft.
