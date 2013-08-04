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
	default = 'd3d-ap-%%MAC_ADDR_TAIL%%',
	type = 'string',
	description = 'Access Point mode SSID',
	min = 1,
	max = 32
}

M.network_ap_address = {
	default = '192.168.10.1',
	type = 'string',
	description = 'Access Point mode IP address',
	regex = '%d+\.%d+\.%d+\.%d+'
}

M.network_ap_netmask = {
	default = '255.255.255.0',
	type = 'string',
	description = 'Access Point mode netmask',
	regex = '%d+\.%d+\.%d+\.%d+'
}

M.printer_temperature = {
	default = 230,
	type = 'int',
	description = '3D printer temperature',
	min = 0
}

M.printer_objectHeight = {
	default = 20,
	type = 'int',
	description = 'Maximum height that will be printed',
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

M.printer_autoWarmUp = {
	default = true,
	type = 'bool',
	description = '',
}

M.printer_simplify_iterations = {
	default = 10,
	type = 'int',
	description = '',
	min = 0
}

M.printer_simplify_minNumPoints = {
	default = 15,
	type = 'int',
	description = '',
	min = 0
}

M.printer_simplify_minDistance = {
	default = 3,
	type = 'int',
	description = '',
	min = 0
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

M.printer_autoWarmUpCommand = {
	default = 'M104 S230',
	type = 'string',
	description = ''
}

return M
