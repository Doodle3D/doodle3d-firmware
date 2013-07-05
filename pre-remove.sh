#!/bin/sh

if [ -z "$$IPKG_INSTROOT" ]; then
	/etc/init.d/wifibox_init disable
fi

exit 0
