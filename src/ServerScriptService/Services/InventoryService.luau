-- Gives players the Tools for the items they own (and the treasure map when they have maps).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local DataService = require(script.Parent.DataService)

local InventoryService = {}

local toolTemplates = ServerStorage:WaitForChild("Tools")

-- Tool names the game manages (anything else in the backpack is left alone)
local MANAGED: { [string]: boolean } = { TreasureMap = true }
for id in Config.Items do
	MANAGED[id] = true
end

local function wantedTools(player: Player): { [string]: boolean }
	local data = DataService.Get(player)
	local wanted = {}
	if not data then
		return wanted
	end
	for id, owned in data.Items do
		if owned and Config.Items[id] then
			wanted[id] = true
		end
	end
	if #data.Maps > 0 then
		wanted.TreasureMap = true
	end
	return wanted
end

local function currentTools(player: Player): { [string]: Tool }
	local found = {}
	local containers: { Instance? } = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and MANAGED[child.Name] then
					found[child.Name] = child
				end
			end
		end
	end
	return found
end

-- Make the player's tools match what they own
function InventoryService.Refresh(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not backpack or not character then
		return
	end
	local wanted = wantedTools(player)
	local have = currentTools(player)
	for name, tool in have do
		if not wanted[name] then
			tool:Destroy()
		end
	end
	-- keep a stable hotbar order
	local order = {}
	for name in wanted do
		table.insert(order, name)
	end
	table.sort(order, function(a, b)
		local ia = if Config.Items[a] then Config.Items[a].Order else 99
		local ib = if Config.Items[b] then Config.Items[b].Order else 99
		return ia < ib
	end)
	for _, name in order do
		if not have[name] then
			local template = toolTemplates:FindFirstChild(name)
			if template then
				template:Clone().Parent = backpack
			end
		end
	end
end

function InventoryService.Owns(player: Player, itemId: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.Items[itemId] == true
end

function InventoryService.Grant(player: Player, itemId: string)
	local data = DataService.Get(player)
	if data then
		data.Items[itemId] = true
		DataService.Changed(player)
		InventoryService.Refresh(player)
	end
end

function InventoryService.Revoke(player: Player, itemId: string)
	local data = DataService.Get(player)
	if data and not (Config.Items[itemId] and Config.Items[itemId].Starter) then
		data.Items[itemId] = nil
		DataService.Changed(player)
		InventoryService.Refresh(player)
	end
end

-- Returns the equipped tool if it is one of the given names
function InventoryService.GetEquipped(player: Player, names: { string }): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if tool and table.find(names, tool.Name) then
		return tool
	end
	return nil
end

function InventoryService.Init()
	DataService.OnChanged(function(player)
		-- maps can appear/disappear: keep the TreasureMap tool in sync
		local data = DataService.Get(player)
		if not data then
			return
		end
		local have = currentTools(player)
		if (#data.Maps > 0) ~= (have.TreasureMap ~= nil) then
			InventoryService.Refresh(player)
		end
	end)
end

return InventoryService
