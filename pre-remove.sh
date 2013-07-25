#!/bin/sh

if [ -z "$$IPKG_INSTROOT" ]; then
	/etc/init.d/wifibox disable
fi

exit 0
