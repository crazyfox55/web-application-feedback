# Feedback Workbench Umbrella

This umbrella runs across multiple feedback conversations, retaining feedback
records between runs and publishing what it learns to the EdubaWareVision
Atlas as early as possible.

Read `CONTEXT.md` to route the work. Follow the numbered stage contracts in
order. The only user gate is the stage 2 summary confirmation. Never ask the
user to approve or confirm a publish: when an Atlas write is due, write it and
publish it in the same turn.

## Platform Bootstrap

Fetch or refresh the EdubaWareVision checkout at the start of every turn:

```bash
export ICM_GITHUB_OWNER="crazyfox55"
export ICM_GITHUB_REPOSITORY="EdubaWareVision"
export ICM_GITHUB_BRANCH="main"
export ICM_GITHUB_CHECKOUT_DIR="EdubaWareVision"
export ICM_GITHUB_API_KEY_NAME="github-key1"
bash .how-to-setup/configure-git.sh
```

The script is safe to rerun. It never clones into an existing folder and
resets `EdubaWareVision/` to the remote branch, but first it saves any Atlas
change that was not published (a failed push, or a file written but never
published) under `.icm-git/`, then reapplies and publishes it. Do not edit or
delete `.icm-git/`.

Publish with the same `export` lines in the same Bash command:
`bash .how-to-setup/configure-git.sh publish "<message>" <path>...`, with
paths relative to the checkout. A rejected push is rebased and retried; it is
never forced.

Read the script's output:

- Exit 0 with `ready at` or `Published`: done.
- `UNPUBLISHED` (publish exit 75): the change is kept and the next bootstrap
  publishes it. Continue the conversation; do not ask the user to retry.
  Record the status as `pending-publish` and mention it briefly.
- `CONFLICT`: someone else changed the same Atlas file. Merge the saved copy
  it names into the checkout file, keeping both sets of content, and publish
  it in the same turn.
- Any other failure of the plain bootstrap: stop and report it. Do not begin
  feedback intake with missing or stale Atlas context.

## Boundaries

- `EdubaWareVision/` is the product Atlas. It is a workflow input for product
  context and the output destination for Atlas drafts and durable artifacts.
  It is nested in this workspace for access, but it remains a separate
  repository.
- `EdubaWareVision/features/drafts/` holds rough feature-request estimates
  published before confirmation or triage. Each draft is labelled as
  unaccepted. Only stage 3 promotes a draft into `features/open/`.
- `feedback/` stores user accounts and Workbench interpretations accumulated
  across umbrella runs. It is never published to the Atlas. Several chats can
  share this workbench and run at the same time; re-list a folder immediately
  before numbering a new record.
- Repository bootstrap is a platform prerequisite executed by the agent before
  the domain stages. It is not itself a feedback stage.

## References

- `edubaware/edubaware-integrations.md`: what EdubaWare does with this folder
  (loading, tools, saving, uploads, previews, limits).
- `edubaware/workbooks.md`: when and how to write an interactive `.html` page.
- `.claude/skills/icm-architect/`: the `icm-architect` skill, for designing or
  auditing ICM workspaces. It is not part of the feedback stages.
