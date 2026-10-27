# Atlas Artifact Routing

Feedback is evidence, not a product decision. The Atlas still captures it
early, labelled for what it is, so it is not lost.

## Promotion Rules

Apply the first rule that matches the confirmed feedback record:

| # | Condition | Outcome |
| --- | --- | --- |
| 1 | An existing Atlas record already owns the need or behavior | Update that record with the new evidence; mark the draft `duplicate` of it |
| 2 | Someone with authority to decide has declined it | Draft status `declined`, with who and why |
| 3 | Issue report with a reproducible description: what the user did or the circumstances, what happened, and what they expected | `bugs/open/` using `templates/bug.md` |
| 4 | Feature request whose need and desired outcome are recognisable | Promote the draft to `features/open/` using `templates/feature.md` |
| 5 | None of the above (including general feedback) | No durable change; draft status `feedback-only`, naming the missing criterion |

Evidence such as logs, screenshots, or a team reproduction is not required
for rules 3 and 4. When it is missing or unverified, promote anyway with the
needs-validation banner from the stage contract.

Change `VISION.md`, a file under `architecture/`, or a rationale record
(`templates/rationale.md`) only to record a decision explicitly made by
someone with the authority to make it.
