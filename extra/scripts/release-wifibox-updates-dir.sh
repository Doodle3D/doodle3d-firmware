#!/bin/sh

# This script copies the packages feed & images directory to ~/Sites (e.g. for use with XAMPP or the like).
# Using the -u option, it can also upload to doodle3d.com/updates (make sure ssh automatically uses the correct username, or change the rsync command below).
# Modify WIFIBOX_BASE_DIR to point to your wifibox directory tree.

WIFIBOX_BASE_DIR=~/Files/_devel/eclipse-workspace/doodle3d/doodle3d-firmware
DEST_DIR=~/public_html/wifibox
UPDATES_DIR=updates
BASE_URL=doodle3d.com

OPTIONS=$DEST_DIR
UPLOAD_FILES=0

for arg in "$@"; do
	case $arg in
		-h)
			echo "This script calls 'create-wifibox-updates-dir.sh' to generate feed/image directories in $DEST_DIR"
			echo "Use '-z' to also create a compressed file containing the 'updates' directory."
			echo "Used '-u' to also upload the directory to doodle3d.com/updates"
			exit
			;;
		-z)
			OPTIONS="$OPTIONS -z"
			;;
		-u)
			UPLOAD_FILES=1
			;;
		*)
			echo "Unrecognized option '$arg'"
			exit 1
			;;
	esac
done

$WIFIBOX_BASE_DIR/extra/scripts/create-wifibox-updates-dir.sh $OPTIONS
RETURN_VALUE=$?
if [ $RETURN_VALUE -ne 0 ]; then
	echo "create-wifibox-updates-dir.sh returned an error (${RETURN_VALUE}), exiting"
	exit $RETURN_VALUE
fi

if [ $UPLOAD_FILES -eq 1 ]; then
	#UPLOAD_PATH=$BASE_URL:public_html/updates
	UPLOAD_PATH=$BASE_URL:doodle3d.com/DEFAULT/updates

	cat <<-'EOM' > $DEST_DIR/$UPDATES_DIR/.htaccess
	Options +Indexes
EOM

	echo "Uploading files to $UPLOAD_PATH (if you are asked for your password, please add an entry to your ~/.ssh/config and upload your public ssh key)"
	#options are: recursive, preserve perms, symlinks and timestamps, be verbose and use compression
	rsync -rpltvz -e ssh --progress $DEST_DIR/$UPDATES_DIR/.htaccess $DEST_DIR/$UPDATES_DIR/* $UPLOAD_PATH
fi
