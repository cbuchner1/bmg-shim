# Installing the ANV H.265 shim on CachyOS

The installer is a standalone script (`install-cachyos.sh`); it can
build natively from the patch or install a prebuilt `.so`.  The Podman
container is only a verification/CI aid — it is not required to install.

## Route A — verify/build with Podman (optional)

The installer is standalone; the container only verifies it on a clean
CachyOS base.  Podman is the recommended open-source Docker alternative:

```sh
cd ~/bmg-shim
podman build -f docker/Dockerfile -t bmg-shim-builder .
podman run --rm bmg-shim-builder --build --version 26.2.5
```

That builds and installs inside the disposable container (useful as a CI
check).  For a host install, use Route B or pass a prebuilt `.so` to
`install-cachyos.sh`.  Docker works too with the same Dockerfile/commands.

## Route B — native CachyOS build

```sh
sudo pacman -S --needed base-devel git meson ninja python python-mako \
  python-yaml python-packaging python-setuptools glslang libva libdrm \
  vulkan-headers vulkan-icd-loader wayland wayland-protocols \
  libx11 libxext libxshmfence libxcb libxrandr xcb-util-keysyms \
  libelf expat flex bison llvm clang pkgconf spirv-llvm-translator
git clone --depth 1 --branch mesa-26.2.5 \
  https://gitlab.freedesktop.org/mesa/mesa.git ~/mesa-26.2.5
cd ~/mesa-26.2.5
git apply ~/bmg-shim/patches/anv-va-h265-shim-mesa-26.2.5-2026-11-08.patch
meson setup build -Dbuildtype=release -Dwerror=false -Degl=disabled \
  -Dgallium-drivers= -Dgbm=disabled -Dglx=disabled \
  -Dplatforms=x11,wayland -Dvideo-codecs=all -Dvulkan-drivers=intel
ninja -C build src/intel/vulkan/libvulkan_intel.so
sudo ~/bmg-shim/install-cachyos.sh \
  build/src/intel/vulkan/libvulkan_intel.so
```

## Rollback

```sh
sudo ~/bmg-shim/install-cachyos.sh --restore
```

or reinstall the distro package:

```sh
sudo pacman -S vulkan-intel
```

## Notes

- Match the patch to the installed Mesa base: `vulkan-intel 3:26.2.6-1`
  pairs with the 26.2.6 patch; `mesa 3:26.2.5-1` with the 26.2.5 patch.
- The install replaces `/usr/lib/libvulkan_intel.so`; `pacman -Qkk
  vulkan-intel` will flag it, and a package update will overwrite it.
- The shim is only used by the ANV Vulkan ICD; Steam Link’s 2D H.264 path
  uses FFmpeg/iHD and is unaffected.
