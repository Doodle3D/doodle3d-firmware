--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


---
-- The REST response object handles all operations necessary to generate a HTTP response.
-- It knows about the request, ensures the correct HTTP headers are present and
-- allows to set a status (one of `success`, `fail` or `error`) and addtional data.
local JSON = require('util/JSON')
local settings = require('util.settings')
local defaults = require('conf_defaults')
local utils = require('util.utils')
local log = require('util.logger')
  
local M = {}
M.__index = M

local REQUEST_ID_ARGUMENT = 'rq_id'

M.httpStatusCode, M.httpStatusText, M.contentType = nil, nil, nil
M.binaryData, M.binarySavename = nil, nil

--- Print a HTTP header line with the given type and value.
-- @string headerType
-- @string headerValue
local function printHeaderLine(headerType, headerValue)
	io.write(headerType .. ": " .. headerValue .. "\r\n")
end


setmetatable(M, {
	__call = function(cls, ...)
		return cls.new(...)
	end
})

--- Instantiates a new response object initialized with the given @{request} object.
-- The request object should always be passed, except on init failure, when it is not yet available.
-- @tparam request requestObject The object representing the HTTP request.
-- @treturn response A newly instantiated response object.
function M.new(requestObject)
	local self = setmetatable({}, M)
	self.body = { status = nil, data = {} }
	self:setHttpStatus(200, 'OK')
	self:setContentType('application/json;charset=UTF-8')
	--self:setContentType('application/json;charset=UTF-8')

	-- A queue for functions to be executed when the response has been given.
	-- Needed for api calls like network/associate, which requires a restart of the webserver.
	self.postResponseQueue = {}

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

--- Set HTTP status (the default is `200 OK`).
-- @number code The status code.
-- @string text The status text, this should of course correspond to the given code.
function M:setHttpStatus(code, text)
	if code ~= nil then self.httpStatusCode = code end
	if text ~= nil then self.httpStatusText = text end
end

--- Set the HTTP content type (the default is `text/plain;charset=UTF-8`).
-- @string contentType The content type to set.
function M:setContentType(contentType)
	if contentType ~= nil then self.contentType = contentType end
end

--- Set REST status to success.
-- @string[opt] msg An optional human-readable message to include with the status.
function M:setSuccess(msg)
	self.body.status = 'success'
	if msg ~= '' then self.body.msg = msg end
end

--- Set REST status to failure.
-- @string[opt] msg An optional human-readable message to include with the status.
function M:setFail(msg)
	self.body.status = 'fail'
	if msg ~= '' then self.body.msg = msg end
end

--- Set REST status to error.
-- A reference to the API documentation will also be included.
-- @string[opt] msg An optional human-readable message to include with the status.
function M:setError(msg)
	self.body.status = 'error'
	if msg ~= '' then self.body.msg = msg end

	self:addData('more_info', 'http://' .. defaults.API_BASE_URL_PATH .. '/api')
end

--- Adds a data item to the response, this will be included under the `data` item of the json text.
--
-- NOTE: To add nested data with this method, it is necessary to precreate the table
-- and then add that with its root key (see usage).
--
-- After calling this, any binary data set by @{M:setBinaryFileData} will not be sent anymore.
--
-- @string k The key of the item to set.
-- @param v The value to set.
-- @usage response:addData('f_values', {f1=3, f2='x'})
function M:addData(k, v)
	self.body.data[k] = v
	self.binaryData = nil
end

--- Queue a function for execution after the response has been passed back to the webserver.
--
-- Note that this is not useful in many cases since the webserver will not actually send
-- the response until this script finishes. So for instance if the queue contains code
-- to restart the webserver, the response will never be sent out.
-- @func fn The function to queue.
function M:addPostResponseFunction(fn)
  table.insert(self.postResponseQueue, fn)
end

--- Call all function on the post-response queue, see @{M:addPostResponseFunction} for details and a side-note.
function M:executePostResponseQueue()
  --log:info("Response:executePostResponseQueue: " .. utils.dump(self.postResponseQueue))

  for i,fn in ipairs(self.postResponseQueue) do fn() end
end

--- Returns an API url pointing to @{conf_defaults.API_BASE_URL_PATH}, which is quite useless.
-- @string mod
-- @string func
-- @treturn string A not-so-useful URL.
function M:apiURL(mod, func)
	if not mod then return nil end
	if func then func = '/' .. func else func = "" end
	return 'http://' .. defaults.API_BASE_URL_PATH .. '/cgi-bin/d3dapi/' .. mod .. func
end

--- Returns the body data contained in this object as [JSON](http://www.json.org/).
-- @treturn string The JSON data.
function M:serializeAsJson()
	return JSON:encode(self.body)
end

--- Writes HTTP headers, followed by an HTTP body containing JSON data to stdout.
function M:send()
	printHeaderLine("Status", self.httpStatusCode .. " " .. self.httpStatusText)
	printHeaderLine("Content-Type", self.contentType)
	printHeaderLine("Access-Control-Allow-Origin", "*")
	printHeaderLine("Expires", "-1")

	if self.binaryData == nil then
		io.write("\r\n")
		print(self:serializeAsJson())
	else
		printHeaderLine("Content-Disposition", "attachment; filename=" .. self.binarySavename)
		io.write("\r\n")
		io.write(self.binaryData)
	end
	
	if self.body.status ~= "success" then 
		log:debug("Response:"..utils.dump(self.body.status).." ("..utils.dump(self.body.msg)..")")
	end 
end

--- Sets the response object to return binary data instead of JSON as its body.
--
-- After calling this, REST data and status will not be sent anymore.
-- @string rFile The file on the local file system to read the data from.
-- @string saveName The file name to suggest the user to save the data in.
-- @string contentType The content type of the data.
-- @treturn bool|nil True, or nil in which case the second argument will be set.
-- @treturn ?string An error message if the first argument is nil.
function M:setBinaryFileData(rFile, saveName, contentType)
	if type(rFile) ~= 'string' or rFile:len() == 0 then return false end

	local f,msg = io.open(rFile, "rb")

	if not f then return nil,msg end

	self.binaryData = f:read("*all")
	f:close()

	self.binarySavename = saveName
	self:setContentType(contentType)

	return true
end

return M
