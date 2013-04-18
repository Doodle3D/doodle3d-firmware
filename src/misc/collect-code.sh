#!/bin/sh

BASE_NAME=d3d-wifibox-backup
SRC_PATHS="/etc /root /www/ /usr/share/lua"
TEMP_DIR=/tmp
TGT_FILE=$BASE_NAME.tar.gz

if [ -e /www-external ]; then
	echo "ERROR: switch back /www-regular to /www before running this script"
	exit 1
fi

cd $TEMP_DIR
if [ $? != 0 ]; then
	echo "ERROR: could not cd to temporary directory ($TEMP_DIR)"
	exit 2
fi

TGT_DIR=$TEMP_DIR/$BASE_NAME
rm -rf $TGT_DIR
mkdir -p $TGT_DIR

for path in $SRC_PATHS; do
	echo "copying $path -> $TGT_DIR..."
	cp -a $path $TGT_DIR
done

echo "compressing $TGT_DIR into $BASE_NAME.tar.gz..."
tar czf $BASE_NAME.tar.gz $BASE_NAME

echo "removing staging dir..."
rm -rf $TGT_DIR

echo "done."
