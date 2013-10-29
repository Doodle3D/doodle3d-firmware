--[[--
	TODO: finish documentation
	This file contains all valid configuration keys, their default values and optional constraints.
	The table names are used as configuration key names, where underscores ('_') may be used to denote semi-categories.
	The settings interface replaces periods ('.') by underscores so for instance 'network.ap.address' will
	be translated to 'network_ap_address'. Multi-word names should be notated as camelCase.
	Valid fields for the tables are:
	- default: the default value (used when the key is not set in UCI config)
	- type: used for basic type checking, one of bool, int, float or string
	- description: A descriptive text usable by API clients
	- min, max, regex: optional constraints (min and max constrain value for numbers, or length for strings)

	NOTE that the all-caps definitions will be changed into configuration keys, or moved to a different location
]]--
local printer = require('util.printer')
local log = require('util.logger')
local utils = require('util.utils')

local M = {}

--NOTE: pcall protects from invocation exceptions, which is what we need except
--during debugging. This flag replaces them with a normal call so we can inspect stack traces.
M.DEBUG_PCALLS = false

--This enables debugging of the REST API from the command-line, specify the path and optionally the request method as follows: 'p=/mod/func rq=POST'
M.DEBUG_API = true

--REST responses will contain 'module' and 'function' keys describing what was requested
M.API_INCLUDE_ENDPOINT_INFO = false

M.API_BASE_URL_PATH = 'doodle3d.com' -- includes any base path if necessary (e.g. 'localhost/~user')

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
M.printer_bed_width = {
	default = 220,
	type = 'int',
	description = '',
	min = 0
}
M.printer_bed_height = {
	default = 220,
	type = 'int',
	description = '',
	min = 0
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
	type = 'int',
	description = '',
	min = 0
}

M.printer_enableTraveling = {
	default = false,
	type = 'bool',
	description = ''
}

M.printer_startcode_marlin = {
	default = ';Generated with Doodle3D\nM109 S{printingTemp} ;set target temperature \n;M190 S{printingBedTemp} ;set target bed temperature\nG21 ;metric values\nG91 ;relative positioning\nM107 ;start with the fan off\nG28 X0 Y0 ;move X/Y to min endstops\nG28 Z0 ;move Z to min endstops\nG1 Z15 F9000 ;move the platform down 15mm\nG92 E0 ;zero the extruded length\nG1 F200 E10 ;extrude 10mm of feed stock\nG92 E0 ;zero the extruded length again\nG92 E0 ;zero the extruded length again\nG1 F9000\nG90 ;absolute positioning\nM117 Printing Doodle...   ;display message (20 characters to clear whole screen)',
	type = 'string',
	description = ''
}

M.printer_endcode_marlin = {
	default = 'M107 ;fan off\nG91 ;relative positioning\nG1 E-1 F300 ;retract the filament a bit before lifting the nozzle, to release some of the pressure\nG1 Z+0.5 E-5 X-20 Y-20 F9000 ;move Z up a bit and retract filament even more\nG28 X0 Y0 ;move X/Y to min endstops, so the head is out of the way\nM84 ;disable axes / steppers\nG90 ;absolute positioning\nM104 S{preheatTemp}\n;M140 S{preheatBedTemp}\nM117 Done                 ;display message (20 characters to clear whole screen)',
	type = 'string',
	description = ''
}

M.printer_startcode_x3g = {
	default = '(**** CONFIGURATION MACROS ****)\n;@printer r2x\n;@enable progress\n(** This GCode was generated by ReplicatorG 0040 **)\n(*  using Skeinforge (50)  *)\n(*  for a Dual headed Replicator 2  *)\n(*  on 2013/10/27 15:07:27 (+0100) *)\n(**** start.gcode for Replicator 2X, single head ****)\nM103 (disable RPM)\nM73 P0 (enable build progress)\nG21 (set units to mm)\nG90 (set positioning to absolute)\nM104 S240 T0 (set extruder temperature) (temp updated by printOMatic)\nM140 S110 T0 (set HBP temperature)\n(**** begin homing ****)\nG162 X Y F2500 (home XY axes maximum)\nG161 Z F1100 (home Z axis minimum)\nG92 Z-5 (set Z to -5)\nG1 Z0.0 (move Z to "0")\nG161 Z F100 (home Z axis minimum)\nM132 X Y Z A B (Recall stored home offsets for XYZAB axis)\n(**** end homing ****)\nG1 X-141 Y-74 Z10 F3300.0 (move to waiting position)\nG130 X20 Y20 Z20 A20 B20 (Lower stepper Vrefs while heating)\nM6 T0 (wait for toolhead, and HBP to reach temperature)\nG130 X127 Y127 Z40 A127 B127 (Set Stepper motor Vref to defaults)\nM108 R3.0 T0\nG0 X-141 Y-74 (Position Nozzle)\nG0 Z0.6      (Position Height)\nM108 R5.0    (Set Extruder Speed)\nM101         (Start Extruder)\nG4 P2000     (Create Anchor)\nG92 X0 Y0\nM106\n(**** end of start.gcode ****)',
	type = 'string',
	description = ''
}

M.printer_endcode_x3g = {
	default = '(******* End.gcode*******)\nM73 P100 ( End  build progress )\nG0 Z150 ( Send Z axis to bottom of machine )\nM18 ( Disable steppers )\nM104 S0 T0 ( Cool down the Right Extruder )\nG162 X Y F2500 ( Home XY endstops )\nM18 ( Disable stepper motors )\nM70 P5 ( We <3 Making Things!)\nM72 P1  ( Play Ta-Da song )\n(*********end End.gcode*******)',
	type = 'string',
	description = ''
}

M.printer_maxObjectHeight = {
	default = 150,
	type = 'int',
	description = 'Maximum height that will be printed',
	min = 0
}

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

return M
