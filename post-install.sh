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
	cat <<-\EOM > $IPKG_INSTROOT/etc/banner
		,------.                   ,--.,--.       ,----. ,------.
		|  .-.  \  ,---.  ,---.  ,-|  ||  | ,---. '.-.  ||  .-.  \
		|  |  \  :| .-. || .-. |' .-. ||  || .-. :  .' < |  |  \  :
		|  '--'  /' '-' '' '-' '\ `-' ||  |\   --./'-'  ||  '--'  /
		`-------'  `---'  `---'  `---' `--' `----'`----' `-------'
		__          ___ ______ _        ____
		 \ \        / (_)  ____(_)      |  _ \
		  \ \  /\  / / _| |__   _ ______| |_) | _____  __
		   \ \/  \/ / | |  __| | |______|  _ < / _ \ \/ /
		    \  /\  /  | | |    | |      | |_) | (_) >  <
		     \/  \/   |_|_|    |_|      |____/ \___/_/\_\
EOM
fi

### Add some convenience aliases to root's profile
mkdir -p $IPKG_INSTROOT/root
grep '^# DO NOT MODIFY.*wifibox package.$' $IPKG_INSTROOT/root/.profile >/dev/null 2>&1
if [ $? -gt 0 ]; then
	cat <<-\EOM >> $IPKG_INSTROOT/root/.profile
		# DO NOT MODIFY - this block of lines has been added by the wifibox package.
		alias d='ls -la'
		alias encore='ulimit -c unlimited'
		alias wopkg='opkg -f /usr/share/lua/wifibox/opkg.conf'

		alias tailfw='loglite /tmp/wifibox.log firmware'
		tailp3d() {
		  logfile=/tmp/print3d-ttyACM0.log
		  if [ $# -gt 0 ]; then logfile=$1; fi
		  loglite "$logfile" print3d
		}

		loop() {
		  if [ $# -lt 2 ]; then echo "Please supply a delay and a command."; return 1; fi
		  DELAY=$1; shift; while true; do $@; sleep $DELAY; done
		}
EOM
fi

#preserve saved sketches during firmware update
echo "/root/sketches" >> $IPKG_INSTROOT/etc/sysupgrade.conf



### Finally make sure basic configuration is set correctly

LOGROTATE_CRON_LINE="*/2 *   *   *   *   /usr/sbin/logrotate /etc/logrotate.conf"

if [ -z "$IPKG_INSTROOT" ]; then
	# No installation root, we are being installed on a live box so run uci commands directly.

	echo "Enabling and configuring wifi device..."
	uci set wireless.@wifi-device[0].disabled=0
	uci delete wireless.radio0.channel
	uci commit wireless; wifi

	echo "Disabling default route and DNS server for lan network interface..."
	uci set dhcp.lan.dhcp_option='3 6'
	uci commit dhcp; /etc/init.d/dnsmasq reload

	addFirewallNet

	echo "Adding network interface 'wlan'..."
	uci set network.wlan=interface
	uci commit network; /etc/init.d/network reload

	echo "Setting default wifibox log level..."
	uci set wifibox.general.system_log_level='info'
	uci -q delete wifibox.system.loglevel  # remove key used in older versions (<=0.10.8a) if it exists
	uci commit wifibox

	crontab -l 2> /dev/null | grep logrotate\.conf > /dev/null
	if [ $? -ne 0 ]; then
		# add line, method from http://askubuntu.com/a/58582
		# Note: `crontab -l` will throw an error to stderr because the file does not exist, but that does not matter
		(crontab -l 2> /dev/null; echo "$LOGROTATE_CRON_LINE" ) | crontab -
	fi

else
	# Create a script to setup the system as wifibox, it will be deleted after it has been run, except if it returns > 0.

	cat <<-EOM >> $IPKG_INSTROOT/etc/uci-defaults/setup-wifibox.sh
	uci set system.@system[0].hostname=wifibox
	uci set system.@system[0].log_size=64
	uci set network.lan.ipaddr=192.168.5.1
	echo -e "beta\nbeta" | passwd root

	# uhttpd config: https://wiki.openwrt.org/doc/uci/uhttpd#server_settings
	uci set uhttpd.main.lua_handler='/usr/share/lua/wifibox/main.lua'
	uci set uhttpd.main.lua_prefix='/d3dapi'
	uci set uhttpd.main.max_requests='10'

	uci set wireless.@wifi-device[0].disabled=0
	uci delete wireless.radio0.channel
	# TODO: add firewall net
	uci set network.wlan=interface

	uci set dhcp.lan.dhcp_option='3 6'

	uci set wifibox.general.system_log_level='info'
	uci -q delete wifibox.system.loglevel  # remove key used in older versions (<=0.10.8a) if it exists

	# update wifibox's config for config changes in 0.10.10
	uci set wifibox.system.log_path='/tmp'
	uci set wifibox.system.api_log_filename='wifibox.log'
	uci set wifibox.system.p3d_log_basename='print3d'

	crontab -l 2> /dev/null | grep logrotate\.conf > /dev/null
	if [ $? -ne 0 ]; then
		# add line, method from http://askubuntu.com/a/58582
		# Note: `crontab -l` will throw an error to stderr because the file does not exist, but that does not matter
		(crontab -l 2> /dev/null; echo "$LOGROTATE_CRON_LINE" ) | crontab -
	fi

	exit 0
EOM

	echo "WARNING: WiFiBox network configuration can only be fully prepared when installing on real device"
fi

$IPKG_INSTROOT/etc/init.d/wifibox enable
$IPKG_INSTROOT/etc/init.d/wifibox start
$IPKG_INSTROOT/etc/init.d/dhcpcheck enable
$IPKG_INSTROOT/etc/init.d/cron enable
$IPKG_INSTROOT/etc/init.d/cron start

exit 0
