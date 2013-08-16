local lfs = require('lfs')

local TMP_DIR = '/tmp'
local LOG_COLLECT_DIRNAME = 'wifibox-logs'
local LOG_COLLECT_DIR = TMP_DIR .. '/' .. LOG_COLLECT_DIRNAME
local WIFIBOX_LOG_FILENAME = 'wifibox.log'
local WIFIBOX_LOG_FILE = TMP_DIR .. '/' .. WIFIBOX_LOG_FILENAME
local ULTIFI_PATH = '/tmp/UltiFi'
local SYSLOG_FILENAME = 'syslog'
local ULTIFI_LOG_FILENAME = 'server.log'
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
	
	for file in lfs.dir(ULTIFI_PATH) do
		if file ~= '.' and file ~= '..' then
			local srcLogFile = ULTIFI_PATH .. '/' .. file .. '/' .. ULTIFI_LOG_FILENAME
			local tgtLogFile = LOG_COLLECT_DIR .. '/' .. file .. '-' .. ULTIFI_LOG_FILENAME
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
	
	for file in lfs.dir(ULTIFI_PATH) do
		if file ~= '.' and file ~= '..' then
			local tgtLogFile = LOG_COLLECT_DIR .. '/' .. file .. '-' .. ULTIFI_LOG_FILENAME
			local rv,sig,code = redirectedExecute('rm ' .. tgtLogFile)
		end
	end
	
	local rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. WIFIBOX_LOG_FILENAME)
	
	local rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. SYSLOG_FILENAME)
	
	local rv,msg = lfs.rmdir(LOG_COLLECT_DIR)
	
	local rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_ARCHIVE_FILE)
end

return M
