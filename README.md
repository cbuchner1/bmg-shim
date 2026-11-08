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

## How to build and install

A simple install method is being worked on at the moment.
