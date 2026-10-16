-- Shop windows for the shopkeepers of Kingshaven (opened from their dialogue, see
-- DialogueUI): ships and sail cosmetics, treasure maps, weapons and the tavern.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

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
local goldLabel: TextLabel
local currentShop: string? = nil
local busy = false
local tavernMessage = "Welcome to the Rusty Anchor, love! What'll it be?"
local tabs: { [string]: string } = { Shipwright = "Ships", Merchant = "Maps" }
local scrollMemory: { [string]: Vector2 } = {}

-- Customize tab: what is being previewed (nil symbol = plain sails)
local preview = { Color = Config.DefaultSailColor, Symbol = nil :: string?, Kind = "Symbol" }

-- Called when the Trading Post opens (set by the client entry script)
ShopUI.OpenTrading = nil :: (() -> ())?

local TITLES = {
	Shipwright = "Barnaby's Shipyard",
	Merchant = "Coralie's Trading Co.",
	Armory = "Ironhook's Armory",
	Tavern = "The Rusty Anchor",
}

local MASTS = { Sloop = 1, Brigantine = 2, Galleon = 3 }
local SIZES = {
	Shipwright = Vector2.new(780, 600),
	Merchant = Vector2.new(780, 600),
	Armory = Vector2.new(780, 470),
	Tavern = Vector2.new(700, 330),
}
local TIER_COLORS: { [string]: Color3 } = {
	Castaway = Color3.fromRGB(190, 150, 86),
	Seafarer = Color3.fromRGB(24, 134, 146),
	Marauder = Color3.fromRGB(150, 40, 40),
	Captain = Color3.fromRGB(92, 42, 124),
}

local function sortedIds<T>(tbl: { [string]: T }, order: (T) -> number): { string }
	local ids = {}
	for id in tbl do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return order(tbl[a]) < order(tbl[b])
	end)
	return ids
end

-- Ask the server (all validation happens there); shows the answer as a toast
function ShopUI.Request(action: string, arg: any?): any
	if busy then
		return nil
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
local request = ShopUI.Request

local function priceText(price: number): string
	return if price <= 0 then "FREE" else Util.FormatNumber(price) .. "g"
end

local function cosmetics()
	local data = State.Data
	local c = data and data.Cosmetics
	return {
		SailColors = if c then c.SailColors else { [Config.DefaultSailColor] = true },
		Symbols = if c then c.Symbols else {},
		SailColor = if c then c.SailColor else Config.DefaultSailColor,
		Symbol = if c then c.Symbol else "",
	}
end

local function smallText(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = UIKit.Label(parent, text, {
		FontFace = UIKit.Fonts.Text,
		TextScaled = false,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.Ink,
		LineHeight = 1.1,
	})
	if props then
		for k, v in props do
			(label :: any)[k] = v
		end
	end
	return label
end

local function card(parent: Instance, height: number, order: number): Frame
	local c = UIKit.Card(parent, height, order)
	UIKit.Hover(c)
	return c
end

local function statBar(parent: Instance, x: number, y: number, label: string, frac: number, color: Color3?)
	UIKit.Label(parent, label, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(62, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = UIKit.Fonts.Small,
		TextScaled = false,
		TextSize = 12,
		TextColor3 = C.WoodLight,
	})
	local back = UIKit.new("Frame", {
		Position = UDim2.fromOffset(x + 64, y + 3),
		Size = UDim2.fromOffset(84, 10),
		BackgroundColor3 = Color3.fromRGB(214, 192, 148),
		Parent = parent,
	})
	UIKit.Corner(back, 5)
	UIKit.Stroke(back, Color3.fromRGB(170, 136, 90), 1)
	local fill = UIKit.new("Frame", { Size = UDim2.fromScale(math.clamp(frac, 0.06, 1), 1), BackgroundColor3 = color or C.Teal, Parent = back })
	UIKit.Corner(fill, 5)
	UIKit.Gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180))
end

-- Right-hand corner of a card: price tag or a status badge
local function cornerTag(parent: Instance, owned: boolean, price: number, ownedText: string?, ownedColor: Color3?)
	if owned then
		UIKit.Badge(parent, ownedText or "OWNED", ownedColor or C.Green, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
		})
	else
		UIKit.PriceTag(parent, price, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 10),
		})
	end
end

---------------------------------------------------------------------------
-- 2D ship / sail drawings
---------------------------------------------------------------------------
local function emblem(parent: Instance, symbol: Config.SailSymbolDef, size: UDim2, position: UDim2)
	local badge = UIKit.new("Frame", {
		Name = "Emblem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = symbol.BadgeColor,
		Parent = parent,
	})
	UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = badge })
	UIKit.Round(badge)
	UIKit.Stroke(badge, Color3.fromRGB(226, 178, 74), 2)
	UIKit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.74, 0.74),
		BackgroundTransparency = 1,
		Text = symbol.Glyph,
		TextScaled = true,
		TextColor3 = C.White,
		Parent = badge,
	})
	return badge
end

local function sail(parent: Instance, color: Color3, x: number, y: number, w: number, h: number): Frame
	local cloth = UIKit.new("Frame", {
		Name = "Sail",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
	UIKit.Corner(cloth, 3)
	UIKit.Stroke(cloth, Color3.fromRGB(40, 28, 18), 1).Transparency = 0.5
	-- billow: darker edges, lit middle
	UIKit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(176, 176, 176)),
			ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 160)),
		}),
		Parent = cloth,
	})
	return cloth
end

-- A little ship (bow to the right) with the given sail colour and symbol
local function drawShip(art: Frame, masts: number, sailColor: Color3, symbol: Config.SailSymbolDef?)
	art.ClipsDescendants = true
	art.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	UIKit.Gradient(art, Color3.fromRGB(120, 196, 236), Color3.fromRGB(226, 244, 250))
	local wood = Color3.fromRGB(74, 46, 26)
	-- sea
	local sea = UIKit.new("Frame", {
		Name = "Sea",
		Position = UDim2.fromScale(0, 0.74),
		Size = UDim2.fromScale(1, 0.26),
		BackgroundColor3 = Color3.fromRGB(26, 150, 170),
		BorderSizePixel = 0,
		Parent = art,
	})
	UIKit.Gradient(sea, Color3.fromRGB(255, 255, 255), Color3.fromRGB(110, 140, 160))
	-- hull: the bottom half of a rounded bar
	local hullTop, hullH, x0, x1 = 0.6, 0.2, 0.12, 0.84
	local clip = UIKit.new("Frame", {
		Name = "Hull",
		Position = UDim2.fromScale(x0, hullTop),
		Size = UDim2.fromScale(x1 - x0, hullH),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = art,
	})
	local body = UIKit.new("Frame", {
		Position = UDim2.fromScale(0, -1),
		Size = UDim2.fromScale(1, 2),
		BackgroundColor3 = wood,
		Parent = clip,
	})
	UIKit.Round(body)
	UIKit.Gradient(body, Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 120))
	-- gold trim along the rail and a raised stern castle
	UIKit.new("Frame", {
		Name = "Trim",
		Position = UDim2.fromScale(x0, hullTop),
		Size = UDim2.new(x1 - x0, 0, 0, 3),
		BackgroundColor3 = C.GoldDark,
		BorderSizePixel = 0,
		Parent = art,
	})
	local castle = UIKit.new("Frame", {
		Name = "Castle",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(x0 + 0.005, hullTop + 0.01),
		Size = UDim2.fromScale(0.17, 0.09),
		BackgroundColor3 = wood,
		Parent = art,
	})
	UIKit.Corner(castle, 3)
	UIKit.new("Frame", {
		Name = "Bowsprit",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(x1 - 0.04, hullTop + 0.01),
		Size = UDim2.new(0.18, 0, 0, 3),
		Rotation = -16,
		BackgroundColor3 = wood,
		BorderSizePixel = 0,
		Parent = art,
	})
	-- masts and sails
	local xs = if masts >= 3 then { 0.3, 0.5, 0.69 } elseif masts == 2 then { 0.36, 0.6 } else { 0.48 }
	local sailW = if masts >= 3 then 0.17 elseif masts == 2 then 0.22 else 0.3
	local mainIndex = if masts >= 3 then 2 else 1
	for i, x in xs do
		local mh = if i == mainIndex then 0.5 else 0.42
		local top = hullTop - mh
		UIKit.new("Frame", {
			Name = "Mast",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(x, top),
			Size = UDim2.new(0, 3, mh, 0),
			BackgroundColor3 = wood,
			BorderSizePixel = 0,
			Parent = art,
		})
		local w = if i == mainIndex then sailW else sailW * 0.88
		local course = sail(art, sailColor, x, top + mh * 0.42, w, mh * 0.42)
		sail(art, sailColor, x, top + mh * 0.08, w * 0.8, mh * 0.3)
		if i == mainIndex then
			if symbol then
				emblem(course, symbol, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.5, 0.5))
			end
			local flag = UIKit.new("Frame", {
				Name = "Flag",
				Position = UDim2.new(x, 1, top - 0.05, 0),
				Size = UDim2.fromScale(0.08, 0.06),
				BackgroundColor3 = Color3.fromRGB(24, 22, 26),
				BorderSizePixel = 0,
				Parent = art,
			})
			UIKit.new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "☠",
				TextScaled = true,
				TextColor3 = Color3.fromRGB(240, 236, 226),
				Parent = flag,
			})
		end
	end
end

---------------------------------------------------------------------------
-- Shipwright: ships
---------------------------------------------------------------------------
local function buildShips(body: Frame)
	local data = State.Data
	local look = cosmetics()
	local colorDef = Config.SailColors[look.SailColor] or Config.SailColors[Config.DefaultSailColor]
	local symbolDef = if look.Symbol ~= "" then Config.SailSymbols[look.Symbol] else nil
	local scroll = UIKit.Scroll(body, { Name = "Scroll", Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50) })
	UIKit.List(scroll, 10)
	for i, id in sortedIds(Config.Ships, function(def)
		return def.Order
	end) do
		local def = Config.Ships[id]
		local owned = data ~= nil and data.Ships[id] == true
		local c = card(scroll, 150, i)
		local art = UIKit.new("Frame", {
			Name = "Art",
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(176, 130),
			Parent = c,
		})
		UIKit.Corner(art, 8)
		UIKit.Stroke(art, C.Wood, 2)
		drawShip(art, MASTS[id] or 1, colorDef.Color, symbolDef)
		UIKit.Heading(c, def.DisplayName, {
			Position = UDim2.fromOffset(200, 10),
			Size = UDim2.new(1, -400, 0, 30),
		})
		UIKit.Label(c, ("Crew %d  ·  %d cannons  ·  %s hull"):format(def.Crew, def.Cannons, Util.FormatNumber(def.MaxHP)), {
			FontFace = UIKit.Fonts.Small,
			Position = UDim2.fromOffset(200, 40),
			Size = UDim2.new(1, -400, 0, 16),
			TextScaled = false,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.WoodLight,
		})
		smallText(c, def.Description, {
			Position = UDim2.fromOffset(200, 60),
			Size = UDim2.new(1, -400, 0, 36),
		})
		statBar(c, 200, 102, "Speed", def.MaxSpeed / 50, C.Teal)
		statBar(c, 200, 122, "Hull", def.MaxHP / 1200, C.Green)
		statBar(c, 356, 102, "Turning", def.TurnRate / math.rad(17), C.Sea)
		statBar(c, 356, 122, "Cannons", def.Cannons / 8, C.Crimson)
		cornerTag(c, owned, def.Price)
		local button = if owned
			then UIKit.Button(c, "Launch", C.Teal, function()
				local result = request("LaunchShip", id)
				if result and result.Ok then
					window.Close()
				end
			end)
			else UIKit.Button(c, "Buy", C.Green, function()
				request("BuyShip", id)
			end)
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, -12, 1, -12)
		button.Size = UDim2.fromOffset(150, 46)
	end
	local footer = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -14, 0, 52), LayoutOrder = 10, Parent = scroll })
	UIKit.Button(footer, "Return my ship to port", C.Crimson, function()
		request("ScuttleShip")
	end, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(280, 42) })
end

---------------------------------------------------------------------------
-- Shipwright: sail colours and symbols
---------------------------------------------------------------------------
local function selectStroke(frame: GuiObject, selected: boolean)
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke and selected then
		stroke.Color = C.Gold
		stroke.Thickness = 3
	end
end

local function buildCustomize(body: Frame)
	local look = cosmetics()
	local previewColor = Config.SailColors[preview.Color] or Config.SailColors[Config.DefaultSailColor]
	local previewSymbol = if preview.Symbol then Config.SailSymbols[preview.Symbol] else nil

	-- left column: live preview + action (scrolls when the window is squeezed on phones)
	local left = UIKit.Scroll(body, {
		Name = "PreviewColumn",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(0, 308, 1, -50),
		ScrollBarThickness = 5,
	})
	local art = UIKit.new("Frame", {
		Name = "Preview",
		Size = UDim2.fromOffset(300, 214),
		Parent = left,
	})
	UIKit.Corner(art, 10)
	UIKit.Stroke(art, C.Wood, 3)
	local data = State.Data
	local shipId = if data and data.Ships.Galleon then "Galleon" elseif data and data.Ships.Brigantine then "Brigantine" else "Sloop"
	drawShip(art, MASTS[shipId] or 1, previewColor.Color, previewSymbol)
	UIKit.Badge(art, "PREVIEW", C.WoodDark, { Position = UDim2.fromOffset(8, 8) })

	local title, info
	if preview.Kind == "Color" then
		title = previewColor.DisplayName .. " sails"
		info = previewColor.Description
	elseif previewSymbol then
		title = previewSymbol.DisplayName
		info = "Painted in a golden ring on your biggest sails, front and back."
	else
		title = "Plain sails"
		info = "No symbol. Mysterious... or just cheap."
	end
	UIKit.Heading(left, title, { Name = "SelectedName", Position = UDim2.fromOffset(2, 222), Size = UDim2.new(1, 0, 0, 30) })
	smallText(left, info, { Name = "SelectedInfo", Position = UDim2.fromOffset(2, 254), Size = UDim2.new(1, 0, 0, 36) })

	local buttonText, buttonColor, action, arg = "", C.Teal, nil :: string?, nil :: string?
	if preview.Kind == "Color" then
		local id = previewColor.Id
		if look.SailColor == id then
			buttonText, buttonColor = "Rigged on your ship", C.ParchmentDark
		elseif look.SailColors[id] then
			buttonText, action, arg = "Rig these sails", "EquipSailColor", id
		else
			buttonText, buttonColor, action, arg = "Buy & rig  ·  " .. priceText(previewColor.Price), C.Green, "BuySailColor", id
		end
	elseif previewSymbol then
		local id = previewSymbol.Id
		if look.Symbol == id then
			buttonText, buttonColor = "Painted on your sails", C.ParchmentDark
		elseif look.Symbols[id] then
			buttonText, action, arg = "Paint this symbol", "EquipSymbol", id
		else
			buttonText, buttonColor, action, arg = "Buy & paint  ·  " .. priceText(previewSymbol.Price), C.Green, "BuySymbol", id
		end
	elseif look.Symbol ~= "" then
		buttonText, buttonColor, action = "Scrub off the symbol", C.Crimson, "ClearSymbol"
	else
		buttonText, buttonColor = "Your sails are plain", C.ParchmentDark
	end
	UIKit.Button(left, buttonText, buttonColor, function()
		if action then
			request(action, arg)
		end
	end, {
		Name = "Action",
		Position = UDim2.fromOffset(0, 298),
		Size = UDim2.fromOffset(300, 46),
		TextColor3 = if action then C.White else C.Ink,
		AutoButtonColor = false,
	})
	if look.SailColor ~= previewColor.Id or (preview.Symbol or "") ~= look.Symbol then
		UIKit.Button(left, "Show my current sails", C.WoodLight, function()
			preview.Color = look.SailColor
			preview.Symbol = if look.Symbol ~= "" then look.Symbol else nil
			ShopUI.Refresh()
		end, { Name = "Reset", Position = UDim2.fromOffset(40, 352), Size = UDim2.fromOffset(220, 34) })
	end

	-- right column: swatches and symbols
	local scroll = UIKit.Scroll(body, {
		Name = "Scroll",
		Position = UDim2.fromOffset(320, 50),
		Size = UDim2.new(1, -320, 1, -50),
	})
	UIKit.List(scroll, 8, false, Enum.HorizontalAlignment.Left)
	UIKit.Heading(scroll, "Sail Cloth", { LayoutOrder = 1, Size = UDim2.new(1, -14, 0, 24) })
	local swatches = UIKit.new("Frame", { Name = "Swatches", BackgroundTransparency = 1, Size = UDim2.new(1, -14, 0, 104), LayoutOrder = 2, Parent = scroll })
	UIKit.List(swatches, 8, true, Enum.HorizontalAlignment.Left)
	for i, id in sortedIds(Config.SailColors, function(def)
		return def.Order
	end) do
		local def = Config.SailColors[id]
		local owned = look.SailColors[id] == true
		local cell = UIKit.new("TextButton", {
			Name = id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(255, 251, 238),
			Size = UDim2.fromOffset(120, 104),
			LayoutOrder = i,
			Parent = swatches,
		})
		UIKit.Corner(cell, 10)
		UIKit.Stroke(cell, Color3.fromRGB(190, 152, 98), 1.5)
		UIKit.Gradient(cell, Color3.new(1, 1, 1), Color3.fromRGB(236, 226, 206))
		UIKit.Hover(cell)
		selectStroke(cell, preview.Kind == "Color" and preview.Color == id)
		-- a tiny sail on its yard
		UIKit.new("Frame", {
			Position = UDim2.new(0.5, -34, 0, 10),
			Size = UDim2.fromOffset(68, 4),
			BackgroundColor3 = C.Wood,
			BorderSizePixel = 0,
			Parent = cell,
		})
		sail(cell, def.Color, 0.5, 0.13, 0.48, 0.36)
		UIKit.Label(cell, def.DisplayName, {
			Position = UDim2.fromOffset(4, 54),
			Size = UDim2.new(1, -8, 0, 18),
			TextScaled = true,
			TextColor3 = C.Wood,
		})
		if look.SailColor == id then
			UIKit.Badge(cell, "RIGGED", C.GoldDark, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76) })
		elseif owned then
			UIKit.Badge(cell, "OWNED", C.Green, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76) })
		else
			UIKit.PriceTag(cell, def.Price, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74) })
		end
		cell.Activated:Connect(function()
			preview.Color = id
			preview.Kind = "Color"
			ShopUI.Refresh()
		end)
	end

	local ownedCount = 0
	for _ in look.Symbols do
		ownedCount += 1
	end
	local symbolIds = sortedIds(Config.SailSymbols, function(def)
		return def.Order
	end)
	UIKit.Heading(scroll, ("Symbols  ·  %d / %d owned"):format(ownedCount, #symbolIds), { LayoutOrder = 3, Size = UDim2.new(1, -14, 0, 24) })
	local grid = UIKit.new("Frame", {
		Name = "SymbolGrid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -14, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = scroll,
	})
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(88, 106),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local function symbolCell(id: string?, order: number)
		local def = if id then Config.SailSymbols[id] else nil
		local cell = UIKit.new("TextButton", {
			Name = id or "None",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(255, 251, 238),
			LayoutOrder = order,
			Parent = grid,
		})
		UIKit.Corner(cell, 10)
		UIKit.Stroke(cell, Color3.fromRGB(190, 152, 98), 1.5)
		UIKit.Gradient(cell, Color3.new(1, 1, 1), Color3.fromRGB(236, 226, 206))
		UIKit.Hover(cell)
		selectStroke(cell, preview.Kind == "Symbol" and preview.Symbol == id)
		if def then
			UIKit.Icon(cell, def.Glyph, 46, def.BadgeColor, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 7) })
		else
			local none = UIKit.Icon(cell, "", 46, Color3.fromRGB(226, 214, 190), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 7) })
			UIKit.Label(none, "none", { Size = UDim2.fromScale(1, 1), TextColor3 = C.WoodLight, TextScaled = false, TextSize = 13 })
		end
		UIKit.Label(cell, if def then def.DisplayName else "Plain sails", {
			FontFace = UIKit.Fonts.Small,
			Position = UDim2.fromOffset(3, 56),
			Size = UDim2.new(1, -6, 0, 22),
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = C.Wood,
		})
		local equipped = if id then look.Symbol == id else look.Symbol == ""
		if equipped then
			UIKit.Badge(cell, "PAINTED", C.GoldDark, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5) })
		elseif not def or look.Symbols[def.Id] then
			UIKit.Badge(cell, "OWNED", C.Green, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5) })
		else
			UIKit.PriceTag(cell, def.Price, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4) })
		end
		cell.Activated:Connect(function()
			preview.Symbol = id
			preview.Kind = "Symbol"
			ShopUI.Refresh()
		end)
	end
	symbolCell(nil, 0)
	for i, id in symbolIds do
		symbolCell(id, i)
	end
end

---------------------------------------------------------------------------
-- Merchant
---------------------------------------------------------------------------
local function buildMerchant(body: Frame)
	local data = State.Data
	local scroll = UIKit.Scroll(body, { Name = "Scroll", Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50) })
	UIKit.List(scroll, 8)

	if tabs.Merchant == "Maps" then
		local count = if data then #data.Maps else 0
		smallText(scroll, ("Your maps: %d / %d. Hold a map to see where X marks the spot."):format(count, Config.MaxMaps), {
			Size = UDim2.new(1, -14, 0, 20),
			LayoutOrder = 0,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.WoodLight,
		})
		for i, id in sortedIds(Config.MapTiers, function(def)
			return def.Order
		end) do
			local tier = Config.MapTiers[id]
			local chest = Config.Chests[tier.Chest]
			local c = card(scroll, 96, i)
			UIKit.Icon(c, "🗺️", 64, TIER_COLORS[id] or C.Sea, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0) })
			UIKit.Heading(c, tier.DisplayName, { Position = UDim2.fromOffset(94, 10), Size = UDim2.new(1, -290, 0, 28) })
			local where = if tier.NearIslands then "nearby islands" elseif tier.FarIslands then "far-away islands" else "any island"
			local guards = if tier.Guards > 0 then ("  Guarded by %d skeleton%s!"):format(tier.Guards, if tier.Guards == 1 then "" else "s") else ""
			smallText(c, ("Leads to a %s worth %sg on %s.%s"):format(chest.DisplayName, Util.FormatNumber(chest.Value), where, guards), {
				Position = UDim2.fromOffset(94, 42),
				Size = UDim2.new(1, -290, 0, 44),
			})
			cornerTag(c, false, tier.Price)
			UIKit.Button(c, "Buy Map", C.Green, function()
				request("BuyMap", id)
			end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(150, 42) })
		end
	else
		local carrying = player:GetAttribute("CarryingTier")
		local chest = if type(carrying) == "string" then Config.Chests[carrying] else nil
		local c = card(scroll, 86, 0)
		UIKit.Icon(c, if carrying == "King" then "👑" else "💰", 58, C.GoldDark, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0) })
		UIKit.Heading(c, if chest then chest.DisplayName else "Treasure", { Position = UDim2.fromOffset(88, 10), Size = UDim2.new(1, -290, 0, 28) })
		smallText(c, if chest
			then ("Worth %s gold. Hand it over, chéri!"):format(Util.FormatNumber(player:GetAttribute("CarryingValue") or 0))
			else "Carry a treasure chest to my counter and I'll pay in gold.", {
			Position = UDim2.fromOffset(88, 42),
			Size = UDim2.new(1, -290, 0, 36),
		})
		UIKit.Button(c, "Sell Treasure", if chest then C.GoldDark else C.ParchmentDark, function()
			request("SellTreasure")
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(170, 44), TextColor3 = if chest then C.White else C.Ink })
		local any = false
		if data then
			for i, map in data.Maps do
				any = true
				local tier = Config.MapTiers[map.Tier]
				local row = card(scroll, 60, 10 + i)
				UIKit.Icon(row, "🗺️", 40, TIER_COLORS[map.Tier] or C.Sea, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0) })
				UIKit.Label(row, ("%s  ·  %s"):format(tier and tier.DisplayName or map.Tier, map.Island), {
					Position = UDim2.fromOffset(64, 0),
					Size = UDim2.new(1, -240, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextScaled = false,
					TextSize = 18,
					TextColor3 = C.Wood,
				})
				UIKit.Button(row, "Sell  ·  " .. priceText(math.floor((tier and tier.Price or 0) * Config.SellBackRate)), C.Crimson, function()
					request("SellMap", map.Id)
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(160, 38) })
			end
			for id, owned in data.Items do
				local item = Config.Items[id]
				if owned and item and not item.Starter then
					any = true
					local row = card(scroll, 60, 50 + item.Order)
					UIKit.Icon(row, item.Icon or "⚔️", 40, C.Navy, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0) })
					UIKit.Label(row, item.DisplayName, {
						Position = UDim2.fromOffset(64, 0),
						Size = UDim2.new(1, -240, 1, 0),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextScaled = false,
						TextSize = 18,
						TextColor3 = C.Wood,
					})
					UIKit.Button(row, "Sell  ·  " .. priceText(math.floor(item.Price * Config.SellBackRate)), C.Crimson, function()
						request("SellItem", id)
					end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(160, 38) })
				end
			end
		end
		if not any then
			smallText(scroll, "No maps or fine weapons to sell. Starter gear stays with you.", {
				Size = UDim2.new(1, -14, 0, 24),
				LayoutOrder = 100,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = C.WoodLight,
			})
		end
	end
end

---------------------------------------------------------------------------
-- Armory
---------------------------------------------------------------------------
local function buildArmory(body: Frame)
	local data = State.Data
	local scroll = UIKit.Scroll(body, { Name = "Scroll" })
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
		local c = card(scroll, 104, i)
		UIKit.Icon(c, item.Icon or "⚔️", 70, if string.find(id, "Golden") then C.GoldDark else C.Navy, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
		})
		UIKit.Heading(c, item.DisplayName, { Position = UDim2.fromOffset(100, 10), Size = UDim2.new(1, -300, 0, 28) })
		local chips = {}
		if item.Damage then
			table.insert(chips, ("Damage %d"):format(item.Damage))
		end
		if item.Cooldown then
			table.insert(chips, ("Reload %.1fs"):format(item.Cooldown))
		end
		if item.Range and item.Range > 20 then
			table.insert(chips, ("Range %d"):format(item.Range))
		end
		if item.DigStrikes then
			table.insert(chips, ("%d strikes per chest"):format(item.DigStrikes))
		end
		UIKit.Label(c, table.concat(chips, "  ·  "), {
			FontFace = UIKit.Fonts.Small,
			Position = UDim2.fromOffset(100, 40),
			Size = UDim2.new(1, -300, 0, 16),
			TextScaled = false,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Crimson,
		})
		smallText(c, item.Description, { Position = UDim2.fromOffset(100, 60), Size = UDim2.new(1, -300, 0, 36) })
		cornerTag(c, owned, item.Price)
		if owned then
			UIKit.Button(c, "Sell  ·  " .. priceText(math.floor(item.Price * Config.SellBackRate)), C.Crimson, function()
				request("SellItem", id)
			end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(160, 42) })
		else
			UIKit.Button(c, "Buy", C.Green, function()
				request("BuyItem", id)
			end, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(160, 42) })
		end
	end
end

---------------------------------------------------------------------------
-- Tavern
---------------------------------------------------------------------------
local function buildTavern(body: Frame)
	local c = UIKit.Card(body, 150, 1)
	c.Size = UDim2.new(1, 0, 0, 150)
	UIKit.Icon(c, "🍺", 84, C.Green, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0) })
	UIKit.Heading(c, "Rosie says...", { Position = UDim2.fromOffset(120, 14), Size = UDim2.new(1, -140, 0, 28) })
	smallText(c, tavernMessage, {
		FontFace = UIKit.Fonts.Small,
		TextSize = 18,
		Position = UDim2.fromOffset(120, 48),
		Size = UDim2.new(1, -140, 1, -60),
	})
	local buttons = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 170), Size = UDim2.new(1, 0, 0, 50), Parent = body })
	UIKit.List(buttons, 14, true)
	UIKit.Button(buttons, ("Grog  ·  %dg  ·  heals you"):format(Config.GrogPrice), C.Green, function()
		request("BuyGrog")
	end, { Size = UDim2.fromOffset(270, 48) })
	UIKit.Button(buttons, "Hear a rumour", C.Teal, function()
		local result = request("Rumor")
		if result and result.Ok then
			tavernMessage = '"' .. result.Message .. '"'
			ShopUI.Refresh()
		end
	end, { Size = UDim2.fromOffset(220, 48) })
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function rememberScroll()
	local old = window.Body:FindFirstChild("Scroll")
	if old and old:IsA("ScrollingFrame") and currentShop then
		scrollMemory[currentShop .. (tabs[currentShop] or "")] = old.CanvasPosition
	end
end

local function restoreScroll()
	local new = window.Body:FindFirstChild("Scroll")
	local saved = currentShop and scrollMemory[currentShop .. (tabs[currentShop] or "")]
	if saved and new and new:IsA("ScrollingFrame") then
		new.CanvasPosition = saved
	end
end

function ShopUI.Refresh()
	if not currentShop or not window.Gui.Enabled then
		return
	end
	rememberScroll()
	UIKit.Clear(window.Body)
	local shopId = currentShop :: string
	window.Title.Text = TITLES[shopId] or shopId
	UIKit.SetWindowSize(window, SIZES[shopId] or Vector2.new(780, 600))
	if shopId == "Shipwright" then
		UIKit.Tabs(window.Body, {
			{ Id = "Ships", Text = "Ships" },
			{ Id = "Customize", Text = "Sails & Symbols" },
		}, tabs.Shipwright, function(id)
			if id == "Customize" and tabs.Shipwright ~= "Customize" then
				local look = cosmetics()
				preview.Color = look.SailColor
				preview.Symbol = if look.Symbol ~= "" then look.Symbol else nil
				preview.Kind = "Symbol"
			end
			tabs.Shipwright = id
			ShopUI.Refresh()
		end)
		if tabs.Shipwright == "Customize" then
			buildCustomize(window.Body)
		else
			buildShips(window.Body)
		end
	elseif shopId == "Merchant" then
		UIKit.Tabs(window.Body, {
			{ Id = "Maps", Text = "Treasure Maps" },
			{ Id = "Sell", Text = "Sell Goods" },
		}, tabs.Merchant, function(id)
			tabs.Merchant = id
			ShopUI.Refresh()
		end)
		buildMerchant(window.Body)
	elseif shopId == "Armory" then
		buildArmory(window.Body)
	elseif shopId == "Tavern" then
		buildTavern(window.Body)
	end
	restoreScroll()
end

function ShopUI.Open(shopId: string, tab: string?)
	if shopId == "TradingPost" then
		if ShopUI.OpenTrading then
			ShopUI.OpenTrading()
		end
		return
	end
	if not TITLES[shopId] then
		return
	end
	if tab and tabs[shopId] ~= nil then
		tabs[shopId] = tab
	end
	if shopId == "Shipwright" then
		local look = cosmetics()
		preview.Color = look.SailColor
		preview.Symbol = if look.Symbol ~= "" then look.Symbol else nil
		preview.Kind = "Symbol"
	end
	currentShop = shopId
	window.Gui.Enabled = true
	ShopUI.Refresh()
end

function ShopUI.CloseWindow()
	if window.Gui.Enabled then
		window.Close()
	end
end

function ShopUI.IsOpen(): boolean
	return window.Gui.Enabled
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
	window = UIKit.Window("ShopWindow", "Shop", UDim2.fromOffset(780, 590))
	-- your purse, top-left of the window
	local purse = UIKit.new("Frame", {
		Name = "Purse",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0, 30),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.WoodDark,
		Parent = window.Header,
	})
	UIKit.Round(purse)
	UIKit.Stroke(purse, C.GoldDark, 1.5)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 14), Parent = purse })
	local purseList = UIKit.List(purse, 6, true, Enum.HorizontalAlignment.Left)
	purseList.VerticalAlignment = Enum.VerticalAlignment.Center
	UIKit.Coin(purse, 26).LayoutOrder = 1
	goldLabel = UIKit.new("TextLabel", {
		Name = "Gold",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "0",
		FontFace = UIKit.Fonts.Title,
		TextSize = 19,
		TextColor3 = C.Gold,
		LayoutOrder = 2,
		Parent = purse,
	})
	UIKit.TextStroke(goldLabel, C.Shadow, 1.5, 0.2)
	local function updateGold()
		goldLabel.Text = Util.FormatNumber(if State.Data then State.Data.Gold else 0)
	end
	updateGold()

	window.OnClose.Event:Connect(function()
		currentShop = nil
	end)
	State.DataChanged.Event:Connect(function()
		updateGold()
		ShopUI.Refresh()
	end)
	player:GetAttributeChangedSignal("CarryingTier"):Connect(ShopUI.Refresh)
	-- close the shop when walking away
	task.spawn(function()
		while true do
			task.wait(0.5)
			local shopId = currentShop
			if shopId and window.Gui.Enabled then
				local position = npcPosition(shopId)
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
