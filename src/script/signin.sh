#!/bin/sh
# This file is part of the Doodle3D project (http://doodle3d.com).
#
# Copyright (c) 2013, Doodle3D
# This software is licensed under the terms of the GNU GPL v2 or later.
# See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.

sleep 15m
while true; do 
	/usr/share/lua/wifibox/script/d3dapi signin > /dev/null 2> /dev/null
	
	sleep 15m
done
