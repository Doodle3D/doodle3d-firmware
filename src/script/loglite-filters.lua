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
