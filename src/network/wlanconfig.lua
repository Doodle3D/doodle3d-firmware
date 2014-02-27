--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


local log = require('util.logger')
local utils = require('util.utils')
local uci = require('uci').cursor()
local iwinfo = require('iwinfo')

local M = {}

-- NOTE: fallback device 'radio0' is required because sometimes the wlan0 device disappears
M.DFL_DEVICE = 'wlan0'
M.DFL_DEVICE_FALLBACK = 'radio0'
M.NET = 'wlan'

-- NOTE: deviceApi is returned by iwinfo.type(deviceName)
local deviceName, deviceApi

-- if a substitution of baseApSsid is requested, cachedApSsid is returned if not nil
local cachedApSsid, baseApSsid = nil, nil

function M.getSubstitutedSsid(unformattedSsid)
	if unformattedSsid == baseApSsid and cachedApSsid ~= nil then return cachedApSsid end
	if not unformattedSsid or type(unformattedSsid) ~= 'string' then return nil end

	local macTail = M.getMacAddress():sub(7)

	baseApSsid = unformattedSsid
	cachedApSsid = unformattedSsid:gsub('%%%%MAC_ADDR_TAIL%%%%', macTail)

	return cachedApSsid
end


--- Map device mode as reported by iwinfo to device mode as required by UCI
-- Note that this function is quite naive.
-- @param mode			mode text as reported by iwinfo
-- @param masterIsAp	set to true to map 'Master' to 'ap' instead of 'sta' (optional)
function M.mapDeviceMode(mode, masterIsAp)
	local modeMap = {
		['Master'] = masterIsAp and 'ap' or 'sta',
		['Client'] = 'sta',
		['Ad-Hoc'] = 'adhoc'
	}
	return modeMap[mode] or mode
end

--[[
	- TODO: several modes need to be tested (wep, psk2, mixed-psk)
	- See: http://wiki.openwrt.org/doc/uci/wireless#wpa.modes
]]
function M.mapEncryptionType(scanEncrTbl)
	local wpaModeMap = { [1] = 'psk', [2] = 'psk2', [3] = 'mixed-psk' }

	if scanEncrTbl.enabled == false then return 'none' end
	if scanEncrTbl.wep == true then return 'wep' end

	return wpaModeMap[scanEncrTbl.wpa] or scanEncrTbl.description
end


--- Initialize WiFi helper library
-- @param device	wireless device to operate on (optional, defaults to DFL_DEVICE)
-- @return true on success or false+error on failure
function M.init(device)
	deviceName = device or M.DFL_DEVICE
	deviceApi = iwinfo.type(deviceName)
	if not deviceApi then
		local devInitial = deviceName
		deviceName = M.DFL_DEVICE_FALLBACK
		deviceApi = iwinfo.type(deviceName)

		log:info("wireless device '" .. devInitial .. "' not found, trying fallback '" .. deviceName .. "'")

		if not deviceApi then
			return false, "No such wireless device: '" .. devInitial .. "' (and fallback '" .. deviceName .. "' does not exist either)"
		end
	end

	return true
end


function M.getDeviceState()
	local iw = iwinfo[deviceApi]
	local encDescription = type(iw.encryption) == 'function' and iw.encryption(deviceName) or '<unknown>'
	local result = {
		['ssid'] = iw.ssid(deviceName),
		['bssid'] = iw.bssid(deviceName),
		['channel'] = iw.channel(deviceName),
		['mode'] = M.mapDeviceMode(iw.mode(deviceName), true),
		['encryption'] = M.mapEncryptionType(encDescription),
		['quality'] = iw.quality(deviceName),
		['quality_max'] = iw.quality_max(deviceName),
		['txpower'] = iw.txpower(deviceName),
		['signal'] = iw.signal(deviceName),
		['noise'] = iw.noise(deviceName)
	}
	return result
end

--returns the wireless device's MAC address (as string, without colons)
--(lua numbers on openWrt seem to be 32bit so they cannot represent a MAC address as one number)
function M.getMacAddress()
	local macText = utils.readFile('/sys/class/net/' .. deviceName .. '/address')
	local out = ''

	-- Hack to prevent failure in case the MAC address could not be obtained.
	if not macText or macText == '' then return "000000000000" end

	for i = 0, 5 do
		local bt = string.sub(macText, i*3+1, i*3+2)
		out = out .. bt
	end

	return out:upper()
end

--returns the wireless local ip address
function M.getLocalIP()
	local ifconfig, rv = utils.captureCommandOutput("ifconfig wlan0");
	--log:debug("  ifconfig: \n"..utils.dump(ifconfig));
	local localip = ifconfig:match('inet addr:([%d\.]+)')
	return localip;
end

function M.getDeviceName()
	return deviceName
end

--- Return one or all available wifi networks resulting from an iwinfo scan
-- @param ssid	return data for given SSID or for all networks if SSID not given
-- @return data for all or requested network; false+error on failure or nil when requested network not found
function M.getScanInfo(ssid)

	local iw = iwinfo[deviceApi]
	local sr = iw.scanlist(deviceName)
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
	uci.foreach('wireless', 'wifi-iface', function(s) table.insert(l, s) end)
	return l
end

--- Remove UCI config for network with given SSID
-- @return true if successfully removed, false if no such config exists
function M.removeConfig(ssid)
	local rv = false
	uci:foreach('wireless', 'wifi-iface', function(s)
		if s.ssid == ssid then
			uci:delete('wireless', s['.name'])
			rv = true
		end
	end)
	uci:commit('wireless')
	return rv
end

--- Activate wireless section for given SSID and disable all others
-- @param ssid	SSID of config to enable, or nil to disable all network configs
function M.activateConfig(ssid)
	--log:info("wlanconfig.activateConfig: "..ssid);

	-- make sure only one is enabled
	uci:foreach('wireless', 'wifi-iface', function(s)
		local disabled = s.ssid ~= ssid and '1' or '0'
		--log:info("    "..utils.dump(s.ssid).." disable: "..utils.dump(disabled))
		uci:set('wireless', s['.name'], 'disabled', disabled)
	end)

	uci:commit('wireless')

	-- make sure the wifi-device radio0 is on top
	uci:reorder('wireless', 'radio0', 0)

	uci:commit('wireless')

	-- put it on top of the wireless configuration so it's the first option when the devices starts
	uci:foreach('wireless', 'wifi-iface', function(s)
		if s.ssid == ssid then
			uci:reorder('wireless', s['.name'], 1)
			return false
		end
	end)
	--[[log:info("  result:");
	uci:foreach('wireless', 'wifi-iface', function(s)
		local disabled = s.ssid ~= ssid and '1' or '0'
		log:info("    "..utils.dump(s.ssid).." disable: "..utils.dump(disabled))
	end)]]--

	uci:commit('wireless')
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
		device = 'radio0',
		ssid = info.ssid,
		--bssid = info.bssid,
		encryption = M.mapEncryptionType(info.encryption),
		mode = mode,
	}
	if passphrase ~= nil then apconfig.key = passphrase end
	apconfig.disabled = disabled ~= nil and disabled and 1 or 0

	uci:foreach('wireless', 'wifi-iface', function(s)
		--if s.bssid == info.bssid then
		if s.ssid == info.ssid then
			log:debug("removing old wireless config for net '" .. s.ssid .. "'")
			uci:delete('wireless', s['.name'])
--			return false --keep looking, just in case multiple entries with this bssid exist
		end
	end)

	local sname = uci:add('wireless', 'wifi-iface');
	for k, v in pairs(apconfig) do
		uci:set('wireless', sname, k, v)
	end
	uci:commit('wireless')
end

--- Reload network config to reflect contents of config
-- @see http://wiki.openwrt.org/doc/techref/netifd)
-- * Network reload only restarts interfaces which need to be restarted so no
--   unneccesary interruptions there.
-- * ubus does not seem to work -- local c=ubus.connect();
--   c:call('network.interface.wlan', 'down'); c:call('network.interface.wlan', 'up'); c:close()
-- @param dhcpToo also reload dnsmasq if true
function M.restart(dhcpToo)
	os.execute('/etc/init.d/network reload') --always seems to return 0
	if dhcpToo ~= nil and dhcpToo then os.execute('/etc/init.d/dnsmasq reload') end
	return 0
end

return M
