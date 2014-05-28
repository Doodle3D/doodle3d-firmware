--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


local lfs = require('lfs')
local log = require('util.logger')
local utils = require('util.utils')
local accessManager = require('util.access')
local printDriver = require('print3d')
local printerUtils = require('util.printer')
local printerAPI = require('rest.api.api_printer')
local wifi = require('network.wlanconfig')
local settings = require('util.settings')

local TMP_DIR = '/tmp'
local LOG_COLLECT_DIRNAME = 'wifibox-logs'
local LOG_COLLECT_DIR = TMP_DIR .. '/' .. LOG_COLLECT_DIRNAME
local WIFIBOX_LOG_FILENAME = 'wifibox.log'
local WIFIBOX_LOG_FILE = TMP_DIR .. '/' .. WIFIBOX_LOG_FILENAME

local SYSLOG_FILENAME = 'syslog'
local PROCESS_LIST_FILENAME = 'processes'
local MEMINFO_FILENAME = 'meminfo'
local MOUNTS_FILENAME = 'mounts'
local DISKFREE_FILENAME = 'diskfree'

local UCI_CONFIG_FILES_TO_SAVE = { 'dhcp', 'firewall', 'network', 'system', 'wifibox', 'wireless' }

local USB_DIRTREE_COMMAND = "ls -R /sys/devices/platform/ehci-platform/usb1 | grep \":$\" | sed -e 's/:$//' -e 's/[^-][^\\/]*\\//--/g' -e 's/^/   /' -e 's/-/|/'"
local USB_DIRTREE_FILENAME = 'sys_devices_platform_ehci-platform_usb1.tree'

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

-- returns wifiboxid (since version 0.10.2)
function M._global(request, response)
	response:setSuccess()
	
	local wifiboxid = wifi.getSubstitutedSsid(settings.get('network.cl.wifiboxid'))
	response:addData('wifiboxid', wifiboxid)
	
end

-- TODO: redirect stdout+stderr; handle errors
function M.logfiles(request, response)
	local rv,sig,code,msg = nil,nil,nil,nil

	rv,msg = lfs.mkdir(LOG_COLLECT_DIR)
	rv,msg = lfs.chdir(TMP_DIR)


	--[[ create temporary files ]]--

	-- copy wifibox API-script log
	rv,sig,code = redirectedExecute('cp ' .. WIFIBOX_LOG_FILE .. ' ' .. LOG_COLLECT_DIR)

	-- capture syslog
	rv,sig,code = os.execute('logread > ' .. LOG_COLLECT_DIR .. '/' .. SYSLOG_FILENAME)

	-- capture running processes
	rv,sig,code = os.execute('ps -w > ' .. LOG_COLLECT_DIR .. '/' .. PROCESS_LIST_FILENAME)

	-- capture info on RAM memory
	rv,sig,code = os.execute('cat /proc/meminfo > ' .. LOG_COLLECT_DIR .. '/' .. MEMINFO_FILENAME)

	-- capture info on mounted file systems
	rv,sig,code = os.execute('mount > ' .. LOG_COLLECT_DIR .. '/' .. MOUNTS_FILENAME)

	-- capture info on free disk space
	rv,sig,code = os.execute('df -h > ' .. LOG_COLLECT_DIR .. '/' .. DISKFREE_FILENAME)

	-- list directory structure for primary USB controller
	rv,sig,code = os.execute(USB_DIRTREE_COMMAND .. ' > ' .. LOG_COLLECT_DIR .. '/' .. USB_DIRTREE_FILENAME)

	-- copy relevant openwrt configuration files
	rv,msg = lfs.mkdir(LOG_COLLECT_DIR .. '/config')
	for _,v in pairs(UCI_CONFIG_FILES_TO_SAVE) do
		local srcFile = '/etc/config/' .. v
		local tgtFile = LOG_COLLECT_DIR .. '/config/' .. v
		if v ~= 'wireless' then
			rv,sig,code = redirectedExecute('cp ' .. srcFile .. ' ' .. tgtFile)
		else
			rv,sig,code = os.execute("sed \"s/option key '.*'/option key '...'/g\" " .. srcFile .. " > " .. tgtFile)
		end
	end

	-- collect and copy print3d server logs
	for file in lfs.dir(PRINT3D_BASEPATH) do
		if file:find(PRINT3D_LOG_FILENAME_PREFIX) == 1 and file:find(PRINT3D_LOG_FILENAME_SUFFIX) ~= nil then
			local srcLogFile = PRINT3D_BASEPATH .. '/' .. file
			local tgtLogFile = LOG_COLLECT_DIR .. '/' .. file
			rv,sig,code = redirectedExecute('cp ' .. srcLogFile .. ' ' .. tgtLogFile)
			end
		end

	rv,sig,code = redirectedExecute('tar czf ' .. LOG_COLLECT_ARCHIVE_FILE .. ' ' .. LOG_COLLECT_DIRNAME) --returns 0 success, 1 error


	--[[ add response content ]]--

	rv,msg = response:setBinaryFileData(LOG_COLLECT_ARCHIVE_FILE, LOG_COLLECT_ARCHIVE_FILENAME, 'application/x-compressed')
	if not rv then
		response:setError("could not set binary data from file '" .. LOG_COLLECT_ARCHIVE_FILE .. "' (" .. msg .. ")")
	else
		response:setSuccess()
	end


	--[[ remove temporary files ]]--

	for file in lfs.dir(LOG_COLLECT_DIR) do
		if file:find(PRINT3D_LOG_FILENAME_PREFIX) == 1 and file:find(PRINT3D_LOG_FILENAME_SUFFIX) ~= nil then
			local tgtLogFile = LOG_COLLECT_DIR .. '/' .. file
			rv,sig,code = redirectedExecute('rm ' .. tgtLogFile)
		end
	end

	rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/config/*')
	rv,msg = lfs.rmdir(LOG_COLLECT_DIR .. '/config')

	rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. USB_DIRTREE_FILENAME)
	rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. DISKFREE_FILENAME)
	rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. MOUNTS_FILENAME)
	rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. MEMINFO_FILENAME)
	rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. PROCESS_LIST_FILENAME)
	rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. SYSLOG_FILENAME)
	rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_DIR .. '/' .. WIFIBOX_LOG_FILENAME)

	rv,msg = lfs.rmdir(LOG_COLLECT_DIR)

	rv,sig,code = redirectedExecute('rm ' .. LOG_COLLECT_ARCHIVE_FILE)
end

function M.access(request, response)
	--log:info("  remoteAddress: |"..utils.dump(request.remoteAddress).."|");
	--log:info("  controller: |"..utils.dump(accessManager.getController()).."|");

	local hasControl = accessManager.hasControl(request.remoteAddress)
	-- if hasControl then log:info("  hasControl: true")
	-- else log:info("  hasControl: false") end
	response:setSuccess()
	response:addData('has_control', hasControl)

	return true
end

function M.status(request, response)

	local rv, state = printerAPI.state(request, response)
	if(rv == false) then return end

	if state ~= "disconnected" and state ~= "connecting" then
		rv = printerAPI.temperature(request, response)
		if(rv == false) then return end
		rv = printerAPI.progress(request, response)
		if(rv == false) then return end
		rv = M.access(request, response)
		if(rv == false) then return end
	end
end

return M
