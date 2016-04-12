#!/bin/sh

[ "${ACTION}" = "released" ] || exit 0

. /lib/functions.sh

logger "$BUTTON pressed for $SEEN seconds"
if [ "$SEEN" -gt 4 ]
then
  logger "Resetting Wireless"
  /usr/share/lua/wifibox/script/d3dapi p=/network/reset r=POST
fi
