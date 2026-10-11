-- Skeleton pirates. They rise on islands when pirates come close (more at night),
-- guard dug-up treasure, and drop gold when defeated.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Heightmap = require(Shared:WaitForChild("Heightmap"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local IslandPoints = require(script.Parent.IslandPoints)

local EnemyService = {}

local S = Config.Skeleton
-- Roblox's default R6 animations
local ANIMATIONS = {
	Idle = "rbxassetid://180435571",
	Walk = "rbxassetid://180426354",
	Slash = "rbxassetid://129967390",
}

type Enemy = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Island: string,
	Home: Vector3,
	Guard: boolean,
	LastAttack: number,
	NextWander: number,
	Tracks: { [string]: AnimationTrack },
	Returning: boolean,
}

local enemies: { [Model]: Enemy } = {}
local islandState: { [string]: { LastSeen: number, LastSpawn: number } } = {}
local template = ServerStorage:WaitForChild("Enemies"):WaitForChild("Skeleton") :: Model
local folder = workspace:WaitForChild("Enemies")

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t < 6 or t > 18.5
end

local function onDied(enemy: Enemy)
	local killer = CombatService.GetLastAttacker(enemy.Humanoid, 12)
	if killer and killer.Parent then
		DataService.AddStat(killer, "SkeletonsDefeated")
		DataService.AddGold(killer, math.random(S.RewardMin, S.RewardMax), "Skeleton defeated")
	end
	Net.Event("Fx"):FireAllClients("Bones", enemy.Root.Position)
	task.delay(5, function()
		enemies[enemy.Model] = nil
		enemy.Model:Destroy()
	end)
end

function EnemyService.SpawnSkeleton(islandName: string, ground: Vector3, guard: boolean?): Enemy?
	local model = template:Clone()
	model:PivotTo(CFrame.new(ground + Vector3.new(0, 3.1, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model:SetAttribute("Island", islandName)
	model.Parent = folder
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if not humanoid or not root then
		model:Destroy()
		return nil
	end
	humanoid.WalkSpeed = S.WalkSpeed
	humanoid.MaxHealth = S.Health
	humanoid.Health = S.Health
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local tracks = {}
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	for name, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = name ~= "Slash"
			tracks[name] = track
		end
	end
	if tracks.Idle then
		tracks.Idle:Play()
	end
	local enemy: Enemy = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Island = islandName,
		Home = ground,
		Guard = guard == true,
		LastAttack = 0,
		NextWander = os.clock() + math.random() * 3,
		Tracks = tracks,
		Returning = false,
	}
	humanoid.Running:Connect(function(speed)
		local walk = tracks.Walk
		if not walk then
			return
		end
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
			end
		elseif walk.IsPlaying then
			walk:Stop(0.2)
		end
	end)
	humanoid.Died:Connect(function()
		onDied(enemy)
	end)
	enemies[model] = enemy
	Net.Event("Fx"):FireAllClients("SkeletonRise", ground)
	return enemy
end

-- A few skeletons rise around freshly dug treasure
function EnemyService.SpawnGuards(islandName: string, position: Vector3, count: number)
	for i = 1, count do
		local angle = (i / math.max(count, 1)) * math.pi * 2 + math.random()
		local distance = math.random(10, 16)
		local x, z = position.X + math.cos(angle) * distance, position.Z + math.sin(angle) * distance
		if Heightmap.GetHeight(x, z) < 1.5 then
			x, z = position.X, position.Z
		end
		local ground = IslandPoints.Ground(x, z, { folder, workspace:WaitForChild("Nature") })
		task.delay(i * 0.4, function()
			EnemyService.SpawnSkeleton(islandName, ground, true)
		end)
	end
end

local function findTarget(enemy: Enemy): (Humanoid?, BasePart?, number)
	local best, bestRoot, bestDist = nil, nil, S.AggroRange
	local position = enemy.Root.Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local d = (root.Position - position).Magnitude
			if d < bestDist and not Util.InSafeZone(root.Position) and Heightmap.GetHeight(root.Position.X, root.Position.Z) > 0.5 then
				best, bestRoot, bestDist = humanoid, root, d
			end
		end
	end
	return best, bestRoot, bestDist
end

local function think(enemy: Enemy, now: number)
	if enemy.Humanoid.Health <= 0 then
		return
	end
	local position = enemy.Root.Position
	local fromHome = Util.FlatDistance(position, enemy.Home)
	if enemy.Returning then
		enemy.Humanoid:MoveTo(enemy.Home)
		if fromHome < 8 then
			enemy.Returning = false
		end
		return
	end
	if fromHome > 130 then
		enemy.Returning = true
		return
	end
	local target, targetRoot, distance = findTarget(enemy)
	if target and targetRoot then
		enemy.Humanoid:MoveTo(targetRoot.Position)
		if distance <= S.AttackRange and now - enemy.LastAttack > S.AttackCooldown then
			enemy.LastAttack = now
			local slash = enemy.Tracks.Slash
			if slash then
				slash:Play(0.05)
			end
			task.delay(0.25, function()
				if enemy.Humanoid.Health > 0 and target.Health > 0 and (targetRoot.Position - enemy.Root.Position).Magnitude <= S.AttackRange + 1.5 then
					CombatService.DamageHumanoid(nil, target, S.Damage)
				end
			end)
		end
	elseif now > enemy.NextWander then
		enemy.NextWander = now + math.random(3, 7)
		for _ = 1, 4 do
			local x = enemy.Home.X + math.random(-22, 22)
			local z = enemy.Home.Z + math.random(-22, 22)
			if Heightmap.GetHeight(x, z) > 2.5 then
				enemy.Humanoid:MoveTo(Vector3.new(x, enemy.Home.Y, z))
				break
			end
		end
	end
end

local function manageIslands(now: number)
	local counts: { [string]: number } = {}
	for _, enemy in enemies do
		if not enemy.Guard and enemy.Humanoid.Health > 0 then
			counts[enemy.Island] = (counts[enemy.Island] or 0) + 1
		end
	end
	for _, island in WorldData.Islands do
		if island.Skeletons <= 0 then
			continue
		end
		local state = islandState[island.Name]
		if not state then
			state = { LastSeen = 0, LastSpawn = 0 }
			islandState[island.Name] = state
		end
		local near = false
		local reach = island.Radius + S.ActivateDistance
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local dx, dz = root.Position.X - island.X, root.Position.Z - island.Z
				if dx * dx + dz * dz < reach * reach then
					near = true
					break
				end
			end
		end
		if near then
			state.LastSeen = now
			local cap = island.Skeletons + (if isNight() then 2 else 0)
			if (counts[island.Name] or 0) < cap and now - state.LastSpawn > S.SpawnInterval then
				local spot = IslandPoints.Random(island.Name, "Land")
				if spot then
					state.LastSpawn = now
					local ground = IslandPoints.Ground(spot.X, spot.Z, { folder, workspace:WaitForChild("Nature") })
					EnemyService.SpawnSkeleton(island.Name, ground, false)
				end
			end
		elseif now - state.LastSeen > S.DespawnDelay then
			for model, enemy in enemies do
				if enemy.Island == island.Name then
					enemies[model] = nil
					model:Destroy()
				end
			end
		end
	end
end

function EnemyService.Init()
	task.spawn(function()
		IslandPoints.Build()
		local lastIslands = 0
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, enemy in enemies do
				think(enemy, now)
			end
			if now - lastIslands > 2 then
				lastIslands = now
				manageIslands(now)
			end
		end
	end)
end

return EnemyService
