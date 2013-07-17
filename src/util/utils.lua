local uci = require('uci').cursor()

local M = {}

function string:split(div)
	local div, pos, arr = div or ':', 0, {}
	for st,sp in function() return self:find(div, pos, true) end do
		table.insert(arr, self:sub(pos, st - 1))
		pos = sp + 1
	end
	table.insert(arr, self:sub(pos))
	return arr
end

function M.toboolean(s)
	if not s then return false end
	
	local b = type(s) == 'string' and s:lower() or s
	local textTrue = (b == '1' or b == 't' or b == 'true')
	local boolTrue = (type(b) == 'boolean' and b == true)
	local numTrue = (type(b) == 'number' and b > 0)
	return textTrue or boolTrue or numTrue
end

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

function M.getUciSectionName(config, type)
	local sname = nil
	uci:foreach(config, type, function(s) sname = s['.name'] end)
	return sname
end

function M.exists(file)
	if not file or type(file) ~= 'string' or file:len() == 0 then
		return nil, "file must be a non-empty string"
	end
	
	local r = io.open(file, 'r') -- ignore returned message
	if r then r:close() end
	return r ~= nil
end

--creates and returns true if not exists, returns false it does, nil+msg on error
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

--FIXME: somehow protect this function from running arbitrary commands
function M.symlink(from, to)
	if from == nil or from == '' or to == nil or to == '' then return -1 end
	local x = 'ln -s ' .. from .. ' ' .. to
	return os.execute(x)
end

return M
