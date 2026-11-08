# ANV Vulkan Video H.265 → libva/iHD shim — patch snapshots

> This work was done by **DeepSeek V4.1 Flash**.

Two snapshots of the same shim feature set, one per Mesa base.  The
`anv_va_encode.c` files differ in their Mesa context/version, so their md5s
are not identical.  The snapshots are dated **2026-11-08**.

Both snapshots contain the environment migration: the encoder options are
`ANV_VA_*` environment variables, not `/tmp/va_*` flag files; the logs default
to `/tmp/anv-va.log` and `/tmp/vrlink-probe.log` (overridable with
`ANV_VA_LOG` / `ANV_VA_PROBE_LOG`); `/tmp` remains only for optional debug
dumps.

## Mesa 26.2.5

- Base: `ddaf85e` “VERSION: bump for 26.2.5” (tag `mesa-26.2.5`)
- Patch: `anv-va-h265-shim-mesa-26.2.5-2026-11-08.patch`
  - 191,892 bytes, md5 `224cd43c60af883f63c8fe52e671d43e`
  - 19 files (17 modified + 2 new)
- `anv_va_encode.c` md5: `b282dda0106a370fead5d1fa09c1ea00`
- Build/installed `.so`: `a9da6368291d2dbc4ba15d84bfca4ce0`

```sh
cd ~/mesa-26.2.5
git apply ~/bmg-shim/patches/anv-va-h265-shim-mesa-26.2.5-2026-11-08.patch
ninja -C build src/intel/vulkan/libvulkan_intel.so
sudo install -m 0644 build/src/intel/vulkan/libvulkan_intel.so \
    /usr/lib/libvulkan_intel.so
```

## Mesa 26.2.6

- Base: `8e87a50` “VERSION: bump for 26.2.6” (tag `mesa-26.2.6`, tag object
  `66b6349`)
- Patch: `anv-va-h265-shim-mesa-26.2.6-2026-11-08.patch`
  - 189,268 bytes, md5 `43459eb29ede4b782c8036ffea31bc85`
  - 19 files (17 modified + 2 new)
- `anv_va_encode.c` md5: `20295ec89b2b3bd37848820989e892f7`
- Build: `~/mesa-26.2.6/build/src/intel/vulkan/libvulkan_intel.so`
  md5 `76721a3c837e798155f557315f75e418` (not installed; the live driver is
  the 26.2.5 build).

```sh
cd ~/mesa-26.2.6
git apply ~/bmg-shim/patches/anv-va-h265-shim-mesa-26.2.6-2026-11-08.patch
meson setup build -Dbuildtype=release -Dwerror=false -Degl=disabled \
  -Dgallium-drivers= -Dgbm=disabled -Dglx=disabled \
  -Dplatforms=x11,wayland -Dvideo-codecs=all -Dvulkan-drivers=intel
ninja -C build src/intel/vulkan/libvulkan_intel.so
```

The distro package is `vulkan-intel 3:26.2.6-1`; installing the 26.2.6 build
would make the ICD file version match the package again (still patched, so
`pacman -Qkk vulkan-intel` would still flag the file).
