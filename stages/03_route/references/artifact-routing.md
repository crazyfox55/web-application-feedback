# Atlas Artifact Routing

Choose the narrowest artifact that preserves the durable conclusion supported
by the feedback. Feedback is evidence; it is not itself a product decision.

| Supported conclusion | Primary Atlas artifact |
| --- | --- |
| A verified behavior differs from documented or accepted behavior | `bugs/open/` using `templates/bug.md` |
| An accepted user need requires a new or changed capability | `features/open/` using `templates/feature.md` |
| A durable decision, constraint, or trade-off needs explanation | A rationale record using `templates/rationale.md` |
| Product purpose or enduring direction has deliberately changed | `VISION.md` |
| Verified system structure or security posture has changed | The relevant file under `architecture/` |
| An existing Atlas record already covers the conclusion | Update that existing record with new evidence |
| The report is unverified, undecided, unclear, declined, or purely evidentiary | No Atlas change; retain the Workbench record |

## Selection Tests

Before proposing an Atlas change, answer:

1. What durable claim is supported beyond the fact that one user said it?
2. Is the claim verified, accepted, or explicitly decided by someone with the
   authority to make that decision?
3. Does an existing Atlas artifact already own this claim?
4. What would become misleading if the Atlas were changed now?

When answers are incomplete, select a feedback-only status and state what must
be learned or decided next.
