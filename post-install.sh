#!/bin/sh

### This function makes sure the 'wlan' net is in the 'lan' zone
addFirewallNet() {
	cfgChanged=0; zoneNum=-1; i=0

	while true; do
		name=`uci get firewall.@zone[$i].name 2>&1`
		exists=`echo "$name" | grep "Entry not found" >/dev/null 2>&1; echo $?`

		if [ $exists -eq 0 ]; then break; fi
		if [ "x$name" = "xlan" ]; then zoneNum=$i; fi

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


### Replace the banner with a custom one
if [ ! -f $IPKG_INSTROOT/etc/banner.default ]; then
	mv $IPKG_INSTROOT/etc/banner $IPKG_INSTROOT/etc/banner.default
	cat <<-'EOM' > $IPKG_INSTROOT/etc/banner
		........D o o d l e 3 D
		.......________     _____  _____  v \$(PACKAGE_VERSION)
		....../  /  /  |__ /  __/ /  - /___ __
		...../  /  /  /--//  _|-//  --| . /v /
		..../________/__//__/__//____/___/_^_\
		...
		..A cad in a box.
		.
EOM
fi

### Add some convenience aliases to root's profile
mkdir -p $IPKG_INSTROOT/root
grep '^# DO NOT MODIFY.*wifibox package.$' $IPKG_INSTROOT/root/.profile >/dev/null 2>&1
if [ $? -gt 0 ]; then
		cat <<-EOM >> $IPKG_INSTROOT/root/.profile

		# DO NOT MODIFY - this block of lines has been added by the wifibox package.
		alias d='ls -la'
		alias d3dapi='/usr/share/lua/wifibox/script/d3dapi'
		alias encore='ulimit -c unlimited'
		alias wopkg='opkg -f /usr/share/lua/wifibox/opkg.conf'

		loop() {
			if [ \$# -lt 2 ]; then echo "Please supply a delay and a command."; return 1; fi
			DELAY=\$1; shift; while true; do \$@; sleep \$DELAY; done
		}
EOM
fi

#preserve saved sketches during firmware update
echo "/root/sketches" >> /etc/sysupgrade.conf

### Finally make sure basic configuration is set correctly

$IPKG_INSTROOT/etc/init.d/wifibox enable
$IPKG_INSTROOT/etc/init.d/wifibox start

if [ -z "$IPKG_INSTROOT" ]; then
	echo "Enabling wifi device..."
	uci set wireless.@wifi-device[0].disabled=0; uci commit wireless; wifi

	addFirewallNet

	echo "Adding network interface 'wlan'..."
	uci set network.wlan=interface; uci commit network; /etc/init.d/network reload

else
	# Create a script to setup the system as wifibox, it will be deleted after it has been run, except if it returns > 0
	cat <<-EOM >> $IPKG_INSTROOT/etc/uci-defaults/setup-wifibox.sh
	uci set system.@system[0].hostname=wifibox
	uci set system.@system[0].log_size=64
	uci set network.lan.ipaddr=192.168.5.1
	echo -e "beta\nbeta" | passwd root

	uci set uhttpd.main.lua_handler='/usr/share/lua/wifibox/main.lua'
	uci set uhttpd.main.lua_prefix='/d3dapi'

	uci set wireless.@wifi-device[0].disabled=0
	# TODO: add firewall net
	uci set network.wlan=interface
EOM

	echo "WARNING: WiFiBox network configuration can only be fully prepared when installing on real device"
fi

exit 0
