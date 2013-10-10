local lfs = require('lfs')
local log = require('util.logger')
local utils = require('util.utils')
local accessManager = require('util.access')
local printDriver = require('print3d')
local printerUtils = require('util.printer')
--local printerAPI = require('rest.api.api_printer')

local TMP_DIR = '/tmp'
local LOG_COLLECT_DIRNAME = 'wifibox-logs'
local LOG_COLLECT_DIR = TMP_DIR .. '/' .. LOG_COLLECT_DIRNAME
local WIFIBOX_LOG_FILENAME = 'wifibox.log'
local WIFIBOX_LOG_FILE = TMP_DIR .. '/' .. WIFIBOX_LOG_FILENAME
local SYSLOG_FILENAME = 'syslog'
local PRINT3D_BASEPATH = '/tmp'
local PRINT3D_LOG_FILENAME_PREFIX = 'print3d-'
local PRINT3D_LOG_FILENAME_SUFFIX = '.log'
local LOG_COLLECT_ARCHIVE_FILENAME = LOG_COLLECT_DIRNAME .. '.tgz'
local LOG_COLLECT_ARCHIVE_FILE = TMP_DIR .. '/' .. LOG_COLLECT_ARCHIVE_FILENAME

local function redirectedExecute(cmd)
	return os.execute(cmd .. " > /dev/null 2>&1")
end

local M = {
	isApi = true
}

function M._global(request, response)
	response:setSuccess()
end

function M.firmware(request, response)
	--response:setSuccess()
	-- can return (essentially all wraps ipkg output):
	-- available (list)
	-- current
	-- latest
	-- upgradable
end

-- TODO: redirect stdout+stderr; handle errors
function M.logfiles(request, response)
	local rv,msg = lfs.mkdir(LOG_COLLECT_DIR)
	local rv,msg = lfs.chdir(TMP_DIR)


	--[[ create temporary files ]]--

	local rv,sig,code = redirectedExecute('cp ' .. WIFIBOX_LOG_FILE .. ' ' .. LOG_COLLECT_DIR)

	local rv,sig,code = os.execute('logread > ' .. LOG_COLLECT_DIR .. '/' .. SYSLOG_FILENAME)

	for file in lfs.dir(PRINT3D_BASEPATH) do
		if file:find(PRINT3D_LOG_FILENAME_PREFIX) == 1 and file:find(PRINT3D_LOG_FILENAME_SUFFIX) ~= nil then
			local srcLogFile = PRINT3D_BASEPATH .. '/' .. file
			local tgtLogFile = LOG_COLLECT_DIR .. '/' .. file
			local rv,sig,code = redirectedExecute('cp ' .. srcLogFile .. ' ' .. tgtLogFile)
		end
	end

	local rv,sig,code = redirectedExecute('tar czf ' .. LOG_COLLECT_ARCHIVE_FILE .. ' ' .. LOG_COLLECT_DIRNAME) --returns 0 success, 1 error


	--[[ add response content ]]--

	local rv,msg = response:setBinaryFileData(LOG_COLLECT_ARCHIVE_FILE, LOG_COLLECT_ARCHIVE_FILENAME, 'application/x-compressed')
	if not rv then
		response:setError("could not set binary data from file '" .. LOG_COLLECT_ARCHIVE_FILE .. "' (" .. msg .. ")")
	else
		response:setSuccess()
	end


	--[[ remove temporary files ]]--

	if ultip and ultip == 'directory' then
		for file in lfs.dir(ULTIFI_PATH) do
			if file ~= '.' and file ~= '..' then
				local tgtLogFile = LOG_COLLECT_DIR .. '/' .. file .. '-' .. ULTIFI_LOG_FILENAME
				local rv,sig,code = redirectedExecute('rm ' .. tgtLogFile)
			end
		end
	end

	local rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. WIFIBOX_LOG_FILENAME)

	local rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. SYSLOG_FILENAME)

	local rv,msg = lfs.rmdir(LOG_COLLECT_DIR)

	local rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_ARCHIVE_FILE)
end

function M.access(request, response)
	--log:info("  remoteAddress: |"..utils.dump(request.remoteAddress).."|");
	--log:info("  controller: |"..utils.dump(accessManager.getController()).."|");

	-- when there is a controller we check if the printer is idle,
	-- if so, it should be done printing and we can clear the controller
	if accessManager.getController() ~= "" then
		local argId = request:get("id")
		local printer,msg = printerUtils.createPrinterOrFail(argId, response)
		local rv,msg = printer:getState()
		if rv then
			response:setSuccess()
			if(state == "idle") then -- TODO: define in constants somewhere
				accessManager.setController("") -- clear controller
			end
		else
			response:setError(msg)
			return
		end
	end

	local hasControl = accessManager.hasControl(request.remoteAddress)
	response:setSuccess()
	response:addData('hasControl', hasControl)

	return
end

function M.status(request, response)
	--[[
	local argId = request:get("id")
	local printer,msg = printerUtils.createPrinterOrFail(argId, response)
	if not printer then return end

	response:addData('id', argId)

	-- Temperature
	local temperatures,msg = printer:getTemperatures()
	if temperatures then
		response:setSuccess()
		response:addData('hotend', temperatures.hotend)
		response:addData('hotend_target', temperatures.hotend_target)
		response:addData('bed', temperatures.bed)
		response:addData('bed_target', temperatures.bed_target)
	else
		response:setError(msg)
		return
	end
	--TODO: reuse printer/temperature api

	-- Progress
	-- NOTE: despite their names, `currentLine` is still the error indicator and `numLines` the message in such case.
	local currentLine,numLines = printer:getProgress()
	if currentLine then
		response:setSuccess()
		response:addData('current_line', currentLine)
		response:addData('num_lines', numLines)
	else
		response:setError(numLines)
		return
	end
	--TODO: reuse printer/progress api

	-- State
	local rv,msg = printer:getState()
	if rv then
		response:setSuccess()
		response:addData('state', rv)
	else
		response:setError(msg)
		return
	end
	]]---
	----TODO: reuse printer/state api

	--printerAPI.temperature(request, response)
	--printerAPI.progress(request, response)
	--printerAPI.state(request, response)

	-- access
	M.access(request, response)

	response:addData('v', 8)

end

return M
