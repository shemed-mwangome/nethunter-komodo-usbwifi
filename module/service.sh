#!/system/bin/sh
# NetHunter USB Wi-Fi driver loader. Runs in Magisk late_start service, after the
# vendor wifi stack (mac80211/cfg80211) is up. Loads external-adapter drivers so a
# dongle binds whenever it is plugged.
#
# Firmware is delivered via this module's system/vendor/firmware overlay (merged into
# /vendor/firmware by Magisk), so we do NOT touch firmware_class.path — changing it
# would starve the internal Broadcom wifi of its firmware on any reload.
MODDIR=${0%/*}

# Wait for the vendor mac80211 to be loaded (our drivers depend on it).
i=0
while [ $i -lt 60 ]; do
    [ -d /sys/module/mac80211 ] && break
    sleep 1
    i=$((i + 1))
done

# Load drivers in dependency order; skip any already present. Module names use '-',
# /sys/module uses '_'.
while IFS= read -r m; do
    [ -z "$m" ] && continue
    sysname=$(echo "$m" | tr '-' '_')
    [ -d "/sys/module/$sysname" ] && continue
    insmod "$MODDIR/modules/$m.ko" 2>/dev/null
done < "$MODDIR/load_order.txt"
