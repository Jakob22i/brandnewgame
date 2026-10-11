-- Keeps you moving with the ship while you're in the air above its deck (jumping),
-- so you don't get left behind by a sailing ship.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Util = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"))

local State = require(script.Parent.State)

local ShipRider = {}

local player = Players.LocalPlayer

function ShipRider.Init()
	local lastShip: Model? = nil
	local lastCFrame: CFrame? = nil
	local wasAirborne = false
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	RunService.PreSimulation:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local shipsFolder = workspace:FindFirstChild("Ships")
		if not humanoid or not root or not root:IsA("BasePart") or not shipsFolder or State.Mode ~= nil then
			lastShip, lastCFrame = nil, nil
			return
		end
		params.FilterDescendantsInstances = { shipsFolder }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -16, 0), params)
		local ship = if hit then Util.FindShipModel(hit.Instance) else nil
		local shipRoot = ship and ship.PrimaryPart
		if not ship or not shipRoot then
			lastShip, lastCFrame, wasAirborne = nil, nil, false
			return
		end
		local airborne = humanoid.FloorMaterial == Enum.Material.Air
		if airborne and ship == lastShip and lastCFrame then
			if not wasAirborne then
				-- leaving the deck: keep only our own velocity relative to the ship
				local v = root.AssemblyLinearVelocity - shipRoot.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(v.X, root.AssemblyLinearVelocity.Y, v.Z)
			end
			local delta = shipRoot.CFrame * lastCFrame:Inverse()
			root.CFrame = delta * root.CFrame
		end
		wasAirborne = airborne
		lastShip = ship
		lastCFrame = shipRoot.CFrame
	end)
end

return ShipRider
