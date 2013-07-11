local M = {}

--NOTE: pcall protects from invocation exceptions, which is what we need except
--during debugging. This flag replaces them with a normal call so we can inspect stack traces.
M.DEBUG_PCALLS = true

--REST responses will contain 'module' and 'function' keys describing what was requested
M.API_INCLUDE_ENDPOINT_INFO = true

M.DEFAULT_AP_SSID = "d3d-ap-%MAC_ADDR_TAIL%"
M.DEFAULT_AP_ADDRESS = "192.168.10.1"
M.DEFAULT_AP_NETMASK = "255.255.255.0"

return M
