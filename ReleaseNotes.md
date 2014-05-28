Changelog
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
