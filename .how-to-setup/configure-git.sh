#!/bin/bash
# Configure Git and check out a workflow repository through the EdubaWare proxy.

set -euo pipefail

: "${ICM_GITHUB_OWNER:?Set ICM_GITHUB_OWNER in the workflow instructions}"
: "${ICM_GITHUB_REPOSITORY:?Set ICM_GITHUB_REPOSITORY in the workflow instructions}"

ICM_GITHUB_BRANCH="${ICM_GITHUB_BRANCH:-main}"
ICM_GITHUB_CHECKOUT_DIR="${ICM_GITHUB_CHECKOUT_DIR:-${ICM_GITHUB_REPOSITORY}}"
ICM_GITHUB_API_KEY_NAME="${ICM_GITHUB_API_KEY_NAME:-github-key1}"

git config --global user.email "${ICM_GIT_USER_EMAIL:-icm-agent@eduba.io}"
git config --global user.name "${ICM_GIT_USER_NAME:-ICM Agent}"

# Configure credential helper to provide session token via Basic auth
git config --global credential.helper '!f() { echo "username=token"; echo "password=${EDUBAWARE_SESSION_TOKEN}"; }; f'

if [ -n "${EDUBAWARE_EXTERNAL_API_PROXY_URL:-}" ]; then
  REPOSITORY_REMOTE="${EDUBAWARE_EXTERNAL_API_PROXY_URL}/${ICM_GITHUB_API_KEY_NAME}/${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}.git"
else
  REPOSITORY_REMOTE="https://github.com/${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}.git"
fi

if [ -d "${ICM_GITHUB_CHECKOUT_DIR}/.git" ]; then
  git -C "${ICM_GITHUB_CHECKOUT_DIR}" remote set-url origin "${REPOSITORY_REMOTE}"
  git -C "${ICM_GITHUB_CHECKOUT_DIR}" checkout "${ICM_GITHUB_BRANCH}"
  git -C "${ICM_GITHUB_CHECKOUT_DIR}" pull --ff-only origin "${ICM_GITHUB_BRANCH}"
elif [ -e "${ICM_GITHUB_CHECKOUT_DIR}" ]; then
  echo "Checkout path exists but is not a Git repository: ${ICM_GITHUB_CHECKOUT_DIR}" >&2
  exit 1
else
  mkdir -p "$(dirname "${ICM_GITHUB_CHECKOUT_DIR}")"
  git clone --branch "${ICM_GITHUB_BRANCH}" "${REPOSITORY_REMOTE}" "${ICM_GITHUB_CHECKOUT_DIR}"
fi

echo "${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY} ready at ${ICM_GITHUB_CHECKOUT_DIR}"
git -C "${ICM_GITHUB_CHECKOUT_DIR}" status --short --branch
git -C "${ICM_GITHUB_CHECKOUT_DIR}" remote -v
