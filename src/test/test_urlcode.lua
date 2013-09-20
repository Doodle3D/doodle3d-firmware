-- TODO: also test malformed query strings
local urlcode = require("util.urlcode")

local M = {
	_is_test = true,
	_skip = {},
	_wifibox_only = {}
}

-- NOTE: the previous approach using #t1 and #t2 was too naive and only worked for tables with contiguous ranges of numeric keys.
local function compareTables(t1, t2)
	local len = 0

	for k1,v1 in pairs(t1) do
		len = len + 1
		if t2[k1] ~= v1 then return false end
	end

	for _ in pairs(t2) do len = len - 1 end

	return len == 0 and true or false
end

local queryTexts = {
	[1] = "k1=v1&k2=v2x&k3yy=v3",
	[2] = "k1=v1&k2=v2x&k3yy=v3&",
	[3] = "k1=v1&k2=v2x&k3yy=v3&=",
	[4] = "k1=v1&k2=v2x&k3yy=v3& =",
	[5] = ""
}

local queryTables = {
	[1] = { ["k1"] = "v1", ["k2"] = "v2x", ["k3yy"] = "v3" },
	[2] = { ["k1"] = "v1", ["k2"] = "v2x", ["k3yy"] = "v3" },
	[3] = { ["k1"] = "v1", ["k2"] = "v2x", ["k3yy"] = "v3" },
	[4] = { ["k1"] = "v1", ["k2"] = "v2x", ["k3yy"] = "v3", [" "] = "" },
	[5] = {}
}

function M:_setup()
	local longValue = ""
	for i=1,5000 do
		longValue = longValue .. i .. ": abcdefghijklmnopqrstuvwxyz\n"
	end

	table.insert(queryTexts, "shortkey=&longkey=" .. longValue)
	table.insert(queryTables, { ["shortkey"] = "", ["longkey"] = longValue })
end

function M:_teardown()
end


function M:test_parsequery()
	for i=1,#queryTexts do
		local args = {}
		urlcode.parsequery(queryTexts[i], args)
		assert(compareTables(queryTables[i], args))
	end
end

function M:test_parsequeryNoRegex()
	for i=1,#queryTexts do
		local args = {}
		urlcode.parsequeryNoRegex(queryTexts[i], args)
		assert(compareTables(queryTables[i], args))
	end
end

return M
