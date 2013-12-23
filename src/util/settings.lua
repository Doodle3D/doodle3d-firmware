--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


---
-- The settings interface reads and writes configuration keys using [UCI](http://wiki.openwrt.org/doc/uci).
-- All keys have pre-defined defaults in @{conf_defaults} which will be used
-- if no value is stored in the UCI config. The UCI config file is `/etc/config/wifibox`.
-- The default values guarantee there will always be a set of reasonable settings
-- to use and provide a clear overview of all existing configuration keys as well.
-- uci api: http://wiki.openwrt.org/doc/techref/uci, http://luci.subsignal.org/api/luci/modules/luci.model.uci.html
local uci = require('uci').cursor()
local utils = require('util.utils')
local baseconfig = require('conf_defaults')
local utils = require('util.utils')
local log = require('util.logger')

local M = {}

--- UCI config name (i.e., file under `/etc/config`)
local UCI_CONFIG_NAME = 'wifibox'

--- Absolute path to the UCI config file
local UCI_CONFIG_FILE = '/etc/config/' .. UCI_CONFIG_NAME

--- [Section type](http://wiki.openwrt.org/doc/techref/uci#about.uci.structure) that will be used in @{UCI_CONFIG_FILE}
local UCI_CONFIG_TYPE = 'settings'

--- [Section name](http://wiki.openwrt.org/doc/techref/uci#about.uci.structure) that will be used for 'public' settings (as predefined in conf_defaults.lua) in @{UCI_CONFIG_FILE}
local UCI_CONFIG_SECTION = 'general'

--- [Section name](http://wiki.openwrt.org/doc/techref/uci#about.uci.structure) that will be used for 'firmware-local' settings in @{UCI_CONFIG_FILE}
local UCI_CONFIG_SYSTEM_SECTION = 'system'

local ERR_NO_SUCH_KEY = "key does not exist"


--- Returns a key with all periods ('.') replaced by underscores ('_').
-- @string key The key for which to substitute dots.
-- @return The substituted key, or the key parameter itself if it is not of type 'string'.
local function replaceDots(key)
	if type(key) ~= 'string' then return key end
	local r = key:gsub('%.', '_')
	return r
end

--- Returns a key with all underscores ('_') replaced by periods ('.').
-- @string key The key for which to substitute underscores.
-- @return The substituted key, or the key parameter itself if it is not of type 'string'.
local function replaceUnderscores(key)
	if type(key) ~= 'string' then return key end
	local r = key:gsub('_', '%.')
	return r
end

--- Converts a lua value to equivalent representation for UCI.
-- Boolean values are converted to '1' and '0', everything else is converted to a string.
--
-- @p v The value to convert.
-- @p vType The type of the given value.
-- @return A value usable to write to UCI.
local function toUciValue(v, vType)
	if vType == 'bool' then return v and '1' or '0' end
	if(vType == 'string') then
		v = v:gsub('[\n\r]', '\\n')
	end

	return tostring(v)
end

--- Converts a value read from UCI to a correctly typed lua value.
-- For boolean, '1' is converted to true and everything else to false. Floats
-- and ints are converted to numbers and everything else will be returned as is.
--
-- @p v The value to convert.
-- @p vType The type of the given value.
-- @return A lua value typed correctly with regard to the vType parameter.
local function fromUciValue(v, vType)
	if v == nil then return nil end

	if vType == 'bool' then
		return (v == '1') and true or false
	elseif vType == 'float' or vType == 'int' then
		return tonumber(v)
	elseif vType == 'string' then
		v = v:gsub('\\n', '\n')
		return v
	else
		return v
	end

end

--- Reports whether a value is valid given the constraints specified in a base table.
-- @p value The value to test.
-- @tab baseTable The base table to use constraint data from (min,max,regex).
-- @treturn bool Returns true if the value is valid, false if it is not.
local function isValid(value, baseTable)
	local varType, min, max, regex, isValid = baseTable.type, baseTable.min, baseTable.max, baseTable.regex, baseTable.isValid

	if isValid then
		local ok,msg = isValid(value)
		if msg == nil then msg = "invalid value" end
		return ok or nil,msg
	end

	if varType == 'bool' then
		return type(value) == 'boolean' or nil,"invalid bool value"

	elseif varType == 'int' or varType == 'float' then
		local numValue = tonumber(value)
		if numValue == nil then
			return nil, "invalid number"
		elseif varType == 'int' and math.floor(numValue) ~= numValue then
			return nil, "invalid int"
		elseif min and numValue < min then
			return nil, "too low"
		elseif max and numValue > max then
			return nil, "too high"
		end

	elseif varType == 'string' then
		local ok = true
		if min and value:len() < min then
			return nil,"too short"
		elseif max and value:len() > max then
			return nil,"too long"
		elseif regex and value:match(regex) == nil then
			return nil,"invalid value"
		end
	end

	return true
end

--- Looks up the table in @{conf_defaults}.lua corresponding to a key.
-- @string key The key for which to return the base table.
-- @treturn table The base table for key, or nil if it does not exist.
local function getBaseKeyTable(key)
	local base = baseconfig[key]
	return type(base) == 'table' and base.default ~= nil and base or nil
end

--- Looks up the table in @{subconf_defaults}.lua corresponding to a key.
-- @string key The key for which to return the base table.
-- @treturn table The base table for key, or nil if it does not exist.
--[[local function getSubBaseKeyTable(key)
	local base = subconfig[key]
	return type(base) == 'table' and base.default ~= nil and base or nil
end]]--


--- Returns the value of the requested key if it exists.
-- @p key The key to return the associated value for.
-- @return The associated value, beware (!) that this may be boolean false for keys of 'bool' type, or nil if the key could not be read because of a UCI error.
-- @treturn string Message in case of error.
function M.get(key)
	--log:info("settings:get: "..utils.dump(key))
	key = replaceDots(key)
	local base = getBaseKeyTable(key)

	if not base then return nil,ERR_NO_SUCH_KEY end

	local section = UCI_CONFIG_SECTION;
	if base.subSection ~= nil then
		section = M.get(base.subSection)
	end

	local uciV,msg = uci:get(UCI_CONFIG_NAME, section, key)
	if not uciV and msg ~= nil then
		local errorMSG = "Issue reading setting '"..utils.dump(key).."': "..utils.dump(msg);
		log:info(errorMSG)
		return nil, errorMSG;
	end

	local uciV = fromUciValue(uciV, base.type)
	if uciV ~= nil then
		-- returning value from uci
		return uciV
	elseif base.subSection ~= nil then
		local subDefault = base["default_"..section]
		if subDefault ~= nil then
			-- returning subsection default value
			return subDefault
		end
	end
	-- returning default value
	return base.default
end

--- Returns all configuration keys with their current values.
-- @return A table containing a key/value pair for each configuration key, or nil if a UCI error occured.
-- @return string Message in case of error.
function M.getAll()
	local result = {}
	for k,_ in pairs(baseconfig) do
		if not k:match('^[A-Z_]*$') then --TEMP: skip 'constants', which should be moved anyway
			local key = replaceUnderscores(k)
			local v, msg = M.get(key)
			if not v and msg ~= nil then
				return nil, msg
			else
				result[key] = v
			end
		end
	end
	return result
end

--- Reports whether or not a key exists.
-- @string key The key to find.
-- @treturn bool True if the key exists, false if not.
function M.exists(key)
	key = replaceDots(key)
	return getBaseKeyTable(key) ~= nil
end

--- Reports whether or not a key is at its default value.
-- 'Default' in this regard means that no UCI value is defined. This means that
-- if for instance, the default is 'abc', and UCI contains a configured value of
-- 'abc' as well, that key is _not_ a default value.
--
-- @string key The key to report about.
-- @treturn bool True if the key is currently at its default value, false if not.
function M.isDefault(key)
	key = replaceDots(key)
	if not M.exists(key) then return nil,ERR_NO_SUCH_KEY end
	return uci:get(UCI_CONFIG_NAME, UCI_CONFIG_SECTION, key) == nil
end

--- Sets a key to a new value or reverts it to the default value.
-- @string key The key to set.
-- @p[opt=nil] value The value or set, or nil to revert key to its default value.
-- @p[opt=nil] noCommit If true, do not commit the uci configuration; this is more efficient when setting multiple values
-- @treturn bool|nil True if everything went well, false if validation error, nil in case of error.
-- @treturn ?string Error message in case first return value is nil (invalid key).
function M.set(key, value, noCommit)
	log:info("settings:set: "..utils.dump(key).." to: "..utils.dump(value))
	key = replaceDots(key)

	local r = utils.create(UCI_CONFIG_FILE)
	local rv, msg = uci:set(UCI_CONFIG_NAME, UCI_CONFIG_SECTION, UCI_CONFIG_TYPE)
	if not rv and msg ~= nil then
		local errorMSG = "Issue creating section '"..utils.dump(UCI_CONFIG_SECTION).."': "..utils.dump(msg);
		log:info(errorMSG)
		return nil, errorMSG;
	end

	local base = getBaseKeyTable(key)
	if not base then return false,ERR_NO_SUCH_KEY end

	--log:info("  base.type: "..utils.dump(base.type))
	if base.type == 'bool' then
		if value ~= "" then
			value = utils.toboolean(value)
		else
			value = nil
		end
	elseif base.type == 'int' or base.type == 'float' then
		value = tonumber(value)
		if(value == nil) then
			return false,"Value isn't a valid int or float"
		end
	end
	
	local valid,m = isValid(value, base)
	if not valid then
		return false,m
	end

	local section = UCI_CONFIG_SECTION;
	if base.subSection ~= nil then
		section = M.get(base.subSection)
		local rv, msg = uci:set(UCI_CONFIG_NAME, section, UCI_CONFIG_TYPE)
		if not rv and msg ~= nil then
			local errorMSG = "Issue getting subsection '"..utils.dump(base.subSection).."': "..utils.dump(msg);
			log:info(errorMSG)
			return nil, errorMSG;
		end
	end

	if value ~= nil then
		local rv, msg = uci:set(UCI_CONFIG_NAME, section, key, toUciValue(value, base.type))
		if not rv and msg ~= nil then
			local errorMSG = "Issue setting setting '"..utils.dump(key).."' in section '"..utils.dump(section).."': "..utils.dump(msg);
			log:info(errorMSG)
			return nil, errorMSG;
		end
	else
		local rv, msg = uci:delete(UCI_CONFIG_NAME, section, key)
		if not rv and msg ~= nil then
			local errorMSG = "Issue deleting setting '"..utils.dump(key).."' in section '"..utils.dump(section).."': "..utils.dump(msg);
			log:info(errorMSG)
			return nil, errorMSG;
		end
	end

	if noCommit ~= true then uci:commit(UCI_CONFIG_NAME) end
	return true
end

--- Commit the UCI configuration, this can be used after making multiple changes
-- which have not been committed yet.
function M.commit()
	uci:commit(UCI_CONFIG_NAME)
end

--- Reset all settings to their default values
-- @string key The key to set.
-- @treturn bool|nil True if everything went well, nil in case of error.
function M.resetAll()
	log:info("settings:resetAll")

	-- find all sections
	local allSections, msg = uci:get_all(UCI_CONFIG_NAME)
	if not allSections and msg ~= nil then
		local errorMSG = "Issue reading all settings: "..utils.dump(msg);
		log:info(errorMSG)
		return nil, errorMSG;
	end
	
	-- delete all uci sections but system
	for key,value in pairs(allSections) do
		if key ~= "system" and not key:match('^[A-Z_]*$') then --TEMP: skip 'constants', which should be moved anyway
			local rv, msg = uci:delete(UCI_CONFIG_NAME,key)
			if not rv and msg ~= nil then
				local errorMSG = "Issue deleting setting '"..utils.dump(key).."': "..utils.dump(msg);
				log:info(errorMSG)
				return nil, errorMSG;
			end
		end
	end
	
	-- reset all to defaults
	for k,_ in pairs(baseconfig) do
		if not k:match('^[A-Z_]*$') then --TEMP: skip 'constants', which should be moved anyway
			M.reset(k,true)
		end
	end
	
	M.commit()
	return true
end

--- Reset setting to default value
-- @string key The key to reset.
-- @p[opt=nil] noCommit If true, do not commit the uci configuration; this is more efficient when resetting multiple values
-- @treturn bool|nil True if everything went well, nil in case of error.
function M.reset(key, noCommit)
	log:info("settings:reset: "..utils.dump(key))

	-- delete
	key = replaceDots(key)
	local base = getBaseKeyTable(key)
	if not base then return nil,ERR_NO_SUCH_KEY end
	local section = UCI_CONFIG_SECTION;
	if base.subSection ~= nil then
		section = M.get(base.subSection)
	end 
	local rv, msg = uci:delete(UCI_CONFIG_NAME, section, key)
	-- we can't respond to errors in general here because when a key isn't found 
	--   (which always happens when reset is used in resetall) it will also generate a error
	--if not rv and msg ~= nil then
	--	local errorMSG = "Issue deleting setting '"..utils.dump(key).."' in section '"..section.."': "..utils.dump(msg);
	--	log:info(errorMSG)
	--	return nil, errorMSG;
	--end

	-- reuse get logic to retrieve default and set it.
	M.set(key,M.get(key),true)

	if noCommit ~= true then uci:commit(UCI_CONFIG_NAME) end
	return true
end


--- Returns a UCI configuration key from the system section.
-- @string key The key for which to return the value, must be non-empty.
-- @return Requested value or false if it does not exist or nil on UCI error.
function M.getSystemKey(key)
	if type(key) ~= 'string' or key:len() == 0 then return nil end
	local v,msg = uci:get(UCI_CONFIG_NAME, UCI_CONFIG_SYSTEM_SECTION, key)
	if not v and msg ~= nil then
		local errorMSG = "Issue getting system setting '"..utils.dump(key).."' in section '"..UCI_CONFIG_SYSTEM_SECTION.."': "..utils.dump(msg);
		return nil, errorMSG;
	end

	return v or false
end

--- Sets the value of a UCI key in the system section.
-- Note that unlike the public settings, system keys are untyped and value must
-- be of type string; UCI generally uses '1' and '0' for boolean values.
-- @string key The key to set, must be non-empty.
-- @string value The value to set key to.
-- @return True on success or nil if key or value arguments are invalid.
function M.setSystemKey(key, value)
	if type(key) ~= 'string' or key:len() == 0 then return nil end
	if type(value) ~= 'string' then return nil end

	local r = utils.create(UCI_CONFIG_FILE) -- make sure the file exists for uci to write to
	uci:set(UCI_CONFIG_NAME, UCI_CONFIG_SYSTEM_SECTION, UCI_CONFIG_TYPE)
	uci:set(UCI_CONFIG_NAME, UCI_CONFIG_SYSTEM_SECTION, key, value)
	uci:commit(UCI_CONFIG_NAME)

	return true
end

return M
