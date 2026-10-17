-- Builds Kingshaven as a Sea of Thieves-style wooden pirate outpost: plank shops on stilts
-- with porches, shingle and thatch roofs and a shopkeeper behind every counter, the two piers,
-- the boardwalk, the King statue, market stalls, the welcome arch, the lighthouse and the spawn.
--
-- Shops are built in local space (front = +Z, floor raised on stilts) and moved into place
-- with P.transform. The shop list comes from WorldData.Shops.
local P = require("./Parts")
local Rigs = require("./Rigs")
local O = require("./Outpost")

local V = P.Vector3.new
local CF = P.CFrame.new
local Angles = P.CFrame.Angles
local rgb = P.rgb

local Town = {}

local PI = math.pi
local IRON = O.IRON
local DARK = O.DARK

-- Shopkeepers ------------------------------------------------------------------------------------

local SHOPKEEPERS = {
	Shipwright = {
		Name = "Captain Barnaby",
		Role = "SHIPWRIGHT",
		Look = {
			Skin = rgb(226, 176, 134),
			Shirt = rgb(236, 228, 208),
			Sleeves = "Rolled",
			Apron = rgb(124, 82, 50),
			Pants = rgb(84, 72, 60),
			Boots = rgb(64, 44, 30),
			Neckerchief = rgb(176, 46, 40),
			Hat = "Tricorn",
			HatColor = rgb(40, 46, 70),
			HatTrim = rgb(214, 172, 74),
			Hair = rgb(214, 214, 210),
			Beard = rgb(232, 232, 228),
			BeardStyle = "Long",
			Mustache = rgb(240, 240, 236),
			Earring = true,
			Prop = "Hammer",
		},
	},
	Merchant = {
		Name = "Madame Coralie",
		Role = "MERCHANT",
		Look = {
			Skin = rgb(156, 104, 72),
			Shirt = rgb(242, 232, 210),
			Coat = rgb(30, 104, 112),
			CoatTrim = rgb(222, 170, 60),
			LongCoat = true,
			Vest = rgb(104, 44, 98),
			Pants = rgb(46, 38, 44),
			Sash = rgb(222, 170, 60),
			Boots = rgb(60, 40, 32),
			Hat = "WideBrim",
			HatColor = rgb(98, 40, 94),
			HatTrim = rgb(222, 170, 60),
			Feather = rgb(250, 246, 236),
			Hair = rgb(34, 26, 24),
			HairStyle = "Long",
			Earring = "Both",
			Prop = "Ledger",
		},
	},
	Armory = {
		Name = "Old Ironhook",
		Role = "ARMORY",
		Look = {
			Skin = rgb(230, 186, 150),
			Shirt = rgb(226, 218, 200),
			Coat = rgb(124, 30, 32),
			CoatTrim = rgb(206, 160, 70),
			Vest = rgb(34, 30, 32),
			Pants = rgb(40, 36, 36),
			Boots = rgb(26, 22, 22),
			Bandolier = rgb(70, 46, 30),
			Hat = "Tricorn",
			HatColor = rgb(26, 24, 26),
			HatTrim = rgb(150, 30, 30),
			Hair = rgb(36, 30, 28),
			Beard = rgb(36, 30, 28),
			Mustache = rgb(30, 26, 24),
			EyePatch = true,
			Earring = true,
			Hook = true,
			Cutlass = true,
		},
	},
	Tavern = {
		Name = "Rosie the Barkeep",
		Role = "TAVERN",
		Look = {
			Skin = rgb(240, 196, 160),
			Shirt = rgb(246, 242, 232),
			Sleeves = "Rolled",
			Vest = rgb(58, 126, 70),
			Skirt = rgb(118, 74, 44),
			Apron = rgb(240, 234, 218),
			Boots = rgb(70, 46, 30),
			Hat = "Headscarf",
			HatColor = rgb(206, 50, 48),
			Hair = rgb(186, 84, 40),
			HairStyle = "Bun",
			Earring = "Both",
			Prop = "Mug",
		},
	},
	TradingPost = {
		Name = "Jules the Trader",
		Role = "TRADING POST",
		Look = {
			Skin = rgb(120, 84, 60),
			Shirt = rgb(240, 236, 224),
			Sleeves = "Shirt",
			Vest = rgb(212, 150, 56),
			Sash = rgb(188, 40, 44),
			Pants = rgb(222, 210, 180),
			Boots = rgb(92, 60, 36),
			Hat = "Bandana",
			HatColor = rgb(44, 86, 170),
			Hair = rgb(24, 20, 18),
			HairStyle = "Ponytail",
			Beard = rgb(24, 20, 18),
			BeardStyle = "Goatee",
			Mustache = rgb(24, 20, 18),
			Earring = "Both",
			Parrot = true,
		},
	},
}

Town.Shopkeepers = SHOPKEEPERS

-- Puts a shopkeeper at world CFrame `cf` (feet, facing cf's look direction)
local function shopkeeper(parent: any, shopId: string, cf: any)
	local def = SHOPKEEPERS[shopId] or { Name = "Shopkeeper", Role = string.upper(shopId), Look = { Skin = rgb(220, 170, 130) } }
	local model, r = Rigs.Npc(def.Name, def.Look)
	-- the rig faces -Z: turn it around so it faces the same way as cf
	P.transform(model, cf * Angles(0, PI, 0))
	model.Parent = parent
	model:AddTag("ShopNPC")
	model:SetAttribute("ShopId", shopId)
	r.HRP:SetAttribute("ShopId", shopId)

	local gui = P.Instance.new("BillboardGui")
	gui.Name = "Title"
	-- sized in studs and drawn on top: the shopkeeper stands inside, under the shop's front wall
	gui.Size = P.UDim2.new(7, 0, 2.1, 0)
	gui.StudsOffset = V(0, 3.3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	gui.Parent = r.Head
	local role = P.Instance.new("TextLabel")
	role.Name = "Role"
	role.BackgroundTransparency = 1
	role.Size = P.UDim2.fromScale(1, 0.55)
	role.Text = def.Role
	role.TextScaled = true
	role.TextColor3 = rgb(255, 210, 100)
	role.TextStrokeTransparency = 0.15
	role.TextStrokeColor3 = rgb(40, 20, 10)
	role.FontFace = P.RYE
	role.Parent = gui
	local nameLabel = P.Instance.new("TextLabel")
	nameLabel.Name = "NpcName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = P.UDim2.fromScale(0, 0.58)
	nameLabel.Size = P.UDim2.fromScale(1, 0.42)
	nameLabel.Text = def.Name
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = rgb(255, 250, 236)
	nameLabel.TextStrokeTransparency = 0.25
	nameLabel.TextStrokeColor3 = rgb(40, 20, 10)
	nameLabel.FontFace = P.RYE
	nameLabel.Parent = gui

	P.prompt(r.HRP, {
		Name = "ShopPrompt",
		ActionText = "Talk",
		ObjectText = def.Name,
		KeyboardKeyCode = P.Enum.KeyCode.E,
		GamepadKeyCode = P.Enum.KeyCode.ButtonX,
		MaxActivationDistance = 12,
		RequiresLineOfSight = false,
		HoldDuration = 0,
		Exclusivity = P.Enum.ProximityPromptExclusivity.AlwaysShow,
		UIOffset = P.Vector2.new(0, 40),
	})
	return model, r
end

-- Shop shell ------------------------------------------------------------------------------------------
-- A raised plank building with a covered porch, an open shop window with a counter and a sign.
-- Local space: ground at y = 0 under the shop centre, front = +Z.
--   c.W, c.D        footprint (width along the front, depth)
--   c.F             floor height (computed from the terrain)
--   c.Hw            wall height, c.Pd porch depth
--   c.Walls         plank palette, c.Trim (posts/beams colour)
--   c.Roof          { Style, Colors, AlongX, Rise }
--   c.Opening       { W, Y0, H } shop window in the front wall
--   c.DoorX         x of a door in the front wall (nil = none)
--   c.Stone         stone plinth instead of open stilts
-- Returns a table with the key heights/positions for the shop's own decorations.
local function shopShell(m: any, c: { [string]: any }, g: (number, number) -> number, title: string)
	local W, D, F, Hw, Pd = c.W, c.D, c.F, c.Hw or 8.5, c.Pd or 5.5
	local zf = D / 2 - 1 -- front wall
	local zb = -D / 2 -- back wall
	local Db = zf - zb
	local zc = (zf + zb) / 2
	local pz = zf + Pd -- porch edge
	local trim = c.Trim or DARK
	local walls = c.Walls or O.WOOD
	local roof = c.Roof or {}
	local half = W / 2
	local op = c.Opening or { W = 12, Y0 = 2.4, H = 5.2 }

	-- Foundations -------------------------------------------------------
	if c.Stone then
		local minG = math.huge
		for x = -half, half, 4 do
			for z = zb, pz, 4 do
				minG = math.min(minG, g(x, z))
			end
		end
		local bottom = minG - 2
		O.Part(m, "Plinth", V(W + 0.8, F - 0.6 - bottom, Db + 0.8), CF(0, (F - 0.6 + bottom) / 2, zc), rgb(132, 126, 116), "Cobblestone")
		O.Part(m, "PlinthCap", V(W + 1.4, 0.5, Db + 1.4), CF(0, F - 0.75, zc), rgb(150, 144, 132), "Slate")
		O.Stilts(m, -half, half, zf + 0.6, pz, F - 0.7, g, { Spacing = 9, Color = c.StiltColor })
	else
		O.Stilts(m, -half, half, zb, pz, F - 0.7, g, { Spacing = 9, Color = c.StiltColor, NoBackBraces = true })
	end

	-- Floors --------------------------------------------------------------------------------
	O.Part(m, "Floor", V(W - 0.4, 0.7, Db - 0.4), CF(0, F - 0.35, zc), rgb(118, 86, 58), "WoodPlanks")
	O.Deck(m, -half, half, zf, pz, F, { Colors = c.DeckColors or O.WOOD })

	-- Walls ------------------------------------------------------------------------------------
	local holes = { { -op.W / 2, op.W / 2, op.Y0, op.Y0 + op.H } }
	if c.DoorX then
		table.insert(holes, { c.DoorX - 1.7, c.DoorX + 1.7, 0, 6.6 })
	end
	local back = c.Back or rgb(84, 60, 42)
	O.PlankWall(m, CF(0, F, zf), W, Hw, { Holes = holes, Colors = walls, Back = back })
	local winY = 4.6
	local sideHoles = {}
	for _, wx in c.SideWindows or { -Db / 4, Db / 4 } do
		table.insert(sideHoles, { wx - 1.4, wx + 1.4, winY - 1.5, winY + 1.5 })
	end
	O.PlankWall(m, CF(0, F, zb) * Angles(0, PI, 0), W, Hw, { Colors = walls, Back = back, Holes = c.BackHoles })
	O.PlankWall(m, CF(-half, F, zc) * Angles(0, -PI / 2, 0), Db, Hw, { Holes = sideHoles, Colors = walls, Back = back })
	O.PlankWall(m, CF(half, F, zc) * Angles(0, PI / 2, 0), Db, Hw, { Holes = sideHoles, Colors = walls, Back = back })
	for _, wx in c.SideWindows or { -Db / 4, Db / 4 } do
		O.Window(m, CF(-half, F + winY, zc + wx) * Angles(0, -PI / 2, 0), 2.8, 3, c.Shutter)
		O.Window(m, CF(half, F + winY, zc - wx) * Angles(0, PI / 2, 0), 2.8, 3, c.Shutter)
	end
	if c.DoorX then
		O.Door(m, CF(c.DoorX, F, zf + 0.05), 3.4, 6.6)
		O.WallLantern(m, CF(c.DoorX + (if c.DoorX > 0 then 2.6 else -2.6), F + 5.6, zf + 0.3), { Range = 12, Brightness = 1 })
	end
	-- corner posts and wall plates
	for _, x in { -half, half } do
		for _, z in { zb, zf } do
			O.Part(m, "CornerPost", V(1.2, Hw + 0.4, 1.2), CF(x, F + Hw / 2 - 0.1, z), O.Jitter(trim, 0.05), "Wood")
		end
	end
	O.Part(m, "WallPlate", V(W + 1.2, 0.8, 0.9), CF(0, F + Hw - 0.1, zf + 0.15), trim, "Wood")
	O.Part(m, "WallPlate", V(W + 1.2, 0.8, 0.9), CF(0, F + Hw - 0.1, zb - 0.15), trim, "Wood")
	O.Part(m, "WallPlate", V(0.9, 0.8, Db), CF(-half - 0.15, F + Hw - 0.1, zc), trim, "Wood")
	O.Part(m, "WallPlate", V(0.9, 0.8, Db), CF(half + 0.15, F + Hw - 0.1, zc), trim, "Wood")
	O.Part(m, "SillBeam", V(W + 1.2, 0.7, 0.9), CF(0, F + 0.2, zb - 0.15), trim, "Wood")
	O.Part(m, "SillBeam", V(0.9, 0.7, Db), CF(-half - 0.15, F + 0.2, zc), trim, "Wood")
	O.Part(m, "SillBeam", V(0.9, 0.7, Db), CF(half + 0.15, F + 0.2, zc), trim, "Wood")

	-- Shop window: frame, counter, propped shutter ---------------------------------------------------
	local oy0, oy1 = F + op.Y0, F + op.Y0 + op.H
	local counter = O.Part(m, "ShopCounter", V(op.W + 1.2, 0.35, 2.3), CF(0, oy0 + 0.05, zf - 0.25), O.Jitter(rgb(140, 98, 62), 0.04), "WoodPlanks")
	for _, x in { -op.W / 2 - 0.25, op.W / 2 + 0.25 } do
		O.Part(m, "OpeningFrame", V(0.55, op.H + 0.4, 0.8), CF(x, (oy0 + oy1) / 2, zf - 0.1), trim, "Wood")
		O.Stick(m, "CounterBracket", V(x * 0.9, oy0 - 1.4, zf + 0.1), V(x * 0.9, oy0 - 0.1, zf + 0.85), 0.3, 0.3, trim, "Wood", { CanCollide = false })
	end
	O.Part(m, "OpeningFrame", V(op.W + 1.0, 0.55, 0.8), CF(0, oy1 + 0.2, zf - 0.1), trim, "Wood")
	-- the shutter flap, propped open on two sticks
	local flap = CF(0, oy1 + 0.45, zf + 0.15) * Angles(math.rad(68), 0, 0)
	O.BoardPanel(m, flap, op.W + 0.6, 2.6, c.ShutterBoards or walls, 1.0)
	for _, x in { -op.W / 2 + 0.6, op.W / 2 - 0.6 } do
		O.Stick(m, "ShutterProp", V(x, oy0 + 0.25, zf + 0.6), (flap * CF(x, 2.3, -0.1)).Position, 0.18, 0.18, trim, "Wood", { CanCollide = false })
	end

	-- Roof ---------------------------------------------------------------------------------------------
	local rise = roof.Rise or half * 0.72
	local info: { [string]: any } = { F = F, zf = zf, zb = zb, zc = zc, pz = pz, Hw = Hw, W = W, D = D, Db = Db, half = half, Counter = counter, Rise = rise, OpeningTop = oy1 }
	if not roof.AlongX then
		-- front gable with a deep roof over the porch, carried by a truss
		O.GableWall(m, CF(0, F + Hw, zf), W, rise - 0.1, { Colors = walls, Back = back })
		O.GableWall(m, CF(0, F + Hw, zb) * Angles(0, PI, 0), W, rise - 0.1, { Colors = walls, Back = back })
		info.RidgeY = F + Hw + O.Roof(m, CF(0, F + Hw, zc), W, Db, { Style = roof.Style, Colors = roof.Colors, Rise = rise, Front = Pd + 0.9, Back = 1.5, Edge = trim })
		local tz = pz - 0.45
		for _, x in { -half + 0.5, half - 0.5 } do
			O.Part(m, "PorchPost", V(1.0, Hw - 0.2, 1.0), CF(x, F + (Hw - 0.2) / 2, tz), O.Jitter(trim, 0.05), "Wood")
			O.Stick(m, "KneeBrace", V(x, F + Hw - 2.6, tz), V(x * 0.78, F + Hw - 0.6, tz), 0.4, 0.4, trim, "Wood", { CanCollide = false })
		end
		O.Part(m, "TieBeam", V(W + 0.4, 0.9, 1.0), CF(0, F + Hw - 0.4, tz), trim, "Wood")
		for _, side in { -1, 1 } do
			O.Part(m, "PorchBeam", V(0.8, 0.8, Pd + 0.6), CF(side * (half - 0.5), F + Hw - 0.4, zf + Pd / 2), trim, "Wood")
		end
		-- open gable truss above the sign: collar beam and king post
		local collarY = F + Hw + rise * 0.74
		O.Part(m, "Collar", V(W * 0.26 + 0.6, 0.7, 0.8), CF(0, collarY, tz), trim, "Wood", { CanCollide = false })
		O.Part(m, "KingPost", V(0.7, rise * 0.26, 0.7), CF(0, collarY + rise * 0.13, tz), trim, "Wood", { CanCollide = false })
		local sw = math.min(W * 0.5, 12.5)
		O.Sign(m, CF(0, F + Hw + 1.75, tz + 0.1), sw, 2.6, title, { TwoSided = false, Color = c.SignColor, Emblem = c.Emblem, EmblemScale = 0.9 })
		info.SignTop = F + Hw + 3.1
		info.TieZ = tz
	else
		-- side gables, the eave faces the street; a lean-to roof covers the porch
		O.GableWall(m, CF(-half, F + Hw, zc) * Angles(0, -PI / 2, 0), Db, (Db / 2) * 0.72 - 0.1, { Colors = walls, Back = back })
		O.GableWall(m, CF(half, F + Hw, zc) * Angles(0, PI / 2, 0), Db, (Db / 2) * 0.72 - 0.1, { Colors = walls, Back = back })
		info.RidgeY = F + Hw + O.Roof(m, CF(0, F + Hw, zc) * Angles(0, PI / 2, 0), Db, W, { Style = roof.Style, Colors = roof.Colors, Rise = (Db / 2) * 0.72, Front = 1.5, Back = 1.5, Edge = trim })
		local hy = F + Hw - 0.9
		local ly = F + Hw - 2.6
		O.LeanTo(m, CF(0, hy, zf + 0.2), W + 1.2, Pd + 0.7, hy - ly, roof.PorchColors or roof.Colors, roof.Style == "Thatch")
		local tz = pz - 0.45
		local postH = ly - F - 0.3 + 0.2
		for _, x in { -half + 0.5, half - 0.5 } do
			O.Part(m, "PorchPost", V(1.0, postH, 1.0), CF(x, F + postH / 2, tz), O.Jitter(trim, 0.05), "Wood")
			O.Stick(m, "KneeBrace", V(x, F + postH - 2, tz), V(x * 0.8, F + postH - 0.2, tz), 0.4, 0.4, trim, "Wood", { CanCollide = false })
		end
		O.Part(m, "PorchBeam", V(W + 0.4, 0.8, 0.9), CF(0, F + postH - 0.2, tz), trim, "Wood")
		-- the sign stands on the porch roof
		local sw = math.min(W * 0.55, 14)
		local signY = ly + 1.7
		O.Sign(m, CF(0, signY, tz + 0.2), sw, 2.6, title, { Color = c.SignColor, Emblem = c.Emblem, EmblemScale = 0.9 })
		for _, x in { -sw * 0.3, sw * 0.3 } do
			O.Part(m, "SignPost", V(0.35, 1.6, 0.35), CF(x, ly + 0.2, tz + 0.05), trim, "Wood", { CanCollide = false })
		end
		info.SignTop = signY + 1.3
		info.TieZ = tz
		info.PorchRoofY = ly
	end

	-- Stairs and porch railings ----------------------------------------------------------------------
	local stairW = c.StairW or 6
	local footZ = pz + F * 1.6
	local rise2 = F - g(0, footZ)
	local run = O.Stairs(m, CF(0, F, pz), stairW, math.max(0.8, rise2))
	info.StairEnd = pz + run
	local rx = stairW / 2 + 0.3
	O.Railing(m, V(-half + 0.5, F, pz - 0.45), V(-rx, F, pz - 0.45), { Height = 3 })
	O.Railing(m, V(rx, F, pz - 0.45), V(half - 0.5, F, pz - 0.45), { Height = 3 })
	for _, x in { -half + 0.45, half - 0.45 } do
		O.Railing(m, V(x, F, zf + 0.6), V(x, F, pz - 0.45), { Height = 3 })
	end

	-- Hanging lanterns at the porch front, one lighting the counter
	for _, x in { -half + 3.2, half - 3.2 } do
		O.Lantern(m, CF(x, F + (if roof.AlongX then info.PorchRoofY - F - 0.7 else Hw - 0.85), info.TieZ), { Range = 14, Brightness = 1.1 })
	end
	O.Lantern(m, CF(op.W / 2 - 1.6, oy1 - 0.1, zf - 1.0), { Range = 16, Brightness = 1.4, Scale = 0.85 })
	-- an upper floor seen through the windows
	O.Part(m, "Ceiling", V(W - 0.6, 0.4, Db - 0.6), CF(0, F + Hw - 0.6, zc), rgb(96, 70, 48), "WoodPlanks", { CanCollide = false })

	-- Back shelves inside the shop
	if c.Shelves ~= false then
		for _, y in { 3.2, 5.6 } do
			O.Part(m, "Shelf", V(W * 0.6, 0.25, 1.3), CF(0, F + y, zb + 1.2), rgb(120, 86, 56), "WoodPlanks", { CanCollide = false })
		end
	end
	return info
end

-- Little helper to scatter goods on the back shelves
local function shelfGoods(m: any, info: { [string]: any }, kinds: { string })
	local F, zb, W = info.F, info.zb, info.W
	for _, y in { 3.33, 5.73 } do
		local x = -W * 0.28
		while x < W * 0.28 do
			local kind = O.Pick(kinds)
			if kind == "Bottle" then
				O.Bottle(m, CF(x, F + y, zb + 1.2), O.Pick({ rgb(60, 120, 70), rgb(120, 60, 40), rgb(60, 80, 140) }))
				x += 0.7
			elseif kind == "Box" then
				O.Part(m, "Box", V(1.2, 1.0, 0.9), CF(x + 0.3, F + y + 0.5, zb + 1.2), O.Jitter(rgb(170, 128, 80), 0.1), "WoodPlanks", { CanCollide = false })
				x += 1.5
			elseif kind == "Jar" then
				O.Cyl(m, "Jar", CF(x, F + y + 0.45, zb + 1.2), 0.9, 0.8, O.Pick({ rgb(180, 110, 70), rgb(200, 190, 170), rgb(90, 130, 140) }), "SmoothPlastic", { CanCollide = false })
				x += 1.1
			elseif kind == "Scroll" then
				O.Part(m, "Scroll", V(1.3, 0.35, 0.35), CF(x + 0.3, F + y + 0.18, zb + 1.2), rgb(236, 220, 176), "SmoothPlastic", { Shape = "Cylinder", CanCollide = false })
				x += 1.0
			else
				O.Ball(m, "Goods", V(x, F + y + 0.35, zb + 1.2), 0.7, O.Pick({ rgb(220, 60, 50), rgb(240, 180, 40), rgb(90, 170, 60) }), "SmoothPlastic", { CanCollide = false })
				x += 0.8
			end
			x += 0.25
		end
	end
end

-- Shipwright: ship skeleton on the slip, lumber, sawhorse, tools -------------------------------------
local function decorateShipwright(m: any, info: { [string]: any }, g: (number, number) -> number)
	local F, zf, pz, half = info.F, info.zf, info.pz, info.half
	shelfGoods(m, info, { "Box", "Jar", "Box" })
	-- tools on the counter
	O.Hammer(m, CF(-4, F + 2.65, zf - 0.3) * Angles(0, 0.4, 0))
	O.Part(m, "Plans", V(2.4, 0.05, 1.6), CF(3, F + 2.67, zf - 0.4) * Angles(0, -0.2, 0), rgb(220, 226, 236), "SmoothPlastic", { CanCollide = false })
	O.Part(m, "PlanLines", V(1.8, 0.06, 0.08), CF(3, F + 2.69, zf - 0.4) * Angles(0, -0.2, 0), rgb(60, 90, 160), "SmoothPlastic", { CanCollide = false })
	-- porch: rope, barrels, oars
	O.RopeCoil(m, CF(-half + 2.2, F, zf + 2.0))
	O.Barrel(m, CF(half - 2, F, zf + 1.6))
	O.Crate(m, CF(half - 2.2, F, zf + 3.9), 2)
	for i = 0, 2 do
		O.Stick(m, "Oar", V(-half + 1.2 + i * 0.7, F + 0.1, zf + 0.5), V(-half + 1.0 + i * 0.7, F + 6.2, zf + 0.3), 0.25, 0.12, rgb(176, 136, 88), "Wood", { CanCollide = false })
		O.Part(m, "OarBlade", V(0.6, 1.6, 0.12), CF(-half + 1.0 + i * 0.7, F + 5.6, zf + 0.33), rgb(176, 136, 88), "WoodPlanks", { CanCollide = false })
	end
	-- ship's wheel on the front wall
	local wheel = CF(half - 4.2, F + 5.2, zf + 0.35)
	O.CylZ(m, "WheelRim", wheel, 0.3, 3.0, rgb(120, 78, 44), "Wood", { CanCollide = false })
	O.CylZ(m, "WheelHole", wheel * CF(0, 0, 0.02), 0.32, 2.4, info.WallBack or rgb(84, 60, 42), "WoodPlanks", { CanCollide = false })
	O.CylZ(m, "WheelHub", wheel * CF(0, 0, 0.1), 0.5, 0.7, O.BRASS, "Metal", { CanCollide = false })
	for k = 0, 3 do
		O.Part(m, "WheelSpoke", V(4.0, 0.22, 0.22), wheel * CF(0, 0, 0.12) * Angles(0, 0, k * PI / 4), rgb(140, 92, 52), "Wood", { CanCollide = false })
	end
	-- the slipway beside the workshop: a hull skeleton
	local slip = CF(half + 6.5, 0, 1)
	local base = g(half + 6.5, 1)
	local keelY = base + 1.6
	O.Part(m, "Keel", V(1.0, 1.0, 20), slip * CF(0, keelY, 0), rgb(110, 76, 48), "Wood")
	for _, z in { -7, 0, 7 } do
		O.Part(m, "Cradle", V(3.2, 1.2, 1.2), slip * CF(0, base + 0.6, z), rgb(96, 70, 48), "Wood")
	end
	O.Stick(m, "Stem", (slip * CF(0, keelY, -10)).Position, (slip * CF(0, keelY + 7.5, -12.5)).Position, 0.9, 0.9, rgb(110, 76, 48))
	O.Stick(m, "Sternpost", (slip * CF(0, keelY, 10)).Position, (slip * CF(0, keelY + 6.5, 10.8)).Position, 0.9, 0.9, rgb(110, 76, 48))
	for i = -3, 3 do
		local z = i * 2.6
		local w = 3.8 * (1 - (math.abs(i) / 4.2) ^ 2)
		for _, side in { -1, 1 } do
			local p0 = (slip * CF(0, keelY + 0.3, z)).Position
			local p1 = (slip * CF(side * w, keelY + 2.2, z)).Position
			local p2 = (slip * CF(side * (w + 0.5), keelY + 5.6, z)).Position
			O.Stick(m, "Rib", p0, p1, 0.5, 0.6, rgb(176, 132, 84), "Wood", { CanCollide = false })
			O.Stick(m, "Rib", p1, p2, 0.5, 0.6, rgb(176, 132, 84), "Wood", { CanCollide = false })
		end
	end
	for _, side in { -1, 1 } do
		O.Stick(m, "Stringer", (slip * CF(side * 3.6, keelY + 5.0, -9.5)).Position, (slip * CF(side * 4.3, keelY + 5.6, 8.5)).Position, 0.4, 0.5, rgb(160, 120, 76), "Wood", { CanCollide = false })
	end
	O.Hoist(m, slip * CF(0, base, 0.5), 16, 7.4)
	O.Lumber(m, CF(half + 5, base, -12.2) * Angles(0, PI / 2, 0), 9, 3)
	O.Sawhorse(m, CF(half + 3.8, g(half + 3.8, zf + 5), zf + 5) * Angles(0, 0.2, 0))
	O.Logs(m, CF(-half - 3.2, g(-half - 3.2, -3), -3) * Angles(0, PI / 2, 0), 8)
	O.LanternPost(m, CF(half + 2.4, g(half + 2.4, pz + 2), pz + 2) * Angles(0, PI / 2, 0), 8)
end

-- Merchant: chests of gold, scales, maps, sacks ---------------------------------------------------------
local function decorateMerchant(m: any, info: { [string]: any }, g: (number, number) -> number)
	local F, zf, pz, half = info.F, info.zf, info.pz, info.half
	shelfGoods(m, info, { "Scroll", "Bottle", "Box", "Jar" })
	O.Scales(m, CF(-3.8, F + 2.63, zf - 0.4))
	O.MapSheet(m, CF(3.2, F + 2.63, zf - 0.5) * Angles(0, 0.15, 0))
	O.Scrolls(m, CF(5.4, F + 2.63, zf - 0.3), 2)
	for i = -1, 1 do
		O.Cyl(m, "Coins", CF(-1.2 + i * 0.55, F + 2.73, zf - 0.1), 0.2 + (i + 1) * 0.15, 0.5, O.GOLD, "Metal", { CanCollide = false })
	end
	-- porch goods
	O.Chest(m, CF(-half + 2.4, F, zf + 1.8) * Angles(0, 0.3, 0), { Gold = true })
	O.Chest(m, CF(half - 2.6, F, zf + 1.6) * Angles(0, -0.25, 0), { Color = rgb(70, 50, 40), Band = rgb(170, 170, 176) })
	O.Sack(m, CF(-half + 1.6, F, zf + 4.2))
	O.Sack(m, CF(-half + 2.9, F, zf + 4.5), rgb(196, 170, 120))
	O.Crate(m, CF(half - 1.9, F, zf + 4.0), 2.0)
	O.Crate(m, CF(half - 1.9, F + 2.0, zf + 4.0) * Angles(0, 0.4, 0), 1.4)
	-- sacks and barrels at the foot of the stairs
	O.Barrel(m, CF(-5.2, g(-5.2, pz + 2.5), pz + 2.5))
	O.Barrel(m, CF(-6.6, g(-6.6, pz + 1.2), pz + 1.2), { Color = rgb(150, 100, 60) })
	O.LanternPost(m, CF(5.6, g(5.6, pz + 2.2), pz + 2.2), 8)
	-- a striped awning over each side window
	for _, side in { -1, 1 } do
		for _, wz in { -info.Db / 4, info.Db / 4 } do
			for i = 0, 2 do
				local z = info.zc + wz - 2.25 + (i + 0.5) * 1.5
				O.Stick(m, "Awning", V(side * (half + 0.3), F + 6.9, z), V(side * (half + 2.2), F + 5.9, z), 1.52, 0.12, if i % 2 == 0 then rgb(196, 54, 46) else rgb(240, 230, 210), "Fabric", { CanCollide = false })
			end
		end
	end
	-- a little cupola with a weathervane on the ridge
	local ridge = info.RidgeY
	local cz = info.zc
	O.Part(m, "Cupola", V(3.2, 2.6, 3.2), CF(0, ridge + 0.6, cz), O.Jitter(O.TEAL[1], 0.04), "WoodPlanks")
	for _, z in { -1.62, 1.62 } do
		O.Part(m, "Louvre", V(2.0, 1.2, 0.1), CF(0, ridge + 1.1, cz + z), O.DARK, "Wood", { CanCollide = false })
	end
	for _, side in { -1, 1 } do
		O.Triangle(m, "CupolaRoof", V(0, ridge + 1.9, cz), V(side * 2.2, 0, 0), V(0, 1.6, 0), 4.2, rgb(150, 70, 52), "WoodPlanks", { CanCollide = false })
	end
	O.Part(m, "VanePost", V(0.16, 2.4, 0.16), CF(0, ridge + 4.6, cz), IRON, "Metal", { CanCollide = false })
	O.Part(m, "VaneArrow", V(0.12, 0.12, 2.6), CF(0, ridge + 5.2, cz), IRON, "Metal", { CanCollide = false })
	O.Triangle(m, "VaneTail", V(0, ridge + 5.2, cz + 1.3), V(0, 0, -0.9), V(0, 0.7, 0), 0.08, IRON, "Metal", { CanCollide = false })
	-- the merchant's flag and a hand cart of goods
	O.FlagPole(m, CF(-half - 1.4, g(-half - 1.4, zf + 1), zf + 1), 16, rgb(30, 110, 120))
	O.Cart(m, CF(half + 4.2, g(half + 4.2, 3), 3) * Angles(0, PI / 2 + 0.25, 0))
end

-- Armory: weapon racks, cannonballs, a cannon ---------------------------------------------------------
local function decorateArmory(m: any, info: { [string]: any }, g: (number, number) -> number)
	local F, zf, pz, half = info.F, info.zf, info.pz, info.half
	-- weapons on the back wall, visible through the window
	O.WeaponRack(m, CF(-3.8, F, info.zb + 0.9), 6)
	O.WeaponRack(m, CF(3.8, F, info.zb + 0.9), 6)
	O.Cutlass(m, CF(-2.8, F + 2.75, zf - 0.3) * Angles(PI / 2, 0, 0.5))
	O.Musket(m, CF(1.0, F + 2.75, zf - 0.6) * Angles(PI / 2, 0, -1.4))
	-- porch racks and cannonballs
	O.WeaponRack(m, CF(-half + 1.6, F, zf + 2.8) * Angles(0, PI / 2, 0), 4.5)
	O.Cannonballs(m, CF(half - 2.2, F, zf + 1.8))
	O.Barrel(m, CF(half - 2.0, F, zf + 4.3), { Color = rgb(70, 60, 56) })
	O.Part(m, "PowderMark", V(0.1, 0.8, 0.8), CF(half - 2.0 - 0.99, F + 1.3, zf + 4.3), rgb(190, 40, 40), "SmoothPlastic", { CanCollide = false })
	-- a cannon guarding the steps
	O.Cannon(m, CF(-7.2, g(-7.2, pz + 3.0), pz + 3.0) * Angles(0, -0.35, 0), 1.1)
	O.Cannonballs(m, CF(7.0, g(7.0, pz + 2.4), pz + 2.4), 0.9)
	-- practice yard beside the armory: straw dummies and a shooting target
	local yx = half + 5.5
	O.Dummy(m, CF(yx, g(yx, 2), 2) * Angles(0, -PI / 2 + 0.3, 0))
	O.Dummy(m, CF(yx + 1, g(yx + 1, -4.5), -4.5) * Angles(0, -PI / 2 - 0.2, 0))
	O.Target(m, CF(yx + 0.5, g(yx + 0.5, 8.5), 8.5) * Angles(0, -PI / 2 + 0.5, 0))
	O.LanternPost(m, CF(5.8, g(5.8, pz + 2.6), pz + 2.6), 8)
	-- the forge chimney through the back of the roof, smoking
	local chX, chZ = -half + 2.6, info.zb + 2.4
	local chTop = F + info.Hw + info.Rise * 0.72 + 1.2
	O.Part(m, "Chimney", V(2.6, chTop - F, 2.6), CF(chX, (F + chTop) / 2, chZ), rgb(128, 120, 112), "Cobblestone")
	O.Part(m, "ChimneyCap", V(3.2, 0.5, 3.2), CF(chX, chTop + 0.2, chZ), rgb(96, 92, 88), "Slate")
	local smoke = O.Part(m, "SmokeSource", V(1, 0.2, 1), CF(chX, chTop + 0.6, chZ), rgb(0, 0, 0), "SmoothPlastic", { Transparency = 1, CanCollide = false, CanQuery = false })
	P.emitter(smoke, { Name = "Smoke", Rate = 3, Lifetime = P.NumberRange.new(4, 7), Speed = P.NumberRange.new(2, 4), Size = P.NumberSequence.new({ P.NumberSequenceKeypoint.new(0, 1.2), P.NumberSequenceKeypoint.new(1, 5) }), Transparency = P.NumberSequence.new({ P.NumberSequenceKeypoint.new(0, 0.5), P.NumberSequenceKeypoint.new(1, 1) }), Color = P.ColorSequence.new(rgb(150, 146, 146)), Acceleration = V(1.2, 0.5, 0), RotSpeed = P.NumberRange.new(-20, 20) })
end

-- Trading post: an open pavilion of counters piled with goods -------------------------------------------
local function buildTradingPost(m: any, c: { [string]: any }, g: (number, number) -> number, title: string)
	local W, D, F = c.W, c.D, c.F
	local half, hd = W / 2, D / 2
	local Hw = 9
	O.Stilts(m, -half, half, -hd, hd, F - 0.7, g, { Spacing = 6 })
	O.Deck(m, -half, half, -hd, hd, F, { AlongZ = true, Colors = O.HONEY, MaxLen = 20, PlankW = 1.3 })
	-- posts carrying the roof
	local posts = {}
	for _, x in { -half + 0.6, -half / 3, half / 3, half - 0.6 } do
		for _, z in { -hd + 0.6, hd - 0.6 } do
			table.insert(posts, { x, z })
		end
	end
	for _, z in { -hd / 3, hd / 3 } do
		table.insert(posts, { -half + 0.6, z })
		table.insert(posts, { half - 0.6, z })
	end
	for _, p in posts do
		O.Part(m, "Post", V(1.0, Hw, 1.0), CF(p[1], F + Hw / 2, p[2]), O.Jitter(DARK, 0.06), "Wood")
	end
	for _, z in { -hd + 0.6, hd - 0.6 } do
		O.Part(m, "Beam", V(W + 0.8, 0.9, 0.9), CF(0, F + Hw - 0.2, z), DARK, "Wood")
	end
	for _, x in { -half + 0.6, half - 0.6 } do
		O.Part(m, "Beam", V(0.9, 0.9, D), CF(x, F + Hw - 0.2, 0), DARK, "Wood")
	end
	local rise = hd * 0.95
	O.Roof(m, CF(0, F + Hw + 0.2, 0) * Angles(0, PI / 2, 0), D, W, { Style = "Thatch", Rise = rise, Front = 1.8, Back = 1.8, Over = 2.6 })
	-- open gable trusses
	for _, x in { -half + 0.6, half - 0.6 } do
		O.Part(m, "KingPost", V(0.6, rise - 0.6, 0.6), CF(x, F + Hw + 0.2 + (rise - 0.6) / 2, 0), DARK, "Wood")
		for _, side in { -1, 1 } do
			O.Stick(m, "Rafter", V(x, F + Hw + 0.2, side * (hd - 0.6)), V(x, F + Hw + rise - 0.2, 0), 0.5, 0.6, DARK, "Wood", { CanCollide = false })
		end
	end
	-- counters around three sides (open at the back for the trader)
	local function counter(x0: number, x1: number, z0: number, z1: number)
		O.Part(m, "Counter", V(x1 - x0, 2.3, z1 - z0), CF((x0 + x1) / 2, F + 1.15, (z0 + z1) / 2), O.Jitter(rgb(126, 88, 56), 0.05), "WoodPlanks")
		return O.Part(m, "CounterTop", V(x1 - x0 + 0.5, 0.3, z1 - z0 + 0.5), CF((x0 + x1) / 2, F + 2.45, (z0 + z1) / 2), rgb(150, 108, 68), "WoodPlanks")
	end
	local front = counter(-half + 2, half - 2, hd - 3.6, hd - 2.2)
	counter(-half + 2, -half + 3.4, -hd + 3, hd - 3.6)
	counter(half - 3.4, half - 2, -hd + 3, hd - 3.6)
	-- goods on the counters
	local fruit = { rgb(250, 150, 30), rgb(250, 214, 60), rgb(110, 190, 60), rgb(220, 50, 50), rgb(130, 80, 40) }
	O.Basket(m, CF(-6.5, F + 2.6, hd - 2.9), fruit)
	O.Basket(m, CF(-4.3, F + 2.6, hd - 2.9), { rgb(130, 80, 40), rgb(110, 70, 36) })
	O.Cloth(m, CF(4.0, F + 2.6, hd - 2.9), rgb(180, 50, 60))
	O.Cloth(m, CF(4.3, F + 3.4, hd - 2.9), rgb(50, 90, 170))
	O.Cloth(m, CF(6.6, F + 2.6, hd - 2.9), rgb(230, 190, 60))
	O.Chest(m, CF(1.6, F + 2.6, hd - 2.9) * Angles(0, PI, 0), { Scale = 0.6, Gold = true })
	for i = 0, 3 do
		O.Bottle(m, CF(-half + 2.7, F + 2.6, -3 + i * 1.2), O.Pick({ rgb(60, 120, 70), rgb(120, 60, 40), rgb(60, 80, 140) }))
	end
	O.Basket(m, CF(half - 2.7, F + 2.6, -2.5), fruit)
	O.Scrolls(m, CF(half - 2.7, F + 2.6, 1.5), 2)
	-- hanging goods from the beams
	for i = 0, 3 do
		O.Fish(m, CF(-6 + i * 1.3, F + Hw - 0.7, hd - 0.6), O.Pick({ rgb(150, 170, 180), rgb(200, 150, 110) }))
	end
	O.Net(m, CF(half - 0.4, F + 5.6, -hd / 2) * Angles(0, PI / 2, 0), 5, 3.4)
	for _, x in { -half + 2.6, half - 2.6 } do
		O.Lantern(m, CF(x, F + Hw - 0.65, hd - 0.6), { Range = 14, Brightness = 1.1 })
	end
	O.Lantern(m, CF(0, F + Hw - 0.65, 0), { Range = 16, Brightness = 1.3 })
	-- crates, sacks and barrels around the pavilion
	O.Crate(m, CF(-half + 2, F, -hd + 2))
	O.Crate(m, CF(-half + 2, F + 2.4, -hd + 2) * Angles(0, 0.5, 0), 1.6)
	O.Sack(m, CF(half - 2.2, F, -hd + 1.8))
	O.Barrel(m, CF(half - 4.2, F, -hd + 1.8))
	O.Barrel(m, CF(-half - 1.7, g(-half - 1.7, hd - 2.5), hd - 2.5))
	O.Crate(m, CF(half + 1.8, g(half + 1.8, hd + 2.5), hd + 2.5) * Angles(0, 0.3, 0))
	O.Sack(m, CF(half + 2.0, g(half + 2.0, hd + 5.0), hd + 5.0), rgb(196, 170, 120))
	-- carved sign standing on the front eave of the thatch
	O.Sign(m, CF(0, F + Hw + 2.0, hd + 1.3), 10, 2.4, title, { Color = rgb(100, 64, 38) })
	for _, x in { -3.4, 3.4 } do
		O.Part(m, "SignPost", V(0.4, 2.2, 0.4), CF(x, F + Hw + 0.4, hd + 1.15), DARK, "Wood", { CanCollide = false })
	end
	-- a barrel emblem on the gable truss facing the square
	O.Emblem(m, CF(half + 0.1, F + Hw + rise * 0.42, 0) * Angles(0, PI / 2, 0), "Barrel", 1.1)
	O.Emblem(m, CF(-half - 0.1, F + Hw + rise * 0.42, 0) * Angles(0, -PI / 2, 0), "Barrel", 1.1)
	-- flags on the ridge ends and bunting
	O.FlagPole(m, CF(-half - 1.2, F + Hw + rise - 2, 0), 8, rgb(230, 170, 40), { Width = 3.6, Height = 2.2, Diameter = 0.35 })
	O.Bunting(m, V(-half + 0.6, F + Hw - 1, hd - 0.4), V(half - 0.6, F + Hw - 1, hd - 0.4), { rgb(220, 60, 50), rgb(250, 210, 70), rgb(60, 130, 200), rgb(250, 246, 236) }, 10, 1.6)
	-- steps: front, both sides of the counter
	local run = O.Stairs(m, CF(0, F, hd), 7, math.max(0.8, F - g(0, hd + 3)))
	return { F = F, StairEnd = hd + run, Npc = CF(0, F, hd - 5.6), Counter = front }
end

-- Tavern "The Rusty Anchor": two storeys, a balcony and a thatched roof ------------------------------
local function buildTavern(m: any, c: { [string]: any }, g: (number, number) -> number, title: string)
	local W, D, F = c.W, c.D, c.F
	local half = W / 2
	local zf, zb = D / 2 - 1, -D / 2
	local Db = zf - zb
	local zc = (zf + zb) / 2
	local Pd = 5.5
	local pz = zf + Pd
	local H1, H2 = 8.5, 6.5
	local Hw = H1 + H2
	local walls = O.HONEY
	local back = rgb(84, 60, 42)
	O.Stilts(m, -half, half, zb, pz, F - 0.7, g, { Spacing = 9, NoBackBraces = true })
	O.Part(m, "Floor", V(W - 0.4, 0.7, Db - 0.4), CF(0, F - 0.35, zc), rgb(118, 86, 58), "WoodPlanks")
	O.Deck(m, -half, half, zf, pz, F, { Colors = O.WOOD })
	-- ground floor: wide counter opening + door; upper floor: windows and a balcony door
	local op = { W = 12, Y0 = 2.4, H = 5.0 }
	O.PlankWall(m, CF(0, F, zf), W, H1, { Holes = { { -op.W / 2, op.W / 2, op.Y0, op.Y0 + op.H }, { 8.6, 12, 0, 6.6 } }, Colors = walls, Back = back })
	O.PlankWall(m, CF(0, F + H1, zf), W, H2, { Holes = { { -1.6, 1.6, 0, 5.4 }, { -9.4, -6.6, 1.6, 4.4 }, { 6.6, 9.4, 1.6, 4.4 } }, Colors = O.TEAL, Back = back })
	O.PlankWall(m, CF(0, F, zb) * Angles(0, PI, 0), W, Hw, { Colors = walls, Back = back })
	local sideHoles = { { -4, -1.2, 3, 6 }, { 1.2, 4, 3, 6 }, { -1.4, 1.4, H1 + 1.6, H1 + 4.4 } }
	O.PlankWall(m, CF(-half, F, zc) * Angles(0, -PI / 2, 0), Db, H1, { Holes = { sideHoles[1], sideHoles[2] }, Colors = walls, Back = back })
	O.PlankWall(m, CF(half, F, zc) * Angles(0, PI / 2, 0), Db, H1, { Holes = { sideHoles[1], sideHoles[2] }, Colors = walls, Back = back })
	O.PlankWall(m, CF(-half, F + H1, zc) * Angles(0, -PI / 2, 0), Db, H2, { Holes = { { -1.4, 1.4, 1.6, 4.4 } }, Colors = O.TEAL, Back = back })
	O.PlankWall(m, CF(half, F + H1, zc) * Angles(0, PI / 2, 0), Db, H2, { Holes = { { -1.4, 1.4, 1.6, 4.4 } }, Colors = O.TEAL, Back = back })
	for _, side in { -1, 1 } do
		for _, wz in { -2.6, 2.6 } do
			O.Window(m, CF(side * half, F + 4.5, zc + wz) * Angles(0, side * PI / 2, 0), 2.8, 3, rgb(60, 120, 70))
		end
		O.Window(m, CF(side * half, F + H1 + 3, zc) * Angles(0, side * PI / 2, 0), 2.8, 2.8, rgb(150, 60, 40))
		O.Window(m, CF(side * 8, F + H1 + 3, zf), 2.8, 2.8, rgb(150, 60, 40))
	end
	O.Door(m, CF(10.3, F, zf + 0.05), 3.4, 6.6)
	O.Door(m, CF(0, F + H1, zf + 0.05), 3.2, 5.4, O.TEAL)
	O.Part(m, "UpperFloor", V(W - 0.6, 0.5, Db - 0.6), CF(0, F + H1 - 0.25, zc), rgb(96, 70, 48), "WoodPlanks")
	-- frame
	for _, x in { -half, half } do
		for _, z in { zb, zf } do
			O.Part(m, "CornerPost", V(1.3, Hw + 0.4, 1.3), CF(x, F + Hw / 2 - 0.1, z), DARK, "Wood")
		end
	end
	for _, y in { H1, Hw } do
		O.Part(m, "WallPlate", V(W + 1.3, 0.8, 1.0), CF(0, F + y - 0.1, zf + 0.15), DARK, "Wood")
		O.Part(m, "WallPlate", V(W + 1.3, 0.8, 1.0), CF(0, F + y - 0.1, zb - 0.15), DARK, "Wood")
		O.Part(m, "WallPlate", V(1.0, 0.8, Db), CF(-half - 0.15, F + y - 0.1, zc), DARK, "Wood")
		O.Part(m, "WallPlate", V(1.0, 0.8, Db), CF(half + 0.15, F + y - 0.1, zc), DARK, "Wood")
	end
	-- counter
	local oy0, oy1 = F + op.Y0, F + op.Y0 + op.H
	local counter = O.Part(m, "ShopCounter", V(op.W + 1.2, 0.35, 2.3), CF(0, oy0 + 0.05, zf - 0.25), rgb(140, 98, 62), "WoodPlanks")
	for _, x in { -op.W / 2 - 0.25, op.W / 2 + 0.25 } do
		O.Part(m, "OpeningFrame", V(0.55, op.H + 0.4, 0.8), CF(x, (oy0 + oy1) / 2, zf - 0.1), DARK, "Wood")
	end
	O.Part(m, "OpeningFrame", V(op.W + 1.0, 0.55, 0.8), CF(0, oy1 + 0.2, zf - 0.1), DARK, "Wood")
	-- balcony over the porch (also the porch roof)
	local by = F + H1
	O.Deck(m, -half, half, zf, pz, by + 0.3, { Colors = O.WOOD })
	for _, x in { -half + 0.5, -half / 2.6, half / 2.6, half - 0.5 } do
		O.Part(m, "PorchPost", V(1.0, H1 + 3.4, 1.0), CF(x, F + (H1 + 3.4) / 2, pz - 0.45), O.Jitter(DARK, 0.05), "Wood")
		O.Stick(m, "KneeBrace", V(x, by - 2.2, pz - 0.45), V(x + (if x < 0 then 1.6 else -1.6), by - 0.6, pz - 0.45), 0.35, 0.35, DARK, "Wood", { CanCollide = false })
	end
	O.Part(m, "BalconyBeam", V(W + 0.6, 0.9, 1.0), CF(0, by - 0.55, pz - 0.45), DARK, "Wood")
	O.Railing(m, V(-half + 0.5, by + 0.3, pz - 0.45), V(half - 0.5, by + 0.3, pz - 0.45), { Height = 3, Spacing = 3 })
	for _, x in { -half + 0.45, half - 0.45 } do
		O.Railing(m, V(x, by + 0.3, zf + 0.6), V(x, by + 0.3, pz - 0.45), { Height = 3, Spacing = 3 })
	end
	-- the hanging anchor sign between the middle posts... above the balcony rail
	O.Sign(m, CF(0, by + 4.6, pz - 0.2), 14, 2.8, title, { Color = rgb(92, 56, 34), Emblem = "Anchor", EmblemScale = 1.1 })
	for _, x in { -5.2, 5.2 } do
		O.Part(m, "SignPost", V(0.4, 2.4, 0.4), CF(x, by + 3.3 - 0.2, pz - 0.45), DARK, "Wood", { CanCollide = false })
	end
	O.Anchor(m, CF(-half - 0.6, F + H1 - 1.2, zf + 1.4) * Angles(0, PI / 2, 0), 0.75)
	-- roof: thatch, ridge along X, with a front cross gable over the balcony door
	local rise = (Db / 2) * 0.9
	O.GableWall(m, CF(-half, F + Hw, zc) * Angles(0, -PI / 2, 0), Db, rise - 0.1, { Colors = walls, Back = back })
	O.GableWall(m, CF(half, F + Hw, zc) * Angles(0, PI / 2, 0), Db, rise - 0.1, { Colors = walls, Back = back })
	local ridgeY = F + Hw + O.Roof(m, CF(0, F + Hw, zc) * Angles(0, PI / 2, 0), Db, W, { Style = "Thatch", Rise = rise, Front = 1.8, Back = 1.8, Over = 2.4 })
	-- stone chimney with smoke
	local chX, chZ = -half + 4, zb + 3
	O.Part(m, "Chimney", V(3, ridgeY - F + 2, 3), CF(chX, F + (ridgeY - F + 2) / 2, chZ), rgb(140, 132, 122), "Cobblestone")
	O.Part(m, "ChimneyCap", V(3.6, 0.6, 3.6), CF(chX, ridgeY + 2.3, chZ), rgb(110, 104, 98), "Slate")
	local smoke = O.Part(m, "SmokeSource", V(1, 0.2, 1), CF(chX, ridgeY + 2.7, chZ), rgb(0, 0, 0), "SmoothPlastic", { Transparency = 1, CanCollide = false, CanQuery = false })
	P.emitter(smoke, { Name = "Smoke", Rate = 3, Lifetime = P.NumberRange.new(5, 8), Speed = P.NumberRange.new(2, 4), Size = P.NumberSequence.new({ P.NumberSequenceKeypoint.new(0, 1.5), P.NumberSequenceKeypoint.new(1, 6) }), Transparency = P.NumberSequence.new({ P.NumberSequenceKeypoint.new(0, 0.55), P.NumberSequenceKeypoint.new(1, 1) }), Color = P.ColorSequence.new(rgb(220, 220, 224)), Acceleration = V(1.5, 0.6, 0), RotSpeed = P.NumberRange.new(-20, 20) })
	-- interior: kegs behind the bar, shelves of bottles
	for _, x in { -2.4, 2.4 } do
		O.Keg(m, CF(x, F, zb + 1.6) * Angles(0, PI / 2, 0))
	end
	for _, y in { 4.4, 6.2 } do
		O.Part(m, "Shelf", V(W * 0.6, 0.25, 1.0), CF(0, F + y, zb + 0.9), rgb(120, 86, 56), "WoodPlanks", { CanCollide = false })
		for i = 0, 4 do
			O.Bottle(m, CF(-6 + i * 3 + O.Range(-0.4, 0.4), F + y + 0.13, zb + 0.9), O.Pick({ rgb(60, 120, 70), rgb(120, 60, 40), rgb(60, 80, 140), rgb(170, 130, 50) }))
		end
	end
	O.Mug(m, CF(-3, F + 2.63, zf - 0.4))
	O.Mug(m, CF(-2.2, F + 2.63, zf - 0.1))
	O.Mug(m, CF(4, F + 2.63, zf - 0.3))
	O.Lantern(m, CF(4.4, oy1 - 0.1, zf - 1.0), { Range = 16, Brightness = 1.4, Scale = 0.85 })
	-- porch: tables, stools, barrels
	for _, x in { -8, 8 } do
		O.Table(m, CF(x, F, zf + 2.8), 3.6, 2.2)
		O.Mug(m, CF(x - 0.6, F + 2.8, zf + 2.6))
		O.Mug(m, CF(x + 0.8, F + 2.8, zf + 3.1))
		O.Stool(m, CF(x - 2.4, F, zf + 2.8))
		O.Stool(m, CF(x + 2.4, F, zf + 2.6))
	end
	O.Barrel(m, CF(-half + 1.6, F, zf + 1.4))
	O.Keg(m, CF(half - 1.8, F, zf + 4.2) * Angles(0, PI / 2, 0))
	for _, x in { -half + 3.2, half - 3.2 } do
		O.Lantern(m, CF(x, by - 1.0, pz - 0.45), { Range = 14, Brightness = 1.1 })
	end
	O.Lantern(m, CF(-4, by + 3.0, pz - 0.45), { Light = false })
	O.Lantern(m, CF(4, by + 3.0, pz - 0.45), { Light = false })
	-- bunting along the balcony
	O.Bunting(m, V(-half + 0.5, by + 3.0, pz - 0.2), V(-6.5, by + 3.0, pz - 0.2), { rgb(206, 50, 48), rgb(250, 210, 70), rgb(40, 110, 170) }, 6, 1.0)
	O.Bunting(m, V(6.5, by + 3.0, pz - 0.2), V(half - 0.5, by + 3.0, pz - 0.2), { rgb(206, 50, 48), rgb(250, 210, 70), rgb(40, 110, 170) }, 6, 1.0)
	-- outdoor seating beside the tavern
	local sx, sz = half + 6, 2
	O.Table(m, CF(sx, g(sx, sz), sz) * Angles(0, 0.3, 0), 4, 2.4)
	O.Stool(m, CF(sx - 2.6, g(sx - 2.6, sz), sz))
	O.Stool(m, CF(sx + 2.6, g(sx + 2.6, sz + 0.8), sz + 0.8))
	O.Barrel(m, CF(sx, g(sx, sz - 5), sz - 5))
	O.Barrel(m, CF(sx + 2.1, g(sx + 2.1, sz - 5.4), sz - 5.4), { Color = rgb(150, 100, 60) })
	O.LanternPost(m, CF(sx - 1, g(sx - 1, sz + 4.5), sz + 4.5), 8)
	-- stairs and porch railings
	local run = O.Stairs(m, CF(0, F, pz), 6, math.max(0.8, F - g(0, pz + F * 1.6)))
	O.Railing(m, V(-half + 0.5, F, pz - 0.45), V(-3.3, F, pz - 0.45), { Height = 3 })
	O.Railing(m, V(3.3, F, pz - 0.45), V(half - 0.5, F, pz - 0.45), { Height = 3 })
	return { F = F, zf = zf, pz = pz, StairEnd = pz + run, Counter = counter, Npc = CF(0, F, zf - 2.2) }
end

-- Shop placement --------------------------------------------------------------------------------------

local SHOP_STYLE = {
	Shipwright = {
		Walls = O.WOOD, Trim = rgb(70, 48, 32), Roof = { Style = "Shingle", Colors = O.TEAL_ROOF }, Shutter = rgb(44, 110, 150), DoorX = -9.2, SignColor = rgb(88, 56, 34), Emblem = "Wheel",
	},
	Merchant = {
		Walls = O.TEAL, Trim = rgb(66, 46, 32), Roof = { Style = "Shingle", Colors = O.RED_ROOF, AlongX = true, PorchColors = O.SHINGLE }, Shutter = rgb(170, 70, 50), DoorX = 9.2, SignColor = rgb(70, 46, 32), ShutterBoards = O.HONEY, Emblem = "Coin",
	},
	Armory = {
		Walls = O.DRIFT, Trim = rgb(58, 42, 32), Roof = { Style = "Shingle", Colors = O.SLATE }, Shutter = rgb(140, 40, 36), Stone = true, DoorX = -7.6, SignColor = rgb(60, 44, 34), SideWindows = { -3.2, 3.2 }, Shelves = false, Emblem = "Swords",
	},
}

local function buildShop(parent: any, shop: { [string]: any }, H: any)
	O.Seed(#shop.Id * 7919 + math.floor(shop.X * 13 + shop.Z * 7))
	local m = P.model(parent, shop.Id)
	local base = (H.GetHeight(shop.X, shop.Z))
	local origin = CF(shop.X, base, shop.Z) * Angles(0, shop.Yaw, 0)
	local function g(lx: number, lz: number): number
		local p = origin * V(lx, 0, lz)
		return (H.GetHeight(p.X, p.Z)) - base
	end
	local W, D = shop.Width, shop.Depth
	-- floor height: a little above the highest ground under the building
	local top = 0
	for x = -W / 2, W / 2, 4 do
		for z = -D / 2, D / 2 + 5, 4 do
			top = math.max(top, g(x, z))
		end
	end
	local F = top + (if shop.Id == "TradingPost" then 1.6 else 2.6)
	local c = { W = W, D = D, F = F }
	local info
	if shop.Id == "TradingPost" then
		info = buildTradingPost(m, c, g, shop.Title)
	elseif shop.Id == "Tavern" then
		info = buildTavern(m, c, g, shop.Title)
	else
		local style = SHOP_STYLE[shop.Id] or SHOP_STYLE.Shipwright
		for k, v in style do
			c[k] = v
		end
		info = shopShell(m, c, g, shop.Title)
		info.Npc = CF(0, F, info.zf - 2.2)
		if shop.Id == "Shipwright" then
			decorateShipwright(m, info, g)
		elseif shop.Id == "Merchant" then
			decorateMerchant(m, info, g)
		elseif shop.Id == "Armory" then
			decorateArmory(m, info, g)
		end
	end
	-- a carved sign on a gallows post at the front corner of the porch, hanging out to the side
	local sz = (info.pz or D / 2) + 1.0
	local sx = -(W / 2 + 0.9)
	local short = (string.gsub(shop.Title, "^THE ", ""))
	O.PostSign(m, CF(sx, g(sx, sz), sz) * Angles(0, PI, 0), short, { Lantern = true, Light = false, Height = 9.2, Width = math.clamp(#short * 0.36, 3.4, 4.6) })
	P.transform(m, origin)

	-- the shopkeeper stands behind the counter, facing the street
	shopkeeper(m, shop.Id, origin * info.Npc)
	if shop.Id == "Merchant" then
		local counter = info.Counter
		counter.Name = "SellCounter"
		counter:SetAttribute("ShopId", "Merchant")
		counter:AddTag("SellCounter")
		P.prompt(counter, {
			Name = "SellPrompt",
			ActionText = "Sell Treasure",
			ObjectText = "Trading Company",
			KeyboardKeyCode = P.Enum.KeyCode.F,
			GamepadKeyCode = P.Enum.KeyCode.ButtonY,
			MaxActivationDistance = 12,
			RequiresLineOfSight = false,
			Exclusivity = P.Enum.ProximityPromptExclusivity.AlwaysShow,
		})
	end
	return m, origin
end

-- Cottages of the outpost (no shop): small plank houses on stilts with a porch -----------------------
-- spec: X, Z, Yaw (front = local +Z), W, D, Roof ("Thatch" | "Shingle"), Walls, Shutter, Name
local function cottage(parent: any, spec: { [string]: any }, H: any)
	O.Seed(math.floor(spec.X * 31 + spec.Z * 17) + 99)
	local m = P.model(parent, spec.Name or "Cottage")
	local base = (H.GetHeight(spec.X, spec.Z))
	local origin = CF(spec.X, base, spec.Z) * Angles(0, spec.Yaw, 0)
	local function g(lx: number, lz: number): number
		local p = origin * V(lx, 0, lz)
		return (H.GetHeight(p.X, p.Z)) - base
	end
	local W, D = spec.W or 12, spec.D or 10
	local half = W / 2
	local zf, zb = D / 2, -D / 2
	local Pd = spec.Porch or 3.6
	local pz = zf + Pd
	local top = 0
	for lx = -half, half, 3 do
		for lz = zb, pz, 3 do
			top = math.max(top, g(lx, lz))
		end
	end
	local F = top + (spec.Lift or 2.4)
	local Hw = spec.Hw or 7.2
	local walls = spec.Walls or O.WOOD
	local trim = spec.Trim or rgb(70, 50, 34)
	local back = rgb(84, 60, 42)
	local thatch = spec.Roof == "Thatch"
	O.Stilts(m, -half, half, zb, pz, F - 0.6, g, { Spacing = 12, Braces = false })
	O.Part(m, "Floor", V(W - 0.4, 0.6, D - 0.4), CF(0, F - 0.3, 0), rgb(110, 80, 54), "WoodPlanks")
	O.Deck(m, -half, half, zf, pz, F, { MaxLen = 16, PlankW = 1.2 })
	local doorX = spec.DoorX or -2.2
	local winX = -doorX * 1.25
	local plank = { Colors = walls, Back = back, PlankH = 1.45, MaxLen = 24, SolidBack = true }
	local function wall(cf: any, len: number, holes: { any }?)
		local o = table.clone(plank)
		o.Holes = holes
		O.PlankWall(m, cf, len, Hw, o)
	end
	wall(CF(0, F, zf), W, { { doorX - 1.6, doorX + 1.6, 0, 6.3 }, { winX - 1.3, winX + 1.3, 2.6, 5.2 } })
	wall(CF(0, F, zb) * Angles(0, PI, 0), W)
	wall(CF(-half, F, 0) * Angles(0, -PI / 2, 0), D, { { -1.3, 1.3, 2.6, 5.2 } })
	wall(CF(half, F, 0) * Angles(0, PI / 2, 0), D)
	O.Door(m, CF(doorX, F, zf + 0.05), 3.2, 6.3)
	O.Window(m, CF(winX, F + 3.9, zf + 0.27), 2.6, 2.6, spec.Shutter)
	O.Window(m, CF(-half, F + 3.9, 0) * Angles(0, -PI / 2, 0) * CF(0, 0, 0.27), 2.6, 2.6)
	for _, x in { -half, half } do
		for _, z in { zb, zf } do
			O.Part(m, "CornerPost", V(1.0, Hw + 0.3, 1.0), CF(x, F + Hw / 2 - 0.1, z), O.Jitter(trim, 0.05), "Wood")
		end
	end
	-- roof: front gable reaching over the porch
	local rise = half * (if thatch then 0.95 else 0.8)
	O.GableWall(m, CF(0, F + Hw, zf), W, rise - 0.1, { Colors = walls })
	O.GableWall(m, CF(0, F + Hw, zb) * Angles(0, PI, 0), W, rise - 0.1, { Colors = walls })
	O.Roof(m, CF(0, F + Hw, 0), W, D, { Style = spec.Roof, Colors = spec.RoofColors, Rise = rise, Front = Pd + 0.6, Back = 1.2, Edge = trim })
	for _, x in { -half + 0.5, half - 0.5 } do
		O.Part(m, "PorchPost", V(0.9, Hw - 0.2, 0.9), CF(x, F + (Hw - 0.2) / 2, pz - 0.45), O.Jitter(trim, 0.05), "Wood")
	end
	O.Part(m, "TieBeam", V(W + 0.4, 0.8, 0.9), CF(0, F + Hw - 0.4, pz - 0.45), trim, "Wood")
	O.Lantern(m, CF(doorX + 2.4, F + Hw - 0.85, pz - 0.45), { Range = 12, Brightness = 0.9 })
	-- steps and a bit of life on the porch
	local run = O.Stairs(m, CF(doorX, F, pz), 4, math.max(0.8, F - g(doorX, pz + 2.5)))
	O.Railing(m, V(doorX + 2.3, F, pz - 0.45), V(half - 0.5, F, pz - 0.45), { Height = 2.8, Spacing = 3.5 })
	if spec.Props == "Fisher" then
		O.Net(m, CF(half + 0.35, F + 3.6, 0) * Angles(0, PI / 2, 0), 5, 3.2)
		O.Barrel(m, CF(winX + 1.4, F, zf + 1.6), { Scale = 0.8 })
		O.RopeCoil(m, CF(winX - 0.6, F, zf + 2.2), 0.8)
	elseif spec.Props == "Washing" then
		O.Barrel(m, CF(half - 1.6, F, zf + 1.5), { Scale = 0.8 })
		O.Stool(m, CF(winX - 0.8, F, zf + 1.6))
		local a, b = V(half - 0.5, F + Hw - 1.4, pz - 0.45), V(half + 6.5, g(half + 6.5, pz - 1) + 5.6, pz - 1)
		O.Part(m, "LinePole", V(0.45, 6.2, 0.45), CF(b.X, b.Y - 2.7, b.Z), O.DARK, "Wood")
		O.Rod(m, "Washline", a, b, 0.08, O.ROPE, "Fabric", { CanCollide = false, CanQuery = false })
		for i, col in { rgb(236, 230, 214), rgb(70, 110, 170), rgb(190, 60, 50) } do
			local t = i / 4
			local p = a:Lerp(b, t) - V(0, 0.2 + math.sin(t * PI) * 0.3, 0)
			O.Part(m, "Laundry", V(1.0 + i * 0.15, 1.5, 0.08), P.lookAt(p - V(0, 0.75, 0), p - V(0, 0.75, 0) + (b - a)) * Angles(0, PI / 2, 0), col, "Fabric", { CanCollide = false, CanQuery = false })
		end
	else
		O.Crate(m, CF(winX + 1.2, F, zf + 1.5) * Angles(0, 0.3, 0), 1.8)
		O.Sack(m, CF(winX - 0.8, F, zf + 1.7))
	end
	-- a chimney pipe on the side
	if spec.Chimney then
		local cx = half - 2.2
		O.Part(m, "Chimney", V(2.0, rise + 2.4, 2.0), CF(cx, F + Hw + (rise + 2.4) / 2 - 0.4, zb + 2.6), rgb(138, 128, 118), "Cobblestone")
		O.Part(m, "ChimneyCap", V(2.5, 0.4, 2.5), CF(cx, F + Hw + rise + 2.2, zb + 2.6), rgb(100, 96, 92), "Slate")
	end
	P.transform(m, origin)
	return m, F + base, run
end

-- Harbour watchtower: a lookout platform on four raked legs under a conical thatch cap ---------------
local function watchtower(parent: any, x: number, z: number, yaw: number, H: any)
	O.Seed(5150)
	local m = P.model(parent, "Watchtower")
	local base = (H.GetHeight(x, z))
	local origin = CF(x, base, z) * Angles(0, yaw, 0)
	local function g(lx: number, lz: number): number
		local p = origin * V(lx, 0, lz)
		return (H.GetHeight(p.X, p.Z)) - base
	end
	local h = 15
	local foot, top = 3.6, 2.5
	local wood = rgb(104, 76, 52)
	local function leg(sx: number, sz: number, t: number)
		local r = foot + (top - foot) * t
		return V(sx * r, h * t, sz * r)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local gy = g(sx * foot, sz * foot)
			O.Stick(m, "Leg", V(sx * foot, gy - 1, sz * foot), leg(sx, sz, 1) + V(0, 4.4, 0) + V(sx, 0, sz) * (-(foot - top) * 4.4 / h), 0.9, 0.9, O.Jitter(wood, 0.06), "Wood")
			P.pillar(m, sx * foot, sz * foot, gy - 0.3, gy + 0.4, 1.6, { Name = "Footing", Mat = "Slate", Color = rgb(120, 116, 108) })
		end
	end
	-- braces: an X on the back, single diagonals on the sides
	O.Stick(m, "Brace", leg(-1, -1, 0.1), leg(1, -1, 0.6), 0.35, 0.45, wood, "Wood", { CanCollide = false })
	O.Stick(m, "Brace", leg(1, -1, 0.1), leg(-1, -1, 0.6), 0.35, 0.45, wood, "Wood", { CanCollide = false })
	O.Stick(m, "Brace", leg(-1, -1, 0.15), leg(-1, 1, 0.65), 0.35, 0.45, wood, "Wood", { CanCollide = false })
	O.Stick(m, "Brace", leg(1, 1, 0.15), leg(1, -1, 0.65), 0.35, 0.45, wood, "Wood", { CanCollide = false })
	-- platform with a railing on three sides (the ladder comes up at the front)
	O.Part(m, "Platform", V(6.8, 0.5, 6.8), CF(0, h - 0.25, 0), O.Jitter(rgb(140, 102, 68), 0.05), "WoodPlanks")
	O.Part(m, "PlatformRim", V(7.2, 0.6, 7.2), CF(0, h - 0.75, 0), O.DARK, "Wood")
	for _, side in { { 0, -1 }, { -1, 0 }, { 1, 0 } } do
		local c = V(side[1] * 3.25, h + 2.6, side[2] * 3.25)
		local size = if side[1] == 0 then V(6.6, 0.35, 0.35) else V(0.35, 0.35, 6.6)
		O.Part(m, "Rail", size, CF(c), O.DARK, "Wood")
	end
	-- conical thatch cap
	local ry = h + 4.4
	for i, d in { 9.0, 7.0, 4.8, 2.6 } do
		O.Cyl(m, "Thatch", CF(0, ry + (i - 1) * 0.85 + 0.45, 0), 1.0, d, O.Jitter(O.STRAW[i % #O.STRAW + 1], 0.05), "Grass", { CanCollide = false })
	end
	O.Ball(m, "ThatchTop", V(0, ry + 3.9, 0), 1.3, O.STRAW[2], "Grass", { CanCollide = false })
	O.FlagPole(m, CF(0, ry + 4.1, 0), 4.5, rgb(20, 18, 22), { Width = 3.2, Height = 2.0, Diameter = 0.3 })
	O.Lantern(m, CF(0, ry - 0.1, 0), { Range = 22, Brightness = 1.3 })
	-- ladder up the front
	O.Part(m, "Ladder", V(2, h + 0.5, 2), CF(0, (h + 0.5) / 2 - 0.3, top + 1.1), rgb(110, 80, 54), "Wood", { Class = "TrussPart" })
	O.Crate(m, CF(-2.6, g(-2.6, 5.6), 5.6) * Angles(0, 0.4, 0), 2.2)
	O.Barrel(m, CF(2.8, g(2.8, 5.2), 5.2))
	P.transform(m, origin)
	return m
end

-- A campfire with log benches and a cooking pot on a spit ---------------------------------------
local function campfire(parent: any, x: number, z: number, H: any)
	O.Seed(9090)
	local m = P.model(parent, "Campfire")
	local function gy(px: number, pz: number): number
		return (H.GetHeight(px, pz))
	end
	local y = gy(x, z)
	local base = CF(x, y, z)
	for i = 0, 6 do
		local a = i * 2 * PI / 7
		O.Ball(m, "FireStone", (base * CF(math.cos(a) * 1.9, 0.2, math.sin(a) * 1.9)).Position, O.Range(0.8, 1.1), O.Jitter(rgb(128, 122, 114), 0.08), "Slate")
	end
	for k = 0, 1 do
		O.Part(m, "FireLog", V(2.6, 0.5, 0.5), base * CF(0, 0.35, 0) * Angles(0, k * PI / 2 + 0.4, 0) * Angles(0, 0, 0.12), rgb(90, 60, 40), "Wood", { Shape = "Cylinder" })
	end
	local core = O.Ball(m, "Embers", (base * CF(0, 0.55, 0)).Position, 0.9, rgb(255, 130, 40), "Neon", { CanCollide = false, CanQuery = false })
	local fire = P.Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 8
	fire.Parent = core
	P.pointLight(core, rgb(255, 150, 70), 22, 1.6, false)
	-- spit and pot
	for _, sx in { -1.7, 1.7 } do
		O.Stick(m, "SpitPost", (base * CF(sx, 0, 0)).Position, (base * CF(sx * 0.95, 3.0, 0)).Position, 0.22, 0.22, O.DARK, "Wood", { CanCollide = false })
	end
	O.Part(m, "Spit", V(3.8, 0.16, 0.16), base * CF(0, 2.95, 0), O.IRON, "Metal", { CanCollide = false })
	O.Cyl(m, "Pot", base * CF(0, 1.95, 0), 1.0, 1.2, rgb(46, 44, 46), "Metal", { CanCollide = false })
	-- log benches around it
	for i = 0, 2 do
		local a = i * 2 * PI / 3 + 0.5
		local p = (base * CF(math.cos(a) * 5, 0, math.sin(a) * 5)).Position
		O.Part(m, "LogBench", V(3.8, 1.1, 1.1), CF(p.X, gy(p.X, p.Z) + 0.45, p.Z) * Angles(0, -a + PI / 2, 0), O.Jitter(rgb(112, 80, 52), 0.08), "Wood", { Shape = "Cylinder" })
	end
	return m
end

-- A fenced vegetable garden with a scarecrow --------------------------------------------------------
local function garden(parent: any, x: number, z: number, yaw: number, H: any)
	O.Seed(4711)
	local m = P.model(parent, "Garden")
	local base = (H.GetHeight(x, z))
	local origin = CF(x, base, z) * Angles(0, yaw, 0)
	local function g(lx: number, lz: number): number
		local p = origin * V(lx, 0, lz)
		return (H.GetHeight(p.X, p.Z)) - base
	end
	local hw, hd = 7.5, 5.5
	for _, px in { -hw, 0, hw } do
		for _, pz in { -hd, hd } do
			O.Part(m, "FencePost", V(0.5, 3.4, 0.5), CF(px, g(px, pz) + 1.2, pz) * Angles(0, 0, math.rad(O.Range(-3, 3))), O.Jitter(O.DARK, 0.08), "Wood")
		end
	end
	for _, pz in { -hd, hd } do
		O.Stick(m, "FenceRail", V(-hw, g(-hw, pz) + 2.3, pz), V(hw, g(hw, pz) + 2.3, pz), 0.25, 0.4, O.Jitter(rgb(120, 88, 58), 0.06), "Wood")
	end
	for _, px in { -hw, hw } do
		O.Stick(m, "FenceRail", V(px, g(px, -hd) + 2.3, -hd), V(px, g(px, hd) + 2.3, hd), 0.25, 0.4, O.Jitter(rgb(120, 88, 58), 0.06), "Wood")
	end
	local crops = { rgb(96, 168, 64), rgb(232, 132, 40), rgb(124, 186, 74) }
	for i, rz in { -3, 0, 3 } do
		O.Part(m, "Bed", V(12, 0.5, 1.9), CF(0, g(0, rz) + 0.1, rz), rgb(104, 76, 52), "Ground", { CanCollide = false })
		for k = -1, 1 do
			local px = k * 3.6 + O.Range(-0.4, 0.4)
			local size = if i == 2 then V(1.1, 0.9, 1.1) else V(1.4, 0.8, 1.4)
			local plant = O.Part(m, "Crop", size, CF(px, g(px, rz) + 0.65, rz), O.Jitter(crops[i], 0.08), "SmoothPlastic", { CanCollide = false })
			local mesh = P.Instance.new("SpecialMesh")
			mesh.MeshType = P.Enum.MeshType.Sphere
			mesh.Parent = plant
		end
	end
	O.Dummy(m, CF(5.2, g(5.2, 1.5), 1.5) * Angles(0, 0.4, 0))
	P.transform(m, origin)
	return m
end

-- Market stalls ------------------------------------------------------------------------------------------

local function stall(parent: any, cf: any, colorA: any, colorB: any, kind: string)
	local m = P.model(parent, "MarketStall")
	O.Part(m, "StallBase", V(9.4, 0.5, 4.4), CF(0, 0.25, 0), DARK, "WoodPlanks")
	O.Part(m, "StallCounter", V(8.6, 2.6, 2.2), CF(0, 1.55, 1.0), O.Jitter(rgb(140, 100, 62), 0.05), "WoodPlanks")
	O.Part(m, "StallTop", V(9.2, 0.3, 2.6), CF(0, 3.0, 1.0), rgb(160, 116, 72), "WoodPlanks")
	O.Part(m, "StallSkirt", V(8.7, 0.6, 0.12), CF(0, 2.4, 2.18), colorA, "Fabric", { CanCollide = false })
	for _, x in { -4.3, 4.3 } do
		for _, z in { -1.9, 1.9 } do
			local h = if z < 0 then 8.6 else 7.4
			O.Part(m, "Post", V(0.5, h, 0.5), CF(x, h / 2, z), O.Jitter(DARK, 0.06), "Wood")
		end
	end
	-- striped canvas canopy with a scalloped front edge
	for i = 0, 5 do
		local x = -4.6 + (i + 0.5) * 9.2 / 6
		local color = if i % 2 == 0 then colorA else colorB
		O.Stick(m, "Canopy", V(x, 8.85, -2.4), V(x, 7.55, 2.7), 9.2 / 6 + 0.02, 0.12, color, "Fabric", { CanCollide = false })
		O.Part(m, "CanopyFlap", V(9.2 / 6, 0.8, 0.1), CF(x, 7.1, 2.72), color, "Fabric", { CanCollide = false })
	end
	-- goods
	local fruit = { rgb(250, 150, 30), rgb(250, 214, 60), rgb(110, 190, 60), rgb(220, 50, 50), rgb(170, 70, 200) }
	if kind == "Fruit" then
		for i = 0, 2 do
			O.Basket(m, CF(-2.6 + i * 2.6, 3.15, 1.0), fruit)
		end
		for i = 0, 2 do
			O.Ball(m, "Coconut", V(4.9 + i * 0.3, 0.9 + (i % 2) * 0.8, -0.8 + i * 0.6), 1.0, rgb(110, 72, 40), "SmoothPlastic", { CanCollide = false })
		end
	elseif kind == "Fish" then
		for i = 0, 3 do
			O.Fish(m, CF(-3.0 + i * 2.0, 7.0, 1.9), O.Pick({ rgb(150, 170, 180), rgb(200, 150, 110), rgb(120, 150, 190) }))
		end
		O.Part(m, "IceBox", V(6, 0.6, 1.8), CF(0, 3.45, 1.0), rgb(196, 226, 236), "Glass", { Transparency = 0.2, CanCollide = false })
		for i = 0, 4 do
			O.Part(m, "Fish", V(1.4, 0.3, 0.6), CF(-2.4 + i * 1.2, 3.85, 1.0 + (i % 2) * 0.3) * Angles(0, 0.3 * i, 0), rgb(160, 176, 186), "SmoothPlastic", { CanCollide = false })
		end
	elseif kind == "Cloth" then
		for i = 0, 3 do
			O.Cloth(m, CF(-3 + i * 2, 3.15, 1.0) * Angles(0, PI / 2, 0), O.Pick({ rgb(180, 50, 60), rgb(50, 90, 170), rgb(230, 190, 60), rgb(70, 150, 90) }))
		end
		for i = 0, 2 do
			O.Part(m, "HangingCloth", V(1.5, 3.2, 0.1), CF(-2.5 + i * 2.5, 5.6, -1.7), O.Pick({ rgb(180, 50, 60), rgb(50, 90, 170), rgb(230, 190, 60) }), "Fabric", { CanCollide = false })
		end
	else -- bottles and jars
		for i = 0, 7 do
			O.Bottle(m, CF(-3.6 + i * 1.0, 3.15, 0.7 + (i % 2) * 0.5), O.Pick({ rgb(60, 120, 70), rgb(120, 60, 40), rgb(60, 80, 140), rgb(170, 130, 50) }))
		end
		O.Chest(m, CF(3.2, 3.15, 1.0), { Scale = 0.55, Gold = true })
	end
	O.Crate(m, CF(5.6, 0, 1.6) * Angles(0, 0.3, 0))
	O.Sack(m, CF(-5.5, 0, 1.2))
	O.Lantern(m, CF(-4.3, 7.4, 2.1), { Range = 12, Brightness = 1 })
	P.transform(m, cf)
	return m
end

-- The King statue on the square (keeps KingStatue.Plaque.PlaqueGui.Label for WorldService) --------------
-- A golden pirate captain on a stepped pedestal in an octagonal fountain. The figure is a shopkeeper
-- rig (long coat, tricorn, long beard) posed with a raised cutlass, scaled up and turned to gold.
local function goldenFigure(parent: any, cf: any, s: number)
	local gold, deep, bright = rgb(236, 178, 56), rgb(186, 128, 36), rgb(255, 214, 100)
	local fig, r = Rigs.Npc("Figure", {
		Skin = gold, Shirt = bright, Coat = gold, CoatTrim = bright, LongCoat = true, Vest = deep, Pants = deep,
		Boots = deep, Belt = deep, Buckle = bright, Sash = deep, Hat = "Tricorn", HatColor = gold, HatTrim = bright,
		Hair = deep, Beard = gold, BeardStyle = "Long", Mustache = bright, Cutlass = true, Earring = true,
	})
	-- pose: right arm raised high, left hand out to the hip
	local function swing(limb: any, pivot: any, rot: any)
		local moved = { limb }
		for _, d in fig:GetDescendants() do
			if d:IsA("Weld") and d.Part0 == limb then
				table.insert(moved, d.Part1)
			end
		end
		local t = pivot * rot * pivot:Inverse()
		for _, part in moved do
			part.CFrame = t * part.CFrame
		end
	end
	swing(r.RightArm, r.Torso.CFrame * CF(1, 0.5, 0), Angles(math.rad(-38), 0, math.rad(118)))
	swing(r.LeftArm, r.Torso.CFrame * CF(-1, 0.5, 0), Angles(0, 0, math.rad(-16)))
	-- the cutlass in the raised hand
	local grip = r.RightArm.CFrame * CF(0, -1.0, 0)
	P.part(fig, { Name = "Grip", Size = V(0.22, 0.7, 0.22), CFrame = grip, Color = deep })
	P.part(fig, { Name = "Guard", Size = V(0.24, 0.2, 0.95), CFrame = grip * CF(0, -0.42, 0), Color = bright })
	P.part(fig, { Name = "Blade", Size = V(0.14, 3.4, 0.46), CFrame = grip * CF(0, -2.2, 0.06) * Angles(math.rad(5), 0, 0), Color = rgb(250, 236, 190) })
	-- a statue: no humanoid, joints or face; a round golden head
	for _, d in fig:GetDescendants() do
		if d:IsA("Humanoid") or d:IsA("JointInstance") or d:IsA("Decal") or (d:IsA("SpecialMesh") and d.MeshType == P.Enum.MeshType.Head) then
			d:Destroy()
		end
	end
	r.HRP:Destroy()
	r.Head.Shape = P.Enum.PartType.Ball
	r.Head.Size = V(1.3, 1.3, 1.3)
	for _, part in P.descendantParts(fig) do
		if part.Transparency < 1 then
			local rel = part.CFrame
			part.Size = part.Size * s
			part.CFrame = CF(rel.Position * s) * (rel - rel.Position)
			part.Material = P.Enum.Material.Metal
			part.Reflectance = 0.12
			part.Anchored = true
			part.CanCollide = false
		else
			part:Destroy()
		end
	end
	P.transform(fig, cf)
	for _, part in P.descendantParts(fig) do
		part.Parent = parent
	end
	fig:Destroy()
end

local function statue(parent: any, x: number, y: number, z: number)
	local m = P.model(parent, "KingStatue")
	local stone = rgb(214, 204, 186)
	local stoneDark = rgb(166, 156, 140)
	local gold = rgb(255, 196, 64)
	-- octagonal fountain basin
	P.pillar(m, 0, 0, -1, 0.6, 21, { Name = "BasinFloor", Mat = "Cobblestone", Color = stoneDark })
	P.pillar(m, 0, 0, 0.6, 0.85, 20, { Name = "Water", Mat = "Glass", Color = rgb(40, 190, 200), Transparency = 0.25, CanCollide = false })
	for i = 0, 7 do
		local a = i * PI / 4
		O.Part(m, "BasinRim", V(9.2, 2.0, 1.6), CF(math.sin(a) * 10.6, 1.0, math.cos(a) * 10.6) * Angles(0, a, 0), O.Jitter(stone, 0.04), "Marble")
		O.Part(m, "BasinLip", V(9.6, 0.4, 2.0), CF(math.sin(a) * 10.6, 2.15, math.cos(a) * 10.6) * Angles(0, a, 0), stoneDark, "Marble")
	end
	-- stepped pedestal with corner columns and four spouting lion... er, fish heads
	O.Part(m, "Step", V(9, 1, 9), CF(0, 1.1, 0), stoneDark, "Marble")
	O.Part(m, "Pedestal", V(6.4, 6.4, 6.4), CF(0, 4.8, 0), stone, "Marble")
	O.Part(m, "PedestalBand", V(6.8, 0.5, 6.8), CF(0, 2.0, 0), stoneDark, "Marble")
	O.Part(m, "PedestalTop", V(7.6, 0.8, 7.6), CF(0, 8.3, 0), stoneDark, "Marble")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			P.pillar(m, sx * 3.25, sz * 3.25, 1.6, 8.0, 0.8, { Name = "Column", Mat = "Marble", Color = stoneDark })
		end
	end
	for i = 1, 3 do
		local a = i * PI / 2
		local spout = CF(0, 3.4, 0) * Angles(0, a, 0) * CF(0, 0, 3.55)
		O.Ball(m, "Spout", spout.Position, 1.0, gold, "Metal")
		O.CylZ(m, "SpoutPipe", spout * CF(0, 0, 0.5), 0.9, 0.42, gold, "Metal")
		O.Part(m, "Jet", V(0.35, 0.35, 2.8), spout * CF(0, -1.0, 1.9) * Angles(math.rad(-48), 0, 0), rgb(170, 230, 240), "Glass", { Transparency = 0.45, CanCollide = false, CanQuery = false })
	end
	local plaque = O.Part(m, "Plaque", V(5.2, 3.2, 0.3), CF(0, 4.8, 3.35), rgb(70, 50, 30), "Metal")
	O.Part(m, "PlaqueFrame", V(5.6, 3.6, 0.2), CF(0, 4.8, 3.25), gold, "Metal")
	P.surfaceText(plaque, "Back", "KING OF THE PIRATES\nNo king yet...", { Name = "PlaqueGui", Color = rgb(255, 214, 110), PixelsPerStud = 40 })
	-- the golden captain stands on a chest of gold, facing the road to the harbour (+Z)
	local top = 8.7
	O.Chest(m, CF(0, top, -0.6), { Scale = 0.9, Color = gold, Band = rgb(230, 170, 50), Gold = true })
	goldenFigure(m, CF(0, top, 0.9) * Angles(0, PI, 0), 1.85)
	local light = O.Part(m, "Spot", V(1, 1, 1), CF(0, 3, 9), rgb(0, 0, 0), "SmoothPlastic", { Transparency = 1, CanCollide = false, CanQuery = false })
	P.pointLight(light, rgb(255, 220, 160), 20, 1.4, false)
	P.transform(m, CF(x, y, z))
	return m
end

-- Lighthouse on the northern hill (keeps the part tagged LighthouseBeam) -----------------------------------
local function lighthouse(parent: any, x: number, y: number, z: number)
	local m = P.model(parent, "Lighthouse")
	local stone = rgb(150, 144, 134)
	-- rocky base and keeper's steps
	P.pillar(m, 0, 0, -6, 2.5, 19, { Name = "Base", Mat = "Cobblestone", Color = stone })
	P.pillar(m, 0, 0, 2.5, 3.2, 20, { Name = "BaseCap", Mat = "Slate", Color = rgb(120, 116, 108) })
	-- tapered tower, white and red bands
	local h = 3.2
	local sections = 8
	for i = 0, sections - 1 do
		local d = 12 - i * 0.6
		P.pillar(m, 0, 0, h + i * 4.4, h + (i + 1) * 4.4, d, { Name = "Tower", Mat = "Concrete", Color = if i % 2 == 0 then rgb(242, 238, 228) else rgb(196, 54, 46) })
	end
	local topY = h + sections * 4.4
	for i = 0, 2 do
		local wy = h + 7 + i * 10
		O.Part(m, "TowerWindow", V(1.4, 2.2, 0.4), CF(0, wy, 5.7 - (wy - h) / 4.4 * 0.3) , rgb(60, 40, 30), "Wood")
	end
	O.Door(m, CF(0, h, 5.85), 3.2, 5.6)
	-- wooden gallery with a railing
	P.pillar(m, 0, 0, topY, topY + 0.8, 14, { Name = "Gallery", Mat = "WoodPlanks", Color = rgb(120, 84, 54) })
	for i = 0, 15 do
		local a = i * PI / 8
		O.Part(m, "GalleryPost", V(0.35, 2.6, 0.35), CF(math.cos(a) * 6.6, topY + 2.1, math.sin(a) * 6.6), DARK, "Wood")
		O.Part(m, "GalleryRail", V(0.35, 0.35, 2.75), CF(math.cos(a + PI / 16) * 6.55, topY + 3.3, math.sin(a + PI / 16) * 6.55) * Angles(0, -(a + PI / 16), 0), DARK, "Wood")
	end
	for i = 0, 7 do
		local a = i * PI / 4
		O.Stick(m, "GalleryBrace", V(math.cos(a) * 4.9, topY - 3, math.sin(a) * 4.9), V(math.cos(a) * 6.6, topY, math.sin(a) * 6.6), 0.4, 0.4, DARK, "Wood", { CanCollide = false })
	end
	-- lamp room
	P.pillar(m, 0, 0, topY + 0.8, topY + 1.8, 7.4, { Name = "LampRoomBase", Mat = "Metal", Color = IRON })
	P.pillar(m, 0, 0, topY + 1.8, topY + 7, 6.8, { Name = "LampRoom", Mat = "Glass", Color = rgb(200, 240, 255), Transparency = 0.55 })
	for i = 0, 7 do
		local a = i * PI / 4
		O.Part(m, "LampFrame", V(0.3, 5.2, 0.3), CF(math.cos(a) * 3.4, topY + 4.4, math.sin(a) * 3.4), IRON, "Metal")
	end
	local lamp = O.Ball(m, "Lamp", V(0, topY + 4.2, 0), 3, rgb(255, 230, 150), "Neon")
	P.pointLight(lamp, rgb(255, 225, 160), 60, 2.5, false)
	-- red cone roof with a weathervane
	for i = 0, 4 do
		P.pillar(m, 0, 0, topY + 7 + i * 0.9, topY + 7.9 + i * 0.9, 8 - i * 1.7, { Name = "Roof", Mat = "Metal", Color = rgb(186, 50, 44) })
	end
	O.Ball(m, "RoofKnob", V(0, topY + 11.9, 0), 0.9, O.BRASS, "Metal")
	O.Part(m, "Vane", V(0.15, 2.6, 0.15), CF(0, topY + 13.2, 0), IRON, "Metal")
	O.Part(m, "VaneArrow", V(2.4, 0.15, 0.15), CF(0, topY + 13.8, 0), IRON, "Metal")
	O.Part(m, "VaneTail", V(0.1, 0.6, 0.9), CF(-1.1, topY + 13.8, 0) * Angles(0, PI / 2, 0), IRON, "Metal")
	local beam = O.Part(m, "Beam", V(3, 3, 220), CF(0, topY + 4.2, 0), rgb(255, 236, 170), "Neon", {
		Transparency = 0.86,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	beam:AddTag("LighthouseBeam")
	-- keeper's things around the base
	O.Barrel(m, CF(4.5, 3.2, 7.2))
	O.Crate(m, CF(-4.8, 3.2, 7.0) * Angles(0, 0.4, 0))
	O.RopeCoil(m, CF(6.6, 3.2, 4.4))
	P.transform(m, CF(x, y, z))
	return m
end

-- Piers ----------------------------------------------------------------------------------------------------
-- The pier deck (top y = Height) runs from MinZ to MaxZ like WorldData.Piers says; where the island
-- is higher than the deck (the landward end under the boardwalk and the grassy bank) the planks
-- climb over the ground as a ramp of cross boards, so the pier meets the boardwalk.

-- Height of the boardwalk along the harbour front (follows the ground)
local BOARDWALK_Z0, BOARDWALK_Z1 = 296, 306
local function boardwalkHeight(H: any, x: number): number
	local top = -math.huge
	for _, dx in { -3, 0, 3 } do
		for _, z in { BOARDWALK_Z0, (BOARDWALK_Z0 + BOARDWALK_Z1) / 2, BOARDWALK_Z1 } do
			top = math.max(top, (H.GetHeight(x + dx, z)))
		end
	end
	return math.max(top + 0.45, 5)
end

local function pier(parent: any, index: number, pd: { [string]: any }, H: any)
	O.Seed(4242 + index * 97)
	local pm = P.model(parent, "Pier" .. index)
	local x0, y = pd.X, pd.Height
	local hw = pd.HalfWidth
	local len = pd.MaxZ - pd.MinZ
	local midZ = (pd.MinZ + pd.MaxZ) / 2
	-- ground under the deck (highest point across the width)
	local function groundAt(z: number): number
		local top = -math.huge
		for _, dx in { -hw, 0, hw } do
			top = math.max(top, (H.GetHeight(x0 + dx, z)))
		end
		return top
	end
	-- where the bank drops below the deck
	local shoreZ = pd.MinZ
	for z = BOARDWALK_Z1, pd.MaxZ, 1 do
		if groundAt(z) < y - 0.35 then
			shoreZ = z
			break
		end
	end
	-- collision deck (WorldData geometry; the landward end is under the ground)
	O.Part(pm, "Deck", V(hw * 2, 1, len), CF(x0, y - 0.75, midZ), O.DARKER, "Wood")

	-- the ramp over the bank: cross boards from the boardwalk down to the deck
	local rampZ0 = BOARDWALK_Z1
	local yTop = boardwalkHeight(H, x0)
	local function rampY(z: number): number
		local t = math.clamp((z - rampZ0) / math.max(1, shoreZ - rampZ0), 0, 1)
		local lin = yTop + (y - yTop) * t
		return math.max(lin, groundAt(z) + 0.4, y)
	end
	local bz = rampZ0
	local bw = 1.5
	while bz < shoreZ do
		local zc = bz + bw / 2
		local ya, yb = rampY(bz), rampY(bz + bw)
		local tilt = math.atan2(ya - yb, bw)
		local yc = (ya + yb) / 2 - 0.15
		O.Part(pm, "RampBoard", V(hw * 2 - O.Range(0, 0.5), 0.3, bw - 0.14), CF(x0 + O.Range(-0.15, 0.15), yc, zc) * Angles(tilt, O.Range(-0.012, 0.012), 0), O.Jitter(O.Pick(O.WOOD), 0.08), "WoodPlanks")
		bz += bw
	end
	for _, side in { -1, 1 } do
		local px = x0 + side * (hw - 0.1)
		local za = rampZ0
		while za < shoreZ - 0.1 do
			local zb = math.min(shoreZ, za + 9)
			O.Stick(pm, "RampStringer", V(px, rampY(za) - 0.55, za), V(px, rampY(zb) - 0.55, zb), 0.6, 0.8, DARK, "Wood", { CanCollide = false })
			za = zb
		end
	end

	-- the deck over the water: lengthwise planks with staggered joints
	local strips = 6
	local sw = hw * 2 / strips
	for i = 0, strips - 1 do
		local px = x0 - hw + (i + 0.5) * sw
		local zpos = shoreZ - 0.6
		local first = true
		while zpos < pd.MaxZ - 0.5 do
			local l = if first then O.Range(14, 44) else O.Range(34, 52)
			first = false
			local z1 = math.min(pd.MaxZ, zpos + l)
			O.Part(pm, "Plank", V(sw - 0.12, 0.3, z1 - zpos - 0.12), CF(px, y - 0.15 - O.Range(0, 0.04), (zpos + z1) / 2), O.Jitter(O.Pick(O.WOOD), 0.07), "WoodPlanks")
			zpos = z1
		end
	end
	local wetLen = pd.MaxZ - shoreZ
	for _, side in { -1, 1 } do
		O.Part(pm, "Stringer", V(0.8, 1.2, wetLen), CF(x0 + side * (hw + 0.4), y - 0.75, shoreZ + wetLen / 2), DARK, "Wood")
	end
	-- pilings in pairs, sticking up as posts along the walkway section
	local railEnd = 412
	local pileZ = {}
	local zp = shoreZ + 3
	while zp <= pd.MaxZ - 1 do
		table.insert(pileZ, zp)
		zp += 18
	end
	table.insert(pileZ, pd.MaxZ - 0.8)
	for k, pz in pileZ do
		if k % 2 == 1 or k == #pileZ then
			O.Part(pm, "Joist", V(hw * 2 + 1.6, 0.9, 1.0), CF(x0, y - 1.8, pz), O.Jitter(DARK, 0.05), "Wood")
		end
		for _, side in { -1, 1 } do
			local px = x0 + side * (hw + 0.4)
			local ground = (H.GetHeight(px, pz))
			local postTop = if pz < railEnd then y + 3.2 else y + 1.2
			P.pillar(pm, px, pz, math.min(ground - 3, -26), postTop, 1.3, { Name = "Piling", Mat = "Wood", Color = O.Jitter(rgb(100, 74, 52), 0.08) })
		end
	end
	-- rope railing: posts on the ramp, then along the pilings to the first berth
	local railPosts = {}
	local rz = rampZ0 + 1
	while rz < shoreZ - 2 do
		table.insert(railPosts, { rz, rampY(rz) })
		rz += 8
	end
	for _, pz in pileZ do
		if pz <= railEnd then
			table.insert(railPosts, { pz, y })
		end
	end
	for k, rp in railPosts do
		for _, side in { -1, 1 } do
			local px = x0 + side * (hw + 0.4)
			if rp[1] < shoreZ then
				O.Part(pm, "RailPost", V(0.8, 3.6, 0.8), CF(px, rp[2] + 1.3, rp[1]), O.Jitter(rgb(100, 74, 52), 0.08), "Wood")
			end
			local nxt = railPosts[k + 1]
			if nxt then
				local topA = if rp[1] < shoreZ then rp[2] + 2.7 else y + 2.6
				local topB = if nxt[1] < shoreZ then nxt[2] + 2.7 else y + 2.6
				local a, b = V(px, topA, rp[1]), V(px, topB, nxt[1])
				local mid = (a + b) / 2 - V(0, 0.6, 0)
				O.Rod(pm, "Rope", a, mid, 0.2, O.ROPE, "Fabric", { CanCollide = false })
				O.Rod(pm, "Rope", mid, b, 0.2, O.ROPE, "Fabric", { CanCollide = false })
			end
		end
	end
	-- mooring bollards at the dock slots
	for _, bz2 in { 468, 532, 598, 662 } do
		for _, side in { -1, 1 } do
			O.Bollard(pm, CF(x0 + side * (hw - 0.9), y, bz2))
		end
	end
	-- lantern posts every ~70 studs, alternating sides
	local lz = shoreZ + 24
	local flip = 1
	while lz < pd.MaxZ - 20 do
		O.LanternPost(pm, CF(x0 + flip * (hw - 0.6), y, lz) * Angles(0, if flip > 0 then -PI / 2 else PI / 2, 0), 8, { Range = 18, Brightness = 1.2 })
		lz += 90
		flip = -flip
	end
	-- cargo near the landward end and between the berths
	local cz = shoreZ + 8
	O.Barrel(pm, CF(x0 - hw + 1.6, y, cz))
	O.Barrel(pm, CF(x0 - hw + 1.7, y, cz + 2.2), { Color = rgb(150, 100, 60) })
	O.Barrel(pm, CF(x0 - hw + 1.6, y, cz + 1.1) * CF(0, 2.6, 0), { Scale = 0.8 })
	O.Crate(pm, CF(x0 + hw - 1.8, y, cz + 6) * Angles(0, 0.4, 0))
	O.Crate(pm, CF(x0 + hw - 1.8, y + 2.4, cz + 6.2) * Angles(0, 0.1, 0), 1.8)
	O.Sack(pm, CF(x0 + hw - 1.6, y, cz + 9))
	O.RopeCoil(pm, CF(x0 - hw + 1.8, y, cz + 22))
	O.Net(pm, CF(x0 + hw - 0.3, y + 1.4, cz + 26) * Angles(0, PI / 2, math.rad(-8)), 4.6, 2.4)
	O.Crate(pm, CF(x0 - hw + 1.7, y, 565))
	O.Barrel(pm, CF(x0 + hw - 1.6, y, 560))
	O.RopeCoil(pm, CF(x0 + hw - 1.8, y, 570))
	-- the far end: a black flag and ladders down to the water
	O.FlagPole(pm, CF(x0, y, pd.MaxZ - 2), 16, rgb(20, 18, 22))
	local flagPart = pm:FindFirstChild("Flag")
	if flagPart then
		for _, face in { "Front", "Back" } do
			P.surfaceText(flagPart, face, "☠", { Color = rgb(240, 236, 226), StrokeTransparency = 1, PixelsPerStud = 20 })
		end
	end
	for _, spot in { { x0, pd.MaxZ + 1.0 }, { x0 + hw + 1.0, 565 }, { x0 - hw - 1.0, 565 } } do
		O.Part(pm, "Ladder", V(2, 10, 2), CF(spot[1], y - 5, spot[2]), rgb(110, 80, 54), "Wood", { Class = "TrussPart" })
	end
	return pm, shoreZ
end

-- Boardwalk along the harbour front (z 296..306): planks that follow the ground from the beach
-- trail in the west to the one in the east, crossing the main street and the pier heads.
-- "Boardwalk" itself is an invisible marker part spanning it; the planks are in BoardwalkDeck.
local function boardwalk(parent: any, H: any)
	O.Seed(777)
	local x0, x1 = -84, 84
	local z0, z1 = BOARDWALK_Z0, BOARDWALK_Z1
	-- smoothed height profile every 4 studs
	local prof = {}
	for x = x0, x1, 4 do
		prof[x] = boardwalkHeight(H, x)
	end
	local function hAt(x: number): number
		local xa = math.clamp(math.floor((x - x0) / 4) * 4 + x0, x0, x1 - 4)
		local t = (x - xa) / 4
		return prof[xa] + (prof[xa + 4] - prof[xa]) * t
	end
	local avg = 0
	for x = x0, x1, 4 do
		avg += prof[x]
	end
	avg /= (x1 - x0) / 4 + 1
	local bw = O.Part(parent, "Boardwalk", V(x1 - x0, 1, z1 - z0), CF(0, avg - 0.5, (z0 + z1) / 2), O.DARKER, "Wood", { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local m = P.model(parent, "BoardwalkDeck")
	local rows = 6
	local rw = (z1 - z0) / rows
	for i = 0, rows - 1 do
		local pz = z0 + (i + 0.5) * rw
		local x = x0 + O.Range(0, 6) * (i % 2)
		if x > x0 then
			local yA, yB = hAt(x0), hAt(x)
			O.Stick(m, "Plank", V(x0, yA - 0.15, pz), V(x - 0.1, yB - 0.15, pz), rw - 0.12, 0.3, O.Jitter(O.Pick(O.WOOD), 0.07), "WoodPlanks")
		end
		while x < x1 - 0.5 do
			local xb = math.min(x1, x + O.Range(14, 22))
			if x1 - xb < 4 then
				xb = x1
			end
			O.Stick(m, "Plank", V(x, hAt(x) - 0.15 - O.Range(0, 0.04), pz), V(xb - 0.1, hAt(xb) - 0.15, pz), rw - 0.12, 0.3, O.Jitter(O.Pick(O.WOOD), 0.07), "WoodPlanks")
			x = xb
		end
	end
	-- edge beams and posts on the seaward side
	local x = x0
	while x < x1 - 0.5 do
		local xb = math.min(x1, x + 21)
		for _, z in { z0 - 0.35, z1 + 0.35 } do
			O.Stick(m, "EdgeBeam", V(x, hAt(x) - 0.45, z), V(xb, hAt(xb) - 0.45, z), 0.6, 0.75, DARK, "Wood", { CanCollide = false })
		end
		x = xb
	end
	for px = x0 + 4, x1 - 4, 14 do
		if math.abs(math.abs(px) - 70) > 8 and math.abs(px) > 8 then
			local gz = z1 + 0.35
			local ground = (H.GetHeight(px, gz))
			P.pillar(m, px, gz, ground - 1, hAt(px) + 0.25, 0.9, { Name = "Post", Mat = "Wood", Color = O.Jitter(rgb(100, 74, 52), 0.08), CanCollide = false })
		end
	end
	return bw, hAt
end

-- Welcome arch over the road to the piers --------------------------------------------------------------------
local function welcomeArch(parent: any, x: number, y: number, z: number)
	local m = P.model(parent, "WelcomeArch")
	for _, side in { -1, 1 } do
		local px = side * 9.8
		P.pillar(m, px, 0, -1, 16.5, 1.9, { Name = "ArchPost", Mat = "Wood", Color = rgb(104, 72, 48) })
		P.pillar(m, px, 0, -0.5, 1.2, 3.2, { Name = "ArchFooting", Mat = "Cobblestone", Color = rgb(140, 132, 122) })
		for _, ry in { 3, 3.6, 11.5, 12.1 } do
			P.pillar(m, px, 0, ry, ry + 0.35, 2.05, { Name = "RopeWrap", Mat = "Fabric", Color = O.ROPE, CanCollide = false })
		end
		O.Stick(m, "ArchBrace", V(px, 10.6, 0), V(px - side * 3.4, 14.3, 0), 0.6, 0.6, DARK, "Wood", { CanCollide = false })
		local torch = O.Part(m, "TorchBowl", V(1.6, 0.8, 1.6), CF(px, 17.0, 0), IRON, "Metal")
		local fire = P.Instance.new("Fire")
		fire.Size = 3.5
		fire.Heat = 7
		fire.Parent = torch
		P.pointLight(torch, rgb(255, 160, 80), 22, 1.4, false)
	end
	P.beam(m, V(-11.6, 14.6, 0), V(11.6, 14.6, 0), 1.6, { Name = "ArchBeam", Mat = "Wood", Color = rgb(104, 72, 48) })
	P.beam(m, V(-10.6, 13.3, 0), V(10.6, 13.3, 0), 0.8, { Name = "ArchBeam", Mat = "Wood", Color = DARK })
	local sign = O.Sign(m, CF(0, 11.2, 0.1), 15, 3.2, "KINGSHAVEN", { TwoSided = true, Hang = 1.4, Color = rgb(92, 58, 36), PixelsPerStud = 26 })
	sign.Name = "ArchSign"
	-- skull and crossbones on top
	local bone = rgb(236, 230, 210)
	O.Ball(m, "Skull", V(0, 16.6, 0), 2.2, bone, "SmoothPlastic")
	O.Part(m, "Jaw", V(1.4, 0.7, 1.3), CF(0, 15.5, 0.25), bone, "SmoothPlastic")
	for _, ex in { -0.45, 0.45 } do
		O.Ball(m, "EyeSocket", V(ex, 16.7, 0.9), 0.62, rgb(30, 26, 24), "SmoothPlastic")
	end
	for _, a in { 35, -35 } do
		O.Part(m, "Bone", V(4.4, 0.5, 0.5), CF(0, 15.6, -0.4) * Angles(0, 0, math.rad(a)), bone, "SmoothPlastic")
		for _, s in { -1, 1 } do
			O.Ball(m, "BoneEnd", (CF(0, 15.6, -0.4) * Angles(0, 0, math.rad(a)) * CF(s * 2.2, 0, 0)).Position, 0.75, bone, "SmoothPlastic")
		end
	end
	-- banners hanging from the beam
	for _, side in { -1, 1 } do
		O.Part(m, "Banner", V(2.2, 5, 0.12), CF(side * 7.2, 11.3, 0.6), rgb(150, 30, 34), "Fabric", { CanCollide = false })
		O.Part(m, "BannerTrim", V(2.3, 0.3, 0.14), CF(side * 7.2, 8.9, 0.6), O.BRASS, "Fabric", { CanCollide = false })
		O.Lantern(m, CF(side * 4.6, 13.0, 0.9), { Range = 14, Brightness = 1.1 })
	end
	O.Bunting(m, V(-9.8, 13.0, -0.7), V(9.8, 13.0, -0.7), { rgb(206, 50, 48), rgb(250, 210, 70), rgb(40, 110, 170), rgb(250, 246, 236) }, 10, 1.4)
	P.transform(m, CF(x, y, z))
	return m
end

-- Lagoon outpost extras --------------------------------------------------------------------------------

-- A plank lookout deck on stilts at the edge of a rock ledge (front = +Z, out over the drop),
-- with a railing, a telescope, a flag and a lantern. The best view over the pool to the sea.
local function rimLookout(parent: any, x: number, z: number, yaw: number, H: any)
	O.Seed(8080)
	local m = P.model(parent, "RimLookout")
	local base = (H.GetHeight(x, z))
	local origin = CF(x, base, z) * Angles(0, yaw, 0)
	local function g(lx: number, lz: number): number
		local p = origin * V(lx, 0, lz)
		return (H.GetHeight(p.X, p.Z)) - base
	end
	local W, D = 14, 10
	local top = 0
	for lx = -W / 2, W / 2, 3.5 do
		top = math.max(top, g(lx, -D / 2), g(lx, 0))
	end
	local F = top + 0.7
	O.Stilts(m, -W / 2, W / 2, -D / 2, D / 2, F - 0.5, g, { Spacing = 7 })
	O.Deck(m, -W / 2, W / 2, -D / 2, D / 2, F, {})
	O.Railing(m, V(-W / 2 + 0.3, F, D / 2 - 0.3), V(W / 2 - 0.3, F, D / 2 - 0.3), { Height = 3.2 })
	O.Railing(m, V(-W / 2 + 0.3, F, -D / 2 + 2), V(-W / 2 + 0.3, F, D / 2 - 0.3), { Height = 3.2 })
	O.Railing(m, V(W / 2 - 0.3, F, -D / 2 + 2), V(W / 2 - 0.3, F, D / 2 - 0.3), { Height = 3.2 })
	-- a brass telescope on a tripod
	local tp = V(2.5, F, D / 2 - 2.2)
	for k = 0, 2 do
		local a = k * PI * 2 / 3 + 0.3
		O.Stick(m, "Tripod", tp + V(0, 3.4, 0), tp + V(math.cos(a) * 1.1, 0, math.sin(a) * 1.1), 0.22, 0.22, O.DARK, "Wood", { CanCollide = false })
	end
	local tube = CF(tp + V(0, 3.9, 0)) * Angles(math.rad(8), math.rad(-10), 0)
	O.CylZ(m, "Telescope", tube * CF(0, 0, 0.4), 3.2, 0.55, rgb(196, 150, 60), "Metal")
	O.CylZ(m, "Telescope", tube * CF(0, 0, 1.9), 1.0, 0.75, rgb(150, 110, 44), "Metal")
	O.FlagPole(m, CF(W / 2 - 1.2, F, -D / 2 + 1.2), 11, rgb(176, 40, 40), { Width = 3.6, Height = 2.2 })
	O.LanternPost(m, CF(-W / 2 + 1.2, F, -D / 2 + 1.2) * Angles(0, PI / 4, 0), 7.5, { Range = 16 })
	O.Barrel(m, CF(-W / 2 + 1.6, F, D / 2 - 1.8))
	O.Crate(m, CF(-W / 2 + 3.6, F, D / 2 - 1.6) * Angles(0, 0.3, 0), 1.8)
	P.transform(m, origin)
	return m
end

-- A small wooden rowboat (cf: centre of the bottom boards, bow towards -Z)
local function rowboat(m: any, boat: any)
	local hull = rgb(120, 82, 52)
	O.Part(m, "BoatBottom", V(3.0, 0.5, 9.0), boat * CF(0, 0, 0), O.DARK, "WoodPlanks")
	for _, sx in { -1, 1 } do
		O.Part(m, "BoatSide", V(0.4, 1.4, 9.4), boat * CF(sx * 1.6, 0.7, 0) * Angles(0, 0, sx * -0.3), hull, "WoodPlanks")
	end
	O.Part(m, "BoatBow", V(3.2, 1.4, 0.4), boat * CF(0, 0.7, -4.6) * Angles(0.3, 0, 0), hull, "WoodPlanks")
	O.Part(m, "BoatStern", V(3.2, 1.4, 0.4), boat * CF(0, 0.7, 4.6) * Angles(-0.2, 0, 0), hull, "WoodPlanks")
	O.Part(m, "BoatSeat", V(3.0, 0.3, 1.0), boat * CF(0, 1.0, 0.8), O.Jitter(rgb(150, 110, 72), 0.05), "WoodPlanks")
	O.Stick(m, "Oar", (boat * CF(-0.4, 1.3, -1.5)).Position, (boat * CF(0.8, 0.8, 3.2)).Position, 0.25, 0.25, rgb(170, 130, 86), "Wood", { CanCollide = false })
end

-- Harbour clutter on the quay: stacked cargo, barrels, sacks, a net rack and lantern posts
-- along the street up from the piers (cf positions are on the ground)
local function harbourClutter(parent: any, H: any)
	O.Seed(2468)
	local m = P.model(parent, "QuayCargo")
	local function at(x: number, z: number, yaw: number?): any
		return CF(x, (H.GetHeight(x, z)), z) * Angles(0, yaw or 0, 0)
	end
	-- cargo piles: { x, z, yaw, kind }
	local piles = {
		{ -22, 289, 0.2, "Barrels" },
		{ 23, 288, -0.3, "Crates" },
		{ -58, 289, 0.5, "Crates" },
		{ 50, 286, -0.2, "Barrels" },
		{ -27, 278, 0.1, "Sacks" },
		{ 100, 288, -0.4, "Crates" },
		{ -102, 288, 0.3, "Barrels" },
	}
	for _, p in piles do
		local cf = at(p[1], p[2], p[3])
		if p[4] == "Barrels" then
			O.Barrel(m, cf * CF(-1.2, 0, 0))
			O.Barrel(m, cf * CF(1.1, 0, 0.3), { Color = rgb(150, 100, 60) })
			O.Barrel(m, cf * CF(0, 0, -1.9), { Scale = 0.9 })
			O.Barrel(m, cf * CF(-0.1, 2.6, -0.4), { Scale = 0.8 })
			O.Crate(m, cf * CF(2.6, 0, -1.8) * Angles(0, 0.4, 0), 1.8)
		elseif p[4] == "Crates" then
			O.Crate(m, cf * CF(-1.3, 0, 0) * Angles(0, 0.1, 0), 2.4)
			O.Crate(m, cf * CF(1.3, 0, 0.2) * Angles(0, -0.2, 0), 2.2)
			O.Crate(m, cf * CF(-0.6, 2.4, 0) * Angles(0, 0.5, 0), 2.0)
			O.Sack(m, cf * CF(2.8, 0, 1.6))
			O.RopeCoil(m, cf * CF(-2.8, 0, 1.8))
		else
			O.Sack(m, cf * CF(-0.8, 0, 0))
			O.Sack(m, cf * CF(0.7, 0, 0.4))
			O.Sack(m, cf * CF(0, 1.2, 0.1))
			O.Barrel(m, cf * CF(2.2, 0, -0.6), { Scale = 0.85 })
		end
	end
	-- a net drying rack between two posts
	for _, spec in { { -62, 275, 0.3 }, { 62, 274, -0.3 } } do
		local cf = at(spec[1], spec[2], spec[3])
		for _, sx in { -3, 3 } do
			O.Part(m, "RackPost", V(0.5, 5.4, 0.5), cf * CF(sx, 2.2, 0), O.Jitter(O.DARK, 0.06), "Wood")
		end
		O.Part(m, "RackBar", V(6.8, 0.4, 0.4), cf * CF(0, 4.7, 0), O.DARK, "Wood")
		O.Net(m, cf * CF(0, 3.0, 0), 5.6, 3.2)
		O.Barrel(m, cf * CF(4.4, 0, 1.4), { Scale = 0.8 })
	end
	-- lantern posts lining the street from the arch to the plaza
	for _, spec in { { -8.5, 278, -PI / 2 }, { 8.5, 270, PI / 2 } } do
		O.LanternPost(m, at(spec[1], spec[2], spec[3]), 8, { Range = 18, Brightness = 1.2 })
	end
	return m
end

-- A wooden railing along the pool's rocky lip below the plaza (where the drop is high)
local function poolRail(parent: any, H: any, Pool: any)
	local m = P.model(parent, "PoolRail")
	local last = nil
	for deg = 38, 118, 8 do
		local a = math.rad(deg)
		local x = Pool.X + (Pool.Rx + 3.5) * math.cos(a)
		local z = Pool.Z + (Pool.Rz + 3.5) * math.sin(a)
		local h = (H.GetHeight(x, z))
		local p = V(x, h, z)
		if h > 3.5 then
			if last then
				O.Railing(m, last, p, { Height = 3, Spacing = 5, Rope = true })
			end
			last = p
		else
			last = nil
		end
	end
	return m
end

-- A little landing stage on the pool: stairs down the lip from the plaza and a floating plank
-- dock with a moored rowboat
local function poolDock(parent: any, H: any, Pool: any)
	O.Seed(1357)
	local m = P.model(parent, "PoolDock")
	local a = math.rad(64)
	local lip = V(Pool.X + (Pool.Rx + 4) * math.cos(a), 0, Pool.Z + (Pool.Rz + 4) * math.sin(a))
	local inward = V(Pool.X - lip.X, 0, Pool.Z - lip.Z).Unit
	local top = (H.GetHeight(lip.X, lip.Z))
	-- frame: +Z points into the pool
	local origin = P.CFrame.fromMatrix(V(lip.X, top, lip.Z), V(0, 1, 0):Cross(inward), V(0, 1, 0), inward)
	local deckY = 1.1
	local run = O.Stairs(m, CF(0, 0, 0), 4.5, top - deckY)
	-- the floating dock beyond the stairs
	local z0, z1 = run - 0.2, run + 12
	O.Deck(m, -3.5, 3.5, z0, z1, deckY - top, { AlongZ = true, MaxLen = 12 })
	for _, sx in { -3.2, 3.2 } do
		for _, sz in { z0 + 1, z1 - 1 } do
			P.pillar(m, sx, sz, -8 - top, deckY - top + 1.2, 0.9, { Name = "Piling", Mat = "Wood", Color = O.Jitter(rgb(100, 74, 52), 0.08) })
		end
	end
	O.Bollard(m, CF(2.6, deckY - top, z1 - 2))
	-- a rowboat moored alongside
	rowboat(m, CF(6.6, deckY - top - 1.0, (z0 + z1) / 2) * Angles(0, 0.06, 0))
	O.Lantern(m, CF(-3.2, deckY - top + 3.2, z1 - 1) , { Range = 14 })
	O.Part(m, "LanternPole", V(0.4, 3.4, 0.4), CF(-3.2, deckY - top + 1.6, z1 - 1), O.DARK, "Wood")
	P.transform(m, origin)
	return m, lip
end

-- The waterfront --------------------------------------------------------------------------------------
-- Clusters of cargo standing on the ground at (x, z): barrels, crates, sacks and rope
local function cargo(parent: any, H: any, x: number, z: number, yaw: number, kind: number)
	local m = P.model(parent, "Cargo")
	local cf = CF(x, (H.GetHeight(x, z)), z) * Angles(0, yaw, 0)
	local function at(lx: number, lz: number, a: number?)
		local p = cf * V(lx, 0, lz)
		return CF(p.X, (H.GetHeight(p.X, p.Z)) - 0.1, p.Z) * Angles(0, yaw + (a or 0), 0)
	end
	if kind == 1 then
		O.Barrel(m, at(0, 0))
		O.Barrel(m, at(2.1, 0.4), { Color = rgb(150, 100, 60) })
		O.Barrel(m, at(1.0, 1.9), { Lying = true })
		O.Crate(m, at(-2.4, 0.6, 0.3))
	elseif kind == 2 then
		O.Crate(m, at(0, 0, 0.2))
		O.Crate(m, at(2.5, 0.2, -0.1), 2.0)
		O.Crate(m, at(0.9, 0.1, 0.5) * CF(0, 2.4, 0), 1.6)
		O.Sack(m, at(-2.0, 1.0))
	else
		O.Barrel(m, at(0, 0), { Color = rgb(110, 76, 50) })
		O.Sack(m, at(1.8, 0.8))
		O.Crate(m, at(-1.9, 0.5, 0.6), 1.8)
		O.RopeCoil(m, at(1.2, -1.6))
	end
	return m
end

-- A net drying on a rack of two posts (cf: ground between the posts, the net in the XY plane)
local function netRack(parent: any, cf: any, w: number)
	for _, sx in { -w / 2, w / 2 } do
		O.Part(parent, "RackPost", V(0.5, 5.6, 0.5), cf * CF(sx, 2.3, 0) * Angles(0, 0, math.rad(O.Range(-3, 3))), O.Jitter(O.DARK, 0.06), "Wood")
	end
	O.Part(parent, "RackBar", V(w + 0.8, 0.4, 0.4), cf * CF(0, 4.9, 0), O.DARK, "Wood")
	O.Net(parent, cf * CF(0, 3.2, 0), w - 0.6, 3.2)
end

-- A cargo derrick on the quay edge: a mast with a boom swung out over the beach, a crate hanging
-- from the tackle and a winch at the foot (cf: foot of the mast, the boom reaches towards +Z)
local function derrick(parent: any, cf: any)
	local m = P.model(parent, "Derrick")
	local wood = rgb(112, 82, 56)
	O.Part(m, "DerrickBase", V(3.2, 0.6, 3.2), cf * CF(0, 0.3, 0), O.DARK, "Wood")
	O.Part(m, "DerrickMast", V(1.1, 13, 1.1), cf * CF(0, 6.5, 0), O.Jitter(wood, 0.05), "Wood")
	for _, sx in { -1, 1 } do
		O.Stick(m, "DerrickStrut", (cf * CF(sx * 2.6, 0.2, -1.8)).Position, (cf * CF(0, 5.5, 0)).Position, 0.45, 0.45, O.DARK, "Wood", { CanCollide = false })
	end
	local foot = (cf * CF(0, 2.6, 0.4)).Position
	local tip = (cf * CF(0.8, 10.6, 9.5)).Position
	O.Stick(m, "DerrickBoom", foot, tip, 0.6, 0.6, O.Jitter(wood, 0.05), "Wood", { CanCollide = false })
	O.Rod(m, "DerrickStay", (cf * CF(0, 12.8, 0)).Position, tip, 0.14, O.ROPE, "Fabric", { CanCollide = false })
	local hook = tip - V(0, 4.6, 0)
	O.Rod(m, "DerrickFall", tip, hook, 0.16, O.ROPE, "Fabric", { CanCollide = false })
	O.Crate(m, CF(hook - V(0, 2.2, 0)) * Angles(0, 0.5, 0), 2.0)
	O.CylZ(m, "Winch", cf * CF(0, 1.6, -1.4) * Angles(0, PI / 2, 0), 2.2, 1.1, O.DARK, "Wood", { CanCollide = false })
	O.Rod(m, "WinchRope", (cf * CF(0, 1.9, -1.2)).Position, foot + V(0, 0.4, 0), 0.14, O.ROPE, "Fabric", { CanCollide = false })
	return m
end

-- A little plank jetty running from the beach out over the shallows, a rowboat moored alongside
-- (x: centre line; from z0 on the beach out to z1)
local function dinghyDock(parent: any, H: any, x: number, z0: number, z1: number)
	O.Seed(2929)
	local m = P.model(parent, "DinghyDock")
	local y = math.max((H.GetHeight(x, z0)) + 0.5, 3.2)
	O.Deck(m, x - 2.2, x + 2.2, z0, z1, y, { AlongZ = true, MaxLen = 14 })
	local z = z0 + 1
	while z <= z1 do
		for _, sx in { -2.4, 2.4 } do
			local g = (H.GetHeight(x + sx, z))
			if g < y - 0.8 then
				P.pillar(m, x + sx, z, g - 3, y + (if z > z1 - 2 then 1.4 else 0.2), 0.9, { Name = "Piling", Mat = "Wood", Color = O.Jitter(rgb(100, 74, 52), 0.08) })
			end
		end
		z += 6
	end
	O.Bollard(m, CF(x + 1.4, y, z1 - 1.6))
	O.Part(m, "LanternPole", V(0.45, 5.2, 0.45), CF(x - 2.1, y + 2.4, z1 - 0.6), O.DARK, "Wood")
	O.Lantern(m, CF(x - 2.1, y + 4.8, z1 + 0.2), { Range = 16 })
	-- the rowboat, afloat on the lee side, tied off to the bollard
	local boat = CF(x + 4.6, -0.25, z1 - 7) * Angles(0, 0.05, 0)
	rowboat(m, boat)
	O.Rod(m, "MooringLine", V(x + 1.4, y + 1.2, z1 - 1.6), (boat * CF(0, 1.2, -4.2)).Position, 0.14, O.ROPE, "Fabric", { CanCollide = false })
	return m
end

-- The quay wall: a timber bulkhead along the front of the paved quay (WorldData.Quay) where the
-- harbour level drops to the beach, found on the terrain. Posts stand proud of the boarded face
-- under a heavy cap beam; steps lead down to the sand. Returns the model and the runs of wall.
local function quayWall(parent: any, H: any, World: any, steps: { { number } })
	O.Seed(6262)
	local m = P.model(parent, "QuayWall")
	local Q = World.Quay
	local zf = Q.Z + 2.0 -- the face of the wall
	local function topAt(x: number): number
		return (H.GetHeight(x, Q.Z - 1.5))
	end
	local function lowAt(x: number): number
		return math.min((H.GetHeight(x, zf + 0.8)), (H.GetHeight(x, zf + 2.5)) + 0.6)
	end
	local function inSteps(x: number): boolean
		for _, s in steps do
			if math.abs(x - s[1]) < s[2] / 2 + 0.4 then
				return true
			end
		end
		return false
	end
	-- runs of wall: wherever the quay drops more than a step to the beach
	local runs = {}
	local cur = nil
	for x = Q.MinX - Q.Blend, Q.MaxX + Q.Blend do
		local top = topAt(x)
		local ok = top > 4.5 and top - lowAt(x) > 1.4 and not inSteps(x)
		if ok then
			if not cur then
				cur = { x, x }
				table.insert(runs, cur)
			end
			cur[2] = x
		else
			cur = nil
		end
	end
	local wood = rgb(104, 76, 52)
	for _, run in runs do
		local xa, xb = run[1] - 0.4, run[2] + 0.4
		local len = xb - xa
		if len < 3 then
			continue
		end
		local pieces = math.max(1, math.floor(len / 8.5 + 0.5))
		local pl = len / pieces
		for k = 0, pieces - 1 do
			local x0, x1 = xa + k * pl, xa + (k + 1) * pl
			local xc = (x0 + x1) / 2
			local top = math.max(topAt(x0), topAt(xc), topAt(x1))
			local low = math.min(lowAt(x0), lowAt(xc), lowAt(x1)) - 0.8
			-- boards on the face, bottom up
			local rows = math.max(1, math.ceil((top - low) / 1.15))
			local bh = (top - low) / rows
			for r = 0, rows - 1 do
				O.Part(m, "QuayBoard", V(pl + 0.1, bh - 0.08, 0.8), CF(xc, low + (r + 0.5) * bh, zf - 0.2) * Angles(0, 0, math.rad(O.Range(-0.4, 0.4))), O.Jitter(O.Pick(O.WOOD), 0.06), "WoodPlanks")
			end
			-- the cap beam over the edge
			O.Part(m, "QuayCap", V(pl + 0.12, 0.8, 2.6), CF(xc, top + 0.1, zf - 1.1), O.Jitter(rgb(96, 68, 46), 0.05), "Wood")
		end
		-- posts proud of the face
		local posts = math.max(1, math.floor(len / 4.2 + 0.5))
		for k = 0, posts do
			local x = xa + len * k / posts
			local top = topAt(x)
			P.pillar(m, x, zf + 0.45, lowAt(x) - 2, top + 0.9, 1.15, { Name = "QuayPost", Mat = "Wood", Color = O.Jitter(wood, 0.07) })
		end
	end
	-- steps down to the beach
	for _, s in steps do
		local x, w = s[1], s[2]
		local top = topAt(x)
		local rise = top - (H.GetHeight(x, zf + 5))
		local run = (math.max(1, math.ceil(rise / 0.7) - 1) + 1) * 1.2
		rise = top - (H.GetHeight(x, zf + run)) + 0.2
		O.Part(m, "StepLanding", V(w + 0.6, 0.8, 2.6), CF(x, top + 0.1, zf - 1.1), O.Jitter(rgb(96, 68, 46), 0.05), "Wood")
		O.Stairs(m, CF(x, top, zf + 0.2), w, rise)
	end
	return m, runs, zf
end

-- The harbour front: the quay wall, life on the quay and on the beach below it
local function waterfront(parent: any, H: any, World: any, keep: (number, number, number) -> ())
	local m = P.model(parent, "Waterfront")
	local Q = World.Quay
	local steps = { { 0, 7.5 }, { -100, 5 }, { 102, 5 } }
	local _, _, zf = quayWall(m, H, World, steps)
	O.Seed(8181)
	local function at(x: number, z: number, yaw: number?): any
		return CF(x, (H.GetHeight(x, z)), z) * Angles(0, yaw or 0, 0)
	end
	-- the quay: bollards on the cap, lantern posts, a cargo derrick and stacked cargo
	for _, x in { -30, 16, 50, -106, 92 } do
		O.Bollard(m, CF(x, (H.GetHeight(x, Q.Z - 1.5)) + 0.5, zf - 1.1))
	end
	for _, spec in { { -18, 0.25 }, { 22, -0.25 }, { -92, 0.1 }, { 110, -0.1 } } do
		O.LanternPost(m, at(spec[1], Q.Z - 0.6, spec[2]), 8, { Range = 18, Brightness = 1.2 })
		keep(spec[1], Q.Z - 0.6, 2.5)
	end
	derrick(m, at(36, Q.Z - 1.8, 0.15))
	keep(36, Q.Z - 1.8, 4)
	for _, c in { { 52, 311, 0.3, 2 }, { -28, 311, -0.2, 1 }, { 89, 312, 0.5, 3 }, { -88, 312, -0.4, 2 }, { 18, 311.5, 0.1, 3 }, { -111, 312, 0.6, 1 }, { 113, 311.5, -0.3, 2 } } do
		cargo(m, H, c[1], c[2], c[3], c[4])
		keep(c[1], c[2], 4.5)
	end
	-- the beach: rowboats pulled up on the sand, one upturned on trestles for caulking, nets
	-- drying, a little jetty for the dinghies
	for _, b in { { 13, 325.5, -0.35 }, { 38, 327, 0.2 }, { -104, 326, 0.45 }, { 96, 326.5, -0.55 } } do
		rowboat(m, CF(b[1], (H.GetHeight(b[1], b[2])) + 0.12, b[2]) * Angles(0, b[3], 0) * Angles(0, 0, 0.12))
		keep(b[1], b[2], 5.5)
	end
	do
		local x, z = 110, 324
		local g = (H.GetHeight(x, z))
		for _, dz in { -2.6, 2.6 } do
			O.Sawhorse(m, CF(x, (H.GetHeight(x, z + dz)), z + dz))
		end
		rowboat(m, CF(x, g + 4.3, z) * Angles(0, 0.04, PI))
		O.Barrel(m, at(x + 3.2, z + 3.4), { Scale = 0.8, Color = rgb(70, 54, 40) })
		keep(x, z, 6)
	end
	netRack(m, at(-13, 323.5, 0.08), 6.4)
	netRack(m, at(78, 323, -0.2), 6)
	keep(-13, 323.5, 4.5)
	keep(78, 323, 4.5)
	O.RopeCoil(m, at(-8.5, 324.5))
	O.Anchor(m, at(60, 323.5, 0.6) * CF(0, 0.35, 0) * Angles(0, 0, PI / 2), 0.8)
	dinghyDock(m, H, -26, zf + 0.6, 346)
	keep(-26, 333, 7)
	return m
end

-- Returns the town model and a list of "keep clear" zones for palms/rocks: circles
-- { X, Z, R } and turned rectangles { X, Z, R, Hx, Hz, C, S } (see Nature.Blocked)
function Town.Build(parent: any, H: any, World: any)
	local town = P.model(parent, "Kingshaven")
	local clear = {}
	local function keep(x: number, z: number, r: number)
		table.insert(clear, { X = x, Z = z, R = r })
	end
	-- a rectangle around local (lx0..lx1, lz0..lz1) of a frame at (x, z) turned by yaw
	-- (solid = the footprint of a building: even the cliff rocks of the town bowl, which hug the
	-- cliff feet right behind the houses, keep out of it)
	local function keepRect(x: number, z: number, yaw: number, lx0: number, lx1: number, lz0: number, lz1: number, solid: boolean?)
		local c, s = math.cos(yaw), math.sin(yaw)
		local mx, mz = (lx0 + lx1) / 2, (lz0 + lz1) / 2
		local hx, hz = (lx1 - lx0) / 2, (lz1 - lz0) / 2
		table.insert(clear, { X = x + mx * c + mz * s, Z = z - mx * s + mz * c, R = math.sqrt(hx * hx + hz * hz), Hx = hx, Hz = hz, C = c, S = s, Solid = solid })
	end
	local function ground(x: number, z: number): number
		return (H.GetHeight(x, z))
	end
	local T = World.Town

	-- Shops: the building, its porch and stairs and the patch in front stay clear; the jungle
	-- grows right up to the side and back walls
	for _, shop in World.Shops do
		buildShop(town, shop, H)
		keepRect(shop.X, shop.Z, shop.Yaw, -shop.Width / 2 - 1.5, shop.Width / 2 + 1.5, -shop.Depth / 2 - 1.5, shop.Depth / 2 + 15)
		keepRect(shop.X, shop.Z, shop.Yaw, -shop.Width / 2 - 1, shop.Width / 2 + 1, -shop.Depth / 2 - 1, shop.Depth / 2 + 7, true)
		if shop.FrontX and shop.FrontZ then
			keep(shop.FrontX, shop.FrontZ, 6)
		end
	end

	-- The plaza: statue, market stalls round its edge -------------------------------------------------
	statue(town, T.X, ground(T.X, T.Z), T.Z)
	keep(T.X, T.Z, T.SquareRadius + 2)
	-- the stalls stand in a crescent on the far side of the statue: seen from the arch they are its
	-- backdrop, the gap between them keeps the view over the pool to the falls, and the sides of the
	-- plaza stay open towards the shop paths
	local stalls = {
		{ -10.3, 240.2, rgb(206, 56, 48), "Fruit" },
		{ 10.3, 240.2, rgb(40, 140, 190), "Fish" },
		{ -18.1, 248.4, rgb(230, 170, 40), "Cloth" },
		{ 18.1, 248.4, rgb(60, 150, 90), "Bottles" },
	}
	O.Seed(31337)
	for _, s in stalls do
		local yaw = math.atan2(T.X - s[1], T.Z - s[2])
		stall(town, CF(s[1], ground(s[1], s[2]), s[2]) * Angles(0, yaw, 0), s[3], rgb(244, 236, 220), s[4])
		keep(s[1], s[2], 6)
	end

	-- Sightlines: the walk from the arch to the statue, and from the plaza along the paths to the
	-- shops, stay open (no plants, rocks or props beside the street)
	local function keepLine(x1: number, z1: number, x2: number, z2: number, half: number)
		local dx, dz = x2 - x1, z2 - z1
		keepRect(x1, z1, math.atan2(dx, dz), -half, half, 0, math.sqrt(dx * dx + dz * dz))
	end
	keepLine(0, 300, 0, 262, 13)
	keepLine(10, 263, 50, 261, 7.5)
	keepLine(-10, 263, -54, 261, 7.5)

	-- Spawn: a compass rose on the street just south of the plaza --------------------------------------
	local sp = World.SpawnPoint
	local sy = ground(sp.X, sp.Z)
	local spawn = O.Part(town, "TownSpawn", V(10, 1, 10), CF(sp.X, sy - 0.3, sp.Z), rgb(196, 170, 120), "Cobblestone", { Class = "SpawnLocation" })
	spawn.Neutral = true
	spawn.Duration = 5
	O.Part(town, "Compass", V(0.2, 9, 9), CF(sp.X, sy + 0.25, sp.Z) * Angles(0, 0, PI / 2), rgb(120, 84, 54), "WoodPlanks", { Shape = "Cylinder", CanCollide = false })
	O.Part(town, "CompassRing", V(0.22, 7.6, 7.6), CF(sp.X, sy + 0.27, sp.Z) * Angles(0, 0, PI / 2), O.BRASS, "Metal", { Shape = "Cylinder", CanCollide = false })
	O.Part(town, "CompassFace", V(0.24, 7.0, 7.0), CF(sp.X, sy + 0.29, sp.Z) * Angles(0, 0, PI / 2), rgb(226, 206, 160), "SmoothPlastic", { Shape = "Cylinder", CanCollide = false })
	for i = 0, 3 do
		local col = if i % 2 == 0 then rgb(150, 40, 40) else rgb(40, 44, 60)
		O.Part(town, "CompassPoint", V(0.9, 0.3, 6.6), CF(sp.X, sy + 0.32, sp.Z) * Angles(0, i * PI / 4, 0) * Angles(0, PI / 4, 0), col, "SmoothPlastic", { CanCollide = false })
	end
	O.Ball(town, "CompassHub", V(sp.X, sy + 0.4, sp.Z), 0.8, O.BRASS, "Metal", { CanCollide = false })
	keep(sp.X, sp.Z, 8)

	-- Cottages tucked on the ledges between the shops ------------------------------------------------
	local cottages = {
		{ Name = "Cottage", X = -80, Z = 280, Yaw = 0.12, Roof = "Thatch", Walls = O.HONEY, Shutter = rgb(60, 120, 70), Props = "Washing" },
		{ Name = "Cottage", X = 82, Z = 279, Yaw = -0.12, Roof = "Shingle", RoofColors = O.RED_ROOF, Walls = O.DRIFT, Shutter = rgb(44, 110, 150), DoorX = 2.2, Chimney = true },
		{ Name = "Cottage", X = -100, Z = 250, Yaw = 0.6, Roof = "Shingle", RoofColors = O.SLATE, Walls = O.TEAL, Shutter = rgb(200, 150, 60), DoorX = -2.2, Props = "Fisher" },
		{ Name = "Cottage", X = 100, Z = 248, Yaw = -0.6, Roof = "Thatch", Walls = O.WOOD, Shutter = rgb(150, 50, 44), Props = "Washing" },
	}
	for _, c in cottages do
		cottage(town, c, H)
		keepRect(c.X, c.Z, c.Yaw, -7.5, 7.5, -6.5, 12, true)
	end

	-- Welcome arch on the street to the piers
	welcomeArch(town, 0, ground(0, 292), 292)
	keep(0, 292, 12)

	-- Piers and boardwalk ---------------------------------------------------------------------------------
	for pi, pd in World.Piers do
		pier(town, pi, pd, H)
	end
	boardwalk(town, H)
	-- keep the harbour front open: the boardwalk, the view from the piers to the arch, the pier heads
	for x = -84, 84, 12 do
		keep(x, 301, 9)
	end
	keep(0, 318, 16)
	for _, pd in World.Piers do
		keep(pd.X, 312, 11)
		keep(pd.X, 326, 11)
	end

	-- Cargo and nets on the quay, a railing along the pool's lip, a landing stage on the pool
	harbourClutter(town, H)
	for _, spot in { { -22, 289 }, { 23, 288 }, { -58, 289 }, { 50, 286 }, { -27, 278 }, { 100, 288 }, { -102, 288 }, { -62, 275 }, { 62, 274 } } do
		keep(spot[1], spot[2], 5)
	end
	-- the waterfront: the quay wall, cargo, the derrick, boats and nets on the beach, the jetty
	waterfront(town, H, World, keep)
	poolRail(town, H, World.Pool)
	local _, lip = poolDock(town, H, World.Pool)
	keep(lip.X, lip.Z, 6)

	-- A lookout deck on the rim beside the lighthouse trail: the view over the falls, the pool
	-- and the town to the sea (the trees in front of it stay low)
	rimLookout(town, -6, 110, 0, H)
	keep(-6, 110, 11)
	for _, spot in { { 2, 122, 9 }, { 0, 136, 9 }, { -2, 150, 8 }, { 4, 98, 7 }, { -16, 124, 7 }, { 22, 124, 7 } } do
		keep(spot[1], spot[2], spot[3])
	end

	-- A campfire on the high eastern ledge, a vegetable garden behind the shipwright
	campfire(town, 60, 128, H)
	keep(60, 128, 9)
	garden(town, 92, 226, -0.4, H)
	keepRect(92, 226, -0.4, -9, 9, -7, 7, true)

	-- A lookout tower on the eastern headland, over the harbour
	watchtower(town, 150, 270, -0.3, H)
	keep(150, 270, 9)

	-- Lighthouse on the northern hill
	local lh = World.Lighthouse
	lighthouse(town, lh.X, ground(lh.X, lh.Z), lh.Z)
	keep(lh.X, lh.Z, 22)

	return town, clear
end

return Town
