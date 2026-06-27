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
#   [-] sudo zvc -d, --disable 
#   [-] zvc -h, --help
#   [-] zvc -v, --version

set -e

VERSION="1.0"
ZVC_ROOT="/opt/zvc"
ZIG_URL="https://ziglang.org/download"
ZIG_BUILDS="https://ziglang.org/builds"
ZIG_INDEX="${ZIG_URL}/index.json"

# Function utils
err()  { printf 'ZVC Error: %s\n' "$*" >&2; exit 1; }
info() { printf '[ZVC] %s\n' "$*"; }

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

  available="$(fetch_stdout "$ZIG_INDEX" \
    | grep -o '"master"\|"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"' \
    | tr -d '"' || true)"
  echo "$available" | grep -qx "$ver" || \
    err "Version '${ver}' not found. Run: zvc -l download"
}

#-- Function For variant Master
# get full version string for master(eg: 0.17.0-dev.947+36-69a2a7)
get_master_version() {
  fetch_stdout "$ZIG_INDEX" \
    | grep -o '"version" *: *"[^"]*"' \
    | head -1 \
    | grep -o '"[^"]*"$' \
    | tr -d '"'
}

# search folder master
find_master_dir() {
  pattern="$1"
  found="$(ls -d ${ZVC_ROOT}/${pattern} 2>/dev/null | tail -1)"
  echo "$found"
}
#---

arch_os_map() {
  arch="$1"
  case "$arch" in
    x86_64)      echo "Linux / MacOS / Windows / FreeBSD / NetBSD / OpenBSD" ;;
    aarch64)     echo "Linux / MacOS / Windows / FreeBSD / NetBSD / OpenBSD" ;;
    x86)         echo "Linux / Windows / NetBSD"                             ;;
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
  info "Zig installed in ${ZVC_ROOT}:"
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

  [ -n "$ver" ] || err "Version is required. Example: zvc -i 0.16.0"

  root
  dir_root
  validate_version "$ver" "$arch"

  info "Variant : ${arch}"

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
_do_remove() {
  name="$1"
  dest="${ZVC_ROOT}/${name}"

  [ -d "$dest" ] || { info "Skip ${name} (not found)"; return 0; }

  rm -rf "$dest"
  info "Removed: ${name}"

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

cmd_remove() {
  ver="$2"
  arg3="${3:-}"
  os="$(detect_os)"

  [ -n "$ver" ] || err "Version is required. Example: zvc -r 0.16.0 | all"

  root

  # Case 1 : remove All
  if [ "$ver" = "all" ]; then
    found=0
    for d in "$ZVC_ROOT"/zig-*; do
      [ -d "$d" ] || continue
      found=1
      break
    done
    [ "$found" -eq 1 ] || err "No Zig installed in ${ZVC_ROOT}"

    info "Removing all Zig from ${ZVC_ROOT} ....."
    for d in "$ZVC_ROOT"/zig-*; do
      [ -d "$d" ] || continue
      _do_remove "$(basename "$d")"
    done
    info "Done. All Zig Removed."
    return 0
  fi

  # Case 2 : remove <version> - Remove all of a specific version
  if [ -z "$arg3" ]; then
    case "$ver" in
      master)
        glob="${ZVC_ROOT}/zig-*dev*"
        label="Master (dev builds)"
        ;;
      source|src)
        glob="${ZVC_ROOT}/zig-source-*"
        label="Source"
        ;;
      bootstrap)
        glob="${ZVC_ROOT}/zig-bootstrap-*"
        label="Bootstrap"
        ;;
      *)
        glob="${ZVC_ROOT}/zig-*${ver}*"
        label="$ver"
        ;;
    esac

    found=0
    for d in $glob; do
      [ -d "$d" ] || continue
      found=1
      break
    done
    [ "$found" -eq 1 ] || err "No Zig with version '${ver}' found in ${ZVC_ROOT}"

    info "Removing all ${label} variants ....."
    for d in $glob; do
      [ -d "$d" ] || continue
      _do_remove "$(basename "$d")"
    done
    info "Done. All ${label} variant removed."
    return 0
  fi
  
  # Case 3 : remove <version> <arch>
  arch="$arg3"
  case "$arch" in
    source|src) name="zig-source-${ver}"       ;;
    bootstrap)  name="zig-bootstrap-${ver}"    ;;
    *)          name="zig-${arch}-${os}-${ver}";;
  esac
  
  info "Successfully deleted ${name} ....."
  _do_remove "$name"
  info "Done."
}

# Use Function, (for now, just this session)
cmd_use() {
  ver="$2"
  os="$(detect_os)"

  [ -n "$ver" ] || err "Version is required. Example: zvc -u 0.16.0"

  shift 2

  arch=""
  if [ -n "${1:-}" ] && [ "$1" != "--" ]; then
    arch="$1"
    shift 1
  else
    arch="$(detect_arch)"
  fi
  [ "${1:-}" = "--" ] && shift 1

  # Resolve dest
  if [ "$ver" = "master" ]; then
    # Fix: Variant Master Folder
    case "$arch" in
      source|src)
        dest="$(find_master_dir "zig-source-*dev*")"
        [ -n "$dest" ] || err "No master source build found. Install: sudo zvc -i master source"
        ;;
      bootstrap)
        dest="$(find_master_dir "zig-bootstrap-*dev*")"
        [ -n "$dest" ] || err "No master bootstrap build found. Install: sudo zvc -i master bootstrap"
        ;;
      *)
        dest="$(find_master_dir "zig-${arch}-${os}-*dev*")"
        [ -n "$dest" ] || err "No master build for ${arch}-${os}. Install: sudo zvc -i master ${arch}"
        ;;
    esac
    name="$(basename "$dest")"
  else
    case "$arch" in
      source|src) name="zig-source-${ver}"        ;;
      bootstrap)  name="zig-bootstrap-${ver}"     ;;
      *)          name="zig-${arch}-${os}-${ver}" ;;
    esac
    dest="${ZVC_ROOT}/${name}"
    [ -d "$dest" ] || err "${name} not found. Install: sudo zvc -i ${ver}"
  fi

  # Fix: Output zig variant source/bootstrap
  case "$arch" in
    source|src|bootstrap)
      if [ "$#" -gt 0 ]; then
        err "${name} has no zig binary. source/bootstrap are for building Zig itself."
      fi
      export PATH="${dest}:$PATH"
      info "Using: ${name} (no zig binary, PATH set to ${dest})"
      return 0
      ;;
  esac

  native="$(detect_arch)"
  if [ "$arch" != "$native" ]; then
    err "Cannot run ${arch} binary on ${native} machine"
  fi
    
  export PATH="${dest}:$PATH"
  info "Using: ${name}"

  if [ "$#" -gt 0 ]; then
    exec "${dest}/zig" "$@"
  fi
}

# Set Default(Persistent) Function
cmd_set(){
  ver="$2"
  arch="${3:-$(detect_arch)}"
  os="$(detect_os)"

  [ -n "$ver" ] || err "Version is required. Example: zvc -s 0.16.0"

  root

  # Fix: Source/Bootstrap variant cannot set as zig default
  case "$arch" in
    source|src|bootstrap)
      err "Cannot set source/bootstrap as default zig (no zig binary)"
      ;;
  esac

  if [ "$ver" = "master" ]; then
    dest="$(find_master_dir "zig-${arch}-${os}-*dev*")"
    [ -n "$dest" ] || err "No master build for ${arch}-${os}. Install: sudo zvc -i master"
    name="$(basename "$dest")"
  else
    name="zig-${arch}-${os}-${ver}"
    dest="$ZVC_ROOT/${name}"
    [ -f "${dest}/zig" ] || err "${name} not found. Install first: sudo zvc -i ${ver} ${arch}"
  fi
  
  ln -sf "${dest}/zig" /usr/local/bin/zig
  info "Default Zig Now -> ${name}"
  info "Check: zig version"
}

cmd_disable() {
  root

  if [ -L /usr/local/bin/zig ]; then
    current="$(readlink /usr/local/bin/zig)"
    rm -f /usr/local/bin/zig
    info "Default Zig removed (was: ${current})"
    info "Run 'sudo zvc -s <version/variant>' to set a new default"
  else
    info "No default Zig is currently set"
  fi
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
    Ex : sudo zvc -i 0.16.0
         sudo zvc -i 0.16.0 aarch64
         sudo zvc -i 0.16.0 source
         sudo zvc -i 0.16.0 bootstrap
         sudo zvc -i master

  zvc -l, --list [download|system]
    To display the Zig
      download  : displays a list of zig available downloads
      system    : displays a list of zig available in the system (default)
      Ex: zvc -l download
          zvc -l system

  sudo zvc -r, --remove all
    Remove ALL installed Zig.
    Ex: sudo zvc -r all

  sudo zvc -r, --remove <version>
    Remove all variants of a specific version.
    Ex: sudo zvc -r 0.16.0

  sudo zvc -r, --remove <version> <arch>
    Remove a specific version + arch variant.
    Ex: sudo zvc -r 0.16.0 x86_64
        sudo zvc -r 0.16.0 source
        sudo zvc -r 0.16.0 bootstrap

  zvc -u, --use <version> [arch] [-- Args Zig]
    Use a specific version of Zig (temporarily, this session only).
    ZVC Arch is automatically detected if it is not filled.
    Ex: zvc -u 0.16.0
        zvc -u 0.16.0 x86_64 -- build
        zvc -u master -- version

  zvc -s, --set <version> [arch]
    Set Zig as system default(/usr/local/bin/zig)
    Ex : sudo zvc -s 0.16.0
         sudo zvc -s master

  zvc -d, --disable <version> [arch]
    Remove the current default Zig symlink
    Ex : sudo zvc -d 
         sudo zvc -disable

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
    -d|--disable) cmd_disable     "$@" ;;
    -h|--help)    usage                ;;
    -v|--version) version              ;;
    *)
      err "Unknown Arguments"
      ;;
  esac
}

main "$@"
