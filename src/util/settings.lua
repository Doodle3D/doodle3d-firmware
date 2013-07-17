--[[
	This settings interface reads and writes its configuration using UCI.
	The corresponding config file is /etc/config/wifibox. To have an initial
	set of reasonable settings (and allow users to easily return to them),
	any key not found in the UCI configuration is looked up in the (immutable)
	'base configuration' (base_config.lua). This file also contains constraints
	to check if newly set values are valid.
]]--
local u = require('util.utils')
local baseconfig = require('conf_defaults')
local uci = require('uci').cursor()

local M = {}

local UCI_CONFIG_NAME = 'wifibox' -- the file under /etc/config
local UCI_CONFIG_FILE = '/etc/config/' .. UCI_CONFIG_NAME
local UCI_CONFIG_TYPE = 'settings' -- the section type that will be used in UCI_CONFIG_FILE
local UCI_CONFIG_SECTION = 'general' -- the section name that will be used in UCI_CONFIG_FILE
local ERR_NO_SUCH_KEY = "key does not exist"


local function toUciValue(v, type)
	if type == 'bool' then return v and '1' or '0' end
	return tostring(v)
end

local function fromUciValue(v, type)
	if type == 'bool' then
		return (v == '1') and true or false
	elseif type == 'float' or type == 'int' then
		return tonumber(v)
	else
		return v
	end
	
end

local function isValid(value, baseTable)
	local type, min, max, regex = baseTable.type, baseTable.min, baseTable.max, baseTable.regex
	
	if type == 'bool' then
		return isboolean(value) or nil,"invalid bool value"
		
	elseif type == 'int' or type == 'float' then
		local numValue = tonumber(value)
		local ok = numValue and true or false
		ok = ok and (type == 'float' or math.floor(numValue) == numValue)
		if min then ok = ok and numValue >= min end
		if max then ok = ok and numValue <= max end
		return ok or nil,"invalid int/float value or out of range"
		
	elseif type == 'string' then
		local ok = true
		if min then ok = ok and value:len() >= min end
		if max then ok = ok and value:len() <= max end
		if regex then ok = ok and value:match(regex) ~= nil end
		return ok or nil,"invalid string value"
	end
	
	return true
end

local function getBaseKeyTable(key)
	local base = baseconfig[key]
	return type(base) == 'table' and base.default ~= nil and base or nil
end


function M.get(key)
	local base = getBaseKeyTable(key)
	
	if not base then return nil,ERR_NO_SUCH_KEY end
	
	local v = base.default
	local uciV = fromUciValue(uci:get(UCI_CONFIG_NAME, UCI_CONFIG_SECTION, key), base.type)
	
	return uciV or v
end

function M.exists(key)
	return getBaseKeyTable(key) ~= nil
end

function M.isDefault(key)
	if not M.exists(key) then return nil,ERR_NO_SUCH_KEY end
	return uci:get(UCI_CONFIG_NAME, UCI_CONFIG_SECTION, key) == nil
end

-- pass nil as value to restore default
function M.set(key, value)
	local r = u.create(UCI_CONFIG_FILE)
	uci:set(UCI_CONFIG_NAME, UCI_CONFIG_SECTION, UCI_CONFIG_TYPE)
	
	local base = getBaseKeyTable(key)
	if not base then return nil,ERR_NO_SUCH_KEY end
	
	if M.isDefault(key) and value == nil then return true end -- key is default already
	
	local current = uci:get(UCI_CONFIG_NAME, UCI_CONFIG_SECTION, key)
	
	if fromUciValue(current, base.type) == value then return true end
	
	if value ~= nil then
		local valid,m = isValid(value, base)
		if (valid) then
			uci:set(UCI_CONFIG_NAME, UCI_CONFIG_SECTION, key, toUciValue(value, base.type))
		else
			return nil,m
		end
	else
		uci:delete(UCI_CONFIG_NAME, UCI_CONFIG_SECTION, key)
	end
	
	uci:commit(UCI_CONFIG_NAME)
	return true
end

return M
