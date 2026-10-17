-- Heads-up display: compass + wind, location, gold, menu buttons, ship status,
-- carry hint, notifications and hit markers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local State = require(script.Parent.State)
local UIKit = require(script.Parent.UIKit)

local HUD = {}

local player = Players.LocalPlayer
local C = UIKit.Colors

local gui: ScreenGui
local notifications: Frame
local goldLabel: TextLabel
local compassStrip: Frame
local windArrow: TextLabel
local locationLabel: TextLabel
local safeBadge: TextLabel
local shipPanel: Frame
local shipName: TextLabel
local hpFill: Frame
local sailFill: Frame
local shipInfo: TextLabel
local carryPanel: Frame
local carryLabel: TextLabel
local hitMarker: TextLabel
local menu: Frame
local compassHolder: Frame
local shownGold = 0
local dialogueOpen = false -- bottom panels make room for a shopkeeper's dialogue

local KIND_COLORS = {
	info = Color3.fromRGB(40, 32, 26),
	good = Color3.fromRGB(34, 110, 60),
	bad = Color3.fromRGB(150, 40, 34),
	gold = Color3.fromRGB(150, 104, 16),
	warn = Color3.fromRGB(170, 90, 20),
}

function HUD.Notify(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	local pill = UIKit.new("Frame", {
		BackgroundColor3 = C.WoodDark,
		BackgroundTransparency = 0.08,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = notifications,
	})
	UIKit.Corner(pill, 10)
	UIKit.Stroke(pill, color:Lerp(C.Gold, 0.35), 2).Transparency = 0.1
	UIKit.Gradient(pill, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 16), Parent = pill })
	-- coloured tab on the left shows the kind of message
	local tab = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -16, 0.5, 0),
		Size = UDim2.fromOffset(6, 22),
		BackgroundColor3 = color:Lerp(C.White, 0.25),
		Parent = pill,
	})
	UIKit.Corner(tab, 3)
	local label = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		Text = text,
		FontFace = UIKit.Fonts.Body,
		TextSize = 19,
		TextColor3 = if kind == "gold" then C.Gold else C.Parchment,
		Parent = pill,
	})
	local stroke = UIKit.TextStroke(label, C.Shadow, 1.5, 0.2)
	local items = notifications:GetChildren()
	local frames = {}
	for _, child in items do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames > 5 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
	task.delay(4.5, function()
		if pill.Parent then
			TweenService:Create(pill, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			TweenService:Create(tab, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			for _, s in pill:GetChildren() do
				if s:IsA("UIStroke") then
					TweenService:Create(s, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end
			end
			task.wait(0.5)
			pill:Destroy()
		end
	end)
end

function HUD.HitMarker()
	hitMarker.TextTransparency = 0
	hitMarker.Size = UDim2.fromOffset(44, 44)
	TweenService:Create(hitMarker, TweenInfo.new(0.35), { TextTransparency = 1, Size = UDim2.fromOffset(30, 30) }):Play()
end

function HUD.CoinBurst()
	for i = 1, 8 do
		local coin = UIKit.Coin(gui, 18)
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Position = UDim2.fromScale(0.5, 0.55)
		local target = goldLabel.AbsolutePosition + goldLabel.AbsoluteSize / 2
		local offset = Vector2.new(math.random(-80, 80), math.random(-60, 20))
		TweenService:Create(coin, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, offset.X, 0.55, offset.Y) }):Play()
		task.delay(0.25 + i * 0.04, function()
			local tween = TweenService:Create(coin, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(target.X, target.Y),
			})
			tween:Play()
			tween.Completed:Wait()
			coin:Destroy()
		end)
	end
end

-- Other controllers add their buttons to the right-hand menu
function HUD.AddMenuButton(text: string, key: Enum.KeyCode?, order: number, color: Color3, callback: () -> ())
	local button = UIKit.Button(menu, text, color, callback, { Size = UDim2.fromOffset(156, 42), LayoutOrder = order })
	if key then
		button.Text = ("%s [%s]"):format(text, key.Name)
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == key then
				callback()
			end
		end)
	end
	return button
end

local function buildCompass()
	local holder = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(440, 38),
		BackgroundColor3 = C.WoodDark,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	compassHolder = holder
	UIKit.Corner(holder, 10)
	UIKit.Stroke(holder, C.GoldDark, 2).Transparency = 0.1
	UIKit.Gradient(holder, Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 140))
	compassStrip = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Parent = holder,
	})
	local names = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
	for i = 0, 23 do
		local heading = i * 15
		local major = heading % 45 == 0
		local label = UIKit.new("TextLabel", {
			Name = tostring(heading),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(40, 30),
			Text = if major then names[heading // 45 + 1] else "·",
			FontFace = UIKit.Fonts.Title,
			TextSize = if major then (if heading % 90 == 0 then 22 else 15) else 16,
			TextColor3 = if heading == 0 then Color3.fromRGB(255, 96, 72) elseif major then C.Gold else C.Rope,
			Parent = compassStrip,
		})
		if major then
			UIKit.TextStroke(label, C.Shadow, 1.5, 0.2)
		end
		label:SetAttribute("Heading", heading)
	end
	UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(4, 8),
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		Parent = compassStrip,
	})
	-- wind indicator on the left of the compass
	UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.fromOffset(30, 12),
		Text = "WIND",
		FontFace = UIKit.Fonts.Title,
		TextSize = 10,
		TextColor3 = C.Parchment,
		Parent = holder,
	})
	windArrow = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(38, 22),
		Size = UDim2.fromOffset(22, 22),
		Text = "→",
		FontFace = UIKit.Fonts.Body,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(150, 230, 255),
		Parent = holder,
	})
	locationLabel = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(400, 24),
		Text = "",
		FontFace = UIKit.Fonts.Title,
		TextSize = 24,
		TextColor3 = C.Parchment,
		Parent = gui,
	})
	UIKit.TextStroke(locationLabel, C.Shadow, 2)
	UIKit.Gradient(locationLabel, Color3.fromRGB(255, 252, 236), Color3.fromRGB(255, 214, 120))
	safeBadge = UIKit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "⚓ SAFE HAVEN  ·  no fighting here",
		FontFace = UIKit.Fonts.Body,
		TextSize = 14,
		TextColor3 = C.White,
		BackgroundColor3 = Color3.fromRGB(46, 120, 70),
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	UIKit.Corner(safeBadge, 6)
	UIKit.Stroke(safeBadge, C.Shadow, 1.5).Transparency = 0.3
	UIKit.TextStroke(safeBadge, C.Shadow, 1, 0.4)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = safeBadge })
end

local function buildGold()
	local pill = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0.3, 0),
		Size = UDim2.fromOffset(156, 46),
		BackgroundColor3 = C.WoodDark,
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	UIKit.Corner(pill, 23)
	UIKit.Stroke(pill, C.GoldDark, 2)
	UIKit.Gradient(pill, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	local coin = UIKit.Coin(pill, 32)
	coin.Position = UDim2.fromOffset(8, 7)
	goldLabel = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.new(1, -54, 1, 0),
		Text = "0",
		FontFace = UIKit.Fonts.Title,
		TextSize = 25,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Gold,
		Parent = pill,
	})
	UIKit.TextStroke(goldLabel, C.Shadow, 1.5, 0.1)
	menu = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0.3, 56),
		Size = UDim2.fromOffset(156, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.List(menu, 8, false, Enum.HorizontalAlignment.Right)
end

local function buildShipPanel()
	shipPanel = UIKit.Panel(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(360, 92),
		Visible = false,
	})
	shipName = UIKit.Label(shipPanel, "Ship", {
		FontFace = UIKit.Fonts.Title,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Wood,
	})
	local function bar(y: number, label: string, color: Color3): Frame
		UIKit.Label(shipPanel, label, {
			Position = UDim2.fromOffset(12, y),
			Size = UDim2.fromOffset(52, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = UIKit.Fonts.Small,
		})
		local back = UIKit.new("Frame", {
			Position = UDim2.fromOffset(66, y + 2),
			Size = UDim2.new(1, -78, 0, 12),
			BackgroundColor3 = Color3.fromRGB(60, 44, 30),
			Parent = shipPanel,
		})
		UIKit.Corner(back, 6)
		local fill = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = back })
		UIKit.Corner(fill, 6)
		return fill
	end
	hpFill = bar(34, "Hull", C.Green)
	sailFill = bar(52, "Sails", Color3.fromRGB(240, 230, 200))
	shipInfo = UIKit.Label(shipPanel, "", {
		Position = UDim2.fromOffset(12, 68),
		Size = UDim2.new(1, -24, 0, 18),
		FontFace = UIKit.Fonts.Small,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function buildCarryPanel()
	carryPanel = UIKit.Panel(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -196),
		Size = UDim2.fromOffset(440, 58),
		Visible = false,
	})
	UIKit.Icon(carryPanel, "💰", 44, C.GoldDark, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
	})
	carryLabel = UIKit.Label(carryPanel, "", {
		Position = UDim2.fromOffset(62, 0),
		Size = UDim2.new(1, -184, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Wood,
	})
	local constraint = carryLabel:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then
		constraint.MaxTextSize = 20
	end
	UIKit.Button(carryPanel, "Drop [G]", C.Red, function()
		Net.Event("TreasureAction"):FireServer("Drop")
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(108, 38),
	})
end

local function currentShip(): Model?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local shipsFolder = workspace:FindFirstChild("Ships")
	if not root or not root:IsA("BasePart") or not shipsFolder then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { shipsFolder }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -14, 0), params)
	local onShip = hit and Util.FindShipModel(hit.Instance)
	if onShip then
		return onShip
	end
	local crewIds: { [number]: boolean } = { [player.UserId] = true }
	if State.Crew then
		for _, m in State.Crew.Members do
			crewIds[m.UserId] = true
		end
	end
	local best, bestDist = nil, 700
	for _, ship in shipsFolder:GetChildren() do
		local owner = ship:GetAttribute("OwnerUserId")
		if ship:IsA("Model") and ship.PrimaryPart and type(owner) == "number" and crewIds[owner] then
			local d = (ship.PrimaryPart.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = ship, d
			end
		end
	end
	return best
end

local function updateShipPanel()
	local ship = if dialogueOpen then nil else currentShip()
	shipPanel.Visible = ship ~= nil
	if not ship then
		return
	end
	local hp = ship:GetAttribute("HP") or 0
	local maxHp = ship:GetAttribute("MaxHP") or 1
	local frac = math.clamp(hp / maxHp, 0, 1)
	shipName.Text = ship.Name
	hpFill.Size = UDim2.fromScale(frac, 1)
	hpFill.BackgroundColor3 = C.Red:Lerp(C.Green, frac)
	sailFill.Size = UDim2.fromScale(math.clamp(ship:GetAttribute("Sail") or 0, 0.02, 1), 1)
	local holes = ship:GetAttribute("Holes") or 0
	local parts = {}
	if ship:GetAttribute("Sinking") then
		table.insert(parts, "SINKING!")
	else
		table.insert(parts, if ship:GetAttribute("Anchored") then "Anchored" else "Under way")
		table.insert(parts, ("%d knots"):format(math.floor((ship:GetAttribute("Speed") or 0) / 2 + 0.5)))
		if holes > 0 then
			table.insert(parts, ("%d hole%s - repair!"):format(holes, if holes == 1 then "" else "s"))
		end
	end
	shipInfo.Text = table.concat(parts, "  |  ")
	shipInfo.TextColor3 = if holes > 0 or ship:GetAttribute("Sinking") then C.Red else C.Ink
end

local function updateLocation()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local pos = root.Position
	local island, dist = Util.NearestIsland(pos)
	locationLabel.Text = if dist < island.Radius * 0.35 then island.Name else "The Open Sea"
	safeBadge.Visible = Util.InSafeZone(pos) and not dialogueOpen
	if math.sqrt(pos.X * pos.X + pos.Z * pos.Z) > WorldData.BoundaryRadius then
		locationLabel.Text = "The Devil's Sea - turn back!"
	end
end

local function updateCarry()
	local tier = player:GetAttribute("CarryingTier")
	carryPanel.Visible = tier ~= nil and not dialogueOpen
	if tier then
		local def = Config.Chests[tier]
		local value = player:GetAttribute("CarryingValue") or 0
		carryLabel.Text = ("Carrying %s (%sg)"):format(if def then def.DisplayName else "treasure", Util.FormatNumber(value))
	end
end

-- Hide the bottom panels and the menu while a dialogue panel is on screen
function HUD.SetDialogueOpen(open: boolean)
	dialogueOpen = open
	menu.Visible = not open
	compassHolder.Visible = not open
	locationLabel.Visible = not open
	if open then
		safeBadge.Visible = false
	end
	updateCarry()
	updateShipPanel()
end

function HUD.Init()
	gui = UIKit.Screen("HUD", 2)
	-- toasts get their own layer so they show above shop windows and dialogues
	notifications = UIKit.new("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.new(0.9, 0, 0, 220),
		BackgroundTransparency = 1,
		Parent = UIKit.Screen("Toasts", 20),
	})
	UIKit.List(notifications, 6)
	hitMarker = UIKit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		Text = "X",
		FontFace = UIKit.Fonts.Title,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 80, 60),
		TextTransparency = 1,
		Parent = gui,
	})
	buildCompass()
	buildGold()
	buildShipPanel()
	buildCarryPanel()
	-- shrink the fixed-size HUD pieces on phones
	for _, element in { compassHolder, goldLabel.Parent, menu, shipPanel, carryPanel } do
		if element and element:IsA("GuiObject") then
			UIKit.AutoScale(element, 720, 0.6)
		end
	end

	Net.Event("Notify").OnClientEvent:Connect(HUD.Notify)

	State.DataChanged.Event:Connect(function(data)
		local target = data.Gold
		local from = shownGold
		shownGold = target
		task.spawn(function()
			local steps = 20
			for i = 1, steps do
				goldLabel.Text = Util.FormatNumber(from + (target - from) * i / steps)
				task.wait(0.02)
			end
		end)
	end)
	if State.Data then
		shownGold = State.Data.Gold
		goldLabel.Text = Util.FormatNumber(shownGold)
	end

	player:GetAttributeChangedSignal("CarryingTier"):Connect(updateCarry)
	player:GetAttributeChangedSignal("CarryingValue"):Connect(updateCarry)
	updateCarry()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if (input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonX) and player:GetAttribute("CarryingTier") then
			Net.Event("TreasureAction"):FireServer("Drop")
		end
	end)

	local camera = workspace.CurrentCamera
	RunService.RenderStepped:Connect(function()
		camera = workspace.CurrentCamera
		local heading = math.deg(Util.Heading(camera.CFrame.LookVector))
		local width = compassStrip.AbsoluteSize.X
		for _, label in compassStrip:GetChildren() do
			local h = label:GetAttribute("Heading")
			if label:IsA("TextLabel") and type(h) == "number" then
				local diff = (h - heading + 540) % 360 - 180
				label.Visible = math.abs(diff) < 95
				label.Position = UDim2.fromOffset(width / 2 + diff / 90 * (width / 2), 16)
			end
		end
		local windAngle = workspace:GetAttribute("WindAngle")
		if type(windAngle) == "number" then
			local windHeading = math.deg(Util.Heading(Vector3.new(math.cos(windAngle), 0, math.sin(windAngle))))
			windArrow.Rotation = windHeading - heading - 90
		end
	end)
	task.spawn(function()
		while true do
			updateLocation()
			updateShipPanel()
			task.wait(0.2)
		end
	end)
end

return HUD
