-- Shop windows for the shopkeepers of Kingshaven.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local HUD = require(script.Parent.HUD)
local State = require(script.Parent.State)
local UIKit = require(script.Parent.UIKit)

local ShopUI = {}

local player = Players.LocalPlayer
local C = UIKit.Colors
local window: UIKit.Window
local currentShop: string? = nil
local merchantTab = "Maps"
local busy = false
local tavernMessage = "Welcome to The Rusty Anchor! What'll it be?"

-- Called when the Trading Post opens (set by PlayersUI)
ShopUI.OpenTrading = nil :: (() -> ())?

local TITLES = {
	Shipwright = "Shipwright - Captain Barnaby",
	Merchant = "Merchant - Madame Coralie",
	Armory = "Armory - Old Ironhook",
	Tavern = "The Rusty Anchor",
}

local function request(action: string, arg: any?): any
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return Net.Function("ShopRequest"):InvokeServer(action, arg)
	end)
	busy = false
	if not ok or type(result) ~= "table" then
		HUD.Notify("The shopkeeper didn't hear you. Try again.", "bad")
		return nil
	end
	HUD.Notify(result.Message, if result.Ok then "good" else "bad")
	return result
end

local function priceText(price: number): string
	return if price <= 0 then "FREE" else Util.FormatNumber(price) .. " gold"
end

local function statBar(parent: Instance, y: number, label: string, frac: number)
	UIKit.Label(parent, label, {
		Position = UDim2.fromOffset(150, y),
		Size = UDim2.fromOffset(64, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = UIKit.Fonts.Small,
	})
	local back = UIKit.new("Frame", {
		Position = UDim2.fromOffset(216, y + 3),
		Size = UDim2.new(1, -380, 0, 10),
		BackgroundColor3 = C.ParchmentDark,
		Parent = parent,
	})
	UIKit.Corner(back, 5)
	local fill = UIKit.new("Frame", { Size = UDim2.fromScale(math.clamp(frac, 0.05, 1), 1), BackgroundColor3 = C.Teal, Parent = back })
	UIKit.Corner(fill, 5)
end

local function buildShipwright(body: Frame)
	local data = State.Data
	local scroll = UIKit.Scroll(body)
	UIKit.List(scroll, 8)
	local ids = {}
	for id in Config.Ships do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.Ships[a].Order < Config.Ships[b].Order
	end)
	for i, id in ids do
		local def = Config.Ships[id]
		local owned = data ~= nil and data.Ships[id] == true
		local card = UIKit.Card(scroll, 132, i)
		UIKit.Label(card, def.DisplayName, {
			Font = UIKit.Fonts.Title,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.fromOffset(130, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Wood,
		})
		UIKit.Label(card, def.Description, {
			Position = UDim2.fromOffset(14, 96),
			Size = UDim2.new(1, -170, 0, 30),
			Font = UIKit.Fonts.Small,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		})
		UIKit.Label(card, ("Crew %d  |  %d cannons"):format(def.Crew, def.Cannons), {
			Position = UDim2.fromOffset(14, 42),
			Size = UDim2.fromOffset(130, 18),
			Font = UIKit.Fonts.Small,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		statBar(card, 14, "Speed", def.MaxSpeed / 50)
		statBar(card, 34, "Hull", def.MaxHP / 1200)
		statBar(card, 54, "Turning", def.TurnRate / math.rad(17))
		statBar(card, 74, "Cannons", def.Cannons / 8)
		if owned then
			UIKit.Button(card, "Launch", C.Teal, function()
				local result = request("LaunchShip", id)
				if result and result.Ok then
					window.Close()
				end
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 46) })
		else
			UIKit.Button(card, "Buy " .. priceText(def.Price), C.Green, function()
				request("BuyShip", id)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 46) })
		end
	end
	local footer = UIKit.Card(scroll, 56, 10)
	footer.BackgroundTransparency = 1
	UIKit.Button(footer, "Return my ship to port", C.Red, function()
		request("ScuttleShip")
	end, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(260, 42) })
end

local function buildMerchant(body: Frame)
	local data = State.Data
	local tabs = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = body })
	UIKit.List(tabs, 8, true, Enum.HorizontalAlignment.Left)
	for i, name in { "Maps", "Sell" } do
		local selected = merchantTab == name
		UIKit.Button(tabs, if name == "Maps" then "Treasure Maps" else "Sell Goods", if selected then C.Wood else C.ParchmentDark, function()
			merchantTab = name
			ShopUI.Refresh()
		end, { Size = UDim2.fromOffset(170, 40), LayoutOrder = i, TextColor3 = if selected then C.Gold else C.Ink })
	end
	local content = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), Parent = body })
	local scroll = UIKit.Scroll(content)
	UIKit.List(scroll, 8)

	if merchantTab == "Maps" then
		local count = if data then #data.Maps else 0
		UIKit.Label(scroll, ("Your maps: %d / %d. Equip the map to see where X marks the spot."):format(count, Config.MaxMaps), {
			Size = UDim2.new(1, -12, 0, 22),
			Font = UIKit.Fonts.Small,
			LayoutOrder = 0,
		})
		local tiers = {}
		for id in Config.MapTiers do
			table.insert(tiers, id)
		end
		table.sort(tiers, function(a, b)
			return Config.MapTiers[a].Order < Config.MapTiers[b].Order
		end)
		for i, id in tiers do
			local tier = Config.MapTiers[id]
			local chest = Config.Chests[tier.Chest]
			local card = UIKit.Card(scroll, 78, i)
			UIKit.Label(card, tier.DisplayName, {
				Font = UIKit.Fonts.Title,
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(1, -190, 0, 28),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.Wood,
			})
			local where = if tier.NearIslands then "nearby islands" elseif tier.FarIslands then "far-away islands" else "any island"
			UIKit.Label(card, ("Leads to a %s (worth %sg) on %s.%s"):format(chest.DisplayName, Util.FormatNumber(chest.Value), where, if tier.Guards > 0 then " Guarded!" else ""), {
				Position = UDim2.fromOffset(14, 40),
				Size = UDim2.new(1, -190, 0, 30),
				Font = UIKit.Fonts.Small,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			})
			UIKit.Button(card, "Buy " .. priceText(tier.Price), C.Green, function()
				request("BuyMap", id)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 44) })
		end
	else
		local carrying = player:GetAttribute("CarryingTier")
		local card = UIKit.Card(scroll, 70, 0)
		UIKit.Label(card, if carrying
			then ("You carry a %s worth %sg!"):format(Config.Chests[carrying].DisplayName, Util.FormatNumber(player:GetAttribute("CarryingValue") or 0))
			else "Carry a treasure chest here to sell it.", {
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -200, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		})
		UIKit.Button(card, "Sell Treasure", if carrying then C.Gold else C.ParchmentDark, function()
			request("SellTreasure")
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(170, 44), TextColor3 = C.Ink })
		if data then
			for i, map in data.Maps do
				local tier = Config.MapTiers[map.Tier]
				local row = UIKit.Card(scroll, 52, 10 + i)
				UIKit.Label(row, ("%s - %s"):format(tier and tier.DisplayName or map.Tier, map.Island), {
					Position = UDim2.fromOffset(14, 0),
					Size = UDim2.new(1, -170, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				UIKit.Button(row, "Sell " .. Util.FormatNumber(math.floor((tier and tier.Price or 0) * Config.SellBackRate)) .. "g", C.Red, function()
					request("SellMap", map.Id)
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 38) })
			end
			for id, owned in data.Items do
				local item = Config.Items[id]
				if owned and item and not item.Starter then
					local row = UIKit.Card(scroll, 52, 50 + item.Order)
					UIKit.Label(row, item.DisplayName, {
						Position = UDim2.fromOffset(14, 0),
						Size = UDim2.new(1, -170, 1, 0),
						TextXAlignment = Enum.TextXAlignment.Left,
					})
					UIKit.Button(row, "Sell " .. Util.FormatNumber(math.floor(item.Price * Config.SellBackRate)) .. "g", C.Red, function()
						request("SellItem", id)
					end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 38) })
				end
			end
		end
	end
end

local function buildArmory(body: Frame)
	local data = State.Data
	local scroll = UIKit.Scroll(body)
	UIKit.List(scroll, 8)
	local ids = {}
	for id, item in Config.Items do
		if item.Shop == "Armory" then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return Config.Items[a].Order < Config.Items[b].Order
	end)
	for i, id in ids do
		local item = Config.Items[id]
		local owned = data ~= nil and data.Items[id] == true
		local card = UIKit.Card(scroll, 84, i)
		UIKit.Label(card, item.DisplayName, {
			Font = UIKit.Fonts.Title,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -200, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Wood,
		})
		local stats = item.Description
		if item.Damage then
			stats ..= ("  Damage %d."):format(item.Damage)
		end
		UIKit.Label(card, stats, {
			Position = UDim2.fromOffset(14, 40),
			Size = UDim2.new(1, -200, 0, 34),
			Font = UIKit.Fonts.Small,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		})
		if owned then
			UIKit.Button(card, "Sell " .. Util.FormatNumber(math.floor(item.Price * Config.SellBackRate)) .. "g", C.Red, function()
				request("SellItem", id)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 44) })
		else
			UIKit.Button(card, "Buy " .. priceText(item.Price), C.Green, function()
				request("BuyItem", id)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 44) })
		end
	end
end

local function buildTavern(body: Frame)
	local card = UIKit.Card(body, 120, 1)
	UIKit.Label(card, tavernMessage, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 1, -20),
		TextWrapped = true,
		Font = UIKit.Fonts.Body,
	})
	local buttons = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 50), Parent = body })
	UIKit.List(buttons, 12, true)
	UIKit.Button(buttons, ("Grog (%dg) - heals you"):format(Config.GrogPrice), C.Green, function()
		request("BuyGrog")
	end, { Size = UDim2.fromOffset(240, 46) })
	UIKit.Button(buttons, "Hear a rumour", C.Teal, function()
		local result = request("Rumor")
		if result and result.Ok then
			tavernMessage = '"' .. result.Message .. '"'
			ShopUI.Refresh()
		end
	end, { Size = UDim2.fromOffset(200, 46) })
end

function ShopUI.Refresh()
	if not currentShop or not window.Gui.Enabled then
		return
	end
	UIKit.Clear(window.Body)
	window.Title.Text = TITLES[currentShop] or currentShop
	if currentShop == "Shipwright" then
		buildShipwright(window.Body)
	elseif currentShop == "Merchant" then
		buildMerchant(window.Body)
	elseif currentShop == "Armory" then
		buildArmory(window.Body)
	elseif currentShop == "Tavern" then
		buildTavern(window.Body)
	end
end

function ShopUI.Open(shopId: string)
	if shopId == "TradingPost" then
		if ShopUI.OpenTrading then
			ShopUI.OpenTrading()
		end
		return
	end
	currentShop = shopId
	window.Gui.Enabled = true
	ShopUI.Refresh()
end

local function npcPosition(shopId: string): Vector3?
	for _, npc in CollectionService:GetTagged("ShopNPC") do
		if npc:GetAttribute("ShopId") == shopId then
			local root = npc:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				return root.Position
			end
		end
	end
	return nil
end

function ShopUI.Init()
	window = UIKit.Window("ShopWindow", "Shop", UDim2.fromOffset(640, 520))
	window.OnClose.Event:Connect(function()
		currentShop = nil
	end)
	Net.Event("OpenShop").OnClientEvent:Connect(ShopUI.Open)
	State.DataChanged.Event:Connect(ShopUI.Refresh)
	player:GetAttributeChangedSignal("CarryingTier"):Connect(ShopUI.Refresh)
	-- close the shop when walking away
	task.spawn(function()
		while true do
			task.wait(0.5)
			if currentShop and window.Gui.Enabled then
				local position = npcPosition(currentShop)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if position and root and root:IsA("BasePart") and (root.Position - position).Magnitude > 32 then
					window.Close()
				end
			end
		end
	end)
end

return ShopUI
