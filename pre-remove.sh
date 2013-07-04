#!/bin/sh

if [ -z "$$IPKG_INSTROOT" ]; then
	/etc/init.d/autowifi_init disable
fi

exit 0
