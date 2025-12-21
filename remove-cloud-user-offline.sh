#!/bin/bash
set -euo pipefail

# Offline removal of user "cloud-user" (UID 1000) from a root filesystem tree.
# Usage:
#   sudo ./remove-cloud-user-offline.sh /path/to/mounted/rootfs
#
# What it does:
# - Removes cloud-user lines from /etc/passwd, /etc/group, /etc/shadow, /etc/gshadow
# - Removes /home/cloud-user (and any other home path found in passwd entry)
# - Finds files owned by UID 1000 inside the rootfs and either deletes or reassigns them

ROOTFS="${1:-}"
USER_NAME="cloud-user"
USER_UID="1000"
DEFAULT_REASSIGN_USER="root"
DEFAULT_REASSIGN_GROUP="root"

if [[ -z "${ROOTFS}" ]]; then
  echo "ERROR: Missing ROOTFS path." >&2
  echo "Usage: $0 /path/to/mounted/rootfs" >&2
  exit 2
fi

if [[ ! -d "${ROOTFS}" ]]; then
  echo "ERROR: ROOTFS does not exist or is not a directory: ${ROOTFS}" >&2
  exit 2
fi

PASSWD="${ROOTFS}/etc/passwd"
GROUP="${ROOTFS}/etc/group"
SHADOW="${ROOTFS}/etc/shadow"
GSHADOW="${ROOTFS}/etc/gshadow"

for f in "${PASSWD}" "${GROUP}" "${SHADOW}"; do
  if [[ ! -f "${f}" ]]; then
    echo "ERROR: Required file not found: ${f}" >&2
    exit 2
  fi
done

# Optional behavior controls:
#   MODE=chown  -> reassign UID 1000 files to root:root (default)
#   MODE=delete -> delete UID 1000 files instead (dangerous)
MODE="${MODE:-chown}"

# If MODE=chown, you can override reassignment target:
REASSIGN_USER="${REASSIGN_USER:-${DEFAULT_REASSIGN_USER}}"
REASSIGN_GROUP="${REASSIGN_GROUP:-${DEFAULT_REASSIGN_GROUP}}"

# Safety: refuse to run if ROOTFS is "/"
if [[ "$(readlink -f "${ROOTFS}")" == "/" ]]; then
  echo "ERROR: Refusing to operate on /" >&2
  exit 2
fi

timestamp() { date +"%Y%m%d-%H%M%S"; }
backup_file() {
  local f="$1"
  cp -a "$f" "${f}.bak.$(timestamp)"
}

echo "ROOTFS: ${ROOTFS}"
echo "User:   ${USER_NAME} (UID ${USER_UID})"
echo "MODE:   ${MODE}"

# Extract home dir from passwd entry if present
HOME_DIR=""
if grep -qE "^${USER_NAME}:" "${PASSWD}"; then
  HOME_DIR="$(awk -F: -v u="${USER_NAME}" '$1==u{print $6}' "${PASSWD}" | head -n1 || true)"
fi

# Back up files before editing
backup_file "${PASSWD}"
backup_file "${GROUP}"
backup_file "${SHADOW}"
if [[ -f "${GSHADOW}" ]]; then
  backup_file "${GSHADOW}"
fi

echo "Removing account entries from /etc/*..."

# Remove user line from passwd
sed -i -e "/^${USER_NAME}:/d" "${PASSWD}"

# Remove user line from shadow
sed -i -e "/^${USER_NAME}:/d" "${SHADOW}"

# Remove group with same name (only that name, not UID-based)
sed -i -e "/^${USER_NAME}:/d" "${GROUP}"
if [[ -f "${GSHADOW}" ]]; then
  sed -i -e "/^${USER_NAME}:/d" "${GSHADOW}"
fi

# Also remove the username from any supplementary group member lists in /etc/group and /etc/gshadow
# (handles cases where cloud-user is listed as a member of other groups)
perl -0777 -i -pe '
  s/^(.*?:.*?:.*?:)([^\n]*)$/
    my ($p,$m)=($1,$2);
    my @x = grep { $_ ne "'"${USER_NAME}"'" && $_ ne "" } split(/,/, $m);
    $p . join(",", @x)
  /gme
' "${GROUP}"

if [[ -f "${GSHADOW}" ]]; then
  perl -0777 -i -pe '
    s/^(.*?:.*?:)([^\n]*)(:.*)$/
      my ($p,$m,$s)=($1,$2,$3);
      my @x = grep { $_ ne "'"${USER_NAME}"'" && $_ ne "" } split(/,/, $m);
      $p . join(",", @x) . $s
    /gme
  ' "${GSHADOW}"
fi

# Remove home directory
if [[ -z "${HOME_DIR}" ]]; then
  HOME_DIR="/home/${USER_NAME}"
fi

if [[ -e "${ROOTFS}${HOME_DIR}" ]]; then
  echo "Removing home directory: ${HOME_DIR}"
  rm -rf --one-file-system "${ROOTFS}${HOME_DIR}"
else
  echo "Home directory not found: ${HOME_DIR} (skipping)"
fi

echo "Scanning for files owned by UID ${USER_UID} (one filesystem only)..."
# -xdev keeps it inside the same filesystem as ROOTFS mount
# Exclude /proc, /sys, /dev if present in the tree (common in rootfs exports)
mapfile -t OWNED < <(
  find "${ROOTFS}" -xdev \
    \( -path "${ROOTFS}/proc" -o -path "${ROOTFS}/sys" -o -path "${ROOTFS}/dev" \) -prune -o \
    -uid "${USER_UID}" -print
)

echo "Found ${#OWNED[@]} path(s) owned by UID ${USER_UID}."

case "${MODE}" in
  chown)
    echo "Reassigning ownership to ${REASSIGN_USER}:${REASSIGN_GROUP}..."
    if ((${#OWNED[@]} > 0)); then
      # Use numeric chown to avoid relying on target rootfs NSS;
      # but we still pass names for clarity if host resolves them.
      # Prefer numeric 0:0 if you want guaranteed.
      chown -h "${REASSIGN_USER}:${REASSIGN_GROUP}" "${OWNED[@]}" 2>/dev/null || true
      # Ensure recursive ownership for directories/files (followed by -h above)
      chown -R "${REASSIGN_USER}:${REASSIGN_GROUP}" "${OWNED[@]}" 2>/dev/null || true
    fi
    ;;
  delete)
    echo "Deleting all UID ${USER_UID} files (high impact)..."
    if ((${#OWNED[@]} > 0)); then
      rm -rf --one-file-system "${OWNED[@]}"
    fi
    ;;
  *)
    echo "ERROR: Unknown MODE=${MODE}. Use MODE=chown or MODE=delete." >&2
    exit 2
    ;;
esac

echo "Validation checks..."
if grep -qE "^${USER_NAME}:" "${PASSWD}"; then
  echo "ERROR: ${USER_NAME} still present in passwd" >&2
  exit 1
fi
if grep -qE "^${USER_NAME}:" "${SHADOW}"; then
  echo "ERROR: ${USER_NAME} still present in shadow" >&2
  exit 1
fi

# Ensure no remaining UID 1000 ownership (best-effort)
REMAINING_COUNT="$(
  find "${ROOTFS}" -xdev \
    \( -path "${ROOTFS}/proc" -o -path "${ROOTFS}/sys" -o -path "${ROOTFS}/dev" \) -prune -o \
    -uid "${USER_UID}" -print | wc -l | tr -d ' '
)"
echo "Remaining UID ${USER_UID} owned paths: ${REMAINING_COUNT}"

echo "Done."
echo "Backups created:"
echo "  ${PASSWD}.bak.*"
echo "  ${GROUP}.bak.*"
echo "  ${SHADOW}.bak.*"
[[ -f "${GSHADOW}" ]] && echo "  ${GSHADOW}.bak.*"
