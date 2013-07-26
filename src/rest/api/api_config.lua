local log = require('util.logger')
local settings = require('util.settings')

local M = {
	isApi = true
}


function M._global_GET(request, response)
	response:setSuccess()
	for k,v in pairs(request:getAll()) do
		local r,m = settings.get(k)
		
		if r then response:addData(k, r)
		else response:addData(k, "could not read key ('" .. m .. "')")
		end
	end
end

function M._global_POST(request, response)
	response:setSuccess()
	
	for k,v in pairs(request:getAll()) do
		local r,m = settings.set(k, v)
		
		if r then response:addData(k, "ok")
		else response:addData(k, "could not set key ('" .. m .. "')")
		end
	end
end

function M.all_GET(request, response)
	for k,v in pairs(settings.getAll()) do
		response:addData(k,v)
	end
end

return M
