#!/usr/bin/env bash
set -euo pipefail

# --- Defaults ---
DRY_RUN=false
VERBOSE=false
CONFIG_FILE=""
JAILROOT=""
BINARIES=()
MOUNT_PROC=false
MOUNT_SYS=false
MOUNT_DEV=false

log() { echo "[*] $*"; }
logv() { $VERBOSE && echo "[v] $*"; }
run() { $DRY_RUN && echo "(dry-run) $*" || eval "$*"; }

die() { echo "[!] $*" >&2; exit 1; }

check_dependencies() {
  for cmd in chroot ldd cp bash mknod mkdir realpath; do
    command -v "$cmd" >/dev/null || die "Missing required command: $cmd"
  done
}

parse_config() {
  [[ -f "$CONFIG_FILE" ]] || die "Config file '$CONFIG_FILE' not found"
  source "$CONFIG_FILE"
  [[ -n "$JAIL_ROOT" && ${#BINARIES[@]} -gt 0 ]] || die "Config must define JAIL_ROOT and BINARIES[]"
  JAILROOT="$(realpath "$JAIL_ROOT")"
}

copy_binary_and_deps() {
  local bin="$1"
  [[ -x "$bin" ]] || bin="$(command -v "$bin" 2>/dev/null || true)"
  [[ -x "$bin" ]] || die "Cannot find executable: $1"
  local dest="$JAILROOT$bin"
  run mkdir -p "$(dirname "$dest")"
  run cp "$bin" "$dest"
  ldd "$bin" | awk '/=>/ {print $3} /^\/lib/ {print $1}' | while read lib; do
    [[ -e "$lib" ]] || continue
    local dlib="$JAILROOT$lib"
    run mkdir -p "$(dirname "$dlib")"
    run cp "$lib" "$dlib"
  done
}

setup_etc() {
  run mkdir -p "$JAILROOT/etc"
  echo "root:x:0:0:root:/root:/bin/bash" | run tee "$JAILROOT/etc/passwd" >/dev/null
  echo "root:x:0:" | run tee "$JAILROOT/etc/group" >/dev/null
}

setup_dev() {
  log "Creating minimal /dev"
  run mkdir -p "$JAILROOT/dev"
  run mknod -m 666 "$JAILROOT/dev/null" c 1 3
  run mknod -m 666 "$JAILROOT/dev/zero" c 1 5
  run mknod -m 666 "$JAILROOT/dev/tty" c 5 0
  run mknod -m 666 "$JAILROOT/dev/random" c 1 8
  run mknod -m 666 "$JAILROOT/dev/urandom" c 1 9
}

mount_fs() {
  $MOUNT_PROC && run mount --bind /proc "$JAILROOT/proc"
  $MOUNT_SYS  && run mount --bind /sys  "$JAILROOT/sys"
  $MOUNT_DEV  && run mount --bind /dev  "$JAILROOT/dev"
}

usage() {
  echo "Usage: $0 -c jail.conf [--dry-run] [--verbose]"
  exit 1
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config) CONFIG_FILE="$2"; shift ;;
    --dry-run) DRY_RUN=true ;;
    --verbose) VERBOSE=true ;;
    *) usage ;;
  esac
  shift
done

[[ -n "$CONFIG_FILE" ]] || usage

check_dependencies
parse_config

log "Creating jail at: $JAILROOT"
run rm -rf "$JAILROOT"
run mkdir -p "$JAILROOT"/{bin,lib,lib64,usr/bin,etc,tmp}
run chmod 1777 "$JAILROOT/tmp"

for bin in "${BINARIES[@]}"; do
  log "Copying $bin"
  copy_binary_and_deps "$bin"
done

setup_etc
setup_dev
mount_fs

log "Jail created at: $JAILROOT"
log "To enter: sudo chroot $JAILROOT /bin/bash"
