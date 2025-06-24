#!/usr/bin/env bash
#
# backup_gpg.sh
#
# Export your GPG secret key, public key, and revocation certs
# into a single directory for safe offline storage.
#
# Usage:
#   ./backup_gpg.sh KEYID [BACKUP_DIR]
#
#   KEYID       = your long GPG key ID (e.g. 435C3C15ECE6BD33)
#   BACKUP_DIR  = directory to write backups into (default: $HOME/gpg-backup)
#

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 KEYID [BACKUP_DIR]" >&2
  exit 1
fi

KEYID="$1"
BACKUP_DIR="${2:-$HOME/gpg-backup}"

echo "Backing up GPG key ${KEYID} → ${BACKUP_DIR}/"

mkdir -p "$BACKUP_DIR/revocation-certs"

# 1) Export secret key (including subkeys)
gpg --export-secret-keys --armor "$KEYID" \
    > "$BACKUP_DIR/secret-key.asc"

# 2) Export public key
gpg --export --armor "$KEYID" \
    > "$BACKUP_DIR/public-key.asc"

# 3) Copy any revocation certificates
cp ~/.gnupg/openpgp-revocs.d/*.rev \
   "$BACKUP_DIR/revocation-certs/" 2>/dev/null || true

echo
echo "Backup files in ${BACKUP_DIR}:"
ls -1 "$BACKUP_DIR"
echo "Done."
