local l = require("logger")
local RequestClass = require("rest.request")
local ResponseClass = require("rest.response")
local wifi = require("network.wlanconfig")
local netconf = require("network.netconfig")


--NOTE: pcall protects from invocation exceptions, which is what we need except
--during debugging. This flag replaces them with a normal call so we can inspect stack traces.
local DEBUG_PCALLS = true


local postData = nil


local function setupAutoWifiMode()
	io.write("--TODO: join known network if present, fall back to access point otherwise\n")
end

local function init()
	l:init(l.LEVEL.debug)
	l:setStream(io.stderr)
	
	if DEBUG_PCALLS then l:info("Wifibox CGI handler started (pcall debugging enabled)")
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
	local rq = RequestClass.new(postData, DEBUG_PCALLS) -- initializes itself using various environment variables and the arg array
	
	l:info("received request of type " .. rq:getRequestMethod() .. " with arguments: " .. l:dump(rq:getAll()))
	if rq:getRequestMethod() ~= "CMDLINE" then
		l:info("remote IP/port: " .. rq:getRemoteHost() .. "/" .. rq:getRemotePort())
		l:debug("user agent: " .. rq:getUserAgent())
	end
	
	if (not DEBUG_PCALLS and rq:getRequestMethod() == "CMDLINE") then
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

local s, msg = init()
if s == false then
	local resp = ResponseClass.new()
	resp:setError("initialization failed (" .. msg .. ")")
	resp:send() --FIXME: this message does not seem to be sent
	l:error("initialization failed (" .. msg .. ")") --NOTE: this assumes the logger has been inited properly, despite init() having failed
	os.exit(1)
else
	main()
	os.exit(0)
end
