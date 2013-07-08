local JSON = (loadfile "util/JSON.lua")()

local M = {}
M.__index = M

setmetatable(M, {
	__call = function(cls, ...)
		return cls.new(...)
	end
})

function M.new()
	local self = setmetatable({}, M)
	
	self.body = {status = nil, data = {}}
	
	return self
end

function M:setStatus(s)
	self.body.status = s
end

function M:setSuccess(msg)
	self.body.status = "success"
	self.body.msg = msg
end

function M:setError(msg)
	self.body.status = "error"
	self.body.msg = msg
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
