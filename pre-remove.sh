#!/bin/sh

[ -z "$$IPKG_INSTROOT" ] || { /etc/init.d/autowifi_init disable; }

exit 0
