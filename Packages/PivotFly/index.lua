--Pivot Fly Script
--Should be undetectable unless I missed something, works on every anticheat I've tried with
--Obviously, this won't bypass server-sided checks
--Andy_Wirus#5999

local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))

local PACKAGE = select(1, ...)

local player = cloneref(Players.LocalPlayer or Players.PlayerAdded:Wait())

local ZeroVector3 = Vector3.zero
local inf = math.huge

local KeyCode = Enum.KeyCode

local KeyCode_ToggleFly = KeyCode.F4

local KeyCode_Forward = KeyCode.W
local KeyCode_Backward = KeyCode.S
local KeyCode_Left = KeyCode.A
local KeyCode_Right = KeyCode.D
local KeyCode_Up = KeyCode.E
local KeyCode_Down = KeyCode.Q

local flySpeedPath = PACKAGE.Path .. "\\flyspeed.txt"

if isfolder(flySpeedPath) then
	error("[Wirus Hub] " .. flySpeedPath .. " already exists as a folder. PivotFly cannot continue.")
elseif not isfile(flySpeedPath) then
	writefile(flySpeedPath, 16)
end

local forward, backward, left, right, up, down

local getSpoofTable = shared.WirusHub.SignalSpoofer.GetSpoofTable

local flyCFrame = CFrame.identity

local module = {
	SetFlyCFrame = function(newCFrame)
		flyCFrame = newCFrame
	end,
	IsFlying = false,
	FlySpeed = tonumber(readfile(flySpeedPath)) or 16
}

local flyConnections = {}
local onCharacterAdded = function(character)
	character = cloneref(character)
	module.IsFlying = false
	
	local hrp = cloneref(character:WaitForChild("HumanoidRootPart", inf))
	
    local spoof = getSpoofTable(hrp, "PivotFly")

	flyCFrame = character:GetPivot()
	
	for i = 1, #flyConnections do
		flyConnections[i]:Disconnect()
	end
	table.clear(flyConnections)
	
	table.insert(flyConnections, UserInputService.InputBegan:Connect(function(input, gpe)
		if input.KeyCode == KeyCode_ToggleFly and not gpe then
			module.IsFlying = not module.IsFlying
			
			spoof.Velocity = false
            spoof.RotVelocity = false
            spoof.AssemblyLinearVelocity = false
            spoof.AssemblyAngularVelocity = false
			
			hrp.AssemblyLinearVelocity = ZeroVector3
			hrp.AssemblyAngularVelocity = ZeroVector3
			
			spoof.Velocity = true
            spoof.RotVelocity = true
            spoof.AssemblyLinearVelocity = true
            spoof.AssemblyAngularVelocity = true
		end
	end))
	
	table.insert(flyConnections, RunService.Heartbeat:Connect(function(delta)
		local adjustedFlySpeed = module.FlySpeed * delta

		local camera = cloneref(workspace.CurrentCamera).CFrame
		if forward then
			flyCFrame += camera.LookVector * adjustedFlySpeed
		end
		if backward then
			flyCFrame -= camera.LookVector * adjustedFlySpeed
		end
		if right then
			flyCFrame += camera.RightVector * adjustedFlySpeed
		end
		if left then
			flyCFrame -= camera.RightVector * adjustedFlySpeed
		end
		if up then
			flyCFrame += camera.UpVector * adjustedFlySpeed
		end
		if down then
			flyCFrame -= camera.UpVector * adjustedFlySpeed
		end
		
		if module.IsFlying and isnetworkowner(hrp) and not hrp:IsGrounded() then
			spoof.CFrame = false
			character:PivotTo(flyCFrame)
			spoof.CFrame = true
		else
			flyCFrame = character:GetPivot()
		end
	end))
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if not gpe then
		local inputCode = input.KeyCode
		if inputCode == KeyCode_Forward then
			forward = true
		elseif inputCode == KeyCode_Backward then
			backward = true
		elseif inputCode == KeyCode_Left then
			left = true
		elseif inputCode == KeyCode_Right then
			right = true
		elseif inputCode == KeyCode_Up then
			up = true
		elseif inputCode == KeyCode_Down then
			down = true
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local inputCode = input.KeyCode
	if inputCode == KeyCode_Forward then
		forward = false
	elseif inputCode == KeyCode_Backward then
		backward = false
	elseif inputCode == KeyCode_Left then
		left = false
	elseif inputCode == KeyCode_Right then
		right = false
	elseif inputCode == KeyCode_Up then
		up = false
	elseif inputCode == KeyCode_Down then
		down = false
	end
end)

module.OnCommand = function(command, ...)
	if module.IsFlying then
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local spoof = getSpoofTable(hrp, "PivotFly2")
				
				spoof.Velocity = false
				spoof.RotVelocity = false
				spoof.AssemblyLinearVelocity = false
				spoof.AssemblyAngularVelocity = false
				
				hrp.AssemblyLinearVelocity = ZeroVector3
				hrp.AssemblyAngularVelocity = ZeroVector3
				
				spoof.Velocity = true
				spoof.RotVelocity = true
				spoof.AssemblyLinearVelocity = true
				spoof.AssemblyAngularVelocity = true
			end
		end
	end
	if command == "fly" then
		module.IsFlying = true
	elseif command == "unfly" then
		module.IsFlying = false
	elseif command == "togglefly" then
		module.IsFlying = not module.IsFlying
	elseif command == "flyspeed" then
		local strSpeed = select(1, ...)
		local speed = tonumber(strSpeed)
		if speed then
			module.FlySpeed = speed
			writefile(flySpeedPath, strSpeed)
		end
	end
end

do
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		onCharacterAdded(character)
	end
end

player.CharacterAdded:Connect(onCharacterAdded)

return module