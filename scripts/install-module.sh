#!/usr/bin/env bash
# Install the built Magisk module onto a rooted device over adb (USB).
# Requires: adb, Magisk root (su), nethunter-usbwifi.zip built.
set -euo pipefail
cd "$(dirname "$0")/.."
ZIP=nethunter-usbwifi.zip
[ -f "$ZIP" ] || { echo "build it first (scripts/build-all.sh)"; exit 1; }
ADB=${ADB:-adb}
"$ADB" get-state >/dev/null 2>&1 || { echo "no adb device; plug in USB + enable USB debugging"; exit 1; }
"$ADB" push "$ZIP" /data/local/tmp/nethunter-usbwifi.zip
"$ADB" shell 'su -c "
  set -e
  D=/data/adb/modules/nethunter-usbwifi
  rm -rf \$D && mkdir -p \$D
  cd \$D && unzip -oq /data/local/tmp/nethunter-usbwifi.zip
  chmod 755 \$D/service.sh
  echo installed:; ls \$D
"'
echo "Reboot to activate (drivers auto-load at boot, firmware via /vendor overlay):"
echo "  adb reboot"
