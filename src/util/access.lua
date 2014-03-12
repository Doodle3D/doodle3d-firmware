--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


local log = require('util.logger')
local utils = require('util.utils')
local printerUtils = require('util.printer')

local M = {}

function M.hasControl(ip)
	local controllerIP = M.getController()
	
	-- no controller stored? we have control
	if controllerIP == "" then return true end;
	
	-- controller stored is same as our (requesting) ip? we have control
	if(controllerIP == ip) then return true end;
	
	-- no printer connected? we have control
	local printer,msg = printerUtils.createPrinterOrFail()
	if not printer or not printer:hasSocket() then 
		M.setController("") -- clear the controller
		return true
	end
	
	-- printer is idle (done printing)? we have control
	local state = printer:getState()
	if state == "idle" then -- TODO: define in constants somewhere
		M.setController("") -- clear controller
		return true
	end
	
	return false
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
