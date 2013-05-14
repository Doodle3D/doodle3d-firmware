#!/bin/sh

cfgChanged=0; zoneNum=-1; i=0

while true; do
	name=`uci get firewall.@zone[$i].name 2>&1`
	exists=`echo "$name" | grep "Entry not found" >/dev/null 2>&1; echo $?`
	
	if [ $exists -eq 0 ]; then break; fi
	if [ $name = "lan" ]; then zoneNum=$i; fi
	
	i=`expr $i + 1`
done

if [ $zoneNum -gt -1 ]; then
	network=`uci get firewall.@zone[$zoneNum].network 2>&1`
	hasWlan=`echo $network | grep "wlan" >/dev/null 2>&1; echo $?`
	if [ $hasWlan -eq 1 ]; then
		uci set firewall.@zone[$zoneNum].network="lan wlan"
		uci commit firewall
		/etc/init.d/dnsmasq reload
		cfgChanged=1
	fi
fi

if [ $cfgChanged -eq 1 ]; then
	echo "Added network 'wlan' to zone lan"
else
	echo "Firewall configuration not changed"
fi
