local JSON = (loadfile "util/JSON.lua")()

local M = {}
M.__index = M

local REQUEST_ID_ARGUMENT = "rq_id"
local INCLUDE_ENDPOINT_INFO = false

setmetatable(M, {
	__call = function(cls, ...)
		return cls.new(...)
	end
})

--requestObject should always be passed (except on init failure, when it is not yet available)
function M.new(requestObject)
	local self = setmetatable({}, M)
	
	self.body = {status = nil, data = {}}
	
	if requestObject ~= nil then
		local rqId = requestObject:get(REQUEST_ID_ARGUMENT)
		if rqId ~= nil then self.body[REQUEST_ID_ARGUMENT] = rqId end
		
		if INCLUDE_ENDPOINT_INFO == true then
			self.body["module"] = requestObject:getApiModule()
			self.body["function"] = requestObject:getApiFunction() or ""
		end
	end
	
	return self
end

function M:setStatus(s)
	self.body.status = s
end

function M:setSuccess(msg)
	self.body.status = "success"
	if msg ~= "" then self.body.msg = msg end
end

function M:setError(msg)
	self.body.status = "error"
	if msg ~= "" then self.body.msg = msg end
end

--NOTE: with this method, to add nested data, it is necessary to precreate the table and add it with its root key
--(e.g.: response:addData("data", {f1=3, f2="x"}))
function M:addData(k, v)
	self.body.data[k] = v
end

function M:serializeAsJson()
	return JSON:encode(self.body)
end

return M
