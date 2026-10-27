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
#   `.git` into place, and resets the files to the remote branch.
# - Nothing unpublished is lost to that reset. After every sync or push the
#   script records the remote file hashes the checkout is based on in
#   `${ICM_GITHUB_STATE_DIR}/synced`. A file that differs from that record is
#   a local change. Before resetting, the script copies local changes to
#   `${ICM_GITHUB_STATE_DIR}/pending/` (outside the checkout, so it persists),
#   then reapplies and publishes them on top of the fresh remote. A pending
#   change whose remote file has also changed is kept, not applied, and
#   reported as a conflict.
# - A rejected push is fetched, rebased, and retried. It is never forced. If
#   the push still fails, the commit's files stay in the workbench and the next
#   sync publishes them.
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
ICM_GITHUB_STATE_DIR="${ICM_GITHUB_STATE_DIR:-.icm-git/${ICM_GITHUB_CHECKOUT_DIR}}"
ICM_GITHUB_PUSH_ATTEMPTS="${ICM_GITHUB_PUSH_ATTEMPTS:-4}"

if [ -n "${ICM_GITHUB_REMOTE_URL:-}" ]; then
  # Override for local testing against a scratch repository.
  REPOSITORY_REMOTE="${ICM_GITHUB_REMOTE_URL}"
elif [ -n "${EDUBAWARE_EXTERNAL_API_PROXY_URL:-}" ]; then
  : "${EDUBAWARE_SESSION_TOKEN:?EDUBAWARE_SESSION_TOKEN is not set; the proxy requires it}"
  REPOSITORY_REMOTE="${EDUBAWARE_EXTERNAL_API_PROXY_URL%/}/${ICM_GITHUB_API_KEY_NAME}/${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}.git"
else
  # Outside EdubaWare: direct HTTPS, which works only for public repositories.
  REPOSITORY_REMOTE="https://github.com/${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}.git"
fi

case "${ICM_GITHUB_STATE_DIR}" in
  /*) STATE="${ICM_GITHUB_STATE_DIR}" ;;
  *) STATE="${PWD}/${ICM_GITHUB_STATE_DIR}" ;;
esac
PENDING="${STATE}/pending"
MANIFEST="${PENDING}/manifest"   # lines: put|del <TAB> base blob or - <TAB> path

# The helper reads the token when git asks for it, so the token is never
# written to disk or to a command line.
CREDENTIAL_HELPER='!f() { echo "username=token"; echo "password=${EDUBAWARE_SESSION_TOKEN}"; }; f'

git_remote() {
  git -c credential.helper= -c "credential.helper=${CREDENTIAL_HELPER}" "$@"
}

g() {
  git -C "${ICM_GITHUB_CHECKOUT_DIR}" -c core.quotePath=false "$@"
}

lock_checkout() {
  command -v flock >/dev/null || return 0
  local key
  key="$(printf '%s' "${PWD}/${ICM_GITHUB_CHECKOUT_DIR}" | md5sum | cut -c1-12)"
  exec 9>"${TMPDIR:-/tmp}/icm-git-${key}.lock"
  flock -w 300 9
}

# Records the remote files the checkout is now based on.
record_synced() {
  mkdir -p "${STATE}"
  g ls-tree -r --full-tree "$1" | awk -F'\t' '{ split($1, a, " "); print a[3] "\t" $2 }' >"${STATE}/synced.tmp"
  mv "${STATE}/synced.tmp" "${STATE}/synced"
}

synced_blob() {
  awk -F'\t' -v p="$1" '$2 == p { print $1 }' "${STATE}/synced"
}

remote_blob() {
  g rev-parse -q --verify "HEAD:$1" 2>/dev/null || echo -
}

pending_blob() {
  g hash-object --stdin --path="$1" <"${PENDING}/files/$1"
}

drop_pending() {
  [ -f "${MANIFEST}" ] || return 0
  awk -F'\t' -v p="$1" '$3 != p' "${MANIFEST}" >"${MANIFEST}.tmp"
  mv "${MANIFEST}.tmp" "${MANIFEST}"
  rm -f "${PENDING}/files/$1"
}

save_pending() {
  local op="$1" base="$2" path="$3"
  mkdir -p "${PENDING}/files"
  drop_pending "${path}"
  if [ "${op}" = put ]; then
    mkdir -p "$(dirname "${PENDING}/files/${path}")"
    cp -p "${ICM_GITHUB_CHECKOUT_DIR}/${path}" "${PENDING}/files/${path}"
  fi
  printf '%s\t%s\t%s\n' "${op}" "${base}" "${path}" >>"${MANIFEST}"
  echo "Saved unpublished change: ${op} ${path}"
}

clear_pending_if_empty() {
  if [ -f "${MANIFEST}" ] && [ ! -s "${MANIFEST}" ]; then
    rm -rf "${PENDING}"
  fi
}

# Runs with the fresh `.git` in place but before the reset: every file that
# differs from the remote is either a local change (it also differs from the
# synced record) or a stale copy of a file someone else changed.
capture_local_changes() {
  local path base local_blob recovered
  local changed
  changed="$( { g diff --name-only --no-renames HEAD; g ls-files --others --exclude-standard; } | sort -u)"
  [ -n "${changed}" ] || return 0

  if [ ! -f "${STATE}/synced" ]; then
    # Without a record, local and stale copies look alike: keep them, unpublished.
    recovered="${STATE}/recovered/$(date -u +%Y%m%dT%H%M%SZ)"
    while IFS= read -r path; do
      [ -f "${ICM_GITHUB_CHECKOUT_DIR}/${path}" ] || continue
      mkdir -p "$(dirname "${recovered}/${path}")"
      cp -p "${ICM_GITHUB_CHECKOUT_DIR}/${path}" "${recovered}/${path}"
    done <<<"${changed}"
    echo "WARNING: no sync record; copied files that differ from the remote to ${recovered} without publishing them." >&2
    return 0
  fi

  while IFS= read -r path; do
    base="$(synced_blob "${path}")"
    if [ -f "${ICM_GITHUB_CHECKOUT_DIR}/${path}" ]; then
      local_blob="$(g hash-object -- "${path}")"
      [ "${local_blob}" != "${base}" ] || continue
      save_pending put "${base:--}" "${path}"
    elif [ -n "${base}" ]; then
      save_pending del "${base}" "${path}"
    fi
  done <<<"${changed}"
}

# Pushes HEAD, rebasing local commits onto the remote after a rejection.
# Sets PUSHED_FROM to the remote commit the pushed commits sit on.
push_with_retry() {
  local attempt=1
  PUSHED_FROM="$(g rev-parse "refs/remotes/origin/${ICM_GITHUB_BRANCH}")"
  until git_remote -C "${ICM_GITHUB_CHECKOUT_DIR}" push --quiet origin "HEAD:${ICM_GITHUB_BRANCH}"; do
    if [ "${attempt}" -ge "${ICM_GITHUB_PUSH_ATTEMPTS}" ]; then
      return 1
    fi
    attempt=$((attempt + 1))
    echo "Push failed; fetching and rebasing before attempt ${attempt} of ${ICM_GITHUB_PUSH_ATTEMPTS}." >&2
    sleep "$((attempt - 1))"
    git_remote -C "${ICM_GITHUB_CHECKOUT_DIR}" fetch --quiet origin "${ICM_GITHUB_BRANCH}" || continue
    if ! g rebase --quiet --autostash "refs/remotes/origin/${ICM_GITHUB_BRANCH}"; then
      g rebase --abort || true
      echo "Rebase conflicts with the remote." >&2
      return 1
    fi
    PUSHED_FROM="$(g rev-parse "refs/remotes/origin/${ICM_GITHUB_BRANCH}")"
    record_synced "${PUSHED_FROM}"
  done
}

after_push() {
  local path
  if [ -f "${MANIFEST}" ]; then
    while IFS= read -r path; do
      drop_pending "${path}"
    done < <(g diff --name-only --no-renames "${PUSHED_FROM}" HEAD)
    clear_pending_if_empty
  fi
  rm -f "${STATE}/messages"
  record_synced HEAD
}

# Applies saved changes on top of the fresh remote and publishes them.
replay_pending() {
  [ -s "${MANIFEST}" ] || return 0
  local op base path current wanted applied="" conflicts=""
  while IFS=$'\t' read -r op base path; do
    current="$(remote_blob "${path}")"
    wanted=-
    [ "${op}" = del ] || wanted="$(pending_blob "${path}")"
    if [ "${current}" = "${wanted}" ]; then
      drop_pending "${path}"
    elif [ "${current}" = "${base}" ]; then
      if [ "${op}" = put ]; then
        mkdir -p "$(dirname "${ICM_GITHUB_CHECKOUT_DIR}/${path}")"
        cp -p "${PENDING}/files/${path}" "${ICM_GITHUB_CHECKOUT_DIR}/${path}"
        g add -- "${path}"
      else
        g rm --quiet -- "${path}"
      fi
      applied="${applied}  ${op} ${path}"$'\n'
    else
      conflicts="${conflicts}  ${path} (saved copy: ${PENDING}/files/${path})"$'\n'
    fi
  done <"${MANIFEST}.replay"
  clear_pending_if_empty

  if [ -n "${conflicts}" ]; then
    echo "CONFLICT: these unpublished changes were not applied because the remote file changed too." >&2
    echo "Merge each saved copy into the checkout by hand, then publish it:" >&2
    printf '%s' "${conflicts}" >&2
  fi
  [ -n "${applied}" ] || return 0

  {
    if [ "$(wc -l <"${STATE}/messages" 2>/dev/null || echo 0)" -eq 1 ]; then
      cat "${STATE}/messages"
    elif [ -s "${STATE}/messages" ]; then
      echo "Publish Atlas changes saved after failed pushes"
      echo
      sed 's/^/- /' "${STATE}/messages"
    else
      echo "Publish Atlas changes saved in the workbench"
    fi
  } >"${STATE}/commit-message"
  g commit --quiet -F "${STATE}/commit-message"
  rm -f "${STATE}/commit-message"

  if push_with_retry; then
    after_push
    echo "Published saved changes:"
    printf '%s' "${applied}"
  else
    echo "WARNING: saved changes are applied in the checkout but still unpublished; the next sync retries them:" >&2
    printf '%s' "${applied}" >&2
  fi
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
    # A marker left by an interrupted reset means the files may already be
    # partly reset; the pending copy saved before it is authoritative.
    if [ ! -e "${STATE}/refreshing" ]; then
      capture_local_changes
    fi
    mkdir -p "${STATE}"
    : >"${STATE}/refreshing"
    g reset --quiet --hard HEAD
    g clean -fdq
  else
    rm -rf "${ICM_GITHUB_CHECKOUT_DIR}"
    mkdir -p "$(dirname "${ICM_GITHUB_CHECKOUT_DIR}")"
    mv "${tmp}/repo" "${ICM_GITHUB_CHECKOUT_DIR}"
  fi

  g config user.email "${ICM_GIT_USER_EMAIL:-icm-agent@eduba.io}"
  g config user.name "${ICM_GIT_USER_NAME:-ICM Agent}"
  record_synced HEAD
  rm -f "${STATE}/refreshing"

  if [ -s "${MANIFEST}" ]; then
    cp "${MANIFEST}" "${MANIFEST}.replay"
    replay_pending
    rm -f "${MANIFEST}.replay"
  fi

  echo "${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}@${ICM_GITHUB_BRANCH} ready at ${ICM_GITHUB_CHECKOUT_DIR}"
  g log -1 --format='%h %cs %s'
}

publish_checkout() {
  local message="${1:-}"
  shift || true
  if [ -z "${message}" ] || [ "$#" -eq 0 ]; then
    echo "Usage: configure-git.sh publish \"<message>\" <path>..." >&2
    exit 2
  fi
  if [ ! -d "${ICM_GITHUB_CHECKOUT_DIR}/.git" ]; then
    echo "No repository metadata in ${ICM_GITHUB_CHECKOUT_DIR}. Run the sync first; it keeps" >&2
    echo "and publishes the unpublished files it finds. Then publish again if needed." >&2
    exit 1
  fi

  g remote set-url origin "${REPOSITORY_REMOTE}"
  g add -A -- "$@"
  if ! g diff --cached --quiet; then
    g commit --quiet -m "${message}"
    mkdir -p "${STATE}"
    printf '%s\n' "${message}" >>"${STATE}/messages"
  elif [ -z "$(g rev-list "refs/remotes/origin/${ICM_GITHUB_BRANCH}..HEAD")" ]; then
    echo "Nothing to publish."
    return 0
  fi

  if push_with_retry; then
    after_push
    echo "Published to ${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}@${ICM_GITHUB_BRANCH}:"
    g log -1 --format='%h %s'
  else
    echo "UNPUBLISHED: the change is saved in the workbench files and will be published by the" >&2
    echo "next sync (rerun the bootstrap now or at the start of the next turn). Do not delete it." >&2
    exit 75
  fi
}

lock_checkout
case "${1:-sync}" in
  sync) sync_checkout ;;
  publish) shift; publish_checkout "$@" ;;
  *) echo "Unknown command: $1 (expected sync or publish)" >&2; exit 2 ;;
esac
