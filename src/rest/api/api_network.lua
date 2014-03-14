--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


local log = require('util.logger')
local settings = require('util.settings')
local utils = require('util.utils')
local netconf = require('network.netconfig')
local wifi = require('network.wlanconfig')
local ResponseClass = require('rest.response')
local signin = require('network.signin')
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


function M._global(request, response)
	response:setError("not implemented")
end

--accepts API argument 'nofilter'(bool) to disable filtering of APs and 'self'
--accepts with_raw(bool) to include raw table dump
function M.scan(request, response)
	local noFilter = utils.toboolean(request:get("nofilter"))
	local withRaw = utils.toboolean(request:get("with_raw"))
	local sr = wifi.getScanInfo()
	local si, se

	if sr and #sr > 0 then
		response:setSuccess("")
		local netInfoList = {}
		for _, se in ipairs(sr) do
			if noFilter or se.mode ~= "ap" and se.ssid ~= wifi.getSubstitutedSsid(settings.get('network.ap.ssid')) then
				local netInfo = {}

				netInfo["ssid"] = se.ssid
				netInfo["bssid"] = se.bssid
				netInfo["channel"] = se.channel
				netInfo["mode"] = wifi.mapDeviceMode(se.mode)
				netInfo["encryption"] = wifi.mapEncryptionType(se.encryption)
				netInfo["signal"] = se.signal
				netInfo["quality"] = se.quality
				netInfo["quality_max"] = se.quality_max
				if withRaw then netInfo["_raw"] = utils.dump(se) end

				table.insert(netInfoList, netInfo)
			end
		end
		response:addData("count", #netInfoList)
		response:addData("networks", netInfoList)
	else
		response:setFail("No scan results or scanning not possible")
	end
end

--accepts API argument 'nofilter'(bool) to disable filtering of APs and 'self'
--accepts with_raw(bool) to include raw table dump
function M.known(request, response)
	local noFilter = utils.toboolean(request:get("nofilter"))
	local withRaw = utils.toboolean(request:get("with_raw"))

	response:setSuccess()
	local netInfoList = {}
	for _, net in ipairs(wifi.getConfigs()) do
		if noFilter or net.mode == "sta" then
			local netInfo = {}
			netInfo["ssid"] = net.ssid
			netInfo["bssid"] = net.bssid or ""
			netInfo["channel"] = net.channel or ""
			netInfo["encryption"] = net.encryption
			if withRaw then netInfo["_raw"] = utils.dump(net) end
			table.insert(netInfoList, netInfo)
		end
	end
	response:addData("count", #netInfoList)
	response:addData("networks", netInfoList)
end

--accepts with_raw(bool) to include raw table dump
function M.status(request, response)
	local withRaw = utils.toboolean(request:get("with_raw"))
	local ds = wifi.getDeviceState()

	local statusCode, statusMessage = netconf.getStatus()
	response:addData("status",statusCode)
	response:addData("statusMessage",statusMessage)
	response:setSuccess(statusMessage)

	response:addData("ssid", ds.ssid or "")
	response:addData("bssid", ds.bssid or "")
	response:addData("channel", ds.channel or "")
	response:addData("mode", ds.mode)
	response:addData("encryption", ds.encryption)
	response:addData("quality", ds.quality)
	response:addData("quality_max", ds.quality_max)
	response:addData("txpower", ds.txpower)
	response:addData("signal", ds.signal)
	response:addData("noise", ds.noise)



	if withRaw then response:addData("_raw", utils.dump(ds)) end

	local localip = wifi.getLocalIP()
	response:addData("localip", localip)
end

--requires ssid(string), accepts phrase(string), recreate(bool)
function M.associate_POST(request, response)
	local argSsid = request:get("ssid")
	local argPhrase = request:get("phrase")
	local argRecreate = request:get("recreate")

	if argSsid == nil or argSsid == "" then
		response:setError("missing ssid argument")
		return
	end

	if not operationsAccessOrFail(request, response) then return end

	response:setSuccess("wlan is trying to associate")

	local rv,msg = netconf.associateSsid(argSsid, argPhrase, argRecreate)
	if rv then
		log:info("associated to wifi: "..utils.dump(argSsid))
	else
		log:info("failed to associate to wifi: "..utils.dump(argSsid).." ("..utils.dump(msg)..")")
	end

end

function M.disassociate_POST(request, response)
	if not operationsAccessOrFail(request, response) then return end

	local rv = netconf.disassociate()

	response:setSuccess("all wireless networks deactivated")
	response:addData("wifi_restart_result", rv)
end

function M.openap_POST(request, response)
	if not operationsAccessOrFail(request, response) then return end

	local ssid = wifi.getSubstitutedSsid(settings.get('network.ap.ssid'))
	local rv,msg = netconf.setupAccessPoint(ssid)

	response:addData("ssid", ssid)
	if rv then
		response:setSuccess("switched to Access Point mode")
	else
		response:setFail("could not switch to Access Point mode")
		response:addData("msg", msg)
	end
end

--requires ssid(string)
function M.remove_POST(request, response)
	local argSsid = request:get("ssid")

	if argSsid == nil or argSsid == "" then
		response:setError("missing ssid argument")
		return
	end

	if not operationsAccessOrFail(request, response) then return end

	if wifi.removeConfig(argSsid) then
		response:setSuccess("removed wireless network with requested SSID")
		response:addData("ssid", argSsid)
	else
		response:setFail("no wireless network with requested SSID") --this used to be a warning instead of an error...
		response:addData("ssid", argSsid)
	end
end

function M.signin(request, response)
	log:info("API:Network:signin")
	local success, output = signin.signin()
	if success then
  		log:info("API:Network:signed in")
  		response:setSuccess("API:Network:signed in")
  		response:addData("response", output)
	else
		log:info("API:Network:Signing in failed")
		response:setError("Signing in failed")
	end
end

function M.alive(request, response)
	response:setSuccess("alive")
end

return M
