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
