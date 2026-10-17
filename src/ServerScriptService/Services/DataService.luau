-- Player save data (gold, ships, items, treasure maps) with DataStore persistence.
-- If DataStores are unavailable (e.g. Studio without API access) the game still
-- works, it just doesn't save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local DataService = {}

local STORE_NAME = "KingOfThePirates_PlayerData_v1"

export type MapData = { Id: number, Tier: string, Island: string, X: number, Z: number }
-- Sail cosmetics: owned colours/symbols (sets) and what is rigged ("" = no symbol)
export type Cosmetics = {
	SailColors: { [string]: boolean },
	Symbols: { [string]: boolean },
	SailColor: string,
	Symbol: string,
}
export type PlayerData = {
	Version: number,
	Gold: number,
	Ships: { [string]: boolean },
	Items: { [string]: boolean },
	Maps: { MapData },
	NextMapId: number,
	Stats: { [string]: number },
	Cosmetics: Cosmetics,
}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress will not be saved:", result)
	end
end

local profiles: { [Player]: PlayerData } = {}
local canSave: { [Player]: boolean } = {}
local loadedCallbacks: { (Player, PlayerData) -> () } = {}
local changedCallbacks: { (Player, PlayerData) -> () } = {}

local function defaultData(): PlayerData
	local items = {}
	for id, item in Config.Items do
		if item.Starter then
			items[id] = true
		end
	end
	return {
		Version = 1,
		Gold = Config.StartingGold,
		Ships = { Sloop = true },
		Items = items,
		Maps = {},
		NextMapId = 1,
		Stats = { ChestsSold = 0, SkeletonsDefeated = 0, ShipsSunk = 0, GoldEarned = 0 },
		Cosmetics = {
			SailColors = { [Config.DefaultSailColor] = true },
			Symbols = {},
			SailColor = Config.DefaultSailColor,
			Symbol = "",
		},
	}
end

-- Owned sets and equipped choices must point at things that exist (and are owned)
local function reconcileCosmetics(data: any, fresh: PlayerData)
	if type(data.Cosmetics) ~= "table" then
		data.Cosmetics = fresh.Cosmetics
	end
	local cosmetics = data.Cosmetics
	if type(cosmetics.SailColors) ~= "table" then
		cosmetics.SailColors = {}
	end
	if type(cosmetics.Symbols) ~= "table" then
		cosmetics.Symbols = {}
	end
	for id in cosmetics.SailColors do
		if not Config.SailColors[id] then
			cosmetics.SailColors[id] = nil
		end
	end
	for id in cosmetics.Symbols do
		if not Config.SailSymbols[id] then
			cosmetics.Symbols[id] = nil
		end
	end
	cosmetics.SailColors[Config.DefaultSailColor] = true
	if type(cosmetics.SailColor) ~= "string" or not cosmetics.SailColors[cosmetics.SailColor] then
		cosmetics.SailColor = Config.DefaultSailColor
	end
	if type(cosmetics.Symbol) ~= "string" or (cosmetics.Symbol ~= "" and not cosmetics.Symbols[cosmetics.Symbol]) then
		cosmetics.Symbol = ""
	end
end

-- Fill in anything missing from older saves
local function reconcile(data: any): PlayerData
	local fresh = defaultData()
	if type(data) ~= "table" then
		return fresh
	end
	for key, value in fresh :: any do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" and key ~= "Maps" then
			for k, v in value do
				if data[key][k] == nil then
					data[key][k] = v
				end
			end
		end
	end
	-- starter items can never be lost
	for id, item in Config.Items do
		if item.Starter then
			data.Items[id] = true
		end
	end
	data.Ships.Sloop = true
	reconcileCosmetics(data, fresh)
	return data
end

local function key(player: Player): string
	return "player_" .. player.UserId
end

local function snapshot(data: PlayerData)
	return {
		Gold = data.Gold,
		Ships = table.clone(data.Ships),
		Items = table.clone(data.Items),
		Maps = table.clone(data.Maps),
		Stats = table.clone(data.Stats),
		Cosmetics = {
			SailColors = table.clone(data.Cosmetics.SailColors),
			Symbols = table.clone(data.Cosmetics.Symbols),
			SailColor = data.Cosmetics.SailColor,
			Symbol = data.Cosmetics.Symbol,
		},
	}
end

local function updateLeaderstats(player: Player, data: PlayerData)
	local stats = player:FindFirstChild("leaderstats")
	local gold = stats and stats:FindFirstChild("Gold")
	if gold and gold:IsA("IntValue") then
		gold.Value = data.Gold
	end
end

-- Push the latest data to the player's UI and leaderboard
function DataService.Changed(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	updateLeaderstats(player, data)
	Net.Event("PlayerData"):FireClient(player, snapshot(data))
	for _, callback in changedCallbacks do
		task.spawn(callback, player, data)
	end
end

function DataService.Get(player: Player): PlayerData?
	return profiles[player]
end

function DataService.WaitFor(player: Player): PlayerData?
	local started = os.clock()
	while not profiles[player] and player.Parent and os.clock() - started < 30 do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.OnLoaded(callback: (Player, PlayerData) -> ())
	table.insert(loadedCallbacks, callback)
	for player, data in profiles do
		task.spawn(callback, player, data)
	end
end

function DataService.OnChanged(callback: (Player, PlayerData) -> ())
	table.insert(changedCallbacks, callback)
end

function DataService.GetGold(player: Player): number
	local data = profiles[player]
	return if data then data.Gold else 0
end

function DataService.AddGold(player: Player, amount: number, reason: string?)
	local data = profiles[player]
	if not data or amount == 0 then
		return
	end
	data.Gold = math.max(0, math.floor(data.Gold + amount))
	if amount > 0 then
		data.Stats.GoldEarned = (data.Stats.GoldEarned or 0) + amount
		if reason then
			Net.Notify(player, ("+%d gold  %s"):format(amount, reason), "gold")
		end
	end
	DataService.Changed(player)
end

-- Returns true and deducts the gold if the player can afford it
function DataService.SpendGold(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or amount < 0 or data.Gold < amount then
		return false
	end
	data.Gold -= amount
	DataService.Changed(player)
	return true
end

function DataService.AddStat(player: Player, stat: string, amount: number?)
	local data = profiles[player]
	if data then
		data.Stats[stat] = (data.Stats[stat] or 0) + (amount or 1)
	end
end

local function save(player: Player)
	local data = profiles[player]
	if not data or not store or not canSave[player] then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
	end
end
DataService.Save = save

local function load(player: Player)
	local data: any = nil
	local ok = true
	if store then
		ok = false
		for attempt = 1, 3 do
			local success, result = pcall(function()
				return (store :: DataStore):GetAsync(key(player))
			end)
			if success then
				data = result
				ok = true
				break
			end
			warn("[DataService] Load attempt", attempt, "failed for", player.Name, result)
			task.wait(1.5)
		end
	end
	if not player.Parent then
		return
	end
	-- Never save over data we failed to read
	canSave[player] = ok and store ~= nil
	profiles[player] = reconcile(data)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Parent = leaderstats
	leaderstats.Parent = player

	DataService.Changed(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profiles[player])
	end
	if not ok then
		Net.Notify(player, "Could not load your save. Progress this session won't be saved.", "bad")
	end
end

function DataService.Init()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		canSave[player] = nil
	end)
	game:BindToClose(function()
		local threads = 0
		for player in profiles do
			threads += 1
			task.spawn(function()
				save(player)
				threads -= 1
			end)
		end
		local started = os.clock()
		while threads > 0 and os.clock() - started < 20 do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)
end

return DataService
