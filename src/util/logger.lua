--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


---
-- Logging facilities.

local utils = require('util.utils')

local M = {}

local logLevel, logVerbose, logStream

--- Available log levels
-- @table LEVEL
M.LEVEL = {
	'debug', -- for debug messages
	'info', -- for informational messages
	'warn', -- for warnings (something is wrong/fishy but not neccesarily problematic)
	'error', -- for recoverable errors
	'fatal' -- for unrecoverable errors
}

-- M.LEVEL already has idx=>name entries, now create name=>idx entries
for i,v in ipairs(M.LEVEL) do
	M.LEVEL[v] = i
end


local function log(level, msg, verbose)
	if level >= logLevel then
		local now = os.date('%m-%d %H:%M:%S')
		local i = debug.getinfo(3) --the stack frame just above the logger call
		local v = verbose
		if v == nil then v = logVerbose end
		local name = i.name or "(nil)"
		local vVal = 'nil'
		local m = (type(msg) == 'string') and msg or utils.dump(msg)

		if v then logStream:write(now .. " (" .. M.LEVEL[level] .. ")     " .. m .. "  [" .. name .. "@" .. i.short_src .. ":" .. i.linedefined .. "]\n")
		else logStream:write(now .. " (" .. M.LEVEL[level] .. ")     " .. m .. "\n") end

		logStream:flush()
	end
end


--- Initializes the logger.
-- @tparam @{util.logger.LEVEL} level Minimum level of messages to log.
-- @tparam bool verbose Write verbose log messages (include file/line inforomation).
function M:init(level, verbose)
	logLevel = level or M.LEVEL.warn
	logVerbose = verbose or false
	logStream = stream or io.stdout
end

-- pass nil as stream to reset to stdout
function M:setStream(stream)
	logStream = stream or io.stdout
end

function M:debug(msg, verbose) log(M.LEVEL.debug, msg, verbose); return true end
function M:info(msg, verbose) log(M.LEVEL.info, msg, verbose); return true end
function M:warn(msg, verbose) log(M.LEVEL.warn, msg, verbose); return true end
function M:error(msg, verbose) log(M.LEVEL.error, msg, verbose); return false end
function M:fatal(msg, verbose) log(M.LEVEL.fatal, msg, verbose); return false end

return M
