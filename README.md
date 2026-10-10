# NetHunter USB Wi-Fi driver pack — Pixel 9 Pro XL (komodo), GKI android14-6.1

External USB Wi-Fi adapters (monitor mode + injection) on a **NetHunter Lite / stock-kernel**
Pixel 9 Pro XL, **without replacing the kernel**. The drivers are built against the exact GKI
source and shipped as a **Magisk module** that auto-loads them at boot. Firmware rides a
`/vendor/firmware` overlay. Developed and verified on `6.1.162-android14-11-g2ec90535fa34-ab15810641`.

> For authorized security testing on hardware and networks you own. Monitor mode / injection is a
> penetration-testing capability — use it lawfully.

## Why this exists
NetHunter Lite keeps the **stock GKI kernel**, which ships **no Atheros/USB-Wi-Fi drivers** — so an
AR9271/MT7612U/etc. enumerates on USB but never gets a driver. Building a full custom NetHunter
kernel is heavy and risky on GKI (it endangers the whole vendor-module set). Instead we build just
the Wi-Fi drivers as loadable modules against the matching GKI source and load them with Magisk.

## What you get
`ath9k_htc` (AR9271/AR7010), `mt76x2u`/`mt76x0u`/`mt7921u` (MediaTek incl. **MT7612U = Alfa
AWUS036ACM**, dual-band), `rt2x00`/`rt2800usb` (Ralink/Panda), `rtl8xxxu`, `rtl8187`, `rtl8192cu`,
`zd1211rw`, `carl9170`, `ar5523` — 32 modules + firmware. **Not** RTL8812AU/8821AU (see Limitations).

## Requirements
- Rooted Pixel 9 Pro XL (komodo) with Magisk, bootloader unlocked, NetHunter Lite chroot.
- A Linux build host: `git`, Google's `repo`, `python3`, `zip`, ~40 GB free, a few hours (first build).
- `adb` + USB cable (recommended control channel).

## Build & install
```sh
# 1. find YOUR kernel tag (see "Matching your kernel" below), then:
TAG=android14-6.1-2026-03_r18 BUILD_NUMBER=15810641 bash scripts/build-all.sh
# 2. verify CRCs vs your device's vendor mac80211 (see below), then:
bash scripts/install-module.sh
adb reboot
```
After reboot the drivers auto-load; plug an adapter and it binds. Set monitor mode per session:
```sh
ip link set wlan2 down; iw dev wlan2 set type monitor; ip link set wlan2 up
wifite -i wlan2        # or: airmon-ng start wlan2
```

## Matching your kernel (critical)
`adb shell su -c 'uname -r'` → e.g. `6.1.162-android14-11-g2ec90535fa34-ab15810641`.
- The `-g<sha>` is the GKI `common` HEAD. Find the `android14-6.1-YYYY-MM_rNN` tag whose HEAD sha
  equals it (`git ls-remote https://android.googlesource.com/kernel/common | grep <sha>`), set `TAG`.
- `-ab<N>` → `BUILD_NUMBER` (cosmetic; vermagic is **not** strictly enforced on GKI — see below).

## The gotchas (why a naive build fails)
1. **vermagic isn't enforced** — this GKI loads modules by KMI, not exact vermagic. The vendor
   `mac80211.ko` runs with a totally different `-g…-ab…` suffix. So `-dirty`/sha/build mismatches
   are harmless; the only real gate is **modversion symbol CRCs**.
2. **The CRC that bites:** `ieee80211_alloc_hw_nm` / `wiphy_new_nm`. The vendor `mac80211` is built
   with **`CONFIG_NL80211_TESTMODE=y`** and **`MAC80211_LEDS` off** (ath9k force-selects LEDS, so
   `patches/ath9k-drop-mac80211-leds.patch` removes that). Match these or `ath9k_htc` won't load.
3. **arm64 GKI has no `CFG80211`/`MAC80211`** in its defconfig (they're vendor modules) — the
   fragment adds `WLAN`, `CFG80211=m`, `MAC80211=m`, `RFKILL=m`.
4. **Harvest from the staging archive** (`modules_staging_dir.tar.gz`), not the dist target —
   undeclared modules don't reach dist. Build flags: `--allow_undeclared_modules
   --nowarn_undeclared_modules --nokmi_symbol_list_strict_mode --nokmi_symbol_list_violations_check`.
5. **Firmware:** ship it in `module/system/vendor/firmware/` (Magisk overlay). **Never** point
   `firmware_class.path` at the module dir — that starves the internal Broadcom Wi-Fi of its
   firmware on reload ("no networks"). `tools/kover_crc_check.py` compares your `.ko` CRCs against
   the device's vendor modules (pull them from `/vendor_dlkm/lib/modules/`).

## HID / BadUSB, DriveDroid, USB networking
All supported by the **stock kernel** (gadget functions built in) — no custom kernel needed. See
[docs/hid-setup.md](docs/hid-setup.md).

## Limitations
- **RTL8812AU/8821AU (Alfa ACH/AC, TP-Link T2U Plus)** — not included. The out-of-tree driver
  doesn't build against this GKI's backported 6.3-era cfg80211 APIs without substantial patching.
  Prefer an **MT7612U** adapter (in-tree, dual-band, supported here).
- **nexmon internal-chip injection** — not attempted; BCM4390 is almost certainly unsupported.
- Modules are tied to the kernel build; a kernel OTA needs a rebuild against the new tag.

## Layout
```
patches/   nethunter_wifi_defconfig (the config fragment), ath9k LEDS patch
module/    Magisk module template (module.prop, service.sh, load_order.txt; .ko + firmware added by build)
scripts/   build-all.sh, fetch-firmware.sh, install-module.sh
tools/     stage_module.py (assemble+zip), kover_crc_check.py (CRC verify)
docs/      hid-setup.md
```
