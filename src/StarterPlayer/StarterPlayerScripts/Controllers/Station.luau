-- Locks the character to a station on a moving ship (helm or cannon) and turns
-- the normal walking controls off while you're there.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Station = {}

local player = Players.LocalPlayer
local controls: any = nil
local lockConnection: RBXScriptConnection? = nil

local function getControls(): any
	if controls == nil then
		pcall(function()
			local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
			controls = playerModule:GetControls()
		end)
	end
	return controls
end

function Station.SetControlsEnabled(enabled: boolean)
	local c = getControls()
	if c then
		pcall(function()
			if enabled then
				c:Enable()
			else
				c:Disable()
			end
		end)
	end
end

-- Height of the HumanoidRootPart above the floor for this avatar
function Station.RootHeight(): number
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return 3
	end
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return 3
	end
	return humanoid.HipHeight + root.Size.Y / 2
end

-- Every physics step, put the character at getCFrame() and give it the ship's velocity
function Station.Lock(getCFrame: () -> CFrame?, getVelocity: () -> Vector3)
	Station.Unlock()
	lockConnection = RunService.PreSimulation:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local cf = getCFrame()
		if root and root:IsA("BasePart") and cf then
			root.CFrame = cf
			root.AssemblyLinearVelocity = getVelocity()
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

function Station.Unlock()
	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end
end

return Station
