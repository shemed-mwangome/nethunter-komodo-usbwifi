# HID / BadUSB on the stock kernel (no custom kernel needed)

The komodo stock kernel already builds the USB HID gadget function in (`CONFIG_USB_F_HID=y`,
`CONFIG_USB_CONFIGFS_F_HID=y`, `CONFIG_UHID=y`, `CONFIG_HIDRAW=y`) and the gadget framework is
live at `/config/usb_gadget/g1`. So BadUSB works without replacing the kernel — you just add a HID
function to the live gadget via configfs. Mass storage (`USB_F_MASS_STORAGE=y`, DriveDroid) and USB
networking (`USB_F_ECM/EEM/NCM=y`) are the same story.

Run these as root on the device (adb shell su, or NetHunter terminal). `g1` is Android's gadget
(carries adb/MTP); adding HID to it means an unbind/rebind, so USB/adb blinks for a second.

```sh
G=/config/usb_gadget/g1

# 1. create a boot-keyboard HID function
mkdir -p $G/functions/hid.0
echo 1 > $G/functions/hid.0/protocol       # keyboard
echo 1 > $G/functions/hid.0/subclass       # boot interface
echo 8 > $G/functions/hid.0/report_length
# standard 63-byte boot-keyboard report descriptor
printf '\x05\x01\x09\x06\xA1\x01\x05\x07\x19\xE0\x29\xE7\x15\x00\x25\x01\x75\x01\x95\x08\x81\x02\x95\x01\x75\x08\x81\x03\x95\x05\x75\x01\x05\x08\x19\x01\x29\x05\x91\x02\x95\x01\x75\x03\x91\x03\x95\x06\x75\x08\x15\x00\x25\x65\x05\x07\x19\x00\x29\x65\x81\x00\xC0' > $G/functions/hid.0/report_desc

# 2. link it into the active config and rebind (configfs won't edit a bound gadget)
UDC=$(cat $G/UDC)                 # e.g. 11210000.dwc3
echo "" > $G/UDC                  # unbind (adb/USB drops briefly)
ln -s $G/functions/hid.0 $G/configs/b.1/hid.0
echo "$UDC" > $G/UDC             # rebind -> /dev/hidg0 appears
ls -l /dev/hidg0
```

Send keystrokes by writing 8-byte reports to `/dev/hidg0` ([modifier, reserved, k1..k6], then a
zero report to release). Example — type `l`:

```sh
printf '\0\0\x0f\0\0\0\0\0' > /dev/hidg0   # press 'l' (usage 0x0f)
printf '\0\0\0\0\0\0\0\0'   > /dev/hidg0   # release
```

Keystrokes go to whatever has focus on the connected host, so focus a safe text field first.
NetHunter's DuckHunter/HID attack UI writes these reports for you once `/dev/hidg0` exists.

**Caveat:** Android's USB HAL owns `g1`; on some USB state changes it may reassert its own config
and drop your `hid.0` link. For a persistent HID gadget, add the link from a boot service (or let
the NetHunter app manage the gadget). Control the phone over Wi-Fi SSH while doing gadget surgery,
since the USB rebind interrupts adb.
