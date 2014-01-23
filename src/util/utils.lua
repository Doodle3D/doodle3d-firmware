--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


---
-- The unavoidable collection of utility functions.
--
-- Functions in this file are accompanied by unit tests, please study those
-- to see how utility functions are expected to behave.

local M = {}


--- Splits a string on a given divider character.
-- @string[opt=':'] div The divider character to use.
-- @return An array containing the resultant substrings.
-- @usage local str = "a,b,c"; local parts = str:split(',')
function string:split(div)
	local div, pos, arr = div or ':', 0, {}
	for st,sp in function() return self:find(div, pos, true) end do
		table.insert(arr, self:sub(pos, st - 1))
		pos = sp + 1
	end
	table.insert(arr, self:sub(pos))
	return arr
end

--- Returns the size of an open file handle.
-- @param file File handle to report about.
-- @treturn number Size of the file, determined by seeking to the end.
function M.fileSize(file)
	local current = file:seek()
	local size = file:seek('end')
	file:seek('set', current)
	return size
end

--- Convert an object to boolean.
-- String values which will yield true are (case insensitive): '1', 't' and 'true'.
-- Boolean true and numbers other than 0 also yield true, everything else yields false.
-- @param s The object to convert.
-- @treturn bool The converted value.
function M.toboolean(s)
	if not s then return false end

	local b = type(s) == 'string' and s:lower() or s
	local textTrue = (b == '1' or b == 't' or b == 'true')
	local boolTrue = (type(b) == 'boolean' and b == true)
	local numTrue = (type(b) == 'number' and b > 0)
	return textTrue or boolTrue or numTrue
end

--- Stringifies the given object.
-- Note that self-referencing objects will cause an endless loop with the current implementation.
-- @param o The object to convert.
-- @treturn string Stringified version of o.
function M.dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. M.dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

--- Returns the name of a section in a UCI config.
-- This name is necessary to be able to refer to the corresponding section and
-- the UCI library does not provide a way to look it up.
-- @tparam string config Name of the UCI config to search through.
-- @tparam string type UCI type of the section to find.
-- @treturn string Name of the section matching the parameters, or nil if it could not be found.
function M.getUciSectionName(config, type)
	local uci = require('uci').cursor()
	local sname = nil
	uci:foreach(config, type, function(s) sname = s['.name'] end)
	return sname
end

--- Reports whether or not a file exists. This is done by trying to open it.
-- @tparam string file Filename to report about.
-- @treturn bool|nil True if the file exists, false otherwise or nil on invalid argument.
-- @treturn ?string Descriptive message on error.
function M.exists(file)
	if not file or type(file) ~= 'string' or file:len() == 0 then
		return nil, "file must be a non-empty string"
	end

	local r = io.open(file, 'r') -- ignore returned message
	if r then r:close() end
	return r ~= nil
end

--- Creates a file if it does not exist yet.
-- @string file Path and name of the file to create.
-- @treturn bool|nil True if the file has been created, false if it already existed or nil on error
-- @treturn ?string Descriptive message on error
function M.create(file)
	local r,m = M.exists(file)

	if r == nil then
		return r,m
	elseif r == true then
		return true
	end

	r,m = io.open(file, 'a') -- append mode is probably safer in case the file does exist after all
	if not r then return r,m end

	r:close()
	return true
end

--- Create a symlink on the file system.
-- _Note_ that this function contains a potential security leak as it uses os.execute with given parameters.
-- @string from Source path for the symlink.
-- @string to Target path for the symlink.
-- @return The return value from @{os.execute}, or -1 on invalid parameter(s).
-- @fixme: somehow protect this function from running arbitrary commands
function M.symlink(from, to)
	if from == nil or from == '' or to == nil or to == '' then return -1 end
	local x = 'ln -s ' .. from .. ' ' .. to
	return os.execute(x)
end

function M.readFile(filePath)
	local f, msg, nr = io.open(filePath, 'r')
	if not f then return nil,msg,nr end

	local res = f:read('*all')
	f:close()

	return res
end

--- Runs a command and captures its output using @{io.popen}.
-- @string cmd The command to run.
-- @treturn string Output of the command that was run.
-- @todo: this function has been duplicated from rest/api/api_system.lua
function M.captureCommandOutput(cmd)
	local f = assert(io.popen(cmd..' 2>&1', 'r'))
	local output = assert(f:read('*all'))
	f:close()
	return output
end

return M
