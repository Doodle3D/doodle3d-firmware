local l = require("util.logger")
local ResponseClass = require("rest.response")

local M = {}

M.isApi = true

--empty or nil is equivalent to 'ANY', otherwise restrict to specified letters (command-line is always allowed)
M._access = {
	_global = "GET",
	success = "GET", fail = "GET", error = "GET",
	read = "GET", write = "POST", readwrite = "ANY", readwrite2 = "",
	echo = "GET"
}


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


function M.read(request, response) response:setSuccess("this endpoint can only be accessed through GET request") end
function M.write(request, response) response:setSuccess("this endpoint can only be accessed through POST request") end
function M.readwrite(request, response) response:setSuccess("this endpoint can only be accessed through POST request") end
function M.readwrite2(request, response) response:setSuccess("this endpoint can only be accessed through POST request") end


function M.echo(request, response)
	response:setSuccess("request echo")
	response:addData("request_data", request:getAll())
	response:addData("blank_argument", request:getBlankArgument())
	response:addData("path_data", request:getPathData())
end

return M
