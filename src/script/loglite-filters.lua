local M = {}

M.default = {
	['options'] = { ['mode'] = 'keep', count = 'none' },
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
	}
}


M.test = {  -- TEST set
	['options'] = { ['mode'] = 'keep', count = 'all' },
	['patterns'] = {
		['%(info%)'] = 'yellow'
	}
}

M.printstart = {
	['options'] = { ['mode'] = 'delete' },
	['patterns'] = {
		['print started'] = '_uppercase,bwhite'
	}
}

return M
