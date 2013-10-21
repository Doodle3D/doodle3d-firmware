#!/bin/sh

# NOTE: this script generates an index based on images found in the target directory.
# So make sure it contains all images ever released (unless you want to actually remove them).
# If this is not the case, first create a mirror of doodle3d.com/updates/images.

#prevent being run as root (which is dangerous)
if [ "$(id -u)" == "0" ]; then
   echo "Don't run this script as root, it is potentially dangerous." 1>&2
   exit 1
fi


# expects path of file to return the size of
fileSize() {
	stat -f %z ${1}
}

# expects arguments: version, devType, sysupgrade|factory
# image name will be: '${IMAGE_BASENAME}-<version>-<devType>-<sysupgrade|factory>.bin'
constructImageName() {
	if [ $# -lt 3 ]; then echo "incorrect usage of constructImageName()"; exit 1; fi
	echo "${IMAGE_BASENAME}-${1}-${2}-${3}.bin"
}

# expects arguments: basePath (where the files are), version, devType
generateIndexEntry() {
	if [ $# -lt 3 ]; then echo "incorrect usage of generateIndexEntry()"; exit 1; fi

	sysupgrade_out_basename=`constructImageName ${2} ${3} sysupgrade`
	factory_out_basename=`constructImageName ${2} ${3} factory`
	sysupgrade_out_file=${1}/${sysupgrade_out_basename}
	factory_out_file=${1}/${factory_out_basename}

	sysupgrade_filesize=`fileSize ${sysupgrade_out_file}`
	factory_filesize=`fileSize ${factory_out_file}`
	sysupgrade_md5sum=`md5 -q ${sysupgrade_out_file}`
	factory_md5sum=`md5 -q ${factory_out_file}`
	echo "Version: ${2}" >> $IMG_INDEX_FILE
	echo "Files: ${sysupgrade_out_basename}; ${factory_out_basename}" >> $IMG_INDEX_FILE
	echo "FileSize: ${sysupgrade_filesize}; ${factory_filesize}" >> $IMG_INDEX_FILE
	echo "MD5: ${sysupgrade_md5sum}; ${factory_md5sum}" >> $IMG_INDEX_FILE
}


OPENWRT_BASE=.
PKG_SRC_DIR=$OPENWRT_BASE/bin/ar71xx/packages
PKG_DEST_SUBPATH=updates
MAKE_INDEX_SCRIPT=$OPENWRT_BASE/scripts/ipkg-make-index.sh
INDEX_FILE=Packages
INDEX_GZ_FILE=Packages.gz
DEVICE_TYPES="tl-mr3020 tl-wr703"
MAX_GOOD_IMAGE_SIZE=3500000
IMAGE_BASENAME="doodle3d-wifibox"

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


#determine the wifibox root path
my_rel_dir=`dirname $0`
pushd "$my_rel_dir" > /dev/null
WIFIBOX_DIR="`pwd`/../.."
popd > /dev/null

FW_VERSION=`cat $WIFIBOX_DIR/src/FIRMWARE-VERSION`
echo "Compiling firmware update files for version ${FW_VERSION}"


#setup paths
PKG_DEST_DIR=$PKG_DEST_BASE/$PKG_DEST_SUBPATH
PKG_FEED_DIR=$PKG_DEST_DIR/feed
PKG_IMG_DIR=$PKG_DEST_DIR/images
IMG_INDEX_FILE=$PKG_IMG_DIR/wifibox-image.index

if [ ! -d $PKG_DEST_DIR ]; then mkdir -p $PKG_DEST_DIR; fi
echo "Using $PKG_DEST_DIR as target directory"


#clear directory and copy package files
if [ ! -d $PKG_FEED_DIR ]; then mkdir $PKG_FEED_DIR; fi
cp $PKG_SRC_DIR/wifibox*.ipk $PKG_FEED_DIR
cp $PKG_SRC_DIR/ultifi*.ipk $PKG_FEED_DIR
cp $PKG_SRC_DIR/print3d*.ipk $PKG_FEED_DIR
rm -f $PKG_FEED_DIR/$INDEX_FILE
rm -f $PKG_FEED_DIR/$INDEX_GZ_FILE


#copy and rename images
if [ ! -d $PKG_IMG_DIR ]; then mkdir $PKG_IMG_DIR; fi
rm -f $IMG_INDEX_FILE
for devtype in $DEVICE_TYPES; do
	IMG_SRC_PATH=$OPENWRT_BASE/bin/ar71xx
	if [ -f $IMG_SRC_PATH/openwrt-ar71xx-generic-${devtype}-v1-squashfs-sysupgrade.bin ]; then
		sysupgrade_name=$IMG_SRC_PATH/openwrt-ar71xx-generic-${devtype}-v1-squashfs-sysupgrade.bin
		factory_name=$IMG_SRC_PATH/openwrt-ar71xx-generic-${devtype}-v1-squashfs-factory.bin
		sysupgrade_size=`fileSize $sysupgrade_name`
		factory_size=`fileSize $factory_name`

		echo "Copying images for device '${devtype}' (sysupgrade size: ${sysupgrade_size}, factory size: ${factory_size})"
		cp $sysupgrade_name $PKG_IMG_DIR/`constructImageName ${FW_VERSION} ${devtype} sysupgrade`
		cp $factory_name $PKG_IMG_DIR/`constructImageName ${FW_VERSION} ${devtype} factory`

		if [ $sysupgrade_size -gt $MAX_GOOD_IMAGE_SIZE ]; then
			echo "WARNING: the sysupgrade image is larger than $MAX_GOOD_IMAGE_SIZE bytes, which probably means it will cause read/write problems when flashed to a device"
		fi
	fi
done


# ok this is ugly, but at least it generates a complete index (the loop assumes for each
# sysupgrade image it finds, there is also a factory counterpart)
for file in $PKG_IMG_DIR/${IMAGE_BASENAME}-*-sysupgrade.bin; do
	basefile=`basename ${file}`
	echo "Considering $basefile (${file})"
	# sorry for the shell magic
	devtype=${basefile:`expr ${#IMAGE_BASENAME} + 1`}
	version=${devtype//-*}
	devtype=${devtype#*-}
	devtype=${devtype%-*}
	generateIndexEntry $PKG_IMG_DIR $version $devtype >> $IMG_INDEX_FILE
done


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
pushd $PKG_FEED_DIR > /dev/null
$OPENWRT_DIR/$MAKE_INDEX_SCRIPT . > $PKG_FEED_DIR/$INDEX_FILE
popd > /dev/null

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
