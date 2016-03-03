#!/usr/bin/env lua

-- EXAMPLE USAGE:
-- To be able to run print3d and at the same time color the logging you can use
-- the pipe (|) operator. Use 2>&1 to redirect the stderr to stdout, e.g.:
-- ./print3d -S -V -F -p marlin_generic 2>&1 | ./loglite.lua 
-- 
-- Notes
-- * directives: either a color, a color prefixed by 'b' or one of: _delete, _nodelete, [_matchonly]
-- * pattern rules are matched top to bottom, the last one encountered overriding any previous conflicting directive
--
-- TODO:
-- * pre-split keyword lists for efficiency?
-- * keep formats separate and only concat in the end, so things like uppercasing can work properly
-- * add more directives like uppercase, prefix/suffix?
-- * options: en/dis total count, en/dis match count (how to deal with multiple matches?), en/dis keep_mode / delete_mode/
-- * add specialized patterns for levels/modules?
--
-- FIXME:
-- * with deleteMode enabled, multiple matches and _nodelete in a later match, previous directives are ignored

--[[
-- * https://stackoverflow.com/questions/17363973/how-can-i-tail-f-a-log-filetruncate-aware-in-lua
-- * http://pueblo.sourceforge.net/doc/manual/ansi_color_codes.html
]]--


--[[========================================================================]]--

local ANSI_COLORS = {
	['blink'] = 5, -- no dice on osx/iterm2
	['underline'] = 24, -- no dice on osx/iterm2
	['black'] = 30,
	['red'] = 31,
	['green'] = 32,
	['yellow'] = 33,
	['blue'] = 34,
	['magenta'] = 35,
	['cyan'] = 36,
	['white'] = 37,
	['bblack'] = 40,
	['bred'] = 41,
	['bgreen'] = 42,
	['byellow'] = 43,
	['bblue'] = 44,
	['bmagenta'] = 45,
	['bcyan'] = 46,
	['bwhite'] = 47
}

local ESCAPE_STR = string.char(27) .. "["
local RESET_CODE = ESCAPE_STR .. "m"

local DFL_FILTERSET_FILE = "loglite-filters.lua"



--[[========================================================================]]--

--- Stringifies the given object.
-- From util/utils.lua
-- Note that self-referencing objects will cause an endless loop with the current implementation.
-- @param o The object to convert.
-- @treturn string Stringified version of o.
local function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

--- Splits a string on a given divider character.
-- From util/utils.lua
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

--- Determines if filename exists and can be opened for reading.
-- From http://stackoverflow.com/a/4991602
-- @string filename The file to test.
-- @return True if the file exists and is readable, false otherwise.
function fileExists(filename)
   local f = io.open(filename, "r")
   if f ~= nil then io.close(f) return true else return false end
end

--- Converts keys of a table into a string.
-- Adapted from http://stackoverflow.com/a/12674376.
-- @string tbl A key/value table.
-- @string[opt=','] sep Separator to use between items.
-- @boolean[opt=false] sort Whether or not to sort the resulting list.
-- @return A string with all keys from the given table.
local function keysToString(tbl, sep, sort)
	local sep, sort = sep or ',', sort or false
	local keyset, n = {}, 0
	for k,_ in pairs(tbl) do
		n = n + 1
		keyset[n] = k
	end
	if sort then table.sort(keyset) end
	return table.concat(keyset, sep)
end

--- Merge two tables recursively (i.e., subtables also get merged).
-- from: http://stackoverflow.com/a/1283608
-- @table t1 Table to merge into.
-- @table t2 Table to merge into t1.
-- @return The combined table (actually t1).
function mergeTables(t1, t2)
	for k,v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k] or false) == "table" then
				mergeTables(t1[k] or {}, t2[k] or {})
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
	end
	return t1
end

local function hasValue(t, needle)
	for k,v in pairs(t) do
		if needle == v then return k end
	end
	return nil
end

local function makeAnsiCode(key)
	if not ANSI_COLORS[key] then return nil end
	return ESCAPE_STR .. ANSI_COLORS[key] .. 'm'
end



--[[========================================================================]]--

local function tailStream(stream, filterSet)
	patterns = filterSet and filterSet.patterns or {}
	options = filterSet and filterSet.options or { ['mode'] = 'keep' }
	local c = 0

	for line in stream:lines() do
		--c = c + 1 -- Note: this would also count deleted lines
		local embellished = line
		local keepLine = (options.mode == 'keep')
		local keepLineOverridden = false

		-- look for a pattern matching this line
		for p,c in pairs(patterns) do
			if line:match(p) then
				--print("[DEBUG] +matched rule '" .. p .. "'/'" .. c .. "' against '" .. line .. "'")
				local kws = c:split(',')

				if hasValue(kws, '_delete') then keepLine = false; keepLineOverridden = true
				elseif hasValue(kws, '_nodelete') then keepLine = true; keepLineOverridden = true
				end

				if keepLine then
					-- first collect formatting sequences
					local fmt = ''
					for _,kw in ipairs(kws) do
						local code = makeAnsiCode(kw)
						if code then fmt = fmt .. code end
					end

					-- then wrap the line in formatting, if any
					if fmt:len() > 0 then embellished = fmt .. embellished .. RESET_CODE end
				else
					-- Note: break out of loop and stop processing when line should be deleted _if_ the default has been overridden to do so
					if keepLineOverridden then
						embellished = nil
						break
					end
				end

				--break -- Note: don't break, allow multiple matches per line, e.g. to mix and match fg and bg colors
			end
		end

		if embellished and keepLine then
			c = c + 1

			if options.count == 'all' then print(c, embellished)
			else print(embellished) end
		else
			--print("[DEBUG] -skipped '"..line.."'")
		end

		--c = line:match 'truncated' and 0 or c -- from tail on stderr apparently
	end
end

--TODO: could be extended to look for multiple filenames in multiple paths
local function readConfigFile(filename, searchPath)
	fullPath = searchPath .. '/' .. filename
	if not fileExists(fullPath) then
		--print("[DEBUG] config file '" .. fullPath .. "' not found")
		return nil
	end
   
	--print("[DEBUG] using config file '" .. fullPath .. "'")
	-- require does not accept full paths? also, pcall does not help with dofile   
	return dofile(fullPath)
end

--- Load filter set with given name from configSets, with inheritance as specified.
local function readFilterSet(configSets, setName)
	local result = {}
	for k,_ in pairs(configSets) do
		if k == setName then
			parent = configSets[setName]['parent']
			if parent ~= nil then
				--print("[DEBUG] recursing for filter set '" .. parent .. "' from config")
				result = mergeTables(result, readFilterSet(configSets, parent))
			end
			--print("[DEBUG] using/merging filter set '" .. setName .. "' from config")
			result = mergeTables(result, configSets[setName])
			break
		end
	end
	return result
end

--NOTE: if command-line options get any more complex, switch to a lightweight
--      getopt like this one? https://attractivechaos.wordpress.com/2011/04/07/getopt-for-lua/
local function main()
	-- handle command-line arguments
	local showHelp, followFile, filterSetName = false, nil, 'default'
	if #arg > 0 and arg[1] == "-h" or arg[1] == "--help" then
		showHelp = true
	else
		if #arg > 0 and arg[1] ~= '-' then followFile = arg[1] end
		if #arg > 1 then filterSetName = arg[2] end
	end

	-- read filter set file if available
	local configSets = readConfigFile(DFL_FILTERSET_FILE, os.getenv('HOME')) or {}
	local filterSet = readFilterSet(configSets, filterSetName)
	--print("[DEBUG] final filter set for '" .. filterSetName .. "' from config: " .. dump(filterSet))

	-- if requested, display help and exit
	if showHelp and showHelp == true then
		print("Usage: loglite.lua [file-to-tail] [filter-set]")
		print("  If no arguments are supplied, or if the first one is `-', stdin is used as input.")
		print("  If no filter set is supplied, a set named `default' will be looked for.")
		print("  Filter sets can be defined in a file `loglite-filters.lua' in your home directory.")
		print()
		print("  Available filter sets in " .. os.getenv('HOME') .. "/" .. DFL_FILTERSET_FILE .. ": " .. keysToString(configSets, ', ', true))
		os.exit(0)
	end


	-------------------------

	--print("[DEBUG] following file: '" .. (followFile and followFile or "<stdin>") .. "', with filter set '" .. filterSetName .. "'.")

	--local tailin = io.popen('tail -F '..(...)..' 2>&1', 'r')
	local tailin = followFile and io.popen('tail -f ' .. followFile, 'r') or io.stdin

	pcall(tailStream, tailin, filterSet) -- Note: protected call to suppress interrupt error thrown by lines iterator
end

main()
os.exit(0)
