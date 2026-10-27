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
published) under `.icm-git/`, then reapplies and publishes it. It also tests
write access with an authenticated dry-run push and records the result in
`.icm-git/EdubaWareVision/write-access`. Do not edit or delete `.icm-git/`.

Publish with the same `export` lines in the same Bash command:
`bash .how-to-setup/configure-git.sh publish "<message>" <path>...`, with
paths relative to the checkout. A rejected push is rebased and retried; it is
never forced.

Run both commands exactly as shown. Never pipe or filter their output
(`| tail`, `| head`, `| grep`, `>/dev/null`, `2>&1 | ...`); read all of it,
and quote the full error to the user when one occurs. Each run ends with a
`STATUS:` line; act on its exit code:

- `0`: done. `Published` lists the commit hash and files.
- `75` FAILED UNPUBLISHED: a transient push failure. The files are saved
  under `.icm-git/` and the next bootstrap retries them.
- `76` CONFLICT: a saved change was not applied because the remote file also
  changed. Merge the saved copy it names into the checkout file, keeping both
  sets of content, and publish it in the same turn.
- `77` FAILED NO_WRITE_ACCESS: the API key named in the output cannot push
  (for example GitHub's 403 `Write access to repository not granted`). The
  Atlas is still readable and changes stay saved under `.icm-git/`. Keep
  working: write Atlas files locally as the stages require; they publish at
  the first bootstrap after access is fixed. The fix is for whoever manages
  the key; do not touch keys or settings.
- Any other failure of the plain bootstrap: stop and report the full output.
  Do not begin feedback intake with missing or stale Atlas context.

After 75 or 77, never describe the change as published or done. Tell the
user `FAILED`, the reason and exact error, the unpushed commit hash, the
files, and that the next turn's bootstrap retries them automatically. Record
the publish result as `pending-publish` in the feedback record.

## Reporting

Two kinds of files are written, and every report keeps them apart:

- **Workbench records**: files under `feedback/`. They stay in this workbench
  and are never published.
- **Atlas entries**: files in `crazyfox55/EdubaWareVision`, visible to
  everyone with the repository.

In the first reply of a conversation, say this in one sentence and give the
write-access result from the bootstrap (`Write access: OK`, or
`NO_WRITE_ACCESS` with the key name and error). Whenever a turn writes or
publishes anything, end the reply with:

```text
Workbench records (stay here): feedback/feature-requests/004-slug.md (draft)
Atlas entries (EdubaWareVision): features/drafts/slug.md (folder features/drafts) - published abc1234
                                 bugs/open/slug.md (folder bugs/open) - FAILED NO_WRITE_ACCESS (key github-key1), unpushed def5678, retried next turn
```

State what happened. Do not hedge ("no Atlas change for now", "tell me if
you'd rather promote"); the stage rules decide, and the reply reports.

## Boundaries

- `EdubaWareVision/` is the product Atlas. It is a workflow input for product
  context and the output destination for Atlas drafts and durable artifacts.
  It is nested in this workspace for access, but it remains a separate
  repository.
- `EdubaWareVision/features/drafts/` holds rough feature-request estimates
  published before confirmation or triage. Each draft is labelled as
  unaccepted. Only stage 3 promotes into `features/open/` or `bugs/open/`.
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
