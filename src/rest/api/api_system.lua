local M = {
	isApi = true
}


-- TODO: this function has been duplicated from test/test_wlanconfig.lua
local function captureCommandOutput(cmd)
	local f = assert(io.popen(cmd, 'r'))
	local output = assert(f:read('*all'))
	--TODO: test if this works to obtain the return code (http://stackoverflow.com/questions/7607384/getting-return-status-and-program-output)
	--local rv = assert(f:close())
	--return output,rv[3]
	return output
end

function M._global(request, response)
	response:setSuccess()
end

function M.fwversions(request, response)
	local pkgName = 'wifibox'
	local opkg = 'opkg -f /usr/share/lua/wifibox/opkg.conf'
	local output, rv
	
	response:setSuccess()
	
	output = captureCommandOutput(opkg .. ' list-installed wifibox')
	local version = output:match('^wifibox %- (.*)\n$')
	response:addData('current', version)
	
	rv = os.execute(opkg .. ' update >/dev/null')
	if rv == 0 then
		output = captureCommandOutput(opkg .. ' list wifibox')
		local versions = {}
		for v in output:gmatch('wifibox %- (%d+\.%d+\.%d+%-%d+) %- ') do
			versions[#versions+1] = v
		end
		response:addData('all_versions', versions)
	else
		response:setFail("could not fetch update list")
	end
end

-- functie maken om mbv 'opkg compare-versions <v1> <op> <v2>' versies te vergelijken?
-- of intern vergelijken? (uitsplitsen naar major/minor/patch/pkgrel)
-- met comparefunctie (voor table.sort())
 
-- TO UPGRADE to version x (e.g. 0.1.0-7) (met force-optie):
-- 'opkg update'
-- 'opkg upgrade wifibox' (state versions explicitly?)

return M
