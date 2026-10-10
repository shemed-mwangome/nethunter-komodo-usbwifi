#!/usr/bin/env python3
"""Assemble the nethunter-usbwifi Magisk module from a Kleaf build's staging archive.
Usage: stage_module.py <modules_staging_dir.tar.gz> <repo_root>
- collects the wifi .ko (+ eeprom_93cx6), computes insmod order -> module/load_order.txt
- copies the needed firmware subset from lf-fw/ -> module/system/vendor/firmware/
  (Magisk overlays this onto /vendor/firmware; do NOT change firmware_class.path)
- zips module/ -> nethunter-usbwifi.zip
"""
import os, sys, subprocess, shutil, tarfile, tempfile, glob

arch, repo = sys.argv[1], os.path.abspath(sys.argv[2])
mod = os.path.join(repo, "module")
ko_dst = os.path.join(mod, "modules")
fw_dst = os.path.join(mod, "system", "vendor", "firmware")
os.makedirs(ko_dst, exist_ok=True); os.makedirs(fw_dst, exist_ok=True)

tmp = tempfile.mkdtemp()
with tarfile.open(arch) as t: t.extractall(tmp)
ver = os.listdir(os.path.join(tmp, "lib/modules"))[0]
kroot = os.path.join(tmp, "lib/modules", ver, "kernel")

srcs = glob.glob(os.path.join(kroot, "drivers/net/wireless/**/*.ko"), recursive=True)
srcs += glob.glob(os.path.join(kroot, "drivers/misc/eeprom/eeprom_93cx6.ko"))
depends = {}
for s in srcs:
    name = os.path.basename(s)[:-3]
    out = subprocess.run(["modinfo","-F","depends",s],capture_output=True,text=True).stdout.strip()
    depends[name] = [d for d in out.split(",") if d]
    shutil.copy(s, ko_dst)
have = set(depends); order=[]; done=set(); ch=True
while ch:
    ch=False
    for m in sorted(have):
        if m in done: continue
        if all(d in done or d not in have for d in depends[m]):
            order.append(m); done.add(m); ch=True
order += sorted(have-done)
open(os.path.join(mod,"load_order.txt"),"w").write("\n".join(order)+"\n")
print(f"staged {len(order)} modules (ver {ver})")

lf = os.path.join(repo,"lf-fw")
if os.path.isdir(lf):
    for d in ("ath9k_htc","rtlwifi","zd1211"):
        if os.path.isdir(os.path.join(lf,d)):
            shutil.copytree(os.path.join(lf,d), os.path.join(fw_dst,d), dirs_exist_ok=True)
    os.makedirs(os.path.join(fw_dst,"mediatek"), exist_ok=True)
    for f in ("mt7610u.bin","mt7610e.bin","mt7662.bin","mt7662_rom_patch.bin",
              "WIFI_RAM_CODE_MT7961_1.bin","WIFI_MT7961_patch_mcu_1_2_hdr.bin"):
        p=os.path.join(lf,"mediatek",f)
        if os.path.isfile(p): shutil.copy(p, os.path.join(fw_dst,"mediatek",f))
    # mt7601u driver requests mt7601u.bin at the firmware root
    p=os.path.join(lf,"mediatek","mt7601u.bin")
    if os.path.isfile(p): shutil.copy(p, os.path.join(fw_dst,"mt7601u.bin"))
    for f in ("carl9170-1.fw","ar5523.bin","rt2860.bin","rt2870.bin","rt2561.bin","rt2561s.bin",
              "rt2661.bin","rt3070.bin","rt3071.bin","rt3090.bin","rt3290.bin","rt73.bin"):
        p=os.path.join(lf,f)
        if os.path.isfile(p): shutil.copy(p, fw_dst)
    nfw=sum(len(f) for _,_,f in os.walk(fw_dst)); print(f"firmware files: {nfw}")
else:
    print("WARN: lf-fw/ missing — run scripts/fetch-firmware.sh first")

os.chmod(os.path.join(mod,"service.sh"), 0o755)
zp = os.path.join(repo,"nethunter-usbwifi.zip")
if os.path.exists(zp): os.remove(zp)
subprocess.run(["zip","-rq",zp,"."], cwd=mod, check=True)
print(f"packaged: {zp}")
shutil.rmtree(tmp, ignore_errors=True)
