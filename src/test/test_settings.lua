local s = require('util.settings')
local defaults = require('conf_defaults')

local uciConfigFile = '/etc/config/wifibox'
local uciConfigFileBackup = '/etc/config/wifibox.orig'

local M = {
	_is_test = true,
	_skip = { 'constraints' }, --FIXME: enabling constraints 'breaks' other tests
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
	local realKey, fakeKey = 'network_ap_address', 'theQuestion'
	
	assert(not s.exists(fakeKey))
	local fakeValue = s.get(fakeKey)
	assert(fakeValue == nil)
	
	assert(s.exists(realKey))
	local realValue = s.get(realKey)
	assert(realValue ~= nil)
	assert(realValue == defaults.network_ap_address.default)
end

function M:test_set()
	local key, intKey, floatKey, boolKey = 'network_ap_address', 'printer_temperature', 'printer_filamentThickness', 'printer_useSubLayers'
	local intValue, floatValue, boolValue = 340, 4.2, false
	local value = '10.0.0.1'
	
	assert(s.get(key) == defaults.network_ap_address.default)
	assert(s.isDefault(key))
	
	assert(s.set(key, value))
	assert(s.get(key) == value)
	assert(not s.isDefault(key))
	
	assert(s.set(key, nil))
	assert(s.isDefault(key))
	
	-- test with value of int type
	assert(s.get(intKey) == defaults.printer_temperature.default)
	assert(s.isDefault(intKey))
	
	assert(s.set(intKey, intValue))
	assert(s.get(intKey) == intValue)
	assert(not s.isDefault(intKey))

	-- test with value of float type
	assert(s.get(floatKey) == defaults.printer_filamentThickness.default)
	assert(s.isDefault(floatKey))
	
	assert(s.set(floatKey, floatValue))
	assert(s.get(floatKey) == floatValue)
	assert(not s.isDefault(floatKey))

	-- test with value of bool type
	assert(s.get(boolKey) == defaults.printer_useSubLayers.default)
	assert(s.isDefault(boolKey))
	
	assert(s.set(boolKey, boolValue))
	assert(s.get(boolKey) == boolValue)
	assert(not s.isDefault(boolKey))
end

function M:test_dotsReplacement()
	local underscoredKey, dottedKey, mixedKey = 'printer_retraction_speed', 'printer.retraction.speed', 'printer.retraction_speed'
	
	assert(s.get(underscoredKey) == defaults.printer_retraction_speed.default)
	assert(s.get(dottedKey) == defaults.printer_retraction_speed.default)
	assert(s.get(mixedKey) == defaults.printer_retraction_speed.default)
	
	assert(s.set(mixedKey, 54321))
	assert(s.get(underscoredKey) == 54321)
	assert(s.get(dottedKey) == 54321)
end

function M:test_constraints()
	local key, key2 = 'network_ap_address', 'printer_temperature'
	local goodValue, badValue1, badValue2 = '10.0.0.1', '10.00.1', '10.0.0d.1'
	
	assert(s.set(key, goodValue))
	
	assert(s.set(key, badValue1) == nil)
	assert(s.get(key) == goodValue)
	
	assert(s.set(key, badValue2) == nil)
	assert(s.get(key) == goodValue)
	
	assert(s.get(key2) == defaults.printer_temperature.default)
	assert(s.set(key2, -1) == nil)
	assert(s.get(key2) == defaults.printer_temperature.default)
end

function M:test_setNonExistent()
	local fakeKey = 'theQuestion'
	
	assert(s.get(fakeKey) == nil)
	assert(s.set(fakeKey, 42) == nil)
	assert(s.get(fakeKey) == nil)
end

return M
