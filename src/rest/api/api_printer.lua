local lfs = require('lfs')
local log = require('util.logger')
local utils = require('util.utils')
local settings = require('util.settings')

local M = {
	isApi = true
}


local ULTIFI_BASE_PATH = '/tmp/UltiFi'
local TEMPERATURE_FILE = 'temp.out'
local PROGRESS_FILE = 'progress2.out'
local COMMAND_FILE = 'command.in'
local GCODE_TMP_FILE = 'combined.gc'

-- returns full path + ultifi path or nil
local function printerExists(id)
	if id == nil then return nil end
	
	local path = '/dev/ttyACM' .. id
	local upath = ULTIFI_BASE_PATH .. '/ttyACM' .. id
	if utils.exists(path) then return path,upath end
	
	path = '/dev/ttyUSB' .. id
	upath = ULTIFI_BASE_PATH .. '/ttyUSB' .. id
	if utils.exists(path) then return path,upath end
	
	return nil
end

-- returns printerId,devicePath,ultifiPath or nil if printer does not exist
-- when nil is returned, response has already been set as an error
local function getPrinterDataOrFail(request, response)
	local id = tonumber(request:get("id"))

	if id == nil then
		response:setError("missing id argument")
		return nil
	end
	
	local devpath,ultipath = printerExists(id)
	
	if not devpath then
		response:setError("printer does not exist")
		response:addData('id', id)
		return nil
	end
	
	return id,devpath,ultipath
end

-- assumes printerPath exists, returns true if successful, false if command file already exists and is non-empty (i.e. printer busy),
-- nil+err if file could not be opened
local function sendGcode(printerPath, gcode)
	local cmdPath = printerPath .. '/' .. COMMAND_FILE
	local f,msg = io.open(cmdPath, 'a+') -- 'a+' is important, do not overwrite current contents in any case
	
	if not f then return nil,msg end
	if utils.fileSize(f) > 0 then return false end
	
	log:debug("sending " .. gcode:len() .. " bytes of gcode")
	f:write(gcode)
	f:close()
	
	return true
end

local function addToGcodeFile(printerPath, gcode)
	if not gcode or type(gcode) ~= 'string' then return nil,"missing gcode data" end
	
	local gtFile = printerPath .. '/' .. GCODE_TMP_FILE
	
	local gcf,msg = io.open(gtFile, 'a+')
	if not gcf then return nil,msg end
	
	log:debug("appending " .. gcode:len() .. " bytes of gcode to " .. gtFile)
	gcf:write(gcode)
	gcf:write("\n")
	gcf:close()
	
	return true
end

-- assumes printerPath exists, returns true if successful, false if command file already exists and is non-empty (i.e. printer busy),
-- nil+err if file could not be opened
local function printGcodeFile(printerPath)
	local gtFile = printerPath .. '/' .. GCODE_TMP_FILE
	local cmdPath = printerPath .. '/' .. COMMAND_FILE
	local cmdf,msg = io.open(cmdPath, 'a+') -- 'a+' is important, do not overwrite current contents in any case
	
	if not cmdf then return nil,msg end
	if utils.fileSize(cmdf) > 0 then return false end
	
	log:debug("starting print of gcode in " .. gtFile)
	cmdf:write('(SENDFILE=' .. gtFile)
	cmdf:close()
	
	return true
end

--UNTESTED
-- assumes printerPath exists, returns true if successful, false if command file already exists and is non-empty (i.e. printer busy),
-- nil+err if file could not be opened
local function stopGcodeFile(printerPath)
	local cmdPath = printerPath .. '/' .. COMMAND_FILE
	local cmdf,msg = io.open(cmdPath, 'a+') -- 'a+' is important, do not overwrite current contents in any case
	
	if not cmdf then return nil,msg end
	if utils.fileSize(cmdf) > 0 then return false end
	
	log:debug("stopping print of gcode")
	cmdf:write('(CANCELFILE')
	cmdf:close()
	
	return true
end

local function isBusy(printerPath)
	local cmdPath = printerPath .. '/' .. COMMAND_FILE
	
	if not utils.exists(cmdPath) then return false end
	
	local f,msg = io.open(cmdPath, 'r')
	
	if not f then return nil,msg end
	local size = utils.fileSize(f)
	f:close()
	
	return size > 0
end


function M._global(request, response)
	-- TODO: list all printers (based on /dev/ttyACM* and /dev/ttyUSB*)
	response:setSuccess()
end

--requires id(int)
--accepts with_raw(bool) to include raw printer response
function M.temperature(request, response)
	local withRaw = utils.toboolean(request:get("with_raw"))
	
	local argId,devpath,ultipath = getPrinterDataOrFail(request, response)
	if argId == nil then return end
	
	local f = io.open(ultipath .. '/' .. TEMPERATURE_FILE)
	
	if not f then
		response:setError("could not open temperature file")
		response:addData('id', argId)
		return
	end
	
	local tempText = f:read('*all')
	f:close()
	
	local hotend, hotendTarget, bed, bedTarget = tempText:match('T:(.*)%s+/(.*)%s+B:(.*)%s/(.*)%s+@.*')
	
	response:setSuccess()
	if withRaw then response:addData('raw', tempText) end

	-- After pressing print it waits until it's at the right temperature. 
	-- it then stores temperature in the following format
	-- T:204.5 E:0 W:?
	if(hotend == nil) then 
		local hotend = tempText:match('T:([%d%.]*).*')
		response:addData('hotend', hotend)
	else 
		response:addData('hotend', hotend)
		response:addData('bed', bed)
		response:addData('hotend_target', hotendTarget)
		response:addData('bed_target', bedTarget)
	end

	-- get last modified time
	local file_attr = lfs.attributes(ultipath .. '/' .. TEMPERATURE_FILE)
	local last_mod = file_attr.modification
	local last_mod = os.difftime (os.time(),last_mod)
	response:addData('last_mod', last_mod)

end

--requires id(int)
function M.progress(request, response)
	local argId,devpath,ultipath = getPrinterDataOrFail(request, response)
	if argId == nil then return end
	
	local f = io.open(ultipath .. '/' .. PROGRESS_FILE)
	
	if not f then
		response:setError("could not open progress file")
		response:addData('id', argId)
		return
	end
	
	local tempText = f:read('*all')
	f:close()

	local currentLine,numLines = tempText:match('(%d+)/(%d+)')
	
	response:setSuccess()

	if(currentLine == nil) then
		response:addData('printing', false)
	else 
		response:addData('printing', true)
		response:addData('current_line', currentLine)
		response:addData('num_lines', numLines)
	end

	-- get last modified time
	local file_attr = lfs.attributes(ultipath .. '/' .. PROGRESS_FILE)
	local last_mod = file_attr.modification
	local last_mod = os.difftime (os.time(),last_mod)
	response:addData('last_mod', last_mod)

end

--requires id(int)
function M.busy(request, response)
	local argId,devpath,ultipath = getPrinterDataOrFail(request, response)
	if argId == nil then return end
	
	local b,msg = isBusy(ultipath)
	
	if b == nil then
		response:setError("could not determine printer state")
		response:addData('msg', msg)
	else
		response:setSuccess()
		response:addData('busy', b)
	end
end


function M.printing(request, response)
	response:setError("not implemented")
	response:addData('api_refer', response:apiURL('printer', 'busy'))
end

--requires id(int)
function M.heatup_POST(request, response)
	local argId,devpath,ultipath = getPrinterDataOrFail(request, response)
	if argId == nil then return end
	
	local gcode = settings.get('printer.autoWarmUpCommand') .. "\n"
	local rv,msg = sendGcode(ultipath, gcode)
	
	if rv then
		response:setSuccess()
	elseif rv == false then
		response:setFail("printer is busy")
	else
		response:setError("could not send gcode")
		response:addData('msg', msg)
	end
end

--requires id(int)
function M.stop_POST(request, response)
	local argId,devpath,ultipath = getPrinterDataOrFail(request, response)
	if argId == nil then return end

	rv,msg = stopGcodeFile(ultipath)

	if rv then
		response:setSuccess()
	elseif rv == false then
		response:setFail("printer is busy")
	else
		response:setError("could not send gcode")
		response:addData('msg', msg)
	end
end

--requires id(int), gcode(string)
--accepts: first(bool) (chunks will be concatenated but output file will be cleared first if this argument is true)
--accepts: last(bool) (chunks will be concatenated and only when this argument is true will printing be started)
function M.print_POST(request, response)
	local argId,devpath,ultipath = getPrinterDataOrFail(request, response)
	if argId == nil then return end
	
	local gtFile = ultipath .. '/' .. GCODE_TMP_FILE

	local argGcode = request:get("gcode")
	local argIsFirst = utils.toboolean(request:get("first"))
	local argIsLast = utils.toboolean(request:get("last"))
	
	if argGcode == nil or argGcode == '' then
		response:setError("missing gcode argument")
		return
	end
	
	if argIsFirst == true then
		log:debug("clearing all gcode in " .. gtFile)
		response:addData('gcode_clear',true)
		os.remove(gtFile)
	end
	
	local rv,msg
	
	rv,msg = addToGcodeFile(ultipath, argGcode)
	if rv == nil then
		response:setError("could not add gcode")
		response:addData('msg', msg)
		return
	else
		--NOTE: this does not report the number of lines, but only the block which has just been added
		response:addData('gcode_append',argGcode:len())
	end
	
	if argIsLast == true then
		rv,msg = printGcodeFile(ultipath)
	
		if rv then
			response:setSuccess()
			response:addData('gcode_print',true)
		elseif rv == false then
			response:setFail("printer is busy")
		else
			response:setError("could not send gcode")
			response:addData('msg', msg)
		end
	else
		response:setSuccess()
	end
end

return M
