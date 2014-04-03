#!/bin/sh

# This script generates a file feeds.conf and places it in the OpenWrt buildroot directory.
# It deduces the location of your Doodle3D feed by looking at its own path and,
# on OSX, tries to find the OpenWrt buildroot by looking for something mounted in a
# directory containing the word 'openwrt'; specify the path with -p <path> if that fails.

SYSNAME=`uname -s`
WRT_PATH=
FEED_PATH=
PACKAGES_FEED_SHA5=e5f758e0729d094441aad849bbab4117b816567d

nextIsWrtPath=0
for arg in "$@"; do
	if [ $nextIsWrtPath -eq 1 ]; then
		WRT_PATH="$arg"
		nextIsWrtPath=0
		continue
	fi

	case "$arg" in
	-p)
		nextIsWrtPath=1
		;;
	-h)
		echo "This script generates an OpenWrt feeds.conf file for building Doodle3D, it works automatically."
		echo "If the wrt buildroot path cannot be determined, specify it using '-p <path>'."
		echo "If you want the file contents to be shown instead of written out to a file, use '-c'."
		exit 0
		;;
	*)
		echo "! Error: unknown argument '$arg' found"
		exit 1
		;;
	esac
done
if [ $nextIsWrtPath -eq 1 ]; then
	echo "! Error: missing argument for -p option"
	exit 1
fi


if [ "x$WRT_PATH" = "x" ]; then
	if [ "x$SYSNAME" != "xDarwin" ]; then
		echo "! Error: it looks like you are not using OSX, please specify the OpenWrt buildroot path with '-p <path>'."
		exit 1

	elif [ "x$SYSNAME" = "xDarwin" ]; then
		mountPath=`mount | sed -n 's|^.* \([^ ]*[Oo][Pp][Ee][Nn][Ww][Rr][Tt][^ ]*\).*$|\1|p'`
		if [ -z "$mountPath" ]; then
			echo "! Error: could not find openwrt-like path in list of mount points."
			echo "! Please mount the image an rerun, or specify the path using '-p <path>'."
			exit 2
		fi

		# Looking for the word 'openwrt' in a README file in a direct subdir...is this a reasonable 'detect' approach?
		for i in $(ls -d $mountPath/*/); do
			dirname=${i%%/}
			grep -sqi openwrt "$dirname/README"
			if [ $? -eq 0 ]; then
				WRT_PATH="$dirname"
			fi
		done

		if [ -z "$WRT_PATH" ]; then
			echo "! Error: could not find buildroot path in what looks like an OpenWrt image ('$mountPath'), please rerun with '-p <path>'."
			exit 3
		fi
	fi
fi


echo "===== Doodle3D OpenWrt feeds.conf generator"
echo "* Using OpenWrt buildroot path: '$WRT_PATH'"

FEED_PATH="$0"
FEED_PATH=`dirname "$FEED_PATH"` # Ok, so after this we've got a non-normalized path to the script dir
FEED_PATH="$FEED_PATH/../../.." # go back to just outside the doodle3d-firmware repo, which should be the feed root

echo "$FEED_PATH" | grep -sq "^\/"
if [ $? -ne 0 ]; then FEED_PATH="`pwd`/$FEED_PATH"; fi

#NOTE: and normalize the path...this method feels a bit fragile (spurious output, special user env conditions and whatnot)
pushd "$FEED_PATH" > /dev/null 2>&1
FEED_PATH="`pwd`"
popd > /dev/null 2>&1

echo "* Using Doodle3D feed path: '$FEED_PATH'"

echo "$FEED_PATH" | grep -sq ' '
if [ $? -eq 0 ]; then
	echo "! Error: the feed path contains spaces, which OpenWrt cannot handle. Exiting..."
	exit 4
fi

FILE_CONTENTS=$( cat << EOT
src-git packages git://git.openwrt.org/packages.git^$PACKAGES_FEED_SHA5
src-link wifibox $FEED_PATH
EOT
)

echo "* Contents to be written:\n$FILE_CONTENTS\n"

while true; do
	read -p "? Proceed to write a new feeds.conf? " yn
    case $yn in
        [Yy]*) break;;
        [Nn]*)
			echo "* Ok, feeds.conf will not be generated. Exiting..."
			exit 0;;
		*) echo "! Please answer yes or no.";;
    esac
done

OUT_PATH="$WRT_PATH/feeds.conf"
BKP_PATH="$WRT_PATH/feeds.conf.d3dbkp"
if [ -f "$OUT_PATH" ]; then
	echo "* Backing up $OUT_PATH to $BKP_PATH"
	cp "$OUT_PATH" "$BKP_PATH"
fi

echo "* Generating $OUT_PATH"
echo "$FILE_CONTENTS" > "$OUT_PATH"

exit 0
