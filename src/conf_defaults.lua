--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


---
-- This file contains all valid configuration keys, their default values and optional constraints.
-- The table names are used as configuration key names, where underscores ('`_`') may be used to denote semi-categories.
-- The settings interface replaces periods ('`.`') by underscores so for instance `network.ap.address` will
-- be translated to `network_ap_address`. Multi-word names should be notated as camelCase.
--
-- Valid fields for the tables are:
--
-- - _default_: the default value (used when the key is not set in UCI config)
-- - _type_: used for basic type checking, one of bool, int, float or string
-- - _description_: A descriptive text usable by API clients
-- - _min_, _max_, _regex_: optional constraints (min and max constrain value for numbers, or length for strings)
-- - _isValid_: an optional function which should return true for valid values and false for invalid ones
-- - _subSection: optional: setting name of which current value is used as the uci section where this setting should be loaded from. Otherwise it's retrieved from the generic section. Setting subsection also means it will first try to get a default from subconf_defaults, if that doesn't exsist it will use the regular default
-- The configuration keys themselves document themselves rather well, hence they are not included in the generated documentation.
--
-- NOTE: the all-caps definitions should be changed into configuration keys, or moved to a better location.
local printer = require('util.printer')
local log = require('util.logger')
local utils = require('util.utils')

local M = {}

--- This constant should only be true during development. It replaces `pcall` by regular `call`.
-- Pcall protects the script from invocation exceptions, which is what we need except during debugging.
-- When this flag is true, normal calls will be used so we can inspect stack traces.
M.DEBUG_PCALLS = false

--- This constant enables debugging of the REST API from the command-line by emulating GET/POST requests.
-- Specify the path and optionally the request method as follows: `d3dapi p=/mod/func r=POST`.
M.DEBUG_API = true

--- If enabled, REST responses will contain 'module' and 'function' keys describing what was requested.
M.API_INCLUDE_ENDPOINT_INFO = false

--- This base path is used in @{rest.response}. It includes any base path if necessary (e.g. 'localhost/~user').
M.API_BASE_URL_PATH = 'doodle3d.com'

M.network_ap_ssid = {
	default = 'Doodle3D-%%MAC_ADDR_TAIL%%',
	type = 'string',
	description = 'Access Point mode SSID (name)',
	min = 1,
	max = 32
}

M.network_ap_address = {
	default = '192.168.10.1',
	type = 'string',
	description = 'Access Point mode IP address',
	regex = '%d+\.%d+\.%d+\.%d+'
}

M.network_ap_key = {
	default = '',
	type = 'string',
	description = 'Access Point security key',
	isValid = function(value)
		if value == "" then
			return true;
		elseif value:len() < 8 then
			return false, "too short"
		elseif value:len() > 63 then
			return false, "too long"
		else
			return true
		end
	end
}

M.network_ap_netmask = {
	default = '255.255.255.0',
	type = 'string',
	description = 'Access Point mode netmask',
	regex = '%d+\.%d+\.%d+\.%d+'
}

M.network_cl_wifiboxid = {
	default = 'Doodle3D-%%MAC_ADDR_TAIL%%',
	type = 'string',
	description = 'Client mode WiFi box id',
	min = 1,
	max = 32
}

M.printer_type = {
	default = 'ultimaker',
	type = 'string',
	description = '',
	isValid = function(value)
		local printers = printer.supportedPrinters()
		return printers[value] ~= nil
	end
}

M.printer_dimensions_x = {
	default = 200,
	default_delta_rostockmax = 0,
	default_deltamaker = 0,
	default_kossel = 0,
	default_minifactory = 150,
	subSection = 'printer_type',
	type = 'int',
	description = '',
	min = 0
}
M.printer_dimensions_y = {
	default = 200,
	default_delta_rostockmax = 0,
	default_deltamaker = 0,
	default_kossel = 0,
	default_minifactory = 150,
	subSection = 'printer_type',
	type = 'int',
	description = '',
	min = 0
}
M.printer_dimensions_z = {
	default = 200,
	default_minifactory = 155,
	subSection = 'printer_type',
	type = 'int',
	description = '',
	min = 0
}
M.printer_heatedbed = {
	default = false,
	default_ultimaker2 = true,
	default_makerbot_replicator2x = true,
	default_minifactory = true,
	subSection = 'printer_type',
	type = 'bool',
	description = 'Printer has heated bed',
}

local default_makerbot_startcode = ";@printer {printerType}\nM136 (enable build)\nM73 P0\nG162 X Y F2000(home XY axes maximum)\nG161 Z F900(home Z axis minimum)\nG92 X0 Y0 Z-5 A0 B0 (set Z to -5)\nG1 Z0.0 F900(move Z to '0')\nG161 Z F100(home Z axis minimum)\nM132 X Y Z A B (Recall stored home offsets for XYZAB axis)\nG92 X152 Y72 Z0 A0 B0\nG1 X-112 Y-73 Z0.5 F3300.0 (move to front left 'zero' position)\nG92 X0 Y0 Z0.5 A0 B0\nG1 X0 Y0 Z0.5 F3300.0 (move to waiting position)\nG130 X20 Y20 A20 B20 (Lower stepper Vrefs while heating)\n{if heatedBed};M109 S{printingBedTemp} T0\n{if heatedBed}M140 S{printingBedTemp} T0\nM104 S{printingTemp} T0\n;M134 T0\nM135 T0\nM104 S{printingTemp} T0\nM133 T0\nG130 X127 Y127 A127 B127 (Set Stepper motor Vref to defaults)\nG1 F100 A10 ;extrude 10mm\nG92 A0 ;reset again\nG0 Z20"
local default_deltabot_startcode = ';Generated with Doodle3D (deltabot)\nM109 S{printingTemp} ;set target temperature\n{if heatedBed}M190 S{printingBedTemp} ;set target bed temperature\nG21 ;metric values\nG91 ;relative positioning\nM107 ;start with the fan off\nG28 ; move to home\nG92 E0 ;zero the extruded length\nG90 ;absolute positioning\nM117 Printing Doodle...   ;display message (20 characters to clear whole screen)'
M.printer_startcode = {
	default = ';Generated with Doodle3D (default)\nM109 S{printingTemp} ;set target temperature \n{if heatedBed}M190 S{printingBedTemp} ;set target bed temperature\nG21 ;metric values\nG91 ;relative positioning\nM107 ;start with the fan off\nG28 X0 Y0 ;move X/Y to min endstops\nG28 Z0 ;move Z to min endstops\nG1 Z15 F9000 ;move the platform down 15mm\nG92 E0 ;zero the extruded length\nG1 F200 E10 ;extrude 10mm of feed stock\nG92 E0 ;zero the extruded length again\nG92 E0 ;zero the extruded length again\nG1 F9000\nG90 ;absolute positioning\nM117 Printing Doodle...   ;display message (20 characters to clear whole screen)',
	default_ultimaker2 = ';Generated with Doodle3D (ultimaker2)\nM109 S{printingTemp} ;set target temperature \n{if heatedBed}M190 S{printingBedTemp} ;set target bed temperature\nG21 ;metric values\nG90 ;absolute positioning\nM107 ;start with the fan off\nG28 ; home to endstops\nG1 Z15 F9000 ;move the platform down 15mm\nG92 E0 ;zero the extruded length\nG1 F200 E10 ;extrude 10mm of feed stock\nG92 E0 ;zero the extruded length again\nG1 F9000\nM117 Printing Doodle...   ;display message (20 characters to clear whole screen)\n',
	default_makerbot_generic = default_makerbot_startcode,
	default_makerbot_replicator2 = default_makerbot_startcode,
	default_makerbot_replicator2x = default_makerbot_startcode,
	default_makerbot_thingomatic = default_makerbot_startcode,
	default_delta_rostockmax = default_deltabot_startcode,
	default_deltamaker = default_deltabot_startcode,
	default_kossel = default_deltabot_startcode,
	type = 'string',
	subSection = 'printer_type',
	description = ''
}

local default_makerbot_endcode = 'M73 P100\nG92 A0 B0 ;reset extruder position to prevent retraction\nM18 A B(Turn off A and B Steppers)\nG1 Z155 F900\nG162 X Y F2000\nM18 X Y Z(Turn off steppers after a build)\n{if heatedBed}M140 S{preheatBedTemp} T0\nM104 S{preheatTemp} T0\nM73 P100 (end  build progress )\nM72 P1  ( Play Ta-Da song )\nM137 (build end notification)'
local default_deltabot_endcode = 'M107 ;fan offG91 ;relative positioningG1 E-1 F300 ;retract the filament a bit before lifting the nozzle, to release some of the pressureG1 Z+0.5 E-5 X-20 Y-20 F9000 ;move Z up a bit and retract filament even moreG28 ;move to homeM84 ;disable axes / steppersG90 ;absolute positioningM109 S0 ; hot end off{if heatedBed}M140 S{preheatBedTemp}M117 Done                 ;display message (20 characters to clear whole screen)'
M.printer_endcode = {
	default = 'M107 ;fan off\nG91 ;relative positioning\nG1 E-1 F300 ;retract the filament a bit before lifting the nozzle, to release some of the pressure\nG1 Z+0.5 E-5 X-20 Y-20 F9000 ;move Z up a bit and retract filament even more\nG28 X0 Y0 ;move X/Y to min endstops, so the head is out of the way\nM84 ;disable axes / steppers\nG90 ;absolute positioning\nM104 S{preheatTemp}\n{if heatedBed}M140 S{preheatBedTemp}\nM117 Done                 ;display message (20 characters to clear whole screen)',
	default_ultimaker2 = 'M107 ;fan off\nG91 ;relative positioning\nG1 E-1 F300 ;retract the filament a bit before lifting the nozzle, to release some of the pressure\nG1 Z+5.5 E-5 X-20 Y-20 F9000 ;move Z up a bit and retract filament even more\nG28 ;home the printer\nM84 ;disable axes / steppers\nG90 ;absolute positioning\nM104 S{preheatTemp}\n{if heatedBed}M140 S{preheatBedTemp}\nM117 Done                 ;display message (20 characters to clear whole screen)',
	default_makerbot_generic = default_makerbot_endcode,
	default_makerbot_replicator2 = default_makerbot_endcode,
	default_makerbot_replicator2x = default_makerbot_endcode,
	default_makerbot_thingomatic = default_makerbot_endcode,
	default_delta_rostockmax = default_deltabot_endcode,
	default_deltamaker = default_deltabot_endcode,
	default_kossel = default_deltabot_endcode,
	type = 'string',
	subSection = 'printer_type',
	description = ''
}

M.printer_baudrate = {
	default = '115200',
	type = 'int',
	description = '',
	isValid = function(value)
		local baudrates = printer.supportedBaudRates()
		return baudrates[tostring(value)] ~= nil
	end
}

M.printer_temperature = {
	default = 230,
	type = 'int',
	description = 'printing temperature',
	min = 0
}

M.printer_bed_temperature = {
	default = 70,
	type = 'int',
	description = 'printing bed temperature',
	min = 0
}

M.printer_layerHeight = {
	default = 0.2,
	type = 'float',
	description = '',
	min = 0.0
}

M.printer_wallThickness = {
	default = 0.5,
	type = 'float',
	description = '',
	min = 0.0
}

M.printer_speed = {
	default = 70,
	type = 'int',
	description = '',
	min = 0
}

M.printer_travelSpeed = {
	default = 200,
	type = 'int',
	description = '',
	min = 0
}

M.printer_filamentThickness = {
	default = 2.89,
	type = 'float',
	description = '',
	min = 0.0
}

M.printer_useSubLayers = {
	default = true,
	type = 'bool',
	description = 'Continuously move platform while printing instead of once per layer'
}

M.printer_firstLayerSlow = {
	default = true,
	type = 'bool',
	description = 'Print the first layer slowly to get a more stable start'
}

M.printer_bottomLayerSpeed = {
  default = 35,
  type = 'int',
  description = 'If first layers are to be printed slowly, use this speed'
}

M.printer_bottomFlowRate = {
  default = 2,
  type = 'float',
  description = 'Multiplication factor for filament flow rate in first few layers'
}

M.printer_heatup_enabled = {
	default = true,
	type = 'bool',
	description = ''
}

M.printer_heatup_temperature = {
	default = 180,
	type = 'int',
	description = ''
}

M.printer_heatup_bed_temperature = {
	default = 70,
	type = 'int',
	description = ''
}

M.printer_retraction_enabled = {
	default = true,
	type = 'bool',
	description = ''
}

M.printer_retraction_speed = {
	default = 50,
	type = 'int',
	description = '',
	min = 0
}

M.printer_retraction_minDistance = {
	default = 5,
	type = 'int',
	description = '',
	min = 0
}

M.printer_retraction_amount = {
	default = 3,
	type = 'float',
	description = '',
	min = 0
}

M.printer_enableTraveling = {
	default = true,
	type = 'bool',
	description = ''
}

-- M.printer_maxObjectHeight = {
-- 	default = 150,
-- 	type = 'int',
-- 	description = 'Maximum height that will be printed',
-- 	min = 0
-- }

M.printer_screenToMillimeterScale = {
	default = 0.3,
	type = 'float',
	description = '',
}

M.doodle3d_simplify_minDistance = {
	default = 3,
	type = 'int',
	description = '',
	min = 0
}

M.doodle3d_tour_enabled = {
	default = true,
	type = 'bool',
	description = 'Show tour to new users'
}

M.doodle3d_update_includeBetas = {
	default = false,
	type = 'bool',
	description = 'Include beta releases when updating'
}

M.doodle3d_update_baseUrl = {
	default = 'http://doodle3d.com/updates',
	type = 'string',
	description = ''
}

return M
