#!/bin/bash
# Fetch, refresh, or publish a GitHub repository through the EdubaWare External API proxy.
#
#   bash .how-to-setup/configure-git.sh                          # fetch or refresh
#   bash .how-to-setup/configure-git.sh publish "<message>" <path>...  # commit and push
#
# Why it works this way (checked against EdubaWare master 369354dd):
# - Workbench files persist between turns, but `.git` directories never do
#   (ICM.Sandbox/utils/path_safety.py). A later turn can therefore find a
#   populated checkout with no repository, so this script never clones into
#   the checkout. It shallow-clones into a temporary directory, moves the fresh
#   `.git` into place, and resets the files to the remote branch. The remote
#   wins: publish an approved change in the same turn that writes it.
# - The proxy forwards git smart HTTP to github.com and adds the External API
#   Key's token server-side (EdubaWare.ApiService/Icm/GitSmartHttpProxy.cs), so
#   the token never enters the sandbox. Git authenticates to the proxy with
#   EDUBAWARE_SESSION_TOKEN, which is valid only during the current turn, so
#   run this script in each turn that needs the repository.
# - Chats on one workbench share its files and can run turns at the same time,
#   so runs against the same checkout are serialized with flock.

set -euo pipefail

: "${ICM_GITHUB_OWNER:?Set ICM_GITHUB_OWNER in the workflow instructions}"
: "${ICM_GITHUB_REPOSITORY:?Set ICM_GITHUB_REPOSITORY in the workflow instructions}"

ICM_GITHUB_BRANCH="${ICM_GITHUB_BRANCH:-main}"
ICM_GITHUB_CHECKOUT_DIR="${ICM_GITHUB_CHECKOUT_DIR:-${ICM_GITHUB_REPOSITORY}}"
ICM_GITHUB_API_KEY_NAME="${ICM_GITHUB_API_KEY_NAME:-github-key1}"

if [ -n "${EDUBAWARE_EXTERNAL_API_PROXY_URL:-}" ]; then
  : "${EDUBAWARE_SESSION_TOKEN:?EDUBAWARE_SESSION_TOKEN is not set; the proxy requires it}"
  REPOSITORY_REMOTE="${EDUBAWARE_EXTERNAL_API_PROXY_URL%/}/${ICM_GITHUB_API_KEY_NAME}/${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}.git"
else
  # Outside EdubaWare: direct HTTPS, which works only for public repositories.
  REPOSITORY_REMOTE="https://github.com/${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}.git"
fi

# The helper reads the token when git asks for it, so the token is never
# written to disk or to a command line.
CREDENTIAL_HELPER='!f() { echo "username=token"; echo "password=${EDUBAWARE_SESSION_TOKEN}"; }; f'

git_remote() {
  git -c credential.helper= -c "credential.helper=${CREDENTIAL_HELPER}" "$@"
}

lock_checkout() {
  command -v flock >/dev/null || return 0
  local key
  key="$(printf '%s' "${PWD}/${ICM_GITHUB_CHECKOUT_DIR}" | md5sum | cut -c1-12)"
  exec 9>"${TMPDIR:-/tmp}/icm-git-${key}.lock"
  flock -w 300 9
}

sync_checkout() {
  SYNC_TMP="$(mktemp -d)"
  trap 'rm -rf "${SYNC_TMP}"' EXIT
  local tmp="${SYNC_TMP}"

  git_remote clone --quiet --depth 1 --single-branch --branch "${ICM_GITHUB_BRANCH}" \
    "${REPOSITORY_REMOTE}" "${tmp}/repo"

  if [ -d "${ICM_GITHUB_CHECKOUT_DIR}" ] && [ -n "$(ls -A "${ICM_GITHUB_CHECKOUT_DIR}")" ]; then
    rm -rf "${ICM_GITHUB_CHECKOUT_DIR}/.git"
    mv "${tmp}/repo/.git" "${ICM_GITHUB_CHECKOUT_DIR}/.git"
    git -C "${ICM_GITHUB_CHECKOUT_DIR}" reset --quiet --hard HEAD
    # Lists local files that do not exist on the remote branch as it removes them.
    git -C "${ICM_GITHUB_CHECKOUT_DIR}" clean -fd
  else
    rm -rf "${ICM_GITHUB_CHECKOUT_DIR}"
    mkdir -p "$(dirname "${ICM_GITHUB_CHECKOUT_DIR}")"
    mv "${tmp}/repo" "${ICM_GITHUB_CHECKOUT_DIR}"
  fi

  git -C "${ICM_GITHUB_CHECKOUT_DIR}" config user.email "${ICM_GIT_USER_EMAIL:-icm-agent@eduba.io}"
  git -C "${ICM_GITHUB_CHECKOUT_DIR}" config user.name "${ICM_GIT_USER_NAME:-ICM Agent}"

  echo "${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}@${ICM_GITHUB_BRANCH} ready at ${ICM_GITHUB_CHECKOUT_DIR}"
  git -C "${ICM_GITHUB_CHECKOUT_DIR}" log -1 --format='%h %cs %s'
}

publish_checkout() {
  local message="${1:-}"
  shift || true
  if [ -z "${message}" ] || [ "$#" -eq 0 ]; then
    echo "Usage: configure-git.sh publish \"<message>\" <path>..." >&2
    exit 2
  fi
  if [ ! -d "${ICM_GITHUB_CHECKOUT_DIR}/.git" ]; then
    echo "No repository metadata in ${ICM_GITHUB_CHECKOUT_DIR}. Copy the change aside, run the" >&2
    echo "refresh, reapply the change, then publish in the same turn." >&2
    exit 1
  fi

  git -C "${ICM_GITHUB_CHECKOUT_DIR}" add -- "$@"
  if git -C "${ICM_GITHUB_CHECKOUT_DIR}" diff --cached --quiet; then
    echo "Nothing to publish."
    return 0
  fi
  git -C "${ICM_GITHUB_CHECKOUT_DIR}" commit --quiet -m "${message}"
  git_remote -C "${ICM_GITHUB_CHECKOUT_DIR}" push --quiet origin "HEAD:${ICM_GITHUB_BRANCH}"
  echo "Published to ${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}@${ICM_GITHUB_BRANCH}:"
  git -C "${ICM_GITHUB_CHECKOUT_DIR}" log -1 --format='%h %s'
}

lock_checkout
case "${1:-sync}" in
  sync) sync_checkout ;;
  publish) shift; publish_checkout "$@" ;;
  *) echo "Unknown command: $1 (expected sync or publish)" >&2; exit 2 ;;
esac
