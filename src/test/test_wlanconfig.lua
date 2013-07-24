local wlanconfig = require("network.wlanconfig")

local M = {
	_is_test = true,
	_skip = {},
	_wifibox_only = {}
}

local function captureCommandOutput(cmd)
	local f = assert(io.popen(cmd, 'r'))
	return assert(f:read('*all'))
end

function M._setup()
	wlanconfig.init()
end

function M.test_getMacAddress()
	local reportedMac = wlanconfig.getMacAddress()
	local f = io.open('/sys/class/net/wlan0/address')
	assert(f)
	local output = f:read('*all')
	f:close()
	local actualMac = output:match('(%w%w:%w%w:%w%w:%w%w:%w%w:%w%w)'):gsub(':', ''):upper()
	
	assert(reportedMac == actualMac)
end

function M.test_getSubstitutedSsid()
	local mac = wlanconfig.getMacAddress()
	local macTail = mac:sub(7)
	
	local expected1 = 'pre' .. macTail .. 'post'
	local expected2 = 'pre' .. macTail .. 'post-cache-test'
	
	assert(wlanconfig.getSubstitutedSsid('pre%%MAC_ADDR_TAIL%%post') == expected1)
	assert(wlanconfig.getSubstitutedSsid('pre%%MAC_ADDR_TAIL%%post-cache-test') == expected2)
	assert(wlanconfig.getSubstitutedSsid('pre%%MAC_ADDR_TAIL%%post') == expected1)
	assert(wlanconfig.getSubstitutedSsid('pre%%MAC_ADDR_TAIL%%post') == expected1)
end

return M
