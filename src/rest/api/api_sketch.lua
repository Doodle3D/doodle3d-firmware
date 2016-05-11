--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


--[[
	This module uses the Lua filesystem library to iterate over all sketches.
	A more flexible approach would be to use an index file (like the update module does).
	That way, we could also store arbitrary meta-data together with the sketches.
]]--

local lfs = require('lfs')
local log = require('util.logger')
local utils = require('util.utils')

local MOD_ABBR = "ASKE"

local M = {
	isApi = true,
	SKETCH_DIR = '/root/sketches',
	MIN_FREE_SPACE = 1024 * 80
}

local NUMBER_PAD_WIDTH = 5
local SKETCH_FILE_EXTENSION = 'svg'


-- creates sketch directory, and sets response to error state on failure
local function createSketchDirectory()
	if os.execute('mkdir -p ' .. M.SKETCH_DIR) ~= 0 then
		log:error(MOD_ABBR, "could not create sketch directory '" .. M.SKETCH_DIR .. "'")
		response:setError("could not create sketch directory")
		return false
	end
	return true
end

local function constructSketchFilename(idx)
	return string.format('%0' .. NUMBER_PAD_WIDTH .. '.0f.%s', idx, SKETCH_FILE_EXTENSION)
end

--should this return 1k-blocks or bytes?
local function getFreeDiskSpace()
	local kb = utils.captureCommandOutput('df / -k | awk \'$3 ~ /[0-9]+/ { print $4 }\'')
	return kb * 1024
end

local function createSketchList()
	local result = {}

	for item in lfs.dir(M.SKETCH_DIR) do
		if item ~= '.' and item ~= '..' then
			local idx = item:match('^(%d+)\.'..SKETCH_FILE_EXTENSION..'$')
			if idx and idx:len() == NUMBER_PAD_WIDTH then
				table.insert(result, tonumber(idx))
			end
		end
	end

	table.sort(result)
	return result
end


-- retrieve sketches, requires id(int)
function M._global_GET(request, response)
	local argId = request:getBlankArgument() -- try this one first
	if not argId then argId = request:get("id") end -- and fall back to this one

	if not argId then
		response:setError("missing id argument")
		return
	end
	argId = tonumber(argId)

	if not createSketchDirectory(request, response) then return end
	local sketches = createSketchList()

	local exists = false
	for _,sketchId in ipairs(sketches) do
		if sketchId == argId then
			exists = true
			break
		end
	end

	response:addData('id', argId)
	if exists then
		local loadFile,msg = io.open(M.SKETCH_DIR .. '/' .. constructSketchFilename(argId))

		if not loadFile then
			response:setError("could not open sketch file for reading (" .. msg .. ")")
			return
		end

		local data = loadFile:read('*a')
		if not data then data = '' end
		response:addData('data', data)

		loadFile:close()
		response:setSuccess()
	else
		response:setFail("sketch not found")
	end
end

-- TODO: do we need locking?
-- save sketches, requires data(string)
function M._global_POST(request, response)
	local argData = request:get("data")

	if not argData then
		response:setFail("missing data argument")
		return
	elseif argData:len() == 0 then
		response:setFail("data argument must be non-empty")
		return
	end

	if getFreeDiskSpace() - M.MIN_FREE_SPACE < argData:len() then
		response:setFail("not enough free space")
		response:addData('available', getFreeDiskSpace())
		response:addData('reserved', M.MIN_FREE_SPACE)
		response:addData('sketch_size', argData:len())
		return
	end

	if not createSketchDirectory(request, response) then return end
	local sketches = createSketchList()

	local listSize = table.getn(sketches)
	local sketchIdx = listSize > 0 and sketches[listSize] + 1 or 1
	local sketchFile = M.SKETCH_DIR .. '/' .. constructSketchFilename(sketchIdx)

	log:verbose(MOD_ABBR, "saving sketch #" .. sketchIdx .. " (" .. argData:len() .. " bytes)")
	local saveFile,msg = io.open(sketchFile, 'w')

	if not saveFile then
		response:setError("error opening sketch file for writing (".. msg .. ")")
		return
	end

	saveFile:write(argData)
	saveFile:close()

	response:addData('id', sketchIdx)
	response:setSuccess()
end

-- TODO: return total space used by sketches? (createSketchList() could just as well collect size info too...see lfs.attributes)
function M.status(request, response)
	if not createSketchDirectory(request, response) then return end
	local sketches = createSketchList()

	local listSize = table.getn(sketches)
	response:addData('number_of_sketches', table.getn(sketches))
	response:addData('available', getFreeDiskSpace())
	response:addData('reserved', M.MIN_FREE_SPACE)

	response:setSuccess()
end

-- remove all sketches
function M.clear_POST(request, response)
	local rv = os.execute("rm -f " .. M.SKETCH_DIR .. '/*')
	if rv == 0 then response:setSuccess()
	else response:setFail("could not remove contents of sketch directory")
	end
end

-- remove single sketch
-- function M.delete_POST(request, response)
-- 	local argId = tonumber(request:get("id")) --to number will raise exception in case of illegal input
-- 	local filename = M.SKETCH_DIR .. '/' .. constructSketchFilename(argId)
-- 	local rv = os.execute("rm -f " .. filename)
-- 	if rv == 0 then response:setSuccess()
-- 	else response:setFail("could not remove " .. filename)
-- 	end
-- end

-- recreate directory sequence by renaming files
function M.index_POST(request, response)
	local list = {}
	local index = 1
	for item in lfs.dir(M.SKETCH_DIR) do
		if item ~= '.' and item ~= '..' then
			local idx = item:match('^(%d+)\.'..SKETCH_FILE_EXTENSION..'$')
			if idx and idx:len() == NUMBER_PAD_WIDTH then
				local src = M.SKETCH_DIR .. '/' .. item
				local dst = M.SKETCH_DIR .. '/' .. constructSketchFilename(index)
				
				if src ~= dst then
					table.insert(list, src .. ' ' .. dst)
					local rv = os.execute("mv " .. src .. ' ' .. dst)
				end

				index = index + 1
				
			end
		end
	end

	response:addData('list',list)
	response:setSuccess()
end

-- list files by fileID (not by index)
function M.list_GET(request, response)
	response:addData("list",createSketchList())
	response:setSuccess()
end

-- remove single sketch by fileID (not by index)
function M.delete_POST(request, response)
	local argId = tonumber(request:get("id")) --to number will raise exception in case of illegal input
	local filename = M.SKETCH_DIR .. '/' .. constructSketchFilename(argId)
	local rv = os.execute("rm -f " .. filename)
	if rv == 0 then response:setSuccess()
	else response:setFail("could not remove " .. filename)
	end
end

return M
