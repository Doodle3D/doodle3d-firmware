--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


local wifi = require('network.wlanconfig')
local netconf = require('network.netconfig')
local settings = require('util.settings')

-- NOTE: the updater module 'detects' command-line invocation by existence of 'arg', so we have to make sure it is not defined.
argStash = arg
arg = nil
local updater = require('script.d3d-updater')
arg = argStash

local log = require('util.logger')
local utils = require('util.utils')
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
	-- NOTE: rv being false means a printer device exists but no server is running for it, so it cannot be 'busy'
	if rv == false then return true end

	if printerState == 'buffering' or printerState == 'printing' or printerState == 'stopping' then
		response:setFail("Printer is busy, please wait")
		return false
	end

	return true
end


function M.status(request, response)
	local includeBetas = settings.get('doodle3d.update.includeBetas')
	local baseUrl = settings.get('doodle3d.update.baseUrl')
	updater.setLogger(log)
	updater.setBaseUrl(baseUrl)
	updater.setUseCache(false)
	local success,status,msg = updater.getStatus(includeBetas)

	response:addData('current_version', updater.formatVersion(status.currentVersion))

	response:addData('state_code', status.stateCode)
	response:addData('state_text', status.stateText)

	if not success then
		response:setFail(msg)
		return
	end

	local canUpdate = updater.compareVersions(status.newestVersion, status.currentVersion, status.newestReleaseTimestamp, status.currentReleaseTimestamp) > 0
	if (status.currentVersion.suffix ~= nil) and not includeBetas then canUpdate = true end -- always allow downgrade from beta to stable if !includeBetas

	response:addData('newest_version', updater.formatVersion(status.newestVersion))
	if status.currentReleaseTimestamp then response:addData('current_release_date', updater.formatDate(status.currentReleaseTimestamp)) end
	if status.newestReleaseTimestamp then response:addData('newest_release_date', updater.formatDate(status.newestReleaseTimestamp)) end
	response:addData('can_update', canUpdate)

	if status.progress then response:addData('progress', status.progress) end
	if status.imageSize then response:addData('image_size', status.imageSize) end
	response:setSuccess()
end

-- accepts: version(string) (major.minor.patch)
-- accepts: clear_gcode(bool, defaults to true) (this is to lower the chance on out-of-memory crashes, but still allows overriding this behaviour)
-- accepts: clear_images(bool, defaults to true) (same rationale as with clear_gcode)
-- note: call this with a long timeout - downloading may take a while (e.g. ~3.3MB with slow internet...)
function M.download_POST(request, response)
	local argVersion = request:get("version")
	local argClearGcode = utils.toboolean(request:get("clear_gcode"))
	local argClearImages = utils.toboolean(request:get("clear_images"))
	if argClearGcode == nil then argClearGcode = true end
	if argClearImages == nil then argClearImages = true end

	-- block access to prevent potential issues with printing (e.g. out of memory)
	if not operationsAccessOrFail(request, response) then return end

	local includeBetas = settings.get('doodle3d.update.includeBetas')
	local baseUrl = settings.get('doodle3d.update.baseUrl')
	updater.setLogger(log)
	updater.setBaseUrl(baseUrl)

	updater.setState(updater.STATE.DOWNLOADING,"")

	local vEnt, rv, msg

	if not argVersion then
		local success,status,msg = updater.getStatus(includeBetas)
		if not success then
			updater.setState(updater.STATE.DOWNLOAD_FAILED, msg)
			response:setFail(msg)
			return
		else
			argVersion = updater.formatVersion(status.newestVersion)
		end
	end

	if argClearImages then
		rv,msg = updater.clear()
		if not rv then
			updater.setState(updater.STATE.DOWNLOAD_FAILED, msg)
			response:setFail(msg)
			return
		end
	end

	if argClearGcode then
		response:addData('gcode_clear',true)
		local rv,msg = printer:clearGcode()

		if not rv then
			updater.setState(updater.STATE.DOWNLOAD_FAILED, msg)
			response:setError(msg)
			return
		end
	end

	vEnt,msg = updater.findVersion(argVersion, includeBetas)
	if vEnt == nil then
		updater.setState(updater.STATE.DOWNLOAD_FAILED, "error searching version index (" .. msg .. ")")
		response:setFail("error searching version index (" .. msg .. ")")
		return
	elseif vEnt == false then
		updater.setState(updater.STATE.DOWNLOAD_FAILED, "no such version")
		response:setFail("no such version")
		return
	end

	rv,msg = updater.downloadImageFile(vEnt)
	if not rv then
		updater.setState(updater.STATE.DOWNLOAD_FAILED, msg)
		response:setFail(msg)
		return
	end

	response:setSuccess()
end

-- if successful, this call won't return since the device will flash its memory and reboot
-- accepts: version (string, will try to use most recent if not specified)
-- accepts: no_retain (bool, device will be completely cleaned if true (aka '-n' flag to sysupgrade))
function M.install_POST(request, response)
	local argVersion = request:get("version")
	local argNoRetain = request:get("no_retain")
	log:info("API:update/install (noRetain: "..utils.dump(argNoRetain)..")")
	local noRetain = argNoRetain == 'true'

	if not operationsAccessOrFail(request, response) then return end

	local includeBetas = settings.get('doodle3d.update.includeBetas')
	local baseUrl = settings.get('doodle3d.update.baseUrl')
	updater.setBaseUrl(baseUrl)
	updater.setLogger(log)
	updater.setState(updater.STATE.INSTALLING,"")

	--local ssid = wifi.getSubstitutedSsid(settings.get('network.ap.ssid'))
	--local rv,msg = netconf.enableAccessPoint(ssid)

	if not argVersion then
		local success,status,msg = updater.getStatus(includeBetas)
		if not success then
			updater.setState(updater.STATE.INSTALL_FAILED, msg)
			response:setFail(msg)
			return
		else
			argVersion = updater.formatVersion(status.newestVersion)
		end
	end

	vEnt,msg = updater.findVersion(argVersion, includeBetas)
	if vEnt == nil then
		updater.setState(updater.STATE.INSTALL_FAILED, "error searching version index (" .. msg .. ")")
		response:setFail("error searching version index (" .. msg .. ")")
		return
	elseif vEnt == false then
		updater.setState(updater.STATE.INSTALL_FAILED, "no such version")
		response:setFail("no such version")
		return
	end

	local rv,msg = updater.flashImageVersion(vEnt, noRetain)

	if not rv then
		updater.setState(updater.STATE.INSTALL_FAILED, "installation failed (" .. msg .. ")")
		response:setFail("installation failed (" .. msg .. ")")
	else
		response:setSuccess()
	end
end

function M.clear_POST(request, response)
	updater.setLogger(log)
	local rv,msg = updater.clear()

	if rv then response:setSuccess()
	else response:setFail(msg)
	end
end

return M
