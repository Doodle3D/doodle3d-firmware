local M = {}

--NOTE: proposed notation for baseline configuration (containing defaults as well as type and constraint information)
--the table name is the configuration key; min, max and regex are all optional; type is one of: {bool, int, float, string}

--NOTE: pcall protects from invocation exceptions, which is what we need except
--during debugging. This flag replaces them with a normal call so we can inspect stack traces.
M.DEBUG_PCALLS = true

--This enables debugging of the REST API from the command-line, specify the path and optionally the request method as follows: 'p=/mod/func rq=POST'
M.DEBUG_API = true

--REST responses will contain 'module' and 'function' keys describing what was requested
M.API_INCLUDE_ENDPOINT_INFO = false


M.apSsid = {
	default = 'd3d-ap-%%MAC_ADDR_TAIL%%',
	type = 'string',
	description = 'Access Point mode SSID',
	min = 1,
	max = 32
}

M.apAddress = {
	default = '192.168.10.1',
	type = 'string',
	description = 'Access Point mode IP address',
	regex = '%d+\.%d+\.%d+\.%d+'
}

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
