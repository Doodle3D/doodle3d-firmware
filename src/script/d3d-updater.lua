#!/usr/bin/env lua

-- TODO/NOTES:
-- M.checkValidImage(verEnt) -> doet exists+fileSize/MD5 check
-- after download: (can use checkValidImage for this)
-- - remove file on fail
-- - check size or md5 and remove file on mismatch [osx: md5 -q <file>]
-- add to status: validImage: none|<version> (can use checkValidImage for this)
-- any more TODO's across this file?
-- max 1 image tegelijk (moet api doen), en rekening houden met printbuffer (printen blokkeren?)

-- MAYBE/LATER:
-- add API calls to retrieve a list of all versions with their info (i.e., the result of getAvailableVersions)
-- wget: add provision (in verbose mode?) to use -v instead of -q and disable output redirection
-- wget: configurable timeout?
-- max cache lifetime for index file?
-- document index file format (Version first, then in any order: Files: sysup; factory, FileSize: sysup; factory, MD5: sysup; factory, ChangelogStart:, ..., ChangelogEnd:)
-- remove /etc/wifibox-version on macbook...
-- copy improved fileSize back to utils (add unit tests!)
-- create new utils usable by updater as well as api? (remove dependencies on uci and logger etc)
-- note: take care not to print any text in module functions, as this breaks http responses
-- change representation of sysupgrade/factory info in versionInfo? (and also in image index?) <- create api call to get all info on all versions?

local M = {}

-- NOTE: 'INSTALLED' will never be returned (and probably neither will 'INSTALLING') since in that case the device is flashing or rebooting
M.STATE = { NONE = 1, DOWNLOADING = 2, DOWNLOAD_FAILED = 3, IMAGE_READY = 4, INSTALLING = 5, INSTALLED = 6, INSTALL_FAILED = 7 }
M.STATE_NAMES = {
	[M.STATE.NONE] = 'none', [M.STATE.DOWNLOADING] = 'downloading', [M.STATE.DOWNLOAD_FAILED] = 'download_failed', [M.STATE.IMAGE_READY] = 'image_ready',
	[M.STATE.INSTALLING] = 'installing', [M.STATE.INSTALLED] = 'installed', [M.STATE.INSTALL_FAILED] = 'install_failed'
}

M.DEFAULT_BASE_URL = 'http://doodle3d.com/updates'
--M.DEFAULT_BASE_URL = 'http://localhost/~USERNAME/wifibox/updates'
M.IMAGE_INDEX_FILE = 'wifibox-image.index'
M.CACHE_PATH = '/tmp/d3d-updater'
M.STATE_FILE = 'update-state'
M.WGET_OPTIONS = "-q -t 1 -T 30"
--M.WGET_OPTIONS = "-v -t 1 -T 30"

local verbosity = 0
local log = nil -- wifibox API can use M.setLogger to enable this module to use its logger




---------------------
-- LOCAL FUNCTIONS --
---------------------

-- use level==1 for important messages, 0 for regular messages and -1 for less important messages
local function P(lvl, msg)
	if log then
		if lvl == -1 then log:debug(msg)
		elseif lvl == 0 or lvl == 1 then log:info(msg)
		end
	else
		if (-lvl <= verbosity) then print(msg) end
	end
end

local function D(msg) P(-1, (log and msg or "(DBG) " .. msg)) end

local function E(msg)
	if log then log:error(msg)
	else io.stderr:write(msg .. '\n')
	end
end

-- dontShift is optional
-- Note: os.execute() return value is shifted one byte to the left, this function
-- takes that fact into account, unless dontShift is true.
local function wgetStatusToString(exitStatus, dontShift)
	if not dontShift then exitStatus = exitStatus / 256 end
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
	local result = statusTexts[tostring(exitStatus)]

	if result then return exitStatus .. ": " .. result
	else return exitStatus
	end
end

local function createCacheDirectory()
	if os.execute('mkdir -p ' .. M.CACHE_PATH) ~= 0 then
		return nil,"Error: could not create cache directory '" .. M.CACHE_PATH .. "'"
	end
	return true
end

local function getState()
	local file,msg = io.open(M.CACHE_PATH .. '/' .. M.STATE_FILE, 'r')
	if not file then return M.STATE.NONE,"" end

	local state = file:read('*a')
	file:close()
	local code,msg = string.match(state, '([^|]+)|+(.*)')
	return code,msg
end

-- NOTE: make sure the cache directory exists before calling this function or it will fail.
-- NOTE: this function _can_ fail but we don't expect this to happen so the return value is ignored for now
local function setState(code, msg)
	local s = code .. '|' .. msg
	D("set update state: " .. M.STATE_NAMES[code] .. " ('" .. s .. "')")
	local file,msg = io.open(M.CACHE_PATH .. '/' .. M.STATE_FILE, 'w')

	if not file then
		E("error: could not open state file for writing (" .. msg .. ")")
		return false
	end

	file:write(s)
	file:close()
	return true
end

-- trim whitespace from both ends of string (from http://snippets.luacode.org/?p=snippets/trim_whitespace_from_string_76)
local function trim(s)
	if type(s) ~= 'string' then return s end
	return (s:find('^%s*$') and '' or s:match('^%s*(.*%S)'))
end

-- from utils.lua
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

-- from utils.lua
local function exists(file)
	if not file or type(file) ~= 'string' or file:len() == 0 then
		return nil, "file must be a non-empty string"
	end

	local r = io.open(file, 'r') -- ignore returned message
	if r then r:close() end
	return r ~= nil
end

-- from utils.lua
--argument: either an open file or a filename
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


-- returns return value of command
local function runCommand(command, dryRun) D("about to run: '" .. command .. "'"); return (not dryRun) and os.execute(command) or 0 end

-- returns return value of wget (or nil if saveDir is nil or empty), filename is optional
-- NOTE: leaving out filename will cause issues with files not being overwritten but suffixed with '.1', '.2',etc instead
local function downloadFile(url, saveDir, filename)
	if not saveDir or saveDir:len() == 0 then return nil, "saveDir must be non-empty" end
	local outArg = (filename:len() > 0) and (' -O' .. filename) or ''
	if filename:len() > 0 then
		return runCommand('wget ' .. M.WGET_OPTIONS .. ' -O ' .. saveDir .. '/' .. filename .. ' ' .. url .. ' 2> /dev/null')
	else
		return runCommand('wget ' .. M.WGET_OPTIONS .. ' -P ' .. saveDir .. ' ' .. url .. ' 2> /dev/null')
	end
end

local function parseCommandlineArguments(arglist)
	local result = { verbosity = 0, baseUrl = M.DEFAULT_BASE_URL, action = nil }
	local nextIsVersion, nextIsUrl = false, false
	for index,argument in ipairs(arglist) do
		if nextIsVersion then
			result.version = argument; nextIsVersion = false
		elseif nextIsUrl then
			result.baseUrl = argument; nextIsUrl = false
		else
			if argument == '-h' then result.action = 'showHelp'
			elseif argument == '-q' then result.verbosity = -1
			elseif argument == '-V' then result.verbosity = 1
			elseif argument == '-c' then result.useCache = true
			elseif argument == '-C' then result.useCache = false
			elseif argument == '-u' then nextIsUrl = true
			elseif argument == '-v' then result.action = 'showCurrentVersion'
			elseif argument == '-s' then result.action = 'showStatus'
			elseif argument == '-l' then result.action = 'showAvailableVersions'
			elseif argument == '-i' then result.action = 'showVersionInfo'; nextIsVersion = true
			elseif argument == '-d' then result.action = 'imageDownload'; nextIsVersion = true
			elseif argument == '-f' then result.action = 'imageInstall'; nextIsVersion = true
			elseif argument == '-r' then result.action = 'clear'
			else return nil,"unrecognized argument '" .. argument .. "'"
			end
		end
	end

	if result.version then
		result.version = M.parseVersion(result.version)
		if not result.version then
			return nil,"error parsing specified version"
		end
	end

	if nextIsVersion then return nil, "missing required version argument" end
	if nextIsUrl then return nil, "missing required URL argument" end

	return result
end




----------------------
-- MODULE FUNCTIONS --
----------------------

function M.setLogger(logger)
	log = logger
end

-- baseUrl and useCache are optional
function M.getStatus(baseUrl, useCache)
	if not baseUrl then baseUrl = M.DEFAULT_BASE_URL end
	local result = {}

	local verTable,msg = M.getAvailableVersions(baseUrl, useCache)
	if not verTable then return nil,msg end

	local newest = verTable[#verTable]
	result.currentVersion = M.getCurrentVersion()
	result.newestVersion = newest.version
	result.stateCode, result.stateText = getState()
	result.stateCode = tonumber(result.stateCode)

	if result.stateCode == M.STATE.DOWNLOADING then
		result.progress = fileSize(M.CACHE_PATH .. '/' .. newest.sysupgradeFilename)
		if not result.progress then result.progress = 0 end -- in case the file does not exist yet (which yields nil)
		result.imageSize = newest.sysupgradeFileSize
	end

	return result
end

-- Turns a plain-text version into a table.
-- tables as argument are ignored so you can safely pass in an already parsed
-- version and expect it back unmodified.
function M.parseVersion(versionText)
	if type(versionText) == 'table' then return versionText end
	if not versionText or versionText:len() == 0 then return nil end

	local major,minor,patch = versionText:match("^%s*(%d+)%.(%d+)%.(%d+)%s*$")
	if not major or not minor or not patch then return nil end

	return { ['major'] = major, ['minor'] = minor, ['patch'] = patch }
end

-- Formats a version as returned by parseVersion().
-- Strings are returned unmodified, so an 'already formatted' version can be
-- passed in safely and expected back unmodified.
function M.formatVersion(version)
	if type(version) == 'string' then return version end
	return version.major .. "." .. version.minor .. "." .. version.patch
end

-- expects two tables as created by M.parseVersion()
function M.compareVersions(versionA, versionB)
	if type(versionA) ~= 'table' or type(versionB) ~= 'table' then return nil end
	local diff = versionA.major - versionB.major
	if diff == 0 then diff = versionA.minor - versionB.minor end
	if diff == 0 then diff = versionA.patch - versionB.patch end
	return diff > 0 and 1 or (diff < 0 and -1 or 0)
end

function M.findVersion(verTable, version)
	for _,ent in pairs(verTable) do
		if M.compareVersions(ent.version, version) == 0 then return ent end
	end
	return nil
end

-- version may be a table or a string, devtype and isFactory are optional
function M.constructImageFilename(version, devType, isFactory)
	local sf = isFactory and 'factory' or 'sysupgrade'
	local v = M.formatVersion(version)
	local dt = devType and devType or 'tl-mr3020'
	return 'doodle3d-wifibox-' .. M.formatVersion(v) .. '-' .. dt .. '-' .. sf .. '.bin'
end

-- returns a plain text version
function M.getCurrentVersionText()
	local res,msg,nr = readFile('/etc/wifibox-version', true)
	if res then return res else return nil,msg,nr end
end

-- returns a table with major, minor and patch as keys
function M.getCurrentVersion()
	local vt,msg = M.getCurrentVersionText()
	return vt and M.parseVersion(vt) or nil,msg
end

-- requires url of image index file; returns an indexed (and sorted) table containing version tables
-- baseUrl and useCache are optional
function M.getAvailableVersions(baseUrl, useCache)
	if not baseUrl then baseUrl = M.DEFAULT_BASE_URL end
	local indexFilename = M.CACHE_PATH .. '/' .. M.IMAGE_INDEX_FILE

	local ccRv,ccMsg = createCacheDirectory()
	if not ccRv then return nil,ccMsg end

	if not useCache or not exists(indexFilename) then
		local rv = downloadFile(baseUrl .. '/images/' .. M.IMAGE_INDEX_FILE, M.CACHE_PATH, M.IMAGE_INDEX_FILE)
		if rv ~= 0 then return nil,"could not download image index file (" .. wgetStatusToString(rv) .. ")" end
	end

	local status,idxLines = pcall(io.lines, indexFilename)

	if not status then return nil,"could not open image index file '" .. indexFilename .. "'" end --do not include io.lines error message

	local result,entry = {}, nil
	local lineno,changelogMode = 1, false
	for line in idxLines do
		local k,v = line:match('^(.-):(.*)$')
		k,v = trim(k), trim(v)
		if not log then D("#" .. lineno .. ": considering '" .. line .. "' (" .. (k or '<nil>') .. " / " .. (v or '<nil>') .. ")") end
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

-- forceDownload, devtype and isFactory are optional
-- returns true or nil+msg or nil + return value from wget
function M.downloadImageFile(baseUrl, version, forceDownload, devType, isFactory)
	if not baseUrl then baseUrl = M.DEFAULT_BASE_URL end
	local filename = M.constructImageFilename(version, devType, isFactory)
	local doDownload = (type(forceDownload) == 'boolean') and forceDownload or (not exists(M.CACHE_PATH .. '/' .. filename))

	local ccRv,ccMsg = createCacheDirectory()
	if not ccRv then return nil,ccMsg end

	--TODO: call M.checkValidImage, set doDownload to true if not valid

	local rv = 0
	if doDownload then
		setState(M.STATE.DOWNLOADING, "Downloading image (" .. filename .. ")")
		rv = downloadFile(baseUrl .. '/images/' .. filename, M.CACHE_PATH, filename)
	end

	if rv == 0 then
		--TODO: check if the downloaded file is complete and matches checksum
		setState(M.STATE.IMAGE_READY, "Image downloaded, ready to install (image name: " .. filename .. ")")
		return true
	else
		local ws = wgetStatusToString(rv)
		setState(M.STATE.DOWNLOAD_FAILED, "Image download failed (" .. ws .. ")")
		return nil,ws
	end
end

-- this function will not return
-- noRetain, devType and isFactory are optional
-- returns true or nil + wget return value
function M.flashImageVersion(version, noRetain, devType, isFactory)
	local imgName = M.constructImageFilename(version, devType, isFactory)
	local cmd = noRetain and 'sysupgrade -n ' or 'sysupgrade '
	cmd = cmd .. M.CACHE_PATH .. '/' .. imgName

	local ccRv,ccMsg = createCacheDirectory()
	if not ccRv then return nil,ccMsg end

	setState(M.STATE, "Installing new image (" .. imgName .. ")") -- yes this is rather pointless
	local rv = runCommand(cmd, true) -- if everything goes to plan, this will not return

	if rv == 0 then setState(M.STATE.INSTALLED, "Image installed")
	else setState(M.STATE.INSTALL_FAILED, "Image installation failed (sysupgrade returned " .. rv .. ")")
	end

	return (rv == 0) and true or nil,rv
end

--returns true on success, or nil+msg otherwise
function M.clear()
	local ccRv,ccMsg = createCacheDirectory()
	if not ccRv then return nil,ccMsg end

	D("Removing " .. M.CACHE_PATH .. "/doodle3d-wifibox-*.bin")
	setState(M.STATE.NONE, "")
	local rv = os.execute('rm -f ' .. M.CACHE_PATH .. '/doodle3d-wifibox-*.bin')
	return (rv == 0) and true or nil,"could not remove image files"
end





----------
-- MAIN --
----------

local function main()
	local useCache = true
	local argTable,msg = parseCommandlineArguments(arg)

	if not argTable then
		E("error interpreting command-line arguments, try '-h' for help (".. msg ..")")
		os.exit(1)
	end

	verbosity = argTable.verbosity
	if argTable.useCache ~= nil then useCache = argTable.useCache end

	P(0, "Doodle3D Wifibox firmware updater")
	local cacheCreated,msg = createCacheDirectory()
	if not cacheCreated then
		E(msg)
		os.exit(1)
	end

	if argTable.action == 'showHelp' then
		P(1, "\t-h\t\tShow this help message")
		P(1, "\t-q\t\tquiet mode")
		P(1, "\t-V\t\tverbose mode")
		P(1, "\t-c\t\tUse cache as much as possible")
		P(1, "\t-C\t\tDo not use the cache")
		P(1, "\t-u <base_url>\tUse specified base URL (default: " .. M.DEFAULT_BASE_URL .. ")")
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
		local status = M.getStatus(argTable.baseUrl, useCache)
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
		local verTable,msg = M.getAvailableVersions(argTable.baseUrl, useCache)
		if not verTable then
			E("error collecting version information (" .. msg .. ")")
			os.exit(2)
		end

		P(0, "Available versions:")
		for _,ent in ipairs(verTable) do P(1, M.formatVersion(ent.version)) end

	elseif argTable.action == 'showVersionInfo' then
		local verTable,msg = M.getAvailableVersions(argTable.baseUrl, useCache)
		if not verTable then
			E("error parsing image index file (" .. msg .. ")")
			os.exit(2)
		end

		local vEnt,msg = M.findVersion(verTable, argTable.version)

		if vEnt then
			P(0, "Information on version:")
			P(1, "  version:\t\t" .. M.formatVersion(vEnt.version))
			P(1, "  sysupgradeFilename:\t" .. (vEnt.sysupgradeFilename or '-'))
			P(1, "  sysupgradeFileSize:\t" .. (vEnt.sysupgradeFileSize or '-'))
			P(1, "  sysupgradeMD5:\t" .. (vEnt.sysupgradeMD5 or '-'))
			P(1, "  factoryFilename:\t" .. (vEnt.factoryFilename or '-'))
			P(1, "  factoryFileSize:\t" .. (vEnt.factoryFileSize or '-'))
			P(1, "  factoryMD5:\t\t" .. (vEnt.factoryMD5 or '-'))
			if vEnt.changelog then
				P(1, "\n--- Changelog ---\n" .. vEnt.changelog .. '---')
			else
				P(1, "  changelog:\t\t-")
			end
		else
			P(1, "not found")
		end

	elseif argTable.action == 'imageDownload' then
		--TODO: first check if version exists
		local rv,msg = M.downloadImageFile(argTable.baseUrl, argTable.version, not useCache) --TEMP
		if not rv then E("could not download file (" .. msg .. ")")
		else P(1, "success")
		end
	elseif argTable.action == 'clear' then
		local rv,msg = M.clear()
		if not rv then P(1, "error (" .. msg .. ")")
		else P(1, "success")
		end

	elseif argTable.action == 'imageInstall' then
		local rv = M.flashImageVersion(argTable.version)
		E("error: flash function returned, the device should have been flashed and rebooted instead")
		os.exit(3)

	else
		P(0, "usage: d3d-updater [-hqVcCvslr] [-u base_url] [-i version] [-d version] [-f version]")
	end

	os.exit(0)
end

-- only execute the main function if an arg table is present, this enables usage both as module and as standalone script
if arg ~= nil then main() end

return M
