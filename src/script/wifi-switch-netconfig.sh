#!/bin/sh

[ "${ACTION}" = "released" ] || exit 0

. /lib/functions.sh

logger "$BUTTON pressed for $SEEN seconds"
if [ "$SEEN" -lt 1 ]
then
	#see https://github.com/Doodle3D/doodle3d-firmware/blob/master/src/network/wlanconfig.lua#L188 for reference
	#check if network on top is enabled
	uci get wireless.@wifi-iface[0].disabled
	RESULT=$?
	if [ $RESULT -eq 0 ]
	then
		uci set wireless.@wifi-iface[0].disabled=1 #disable current config
		uci set wireless.@wifi-iface[1].disabled=0 #enable last used network
		uci reorder wireless.@wifi-iface[0]=2 #reorder networks so last used config goes to the top again
		uci commit wireless #commit changes
		/etc/init.d/network reload #reload network module so changes become effective
	fi
fi
