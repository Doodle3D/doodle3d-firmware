local l = require("logger")
local RequestClass = require("rest.request")
local ResponseClass = require("rest.response")


local DEBUG_PCALLS = false


local postData = nil
local resp = ResponseClass.new()


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
				resp:setError("call to function '" .. mod .. "/" .. sr .. "' failed")
				print(resp:serializeAsJson())
				l:error("calling function '" .. func .. "' in API module '" .. mod .. "' somehow failed ('" .. r .. "')")
			end
		else
			resp:setError("function unknown '" .. mod .. "/" .. func .. "'")
			print(resp:serializeAsJson())
			l:error("could not resolve requested API function ('" .. sr .. "')")
		end
	end
end


init()
main()
