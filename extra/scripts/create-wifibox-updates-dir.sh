#!/bin/sh

OPENWRT_BASE=.
PKG_SRC_DIR=$OPENWRT_BASE/bin/ar71xx/packages
PKG_DEST_SUBPATH=updates
MAKE_INDEX_SCRIPT=$OPENWRT_BASE/scripts/ipkg-make-index.sh
INDEX_FILE=Packages
INDEX_GZ_FILE=Packages.gz

COMPRESS_RESULT=0
PKG_DEST_BASE=.

for arg in "$@"; do
	case $arg in
		-h)
			echo "This script creates a directory with wifibox and ultifi ipk files found in the openWrt build environment."
			echo "The feed dir is called $PKG_DEST_DIR and will be created in the current directory. (currently `pwd`)"
			echo "If specified, the -z option also compresses the result for easier transfer to a webserver."
			exit
			;;
		-z)
			COMPRESS_RESULT=1
			;;
		-*)
			echo "Unrecognized option '$arg'"
			exit 1
			;;
		*)
			PKG_DEST_BASE=$arg
			;;
	esac
done

grep "^This is the buildsystem for the OpenWrt Linux distribution\.$" README >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Please run this script from the Openwrt build root (on OSX this is probably an image mounted under /Volumes)."
	exit 1
fi

#setup paths
PKG_DEST_DIR=$PKG_DEST_BASE/$PKG_DEST_SUBPATH
PKG_FEED_DIR=$PKG_DEST_DIR/feed
PKG_IMG_DIR=$PKG_DEST_DIR/images
if [ ! -d $PKG_DEST_DIR ]; then mkdir -p $PKG_DEST_DIR; fi
echo "Using $PKG_DEST_DIR as target directory"


#clear directory and copy package files
if [ ! -d $PKG_FEED_DIR ]; then mkdir $PKG_FEED_DIR; fi
cp $PKG_SRC_DIR/wifibox*.ipk $PKG_FEED_DIR
cp $PKG_SRC_DIR/ultifi*.ipk $PKG_FEED_DIR
cp $PKG_SRC_DIR/print3d*.ipk $PKG_FEED_DIR
rm -f $PKG_FEED_DIR/$INDEX_FILE
rm -f $PKG_FEED_DIR/$INDEX_GZ_FILE


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

#this cwd juggling is required to have the package indexer generate correct paths (i.e. no paths) in the Packages file
OPENWRT_DIR=`pwd`
pushd $PKG_FEED_DIR
$OPENWRT_DIR/$MAKE_INDEX_SCRIPT . > $PKG_FEED_DIR/$INDEX_FILE
popd

if [ $MD5_HACK_ENABLED -eq 1 ]; then
	rm $TEMPBIN_DIR/md5sum
	rmdir $TEMPBIN_DIR
fi

gzip -c $PKG_FEED_DIR/$INDEX_FILE > $PKG_FEED_DIR/$INDEX_GZ_FILE


if [ $COMPRESS_RESULT -eq 1 ]; then
	cd $PKG_DEST_BASE
	echo "Compressing generated package directory..."
	tar czvf "doodle3d-wifibox-update-dist.tgz" $PKG_DEST_SUBPATH
fi
