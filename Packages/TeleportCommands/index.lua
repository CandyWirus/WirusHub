local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))

local player = cloneref(Players.LocalPlayer or Players.PlayerAdded:Wait())


local KeyCode = Enum.KeyCode
local KeyCode_TOGGLE = KeyCode.F2
local KeyCode_CLICK = Enum.UserInputType.MouseButton1

local WirusHub = shared.WirusHub
local setFlyCFrame = false
local PivotFly = WirusHub.PivotFly
if PivotFly then
	setFlyCFrame = PivotFly.SetFlyCFrame
end

local getSpoofTable = WirusHub.SignalSpoofer.GetSpoofTable

local teleport = function(cframe)
	local character = cloneref(player.Character)
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
			if setFlyCFrame and PivotFly.IsFlying then
				setFlyCFrame(cframe)
			else
				local spoof = getSpoofTable(hrp, "ClickTeleport")
				spoof.CFrame = false
				character:PivotTo(cframe)
				spoof.CFrame = true
			end
		end
	end
end

local onCommand = function(command, playerName)
	local partial = playerName:lower()
	local target = player
	local targetCharacter
	for _, v in Players:GetPlayers() do
		local currentName = v.Name:lower()
		if string.sub(currentName, 1, #partial) == partial then
			local character = v.Character
			if character then
				target = v
				targetCharacter = character
			end
		end
	end
	if command == "goto" then
		return teleport(targetCharacter:GetPivot())
	end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and UserInputService:IsKeyDown(KeyCode_TOGGLE) and input.UserInputType == KeyCode_CLICK then
        local camera = cloneref(workspace.CurrentCamera)
		if camera then
			local inputPosition = input.Position
			local unitRay = camera:ScreenPointToRay(inputPosition.X, inputPosition.Y)
			local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000)
			if result then
				local cframe = CFrame.new(result.Position + Vector3.new(0, 5, 0))
				teleport(cframe)
			end
		end
    end
end)

return {
	OnCommand = onCommand
}