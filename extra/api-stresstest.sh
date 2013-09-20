#!/bin/sh

# TODO
# - have wget run POST requests
# - 'gcode' posten?
# - try to reproduce client behaviour more closely? (currently uhttpd is not exhibiting the strange behaviour)
# - shorter timeouts
# - add threading/subprocess-spawning?
# -? http://www.unix.com/shell-programming-scripting/36030-time-command-usage-sh-script.html
# - more wget options:
#   * '-O <file>' or -O - to check response content?
#   * -S to show server response headers
#   * -T n to set all timeouts

WIFIBOX_IP=192.168.5.1
#WIFIBOX_IP=192.168.10.1
#API_BASE=$WIFIBOX_IP/d3dapi
API_BASE=$WIFIBOX_IP/cgi-bin/d3dapi
WGET=wget
#REQUEST_PATH=network/status
REQUEST_PATH=printer/print
#POST_PARMS=--post-data=xyzzy
POST_PARMS=--post-file=200k.gcode

RETRIES=1

counter=0

while true; do
	#$WGET -q -O - $POST_PARMS -t $RETRIES $API_BASE/$REQUEST_PATH 2>&1 >/dev/null
	$WGET -q -O - $POST_PARMS -t $RETRIES $API_BASE/$REQUEST_PATH 2>&1 >/dev/null
	#check $? (and time spent?)
	#print line every 100 counts or when a timeout/error occurs?

	if [ $? -gt 0 ]; then
		echo "response error at counter: $counter"
	fi

	if [ `expr $counter % 25` -eq 0 ]; then
		echo "counter: $counter"
	fi

	counter=`expr $counter + 1`
done
