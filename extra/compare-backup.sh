#!/bin/sh

BACKUP_BASENAME=d3d-wifibox-backup
BACKUP_FILE=$BACKUP_BASENAME.tar.gz
REPO_PATH=../../src
BKP_PATH=$BACKUP_BASENAME/lua/autowifi

cd backup
tar xzvf $BACKUP_FILE
opendiff $REPO_PATH $BKP_PATH
