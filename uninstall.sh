#!/bin/sh

# Script for Uninstall

set -e

ZVC_ROOT="/opt/zvc"
ZVC_BIN="/usr/local/bin/zvc"

root() { printf 'Error: %s\n' "$*" >&2; exit; }
info() { printf '[UNINSTALL] %s\n' "$*"; }

root() {
  [ "$(id -u)" -eq 0 ] || err "this command requires root"
}

clean() {
  if [ -d "$ZVC_ROOT" ]; then
    info "Removing ${ZVC_ROOT}..."
    rm -rf "${ZVC_ROOT}"
  else
    info  "${ZVC_ROOT} not found, skipping"
  fi

  if [ -f "$ZVC_BIN" ] || [ -L "$ZVC_BIN" ]; then
    info "Removing ${ZVC_BIN}..."
    rm -rf "${ZVC_BIN}"
  else
    info "${ZVC_BIN} not found, skipping"
  fi

  # Remove symlink zig default
  if [ -L /usr/local/bin/zig ]; then
    info "Removing default zig symlink..."
    rm -rf /usr/local/bin/zig
  fi

  info "ZVC successfully removed!"
  info "Run 'hash -r' or open a new terminal to clear command cache"
}

main() {
  root
  clean
}

main "$@"
