local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))

local PACKAGE = select(1, ...)

local ZeroVector3 = Vector3.zero
local inf = math.huge

local walkSpeedPath = PACKAGE.Path .. "\\walkspeed.txt"

if isfolder(walkSpeedPath) then
	error("[Wirus Hub] " .. walkSpeedPath .. " already exists as a folder. PivotWalkSpeed cannot continue.")
elseif not isfile(walkSpeedPath) then
	writefile(walkSpeedPath, 16)
end

local getSpoofTable = shared.WirusHub.SignalSpoofer.GetSpoofTable

local player = cloneref(Players.LocalPlayer or Players.PlayerAdded:Wait())

local WaitForChildWhichIsA = function(self, class)
	local found = self:FindFirstChildWhichIsA(class)
	if found then
		return found
	end
	local thread = coroutine.running()
	local connection
	connection = self.ChildAdded:Connect(function(child)
		if child:IsA(class) then
			connection:Disconnect()
			return assert(coroutine.resume(thread, child))
		end
	end)
	return coroutine.yield()
end

local module = {
	WalkSpeedActive = false,
	WalkSpeed = tonumber(readfile(walkSpeedPath)) or 16
}

local KeyCode_TOGGLEWALKSPEED = Enum.KeyCode.F3

local walkSpeedConnections = {}
local onCharacterAdded = function(character)
	character = cloneref(character)
	module.WalkSpeedActive = false
	
	for i = 1, #walkSpeedConnections do
		walkSpeedConnections[i]:Disconnect()
	end
	table.clear(walkSpeedConnections)
	
	local humanoid = cloneref(WaitForChildWhichIsA(character, "Humanoid"))
	local hrp = cloneref(character:WaitForChild("HumanoidRootPart", inf))
	if humanoid and hrp then
		local spoof = getSpoofTable(hrp, "PivotWalkSpeed")
		table.insert(walkSpeedConnections, RunService.Heartbeat:Connect(function(delta)
			if humanoid and hrp and module.WalkSpeedActive and isnetworkowner(hrp) and not hrp:IsGrounded() then
				local direction = humanoid.MoveDirection
				if direction ~= ZeroVector3 then
					local adjustedWalkSpeed = (module.WalkSpeed - humanoid.WalkSpeed) * delta
					local characterCFrame = character:GetPivot()
					--local params = RaycastParams.new()
					--params.FilterDescendantsInstances = {character}
					--params.CollisionGroup = hrp.CollisionGroup
					--params.RespectCanCollide = true
					--local result = workspace:Raycast(characterCFrame.Position, direction * adjustedWalkSpeed, params)
					local cframe
					--if result then
					--	cframe = characterCFrame - characterCFrame.Position + result.Position
					--else
						cframe = characterCFrame + direction * adjustedWalkSpeed
					--end
					--can't get the raycasting to work right, you'll ahve to deal with clipping into walls
					spoof.CFrame = false
					character:PivotTo(cframe)
					spoof.CFrame = true
				end
			end
		end))
		
		table.insert(walkSpeedConnections, UserInputService.InputBegan:Connect(function(input, gpe)
			if input.KeyCode == KeyCode_TOGGLEWALKSPEED and not gpe then
				module.WalkSpeedActive = not module.WalkSpeedActive
			end
		end))
	end
end

module.OnCommand = function(command, ...)
	if command == "walkspeed" then
		local stringWs = select(1, ...) --ARGH! I HATE HIDDEN NILS!
		local ws = tonumber(stringWs)
		if ws then
			module.WalkSpeed = ws
			writefile(walkSpeedPath, stringWs)
		end
		module.WalkSpeedActive = true
	elseif command == "unwalkspeed" then
		module.WalkSpeedActive = false
	elseif command == "togglewalkspeed" then
		module.WalkSpeedActive = not module.WalkSpeedActive
	end
end

do
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChildWhichIsA("Humanoid") then
		onCharacterAdded(character)
	end
end

player.CharacterAdded:Connect(onCharacterAdded)

return module