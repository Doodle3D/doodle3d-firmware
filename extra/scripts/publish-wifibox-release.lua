#!/usr/bin/env lua
--#!/usr/bin/env lua -l strict

-- This script creates a new release by copying openwrt image files and release notes to a local
-- directory and updating the relevant index file with a new entry. This directory is
-- then synchronized to the release repository online.
--
-- USAGE:
-- The only dependency of this script are the penlight and luafilesystem libraries, which can be installed using
-- LuaRocks (http://luarocks.org/) as follows: 
-- sudo luarocks install penlight
-- If the penlight libary is not found you might need to add the following to /etc/launchd.conf
-- setenv LUA_CPATH /opt/local/share/luarocks/lib/lua/5.2/?.so
-- setenv LUA_PATH /opt/local/share/luarocks/share/lua/5.2/?.lua
-- Reboot
--
-- This script will automatically locate the Doodle3D repo's. 
-- Index files are fetched from the online repository.
-- For synchronizing, rsync must have passwordless SSH access to the server, for a
-- guide, see: http://www.linuxproblem.org/art_9.html.
-- The scrips expects a alias named 'doodle3d.com', you can add this editing the following file:
-- .ssh/config
-- and adding
-- Host doodle3d.com
--        User webmaster@doodle3d.com
--        HostName ftp.greenhost.nl
-- Some basic sanity checks are built in (unique version, updated release notes, 'clean' openwrt config)
-- but lots others are still missing (mainly: clean git repo's, freshly built images).
-- The script must be run from within the openwrt build root. So it's handy to create a symlink 
-- to this file. You could to something like from the build root: 
-- ln -s ~/wrt-wifibox-feed/doodle3d-firmware/extra/scripts/publish-wifibox-release.lua .
-- Then you can start with:
-- cd trunk ../publish-wifibox-release.lua
-- Before anything is actually uploaded, you will be asked if that's really what you want to do.
-- It might be wise to make a backup on the server before updating it, there's a script
-- to do this on the server: '~/backup-updates-dir.sh'.
--
-- To play around with or improve on this script, use and modify the variables 'SERVER_HOST'
-- and 'SERVER_PATH' below to point to your machine (assuming you have a webserver running there).
-- Also uncomment and modify UPDATER_BASE_URL. You will have to init the local 'repo' with at
-- least empty index files ('wifibox-image.index' and 'wifibox-image.beta.index'), or you
-- could of course mirror the online repository.
--
-- TODO (in random order):
-- * (feature) command-line arguments: overrides, verbosity, allow local mirroring, clear local cache dir, etc.
-- * (feature) automatically create a backup of the online repo (there's already a script fir this, as mentioned above)
-- * (feature) check whether git repo's are clean and on correct branch
-- * (feature) allow local mirroring with a reverse rsync command and rebuilding the indexes
--   - update manager 'cache' should then be enabled to prevent fetchIndexTable from downloading files
-- * (feature) automatically (re)build openwrt to ensure it is up to date?
-- * (feature) update package feed (requires a local mirror for the feed indexing script)
--   - in this case sanity checks must also be run on package versions/revisions
-- * (feature) automatically tag (and merge?) git commits?
-- * (feature) execute as dry-run by default so changes can be reviewed?
-- * (refactor) rename awkward vars/funcs regarding entries, versions and caches...
-- * (refactor) replace function arguments 'includeBetas' with a set function like setUseCache to improve readability
-- * (refactor) replace prints with D() function from update manager or other slightly smarter mechanisms?

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

--local SERVER_HOST = 'localhost'
--local SERVER_PATH = '~USERDIR/public_html/wifibox/updates'
--local UPDATER_BASE_URL = 'http://localhost/~USERDIR/wifibox/updates'
local SERVER_HOST = 'doodle3d.com'
local SERVER_PATH = 'doodle3d.com/DEFAULT/updates'
--- SERVER_HOST and SERVER_PATH are used by rsync to merge the local working directory
-- back into the online repository (requires functioning public key SSH access).
-- UPDATER_BASE_URL is used by the d3d-updater script to download the index files
-- (over HTTP), it defaults to the doodle3d.com online repo so it should only be
-- used for development purposes.

local D3D_REPO_FIRMWARE_NAME = 'doodle3d-firmware'
local D3D_REPO_CLIENT_NAME = 'doodle3d-client'
local D3D_REPO_PRINT3D_NAME = 'print3d'
local IMAGE_BASENAME = 'doodle3d-wifibox'
local BACKUP_FILE_SUFFIX = 'bkp'
local RELEASE_NOTES_FILE = "ReleaseNotes.md"
local RSYNC_TIMEOUT = 2
local MAX_VIABLE_IMAGE_SIZE = 3500000

local deviceType = 'tl-mr3020' -- or 'tl-wr703'
local lock = nil
local paths = {}



-----------------------
-- UTILITY FUNCTIONS --
-----------------------

local function loadUpdateManager()
	package.path = package.path .. ';' .. pl.path.join(paths.firmware, 'src') .. '/?.lua'
	local argStash = arg
	arg = nil
	um = require('script.d3d-updater') -- arg must be nil for the update manager to load as module
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
	until answer == 'yes' or answer == 'y' or answer == 'no' or answer == 'n'

	return (answer:sub(1, 1) == 'y') and true or false
end

local function detectRootPrivileges()
	local rv,_,userId = pl.utils.executeex('id -u')
	if not rv then return nil end

	return tonumber(userId) == 0 and true or false
end

local function findInFile(needle, file)
	local f = io.open(file, 'r')
	if not f then return nil,"could not open file" end

	local t = f:read('*all')
	return not not t:find(needle, 1, true)
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
--	io.write(msg .. "... ")
--	return processFunc(--[[ hmm ]]--)
--end

local function runAction(actMsg, errMsg, ev, func)
	io.write("* " .. actMsg .. "...")
	local rv,err = func()
	if not rv then
		if err then print("Error: " .. errMsg .. " (" .. err .. ")")
		else print("Error: " .. errMsg)
		end
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

	io.write("* Checking if working directory is the OpenWrt root... ")
	local isOpenWrtRoot = detectOpenWrtRoot()
	if isOpenWrtRoot then
		paths.wrt = pl.path.currentdir()
		print("found " .. paths.wrt)
	else
		print("unrecognized directory, try changing directories or using -wrt-root")
		return nil
	end

	io.write("* Looking for Doodle3D feed path... ")
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
		--paths.cache = pl.app.appfile('')
		paths.cache = '/tmp/d3d-release-dir'
	end
	io.write("* Attempting to use " .. paths.cache .. " as cache dir... ")
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

		-- initialize update manager script
	um.setUseCache(false)
	um.setVerbosity(1)
	um.setCachePath(imageCachePath())
	if type(UPDATER_BASE_URL) == 'string' and UPDATER_BASE_URL:len() > 0 then
		print("* Using updater base URL: '" .. UPDATER_BASE_URL .. "'")
		um.setBaseUrl(UPDATER_BASE_URL)
	else
		print("* Using updater base URL: d3d-updater default")
	end

	print("* Using rsync server remote: '" .. SERVER_HOST .. "/" .. SERVER_PATH .. "'")

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
	versionTable[#versionTable+1] = newVersion
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
		if el.timestamp then idxFile:write("ReleaseDate: " .. um.formatDate(el.timestamp) .. "\n") end
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

local function copyReleaseNotes(newVersion)
	local srcReleaseNotesPath = pl.path.join(paths.firmware, RELEASE_NOTES_FILE)
	local tgtReleaseNotesPath = pl.path.join(imageCachePath(), RELEASE_NOTES_FILE)

	if not findInFile(um.formatVersion(newVersion.version), srcReleaseNotesPath) then
		return nil,"version not mentioned in release notes file"
	end

	if pl.path.isfile(tgtReleaseNotesPath) then
		local rv = pl.file.copy(tgtReleaseNotesPath, tgtReleaseNotesPath..'.'..BACKUP_FILE_SUFFIX)
		if not rv then return nil,"could not backup file" end
	end

	local rv = pl.file.copy(srcReleaseNotesPath, tgtReleaseNotesPath)
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

local function checkWrtConfig()
	local goodConfigPath = pl.path.join(paths.firmware, "extra/openwrt-build/openwrt-diffconfig-extramini")
	local wrtConfigPath = pl.path.tmpname()
	--print("diffonfig output file: " .. wrtConfigPath)

	local rv,ev = pl.utils.execute('./scripts/diffconfig.sh > "' .. wrtConfigPath .. '" 2> /dev/null')
	if not rv then return nil,"could not run diffconfig script (exit status: " .. ev .. ")" end

	local _,rv,output = pl.utils.executeex('diff "' .. wrtConfigPath .. '" "' .. goodConfigPath .. '"')

	if rv == 0 then
		return true
	elseif rv == 1 then
		print("configurations differ:\n-----------------------\n" .. output .. "\n-----------------------")
		--ask for confirmation?
	else
		return nil,"unexpected exit status from diff (" .. rv .. ")"
	end
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


	local newVersion,msg = collectLocalInfo()
	if not newVersion then
		print("Error: could not collect local version information (" .. msg .. ")")
		quit(3)
	end

	local stables,betas = fetchVersionInfo()
	if not stables then
		print("Error: could not get version information (" .. betas .. ")")
		quit(1)
	end

	--TODO: if requested, fetch images and packages (i.e., mirror whole directory)


--	pl.pretty.dump(newVersion)
--	print("stables: "); pl.pretty.dump(stables)
--	print("===========================");
--	print("betas: "); pl.pretty.dump(betas)


	print("\nRunning sanity checks")

	runAction("Checking whether version is unique",
			"firmware version " .. um.formatVersion(newVersion.version) .. " already exists", 3, function()
		return not (um.findVersion(newVersion.version, nil, stables) or um.findVersion(newVersion.version, nil, betas)) and true or nil
	end)

	runAction("Checking OpenWrt config", "failed", 3, checkWrtConfig)

	--TODO: check git repos (`git log -n 1 --pretty=format:%ct` gives commit date of last commit (not author date))

	local isStable = (newVersion.version.suffix == nil)
	print("\nRolling release for firmware version " .. um.formatVersion(newVersion.version) .. " (type: " .. (isStable and "stable" or "beta") .. ").")

	if newVersion.sysupgradeFileSize > MAX_VIABLE_IMAGE_SIZE then
		print("Error: sysupgrade image file is too large, it will not run well (max. size: " .. MAX_VIABLE_IMAGE_SIZE .. " bytes)")
		quit(4)
	end

	runAction("Copying release notes", "failed", 5, function()
		return copyReleaseNotes(newVersion)
	end)

	runAction("Generating new index file", "could not generate index", 5, function()
		return generateIndex(newVersion, isStable and stables or betas, isStable)
	end)

	runAction("Copying image files", "could not generate index", 5, function()
		return copyImages(newVersion)
	end)

	io.write("* Building package feed directory...")
	print("skipped - not implemented")
--	runAction("Building package feed directory", "failed", 5, buildFeedDir)


	local answer = getYesNo("? Local updates cache will be synced to remote server, proceed? (y/n) ")
	if answer ~= true then
		print("Did not get green light, quitting.")
		quit(5)
	end

	runAction("About to sync files to server", "could not upload files", 6, uploadFiles)

	print("Done.")
	quit()
end

main()
