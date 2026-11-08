# BMG Vulkan Video → VA-API shim for SteamVR PCVR

A Mesa/ANV out-of-tree backend that enables **H.265 Vulkan Video encode** on
Intel Arc B-series (Battlemage / BMG) GPUs by translating the Vulkan Video
encode API to **libva/iHD**. It is what lets SteamVR's `driver_vrlink` stream
PCVR to a Steam Frame headset on an Arc B570/B580 GPU.

## Why this exists

- A PC with an Intel Arc B570/B580 (BMG) runs SteamVR and the Steam Frame's
  wireless PCVR client.
- SteamVR's vrlink path uses **Vulkan Video H.265 encode**
  (`VK_KHR_video_encode_h265`).
- Mesa's ANV on BMG does not expose or implement that path: the generic video
  encode support is gated to older platforms / `ANV_DEBUG(VIDEO_ENCODE)`, even
  though the hardware has **two VCS media engines** and iHD supports HEVC.

## Limitations

- The Vulkan support is not intended to be generic. It is only tested on the
  P010 video surface used by the SteamVR texture atlas containing both the
  foveated and the peripheral views for left and right eye.

## Best practices: Start with low render settings

Initially start with low specs, such that steaming quality issues are not
caused by overloading the render/encoding pipeline from the start.

- General: Set render resolution to Custom 2476x2476 per eye (100%)
- Steam Link: Set Target Bandwidth to Auto
- Steam Link: Set Encoded Video Size to Manual, Size (px) to 768

## Enabling VR streaming

In the headset, actiate the Steam Overlay bar and click on the Streaming Status
Icon and under Available Computers flop open "Advanced" and select "Stream VR
without game". This should show you a streamed Steam environment and the Steam
interface streamed from your PC. If the Steam interface does not show on its
own, open it using the "Steam" icon (with the green remote symbol) in the steam
overlay bar.

Try running a game with modest graphics requirement first, such as Beat Saber.

## How to build and install

### Pre-installation requirements

Install the Intel graphics/Vulkan runtime and the verification tools before
running the installer:

```sh
sudo pacman -S --needed \
  mesa vulkan-intel vulkan-icd-loader intel-media-driver \
  libva libdrm linux-firmware \
  vulkan-tools libva-utils intel-gpu-tools
```

- `mesa` / `vulkan-intel` / `vulkan-icd-loader` — Intel ANV driver, the
  `libvulkan_intel.so` ICD and the Vulkan loader.
- `intel-media-driver` / `libva` — iHD VA-API backend used by the shim.
- `libdrm` / `linux-firmware` — DRM and GPU firmware.
- `vulkan-tools` (`vulkaninfo`), `libva-utils` (`vainfo`) and
  `intel-gpu-tools` (`intel_gpu_top`) — verification/diagnostics.

On CachyOS, the installer builds the patched ANV driver from the matching
patch in `patches/` and installs it over the distro's `libvulkan_intel.so`:

```sh
sudo ./install-cachyos.sh
```

It detects the installed `vulkan-intel`/`mesa` version, selects
`patches/anv-va-h265-shim-mesa-<version>-2026-11-08.patch`, installs the
build dependencies, clones the matching Mesa tag, applies the patch, builds
`libvulkan_intel.so`, backs up the existing one and installs the new one.

Options:

```sh
sudo ./install-cachyos.sh --version 26.2.5   # if detection is ambiguous
sudo ./install-cachyos.sh --so /path/libvulkan_intel.so   # deploy a prebuilt
sudo ./install-cachyos.sh --restore          # roll back
```

The installer is self-contained; a CachyOS container is only an optional
local verification aid and is not required for installation.  See
`INSTALL-cachyos.md` for the full native and container instructions.

### Verify the install

Confirm that the H.265 video encode path is exposed:

```sh
vulkaninfo 2>/dev/null | grep -iE "VK_KHR_video_encode"
```

Expected output:

```
VK_KHR_video_encode_h264                      : extension revision 14
VK_KHR_video_encode_h265                      : extension revision 14
VK_KHR_video_encode_queue                     : extension revision 12
```
