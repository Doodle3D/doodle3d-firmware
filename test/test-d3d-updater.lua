-- This script contains a number of impromptu tests to check version comparisons, kept around in case real unit tests will be created one day.
argStash = arg
arg = nil
local upd = require('d3d-updater')
arg = argStash

local function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

local input = '19990213'
local ts = upd.parseDate(input)
print("parse " .. input .. ": " .. ts)
print("format " .. ts .. ": " .. upd.formatDate(ts))

local vertex1 = '0.2.3'
local vertab1 = upd.parseVersion(vertex1)
print("parse " .. vertex1 .. ": " .. dump(vertab1))
print("formatted: " .. upd.formatVersion(vertab1))

local vertex2 = '0.2.3-text'
local vertab2 = upd.parseVersion(vertex2)
print("parse " .. vertex2 .. ": " .. dump(vertab2))
print("formatted: " .. upd.formatVersion(vertab2))

local vA, vB = upd.parseVersion("1.4.5-alpha"), upd.parseVersion("1.4.4-rc1")
local tsA, tsB = 100000, 100005

local cmp1,cmp2 = upd.compareVersions(vA, vB)
print("vA <=> vB: " .. cmp1 .. " / " .. dump(cmp2))
cmp1,cmp2 = upd.compareVersions(vA, vB, tsA, tsB)
print("vA/tsA <=> vB/tsB: " .. cmp1 .. " / " .. dump(cmp2))
cmp1,cmp2 = upd.compareVersions(vB, vA, tsA, tsB)
print("vB/tsA <=> vA/tsB: " .. cmp1 .. " / " .. dump(cmp2))
cmp1,cmp2 = upd.compareVersions(vA, vB, tsB, tsA)
print("vA/tsB <=> vB/tsA: " .. cmp1 .. " / " .. dump(cmp2))

local vWithout,vWith = upd.parseVersion('1.2.3'), upd.parseVersion('1.2.3-sfx')
--print("vWithout: " .. dump(vWithout) .. "; vWith: " .. dump(vWith))
cmp1,cmp2 = upd.compareVersions(vWithout, vWithout)
print("1.2.3 <=> 1.2.3: " .. cmp1 .. " / " .. dump(cmp2))
cmp1,cmp2 = upd.compareVersions(vWithout, vWith)
print("1.2.3 <=> 1.2.3-sfx: " .. cmp1 .. " / " .. dump(cmp2))
cmp1,cmp2 = upd.compareVersions(vWith, vWith)
print("1.2.3-sfx <=> 1.2.3-sfx: " .. cmp1 .. " / " .. dump(cmp2))

print("nn equal? " .. dump(upd.versionsEqual(vWithout, vWithout)))
print("ny equal? " .. dump(upd.versionsEqual(vWithout, vWith)))
print("yy equal? " .. dump(upd.versionsEqual(vWith, vWith)))
