local urlcode = require("util.urlcode")
local ResponseClass = require("rest.response")

local M = {}
M.__index = M

local GLOBAL_API_FUNCTION_NAME = "_global"

local function kvTableFromUrlEncodedString(encodedText)
	local args = {}
	if (encodedText ~= nil) then
		urlcode.parsequery(encodedText, args)
	end
	return args
end

local function kvTableFromArray(argArray)
	local args = {}
	
	for _, v in ipairs(argArray) do
		local split = v:find("=")
		if split ~= nil then
			args[v:sub(1, split - 1)] = v:sub(split + 1)
		else
			args[v] = true
		end
	end
	
	return args
end


setmetatable(M, {
	__call = function(cls, ...)
		return cls.new(...)
	end
})

function M.new(postData, debug)
	local self = setmetatable({}, M)
	
	--NOTE: is it correct to assume that absence of REQUEST_METHOD indicates command line invocation?
	self.requestMethod = os.getenv("REQUEST_METHOD")
	if self.requestMethod ~= nil then
		self.remoteHost = os.getenv("REMOTE_HOST")
		self.remotePort = os.getenv("REMOTE_PORT")
		self.userAgent = os.getenv("HTTP_USER_AGENT")
	else
		self.requestMethod = "CMDLINE"
	end
	
	self.cmdLineArgs = kvTableFromArray(arg)
	self.getArgs = kvTableFromUrlEncodedString(os.getenv("QUERY_STRING"))
	self.postArgs = kvTableFromUrlEncodedString(postData)
	
	--TEMP: until these can be extracted from the url path itself
	self.apiModule = self.getArgs["m"]
	self.apiFunction = self.getArgs["f"]
	
	if debug then
		self.apiModule = self.cmdLineArgs["m"] or self.apiModule
		self.apiFunction = self.cmdLineArgs["f"] or self.apiFunction
	end
	
	if self.apiModule == "" then self.apiModule = nil end
	if self.apiFunction == "" then self.apiFunction = nil end
	
	return self
end

function M:getRequestMethod()
	return self.requestMethod
end

function M:getApiModule()
	return self.apiModule
end

function M:getApiFunction()
	return self.apiFunction
end

function M:getBlankArgument()
	return self.blankArgument
end

function M:setBlankArgument(arg)
	self.blankArgument = arg
end

function M:getRemoteHost() return self.remoteHost or "" end
function M:getRemotePort() return self.remotePort or 0 end
function M:getUserAgent() return self.userAgent or "" end

function M:get(key)
	if self.requestMethod == "GET" then
		return self.getArgs[key]
	elseif self.requestMethod == "POST" then
		return self.postArgs[key]
	elseif self.requestMethod == "CMDLINE" then
		return self.cmdLineArgs[key]
	else
		return nil
	end
end

function M:getAll()
	if self.requestMethod == "GET" then
		return self.getArgs
	elseif self.requestMethod == "POST" then
		return self.postArgs
	elseif self.requestMethod == "CMDLINE" then
		return self.cmdLineArgs
	else
		return nil
	end
end

--returns either a module object, or nil+errmsg
local function resolveApiModule(modname)
	if modname == nil then return nil, "missing module name" end
	if string.find(modname, "_") == 1 then return nil, "module names starting with '_' are preserved for internal use" end
	
	local reqModName = "rest.api.api_" .. modname
	local ok, modObj
	
	--TODO: create config.lua which contains DEBUG_PCALLS (nothing else for the moment)
	if DEBUG_PCALLS then ok, modObj = true, require(reqModName)
	else ok, modObj = pcall(require, reqModName)
	end
	
	if ok == false then return nil, "API module does not exist" end
	if modObj == nil then return nil, "API module could not be found" end
	if modObj.isApi ~= true then return nil, "module is not part of the CGI API" end
	
	return modObj
end

--returns funcobj+nil (usual), funcobj+number (global func with blank arg), or nil+errmsg (unresolvable or inaccessible)
local function resolveApiFunction(modname, funcname)
	if funcname and string.find(funcname, "_") == 1 then return nil, "function names starting with '_' are preserved for internal use" end
	
	local mod, msg = resolveApiModule(modname)
	
	if (funcname == nil or funcname == '') then funcname = GLOBAL_API_FUNCTION_NAME end --treat empty function name as nil
	local f = mod[funcname]
	local funcNumber = tonumber(funcname)
	
	if (type(f) == "function") then
		return f
	elseif funcNumber ~= nil then
		return mod[GLOBAL_API_FUNCTION_NAME], funcNumber
	else
		return nil, ("function '" .. funcname .. "' does not exist in API module '" .. modname .. "'")
	end
end

--returns either a response object+nil, or response object+errmsg
function M:handle()

	--TEMP: should be moved to init
	local mod = self:getApiModule()
	local func = self:getApiFunction()
	local sf, sr = resolveApiFunction(mod, func)
	
	local resp = ResponseClass.new(rq) --TEMP: do not do this before resolving. after resolving has been moved to init that will be automatically true
	
	if (sf ~= nil) then
		if (sr ~= nil) then self:setBlankArgument(sr) end
		
		local ok, r
		if DEBUG_PCALLS then ok, r = true, sf(self)
		else ok, r = pcall(sf, self)
		end
		 
		if ok == true then
			return r, nil
		else
			resp:setError("call to function '" .. mod .. "/" .. sr .. "' failed")
			return resp, ("calling function '" .. func .. "' in API module '" .. mod .. "' somehow failed ('" .. r .. "')")
		end
	else
		resp:setError("function unknown '" .. (mod or "<empty>") .. "/" .. (func or "<global>") .. "'")
		return resp, ("could not resolve requested API function ('" .. sr .. "')")
	end
	
	return resp
end

return M
