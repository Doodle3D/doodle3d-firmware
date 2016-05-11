## Loglite

The loglite script allows coloring and filtering of log files by specifying certain patterns and associating directives to them. These mainly specify colors but additionally, (non-)matched lines can be deleted from output and also all output lines can be numbered.


### Usage

The script can follow an existing log file (comparable to `tail -f`), or it can follow its standard input. A file to follow is always specified as the first argument and a filter set name as the second (use '-' as file name to read from standard input). Details on filter sets can be found below. If no filter set is mentioned on the command-line, the script will attempt to use one named 'default'.

* Example following an existing log file using a filter set named 'example':   
`./loglite.lua print3d.log example`.
* Example using standard input, to filter/view a whole log file, with a filter set named 'serial' (note the '-' as file name):  
`cat print3d-ttyACM0.log | ./loglite.lua - serial`
* Example using standard input, to capture both output streams from `print3d`, with a filter set named 'example' (note the '-' as file name):  
`./print3d -V 2>&1 | ./loglite.lua - example`.

#### On WiFi-Box
Loglite is already installed since version 0.10.10 as `loglite`.  
Check `/root/.profile` for handy aliases like `tailfw` and `tailp3d`.

### Filter sets

The script looks for filter sets in the file '$HOME/loglite-filters.lua'. It looks like this:

``` lua
local M = {}

M.default = {
	['options'] = { mode = 'keep', count = 'none' },
	['patterns'] = {
		['%(error%)'] = 'red',
		['%(warning%)'] = 'yellow',
		['%(bulk%)'] = 'bold,black'
	}
}

M.specialization = {
	['parent'] = 'default',
	['options'] = { mode = 'delete' }
	['patterns'] = {
		['setState%(%)'] = 'bblue,_nodelete'
	}
}

return M
```

Here, the declaration and returning of `M` is required for the loglite script to be able to cleanly import the file. In `M.default`, 'default' is the name of a filter set being defined (similar for 'specialization'). Definitions can contain three so-called keys: 'parent' specifies a filter set to inherit from in order to reduce code duplication, 'options' and 'patterns' are described below.

Inheritance can be used to set new keys or to override keys from the parent set. Previously set keys cannot be removed, but they can be set to a non-existing directive (e.g., Lua's 'false' keyword) to achieve the same effect. Note that directives in inheriting sets are currently not combined with previous ones, so for instance overriding `['test'] = 'red, _delete'` with `['test'] = 'blue'` will result in only the directive 'blue' to be applied.

#### Options

Two options are currently available:

* `mode`, which specifies whether to keep log lines (`keep`, the default) or to drop them (`delete`). For specific lines this can then be overridden, see 'Patterns' below.
* `count`, which can be set to `all` to prefix log lines with a counter, or `none` (default) to leave them as is.

#### Patterns

Pattern specifications are patterns as used in Lua: [Lua documentation on patterns](http://www.lua.org/pil/20.2.html).
The following directives can be associated with a pattern:

* A foreground color, one of: black, red, green, yellow, blue, magenta, cyan or white.
* A background color, like foreground colors but prefixed with 'b'.
* `bold`, which usually has the effect of rendering a bright variant of the foreground color (note that `bold,black` renders as dark gray).
* `reverse` will reverse fore- and background colors.
* Also available are `blink` and `underscore` but they do currently not work in all terminal programs or might need to be enabled in the preferences.
* `_delete` or `_nodelete` to override the active mode specified in the 'options' above.

Directives can be combined with ',' (e.g.: `'red,_nodelete'`). Finally, in any filter set, pattern rules are matched from top to bottom, the last one encountered overriding any previous conflicting directive.

### Installation
Note: Loglite is already installed on the WiFi-Box since version 0.10.10.

Install Lua. See:  
http://lua-users.org/wiki/LuaBinaries  
It's tested in Lua 5.1 and Lua 5.2.

Loglite will check for a `loglite-filters.lua` file in your home directory. It's recommended to create a symbolic link to the latest version.
On OS X / Linux:
```
cd
ln -s [absolute path to file]/loglite-filters.lua loglite-filters.lua
```

It's recommended to create a symbolic link in one of your PATH directories (`echo $PATH`) to the loglite.lua file. This allows you to run `loglite` from any directory.
On OS X / Linux:
```
cd /usr/local/bin
ln -s [absolute path to file]/loglite.lua loglite.lua
```
