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

return M
