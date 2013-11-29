WiFi box OpenWRT firmware package
=================================

General documentation can be found on the wiki: <http://doodle3d.com/help/wiki>. Source code documentation can be generated, see below.

Documentation
-------------

The script 'doxify.sh' generates HTML documentation of the source code in the directory 'docs'.
Make sure the 'ldoc' program is installed on your machine and the LDOC variable in the script points there.

On OSX, this can be accomplished by installing it through luarocks (run `sudo luarocks install ldoc`). Luarocks can be installed using [MacPorts](http://www.macports.org/). After installing that, the command would be `sudo port install luarocks`.
