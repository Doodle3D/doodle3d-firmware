#!/usr/bin/env lua
--#!/usr/bin/env lua -l strict

local function ERR(msg) print(msg) end

local ok, pl = pcall(require, 'pl.import_into')
if not ok then
	ERR('This script requires the Penlight library')
	os.exit(2)
end
pl = pl()

local lfs = require('lfs') -- assume this exists since it's required by penlight as well

local argStash = arg
arg = nil
local upmgr = require('d3d-update-mgr') -- arg must be nil for the update manager to load as module
arg = argStash



-----------------------------
-- CONSTANTS AND VARIABLES --
-----------------------------

local D3D_REPO_FIRMWARE_NAME = 'doodle3d-firmware'
local D3D_REPO_CLIENT_NAME = 'doodle3d-client'
local D3D_REPO_PRINT3D_NAME = 'print3d'
local IMAGE_BASENAME = 'doodle3d-wifibox'

local deviceType = 'tl-mr3020' -- or 'tl-wr703'
local lock = nil
local paths = {}



-----------------------
-- UTILITY FUNCTIONS --
-----------------------

local function quit(ev)
	if lock then lock:free() end
	os.exit(ev or 0)
end

local function md5sum(file)
	local rv,_,sum = pl.utils.executeex('md5 -q "' .. file .. '"')

	return rv and sum:sub(1, -2) or nil
end

local function detectOpenWrtRoot()
	local f = io.open('Makefile', 'r')
	local line = f and f:read('*line')
	local rv = (line and line:find('# Makefile for OpenWrt') == 1) and true or false

	if f then f:close() end
	return rv
end

-- returns uri (file path) of the wifibox feed, nil if not found or nil+msg on error
-- recognized feed names are 'wifibox' and 'doodle3d' (case-insensitive)
local function getWifiboxFeedRoot(feedsFile)
	local typ, nam, uri = nil, nil, nil
	local lineNo = 1
	local f = io.open(feedsFile, 'r')

	if not f then return nil, "could not open '" .. feedsFile .. '"' end

	for line in f:lines() do
		typ, nam, uri = line:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)$')

		if not (typ and nam and uri) then
			f:close()
			return uri or nil, "could not parse line " .. feedsFile .. "#" .. lineNo
		end

		local commented = (typ:find('#') == 1)
		if not commented and (nam:lower() == 'wifibox' or nam:lower() == 'doodle3d') then
			break
		else
			typ, nam, uri = nil, nil, nil
		end

		lineNo = lineNo + 1
	end

	if uri and not (typ == 'src-link' or typ == 'src-cpy') then return nil, "d3d feed has wrong type '" .. typ .. "', use 'src-link' or 'src-cpy'" end

	f:close()
	return uri
end

-- TODO: pass table to functions to fill in? if they all return either true or nil+msg, that could be used for display of ok/msg
-- returns true on success, false on error, and displays meaningful messages
--local function runCheck(msg, processFunc)
--	io.stdout:write(msg .. "... ")
--	return processFunc(--[[ hmm ]]--)
--end


local function constructImageName(version, devType, sysupOrFactory)
	return IMAGE_BASENAME .. '-' .. upmgr.formatVersion(version) .. '-' .. devType .. '-' .. sysupOrFactory .. '.bin'
end


local function collectLocalInfo()
	local info = {}

	-- temporary fields required for copying image files
	info.sysupImgPath = paths.wrt .. '/bin/ar71xx/openwrt-ar71xx-generic-' .. deviceType .. '-v1-squashfs-sysupgrade.bin'
	info.factImgPath = paths.wrt .. '/bin/ar71xx/openwrt-ar71xx-generic-' .. deviceType .. '-v1-squashfs-factory.bin'

	info.version = upmgr.parseVersion(pl.file.read(paths.firmware .. '/src/FIRMWARE-VERSION'))
	if not info.version then return nil,"could not determine current firmware version" end

	info.factoryFileSize = pl.path.getsize(info.factImgPath)
	if not info.factoryFileSize then return nil,"could not determine size for factory image" end

	info.sysupgradeFileSize = pl.path.getsize(info.sysupImgPath)
	if not info.sysupgradeFileSize then return nil,"could not determine size for sysupgrade image" end

	info.factoryMD5 = md5sum(info.factImgPath)
	info.sysupgradeMD5 = md5sum(info.sysupImgPath)
	if not info.factoryMD5 or not info.sysupgradeMD5 then return nil,"could not determine MD5 sum for image(s)" end

	info.factoryFilename = constructImageName(info.version, deviceType, 'factory')
	info.sysupgradeFilename = constructImageName(info.version, deviceType, 'sysupgrade')
	info.timestamp = os.time()

	return info
end



--------------------
-- MAIN FUNCTIONS --
--------------------

local function prepare()
	local msg = nil

	io.stdout:write("Checking if working directory is the OpenWrt root... ")
	local isOpenWrtRoot = detectOpenWrtRoot()
	if isOpenWrtRoot then
		paths.wrt = pl.path.currentdir()
		print("found (" .. paths.wrt .. ")")
	else
		print("unrecognized directory, try changing directories or using -wrt-root")
		return nil
	end

	io.stdout:write("Looking for Doodle3D feed path... ")
	local d3dFeed,msg = getWifiboxFeedRoot('feeds.conf')
	if d3dFeed then
		print("found " .. d3dFeed)
	else
		if msg then print("not found: " .. msg) else print("not found.") end
		return nil
	end

	paths.firmware = d3dFeed .. '/' .. D3D_REPO_FIRMWARE_NAME
	paths.client = d3dFeed .. '/' .. D3D_REPO_CLIENT_NAME
	paths.print3d = d3dFeed .. '/' .. D3D_REPO_PRINT3D_NAME

	-- if empty, try to choose something sensible
	if not paths.cache or paths.cache == '' then
		paths.cache = '/tmp/d3d-release-dir/2ndpath'
	end
	io.stdout:write("Attempting to use " .. paths.cache .. " as cache dir... ")
	local rv,msg = pl.dir.makepath(paths.cache)
	if not rv then
		print("could not create path (" .. msg .. ").")
		return nil
	end

	lock,msg = lfs.lock_dir(paths.cache)
	if not lock then
		print("could not obtain directory lock (" .. msg .. ").")
		return nil
	else
		print("ok")
	end

	return true
end

local function fetchVersionInfo()
	local msg,stables,betas = nil,nil,nil

	stables,msg = upmgr.getAvailableVersions('stables')
	if not stables then return nil,msg end

	betas,msg = upmgr.getAvailableVersions('betas')
	if not betas then return nil,msg end

	return stables, betas
end

local function generateIndex(newVersion, versionTable, isStable)
	return 0
end

local function copyImages(newVersion)
	return 0
end

local function main()
	print("Doodle3D release script")
--	local opts = parseOptions(arg)
--
--	if opts['wrt-root'] then changedir(opts['wrt-root']) end
--	if opts['cache-dir'] then paths.cache = opts['cache-dir'] end

	if not prepare() then quit(1) end

	-- initialize update manager script
	upmgr.setUseCache(false)
	upmgr.setVerbosity(1)
	upmgr.setCachePath(paths.cache)

	local newVersion = collectLocalInfo()

	local stables,betas = fetchVersionInfo()
	if not stables then
		print("Error: could not get version information (" .. betas .. ")")
		quit(1)
	end

	local isStable = (newVersion.version.suffix == nil)
	print("Rolling release for firmware version " .. upmgr.formatVersion(newVersion.version) .. " (type: " .. (isStable and "stable" or "beta") .. ").")

	if upmgr.findVersion(newVersion.version, stables) or upmgr.findVersion(newVersion.version, betas) then
		print("Error: firmware version " .. upmgr.formatVersion(newVersion.version) .. " already exists")
		quit(3)
	end

	if not generateIndex(newVersion, isStable and stables or betas, isStable) then
		print("Error: could not generate index")
		quit(4)
	end

	if not copyImages(newVersion) then
		print("Error: could not copy images")
		quit(4)
	end


	print(pl.pretty.dump(newVersion))
	print("stables: " .. pl.pretty.dump(stables))
	print("===========================");
	print("betas: " .. pl.pretty.dump(betas))


	--if requested, fetch images and packages (i.e., mirror whole directory)

	--run sanity checks

	--check whether newVersion is not conflicting with or older than anything in corresponding table
	--add newVersion to correct table and generate updated index file

	quit()
end


main()
