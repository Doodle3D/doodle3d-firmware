#!/usr/bin/env lua

-- TODO/NOTES:
-- implement image removal
-- make sure downloaded files are overwritten, and never named with '.n' suffix
-- max 1 image tegelijk gedownload (zelfs dat is al link qua geheugengebruik? -> printen blokkeren vanaf download image?)

-- interpret wget return values more intelligently? or add function to run integrity check on index vs actually present files?
-- after downloading anything, check whether it really exists?
-- document index file format (Version first, then in any order: Files: sysup; factory, ChangelogStart:, ..., ChangelogEnd:)
-- can we also get rid of the .lua extension? (looks nicer on command-line)
-- remove /etc/wifibox-version on macbook...
-- perhaps create a function for each action and directly assign them in the arguments parser

local M = {}

M.DEFAULT_BASE_URL = 'http://doodle3d.com/updates'
--M.DEFAULT_BASE_URL = 'http://localhost/~wouter/wifibox/updates'
M.IMAGE_INDEX_FILE = 'wifibox-image.index'
M.CACHE_PATH = '/tmp/d3d-updater'
M.WGET_OPTIONS = "-q -t 1 -T 30"
--M.WGET_OPTIONS = "-v -t 1 -T 30"

M.verbosity = 0




---------------------
-- LOCAL FUNCTIONS --
---------------------

-- use level==1 for important messages, 0 for regular messages and -1 for less important messages
local function P(lvl, msg) if (-lvl <= M.verbosity) then print(msg) end end

local function E(msg) io.stderr:write(msg .. '\n') end

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
local function fileSize(file)
	local current = file:seek()
	local size = file:seek('end')
	file:seek('set', current)
	return size
end


-- returns return value of command
local function runCommand(command, dryRun) P(-1, "(DBG) about to run: '" .. command .. "'"); return (not dryRun) and os.execute(command) or 0 end

-- returns return value of wget (or nil if saveDir is nil or empty)
local function downloadFile(url, saveDir, filename)
	if not saveDir or saveDir:len() == 0 then return nil, "saveDir must be non-empty" end
	local outArg = (filename:len() > 0) and (' -O' .. filename) or ''
	if filename:len() > 0 then
		--return runCommand('wget ' .. M.WGET_OPTIONS .. ' -O ' .. saveDir .. '/' .. filename .. ' ' .. url .. ' 2> /dev/null')
		return runCommand('wget ' .. M.WGET_OPTIONS .. ' -O ' .. saveDir .. '/' .. filename .. ' ' .. url)
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
			elseif argument == '-m' then result.machineOutput = true
			elseif argument == '-v' then result.action = 'showCurrentVersion'
			elseif argument == '-l' then result.action = 'showAvailableVersions'
			elseif argument == '-i' then result.action = 'showVersionInfo'; nextIsVersion = true
			elseif argument == '-d' then result.action = 'imageDownload'; nextIsVersion = true
			elseif argument == '-r' then result.action = 'imageRemove'
			elseif argument == '-f' then result.action = 'imageInstall'; nextIsVersion = true
			else return nil,"Unrecognized argument '" .. argument .. "'"
			end
		end
	end

	if result.machineOutput then result.verbosity = -1 end

		if result.version then
		result.version = M.parseVersion(result.version)
		if not result.version then
			return nil,"error parsing specified version"
		end
	end

	if nextIsVersion then return nil, "Missing required version argument" end
	if nextIsUrl then return nil, "Missing required URL argument" end

	return result
end




----------------------
-- MODULE FUNCTIONS --
----------------------

function M.parseVersion(versionText)
	if not versionText or versionText:len() == 0 then return nil end
	local major,minor,patch = versionText:match("^%s*(%d+)%.(%d+)%.(%d+)%s*$")
	if not major or not minor or not patch then return nil end
	return { ['major'] = major, ['minor'] = minor, ['patch'] = patch }
end

function M.formatVersion(version) return version.major .. "." .. version.minor .. "." .. version.patch end

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
function M.constructImageFilename(ver, devType, isFactory)
	local sf = isFactory and 'factory' or 'sysupgrade'
	local v = (type(ver) == 'table') and ver or M.formatVersion(ver)
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
	local vt,msg = getCurrentVersionText()
	return vt and M.parseVersion(vt) or nil,msg
end

-- requires url of image index file; returns an indexed (and sorted) table containing version tables
function M.getAvailableVersions(baseUrl, useCache)
	local indexFilename = M.CACHE_PATH .. '/' .. M.IMAGE_INDEX_FILE

	if not useCache or not exists(indexFilename) then
		local rv = downloadFile(baseUrl .. '/images/' .. M.IMAGE_INDEX_FILE, M.CACHE_PATH, M.IMAGE_INDEX_FILE)
		if rv ~= 0 then return nil,"could not download image index file" end
	end

	local status,idxLines = pcall(io.lines, indexFilename)

	if not status then return nil,"could not open image index file '" .. indexFilename .. "'" end --do not include io.lines error message

	local result,entry = {}, nil
	local lineno,changelogMode = 1, false
	for line in idxLines do
		local k,v = line:match('^(.-):(.*)$')
		k,v = trim(k), trim(v)
		--P(1, "#" .. lineno .. ": considering '" .. line .. "' (" .. (k or '<nil>') .. " / " .. (v or '<nil>') .. ")") -- debug
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
				if sSize then entry.sysupgradeFileSize = sSize end
				if fSize then entry.factoryFileSize = fSize end
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

	--sort table
	table.sort(result, function(a,b)
		return M.compareVersions(a.version,b.version) < 0
	end)

	return result
end

-- devtype and isFactory are optional; returns a table with major, minor and patch as keys
function M.downloadImageFile(baseUrl, ver, forceDownload, devType, isFactory)
	local filename = M.constructImageFilename(ver, devType, isFactory)
	local doDownload = (type(forceDownload) == 'boolean') and forceDownload or (not exists(M.CACHE_PATH .. '/' .. filename))
	--TODO: if file exists but is of different length, set doDownload to true
	--TODO: if file exists but does not match md5sum, set doDownload to true
	return doDownload and downloadFile(baseUrl .. '/images/' .. filename, M.CACHE_PATH, filename) or 0
end

-- this function will not return
function M.flashImageVersion(version, noRetain, devType, isFactory)
	local imgName = M.constructImageFilename(version, devType, isFactory)
	local cmd = noRetain and 'sysupgrade -n ' or 'sysupgrade '
	cmd = cmd .. M.CACHE_PATH .. '/' .. imgName
	P(1, "running command: '" .. cmd .. "'")
	return runCommand(cmd, true) -- if everything goes to plan, this will not return
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

	M.verbosity = argTable.verbosity
	if argTable.useCache ~= nil then useCache = argTable.useCache end

	P(0, "Doodle3D Wifibox firmware updater")
	if os.execute('mkdir -p ' .. M.CACHE_PATH) ~= 0 then
		E("Error: could not create cache directory '" .. M.CACHE_PATH .. "'")
		os.exit(1)
	end

	if argTable.action == 'showHelp' then
		print("\t-h\t\tShow this help message")
		print("\t-q\t\tBe more quiet")
		print("\t-c\t\tUse cache as much as possible")
		print("\t-C\t\tDo not use the cache")
		print("\t-q\t\tBe more quiet")
		print("\t-V\t\tBe more verbose")
		print("\t-u <base_url>\tUse specified base URL (default: " .. M.DEFAULT_BASE_URL .. ")")
		print("\t-m\t\tOnly print machine-readable output (implies -q)")
		print("\t-v\t\tShow current image version")
		print("\t-l\t\tShow list of available image versions (and which one has been downloaded, if any)")
		print("\t-i <version>\tShow information (changelog) about the requested image version")
		print("\t-d <version>\tDownload requested image version")
		print("\t-r\t\tRemove downloaded image")
		print("\t-f <version>\tFlash to requested image version (by means of sysupgrade)")
		os.exit(10)

	elseif argTable.action == 'showCurrentVersion' then
		local vText,msg,nr = M.getCurrentVersionText()
		if not vText then E("error reading firmware version (" .. nr .. ": " .. msg .. ")"); os.exit(1) end
		local v = M.parseVersion(vText)
		if not v then E("error parsing version '" .. vText .. "'"); os.exit(2) end
		P(1, "version: " .. M.formatVersion(v))

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
			P(1, "version: " .. M.formatVersion(vEnt.version))
			P(1, "sysupgradeFilename: " .. (vEnt.sysupgradeFilename or '<nil>'))
			P(1, "factoryFilename: " .. (vEnt.factoryFilename or '<nil>'))
			P(1, "sysupgradeFileSize: " .. (vEnt.sysupgradeFileSize or '<nil>'))
			P(1, "factoryFileSize: " .. (vEnt.factoryFileSize or '<nil>'))
			P(1, "sysupgradeMD5: " .. (vEnt.sysupgradeMD5 or '<nil>'))
			P(1, "factoryMD5: " .. (vEnt.factoryMD5 or '<nil>'))
			P(1, "changelog: " .. (vEnt.changelog or '<nil>'))
		else
			P(1, "not found")
		end

	elseif argTable.action == 'imageDownload' then
		--TODO: first check if version exists
		local rv,msg = M.downloadImageFile(argTable.baseUrl, argTable.version, not useCache) --TEMP
		if rv ~= 0 then E("could not download file (" .. rv .. ")")
		else P(1, "success")
		end
	elseif argTable.action == 'imageRemove' then
		P(0, "Removing " .. M.CACHE_PATH .. "/doodle3d-wifibox-*.bin")
		--TODO: actually remove
	elseif argTable.action == 'imageInstall' then
		local rv = M.flashImageVersion(argTable.version)
		E("error: flash function returned, the device should have been flashed and rebooted instead")
		os.exit(3)
	end

	os.exit(0)
end

-- only execute the main function if an arg table is present, this enables usage both as module and as standalone script
if arg ~= nil then main() end

return M
