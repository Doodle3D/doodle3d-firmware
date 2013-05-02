#!/bin/sh

##############
# MAIN CODE #
############

if [ ! -f /etc/banner.default ]; then
	mv /etc/banner /etc/banner.default
	cat <<-'EOM' > /etc/banner
		........D o o d l e 3 D
		.......________     _____  _____  v $(PACKAGE_VERSION) 
		....../  /  /  |__ /  __/ /  - /___ __
		...../  /  /  /--//  _|-//  - | . /- /
		..../________/__//__/__//____/___/_-_\
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

#3. make sure the radio0 interface is enabled in /etc/config/wireless (preferably through uci)
#4. make sure the wlan net is in the lan zone in /etc/config/dnsmasq (and make sure wlan net exists?)
