-- The world chart (press M) and the treasure map you read when holding the map tool.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Heightmap = require(Shared:WaitForChild("Heightmap"))
local Util = require(Shared:WaitForChild("Util"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local HUD = require(script.Parent.HUD)
local State = require(script.Parent.State)
local UIKit = require(script.Parent.UIKit)

local MapUI = {}

local player = Players.LocalPlayer
local C = UIKit.Colors

local INK = Color3.fromRGB(70, 44, 24)
local SEA = Color3.fromRGB(150, 196, 196)
local SHALLOW = Color3.fromRGB(176, 214, 200)
local SAND = Color3.fromRGB(236, 214, 160)
local LAND = Color3.fromRGB(150, 176, 96)
local ROCK = Color3.fromRGB(150, 136, 112)

---------------------------------------------------------------------------
-- World chart
---------------------------------------------------------------------------
local chart: UIKit.Window
local chartCanvas: Frame
local playerMarker: TextLabel
local shipMarkers: Frame
local CHART_RANGE = 3500

local function toChart(x: number, z: number): UDim2
	return UDim2.fromScale(0.5 + x / (CHART_RANGE * 2), 0.5 + z / (CHART_RANGE * 2))
end

local function buildChart()
	chart = UIKit.Window("WorldChart", "Chart of the Seas", UDim2.fromOffset(640, 690), 6)
	local holder = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = chart.Body })
	UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = holder })
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.fromScale(0.5, 0)
	chartCanvas = UIKit.new("Frame", {
		BackgroundColor3 = SEA,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		Parent = holder,
	})
	UIKit.Corner(chartCanvas, 12)
	UIKit.Stroke(chartCanvas, INK, 2)
	-- grid lines
	for i = 1, 6 do
		for _, vertical in { true, false } do
			UIKit.new("Frame", {
				BackgroundColor3 = INK,
				BackgroundTransparency = 0.85,
				BorderSizePixel = 0,
				Position = if vertical then UDim2.fromScale(i / 7, 0) else UDim2.fromScale(0, i / 7),
				Size = if vertical then UDim2.new(0, 1, 1, 0) else UDim2.new(1, 0, 0, 1),
				Parent = chartCanvas,
			})
		end
	end
	-- edge of the world
	local edge = WorldData.BoundaryRadius / CHART_RANGE
	local ring = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(edge, edge),
		BackgroundTransparency = 1,
		Parent = chartCanvas,
	})
	UIKit.Corner(ring, 1000)
	UIKit.Stroke(ring, Color3.fromRGB(170, 50, 40), 2).Transparency = 0.3
	-- safe haven
	local zone = WorldData.SafeZone
	local safe = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toChart(zone.X, zone.Z),
		Size = UDim2.fromScale(zone.Radius / CHART_RANGE, zone.Radius / CHART_RANGE),
		BackgroundColor3 = C.Green,
		BackgroundTransparency = 0.8,
		Parent = chartCanvas,
	})
	UIKit.Corner(safe, 1000)
	-- islands
	for _, island in WorldData.Islands do
		local size = island.Radius * 2 / (CHART_RANGE * 2)
		local blob = UIKit.new("Frame", {
			Name = island.Name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toChart(island.X, island.Z),
			Size = UDim2.fromScale(size * 1.15, size * 1.15),
			BackgroundColor3 = SAND,
			Parent = chartCanvas,
		})
		UIKit.Corner(blob, 1000)
		UIKit.Stroke(blob, INK, 1.5)
		local inner = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			BackgroundColor3 = if island.Kind == "Rocky" then ROCK elseif island.Kind == "Atoll" then SHALLOW else LAND,
			Parent = blob,
		})
		UIKit.Corner(inner, 1000)
		local label = UIKit.new("TextLabel", {
			Name = "Label",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.fromOffset(140, 16),
			Text = island.Name,
			FontFace = UIKit.Fonts.Body,
			TextSize = 13,
			TextColor3 = INK,
			Parent = blob,
		})
		label:SetAttribute("Island", island.Name)
	end
	-- compass rose
	UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -60, 0, 8),
		Size = UDim2.fromOffset(50, 50),
		Text = "N\n^",
		FontFace = UIKit.Fonts.Title,
		TextSize = 20,
		TextColor3 = INK,
		Parent = chartCanvas,
	})
	shipMarkers = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = chartCanvas })
	playerMarker = UIKit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24),
		Text = "▲",
		FontFace = UIKit.Fonts.Body,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(220, 40, 30),
		ZIndex = 5,
		Parent = chartCanvas,
	})
	local s = Instance.new("UIStroke")
	s.Color = C.White
	s.Thickness = 1.5
	s.Parent = playerMarker
end

local function refreshChartMarkers()
	-- islands with one of your treasure maps get a red X
	local targets: { [string]: boolean } = {}
	if State.Data then
		for _, map in State.Data.Maps do
			targets[map.Island] = true
		end
	end
	for _, blob in chartCanvas:GetChildren() do
		local label = blob:FindFirstChild("Label")
		if label and label:IsA("TextLabel") then
			local name = label:GetAttribute("Island") :: string
			label.Text = if targets[name] then "X " .. name else name
			label.TextColor3 = if targets[name] then Color3.fromRGB(190, 30, 30) else INK
		end
	end
	UIKit.Clear(shipMarkers)
	local shipsFolder = workspace:FindFirstChild("Ships")
	if shipsFolder then
		for _, ship in shipsFolder:GetChildren() do
			if ship:IsA("Model") and ship.PrimaryPart and ship:GetAttribute("OwnerUserId") == player.UserId then
				local p = ship.PrimaryPart.Position
				UIKit.new("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = toChart(p.X, p.Z),
					Size = UDim2.fromOffset(60, 18),
					Text = "Your ship",
					FontFace = UIKit.Fonts.Body,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(30, 60, 140),
					Parent = shipMarkers,
				})
			end
		end
	end
end

function MapUI.ToggleChart()
	chart.Gui.Enabled = not chart.Gui.Enabled
	if chart.Gui.Enabled then
		refreshChartMarkers()
	end
end

---------------------------------------------------------------------------
-- Treasure map (shown while holding the TreasureMap tool)
---------------------------------------------------------------------------
local mapGui: ScreenGui
local mapPanel: Frame
local mapTitle: TextLabel
local mapSubtitle: TextLabel
local mapCanvas: Frame
local mapCounter: TextLabel
local mapIndex = 1
local mapVisible = false
local islandCache: { [string]: Frame } = {}
local GRID = 52

local function colorFor(h: number): Color3
	if h < -8 then
		return SEA
	elseif h < 0 then
		return SHALLOW
	elseif h < 4 then
		return SAND
	elseif h < 30 then
		return LAND
	end
	return ROCK
end

-- Draws an island from the heightmap (rows are merged into runs to keep it light)
local function drawIsland(island: WorldData.Island): Frame
	local cached = islandCache[island.Name]
	if cached then
		return cached
	end
	local frame = UIKit.new("Frame", { BackgroundColor3 = SEA, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) })
	frame:SetAttribute("CachedIsland", island.Name)
	local span = island.Radius * 2.6
	local x0, z0 = island.X - span / 2, island.Z - span / 2
	local step = span / GRID
	for row = 0, GRID - 1 do
		local z = z0 + (row + 0.5) * step
		local runStart = 0
		local runColor: Color3? = nil
		for col = 0, GRID do
			local color = if col < GRID then colorFor((Heightmap.GetHeight(x0 + (col + 0.5) * step, z))) else nil
			if color ~= runColor then
				if runColor and runColor ~= SEA then
					UIKit.new("Frame", {
						BackgroundColor3 = runColor,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(runStart / GRID, row / GRID),
						Size = UDim2.new((col - runStart) / GRID, 1, 1 / GRID, 1),
						Parent = frame,
					})
				end
				runStart = col
				runColor = color
			end
		end
	end
	islandCache[island.Name] = frame
	return frame
end

local function renderTreasureMap()
	local data = State.Data
	for _, child in mapCanvas:GetChildren() do
		if child:GetAttribute("CachedIsland") then
			child.Parent = nil -- keep cached drawings alive
		elseif not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	if not data or #data.Maps == 0 then
		mapTitle.Text = "No maps"
		mapSubtitle.Text = "Buy treasure maps from the Merchant."
		mapCounter.Text = ""
		return
	end
	mapIndex = math.clamp(mapIndex, 1, #data.Maps)
	local map = data.Maps[mapIndex]
	local tier = Config.MapTiers[map.Tier]
	local island = WorldData.GetIsland(map.Island)
	mapTitle.Text = if tier then tier.DisplayName else "Treasure Map"
	mapSubtitle.Text = map.Island .. " - dig at the X"
	mapCounter.Text = ("%d / %d"):format(mapIndex, #data.Maps)
	if not island then
		return
	end
	local drawing = drawIsland(island)
	drawing.Parent = mapCanvas
	local span = island.Radius * 2.6
	local fx = (map.X - (island.X - span / 2)) / span
	local fz = (map.Z - (island.Z - span / 2)) / span
	local x = UIKit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(fx, fz),
		Size = UDim2.fromOffset(34, 34),
		Text = "X",
		FontFace = UIKit.Fonts.Title,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(200, 30, 30),
		ZIndex = 4,
		Parent = mapCanvas,
	})
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(255, 240, 210)
	s.Thickness = 2
	s.Parent = x
	UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -44, 0, 4),
		Size = UDim2.fromOffset(40, 40),
		Text = "N\n^",
		FontFace = UIKit.Fonts.Title,
		TextSize = 16,
		TextColor3 = INK,
		ZIndex = 4,
		Parent = mapCanvas,
	})
end

local function buildTreasureMap()
	mapGui = UIKit.Screen("TreasureMap", 4)
	mapGui.Enabled = false
	mapPanel = UIKit.Panel(mapGui, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -180, 0.5, 0),
		Size = UDim2.fromOffset(360, 440),
	})
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(360, 440), Parent = mapPanel })
	mapTitle = UIKit.Label(mapPanel, "", { FontFace = UIKit.Fonts.Title, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 30), TextColor3 = INK })
	mapSubtitle = UIKit.Label(mapPanel, "", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 20), FontFace = UIKit.Fonts.Small })
	mapCanvas = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(320, 320),
		BackgroundColor3 = SEA,
		ClipsDescendants = true,
		Parent = mapPanel,
	})
	UIKit.Corner(mapCanvas, 8)
	UIKit.Stroke(mapCanvas, INK, 2)
	local nav = UIKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 40), Parent = mapPanel })
	UIKit.Button(nav, "<", C.Wood, function()
		mapIndex -= 1
		if State.Data and mapIndex < 1 then
			mapIndex = #State.Data.Maps
		end
		renderTreasureMap()
	end, { Size = UDim2.fromOffset(60, 36) })
	mapCounter = UIKit.Label(nav, "", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(120, 36) })
	UIKit.Button(nav, ">", C.Wood, function()
		mapIndex += 1
		if State.Data and mapIndex > #State.Data.Maps then
			mapIndex = 1
		end
		renderTreasureMap()
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(60, 36) })
end

function MapUI.ShowTreasureMap(show: boolean)
	mapVisible = show
	mapGui.Enabled = show
	if show then
		renderTreasureMap()
	end
end

function MapUI.Init()
	buildChart()
	buildTreasureMap()
	HUD.AddMenuButton("MAP", Enum.KeyCode.M, 1, C.Wood, MapUI.ToggleChart)
	State.DataChanged.Event:Connect(function()
		if mapVisible then
			renderTreasureMap()
		end
		if chart.Gui.Enabled then
			refreshChartMarkers()
		end
	end)
	local lastShips = 0
	RunService.RenderStepped:Connect(function()
		if not chart.Gui.Enabled then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			playerMarker.Position = toChart(root.Position.X, root.Position.Z)
			playerMarker.Rotation = math.deg(Util.Heading(root.CFrame.LookVector))
		end
		if os.clock() - lastShips > 1 then
			lastShips = os.clock()
			refreshChartMarkers()
		end
	end)
end

return MapUI
