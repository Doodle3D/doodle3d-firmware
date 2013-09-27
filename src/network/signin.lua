local log = require('util.logger')
local utils = require('util.utils')
local uci = require('uci').cursor()
local iwinfo = require('iwinfo')
local settings = require('util.settings')
local wlanconfig = require("network.wlanconfig")

local M = {}

-- TODO: this function has been duplicated from rest/api/api_system.lua
local function captureCommandOutput(cmd)
	local f = assert(io.popen(cmd, 'r'))
	local output = assert(f:read('*all'))
	--TODO: test if this works to obtain the return code (http://stackoverflow.com/questions/7607384/getting-return-status-and-program-output)
	--local rv = assert(f:close())
	--return output,rv[3]
	return output
end

--- Signin to connect.doodle3d.com server
-- 
function M.signin()
	local wifiboxid = "henk"
	local localip = "10.0.0.99"
	local baseurl = "http://192.168.5.220/connect.doodle3d.local/signin.php"
	
	local ifconfig = captureCommandOutput("ifconfig wlan0");
	--log:info("ifconfig: "..ifconfig)
	local localip = ifconfig:match('inet addr:([%d\.]+)')
	--log:info("localip: "..utils.dump(localip))
	
	local wifiboxid = wlanconfig.getSubstitutedSsid(settings.get('network.cl.wifiboxid'))
	--log:info("wifiboxid: "..utils.dump(wifiboxid))
	
	local cmd = "wget -q -O - "..baseurl.."?wifiboxid="..wifiboxid.."\\&localip="..localip;
	local output = captureCommandOutput(cmd);
	log:info("signin: "..output)
	
	return 0
end

return M