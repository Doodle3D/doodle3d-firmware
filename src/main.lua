package.path = package.path .. ';/usr/share/lua/wifibox/?.lua'

local confDefaults = require('conf_defaults')
local util = require('util.utils')
local log = require('util.logger')
local wifi = require('network.wlanconfig')
local netconf = require('network.netconfig')
local RequestClass = require('rest.request')
local ResponseClass = require('rest.response')

local postData = nil


local function setupAutoWifiMode()
	io.write("--TODO: join known network if present, fall back to access point otherwise\n")
end

local function init()
	log:init(log.LEVEL.debug)
	log:setStream(io.stderr)
	
	local dbgText = ""
	if confDefaults.DEBUG_API and confDefaults.DEBUG_PCALLS then dbgText = "pcall and api"
	elseif confDefaults.DEBUG_API then dbgText = "api"
	elseif confDefaults.DEBUG_PCALL then dbgText = "pcall"
	end
	
	if dbgText ~= "" then dbgText = " (" .. dbgText .. " debugging enabled)" end
	
	log:info("Wifibox CGI handler started" .. dbgText)
	
	if (os.getenv('REQUEST_METHOD') == 'POST') then
		local n = tonumber(os.getenv('CONTENT_LENGTH'))
		postData = io.read(n)
	end
	
	local s, msg
	s, msg = wifi.init()
	if not s then return s, msg end
	
	s, msg = netconf.init(wifi, true)
	if not s then return s, msg end
	
	return true
end

 local function main()
	local rq = RequestClass.new(postData, confDefaults.DEBUG_API)
	
	log:info("received request of type " .. rq:getRequestMethod() .. " for " .. (rq:getRequestedApiModule() or "<unknown>")
			.. "/" .. (rq:getRealApiFunctionName() or "<unknown>") .. " with arguments: " .. util.dump(rq:getAll()))
	if rq:getRequestMethod() ~= 'CMDLINE' then
		log:info("remote IP/port: " .. rq:getRemoteHost() .. "/" .. rq:getRemotePort())
		log:debug("user agent: " .. rq:getUserAgent())
	end
	
	if rq:getRequestMethod() == 'CMDLINE' and rq:get('autowifi') ~= nil then
		setupAutoWifiMode()
	elseif rq:getRequestMethod() ~= 'CMDLINE' or confDefaults.DEBUG_API then
		local response, err = rq:handle()
		
		if err ~= nil then log:error(err) end
		response:send()
	else
		log:info("Nothing to do...bye.\n")
	end
end

---'entry point'---
local s, msg = init()
if s == false then
	local resp = ResponseClass.new()
	local errSuffix = msg and " (" .. msg .. ")" or ""
	
	resp:setError("initialization failed" .. errSuffix)
	io.write ("Content-type: text/plain\r\n\r\n")
	resp:send()
	log:error("initialization failed" .. errSuffix) --NOTE: this assumes the logger has been inited properly, despite init() having failed
	
	os.exit(1)
else
	main()
	os.exit(0)
end
