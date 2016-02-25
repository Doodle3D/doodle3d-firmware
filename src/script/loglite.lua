#!/usr/bin/env lua

-- Notes
-- * directives: either a color, a color prefixed by 'b' or one of: _delete, _nodelete, [_matchonly]
-- * pattern rules are matched top to bottom, the last one encountered overriding any previous conflicting directive
--
-- TODO:
-- * move script to firmware repo (since it's shared between that and print3d) and remove commit from print3d
-- * pre-split keyword lists for efficiency?
-- * keep formats separate and only concat in the end, so things like upperasing can work properly
-- * add more directives like uppercase, prefix/suffix?
-- * options: en/dis total count, en/dis match count (how to deal with multiple matches?), en/dis keep_mode / delete_mode/
-- * create named sets of options+patterns to allow for task-specific filter sets - choose/parse options and includes (pcall require()d) in main and pass on to workhorse function
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

local DEFAULT_FILTERSET = {
	['options'] = { 'default_enabled', 'keep_mode' },
	['patterns'] = {
		['%(error%)'] = 'red',
		['%(warning%)'] = 'yellow',
		['%(bulk%)'] = 'gray',
		['setState%(%)'] = 'bblue'
	}
}


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

local function makeAnsiCode(key)
	if not ANSI_COLORS[key] then return nil end
	return ESCAPE_STR .. ANSI_COLORS[key] .. 'm'
end

local function hasValue(t, needle)
	for k,v in pairs(t) do
		if needle == v then return k end
	end
	return nil
end

--- Determines if filename exists and can be opened for reading.
-- From http://stackoverflow.com/a/4991602
-- @string filename The file to test.
-- @return True if the file exists and is readable, false otherwise.
function fileExists(filename)
   local f = io.open(filename, "r")
   if f ~= nil then io.close(f) return true else return false end
end



--[[========================================================================]]--

local function tailStream(stream, filterSet)
	patterns = filterSet.patterns
	options = filterSet.options
	local c = 0
	for line in stream:lines() do
		--c = c + 1 -- Note: this would also count deleted lines
		local embellished = line
		local keepLine = (options.mode == 'keep')
		local keepLineOverridden = false

		-- look for a pattern matching this line
		for p,c in pairs(patterns) do
			if line:match(p) then
--				print("[DEBUG] +matched rule '" .. p .. "'/'" .. c .. "' against '" .. line .. "'")
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
--			print("[DEBUG] -skipped '"..line.."'")
		end

		--c = line:match 'truncated' and 0 or c -- from tail on stderr apparently
	end
end

--TODO: could be extended to look for multiple filenames in multiple paths
local function readConfigFile(filename, searchPath)
	fullPath = searchPath .. '/' .. filename
	if not fileExists(fullPath) then
--		print("[DEBUG] config file '" .. fullPath .. "' not found")
		return nil
	end
   
--	print("[DEBUG] using config file '" .. fullPath .. "'")
	-- require does not accept full paths? also, pcall does not help with dofile   
	return dofile(fullPath)
end

local function main()
	if #arg > 0 and arg[1] == "-h" or arg[1] == "--help" then
		print("Usage: either pass file to tail as argument, or pipe through stdin.")
		os.exit(0)
	end

	local followFile = #arg > 0 and arg[1] or nil
	local filterSetName = 'default'  -- TODO: parse from options and leave at 'default' if not specified

	--print("[DEBUG] following file: '" .. (followFile and followFile or "<stdin>") .. "'.")


	--local tailin = io.popen('tail -F '..(...)..' 2>&1', 'r')
	local tailin = followFile and io.popen('tail -f ' .. followFile, 'r') or io.stdin

	local filterSet = DEFAULT_FILTERSET
	
	configSets = readConfigFile(DFL_FILTERSET_FILE, os.getenv('HOME'))
	for k,_ in pairs(configSets) do
		if k == filterSetName then
			filterSet = configSets[filterSetName]
--			print("[DEBUG] using filter set '" .. filterSetName .. "' from config")
			break
		end
	end

	pcall(tailStream, tailin, filterSet) -- Note: protected call to suppress interrupt error thrown by lines iterator
end

main()
os.exit(0)
