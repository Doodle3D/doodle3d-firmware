local utils = require("util.utils")

local M = {
	_is_test = true,
	_skip = { 'dump', 'symlink', 'getUciSectionName', 'symlinkInRoot' },
	_wifibox_only = { 'getUciSectionName', 'symlinkInRoot' }
}

local function compareTables(t1, t2)
	if #t1 ~= #t2 then return false end
	for i=1,#t1 do
		if t1[i] ~= t2[i] then return false end
	end
	return true
end

-- Returns a string representation of the argument, with 'real' strings enclosed in single quotes
local function stringRepresentation(v)
	return type(v) == 'string' and ("'"..v.."'") or tostring(v)
end


local filename = "/tmp/somefile12345.txt"


function M:_setup()
	os.execute("rm -f " .. filename) -- make sure the file does not exist
end

function M:_teardown()
	os.execute("rm -f " .. filename) -- make sure the file gets removed again
end


function M:test_splitString()
	local input1, input2, input3 = ':a:b::', '/a/b//', '$a$b$$'
	local expected = { '', 'a', 'b', '', '' }
	
	local result1 = input1:split()
	local result2 = input2:split('/')
	local result3 = input3:split('$')
	
	assert(#result1 == 5)
	assert(compareTables(result1, expected))
	assert(#result2 == 5)
	assert(compareTables(result2, expected))
	assert(#result3 == 5)
	assert(compareTables(result3, expected))
end

function M:test_toboolean()
	local trues = { true, 1, 'true', 'True', 'T', '1' }
	local falses = { nil, false, 0, 'false', 'False' , 'f', {} }
	
	for _,v in pairs(trues) do assert(utils.toboolean(v), "expected true: " .. stringRepresentation(v)) end
	for _,v in pairs(falses) do assert(not utils.toboolean(v), "expected false: " .. stringRepresentation(v)) end
end

function M:test_dump()
	--test handling of reference loops
	assert(false, 'not implemented')
end

function M:test_getUciSectionName()
	assert(false, 'not implemented')
end

function M:test_exists()
	assert(utils.exists() == nil)
	assert(utils.exists(nil) == nil)
	
	assert(not utils.exists(filename))
	os.execute("touch " .. filename)
	assert(utils.exists(filename))
end

function M:test_create()
	local f, testContents = nil, 'test text'
	
	assert(utils.create() == nil)
	assert(utils.create(nil) == nil)
	
	assert(not io.open(filename, 'r'))
	utils.create(filename)
	assert(io.open(filename, 'r'))
	
	f = io.open(filename, 'w')
	f:write(testContents)
	f:close()
	
	utils.create(filename)
	f = io.open(filename, 'r')
	local actualContents = f:read('*all')
	assert(actualContents == testContents)
end

function M:test_size()
	local tempFile = '/tmp/132uytjhgfr24e'
	local text = 'Why is a raven like a writing-desk?'
	
	local f = io.open(tempFile, 'w')
	f:write(text)
	f:close()
	
	local f = io.open(tempFile, 'r')
	assert(f:seek() == 0)
	assert(utils.fileSize(f) == text:len())
	assert(f:seek() == 0)
	f:read(4)
	assert(utils.fileSize(f) == text:len())
	assert(f:seek() == 4)
	f:close()
	os.remove(tempFile)
end

function M:test_symlink()
	assert(false, 'not implemented')
end

-- this should test for the following condition: 'Could not rename /www to /www-regular(/www: Invalid cross-device link)'
function M:test_symlinkInRoot()
	assert(false, 'not implemented')
end

return M
