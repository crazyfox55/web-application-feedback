# Web Application Feedback Workbench

This repository develops the Feedback Workbench umbrella ICM. The publishable
ICM is rooted at `workflow/`; repository-level documentation, historical
records, and development instructions stay outside that package boundary.

This is an umbrella rather than a reset-per-run workflow. It runs the feedback
stages repeatedly while retaining confirmed records under `feedback/`, allowing
later conversations to build on the shared experience needed for useful
feedback.

## Repository Layout

- `workflow/`: the runnable, stateful ICM package.
- `records/`: historical feedback retained for development and reference, but
  excluded from new ICM sessions.
- `docs/setup/`: human setup guidance and screenshots.
- `icm.yaml`: the package contract used by local tooling and publishing.

## Umbrella Behavior

The Workbench follows the ICM contracts under `workflow/stages/`:

1. **Orient:** read core and relevant product knowledge from
  `EdubaWareVision/` before replying to the user.
2. **Converse:** explore the experience through focused questions, reflect it
  back, and wait for the user to confirm or correct the summary.
3. **Route:** decide which Atlas artifact, if any, should change. State that
  decision and obtain approval before writing the final artifact to the Atlas.

The user conversation is a review gate. It is not replaced by filling out a
form, and a raw report is not automatically promoted into product knowledge.

`EdubaWareVision/` therefore has two roles at runtime: it supplies the product
context used during orientation, and it receives the approved durable artifact
at the end. `workflow/feedback/` is the inspectable intermediate representation
between those two uses and accumulates feedback across runs of an umbrella
session.

## Ownership Boundary

The Workbench owns the feedback intake templates under `workflow/feedback/`
because they describe how to ask for and capture user observations. The Atlas
owns `templates/bug.md`, `templates/feature.md`, and `templates/rationale.md`
because they define the durable knowledge produced after triage.

When feedback is validated, create the appropriate Atlas record and link it to
the source feedback item. Keep the raw item as evidence; do not treat an
untriaged report as an accepted feature or confirmed bug.

## Atlas Checkout

The umbrella expects the Atlas at `EdubaWareVision/` inside its runtime root.
Host or template setup is responsible for supplying that checkout before a
feedback session starts. `docs/setup/` describes the integration, while
`workflow/.how-to-setup/configure-git.sh` performs it at runtime.

## Supporting Tools

`workflow/generate_report.py` produces `workflow/output.html` from finalized
records under `workflow/feedback/`. Reporting is mechanical support for the
umbrella, not an ICM stage and not part of the user conversation.

## Package

Build an archive whose root is the contents of `workflow/`:

```bash
git archive --format=zip --output=web-application-feedback.zip HEAD:workflow
```