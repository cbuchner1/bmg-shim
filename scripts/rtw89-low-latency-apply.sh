#!/bin/bash
set -u
edca="003F3219"
# Find the Steam Frame Wireless Adapter (28de:2432) by USB IDs, regardless
# of the interface name (wlan0/wlan1/... can change between ports/boots).
dev=""
for d in /sys/class/net/*; do
  [[ "$(cat "$d/device/../idVendor" 2>/dev/null)" == 28de && \
     "$(cat "$d/device/../idProduct" 2>/dev/null)" == 2432 ]] && dev="$d" && break
done
# Optional fallback for callers that pass an interface name.
[ -n "$dev" ] || { [ -n "${1:-}" ] && dev="/sys/class/net/$1"; }
[ -n "$dev" ] && [ -d "$dev" ] || exit 0
iface=$(basename "$dev")
[[ "$(iw dev "$iface" link 2>/dev/null)" == Connected* ]] || exit 0
d="/sys/kernel/debug/ieee80211/$(basename "$(readlink -f "$dev/phy80211")")/rtw89"
[ -d "$d" ] || exit 0
echo "c300 4" > "$d/read_reg" 2>/dev/null
[[ "$(grep -o '0x[0-9a-f]*$' "$d/read_reg" 2>/dev/null)" == "0x${edca,,}" ]] && exit 0
echo 0x30 > "$d/disable_dm" 2>/dev/null
iw dev "$iface" set power_save off 2>/dev/null
iw dev "$iface" set tidconf tids 0xff amsdu off 2>/dev/null
for r in c300 c304 c308 c30c; do echo "$r $edca 4" > "$d/write_reg" 2>/dev/null; done

# Disable wpa_supplicant background scanning for this dedicated link.
NET_ID=$(wpa_cli -i "$iface" status 2>/dev/null | awk -F= '$1 == "id" { print $2; exit }')
if [ -n "$NET_ID" ]; then
  before=$(wpa_cli -i "$iface" get_network "$NET_ID" bgscan 2>/dev/null)
  if wpa_cli -i "$iface" set_network "$NET_ID" bgscan '""' >/dev/null 2>&1; then
    echo "disabled bgscan on $iface (network id $NET_ID, was $before)"
  fi
fi
echo "applied low latency mode on $iface"
