#!/bin/sh
# Zig Version Control
# Tool simple for manage, download, remove and use
#
# Struktur:
#   Root-Folder : /opt/zvc
#   Sub-Folder  : /opt/zvc/zig-<arch>-<version>
#
# Use:
#   [+] sudo zvc -i, --install <version> [arch]
#   [-] zvc -l, --list [download|system]
#   [+] sudo zvc -r, --remove <version> [arch]
#   [-] zvc -u, --use <version> [arch] -- [Args Zig]
#   [+] sudo zvc -s, --set <version> [arch]
#   [-] zvc -h, --help
#   [-] zvc -v, --version

set -e

VERSION="1.0"
ZVC_ROOT="/opt/zvc"
ZIG_URL="https://ziglang.org/download"
ZIG_BUILDS="https://ziglang.org/builds"
ZIG_INDEX="${ZIG_URL}/index.json"

# Function utils
err()  { printf 'ZVC Error: %b\n' "$*" >&2; exit 1; }
info() { printf '[ZVC] %b\n' "$*"; }

root() {
  [ "$(id -u)" -eq 0 ] || err "This command requires root"
}

dir_root() {
  [ -d "$ZVC_ROOT" ] || mkdir -p "${ZVC_ROOT}"
}

# Fetch curl or wget Function
fetch() {
  url="$1"
  out="$2"
  if command -v curl >/dev/null 2>/dev/null; then
    curl -fL --progress-bar -o "$out" "$url"
  elif command -v wget >/dev/null 2>/dev/null; then
    wget -q --show-progress -O "$out" "$url"
  else
    err "curl or wget not found"
  fi
}

fetch_stdout() {
  url="$1"
  if command -v curl >/dev/null 2>/dev/null; then
    curl -fsSL "$url"
  elif command -v wget >/dev/null 2>/dev/null; then
    wget -qO- "$url"
  else
    err "curl or wget not found"
  fi
}

# Detech Funstion
detect_arch() {
  case "$(uname -m)" in
    x86_64)          echo "x86_64"      ;;
    aarch64)         echo "aarch64"     ;;
    armv7l|armv6l)   echo "arm"         ;;
    riscv64)         echo "riscv64"     ;;
    i386|i686)       echo "x86"         ;;
    loongarch64)     echo "loongarch64" ;;
    s390x)           echo "s390x"       ;;
    *) err "Not found architecture : $(uname -m)" ;;
  esac
}

detect_os() {
  case "$(uname -s)" in
    Linux)  echo "linux" ;;
    Darwin) echo "macos" ;;
    *) err "Unknown OS: $(uname -s)" ;;
  esac
}

# Validate Function
validate_version() {
  ver="$1"
  variant="${2:-}"
  if [ -n "$variant" ]; then
    info "Validating version ${ver} (${variant}) ....."
  else
    info "Validating version ${ver} ....."
  fi

  info "Validating version ${ver} ....."
  available="$(fetch_stdout "$ZIG_INDEX" \
    | grep -o '"master"\|"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"' \
    | tr -d '"' || true)"
  echo "$available" | grep -qx "$ver" || \
    err "Version '${ver}' not found. Run: zvc -l download"
}

# get full version string for master(eg: 0.17.0-dev.947+36-69a2a7)
get_master_version() {
  fetch_stdout "$ZIG_INDEX" \
    | grep -o '"version" *: *"[^"]*"' \
    | head -1 \
    | grep -o '"[^"]*"$' \
    | tr -d '"'
}

arch_os_map() {
  arch="$1"
  case "$arch" in
    x86_64)      echo "Linux / MacOS / Windows / FreeBSD / NetBSD / OpenBSD" ;;
    aarch64)     echo "Linux / MacOS / Windows / FreeBSD / NetBSD / OpenBSD" ;;
    x86)         echo "Linux / Windows / NetBSD "                            ;;
    arm)         echo "Linux / FreeBSD / NetBSD / OpenBSD"                   ;;
    riscv64)     echo "Linux / FreeBSD / OpenBSD"                            ;;
    powerpc64le) echo "Linux / FreeBSD"                                      ;;
    loongarch64) echo "Linux"                                                ;;
    s390x)       echo "Linux"                                                ;;
    source)      echo "All (Zig Source Code)"                                ;;
    bootstrap)   echo "All (Zig Bootstrap)"                                  ;;
    *) echo "-" ;;
  esac
}

print_divider() {
  printf '  %s\n' "$(printf '─%.0s' $(seq 1 70))"
}

# List Function
list_download() {
  info "Fetching the version list from ziglang.org ....."

  # take only the top-level version keys: "master" and "x.x.x"
  version="$(fetch_stdout "$ZIG_INDEX" \
    | grep -o '"master"\|"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"' \
    | tr -d '"' \
    | sort -rV)"

  [ -n "$version" ] || err "Failed to fetch  version list"

  printf '  %-12s %-14s %s\n' "VERSION" "VARIANT" "PLATFORM"
  print_divider

  for ver in $version; do
    for  variant in source bootstrap x86_64 aarch64 x86 arm riscv64 powerpc64le loongarch64 s390x; do
      os_list="$(arch_os_map "$variant")"
      printf '  %-12s %-14s %s\n' "$ver" "$variant" "$os_list"
    done
    print_divider
  done
}

list_system() {
  dir_root
  info "Zig installed in ${ZVC_ROOT}:\n"
  found=0
  printf '  %-40s %s\n' "NAME" "PATH"
  printf '  %s\n' "$(printf '─%.0s' $(seq 1 60))"
  for d in "$ZVC_ROOT"/zig-*; do
     [ -d "$d" ] || continue
     printf '  %-40s %s\n' "$(basename "$d")" "$d"
     found=1
  done
  [ "$found" -eq 1 ] || printf '  (none)\n'
}

cmd_list() {
  arg="${2:-system}"
  if [ "$arg" = "download" ]; then
    list_download
  elif [ "$arg" = "system" ]; then
    list_system
  else
    err "Invalid argument: $arg (use: download | system)"
  fi
}

# Install Function
_do_install() {
  name="$1"
  url="$2"
  tarball="$3"

  dest="${ZVC_ROOT}/${name}"

  if [ -d "$dest" ]; then
    info "${name} is already installed at ${dest}"
    return 0
  fi

  info "Downloading ${url} ....."
  tmp=$(mktemp -d)
  fetch "$url" "${tmp}/${tarball}" || {
    rm -rf "$tmp"
    err "Download failed. check your internet or version/arch: zvc -l download"
  }

  info "Extracting to ${dest} ....."
  mkdir -p "$dest"
  tar -xJf "${tmp}/${tarball}" -C "$dest" --strip-components=1
  rm -rf "$tmp"

  info "Successfully installed ${name} to ${dest}"
}

cmd_instal() {
  ver="$2"
  arch="${3:-$(detect_arch)}"

  [ -n "$ver" ] || err "Version is required. Example: zvc -i 0.13.0"

  root
  dir_root
  validate_version "$ver" "$arch"

  info "Architecture : ${arch}"

  # Resolve full-version for master
  if [ "$ver" = "master" ]; then
    fullver="$(get_master_version)"
    [ -n "$fullver" ] || err "Failed to get master version"
    base_url="$ZIG_BUILDS"
  else
    fullver="$ver"
    base_url="${ZIG_URL}/${ver}"
  fi

  case "$arch" in
    source|src)
      tarball="zig-${fullver}.tar.xz"
      name="zig-source-${fullver}"
      _do_install "$name" "${base_url}/${tarball}" "${tarball}"
      ;;
    bootstrap)
      tarball="zig-bootstrap-${fullver}.tar.xz"
      name="zig-bootstrap-${fullver}"
      _do_install "$name" "${base_url}/${tarball}" "${tarball}"
      ;;
    *)
      os="$(detect_os)"
      tarball="zig-${arch}-${os}-${fullver}.tar.xz"
      name="zig-${arch}-${os}-${fullver}"
      _do_install "$name" "${base_url}/${tarball}" "$tarball"
      ;;
  esac
}

# Remove Function
cmd_remove() {
  ver="$2"
  arch="${3:-$(detect_arch)}"
  os="$(detect_os)"

  [ -n "$ver" ] || err "Version is required. Example: zvc -r 0.13.0"

  root

  case "$arch" in
    source|src) name="zig-source-${ver}"       ;;
    bootstrap)  name="zig-bootstrap-${ver}"    ;;
    *)          name="zig-${arch}-${os}-${ver}";;
  esac
  
  dest="$ZVC_ROOT/${name}"
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
  os="$(detect_os)"

  [ -n "$ver" ] || err "Version is required. Example: zvc -u 0.13.0"

  shift 2

  arch=""
  if [ -n "$1" ] && [ "$1" != "--" ]; then
    arch="$1"
    shift 1
  else
    arch="$(detect_arch)"
  fi

  [ "${1:-}" = "--" ] && shift 1
 
  name="zig-${arch}-${os}-${ver}"
  dest="$ZVC_ROOT/${name}"

  [ -d "$dest" ] || err "${name} not found. Install first: sudo zvc -i ${ver}"

  export PATH="${dest}:$PATH"
  info "Using: ${name}"
  echo ""

  if [ "$#" -gt 0 ]; then
    exec "${dest}/zig" "$@"
  fi
}

# Set Default(Persistent) Function
cmd_set(){
  ver="$2"
  arch="${3:-$(detect_arch)}"
  os="$(detect_os)"

  [ -n "$ver" ] || err "Version is required. Example: zvc -s 0.13.0"

  root

  name="zig-${arch}-${os}-${ver}"
  dest="$ZVC_ROOT/${name}"

  [ -f "${dest}/zig" ] || err "${name} not found. Install first: sudo zvc -i ${ver}"

  ln -sf "${dest}/zig" /usr/local/bin/zig
  info "Default Zig Now -> ${name}"
  info "Check: zig version"
}

version() {
  info "Version : ${VERSION}"
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
    -s|--set)     cmd_set         "$@" ;;
    -h|--help)    usage                ;;
    -v|--version) version              ;;
    *)
      err "Unknown Arguments"
      ;;
  esac
}

main "$@"
