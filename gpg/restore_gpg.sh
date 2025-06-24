#!/usr/bin/env bash
#
# restore_gpg.sh
#
# Import a previously-backed-up GPG keypair and revocation certs
# from a directory into your keyring.
#
# Usage:
#   ./restore_gpg.sh BACKUP_DIR
#
#   BACKUP_DIR  = directory containing secret-key.asc,
#                 public-key.asc, and revocation-certs/*.rev
#

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 BACKUP_DIR" >&2
  exit 1
fi

BACKUP_DIR="$1"

echo "Restoring GPG keys from ${BACKUP_DIR}/"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "ERROR: '${BACKUP_DIR}' is not a directory." >&2
  exit 1
fi

# 1) Import public key
if [ -f "$BACKUP_DIR/public-key.asc" ]; then
  gpg --import "$BACKUP_DIR/public-key.asc"
else
  echo "Warning: public-key.asc not found." >&2
fi

# 2) Import secret key
if [ -f "$BACKUP_DIR/secret-key.asc" ]; then
  gpg --import "$BACKUP_DIR/secret-key.asc"
else
  echo "ERROR: secret-key.asc not found. Cannot restore secret key." >&2
  exit 1
fi

# 3) Import revocation certificates
if [ -d "$BACKUP_DIR/revocation-certs" ]; then
  for rev in "$BACKUP_DIR"/revocation-certs/*.rev; do
    [ -f "$rev" ] && gpg --import "$rev"
  done
else
  echo "Note: no revocation-certs/ directory found; skipping." >&2
fi

echo
echo "Current secret keys in keyring:"
gpg --list-secret-keys --keyid-format LONG
echo "Restore complete."
