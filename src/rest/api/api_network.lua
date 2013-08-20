local settings = require("util.settings")
local utils = require("util.utils")
local netconf = require("network.netconfig")
local wifi = require("network.wlanconfig")
local ResponseClass = require("rest.response")

local M = {
	isApi = true
}


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
	
	response:setSuccess()
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

	local cfg = nil
	for _, net in ipairs(wifi.getConfigs()) do
		if net.mode ~= "ap" and net.ssid == argSsid then
			cfg = net
			break
		end
	end
	
	if cfg == nil or argRecreate ~= nil then
		local scanResult = wifi.getScanInfo(argSsid)
		if scanResult ~= nil then
			wifi.createConfigFromScanInfo(scanResult, argPhrase)
		else
			--check for error
			response:setFail("no wireless network with requested SSID is available")
			response:addData("ssid", argSsid)
			return
		end
	end
	
	wifi.activateConfig(argSsid)
	--netconf.switchConfiguration{ wifiiface="add", apnet="rm", staticaddr="rm", dhcppool="rm", wwwredir="rm", dnsredir="rm", wwwcaptive="rm", wireless="reload" }
	netconf.switchConfiguration{ wifiiface="add", apnet="rm", staticaddr="rm", dhcppool="rm", wwwredir="rm", dnsredir="rm", wireless="reload" }
	
	local status = wifi.getDeviceState()
	response:addData("ssid", argSsid)
	if status.ssid and status.ssid ==  argSsid then
		response:setSuccess("wlan associated")
	else
		response:setFail("could not associate with network (incorrect pass phrase?)")
	end
end

function M.disassociate_POST(request, response)
	wifi.activateConfig()
	local rv = wifi.restart()
	response:setSuccess("all wireless networks deactivated")
	response:addData("wifi_restart_result", rv)
end

function M.openap_POST(request, response)
	local ssid = wifi.getSubstitutedSsid(settings.get('network.ap.ssid'))
	netconf.switchConfiguration{apnet="add_noreload"}
	wifi.activateConfig(ssid)
	-- NOTE: dnsmasq must be reloaded after network or it will be unable to serve IP addresses
	netconf.switchConfiguration{ wifiiface="add", network="reload", staticaddr="add", dhcppool="add_noreload", wwwredir="add", dnsredir="add" }
	netconf.switchConfiguration{dhcp="reload"}
	response:setSuccess("switched to Access Point mode")
	response:addData("ssid", ssid)
end

--requires ssid(string)
function M.remove_POST(request, response)
	local argSsid = request:get("ssid")
	
	if argSsid == nil or argSsid == "" then
		response:setError("missing ssid argument")
		return
	end
	
	if wifi.removeConfig(argSsid) then
		response:setSuccess("removed wireless network with requested SSID")
		response:addData("ssid", argSsid)
	else
		response:setFail("no wireless network with requested SSID") --this used to be a warning instead of an error...
		response:addData("ssid", argSsid)
	end
end

return M
