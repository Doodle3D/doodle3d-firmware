local log = require('util.logger')
local settings = require('util.settings')
local printer = require('util.printer')
local signin = require('network.signin')

local M = {
	isApi = true
}

function M._global_GET(request, response)
	response:setSuccess()
	for k,v in pairs(request:getAll()) do
		local r,m = settings.get(k)
		
		if r ~= nil then response:addData(k, r)
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
	
	log:info("API:Network:try signing in")
  	signin.signin();
  	log:info("API:Network:signed in")
end

function M.all_GET(request, response)
	response:setSuccess()
	for k,v in pairs(settings.getAll()) do
		response:addData(k,v)
	end
end

function M.supportedprinters_GET(request, response)
	response:setSuccess()
	for k,v in pairs(printer.supportedPrinters()) do
		response:addData(k,v)
	end
end

function M.supportedbaudrates_GET(request, response)
	response:setSuccess()
	for k,v in pairs(printer.supportedBaudRates()) do
		response:addData(k,v)
	end
end

return M
