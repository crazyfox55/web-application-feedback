# Feedback Workbench Umbrella

This umbrella runs across multiple feedback conversations, retaining confirmed
records between runs and, when warranted, proposing changes to the
EdubaWareVision Atlas.

Read `CONTEXT.md` to route the work. Follow the numbered stage contracts in
order. Do not skip the user review gates between conversation and promotion.

## Platform Bootstrap

Before reading Atlas context or starting the workflow, configure and verify the
nested EdubaWareVision checkout:

```bash
export ICM_GITHUB_OWNER="crazyfox55"
export ICM_GITHUB_REPOSITORY="EdubaWareVision"
export ICM_GITHUB_BRANCH="main"
export ICM_GITHUB_CHECKOUT_DIR="EdubaWareVision"
export ICM_GITHUB_API_KEY_NAME="github-key1"
bash .how-to-setup/configure-git.sh
git -C EdubaWareVision status --short --branch
git -C EdubaWareVision remote -v
git -C EdubaWareVision pull --ff-only origin main
```

Stop and report the failure if any bootstrap or verification command fails. Do
not begin feedback intake with missing or stale Atlas context.

## Boundaries

- `EdubaWareVision/` is the product Atlas. It is a workflow input for product
  context and the output destination for an approved durable artifact. It is
  nested in this workspace for access, but it remains a separate repository.
- `feedback/` stores confirmed user accounts and Workbench interpretations
  accumulated across umbrella runs.
- Durable product knowledge belongs in the Atlas only after the user confirms
  that the feedback record represents what they meant and approves the proposed
  artifact choice.
- Repository bootstrap is a platform prerequisite executed by the agent before
  the domain stages. It is not itself a feedback stage.