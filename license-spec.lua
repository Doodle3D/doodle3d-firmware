local M = {
	BASE_PATH = 'src',
	EXCLUDE_FILES = { 'src/util/JSON.lua', 'src/util/urlcode.lua' },
	PROCESS_FILES = {
		['src/[^/]*%.lua'] = 'lua',
		['src/network/[^/]*%.lua'] = 'lua',
		['src/rest/[^/]*%.lua'] = 'lua',
		['src/rest/api/[^/]*%.lua'] = 'lua',
		['src/script/[^/]*%.lua'] = 'lua',
		['src/util/[^/]*%.lua'] = 'lua',
		['src/script/d3dapi'] = 'sh',
		['src/script/dhcpcheck_init'] = 'sh',
		['src/script/signin%.sh'] = 'sh',
		['src/script/wifibox_init'] = 'sh'
	},
	IGNORE_GIT_CHANGED = false
}
return M
