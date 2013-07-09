local l = require("logger")
local u = require("util.utils")
local netconf = require("network.netconfig")
local wifi = require("network.wlanconfig")
local ResponseClass = require("rest.response")

local M = {}

M.isApi = true

function M._global(request, response)
	response:setError("not implemented")
end

--accepts API argument 'nofilter'(bool) to disable filtering of APs and 'self'
--accepts with_raw(bool) to include raw table dump
function M.available(request, response)
	local noFilter = u.toboolean(request:get("nofilter"))
	local withRaw = u.toboolean(request:get("with_raw"))
	local sr = wifi.getScanInfo()
	local si, se
	
	if sr and #sr > 0 then
		response:setSuccess("")
		local netInfoList = {}
		for _, se in ipairs(sr) do
			if noFilter or se.mode ~= "ap" and se.ssid ~= wifi.AP_SSID then
				local netInfo = {}
				
				netInfo["ssid"] = se.ssid
				netInfo["bssid"] = se.bssid
				netInfo["channel"] = se.channel
				netInfo["mode"] = wifi.mapDeviceMode(se.mode)
				netInfo["encryption"] = wifi.mapEncryptionType(se.encryption)
				netInfo["signal"] = se.signal
				netInfo["quality"] = se.quality
				netInfo["quality_max"] = se.quality_max
				if withRaw then netInfo["_raw"] = l:dump(se) end
				
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
	local noFilter = u.toboolean(request:get("nofilter"))
	local withRaw = u.toboolean(request:get("with_raw"))
	
	response:setSuccess()
	local netInfoList = {}
	for _, net in ipairs(wifi.getConfigs()) do
		if noFilter or net.mode == "sta" then
			local netInfo = {}
			netInfo["ssid"] = net.ssid
			netInfo["bssid"] = net.bssid or ""
			netInfo["channel"] = net.channel or ""
			netInfo["encryption"] = net.encryption
			if withRaw then netInfo["_raw"] = l:dump(net) end
			table.insert(netInfoList, netInfo)
		end
	end
	response:addData("count", #netInfoList)
	response:addData("networks", netInfoList)
end

--accepts with_raw(bool) to include raw table dump
function M.state(request, response)
	local withRaw = u.toboolean(request:get("with_raw"))
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
	if withRaw then response:addData("_raw", l:dump(ds)) end
end

--UNTESTED
--requires ssid(string), accepts phrase(string), recreate(bool)
function M.assoc(request, response)
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
	netconf.switchConfiguration{ wifiiface="add", apnet="rm", staticaddr="rm", dhcppool="rm", wwwredir="rm", dnsredir="rm", wwwcaptive="rm", wireless="reload" }
	response:setSuccess("wlan associated")
	response:addData("ssid", argSsid)
end

--UNTESTED
function M.disassoc(request, response)
	wifi.activateConfig()
	local rv = wifi.restart()
	response:setSuccess("all wireless networks deactivated")
	response:addData("wifi_restart_result", rv)
end

--UNTESTED
function M.openap(request, response)
	--add AP net, activate it, deactivate all others, reload network/wireless config, add all dhcp and captive settings and reload as needed
	netconf.switchConfiguration{apnet="add_noreload"}
	wifi.activateConfig(wifi.AP_SSID)
	netconf.switchConfiguration{ wifiiface="add", network="reload", staticaddr="add", dhcppool="add", wwwredir="add", dnsredir="add", wwwcaptive="add" }
	response:setSuccess("switched to Access Point mode")
	response:addData("ssid", wifi.AP_SSID)
end

--UNTESTED
--requires ssid(string)
function M.rm(request, response)
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
