#!/usr/bin/env bash
# Build the external USB Wi-Fi driver pack for a GKI android14-6.1 device
# (developed for Pixel 9 Pro XL "komodo", NetHunter Lite / stock kernel).
#
# Produces module/ (Magisk module) + nethunter-usbwifi.zip.
# Run from the repo root. Needs: git, repo, python3, ~40 GB disk, a few hours first time.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"

# ---- 0. target kernel tag -------------------------------------------------
# Find YOUR tag: `adb shell su -c 'uname -r'` gives e.g.
#   6.1.162-android14-11-g2ec90535fa34-ab15810641
# The -g<sha> is the GKI common HEAD. Find the android14-6.1-YYYY-MM_rNN tag whose
# HEAD sha matches it (see README). BUILD_NUMBER is the -ab<N> (cosmetic on GKI).
TAG=${TAG:-android14-6.1-2026-03_r18}
export BUILD_NUMBER=${BUILD_NUMBER:-15810641}

# ---- 1. fetch GKI source --------------------------------------------------
if [ ! -d gki/common ]; then
  mkdir -p gki && (cd gki
    repo init -u https://android.googlesource.com/kernel/manifest -b common-android14-6.1 --depth=1
    repo sync -c -j"$(nproc)" --no-tags --optimized-fetch --force-sync
    git -C common fetch --depth=1 https://android.googlesource.com/kernel/common "refs/tags/$TAG:refs/tags/$TAG"
    git -C common checkout "$TAG")
fi
echo "common @ $(git -C gki/common rev-parse --short HEAD) (want the -g sha from uname)"

# ---- 2. apply config + patches --------------------------------------------
mkdir -p gki/nethunter
cp patches/nethunter_wifi_defconfig gki/nethunter/
cat > gki/nethunter/BUILD.bazel <<'B'
filegroup(name = "wifi_frag", srcs = ["nethunter_wifi_defconfig"], visibility = ["//visibility:public"])
B
# ath9k must not force MAC80211_LEDS on (vendor mac80211 is built without it)
sed -i '/select MAC80211_LEDS if LEDS_CLASS/d' gki/common/drivers/net/wireless/ath/ath9k/Kconfig

# ---- 3. build -------------------------------------------------------------
(cd gki && BUILD_NUMBER="$BUILD_NUMBER" tools/bazel build //common:kernel_aarch64 \
   --config=stamp --defconfig_fragment=//nethunter:wifi_frag --lto=thin \
   --allow_undeclared_modules --nowarn_undeclared_modules \
   --nokmi_symbol_list_strict_mode --nokmi_symbol_list_violations_check) || true
ARCH=$(find -L gki/bazel-bin/common -name modules_staging_dir.tar.gz | head -1)
[ -n "$ARCH" ] || { echo "build produced no staging archive"; exit 1; }

# ---- 4. firmware + package ------------------------------------------------
bash scripts/fetch-firmware.sh
python3 tools/stage_module.py "$ARCH" "$REPO"
echo
echo "Verify CRCs against your device's vendor mac80211/cfg80211 before trusting it:"
echo "  adb shell su -c 'cp /vendor_dlkm/lib/modules/{mac80211,cfg80211,wonder}.ko /data/local/tmp/'"
echo "  adb pull /data/local/tmp/wonder.ko ; python3 tools/kover_crc_check.py module/modules/ath9k_htc.ko wonder.ko"
echo "Then: bash scripts/install-module.sh"
