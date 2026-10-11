-- Spawns players once Kingshaven exists, and respawns them after death:
-- aboard their (or their crew's) ship if it's afloat, otherwise in town.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local ShipService = require(script.Parent.ShipService)
local WorldService = require(script.Parent.WorldService)

local SpawnService = {}

local worldReady = false
local spawning: { [Player]: boolean } = {}
local hasSpawned: { [Player]: boolean } = {}

local function spawnPlayer(player: Player)
	if spawning[player] or not player.Parent or not worldReady then
		return
	end
	spawning[player] = true
	DataService.WaitFor(player)
	if player.Parent then
		local ok, err = pcall(function()
			player:LoadCharacter()
		end)
		if not ok then
			warn("[SpawnService] LoadCharacter failed:", err)
		end
	end
	spawning[player] = nil
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	humanoid.WalkSpeed = Config.DefaultWalkSpeed
	player:SetAttribute("Station", nil)
	player:WaitForChild("Backpack", 5)
	task.defer(InventoryService.Refresh, player)

	if hasSpawned[player] then
		local ship = ShipService.GetCrewShip(player)
		if ship then
			task.wait(0.1)
			if character.Parent then
				character:PivotTo(ShipService.GetCrewSpawn(ship))
				Net.Notify(player, "You wake up aboard your ship.", "info")
			end
		end
	else
		Net.Notify(player, "Welcome to Kingshaven! Visit the Shipwright to launch your ship.", "gold")
	end
	hasSpawned[player] = true
	WorldService.ApplyCrown(player)

	humanoid.Died:Connect(function()
		CarryService.Drop(player, true)
		ShipService.ReleasePlayer(player)
		task.delay(Config.RespawnTime, function()
			if player.Parent and player.Character == character then
				spawnPlayer(player)
			end
		end)
	end)
end

-- Called once Kingshaven's terrain is generated
function SpawnService.SetWorldReady()
	if worldReady then
		return
	end
	worldReady = true
	workspace:SetAttribute("MainIslandReady", true)
	for _, player in Players:GetPlayers() do
		if not player.Character then
			task.spawn(spawnPlayer, player)
		end
	end
end

function SpawnService.Init()
	Players.CharacterAutoLoads = false
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		task.spawn(spawnPlayer, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		spawning[player] = nil
		hasSpawned[player] = nil
	end)
	-- safety net: anyone without a character gets one
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if worldReady and (not character or not character.Parent) and not spawning[player] then
					task.spawn(spawnPlayer, player)
				end
			end
		end
	end)
end

return SpawnService
