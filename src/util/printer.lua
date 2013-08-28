local SUPPORTED_PRINTERS = { 
	rigidbot = "Rigidbot",
	ultimaker = "Ultimaker",
	makerbot_replicator2 = "MakerBot Replicator2",
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
	vision_3d_printer = "Vision 3D Printer"
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

return M
