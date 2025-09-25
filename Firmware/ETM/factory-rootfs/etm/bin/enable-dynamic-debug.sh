#!/bin/sh

# set printk to maximum
echo 7 > /proc/sys/kernel/printk

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!! comment next line to enable dynamic debug logs !!!
# !!!               logs can be verbose              !!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
exit 0

# mount debugfs
mount -t debugfs none /sys/kernel/debug

# enable USB dynamic debug logs
(
echo 'file drivers/usb/core/hub.c +p'
echo 'file drivers/usb/musb/* +p'
) > /sys/kernel/debug/dynamic_debug/control
# print out enabled logs
awk '$3 != "=_"' /sys/kernel/debug/dynamic_debug/control

# enable SCSI logging
# See https://www.suse.com/support/kb/doc/?id=000017472
# IOCTL HLCOMPLETE HLQUEUE LLCOMPLETE LLQUEUE MLCOMPLETE MLQUEUE SCAN TIMEOUT ERROR
#   000        000     000        000     000        000     000  000     001   001
echo 0x00000009 > /proc/sys/dev/scsi/logging_level

# enable USB capture
cat /sys/kernel/debug/usb/usbmon/1u | awk '{ print strftime("%d %H:%M:%S"), $0; fflush(); }' > /root/log/usb-bus1.log &
cat /sys/kernel/debug/usb/usbmon/2u | awk '{ print strftime("%d %H:%M:%S"), $0; fflush(); }' > /root/log/usb-bus2.log &
