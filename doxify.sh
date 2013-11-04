#!/bin/sh

# Generate Lua source code documentation using ldoc. Change LDOC to the path of your luadoc executable and change WIFIBOX_BASE_DIR to the location of your wifibox source tree, or "." if you really want a relative output directory.
# All given options are forwarded to ldoc, -a is already being passed by default.

LDOC=/opt/local/share/luarocks/bin/ldoc
WIFIBOX_BASE_DIR=~/Files/_devel/eclipse-workspace/wifibox

HTML_PATH=$WIFIBOX_BASE_DIR/docs
SRC_DIR=$WIFIBOX_BASE_DIR/src
FILESPEC=$WIFIBOX_BASE_DIR/src #replace by config.ld so we can also specify README.md?

LUA_VERSION=`lua -v 2>&1 | awk -F" " '{print $2}'`

echo $LUA_VERSION | grep -q "^5.2"
if [ $? -ne 0 ]; then
	echo "Lua 5.2 is needed to run this script (as well as luarocks), you have $LUA_VERSION."
	exit 1
fi

#$LDOC -d $HTML_PATH $FILESPEC -a -f markdown $@
$LDOC .

if [ $? -eq 127 ]; then
	echo "$0: It looks like the ldoc program could not be found, please configure the LDOC variable correctly and make sure ldoc is installed on your system."
	echo "$0: By default, this script expects ldoc has been installed with luarocks on OSX, which in turn is installed with macports."
fi
