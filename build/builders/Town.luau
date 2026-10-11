-- Builds Kingshaven: piers, shops with their shopkeepers, the King statue,
-- market stalls, lamps, the lighthouse and the spawn point.
local P = require("./Parts")
local Rigs = require("./Rigs")

local V = P.Vector3.new
local CF = P.CFrame.new
local Angles = P.CFrame.Angles
local rgb = P.rgb

local Town = {}

local WARM = rgb(255, 196, 120)
local IRON = rgb(44, 42, 46)
local DARK_WOOD = rgb(78, 50, 30)
local WOOD = rgb(132, 92, 56)

local function lamp(parent: any, x: number, y: number, z: number, height: number?)
	local h = height or 8
	P.pillar(parent, x, z, y - 0.5, y + h, 0.45, { Name = "LampPost", Mat = "Metal", Color = IRON })
	P.part(parent, { Name = "LampArm", Size = V(0.3, 0.3, 1.4), CFrame = CF(x, y + h - 0.3, z - 0.6), Mat = "Metal", Color = IRON })
	local lantern = P.part(parent, { Name = "Lantern", Size = V(0.9, 1.2, 0.9), CFrame = CF(x, y + h - 1.2, z - 1.2), Mat = "Neon", Color = rgb(255, 200, 120), CanCollide = false })
	P.part(parent, { Name = "LanternCap", Size = V(1.2, 0.3, 1.2), CFrame = CF(x, y + h - 0.45, z - 1.2), Mat = "Metal", Color = IRON, CanCollide = false })
	P.pointLight(lantern, WARM, 22, 1.4, false)
end
Town.Lamp = lamp

local function crate(parent: any, cf: any, size: number?)
	local s = size or 2.4
	P.part(parent, { Name = "Crate", Size = V(s, s, s), CFrame = cf, Mat = "WoodPlanks", Color = rgb(168, 124, 74) })
end
Town.Crate = crate

local function barrel(parent: any, x: number, y: number, z: number)
	P.pillar(parent, x, z, y, y + 2.6, 1.9, { Name = "Barrel", Mat = "WoodPlanks", Color = rgb(124, 82, 46) })
	P.pillar(parent, x, z, y + 0.4, y + 0.6, 1.98, { Name = "Hoop", Mat = "Metal", Color = IRON, CanCollide = false })
	P.pillar(parent, x, z, y + 2.0, y + 2.2, 1.98, { Name = "Hoop", Mat = "Metal", Color = IRON, CanCollide = false })
end
Town.Barrel = barrel

-- A shop building. Built around a local origin (ground centre, front facing +Z).
local function building(parent: any, o: { [string]: any }, ground: number)
	local m = P.model(parent, o.Name)
	local W, D, H = o.Width, o.Depth, o.Height
	local base = 0.9
	P.part(m, { Name = "Foundation", Size = V(W + 2, 2.4, D + 2), CFrame = CF(0, -0.3, 0), Mat = "Cobblestone", Color = rgb(150, 142, 130) })
	P.part(m, { Name = "Floor", Size = V(W - 1, 0.4, D - 1), CFrame = CF(0, base + 0.2, 0), Mat = "WoodPlanks", Color = rgb(150, 108, 66) })
	local wall = { Mat = o.WallMat or "SmoothPlastic", Color = o.Wall }
	local function wallPart(name, size, cf)
		local props = { Name = name, Size = size, CFrame = cf }
		for k, v in wall do
			props[k] = v
		end
		return P.part(m, props)
	end
	wallPart("Wall", V(W, H, 0.8), CF(0, base + H / 2, -D / 2 + 0.4))
	wallPart("Wall", V(0.8, H, D), CF(-W / 2 + 0.4, base + H / 2, 0))
	wallPart("Wall", V(0.8, H, D), CF(W / 2 - 0.4, base + H / 2, 0))
	local doorW, doorH = 5, 7.5
	local sideW = (W - doorW) / 2
	wallPart("Wall", V(sideW, H, 0.8), CF(-(doorW / 2 + sideW / 2), base + H / 2, D / 2 - 0.4))
	wallPart("Wall", V(sideW, H, 0.8), CF(doorW / 2 + sideW / 2, base + H / 2, D / 2 - 0.4))
	wallPart("Wall", V(doorW, H - doorH, 0.8), CF(0, base + doorH + (H - doorH) / 2, D / 2 - 0.4))
	-- timber frame
	for _, x in { -W / 2, W / 2 } do
		for _, z in { -D / 2, D / 2 } do
			P.part(m, { Name = "Beam", Size = V(1, H + 0.2, 1), CFrame = CF(x, base + H / 2, z), Mat = "Wood", Color = DARK_WOOD })
		end
	end
	P.part(m, { Name = "Beam", Size = V(W + 0.4, 0.8, 1), CFrame = CF(0, base + H, D / 2), Mat = "Wood", Color = DARK_WOOD })
	P.part(m, { Name = "Beam", Size = V(W + 0.4, 0.8, 1), CFrame = CF(0, base + H, -D / 2), Mat = "Wood", Color = DARK_WOOD })
	P.part(m, { Name = "DoorFrame", Size = V(doorW + 1, 0.6, 1.0), CFrame = CF(0, base + doorH + 0.3, D / 2), Mat = "Wood", Color = DARK_WOOD })
	for _, x in { -doorW / 2 - 0.3, doorW / 2 + 0.3 } do
		P.part(m, { Name = "DoorFrame", Size = V(0.6, doorH, 1.0), CFrame = CF(x, base + doorH / 2, D / 2), Mat = "Wood", Color = DARK_WOOD })
	end
	-- windows with open shutters on the sides
	local winY = base + H * 0.55
	for _, side in { -1, 1 } do
		for _, z in { -D / 4, D / 4 } do
			local x = side * (W / 2 + 0.05)
			P.part(m, { Name = "WindowFrame", Size = V(0.3, 3.4, 3.0), CFrame = CF(x, winY, z), Mat = "Wood", Color = DARK_WOOD })
			P.part(m, { Name = "Window", Size = V(0.32, 2.8, 2.4), CFrame = CF(x + side * 0.02, winY, z), Mat = "Glass", Color = rgb(255, 220, 150), Transparency = 0.25 })
			for _, dz in { -1, 1 } do
				P.part(m, { Name = "Shutter", Size = V(1.4, 3.0, 0.2), CFrame = CF(x + side * 0.7, winY, z + dz * 1.9) * Angles(0, side * dz * math.rad(25), 0), Mat = "WoodPlanks", Color = o.Shutter or rgb(46, 140, 150) })
			end
		end
		local x = side * (W / 4 + 0.6)
		P.part(m, { Name = "WindowFrame", Size = V(3.0, 3.4, 0.3), CFrame = CF(x, winY, D / 2 + 0.05), Mat = "Wood", Color = DARK_WOOD })
		P.part(m, { Name = "Window", Size = V(2.4, 2.8, 0.32), CFrame = CF(x, winY, D / 2 + 0.07), Mat = "Glass", Color = rgb(255, 220, 150), Transparency = 0.25 })
		P.part(m, { Name = "FlowerBox", Size = V(3.2, 0.7, 0.9), CFrame = CF(x, winY - 1.9, D / 2 + 0.5), Mat = "WoodPlanks", Color = DARK_WOOD })
		for i = -1, 1 do
			local flower = ({ rgb(255, 80, 120), rgb(255, 210, 60), rgb(255, 120, 40) })[i + 2]
			P.part(m, { Name = "Flower", Shape = "Ball", Size = V(0.7, 0.7, 0.7), CFrame = CF(x + i * 0.9, winY - 1.35, D / 2 + 0.5), Color = flower, CanCollide = false })
		end
	end
	-- roof: two sloped planks + gable ends
	local roofBase = base + H + 0.4
	local rise = o.RoofRise or W * 0.32
	local over = 1.8
	for _, side in { -1, 1 } do
		P.plank(m, V(side * (W / 2 + over), roofBase - 0.4, 0), V(0, roofBase + rise, 0), D + over * 2, 0.7, { Name = "Roof", Mat = o.RoofMat or "Slate", Color = o.Roof })
	end
	for _, z in { -D / 2 + 0.4, D / 2 - 0.4 } do
		P.gableRoof(m, CF(0, 0, z), W, 0.8, roofBase - 0.4, rise - 0.3, 0, { Name = "Gable", Mat = o.WallMat or "SmoothPlastic", Color = o.Wall })
	end
	P.part(m, { Name = "Ridge", Shape = "Cylinder", Size = V(D + over * 2 + 0.4, 0.8, 0.8), CFrame = CF(0, roofBase + rise + 0.1, 0) * Angles(0, math.pi / 2, 0), Mat = "Wood", Color = DARK_WOOD })
	-- sign above the door
	local sign = P.part(m, { Name = "Sign", Size = V(math.min(W * 0.7, 18), 2.6, 0.4), CFrame = CF(0, base + doorH + 2.2, D / 2 + 0.55), Mat = "WoodPlanks", Color = rgb(70, 42, 24) })
	P.surfaceText(sign, "Back", o.Sign, { Color = rgb(255, 214, 110), PixelsPerStud = 30 })
	-- striped awning
	local stripes = 4
	local aw = doorW + 3
	for i = 0, stripes - 1 do
		local x = -aw / 2 + (i + 0.5) * aw / stripes
		local color = if i % 2 == 0 then o.Awning or rgb(220, 60, 50) else rgb(250, 244, 230)
		P.plank(m, V(x, base + doorH + 0.6, D / 2 + 0.4), V(x, base + doorH - 0.7, D / 2 + 3.6), aw / stripes, 0.2, { Name = "Awning", Mat = "Fabric", Color = color, CanCollide = false })
	end
	-- door lanterns
	for _, x in { -doorW / 2 - 1.4, doorW / 2 + 1.4 } do
		local lantern = P.part(m, { Name = "Lantern", Size = V(0.8, 1.1, 0.8), CFrame = CF(x, base + doorH - 1, D / 2 + 0.7), Mat = "Neon", Color = rgb(255, 200, 120), CanCollide = false })
		P.pointLight(lantern, WARM, 16, 1.2, false)
	end
	-- a bit of interior
	P.part(m, { Name = "Counter", Size = V(W * 0.5, 3.2, 1.6), CFrame = CF(0, base + 2, -D / 2 + 4), Mat = "WoodPlanks", Color = WOOD })
	barrel(m, -W / 2 + 2.6, base + 0.4, -D / 2 + 2.6)
	barrel(m, W / 2 - 2.6, base + 0.4, -D / 2 + 2.6)
	local inside = P.part(m, { Name = "InteriorLight", Size = V(1, 1, 1), CFrame = CF(0, base + H - 2, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	P.pointLight(inside, WARM, 26, 1.0, true)

	local origin = CF(o.X, ground, o.Z) * Angles(0, o.Yaw, 0)
	P.transform(m, origin)
	return m, origin
end

local function npc(parent: any, shopId: string, title: string, name: string, look: any, cf: any, actionText: string)
	local model, r = Rigs.Npc(name, look)
	P.transform(model, cf)
	model.Parent = parent
	model:AddTag("ShopNPC")
	model:SetAttribute("ShopId", shopId)
	local gui = P.Instance.new("BillboardGui")
	gui.Name = "Title"
	gui.Size = P.UDim2.fromOffset(220, 64)
	gui.StudsOffset = V(0, 3.4, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = r.Head
	local t = P.Instance.new("TextLabel")
	t.Name = "Role"
	t.BackgroundTransparency = 1
	t.Size = P.UDim2.fromScale(1, 0.6)
	t.Text = title
	t.TextScaled = true
	t.TextColor3 = rgb(255, 210, 90)
	t.TextStrokeTransparency = 0.1
	t.TextStrokeColor3 = rgb(40, 20, 10)
	t.FontFace = P.Font.fromEnum(P.Enum.Font.LuckiestGuy)
	t.Parent = gui
	local n = P.Instance.new("TextLabel")
	n.Name = "NpcName"
	n.BackgroundTransparency = 1
	n.Position = P.UDim2.fromScale(0, 0.6)
	n.Size = P.UDim2.fromScale(1, 0.4)
	n.Text = name
	n.TextScaled = true
	n.TextColor3 = rgb(255, 255, 255)
	n.TextStrokeTransparency = 0.2
	n.FontFace = P.Font.fromEnum(P.Enum.Font.FredokaOne)
	n.Parent = gui
	P.prompt(r.HRP, { Name = "ShopPrompt", ActionText = actionText, ObjectText = name, MaxActivationDistance = 12, Exclusivity = P.Enum.ProximityPromptExclusivity.AlwaysShow })
	return model, r
end

local function stall(parent: any, x: number, y: number, z: number, yaw: number, colorA: any, colorB: any, goods: { any })
	local m = P.model(parent, "MarketStall")
	P.part(m, { Name = "Table", Size = V(9, 0.5, 4), CFrame = CF(0, 3, 0), Mat = "WoodPlanks", Color = WOOD })
	P.part(m, { Name = "TableBase", Size = V(8.6, 2.75, 3.6), CFrame = CF(0, 1.4, 0), Mat = "WoodPlanks", Color = DARK_WOOD })
	for _, px in { -4.2, 4.2 } do
		for _, pz in { -1.8, 1.8 } do
			P.pillar(m, px, pz, 0, 8 + (if pz < 0 then 0.8 else 0), 0.4, { Name = "Post", Mat = "Wood", Color = DARK_WOOD })
		end
	end
	for i = 0, 5 do
		local px = -4.5 + (i + 0.5) * 1.5
		P.plank(m, V(px, 8.9, -2.6), V(px, 7.6, 2.8), 1.5, 0.15, { Name = "Awning", Mat = "Fabric", Color = if i % 2 == 0 then colorA else colorB, CanCollide = false })
	end
	for i = 1, 10 do
		local color = goods[(i - 1) % #goods + 1]
		local gx = -3.6 + ((i - 1) % 5) * 1.8
		local gz = if i <= 5 then -0.8 else 0.8
		P.part(m, { Name = "Goods", Shape = "Ball", Size = V(1.1, 1.1, 1.1), CFrame = CF(gx, 3.8, gz), Color = color, CanCollide = false })
	end
	crate(m, CF(5.5, 1.2, 1.5) * Angles(0, 0.3, 0))
	P.transform(m, CF(x, y, z) * Angles(0, yaw, 0))
	return m
end

local function statue(parent: any, x: number, y: number, z: number)
	local m = P.model(parent, "KingStatue")
	local stone = rgb(214, 206, 190)
	local gold = rgb(255, 196, 64)
	P.pillar(m, 0, 0, -1, 1.2, 22, { Name = "Basin", Mat = "Cobblestone", Color = rgb(160, 150, 136) })
	P.pillar(m, 0, 0, 1.0, 1.25, 19, { Name = "Water", Mat = "Glass", Color = rgb(40, 190, 200), Transparency = 0.3, CanCollide = false })
	P.part(m, { Name = "Pedestal", Size = V(7, 7, 7), CFrame = CF(0, 4.5, 0), Mat = "Marble", Color = stone })
	P.part(m, { Name = "PedestalTop", Size = V(8, 0.8, 8), CFrame = CF(0, 8.4, 0), Mat = "Marble", Color = stone })
	local plaque = P.part(m, { Name = "Plaque", Size = V(5.6, 3.4, 0.3), CFrame = CF(0, 4.8, 3.6), Mat = "Metal", Color = rgb(70, 50, 30) })
	P.surfaceText(plaque, "Back", "KING OF THE PIRATES\nNo king yet...", { Name = "PlaqueGui", Color = rgb(255, 214, 110), PixelsPerStud = 40, Font = P.Enum.Font.FredokaOne })
	-- golden pirate (scale 2.2) with a raised cutlass, facing south (+Z)
	local s = 2.2
	local top = 8.8
	local function g(name, size, pos, extra)
		local props = { Name = name, Size = size * s, CFrame = CF(pos.X * s, top + pos.Y * s, pos.Z * s), Mat = "Metal", Color = gold, Reflectance = 0.25 }
		for k, v in extra or {} do
			props[k] = v
		end
		return P.part(m, props)
	end
	g("Leg", V(1, 2, 1), V(-0.5, 1, 0))
	g("Leg", V(1, 2, 1), V(0.5, 1, 0))
	g("Torso", V(2, 2, 1), V(0, 3, 0))
	g("Head", V(1.2, 1.2, 1.2), V(0, 4.6, 0), { Shape = "Ball" })
	g("Arm", V(1, 2, 1), V(-1.5, 3, 0))
	local arm = g("Arm", V(1, 2, 1), V(1.5, 4.4, 0))
	arm.CFrame = arm.CFrame * Angles(0, 0, math.rad(-20))
	g("Blade", V(0.2, 4.2, 0.5), V(1.9, 7.4, 0), { Color = rgb(235, 235, 240) })
	g("Guard", V(0.9, 0.2, 0.9), V(1.85, 5.4, 0))
	g("Cape", V(2.2, 3.4, 0.25), V(0, 2.6, -0.65), { Mat = "Fabric", Color = rgb(170, 30, 36), Reflectance = 0 })
	g("HatBrim", V(0.2, 2.2, 2.2), V(0, 5.15, 0), { Shape = "Cylinder" }).CFrame = CF(0, top + 5.15 * s, 0) * Angles(0, 0, math.pi / 2)
	-- crown
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		g("CrownPoint", V(0.25, 0.7, 0.25), V(math.cos(a) * 0.55, 5.75, math.sin(a) * 0.55))
	end
	g("Gem", V(0.3, 0.3, 0.3), V(0, 5.45, 0.62), { Mat = "Neon", Color = rgb(255, 40, 70), Shape = "Ball" })
	local light = P.part(m, { Name = "Spot", Size = V(1, 1, 1), CFrame = CF(0, 3, 8), Transparency = 1, CanCollide = false, CanQuery = false })
	P.pointLight(light, rgb(255, 220, 160), 20, 1.4, false)
	P.transform(m, CF(x, y, z))
	return m
end

local function lighthouse(parent: any, x: number, y: number, z: number)
	local m = P.model(parent, "Lighthouse")
	P.pillar(m, x, z, y - 4, y + 3, 16, { Name = "Base", Mat = "Cobblestone", Color = rgb(150, 144, 136) })
	local h = y + 3
	for i = 0, 7 do
		local d = 10 - i * 0.45
		P.pillar(m, x, z, h + i * 4.5, h + (i + 1) * 4.5, d, { Name = "Tower", Mat = "SmoothPlastic", Color = if i % 2 == 0 then rgb(245, 245, 240) else rgb(205, 50, 46) })
	end
	local top = h + 36
	P.pillar(m, x, z, top, top + 1, 12, { Name = "Gallery", Mat = "Metal", Color = IRON })
	P.pillar(m, x, z, top + 1, top + 7, 6.5, { Name = "LampRoom", Mat = "Glass", Color = rgb(200, 240, 255), Transparency = 0.5 })
	local lamp = P.part(m, { Name = "Lamp", Shape = "Ball", Size = V(3, 3, 3), CFrame = CF(x, top + 4, z), Mat = "Neon", Color = rgb(255, 230, 150) })
	P.pointLight(lamp, rgb(255, 225, 160), 60, 2.5, false)
	for i = 0, 3 do
		P.pillar(m, x, z, top + 7 + i * 1.2, top + 8.2 + i * 1.2, 7 - i * 1.8, { Name = "Roof", Mat = "Metal", Color = rgb(205, 50, 46) })
	end
	local beam = P.part(m, {
		Name = "Beam",
		Size = V(3, 3, 220),
		CFrame = CF(x, top + 4, z),
		Mat = "Neon",
		Color = rgb(255, 236, 170),
		Transparency = 0.86,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	beam:AddTag("LighthouseBeam")
	P.part(m, { Name = "Door", Size = V(4, 6.5, 1), CFrame = CF(x, y + 3.2, z + 7.6), Mat = "WoodPlanks", Color = DARK_WOOD })
	return m
end

-- Returns the town model and a list of "keep clear" zones for palms/rocks
function Town.Build(parent: any, H: any, World: any)
	local town = P.model(parent, "Kingshaven")
	local G = World.Town.Height
	local clear = {}
	local function keep(x, z, r)
		table.insert(clear, { X = x, Z = z, R = r })
	end

	-- Shops ---------------------------------------------------------------
	local shops = {
		{
			Name = "Shipwright", Sign = "SHIPWRIGHT", X = 60, Z = 250, Yaw = -math.pi / 2, Width = 26, Depth = 20, Height = 11,
			Wall = rgb(236, 220, 186), Roof = rgb(120, 76, 44), RoofMat = "WoodPlanks", Shutter = rgb(40, 120, 170), Awning = rgb(40, 120, 170),
			Npc = { Id = "Shipwright", Title = "SHIPWRIGHT", Name = "Captain Barnaby", Action = "Browse Ships", Look = { Skin = rgb(224, 172, 128), Shirt = rgb(240, 236, 224), Vest = rgb(70, 90, 140), Pants = rgb(60, 50, 44), Hat = "Tricorn", HatColor = rgb(70, 46, 30), HatTrim = rgb(220, 180, 70), Beard = rgb(200, 200, 200) } },
		},
		{
			Name = "TradingCompany", Sign = "MERCHANT", X = -60, Z = 250, Yaw = math.pi / 2, Width = 26, Depth = 20, Height = 11,
			Wall = rgb(250, 214, 170), Roof = rgb(196, 92, 60), RoofMat = "Slate", Shutter = rgb(40, 150, 110), Awning = rgb(40, 150, 110),
			Npc = { Id = "Merchant", Title = "MERCHANT", Name = "Madame Coralie", Action = "Buy Maps & Sell", Look = { Skin = rgb(160, 106, 72), Shirt = rgb(30, 160, 160), Vest = rgb(230, 180, 60), Pants = rgb(90, 40, 90), Hat = "Bandana", HatColor = rgb(150, 50, 160) } },
		},
		{
			Name = "Armory", Sign = "ARMORY", X = 76, Z = 120, Yaw = -math.pi / 2, Width = 22, Depth = 18, Height = 10,
			Wall = rgb(200, 190, 176), WallMat = "Cobblestone", Roof = rgb(70, 74, 84), RoofMat = "Slate", Shutter = rgb(150, 40, 40), Awning = rgb(150, 40, 40),
			Npc = { Id = "Armory", Title = "ARMORY", Name = "Old Ironhook", Action = "Browse Weapons", Look = { Skin = rgb(230, 186, 150), Shirt = rgb(170, 40, 40), Pants = rgb(40, 36, 36), Hat = "Tricorn", HatColor = rgb(24, 22, 24), Beard = rgb(30, 26, 24), EyePatch = true } },
		},
		{
			Name = "Tavern", Sign = "THE RUSTY ANCHOR", X = -80, Z = 120, Yaw = math.pi / 2, Width = 28, Depth = 22, Height = 12,
			Wall = rgb(255, 236, 196), Roof = rgb(214, 178, 100), RoofMat = "Grass", Shutter = rgb(220, 120, 40), Awning = rgb(220, 120, 40),
			Npc = { Id = "Tavern", Title = "TAVERN", Name = "Rosie the Barkeep", Action = "Order a Drink", Look = { Skin = rgb(240, 196, 160), Shirt = rgb(250, 246, 236), Vest = rgb(60, 130, 70), Pants = rgb(110, 70, 40), Hat = "Bandana", HatColor = rgb(210, 50, 50) } },
		},
		{
			Name = "TradingPost", Sign = "TRADING POST", X = 0, Z = 22, Yaw = 0, Width = 24, Depth = 18, Height = 10,
			Wall = rgb(214, 240, 236), Roof = rgb(46, 150, 150), RoofMat = "Slate", Shutter = rgb(230, 170, 40), Awning = rgb(230, 170, 40),
			Npc = { Id = "TradingPost", Title = "TRADING POST", Name = "Jules the Trader", Action = "Trade with Pirates", Look = { Skin = rgb(120, 84, 60), Shirt = rgb(60, 110, 200), Pants = rgb(220, 210, 180), Hat = "Tricorn", HatColor = rgb(50, 70, 120), HatTrim = rgb(255, 255, 255), Parrot = true } },
		},
	}
	for _, o in shops do
		local _, origin = building(town, o, G)
		local npcCF = origin * CF(0, 0, o.Depth / 2 + 4.5) * Angles(0, math.pi, 0)
		local _, r = npc(town, o.Npc.Id, o.Npc.Title, o.Npc.Name, o.Npc.Look, npcCF, o.Npc.Action)
		-- a counter between the shopkeeper and the street
		local counterCF = origin * CF(0, 1.6, o.Depth / 2 + 7.5)
		local counter = P.part(town, { Name = "ShopCounter", Size = V(7, 3.2, 1.4), CFrame = counterCF, Mat = "WoodPlanks", Color = WOOD })
		P.part(town, { Name = "CounterTop", Size = V(7.4, 0.3, 1.8), CFrame = counterCF * CF(0, 1.7, 0), Mat = "Wood", Color = DARK_WOOD })
		if o.Npc.Id == "Merchant" then
			P.prompt(counter, { Name = "SellPrompt", ActionText = "Sell Treasure", ObjectText = "Trading Company", KeyboardKeyCode = P.Enum.KeyCode.F, GamepadKeyCode = P.Enum.KeyCode.ButtonY, MaxActivationDistance = 12, Exclusivity = P.Enum.ProximityPromptExclusivity.AlwaysShow })
			counter:SetAttribute("ShopId", "Merchant")
			counter:AddTag("SellCounter")
			-- piles of gold on the counter
			for i = -2, 2 do
				P.pillar(town, 0, 0, 0, 0.3, 0.8, { Name = "Coins", Mat = "Metal", Color = rgb(255, 204, 64), CFrame = counterCF * CF(i * 1.2, 1.95, 0) * Angles(0, 0, math.pi / 2), CanCollide = false })
			end
		end
		r.HRP:SetAttribute("ShopId", o.Npc.Id)
		local fp = origin.Position
		keep(fp.X, fp.Z, math.max(o.Width, o.Depth) * 0.75 + 8)
		local cp = counterCF.Position
		keep(cp.X, cp.Z, 9)
	end

	-- Market stalls around the square
	local fruit = { rgb(255, 150, 30), rgb(255, 220, 60), rgb(90, 200, 70), rgb(230, 50, 50), rgb(170, 70, 200) }
	stall(town, 34, G, 152, math.rad(-35), rgb(230, 60, 60), rgb(255, 245, 230), fruit)
	stall(town, -34, G, 152, math.rad(35), rgb(40, 160, 200), rgb(255, 245, 230), fruit)
	stall(town, 34, G, 86, math.rad(-145), rgb(250, 190, 40), rgb(255, 245, 230), fruit)
	stall(town, -34, G, 86, math.rad(145), rgb(60, 170, 90), rgb(255, 245, 230), fruit)

	statue(town, World.Town.X, G, World.Town.Z)
	keep(World.Town.X, World.Town.Z, World.Town.SquareRadius + 6)

	-- Spawn point: a compass rose on the road south of the square
	local sp = World.SpawnPoint
	local spawn = P.part(town, { Class = "SpawnLocation", Name = "TownSpawn", Size = V(10, 1, 10), CFrame = CF(sp.X, G - 0.3, sp.Z), Mat = "Cobblestone", Color = rgb(196, 170, 120) })
	spawn.Neutral = true
	spawn.Duration = 5
	P.part(town, { Name = "Compass", Shape = "Cylinder", Size = V(0.2, 8, 8), CFrame = CF(sp.X, G + 0.25, sp.Z) * Angles(0, 0, math.pi / 2), Mat = "Metal", Color = rgb(230, 186, 80), CanCollide = false })
	for i = 0, 3 do
		P.part(town, { Name = "CompassPoint", Size = V(0.8, 0.3, 7), CFrame = CF(sp.X, G + 0.3, sp.Z) * Angles(0, i * math.pi / 4, 0), Mat = "Metal", Color = rgb(150, 40, 40), CanCollide = false })
	end
	keep(sp.X, sp.Z, 10)

	-- Lamps along the roads
	for z = 175, 290, 28 do
		lamp(town, -8.5, G, z)
		lamp(town, 8.5, G, z)
	end
	for _, x in { -52, -28, 28, 52 } do
		lamp(town, x, G, 128.5)
	end
	for _, p in { { 30, 104 }, { -30, 104 }, { 0, 60 }, { 22, 36 }, { -22, 36 } } do
		lamp(town, p[1], G, p[2])
	end

	-- Welcome arch over the road to the piers
	local archZ = 296
	for _, x in { -9.5, 9.5 } do
		P.part(town, { Name = "ArchPost", Size = V(1.6, 15, 1.6), CFrame = CF(x, G + 7, archZ), Mat = "Wood", Color = DARK_WOOD })
		local torch = P.part(town, { Name = "Torch", Size = V(0.8, 1.2, 0.8), CFrame = CF(x, G + 15.2, archZ), Mat = "Wood", Color = DARK_WOOD })
		local fire = P.Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = torch
	end
	local arch = P.part(town, { Name = "ArchSign", Size = V(22, 3.6, 0.8), CFrame = CF(0, G + 12.6, archZ), Mat = "WoodPlanks", Color = rgb(74, 46, 26) })
	P.surfaceText(arch, "Back", "~ KINGSHAVEN ~", { PixelsPerStud = 24 })
	P.surfaceText(arch, "Front", "~ KINGSHAVEN ~", { PixelsPerStud = 24 })

	-- Piers ------------------------------------------------------------------
	for pi, pier in World.Piers do
		local pm = P.model(town, "Pier" .. pi)
		local len = pier.MaxZ - pier.MinZ
		local midZ = (pier.MinZ + pier.MaxZ) / 2
		P.part(pm, { Name = "Deck", Size = V(pier.HalfWidth * 2, 1, len), CFrame = CF(pier.X, pier.Height - 0.5, midZ), Mat = "WoodPlanks", Color = rgb(160, 116, 72) })
		for _, side in { -1, 1 } do
			P.part(pm, { Name = "Edge", Size = V(0.6, 0.6, len), CFrame = CF(pier.X + side * (pier.HalfWidth - 0.3), pier.Height + 0.2, midZ), Mat = "Wood", Color = DARK_WOOD })
			for z = pier.MinZ + 8, pier.MaxZ, 18 do
				P.pillar(pm, pier.X + side * (pier.HalfWidth + 0.3), z, -26, pier.Height + 1.4, 1.3, { Name = "Piling", Mat = "Wood", Color = rgb(96, 70, 48) })
			end
			for z = pier.MinZ + 60, pier.MaxZ - 10, 90 do
				P.pillar(pm, pier.X + side * (pier.HalfWidth - 1), z + 20, pier.Height, pier.Height + 1.4, 1.0, { Name = "Bollard", Mat = "Metal", Color = IRON })
			end
		end
		for z = pier.MinZ + 40, pier.MaxZ - 10, 70 do
			lamp(pm, pier.X + (if (z // 70) % 2 == 0 then -1 else 1) * (pier.HalfWidth - 0.8), pier.Height, z, 7)
		end
		-- cargo
		barrel(pm, pier.X - 3.5, pier.Height, pier.MinZ + 14)
		barrel(pm, pier.X - 3.6, pier.Height, pier.MinZ + 16.4)
		crate(pm, CF(pier.X + 3.2, pier.Height + 1.2, pier.MinZ + 22) * Angles(0, 0.4, 0))
		crate(pm, CF(pier.X + 3.4, pier.Height + 3.4, pier.MinZ + 22.3) * Angles(0, 0.1, 0), 2)
		-- pirate flag
		P.pillar(pm, pier.X, pier.MaxZ - 2, pier.Height, pier.Height + 16, 0.5, { Name = "FlagPole", Mat = "Wood", Color = DARK_WOOD })
		local flag = P.part(pm, { Name = "Flag", Size = V(0.15, 3.4, 5.2), CFrame = CF(pier.X, pier.Height + 14, pier.MaxZ + 0.8), Mat = "Fabric", Color = rgb(20, 18, 22), CanCollide = false })
		for _, face in { "Left", "Right" } do
			P.surfaceText(flag, face, "☠️", { Color = rgb(240, 236, 226), StrokeTransparency = 1, PixelsPerStud = 20 })
		end
	end
	-- Boardwalk along the beach connecting both piers to the road
	P.part(town, { Name = "Boardwalk", Size = V(160, 1, 10), CFrame = CF(0, World.Piers[1].Height - 0.5, 301), Mat = "WoodPlanks", Color = rgb(160, 116, 72) })
	for x = -76, 76, 16 do
		P.pillar(town, x, 306, -10, World.Piers[1].Height - 0.5, 1.1, { Name = "Piling", Mat = "Wood", Color = rgb(96, 70, 48) })
	end

	-- Lighthouse on the northern hill
	local lh = World.Lighthouse
	local ly = H.GetHeight(lh.X, lh.Z)
	lighthouse(town, lh.X, ly, lh.Z)
	keep(lh.X, lh.Z, 16)

	-- Shipwright's lumber yard
	for i = 0, 4 do
		P.part(town, { Name = "Lumber", Size = V(1.2, 1.2, 14), CFrame = CF(96 + (i % 3) * 1.3, G + 0.6 + (i // 3) * 1.2, 262), Mat = "Wood", Color = rgb(186, 140, 88) })
	end
	barrel(town, 92, G, 280)
	crate(town, CF(98, G + 1.2, 282) * Angles(0, 0.5, 0))

	return town, clear
end

return Town
