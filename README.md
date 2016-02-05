WiFi box OpenWRT firmware package
=================================

General documentation can be found on the wiki: <http://doodle3d.com/help/wiki>. Source code documentation can be generated, see below.

Documentation
-------------

The script 'doxify.sh' generates HTML documentation of the source code in the directory 'docs'.
Make sure the 'ldoc' program is installed on your machine and the LDOC variable in the script points there.

On OSX, this can be accomplished by installing it through luarocks (run `sudo luarocks install ldoc`). Luarocks can be installed using [MacPorts](http://www.macports.org/). After installing that, the command would be `sudo port install luarocks`.


Debugging Lua
-------------

Syntax errors in Lua can lead to tricky issues since they might only surface when the faulty code is actually being run.

One countermeasure for this is to use [pcall](http://www.lua.org/pil/8.4.html) instead of regular calls in many cases. To let the error 'happen' (which in turn gives information in the form of stack traces), tell the code to use regular calls by setting 'M.DEBUG_PCALLS' to 'true' in `conf_defaults.lua`.

A second way of debugging is to take uhttpd out of the loop and invoke the Lua code from command-line. To do this, set 'M.DEBUG_API' to 'true' in `conf_defaults.lua`. Then invoke the API using the command `d3dapi p=/mod/func r=POST` where `p=` is followed by the API path and `r=` followed by either 'GET' or 'POST'.
Be aware though, that this script redirects output streams to a fallback log file where stack traces will end up, this file is `/tmp/wifibox.cgi-fallback.log`.
