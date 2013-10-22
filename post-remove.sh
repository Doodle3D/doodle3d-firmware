#!/bin/sh

if [ -f /etc/banner.default ]; then
	mv /etc/banner.default /etc/banner
fi

rmdir /usr/share/lua/wifibox/network
rmdir /usr/share/lua/wifibox/rest/api
rmdir /usr/share/lua/wifibox/rest
rmdir /usr/share/lua/wifibox/script
rmdir /usr/share/lua/wifibox/test/www 2> /dev/null
rmdir /usr/share/lua/wifibox/test 2> /dev/null
rmdir /usr/share/lua/wifibox/util
rmdir /usr/share/lua/wifibox
rmdir /usr/share/lua

#rm /www/test 2> /dev/null

echo "The wifibox banner has been removed. Changes to the root profile however, have"
echo "not been reverted, as haven't the wlan firewall zone and the radio0 device state."
echo "NOTE: config changes have not been implemented yet."

exit 0
