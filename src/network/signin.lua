--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


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
	
	local attemptInterval = 1
	local maxAttempts = 20
	local attempt = 0
	
	local nextAttemptTime = os.time()
	
	local localip = ""
	local signinResponse = ""
	while true do
		if os.time() > nextAttemptTime then
			log:debug("signin attempt "..utils.dump(attempt).."/"..utils.dump(maxAttempts))
			local signedin = false
			local localip = wifi.getLocalIP();
			--log:debug("  localip: "..utils.dump(localip))
			if localip ~= nil then
				
				local wifiboxid = wifi.getSubstitutedSsid(settings.get('network.cl.wifiboxid'))
				wifiboxid = urlcode.escape(wifiboxid)
			
				local cmd = "wget -q -T 2 -t 1 -O - "..baseurl.."?wifiboxid="..wifiboxid.."\\&localip="..localip;
				signinResponse = utils.captureCommandOutput(cmd);
				log:debug("  signin response: \n"..utils.dump(signinResponse))
				local success = signinResponse:match('"status":"success"')
				log:debug("  success: "..utils.dump(success))
				if success ~= nil then
					signedin = true
				else
					log:warn("signin failed request failed (response: "..utils.dump(signinResponse)..")")
				end
			else 
				log:warn("signin failed no local ip found (attempt: "..utils.dump(attempt).."/"..utils.dump(maxAttempts)..")")
			end
			
			if signedin then
				break
			else
				attempt = attempt+1
				if attempt >= maxAttempts then
					-- still no localIP; fail
					M.setStatus(IDLE_STATUS,"idle")
					return false
				else
					nextAttemptTime = os.time() + attemptInterval
				end
			end
		end
	end
	
	M.setStatus(IDLE_STATUS,"idle")
	return string.len(signinResponse) > 0, signinResponse
end

function M.getStatus()
	return status.get(STATUS_FILE);
end

function M.setStatus(code,msg)
	log:info("signin:setStatus: "..code.." | "..msg)
	status.set(STATUS_FILE,code,msg);
end

return M
