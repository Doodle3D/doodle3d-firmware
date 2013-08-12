#!/bin/bash

# Adapted from: http://wiki.openwrt.org/toh/tp-link/tl-mr3020?s[]=3020#oem.mass.flashing

# Pass the firmware file to be flashed as the first parameter.
#
# The second curl call will time out, but it's expected. Once the
# script exits you can unplug the ethernet cable and proceed to the
# next router, but KEEP each router ON POWER until the new image is
# fully written! When flashing is done the router automatically
# reboots (as shown by all the leds flashing once).

#IMAGE_FILE_DEFAULT=bin/ar71xx/openwrt-ar71xx-generic-tl-wr703n-v1-squashfs-factory.bin
IMAGE_FILE_DEFAULT=bin/ar71xx/openwrt-ar71xx-generic-tl-mr3020-v1-squashfs-factory.bin

QUIET=no
IMAGE_FILE=$IMAGE_FILE_DEFAULT

while getopts hqf: arg; do
	case $arg in
		h)
			echo "$0: automatically flash an openwrt image to a TP-Link MR3020;"
			echo "  default image file: '$IMAGE_FILE_DEFAULT';"
			echo "  pass -q to be less verbose and optionally specify a different image file."
			exit
			;;
		q)
			QUIET=yes
			;;
		f)
			IMAGE_FILE=$OPTARG
			;;
	esac
done

if [ ! -f $IMAGE_FILE ]; then
	echo "$0: image '$IMAGE_FILE' does not exist"
	exit 1
fi

if [ $QUIET == "yes" ]; then
	exec > /dev/null
fi


curl \
  --user admin:admin \
  --user-agent 'Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:12.0) Gecko/20100101 Firefox/12.0' \
  --referer 'http://192.168.0.254/userRpm/SoftwareUpgradeRpm.htm' \
  --form "Filename=@$IMAGE_FILE" -F 'Upgrade=Upgrade' \
  http://192.168.0.254/incoming/Firmware.htm

sleep 1

curl \
  --max-time 2 \
  --user admin:admin \
  --user-agent 'Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:12.0) Gecko/20100101 Firefox/12.0' \
  --referer 'http://192.168.0.254/incoming/Firmware.htm' \
  http://192.168.0.254/userRpm/FirmwareUpdateTemp.htm
