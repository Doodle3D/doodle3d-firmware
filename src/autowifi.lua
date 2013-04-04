--[[
	Response format:
	["OK" | "WARN" | "ERR"]<,{message}>
	{comma-separated line 1}
	...
	{comma-separated line n}
	  
	- see autowifi.js for TODO
	- general info on wireless config: http://wiki.openwrt.org/doc/uci/wireless
	- uci docs: http://wiki.openwrt.org/doc/techref/uci
	- parse/generate urls: https://github.com/keplerproject/cgilua/blob/master/src/cgilua/urlcode.lua
	- utility functions: http://luci.subsignal.org/trac/browser/luci/trunk/libs/sys/luasrc/sys.lua
	- iwinfo tool source: http://luci.subsignal.org/trac/browser/luci/trunk/contrib/package/iwinfo/src/iwinfo.lua?rev=7919
	- captive portal -> redirect all web traffic to one page for auth (or network selection)
	  http://wiki.openwrt.org/doc/howto/wireless.hotspot
  ]]
--print ("HTTP/1.0 200 OK")
print ("Content-type: text/plain\r\n")

local util = require("util")
local wifi = require("wifihelper")
local uci = require("uci").cursor()
local urlcode = require("urlcode")
local iwinfo = require("iwinfo")

local argOperation, argDevice, argSsid, argPhrase, argRecreate
local errortext = nil

function init()
	local qs = os.getenv("QUERY_STRING")
	local urlargs = {}
	urlcode.parsequery(qs, urlargs)

	--supplement urlargs with arguments from the command-line
	for _, v in ipairs(arg) do
		local split = v:find("=")
		if split ~= nil then
			urlargs[v:sub(1, split - 1)] = v:sub(split + 1)
		end
	end

	argOperation = urlargs["op"]
	argDevice = urlargs["dev"] or DFL_DEVICE
	argSsid = urlargs["ssid"]
	argPhrase = urlargs["phrase"]
	argRecreate = urlargs["recreate"]

	if urlargs["echo"] ~= nil then
		print("[[echo: '"..qs.."']]");
	end

	if argOperation == nil then
		errortext = "Missing operation specifier"
		return false
	end

	return wifi.init()
end


function main()
	if argOperation == "getavl" then
		local sr = wifi.getScanInfo()
		local si, se
	
		if sr and #sr > 0 then
			for _, se in ipairs(sr) do
				--print("[[   " .. util.dump(se) .. "   ]]") --TEMP
				util.printWithSuccess(#sr .. " network(s) found");
				print(se.ssid .. "," .. se.bssid .. "," .. se.channel .. "," .. wifi.mapDeviceMode(se.mode))
			end
		else
			util.exitWithError("No scan results or scanning not possible")
		end
	
	elseif argOperation == "getknown" then
		for _, net in ipairs(wifi.getConfigs()) do
			if net.mode == "sta" then
				local bssid = net.bssid or "<unknown BSSID>"
				local channel = net.channel or "<unknown channel>"
				util.printWithSuccess("")
				print(net.ssid .. "," .. bssid .. "," .. channel)
			end
		end
	
	elseif argOperation == "getstate" then
		local ds = wifi.getDeviceState()
		local ssid = ds.ssid or "<unknown SSID>"
		local bssid = ds.bssid or "<unknown BSSID>"
		local channel = ds.channel or "<unknown channel>"
		util.printWithSuccess("");
		print(ssid .. "," .. bssid .. "," .. channel .. "," .. ds.mode)
	
	elseif argOperation == "assoc" then
		if argSsid == nil or argSsid == "" then util.exitWithError("Please supply an SSID to associate with") end
		
		local cfg = nil
		for _, net in ipairs(wifi.getConfigs()) do
			if net.mode ~= "ap" and net.ssid == argSsid then
				cfg = net
				break
			end
		end
		if cfg == nil or argRecreate ~= nil then
			scanResult = wifi.getScanInfo(argSsid)
			if scanResult ~= nil then
				wifi.createConfigFromScanInfo(scanResult)
			else
				--check for error
				util.exitWithError("No wireless network with SSID '" .. argSsid .. "' is available")
			end
		end
		wifi.activateConfig(argSsid)
		--restartWlan()
		util.printWithSuccess("");
		print("Wlan associated with network "..argSsid.."! (dummy mode, not restarting)")
	
	elseif argOperation == "disassoc" then
		wifi.activateConfig()
		--restartWlan()
		exitWithSuccess("Deactivated all wireless networks (dummy mode, not restarting)")
	
	elseif argOperation == "rm" then
		if argSsid == nil or argSsid == "" then util.exitWithError("Please supply an SSID to remove") end
		if wifi.removeConfig(argSsid) then
			exitWithSuccess("Removed wireless network with SSID " .. argSsid)
		else
			exitWithWarning("No wireless network with SSID " .. argSsid)
		end
	
	elseif argOperation == "auto" then
		exitWithWarning("Not implemented");
		--scan nets
		--take union of scan and known
		--connect to first if not empty; setup ap otherwise
		
	else
		util.exitWithError("Unknown operation: '" .. argOperation .. "'")
	end
	
	os.exit(0)
end



--[[ START OF CODE ]]--

if init() == false then
	util.exitWithError(errortext)
end

if wifi.createOrReplaceApConfig() == false then
	util.exitWithError(errortext)
end

main()
