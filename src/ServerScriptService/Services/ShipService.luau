-- Ships: launching from the harbour, sailing (helm, sails, anchor, wind), cannons,
-- hull damage + repairs, sinking.
--
-- Physics: the hull is one unanchored assembly held by rigid AlignPosition/AlignOrientation
-- constraints. The server integrates simple sailing physics every frame and moves the
-- align targets, so pirates standing on deck are carried along by the physics engine.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Heightmap = require(Shared:WaitForChild("Heightmap"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local CarryService = require(script.Parent.CarryService)
local CombatService = require(script.Parent.CombatService)
local CrewService = require(script.Parent.CrewService)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local ShipService = {}

local WATER = Config.WaterLevel
local Sailing = Config.Sailing

type Cannon = {
	Model: Model,
	Carriage: BasePart,
	AimWeld: Weld,
	BaseC0: CFrame,
	Prompt: ProximityPrompt,
	OperatorPoint: Attachment,
	MuzzleOffset: number,
	Operator: Player?,
	Yaw: number,
	Pitch: number,
	LastFire: number,
	AimDirty: boolean,
}

type SailInfo = { Part: BasePart, Weld: Weld, Full: number, Gap: number, ZOffset: number }

export type Ship = {
	Id: number,
	Model: Model,
	Def: Config.ShipDef,
	Owner: Player,
	Root: BasePart,
	AlignPos: AlignPosition,
	AlignOri: AlignOrientation,
	Position: Vector3,
	Yaw: number,
	Speed: number,
	Rudder: number,
	Sail: number,
	SailTarget: number,
	Anchored: boolean,
	HP: number,
	Helmsman: Player?,
	Input: { Turn: number, Sail: number },
	HelmPost: BasePart,
	HelmPrompt: ProximityPrompt,
	WheelWeld: Weld?,
	WheelBaseC0: CFrame,
	Sails: { SailInfo },
	SailPrompts: { ProximityPrompt },
	AnchorPrompt: ProximityPrompt?,
	AnchorWeld: Weld?,
	AnchorBaseC0: CFrame,
	Cannons: { Cannon },
	HoleSpots: { Attachment },
	Holes: { [Attachment]: BasePart },
	Sinking: boolean,
	SinkStart: number,
	LastAttacker: Player?,
	LastAttackTime: number,
	BobPhase: number,
	VisualSail: number,
	VisualRudder: number,
	LastAttributes: number,
	LastWarn: number,
	LastRam: number,
	LastAutoRepair: number,
	Destroyed: boolean,
}

local ships: { [Model]: Ship } = {}
local shipByOwner: { [Player]: Ship } = {}
local helmOf: { [Player]: Ship } = {}
local cannonOf: { [Player]: { Ship: Ship, Cannon: Cannon } } = {}
local nextId = 1
local shipsFolder = workspace:WaitForChild("Ships")
local templates = ServerStorage:WaitForChild("Ships")

type Projectile = { Pos: Vector3, Vel: Vector3, Age: number, Shooter: Player?, Ship: Ship?, Params: RaycastParams }
local projectiles: { Projectile } = {}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function forwardOf(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function crewOf(ship: Ship): { Player }
	return CrewService.GetMembers(ship.Owner)
end

local function notifyCrew(ship: Ship, text: string, kind: string?)
	for _, member in crewOf(ship) do
		Net.Notify(member, text, kind)
	end
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Samples along the centre line of a ship (used for spacing and collisions)
local function centerLine(position: Vector3, yaw: number, length: number): { Vector3 }
	local f = forwardOf(yaw)
	local points = {}
	for _, t in { -0.42, -0.2, 0, 0.2, 0.42 } do
		table.insert(points, position + f * (t * length))
	end
	return points
end

local function closestPoints(a: { Vector3 }, b: { Vector3 }): (number, Vector3, Vector3)
	local best, pa, pb = math.huge, a[1], b[1]
	for _, p in a do
		for _, q in b do
			local dx, dz = p.X - q.X, p.Z - q.Z
			local d = math.sqrt(dx * dx + dz * dz)
			if d < best then
				best, pa, pb = d, p, q
			end
		end
	end
	return best, pa, pb
end

local function isBlocked(point: Vector3, draft: number): boolean
	if Heightmap.GetHeight(point.X, point.Z) > -draft then
		return true
	end
	for _, pier in WorldData.Piers do
		if math.abs(point.X - pier.X) < pier.HalfWidth + 1.5 and point.Z > pier.MinZ - 4 and point.Z < pier.MaxZ + 3 then
			return true
		end
	end
	return false
end

local function spotIsFree(position: Vector3, yaw: number, def: Config.ShipDef): boolean
	local line = centerLine(position, yaw, def.Length)
	for _, other in ships do
		if not other.Destroyed then
			local d = closestPoints(line, centerLine(other.Position, other.Yaw, other.Def.Length))
			if d < (def.Width + other.Def.Width) / 2 + 3 then
				return false
			end
		end
	end
	return true
end

local function findSpawnSpot(def: Config.ShipDef): (number?, number?, number?)
	for index in WorldData.DockSlots do
		local x, z, yaw = WorldData.GetSlotPosition(index, def.Width)
		if spotIsFree(Vector3.new(x, 0, z), yaw, def) then
			return x, z, yaw
		end
	end
	for _, slot in WorldData.AnchorageSlots do
		if spotIsFree(Vector3.new(slot.X, 0, slot.Z), math.pi, def) then
			return slot.X, slot.Z, math.pi
		end
	end
	return nil, nil, nil
end

local function setPromptText(ship: Ship)
	for _, prompt in ship.SailPrompts do
		prompt.ActionText = if ship.SailTarget > 0.5 then "Raise Sails" else "Lower Sails"
	end
	if ship.AnchorPrompt then
		ship.AnchorPrompt.ActionText = if ship.Anchored then "Raise Anchor" else "Drop Anchor"
		ship.AnchorPrompt.HoldDuration = if ship.Anchored then 1.0 else 0.25
	end
end

local function updateSails(ship: Ship)
	for _, sail in ship.Sails do
		local height = 1.4 + (sail.Full - 1.4) * ship.Sail
		sail.Part.Size = Vector3.new(sail.Part.Size.X, height, sail.Part.Size.Z)
		sail.Weld.C0 = CFrame.new(0, -(sail.Gap + height / 2), sail.ZOffset)
	end
	ship.VisualSail = ship.Sail
end

local function updateAnchorVisual(ship: Ship)
	if ship.AnchorWeld then
		ship.AnchorWeld.C0 = ship.AnchorBaseC0 * (if ship.Anchored then CFrame.new(0, -9, 0) else CFrame.new())
	end
end

local function updateAttributes(ship: Ship)
	local model = ship.Model
	local holes = 0
	for _ in ship.Holes do
		holes += 1
	end
	model:SetAttribute("HP", math.max(0, math.floor(ship.HP)))
	model:SetAttribute("Sail", math.floor(ship.Sail * 100 + 0.5) / 100)
	model:SetAttribute("Speed", math.floor(ship.Speed * 10) / 10)
	model:SetAttribute("Rudder", math.floor(ship.Rudder * 100) / 100)
	model:SetAttribute("Anchored", ship.Anchored)
	model:SetAttribute("Holes", holes)
	model:SetAttribute("Helmsman", if ship.Helmsman then ship.Helmsman.UserId else 0)
end

-------------------------------------------------------------------------------
-- Stations (helm / cannons)
-------------------------------------------------------------------------------

local function releaseHelm(ship: Ship)
	local player = ship.Helmsman
	ship.Helmsman = nil
	ship.Input.Turn = 0
	ship.Input.Sail = 0
	if ship.HelmPrompt.Parent then
		ship.HelmPrompt.Enabled = true
	end
	if player then
		helmOf[player] = nil
		player:SetAttribute("Station", nil)
		if player.Parent then
			Net.Event("ShipClient"):FireClient(player, "ExitHelm")
		end
	end
end

local function releaseCannon(cannon: Cannon)
	local player = cannon.Operator
	cannon.Operator = nil
	if cannon.Prompt.Parent then
		cannon.Prompt.Enabled = true
	end
	if player then
		cannonOf[player] = nil
		player:SetAttribute("Station", nil)
		if player.Parent then
			Net.Event("ShipClient"):FireClient(player, "ExitCannon")
		end
	end
end

function ShipService.ReleasePlayer(player: Player)
	local ship = helmOf[player]
	if ship then
		releaseHelm(ship)
	end
	local station = cannonOf[player]
	if station then
		releaseCannon(station.Cannon)
	end
end

local function canUseStation(player: Player): boolean
	if not CombatService.IsAlive(player) then
		return false
	end
	if helmOf[player] or cannonOf[player] then
		return false
	end
	if CarryService.GetCarried(player) then
		Net.Notify(player, "Put the treasure down first!", "bad")
		return false
	end
	return true
end

local function applyAim(cannon: Cannon)
	cannon.AimWeld.C0 = cannon.BaseC0 * CFrame.Angles(0, cannon.Yaw, 0) * CFrame.Angles(cannon.Pitch, 0, 0)
	cannon.AimDirty = false
end

-------------------------------------------------------------------------------
-- Damage, holes, sinking
-------------------------------------------------------------------------------

local function destroyShip(ship: Ship)
	if ship.Destroyed then
		return
	end
	ship.Destroyed = true
	ships[ship.Model] = nil
	if shipByOwner[ship.Owner] == ship then
		shipByOwner[ship.Owner] = nil
	end
	ship.Model:Destroy()
end

local function startSinking(ship: Ship)
	if ship.Sinking then
		return
	end
	ship.Sinking = true
	ship.SinkStart = os.clock()
	ship.HP = 0
	ship.Model:SetAttribute("Sinking", true)
	updateAttributes(ship)
	if ship.Helmsman then
		releaseHelm(ship)
	end
	for _, cannon in ship.Cannons do
		releaseCannon(cannon)
	end
	CarryService.ReleaseCargo(ship.Model)
	for _, part in ship.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
		elseif part:IsA("ProximityPrompt") then
			part.Enabled = false
		end
	end
	if shipByOwner[ship.Owner] == ship then
		shipByOwner[ship.Owner] = nil
	end
	notifyCrew(ship, "Your ship is sinking! Visit the Shipwright to launch a new one.", "bad")
	local attacker = ship.LastAttacker
	if attacker and attacker.Parent and os.clock() - ship.LastAttackTime < 60 and not CrewService.AreAllies(attacker, ship.Owner) then
		DataService.AddStat(attacker, "ShipsSunk")
		DataService.AddGold(attacker, Config.SinkReward, "for sinking a ship!")
		Net.NotifyAll(("%s sank %s's %s!"):format(attacker.DisplayName, ship.Owner.DisplayName, ship.Def.DisplayName), "warn")
	end
end

local function removeHole(ship: Ship, spot: Attachment)
	local hole = ship.Holes[spot]
	if hole then
		ship.Holes[spot] = nil
		hole:Destroy()
	end
end

local function addHole(ship: Ship, near: Vector3?)
	local count = 0
	for _ in ship.Holes do
		count += 1
	end
	if count >= Config.Holes.MaxHoles then
		return
	end
	local free = {}
	for _, spot in ship.HoleSpots do
		if not ship.Holes[spot] then
			table.insert(free, spot)
		end
	end
	if #free == 0 then
		return
	end
	local spot = free[math.random(1, #free)]
	if near then
		local best = math.huge
		for _, candidate in free do
			local d = (candidate.WorldPosition - near).Magnitude + math.random() * 6
			if d < best then
				best, spot = d, candidate
			end
		end
	end
	local holesFolder = ship.Model:FindFirstChild("Holes") or ship.Model
	local hole = Instance.new("Part")
	hole.Name = "Hole"
	hole.Shape = Enum.PartType.Cylinder
	hole.Size = Vector3.new(0.25, 3.2, 3.2)
	hole.CFrame = spot.WorldCFrame * CFrame.Angles(0, 0, math.pi / 2)
	hole.Color = Color3.fromRGB(26, 18, 12)
	hole.Material = Enum.Material.WoodPlanks
	hole.CanCollide = false
	hole.Massless = true
	hole.CollisionGroup = "Ships"
	hole.Parent = holesFolder
	for i = 1, 3 do
		local splinter = Instance.new("WedgePart")
		splinter.Name = "Splinter"
		splinter.Size = Vector3.new(0.4, 0.8, 1.6)
		splinter.CFrame = spot.WorldCFrame * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0, 0.3, -1.6) * CFrame.Angles(math.rad(-30), 0, 0)
		splinter.Color = Color3.fromRGB(150, 108, 66)
		splinter.Material = Enum.Material.Wood
		splinter.CanCollide = false
		splinter.Massless = true
		splinter.CollisionGroup = "Ships"
		splinter.Parent = hole
		local w = Instance.new("WeldConstraint")
		w.Part0 = hole
		w.Part1 = splinter
		w.Parent = splinter
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ship.Root
	weld.Part1 = hole
	weld.Parent = hole
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 240, 255))
	spray.Size = NumberSequence.new(0.6, 1.6)
	spray.Transparency = NumberSequence.new(0.3, 1)
	spray.Lifetime = NumberRange.new(0.5, 0.9)
	spray.Speed = NumberRange.new(5, 9)
	spray.SpreadAngle = Vector2.new(20, 20)
	spray.Acceleration = Vector3.new(0, -25, 0)
	spray.Rate = 25
	spray.EmissionDirection = Enum.NormalId.Right
	spray.Parent = hole
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RepairPrompt"
	prompt.ActionText = "Repair Hole"
	prompt.ObjectText = "Leak!"
	prompt.HoldDuration = Config.Holes.RepairTime
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = hole
	prompt.Triggered:Connect(function(player)
		if ship.Holes[spot] == hole and CombatService.IsAlive(player) and not ship.Sinking then
			removeHole(ship, spot)
			ship.HP = math.min(ship.Def.MaxHP, ship.HP + Config.Holes.RepairHeal)
			Net.Notify(player, "Hole patched!", "good")
			updateAttributes(ship)
		end
	end)
	ship.Holes[spot] = hole
	if count == 0 then
		notifyCrew(ship, "We're taking on water! Repair the holes on deck!", "warn")
	end
end

function ShipService.Damage(ship: Ship, amount: number, attacker: Player?, hitPosition: Vector3?, makeHole: boolean?)
	if ship.Sinking or ship.Destroyed then
		return
	end
	if Util.InSafeZone(ship.Root.Position) then
		return
	end
	ship.HP -= amount
	if attacker then
		ship.LastAttacker = attacker
		ship.LastAttackTime = os.clock()
	end
	if makeHole then
		addHole(ship, hitPosition)
	end
	if ship.HP <= 0 then
		startSinking(ship)
	else
		updateAttributes(ship)
	end
end

-------------------------------------------------------------------------------
-- Cannons
-------------------------------------------------------------------------------

local function explode(p: Projectile, position: Vector3, hit: Instance?, isWater: boolean)
	local fx = Net.Event("Fx")
	if isWater then
		fx:FireAllClients("Splash", position)
	else
		local explosion = Instance.new("Explosion")
		explosion.Position = position
		explosion.BlastRadius = Config.Cannon.BlastRadius
		explosion.BlastPressure = 0
		explosion.DestroyJointRadiusPercent = 0
		explosion.ExplosionType = Enum.ExplosionType.NoCraters
		explosion.Parent = workspace
	end
	if hit then
		local shipModel = Util.FindShipModel(hit)
		local target = shipModel and ships[shipModel]
		if target and target ~= p.Ship and not (p.Shooter and CrewService.AreAllies(p.Shooter, target.Owner)) then
			ShipService.Damage(target, Config.Cannon.ShipDamage, p.Shooter, position, true)
		end
	end
	local overlap = OverlapParams.new()
	local radius = Config.Cannon.BlastRadius
	local damaged: { [Humanoid]: boolean } = {}
	for _, part in workspace:GetPartBoundsInRadius(position, radius, overlap) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and not damaged[humanoid] then
			damaged[humanoid] = true
			local root = model:FindFirstChild("HumanoidRootPart")
			local dist = if root and root:IsA("BasePart") then (root.Position - position).Magnitude else radius / 2
			local falloff = 1 - math.clamp(dist / radius, 0, 1) * 0.6
			CombatService.DamageHumanoid(p.Shooter, humanoid, Config.Cannon.PlayerDamage * falloff)
		end
	end
end

local function fireCannon(ship: Ship, cannon: Cannon, player: Player)
	local now = os.clock()
	if now - cannon.LastFire < Config.Cannon.Cooldown or ship.Sinking then
		return
	end
	cannon.LastFire = now
	applyAim(cannon)
	local pivotCF = cannon.Carriage.CFrame * cannon.BaseC0 * CFrame.Angles(0, cannon.Yaw, 0) * CFrame.Angles(cannon.Pitch, 0, 0)
	local muzzle = pivotCF * CFrame.new(0, 0, -cannon.MuzzleOffset)
	local velocity = muzzle.LookVector * Config.Cannon.Speed + ship.Root.AssemblyLinearVelocity
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { ship.Model, workspace:WaitForChild("Effects") }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	table.insert(projectiles, { Pos = muzzle.Position, Vel = velocity, Age = 0, Shooter = player, Ship = ship, Params = params })
	Net.Event("Fx"):FireAllClients("Cannon", muzzle.Position, velocity, Config.Cannon.Gravity, ship.Model)
end

local function stepProjectiles(dt: number)
	local gravity = Vector3.new(0, -Config.Cannon.Gravity, 0)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		p.Age += dt
		local newVel = p.Vel + gravity * dt
		local newPos = p.Pos + p.Vel * dt + gravity * (0.5 * dt * dt)
		local result = workspace:Raycast(p.Pos, newPos - p.Pos, p.Params)
		if result then
			explode(p, result.Position, result.Instance, result.Material == Enum.Material.Water)
			table.remove(projectiles, i)
		elseif newPos.Y <= WATER then
			local t = (p.Pos.Y - WATER) / math.max(p.Pos.Y - newPos.Y, 1e-3)
			explode(p, p.Pos:Lerp(newPos, math.clamp(t, 0, 1)), nil, true)
			table.remove(projectiles, i)
		elseif p.Age > Config.Cannon.Lifetime then
			table.remove(projectiles, i)
		else
			p.Pos = newPos
			p.Vel = newVel
		end
	end
end

-------------------------------------------------------------------------------
-- Spawning
-------------------------------------------------------------------------------

local function findAll(model: Instance, name: string, className: string?): { Instance }
	local list = {}
	for _, d in model:GetDescendants() do
		if d.Name == name and (className == nil or d:IsA(className)) then
			table.insert(list, d)
		end
	end
	return list
end

local function setupPrompts(ship: Ship)
	ship.HelmPrompt.Triggered:Connect(function(player)
		if ship.Sinking then
			return
		end
		if ship.Helmsman then
			Net.Notify(player, ship.Helmsman.DisplayName .. " is already at the helm.", "info")
			return
		end
		if not canUseStation(player) then
			return
		end
		ship.Helmsman = player
		helmOf[player] = ship
		player:SetAttribute("Station", "Helm")
		ship.HelmPrompt.Enabled = false
		updateAttributes(ship)
		Net.Event("ShipClient"):FireClient(player, "EnterHelm", ship.Model)
	end)
	for _, prompt in ship.SailPrompts do
		prompt.Triggered:Connect(function(player)
			if ship.Sinking or not CombatService.IsAlive(player) then
				return
			end
			ship.SailTarget = if ship.SailTarget > 0.5 then 0 else 1
			setPromptText(ship)
		end)
	end
	if ship.AnchorPrompt then
		ship.AnchorPrompt.Triggered:Connect(function(player)
			if ship.Sinking or not CombatService.IsAlive(player) then
				return
			end
			ship.Anchored = not ship.Anchored
			setPromptText(ship)
			updateAnchorVisual(ship)
			updateAttributes(ship)
			if ship.Anchored then
				Net.Event("Fx"):FireAllClients("Splash", ship.Root.Position + forwardOf(ship.Yaw) * (ship.Def.Length * 0.3))
			end
		end)
	end
	for _, cannon in ship.Cannons do
		cannon.Prompt.Triggered:Connect(function(player)
			if ship.Sinking then
				return
			end
			if cannon.Operator then
				Net.Notify(player, "Someone is already using this cannon.", "info")
				return
			end
			if not canUseStation(player) then
				return
			end
			cannon.Operator = player
			cannonOf[player] = { Ship = ship, Cannon = cannon }
			player:SetAttribute("Station", "Cannon")
			cannon.Prompt.Enabled = false
			Net.Event("ShipClient"):FireClient(player, "EnterCannon", cannon.Model, ship.Model, Config.Cannon.MaxYaw, Config.Cannon.MinPitch, Config.Cannon.MaxPitch)
		end)
	end
end

function ShipService.Spawn(player: Player, shipType: string): (boolean, string)
	local def = Config.Ships[shipType]
	local template = templates:FindFirstChild(shipType)
	if not def or not template or not template:IsA("Model") then
		return false, "Unknown ship."
	end
	local old = shipByOwner[player]
	if old then
		ShipService.Despawn(old)
	end
	local x, z, yaw = findSpawnSpot(def)
	if not x or not z or not yaw then
		return false, "The harbour is full! Try again in a moment."
	end
	local model = template:Clone()
	local id = nextId
	nextId += 1
	model.Name = ("%s's %s"):format(player.DisplayName, def.DisplayName)
	local cf = CFrame.new(x, WATER, z) * CFrame.Angles(0, yaw, 0)
	model:PivotTo(cf)
	model:SetAttribute("ShipId", id)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	model:SetAttribute("DisplayName", def.DisplayName)
	model:SetAttribute("MaxHP", def.MaxHP)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Ships"
		end
	end

	local root = model.PrimaryPart :: BasePart
	local attachment = Instance.new("Attachment")
	attachment.Name = "ShipAlign"
	attachment.Parent = root
	local alignPos = Instance.new("AlignPosition")
	alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPos.Attachment0 = attachment
	alignPos.RigidityEnabled = true
	alignPos.Position = cf.Position
	alignPos.Parent = root
	local alignOri = Instance.new("AlignOrientation")
	alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOri.Attachment0 = attachment
	alignOri.RigidityEnabled = true
	alignOri.CFrame = cf.Rotation
	alignOri.Parent = root

	local tag = root:FindFirstChild("NameTag")
	local label = tag and tag:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = model.Name
	end

	local helmPost = model:FindFirstChild("HelmPost", true) :: BasePart
	local wheelHub = model:FindFirstChild("WheelHub", true)
	local wheelWeld = wheelHub and wheelHub:FindFirstChild("WheelWeld") :: Weld?
	local anchorRoot = model:FindFirstChild("AnchorRoot", true)
	local anchorWeld = anchorRoot and anchorRoot:FindFirstChild("AnchorWeld") :: Weld?
	local capstan = model:FindFirstChild("Capstan", true)
	local ship: Ship = {
		Id = id,
		Model = model,
		Def = def,
		Owner = player,
		Root = root,
		AlignPos = alignPos,
		AlignOri = alignOri,
		Position = Vector3.new(x, 0, z),
		Yaw = yaw,
		Speed = 0,
		Rudder = 0,
		Sail = 0,
		SailTarget = 0,
		Anchored = true,
		HP = def.MaxHP,
		Helmsman = nil,
		Input = { Turn = 0, Sail = 0 },
		HelmPost = helmPost,
		HelmPrompt = helmPost:FindFirstChild("HelmPrompt") :: ProximityPrompt,
		WheelWeld = wheelWeld,
		WheelBaseC0 = if wheelWeld then wheelWeld.C0 else CFrame.new(),
		Sails = {},
		SailPrompts = {},
		AnchorPrompt = capstan and capstan:FindFirstChild("AnchorPrompt") :: ProximityPrompt?,
		AnchorWeld = anchorWeld,
		AnchorBaseC0 = if anchorWeld then anchorWeld.C0 else CFrame.new(),
		Cannons = {},
		HoleSpots = {},
		Holes = {},
		Sinking = false,
		SinkStart = 0,
		LastAttacker = nil,
		LastAttackTime = 0,
		BobPhase = math.random() * 100,
		VisualSail = -1,
		VisualRudder = 99,
		LastAttributes = 0,
		LastWarn = 0,
		LastRam = 0,
		LastAutoRepair = 0,
		Destroyed = false,
	}
	for _, sail in findAll(model, "Sail", "BasePart") do
		local weld = sail:FindFirstChild("SailWeld")
		if weld and weld:IsA("Weld") then
			table.insert(ship.Sails, {
				Part = sail :: BasePart,
				Weld = weld,
				Full = sail:GetAttribute("FullHeight") or (sail :: BasePart).Size.Y,
				Gap = sail:GetAttribute("Gap") or 0.5,
				ZOffset = sail:GetAttribute("ZOffset") or -0.5,
			})
		end
	end
	for _, prompt in findAll(model, "SailPrompt", "ProximityPrompt") do
		table.insert(ship.SailPrompts, prompt :: ProximityPrompt)
	end
	for _, spot in findAll(root, "HoleSpot", "Attachment") do
		table.insert(ship.HoleSpots, spot :: Attachment)
	end
	local cannonsFolder = model:FindFirstChild("Cannons")
	if cannonsFolder then
		for _, cannonModel in cannonsFolder:GetChildren() do
			local carriage = cannonModel:FindFirstChild("Carriage")
			local pivot = cannonModel:FindFirstChild("Pivot")
			local aimWeld = pivot and pivot:FindFirstChild("AimWeld")
			local prompt = carriage and carriage:FindFirstChild("CannonPrompt")
			local operatorPoint = carriage and carriage:FindFirstChild("OperatorPoint")
			if cannonModel:IsA("Model") and carriage and carriage:IsA("BasePart") and aimWeld and aimWeld:IsA("Weld") and prompt and prompt:IsA("ProximityPrompt") and operatorPoint and operatorPoint:IsA("Attachment") then
				table.insert(ship.Cannons, {
					Model = cannonModel,
					Carriage = carriage,
					AimWeld = aimWeld,
					BaseC0 = aimWeld.C0,
					Prompt = prompt,
					OperatorPoint = operatorPoint,
					MuzzleOffset = (pivot :: Instance):GetAttribute("MuzzleOffset") or 3.2,
					Operator = nil,
					Yaw = 0,
					Pitch = math.rad(4),
					LastFire = 0,
					AimDirty = true,
				})
			end
		end
	end

	model.Parent = shipsFolder
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	ships[model] = ship
	shipByOwner[player] = ship
	updateSails(ship)
	updateAnchorVisual(ship)
	setPromptText(ship)
	updateAttributes(ship)
	for _, cannon in ship.Cannons do
		applyAim(cannon)
	end
	setupPrompts(ship)
	return true, ("Your %s is waiting at the dock!"):format(def.DisplayName)
end

function ShipService.Despawn(ship: Ship)
	if ship.Destroyed then
		return
	end
	if ship.Helmsman then
		releaseHelm(ship)
	end
	for _, cannon in ship.Cannons do
		releaseCannon(cannon)
	end
	CarryService.ReleaseCargo(ship.Model)
	destroyShip(ship)
end

function ShipService.GetShip(player: Player): Ship?
	local ship = shipByOwner[player]
	if ship and not ship.Destroyed and not ship.Sinking then
		return ship
	end
	return nil
end

-- The ship a player should respawn on: their own, or a crewmate's
function ShipService.GetCrewShip(player: Player): Ship?
	local own = ShipService.GetShip(player)
	if own then
		return own
	end
	for _, member in CrewService.GetMembers(player) do
		local ship = ShipService.GetShip(member)
		if ship then
			return ship
		end
	end
	return nil
end

function ShipService.GetCrewSpawn(ship: Ship): CFrame
	local spawn = ship.Root:FindFirstChild("CrewSpawn")
	if spawn and spawn:IsA("Attachment") then
		return spawn.WorldCFrame + Vector3.new(0, 3.5, 0)
	end
	return ship.Root.CFrame + Vector3.new(0, 8, 0)
end

-------------------------------------------------------------------------------
-- Simulation
-------------------------------------------------------------------------------

local function updateShip(ship: Ship, dt: number, now: number)
	local def = ship.Def
	if ship.Sinking then
		local t = now - ship.SinkStart
		local depth = math.min(t * 3.4, 70)
		local tilt = math.min(t * 0.07, 0.55)
		local cf = CFrame.new(ship.Position.X, WATER - depth, ship.Position.Z) * CFrame.Angles(0, ship.Yaw, 0) * CFrame.Angles(tilt, 0, tilt * 0.6)
		ship.AlignPos.Position = cf.Position
		ship.AlignOri.CFrame = cf.Rotation
		if t > 14 then
			destroyShip(ship)
		end
		return
	end

	-- controls
	if ship.Helmsman then
		ship.Rudder = math.clamp(ship.Rudder + ship.Input.Turn * Sailing.RudderRate * dt, -1, 1)
		if ship.Input.Sail ~= 0 then
			local before = ship.SailTarget
			ship.SailTarget = math.clamp(ship.SailTarget + ship.Input.Sail * Sailing.SailRate * dt, 0, 1)
			if (before > 0.5) ~= (ship.SailTarget > 0.5) then
				setPromptText(ship)
			end
		end
	end
	ship.Sail = Util.Approach(ship.Sail, ship.SailTarget, Sailing.SailRate * dt)

	-- speed
	local forward = forwardOf(ship.Yaw)
	local windDot = forward:Dot(WorldService.GetWind())
	local windFactor = (1 - Sailing.WindBonus) + Sailing.WindBonus * (windDot * 0.5 + 0.5)
	local target = if ship.Anchored then 0 else def.MaxSpeed * ship.Sail * windFactor
	local rate = if ship.Anchored then Sailing.AnchorDecel elseif target > ship.Speed then def.Accel else def.Decel
	ship.Speed = Util.Approach(ship.Speed, target, rate * dt)

	-- turning (ships need speed to turn well)
	local speedFrac = math.clamp(math.abs(ship.Speed) / def.MaxSpeed, 0, 1)
	local turn = def.TurnRate * ship.Rudder * (Sailing.MinTurnFactor + (1 - Sailing.MinTurnFactor) * speedFrac)
	if ship.Anchored then
		turn = if ship.Speed > 6 then turn * Sailing.AnchorSpinBoost else 0
	end
	ship.Yaw -= turn * dt

	-- movement + grounding
	local newPos = ship.Position + forwardOf(ship.Yaw) * ship.Speed * dt
	local f = forwardOf(ship.Yaw)
	local right = Vector3.new(-f.Z, 0, f.X)
	local half = def.Length * 0.46
	local dir = if ship.Speed >= 0 then f else -f
	local probes: { Vector3 } = {
		newPos + dir * half,
		newPos + dir * (half * 0.5) + right * (def.Width * 0.45),
		newPos + dir * (half * 0.5) - right * (def.Width * 0.45),
	}
	local blocked = false
	if math.abs(ship.Speed) > 0.05 then
		for _, probe in probes do
			if isBlocked(probe, def.Draft) then
				blocked = true
				break
			end
		end
	end
	if blocked then
		if ship.Speed > 14 and not Util.InSafeZone(newPos) then
			ShipService.Damage(ship, ship.Speed * 1.2, nil, nil, ship.Speed > 25)
			notifyCrew(ship, "We've run aground!", "warn")
		end
		ship.Speed = if ship.Speed > 0 then -math.min(ship.Speed * 0.25, 4) else 0
		newPos = ship.Position
	end

	-- edge of the world
	local dist = math.sqrt(newPos.X * newPos.X + newPos.Z * newPos.Z)
	if dist > WorldData.BoundaryRadius then
		ShipService.Damage(ship, Sailing.BoundaryDamagePerSecond * dt, nil)
		if now - ship.LastWarn > 6 then
			ship.LastWarn = now
			notifyCrew(ship, "The sea grows wild out here! Turn back before she breaks apart!", "bad")
		end
		local limit = WorldData.HalfSize - 120
		if dist > limit then
			newPos = newPos * (limit / dist)
		end
	end
	ship.Position = Vector3.new(newPos.X, 0, newPos.Z)

	-- leaks and harbour repairs
	local holes = 0
	for _ in ship.Holes do
		holes += 1
	end
	if holes > 0 then
		ship.HP -= holes * Config.Holes.DrainPerSecond * dt
		if ship.HP <= 0 then
			startSinking(ship)
			return
		end
	end
	if ship.Anchored and Util.InSafeZone(ship.Position) then
		ship.HP = math.min(def.MaxHP, ship.HP + Sailing.HarbourRepairPerSecond * dt)
		if holes > 0 and now - ship.LastAutoRepair > 3 then
			ship.LastAutoRepair = now
			local spot = next(ship.Holes)
			if spot then
				removeHole(ship, spot)
			end
		end
	end

	-- bobbing on the waves
	local t = now + ship.BobPhase
	local bob = math.sin(t * 0.9) * 0.35
	local pitch = math.sin(t * 0.7) * math.rad(1.1)
	local roll = math.sin(t * 0.55 + 1.3) * math.rad(1.6) + ship.Rudder * speedFrac * math.rad(4)
	local cf = CFrame.new(ship.Position.X, WATER + bob, ship.Position.Z) * CFrame.Angles(0, ship.Yaw, 0) * CFrame.Angles(pitch, 0, roll)
	ship.AlignPos.Position = cf.Position
	ship.AlignOri.CFrame = cf.Rotation

	-- visuals (throttled)
	if math.abs(ship.VisualSail - ship.Sail) > 0.01 then
		updateSails(ship)
	end
	if ship.WheelWeld and math.abs(ship.VisualRudder - ship.Rudder) > 0.01 then
		ship.WheelWeld.C0 = ship.WheelBaseC0 * CFrame.Angles(0, 0, -ship.Rudder * math.pi * 1.5)
		ship.VisualRudder = ship.Rudder
	end
	for _, cannon in ship.Cannons do
		if cannon.AimDirty then
			applyAim(cannon)
		end
	end
	if now - ship.LastAttributes > 0.2 then
		ship.LastAttributes = now
		updateAttributes(ship)
	end
end

local function resolveCollisions(now: number)
	local list = {}
	for _, ship in ships do
		if not ship.Sinking and not ship.Destroyed then
			table.insert(list, ship)
		end
	end
	for i = 1, #list do
		local a = list[i]
		for j = i + 1, #list do
			local b = list[j]
			local dx, dz = a.Position.X - b.Position.X, a.Position.Z - b.Position.Z
			if math.sqrt(dx * dx + dz * dz) < (a.Def.Length + b.Def.Length) / 2 + 6 then
				local d, pa, pb = closestPoints(centerLine(a.Position, a.Yaw, a.Def.Length), centerLine(b.Position, b.Yaw, b.Def.Length))
				local need = (a.Def.Width + b.Def.Width) / 2
				if d < need then
					local push = Vector3.new(pa.X - pb.X, 0, pa.Z - pb.Z)
					push = if push.Magnitude > 0.01 then push.Unit else Vector3.new(1, 0, 0)
					local overlap = need - d
					local pa2 = a.Position + push * (overlap * 0.5)
					local pb2 = b.Position - push * (overlap * 0.5)
					if not isBlocked(pa2, a.Def.Draft) then
						a.Position = pa2
					end
					if not isBlocked(pb2, b.Def.Draft) then
						b.Position = pb2
					end
					local relative = (forwardOf(a.Yaw) * a.Speed - forwardOf(b.Yaw) * b.Speed).Magnitude
					if relative > 12 and now - math.max(a.LastRam, b.LastRam) > 1.5 then
						a.LastRam, b.LastRam = now, now
						local damage = relative * Sailing.RamDamagePerSpeed
						ShipService.Damage(a, damage, b.Helmsman, nil, true)
						ShipService.Damage(b, damage, a.Helmsman, nil, true)
						notifyCrew(a, "Ramming collision!", "warn")
						notifyCrew(b, "Ramming collision!", "warn")
					end
					a.Speed *= 0.6
					b.Speed *= 0.6
				end
			end
		end
	end
end

local function validateStations()
	for player, ship in helmOf do
		local root = characterRoot(player)
		if not root or not CombatService.IsAlive(player) or (root.Position - ship.HelmPost.Position).Magnitude > 16 or ship.Sinking then
			releaseHelm(ship)
		end
	end
	for player, station in cannonOf do
		local root = characterRoot(player)
		if not root or not CombatService.IsAlive(player) or (root.Position - station.Cannon.Carriage.Position).Magnitude > 12 or station.Ship.Sinking then
			releaseCannon(station.Cannon)
		end
	end
end

local function onAction(player: Player, action: any, a: any, b: any)
	if action == "HelmInput" then
		local ship = helmOf[player]
		if ship and type(a) == "number" and type(b) == "number" then
			ship.Input.Turn = math.clamp(math.round(a), -1, 1)
			ship.Input.Sail = math.clamp(math.round(b), -1, 1)
		end
	elseif action == "CenterWheel" then
		local ship = helmOf[player]
		if ship then
			ship.Rudder = 0
		end
	elseif action == "LeaveHelm" then
		local ship = helmOf[player]
		if ship then
			releaseHelm(ship)
		end
	elseif action == "CannonAim" or action == "CannonFire" then
		local station = cannonOf[player]
		if not station or not Util.IsFiniteNumber(a) or not Util.IsFiniteNumber(b) then
			return
		end
		local cannon = station.Cannon
		cannon.Yaw = math.clamp(a, -Config.Cannon.MaxYaw, Config.Cannon.MaxYaw)
		cannon.Pitch = math.clamp(b, Config.Cannon.MinPitch, Config.Cannon.MaxPitch)
		cannon.AimDirty = true
		if action == "CannonFire" then
			fireCannon(station.Ship, cannon, player)
		end
	elseif action == "LeaveCannon" then
		local station = cannonOf[player]
		if station then
			releaseCannon(station.Cannon)
		end
	end
end

function ShipService.Init()
	for _, group in { "Ships", "Docks" } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Ships", "Ships", false)
	PhysicsService:CollisionGroupSetCollidable("Ships", "Docks", false)
	-- piers are handled by the sailing code; keep physics from fighting over them
	local town = workspace:FindFirstChild("Kingshaven")
	if town then
		for _, child in town:GetChildren() do
			if string.sub(child.Name, 1, 4) == "Pier" or child.Name == "Boardwalk" then
				local parts: { Instance } = if child:IsA("BasePart") then { child } else child:GetDescendants()
				for _, part in parts do
					if part:IsA("BasePart") then
						part.CollisionGroup = "Docks"
					end
				end
			end
		end
	end

	Net.Event("ShipAction").OnServerEvent:Connect(onAction)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, ship in ships do
			updateShip(ship, dt, now)
		end
		resolveCollisions(now)
		stepProjectiles(dt)
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			validateStations()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		ShipService.ReleasePlayer(player)
		local ship = shipByOwner[player]
		if ship then
			ShipService.Despawn(ship)
		end
	end)
end

return ShipService
