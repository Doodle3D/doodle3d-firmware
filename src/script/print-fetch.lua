#!/usr/bin/lua

local function log(message)
    os.execute("logger " .. message)
    print(message)
end

if (table.getn(arg) == 0) then
    print("Usage: ./print-fetch {printerSocket} {remoteURL} {id} [startGcode] [endGCode]")
    return
end

log("starting gcode fetch program")

package.cpath = package.cpath .. '/usr/lib/lua/?.so'
JSON = (loadfile "/usr/share/lua/wifibox/util/JSON.lua")()

local p3d = require("print3d")

local printer = p3d.getPrinter(arg[1])
if printer == nil then
    log("error connecting to printer")
    return
end

local remote = arg[2]

local finished = false

local id = arg[3]

log("gcode file id: " .. id)
log("gcode server: " .. remote)

local info = JSON:decode(io.popen("wget -qO - " .. remote .. "/info/" .. id):read("*a"))

local current_line = 0
local total_lines = tonumber(info["lines"])
local started = false

log("total lines: " .. total_lines)

local startCode = nil
local endCode = nil

function countlines(file)
    return tonumber(io.popen("wc -l < " .. file):read('*a'))
end

function readGCodeArg(argi)
    local gcodeFile = arg[argi]
    total_lines = total_lines + countlines(gcodeFile)
    return io.open(gcodeFile):read('*a')
end

if table.getn(arg) >= 5 then
    startCode = readGCodeArg(4)
    endCode = readGCodeArg(5)
end

if startCode ~= nil then
    log("appending start gcode")
    printer:appendGcode(startCode)
end

while(not finished)
do
    local f = io.popen("wget -qO - " .. remote .. "/fetch/" .. id .. "/" .. current_line)
    local line = f:read()
    while line ~= nil do
	printer:appendGcode(line, total_lines, { seq_number = -1, seq_total = -1, source = id })
        current_line = current_line + 1
        line = f:read()
    end

    if not started then
	started = true
	print("send print start command")
        printer:startPrint()
    end

    if current_line >= total_lines then
        log("finished fetching gcode")
        if endCode ~= nil then
            log("appending end gcode")
            printer:appendGcode(endCode)
        end
        finished = true
        break
    end


    local accepts_new_gcode = false

    while (not accepts_new_gcode)
    do
	local current,buffer,total,bufferSize,maxBufferSize = printer:getProgress()
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
