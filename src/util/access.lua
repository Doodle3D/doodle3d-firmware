--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


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
		--strip trailing newline (useful when manually editing controller.txt)
		if controllerIP:find('\n') == controllerIP:len() then controllerIP = controllerIP:sub(0, -2) end
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
