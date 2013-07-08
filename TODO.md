# TODO (new functionality)
 - save requested mod+func in request, as well as resolved function/pretty print version/function pointer (or subset…); then fix endpoint function name (when called with blank argument) in response objects to show pretty print name
 - fix init script handling as described here: http://wiki.openwrt.org/doc/devel/packages#packaging.a.service
 - write a simple client script to autotest as much of the api as possible  
   extend the client script to run arbitrary post/get requests 
 - document REST API (mention rq IDs and endpoint information, list endpoints+args+CRUD type, unknown values are empty fields)
   (describe fail/error difference: fail is valid rq..could not comply, while error is invalid rq _or_ system error)
 - use a slightly more descriptive success/error definition (e.g. errortype=system/missing-arg/generic)
 - steps to take regarding versioning/updating
   * versioning scheme
   * create feed location (e.g. www.doodle3d.com/firmware/packages) (see here: http://wiki.openwrt.org/doc/packages#third.party.packages)
   * create opkg (already present in bin/ar71xx/packages as .ipk file)
   * create listing info for package list (checksum, size, etc. ...is this inside the .ipk file?)
   * find a way to add the feed url to opkg.conf (directly in files during image building?)
   * determine how opkg decides what is 'upgradeable'
   * at this point manual updating should be possible, now find out how to implement in lua (execve? or write a minimalistic binding to libopkg?)
   * expose through info API and/or system API; also provide a way (future) to flash a new image
 - dynamic AP name based on partial MAC (set once on installation and then only upon explicit request? (e.g. api/config/wifiname/default))
 - require api functions which change state to be invoked as post request
 - add API functions to test network connectivity in steps (ifup? hasip? resolve? ping?) to network or test
 - add more config options to package, which should act as defaults for a config file on the system; candidates:  
   reconf.WWW_RENAME_NAME, wifihelper.{AP_ADDRESS, AP_NETMASK, (NET)}  
   <https://github.com/2ion/ini.lua>


# Ideas / issues to work out
 - generally, for configuration keys, it could be a good idea to use the concept of default values so it's always possible to return to a 'sane default config'
 - add system api module? with check-updates/do-update/etc
 - how to handle requests which need a restart of uhttpd? (e.g. network/openap)
 - a plain GET request (no ajax/script) runs the risk of timing out on lengthy operations: implement polling in API to get progress updates?
   (this would require those operations to run in a separate daemon process which can be monitored by the CGI handler)
   (!!!is this true? it could very well be caused by a uhttpd restart) 
 - licensing (also for hardware and firmware) + credits for external code and used ideas
  <http://www.codinghorror.com/blog/2007/04/pick-a-license-any-license.html>
 - (this is an old todo item from network:available(), might still be relevant at some point)
   extend netconf interface to support function arguments (as tables) so wifihelper functionality can be integrated
   but how? idea: pass x_args={arg1="a",arg2="2342"} for component 'x'
   or: allow alternative for x="y" --> x={action="y", arg1="a", arg2="2342"}
   in any case, arguments should be put in a new table to pass to the function (since order is undefined it must be an assoc array)
 - perhaps opkg+safeboot could be useful in the update mechanism?
 - add config option to compile sources using luac _or_ add an option to minify the lua code


# Bugs
 - in captive portal mode, https is not redirected
 - using iwinfo with interface name 'radio0' yields very little 'info' output while wlan0 works fine.
   However, sometimes wlan0 disappears (happened after trying to associate with non-existing network)...why?
 - protect dump function against reference loops (see <http://lua-users.org/wiki/TableSerialization>, json also handles this well)
 - relocatabilty of package (take root prefix into consideration everywhere)


# Logos

Check <http://geon.github.io/Programming/2012/04/25/ascii-art-signatures-in-the-wild/> for inspiration.


      D o o d l e 3 D
     --------      ____     .---  v 1.0.1
    |  |  |  | __ |  __|.--.| ._| .---..-.-.
    |  |  |  ||--||  _| |--||  . || . |\   /
    |________||__||__|  |__||____||___|/_._\


      D o o d l e 3 D
     --------     ____   .----  v 1.0.1
    |  |  |  |--.|  __|-.|  ._|---.-.-.
    |  |  |  |--||  _|--||  . | . |_ _/
    |________|__||__||__||____|___|_._\


    ....D o o d l e 3 D
    ...________     _____  _____  v 1.0.1 
    ../  /  /  |__ /  __/ /  - /___ __
    ./  '  '  /--//  _|-//  - | . /v /
    /________/__//__/__//____/___/_^_\
