--
-- This file is part of the Doodle3D project (http://doodle3d.com).
--
-- @copyright 2013, Doodle3D
-- @license This software is licensed under the terms of the GNU GPL v2 or later.
-- See file LICENSE.txt or visit http://www.gnu.org/licenses/gpl.html for full license details.


---
-- This file wraps @{main.handle_request} in main.lua for command-line or CGI usage.
-- It emulates the env table usually constructed by uhttpd-mod-lua.
local main = require('main')

--- Create an environment table mimicking the table uhttpd-mod-lua passes into @{main.handle_request}.
--
-- The table is created using shell environment variables leaving out only 'DOCUMENT\_ROOT',
-- 'SCRIPT\_PATH' and the regular shell variables (e.g., IFS, HOME and PS1).
--
-- See [information on CGI environment variables](http://techpubs.sgi.com/library/dynaweb_docs/0530/SGI_Developer/books/NetscapeSrv_PG/sgi_html/ch01.html).
--
-- Fields present in the 'real' env table but not in this one are: 'HTTP\_VERSION'
-- and another table 'headers' which is mostly mirrored by the 'HTTP\_*' fields.
-- Note that the 'headers' table may contain extra fields (e.g., 'cache-control').
-- @treturn table An environment table created from shell environment variables.
local function createEnvTableFromShellEnvironment()
	local environ = {}

	environ['CONTENT_LENGTH'] = os.getenv('CONTENT_LENGTH') or ''
	environ['CONTENT_TYPE'] = os.getenv('CONTENT_TYPE') or ''
	environ['GATEWAY_INTERFACE'] = os.getenv('GATEWAY_INTERFACE') or ''
	environ['HTTP_ACCEPT'] = os.getenv('HTTP_ACCEPT') or ''
	environ['HTTP_ACCEPT_CHARSET'] = os.getenv('HTTP_ACCEPT_CHARSET') or ''
	environ['HTTP_ACCEPT_ENCODING'] = os.getenv('HTTP_ACCEPT_ENCODING') or ''
	environ['HTTP_ACCEPT_LANGUAGE'] = os.getenv('HTTP_ACCEPT_LANGUAGE') or ''
	environ['HTTP_AUTHORIZATION'] = os.getenv('HTTP_AUTHORIZATION') or ''
	environ['HTTP_CONNECTION'] = os.getenv('HTTP_CONNECTION') or ''
	environ['HTTP_COOKIE'] = os.getenv('HTTP_COOKIE') or ''
	environ['HTTP_HOST'] = os.getenv('HTTP_HOST') or ''
	environ['HTTP_REFERER'] = os.getenv('HTTP_REFERER') or ''
	environ['HTTP_USER_AGENT'] = os.getenv('HTTP_USER_AGENT') or ''
	environ['PATH_INFO'] = os.getenv('PATH_INFO') or ''
	environ['QUERY_STRING'] = os.getenv('QUERY_STRING') or ''
	environ['REDIRECT_STATUS'] = os.getenv('REDIRECT_STATUS') or ''
	environ['REMOTE_ADDR'] = os.getenv('REMOTE_ADDR') or ''
	environ['REMOTE_HOST'] = os.getenv('REMOTE_HOST') or ''
	environ['REMOTE_PORT'] = os.getenv('REMOTE_PORT') or ''
	environ['REQUEST_METHOD'] = os.getenv('REQUEST_METHOD') or ''
	environ['REQUEST_URI'] = os.getenv('REQUEST_URI') or ''
	environ['SCRIPT_FILENAME'] = os.getenv('SCRIPT_FILENAME') or ''
	environ['SCRIPT_NAME'] = os.getenv('SCRIPT_NAME') or ''
	environ['SERVER_ADDR'] = os.getenv('SERVER_ADDR') or ''
	environ['SERVER_NAME'] = os.getenv('SERVER_NAME') or ''
	environ['SERVER_PORT'] = os.getenv('SERVER_PORT') or ''
	environ['SERVER_PROTOCOL'] = os.getenv('SERVER_PROTOCOL') or ''
	environ['SERVER_SOFTWARE'] = os.getenv('SERVER_SOFTWARE') or ''

	return environ
end


--- Entry point for cgi-bin wrapper script. ---
local rv = handle_request(createEnvTableFromShellEnvironment())
os.exit(rv)
