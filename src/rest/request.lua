local urlcode = require("util.urlcode")

local M = {}
M.__index = M

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

return M
