--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


local log = require('util.logger')
local utils = require('util.utils')
local settings = require('util.settings')
local printer = require('util.printer')
--local signin = require('network.signin')
local wifi = require('network.wlanconfig')
local accessManager = require('util.access')
local printerAPI = require('rest.api.api_printer')


local M = {
	isApi = true
}


-- TODO: this function is also defined in 2 other places, combine them (and avoid require loops)
local function operationsAccessOrFail(request, response)
	if not accessManager.hasControl(request.remoteAddress) then
		response:setFail("No control access")
		return false
	end

	local rv, printerState = printerAPI.state(request, response, true)
	if(rv == false) then
		response:setError("Could not get printer state")
		return false
	end

	if printerState == 'buffering' or printerState == 'printing' or printerState == 'stopping' then
		response:setFail("Printer is busy, please wait")
		return false
	end

	return true
end


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
	--log:info("API:config:set")

	if not operationsAccessOrFail(request, response) then return end

	response:setSuccess()

	local validation = {}
	for k,v in pairs(request:getAll()) do
		--log:info("  "..k..": "..v);
		local r,m = settings.set(k, v)

		if r then
			--response:addData(k, "ok")
			validation[k] = "ok"
		else
			--response:addData(k, "could not save setting ('" .. m .. "')")
			validation[k] = "could not save setting ('" .. m .. "')"
			log:info("  m: "..utils.dump(m))
		end
	end
	response:addData("validation",validation)

	local substitutedSsid = wifi.getSubstitutedSsid(settings.get('network.ap.ssid'))
	response:addData("substituted_ssid",substitutedSsid)

	-- we now call signin seperatly trough cgi-bin
	--[[log:info("API:Network:try signing in")
  	if signin.signin() then
  		log:info("API:Network:signin successfull")
  	else
  		log:info("API:Network:signin failed")
  	end]]--
end

function M.all_GET(request, response)
	response:setSuccess()
	for k,v in pairs(settings.getAll()) do
		response:addData(k,v)
	end
end

--- Reset specific setting to default value
-- When an setting has a subSection only the setting in it's current subSection is reset. 
-- For example you want to reset setting _printer.startcode_ 
-- and it has it's _subSection_ set to 'printer_type' 
-- and printer.type is set to 'ultimaker' then 
-- only the printer.startcode under the ultimaker subsection is removed.
function M.reset_POST(request, response)
	--log:info("API:reset");
	if not operationsAccessOrFail(request, response) then return end
	response:setSuccess()
	
	for k,v in pairs(request:getAll()) do
		--log:info("  "..k..": "..v);
		local r,m = settings.reset(k);
		if r ~= nil then response:addData(k, "ok")
		else response:addData(k, "could not reset key ('" .. m .. "')") end
	end
end

--- Reset all settings to default value 
function M.resetall_POST(request, response)
	if not operationsAccessOrFail(request, response) then return end
	response:setSuccess()
	settings.resetAll()
	
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
