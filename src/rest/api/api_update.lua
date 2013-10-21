-- NOTE: the module 'detects' command-line invocation by existence of 'arg', so we have to make sure it is not defined.
argStash = arg
arg = nil
local updater = require('script.d3d-updater')
arg = argStash

local log = require('util.logger')
local utils = require('util.utils')

local M = {
	isApi = true
}

function M.status(request, response)
	updater.setLogger(log)
	updater.setUseCache(false)
	local status,msg = updater.getStatus()
	if not status then
		response:setFail(msg)
		return
	end

	local canUpdate = updater.compareVersions(status.newestVersion, status.currentVersion) > 0

	response:addData('current_version', updater.formatVersion(status.currentVersion))
	response:addData('newest_version', updater.formatVersion(status.newestVersion))
	--response:addData('current_version', status.currentVersion)
	--response:addData('newest_version', status.newestVersion)
	response:addData('can_update', canUpdate)
	response:addData('state_code', status.stateCode)
	response:addData('state_text', status.stateText)
	if status.progress then response:addData('progress', status.progress) end
	if status.imageSize then response:addData('image_size', status.imageSize) end
	response:setSuccess()
end

-- requires: version(string) (major.minor.patch)
-- accepts: clear_gcode(bool, defaults to true) (this is to lower the chance on out-of-memory crashes, but still allows overriding this behaviour)
-- accepts: clear_images(bool, defaults to true) (same rationale as with clear_gcode)
-- note: call this with a long timeout - downloading may take a while (e.g. ~3.3MB with slow internet...)
function M.download_POST(request, response)
	local argVersion = request:get("version")
	local argClearGcode = utils.toboolean(request:get("clear_gcode"))
	local argClearImages = utils.toboolean(request:get("clear_images"))
	if argClearGcode == nil then argClearGcode = true end
	if argClearImages == nil then argClearImages = true end

	if not argVersion then
		response:setError("missing version argument")
		return
	end

	updater.setLogger(log)
	local vEnt, rv, msg

	if argClearImages then
		rv,msg = updater.clear()
		if not rv then
			response:setFail(msg)
			return
		end
	end

	if argClearGcode then
response:addData('gcode_clear',true)
local rv,msg = printer:clearGcode()

if not rv then
	response:setError(msg)
	return
end
	end

	vEnt,msg = updater.findVersion(argVersion)
	if vEnt == nil then
		response:setFail("error searching version index (" .. msg .. ")")
		return
	else if vEnt == false then
		response:setFail("no such version")
		return
	end

	rv,msg = updater.downloadImageFile(vEnt)
	if not rv then
		response:setFail(msg)
		return
	end

	response:setSuccess()
end

-- if successful, this call won't return since the device will flash its memory and reboot
function M.install_POST(request, response)
	local argVersion = request:get("version")
	updater.setLogger(log)

	if not argVersion then
		response:setError("missing version argument")
		return
	end

	local rv,msg = updater.flashImageVersion(argVersion)

	if not rv then response:setFail("installation failed (" .. msg .. ")")
	else response:setSuccess()
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
