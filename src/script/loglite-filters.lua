local M = {}

M.printstart = {
	['options'] = { ['mode'] = 'delete' },
	['patterns'] = {
		['print started'] = '_uppercase,bwhite'
	}
}

M.test = {
	['options'] = { 'delete_mode' },
	['patterns'] = {
		['(verbose)'] = 'underline,cyan,_delete'
		['(info)'] = 'magenta',
		['ABSD'] = '_nodelete',
		['SE?RV?'] = 'bblue'
	}
}

return M
