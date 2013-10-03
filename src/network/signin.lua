local log = require('util.logger')
local utils = require('util.utils')
local uci = require('uci').cursor()
local iwinfo = require('iwinfo')
local settings = require('util.settings')
local wifi = require("network.wlanconfig")

local M = {}

--- Signin to connect.doodle3d.com server
-- 
function M.signin()
	local baseurl = "http://connect.doodle3d.com/api/signin.php"
	
	local localip = wifi.getLocalIP();
	if localip == nil then
		log:error("signin failed no local ip found")
		return false
	end
	
	local wifiboxid = wifi.getSubstitutedSsid(settings.get('network.cl.wifiboxid'))
	
	local cmd = "wget -q -O - "..baseurl.."?wifiboxid="..wifiboxid.."\\&localip="..localip;
	local output = utils.captureCommandOutput(cmd);
	log:info("signin: "..output)
	
	return string.len(output) > 0, output
end

return M