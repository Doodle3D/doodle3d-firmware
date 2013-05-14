#!/bin/sh
if [ -f /etc/banner.default ]; then
	mv /etc/banner.default /etc/banner
fi
echo "The wifibox banner has been removed. Changes to the root profile however, have"
echo "not been reverted, as haven't the wlan firewall zone and the radio0 device state."
echo "NOTE: config changes have not been implemented yet."
