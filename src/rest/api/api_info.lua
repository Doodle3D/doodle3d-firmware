local M = {
	isApi = true
}


function M._global(request, response)
	response:setSuccess()
end

function M.firmware(request, response)
	--response:setSuccess()
	-- can return (essentially all wraps ipkg output):
	-- available (list)
	-- current
	-- latest
	-- upgradable
end

return M
