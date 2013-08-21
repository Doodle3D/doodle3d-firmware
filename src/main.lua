package.path = package.path .. ';/usr/share/lua/wifibox/?.lua'

local confDefaults = require('conf_defaults')
local log = require('util.logger')
local settings = require('util.settings')
local util = require('util.utils')
local wifi = require('network.wlanconfig')
local netconf = require('network.netconfig')
local RequestClass = require('rest.request')
local ResponseClass = require('rest.response')

local postData = nil


-- expects list with tables containing 'ssid' key as values and returns index key if found or nil if not found
local function findSsidInList(list, name)
	for k,v in ipairs(list) do
		if v.ssid == name then return k end
	end
	return nil
end

local function setupAutoWifiMode()
	local wifiState = wifi.getDeviceState()
	local netName, netMode = wifiState.ssid, wifiState.mode
	
	local apSsid = wifi.getSubstitutedSsid(settings.get('network.ap.ssid'))
	local apMode = (apSsid == netName) and netMode == 'ap'
	
	local scanList,msg = wifi.getScanInfo()
	local knownSsids = wifi.getConfigs()
	
	if not scanList then
		return nil, "autowifi: could not scan wifi networks (" .. msg .. ")"
	end
	
	-- START TEMP -- mode should be ap or sta
	print("wifi name: " .. netName .. ", wifi mode: " .. netMode .. ", expected AP ssid: " .. apSsid .. ", apmode: " .. (apMode and "yes" or "no"))
	for _,sn in ipairs(scanList) do
		print("avl net: " .. sn.ssid)
	end
	for _,kn in ipairs(knownSsids) do
		print("known net: " .. kn.ssid .. " (mode: " .. kn.mode .. ")")
	end
	-- END TEMP
	
	-- if the currently active network is client mode and is also visible, do nothing since it will connect automatically further along the boot process
	if netMode == 'sta' and findSsidInList(scanList, netName) then
		return true, "autowifi: no action - existing configuration found for currently wifi visible network (" .. netName .. ")"
	end
	
	-- try to find a known network which is also visible (ordered by known network definitions)
	local connectWith = nil
	for _,kn in ipairs(knownSsids) do
		if findSsidInList(scanList, kn.ssid) then
			connectWith = kn.ssid
			break
		end
	end
	
	if connectWith then
		print("connectWith: " .. connectWith) --TEMP
		-- TODO: refactor connect stuff into network:connect() function and adapt api_network_associate as well (and others?)
		-- TODO: connect with network
		-- return true, "autowifi: associated -- client mode with ssid '" .. connectWith .. "'"
	elseif netMode ~= 'ap' then
		print("shouldBeAp") --TEMP
		-- TODO: setup AP (refactor into network like with client connect)
		-- return true, "autowifi: configured as access point with ssid '" .. apSsid .. "'"
	else
		return true, "autowifi: no action - no known networks found, already in access point mode"
	end
	
	return nil, "autowifi: uh oh - bad situation in autowifi function"
end

local function init(environment)
	log:init(log.LEVEL.debug)
	log:setStream(io.stderr)
	
	local dbgText = ""
	if confDefaults.DEBUG_API and confDefaults.DEBUG_PCALLS then dbgText = "pcall and api"
	elseif confDefaults.DEBUG_API then dbgText = "api"
	elseif confDefaults.DEBUG_PCALL then dbgText = "pcall"
	end
	
	if dbgText ~= "" then dbgText = " (" .. dbgText .. " debugging enabled)" end
	
	log:info("Wifibox CGI handler started" .. dbgText)
	
	if (environment['REQUEST_METHOD'] == 'POST') then
		local n = tonumber(environment['CONTENT_LENGTH'])
		postData = io.read(n)
	end
	
	local s, msg
	s, msg = wifi.init()
	if not s then return s, msg end
	
	s, msg = netconf.init(wifi, true)
	if not s then return s, msg end
	
	return true
end

 local function main(environment)
	local rq = RequestClass.new(environment, postData, confDefaults.DEBUG_API)
	
--	log:info("received request of type " .. rq:getRequestMethod() .. " for " .. (rq:getRequestedApiModule() or "<unknown>")
--			.. "/" .. (rq:getRealApiFunctionName() or "<unknown>") .. " with arguments: " .. util.dump(rq:getAll()))
	log:info("received request of type " .. rq:getRequestMethod() .. " for " .. (rq:getRequestedApiModule() or "<unknown>")
			.. "/" .. (rq:getRealApiFunctionName() or "<unknown>"))
	if rq:getRequestMethod() ~= 'CMDLINE' then
		log:info("remote IP/port: " .. rq:getRemoteHost() .. "/" .. rq:getRemotePort())
		log:debug("user agent: " .. rq:getUserAgent())
	end
	
	if rq:getRequestMethod() == 'CMDLINE' and rq:get('autowifi') ~= nil then
		log:info("running in autowifi mode")
		local rv,msg = setupAutoWifiMode()
		
		if rv then
			log:info("autowifi setup done (" .. msg .. ")")
		else
			log:error("autowifi setup failed (" .. msg .. ")")
		end
	elseif rq:getRequestMethod() ~= 'CMDLINE' or confDefaults.DEBUG_API then
		local response, err = rq:handle()
		
		if err ~= nil then log:error(err) end
		response:send()
	else
		log:info("Nothing to do...bye.\n")
	end
end


--- Main firmware entry point.
-- This is either used by uhttp-mod-lua directly, or by the d3dapi cgi-bin wrapper
-- script which builds the env table from the shell environment. The wrapper script
-- also handles command-line invocation.
-- @tparam table The CGI environment table.
-- @treturn number A Z+ return value suitable to return from wrapper script. Note that this value is ignored by uhttpd-mod-lua.
function handle_request(env)
	local s, msg = init(env)
	
	if s == false then
		local resp = ResponseClass.new()
		local errSuffix = msg and " (" .. msg .. ")" or ""
		
		resp:setError("initialization failed" .. errSuffix)
		resp:send()
		log:error("initialization failed" .. errSuffix) --NOTE: this assumes the logger has been initialized properly, despite init() having failed
		
		return 1
	else
		main(env)
		return 0
	end
end
