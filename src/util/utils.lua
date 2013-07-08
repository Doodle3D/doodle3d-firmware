local uci = require("uci").cursor()

local M = {}

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

--FIXME: somehow protect this function from running arbitrary commands
function M.symlink(from, to)
	if from == nil or from == "" or to == nil or to == "" then return -1 end
	local x = "ln -s " .. from .. " " .. to
	return os.execute(x)
end

return M
