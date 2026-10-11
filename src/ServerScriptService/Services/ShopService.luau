-- The shops of Kingshaven: Shipwright, Merchant (maps + selling treasure),
-- Armory, Tavern and the Trading Post.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local ShipService = require(script.Parent.ShipService)
local TreasureService = require(script.Parent.TreasureService)

local ShopService = {}

local SHOP_RANGE = 30
local shopPositions: { [string]: Vector3 } = {}

local RUMORS = {
	"They say a Chest of the Pirate King hides behind some Captain's maps...",
	"Skeletons crawl out of the sand at night. Bring friends.",
	"Sail WITH the wind and your ship flies. Check the arrow on your compass.",
	"Drop anchor at full speed and your ship will spin like a top!",
	"Treasure on your deck sails with you... and can be stolen by rivals.",
	"Holes in the hull leak your ship's health away. Patch them quick!",
	"Anchor in Kingshaven harbour and the dockhands repair your ship for free.",
	"The richest pirate on the seas wears the crown. Is it you?",
	"Skull Rock and Devil's Ridge are crawling with the undead.",
	"Lost a chest overboard? It floats! Swim out and grab it.",
}

local function isNear(player: Player, shopId: string): boolean
	local position = shopPositions[shopId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not position or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - position).Magnitude <= SHOP_RANGE
end

local function result(ok: boolean, message: string)
	return { Ok = ok, Message = message }
end

function ShopService.SellTreasure(player: Player)
	if not CarryService.GetCarried(player) then
		return result(false, "Bring me a treasure chest and I'll pay in gold!")
	end
	local tier, value = CarryService.TakeCarried(player)
	local def = tier and Config.Chests[tier]
	DataService.AddStat(player, "ChestsSold")
	DataService.AddGold(player, value, "for the " .. (if def then def.DisplayName else "treasure"))
	Net.Event("Fx"):FireClient(player, "Coins")
	return result(true, ("Sold for %s gold!"):format(Util.FormatNumber(value)))
end

local function handle(player: Player, action: any, arg: any)
	local data = DataService.Get(player)
	if not data or type(action) ~= "string" then
		return result(false, "Still loading your save...")
	end

	if action == "BuyShip" or action == "LaunchShip" or action == "ScuttleShip" then
		if not isNear(player, "Shipwright") then
			return result(false, "Talk to the Shipwright at the docks.")
		end
		if action == "ScuttleShip" then
			local ship = ShipService.GetShip(player)
			if not ship then
				return result(false, "You don't have a ship out at sea.")
			end
			ShipService.Despawn(ship)
			return result(true, "Your ship was returned to the shipyard.")
		end
		local def = if type(arg) == "string" then Config.Ships[arg] else nil
		if not def then
			return result(false, "Unknown ship.")
		end
		if action == "BuyShip" then
			if data.Ships[def.Id] then
				return result(false, "You already own this ship.")
			end
			if not DataService.SpendGold(player, def.Price) then
				return result(false, "You need " .. Util.FormatNumber(def.Price) .. " gold for that ship.")
			end
			data.Ships[def.Id] = true
			DataService.Changed(player)
			Net.Event("Fx"):FireClient(player, "Coins")
			return result(true, ("The %s is yours! Press Launch to set sail."):format(def.DisplayName))
		end
		if not data.Ships[def.Id] then
			return result(false, "You don't own this ship yet.")
		end
		local ok, message = ShipService.Spawn(player, def.Id)
		return result(ok, message)
	elseif action == "BuyItem" or action == "SellItem" then
		local item = if type(arg) == "string" then Config.Items[arg] else nil
		if not item then
			return result(false, "Unknown item.")
		end
		if action == "BuyItem" then
			if not isNear(player, "Armory") or item.Shop ~= "Armory" then
				return result(false, "The Armory sells weapons and tools.")
			end
			if data.Items[item.Id] then
				return result(false, "You already own that.")
			end
			if not DataService.SpendGold(player, item.Price) then
				return result(false, "You need " .. Util.FormatNumber(item.Price) .. " gold.")
			end
			InventoryService.Grant(player, item.Id)
			Net.Event("Fx"):FireClient(player, "Coins")
			return result(true, item.DisplayName .. " added to your backpack!")
		end
		if not (isNear(player, "Armory") or isNear(player, "Merchant")) then
			return result(false, "Sell your goods at the Armory or the Merchant.")
		end
		if not data.Items[item.Id] or item.Starter then
			return result(false, "You can't sell that.")
		end
		local refund = math.floor(item.Price * Config.SellBackRate)
		InventoryService.Revoke(player, item.Id)
		DataService.AddGold(player, refund)
		return result(true, ("Sold %s for %s gold."):format(item.DisplayName, Util.FormatNumber(refund)))
	elseif action == "BuyMap" or action == "SellMap" or action == "SellTreasure" then
		if not isNear(player, "Merchant") then
			return result(false, "Visit the Merchant in Kingshaven.")
		end
		if action == "BuyMap" then
			if type(arg) ~= "string" then
				return result(false, "Unknown map.")
			end
			local ok, message = TreasureService.BuyMap(player, arg)
			if ok then
				Net.Event("Fx"):FireClient(player, "Coins")
			end
			return result(ok, message)
		elseif action == "SellMap" then
			if type(arg) ~= "number" then
				return result(false, "Unknown map.")
			end
			local map = TreasureService.RemoveMap(player, arg)
			if not map then
				return result(false, "You don't have that map.")
			end
			local tier = Config.MapTiers[map.Tier]
			local refund = if tier then math.floor(tier.Price * Config.SellBackRate) else 0
			DataService.AddGold(player, refund)
			return result(true, ("Sold the map for %s gold."):format(Util.FormatNumber(refund)))
		end
		return ShopService.SellTreasure(player)
	elseif action == "BuyGrog" or action == "Rumor" then
		if not isNear(player, "Tavern") then
			return result(false, "The Tavern is on the west side of the square.")
		end
		if action == "Rumor" then
			return result(true, RUMORS[math.random(1, #RUMORS)])
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return result(false, "...")
		end
		if not DataService.SpendGold(player, Config.GrogPrice) then
			return result(false, "Grog costs " .. Config.GrogPrice .. " gold.")
		end
		humanoid.Health = humanoid.MaxHealth
		Net.Event("Fx"):FireClient(player, "Grog")
		return result(true, "Yo ho ho! You feel... wobbly. And fully healed.")
	end
	return result(false, "Unknown request.")
end

local function connectNpc(npc: Instance)
	local shopId = npc:GetAttribute("ShopId")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if type(shopId) ~= "string" or not root or not root:IsA("BasePart") then
		return
	end
	shopPositions[shopId] = root.Position
	-- idle animation so the shopkeepers look alive (Roblox's default R6 idle)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://180435571"
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = true
			track:Play()
		end
	end
	local prompt = root:FindFirstChild("ShopPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			Net.Event("OpenShop"):FireClient(player, shopId)
		end)
	end
end

function ShopService.Init()
	for _, npc in CollectionService:GetTagged("ShopNPC") do
		connectNpc(npc)
	end
	for _, counter in CollectionService:GetTagged("SellCounter") do
		local prompt = counter:FindFirstChild("SellPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				local r = ShopService.SellTreasure(player)
				Net.Notify(player, r.Message, if r.Ok then "gold" else "info")
			end)
		end
	end
	Net.Function("ShopRequest").OnServerInvoke = function(player, action, arg)
		local ok, response = pcall(handle, player, action, arg)
		if ok then
			return response
		end
		warn("[ShopService]", response)
		return result(false, "Something went wrong.")
	end
end

return ShopService
