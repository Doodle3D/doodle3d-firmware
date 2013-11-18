local log = require('util.logger')
local utils = require('util.utils')

local M = {}

function M.getInfo()
	local file, error = io.open("/sys/devices/platform/ehci-platform/usb1/1-1/speed",'r')
	if file ~= nil then
		local speed = file:read('*a')
		file:close()
		speed = tonumber(speed)
		
		-- determine if high speed
		-- http://stackoverflow.com/questions/1957589/usb-port-speed-linux
		local highSpeed = (speed == 480)
		
		return speed, highSpeed
	else 
		return nil
	end
	
end

return M
