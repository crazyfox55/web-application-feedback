# Web Application Feedback Workbench

This Workbench collects and triages user feedback before durable product
knowledge is promoted into the EdubaWareVision Atlas. The directory is
self-contained so it can become a separate repository.

## Workflow

The Workbench follows the ICM contracts under `stages/`:

1. **Orient:** read core and relevant product knowledge from
  `EdubaWareVision/` before replying to the user.
2. **Converse:** explore the experience through focused questions, reflect it
  back, and wait for the user to confirm or correct the summary.
3. **Route:** decide which Atlas artifact, if any, should change. State that
  decision and obtain approval before writing the final artifact to the Atlas.

The user conversation is a review gate. It is not replaced by filling out a
form, and a raw report is not automatically promoted into product knowledge.

`EdubaWareVision/` therefore has two roles in this workflow: it supplies the
product context used during orientation, and it receives the approved durable
artifact at the end. `feedback/` is the inspectable intermediate representation
between those two uses.

## Ownership Boundary

The Workbench owns feedback intake templates because they describe how to ask
for and capture user observations. The Atlas owns `templates/bug.md`,
`templates/feature.md`, and `templates/rationale.md` because they define the
durable knowledge produced after triage.

When feedback is validated, create the appropriate Atlas record and link it to
the source feedback item. Keep the raw item here as evidence; do not treat an
untriaged report as an accepted feature or confirmed bug.

## Atlas Checkout

The workflow expects the Atlas at `EdubaWareVision/` inside the Workbench. Host
or template setup is responsible for supplying that checkout before a feedback
session starts. `.how-to-setup/` documents one way to do so; the feedback agent
does not run provisioning as a workflow stage.

## Supporting Tools

`generate_report.py` produces `output.html` from finalized records under
`feedback/`. Reporting is mechanical support for the workflow, not an ICM
stage and not part of the user conversation.