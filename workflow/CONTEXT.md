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

- `feedback/`: the confirmed conversation record and routing trace.
- `EdubaWareVision/`: the approved durable product artifact, when promotion is
   justified. A feedback-only outcome produces no Atlas change.

If `EdubaWareVision/` is unavailable, explain that the Atlas checkout is a host
prerequisite. Do not clone it or configure credentials during feedback intake.

## Route

Run these stages in order:

1. `stages/01_orient/CONTEXT.md` - read the smallest useful slice of the Atlas
   before replying to the user.
2. `stages/02_converse/CONTEXT.md` - explore the experience and confirm a
   faithful summary with the user.
3. `stages/03_route/CONTEXT.md` - select and, only when justified and approved,
   write one primary durable artifact to the Atlas.

Do not start stage 3 until the user confirms or corrects the stage 2 summary.

## Working Rules

- Preserve the user's observation separately from agent interpretation.
- Ask focused follow-up questions instead of presenting a long questionnaire.
- Do not assume a requested implementation is the underlying need.
- Search existing feedback and Atlas records before creating duplicates.
- Treat `feedback/` as evidence, not as accepted product direction.
- State the chosen Atlas artifact and reasoning before changing it.
- Link any Atlas change back to the Workbench feedback record.
- A feedback-only outcome is valid when evidence is incomplete, behavior is
  unverified, or no product decision has been made.
