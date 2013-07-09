local l = require("logger")
local ResponseClass = require("rest.response")

local M = {}

M.isApi = true

function M._global(request, response)
	local ba = request:getBlankArgument()
	
	response:setSuccess("REST test API - default function called with blank argument: '" .. (ba or "<nil>") .. "'")
	if ba ~= nil then response:addData("blank_argument", ba) end
end

function M.success(request, response)
	response:setSuccess("this successful response has been generated on purpose")
	response:addData("url", "http://xkcd.com/349/")
end

function M.fail(request, response)
	response:setFail("this failure has been generated on purpose")
	response:addData("url", "http://xkcd.com/336/")
end

function M.error(request, response)
	response:setError("this error has been generated on purpose")
	response:addData("url", "http://xkcd.com/1024/")
end

function M.echo(request, response)
	response:setSuccess("request echo")
	response:addData("request_data", request)
end

return M
