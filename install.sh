#!/bin/sh

set -e

# Constants
ZVC_PATH="/opt/zvc"
ZVC_BIN="/usr/local/bin/zvc"
ZVC="./zvc.sh"

# Error function
err() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# Info function
info() { printf '[INSTALL] %s\n' "$*"; }

# Check root privileges
check_root() {
    [ "$(id -u)" -eq 0 ] || err "this command requires root privileges"
}

# Install required dependencies
install_deps() {
    missing=""   
    for cmd in curl wget tar; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done
    
    if [ -n "$missing" ]; then
        info "Missing dependencies:$missing, attempting to install..."
        
        if command -v xbps-install >/dev/null 2>&1; then
            xbps-install -y curl wget tar
        elif command -v pacman >/dev/null 2>&1; then
            pacman -S --noconfirm curl wget tar
        elif command -v apt >/dev/null 2>&1; then
            apt update && apt install -y curl wget tar
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y curl wget tar
        elif command -v zypper >/dev/null 2>&1; then
            zypper install -y curl wget tar
        else
            err "No package manager found. Please install curl, wget, and tar manually"
        fi
        
        info "Dependencies installed successfully"
    else
        info "All dependencies (curl, wget, tar) are already available"
    fi
}

# Setup ZVC installation
setup_zvc() {
    [ -f "$ZVC" ] || err "zvc.sh not found in current directory"
    
    info "Creating directory $ZVC_PATH ..."
    mkdir -p "$ZVC_PATH"
    
    info "Installing zvc to $ZVC_BIN ..."
    cp "$ZVC" "$ZVC_BIN"
    chmod +x "$ZVC_BIN"
    
    info "ZVC successfully installed!"
    info "Run 'zvc -h' to check available commands"
}

# Main function
main() {
    check_root
    install_deps
    setup_zvc
}

main "$@"
