--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


local log = require('util.logger')
local utils = require('util.utils')
local printDriver = require('print3d')

local SUPPORTED_PRINTERS = {
	rigidbot = "Rigidbot",
	ultimaker = "Ultimaker",
	ultimaker2 = "Ultimaker2",
	makerbot_replicator2 = "MakerBot Replicator2",
	makerbot_replicator2x = "MakerBot Replicator2x",
	makerbot_thingomatic = "MakerBot Thing-o-matic",
	printrbot = "Printrbot",
	bukobot = "Bukobot",
	cartesio = "Cartesio",
	cyrus = "Cyrus",
	delta_rostockmax = "Delta RostockMax",
	deltamaker = "Deltamaker",
	eventorbot = "EventorBot",
	felix = "Felix",
	gigabot = "Gigabot",
	kossel = "Kossel",
	leapfrog_creatr = "LeapFrog Creatr",
	lulzbot_aO_101 = "LulzBot AO-101",
	makergear_m2 = "MakerGear M2",
	makergear_prusa = "MakerGear Prusa",
	makibox = "Makibox",
	orca_0_3 = "Orca 0.3",
	ord_bot_hadron = "ORD Bot Hadron",
	printxel_3d = "Printxel 3D",
	prusa_i3 = "Prusa I3",
	prusa_iteration_2 = "Prusa Iteration 2",
	rapman = "RapMan",
	reprappro_huxley = "RepRapPro Huxley",
	reprappro_mendel = "RepRapPro Mendel",
	robo_3d_printer = "RoBo 3D Printer",
	shapercube = "ShaperCube",
	tantillus = "Tantillus",
	vision_3d_printer = "Vision 3D Printer",
	minifactory = "miniFactory",
	builder3d = "Builder 3D",
	bigbuilder3d = "Big Builder 3D",
	mamba3d = "Mamba3D",
	marlin_generic = "Generic Marlin Printer",
    makerbot_generic = "Generic Makerbot Printer"
}
local SUPPORTED_BAUDRATES = {
	["115200"] = "115200 bps",
	["2500000"] = "2500000 bps"
}

local M = {}

function M.supportedPrinters()
	return SUPPORTED_PRINTERS
end

function M.supportedBaudRates()
	return SUPPORTED_BAUDRATES
end



--returns a printer instance or nil (and sets error state on response in the latter case)
function M.createPrinterOrFail(deviceId, response)

	--log:debug("API:printer:createPrinterOrFail: "..utils.dump(deviceId))
	local msg,printer = nil, nil

	if deviceId == nil or deviceId == "" then
		printer,msg = printDriver.getPrinter()
	else
		printer,msg = printDriver.getPrinter(deviceId)
	end

	if not printer then
		if response ~= nil then
			response:setError("could not open printer driver (" .. msg .. ")")
			response:addData('id', deviceId)
		end
		return nil
	end

	return printer
end

return M
