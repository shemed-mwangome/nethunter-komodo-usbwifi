#!/usr/bin/env bash
# Fetch the Wi-Fi firmware blobs the driver pack needs, from linux-firmware (sparse).
# Lands them in lf-fw/ ; stage_module.py copies the needed subset into the module.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d lf-fw/.git ] && { echo "lf-fw already present"; exit 0; }
rm -rf lf-fw; mkdir -p lf-fw; cd lf-fw
git init -q
git remote add origin https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git
git config core.sparseCheckout true
cat > .git/info/sparse-checkout <<'EOF'
/ath9k_htc/
/mediatek/
/rtlwifi/
/zd1211/
/carl9170-1.fw
/ar5523.bin
/rt2860.bin
/rt2870.bin
/rt2561.bin
/rt2561s.bin
/rt2661.bin
/rt3070.bin
/rt3071.bin
/rt3090.bin
/rt3290.bin
/rt73.bin
/rtl8187*
/rtl8188*
/rtl8192*
/rtl8712u.bin
/rtl8723*
EOF
git -c protocol.version=2 fetch --depth=1 -q origin HEAD
git checkout -q FETCH_HEAD
echo "firmware fetched: $(find . -type f ! -path './.git/*' | wc -l) files"
