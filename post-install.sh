########### NOTE: add an extra '$' in front of all existing ones when copying into Makefile (and remove this line...)


#!/bin/sh
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

@echo "Enabling wifi device..."
uci set wireless.@wifi-device[0].disabled=0; uci commit wireless; wifi

./add-fw-net.sh

@echo "Adding network interface 'wlan'..."
uci set network.wlan=interface; uci commit network; /etc/init.d/network reload
