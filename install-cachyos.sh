#!/bin/bash
# Standalone CachyOS installer for the ANV Vulkan H.265 shim.
#
#   sudo ./docker/install-cachyos.sh
#   sudo ./docker/install-cachyos.sh --version 26.2.6
#   sudo ./docker/install-cachyos.sh --so /path/libvulkan_intel.so
#   sudo ./docker/install-cachyos.sh --restore
#
# On a fresh CachyOS it installs the build dependencies, clones the matching
# Mesa tag, applies the matching patch from patches/, builds
# libvulkan_intel.so and installs it over /usr/lib/libvulkan_intel.so.
# No container is required; the container workflow is only a verification.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/patches" ]; then
  ROOT="$SCRIPT_DIR"
elif [ -d "$SCRIPT_DIR/../patches" ]; then
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  ROOT="$SCRIPT_DIR"
fi

VERSION=""
PATCH=""
SO=""
PREFIX="/usr/lib"
NO_DEPS=0
MODE="build"

while [ $# -gt 0 ]; do
  case "$1" in
    --build)   MODE="build"; shift ;;
    --version) VERSION="$2"; shift 2 ;;
    --patch)   PATCH="$2"; shift 2 ;;
    --so)      SO="$2"; MODE="install"; shift 2 ;;
    --prefix)  PREFIX="$2"; shift 2 ;;
    --no-deps) NO_DEPS=1; shift ;;
    --restore) MODE="restore"; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

TARGET="${PREFIX}/libvulkan_intel.so"
BACKUP="${TARGET}.bmg-shim.bak"

run_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

if [ "$MODE" = "restore" ]; then
  [ -f "$BACKUP" ] || { echo "no backup at $BACKUP" >&2; exit 1; }
  run_root install -m 0644 "$BACKUP" "$TARGET"
  run_root ldconfig
  echo "restored $TARGET"
  exit 0
fi

if [ "$MODE" = "build" ]; then
  # Match the installed Vulkan ICD first; fall back to the Mesa package.
  if [ -z "$VERSION" ]; then
    for pkg in vulkan-intel mesa; do
      v="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' | sed -E 's/^[0-9]+://; s/-.*$//')"
      case "$v" in
        26.2.5|26.2.6) VERSION="$v"; break ;;
      esac
    done
  fi
  [ -n "$VERSION" ] || { echo "cannot detect Mesa version; use --version" >&2; exit 1; }

  if [ -z "$PATCH" ]; then
    PATCH="$ROOT/patches/anv-va-h265-shim-mesa-${VERSION}-2026-11-08.patch"
  fi
  [ -f "$PATCH" ] || { echo "patch not found: $PATCH" >&2; exit 1; }

  if [ "$NO_DEPS" -eq 0 ]; then
    echo "== refreshing package databases =="
    run_root pacman -Syu --noconfirm
    echo "== installing build dependencies =="
    run_root pacman -S --needed --noconfirm \
      base-devel git meson ninja \
      python python-mako python-yaml python-packaging python-setuptools \
      glslang libva libdrm vulkan-headers vulkan-icd-loader \
      wayland wayland-protocols libx11 libxext libxshmfence libxcb \
      libxrandr xcb-util-keysyms libelf expat flex bison llvm clang \
      pkgconf spirv-llvm-translator
  fi

  BUILD_DIR="$(mktemp -d)"
  trap 'rm -rf "$BUILD_DIR"' EXIT
  echo "== cloning mesa-${VERSION} =="
  git clone --depth 1 --branch "mesa-${VERSION}" \
    https://gitlab.freedesktop.org/mesa/mesa.git "$BUILD_DIR/mesa"
  cd "$BUILD_DIR/mesa"
  git apply "$PATCH"

  meson setup build \
    -Dbuildtype=release -Dwerror=false -Degl=disabled \
    -Dgallium-drivers= -Dgbm=disabled -Dglx=disabled \
    -Dplatforms=x11,wayland -Dvideo-codecs=all -Dvulkan-drivers=intel
  ninja -C build src/intel/vulkan/libvulkan_intel.so
  SO="$BUILD_DIR/mesa/build/src/intel/vulkan/libvulkan_intel.so"
fi

[ -f "$SO" ] || { echo "no .so to install" >&2; exit 1; }

echo "== package =="; pacman -Q vulkan-intel 2>/dev/null || true
if [ -f "$TARGET" ] && [ ! -f "$BACKUP" ]; then
  run_root cp -a "$TARGET" "$BACKUP"
fi
run_root install -m 0644 "$SO" "$TARGET"
run_root ldconfig
echo "== installed =="
sha256sum "$TARGET"
echo "Rollback: sudo $0 --restore"
