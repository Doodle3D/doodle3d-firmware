#!/bin/sh

addFirewallNet() {
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
		echo "Added network 'wlan' to zone lan."
	else
		echo "Firewall configuration not changed."
	fi
}


if [ ! -f /etc/banner.default ]; then
	mv /etc/banner /etc/banner.default
	cat <<-'EOM' > /etc/banner
		........D o o d l e 3 D
		.......________     _____  _____  v $(PACKAGE_VERSION) 
		....../  /  /  |__ /  __/ /  - /___ __
		...../  /  /  /--//  _|-//  --| . /v /
		..../________/__//__/__//____/___/_^_\\
		...
		..A cad in a box.
		.
EOM
fi

grep '^# DO NOT MODIFY.*wifibox package.$' /root/.profile >/dev/null 2>&1
if [ $? -eq 1 ]; then
		cat <<-EOM >> /root/.profile
		
		# DO NOT MODIFY - this block of lines has been added by the wifibox package.
		alias wfcfr='/usr/share/lua/autowifi/ext/wfcf'
		alias encore='ulimit -c unlimited'
EOM
fi

echo "Enabling wifi device..."
uci set wireless.@wifi-device[0].disabled=0; uci commit wireless; wifi

addFirewallNet

echo "Adding network interface 'wlan'..."
uci set network.wlan=interface; uci commit network; /etc/init.d/network reload
