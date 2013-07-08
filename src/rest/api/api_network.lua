local l = require("logger")
local u = require("util.utils")
local netconf = require("network.netconfig")
local wifi = require("network.wlanconfig")
local ResponseClass = require("rest.response")

local M = {}

M.isApi = true

function M._global(d)
	local r = ResponseClass.new(d)
	r:setError("not implemented")
	return r
end

--accepts API argument 'nofilter'(bool) to disable filtering of APs and 'self'
function M.available(d)
	local r = ResponseClass.new(d)
	local noFilter = u.toboolean(d:get("nofilter"))
	local sr = wifi.getScanInfo()
	local si, se
	
	if sr and #sr > 0 then
		r:setSuccess("")
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
				--netInfo["raw"] = l:dump(se) --TEMP for debugging only
				
				table.insert(netInfoList, netInfo)
			end
		end
		r:addData("count", #netInfoList)
		r:addData("networks", netInfoList)
	else
		r:setError("No scan results or scanning not possible")
	end
	
	return r
end

--accepts API argument 'nofilter'(bool) to disable filtering of APs and 'self'
function M.known(d)
	local r = ResponseClass.new(d)
	local noFilter = u.toboolean(d:get("nofilter"))
	
	r:setSuccess()
	local netInfoList = {}
	for _, net in ipairs(wifi.getConfigs()) do
		if noFilter or net.mode == "sta" then
			local netInfo = {}
			netInfo["ssid"] = net.ssid
			netInfo["bssid"] = net.bssid or ""
			netInfo["channel"] = net.channel or ""
			netInfo["encryption"] = net.encryption
			netInfo["raw"] = l:dump(net) --TEMP for debugging only
			table.insert(netInfoList, netInfo)
		end
	end
	r:addData("count", #netInfoList)
	r:addData("networks", netInfoList)
	
	return r
end

function M.state(d)
	local r = ResponseClass.new(d)
	local ds = wifi.getDeviceState()
	
	r:setSuccess()
	r:addData("ssid", ds.ssid or "")
	r:addData("bssid", ds.bssid or "")
	r:addData("channel", ds.channel or "")
	r:addData("mode", ds.mode)
	r:addData("raw", l:dump(ds)) --TEMP for debugging only
	
	return r
end

--UNTESTED
--requires ssid(string), accepts phrase(string), recreate(bool)
function M.assoc(d)
	local r = ResponseClass.new(d)
	local argSsid = d:get("ssid")
	local argPhrase = d:get("phrase")
	local argRecreate = d:get("recreate")
	
	if argSsid == nil or argSsid == "" then
		r:setError("missing ssid argument")
		return r
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
			r:setError("no wireless network with requested SSID is available")
			r:addData("ssid", argSsid)
		end
	end
	
	wifi.activateConfig(argSsid)
	netconf.switchConfiguration{ wifiiface="add", apnet="rm", staticaddr="rm", dhcppool="rm", wwwredir="rm", dnsredir="rm", wwwcaptive="rm", wireless="reload" }
	r:setSuccess("wlan associated")
	r:addData("ssid", argSsid)
	
	return r
end

--UNTESTED
function M.disassoc(d)
	local r = ResponseClass.new(d)
	
	wifi.activateConfig()
	local rv = wifi.restart()
	r:setSuccess("all wireless networks deactivated")
	r:addData("wifi_restart_result", rv)
	
	return r
end

--UNTESTED
function M.openap(d)
	local r = ResponseClass.new(d)

	--add AP net, activate it, deactivate all others, reload network/wireless config, add all dhcp and captive settings and reload as needed
	netconf.switchConfiguration{apnet="add_noreload"}
	wifi.activateConfig(wifi.AP_SSID)
	netconf.switchConfiguration{ wifiiface="add", network="reload", staticaddr="add", dhcppool="add", wwwredir="add", dnsredir="add", wwwcaptive="add" }
	r:setSuccess("switched to Access Point mode")
	r:addData("ssid", wifi.AP_SSID)
	
	return r
end

--UNTESTED
--requires ssid(string)
function M.rm(d)
	local r = ResponseClass.new(d)
	local argSsid = d:get("ssid")
	
	if argSsid == nil or argSsid == "" then
		r:setError("missing ssid argument")
		return r
	end
	
	if wifi.removeConfig(argSsid) then
		r:setSuccess("removed wireless network with requested SSID")
		r:addData("ssid", argSsid)
	else
		r:setError("no wireless network with requested SSID") --this used to be a warning instead of an error...
		r:addData("ssid", argSsid)
	end
	
	return r
end

return M
