--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


local l = require("util.logger")
local ResponseClass = require("rest.response")

local M = {
	isApi = true
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
function M.write_POST(request, response) response:setSuccess("this endpoint can only be accessed through POST request") end
function M.readwrite(request, response) response:setSuccess("this endpoint can be accessed both through GET and POST request") end
function M.readwrite2(request, response) response:setSuccess("this endpoint can be accessed both through GET and POST request") end


function M.echo(request, response)
	response:setSuccess("request echo")
	response:addData("request_data", request:getAll())
	response:addData("blank_argument", request:getBlankArgument())
	response:addData("path_data", request:getPathData())
end

return M
