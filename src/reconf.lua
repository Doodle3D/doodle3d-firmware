local u = require("util")
local uci = require("uci").cursor()

local M = {}
local reconf = {}
local wifi
local reloadSilent

M.WWW_CAPTIVE_PATH = "/usr/share/lua/autowifi/ext/www"
M.WWW_CAPTIVE_INDICATOR = "/www/.autowifi-inplace"
M.WWW_RENAME_NAME = "/www-regular"

function M.init(wifiInstance, reloadSilent)
	wifi = wifiInstance
	silent = reloadSilent or false
	return true
end

--- Switch configuration between AP and station modes
-- @param components	a table with components as keys with operations as values (add or remove)
-- Valid components (each with add and rm operation) are: apnet, staticaddr, dhcppool, wwwredir, dnsredir, wwwcaptive, natreflect.
-- and additionally: wifiiface/add, network/reload
function M.switchConfiguration(components)
	local dirtyList = {} -- laundry list, add config/script name as key with value c (commit), r (reload) or b (both)
	
	for k,v in pairs(components) do
		local fname = k .. "_" .. v
		if type(reconf[fname]) == "function" then
			u:logdebug("reconfiguring component '" .. k .. "' (" .. v .. ")")
			reconf[fname](dirtyList)
		else
			u:logwarn("unknown component or action '" .. fname .. "' skipped")
		end
	end
	
	-- first run all commits, then perform reloads
	for k,v in pairs(dirtyList) do
		if v == "c" or v == "b" then M.commitComponent(k) end
	end
	for k,v in pairs(dirtyList) do
		if v == "r" or v == "b" then M.reloadComponent(k, silent) end
	end
end

function M.commitComponent(c)
	u:loginfo("committing component '" .. c .. "'")
	uci:commit(c)
end

function M.reloadComponent(c, silent)
	u:loginfo("reloading component '" .. c .. "'")
	if silent ~= nil and silent then os.execute("/etc/init.d/" .. c .. " reload &> /dev/null")
	else os.execute("/etc/init.d/" .. c .. " reload") end
end

function M.uciTableSet(config, section, options)
	for k, v in pairs(options) do uci:set(config, section, k, v) end
end



--[[ Issue '/etc/init.d/network reload' command ]]
function reconf.network_reload(dirtyList) dirtyList.network = "r" end

--[[ Add wlan interface declaration to /etc/config/network ]]
function reconf.wifiiface_add(dirtyList)
	uci:set("network", wifi.NET, "interface")
	dirtyList.network = "c";
end

--[[ Add/remove access point network ]]
function reconf.apnet_add_noreload(dirtyList) reconf.apnet_add(dirtyList, true) end
function reconf.apnet_add(dirtyList, noReload)
	local sname = nil
	uci:foreach("wireless", "wifi-iface", function(s)
		if s.ssid == wifi.AP_SSID then sname = s[".name"]; return false end
	end)
	if sname == nil then sname = uci:add("wireless", "wifi-iface") end
	
	M.uciTableSet("wireless", sname, {
		network = wifi.NET,
		ssid = wifi.AP_SSID,
		encryption = "none",
		device = "radio0",
		mode = "ap",
	})
	
	dirtyList.wireless = "c"
	if noReload == nil or noReload == false then dirtyList.network = "r" end
end
function reconf.apnet_rm(dirtyList)
	local sname = nil
	uci:foreach("wireless", "wifi-iface", function(s)
		if s.ssid == wifi.AP_SSID then sname = s[".name"]; return false end
	end)
	if sname == nil then
		u:loginfo("AP network configuration does not exist, nothing to remove")
		return true
	end
	uci:delete("wireless", sname)
	dirtyList.network = "r"; dirtyList.wireless = "c"
end

--[[ Switch between wireless static IP and DHCP ]]
function reconf.staticaddr_add(dirtyList)
--	M.uciTableSet("network", wifi.NET, {
--		proto = "static",
--		ipaddr = wifi.AP_ADDRESS,
--		netmask = wifi.AP_NETMASK,
--		type = "bridge",
--	})
	uci:set("network", wifi.NET, "proto", "static")
	uci:set("network", wifi.NET, "ipaddr", wifi.AP_ADDRESS)
	uci:set("network", wifi.NET, "netmask", wifi.AP_NETMASK)
	uci:set("network", wifi.NET, "type", "bridge")
	dirtyList.network = "b"
end
--TODO: replace repeated deletes by M.uciTableDelete
function reconf.staticaddr_rm(dirtyList)
	uci:set("network", wifi.NET, "proto", "dhcp")
	uci:delete("network", wifi.NET, "ipaddr")
	uci:delete("network", wifi.NET, "netmask")
	uci:delete("network", wifi.NET, "type")
	dirtyList.network = "b"
end

--[[ Add/remove DHCP pool for wireless net ]]
function reconf.dhcppool_add(dirtyList)
--	M.uciTableSet("dhcp", wifi.NET, {
--		interface = wifi.NET,
--		start = "100",
--		limit = "150",
--		leasetime = "12h",
--	})
	uci:set("dhcp", wifi.NET, "dhcp") --create section??? TODO: what was this again
	uci:set("dhcp", wifi.NET, "interface", wifi.NET)
	uci:set("dhcp", wifi.NET, "start", "100")
	uci:set("dhcp", wifi.NET, "limit", "150")
	uci:set("dhcp", wifi.NET, "leasetime", "12h")
	dirtyList.dhcp = "c"; dirtyList.dnsmasq = "r"
end
function reconf.dhcppool_rm(dirtyList)
	uci:delete("dhcp", wifi.NET)
	dirtyList.dhcp = "c"; dirtyList.dnsmasq = "r"
end

--[[ Add/remove webserver 404 redirection and denial of dirlisting ]]
function reconf.wwwredir_add(dirtyList)
	uci:set("uhttpd", "main", "error_page", "/admin/autowifi.html")
	uci:set("uhttpd", "main", "no_dirlist", "1")
	dirtyList.uhttpd = "b"
end
function reconf.wwwredir_rm(dirtyList)
	uci:delete("uhttpd", "main", "error_page")
	uci:delete("uhttpd", "main", "no_dirlist")
	dirtyList.uhttpd = "b"
end

--[[ Add/remove redirecton of all DNS requests to self ]]
function reconf.dnsredir_add(dirtyList)
	local redirText = "/#/" .. wifi.AP_ADDRESS
	local sname = u.getUciSectionName("dhcp", "dnsmasq")
	if sname == nil then
		u:logerror("dhcp config does not contain a dnsmasq section")
		return false
	end
	if uci:get("dhcp", sname, "address") ~= nil then
		u:logdebug("DNS address redirection already in place, not re-adding")
		return true
	end
	
	uci:set("dhcp", sname, "address", {redirText})
	dirtyList.dhcp = "c"; dirtyList.dnsmasq = "r"
end
function reconf.dnsredir_rm(dirtyList)
	local sname = u.getUciSectionName("dhcp", "dnsmasq")
	if sname == nil then
		u:logerror("dhcp config does not contain a dnsmasq section")
		return false
	end
	uci:delete("dhcp", sname, "address")
	dirtyList.dhcp = "c"; dirtyList.dnsmasq = "r"
end

--TODO: handle os.rename() return values (nil+msg on error)
function reconf.wwwcaptive_add(dirtyList)
	if u.exists(M.WWW_CAPTIVE_INDICATOR) then
		u:logdebug("WWW captive directory already in place, not redoing")
		return true
	end
	os.rename("/www", M.WWW_RENAME_NAME)
	u.symlink(M.WWW_CAPTIVE_PATH, "/www")
	return true
end
function reconf.wwwcaptive_rm(dirtyList)
	if not u.exists(M.WWW_CAPTIVE_INDICATOR) then
		u:logdebug("WWW captive directory not in place, not undoing")
		return true
	end
	os.remove("/www")
	return os.rename(M.WWW_RENAME_NAME, "/www")
end

--[[ Setup/remove NAT reflection to redirect all IPs ]]
function reconf.natreflect_add(dirtyList)
	uci:set("firewall", "portalreflect", "redirect");
	M.uciTableSet("firewall", "portalreflect", {
		src = "lan",
		proto = "tcp",
		src_dport = "80",
		dest_port = "80",
		dest_ip = wifi.AP_ADDRESS,
		target = "DNAT"
	})
	dirtyList.firewall = "b"
end
function reconf.natreflect_rm(dirtyList)
	uci:delete("firewall", "portalreflect")
	dirtyList.firewall = "b"
end

return M
