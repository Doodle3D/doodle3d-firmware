package.path = package.path .. ';./test/?.lua'
local ansicolors = require('test.ansicolors')

local testFunctionPrefix = 'test_'

local function tableIndexOf(t, val)
	for k,v in ipairs(t) do 
		if v == val then return k end
	end
	return -1
end

local function runningOnWifibox()
	local f,e = io.open('/etc/openwrt_release', 'r')
	return f ~= nil
end

local function runTestFile(filename, showStackTraces)
	local r,tf = pcall(require, filename)
	local stackTrace, errorMessage
	
	local function errorHandler(msg)
		stackTrace = debug.traceback()
		errorMessage = msg
	end
	
	if not r then return nil,tf end
	if not tf._is_test then return nil,"not a test file" end
	
	local setupFunc, teardownFunc = tf._setup, tf._teardown
	
	print("======= running test file '" .. filename .. "' =======")
	
	for k,v in pairs(tf) do
		--if type(v) == 'function' and k ~= '_setup' and k ~= '_teardown' then
		if type(v) == 'function' and k:find(testFunctionPrefix) == 1 then
			local baseName = k:sub(testFunctionPrefix:len() + 1)
			local skip = (tableIndexOf(tf._skip, baseName) > -1)
			local wifiboxOnly = (tableIndexOf(tf._wifibox_only, baseName) > -1)
			
			if not skip and (not wifiboxOnly or runningOnWifibox()) then
				pcall(setupFunc)
				local testResult = xpcall(v, errorHandler)
				pcall(teardownFunc)
				
				if testResult then
					print(ansicolors.green .. "[OK ] " .. ansicolors.reset .. k)
				else
					print(ansicolors.red .. "[ERR] " .. ansicolors.reset .. k)
					if errorMessage then print("      " .. errorMessage) end
					if showStackTraces and stackTrace then print("      " .. stackTrace) end
				end
			else
				if skip then
					print(ansicolors.bright .. ansicolors.black .. "[SKP] " .. ansicolors.reset .. k)
				else
					print(ansicolors.yellow .. "[WBO] " .. ansicolors.reset .. k)
				end
			end
		end
	end
	
	print("")
	
	return true
end


local function main()
	if #arg < 1 then
		print("Please specify at least one lua test file")
		os.exit(1)
	end
	
	for i=1,#arg do
		local modName = 'test_'..arg[i]
		local r,e = runTestFile(modName, true)
		
		if not r then
			io.stderr:write("test file '" .. modName .. "' could not be loaded or is not a test file ('" .. e .. "')\n")
		end
	end
	
	os.exit(0)
end

main(arg)
