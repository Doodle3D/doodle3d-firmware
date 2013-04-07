local uci = require("uci").cursor()

local M = {}

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

function M.printWithSuccess(msg)
	if msg ~= nil and msg ~= "" then print("OK," .. msg)
	else print("OK") end
end
function M.exitWithSuccess(msg)
	if msg ~= nil and msg ~= "" then print("OK," .. msg)
	else print("OK") end
	os.exit(0)
end
function M.exitWithWarning(msg)
	if msg ~= nil and msg ~= "" then print("WARN," .. msg)
	else print("OK") end
	os.exit(0)
end
function M.exitWithError(msg)
	if msg ~= nil and msg ~= "" then print("ERR," .. msg)
	else print("OK") end
	os.exit(1)
end

function M.getUciSectionName(config, type)
	local sname = nil
	uci:foreach(config, type, function(s) sname = s[".name"] end)
	return sname
end

function M.exists(file)
	local r = io.open(file) --ignore returned message
	if r ~= nil then io.close(r) end
	return r ~= nil
end

function M.symlink(from, to)
	if from == nil or from == "" or to == nil or to == "" then return -1 end
	local x = "ln -s " .. from .. " " .. to
	return os.execute(x)
end


-- logging
M.LOG_LEVEL = {debug = 1, info = 2, warn = 3, error = 4, fatal = 5}
local logLevel, logVerbose, logStream

function M:initlog(level, verbose, stream)
	logLevel = level or M.LOG_LEVEL.warn
	logVerbose = verbose or false
	logStream = stream or io.stdout
end

local function log(level, msg, verbose)
	if level >= logLevel then
		local now = os.date("%m-%d %H:%M:%S")
		local i = debug.getinfo(3)
		local v = verbose ~= nil and verbose or logVerbose
		if v then logStream:write(now .. " (" .. level .. ")  \t" .. msg .. "  [" .. i.name .. "@" .. i.short_src .. ":" .. i.linedefined .. "]\n")
		else logStream:write(now .. " (" .. level .. ")  \t" .. msg .. "\n") end
	end
end

function M:logdebug(msg, verbose) log(M.LOG_LEVEL.debug, msg, verbose) end
function M:loginfo(msg, verbose) log(M.LOG_LEVEL.info, msg, verbose) end
function M:logwarn(msg, verbose) log(M.LOG_LEVEL.warn, msg, verbose) end
function M:logerror(msg, verbose) log(M.LOG_LEVEL.error, msg, verbose) end
function M:logfatal(msg, verbose) log(M.LOG_LEVEL.fatal, msg, verbose) end

return M
