local lfs = require('lfs')
local log = require('util.logger')
local utils = require('util.utils')
local settings = require('util.settings')
local printDriver = require('print3d')

local M = {
	isApi = true
}


local ULTIFI_BASE_PATH = '/tmp/UltiFi'
local TEMPERATURE_FILE = 'temp.out'
local PROGRESS_FILE = 'progress2.out'
local COMMAND_FILE = 'command.in'
local GCODE_TMP_FILE = 'combined.gc'


--returns a printer instance or nil (and sets error state on response in the latter case)
local function createPrinterOrFail(deviceId, response)
	local msg,printer = nil, nil

	if deviceId and deviceId ~= "" then
		printer,msg = printDriver.getPrinter(deviceId)
	else
		msg = "missing device ID"
	end

	if not printer then
		response:setError("could not open printer driver (" .. msg .. ")")
		response:addData('id', deviceId)
		return nil
	end

	return printer
end


function M._global(request, response)
	-- TODO: list all printers (based on /dev/ttyACM* and /dev/ttyUSB*)
	response:setSuccess()
end

--requires id(string)
function M.temperature(request, response)
	local argId = request:get("id")
	local printer,msg = createPrinterOrFail(argId, response)
	if not printer then return end

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
	end
end

--requires id(string)
function M.progress(request, response)
	local argId = request:get("id")
	local printer,msg = createPrinterOrFail(argId, response)
	if not printer then return end

	-- NOTE: despite their names, `currentLine` is still the error indicator and `numLines` the message in such case.
	local currentLine,numLines = printer:getProgress()

	response:addData('id', argId)
	if currentLine then
		response:setSuccess()
		response:addData('current_line', currentLine)
		response:addData('num_lines', numLines)
	else
		response:setError(numLines)
	end
end

--TODO: remove busy function (client should use state function)
--requires id(string)
function M.busy(request, response)
	local argId = request:get("id")
	local printer,msg = createPrinterOrFail(argId, response)
	if not printer then return end

	local rv,msg = printer:getState()

	response:addData('id', argId)
	if rv then
		response:setSuccess()
		response:addData('busy', (rv ~= 'idle'))
	else
		response:setError(msg)
	end
end

--requires id(string)
function M.state(request, response)
	local argId = request:get("id")
	local printer,msg = createPrinterOrFail(argId, response)
	if not printer then return end

	local rv,msg = printer:getState()

	response:addData('id', argId)
	if rv then
		response:setSuccess()
		response:addData('state', rv)
	else
		response:setError(msg)
	end
end

--requires id(string)
function M.heatup_POST(request, response)
	local argId = request:get("id")
	local printer,msg = createPrinterOrFail(argId, response)
	if not printer then return end

	local temperature = settings.get('printer.heatupTemperature')
	local rv,msg = printer:heatup(temperature)

	response:addData('id', argId)
	if rv then response:setSuccess()
	else response:setFail(msg)
	end
end

--requires id(string)
function M.stop_POST(request, response)
	local argId = request:get("id")
	local printer,msg = createPrinterOrFail(argId, response)
	if not printer then return end

	local endGcode = settings.get('printer.endgcode')
	local rv,msg = printer:stopPrint(endGcode)

	response:addData('id', argId)
	if rv then response:setSuccess()
	else response:setError(msg)
	end
end

--requires id(string), gcode(string)
--accepts: first(bool) (chunks will be concatenated but output file will be cleared first if this argument is true)
--accepts: last(bool) (chunks will be concatenated and only when this argument is true will printing be started)
function M.print_POST(request, response)
	local argId = request:get("id")
	local argGcode = request:get("gcode")
	local argIsFirst = utils.toboolean(request:get("first"))
	local argIsLast = utils.toboolean(request:get("last"))

	local printer,msg = createPrinterOrFail(argId, response)
	if not printer then return end

	response:addData('id', argId)

	if argGcode == nil or argGcode == '' then
		response:setError("missing gcode argument")
		return
	end

	if argIsFirst == true then
		log:debug("clearing all gcode for " .. printer)
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

	if argIsLast == true then
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
