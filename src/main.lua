--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


----
-- Entry code of the REST API and secondary functionality.
-- Primarily, this sets up the environment, processes a REST request and responds appropiately.
-- Secondary functions are to auto-switch between access point and client (@{setupAutoWifiMode})
-- and to signin to [connect.doodle3d.com](http://connect.doodle3d.com/) (@{network.signin}).
package.path = package.path .. ';/usr/share/lua/wifibox/?.lua'

local confDefaults = require('conf_defaults')
local log = require('util.logger')
local settings = require('util.settings')
local util = require('util.utils')
local wifi = require('network.wlanconfig')
local netconf = require('network.netconfig')
local RequestClass = require('rest.request')
local ResponseClass = require('rest.response')
local Signin = require('network.signin')

-- NOTE: the updater module 'detects' command-line invocation by existence of 'arg', so we have to make sure it is not defined.
argStash = arg
arg = nil
local updater = require('script.d3d-updater')
arg = argStash

local postData = nil
local MOD_ABBR = "ENTR"


--- Switches to wifi client mode or to access point mode based on availability of known wifi networks.
--
-- If the configuration has actively been set to access point mode, that will always be selected.
-- If not, it will be attempted to connect to a known network (in order of recency) and only if
-- that fails, access point mode will be selected as fall-back.
local function setupAutoWifiMode()
	-- expects list with tables containing 'ssid' key as values and returns index key if found or nil if not found
	local function findSsidInList(list, name)
		for k,v in ipairs(list) do
			if v.ssid == name then return k end
		end
		return nil
	end

	local wifiState = wifi.getDeviceState()
	local netName, netMode = wifiState.ssid, wifiState.mode
	log:info(MOD_ABBR, "current wifi name: " .. (netName or "<nil>") .. ", mode: " .. netMode)

	local apSsid = wifi.getSubstitutedSsid(settings.get('network.ap.ssid'))
	local apMode = (apSsid == netName) and (netMode == 'ap')
	log:info(MOD_ABBR, "ssid of self: " .. apSsid)

	local scanList,msg = wifi.getScanInfo()
	if not scanList then
		return nil, "autowifi: could not scan wifi networks (" .. msg .. ")"
	end

	local knownSsids = wifi.getConfigs()
	-- log:info(MOD_ABBR, "current wifi name: " .. (netName or "<nil>") .. ", mode: " .. netMode .. ", ssid of self: " .. apSsid)
	local visNet, knownNet = {}, {}
	for _,sn in ipairs(scanList) do
		table.insert(visNet, sn.ssid)
	end
	for _,kn in ipairs(knownSsids) do
		table.insert(knownNet, kn.ssid .. "/" .. kn.mode)
	end
	log:info(MOD_ABBR, "visible networks: " .. table.concat(visNet, ", "))
	log:info(MOD_ABBR, "known networks: " .. table.concat(knownNet, ", "))

	-- if the currently active network is client mode and is also visible, do nothing since it will connect automatically further along the boot process
	if netMode == 'sta' and netName ~= nil and netName ~= "" and findSsidInList(scanList, netName) then
		-- signin to connect.doodle3d.com
		local success, output = Signin.signin()
		if success then
				log:info(MOD_ABBR, "Signed in")
		else 
			log:info(MOD_ABBR, "Signing in failed")
		end
		-- report we are connected after signin attempt
		netconf.setStatus(netconf.CONNECTED,"Connected");
		return true, "autowifi: no action - existing configuration found for currently wifi visible network (" .. netName .. ")"
	end

	-- try to find a known network which is also visible (ordered by known network definitions)
	-- when it finds a access point configuration first, it will use that
	local connectWith = nil
	for _,kn in ipairs(knownSsids) do
    	if kn.mode == 'ap' and kn.ssid == apSsid then break end
		if findSsidInList(scanList, kn.ssid) and kn.mode == 'sta' then
			connectWith = kn.ssid
			break
		end
	end

	if connectWith then
		local rv,msg = netconf.associateSsid(connectWith,nil,nil)
		if rv then
			return true, "autowifi: associated -- client mode with ssid '" .. connectWith .. "'"
		else
			return nil, "autowifi: could not associate with ssid '" .. connectWith .. "' (" .. msg .. ")"
		end
	elseif netMode ~= 'ap' or netName ~= apSsid then
		local rv,msg = netconf.setupAccessPoint(apSsid)
		if rv then
			return true, "autowifi: configured as access point with ssid '" .. apSsid .. "'"
		else
			return nil, "autowifi: failed to configure as access point with ssid '" .. apSsid .. "' (" .. msg .. ")"
		end
	else
		netconf.setStatus(netconf.CREATED,"Access point created");
		return true, "autowifi: no action - no known networks found, already in access point mode"
	end

	return nil, "autowifi: uh oh - bad situation in autowifi function"
end

--- Initializes the logging system to use the file and level defined in the system settings.
-- The settings used are `log_path`, `api_log_filename` from the system section and
-- `system_log_level` from the general section. The filename may either be a regular filename
-- (with an absolute log_path), or `<stdout>` or `<stderr>`.
-- TODO: also support backticks (see Logger.cpp in print3d)--
-- @see util.settings.getSystemKey
-- @treturn bool True on success, false on error.
local function setupLogger()
	local logStream = io.stderr -- use stderr as hard-coded default target
	local logLevel = log.LEVEL.verbose -- use verbose logging as hard-coded default level

	local logPathSetting = settings.getSystemKey('log_path')
	local logTargetSetting = settings.getSystemKey('api_log_filename')
	local logLevelSetting = settings.get('system_log_level')
	local logTargetError, logLevelError = nil, nil

	if type(logTargetSetting) == 'string' then
		local streamTarget = logTargetSetting:match('^<(.*)>$')
		local popenTarget = logTargetSetting:match('^`(.*)`$')
		if streamTarget then
			if streamTarget:lower() == 'stdout' then logStream = io.stdout
			elseif streamTarget:lower() == 'stderr' then logStream = io.stderr
			end
		elseif popenTarget then
			local f,msg = io.popen(popenTarget, 'w')

			if f then logStream = f
			else logTargetError = msg
			end
		elseif logPathSetting:sub(1, 1) == '/' then
			local path = logPathSetting .. '/' .. logTargetSetting
			local f,msg = io.open(path, 'a+')

			if f then
				logStream = f
				log:setLogFilePath(path)
			else
				logTargetError = msg
			end
		else
			logTargetError = "log file path is not absolute"
		end
	else
		-- if uci config not available, fallback to /tmp/wifibox.log
		local path = '/tmp/wifibox.log'
		local f,msg = io.open(path, 'a+')

		if f then
			logStream = f
			log:setLogFilePath(path)
		else
			logTargetError = msg
		end
	end

	if type(logLevelSetting) == 'string' and logLevelSetting:len() > 0 then
		local valid = false
		for idx,lvl in ipairs(log.LEVEL) do
			if logLevelSetting == lvl then
				logLevel = idx
				valid = true
			end
		end
		if not valid then logLevelError = true end
	end

	log:init(logLevel)
	log:setStream(logStream)

	local rv = true
	if logTargetError then
		log:error(MOD_ABBR, "could not open logfile '" .. logPathSetting .. '/' .. logTargetSetting .. "', using stderr as fallback (" .. logTargetError .. ")")
		rv = false
	end

	if logLevelError then
		log:error(MOD_ABBR, "uci config specifies invalid log level '" .. logLevelSetting .. "', using verbose level as fallback")
		rv = false
	end

	return rv
end

--- Initializes the environment.
-- The logger is set up, any POST data is read and several other subsystems are initialized.
-- @tparam table environment The 'shell' environment containing all CGI variables. Note that @{cmdmain} simulates this.
local function init(environment)
	setupLogger()

	local dbgText = ""
	if confDefaults.DEBUG_API and confDefaults.DEBUG_PCALLS then dbgText = "pcall+api"
	elseif confDefaults.DEBUG_API then dbgText = "api"
	elseif confDefaults.DEBUG_PCALL then dbgText = "pcall"
	end

	if dbgText ~= "" then dbgText = " (" .. dbgText .. " debugging)" end
	log:verbose(MOD_ABBR, "=======rest api" .. dbgText .. "=======")

	if (environment['REQUEST_METHOD'] == 'POST') then
		local n = tonumber(environment['CONTENT_LENGTH'])
		postData = io.read(n)
	end

	local s, msg
	s, msg = wifi.init()
	if not s then return s, msg end

	s, msg = netconf.init(wifi, false)
	if not s then return s, msg end

	return true
end

--- Decides what action to take based on shell/CGI parameters.
-- Either executes a REST request, or calls @{setupAutoWifiMode} or @{network.signin}.
-- @tparam table environment The CGI environment table.
local function main(environment)
	local rq = RequestClass.new(environment, postData, confDefaults.DEBUG_API)

	if rq:getRequestMethod() == 'CMDLINE' and rq:get('autowifi') ~= nil then

		local version = updater.formatVersion(updater.getCurrentVersion());
		log:info(MOD_ABBR, "Doodle3D version: "..util.dump(version))

		log:info(MOD_ABBR, "Running in autowifi mode")
		local rv,msg = setupAutoWifiMode()

		if rv then
			log:info(MOD_ABBR, "Autowifi setup done (" .. msg .. ")")
		else
			log:error(MOD_ABBR, "Autowifi setup failed (" .. msg .. ")")
		end
	elseif rq:getRequestMethod() == 'CMDLINE' and rq:get('signin') ~= nil then
		log:info(MOD_ABBR, "Running in signin mode")

		log:info(MOD_ABBR, "  attempting signin")
		local success,msg = Signin.signin()
		if success then
	  		log:info(MOD_ABBR, "Signin successful")
		else
			log:warning(MOD_ABBR, "Signin failed: "..util.dump(msg))
		end
	elseif rq:getRequestMethod() ~= 'CMDLINE' or confDefaults.DEBUG_API then
		-- Note: the commented log message will print too many data if it's for instance dumping a gcode add request
		--logMessage = "received request of type " .. rq:getRequestMethod() .. " for " .. (rq:getRequestedApiModule() or "<unknown>")
		--		.. "/" .. (rq:getRealApiFunctionName() or "<unknown>") .. " with arguments: " .. util.dump(rq:getAll())
		logMessage = rq:getRequestMethod() .. " request for " .. (rq:getRequestedApiModule() or "<unknown>")
				.. "/" .. (rq:getRealApiFunctionName() or "<unknown>")
		if rq:getRequestMethod() ~= 'CMDLINE' then
			logMessage = logMessage .. " (remote IP/port: " .. rq:getRemoteHost() .. "/" .. rq:getRemotePort() .. ")"
			--logMessage = logMessage .. " (user agent: " .. rq:getUserAgent() .. ")"
		end
		log:info(MOD_ABBR, logMessage)

		local response, err = rq:handle()

		if err ~= nil then log:error(MOD_ABBR, err) end
		response:send()
		response:executePostResponseQueue()
	else
		log:info(MOD_ABBR, "Nothing to do...bye.\n")
	end
end


--- Firmware entry point. Runs @{init} and calls @{main}.
--
-- This is either used by [uhttp-mod-lua](http://wiki.openwrt.org/doc/uci/uhttpd#embedded.lua)
-- directly, or by the d3dapi cgi-bin wrapper script which builds the env table
-- from the shell environment. The wrapper script also handles command-line invocation.
-- @tparam table env The CGI environment table.
-- @treturn number A Z+ return value suitable to return from wrapper script. Note that this value is ignored by uhttpd-mod-lua.
function handle_request(env)
	local s, msg = init(env)

	if s == false then
		local resp = ResponseClass.new()
		local errSuffix = msg and " (" .. msg .. ")" or ""

		resp:setError("initialization failed" .. errSuffix)
		resp:send()
		log:error(MOD_ABBR, "Initialization failed" .. errSuffix) --NOTE: this assumes the logger has been initialized properly, despite init() having failed

		return 1
	else
		main(env)
		return 0
	end
end
