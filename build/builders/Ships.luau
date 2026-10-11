-- Builds the ship templates (ServerStorage.Ships.*).
-- Ship space: origin at the waterline centre, bow towards -Z, starboard towards +X.
-- Every part is welded (classic Weld) to the invisible "Root" part. Moving parts
-- (wheel, sails, cannon barrels, anchor) hang off named Welds the server animates.
local P = require("./Parts")

local V = P.Vector3.new
local CF = P.CFrame.new
local Angles = P.CFrame.Angles
local rgb = P.rgb

local Ships = {}

local STYLES = {
	Sloop = {
		DeckY = 3,
		Bottom = -4,
		BowLen = 12,
		CastleLen = 11,
		CastleH = 3.5,
		RailH = 2.6,
		Masts = { { Z = -3, Height = 34, SailW = 18, SailH = 19, Main = true } },
		Cannons = { { Z = 0, Side = 1 }, { Z = 5, Side = -1 } },
		Holes = 6,
		Hull = rgb(124, 82, 50),
		BottomColor = rgb(58, 52, 50),
		Stripe = rgb(32, 26, 22),
		Trim = rgb(222, 176, 70),
		Deck = rgb(188, 140, 92),
		Rail = rgb(98, 62, 38),
		Sail = rgb(246, 238, 218),
		Emblem = rgb(36, 28, 24),
		Flag = rgb(24, 22, 24),
	},
	Brigantine = {
		DeckY = 3.2,
		Bottom = -4.5,
		BowLen = 15,
		CastleLen = 15,
		CastleH = 4,
		RailH = 2.6,
		Masts = {
			{ Z = -10, Height = 40, SailW = 22, SailH = 22, Main = true },
			{ Z = 6, Height = 35, SailW = 20, SailH = 19 },
		},
		Cannons = { { Z = -4, Side = 1 }, { Z = -4, Side = -1 }, { Z = 4, Side = 1 }, { Z = 4, Side = -1 } },
		Holes = 8,
		Hull = rgb(94, 60, 40),
		BottomColor = rgb(52, 46, 44),
		Stripe = rgb(170, 44, 38),
		Trim = rgb(232, 186, 76),
		Deck = rgb(176, 128, 84),
		Rail = rgb(80, 50, 32),
		Sail = rgb(232, 214, 176),
		Emblem = rgb(150, 34, 30),
		Flag = rgb(150, 30, 28),
	},
	Galleon = {
		DeckY = 3.6,
		Bottom = -5,
		BowLen = 18,
		CastleLen = 20,
		CastleH = 4.5,
		RailH = 2.8,
		Masts = {
			{ Z = -18, Height = 44, SailW = 28, SailH = 24 },
			{ Z = 0, Height = 52, SailW = 32, SailH = 29, Main = true },
			{ Z = 14, Height = 42, SailW = 26, SailH = 22 },
		},
		Cannons = {
			{ Z = -18, Side = 1 },
			{ Z = -18, Side = -1 },
			{ Z = -8, Side = 1 },
			{ Z = -8, Side = -1 },
			{ Z = 3, Side = 1 },
			{ Z = 3, Side = -1 },
			{ Z = 11, Side = 1 },
			{ Z = 11, Side = -1 },
		},
		Holes = 10,
		Hull = rgb(60, 42, 32),
		BottomColor = rgb(40, 36, 36),
		Stripe = rgb(214, 170, 64),
		Trim = rgb(238, 194, 84),
		Deck = rgb(164, 118, 78),
		Rail = rgb(48, 32, 24),
		Sail = rgb(42, 40, 46),
		Emblem = rgb(240, 236, 226),
		Flag = rgb(20, 18, 22),
	},
}
Ships.Styles = STYLES

local WOOD = rgb(112, 76, 46)
local ROPE = rgb(64, 50, 36)
local IRON = rgb(40, 40, 44)

local function buildCannon(parent: any, style: any)
	local m = P.model(parent, "Cannon")
	local carriage = P.part(m, { Name = "Carriage", Size = V(2.2, 0.9, 3.0), CFrame = CF(0, 0.85, 0.2), Mat = "WoodPlanks", Color = rgb(112, 74, 44) })
	for _, x in { -1.2, 1.2 } do
		for _, z in { -0.9, 1.2 } do
			P.part(m, { Name = "Wheel", Shape = "Cylinder", Size = V(0.35, 0.9, 0.9), CFrame = CF(x, 0.45, z), Mat = "Wood", Color = rgb(78, 52, 30) })
		end
	end
	local pivotCF = CF(0, 1.75, -0.3)
	local pivot = P.part(m, { Name = "Pivot", Size = V(0.3, 0.3, 0.3), CFrame = pivotCF, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local barrelParts = {
		P.part(m, { Name = "Barrel", Shape = "Cylinder", Size = V(3.8, 0.95, 0.95), CFrame = pivotCF * CF(0, 0, -1.2) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = IRON }),
		P.part(m, { Name = "Muzzle", Shape = "Cylinder", Size = V(0.35, 1.25, 1.25), CFrame = pivotCF * CF(0, 0, -3.0) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = IRON }),
		P.part(m, { Name = "Breech", Shape = "Ball", Size = V(0.8, 0.8, 0.8), CFrame = pivotCF * CF(0, 0, 0.85), Mat = "Metal", Color = IRON }),
		P.part(m, { Name = "Band", Shape = "Cylinder", Size = V(0.25, 1.12, 1.12), CFrame = pivotCF * CF(0, 0, -0.1) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = style.Trim }),
	}
	for _, part in barrelParts do
		P.weld(pivot, part)
	end
	P.weld(carriage, pivot, "AimWeld")
	pivot:SetAttribute("MuzzleOffset", 3.2)
	P.attachment(carriage, "OperatorPoint", CF(0, 0, 3.3))
	P.attachment(pivot, "Muzzle", pivotCF * CF(0, 0, -3.2))
	P.prompt(carriage, { Name = "CannonPrompt", ActionText = "Use Cannon", ObjectText = "Cannon", MaxActivationDistance = 7 })
	return m
end

function Ships.Build(id: string, def: any)
	local s = STYLES[id]
	local L, W = def.Length, def.Width
	local model = P.model(nil, id)

	local zBow = -L / 2 + s.BowLen -- where the pointed bow begins
	local zStern = L / 2
	local zCastle = zStern - s.CastleLen
	local deckTop = s.DeckY + 0.3
	local castleTop = s.DeckY + s.CastleH + 0.3
	local railTop = s.DeckY + s.RailH

	local root = P.part(model, {
		Name = "Root",
		Size = V(W * 0.6, 1, L * 0.6),
		CFrame = CF(0, 0, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	model.PrimaryPart = root

	local hull = P.folder(model, "Hull")
	local fittings = P.folder(model, "Fittings")
	local rigging = P.folder(model, "Rigging")
	local cannons = P.folder(model, "Cannons")
	P.folder(model, "Cargo")
	P.folder(model, "Holes")

	-- Hull: layered so the painted stripe runs around the bow as well
	local layers = {
		{ s.Bottom, -0.4, s.BottomColor },
		{ -0.4, s.DeckY - 1.55, s.Hull },
		{ s.DeckY - 1.55, s.DeckY - 0.85, s.Stripe },
		{ s.DeckY - 0.85, s.DeckY, s.Hull },
	}
	for _, layer in layers do
		local y0, y1, color = layer[1], layer[2], layer[3]
		-- the hull below the waterline is visual only, so it can never wedge against the seabed
		local solid = y1 > -0.3
		P.part(hull, { Name = "HullSide", Size = V(W, y1 - y0, zStern - zBow), CFrame = CF(0, (y0 + y1) / 2, (zBow + zStern) / 2), Mat = "WoodPlanks", Color = color, CanCollide = solid })
		for _, side in { -1, 1 } do
			P.bowWedge(hull, side, W / 2, s.BowLen, zBow, y0, y1, { Name = "Bow", Mat = "WoodPlanks", Color = color, CanCollide = solid })
		end
	end
	-- gold trim line
	P.part(hull, { Name = "Trim", Size = V(W + 0.16, 0.22, zStern - zBow), CFrame = CF(0, s.DeckY - 0.3, (zBow + zStern) / 2), Mat = "Metal", Color = s.Trim })
	for _, side in { -1, 1 } do
		P.plank(hull, V(side * (W / 2 + 0.05), s.DeckY - 0.3, zBow), V(0, s.DeckY - 0.3, -L / 2), 0.16, 0.22, { Name = "Trim", Mat = "Metal", Color = s.Trim })
	end
	-- keel + rudder
	P.part(hull, { Name = "Keel", Size = V(W * 0.35, 1.4, L * 0.78), CFrame = CF(0, s.Bottom - 0.5, s.BowLen * 0.25), Mat = "WoodPlanks", Color = s.BottomColor, CanCollide = false })
	P.part(hull, { Name = "Rudder", Size = V(0.6, 6, 3), CFrame = CF(0, s.Bottom + 2.6, zStern + 1.3), Mat = "WoodPlanks", Color = s.BottomColor, CanCollide = false })

	-- Decks
	P.part(hull, { Name = "Deck", Size = V(W - 1.6, 0.3, zCastle - zBow + 0.2), CFrame = CF(0, s.DeckY + 0.15, (zBow + zCastle) / 2), Mat = "WoodPlanks", Color = s.Deck })
	local inset = (W / 2 - 0.8) / (W / 2)
	for _, side in { -1, 1 } do
		P.bowWedge(hull, side, W / 2 - 0.8, s.BowLen * inset, zBow, s.DeckY, s.DeckY + 0.3, { Name = "Deck", Mat = "WoodPlanks", Color = s.Deck })
	end

	-- Bulwarks (railings) around the main deck and bow
	for _, side in { -1, 1 } do
		P.part(hull, { Name = "Bulwark", Size = V(0.8, s.RailH, zCastle - zBow), CFrame = CF(side * (W / 2 - 0.4), s.DeckY + s.RailH / 2, (zBow + zCastle) / 2), Mat = "WoodPlanks", Color = s.Rail })
		P.part(hull, { Name = "RailCap", Size = V(1.1, 0.3, zCastle - zBow), CFrame = CF(side * (W / 2 - 0.4), railTop + 0.15, (zBow + zCastle) / 2), Mat = "Wood", Color = s.Trim })
		local a = V(side * (W / 2 - 0.4), s.DeckY + s.RailH / 2, zBow)
		local b = V(0, s.DeckY + s.RailH / 2, -L / 2 + 0.7)
		P.plank(hull, a, b, 0.8, s.RailH, { Name = "Bulwark", Mat = "WoodPlanks", Color = s.Rail })
		P.plank(hull, a + V(0, s.RailH / 2 + 0.15, 0), b + V(0, s.RailH / 2 + 0.15, 0), 1.1, 0.3, { Name = "RailCap", Mat = "Wood", Color = s.Trim })
	end

	-- Stern castle (raised quarterdeck with the helm)
	P.part(hull, { Name = "Castle", Size = V(W, s.CastleH, s.CastleLen), CFrame = CF(0, s.DeckY + s.CastleH / 2, (zCastle + zStern) / 2), Mat = "WoodPlanks", Color = s.Hull })
	P.part(hull, { Name = "CastleDeck", Size = V(W - 1.6, 0.3, s.CastleLen - 0.8), CFrame = CF(0, s.DeckY + s.CastleH + 0.15, (zCastle + zStern) / 2 - 0.4), Mat = "WoodPlanks", Color = s.Deck })
	P.part(hull, { Name = "Trim", Size = V(W, 0.25, 0.2), CFrame = CF(0, s.DeckY + s.CastleH - 0.15, zCastle - 0.05), Mat = "Metal", Color = s.Trim })
	for _, side in { -1, 1 } do
		P.part(hull, { Name = "Bulwark", Size = V(0.8, s.RailH, s.CastleLen), CFrame = CF(side * (W / 2 - 0.4), s.DeckY + s.CastleH + s.RailH / 2, (zCastle + zStern) / 2), Mat = "WoodPlanks", Color = s.Rail })
		P.part(hull, { Name = "RailCap", Size = V(1.1, 0.3, s.CastleLen), CFrame = CF(side * (W / 2 - 0.4), s.DeckY + s.CastleH + s.RailH + 0.15, (zCastle + zStern) / 2), Mat = "Wood", Color = s.Trim })
		-- front railing of the castle, leaving a gap for the stairs
		local inner, outer = 3.0, W / 2 - 0.8
		P.part(hull, { Name = "Railing", Size = V(outer - inner, 0.3, 0.3), CFrame = CF(side * (inner + outer) / 2, castleTop + 1.4, zCastle + 0.2), Mat = "Wood", Color = s.Trim })
		for x = inner, outer, 1.6 do
			P.part(hull, { Name = "Baluster", Size = V(0.25, 1.4, 0.25), CFrame = CF(side * x, castleTop + 0.7, zCastle + 0.2), Mat = "Wood", Color = s.Rail })
		end
	end
	P.part(hull, { Name = "Bulwark", Size = V(W, s.RailH, 0.8), CFrame = CF(0, s.DeckY + s.CastleH + s.RailH / 2, zStern - 0.4), Mat = "WoodPlanks", Color = s.Rail })
	P.part(hull, { Name = "RailCap", Size = V(W, 0.3, 1.1), CFrame = CF(0, s.DeckY + s.CastleH + s.RailH + 0.15, zStern - 0.4), Mat = "Wood", Color = s.Trim })
	-- stairs up to the castle
	local stairLen = s.CastleH * 1.7
	P.part(hull, { Class = "WedgePart", Name = "Stairs", Size = V(4.6, s.CastleH, stairLen), CFrame = CF(0, deckTop + s.CastleH / 2, zCastle - stairLen / 2), Mat = "WoodPlanks", Color = s.Deck })
	-- glowing stern windows
	for i = -1, 1 do
		local x = i * W * 0.26
		P.part(hull, { Name = "WindowFrame", Size = V(2.3, 2.1, 0.3), CFrame = CF(x, s.DeckY + s.CastleH * 0.5, zStern + 0.15), Mat = "Metal", Color = s.Trim })
		P.part(hull, { Name = "Window", Size = V(1.8, 1.6, 0.3), CFrame = CF(x, s.DeckY + s.CastleH * 0.5, zStern + 0.25), Mat = "Neon", Color = rgb(255, 186, 96), Transparency = 0.15, CanCollide = false })
	end
	-- stern lanterns
	for _, side in { -1, 1 } do
		local base = V(side * (W / 2 - 0.5), s.DeckY + s.CastleH + s.RailH + 0.3, zStern - 0.5)
		P.pillar(fittings, base.X, base.Z, base.Y, base.Y + 1.2, 0.3, { Name = "LanternPost", Mat = "Metal", Color = IRON, CanCollide = false })
		local lantern = P.part(fittings, { Name = "Lantern", Size = V(0.9, 1.2, 0.9), CFrame = CF(base.X, base.Y + 1.8, base.Z), Mat = "Neon", Color = rgb(255, 196, 110), CanCollide = false })
		P.part(fittings, { Name = "LanternCap", Size = V(1.1, 0.25, 1.1), CFrame = CF(base.X, base.Y + 2.5, base.Z), Mat = "Metal", Color = IRON, CanCollide = false })
		P.pointLight(lantern, rgb(255, 190, 110), 18, 1.6, false)
	end

	-- Bowsprit + figurehead
	local bowTip = V(0, s.DeckY + 1.0, -L / 2 + 0.6)
	local spritLen = s.BowLen * 0.8
	local spritEnd = bowTip + V(0, math.sin(math.rad(16)) * spritLen, -math.cos(math.rad(16)) * spritLen)
	P.beam(fittings, bowTip, spritEnd, 0.9, { Name = "Bowsprit", Mat = "Wood", Color = WOOD })
	P.part(fittings, { Name = "Figurehead", Shape = "Ball", Size = V(1.3, 1.3, 1.3), CFrame = CF(0, s.DeckY - 0.6, -L / 2 + 0.3), Mat = "Metal", Color = s.Trim, Reflectance = 0.2 })

	-- Helm (ship's wheel). WheelHub hangs off "WheelWeld" which the server rotates.
	local zWheel = zCastle + 3.2
	local post = P.part(fittings, { Name = "HelmPost", Size = V(1.2, 3.0, 1.2), CFrame = CF(0, castleTop + 1.5, zWheel), Mat = "Wood", Color = s.Rail })
	P.part(fittings, { Name = "Axle", Shape = "Cylinder", Size = V(1.4, 0.5, 0.5), CFrame = CF(0, castleTop + 3.6, zWheel + 0.4) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = s.Trim })
	local hubCF = CF(0, castleTop + 3.6, zWheel + 1.0)
	local wheelModel = P.model(fittings, "Wheel")
	local hub = P.part(wheelModel, { Name = "WheelHub", Size = V(0.4, 0.4, 0.4), CFrame = hubCF, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local wheelParts = {}
	table.insert(wheelParts, P.part(wheelModel, { Name = "HubCap", Shape = "Cylinder", Size = V(0.6, 1.0, 1.0), CFrame = hubCF * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = s.Trim }))
	local R = 2.3
	for i = 0, 11 do
		local phi = i * math.pi * 2 / 12
		table.insert(wheelParts, P.part(wheelModel, { Name = "Rim", Size = V(2 * R * math.sin(math.pi / 12) + 0.15, 0.32, 0.32), CFrame = hubCF * Angles(0, 0, phi) * CF(0, R, 0), Mat = "Wood", Color = rgb(140, 92, 52) }))
	end
	for k = 0, 5 do
		table.insert(wheelParts, P.part(wheelModel, { Name = "Spoke", Size = V(0.22, 2 * R + 1.6, 0.22), CFrame = hubCF * Angles(0, 0, k * math.pi / 6), Mat = "Wood", Color = rgb(150, 100, 58) }))
	end
	for _, part in wheelParts do
		part.CanCollide = false
		P.weld(hub, part)
	end
	P.weld(post, hub, "WheelWeld")
	P.prompt(post, { Name = "HelmPrompt", ActionText = "Take the Helm", ObjectText = "Ship's Wheel", MaxActivationDistance = 8 })
	P.attachment(root, "HelmPoint", CF(0, castleTop, zWheel + 3.1))

	-- Masts, yards and sails
	local mainMastTop = 0
	for _, m in s.Masts do
		local mastD = if L > 70 then 2.0 else 1.6
		local top = deckTop + m.Height
		mainMastTop = math.max(mainMastTop, top)
		P.pillar(rigging, 0, m.Z, s.DeckY, top, mastD, { Name = "Mast", Mat = "Wood", Color = WOOD })
		local base = P.part(rigging, { Name = "MastBase", Size = V(mastD + 1.2, 1.2, mastD + 1.2), CFrame = CF(0, deckTop + 0.6, m.Z), Mat = "WoodPlanks", Color = s.Rail })
		P.prompt(base, { Name = "SailPrompt", ActionText = "Lower Sails", ObjectText = "Sails", HoldDuration = 0.4, MaxActivationDistance = 8 })
		P.part(rigging, { Name = "Masthead", Shape = "Ball", Size = V(mastD + 0.4, mastD + 0.4, mastD + 0.4), CFrame = CF(0, top, m.Z), Mat = "Metal", Color = s.Trim })

		local yardY = deckTop + m.Height * 0.72
		local topY = top - 3
		local yards = {
			{ Y = yardY, Width = m.SailW, Height = m.SailH, Main = m.Main },
			{ Y = topY, Width = m.SailW * 0.62, Height = topY - yardY - 1.2, Main = false },
		}
		for _, y in yards do
			local yard = P.part(rigging, { Name = "Yard", Shape = "Cylinder", Size = V(y.Width + 2.4, 0.7, 0.7), CFrame = CF(0, y.Y, m.Z - 0.9), Mat = "Wood", Color = WOOD })
			local sail = P.part(rigging, {
				Name = "Sail",
				Size = V(y.Width, y.Height, 0.3),
				CFrame = CF(0, y.Y - 0.5 - y.Height / 2, m.Z - 1.4),
				Mat = "Fabric",
				Color = s.Sail,
				CanCollide = false,
				CanQuery = true,
			})
			sail:SetAttribute("FullHeight", y.Height)
			sail:SetAttribute("Gap", 0.5)
			sail:SetAttribute("ZOffset", -0.5)
			P.weld(yard, sail, "SailWeld")
			if y.Main then
				for _, face in { "Front", "Back" } do
					P.surfaceText(sail, face, "☠️", { Name = "Emblem", Color = s.Emblem, StrokeTransparency = 1, PixelsPerStud = 12, Padding = 0.12 })
				end
			end
		end

		-- flag
		P.pillar(rigging, 0, m.Z, top, top + 3.2, 0.3, { Name = "FlagPole", Mat = "Wood", Color = WOOD, CanCollide = false })
		local flag = P.part(rigging, { Name = "Flag", Size = V(0.15, 2.6, 4), CFrame = CF(0, top + 1.9, m.Z + 2.1), Mat = "Fabric", Color = s.Flag, CanCollide = false })
		for _, face in { "Left", "Right" } do
			P.surfaceText(flag, face, "☠️", { Name = "Emblem", Color = rgb(240, 236, 226), StrokeTransparency = 1, PixelsPerStud = 20, Padding = 0.1 })
		end

		-- shrouds
		for _, side in { -1, 1 } do
			for _, dz in { -2.5, 2.5 } do
				P.beam(rigging, V(0, top - 2, m.Z), V(side * (W / 2 - 0.4), railTop + 0.3, m.Z + dz + 2), 0.15, { Name = "Rope", Mat = "Fabric", Color = ROPE, CanCollide = false, CanQuery = false, CastShadow = false })
			end
		end
	end
	-- fore stay from the bowsprit to the first mast
	local first = s.Masts[1]
	P.beam(rigging, spritEnd, V(0, deckTop + first.Height - 1, first.Z), 0.18, { Name = "Rope", Mat = "Fabric", Color = ROPE, CanCollide = false, CanQuery = false, CastShadow = false })

	-- Capstan (anchor control) and the anchor itself
	local zCap = zBow + 3.5
	local capstan = P.pillar(fittings, 0, zCap, deckTop, deckTop + 2.2, 2.2, { Name = "Capstan", Mat = "Wood", Color = rgb(126, 84, 50) })
	P.pillar(fittings, 0, zCap, deckTop + 2.2, deckTop + 2.5, 2.7, { Name = "CapstanTop", Mat = "Metal", Color = s.Trim })
	for i = 0, 1 do
		P.part(fittings, { Name = "CapstanBar", Size = V(4.4, 0.3, 0.3), CFrame = CF(0, deckTop + 2.0, zCap) * Angles(0, i * math.pi / 2, 0), Mat = "Wood", Color = WOOD })
	end
	P.prompt(capstan, { Name = "AnchorPrompt", ActionText = "Raise Anchor", ObjectText = "Anchor", HoldDuration = 1.0, MaxActivationDistance = 8 })

	local mountCF = CF(W / 2 + 0.4, s.DeckY - 0.4, zBow + 1.5)
	local mount = P.part(fittings, { Name = "AnchorMount", Size = V(0.6, 0.6, 0.6), CFrame = mountCF, Mat = "Metal", Color = IRON })
	local anchorModel = P.model(fittings, "Anchor")
	local anchorRoot = P.part(anchorModel, { Name = "AnchorRoot", Size = V(0.3, 0.3, 0.3), CFrame = mountCF * CF(0, -0.5, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	local aParts = {
		P.part(anchorModel, { Name = "Shank", Size = V(0.45, 4.2, 0.45), CFrame = mountCF * CF(0, -2.6, 0), Mat = "Metal", Color = IRON }),
		P.part(anchorModel, { Name = "Arms", Size = V(0.45, 0.45, 3.2), CFrame = mountCF * CF(0, -4.6, 0), Mat = "Metal", Color = IRON }),
		P.part(anchorModel, { Name = "Fluke", Size = V(0.4, 1.0, 0.6), CFrame = mountCF * CF(0, -4.2, 1.5), Mat = "Metal", Color = IRON }),
		P.part(anchorModel, { Name = "Fluke", Size = V(0.4, 1.0, 0.6), CFrame = mountCF * CF(0, -4.2, -1.5), Mat = "Metal", Color = IRON }),
		P.part(anchorModel, { Name = "Stock", Size = V(2.2, 0.35, 0.35), CFrame = mountCF * CF(0, -0.9, 0), Mat = "Wood", Color = WOOD }),
	}
	for _, part in aParts do
		part.CanCollide = false
		P.weld(anchorRoot, part)
	end
	P.weld(mount, anchorRoot, "AnchorWeld")

	-- Cannons
	for _, c in s.Cannons do
		local cannon = buildCannon(cannons, s)
		P.transform(cannon, CF(c.Side * (W / 2 - 3.4), deckTop, c.Z) * Angles(0, -c.Side * math.pi / 2, 0))
		cannon:SetAttribute("Side", c.Side)
	end

	-- Ladders on both sides so swimmers can climb aboard
	for _, side in { -1, 1 } do
		P.part(hull, { Class = "TrussPart", Name = "Ladder", Size = V(2, 14, 2), CFrame = CF(side * (W / 2 + 1), s.DeckY - 3, zBow + 3), Color = s.Rail, Mat = "Wood" })
	end

	-- Hole spots (where cannon damage appears) on the main deck
	local candidates = {}
	local z = zBow + 3
	while z < zCastle - stairLen - 1 do
		for _, x in { -W * 0.22, W * 0.22 } do
			local ok = true
			for _, m in s.Masts do
				if math.abs(z - m.Z) < 3 then
					ok = false
				end
			end
			for _, c in s.Cannons do
				if math.abs(z - c.Z) < 2.5 and x * c.Side > 0 then
					ok = false
				end
			end
			if math.abs(z - zCap) < 2.5 then
				ok = false
			end
			if ok then
				table.insert(candidates, V(x, deckTop + 0.02, z))
			end
		end
		z += 4.5
	end
	local step = math.max(1, #candidates / s.Holes)
	local i = 1
	while i <= #candidates do
		P.attachment(root, "HoleSpot", CF(candidates[math.floor(i)]))
		i += step
	end

	P.attachment(root, "CrewSpawn", CF(W * 0.25, deckTop, zBow + 3))

	-- Wake / bow spray (the client sets Rate from the ship speed)
	local bowAtt = P.attachment(root, "BowSpray", CF(0, 0.6, -L / 2 + 1.5))
	P.emitter(bowAtt, {
		Name = "Wake",
		Rate = 0,
		Color = P.ColorSequence.new(rgb(255, 255, 255)),
		Size = P.seq(1.5, 5),
		Transparency = P.seq(0.35, 1),
		Lifetime = P.NumberRange.new(0.8, 1.4),
		Speed = P.NumberRange.new(6, 12),
		SpreadAngle = P.Vector2.new(50, 15),
		Acceleration = V(0, -14, 0),
		Drag = 1.5,
		LightEmission = 0.25,
	})
	local sternAtt = P.attachment(root, "SternWake", CF(0, 0.3, zStern + 1.5))
	P.emitter(sternAtt, {
		Name = "Wake",
		Rate = 0,
		Color = P.ColorSequence.new(rgb(230, 250, 255)),
		Size = P.seq(3, 10),
		Transparency = P.seq(0.45, 1),
		Lifetime = P.NumberRange.new(2, 3),
		Speed = P.NumberRange.new(1, 3),
		SpreadAngle = P.Vector2.new(25, 25),
		LightEmission = 0.2,
	})

	P.billboard(root, "NameTag", "Ship", { Offset = V(0, mainMastTop + 6, 0), MaxDistance = 700, Size = P.UDim2.fromOffset(300, 46), Color = rgb(255, 230, 160) })

	-- Physics: only Root is anchored in the template; everything is welded to it.
	for _, part in P.descendantParts(model) do
		if part ~= root then
			part.Anchored = false
			part.Massless = true
		end
	end
	P.weldAllTo(model, root)

	model:SetAttribute("ShipType", id)
	model:SetAttribute("Length", L)
	model:SetAttribute("Width", W)
	return model
end

return Ships
