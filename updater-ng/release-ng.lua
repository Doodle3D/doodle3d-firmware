#!/usr/bin/env lua
--#!/usr/bin/env lua -l strict

--TODO: replace prints with D() function from update manager and other slightly smarter mechanisms?

local function ERR(msg) print(msg) end

local ok, pl = pcall(require, 'pl.import_into')
if not ok then
	ERR('This script requires the Penlight library')
	os.exit(2)
end
pl = pl()
local um --- update manager module, will be loaded later through @{loadUpdateManager}

local lfs = require('lfs') -- assume this exists since it's required by penlight as well


-----------------------------
-- CONSTANTS AND VARIABLES --
-----------------------------

local SERVER_HOST = 'localhost'
local SERVER_PATH = '~USERDIR/public_html/wifibox/updates'
--local SERVER_HOST = 'doodle3d.com'
--local SERVER_PATH = 'doodle3d.com/DEFAULT/updates'

local D3D_REPO_FIRMWARE_NAME = 'doodle3d-firmware'
local D3D_REPO_CLIENT_NAME = 'doodle3d-client'
local D3D_REPO_PRINT3D_NAME = 'print3d'
local IMAGE_BASENAME = 'doodle3d-wifibox'
local BACKUP_FILE_SUFFIX = 'bkp'
local RELEASE_NOTES_FILE = "ReleaseNotes.md"
local RSYNC_TIMEOUT = 2

local deviceType = 'tl-mr3020' -- or 'tl-wr703'
local lock = nil
local paths = {}



-----------------------
-- UTILITY FUNCTIONS --
-----------------------

local function loadUpdateManager()
	package.path = package.path .. ';' .. pl.path.join(paths.firmware, 'updater-ng') .. '/?.lua'
	local argStash = arg
	arg = nil
	um = require('d3d-update-mgr') -- arg must be nil for the update manager to load as module
	arg = argStash
end

local function quit(ev)
	if lock then lock:free() end
	os.exit(ev or 0)
end

local function md5sum(file)
	local rv,_,sum = pl.utils.executeex('md5 -q "' .. file .. '"')

	return rv and sum:sub(1, -2) or nil
end

local function getYesNo(question)
	local answer
	repeat
		io.write(question)
		io.flush()
		answer = io.stdin:read('*line'):lower()
	until answer == 'yes' or answer == 'no' or answer == 'n'

	return (answer == 'yes') and true or false
end

local function detectRootPrivileges()
	local rv,_,userId = pl.utils.executeex('id -u')
	if not rv then return nil end

	return tonumber(userId) == 0 and true or false
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

local function runAction(actMsg, errMsg, ev, func)
	io.stdout:write("* " .. actMsg .. "...")
	local rv,err = func()
	if not rv then
		print("Error: " .. errMsg .. " (" .. err .. ")")
		quit(ev)
	else
		print("ok")
	end

	return true
end


local function constructImageName(version, devType, sysupOrFactory)
	return IMAGE_BASENAME .. '-' .. um.formatVersion(version) .. '-' .. devType .. '-' .. sysupOrFactory .. '.bin'
end

local function imageCachePath()
	return pl.path.join(paths.cache, 'images')
end

local function ensureFilePresent(src, tgt)
--	print("About to copy '" .. src .. "' => '" .. tgt .. "'")
	local srcMd5, tgtMd5 = md5sum(src), md5sum(tgt)

	if not srcMd5 then return nil,"source file does not exist" end
	if tgtMd5 and srcMd5 ~= tgtMd5 then return nil,"target file already exists but is different from source file" end

	if not tgtMd5 then
		if not pl.file.copy(src, tgt, false) then return nil,"could not copy file" end
	end

	return true
end



--------------------
-- MAIN FUNCTIONS --
--------------------

local function prepare()
	local msg = nil

	io.stdout:write("* Checking if working directory is the OpenWrt root... ")
	local isOpenWrtRoot = detectOpenWrtRoot()
	if isOpenWrtRoot then
		paths.wrt = pl.path.currentdir()
		print("found (" .. paths.wrt .. ")")
	else
		print("unrecognized directory, try changing directories or using -wrt-root")
		return nil
	end

	io.stdout:write("* Looking for Doodle3D feed path... ")
	local d3dFeed,msg = getWifiboxFeedRoot('feeds.conf')
	if d3dFeed then
		print("found " .. d3dFeed)
	else
		if msg then print("not found: " .. msg) else print("not found.") end
		return nil
	end

	paths.firmware = pl.path.join(d3dFeed, D3D_REPO_FIRMWARE_NAME)
	paths.client = pl.path.join(d3dFeed, D3D_REPO_CLIENT_NAME)
	paths.print3d = pl.path.join(d3dFeed, D3D_REPO_PRINT3D_NAME)

	-- if empty, try to choose something sensible
	if not paths.cache or paths.cache == '' then
		paths.cache = '/tmp/d3d-release-dir'
	end
	io.stdout:write("* Attempting to use " .. paths.cache .. " as cache dir... ")
	local rv,msg = pl.dir.makepath(paths.cache)
	if not rv then
		print("could not create path (" .. msg .. ").")
		return nil
	end

	loadUpdateManager()

	local rv,msg = pl.dir.makepath(imageCachePath())
	if not rv then
		print("could not create images dir (" .. msg .. ").")
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

local function collectLocalInfo()
	local info = {}

	-- temporary fields required for copying image files
	info.factoryImgPath = pl.path.join(paths.wrt, 'bin/ar71xx/openwrt-ar71xx-generic-' .. deviceType .. '-v1-squashfs-factory.bin')
	info.sysupgradeImgPath = pl.path.join(paths.wrt, 'bin/ar71xx/openwrt-ar71xx-generic-' .. deviceType .. '-v1-squashfs-sysupgrade.bin')

	info.version = um.parseVersion(pl.file.read(pl.path.join(paths.firmware, 'src/FIRMWARE-VERSION')))
	if not info.version then return nil,"could not determine current firmware version" end

	info.factoryFileSize = pl.path.getsize(info.factoryImgPath)
	if not info.factoryFileSize then return nil,"could not determine size for factory image" end

	info.sysupgradeFileSize = pl.path.getsize(info.sysupgradeImgPath)
	if not info.sysupgradeFileSize then return nil,"could not determine size for sysupgrade image" end

	info.factoryMD5 = md5sum(info.factoryImgPath)
	info.sysupgradeMD5 = md5sum(info.sysupgradeImgPath)
	if not info.factoryMD5 or not info.sysupgradeMD5 then return nil,"could not determine MD5 sum for image(s)" end

	info.factoryFilename = constructImageName(info.version, deviceType, 'factory')
	info.sysupgradeFilename = constructImageName(info.version, deviceType, 'sysupgrade')
	info.timestamp = os.time()

	return info
end

local function fetchVersionInfo()
	local msg,stables,betas = nil,nil,nil

	stables,msg = um.getAvailableVersions('stables')
	if not stables then return nil,msg end

	betas,msg = um.getAvailableVersions('betas')
	if not betas then return nil,msg end

	return stables, betas
end

local function generateIndex(newVersion, versionTable, isStable)
	local indexFilename = isStable and um.IMAGE_STABLE_INDEX_FILE or um.IMAGE_BETA_INDEX_FILE
	local sortedVers = pl.List(versionTable)
	sortedVers:sort(function(a, b)
		return um.compareVersions(a.version, b.version, a.timestamp, b.timestamp) < 0
	end)

	local indexPath = pl.path.join(imageCachePath(), indexFilename)
	local rv = pl.file.copy(indexPath, pl.path.join(paths.cache, indexFilename..'.'..BACKUP_FILE_SUFFIX))
	if not rv then return nil,"could not backup index file" end

	local idxFile = io.open(pl.path.join(imageCachePath(), indexFilename), 'w')
	if not idxFile then return nil,"could not open index file for writing" end

	sortedVers:foreach(function(el)
		idxFile:write("Version: " .. um.formatVersion(el.version) .. "\n")
		idxFile:write("Files: " .. el.sysupgradeFilename .. "; " .. el.factoryFilename .. "\n")
		idxFile:write("FileSize: " .. el.sysupgradeFileSize .. "; " .. el.factoryFileSize .. "\n")
		idxFile:write("MD5: " .. el.sysupgradeMD5 .. "; " .. el.factoryMD5 .. "\n")
		idxFile:write("ReleaseDate: " .. um.formatDate(el.timestamp) .. "\n")
	end)

	idxFile:close()
	return 0
end

local function copyImages(newVersion)
	local rv,msg
	rv,msg = ensureFilePresent(newVersion.factoryImgPath, pl.path.join(imageCachePath(), newVersion.factoryFilename))
	if not rv then return nil,msg end

	rv,msg = ensureFilePresent(newVersion.sysupgradeImgPath, pl.path.join(imageCachePath(), newVersion.sysupgradeFilename))
	if not rv then return nil,msg end

	return true
end

local function copyReleaseNotes()
	local releaseNotesPath = pl.path.join(imageCachePath(), RELEASE_NOTES_FILE)
	if pl.path.isfile(releaseNotesPath) then
		local rv = pl.file.copy(releaseNotesPath, pl.path.join(paths.cache, RELEASE_NOTES_FILE..'.'..BACKUP_FILE_SUFFIX))
		if not rv then return nil,"could not backup file" end
	end

	local rv = pl.file.copy(pl.path.join(paths.firmware, RELEASE_NOTES_FILE), releaseNotesPath)
	if not rv then return nil,"could not copy file" end

	return true
end

-- TODO: the packages are not really used and the openwrt script to generate the
-- package index requires all packages to be present so this has been skipped for now
local function buildFeedDir()
	local scriptPath = pl.path.join(paths.wrt, 'scripts/ipkg-make-index.sh')

	return nil
end

local function uploadFiles()
	local serverUrl = SERVER_HOST..':'..SERVER_PATH
	-- rsync options are: recursive, preserve perms, symlinks and timestamps, be verbose and use compression
	local cmd = "rsync -rpltvz -e ssh --progress --timeout=" .. RSYNC_TIMEOUT .. " --exclude '*.bkp' --exclude 'lockfile.lfs' " .. paths.cache .. "/* " .. serverUrl
	print("Running command: '" .. cmd .. "'")
	local rv,ev = um.compatexecute(cmd)
	return rv and true or nil,("rsync failed, exit status: " .. ev)
end

local function main()
	print("\nDoodle3D release script")
	if detectRootPrivileges() then
		print("Error: refusing to run script as root.")
		quit(99)
	end

--	local opts = parseOptions(arg)
--
--	if opts['wrt-root'] then changedir(opts['wrt-root']) end
--	if opts['cache-dir'] then paths.cache = opts['cache-dir'] end
-- more options: clear cache, rebuild (download all and generate index from actual files), dry-run, force

	if not prepare() then quit(1) end

	-- initialize update manager script
	um.setUseCache(false)
	um.setVerbosity(1)
	um.setCachePath(imageCachePath())

	local newVersion,msg = collectLocalInfo()
	if not newVersion then
		print("Error: could not collect local version information (" .. msg .. ")")
		quit(3)
	end

	local isStable = (newVersion.version.suffix == nil)
	print("\nRolling release for firmware version " .. um.formatVersion(newVersion.version) .. " (type: " .. (isStable and "stable" or "beta") .. ").")

	local stables,betas = fetchVersionInfo()
	if not stables then
		print("Error: could not get version information (" .. betas .. ")")
		quit(1)
	end

	if um.findVersion(newVersion.version, stables) or um.findVersion(newVersion.version, betas) then
		print("Error: firmware version " .. um.formatVersion(newVersion.version) .. " already exists")
		quit(3)
	end


--	pl.pretty.dump(newVersion)
--	print("stables: "); pl.pretty.dump(stables)
--	print("===========================");
--	print("betas: "); pl.pretty.dump(betas)

	--TODO: if requested, fetch images and packages (i.e., mirror whole directory)
	--TODO: run sanity checks


	runAction("Generating new index file", "could not generate index", 4, function()
		return generateIndex(newVersion, isStable and stables or betas, isStable)
	end)

	runAction("Copying image files", "could not generate index", 4, function()
		return copyImages(newVersion)
	end)

	runAction("Copying release notes", "failed", 4, copyReleaseNotes)

	io.stdout:write("* Building package feed directory...")
	print("skipped - not implemented")
--	runAction("Building package feed directory", "failed", 4, buildFeedDir)


	local answer = getYesNo("? Local updates directory will be synced to remote server, proceed? (y/n) ")
	if answer ~= true then
		print("Did not get green light, quitting.")
		quit(5)
	end

	runAction("About to sync files to server", "could not upload files", 5, uploadFiles)

	print("Done.")
	quit()
end

main()
