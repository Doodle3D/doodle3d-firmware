#!/usr/bin/lua
package.cpath = package.cpath .. '/usr/lib/lua/?.so'
JSON = (loadfile "/usr/share/lua/wifibox/util/JSON.lua")()

local p3d = require("print3d")

local printer = p3d.getPrinter(arg[1])

local remote = arg[2]

local finished = false

local id = arg[3]

local info = JSON:decode(io.popen("wget -qO - " .. remote .. "/info/" .. id):read("*a"))

local current_line = 0
local total_lines = tonumber(info["lines"])
local started = false

while(not finished)
do
    local f = io.popen("wget -qO - " .. remote .. "/fetch/" .. id .. "/" .. current_line)
    local line = f:read()
    while line ~= nil do
        printer:appendGcode(line)
        current_line = current_line + 1
        line = f:read()
    end
    if current_line > total_lines then
        finished = true
        break
    end

    if not started then
	started = true
	print("send print start command")
        printer:startPrint()
    end

    local accepts_new_gcode = false

    while (not accepts_new_gcode)
    do
	local current,buffer,total,bufferSize,maxBufferSize = printer:getProgress()

	print("current: " .. current .. " total:" .. total .. " buffer: " .. buffer .. " bufferSize: " .. bufferSize .. " maxBufferSize: " .. maxBufferSize)
	local percentageBufferSize = bufferSize / maxBufferSize

        if percentageBufferSize < 0.8 then
	    print("buffer below 80% capacity, sending new gcode")
            accepts_new_gcode = true
        else
	    print("buffer above 80% capacity")
            os.execute("sleep 10")
        end
    end
end
