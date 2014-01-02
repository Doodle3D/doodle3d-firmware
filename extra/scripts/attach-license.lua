#!/usr/bin/env lua

-- TODO:
-- - cstyle comments with lines in them not starting with a '*' are not detected properly
-- - cstyle comments a la '//' are ignored completely
-- - lua block comments are not recognized
-- - in replaceComments(), source files should only be replaced with temp file if it has actually been changed
local lfs = require('lfs')

LICENSE_COMMENT_PREFIX = "This file is part of the Doodle3D project"

local specs = nil
local headers = {}


local function getFileList(path)
	local result = {}
	if not path  or type(path) ~= 'string' then return result end
	for file in lfs.dir(path) do
		--local fileWithSubPath = subPath and subPath..'/'..file or file
		local subPath = path..'/'..file
		if lfs.attributes(subPath,'mode') == 'file' then
			table.insert(result, subPath)
		elseif lfs.attributes(subPath,'mode')== 'directory' and file ~= '.' and file ~= '..' then
			local rr = getFileList(subPath)
			for _,v in ipairs(rr) do table.insert(result, v) end
		end
	end

	return result
end

-- @returns indexed table with an entry for each line or nil if file could not be read
local function readFileAsLines(file)
	local f,err = io.open(file, "r")
	if not f then return f,err end
	local result = {}
	for l in f:lines() do
		table.insert(result, l)
	end
	return result
end

local function findItemInList(haystack, needle)
	for _,v in pairs(haystack) do
		if v == needle then return true end
	end
	return false
end

local function getGitChangedFiles(path)
	if not path then path = '' end
	os.execute('git update-index -q --refresh')
	local f,msg = io.popen('git diff-index --name-only HEAD -- ' .. path, "r")
	if not f then return f,msg end

	local result = {}
	for l in f:lines() do
		table.insert(result, l)
	end

	return result
end

local function initHeaders(headersPath)
--	if not firmwareRootPath then firmwareRootPath = '.' end
--	local headersPath = firmwareRootPath .. '/' .. 'extra/license-headers'
	print("Reading headers from: " .. headersPath)
	headers['lua'] = readFileAsLines(headersPath .. '/header-lua')
	headers['sh'] = readFileAsLines(headersPath .. '/header-sh')
	headers['cstyle'] = readFileAsLines(headersPath .. '/header-cstyle')
end

-- writes first through last lines from indexed string array 'lines' to f, with newlines in between
-- if last is nil, everything from first on will be written; if first is nil, it is considered to be line 1
local function emitLines(lines, f, first, last)
	if first == nil then first = 1 end
	if last == nil then last = #lines end
	if last - first < 0 then return end
	for i=first, last do f:write(lines[i] .. '\n') end
end

function string:hashbang() return self:find('^#!') and true or false end
function string:empty() return self:find('^[%s]*$') and true or false end

function string:comment(filetype)
	if filetype == 'lua' then return self:find('^%-%-.*') and true or false
	elseif filetype == 'sh' then return self:find('^#.*') and true or false
	elseif filetype == 'cstyle' then return self:find('^%s?/?%*.*') and true or false
	end
end


-- @returns false if explicitly excluded, type (as string) if matched or nil otherwise
local function matchFileType(file)
	local len = file:len()
	for _,pat in ipairs(specs.EXCLUDE_FILES) do
		local s,e = file:find(pat)
		if s == 1 and e == len then return false end
	end

	for pat,type in pairs(specs.PROCESS_FILES) do
		local s,e = file:find(pat)
		if s == 1 and e == len then return type end
	end

	return nil
end


-- @returns first line nr or false if no comment found
-- @returns last line nr if comment found
local function findComment(lines, filetype)
	if not (filetype == 'lua' or filetype == 'sh' or filetype == 'cstyle') then return nil,'unrecognized file type' end

	local first, last = false, nil

	local justConsumeEmpty = false
	for i,l in ipairs(lines) do
		if i > 1 and l:hashbang() then
			break
		elseif l:hashbang() then
			--ignore this to simulate a continue
		elseif not l:comment(filetype) then
			if first and l:empty() then
				justConsumeEmpty = true
			elseif first then
				last = i - 1
				break
			elseif not l:empty() then
				break
			end
		else
			if justConsumeEmpty then
				last = i - 1
				break
			elseif not first then
				first = i
			end
		end
	end

	return first,last
end


local function detectLicenseComment(lines, filetype, first, last)
	local hasText = function(line, filetype)
		if filetype == 'lua' then return line:find('^[%s%-]*$') == nil and true or false
		elseif filetype == 'sh' then return line:find('^[%s#]*$') == nil and true or false
		elseif filetype == 'cstyle' then return line:find('^[%s%*/]*$') == nil and true or false
		else return nil
		end
	end

	for i,l in ipairs(lines) do
		if i >= first and i <= last and hasText(l, filetype) then
			return l:find(LICENSE_COMMENT_PREFIX, 1, true) and true or false
		end
	end

	return false
end


-- replaces line range [first, last] with header for filetype
-- if first and/or last are nil, header is inserted at line 1, or 2 if a hashbang is present
-- returns true on success, nil+msg otherwise
local function replaceComment(filepath, filetype, lines, first, last)
--	local filesEqual = function(file1, file2) return os.execute('cmp -s ' .. file1 .. ' ' .. file2) end--and true or false end

	if first == nil or last == nil then first = lines[1]:hashbang() and 2 or 1 end

	local tmpFileName = os.tmpname()
	f,msg = io.open(tmpFileName, "w+")
	if not f then return f, "could not open temporary file '" .. tmpFileName .. "' (" .. msg .. ")" end

	emitLines(lines, f, 1, first - 1)
	emitLines(headers[filetype], f)
	emitLines(lines, f, last and last + 1 or first, nil)

	f:close()

--	if not filesEqual(tmpFileName, filepath) then
--		print("actually replacing '" .. filepath .. "' with '" .. tmpFileName .. "' now...")
		local rv,msg = os.rename(tmpFileName, filepath)
		os.remove(tmpFileName) -- clean up
		if not rv then return rv,"could not replace file with '" .. tmpFileName .. "' (" .. msg .. ")" end
--	else
--		print("files are equal, not touching original")
--	end

	return true
end


local function processFile(filepath, filetype, lines)
	local sLine,eLine = findComment(lines, filetype)
	if sLine then
		if detectLicenseComment(lines, filetype, sLine, eLine) then
			print("Replacing comment in file: '" .. filepath .. "' (type: " .. filetype .. ") head comment: " .. sLine .. "-" .. eLine)
			replaceComment(filepath, filetype, lines, sLine, eLine)
		else
			print("Adding comment to file: '" .. filepath .. "' (type: " .. filetype .. ") unrecognized head comment: " .. sLine .. "-" .. eLine)
			replaceComment(filepath, filetype, lines, nil, nil)
		end
	elseif sLine == false then
		print("Adding comment to file: '" .. filepath .. "' (type: " .. filetype .. ") no comment")
		replaceComment(filepath, filetype, lines, nil, nil)
	else
		return nil, "invalid type: '" .. filetype .. "'"
	end

	return true
end


local function main()
	if #arg ~= 1 then
		print("Please supply directory containing 'license-spec.lua' as argument")
		os.exit(1)
	end

	local pwd = lfs.currentdir()
	local scriptPath = arg[0]:match('^(.*)/')
	local headersPath = pwd .. '/' .. scriptPath .. '/../license-headers'
	initHeaders(headersPath) -- NOTE: this must be precede the chdir below

	print("Working directory: " .. arg[1])
	if not lfs.chdir(arg[1]) then
		print("error: could not change to directory '" .. arg[1] .. "', exiting")
		os.exit(1)
	end

	specs = require('license-spec')
	if not specs.BASE_PATH or specs.BASE_PATH:len() == 0 then specs.BASE_PATH = '.' end

	local files = getFileList(specs.BASE_PATH)
	local changed = getGitChangedFiles(specs.BASE_PATH)
--	for _,l in ipairs(changed) do print("changed: " .. l) end --TEMP


	for _,f in ipairs(files) do
		local processType = matchFileType(f)
		if processType then
			if specs.IGNORE_GIT_CHANGED or not findItemInList(changed, f) then
				local lines,err = readFileAsLines(f)
				if lines then
					local rv,msg = processFile(f, processType, lines)
					if not rv then print("error: could not process file '" .. f .. "' (" .. msg .. ")") end
				else
					print("error: could not open '" .. f .. "' (".. err .. ")")
				end
			else
				print("error: file '" .. f .. "' has uncommitted changes in git, refusing to process")
			end
		end
	end
end

main()
