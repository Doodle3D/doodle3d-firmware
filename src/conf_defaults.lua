local M = {}

--NOTE: pcall protects from invocation exceptions, which is what we need except
--during debugging. This flag replaces them with a normal call so we can inspect stack traces.
M.DEBUG_PCALLS = true

--REST responses will contain 'module' and 'function' keys describing what was requested
M.API_INCLUDE_ENDPOINT_INFO = false

M.DEFAULT_AP_SSID = "d3d-ap-%MAC_ADDR_TAIL%"
M.DEFAULT_AP_ADDRESS = "192.168.10.1"
M.DEFAULT_AP_NETMASK = "255.255.255.0"


--NOTE: proposed notation for baseline configuration (containing defaults as well as type and constraint information)
--the table name is the configuration key; min, max and regex are all optional; type is one of: {int, float, string, ...?}
M.temperature = {
	default = 230,
	type = 'int',
	description = '...xyzzy',
	min = 0,
	max = 350
}

M.ssid = {
	default = 'd3d-ap-%%MAC_TAIL%%',
	type = 'int', --one of: {int, float, string, ...?}
	min = 1,
	max = 32,
	regex = '[a-zA-Z0-9 -=+]+'
}


return M
