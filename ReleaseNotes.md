Changelog
# 0.11.0-a
- WiFi-Box can now 'fetch' a gcode-file in chunks from a server.
- Added support for the Renkforce RF100 printer. 

# 0.10.12
# 0.10.12-b (12 jan 2017)
- Post install update to config for changes in 0.10.10 (fixes print3d logging)

# 0.10.12-a (26 jul 2016)
- Added Ultimaker Original Plus (Thanks Remco)
- Added extra usb drivers

# 0.10.11
# 0.10.11-a (25 may 2016)
- After pressing the reset button for about 4 seconds the WiFi-Box will go to access point mode. Useful for when you can't reach it.
- Becomes access point when it can't connect to WiFi network.
- Handles more clients by tweaking the uhttpd config.
- Print3D isn't killed when there is no memory available.
- New banner (shown after ssh login)
- Ultimaker 2 type printers show status information on display.

# 0.10.10 (11 may 2016)
- Logging client version info to console.  
- Logging less when printing to makerbot/wanhao
- Logging API time info
- Included version number file in logfiles
- Fixed stopping while sending

# 0.10.10-e (21 apr 2016)
- Fixed Makerbot end gcode that prevented prints or stopping prints to finish.

# 0.10.10-d (20 apr 2016)
- Allow print part sequence numbers to be retrieved
- Sequence numbers are send back when sending print parts
- When WiFi-Box responds that print part was already received the client will send the next part.

# 0.10.10-c (1 apr 2016)
- Quicker log rotation

# 0.10.10-b (21 mrt 2016)
- Logrotation (making sure older logs are removed)
- Improved logging.
- Always log initial printer communication
- loglite improvements, added readme

# 0.10.10-a (24 feb 2016)
- Max buffer size check: the WiFi-Box can now indicate through the API that its buffer is full and it won't accept new gcode.
- Buffer information is communicated through the API so all clients can handle this properly. The Doodle3D client will stop sending and waits until it drops below 75%. It will check this every 30 seconds.
- Improved progress indication: when sending a print the total number of lines can be added, causing the total lines reported through the API to be correct, instead of being approximated to be total lines in buffer, which keeps increasing while a print is still being sent.
- When sending print parts, sequence numbers can be added which will be checked for correctness.
- The stop button now stays enabled while still sending a print.
- Made firmware log format consistent with print3d's.
- Fixed local IP parsing pattern in firmware.
- Improved log messages and log messages formatting.
- Added loglite utility which enables filtering and coloring of logs.
- Won't attempt sign-in when in access point mode.
- More consistent error reporting from API.
- API d3dapi/printer/print's 'first' parameter has been deprecated in favor of a more descriptive 'clear' parameter.
- Support for CraftBot PLUS printer.

# 0.10.9 (11 jan 2016)
# 0.10.8 (11 jan 2016)
# 0.10.8-b (7 jan 2016)
Logging less by default, fixing some pretty serious memory issues, which could cause the WiFi-box to 'crash' while printing bigger files.
Log level setting, enabling users to log more if they run into problems.
For better adhesion we extruded even while traveling on the bottom layers, we now made it configurable and turned it off by default.  
Fixed month display of releases in settings screen.

# 0.10.8-a (11 nov 2015)
Added ch341 and cp210x usb-serial drivers to diffconfig

# 0.10.7 (21 aug 2015)
Added ColiDo printer profiles

# 0.10.6 (17 jun 2015)
# 0.10.6-rc3 (17 jun 2015)
# 0.10.6-rc2 (16 jun 2015)
# 0.10.6-rc1 (16 jun 2015)
This release sees several connectivity bugs resolved as we continue to look to
create the most stable experience we can offer for Doodle3D users. A new
addition that has been realized in that the filament thickness is now
printer dependent. This is important for printers that use 1,75mm filament.
When changing the printer type it switches automatically. Please contact us for
better filament thickness defaults. For more details please review the notes below:

General:
- Updated OpenWRT (the operating system) to 14.07.
- Fixed several big issues around connecting to printers.
- Big files for Marlin based printers are processed faster.
- Target temperature retrieval is improved.
- Changed the Accesspoint's settings to the default because of startup issues (country: NL to US, channel: 11 to 1).
- Improved 404 page.

Additions
- Filament thickness is now printer type dependent and automatically change when selecting a printer. (Please contact us for better filament thickness defaults.)

Support for more 3D printers:
- DoodleDream
- 3Dison
- LulzBot TAZ 4
- Wanhao Duplicator 4
- Ultimaker 2 Go

Improvements for Makerbot based printers (like the Wanhao printer):
- Prevent that the nozzle bumps into the bed when starting a new print.
- Prevent that the nozzle moves though a print after printing.

# 0.10.5-a (2 Feb 2015)
- Removed gray lines where printer needs to 'travel' (move without printing)
- Enabled traveling also for first couple of layers. This prevents straight lines crossing your print
- Added url parameter l=1 which disables parts of the user interface. The 'Print' button 'saves' the sketch instead of sending it to the printer. This is useful for public events where a moderator needs to start prints instead of the user.
- Fixed a small bug where the last sketch was skipped when pressing the previous button for the first time.
- changed WordArt font to a self-made single line handwritting font. This font prints faster and is more playful.


# 0.10.5
- Added the PhotoGuide feature which is kind of a manual Scan & Trace. Use a photo as a background image and create your doodle on top of it.
- Added support for the '3Dison plus' printer.
- Added a File Manager for downloading, uploading and deleting sketches (can be opened via the Settings Panel)
- Improved the way sketches are loaded
- Fixed scrolling issue in Settings Panel

# 0.10.4-photoguide3 (10th oct 2014)
# 0.10.4-photoguide2 (9th oct 2014)
# 0.10.4-photoguide (9th oct 2014)
- Added the PhotoGuide feature which is kind of a manual Scan & Trace. Use a photo as a background image and create your doodle on top of it.
- Added support for the '3Dison plus' printer.

# 0.10.4 (28th may 2014)
- Pulled  improvements by Ultimaker.
- Fixed printing isues with gcode containing whitelines.
- Added Builder3D to printer types
- iOS captive portal fix

# 0.10.3 (9th apr 2014)
- Fixed Makerbot issue where printer driver didn't get past connecting state

# 0.10.2-makerbotfix (27th mar 2014)
- Fixed Makerbot issue where printer driver didn't get past connecting state

Changelog
# 0.10.2 (14th mar 2014)
- Fixed connection issues to networks with multiple routers sharing the same ssid
- Option to update to beta releases (Beta testers are welcome)
- Substituted wifiboxid retrievable through info api
- Added a "connecting" printer state where it found a printer but couldn't communicate yet. (Not yet implemented for Makerbot's)
- When connecting takes to long, we display a warning that the user might have selected the wrong printer type (Not yet implemented for Makerbot's)
- API's printer/state doesn't return an error anymore when a printer is just connected
- Allowing WiFi channels 12 & 13
- Fixed issue that control access wasn't properly reset after print
- Fixed another issue where the box in access point wouldn't give ip addresses

# 0.10.1 (12th feb 2014)
- miniFactory support
- Fixed most Makerbot display issues
- Allowing wifi channels 12 and 13
- Allow floats for retraction amount setting
- Also preheating reconnected printer
- Fixed network interface issues
- added easter-eggs

# 0.10.0 (20th jan 2014)
- WordArt
- Adding basic shapes
- 2D edit functionality: move, scale, rotate
- Vertical shape buttons in foldable menu (creating more vertical space to draw)
- Fixed issues connecting to networks
- Doesn't switch to access point after firmware update anymore
- Speed and flow rate settings for bottom layers
- Improved Makerbot gcode for better adhesion
- Traveling disabled in bottom layers (providing sort of a poor man's raft)
- Feedback on 'restore settings to default'-button
- Reimplemented layout, lots of improvements
- Re-enabled regular browser keyboard shortcuts
- Faster click responses on iOS
- magnifying glass on iOS is now prevented from showing up

# 0.9.13 (23th dec 2013)
- Links to release notes in settings update panel, both for current version and for updateable version.
- On finishing the tour the status message, thermometer and progress indicators are only hidden when appropriate
- Heated bed printer setting
- Gcode {if heatedBed} variable
- Enable / disable tour setting
- Displaying send percentage in status message
- Deltabot (Delta RostockMax, Deltamaker, Kossel) specific start- and endgcode
- Deltabot now have 0 x and y dimentions to center the print
- No more usb hub needed (OpenWRT full speed usb stability patch)
- You can now update without preserving your personal data (sketches / settings)
- Settings can be saved even if there are printer driver issues
- Save and restore settings issues fixed

# 0.9.12 (18th dec 2013):
- Refill wifibox uci settings after reset, preventing printer driver crash (#138)

# 0.9.11 (11th dec 2013):
- keyboard shortcuts have been added
- sketches can now be downloaded both as SVG and as GCODE files
- much more data is included when downloading log files, making it easier to solve problems
- printer profiles have been added, making it possible to differentiate settings per printer
- added Ultimaker 2 and Makerbot Replicator 2x
- specific gcode for ultimaker2 and makerbot have been added
- loading and saving of sketches now works as it should
- in access-point mode, the wifibox now always serves DHCP addresses properly
- more network related logging
- new API endpoint: /printer/listall
- new API endpoint: /config/reset
- traveling is now enabled by default

# 0.9.10 (22th nov 2013):
- fixed a major issue with makerbots preventing to print anything but small prints
- slightly improved usage of makerbot type profiles
- added option to reset settings to defaults (important to use after updating to allow new defaults to be used)
Note: there are known deficiencies in start/end gcode for makerbots

# 0.9.9 (7th nov 2013)
- fixed issue sometimes causing ultimakers to reset continually

# 0.9.8 (30th oct 2013)
- initial release
