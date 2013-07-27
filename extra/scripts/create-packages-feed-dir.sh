#!/bin/sh

OPENWRT_BASE=/Volumes/openwrt-image-10gb/openwrt
PKG_SRC_DIR=$OPENWRT_BASE/bin/ar71xx/packages
PKG_DEST_DIR=wifibox-packages
MAKE_INDEX_SCRIPT=$OPENWRT_BASE/scripts/ipkg-make-index.sh
INDEX_FILE=Packages
INDEX_GZ_FILE=Packages.gz

if [ "x$1" == "x-h" ]; then
	echo "This script creates a directory with wifibox and ultifi ipk files found in the openWrt build environment. The feed dir is called $PKG_DEST_DIR and will be created in the current directory. (currently `pwd`)"
	echo "If specified, the -z option also compresses the result for easier transfer to a webserver."
	exit
fi

if [ ! -d $PKG_DEST_DIR ]; then mkdir $PKG_DEST_DIR; fi
cp $PKG_SRC_DIR/wifibox*.ipk $PKG_DEST_DIR
cp $PKG_SRC_DIR/ultifi*.ipk $PKG_DEST_DIR
cd $PKG_DEST_DIR
rm -f $INDEX_FILE
rm -f $INDEX_GZ_FILE


# NOTE: the aliasing construct in the indexing script does not work (and even then, the md5 command defaults to a different output format), so we hack around it here.
MD5_HACK_ENABLED=0
which md5sum >/dev/null 2>&1
if [ $? -eq 1 ]; then
	MD5_HACK_ENABLED=1
	TEMPBIN_DIR=/tmp/tempbin23QQDBR
	mkdir $TEMPBIN_DIR

	cat <<EOF > $TEMPBIN_DIR/md5sum
`type -p md5` -q \$1
EOF

	chmod +x $TEMPBIN_DIR/md5sum
	PATH=$PATH:$TEMPBIN_DIR
fi

$MAKE_INDEX_SCRIPT . > $INDEX_FILE

if [ $MD5_HACK_ENABLED -eq 1 ]; then
	rm $TEMPBIN_DIR/md5sum
	rmdir $TEMPBIN_DIR
fi


gzip -c $INDEX_FILE > $INDEX_GZ_FILE

if [ "x$1" == "x-z" ]; then
	cd ..
	echo "Compressing generated package directory..."
	tar czvf $PKG_DEST_DIR.tgz $PKG_DEST_DIR
fi
