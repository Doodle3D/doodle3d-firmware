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

local logLevel, logVerboseFmt, logStream

--- Available log levels (starting at 1)
-- @table LEVEL
M.LEVEL = {
	'quiet',		-- not used for logging, only for setting levels
	'error',		-- fatal or non-fatal error condition
	'warning',	-- possibly troublesome situation
	'info',			-- information about what the application is doing
	'verbose',	-- extra trail information on what the application is doing
	'bulk'			-- debug information (in large amounts)
}

-- M.LEVEL already has idx=>name entries, now create name=>idx entries so it can be indexed both ways
for i,v in ipairs(M.LEVEL) do
	M.LEVEL[v] = i
end


local function log(level, msg, verboseFmt)
	if level <= logLevel then
		local now = os.date('%m-%d %H:%M:%S')
		local i = debug.getinfo(3) --the stack frame just above the logger call
		local v = verboseFmt
		if v == nil then v = logVerboseFmt end
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
function M:init(level, verboseFmt)
	logLevel = level or M.LEVEL.warning
	logVerboseFmt = verboseFmt or false
	logStream = stream or io.stdout
end

function M:setLevel(level, verboseFmt)
	logLevel = level or M.LEVEL.warning
	logVerboseFmt = verboseFmt or false
end

-- pass nil as stream to reset to stdout
function M:setStream(stream)
	logStream = stream or io.stdout
end

function M:getLevel()
	return logLevel, logVerboseFmt
end

function M:error(msg, verboseFmt) log(M.LEVEL.error, msg, verboseFmt); return false end
function M:warning(msg, verboseFmt) log(M.LEVEL.warning, msg, verboseFmt); return true end
function M:info(msg, verboseFmt) log(M.LEVEL.info, msg, verboseFmt); return true end
function M:verbose(msg, verboseFmt) log(M.LEVEL.verbose, msg, verboseFmt); return true end
function M:bulk(msg, verboseFmt) log(M.LEVEL.bulk, msg, verboseFmt); return true end

return M
