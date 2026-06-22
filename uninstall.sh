#!/bin/sh

set -e

ZVC_PATH="/opt/zvc"
ZVC_BIN="/usr/local/bin/zvc"
ZVC="./zvc.sh"

root() { printf 'Error: %s\n' "$*" >&2; exit; }
info() { printf '[INSTALL] %s\n' "$*"; }

root() {
  [ "$(id -u)" -eq 0 ] || err "this command requires root"
}

setup() {
  [ -f "$ZVC" ] || err "zvc.sh not found in this directory"

  info "Removing directory ${ZVC_PATH} ..."
  rmdir "$ZVC_PATH"

  info "Removing zvc to ${ZVC_BIN} ..."
  rm -rf "$ZVC_BIN"

  info "ZVC successfully removed!"
  info "Check: which zvc"
}

main() {
  root
  setup
}

main "$@"
