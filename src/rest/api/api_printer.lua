local lfs = require('lfs')
local log = require('util.logger')
local utils = require('util.utils')
local settings = require('util.settings')
local printDriver = require('print3d')
local printerUtils = require('util.printer')
local accessManager = require('util.access')

local M = {
	isApi = true
}


function M._global(request, response)
	-- TODO: list all printers (based on /dev/ttyACM* and /dev/ttyUSB*)
	response:setSuccess()
end

function M.temperature(request, response)
	local argId = request:get("id")
	local printer,msg = printerUtils.createPrinterOrFail(argId, response)
	if not printer then return false end

	local temperatures,msg = printer:getTemperatures()

	response:addData('id', argId)
	if temperatures then
		response:setSuccess()
		response:addData('hotend', temperatures.hotend)
		response:addData('hotend_target', temperatures.hotend_target)
		response:addData('bed', temperatures.bed)
		response:addData('bed_target', temperatures.bed_target)
	else
		response:setError(msg)
		return false;
	end
	
	return true;
end

function M.progress(request, response)
	local argId = request:get("id")
	local printer,msg = printerUtils.createPrinterOrFail(argId, response)
	if not printer then return false end

	-- NOTE: despite their names, `currentLine` is still the error indicator and `bufferedLines` the message in such case.
	local currentLine,bufferedLines,totalLines = printer:getProgress()

	response:addData('id', argId)
	if currentLine then
		response:setSuccess()
		response:addData('current_line', currentLine)
		response:addData('buffered_lines', bufferedLines)
		response:addData('total_lines', totalLines)
	else
		response:setError(bufferedLines)
		return false
	end
	
	return true;
end

function M.state(request, response)
	local argId = request:get("id")
	response:addData('id', argId)
	
	local printer,msg = printerUtils.createPrinterOrFail(argId, response)
	if not printer then 
		response:setSuccess()
		local printerState = "disconnected"
		response:addData('state', printerState)
		return true, printerState
	else 
		local rv,msg = printer:getState()
		if rv then
			response:setSuccess()
			response:addData('state', rv)
			return true, rv
		else
			response:setError(msg)
			return false
		end
	end
	return true;
end

function M.heatup_POST(request, response)

	if not accessManager.hasControl(request.remoteAddress) then
		response:setFail("No control access")
		return
	end

	local argId = request:get("id")
	local printer,msg = printerUtils.createPrinterOrFail(argId, response)
	if not printer then return false end

	local temperature = settings.get('printer.heatup.temperature')
	local rv,msg = printer:heatup(temperature)

	response:addData('id', argId)
	if rv then response:setSuccess()
	else response:setFail(msg)
	end
end

function M.stop_POST(request, response)

	log:info("API:printer/stop")

	if not accessManager.hasControl(request.remoteAddress) then
		response:setFail("No control access")
		return
	end

	local argId = request:get("id")
	local printer,msg = printerUtils.createPrinterOrFail(argId, response)
	if not printer then return end
	
	-- replacing {printingTemp} and {preheatTemp} in endgcode
	local printingTemperature  	  = settings.get('printer.temperature')
	local preheatTemperature      = settings.get('printer.heatup.temperature')
	local endGcode 				  = settings.get('printer.endgcode')
	endGcode = string.gsub(endGcode,"{printingTemp}",printingTemperature)
	endGcode = string.gsub(endGcode,"{preheatTemp}",preheatTemperature)
	
	local rv,msg = printer:stopPrint(endGcode)

	response:addData('id', argId)
	if rv then response:setSuccess()
	else response:setError(msg)
	end
end

--accepts: first(bool) (chunks will be concatenated but output file will be cleared first if this argument is true)
--accepts: start(bool) (only when this argument is true will printing be started)
function M.print_POST(request, response)

	local controllerIP = accessManager.getController()
	local hasControl = false
	if controllerIP == "" then
		accessManager.setController(request.remoteAddress)
		hasControl = true
	elseif controllerIP == request.remoteAddress then
		hasControl = true
	end

	log:info("  hasControl: "..utils.dump(hasControl))
	if not hasControl then
		response:setFail("No control access")
		return
	end

	local argId = request:get("id")
	local argGcode = request:get("gcode")
	local argIsFirst = utils.toboolean(request:get("first"))
	local argStart = utils.toboolean(request:get("start"))

	local printer,msg = printerUtils.createPrinterOrFail(argId, response)
	if not printer then return end

	response:addData('id', argId)

	if argGcode == nil or argGcode == '' then
		response:setError("missing gcode argument")
		return
	end

	if argIsFirst == true then
		log:debug("clearing all gcode for " .. printer:getId())
		response:addData('gcode_clear',true)
		local rv,msg = printer:clearGcode()

		if not rv then
			response:setError(msg)
			return
		end
	end

	local rv,msg

	-- TODO: return errors with a separate argument like here in the rest of the code (this is how we designed the API right?)
	rv,msg = printer:appendGcode(argGcode)
	if rv then
		--NOTE: this does not report the number of lines, but only the block which has just been added
		response:addData('gcode_append',argGcode:len())
	else
		response:setError("could not add gcode")
		response:addData('msg', msg)
		return
	end

	if argStart == true then
		rv,msg = printer:startPrint()

		if rv then
			response:setSuccess()
			response:addData('gcode_print',true)
		else
			response:setError("could not send gcode")
			response:addData('msg', msg)
		end
	else
		response:setSuccess()
	end
end

return M
