-- Treasure chests you can pick up, carry, stash on your ship, lose overboard,
-- or have stolen by other pirates. Sell them at the Merchant in Kingshaven.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CarryService = {}

local chestTemplates = ServerStorage:WaitForChild("Chests")
local treasureFolder = workspace:WaitForChild("Treasure")

local carried: { [Player]: Model } = {}
local carrierOf: { [Model]: Player } = {}

local function bodyOf(chest: Model): BasePart
	return chest.PrimaryPart :: BasePart
end

local function detach(chest: Model)
	local body = bodyOf(chest)
	for _, name in { "CarryWeld", "ShipWeld" } do
		local weld = body:FindFirstChild(name)
		if weld then
			weld:Destroy()
		end
	end
end

-- mode: "Carried" | "Ground" | "Ship" | "Float"
local function setMode(chest: Model, mode: string)
	local body = bodyOf(chest)
	for _, part in chest:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = mode ~= "Carried"
			part.Massless = part ~= body or mode ~= "Ground"
			part.CollisionGroup = if mode == "Ship" then "Ships" else "Default"
		end
	end
	body.Anchored = mode == "Ground" or mode == "Float"
	chest:SetAttribute("Mode", mode)
	if mode == "Ground" or mode == "Float" then
		chest:SetAttribute("LooseSince", os.clock())
	else
		chest:SetAttribute("LooseSince", nil)
	end
end

local function yawOf(cf: CFrame): CFrame
	local look = cf.LookVector
	return CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
end

function CarryService.Float(chest: Model, position: Vector3)
	detach(chest)
	local body = bodyOf(chest)
	body.Anchored = true
	body.CFrame = CFrame.new(position.X, Config.WaterLevel + 0.1, position.Z)
		* CFrame.Angles(0, math.random() * math.pi * 2, 0)
		* CFrame.Angles(math.rad(math.random(-8, 8)), 0, math.rad(math.random(-8, 8)))
	setMode(chest, "Float")
	chest.Parent = treasureFolder
end

-- Put a chest down near `cf`: on a ship deck (welded, so it sails along), on the
-- ground, or floating in the sea.
function CarryService.Place(chest: Model, cf: CFrame, ignore: { Instance }?)
	detach(chest)
	local body = bodyOf(chest)
	body.Anchored = true
	local exclude: { Instance } = { chest, workspace:WaitForChild("Effects"), workspace:WaitForChild("Nature"), workspace:WaitForChild("Enemies") }
	if ignore then
		for _, inst in ignore do
			table.insert(exclude, inst)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false
	local start = cf.Position + Vector3.new(0, 3, 0)
	local result = workspace:Raycast(start, Vector3.new(0, -80, 0), params)
	if not result or result.Material == Enum.Material.Water then
		CarryService.Float(chest, cf.Position)
		return
	end
	local half = body.Size.Y / 2
	body.CFrame = CFrame.new(result.Position + Vector3.new(0, half, 0)) * yawOf(cf)
	local shipModel = Util.FindShipModel(result.Instance)
	if shipModel and not shipModel:GetAttribute("Sinking") then
		setMode(chest, "Ship")
		local weld = Instance.new("WeldConstraint")
		weld.Name = "ShipWeld"
		weld.Part0 = result.Instance
		weld.Part1 = body
		weld.Parent = body
		chest.Parent = shipModel:FindFirstChild("Cargo") or shipModel
	else
		setMode(chest, "Ground")
		chest.Parent = treasureFolder
	end
end

local function setupChest(chest: Model)
	local body = bodyOf(chest)
	local value = chest:GetAttribute("Value") or 0
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = ("%s (%sg)"):format(tostring(chest:GetAttribute("DisplayName")), Util.FormatNumber(value))
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	-- every chest glints so pirates can spot it on a beach or bobbing in the waves
	if not body:FindFirstChild("Sparkle") then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkle"
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Rate = 3
		sparkle.Lifetime = NumberRange.new(0.6, 1.2)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.Size = NumberSequence.new(0.5, 0)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140))
		sparkle.LightEmission = 1
		sparkle.Parent = body
	end
	prompt.Triggered:Connect(function(player)
		CarryService.PickUp(player, chest)
	end)
end

function CarryService.SpawnChest(tier: string, position: Vector3): Model?
	local template = chestTemplates:FindFirstChild(tier)
	if not template or not template:IsA("Model") then
		warn("[CarryService] Unknown chest tier", tier)
		return nil
	end
	local chest = template:Clone()
	setupChest(chest)
	chest.Parent = treasureFolder
	CarryService.Place(chest, CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	return chest
end

function CarryService.GetCarried(player: Player): Model?
	return carried[player]
end

function CarryService.PickUp(player: Player, chest: Model)
	if carried[player] or carrierOf[chest] or not chest.Parent then
		return
	end
	if player:GetAttribute("Station") then
		Net.Notify(player, "Leave the helm or cannon first.", "bad")
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	local body = bodyOf(chest)
	if (body.Position - root.Position).Magnitude > 14 then
		return
	end
	detach(chest)
	setMode(chest, "Carried")
	chest.Parent = treasureFolder
	local offset = CFrame.new(0, 0.3, -(1.2 + body.Size.Z / 2))
	body.CFrame = root.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = body
	weld.C0 = offset
	weld.Parent = body
	body.Anchored = false
	carried[player] = chest
	carrierOf[chest] = player
	local prompt = body:FindFirstChild("PickupPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end
	humanoid:UnequipTools()
	local tier = chest:GetAttribute("Tier")
	local def = Config.Chests[tier :: string]
	humanoid.WalkSpeed = if def then def.WalkSpeed else Config.CarryWalkSpeed
	player:SetAttribute("CarryingTier", tier)
	player:SetAttribute("CarryingValue", chest:GetAttribute("Value"))
end

-- Drop whatever the player carries. atFeet = drop right where they stand (on death).
function CarryService.Drop(player: Player, atFeet: boolean?)
	local chest = carried[player]
	if not chest then
		return
	end
	carried[player] = nil
	carrierOf[chest] = nil
	player:SetAttribute("CarryingTier", nil)
	player:SetAttribute("CarryingValue", nil)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = Config.DefaultWalkSpeed
	end
	local body = bodyOf(chest)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = if root and root:IsA("BasePart") then root.CFrame else body.CFrame
	local target = if atFeet then origin else origin * CFrame.new(0, 0, -3)
	CarryService.Place(chest, target, if character then { character } else nil)
	local prompt = body:FindFirstChild("PickupPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = true
	end
end

-- Removes the carried chest (used when selling). Returns tier and value.
function CarryService.TakeCarried(player: Player): (string?, number)
	local chest = carried[player]
	if not chest then
		return nil, 0
	end
	local tier = chest:GetAttribute("Tier") :: string
	local value = chest:GetAttribute("Value") or 0
	carried[player] = nil
	carrierOf[chest] = nil
	player:SetAttribute("CarryingTier", nil)
	player:SetAttribute("CarryingValue", nil)
	chest:Destroy()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = Config.DefaultWalkSpeed
	end
	return tier, value
end

-- A ship is sinking or being removed: all its cargo floats up to the surface
function CarryService.ReleaseCargo(shipModel: Model)
	local cargo = shipModel:FindFirstChild("Cargo")
	if not cargo then
		return
	end
	for _, chest in cargo:GetChildren() do
		if chest:IsA("Model") and chest.PrimaryPart then
			local pos = chest.PrimaryPart.Position
			CarryService.Float(chest, pos + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)))
		end
	end
end

function CarryService.Init()
	local function watchCharacter(player: Player, character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and carried[player] then
				task.defer(function()
					local backpack = player:FindFirstChildOfClass("Backpack")
					if backpack and child.Parent == character then
						child.Parent = backpack
					end
				end)
			end
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			watchCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		CarryService.Drop(player, true)
	end)
	Net.Event("TreasureAction").OnServerEvent:Connect(function(player, action)
		if action == "Drop" then
			CarryService.Drop(player)
		end
	end)
	-- tidy up chests nobody wants
	task.spawn(function()
		while true do
			task.wait(30)
			local now = os.clock()
			for _, chest in treasureFolder:GetChildren() do
				local since = chest:GetAttribute("LooseSince")
				if chest:IsA("Model") and not carrierOf[chest] and since and now - since > Config.LooseChestLifetime then
					chest:Destroy()
				end
			end
		end
	end)
end

function CarryService.CountLoose(tag: string?): number
	local count = 0
	for _, chest in treasureFolder:GetChildren() do
		if chest:IsA("Model") and not carrierOf[chest] and (tag == nil or chest:GetAttribute(tag)) then
			count += 1
		end
	end
	return count
end

return CarryService
