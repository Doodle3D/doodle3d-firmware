WiFi box OpenWRT firmware package
=================================

General documentation can be found on the wiki: <http://doodle3d.com/help/wiki>. Source code documentation can be generated, see below.

Documentation
-------------

The script 'doxify.sh' generates HTML documentation of the source code in the directory 'docs'.
Make sure the 'ldoc' program is installed on your machine and the LDOC variable in the script points there.

On OSX, this can be accomplished by installing it through luarocks (run `sudo luarocks install ldoc`). Luarocks can be installed using [MacPorts](http://www.macports.org/). After installing that, the command would be `sudo port install luarocks`.


Command line interface
----------------------
The Doodle3D API can be called using a terminal: 

```d3dapi p=/network/scan r=GET```

Where the p parameter is the module you want to call and r is the method.
Post request can be send using the same method:

```d3dapi p=/printer/print r=POST```

Parameters: TODO
