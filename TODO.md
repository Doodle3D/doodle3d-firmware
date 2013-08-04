- chroma kleur
- size() mag alleen getallen voor export?
- fullscreen via osc

- animata
(- lijstje vakantie: spuitbus deo, kortingsbon Bever (tentje kopen?), Schotland pakken, andere tas ohm?)
(- issue aanmaken voor clementine:
 * mogelijk gerelateerd aan unicode (volgens lahwran op irc)
 * mogelijk gerelateerd: <http://code.google.com/p/clementine-player/issues/detail?id=1898&q=type%3DDefect%20crash&colspec=ID%20Type%20Status%20Priority%20Milestone%20Owner%20Summary%20Stars>
 * mp3 niet opnemen in issue maar aanbieden voor download op persoonlijke aanvraag
 * crash log: <http://pastebin.com/dbu9SS7Z>
 * bestand uit het album dat het wss veroorzaakt: <http://lsof.nl/temp/01%20Chemical%20Brothers%20-%20Come%20With%20Us.mp3>
)

## te doen voor werkend prototype (beta testers)
- (testen) server logging
- (testen/verder implementeren) stopknop
- volgorde chunks (en vaker voorkomen?): elke chunk naar los bestand en op het laatst samenvoegen
- (client) autopreheat wanneer er een printer aanwezig is
- (fw) temp gcode pad veranderen naar device-specifiek (i.e. /tmp/UltiFi/ttyACM?/combined.gc)
- (fw) bij (her)initialisatie printer altijd alle state weggooien (i.e. /dev/UtliFi/ttyACM?)
- client feedback
  * voor ontwikkeling: debugoverlay
  * vaker op 'print' drukken moet niet kunnen (knop disablen en op basis van polling (isPrinting?) status up-to-date houden)
    -> maar! de firmware moet geen nieuwe printopdrachten accepteren wanneer er al een print bezig is
  * temperatuurindicatie (alleen wanneer temperatuuruitlezing via api mogelijk is) -> dus ook indicatie van draaiende printserver
- (misschien?) verticale shape aanpassen
- preheaten voor het starten van een print
  * (fw) wachten op targettemperatuur - 20 graden (hoe om te gaan met afkoelen?)
  * (client) in config bij temperatuurinstelling: opmerking dat de printer gaat printen vanaf lagere temperatuur (bv. -20)

## te den voor final release 
- start/end-codes configureerbaar maken (via los endpoint) (duplicate)
- printerlijst opvragen
  * data: per printer: {id, path, type}
- gcode: printer busy rapporteren vanaf moment dat gcode wordt verzameld, niet pas bij begin printen (of gcode verzamelen per remote host?)
- op wiki over openwrt/osx svn checkout veranderen naar git clone
- image met alles erin
  * in postinst op kastje: ook wifibox start doen (enable doet dat niet) (ook voor ultifi)
  * firewall net wordt nog niet aangemaakt in 'Y'-mode
- nadenken over loggen (procedure voor testers hoe ze problemen kunnen rapporteren zodat wij ze kunnen reproduceren)
  * verzamelen+zippen van logread output (of uci system.@system[0].log_file?) + /tmp/wifibox.conf + printserver log
- na /network/disassociate is wifi uitgeschakeld -> kan geen macadres opvragen -> openap bv. 2x nodig om weer goed macadres te vinden
- client: netwerkkeuze toevoegen?
- herstart van uhttpd en reboot uitstellen tot na sturen van response (closure queue in response.lua)
- consistentie REST API
- code documenteren
- codedocs uitwerken naar apidocs
- optie voor loggen toevoegen aan printmanager
- AP en client tegelijk (VAP / multi-ssid?)
  * toegang altijd via AP, clientmode alleen voor updaten en internet ook via kastje (dan moet wel de portalmodus uit)
  * dns forward: list 'dhcp_option' '6,10.0.0.1,192.168.178.1' (<http://wiki.openwrt.org/doc/howto/dhcp.dnsmasq#configuring.dnsmasq.to.broadcast.external.dns.server.information>)
- auto-update (zowel package als geheel image; <- kijken hoe luci dat doet)
- serieel:
  * 115k2? -> Peter zei iets over instabiele connectie op 250k?
  * fallback lijkt niet te werken (zelfde probleem als bij poort opnieuw openen?)
  * mss helpt arduino reset triggeren om port opnieuw te kunnen openen?
  * 3e manier baudrate zetten? <http://stackoverflow.com/questions/4968529/how-to-set-baud-rate-to-307200-on-linux>
- initscript testen (lijkt vaker dan eens te worden uitgevoerd)
- printerExists: ook nagaan of basispad ultifi bestaat?


## NU MEE BEZIG
- in AP mode, things like 'somewhere.org/asdsfd' still results in 'Not found'
- behalve /dev/ttyACM* kan het voor FTDI dus ook /dev/ttyUSB* zijn
- config API: anders inrichten (misschien toch 1 key per keer instellen zodat response 'fail' kan zijn?)

- auto-update
  - source-url in Makefile aanpassen (type aanpassen naar git en dan direct naar github repo)
  - toevoegen aan /etc/opkg.conf via files in image: `src/gz wifibox http://doodle3d.com/static/wifibox-packages`
  - of lokaal: `src/gz wifibox file:///tmp/wifibox-packages`
  - (info) feed update-script: <wifibox_git_root>/extra/create-packages-dir.sh
    uitvoeren vanuit pad waar wifibox_packages terecht moet komen (bv. ~/Sites)
  - (info) package-url: <http://doodle3d.com/static/wifibox/packages>
  - (info) image-url: <http://doodle3d.com/static/wifibox/images>
  - later: printerprofielen
  
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
- in package postinst: hostname van kastje instellen op wifibox (met mac?)

- tijdens openwrt make:
  '* satisfy_dependencies_for: Cannot satisfy the following dependencies for kmod-ath9k-common:
  '*      kmod-crypto-hash *
- wiki bijwerken (links, structuur, API)
- ook in wiki, luadoc installeren:
  * !! (beter vervangen door?) <http://stevedonovan.github.io/ldoc/topics/doc.md.html>
  * ongeveer volgens <http://www.hobsie.com/mark/archives/33>, maar! :
  * luasocket apart installeren met `sudo luarocks install https://raw.github.com/diegonehab/luasocket/master/luasocket-scm-0.rockspec`
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
- over baud rates: <https://github.com/ErikZalm/Marlin/issues/205>
- versies toevoegen als eerste padelement?
- overig leesvoer
  * <https://github.com/stevedonovan/Penlight>


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
- openap vanuit assocmode gaf tenminste 1x nil in getMacAddress (daarna niet meer)


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















# CONFIG KEYS overzicht (wel/niet in firmware opgenomen)
--[[
	hop=0
?	minScale=.3
?	maxScale=1
	shape=%		-- one of: / | \ # $ % ^ *
?	twists=0
??	debug=false
??	loglevel=2
?	zOffset=0
-	server.port=8888
	autoLoadImage=hand.txt
	loadOffset=0,0
	showWarmUp=true
	loopAlways=false
	useSubpathColors=false
	maxObjectHeight=150
	maxScaleDifference=.1
	frameRate=60
	quitOnEscape=true
	screenToMillimeterScale=.3
	targetTemperature=230
	side.is3D=true
	side.visible=true
	side.bounds=900,210,131,390
	side.border=880,169,2,471
	checkTemperatureInterval=3
	autoWarmUpDelay=3
]]--

# voor volgende keer
- Greenhopper (Atlassian)? (en JIRA?)
  * <http://www.codinginahurry.com/categories/agile/>
- toch anders plannen, meer rekening houden met onvoorspelbaarheden (aka subtaken)
  * zie de 2 dagen voor geplande betarelease…dat lukte niet omdat er meer mankracht nodig was, veel dingen extra tijd kostten (bv gcode maken en sercomm), en eindeloos veel kleine 'hejadatmoetooknogeven'-dingen (die in de 'x2' van de planning moeten vallen maar eerder 'x5' oid lijken)…en dan nog blijft het documenteren liggen
- te weinig gedaan: daily standups -> planning aanpassen
- meer continuïteit nodig?
- meer tijd…
- duidelijker kunnen volgen wat gepland is en wat echt gebeurd (icm met standups)
