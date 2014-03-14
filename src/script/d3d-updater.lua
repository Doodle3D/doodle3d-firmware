#!/usr/bin/env lua
--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


--- This script provides an interface to upgrade or downgrade the Doodle3D wifibox.
-- It can both be used as a standalone command-line tool and as a Lua library.

-- TODO/NOTES: (from old script)
-- add to status: validImage: none|<version> (can use checkValidImage for this)
-- any more TODO's across this file?
-- max 1 image tegelijk (moet api doen), en rekening houden met printbuffer (printen blokkeren?)

-- MAYBE/LATER: (from old script)
-- add API calls to retrieve a list of all versions with their info (i.e., the result of getAvailableVersions)
-- wget: add provision (in verbose mode?) to use '-v' instead of '-q' and disable output redirection
-- document index file format (Version first, then in any order: Files: sysup; factory, FileSize: sysup; factory, MD5: sysup; factory, ChangelogStart:, ..., ChangelogEnd:)
-- copy improved fileSize back to utils (add unit tests!)
-- create new utils usable by updater as well as api? (remove dependencies on uci and logger etc)
-- note: take care not to print any text in module functions, as this breaks http responses
-- change representation of sysupgrade/factory info in versionInfo? (and also in image index?) <- create api call to get all info on all versions?

local M = {}

--- Possible states the updater can be in, they are stored in @{STATE_FILE}.
-- @table STATE
M.STATE = {
	NONE = 1, -- @{STATE_FILE} does not exist
	DOWNLOADING = 2, -- downloading is started but not finished yet
	DOWNLOAD_FAILED = 3, -- download failed (often occurs when the wifibox is not connected to internet)
	IMAGE_READY = 4, -- download succeeded and the image is valid
	INSTALLING = 5, -- image is being installed (this state will probably never be returned since the box is flashing/rebooting)
	INSTALLED = 6, -- image has been installed successfully (this state will never be returned since the box will reboot)
	INSTALL_FAILED = 7 -- installation failed
}

-- Names for the states in @{STATE}, these are returned through the REST API.
M.STATE_NAMES = {
	[M.STATE.NONE] = 'none', [M.STATE.DOWNLOADING] = 'downloading', [M.STATE.DOWNLOAD_FAILED] = 'download_failed', [M.STATE.IMAGE_READY] = 'image_ready',
	[M.STATE.INSTALLING] = 'installing', [M.STATE.INSTALLED] = 'installed', [M.STATE.INSTALL_FAILED] = 'install_failed'
}

--- The default base URL to use for finding update files.
-- This URL will usually contain both an OpenWRT feed directory and an `images` directory.
-- This script uses only the latter, and expects to find the files @{IMAGE_STABLE_INDEX_FILE} and @{IMAGE_BETA_INDEX_FILE} there.
M.DEFAULT_BASE_URL = 'http://doodle3d.com/updates'

--- The index file containing metadata on stable update images.
M.IMAGE_STABLE_INDEX_FILE = 'wifibox-image.index'

--- The index file containing metadata on beta update images.
M.IMAGE_BETA_INDEX_FILE = 'wifibox-image.beta.index'

--- Path to the updater cache.
M.DEFAULT_CACHE_PATH = '/tmp/d3d-updater'

--- Name of the file to store current state in, this file resides in @{cachePath}.
M.STATE_FILE = 'update-state'

M.WGET_OPTIONS = "-q -t 1 -T 30"
--M.WGET_OPTIONS = "-v -t 1 -T 30"

local verbosity = 0 -- set by parseCommandlineArguments() or @{setVerbosity}
local log = nil -- wifibox API can use M.setLogger to enable this module to use its logger
local useCache = false -- default, can be overwritten using @{setUseCache}
local cachePath = M.DEFAULT_CACHE_PATH -- default, can be change using @{setCachePath}
local baseUrl = M.DEFAULT_BASE_URL -- default, can be overwritten by M.setBaseUrl()



---------------------
-- LOCAL FUNCTIONS --
---------------------

--- Log a message with the given level, if logging is enabled for that level.
-- Messages will be written to [stdout](http://www.cplusplus.com/reference/cstdio/stdout/), or logged using the logger set with @{setLogger}.
-- @number lvl Level to log to, use 1 for important messages, 0 for regular messages and -1 for less important messages.
-- @string msg The message to log.
local function P(lvl, msg)
	if log then
		if lvl == -1 then log:debug(msg)
		elseif lvl == 0 or lvl == 1 then log:info(msg)
		end
	else
		if (-lvl <= verbosity) then print(msg) end
	end
end

--- Log a debug message, this function wraps @{P}.
-- The message will be logged with level -1 and be prefixed with '(DBG)'.
-- @string msg The message to log.
local function D(msg) P(-1, (log and msg or "(DBG) " .. msg)) end

--- Log an error.
-- Messages will be written to [stderr](http://www.cplusplus.com/reference/cstdio/stderr/), or logged using the logger set with @{setLogger}.
-- @string msg The message to log.
local function E(msg)
	if log then log:error(msg)
	else io.stderr:write(msg .. '\n')
	end
end

--- Splits the return status from `os.execute` (only Lua <= 5.1), which consists of two bytes.
--
-- `os.execute` internally calls [system](http://linux.die.net/man/3/system),
-- which usually returns the command exit status as high byte (see [WEXITSTATUS](http://linux.die.net/man/2/wait)).
-- Furthermore, see [shifting bits in Lua](http://stackoverflow.com/questions/16158436/how-to-shift-and-mask-bits-from-integer-in-lua).
-- @number exitStatus The combined exit status.
-- @treturn number The command exit status.
-- @treturn number The `os.execute`/[system](http://linux.die.net/man/3/system) return status.
local function splitExitStatus(exitStatus)
	if exitStatus == -1 then return -1,-1 end
	local cmdStatus = math.floor(exitStatus / 256)
	local systemStatus = exitStatus - cmdStatus * 256
	return cmdStatus, systemStatus
end

--- Returns a human-readable message for a [wget exit status](http://www.gnu.org/software/wget/manual/wget.html#Exit-Status).
-- @number exitStatus An exit status from wget.
-- @treturn string|number Either the status followed by a description, or a message indicating the call was interrupted, or just the status if it was not recognized.
local function wgetStatusToString(exitStatus)
--	local wgetStatus,systemStatus = splitExitStatus(exitStatus)
	local wgetStatus = exitStatus

--	if systemStatus ~= 0 then
--		return "interrupted: " .. systemStatus
--	end

	-- adapted from man(1) wget on OSX
	local statusTexts = {
		['0'] = 'Ok',
		['1'] = 'Generic error',
		['2'] = 'Parse error', -- for instance, when parsing command-line options, the .wgetrc or .netrc...
		['3'] = 'File I/O error',
		['4'] = 'Network failure',
		['5'] = 'SSL verification failure',
		['6'] = 'Username/password authentication failure',
		['7'] = 'Protocol error',
		['8'] = 'Server issued an error response'
	}
	local result = statusTexts[tostring(wgetStatus)]

	if result then return exitStatus .. ": " .. result
	else return exitStatus
	end
end

--- Creates the updater cache directory.
-- @return bool|nil True, or nil on error.
-- @return ?string A message in case of error.
local function createCacheDirectory()
	local _,rv = M.compatexecute('mkdir -p ' .. cachePath)
	if rv ~= 0 then
		return nil,"Error: could not create cache directory '" .. cachePath .. "'"
	end
	return true
end

--- Retrieves the current updater state code and message from @{STATE_FILE}.
-- @treturn STATE The current state code (@{STATE}.NONE if no state has been set).
-- @treturn string The current state message (empty string if no state has been set).
local function getState()
	local file,msg = io.open(cachePath .. '/' .. M.STATE_FILE, 'r')
	if not file then return M.STATE.NONE,"" end

	local state = file:read('*a')
	file:close()
	local code,msg = string.match(state, '([^|]+)|+(.*)')
	return code,msg
end

--- Trims whitespace from both ends of a string.
-- See [this Lua snippet](http://snippets.luacode.org/?p=snippets/trim_whitespace_from_string_76).
-- @string s The text to trim.
-- @treturn string s, with whitespace trimmed.
local function trim(s)
	if type(s) ~= 'string' then return s end
	return (s:find('^%s*$') and '' or s:match('^%s*(.*%S)'))
end

--- Read the contents of a file.
--
-- TODO: this file has been copied from @{util.utils}.lua and should be merged back.
-- @string filePath The file to read.
-- @bool trimResult Whether or not to trim the read data.
-- @treturn bool|nil True, or nil on error.
-- @treturn ?string A descriptive message on error.
-- @treturn ?number TODO: find out why this value is returned.
local function readFile(filePath, trimResult)
	local f, msg, nr = io.open(filePath, 'r')
	if not f then return nil,msg,nr end

	local res = f:read('*all')
	f:close()

	if trimResult then
		res = trim(res)
	end

	return res
end

--- Reports whether or not a file exists.
--
-- TODO: this file has been copied from @{util.utils}.lua and should be merged back.
-- @string file The file to report about.
-- @treturn bool True if the file exists, false otherwise.
local function exists(file)
	if not file or type(file) ~= 'string' or file:len() == 0 then
		return nil, "file must be a non-empty string"
	end

	local r = io.open(file, 'r') -- ignore returned message
	if r then r:close() end
	return r ~= nil
end

--- Reports the size of a file or file handle.
--
-- TODO: this file has been copied from @{util.utils}.lua and should be merged back.
-- @param file A file path or open file handle.
-- @treturn number Size of the file.
local function fileSize(file)
	local size = nil
	if type(file) == 'file' then
		local current = file:seek()
		size = file:seek('end')
		file:seek('set', current)
	elseif type(file) == 'string' then
		local f = io.open(file)
		if f then
			size = f:seek('end')
			f:close()
		end
	end

	return size
end

--- Runs an arbitrary shell command.
-- @string command The command to run.
-- @bool dryRun Only log a message if true, otherwise run the command and log a message.
-- @treturn number Exit status of of command or -1 if dryRun is true.
local function runCommand(command, dryRun)
	--D("about to run: '" .. command .. "'")
	if dryRun then return -1 end
	return M.compatexecute(command)
end

--- Removes a file.
-- @string filePath The file to remove.
local function removeFile(filePath)
	return runCommand('rm ' .. filePath)
end

--- Downloads a file and stores it locally.
-- @string url The full URL to download.
-- @string saveDir The path at which to save the downloaded file.
-- @string[opt] filename File name to save as, note that leaving this out has issues with files not being overwritten but suffixed with '.1', '.2',etc instead.
-- @treturn number|nil Exit status of wget command or nil on error.
-- @treturn ?string Descriptive message if saveDir is nil or empty.
local function downloadFile(url, saveDir, filename)
	if not saveDir or saveDir:len() == 0 then return nil, "saveDir must be non-empty" end
	local outArg = (filename:len() > 0) and (' -O' .. filename) or ''
	D("Downloading file '" .. url .. "'")
	if filename:len() > 0 then
		return runCommand('wget ' .. M.WGET_OPTIONS .. ' -O ' .. saveDir .. '/' .. filename .. ' ' .. url .. ' 2> /dev/null')
	else
		return runCommand('wget ' .. M.WGET_OPTIONS .. ' -P ' .. saveDir .. ' ' .. url .. ' 2> /dev/null')
	end
end

--- Parses command-line arguments and returns a table containing information distilled from them.
-- @tparam table arglist A table in the same form as the [arg table](http://www.lua.org/pil/1.4.html) created by Lua.
-- @tparam table defaults A table with defaults settings (actually the basis for the returned table)
-- @treturn table|nil A table containing information on what to do, or nil if invalid arguments were specified.
-- @treturn ?string Descriptive message on error.
local function parseCommandlineArguments(arglist, defaults)
	local nextIsVersion, nextIsUrl = false, false
	for index,argument in ipairs(arglist) do
		if nextIsVersion then
			defaults.version = argument; nextIsVersion = false
		elseif nextIsUrl then
			defaults.baseUrl = argument; nextIsUrl = false
		else
			if argument == '-h' then defaults.action = 'showHelp'
			elseif argument == '-q' then defaults.verbosity = -1
			elseif argument == '-V' then defaults.verbosity = 1
			elseif argument == '-c' then defaults.useCache = true
			elseif argument == '-C' then defaults.useCache = false
			elseif argument == '-u' then nextIsUrl = true
			elseif argument == '-b' then defaults.includeBetas = true
			elseif argument == '-v' then defaults.action = 'showCurrentVersion'
			elseif argument == '-s' then defaults.action = 'showStatus'
			elseif argument == '-l' then defaults.action = 'showAvailableVersions'
			elseif argument == '-i' then defaults.action = 'showVersionInfo'; nextIsVersion = true
			elseif argument == '-d' then defaults.action = 'imageDownload'; nextIsVersion = true
			elseif argument == '-f' then defaults.action = 'imageInstall'; nextIsVersion = true
			elseif argument == '-r' then defaults.action = 'clear'
			else return nil,"unrecognized argument '" .. argument .. "'"
			end
		end
	end

	if defaults.version then
		defaults.version = M.parseVersion(defaults.version)
		if not defaults.version then
			return nil,"error parsing specified version"
		end
	end

	if nextIsVersion then return nil, "missing required version argument" end
	if nextIsUrl then return nil, "missing required URL argument" end

	return defaults
end

--- Determines if the system is OpenWrt or not by checking if `/etc/openwrt_release` exists.
-- @treturn bool True if the OS is OpenWrt.
local function isOpenWrt()
	local flag = nil
	return function()
		if flag == nil then
			local relFile = io.open('/etc/openwrt_release', 'r')
			flag = not not relFile
			if relFile then relFile:close() end
			return flag
		else
			return flag
		end
	end
end

--- Returns the [MD5](http://en.wikipedia.org/wiki/MD5) hash for a given file.
--
-- NOTE: this function is not implemented, and a better hash function should probably be chosen anyway.
-- @string filepath The path of which to calculate the MD5-sum.
-- @treturn nil
local function md5sum(filepath)
	local sfile

	if not isOpenWrt() then
		sfile = io.popen('md5 -q "' .. filepath .. '"')
	else
		sfile = io.popen('md5sum "' .. filepath .. '" 2>/dev/null', 'r')
	end

	local sum = sfile:read('*all')
	sfile:close()

	if not sum then return nil,"could not obtain MD5 sum" end

	sum = sum:match('[%da-fA-F]+')

	return sum
end



----------------------
-- MODULE FUNCTIONS --
----------------------

local compatlua51 = _VERSION == 'Lua 5.1'

--- execute a shell command. Taken from penlight library.
-- This is a compatibility function that returns the same for Lua 5.1 and Lua 5.2
-- @param cmd a shell command
-- @return true if successful
-- @return actual return code
function M.compatexecute(cmd)
	local res1,res2,res3 = os.execute(cmd)
	if compatlua51 then
		local cmd, sys = splitExitStatus(res1)
		return (res1 == 0) and true,cmd or nil,cmd
	else
		return res1, res3
	end
end

--- Set verbosity (log level) that determines which messages do get logged and which do not.
-- @tparam number level The level to set, between -1 and 1.
function M.setVerbosity(level)
	if level and level >= -1 and level <= 1 then
		verbosity = level
	end
end

--- Enables use of the given @{util.logger} object, otherwise `stdout`/`stderr` will be used.
-- @tparam util.logger logger The logger to log future messages to.
function M.setLogger(logger)
	log = logger
end

--- Controls whether or not to use pre-existing files over (re-)downloading them.
--
-- Note that the mechanism is currently naive, (e.g., there are no mechanisms like maximum cache age).
-- @bool use If true, try not to download anything unless necessary.
function M.setUseCache(use)
	useCache = use
end

--- Sets the base URL to use for finding update images, defaults to @{DEFAULT_BASE_URL}.
-- @string url The new base URL to use.
function M.setBaseUrl(url)
	baseUrl = url
end

--- Sets the filesystem path to use as cache for downloaded index and image files.
-- @string path The path to use, use nil to restore default @{DEFAULT_CACHE_PATH}.
function M.setCachePath(path)
	cachePath = path or M.DEFAULT_CACHE_PATH
end

--- Returns a table with information about current update status of the wifibox.
--
-- The result table will contain at least the current version, current state code and text.
-- If the box has internet access, it will also include the newest version available.
-- If an image is currently being downloaded, progress information will also be included.
--
-- @tparam bool[opt] withBetas Consider beta releases when looking for newest version.
-- @treturn bool True if status has been determined fully, false if not.
-- @treturn table The result table.
-- @treturn ?string Descriptive message in case the result table is not complete.
function M.getStatus(withBetas)
	if not baseUrl then baseUrl = M.DEFAULT_BASE_URL end
	local unknownVersion = { major = 0, minor = 0, patch = 0 }
	local result = {}

	result.currentVersion = M.getCurrentVersion()
	result.stateCode, result.stateText = getState()
	result.stateCode = tonumber(result.stateCode)

	local verTable,msg = M.getAvailableVersions(withBetas and 'both' or 'stables')
	if not verTable then
		D("error: could not obtain available versions (" .. msg .. ")")
		return false, result, msg
	end

	-- NOTE: to look up the current version we need a table containing all versions
	local allVersionsTable,msg
	if not withBetas then
		allVersionsTable,msg = M.getAvailableVersions('both')
		if not allVersionsTable then
			D("error: could not obtain available versions including betas (" .. msg .. ")")
			return false, result, msg
		end
	else
		allVersionsTable = verTable
	end


	local newest = verTable and verTable[#verTable]
	result.newestVersion = newest and newest.version or unknownVersion
	result.newestReleaseTimestamp = newest and newest.timestamp

	-- look up timestamp of current version
	local cEnt = M.findVersion(result.currentVersion, nil, allVersionsTable)
	if cEnt then
		result.currentReleaseTimestamp = cEnt.timestamp
	else
		D("warning: could not find current wifibox version in release indexes")
	end

	if result.stateCode == M.STATE.DOWNLOADING then
		result.progress = fileSize(cachePath .. '/' .. newest.sysupgradeFilename)
		if not result.progress then result.progress = 0 end -- in case the file does not exist yet (which yields nil)
		result.imageSize = newest.sysupgradeFileSize
	end

	return true, result
end

--- Turns a plain-text version as returned by @{formatVersion} into a table.
-- @tparam string|table versionText The version string to parse, if it is already a table, it is returned as-is.
-- @treturn table A parsed version or nil on incorrect argument.
function M.parseVersion(versionText)
	if not versionText then return nil end
	if type(versionText) == 'table' then return versionText end
	if not versionText or versionText:len() == 0 then return nil end

	local major,minor,patch,suffix = versionText:match("^%s*(%d+)%.(%d+)%.(%d+)(-?%w*)%s*$")
	if not major or not minor or not patch then return nil end -- suffix not required

	if type(suffix) == 'string' and suffix:len() > 0 then
		if suffix:sub(1, 1) ~= '-' then return nil end
		suffix = suffix:sub(2)
	else
		suffix = nil
	end

	return { ['major'] = major, ['minor'] = minor, ['patch'] = patch, ['suffix'] = suffix }
end

--- Formats a version as returned by @{parseVersion}.
-- @tparam table|string version The version to format, if it is already a string, that will be returned unmodified.
-- @treturn string A formatted version or nil on incorrect argument.
function M.formatVersion(version)
	if not version then return nil end
	if type(version) == 'string' then return version end

	local ver = version.major .. "." .. version.minor .. "." .. version.patch
	if version.suffix then ver = ver .. '-' .. version.suffix end

	return ver
end

--- Compares two versions. Note that the second return value must be used for equality testing.
-- If given, the timestamps have higher priority than the versions. Suffixes are ignored.
-- @tparam table versionA A version as returned by @{parseVersion}.
-- @tparam table versionB A version as returned by @{parseVersion}.
-- @param timestampA[opt] A timestamp as returned by @{parseDate}.
-- @param timestampB[opt] A timestamp as returned by @{parseDate}.
-- @treturn number -1 if versionA/timestampA is smaller/older than versionB/timestampB, 0 if versions are equal (or undecided) or 1 if A is larger/newer than B.
-- @treturn bool True if versions are really equal (first return value can be 0 if everything but the suffix is equal)
function M.compareVersions(versionA, versionB, timestampA, timestampB)
	if type(versionA) ~= 'table' or type(versionB) ~= 'table' then return nil end

	local diff = 0
	if timestampA and timestampB then diff = timestampA - timestampB end
	if diff == 0 then
		diff = versionA.major - versionB.major
		if diff == 0 then diff = versionA.minor - versionB.minor end
		if diff == 0 then diff = versionA.patch - versionB.patch end
	end

	local result = diff > 0 and 1 or (diff < 0 and -1 or 0)
	local reallyEqual = (diff == 0) and (versionA.suffix == versionB.suffix)

	return result, (reallyEqual and true or false)
end

--- Checks if versions are exactly equal.
-- It returns the second return value of @{compareVersions} and accepts the same arguments.
-- @treturn bool True if versions are equal, false otherwise.
function M.versionsEqual(versionA, versionB, timestampA, timestampB)
	return select(2, M.compareVersions(versionA, versionB, timestampA, timestampB))
end

--- Returns information on a version if it can be found in a collection of versions as returned by @{getAvailableVersions}.
-- @tparam table version The version to look for.
-- @tparam bool[opt] withBetas If verTable is not given, download versions including beta releases
-- @tparam table[opt] verTable A table containing a collection of versions, if not passed in, it will be obtained using @{getAvailableVersions}.
-- @param timestamp[opt] Specific timestamp to look for.
-- @treturn table|nil Version information table found in the collection, or nil on error or if not found.
-- @treturn string Descriptive message in case of error or if the version could not be found.
function M.findVersion(version, withBetas, verTable, timestamp)
	local msg = nil
	version = M.parseVersion(version)
	if not verTable then verTable,msg = M.getAvailableVersions(withBetas and 'both' or 'stables') end

	if not verTable then return nil,msg end

	for _,ent in pairs(verTable) do
		if M.versionsEqual(ent.version, version, ent.timestamp, timestamp) == true then return ent end
	end
	return nil,"no such version"
end

--- Turns a date of the format 'yyyymmdd' into a timestamp as returned by os.time.
-- @tparam string dateText The date to parse.
-- @return A timestamp or nil if the argument does not have correct format.
function M.parseDate(dateText)
	if type(dateText) ~= 'string' or dateText:len() ~= 8 or dateText:find('[^%d]') ~= nil then return nil end

	return os.time({ year = dateText:sub(1, 4), month = dateText:sub(5, 6), day = dateText:sub(7,8) })
end

--- Formats a timestamp as returned by os.time to a date of the form 'yyyymmdd'.
-- @param timestamp The timestamp to format.
-- @return A formatted date or nil if the argument is nil.
function M.formatDate(timestamp)
	if not timestamp then return nil end
	return os.date('%Y%m%d', timestamp)
end

--- Creates an image file name based on given properties.
-- The generated name has the following form: `doodle3d-wifibox-<version>-<deviceType>-<'factory'|'sysupgrade'>.bin`.
-- @tparam table|string version The version of the image.
-- @string[opt] devType Openwrt device identifier (defaults to 'tl-mr3020').
-- @bool[opt] isFactory Switches between factory or sysupgrade image name.
-- @treturn string The constructed file name.
function M.constructImageFilename(version, devType, isFactory)
	local sf = isFactory and 'factory' or 'sysupgrade'
	local v = M.formatVersion(version)
	local dt = devType and devType or 'tl-mr3020'
	return 'doodle3d-wifibox-' .. M.formatVersion(v) .. '-' .. dt .. '-' .. sf .. '.bin'
end

--- Checks whether a valid image file is present in @{cachePath} for the given image properties.
-- The versionEntry table will be augmented with an `isValid` key.
--
-- NOTE: currently, this function only checks the image exists and has the correct size.
-- Sysupgrade will perform integrity checks, so this is not a major issue.
--
-- @tparam table versionEntry A version information table.
-- @string[opt] devType Image device type, see @{constructImageFilename}.
-- @bool[opt] isFactory Image type, see @{constructImageFilename}.
-- @treturn bool True if a valid image is present, false otherwise.
-- @treturn string|nil Reason for being invalid if first return value is false.
function M.checkValidImage(versionEntry, devType, isFactory)
	local filename = M.constructImageFilename(versionEntry.version, devType, isFactory)

	local entSize = isFactory and versionEntry.factoryFileSize or versionEntry.sysupgradeFileSize
	local entMd5 = isFactory and versionEntry.factoryMd5 or versionEntry.sysupgradeMD5

	versionEntry.isValid = entMd5 == md5sum(cachePath .. '/' .. filename)
	if not versionEntry.isValid then return false,"incorrect MD5 checksum" end

	versionEntry.isValid = entSize == fileSize(cachePath .. '/' .. filename)
	if not versionEntry.isValid then return false,"incorrect file size" end

	return true
end

--- Returns the current wifibox version text, extracted from `/etc/wifibox-version`.
-- @treturn string Current version as plain-text.
function M.getCurrentVersionText()
	local res,msg,nr = readFile('/etc/wifibox-version', true)
	if res then return res else return nil,msg,nr end
end

--- Returns the current wifibox version as a table with major, minor and patch as keys.
-- @treturn table Current version as version table.
function M.getCurrentVersion()
	local vt,msg = M.getCurrentVersionText()
	return vt and M.parseVersion(vt) or nil,msg
end

--- Returns an indexed and sorted table containing version information tables.
-- The information is obtained from the either cached or downloaded image index file.
local function fetchIndexTable(indexFile, cachePath)
	if not baseUrl then baseUrl = M.DEFAULT_BASE_URL end
	local indexFilename = cachePath .. '/' .. indexFile

	if not useCache or not exists(indexFilename) then
		local rv1,rv2 = downloadFile(baseUrl .. '/images/' .. indexFile, cachePath, indexFile)
		if not rv1 then return nil,"could not download image index file (" .. wgetStatusToString(rv2) .. ")" end
	end

	local status,idxLines = pcall(io.lines, indexFilename)

	if not status then return nil,"could not open image index file '" .. indexFilename .. "'" end --do not include io.lines error message

	local result,entry = {}, nil
	local lineno,changelogMode = 1, false
	for line in idxLines do
		local k,v = line:match('^(.-):(.*)$')
		k,v = trim(k), trim(v)
		--if not log then D("#" .. lineno .. ": considering '" .. line .. "' (" .. (k or '<nil>') .. " / " .. (v or '<nil>') .. ")") end
		if not changelogMode and (not k or not v) then return nil,"incorrectly formatted line in index file (line " .. lineno .. ")" end

		if k == 'ChangelogEnd' then
			changelogMode = false
		elseif changelogMode then
			entry.changelog = entry.changelog .. line .. '\n'
		else
			if k == 'Version' then
				if entry ~= nil then table.insert(result, entry) end

				local pv = M.parseVersion(v)
				if not pv then return nil,"incorrect version text in index file (line " .. lineno .. ")" end
				entry = { version = pv }
			elseif k == 'ChangelogStart' then
				changelogMode = true
				entry.changelog = ""
			elseif k == 'Files' then
				local sName,fName = v:match('^(.-);(.*)$')
				sName,fName = trim(sName), trim(fName)
				if sName then entry.sysupgradeFilename = sName end
				if fName then entry.factoryFilename = fName end
			elseif k == 'FileSize' then
				local sSize,fSize = v:match('^(.-);(.*)$')
				sSize,fSize = trim(sSize), trim(fSize)
				if sSize then entry.sysupgradeFileSize = tonumber(sSize) end
				if fSize then entry.factoryFileSize = tonumber(fSize) end
			elseif k == 'MD5' then
				local sSum,fSum = v:match('^(.-);(.*)$')
				sSum,fSum = trim(sSum), trim(fSum)
				if sSum then entry.sysupgradeMD5 = sSum end
				if fSum then entry.factoryMD5 = fSum end
			elseif k == 'ReleaseDate' then
				local ts = M.parseDate(v)
				if not ts then
					P(0, "ignoring incorrectly formatted ReleaseDate field (line " .. lineno .. ")")
				else
					entry.timestamp = ts
				end
			else
				P(-1, "ignoring unrecognized field in index file '" .. k .. "' (line " .. lineno .. ")")
			end
		end
		lineno = lineno + 1
	end

	if entry ~= nil then table.insert(result, entry) end

	table.sort(result, function(a,b)
		return M.compareVersions(a.version,b.version) < 0
	end)

	return result
end

--- Returns an indexed and sorted table containing version information tables.
-- The information is obtained from the either cached or downloaded image index (@{IMAGE_STABLE_INDEX_FILE}).
-- @tparam which[opt] Which type of versions to fetch, either 'stables' (default), 'betas' or both.
-- @treturn table A table with a collection of version information tables.
function M.getAvailableVersions(which)
	local ccRv,ccMsg = createCacheDirectory()
	if not ccRv then return nil,ccMsg end

	local verTable, msg = {}, nil

	if which == 'stables' or which == 'both' then
		verTable,msg = fetchIndexTable(M.IMAGE_STABLE_INDEX_FILE, cachePath)
		if not verTable then return nil,msg end
	end

	if which == 'betas' or which == 'both' then
		local betas,msg = fetchIndexTable(M.IMAGE_BETA_INDEX_FILE, cachePath)
		if not betas then return nil,msg end

		for k,v in pairs(betas) do verTable[k] = v end
	end

	table.sort(verTable, function(a, b)
		return M.compareVersions(a.version, b.version, a.timestamp, b.timestamp) < 0
	end)


	return verTable
end

--- Attempts to download an image file with the requested properties.
-- @tparam table versionEntry A version information table.
-- @string[opt] devType Image device type, see @{constructImageFilename}.
-- @bool[opt] isFactory Image type, see @{constructImageFilename}.
-- @treturn bool|nil True if successful, or nil on error.
-- @treturn ?string|number (optional) Descriptive message on general error, or wget exit status.
function M.downloadImageFile(versionEntry, devType, isFactory)
	if not baseUrl then baseUrl = M.DEFAULT_BASE_URL end
	local filename = M.constructImageFilename(versionEntry.version, devType, isFactory)
	local doDownload = not useCache

	local ccRv,ccMsg = createCacheDirectory()
	if not ccRv then return nil,ccMsg end

	if versionEntry.isValid == false then
		doDownload = true
	elseif versionEntry.isValid == nil then
		M.checkValidImage(versionEntry, devType, isFactory)
		if versionEntry.isValid == false then doDownload = true end
	end

	local rv1,rv2 = 0,0
	if doDownload then
		M.setState(M.STATE.DOWNLOADING, "Downloading image (" .. filename .. ")")
		rv1,rv2 = downloadFile(baseUrl .. '/images/' .. filename, cachePath, filename)
	end

	if rv1 then
		local valid,msg = M.checkValidImage(versionEntry, devType, isFactory)
		if valid then
			M.setState(M.STATE.IMAGE_READY, "Image downloaded, ready to install (image name: " .. filename .. ")")
			return true
		else
			removeFile(cachePath .. '/' .. filename)
			local ws = "Image download failed (invalid image: " .. msg .. ")"
			M.setState(M.STATE.DOWNLOAD_FAILED, ws)
			return nil,ws
		end
	else
		local ws = wgetStatusToString(rv2)
		removeFile(cachePath .. '/' .. filename)
		M.setState(M.STATE.DOWNLOAD_FAILED, "Image download failed (wget error: " .. ws .. ")")
		return nil,ws
	end
end

--- Issues a [sysupgrade](http://wiki.openwrt.org/doc/howto/generic.sysupgrade) command with a wifibox image file.
--
-- This function will not return if it does its job successfully, the device will flash and reboot instead.
-- @tparam table versionEntry A version information table.
-- @bool[opt] noRetain If true, do not keep files in overlay filesystem (i.e., the '-n' switch in sysupgrade).
-- @string[opt] devType Image device type, see @{constructImageFilename}.
-- @bool[opt] isFactory Image type, see @{constructImageFilename}.
-- @treturn bool|nil True on success (with the 'exception' as noted above) or nil on error.
-- @treturn ?string|number (optional) Descriptive message or sysupgrade exit status on error.
function M.flashImageVersion(versionEntry, noRetain, devType, isFactory)
	if log then log:info("flashImageVersion") end
	local imgName = M.constructImageFilename(versionEntry.version, devType, isFactory)
	local cmd = noRetain and 'sysupgrade -n ' or 'sysupgrade '
	cmd = cmd .. cachePath .. '/' .. imgName

	local ccRv,ccMsg = createCacheDirectory()
	if not ccRv then return nil,ccMsg end

	if not M.checkValidImage(versionEntry) then
		return nil,"no valid image for requested version present"
	end

	M.setState(M.STATE.INSTALLING, "Installing new image (" .. imgName .. ")") -- yes this is rather pointless
	local rv = runCommand(cmd) -- if everything goes to plan, this will not return

	if rv == 0 then
		M.setState(M.STATE.INSTALLED, "Image installed")
	else
		-- NOTE: if cmdrv == 127, this means the command was not found
		local cmdrv,sysrv = splitExitStatus(rv)
		M.setState(M.STATE.INSTALL_FAILED, "Image installation failed (sysupgrade returned " .. cmdrv .. ", execution status: " .. sysrv .. ")")
	end

	return (rv == 0) and true or nil,rv
end

--- Clears '*.bin' and both index files in the @{cachePath} directory.
-- @treturn bool|nil True on success, or nil on error.
-- @treturn ?string Descriptive message on error.
function M.clear()
	local ccRv,ccMsg = createCacheDirectory()
	if not ccRv then return nil,ccMsg end

	D("Removing " .. cachePath .. "/doodle3d-wifibox-*.bin")
	M.setState(M.STATE.NONE, "")
	local success = true
	local rv = M.compatexecute('rm -f ' .. cachePath .. '/doodle3d-wifibox-*.bin')
	success = success and (rv == 0)
	local rv = M.compatexecute('rm -f ' .. cachePath .. '/' .. M.IMAGE_STABLE_INDEX_FILE)
	success = success and (rv == 0)
	local rv = M.compatexecute('rm -f ' .. cachePath .. '/' .. M.IMAGE_BETA_INDEX_FILE)
	success = success and (rv == 0)

	--return success,"could not delete all files"
	return true
end

--- Set updater state.
--
-- NOTE: make sure the cache directory  @{cachePath} exists before calling this function or it will fail.
--
-- NOTE: this function _can_ fail but this is not expected to happen so the return value is mostly ignored for now.
--
-- @number code The @{STATE} code to set.
-- @string msg The accompanying state message to set.
-- @treturn bool True on success or false if the state file could not be opened for writing.
function M.setState(code, msg)
	local s = code .. '|' .. msg
	D("set update state: " .. M.STATE_NAMES[code] .. " ('" .. s .. "')")
	local file,msg = io.open(cachePath .. '/' .. M.STATE_FILE, 'w')

	if not file then
		E("error: could not open state file for writing (" .. msg .. ")")
		return false
	end

	file:write(s)
	file:close()
	return true
end



----------
-- MAIN --
----------

--- The main function which will be called in standalone mode.
-- At the end of the file, this function will be invoked only if `arg` is defined,
-- so this file can also be used as a library.
-- Command-line arguments are expected to be present in the global `arg` variable.
local function main()
	-- NOTE: this require must be local to functions which are only executed on the wifibox (i.e., where we have uci)
	package.path = package.path .. ';/usr/share/lua/wifibox/?.lua'
	local settings = require('util.settings')

	local defaults = { verbosity = 0, baseUrl = M.DEFAULT_BASE_URL, includeBetas = false, action = nil }
	local confBaseUrl = settings.get('doodle3d.update.baseUrl')
	if confBaseUrl and confBaseUrl:len() > 0 then defaults.baseUrl = confBaseUrl end

	local argTable,msg = parseCommandlineArguments(arg, defaults)

	if not argTable then
		E("error interpreting command-line arguments, try '-h' for help (".. msg ..")")
		os.exit(1)
	end

	verbosity = argTable.verbosity
	includeBetas = argTable.includeBetas
	if argTable.useCache ~= nil then useCache = argTable.useCache end
	if argTable.baseUrl ~= nil then baseUrl = argTable.baseUrl end

	P(0, "Doodle3D Wifibox firmware updater")
	local cacheCreated,msg = createCacheDirectory()
	if not cacheCreated then
		E(msg)
		os.exit(1)
	end

	P(0, (includeBetas and "Considering" or "Not considering") .. " beta releases.")

	if argTable.action == 'showHelp' then
		P(1, "\t-h\t\tShow this help message")
		P(1, "\t-q\t\tquiet mode")
		P(1, "\t-V\t\tverbose mode")
		P(1, "\t-c\t\tUse cache as much as possible")
		P(1, "\t-C\t\tDo not use the cache (default)")
		P(1, "\t-u <base_url>\tUse specified base URL (default: " .. M.DEFAULT_BASE_URL .. ")")
		P(1, "\t-b\t\tInclude beta releases")
		P(1, "\t-v\t\tShow current image version")
		P(1, "\t-s\t\tShow current update status")
		P(1, "\t-l\t\tShow list of available image versions (and which one has been downloaded, if any)")
		P(1, "\t-i <version>\tShow information (changelog) about the requested image version")
		P(1, "\t-d <version>\tDownload requested image version")
		P(1, "\t-f <version>\tFlash to requested image version (by means of sysupgrade)")
		P(1, "\t-r\t\tClear downloaded images and reset state")
		os.exit(10)

	elseif argTable.action == 'showCurrentVersion' then
		local vText,msg,nr = M.getCurrentVersionText()
		if not vText then E("error reading firmware version (" .. nr .. ": " .. msg .. ")"); os.exit(1) end
		local v = M.parseVersion(vText)
		if not v then E("error parsing version '" .. vText .. "'"); os.exit(2) end
		P(1, "version: " .. M.formatVersion(v))

	elseif argTable.action == 'showStatus' then
		local success,status,msg = M.getStatus(includeBetas)
		P(0, "Current update status:")
		P(1, "  currentVersion:\t" .. (M.formatVersion(status.currentVersion) or '?'))
		P(1, "  newestVersion:\t" .. (M.formatVersion(status.newestVersion) or '?'))

		if status.stateText and status.stateText:len() > 0 then
			P(1, "  state:\t\t" .. M.STATE_NAMES[status.stateCode] .. " (" .. status.stateText .. ")")
		else
			P(1, "  state:\t\t" .. M.STATE_NAMES[status.stateCode])
		end

		if status.stateCode == M.STATE.DOWNLOADING then
			local percent = (status.imageSize > 0) and (math.ceil(status.progress / status.imageSize * 1000) / 10) or 0
			P(1, "  download progress:\t" .. status.progress .. "/" .. status.imageSize .. " (" .. percent .. "%)")
		end

	elseif argTable.action == 'showAvailableVersions' then
		local verTable,msg = M.getAvailableVersions(includeBetas and 'both' or 'stables')
		if not verTable then
			E("error collecting version information (" .. msg .. ")")
			os.exit(2)
		end

		P(0, "Available versions:")
		for _,ent in ipairs(verTable) do P(1, M.formatVersion(ent.version)) end

	elseif argTable.action == 'showVersionInfo' then
		local vEnt,msg = M.findVersion(argTable.version, includeBetas)

		if vEnt then
			P(0, "Information on version:")
			P(1, "  version:\t\t" .. M.formatVersion(vEnt.version))
			P(1, "  sysupgradeFilename:\t" .. (vEnt.sysupgradeFilename or '-'))
			P(1, "  sysupgradeFileSize:\t" .. (vEnt.sysupgradeFileSize or '-'))
			P(1, "  sysupgradeMD5:\t" .. (vEnt.sysupgradeMD5 or '-'))
			P(1, "  factoryFilename:\t" .. (vEnt.factoryFilename or '-'))
			P(1, "  factoryFileSize:\t" .. (vEnt.factoryFileSize or '-'))
			P(1, "  factoryMD5:\t\t" .. (vEnt.factoryMD5 or '-'))
			P(1, "  releaseDate:\t\t" .. (vEnt.timestamp and M.formatDate(vEnt.timestamp) or '-'))
			if vEnt.changelog then
				P(1, "\n--- Changelog ---\n" .. vEnt.changelog .. '---')
			else
				P(1, "  changelog:\t\t-")
			end
		elseif vEnt == false then
			P(1, "no such version")
			os.exit(4)
		elseif vEnt == nil then
			E("error searching version index (" .. msg .. ")")
			os.exit(2)
		end

	elseif argTable.action == 'imageDownload' then
		local vEnt,msg = M.findVersion(argTable.version, includeBetas)
		if vEnt == false then
			P(1, "no such version")
			os.exit(4)
		elseif vEnt == nil then
			E("error searching version index (" .. msg .. ")")
			os.exit(2)
		end

		local rv,msg = M.downloadImageFile(vEnt)
		if not rv then E("could not download file (" .. msg .. ")")
		else P(1, "success")
		end

	elseif argTable.action == 'clear' then
		local rv,msg = M.clear()
		if not rv then P(1, "error (" .. msg .. ")")
		else P(1, "success")
		end

	elseif argTable.action == 'imageInstall' then
		local vEnt, msg = nil, nil
		vEnt,msg = M.findVersion(argTable.version, includeBetas)
		if vEnt == false then
			P(1, "no such version")
			os.exit(4)
		elseif vEnt == nil then
			E("error searching version index (" .. msg .. ")")
			os.exit(2)
		end

		local rv
		rv,msg = M.flashImageVersion(vEnt)
		E("error: failed to flash image to device (" .. msg .. ")")
		os.exit(3)

	else
		P(0, "usage: d3d-updater [-hqVcCvslr] [-u base_url] [-i version] [-d version] [-f version]")
	end

	os.exit(0)
end

--- Only execute the main function if an arg table is present, this enables usage both as module and as standalone script.
if arg ~= nil then main() end

return M
