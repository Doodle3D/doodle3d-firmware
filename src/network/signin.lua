---
-- TODO: document
local log = require('util.logger')
local utils = require('util.utils')
local uci = require('uci').cursor()
local iwinfo = require('iwinfo')
local settings = require('util.settings')
local wifi = require("network.wlanconfig")
local urlcode = require('util.urlcode')
local status = require('util.status')

local M = {}

local STATUS_FILE = "signinstatus"

local IDLE_STATUS 			= 1
local SIGNING_IN_STATUS 	= 2

--- Signin to connect.doodle3d.com server
--
function M.signin()

	--log:debug("signin:signin");

	local code, msg = M.getStatus()
	--log:debug("  status: "..utils.dump(code).." "..utils.dump(msg));

	-- if we are already signin in, skip
	if(code == SIGNING_IN_STATUS) then
		log:debug("  skipping signin")
		return
	end

	M.setStatus(SIGNING_IN_STATUS,"signing in")

	local baseurl = "http://connect.doodle3d.com/api/signin.php"

	local localip = wifi.getLocalIP();
	if localip == nil then
		log:error("signin failed no local ip found")
		M.setStatus(IDLE_STATUS,"idle")
		return false
	end

	local wifiboxid = wifi.getSubstitutedSsid(settings.get('network.cl.wifiboxid'))
	wifiboxid = urlcode.escape(wifiboxid)

	local cmd = "wget -q -T 2 -t 1 -O - "..baseurl.."?wifiboxid="..wifiboxid.."\\&localip="..localip;
	local output = utils.captureCommandOutput(cmd);
	log:info("signin: "..output)

	M.setStatus(IDLE_STATUS,"idle")

	return string.len(output) > 0, output
end

function M.getStatus()
	return status.get(STATUS_FILE);
end

function M.setStatus(code,msg)
	log:info("signin:setStatus: "..code.." | "..msg)
	status.set(STATUS_FILE,code,msg);
end

return M
