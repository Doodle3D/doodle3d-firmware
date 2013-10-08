----------------------------------------------------------------------------
-- Utility functions for encoding/decoding of URLs.
--
-- @release $Id: urlcode.lua,v 1.10 2008/01/21 16:11:32 carregal Exp $
----------------------------------------------------------------------------

local ipairs, next, pairs, tonumber, type = ipairs, next, pairs, tonumber, type
local string = require"string"
local gsub = string.gsub
local strbyte, strchar, strformat, strsub = string.byte, string.char, string.format, string.sub
local tinsert = require"table".insert

--module ("cgilua.urlcode")
local _M = {}

-- Converts an hexadecimal code in the form %XX to a character
local function hexcode2char (h)
	return strchar(tonumber(h,16))
end

----------------------------------------------------------------------------
-- Decode an URL-encoded string (see RFC 2396)
----------------------------------------------------------------------------
function _M.unescape (str)
	str = gsub (str, "+", " ")
	str = gsub (str, "%%(%x%x)", hexcode2char)
	str = gsub (str, "\r\n", "\n")
	return str
end

-- Converts a character to an hexadecimal code in the form %XX
local function char2hexcode (c)
	return strformat ("%%%02X", strbyte(c))
end

----------------------------------------------------------------------------
-- URL-encode a string (see RFC 2396)
----------------------------------------------------------------------------
function _M.escape (str)
	str = gsub (str, "\n", "\r\n")
	str = gsub (str, "([^0-9a-zA-Z ])", char2hexcode) -- locale independent
	str = gsub (str, " ", "+")
	return str
end

----------------------------------------------------------------------------
-- Insert a (name=value) pair into table [[args]]
-- @param args Table to receive the result.
-- @param name Key for the table.
-- @param value Value for the key.
-- Multi-valued names will be represented as tables with numerical indexes
-- (in the order they came).
----------------------------------------------------------------------------
function _M.insertfield (args, name, value)
	if not args[name] then
		args[name] = value
	else
		local t = type (args[name])
		if t == "string" then
			args[name] = {
				args[name],
				value,
			}
		elseif t == "table" then
			tinsert (args[name], value)
		else
			error ("CGILua fatal error (invalid args table)!")
		end
	end
end

----------------------------------------------------------------------------
-- Parse url-encoded request data
-- (the query part of the script URL or url-encoded post data)
--
-- Each decoded (name=value) pair is inserted into table [[args]]
-- @param query String to be parsed.
-- @param args Table where to store the pairs.
----------------------------------------------------------------------------
function _M.parsequery (query, args)
	if type(query) == "string" then
		local insertfield, unescape = _M.insertfield, _M.unescape
		gsub (query, "([^&=]+)=([^&=]*)&?",
		function (key, val)
			_M.insertfield (args, unescape(key), unescape(val))
		end)
	end
end

----------------------------------------------------------------------------
-- Parse url-encoded request data without using regular expressions
-- (the query part of the script URL or url-encoded post data)
--
-- Each decoded (name=value) pair is inserted into table [[args]]
-- @param query String to be parsed.
-- @param args Table where to store the pairs.
----------------------------------------------------------------------------
function _M.parsequeryNoRegex (query, args)
	if type(query) == "string" then
		local insertfield, unescape = _M.insertfield, _M.unescape

		local k = 1
		while true do
			local v = query:find('=', k+1, true) -- look for '=', assuming a key of at least 1 character and do not perform pattern matching
			if not v then break end -- no k/v pairs left

			local key = query:sub(k, v-1)
			v = v + 1

			local ampersand = query:find('&', v, true)
			if not ampersand then ampersand = 0 end -- 0 will become -1 in the substring call below...meaning end of string


			local value = query:sub(v, ampersand - 1)

			insertfield (args, unescape(key), unescape(value))

			if ampersand == 0 then break end -- we couldn't find any ampersands anymore so this was the last k/v

			k = ampersand + 1
		end
	end
end

----------------------------------------------------------------------------
-- URL-encode the elements of a table creating a string to be used in a
-- URL for passing data/parameters to another script
-- @param args Table where to extract the pairs (name=value).
-- @return String with the resulting encoding.
----------------------------------------------------------------------------
function _M.encodetable (args)
	if args == nil or next(args) == nil then	-- no args or empty args?
		return ""
	end
	local escape = _M.escape
	local strp = ""
	for key, vals in pairs(args) do
		if type(vals) ~= "table" then
			vals = {vals}
		end
		for i,val in ipairs(vals) do
			strp = strp.."&"..escape(key).."="..escape(val)
		end
	end
	-- remove first &
	return strsub(strp,2)
end

return _M
