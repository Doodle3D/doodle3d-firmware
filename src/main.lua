--[[
	Response format:
	["OK" | "WARN" | "ERR"]<,{message}>
	{comma-separated line 1}
	...
	{comma-separated line n}
	  
	- general info on wireless config: http://wiki.openwrt.org/doc/uci/wireless
	- uci docs: http://wiki.openwrt.org/doc/techref/uci
	- parse/generate urls: https://github.com/keplerproject/cgilua/blob/master/src/cgilua/urlcode.lua
	- utility functions: http://luci.subsignal.org/trac/browser/luci/trunk/libs/sys/luasrc/sys.lua
	- iwinfo tool source: http://luci.subsignal.org/trac/browser/luci/trunk/contrib/package/iwinfo/src/iwinfo.lua?rev=7919
	- captive portal -> redirect all web traffic to one page for auth (or network selection)
	  http://wiki.openwrt.org/doc/howto/wireless.hotspot
  ]]
--print ("HTTP/1.0 200 OK")
io.write ("Content-type: text/plain\r\n\r\n")

local u = require("util")
local l = require("logger")
local wifi = require("network.wlanconfig")
local reconf = require("network.netconfig")
local urlcode = require("util.urlcode")
local uci = require("uci").cursor()
local iwinfo = require("iwinfo")

local argOperation, argDevice, argSsid, argPhrase, argRecreate
local errortext = nil

function init()
	l:init(l.LEVEL.debug, true, io.stderr)
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

	return wifi.init() and reconf.init(wifi, true)
end


function main()
	if argOperation == "getavl" then
		local sr = wifi.getScanInfo()
		local si, se
		
		--TODO:
		--  - extend reconf interface to support function arguments (as tables) so wifihelper functionality can be integrated
		--    but how? idea: pass x_args={arg1="a",arg2="2342"} for component 'x'
		--    or: allow alternative for x="y" --> x={action="y", arg1="a", arg2="2342"}
		--    in any case, arguments should be put in a new table to pass to the function (since order is undefined it must be an assoc array)
		if sr and #sr > 0 then
			u.printWithSuccess(#sr .. " network(s) found");
			for _, se in ipairs(sr) do
				--print("[[   " .. u.dump(se) .. "   ]]") --TEMP
				if se.mode ~= "ap" and se.ssid ~= wifi.AP_SSID then
					print(se.ssid .. "," .. se.bssid .. "," .. se.channel .. "," .. wifi.mapDeviceMode(se.mode) .. "," .. wifi.mapEncryptionType(se.encryption))
				end
			end
		else
			u.exitWithError("No scan results or scanning not possible")
		end
	
	elseif argOperation == "getknown" then
		u.printWithSuccess("")
		for _, net in ipairs(wifi.getConfigs()) do
			if net.mode == "sta" then
				local bssid = net.bssid or "<unknown BSSID>"
				local channel = net.channel or "<unknown channel>"
				print(net.ssid .. "," .. bssid .. "," .. channel)
			end
		end
	
	elseif argOperation == "getstate" then
		local ds = wifi.getDeviceState()
		local ssid = ds.ssid or "<unknown SSID>"
		local bssid = ds.bssid or "<unknown BSSID>"
		local channel = ds.channel or "<unknown channel>"
		u.printWithSuccess("");
		print(ssid .. "," .. bssid .. "," .. channel .. "," .. ds.mode)
	
	elseif argOperation == "assoc" then
		if argSsid == nil or argSsid == "" then u.exitWithError("Please supply an SSID to associate with") end
		
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
				u.exitWithError("No wireless network with SSID '" .. argSsid .. "' is available")
			end
		end
		wifi.activateConfig(argSsid)
		reconf.switchConfiguration{ wifiiface="add", apnet="rm", staticaddr="rm", dhcppool="rm", wwwredir="rm", dnsredir="rm", wwwcaptive="rm", wireless="reload" }
		u.exitWithSuccess("Wlan associated with network " .. argSsid .. "!")
	
	elseif argOperation == "disassoc" then
		wifi.activateConfig()
		local rv = wifi.restart()
		u.exitWithSuccess("Deactivated all wireless networks [$?=" .. rv .. "]")
	
	elseif argOperation == "openap" then
		--add AP net, activate it, deactivate all others, reload network/wireless config, add all dhcp and captive settings and reload as needed
		reconf.switchConfiguration{apnet="add_noreload"}
		wifi.activateConfig(wifi.AP_SSID)
		reconf.switchConfiguration{ wifiiface="add", network="reload", staticaddr="add", dhcppool="add", wwwredir="add", dnsredir="add", wwwcaptive="add" }
		u.exitWithSuccess("Switched to AP mode (SSID: '" .. wifi.AP_SSID .. "')")
	
	elseif argOperation == "rm" then
		if argSsid == nil or argSsid == "" then u.exitWithError("Please supply an SSID to remove") end
		if wifi.removeConfig(argSsid) then
			u.exitWithSuccess("Removed wireless network with SSID " .. argSsid)
		else
			u.exitWithWarning("No wireless network with SSID " .. argSsid)
		end
		
	elseif argOperation == "test" then
		--invert actions performed by openap operation
		reconf.switchConfiguration{ apnet="rm", staticaddr="rm", dhcppool="rm", wwwredir="rm", dnsredir="rm", wwwcaptive="rm" }
--		reconf.switchConfiguration{dnsredir="add"}
		u.exitWithSuccess("nop")
	
	elseif argOperation == "auto" then
		u.exitWithWarning("Not implemented");
		--scan nets
		--take union of scan and known
		--connect to first if not empty; setup ap otherwise
		
	else
		u.exitWithError("Unknown operation: '" .. argOperation .. "'")
	end
	
	os.exit(0)
end



--[[ START OF CODE ]]--

if init() == false then
	u.exitWithError(errortext)
end

main()
