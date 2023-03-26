local UserInputService = cloneref(game:GetService("UserInputService"))
local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))

local PACKAGE = select(1, ...)

local player = cloneref(Players.LocalPlayer or Players.PlayerAdded:Wait())

local WirusHub = shared.WirusHub
local SynInput = WirusHub.SynInput

local virtualKeyToKeyCode = SynInput.VirtualKeyToKeyCode
--local keyCodeToVirtualKey = SynInput.KeyCodeToVirtualKey
local keyCodeToAscii = SynInput.KeyCodeToAscii

local packages = WirusHub._packages

local optionsPath = PACKAGE.Path .. "\\options.json"

local options = {
	Prefix = 0xBA
}
if isfile(optionsPath) then
	local loaded, data = pcall(HttpService.JSONDecode, HttpService, readfile(optionsPath))
	if loaded then
		options = data
	else
		warn(optionsPath .. " is corrupted. It will be overwritten")
	end
elseif isfolder(optionsPath) then
	error(optionsPath .. " is occupied by a folder.")
else
	writefile(optionsPath, "{}")
end

local prefixKeyCode = virtualKeyToKeyCode(options.Prefix)
local prefixAscii = ";"
if prefixKeyCode then
	prefixAscii = keyCodeToAscii(prefixKeyCode)
end

player.Chatted:Connect(function(message)
	local detectedPrefix = string.sub(message, 1, 1)
	local isCommand = false
	for i = 1, #prefixAscii do
		if string.sub(prefixAscii, i, i) == detectedPrefix then
			isCommand = true
			break
		end
	end
	if isCommand then
		local args = string.split(string.sub(message, 2, -1), " ")
		local command = table.remove(args, 1):lower()
		for i, v in packages do
			if i ~= PACKAGE.Name then
				local packageCommands = v.Commands
				local cmdFunc = WirusHub[i].OnCommand
				if packageCommands and cmdFunc then
					for i2, v2 in packageCommands do
						if i2:lower() == command then
							return cmdFunc(i2, unpack(args))
						end
						for i = 2, #v2 do
							if v2[i]:lower() == command then
								return cmdFunc(i2, unpack(args))
							end
						end
					end
				end
			end
		end
	end
end)

game.Close:Connect(function()
	writefile(optionsPath, HttpService:JSONEncode(options))
end)

return {}