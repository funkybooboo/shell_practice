#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
DRY_RUN=false
VERBOSE=false
ENTER_AFTER_BUILD=false
CONFIG_FILE=""
JAILROOT=""
BINARIES=()
declare -A COPIED_LIBS

log() { echo "[*] $*"; }
logv() { $VERBOSE && echo "[v] $*"; }
run() { $DRY_RUN && echo "(dry-run) $*" || eval "$*"; }
die() { echo "[!] $*" >&2; exit 1; }

check_dependencies() {
  for cmd in chroot ldd cp bash mkdir realpath; do
    command -v "$cmd" >/dev/null || die "Missing required command: $cmd"
  done
}

parse_config() {
  [[ -f "$CONFIG_FILE" ]] || die "Config file '$CONFIG_FILE' not found"
  source "$CONFIG_FILE"
  [[ -n "$JAIL_ROOT" && ${#BINARIES[@]} -gt 0 ]] || die "Config must define JAIL_ROOT and BINARIES[]"
  JAILROOT="$(realpath "$JAIL_ROOT")"
}

copy_library_once() {
  local lib="$1"
  [[ -e "$lib" ]] || return 0
  [[ -n "${COPIED_LIBS["$lib"]+1}" ]] && return 0
  COPIED_LIBS["$lib"]=1
  local dest="$JAILROOT$lib"
  run mkdir -p "$(dirname "$dest")"
  run cp "$lib" "$dest"
}

copy_binary_and_deps() {
  local bin="$1"
  [[ -x "$bin" ]] || bin="$(command -v "$bin" 2>/dev/null || true)"
  [[ -x "$bin" ]] || die "Cannot find executable: $1"
  local dest="$JAILROOT$bin"
  run mkdir -p "$(dirname "$dest")"
  run cp "$bin" "$dest"

  ldd "$bin" | awk '/=>/ { print $3 } /^\/lib/ { print $1 }' | grep -v '^$' | while read -r lib; do
    copy_library_once "$lib"
  done

  local loader
  loader="$(ldd "$bin" | awk '/ld-linux/ { print $1 }')"
  if [[ -n "$loader" && -e "$loader" ]]; then
    copy_library_once "$loader"
  else
    echo "[!] WARNING: dynamic loader not found for $bin"
  fi
}

enter_jail() {
  echo
  log "Launching into jail: $JAILROOT"
  exec sudo chroot "$JAILROOT" /bin/bash
}

usage() {
  echo "Usage: $0 -c jail.conf [--dry-run] [--verbose] [--enter]"
  exit 1
}

# --- CLI args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config) CONFIG_FILE="$2"; shift ;;
    --dry-run) DRY_RUN=true ;;
    --verbose) VERBOSE=true ;;
    --enter) ENTER_AFTER_BUILD=true ;;
    *) usage ;;
  esac
  shift
done

[[ -n "$CONFIG_FILE" ]] || usage

# --- Workflow ---
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

log "Jail created at: $JAILROOT"
log "To enter: sudo chroot $JAILROOT /bin/bash"

$ENTER_AFTER_BUILD && enter_jail
