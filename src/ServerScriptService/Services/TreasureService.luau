-- Treasure maps, digging with the shovel, and chests that wash up on beaches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local CarryService = require(script.Parent.CarryService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local InventoryService = require(script.Parent.InventoryService)
local IslandPoints = require(script.Parent.IslandPoints)

local TreasureService = {}

local digProgress: { [Player]: { [number]: number } } = {}
local lastHint: { [Player]: number } = {}

local function groundExclude(): { Instance }
	local list: { Instance } = {
		workspace:WaitForChild("Nature"),
		workspace:WaitForChild("Enemies"),
		workspace:WaitForChild("Ships"),
		workspace:WaitForChild("Treasure"),
		workspace:WaitForChild("Effects"),
	}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function islandsFor(tier: Config.MapTier): { WorldData.Island }
	local list = {}
	for _, island in WorldData.Islands do
		if island.Kind ~= "Main" then
			local d = math.sqrt(island.X ^ 2 + island.Z ^ 2)
			local ok = true
			if tier.NearIslands and d > 2000 then
				ok = false
			elseif tier.FarIslands and d < 1900 then
				ok = false
			end
			if ok then
				table.insert(list, island)
			end
		end
	end
	return list
end

function TreasureService.BuyMap(player: Player, tierId: string): (boolean, string)
	local tier = Config.MapTiers[tierId]
	local data = DataService.Get(player)
	if not tier or not data then
		return false, "Unknown map."
	end
	if #data.Maps >= Config.MaxMaps then
		return false, ("You can only carry %d maps. Dig some up first!"):format(Config.MaxMaps)
	end
	local candidates = islandsFor(tier)
	local island, spot
	for _ = 1, 20 do
		island = candidates[math.random(1, #candidates)]
		spot = IslandPoints.Random(island.Name, "Land")
		if spot then
			break
		end
	end
	if not island or not spot then
		return false, "The cartographer is out of ink. Try again!"
	end
	if not DataService.SpendGold(player, tier.Price) then
		return false, "You can't afford that, matey."
	end
	local map = { Id = data.NextMapId, Tier = tier.Id, Island = island.Name, X = math.floor(spot.X), Z = math.floor(spot.Z) }
	data.NextMapId += 1
	table.insert(data.Maps, map)
	DataService.Changed(player)
	InventoryService.Refresh(player)
	return true, ("You got a %s! X marks a spot on %s."):format(tier.DisplayName, island.Name)
end

function TreasureService.RemoveMap(player: Player, mapId: number): any
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	for i, map in data.Maps do
		if map.Id == mapId then
			table.remove(data.Maps, i)
			DataService.Changed(player)
			return map
		end
	end
	return nil
end

local function dig(player: Player)
	local tool = InventoryService.GetEquipped(player, { "Shovel", "GoldenShovel" })
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local data = DataService.Get(player)
	if not tool or not root or not root:IsA("BasePart") or not data or not CombatService.IsAlive(player) then
		return
	end
	if not CombatService.CooldownReady(player, "Dig", Config.Dig.Cooldown) then
		return
	end
	CombatService.PlayToolAnimation(tool, "Slash")
	local ground = IslandPoints.Ground(root.Position.X, root.Position.Z, groundExclude())
	if math.abs(ground.Y - root.Position.Y) > 8 then
		ground = root.Position - Vector3.new(0, 3, 0)
	end
	Net.Event("Fx"):FireAllClients("Dig", ground)

	local target = nil
	local nearest = math.huge
	for _, map in data.Maps do
		local d = Util.FlatDistance(root.Position, Vector3.new(map.X, 0, map.Z))
		if d <= Config.Dig.Radius then
			target = map
			break
		end
		nearest = math.min(nearest, d)
	end
	if not target then
		local now = os.clock()
		if not lastHint[player] or now - lastHint[player] > 2.5 then
			lastHint[player] = now
			if nearest < 35 then
				Net.Notify(player, "So close! The X must be just nearby...", "info")
			else
				Net.Notify(player, "Nothing here but sand. Check your treasure map!", "info")
			end
		end
		return
	end

	local progress = digProgress[player]
	if not progress then
		progress = {}
		digProgress[player] = progress
	end
	progress[target.Id] = (progress[target.Id] or 0) + 1
	local needed = Config.Items[tool.Name].DigStrikes or 3
	if progress[target.Id] < needed then
		Net.Notify(player, ("Digging... (%d/%d)"):format(progress[target.Id], needed), "info")
		return
	end
	progress[target.Id] = nil
	TreasureService.RemoveMap(player, target.Id)

	local tier = Config.MapTiers[target.Tier]
	local chestTier = if tier then tier.Chest else "Castaway"
	if chestTier == "Captain" and math.random() < Config.KingChestChance then
		chestTier = "King"
	end
	local spot = IslandPoints.Ground(target.X, target.Z, groundExclude())
	CarryService.SpawnChest(chestTier, spot + Vector3.new(0, 1, 0))
	local chest = Config.Chests[chestTier]
	Net.Event("Fx"):FireAllClients("Unearth", spot)
	Net.Notify(player, ("You dug up a %s! Bring it to the Merchant in Kingshaven."):format(chest.DisplayName), "gold")
	if chestTier == "King" then
		Net.NotifyAll(player.DisplayName .. " found the Chest of the Pirate King!", "gold")
	end
	if tier and tier.Guards > 0 then
		Net.Notify(player, "The dead don't give up their gold easily...", "warn")
		EnemyService.SpawnGuards(target.Island, spot, tier.Guards)
	end
end

local function spawnBeachChest()
	local beachCount = 0
	for _, chest in workspace:WaitForChild("Treasure"):GetChildren() do
		if chest:GetAttribute("BeachChest") then
			beachCount += 1
		end
	end
	if beachCount >= Config.BeachChests.Max then
		return
	end
	local islands = {}
	for _, island in WorldData.Islands do
		if island.Kind ~= "Main" then
			table.insert(islands, island)
		end
	end
	local island = islands[math.random(1, #islands)]
	local spot = IslandPoints.Random(island.Name, "Beach")
	if not spot then
		return
	end
	local tier = if math.random() < Config.BeachChests.SeafarerChance then "Seafarer" else "Castaway"
	local ground = IslandPoints.Ground(spot.X, spot.Z, groundExclude())
	local chest = CarryService.SpawnChest(tier, ground + Vector3.new(0, 1, 0))
	if chest then
		chest:SetAttribute("BeachChest", true)
	end
end

function TreasureService.Init()
	Net.Event("TreasureAction").OnServerEvent:Connect(function(player, action)
		if action == "Dig" then
			dig(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		digProgress[player] = nil
		lastHint[player] = nil
	end)
	task.spawn(function()
		while not workspace:GetAttribute("WorldReady") do
			task.wait(2)
		end
		for _ = 1, 4 do
			spawnBeachChest()
		end
		while true do
			task.wait(Config.BeachChests.Interval)
			spawnBeachChest()
		end
	end)
end

return TreasureService
