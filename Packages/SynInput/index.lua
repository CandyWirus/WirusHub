local RunService = cloneref(game:GetService("RunService"))
local LocalizationService = cloneref(game:GetService("LocalizationService"))
local Players = cloneref(game:GetService("Players"))

local PACKAGE = select(1, ...)

local inputBegan = SynSignal.new()
local inputEnded = SynSignal.new()

local virtualKeys = loadfile(PACKAGE.Path .. "\\VirtualKeys.lua")()
local keyCodes = loadfile(PACKAGE.Path .. "\\KeyCodes.lua")()

local savedKeyStates = table.create(254, false)
RunService.RenderStepped:Connect(function()
	for i = 1, 254 do
		local oldVal = savedKeyStates[i]
		local newVal = iskeydown(i)
		savedKeyStates[i] = newVal
		
		local keyCode = virtualKeys[i]
		local ascii = nil
		if keyCode then
			ascii = keyCodes[keyCode]
		end
		
		if oldVal ~= newVal then
			if newVal then
				inputBegan:Fire(i, keyCode, ascii)
			else
				inputEnded:Fire(i, keyCode, ascii)
			end
		end
	end
end)

local warningPath = PACKAGE.Path .. "\\nowarning"
if not isfile(warningPath) then
	task.spawn(function()
		local player = cloneref(Players.LocalPlayer or Players.PlayerAdded:Wait())
		local success, countryCode = pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)
		if success and countryCode ~= "US" then
			if messagebox("WARNING - The program has detected that you are not residing in the United States (or you are using a non-US VPN). SynInput is built around US keyboards only. You may experience incompatibilities if you are not using a US keyboard. There are no plans to resolve any incompatibilities with non-US keyboards. Click OK to never show this popup again.", "WirusHub.SynInput", 1) == 1 then
				writefile(warningPath, "")
			end
		end
	end)
end

local virtualKeyToKeyCode = function(virtualKey)
	return virtualKeys[virtualKey]
end
local keyCodeToAscii = function(keyCode)
	return keyCodes[keyCode]
end

return {
	InputBegan = inputBegan,
	InputEnded = inputEnded,
	VirtualKeyToKeyCode = function(virtualKey)
		return virtualKeys[virtualKey]
	end,
	KeyCodeToVirtualKey = function(keyCode)
		for i, v in virtualKeys do
			if v == keyCode then
				return i
			end
		end
	end,
	KeyCodeToAscii = function(keyCode)
		return keyCodes[keyCode]
	end
}