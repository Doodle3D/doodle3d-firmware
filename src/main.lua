--[[
TODO:
 - network/state returns awfully little information (only station mode)
 - document REST API (mention rq IDs and endpoint information, list endpoints+args+CRUD type, unknown values are empty fields)
 - use a slightly more descriptive success/error definition (e.g. errortype=system/missing-arg/generic)
 - how to handle requests which need a restart of uhttpd? (e.g. network/openap)
 - a plain GET request (no ajax/script) runs the risk of timing out on lengthy operations: implement polling in API to get progress updates?
   (this would require those operations to run in a separate daemon process which can be monitored by the CGI handler) 
 - protect dump function against reference loops (see: http://lua-users.org/wiki/TableSerialization, json also handles this well)
 - (this is an old todo item from network:available(), might still be relevant at some point)
   extend reconf interface to support function arguments (as tables) so wifihelper functionality can be integrated
   but how? idea: pass x_args={arg1="a",arg2="2342"} for component 'x'
   or: allow alternative for x="y" --> x={action="y", arg1="a", arg2="2342"}
   in any case, arguments should be put in a new table to pass to the function (since order is undefined it must be an assoc array)

NOTES:
 - The endpoint function info in response objects is incorrect when the global function is called with a blank argument,
   to cleanly solve this, module/function resolution should be moved from main() to the request object
]]--

local l = require("logger")
local RequestClass = require("rest.request")
local ResponseClass = require("rest.response")
local wifi = require("network.wlanconfig")
local reconf = require("network.netconfig")


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
	
	return wifi.init() and reconf.init(wifi, true)
end

--usually returns function+nil, function+number in case of number in place of function name; or
--nil+string if given arguments could not be resolved
local function resolveApiFunction(mod, func)
	if mod == nil then return nil, ("missing module name in CGI call") end
	
	local ok, mObj
	local reqModPath = "rest.api.api_" .. mod
	
	if DEBUG_PCALLS then ok, mObj = true, require(reqModPath)
	else ok, mObj = pcall(require, reqModPath)
	end
	
	if ok == false then return nil, ("API module '" .. mod .. "' does not exist") end
	
	if mObj == nil then return nil, ("API module '" .. mod .. "' could not be found") end
	
	if mObj.isApi ~= true then return nil, ("module '" .. mod .. "' is not part of the CGI API") end
	
	if (func == nil or func == '') then func = "_global" end --treat empty function name as nil
	local f = mObj[func]
	
	if (type(f) ~= "function") then
		if tonumber(func) ~= nil then
			return mObj["_global"], tonumber(func)
		else
			return nil, ("function '" .. func .. "' does not exist in API module '" .. mod .. "'")
		end
	end
	
	return f
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
		
		local mod = rq:getApiModule()
		local func = rq:getApiFunction()
		
		local sf,sr = resolveApiFunction(mod, func)
		if (sf ~= nil) then
			if (sr ~= nil) then
				rq:setBlankArgument(sr)
			end
			
			local ok, r
			if DEBUG_PCALLS then ok, r = true, sf(rq)
			else ok, r = pcall(sf, rq)
			end
			 
			if ok == true then
				print(r:serializeAsJson())
			else
				local resp = ResponseClass.new(rq)
				resp:setError("call to function '" .. mod .. "/" .. sr .. "' failed")
				print(resp:serializeAsJson())
				l:error("calling function '" .. func .. "' in API module '" .. mod .. "' somehow failed ('" .. r .. "')")
			end
		else
			local resp = ResponseClass.new(rq)
			resp:setError("function unknown '" .. (mod or "<empty>") .. "/" .. (func or "<global>") .. "'")
			print(resp:serializeAsJson())
			l:error("could not resolve requested API function ('" .. sr .. "')")
		end
	end
end


if init() == false then
	local resp = ResponseClass.new()
	resp:setError("initialization failed")
	print(resp:serializeAsJson()) --FIXME: this message does not seem to be sent
	l:error("initialization failed") --NOTE: this assumes the logger has been inited properly, despite init() having failed
	os.exit(1)
else
	main()
	os.exit(0)
end
