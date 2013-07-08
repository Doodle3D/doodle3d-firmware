local l = require("logger")

local M = {}

M.isApi = true

function M._global(d)
	return "not implemented..."
end

--[[
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
]--

return M
