--[[
	The settings interface reads and writes its configuration using UCI.
	The corresponding config file is /etc/config/wifibox. To have an initial
	set of reasonable settings (and allow users to easily return to them),
	any key not found in the UCI configuration is looked up in the (immutable)
	'base configuration' (base_config.lua). This file also contains constraints
	to check if newly set values are valid.
	
	By the way, returning correct values in get()/fromUciValue() for booleans has been fixed at a
	relatively convenient time purely thanks to the unit tests...just to indicate they are useful. :)
]]--
local utils = require('util.utils')
local baseconfig = require('conf_defaults')
local uci = require('uci').cursor()

local M = {}

local UCI_CONFIG_NAME = 'wifibox' -- the file under /etc/config
local UCI_CONFIG_FILE = '/etc/config/' .. UCI_CONFIG_NAME
local UCI_CONFIG_TYPE = 'settings' -- the section type that will be used in UCI_CONFIG_FILE
local UCI_CONFIG_SECTION = 'general' -- the section name that will be used in UCI_CONFIG_FILE
local ERR_NO_SUCH_KEY = "key does not exist"


--- Returns the given key with all periods ('.') replaced by underscores ('_').
-- @param key The key for which to substitute dots.
-- @return The substituted key, or the key parameter itself if it is not of type 'string'.
local function replaceDots(key)
	if type(key) ~= 'string' then return key end
	local r = key:gsub('%.', '_')
	return r
end

-- The inverse of replaceDots()
local function replaceUnderscores(key)
	if type(key) ~= 'string' then return key end
	local r = key:gsub('_', '%.')
	return r
end

local function toUciValue(v, vType)
	if vType == 'bool' then return v and '1' or '0' end
	return tostring(v)
end

local function fromUciValue(v, vType)
	if v == nil then return nil end
	
	if vType == 'bool' then
		return (v == '1') and true or false
	elseif vType == 'float' or vType == 'int' then
		return tonumber(v)
	else
		return v
	end
	
end

local function isValid(value, baseTable)
	local varType, min, max, regex = baseTable.type, baseTable.min, baseTable.max, baseTable.regex
	
	if varType == 'bool' then
		return type(value) == 'boolean' or nil,"invalid bool value"
		
	elseif varType == 'int' or varType == 'float' then
		local numValue = tonumber(value)
		local ok = numValue and true or false
		ok = ok and (varType == 'float' or math.floor(numValue) == numValue)
		if min then ok = ok and numValue >= min end
		if max then ok = ok and numValue <= max end
		return ok or nil,"invalid int/float value or out of range"
		
	elseif varType == 'string' then
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


--- Returns the value of the requested key if it exists.
-- @param key The key to return the associated value for.
-- @return The associated value, beware (!) that this may be boolean false for keys of 'bool' type.
function M.get(key)
	key = replaceDots(key)
	local base = getBaseKeyTable(key)
	
	if not base then return nil,ERR_NO_SUCH_KEY end
	
	local v = base.default
	local uciV = fromUciValue(uci:get(UCI_CONFIG_NAME, UCI_CONFIG_SECTION, key), base.type)
	
	local actualV = v
	if uciV ~= nil then actualV = uciV end
	
	return actualV
end

function M.getAll()
	local result = {}
	for k,_ in pairs(baseconfig) do
		if not k:match('^[A-Z_]*$') then --TEMP: skip 'constants', which should be moved anyway
			local key = replaceUnderscores(k)
			result[key] = M.get(key)
		end
	end
	return result
end

function M.exists(key)
	key = replaceDots(key)
	return getBaseKeyTable(key) ~= nil
end

function M.isDefault(key)
	key = replaceDots(key)
	if not M.exists(key) then return nil,ERR_NO_SUCH_KEY end
	return uci:get(UCI_CONFIG_NAME, UCI_CONFIG_SECTION, key) == nil
end

-- pass nil as value to restore default
function M.set(key, value)
	key = replaceDots(key)
	local r = utils.create(UCI_CONFIG_FILE)
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
