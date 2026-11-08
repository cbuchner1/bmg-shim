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
  - 192,362 bytes, md5 `262b032b8c1bb733e20b1feeb0d2cbc2`
  - 19 files (17 modified + 2 new)
- `anv_va_encode.c` md5: `782e4d59b1ab31ac4b0e51a59863e742`
- Build/installed `.so`: `6a1ba17f5a3ac30d5bf1b0acaa9ee6f4`

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
  - 189,738 bytes, md5 `74a8b9fe76b33c65a03c93b7fee4e1c7`
  - 19 files (17 modified + 2 new)
- `anv_va_encode.c` md5: `f25ceb097f2dbcac05198548351456c7`
- Build: `~/mesa-26.2.6/build/src/intel/vulkan/libvulkan_intel.so`
  md5 `7923a25893faa126383add91217a0cb4` (not installed; the live driver is
  the 26.2.5 build).

```sh
cd ~/mesa-26.2.6
git apply ~/bmg-shim/patches/anv-va-h265-shim-mesa-26.2.6-2026-11-08.patch
meson setup build -Dbuildtype=release -Dwerror=false -Degl=disabled \
  -Dgallium-drivers= -Dgbm=disabled -Dglx=disabled \
  -Dplatforms=x11,wayland -Dvideo-codecs=all -Dvulkan-drivers=intel
ninja -C build src/intel/vulkan/libvulkan_intel.so
```

Both snapshots also set the single encode worker to `SCHED_FIFO` priority 50
(best effort; falls back to CFS if the process lacks `CAP_SYS_NICE`).

The distro package is `vulkan-intel 3:26.2.6-1`; installing the 26.2.6 build
would make the ICD file version match the package again (still patched, so
`pacman -Qkk vulkan-intel` would still flag the file).
