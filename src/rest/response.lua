local JSON = require('util/JSON')
local settings = require('util.settings')
local defaults = require('conf_defaults')

local M = {}
M.__index = M

local REQUEST_ID_ARGUMENT = 'rq_id'

M.httpStatusCode, M.httpStatusText, M.contentType = nil, nil, nil


setmetatable(M, {
	__call = function(cls, ...)
		return cls.new(...)
	end
})

--requestObject should always be passed (except on init failure, when it is not yet available)
function M.new(requestObject)
	local self = setmetatable({}, M)
	
	self.body = { status = nil, data = {} }
	self:setHttpStatus(200, 'OK')
	self:setContentType('text/plain;charset=UTF-8')
	--self:setContentType('application/json;charset=UTF-8')
	
	if requestObject ~= nil then
		local rqId = requestObject:get(REQUEST_ID_ARGUMENT)
		if rqId ~= nil then self.body[REQUEST_ID_ARGUMENT] = rqId end
		
		if settings.API_INCLUDE_ENDPOINT_INFO == true then
			self.body['module'] = requestObject:getRequestedApiModule()
			self.body['function'] = requestObject:getRealApiFunctionName() or ''
		end
	end
	
	return self
end

function M:setHttpStatus(code, text)
	if code ~= nil then self.httpStatusCode = code end
	if text ~= nil then self.httpStatusText = text end
end

function M:setContentType(contentType)
	if contentType ~= nil then self.contentType = contentType end
end

function M:setSuccess(msg)
	self.body.status = 'success'
	if msg ~= '' then self.body.msg = msg end
end

function M:setFail(msg)
	self.body.status = 'fail'
	if msg ~= '' then self.body.msg = msg end
end

function M:setError(msg)
	self.body.status = 'error'
	if msg ~= '' then self.body.msg = msg end
	
	self:addData('more_info', 'http://' .. defaults.API_BASE_URL_PATH .. '/wiki/wiki/communication-api')
end

--NOTE: with this method, to add nested data, it is necessary to precreate the table and add it with its root key
--(e.g.: response:addData('data', {f1=3, f2='x'}))
function M:addData(k, v)
	self.body.data[k] = v
end

function M:apiURL(mod, func)
	if not mod then return nil end
	if func then func = '/' .. func else func = "" end
	return 'http://' .. defaults.API_BASE_URL_PATH .. '/cgi-bin/d3dapi/' .. mod .. func
end

function M:serializeAsJson()
	return JSON:encode(self.body)
end

function M:send()
	io.write("Status: " .. self.httpStatusCode .. " " .. self.httpStatusText .. "\r\n")
	io.write ("Content-type: " .. self.contentType .. "\r\n\r\n")
	print(self:serializeAsJson())
end

return M
