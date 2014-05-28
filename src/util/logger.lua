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

local LONGEST_LEVEL_NAME = -1

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


--[[== module initialization code ==]]--

-- M.LEVEL already has idx=>name entries, now create name=>idx entries so it can be indexed both ways, and init LONGEST_LEVEL_NAME
for i,v in ipairs(M.LEVEL) do
	M.LEVEL[v] = i
	if v:len() > LONGEST_LEVEL_NAME then LONGEST_LEVEL_NAME = v:len() end
end


--[[================================]]--


local function log(level, module, msg, verboseFmt)
	if level <= logLevel then
		local now = os.date('%m-%d %H:%M:%S')
		local i = debug.getinfo(3) --the stack frame just above the logger call
		local v = verboseFmt
		if v == nil then v = logVerboseFmt end
		local name = i.name or "(nil)"
		local vVal = 'nil'
		local m = (type(msg) == 'string') and msg or utils.dump(msg)
		if module == nil then module = "LUA " end

		local levelName = M.LEVEL[level]
		local padding = string.rep(' ', LONGEST_LEVEL_NAME - levelName:len())

		if v then logStream:write(now .. " [" .. module .. "] (" .. levelName .. ")" .. padding .. ": " .. m .. "  [" .. name .. "@" .. i.short_src .. ":" .. i.linedefined .. "]\n")
		else logStream:write(now .. " [" .. module .. "] (" .. levelName .. ")" .. padding .. ": " .. m .. "\n") end

		logStream:flush()
	end
end


--- Initializes the logger.
-- @tparam @{util.logger.LEVEL} level Minimum level of messages to log.
-- @tparam bool verbose Write verbose log messages (include file/line information).
function M:init(level, verboseFmt)
	logLevel = level or M.LEVEL.warning
	logVerboseFmt = verboseFmt or false
	--logStream = stream or io.stdout
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

function M:getStream()
	return logStream
end

function M:error(module, msg, verboseFmt) log(M.LEVEL.error, module, msg, verboseFmt); return false end
function M:warning(module, msg, verboseFmt) log(M.LEVEL.warning, module, msg, verboseFmt); return true end
function M:info(module, msg, verboseFmt) log(M.LEVEL.info, module, msg, verboseFmt); return true end
function M:verbose(module, msg, verboseFmt) log(M.LEVEL.verbose, module, msg, verboseFmt); return true end
function M:bulk(module, msg, verboseFmt) log(M.LEVEL.bulk, module, msg, verboseFmt); return true end

return M
