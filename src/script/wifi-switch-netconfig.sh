#!/bin/sh

[ "${ACTION}" = "released" ] || exit 0

. /lib/functions.sh

count_networks() {
    local config="$1"
	logger $config
	count=$((count + 1))
	# run commands for every interface section
}
find_network() {
    local config="$1"
	succes=false
	#logger $(uci get wireless.$config.ssid)
	network_name=$(uci get wireless.$config.ssid)
	if [ ${network_name:0:8} != "Doodle3D" ]
	then
		logger "deleting network $network_name"
		uci delete wireless.$config
	else
		$succes=true
		logger "enabled $network_name"
		uci set wireless.$config.disabled=0
	fi
}

logger "$BUTTON pressed for $SEEN seconds"
if [ "$SEEN" -gt 4 ]
then
	#count number of networks
	config_load wireless
	config_foreach count_networks wifi-iface
	logger $count
	#if number of networks is less than 1 (or 1) do nothing
	if [ $count -gt 1 ]
	then
		logger "switching to AP"
		config_foreach find_network wifi-iface
		if [ $succes != false ]
		then
			logger "wireless somehow not found"
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

		uci commit #commit changes
		/etc/init.d/network reload #reload network module so changes become effective
		logger "setting status flag in /tmp/networkstatus.txt"
		echo "4|" > /tmp/networkstatus.txt
	fi
fi
