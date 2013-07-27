#!/bin/sh

# This script is merely for conveniently generating the packages feed directory in ~/Sites (e.g. for use with XAMPP or the like). Modify WIFIBOX_BASE_DIR to point to your wifibox directory tree.

WIFIBOX_BASE_DIR=~/Files/_devel/eclipse-workspace/wifibox

cd ~/Sites
$WIFIBOX_BASE_DIR/extra/scripts/create-packages-feed-dir.sh
