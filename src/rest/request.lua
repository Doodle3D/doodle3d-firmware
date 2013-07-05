local M = {}

local urlcode = require("util.urlcode")

function M:new()
	--parse os.getenv("QUERY_STRING")
	--parse os.getenv("REPLY")?
	--parse arg

	local qs = os.getenv("QUERY_STRING")
	local urlargs = {}
	urlcode.parsequery(qs, urlargs)

	--supplement urlargs with arguments from the command-line
	for _, v in ipairs(arg) do
		local split = v:find("=")
		if split ~= nil then
			urlargs[v:sub(1, split - 1)] = v:sub(split + 1)
		end
	end
end
