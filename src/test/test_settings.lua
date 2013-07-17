local s = require('util.settings')
local defaults = require('conf_defaults')

local uciConfigFile = '/etc/config/wifibox'
local uciConfigFileBackup = '/etc/config/wifibox.orig'

local M = {
	_is_test = true,
	_skip = { },
	_wifibox_only = { 'get' }
}


function M:_setup()
	os.execute('mv -f ' .. uciConfigFile .. ' ' .. uciConfigFileBackup .. ' 2>/dev/null')
end

function M:_teardown()
	os.execute('rm -f ' .. uciConfigFile)
	os.execute('mv -f ' .. uciConfigFileBackup .. ' ' .. uciConfigFile .. ' 2>/dev/null')
end


function M:test_get()
	local realKey, fakeKey = 'apAddress', 'theAnswer'
	
	assert(not s.exists(fakeKey))
	local fakeValue = s.get(fakeKey)
	assert(fakeValue == nil)
	
	assert(s.exists(realKey))
	local realValue = s.get(realKey)
	assert(realValue ~= nil)
	assert(realValue == defaults.apAddress.default)
end

function M:test_set()
	local key, intKey = 'apAddress', 'temperature'
	local intValue, goodValue, badValue1, badValue2 = 340, '10.0.0.1', '10.00.1', '10.0.0d.1'
	
	assert(s.get(key) == defaults.apAddress.default)
	assert(s.isDefault(key))
	
	assert(s.set(key, goodValue))
	assert(s.get(key) == goodValue)
	assert(not s.isDefault(key))
	
	assert(s.set(key, badValue1) == nil)
	assert(s.get(key) == goodValue)
	
	assert(s.set(key, badValue2) == nil)
	assert(s.get(key) == goodValue)
	
	assert(s.set(key, nil))
	assert(s.isDefault(key))
	
	-- test with value of int type
	assert(s.get(intKey) == defaults.temperature.default)
	assert(s.isDefault(intKey))
	
	assert(s.set(intKey, intValue))
	assert(s.get(intKey) == intValue)
	assert(not s.isDefault(intKey))
end

function M:test_setNonExistent()
	local fakeKey = 'theAnswer'
	
	assert(s.get(fakeKey) == nil)
	assert(s.set(fakeKey, 42) == nil)
	assert(s.get(fakeKey) == nil)
end

return M
