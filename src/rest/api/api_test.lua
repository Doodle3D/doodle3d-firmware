local l = require("logger")
local ResponseClass = require("rest.response")

local M = {}

M.isApi = true

function M._global(d)
	local r = ResponseClass.new(d)
	local ba = d:getBlankArgument()
	
	r:setSuccess("REST test API - default function called with blank argument: '" .. (ba or "<nil>") .. "'")
	if ba ~= nil then r:addData("blank_argument", ba) end
	
	return r
end

function M.success(d)
	local r = ResponseClass.new(d)
	r:setSuccess()
	return r
end

function M.fail(d)
	local r = ResponseClass.new(d)
	r:setFail()
	return r
end

function M.error(d)
	local r = ResponseClass.new(d)
	r:setError("this error has been generated on purpose")
	return r
end

function M.echo(d)
	local r = ResponseClass.new(d)
	r:setSuccess("request echo")
	r:addData("request_data", d)
	return r
end

return M
