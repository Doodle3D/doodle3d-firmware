#!/bin/sh

if [ -f /etc/banner.default ]; then
	mv /etc/banner.default /etc/banner
fi

rmdir /usr/share/lua/autowifi/ext/www/cgi-bin
rm /usr/share/lua/autowifi/ext/www/admin
rmdir /usr/share/lua/autowifi/ext/www
rmdir /usr/share/lua/autowifi/admin
rmdir /usr/share/lua/autowifi/ext
rmdir /usr/share/lua/autowifi/misc
rmdir /usr/share/lua/autowifi
rmdir /usr/share/lua
rm /www/admin
rmdir /www/cgi-bin

echo "The wifibox banner has been removed. Changes to the root profile however, have"
echo "not been reverted, as haven't the wlan firewall zone and the radio0 device state."
echo "NOTE: config changes have not been implemented yet."
