#!/bin/sh
# Zig Version Control
# Tool simple for manage, download, remove and use
#
# Struktur:
#   Root-Folder : /opt/zvc
#   Sub-Folder  : /opt/zvc/zig-<arch>-<version>
#
# Use:
#   sudo zvc -i, --install <version> [arch]
#   zvc -l, --list [download|system]
#   sudo zvc -r, --remove <version> [arch]
#   zvc -u, --use <version> [arch] -- [Args Zig]
#   sudo zvc -s, --set <version> [arch]
#   zvc -h, --help
#   zvc -v, --version

set -e

VERSION="1.0"
ZIG_ROOT="/opt/zvc"
ZIG_URL="https://ziglang.org/download"
ZIG_INDEX="${ZIG_URL}/index.json"

# Function utils
err() { printf 'ZVC: %s\n' "$*" >&2; exit 1; }
info() { printf '[ZVC] %s\n' "$*"; }

root() {
  [ "$(id -u)" -eq 0 ] || err "This command requires root"
}

dir_root() {
  [ -d "$ZIG_ROOT" ] || mkdir -p "${ZIG_ROOT}"
}

# Fetch curl or wget Function
fetch() {
  url="$1"
  out="$2"
  if command -v curl >/dev/null 2&>1; then
    curl -fL --progress-bar -o "$out" "$url"
  elif command -v wget >/dev/null 2&>1; then
    wget -q --show-progress -o "$out" "$url"
  else
    err "curl or wget not found"
  fi
}

fetch_stdout() {
  url="$1"
  if command -v curl >/dev/null 2&>1; then
    curl -fsSL "$url"
  elif command -v wget >/dev/null 2&>1; then
    wget -qO- "$url"
  else
    err "curl or wget not found"
}

# Detech Funstion
detect_arch() {
  case "$(uname -m)" in
    x86_64)
      echo "x86_64"
      ;;
    aarch64)
      echo "aarch64"
      ;;
    armv7l|armv6l)
      echo "arm"
      ;;
    riscv64)
      echo "riscv64"
      ;;
    i386|i686)
      echo "x86"
      ;;
    loongarch64)
      echo "loongarch64"
      ;;
    s390x)
      echo "s390x"
      ;;
    *)
      err "Not found architecture : ${uname -m}"
      ;;
  esac
}

detect_os() {
  case "(uname -s)" in
    Linux)  echo "linux" ;;
    Darwin) echo "macos" ;;
    *) err "Unknow OS: $(uname -s)" ;;
  esac
}

# List Function
list_download() {
  info "Fetching the version list from ziglang.org"
  fetch_stdout "$ZIG_INDEX" | grep -o '"[^"]*":' | grep -v 'tarball\shasum\|size\|docs\|stdDocs\|src\|bootstrap\|date\|version' | tr -d '":' | sort -u
}

list_system() {
  dir_root
  info "List of Zigs installed in ${ZIG_ROOT}:"
  found=0
  for d in "$ZIG_ROOT"/zig-*; do
    [ -d "$d" ] || continue
    printf '  %s\n' "$(basename "$d")"
    found=1
  done
  [ "$found" -eq 1 ] || info "No Zig installed yet"
}

cmd_list() {
  arg="${2:-system}"
  if [ "$2" == "download" ]; then
    list_download
  elif [ "$2" == "system" ]; then
    list_system
  else
    err "Invalid argument: $arg (use: download | system)"
}

# Install Function
cmd_instal() {
  ver="$2"
  arch="${3:-$(detect_arch)}"
  os="$(detect_os)"

  [ -n "$ver" ] || err "Version is required. Example: zvc -i 0.13.0"

  root
  dir_root

  name="zig-${os}-${arch}-${ver}"
  dest="$ZIG_ROOT/${name}"

  if [ -d "$dest" ]; then
    info "${name} is already on ${dest}"
    return 0
  fi

  tarball="zig-${os}-${arch}-${ver}.tar.xz"
  url="${ZIG_URL}/${ver}/${tarball}"

  info "Downloading ${url}.."
  tmp="$(mktemp -d)"
  fetch "$url" "${tmp}/${tarball}" || {
    rm -rf "$tmp"
    err "Download failed. Check version/arch: zvc -l download"
  }

  info "Extracting to ${dest}"
  mkdir -p "${dest}"
  tar -xJf "${tmp}/${tarball}" -C "$dest" --strip-components=1

  rm -rf "$tmp"

  info "Successfully installed ${name} to ${dest}"
}

# Remove Function
cmd_remove() {
  ver="$2"
  arch="${3:-$(detect_arch)}"
  os="$(detect_os)"

  [ -n "$ver" ] || err "Version is required. Example: zvc -i 0.13.0"

  root

  name="zig-${os}-${arch}-${ver}"
  dest="$ZIG_ROOT/${name}"

  [ -d "$dest" ] || err "${name} not found in ${dest}"

  rm -rf "$dest"
  info "Successfully deleted ${name}"

  # Check if the one deleted is the active default
  if [ -L /usr/local/bin/zig ]; then
    link="$(readlink /usr/local/bin/zig)"
    case "$link" in
      *"$name"*)
        rm -rf /usr/local/bin/zig
        info "Default symlink removed because it points to ${name}"
        ;;
    esac
  fi
}

# Use Function, (for now, just this session)
cmd_use() {
  ver="$2"
  arch="${3:-$(detect_arch)}"
  os="$(detect_os)"

  [ -n "$ver" ] || err "Version is required. Example: zvc -i 0.13.0"
 
  name="zig-${os}-${arch}-${ver}"
  dest="$ZIG_ROOT/${name}"

  [ -d "$dest" ] || info "${name} not found. Install first: sudo zvc -i ${ver}"

  # Shift all arguments after -- to zig
  shift 3
  export PATH="${dest}:$PATH"
  info "Using: ${name}"

  if [ "$#" -gt 0 ]; then
    exec "${dest/zig}" "$@"
  fi
}

# Set Default(Persistent) Function
cmd_set(){
  ver="$2"
  arch="${3:-$(detect_arch)}"
  os="$(detect_os)"

  [ -n "$ver" ] || err "Version is required. Example: zvc -i 0.13.0"

  root

  name="zig-${os}-${arch}-${ver}"
  dest="$ZIG_ROOT/${name}"

  [ -f "$dest" ] || err "${name} not found. Install first: sudo zvc -i ${ver}"

  ln -sf "$dest" /usr/local/bin/zig
  info "Default Zig Now -> ${name}"
  info "Check: zig version"
}

version() {
  info "v${VERSION}"
}

usage() {
  cat << EOF
ZVC - Zig Version Control, Simple Tools

Use:
  zvc -i, --install <version> [arch]
    To install Zig, ZVC Arch is automatically detected if it is not filled.
    Ex : sudo zvc -i 0.13.0
         sudo zvc -i 0.13.0 aarch64

  zvc -l, --list [download|system]
    To display the Zig
      download  : displays a list of zig available downloads
      system    : displays a list of zig available in the system (default)
      Ex: zvc -l download
          zvc -l system

  zvc -r, --remove <version> [arch]
    To remove Zig, ZVC Arch is automatically detected if it is not filled.
    Ex: sudo zvc -r 0.13.0
        sudo zvc -r 0.13.0 aarch64

  zvc -u, --use <version> [arch] [-- Args Zig]
    Use a specific version of Zig (temporarily, this session only).
    ZVC Arch is automatically detected if it is not filled.
    Ex: zvc -u 0.13.0
        zvc -u 0.13.0 x86_64 -- build

  zvc -s, --set <version> [arch]
    To configure a specific Zig as default
    ZVC Arch is automatically detected if it is not filled.
    Ex : sudo zvc -s 0.13.0
         sudo zvc -s 0.13.0 aarch64

Flag:
  -h, --help      Displays Help
  -v, --version   Displays Version
EOF
}

main() {
  [ "$#" -gt 0 ] || { usage; exit 0; }
  cmd="$1";
  case "$cmd" in
    -i|--install) cmd_instal      "$@" ;;
    -l|--list)    cmd_list        "$@" ;;
    -r|--remove)  cmd_remove      "$@" ;;
    -u|--use)     cmd_use         "$@" ;;
    -s|--set)     cmd_set_default "$@" ;;
    -h|--help)    usage                ;;
    -v|--version) version              ;;
    *)
      err "Error Arguments"
      ;;
  esac
}

main "$@"
