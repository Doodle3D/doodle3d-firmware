local l = require("logger")
local ResponseClass = require("rest.response")

local M = {}

M.isApi = true

function M._global(d)
	local r = ResponseClass.new()
	local ba = d:getBlankArgument() or "<nil>"
	r:setSuccess("REST test API - default function called with blank argument: '" .. ba .. "'")
	return r
end

function M.success(d)
	local r = ResponseClass.new()
	r:setSuccess("yay!")
	return r
end

function M.error(d)
	local r = ResponseClass.new()
	r:setError("this error has been generated on purpose")
	return r
end

function M.echo(d)
	local r = ResponseClass.new()
	r:setSuccess("request echo")
	r:addData("request_data", d)
	return r
end

return M
