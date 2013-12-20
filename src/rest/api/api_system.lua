--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


local utils = require('util.utils')

local M = {
	isApi = true
}

function M._global(request, response)
	response:setSuccess()
end

function M.fwversions(request, response)
	local pkgName = 'wifibox'
	local opkg = 'opkg -f /usr/share/lua/wifibox/opkg.conf'
	local output, rv
	
	response:setSuccess()
	
	output = utils.captureCommandOutput(opkg .. ' list-installed wifibox')
	local version = output:match('^wifibox %- (.*)\n$')
	response:addData('current', version)
	
	rv = os.execute(opkg .. ' update >/dev/null')
	if rv == 0 then
		output = utils.captureCommandOutput(opkg .. ' list wifibox')
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
