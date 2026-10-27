# User Feedback Workflow

## Purpose

Turn a user's experience into a faithful feedback record, then determine whether
that evidence should change durable product knowledge in `EdubaWareVision/`.
The conversation is part of the workflow, not merely an input form.

## Workspace Inputs

- `EdubaWareVision/`: Layer 3 product reference material supplied by the host.
- The user's opening message and later replies: Layer 4 working material.
- `feedback/`: completed Workbench records from earlier conversations.

## Workspace Outputs

- `feedback/`: the conversation record and routing trace.
- `EdubaWareVision/features/drafts/`: a rough, clearly labelled feature
  draft, published as soon as a usable rough feature request exists.
- `EdubaWareVision/`: the durable product artifact, when promotion is
  justified. A feedback-only outcome changes no durable Atlas record.

If `EdubaWareVision/` is unavailable after the bootstrap in `CLAUDE.md`, report
the bootstrap error. Fetch the Atlas only with that bootstrap script.

## Route

Run these stages in order:

1. `stages/01_orient/CONTEXT.md` - read the smallest useful slice of the Atlas
   before replying to the user.
2. `stages/02_converse/CONTEXT.md` - explore the experience, publish an early
   feature draft when one exists, and confirm a faithful summary with the user.
3. `stages/03_route/CONTEXT.md` - select and, only when justified, write and
   publish one primary durable artifact to the Atlas.

Do not start stage 3 until the user confirms or corrects the stage 2 summary.
That confirmation is the only one: never ask the user to approve a publish.

## Working Rules

- Preserve the user's observation separately from agent interpretation.
- Ask focused follow-up questions instead of presenting a long questionnaire.
- Do not assume a requested implementation is the underlying need.
- Search existing feedback and Atlas records before creating duplicates.
- Treat `feedback/` as evidence, not as accepted product direction.
- Capture early: publish a rough draft as soon as it is usable, then refine
  or promote it. Unpublished work can be lost to errors.
- State the chosen Atlas artifact and reasoning when you publish it.
- Link any Atlas change back to the Workbench feedback record.
- A feedback-only outcome is valid when evidence is incomplete, behavior is
  unverified, or no product decision has been made.
