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
	log:info("signin")
	local baseurl = "http://connect.doodle3d.com/signin.php"
	
	local localip = wifi.getLocalIP();
	log:info("localip: "..utils.dump(localip))
	if localip == nil then
		log:error("signin failed no local ip found")
		return
	end
	
	local wifiboxid = wifi.getSubstitutedSsid(settings.get('network.cl.wifiboxid'))
	log:info("wifiboxid: "..utils.dump(wifiboxid))
	
	local cmd = "wget -q -O - "..baseurl.."?wifiboxid="..wifiboxid.."\\&localip="..localip;
	local output = utils.captureCommandOutput(cmd);
	log:info("signin: "..output)
	
	return 0
end

return M