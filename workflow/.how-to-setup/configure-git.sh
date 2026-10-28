#!/bin/bash
# Fetch, refresh, or publish a GitHub repository through the EdubaWare External API proxy.
#
#   bash .how-to-setup/configure-git.sh                          # fetch or refresh
#   bash .how-to-setup/configure-git.sh publish "<message>" <path>...  # commit and push
#   bash .how-to-setup/configure-git.sh check-slug <path>        # EXISTS <path> or NEW on the remote
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
#   reported as a conflict. With no record yet (the first run after a
#   template whose refresh kept no state), a file the remote never had is
#   published, and any other difference is kept aside under `recovered/`.
#   Before any reset, every changed or untracked file and a binary patch are
#   also copied to `backups/<timestamp>/` (newest 10 kept; printed as BACKUP).
# - A successful push is confirmed with `ls-remote` (printed as VERIFIED); a
#   push the remote does not show is treated as UNPUBLISHED.
# - A rejected push is fetched, rebased, and retried. It is never forced. An
#   authorization failure (for example GitHub's 403 "Write access to repository
#   not granted") is not retried. Either way the commit's files are saved to
#   pending and the next sync publishes them.
# - Every sync checks write access with an authenticated `git push --dry-run`
#   (GitHub authorizes git-receive-pack before advertising refs) and records
#   the result in `${ICM_GITHUB_STATE_DIR}/write-access`.
# - Exit codes: 0 done; 75 UNPUBLISHED (transient, retried by the next sync);
#   76 CONFLICT (a saved change needs a manual merge); 77 NO_WRITE_ACCESS (the
#   API key cannot push; changes stay pending). A sync that exits 75-77 still
#   leaves the checkout ready to read.
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

EXIT_UNPUBLISHED=75
EXIT_CONFLICT=76
EXIT_NO_WRITE_ACCESS=77
STATUS=0   # worst outcome so far; a higher code takes precedence
AUTH_FAILURE='Write access to repository not granted|Permission to .* denied|returned error: 40[13]|Authentication failed|could not read (Username|Password)|Invalid username or password'

# The helper reads the token when git asks for it, so the token is never
# written to disk or to a command line.
CREDENTIAL_HELPER='!f() { echo "username=token"; echo "password=${EDUBAWARE_SESSION_TOKEN}"; }; f'

git_remote() {
  git -c credential.helper= -c "credential.helper=${CREDENTIAL_HELPER}" "$@"
}

# Runs a remote git command, prints its complete output, and keeps it in
# GIT_OUTPUT for classification.
remote_git() {
  local rc=0
  GIT_OUTPUT="$(git_remote "$@" 2>&1)" || rc=$?
  [ -z "${GIT_OUTPUT}" ] || printf '%s\n' "${GIT_OUTPUT}" >&2
  return "${rc}"
}

is_auth_failure() {
  grep -qiE "${AUTH_FAILURE}" <<<"${GIT_OUTPUT}"
}

raise_status() {
  [ "$1" -le "${STATUS}" ] || STATUS="$1"
}

g() {
  git -C "${ICM_GITHUB_CHECKOUT_DIR}" -c core.quotePath=false "$@"
}

# Persists the latest write-access result: ok, denied, or unknown.
record_write_access() {
  mkdir -p "${STATE}"
  {
    echo "status=$1"
    echo "checked=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "key=${ICM_GITHUB_API_KEY_NAME}"
    echo "repository=${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}@${ICM_GITHUB_BRANCH}"
    [ -z "${2:-}" ] || printf 'error:\n%s\n' "$2"
  } >"${STATE}/write-access"
}

no_write_access_message() {
  echo "NO_WRITE_ACCESS: API key '${ICM_GITHUB_API_KEY_NAME}' cannot push to ${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}; git's error is printed above." >&2
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

# Copies every file the reset or clean would change, plus a binary patch of
# tracked changes, to a timestamped folder outside the checkout.
backup_checkout() {
  local changed dir path old
  changed="$( { g diff --name-only --no-renames HEAD; g ls-files --others --exclude-standard; } | sort -u)"
  [ -n "${changed}" ] || return 0
  dir="${STATE}/backups/$(date -u +%Y%m%dT%H%M%SZ)-$$"
  mkdir -p "${dir}/files"
  g diff --binary --no-renames HEAD >"${dir}/tracked.patch"
  printf '%s\n' "${changed}" >"${dir}/paths"
  while IFS= read -r path; do
    [ -f "${ICM_GITHUB_CHECKOUT_DIR}/${path}" ] || continue
    mkdir -p "$(dirname "${dir}/files/${path}")"
    cp -p "${ICM_GITHUB_CHECKOUT_DIR}/${path}" "${dir}/files/${path}"
  done <<<"${changed}"
  echo "BACKUP: ${dir}"
  while IFS= read -r old; do
    rm -rf "${old}"
  done < <(ls -1d "${STATE}/backups"/*/ | sort -r | tail -n +11)
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
    # Without a record (for example the first run after a template whose
    # refresh kept no state), a file the remote never had is a local addition,
    # so it is published. A file the remote deleted, or a changed remote file,
    # may be a local edit or a stale copy: keep it aside, unpublished, for a
    # manual merge. The remote's history (commits and trees, no file contents)
    # tells the two apart; if it cannot be fetched, additions are published.
    local history=1
    if ! remote_git -C "${ICM_GITHUB_CHECKOUT_DIR}" fetch --quiet --unshallow --filter=blob:none origin "${ICM_GITHUB_BRANCH}"; then
      history=0
      echo "WARNING: could not fetch remote history; files the remote lacks are treated as local additions." >&2
    fi
    recovered="${STATE}/recovered/$(date -u +%Y%m%dT%H%M%SZ)"
    while IFS= read -r path; do
      [ -f "${ICM_GITHUB_CHECKOUT_DIR}/${path}" ] || continue
      if [ "$(remote_blob "${path}")" = - ] && { [ "${history}" -eq 0 ] ||
        [ -z "$(g log -1 --format=%h HEAD -- "${path}")" ]; }; then
        save_pending put - "${path}"
        continue
      fi
      mkdir -p "$(dirname "${recovered}/${path}")"
      cp -p "${ICM_GITHUB_CHECKOUT_DIR}/${path}" "${recovered}/${path}"
      echo "  ${path} (saved copy: ${recovered}/${path})" >&2
      raise_status "${EXIT_CONFLICT}"
    done <<<"${changed}"
    if [ -d "${recovered}" ]; then
      echo "CONFLICT: no sync record; the files above differ from the remote (changed, or deleted there) and were not published." >&2
      echo "Merge what is yours into the checkout by hand, then publish it." >&2
    fi
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
# Sets PUSHED_FROM to the remote commit the pushed commits sit on. On failure
# returns the exit code that describes it; authorization failures fail fast.
push_with_retry() {
  local attempt=1
  PUSHED_FROM="$(g rev-parse "refs/remotes/origin/${ICM_GITHUB_BRANCH}")"
  until remote_git -C "${ICM_GITHUB_CHECKOUT_DIR}" push --quiet origin "HEAD:${ICM_GITHUB_BRANCH}"; do
    if is_auth_failure; then
      record_write_access denied "${GIT_OUTPUT}"
      no_write_access_message
      return "${EXIT_NO_WRITE_ACCESS}"
    fi
    if [ "${attempt}" -ge "${ICM_GITHUB_PUSH_ATTEMPTS}" ]; then
      return "${EXIT_UNPUBLISHED}"
    fi
    attempt=$((attempt + 1))
    echo "Push failed; fetching and rebasing before attempt ${attempt} of ${ICM_GITHUB_PUSH_ATTEMPTS}." >&2
    sleep "$((attempt - 1))"
    remote_git -C "${ICM_GITHUB_CHECKOUT_DIR}" fetch --quiet origin "${ICM_GITHUB_BRANCH}" || continue
    if ! g rebase --quiet --autostash "refs/remotes/origin/${ICM_GITHUB_BRANCH}"; then
      g rebase --abort || true
      echo "Rebase conflicts with the remote." >&2
      return "${EXIT_UNPUBLISHED}"
    fi
    PUSHED_FROM="$(g rev-parse "refs/remotes/origin/${ICM_GITHUB_BRANCH}")"
    record_synced "${PUSHED_FROM}"
  done
  record_write_access ok
  verify_push
}

# Confirms the remote branch is HEAD or already contains it.
verify_push() {
  local head remote
  head="$(g rev-parse HEAD)"
  remote="$(git_remote -C "${ICM_GITHUB_CHECKOUT_DIR}" ls-remote origin "refs/heads/${ICM_GITHUB_BRANCH}" | cut -f1)" || true
  if [ -n "${remote}" ] && { [ "${remote}" = "${head}" ] || {
    remote_git -C "${ICM_GITHUB_CHECKOUT_DIR}" fetch --quiet origin "${ICM_GITHUB_BRANCH}" &&
      g merge-base --is-ancestor "${head}" "${remote}"; }; }; then
    echo "VERIFIED: ${head} on origin/${ICM_GITHUB_BRANCH}"
    return 0
  fi
  echo "UNVERIFIED: origin/${ICM_GITHUB_BRANCH} is '${remote:-unreadable}', which does not contain ${head}." >&2
  return "${EXIT_UNPUBLISHED}"
}

# After a failed push: saves the unpushed files to pending, where they survive
# the loss of `.git`, and states exactly what is unpublished.
report_unpushed() {
  local code="$1" label=UNPUBLISHED path base
  [ "${code}" -ne "${EXIT_NO_WRITE_ACCESS}" ] || label=NO_WRITE_ACCESS
  while IFS= read -r path; do
    base="$(synced_blob "${path}")"
    if [ -f "${ICM_GITHUB_CHECKOUT_DIR}/${path}" ]; then
      save_pending put "${base:--}" "${path}"
    elif [ -n "${base}" ]; then
      save_pending del "${base}" "${path}"
    fi
  done < <(g diff --name-only --no-renames "${PUSHED_FROM}" HEAD)
  echo "FAILED: ${label} (exit ${code}). Nothing below reached ${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}." >&2
  echo "Unpushed local commit (the hash does not survive this turn):" >&2
  g log --format='  %h %s' "${PUSHED_FROM}..HEAD" >&2
  echo "Files, saved in ${PENDING} and retried by the next bootstrap:" >&2
  g diff --name-status --no-renames "${PUSHED_FROM}" HEAD | sed 's/^/  /' >&2
  raise_status "${code}"
}

# Tests write authorization without changing the remote.
check_write_access() {
  if remote_git -C "${ICM_GITHUB_CHECKOUT_DIR}" push --dry-run --quiet origin "HEAD:${ICM_GITHUB_BRANCH}"; then
    record_write_access ok
    echo "Write access: OK (key ${ICM_GITHUB_API_KEY_NAME})"
  elif is_auth_failure; then
    record_write_access denied "${GIT_OUTPUT}"
    no_write_access_message
    raise_status "${EXIT_NO_WRITE_ACCESS}"
  else
    record_write_access unknown "${GIT_OUTPUT}"
    echo "WARNING: the write-access check failed for a reason other than authorization (output above); publishing will still be attempted." >&2
  fi
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
    raise_status "${EXIT_CONFLICT}"
  fi
  [ -n "${applied}" ] || return 0

  if [ "${STATUS}" -eq "${EXIT_NO_WRITE_ACCESS}" ]; then
    g reset --quiet
    echo "Not publishing saved changes without write access; they stay pending and are in the checkout:" >&2
    printf '%s' "${applied}" >&2
    return 0
  fi

  {
    if [ -f "${STATE}/messages" ] && [ "$(wc -l <"${STATE}/messages")" -eq 1 ]; then
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

  local code=0
  push_with_retry || code=$?
  if [ "${code}" -eq 0 ]; then
    echo "Published saved changes:"
    g log -1 --format='  %h %s'
    printf '%s' "${applied}"
    after_push
  else
    report_unpushed "${code}"
  fi
}

sync_checkout() {
  SYNC_TMP="$(mktemp -d)"
  trap 'rm -rf "${SYNC_TMP}"' EXIT
  local tmp="${SYNC_TMP}"

  if ! remote_git clone --quiet --depth 1 --single-branch --branch "${ICM_GITHUB_BRANCH}" \
    "${REPOSITORY_REMOTE}" "${tmp}/repo"; then
    echo "FAILED: could not fetch ${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}@${ICM_GITHUB_BRANCH} with API key '${ICM_GITHUB_API_KEY_NAME}'; git's error is printed above." >&2
    exit 1
  fi

  if [ -d "${ICM_GITHUB_CHECKOUT_DIR}" ] && [ -n "$(ls -A "${ICM_GITHUB_CHECKOUT_DIR}")" ]; then
    rm -rf "${ICM_GITHUB_CHECKOUT_DIR}/.git"
    mv "${tmp}/repo/.git" "${ICM_GITHUB_CHECKOUT_DIR}/.git"
    backup_checkout
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
  check_write_access

  if [ -s "${MANIFEST}" ]; then
    cp "${MANIFEST}" "${MANIFEST}.replay"
    replay_pending
    rm -f "${MANIFEST}.replay"
  fi

  echo "${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}@${ICM_GITHUB_BRANCH} ready at ${ICM_GITHUB_CHECKOUT_DIR}"
  g log -1 --format='%h %cs %s'
  if [ -s "${MANIFEST}" ]; then
    echo "Unpublished Atlas changes still pending:"
    awk -F'\t' '{ print "  " $1 " " $3 }' "${MANIFEST}"
  fi
  exit_with_status
}

exit_with_status() {
  case "${STATUS}" in
    0) echo "STATUS: OK" ;;
    "${EXIT_UNPUBLISHED}") echo "STATUS: FAILED UNPUBLISHED (exit ${STATUS})" ;;
    "${EXIT_CONFLICT}") echo "STATUS: CONFLICT (exit ${STATUS})" ;;
    "${EXIT_NO_WRITE_ACCESS}") echo "STATUS: FAILED NO_WRITE_ACCESS (exit ${STATUS}, key ${ICM_GITHUB_API_KEY_NAME})" ;;
  esac
  exit "${STATUS}"
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

  local code=0
  push_with_retry || code=$?
  if [ "${code}" -eq 0 ]; then
    echo "Published to ${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}@${ICM_GITHUB_BRANCH}:"
    g log --format='  %h %s' "${PUSHED_FROM}..HEAD"
    g diff --name-status --no-renames "${PUSHED_FROM}" HEAD | sed 's/^/  /'
    after_push
  else
    report_unpushed "${code}"
  fi
  exit_with_status
}

# Prints EXISTS <path> for each record with the same slug on the remote branch
# in bugs/open, features/open, or features/drafts, or NEW if there is none.
check_slug() {
  local slug found
  if [ -z "${1:-}" ] || [ ! -d "${ICM_GITHUB_CHECKOUT_DIR}/.git" ]; then
    echo "Usage: configure-git.sh check-slug <path>, after the sync in this turn." >&2
    exit 2
  fi
  slug="$(basename "$1" .md)"
  g remote set-url origin "${REPOSITORY_REMOTE}"
  if ! remote_git -C "${ICM_GITHUB_CHECKOUT_DIR}" fetch --quiet origin "${ICM_GITHUB_BRANCH}"; then
    echo "FAILED: could not fetch ${ICM_GITHUB_OWNER}/${ICM_GITHUB_REPOSITORY}@${ICM_GITHUB_BRANCH}; git's error is printed above." >&2
    exit 1
  fi
  found="$(g ls-tree --full-tree --name-only "refs/remotes/origin/${ICM_GITHUB_BRANCH}" -- \
    "bugs/open/${slug}.md" "features/open/${slug}.md" "features/drafts/${slug}.md")"
  if [ -n "${found}" ]; then
    sed 's/^/EXISTS /' <<<"${found}"
  else
    echo NEW
  fi
}

lock_checkout
case "${1:-sync}" in
  sync) sync_checkout ;;
  publish) shift; publish_checkout "$@" ;;
  check-slug) check_slug "${2:-}" ;;
  *) echo "Unknown command: $1 (expected sync, publish, or check-slug)" >&2; exit 2 ;;
esac
