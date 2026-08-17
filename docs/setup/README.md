# Setting Up GitHub Access for an Umbrella ICM

This guide describes the GitHub integration used by this umbrella ICM on the
EdubaWare platform. The publishable package includes
`workflow/.how-to-setup/configure-git.sh`. Claude runs it when a session starts;
the person creating the umbrella does not need to write or manually run a
bootstrap script.

## Security Note

Alpha testing: people within your organization may convince an agent to act
maliciously toward a connected repository. Use narrow access controls,
repository permissions, and token expiration.

## Prerequisites

- EdubaWare organization admin access
- A GitHub repository for the workflow to read or update (can be private)
- An ICM workflow containing its own context and stage contracts (like this repo)

## Step 1: Create GitHub Personal Access Token (PAT)

1. Go to https://github.com/settings/personal-access-tokens/new
2. Click "Generate new token (fine-grained)"
3. Configure token:
    - Repository access: select "Only select repositories" and choose only the
       repositories required by your workflow
   - Expiration: 90 days (or as needed)
   - Repository permissions:
       - Contents: Read-only for reference inputs, or read and write when the
          workflow produces artifacts in the repository
     - Metadata: Read-only
     - Pull requests: Read and write (if needed)
4. Generate token and **save it securely** (you won't see it again)

## Step 2: Register External API Key in EdubaWare

1. Log into EdubaWare as organization admin
2. Navigate to External API Keys settings
3. Create new key:
   - Name: a descriptive name such as `github-reponame`
   - Target Base URL: `https://api.github.com`
   - Auth Header Name: `Authorization`
   - Auth Header Prefix: `Bearer ` (with trailing space)
   - Secret: Paste the GitHub PAT from Step 1

## Step 3: Prepare the Umbrella

1. Create or clone the repository that will contain your umbrella ICM.
2. Define the umbrella's identity, routing, stage contracts, reference inputs,
   working artifacts, review gates, and outputs in its own context files.
3. Include `.how-to-setup/configure-git.sh` in the packaged umbrella root. This
   repository stores it at `workflow/.how-to-setup/configure-git.sh`. The script
   configures the platform credential helper and clones or refreshes the
   required repository. Do not replace it with a workflow-specific script.
4. Put the repository-specific configuration and execution requirement in the
   umbrella's runtime `CLAUDE.md`. In this repository that is
   `workflow/CLAUDE.md`. For example:

   ```bash
   export ICM_GITHUB_OWNER="<github-owner>"
   export ICM_GITHUB_REPOSITORY="<repository-name>"
   export ICM_GITHUB_BRANCH="main"
   export ICM_GITHUB_CHECKOUT_DIR="<local-checkout-path>"
   export ICM_GITHUB_API_KEY_NAME="<external-api-key-name>"
   bash .how-to-setup/configure-git.sh
   git -C "${ICM_GITHUB_CHECKOUT_DIR}" status --short --branch
   git -C "${ICM_GITHUB_CHECKOUT_DIR}" remote -v
   git -C "${ICM_GITHUB_CHECKOUT_DIR}" pull --ff-only origin "${ICM_GITHUB_BRANCH}"
   ```

   These values are workflow configuration, not secrets. The API key name must
   match the External API Key registered in Step 2. The platform supplies
   `EDUBAWARE_SESSION_TOKEN` and `EDUBAWARE_EXTERNAL_API_PROXY_URL` at runtime.
5. Tell Claude to stop and report an error when bootstrap or Git verification
   fails. The domain workflow must not continue with missing or stale context.
6. Grant the narrowest repository permissions that support the workflow's
   declared inputs and outputs.
7. Commit and push the umbrella definition, runtime `CLAUDE.md`, and the
   provided bootstrap script to the repository.

## Step 4: Create ICM Template

1. Create an archive from the `workflow/` package root. Do not download or
   package the entire repository:

   ```bash
   git archive --format=zip --output=web-application-feedback.zip HEAD:workflow
   ```

2. Upload ZIP to EdubaWare as ICM template
3. Configure the template to use the External API Key created in Step 2.

## Step 5: Test

1. Start a new ICM session from the template.
2. Confirm that Claude follows `CLAUDE.md` and runs
   `.how-to-setup/configure-git.sh` before the first domain stage.
3. Confirm that Claude runs the declared `git status`, `git remote`, and
   `git pull --ff-only` verification commands and reports their results.
4. Confirm that the checkout appears at `ICM_GITHUB_CHECKOUT_DIR` on both a new
   session and a later session where the checkout already exists.
5. Run a harmless workflow test that reads expected context and writes only to
   a temporary or test output location.

## Troubleshooting

- If Git authentication fails: check that the External API Key is ICM Proxy
  Enabled and scoped to the intended repository.
- If the remote URL is wrong: verify `EDUBAWARE_EXTERNAL_API_PROXY_URL`, the
  configured API key name, `ICM_GITHUB_OWNER`, and
  `ICM_GITHUB_REPOSITORY`.
- If the PAT expired: generate a new token and update the External API Key
  secret.
- If the script reports a missing variable: add the corresponding
   `ICM_GITHUB_*` export to the umbrella's runtime `CLAUDE.md`.
- If the agent cannot find context: verify that the workflow's root router and
  stage contracts use paths relative to `ICM_GITHUB_CHECKOUT_DIR` in the
  packaged template layout.