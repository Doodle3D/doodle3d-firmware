local log = require('util.logger')
local utils = require('util.utils')

local M = {}

function M.hasControl(ip)
	local controllerIP = M.getController()
	return (controllerIP == "" or (controllerIP ~= "" and controllerIP == ip))
end

function M.getController()
	local file, error = io.open('/tmp/controller.txt','r')
	if file == nil then
		--log:error("Util:Access:Can't read controller file. Error: "..error)
		return ""
	else
		controllerIP = file:read('*a')
		file:close()
		return controllerIP
	end
end

function M.setController(ip)
	local file = io.open('/tmp/controller.txt','w')
	file:write(ip)
	file:flush()
	file:close()
end

return M