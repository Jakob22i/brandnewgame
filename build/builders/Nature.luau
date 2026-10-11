-- Palms, rocks, bushes, flowers, corals, shipwrecks and landmarks on every island.
-- Placement uses the same Heightmap the game generates its terrain from.
local P = require("./Parts")

local V = P.Vector3.new
local CF = P.CFrame.new
local Angles = P.CFrame.Angles
local rgb = P.rgb

local Nature = {}

local FROND_COLORS = { rgb(58, 150, 52), rgb(74, 168, 58), rgb(46, 132, 46), rgb(90, 176, 64) }
local FLOWER_COLORS = { rgb(255, 70, 110), rgb(255, 210, 50), rgb(255, 120, 40), rgb(240, 90, 220), rgb(255, 255, 255) }

function Nature.Palm(parent: any, base: any, rng: any, scale: number?)
	local m = P.model(parent, "Palm")
	local s = scale or 1
	local height = rng:Range(15, 23) * s
	local lean = rng:Range(0, math.pi * 2)
	local leanDir = V(math.cos(lean), 0, math.sin(lean))
	local segments = 4
	local segLen = height / segments
	local p0 = base - V(0, 1.5, 0)
	local bend = rng:Range(0.06, 0.14)
	local tilt = rng:Range(0.05, 0.15)
	for i = 1, segments do
		tilt += bend
		local dir = (V(0, 1, 0) + leanDir * tilt).Unit
		local p1 = p0 + dir * segLen
		local d = (1.7 - i * 0.16) * s
		P.beam(m, p0, p1 + dir * 0.3, d, { Name = "Trunk", Mat = "Wood", Color = if i % 2 == 0 then rgb(150, 112, 72) else rgb(134, 98, 62) })
		p0 = p1
	end
	local top = p0
	P.part(m, { Name = "Crown", Shape = "Ball", Size = V(1.8, 1.8, 1.8) * s, CFrame = CF(top), Mat = "Grass", Color = rgb(70, 120, 40), CanCollide = false })
	local fronds = rng:Int(7, 9)
	for k = 1, fronds do
		local a = (k / fronds) * math.pi * 2 + rng:Range(-0.2, 0.2)
		local out = V(math.cos(a), 0, math.sin(a))
		local color = rng:Pick(FROND_COLORS)
		local len1 = rng:Range(4.5, 5.5) * s
		local len2 = rng:Range(4.5, 6) * s
		local mid = top + (out * math.cos(math.rad(20)) + V(0, math.sin(math.rad(20)), 0)) * len1
		local droop = rng:Range(35, 55)
		local tip = mid + (out * math.cos(math.rad(droop)) - V(0, math.sin(math.rad(droop)), 0)) * len2
		P.plank(m, top, mid, 1.9 * s, 0.18, { Name = "Frond", Mat = "Grass", Color = color, CanCollide = false, CanQuery = false })
		P.plank(m, mid, tip, 1.3 * s, 0.16, { Name = "Frond", Mat = "Grass", Color = color, CanCollide = false, CanQuery = false })
	end
	for i = 1, rng:Int(2, 3) do
		local a = rng:Range(0, math.pi * 2)
		P.part(m, { Name = "Coconut", Shape = "Ball", Size = V(0.95, 0.95, 0.95) * s, CFrame = CF(top + V(math.cos(a) * 0.8, -0.9, math.sin(a) * 0.8) * s), Color = rgb(96, 64, 34), CanCollide = false })
	end
	return m
end

function Nature.Rock(parent: any, pos: any, size: number, rng: any, color: any, material: string)
	local m = P.model(parent, "Rock")
	for i = 1, rng:Int(2, 3) do
		local sx = size * rng:Range(0.6, 1.1)
		local sy = size * rng:Range(0.4, 0.8)
		local sz = size * rng:Range(0.6, 1.1)
		local offset = V(rng:Range(-0.3, 0.3) * size, rng:Range(-0.1, 0.2) * size, rng:Range(-0.3, 0.3) * size)
		local shade = rng:Range(0.85, 1.1)
		P.part(m, {
			Name = "Stone",
			Size = V(sx, sy, sz),
			CFrame = CF(pos + offset) * Angles(rng:Range(-0.4, 0.4), rng:Range(0, math.pi), rng:Range(-0.4, 0.4)),
			Mat = material,
			Color = P.Color3.new(math.min(1, color.R * shade), math.min(1, color.G * shade), math.min(1, color.B * shade)),
		})
	end
	return m
end

function Nature.Bush(parent: any, pos: any, rng: any)
	local m = P.model(parent, "Bush")
	local green = rng:Pick(FROND_COLORS)
	for i = 1, rng:Int(2, 3) do
		local r = rng:Range(2.4, 4)
		P.part(m, { Name = "Leaves", Shape = "Ball", Size = V(r, r * 0.8, r), CFrame = CF(pos + V(rng:Range(-1.2, 1.2), r * 0.25, rng:Range(-1.2, 1.2))), Mat = "Grass", Color = green, CanCollide = false })
	end
	if rng:Next() < 0.7 then
		local flower = rng:Pick(FLOWER_COLORS)
		for i = 1, rng:Int(3, 6) do
			P.part(m, { Name = "Flower", Shape = "Ball", Size = V(0.6, 0.6, 0.6), CFrame = CF(pos + V(rng:Range(-1.6, 1.6), rng:Range(1.2, 2.4), rng:Range(-1.6, 1.6))), Color = flower, CanCollide = false, CanQuery = false })
		end
	end
	return m
end

function Nature.Coral(parent: any, pos: any, rng: any)
	local colors = { rgb(255, 110, 140), rgb(255, 160, 60), rgb(180, 90, 230), rgb(255, 230, 90), rgb(80, 220, 200) }
	local m = P.model(parent, "Coral")
	local c = rng:Pick(colors)
	for i = 1, rng:Int(3, 5) do
		local h = rng:Range(1.5, 3.5)
		local p0 = pos + V(rng:Range(-1.5, 1.5), 0, rng:Range(-1.5, 1.5))
		local p1 = p0 + V(rng:Range(-0.8, 0.8), h, rng:Range(-0.8, 0.8))
		P.beam(m, p0, p1, rng:Range(0.4, 0.8), { Name = "Branch", Color = c, CanCollide = false })
		P.part(m, { Name = "Tip", Shape = "Ball", Size = V(0.9, 0.9, 0.9), CFrame = CF(p1), Color = c, CanCollide = false })
	end
	return m
end

function Nature.Shipwreck(parent: any, pos: any, yaw: number)
	local m = P.model(parent, "Shipwreck")
	local hull = rgb(96, 70, 48)
	local cf = CF(pos) * Angles(0, yaw, 0) * Angles(0, 0, math.rad(18))
	for i = 0, 5 do
		P.part(m, { Name = "Plank", Size = V(1.0, 5, 22 - i * 2), CFrame = cf * CF(4.8, 1.5 + i * 0.4, i * 1.2) * Angles(0, 0, math.rad(-10 + i * 4)), Mat = "WoodPlanks", Color = hull })
	end
	for z = -9, 9, 3 do
		P.beam(m, (cf * CF(-4, 0, z)).Position, (cf * CF(4.5, 5.5, z)).Position, 0.8, { Name = "Rib", Mat = "Wood", Color = rgb(80, 58, 40) })
	end
	P.beam(m, (cf * CF(0, 1, -2)).Position, (cf * CF(-14, 3, 10)).Position, 1.4, { Name = "BrokenMast", Mat = "Wood", Color = rgb(112, 76, 46) })
	P.part(m, { Name = "TornSail", Size = V(8, 0.2, 6), CFrame = cf * CF(-9, 2.2, 6) * Angles(0.2, 0.4, 0.1), Mat = "Fabric", Color = rgb(220, 206, 170), CanCollide = false })
	return m
end

local function skullRock(parent: any, pos: any)
	local m = P.model(parent, "GiantSkull")
	local stone = rgb(214, 208, 192)
	P.part(m, { Name = "Cranium", Shape = "Ball", Size = V(34, 34, 34), CFrame = CF(pos + V(0, 14, 0)), Mat = "Slate", Color = stone })
	P.part(m, { Name = "Jaw", Size = V(22, 10, 20), CFrame = CF(pos + V(0, -1, 4)), Mat = "Slate", Color = stone })
	for _, x in { -7, 7 } do
		P.part(m, { Name = "EyeSocket", Shape = "Ball", Size = V(10, 10, 10), CFrame = CF(pos + V(x, 16, 13)), Mat = "Slate", Color = rgb(24, 22, 24) })
		local glow = P.part(m, { Name = "EyeGlow", Shape = "Ball", Size = V(2.4, 2.4, 2.4), CFrame = CF(pos + V(x, 16, 17.2)), Mat = "Neon", Color = rgb(90, 255, 140) })
		P.pointLight(glow, rgb(90, 255, 140), 24, 2, false)
	end
	P.part(m, { Class = "WedgePart", Name = "Nose", Size = V(5, 6, 4), CFrame = CF(pos + V(0, 9, 15.5)) * Angles(0, math.pi, 0), Mat = "Slate", Color = rgb(30, 28, 30) })
	for i = -3, 3 do
		P.part(m, { Name = "Tooth", Size = V(2.2, 3, 1.5), CFrame = CF(pos + V(i * 2.6, 4.5, 14)), Mat = "Slate", Color = rgb(240, 236, 220) })
	end
	return m
end

local function ruins(parent: any, pos: any, rng: any)
	local m = P.model(parent, "Ruins")
	local stone = rgb(222, 200, 150)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = pos + V(math.cos(a) * 14, 0, math.sin(a) * 14)
		local h = if i % 3 == 0 then rng:Range(3, 6) else rng:Range(9, 14)
		P.pillar(m, p.X, p.Z, p.Y - 2, p.Y + h, 2.6, { Name = "Pillar", Mat = "Sandstone", Color = stone })
	end
	P.part(m, { Name = "Altar", Size = V(6, 3, 4), CFrame = CF(pos + V(0, 0.5, 0)), Mat = "Sandstone", Color = stone })
	P.part(m, { Name = "Lintel", Size = V(14, 2, 3), CFrame = CF(pos + V(0, 12, -14)) * Angles(0, 0, math.rad(6)), Mat = "Sandstone", Color = stone })
	return m
end

-- Does (x, z) sit in a spot that must stay clear (town buildings, roads, piers)?
local function blocked(x: number, z: number, H: any, World: any, clear: { any }): boolean
	for _, c in clear do
		local dx, dz = x - c.X, z - c.Z
		if dx * dx + dz * dz < c.R * c.R then
			return true
		end
	end
	for _, pier in World.Piers do
		if math.abs(x - pier.X) < pier.HalfWidth + 6 and z > pier.MinZ - 12 then
			return true
		end
	end
	if z > 290 and z < 316 and math.abs(x) < 90 then
		return true -- boardwalk
	end
	for _, road in World.Roads do
		local vx, vz = road.X2 - road.X1, road.Z2 - road.Z1
		local len2 = vx * vx + vz * vz
		local t = math.clamp(((x - road.X1) * vx + (z - road.Z1) * vz) / len2, 0, 1)
		local cx, cz = road.X1 + vx * t, road.Z1 + vz * t
		if (x - cx) ^ 2 + (z - cz) ^ 2 < (road.Width / 2 + 4) ^ 2 then
			return true
		end
	end
	return false
end

local ROCK_COLORS = {
	Rock = rgb(132, 126, 116),
	Slate = rgb(120, 116, 112),
	Basalt = rgb(58, 54, 58),
	Sandstone = rgb(214, 186, 140),
	Limestone = rgb(220, 214, 196),
}

function Nature.Build(parent: any, H: any, World: any, Noise: any, clear: { any })
	local root = P.folder(parent, "Nature")
	local stats = { Palms = 0, Rocks = 0, Bushes = 0 }
	for _, island in World.Islands do
		local folder = P.folder(root, island.Name)
		local rng = Noise.Rng(island.Seed * 7919 + 17)
		local isMain = island.Kind == "Main"
		local function samplePoint(maxFrac: number)
			local a = rng:Range(0, math.pi * 2)
			local d = math.sqrt(rng:Next()) * island.Radius * maxFrac
			return island.X + math.cos(a) * d, island.Z + math.sin(a) * d
		end
		local function ok(x: number, z: number): boolean
			local _, owner = H.GetHeight(x, z)
			if owner ~= island then
				return false
			end
			return not (isMain and blocked(x, z, H, World, clear))
		end

		-- Palms: prefer beaches and gentle ground
		local placed = 0
		local tries = 0
		local palmSpots = {}
		while placed < island.Palms and tries < island.Palms * 30 do
			tries += 1
			local x, z = samplePoint(1.05)
			local h = H.GetHeight(x, z)
			if h > 2.6 and h < math.min(island.Height * 0.85, 45) and ok(x, z) and H.GetSlope(x, z) < 0.55 then
				local tooClose = false
				for _, s in palmSpots do
					if (s[1] - x) ^ 2 + (s[2] - z) ^ 2 < 64 then
						tooClose = true
						break
					end
				end
				if not tooClose and (h < 9 or rng:Next() < 0.45) then
					Nature.Palm(folder, V(x, h, z), rng, if island.Kind == "Rocky" then 0.85 else 1)
					table.insert(palmSpots, { x, z })
					placed += 1
				end
			end
		end
		stats.Palms += placed

		-- Rocks (some sit in the shallows)
		local rockColor = ROCK_COLORS[island.RockMaterial] or ROCK_COLORS.Rock
		local rockMat = if island.RockMaterial == "Sandstone" or island.RockMaterial == "Limestone" then "Sandstone" else "Slate"
		placed, tries = 0, 0
		while placed < island.Rocks and tries < island.Rocks * 30 do
			tries += 1
			local x, z = samplePoint(1.15)
			local h = H.GetHeight(x, z)
			if h > -3 and ok(x, z) then
				local size = if island.Kind == "Rocky" then rng:Range(5, 12) else rng:Range(3, 8)
				Nature.Rock(folder, V(x, h + size * 0.1, z), size, rng, rockColor, rockMat)
				placed += 1
			end
		end
		stats.Rocks += placed

		-- Bushes with tropical flowers
		local bushes = math.floor(island.Palms * 0.7)
		placed, tries = 0, 0
		while placed < bushes and tries < bushes * 30 do
			tries += 1
			local x, z = samplePoint(0.95)
			local h = H.GetHeight(x, z)
			if h > 4 and h < 50 and ok(x, z) and H.GetSlope(x, z) < 0.7 then
				Nature.Bush(folder, V(x, h - 0.6, z), rng)
				placed += 1
			end
		end
		stats.Bushes += placed

		-- Landmarks
		if island.Name == "Skull Rock" then
			local bestH, bx, bz = -math.huge, island.X, island.Z
			for i = 1, 200 do
				local x, z = samplePoint(0.5)
				local h = H.GetHeight(x, z)
				if h > bestH then
					bestH, bx, bz = h, x, z
				end
			end
			skullRock(folder, V(bx, bestH - 2, bz))
		elseif island.Name == "Golden Sands" then
			local x, z = island.X + 20, island.Z - 10
			ruins(folder, V(x, H.GetHeight(x, z), z), rng)
		elseif island.Name == "Coral Atoll" then
			for i = 1, 40 do
				local x, z = samplePoint(0.6)
				local h = H.GetHeight(x, z)
				if h < -2 and h > -10 then
					Nature.Coral(folder, V(x, h - 0.5, z), rng)
				end
			end
		end
		if island.Name == "Smuggler's Bay" or island.Name == "Sunken Grove" or island.Name == "Thieves' Haven" then
			for i = 1, 200 do
				local x, z = samplePoint(1.0)
				local h = H.GetHeight(x, z)
				if h > 0.5 and h < 2.5 then
					Nature.Shipwreck(folder, V(x, h, z), rng:Range(0, math.pi * 2))
					break
				end
			end
		end
	end
	return root, stats
end

return Nature
