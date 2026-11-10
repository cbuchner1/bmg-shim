# BMG Vulkan Video → VA-API shim for SteamVR PCVR

A Mesa/ANV out-of-tree backend that enables **H.265 Vulkan Video encode** on
Intel Arc B-series (Battlemage / BMG) GPUs by translating the Vulkan Video
encode API to **libva/iHD**. It is what lets SteamVR's `driver_vrlink` stream
PCVR to a Steam Frame headset on an Arc B570/B580 GPU.

## Why this exists

A PC with an Intel Arc B570/B580 (BMG) runs SteamVR but will not detect
the Steam Frame or controllers for the following reasons:

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

- General: Lower Refresh Rate (Hz) to 72.
- General: Set render resolution to Custom 2476x2476 per eye (100%)
- Steam Link: Set Target Bandwidth to Auto
- Steam Link: Set Encoded Video Size to Manual, Size (px) to 768

You can gradually raise the settings when things work well for you.

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

### Running the installation script
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
sudo ./install-cachyos.sh --build           # build from patches (default)
sudo ./install-cachyos.sh --no-deps          # skip pacman build-dependency install
```

The installer is self-contained; a CachyOS container is only an optional
verification aid and is not required for installation.  See
`INSTALL-cachyos.md` and `docker/Dockerfile` for the full native and
container instructions.

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

## WiFi tuning for the Steam Frame adapter

The following fixes target the wireless link, not the Vulkan shim. They are
optional but are reported to remove most of the "stream reset storm" packet
loss (see ValveSoftware/SteamVR-for-Linux#965 and ValveSoftware/SteamOS#2952).

### Host: 6 GHz TX power override (`rtw89`)

The Frame advertises its 6 GHz AP as VLP, so the in-tree `rtw89` driver caps
the adapter at 7 dBm (single chain) / 4 dBm (two chain). The Windows driver
uses the chip maximum (16 / 13 dBm). The `reg6_pwr_override` patch adds a
module parameter to force the LPI power class.

1. Patch `drivers/net/wireless/realtek/rtw89/regd.c` for your kernel: add a
   `reg6_pwr_override` `module_param` before
   `rtw89_reg_6ghz_power_recalc()`, and in that function, after
   `rcu_read_unlock()`, set `rtwvif_link->reg_6ghz_power` from the override
   when `active`.
2. Build against the running kernel and install:

   ```sh
   cd <kernel-src>/drivers/net/wireless/realtek/rtw89
   make -C /lib/modules/$(uname -r)/build M=$PWD modules LLVM=1
   sudo mkdir -p /lib/modules/$(uname -r)/updates/rtw89
   sudo cp rtw89_*.ko /lib/modules/$(uname -r)/updates/rtw89/
   sudo depmod -a
   ```

3. Set the option:

   ```sh
   echo 'options rtw89_core reg6_pwr_override=2' | \
     sudo tee /etc/modprobe.d/rtw89-frame.conf
   ```

4. Reboot (or replug the adapter; a plain module reload can leave it
   rfkill-ed) and verify:

   ```sh
   sudo dmesg | grep "6 GHz power class forced"
   sudo cat /sys/kernel/debug/ieee80211/phy*/rtw89/txpwr_table | \
     grep -E "reg6_pwr_type|OFDM_2TX|MCS_2TX_160M"
   ```

   Expected: `6 GHz power class forced to 1 by reg6_pwr_override` and
   `[reg6_pwr_type] 1`.

LPI is the indoor 6 GHz class (allowed indoors in the EU/US/Canada as far as
the issue reports go; check your regulatory domain). The override is not
persistent across kernel updates — rebuild after each update.

### Host: rtw89 low-latency mode (EDCA/aggregation)

SteamOS normally runs `holo-realtek-firmware-toggles set-low-latency-mode on`
when the adapter connects; desktop Steam does not ship it, so the adapter
keeps the default EDCA/aggregation settings. The script in
`scripts/rtw89-low-latency-apply.sh` reproduces the important parts through
rtw89 debugfs:

- aggressive EDCA on all four queues (`c300`/`c304`/`c308`/`c30c` =
  `003F3219`: TXOP 2000 µs, CWmax 7, CWmin 3, AIFSN 1),
- `disable_dm` `0x30` (firmware `HW_SCAN`/`INACTIVE_PS` off),
- power save off,
- A-MSDU off,
- wpa_supplicant background scanning off for the Steam Frame network
  (`wpa_cli set_network <id> bgscan ""`),
- Windows-style MAC aggregation/retry caps: `0xC610 = 0x107f3f3f` (512 µs
  A-MPDU airtime) and `0xC62C = 0x06060000` (6 retries).

It finds the adapter by USB ID `28de:2432`, so the interface name can be
`wlan0`, `wlan1`, etc.

The recommended install is the dispatcher, which creates the apply script,
the oneshot service and the 5 s timer on the first Steam Frame `wlan1` up:

```sh
sudo install -m 0755 scripts/90-optimize-latency-for-steam-frame \
  /etc/NetworkManager/dispatcher.d/90-optimize-latency-for-steam-frame
```

The manual equivalent (if you do not use NetworkManager) is:

```sh
sudo install -m 0755 scripts/rtw89-low-latency-apply.sh \
  /usr/local/bin/rtw89-low-latency-apply.sh

sudo tee /etc/systemd/system/rtw89-low-latency.service >/dev/null <<'EOF'
[Unit]
Description=rtw89 low-latency mode for Steam Frame adapter
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rtw89-low-latency-apply.sh

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/rtw89-low-latency.timer >/dev/null <<'EOF'
[Unit]
Description=Reapply rtw89 low-latency mode every 5 s

[Timer]
OnBootSec=5s
OnUnitActiveSec=5s
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now rtw89-low-latency.timer
```

Both routes require `CONFIG_RTW89_DEBUGFS=y` and do not work under Secure
Boot lockdown.

### Headset: `ath12k` reorder timeout

The headset ships `rx_reorder_timeout=2,2,2,2`, tuned for a dongle that caps
retries. A Linux host does not cap them the same way, so late retries fall
outside the 2 ms reorder window and vrlink sees holes.

On the headset (SSH as `steamos`, password as configured):

```sh
echo 'options ath12k rx_reorder_timeout=0,0,0,0' | \
  sudo tee /etc/modprobe.d/ath12k.conf
sudo reboot
```

After the reboot, verify:

```sh
cat /sys/module/ath12k/parameters/rx_reorder_timeout
# expect: 0,0,0,0
```

`0` means the driver default (100/100/100/40 ms). The value is only read when
the radio starts, so a reboot (not just a module reload) is required. Headset
OS updates delete `/etc/modprobe.d/ath12k.conf`, so re-apply after updates.
