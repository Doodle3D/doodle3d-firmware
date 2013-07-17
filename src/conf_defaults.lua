local M = {}

--NOTE: proposed notation for baseline configuration (containing defaults as well as type and constraint information)
--the table name is the configuration key; min, max and regex are all optional; type is one of: {bool, int, float, string}

--NOTE: pcall protects from invocation exceptions, which is what we need except
--during debugging. This flag replaces them with a normal call so we can inspect stack traces.
M.DEBUG_PCALLS = true

--REST responses will contain 'module' and 'function' keys describing what was requested
M.API_INCLUDE_ENDPOINT_INFO = false


-- was: M.DEFAULT_AP_SSID = "d3d-ap-%MAC_ADDR_TAIL%"
M.apSsid = {
	default = 'd3d-ap-%%MAC_ADDR_TAIL%%',
	type = 'string',
	description = 'Access Point mode SSID',
	min = 1,
	max = 32
}

-- was: M.DEFAULT_AP_ADDRESS = "192.168.10.1"
M.apAddress = {
	default = '192.168.10.1',
	type = 'string',
	description = 'Access Point mode IP address',
	regex = '%d+\.%d+\.%d+\.%d+'
}

-- was: M.DEFAULT_AP_NETMASK = "255.255.255.0"
M.apNetmask = {
	default = '255.255.255.0',
	type = 'string',
	description = 'Access Point mode netmask',
	regex = '%d+\.%d+\.%d+\.%d+'
}

M.temperature = {
	default = 230,
	type = 'int',
	description = '3D printer temperature',
	min = 0,
	max = 350
}

return M
