# Feedback Workbench Umbrella

This umbrella runs across multiple feedback conversations, retaining confirmed
records between runs and, when warranted, proposing changes to the
EdubaWareVision Atlas.

Read `CONTEXT.md` to route the work. Follow the numbered stage contracts in
order. Do not skip the user review gates between conversation and promotion.

## Platform Bootstrap

Fetch or refresh the EdubaWareVision checkout at the start of each chat's first
turn, and again in the stage 3 turn before writing to the Atlas:

```bash
export ICM_GITHUB_OWNER="crazyfox55"
export ICM_GITHUB_REPOSITORY="EdubaWareVision"
export ICM_GITHUB_BRANCH="main"
export ICM_GITHUB_CHECKOUT_DIR="EdubaWareVision"
export ICM_GITHUB_API_KEY_NAME="github-key1"
bash .how-to-setup/configure-git.sh
```

The script is safe to rerun: it never clones into an existing folder, and it
resets `EdubaWareVision/` to the remote branch. Saved workbench files do not
keep `.git`, so treat any Atlas file not yet published as temporary.

Stop and report the failure if the script fails. Do not begin feedback intake
with missing or stale Atlas context.

## Boundaries

- `EdubaWareVision/` is the product Atlas. It is a workflow input for product
  context and the output destination for an approved durable artifact. It is
  nested in this workspace for access, but it remains a separate repository.
- `feedback/` stores confirmed user accounts and Workbench interpretations
  accumulated across umbrella runs. Several chats can share this workbench and
  run at the same time; re-list a folder immediately before numbering a new
  record.
- Durable product knowledge belongs in the Atlas only after the user confirms
  that the feedback record represents what they meant and approves the proposed
  artifact choice.
- Repository bootstrap is a platform prerequisite executed by the agent before
  the domain stages. It is not itself a feedback stage.

## References

- `edubaware/edubaware-integrations.md`: what EdubaWare does with this folder
  (loading, tools, saving, uploads, previews, limits).
- `edubaware/workbooks.md`: when and how to write an interactive `.html` page.
- `.claude/skills/icm-architect/`: the `icm-architect` skill, for designing or
  auditing ICM workspaces. It is not part of the feedback stages.
