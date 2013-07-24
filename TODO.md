## te doen voor werkend prototype
- auto-update (zowel package als geheel image; <- kijken hoe luci dat doet)
- tekenen op redelijke subset van apparaten (wat hebben beta-testers?)
- printen (printserver; via dirpad gcode/commando's sturen en uitlezen via voortgangsbestand; zoals UltiFi; REST reageert op rq met poll-url in data waar voortgang te volgen is…eindigt met 'done')

## NU MEE BEZIG
- auto-update
  - source-url in Makefile aanpassen (type aanpassen naar git en dan direct naar github repo)
  - toevoegen aan /etc/opkg.conf via files in image: `src/gz wifibox http://doodle3d.com/static/wifibox-packages`
  - of lokaal: `src/gz wifibox file:///tmp/wifibox-packages`
  - (info) feed update-script: /Volumes/openwrt-image-10gb/update-feed-dir.sh
  - (info) package-url: <http://doodle3d.com/static/wifibox-packages>
  - (info) image-url: <http://doodle3d.com/static/wifibox-images>
  
  - API:
  api/info/currentVersion
  api/info/latestVersion [beta=true]
  api/system/update
  api/system/flash
  * wat als wij een verkeerd package releasen waardoor de API niet meer werkt?
  
  - (ref) <http://wiki.openwrt.org/doc/devel/packages/opkg>
  - (ref) <http://wiki.openwrt.org/doc/techref/opkg>
  - (ref) <http://downloads.openwrt.org/snapshots/trunk/ar71xx/packages/>
- waar moeten debugvlaggen etc naartoe? (run_flags.lua?)
- require vars checken op conflicten
- in package postinst: hostname van kastje instellen op wifibox (met mac?)

- wiki bijwerken (links, structuur, API)
- Code documenteren <http://keplerproject.github.io/luadoc/>
- Lua programmeerstijl? (enkele quotes gebruiken behalve voor i18n)
- zoals het nu werkt wordt het lastig om een hiërarchische api te ondersteunen zoals dit: <http://www.restapitutorial.com/lessons/restfulresourcenaming.html>
- uhttpd ondersteunt geen PUT en DELETE, wel status codes. Beschrijving CGI-antwoorden: <http://docstore.mik.ua/orelly/linux/cgi/ch03_03.htm>
- voor captive portal: cgi 'Location' header voor redirect naar goede url?

- http statuscodes <https://blog.apigee.com/detail/restful_api_design_what_about_errors>; met relevante link in antwoord (meer: <https://blog.apigee.com/taglist/restful>)
- proposed status handling in response.lua:
  fucntion setStatus(code, <msg>) -> sets http status+dfl msg and optional errmsg in data

## lokale notities
- in menuconfig: enabled uhttpd-mod-lua, disabled uhttpd-mod-ubus
- menuconfig: disable Network->6relayd and Network->odhcp6c
  then disable Kernel modules->Network support->kmod ipv6
- menuconfig: disable Network->ppp, then disable Kernel modules->Network support->kmod-{ppp,pppoe,pppox}
- menuconfig: enabled Kernel Modules -> USB Support -> usb-kmod-serial -> …ftdi
- enabled luafilesystem, luasocket (luaposix results in a build error)
- <http://stackoverflow.com/questions/11732934/serial-connection-with-arduino-php-openwrt-bug>

- versies toevoegen als eerste padelement?


# TODO (new functionality)
 - fix init script handling as described here: http://wiki.openwrt.org/doc/devel/packages#packaging.a.service
 - implement (automated) test code where possible
   * in 'test' dir next to 'src', with API tests under 'test/www/'
   * www tests check functionality of the test module
   * www tests also provide an interface to run arbitrary get/post requests
   * test path splitting as well
 - document REST API
   * fail/error difference: fail is a valid rq aka 'could not comply', while error is invalid rq _or_ system error
   * modules/functions prefixed with '_' are for internal use
   * rq IDs and endpoint information can be supplied (but it's probably not useful after all)
   * list endpoints+args+CRUD type
   * success/fail/error statuses are justified by drupal api
   * unknown values (e.g. in network info) are either empty or unmentioned fields
 - define a list of REST error codes to be more descriptive for clients (e.g. errortype=system/missing-arg/generic)
 - steps to take regarding versioning/updating
   * versioning scheme
   * create feed location (e.g. www.doodle3d.com/firmware/packages) (see here: http://wiki.openwrt.org/doc/packages#third.party.packages)
   * create opkg (already present in bin/ar71xx/packages as .ipk file)
   * create listing info for package list (checksum, size, etc. ...is this inside the .ipk file?)
   * find a way to add the feed url to opkg.conf (directly in files during image building?)
   * determine how opkg decides what is 'upgradeable'
   * at this point manual updating should be possible, now find out how to implement in lua (execve? or write a minimalistic binding to libopkg?)
   * expose through info API and/or system API; also provide a way (future) to flash a new image
 - generally, for configuration keys, it could be a good idea to use the concept of default values so it's always possible to return to a 'sane default config'
   * use a uci wifibox config to store configuration and a uci wifibox-defaults config as fallback-lookup (which contains a complete default configuration)
   * specify min/max/type/regex for each config key in separate lua file
   * perhaps defaults should be specified together with min/max/type/regex
 - dynamic AP name based on partial MAC (present in default config so it can be overridden and reverted again)
 - require api functions which change state to be invoked as post request
  * can this be modelled like java annotations or c function attributes?
  * otherwise maybe pair each function with <func>_attribs = {…}?
 - add API functions to test network connectivity in steps (any chance(e.g. ~ap)? ifup? hasip? resolve? ping?) to network or test
 - handling requests which need a restart of uhttpd (e.g. network/openap) will probably respond with some kind of 'please check back in a few seconds' response
 - add more config options to package, which should act as defaults for a config file on the system; candidates:  
   reconf.WWW_RENAME_NAME, wifihelper.{AP_ADDRESS, AP_NETMASK, (NET)}  
   <https://github.com/2ion/ini.lua>


# Ideas / issues to work out
 - add system api module? for check-updates/do-update/etc
 - licensing (also for hardware and firmware) + credits for external code and used ideas (<http://www.codinghorror.com/blog/2007/04/pick-a-license-any-license.html>)
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
