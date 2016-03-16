local M = {}

M.default = {
	['options'] = { mode = 'keep', count = 'none' },
	['patterns'] = {
		['%(error%)'] = 'red',
		['%(warning%)'] = 'yellow',
		['%(bulk%)'] = 'gray',
		['setState%(%)'] = 'bblue'
	}
}

-- filter rules for firmware log (/tmp/wifibox.log)
M.firmware = {
	['parent'] = 'default',
	['patterns'] = {
	}
}

-- filter rules for print3d log (/tmp/print3d-*.log)
M.print3d = {
	['parent'] = 'default',
	['patterns'] = {
		['Print 3D server'] = 'byellow',
		['sendCode%(%)'] = 'green',
		['readCode%(%)'] = 'blue',
		['readResponseCode%(%)'] = 'blue'
	}
}

-- filter rules for serial communcation of print3d
M.serial = {
	['options'] = { mode = 'delete', count = 'none' },
	['patterns'] = {
		['Print 3D server'] = 'byellow,_nodelete',
		['sendCode%(%)'] = 'green,_nodelete',
		['readCode%(%)'] = 'blue,_nodelete',
		['readResponseCode%(%)'] = 'blue,_nodelete',
		['setState%(%)'] = 'bblue,_nodelete',
		['%[ABSD%]'] = 'gray,_nodelete', -- 0.10.10
		['%[ABD%]'] = 'gray,_nodelete', -- 0.10.9
		['%(info%)'] = 'gray,_nodelete' -- 0.10.10
	}
}


M.test = {  -- TEST set
	['options'] = { mode = 'keep', count = 'all' },
	['patterns'] = {
		['%(info%)'] = 'yellow'
	}
}

M.printstart = {
	['options'] = { mode = 'delete' },
	['patterns'] = {
		['print started'] = '_uppercase,bwhite'
	}
}

return M
