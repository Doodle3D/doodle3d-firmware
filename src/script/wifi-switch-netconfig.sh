#!/bin/sh

[ "${ACTION}" = "released" ] || exit 0

. /lib/functions.sh

logger "$BUTTON pressed for $SEEN seconds"
if [ "$SEEN" -lt 1 ]
then
	#see https://github.com/Doodle3D/doodle3d-firmware/blob/master/src/network/wlanconfig.lua#L188 for reference
	#check if network on top is in STA mode
	if [ $(uci get wireless.@wifi-iface[1].mode) == "ap" ]
	then
		logger "switching to AP"
		if [ $(uci get wireless.@wifi-iface[1].network) != "wlan" ] #edge case when only the factory default openwrt network is available
		then
			uci set wireless.@wifi-iface[1].network=wlan
		fi
		#configure dhcp
		uci delete network.wlan
		uci set network.wlan=interface
		uci set network.wlan.netmask=$(uci get wifibox.general.network_ap_netmask)
		uci set network.wlan.proto=static
		uci set network.wlan.ipaddr=$(uci get wifibox.general.network_ap_address)

		uci set dhcp.wlan=dhcp
		uci set dhcp.wlan.start=100
		uci set dhcp.wlan.leasetime=12h
		uci set dhcp.wlan.limit=150
		uci set dhcp.wlan.interface=wlan

		uci set wireless.@wifi-iface[0].disabled=1 #disable current config
		uci set wireless.@wifi-iface[1].disabled=0 #enable last used network
		uci reorder wireless.@wifi-iface[0]=2 #reorder networks so last used config goes to the top again
		uci commit #commit changes
		/etc/init.d/network reload #reload network module so changes become effective
		echo "4|" > /tmp/networkstatus.txt
	else
		logger "switching to STA $(uci get wireless.@wifi-iface[0].mode)"
		uci set wireless.@wifi-iface[0].disabled=1 #disable current config
		uci set wireless.@wifi-iface[1].disabled=0 #enable last used network
		uci reorder wireless.@wifi-iface[0]=2 #reorder networks so last used config goes to the top again

		uci delete network.wlan
		uci set network.wlan=interface
		uci set network.wlan.proto=dhcp
		uci delete dhcp.wlan
		uci commit #commit changes
		/etc/init.d/network reload #reload network module so changes become effective
		echo "2|" > /tmp/networkstatus.txt
	fi
fi
