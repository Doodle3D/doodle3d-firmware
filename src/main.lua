local l = require("logger")
local RequestClass = require("rest.request")
local ResponseClass = require("rest.response")
local wifi = require("network.wlanconfig")
local netconf = require("network.netconfig")
local config = require("config")

local postData = nil


local function setupAutoWifiMode()
	io.write("--TODO: join known network if present, fall back to access point otherwise\n")
end

local function init()
	l:init(l.LEVEL.debug)
	l:setStream(io.stderr)
	
	if config.DEBUG_PCALLS then l:info("Wifibox CGI handler started (pcall debugging enabled)")
	else l:info("Wifibox CGI handler started")
	end
	
	if (os.getenv("REQUEST_METHOD") == "POST") then
		local n = tonumber(os.getenv("CONTENT_LENGTH"))
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
	local rq = RequestClass.new(postData, config.DEBUG_PCALLS)
	
	l:info("received request of type " .. rq:getRequestMethod() .. " with arguments: " .. l:dump(rq:getAll()))
	if rq:getRequestMethod() ~= "CMDLINE" then
		l:info("remote IP/port: " .. rq:getRemoteHost() .. "/" .. rq:getRemotePort())
		l:debug("user agent: " .. rq:getUserAgent())
	end
	
	if (not config.DEBUG_PCALLS and rq:getRequestMethod() == "CMDLINE") then
		if rq:get("autowifi") ~= nil then
			setupAutoWifiMode()
		else
			l:info("Nothing to do...bye.\n")
		end
		
	else
		io.write ("Content-type: text/plain\r\n\r\n")
		local response, err = rq:handle()
		
		if err ~= nil then l:error(err) end
		response:send()
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
	l:error("initialization failed" .. errSuffix) --NOTE: this assumes the logger has been inited properly, despite init() having failed
	
	os.exit(1)
else
	main()
	os.exit(0)
end
