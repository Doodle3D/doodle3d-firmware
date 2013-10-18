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

local M = {}

--NOTE: pcall protects from invocation exceptions, which is what we need except
--during debugging. This flag replaces them with a normal call so we can inspect stack traces.
M.DEBUG_PCALLS = true

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
	description = '3D printer temperature',
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

M.printer_startgcode = {
	default = ';Generated with Doodle3D\nM109 S{printingTemp} ;set target temperature \nG21 ;metric values\nG91 ;relative positioning\nM107 ;start with the fan off\nG28 X0 Y0 ;move X/Y to min endstops\nG28 Z0 ;move Z to min endstops\nG1 Z15 F9000 ;move the platform down 15mm\nG92 E0 ;zero the extruded length\nG1 F200 E10 ;extrude 10mm of feed stock\nG92 E0 ;zero the extruded length again\nG92 E0 ;zero the extruded length again\nG1 F9000\nG90 ;absolute positioning\nM117 Printing Doodle...   ;display message (20 characters to clear whole screen)',
	type = 'string',
	description = ''
}

M.printer_endgcode = {
	default = 'M107 ;fan off\nG91 ;relative positioning\nG1 E-1 F300 ;retract the filament a bit before lifting the nozzle, to release some of the pressure\nG1 Z+0.5 E-5 X-20 Y-20 F9000 ;move Z up a bit and retract filament even more\nG28 X0 Y0 ;move X/Y to min endstops, so the head is out of the way\nM84 ;disable axes / steppers\nG90 ;absolute positioning\nM104 {preheatTemp}\nM117 Done                 ;display message (20 characters to clear whole screen)',
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
