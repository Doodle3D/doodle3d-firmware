local reconf = require("reconf")
local util = require("util")
local uci = require("uci").cursor()
local iwinfo = require("iwinfo")

local M = {}

M.DFL_DEVICE = "radio0" -- was wlan0
M.AP_SSID = "d3d-ap"
M.AP_ADDRESS = "192.168.10.1"
M.AP_NETMASK = "255.255.255.0"
M.NET = "wlan"

local dev, dev_api


--- Map device mode as reported by iwinfo to device mode as required by UCI
-- Note that this function is quite naive.
-- @param mode			mode text as reported by iwinfo
-- @param masterIsAp	set to true to map 'Master' to 'ap' instead of 'sta' (optional)
function M.mapDeviceMode(mode, masterIsAp)
	local modeMap = {
		["Master"] = masterIsAp and "ap" or "sta",
		["Client"] = "sta",
		["Ad-Hoc"] = "adhoc"
	}
	return modeMap[mode] or mode
end

--[[
	- TODO: several modes need to be tested (wep, psk2, mixed-psk)
	- See: http://wiki.openwrt.org/doc/uci/wireless#wpa.modes
]]
function M.mapEncryptionType(scanEncrTbl)
	local wpaModeMap = { [1] = "psk", [2] = "psk2", [3] = "mixed-psk" }
	
	if scanEncrTbl.enabled == false then return "none" end
	if scanEncrTbl.wep == true then return "wep" end
	
	return wpaModeMap[scanEncrTbl.wpa] or scanEncrTbl.description
end


--- Initialize WiFi helper library
-- @param device	wireless device to operate on (optional, defaults to DFL_DEVICE)
-- @return true on success or false+error on failure
function M.init(device)
--	iwinfo = pcall(require, "iwinfo")
	dev = device or M.DFL_DEVICE
	dev_api = iwinfo.type(dev)
	if not dev_api then
		return false, "No such wireless device: '"..dev.."'"
	end

	return true
end


function M.getDeviceState()
	local iw = iwinfo[dev_api]
	local result = {
		["mode"] = M.mapDeviceMode(iw.mode(dev), true),
		["ssid"] = iw.ssid(dev),
		["bssid"] = iw.bssid(dev)
	}
	return result
end

--- Return one or all available wifi networks resulting from an iwinfo scan
-- @param ssid	return data for given SSID or for all networks if SSID not given
-- @return data for all or requested network; false+error on failure or nil when requested network not found
function M.getScanInfo(ssid)
	local iw = iwinfo[dev_api]
	local sr = iw.scanlist(dev)
	local si, se

	if ssid == nil then
		return sr
	else
		if sr and #sr > 0 then
			for _, se in ipairs(sr) do
				if se.ssid == ssid then
					return se
				end
			end
		else
			return false, "No scan results or scanning not possible"
		end
	end

	return nil
end

--- Return all wireless networks configured in UCI
function M.getConfigs()
	local l = {}
	uci.foreach("wireless", "wifi-iface", function(s) table.insert(l, s) end)
	return l
end

--- Remove UCI config for network with given SSID
-- @return true if successfully removed, false if no such config exists
function M.removeConfig(ssid)
	local rv = false
	uci:foreach("wireless", "wifi-iface", function(s)
		if s.ssid == ssid then
			uci:delete("wireless", s[".name"])
			rv = true
			return false
		end
	end)
	uci:commit("wireless")
	return rv
end

--- Activate wireless section for given SSID and disable all others
-- @param ssid	SSID of config to enable, or nil to disable all network configs
function M.activateConfig(ssid)
	uci:foreach("wireless", "wifi-iface", function(s)
		local disabled = s.ssid ~= ssid and "1" or "0"
		uci:set("wireless", s[".name"], "disabled", disabled)
	end)
	uci:commit("wireless")
end

--- Create a new UCI network from the given iwinfo data
-- http://luci.subsignal.org/trac/browser/luci/trunk/libs/iwinfo/src/iwinfo_wext.c?rev=5645 (outdated?)
-- TODO: delete previous network if exists (match on MAC-address)
-- @param info			iwinfo data to create a network from
-- @param passphrase	passphrase to use (optional)
-- @param disabled		immediately disable the network (optional)
function M.createConfigFromScanInfo(info, passphrase, disabled)
	local mode = M.mapDeviceMode(info.mode)

	local apconfig = {
		network = M.NET,
		device = "radio0",
		ssid = info.ssid,
		bssid = info.bssid,
		encryption = M.mapEncryptionType(info.encryption),
		mode = mode,
	}
	if passphrase ~= nil then apconfig.key = passphrase end
	apconfig.disabled = disabled ~= nil and disabled and 1 or 0
	
	local sname = uci:add("wireless", "wifi-iface");
	for k, v in pairs(apconfig) do
		uci:set("wireless", sname, k, v)
	end
	uci:commit("wireless")
end

--- Reload network config to reflect contents of config
-- @see http://wiki.openwrt.org/doc/techref/netifd)
-- * Network reload only restarts interfaces which need to be restarted so no
--   unneccesary interruptions there.
-- * ubus does not seem to work -- local c=ubus.connect();
--   c:call("network.interface.wlan", "down"); c:call("network.interface.wlan", "up"); c:close()
-- @param dhcpToo also reload dnsmasq if true
function M.restart(dhcpToo)
	os.execute("/etc/init.d/network reload") --always seems to return 0
	if dhcpToo ~= nil and dhcpToo then os.execute("/etc/init.d/dnsmasq reload") end
	return 0
end

return M
