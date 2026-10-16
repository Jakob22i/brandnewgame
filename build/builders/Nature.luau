-- Vegetation and landmarks on every island: curved palms, broadleaf jungle trees, ferns,
-- red tropical flowers, hibiscus bushes, layered sandstone rocks, corals, shipwrecks.
-- Kingshaven gets a dense jungle on its terraces (outside the town, the paths and the
-- keep-clear zones); the other islands get a lighter mix to keep the part count low.
-- Placement uses the same Heightmap the game generates its terrain from.
local P = require("./Parts")

local V = P.Vector3.new
local CF = P.CFrame.new
local Angles = P.CFrame.Angles
local rgb = P.rgb
local UP = V(0, 1, 0)

local Nature = {}

-- Palette (stylised, slightly warm greens like the reference)
local FROND = { rgb(64, 150, 50), rgb(80, 166, 56), rgb(54, 136, 48), rgb(96, 176, 60) }
local CANOPY_DARK = { rgb(38, 104, 44), rgb(46, 116, 40), rgb(34, 96, 50) }
local CANOPY_MID = { rgb(60, 138, 48), rgb(70, 148, 44), rgb(56, 132, 58) }
local CANOPY_LIGHT = { rgb(98, 172, 58), rgb(112, 182, 62), rgb(90, 166, 70) }
local FERN = { rgb(58, 140, 52), rgb(74, 156, 50), rgb(48, 124, 56), rgb(88, 160, 46) }
local PALM_TRUNK = { rgb(170, 130, 88), rgb(150, 112, 74) }
local TREE_BARK = { rgb(110, 84, 62), rgb(96, 74, 58), rgb(122, 96, 70) }
local RED_LEAF = { rgb(206, 38, 52), rgb(228, 60, 70), rgb(186, 30, 64), rgb(240, 90, 80) }
local HIBISCUS = { rgb(236, 40, 70), rgb(255, 86, 132), rgb(255, 120, 60), rgb(250, 60, 110) }
local VINE = rgb(52, 120, 44)

-- Sandstone shades (layered rocks)
Nature.SANDSTONE = { rgb(214, 186, 140), rgb(198, 168, 124), rgb(222, 196, 150), rgb(186, 156, 116), rgb(206, 178, 128) }
Nature.GRASS_CAP = { rgb(86, 160, 58), rgb(98, 172, 62), rgb(76, 150, 54) }

local function pick(rng: any, list: { any })
	return list[rng:Int(1, #list)]
end

local function shade(c: any, f: number)
	return P.Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end
Nature.Shade = shade

-- A flat pointed leaf (WedgePart) from `a` (wide base) to `b` (the point). The leaf lies
-- across `up` (its normal is as close to `up` as the direction allows).
function Nature.Leaf(parent: any, a: any, b: any, width: number, thickness: number, up: any, flip: boolean, props: { [string]: any })
	local dir = b - a
	local len = dir.Magnitude
	dir = dir.Unit
	local side = up:Cross(dir)
	if side.Magnitude < 0.01 then
		side = V(1, 0, 0):Cross(dir)
	end
	side = side.Unit
	local normal = dir:Cross(side).Unit
	-- WedgePart: full height at +Z, the point at -Z (local y = -0.5)
	local vZ = -dir
	local vX = if flip then -normal else normal
	local vY = vZ:Cross(vX)
	local merged: { [string]: any } = {
		Class = "WedgePart",
		Size = V(thickness, width, len),
		CFrame = P.CFrame.fromMatrix((a + b) / 2 + vY * (width * 0.25), vX, vY, vZ),
		CanCollide = false,
	}
	for k, v in props do
		merged[k] = v
	end
	return P.part(parent, merged)
end

-- Palm tree: curved, ringed trunk, layered drooping fronds and coconuts.
-- detail 1 = Kingshaven (about 22 parts), 0 = other islands (about 16 parts)
function Nature.Palm(parent: any, base: any, rng: any, scale: number?, detail: number?)
	local m = P.model(parent, "Palm")
	local s = scale or 1
	local full = (detail or 1) >= 1
	local height = rng:Range(17, 25) * s
	local lean = rng:Range(0, math.pi * 2)
	local leanDir = V(math.cos(lean), 0, math.sin(lean))
	local segments = if full then 5 else 4
	local segLen = height / segments
	local p0 = base - V(0, 1.2, 0)
	local tilt = rng:Range(0.02, 0.1)
	local bend = rng:Range(0.07, 0.15)
	local dir = UP
	for i = 1, segments do
		tilt += bend * (0.4 + i * 0.25)
		dir = (UP + leanDir * tilt).Unit
		local p1 = p0 + dir * segLen
		local d = (1.8 - (i - 1) / (segments - 1) * 0.65) * s
		P.beam(m, p0 - dir * 0.2, p1 + dir * 0.2, d, {
			Name = "Trunk",
			Mat = "Wood",
			Color = PALM_TRUNK[i % 2 + 1],
			CanCollide = i <= 2,
		})
		p0 = p1
	end
	local top = p0 + dir * 0.4
	P.part(m, { Name = "Crown", Shape = "Ball", Size = V(2.3, 2.3, 2.3) * s, CFrame = CF(top), Mat = "Grass", Color = rgb(92, 112, 44), CanCollide = false })
	local fronds = if full then 7 else 6
	local spin = rng:Range(0, math.pi * 2)
	for k = 1, fronds do
		local a = spin + (k / fronds) * math.pi * 2 + rng:Range(-0.25, 0.25)
		local out = V(math.cos(a), 0, math.sin(a))
		local young = k == 1 or k == 4 -- a couple of younger fronds stand higher
		local color = pick(rng, FROND)
		local rise = math.rad(if young then rng:Range(30, 42) else rng:Range(6, 24))
		local droop = math.rad(if young then rng:Range(18, 34) else rng:Range(42, 68))
		local len1 = rng:Range(4.8, 6) * s * (if young then 0.85 else 1)
		local len2 = rng:Range(5.6, 7.4) * s * (if young then 0.85 else 1)
		local mid = top + (out * math.cos(rise) + UP * math.sin(rise)) * len1
		local tip = mid + (out * math.cos(droop) - UP * math.sin(droop)) * len2
		local roll = (UP + out:Cross(UP) * rng:Range(-0.3, 0.3)).Unit
		P.plank(m, top, mid + (mid - top).Unit * 0.3, 2.5 * s, 0.2, { Name = "Frond", Mat = "Grass", Color = color, CanCollide = false, CanQuery = false })
		Nature.Leaf(m, mid, tip, 2.7 * s, 0.18, roll, rng:Next() < 0.5, { Name = "Frond", Mat = "Grass", Color = shade(color, 1.06), CanQuery = false })
	end
	for i = 1, if full then 2 else 1 do
		local a = rng:Range(0, math.pi * 2)
		P.part(m, {
			Name = "Coconut",
			Shape = "Ball",
			Size = V(1.05, 1.05, 1.05) * s,
			CFrame = CF(top + V(math.cos(a) * 0.95, -1.0, math.sin(a) * 0.95) * s),
			Color = if i == 1 then rgb(104, 72, 38) else rgb(122, 140, 52),
			CanCollide = false,
		})
	end
	return m
end

-- Broadleaf jungle tree: twisted trunk with buttress roots and a layered, rounded canopy.
-- detail 1 = about 14 parts, 0 = about 8 parts
function Nature.JungleTree(parent: any, base: any, rng: any, scale: number?, detail: number?)
	local m = P.model(parent, "JungleTree")
	local s = scale or 1
	local full = (detail or 1) >= 1
	local height = rng:Range(12, 17) * s
	local bark = pick(rng, TREE_BARK)
	local p0 = base - V(0, 1.5, 0)
	local a = rng:Range(0, math.pi * 2)
	local segs = 3
	for i = 1, segs do
		a += rng:Range(1.6, 2.6) -- the trunk twists back and forth
		local off = V(math.cos(a), 0, math.sin(a)) * rng:Range(1.0, 2.0) * s
		local p1 = p0 + V(0, (height + 1.5) / segs, 0) + off
		local d = (2.7 - (i - 1) * 0.45) * s
		P.beam(m, p0, p1 + (p1 - p0).Unit * 0.5, d, { Name = "Trunk", Mat = "Wood", Color = shade(bark, 1 + (i - 2) * 0.06) })
		p0 = p1
	end
	local top = p0
	if full then
		-- buttress roots
		for i = 1, 2 do
			local ra = rng:Range(0, math.pi * 2)
			local foot = base + V(math.cos(ra) * 3.4 * s, -0.8, math.sin(ra) * 3.4 * s)
			P.beam(m, base + V(0, 3.2 * s, 0), foot, 1.2 * s, { Name = "Root", Mat = "Wood", Color = shade(bark, 0.92) })
		end
	end
	-- canopy: a big crown, a ring of lower clumps and lighter clumps on top
	local R = rng:Range(8.5, 11.5) * s
	local centre = top + V(0, R * 0.25, 0)
	P.part(m, { Name = "Leaves", Shape = "Ball", Size = V(1, 1, 1) * R * 1.5, CFrame = CF(centre), Mat = "Grass", Color = pick(rng, CANOPY_MID), CanCollide = false })
	local ring = if full then 4 else 3
	local ringSpin = rng:Range(0, math.pi * 2)
	for k = 1, ring do
		local ka = ringSpin + k / ring * math.pi * 2 + rng:Range(-0.3, 0.3)
		local kd = R * rng:Range(0.7, 0.9)
		local size = R * rng:Range(0.85, 1.1)
		local p = top + V(math.cos(ka) * kd, rng:Range(-0.25, 0.05) * R, math.sin(ka) * kd)
		P.part(m, { Name = "Leaves", Shape = "Ball", Size = V(size, size, size), CFrame = CF(p), Mat = "Grass", Color = pick(rng, CANOPY_DARK), CanCollide = false })
		if full and k == 1 then
			-- a branch reaching out to a clump
			P.beam(m, top - V(0, 2 * s, 0), p - V(0, size * 0.2, 0), 0.9 * s, { Name = "Branch", Mat = "Wood", Color = bark, CanCollide = false })
		end
	end
	for k = 1, if full then 2 else 1 do
		local ka = rng:Range(0, math.pi * 2)
		local size = R * rng:Range(0.75, 0.95)
		local p = centre + V(math.cos(ka) * R * 0.35, R * 0.55, math.sin(ka) * R * 0.35)
		P.part(m, { Name = "Leaves", Shape = "Ball", Size = V(size, size, size), CFrame = CF(p), Mat = "Grass", Color = pick(rng, CANOPY_LIGHT), CanCollide = false })
	end
	if full and rng:Next() < 0.6 then
		-- a hanging vine
		local va = rng:Range(0, math.pi * 2)
		local vp = top + V(math.cos(va) * R * 0.75, -R * 0.3, math.sin(va) * R * 0.75)
		P.beam(m, vp, vp - V(0, rng:Range(5, 9) * s, 0), 0.35, { Name = "Vine", Mat = "Grass", Color = VINE, CanCollide = false, CanQuery = false })
	end
	return m, R
end

-- Fern: a fan of pointed fronds arching out of the ground (5-6 parts)
function Nature.Fern(parent: any, pos: any, rng: any, scale: number?)
	local m = P.model(parent, "Fern")
	local s = scale or 1
	local n = rng:Int(5, 6)
	local spin = rng:Range(0, math.pi * 2)
	local color = pick(rng, FERN)
	for k = 1, n do
		local a = spin + k / n * math.pi * 2 + rng:Range(-0.3, 0.3)
		local out = V(math.cos(a), 0, math.sin(a))
		local el = math.rad(rng:Range(18, 42))
		local len = rng:Range(3.2, 4.6) * s
		local root = pos + V(0, 0.3, 0) + out * 0.4
		local tip = root + (out * math.cos(el) + UP * math.sin(el)) * len
		Nature.Leaf(m, root, tip, rng:Range(1.1, 1.5) * s, 0.15, UP, rng:Next() < 0.5, { Name = "Frond", Mat = "Grass", Color = shade(color, rng:Range(0.9, 1.1)), CanQuery = false })
	end
	return m
end

-- Red tropical plant: spiky red leaves standing up (like the red plants in the reference)
function Nature.RedPlant(parent: any, pos: any, rng: any, scale: number?)
	local m = P.model(parent, "RedPlant")
	local s = scale or 1
	local n = rng:Int(5, 6)
	local spin = rng:Range(0, math.pi * 2)
	local color = pick(rng, RED_LEAF)
	for k = 1, n do
		local a = spin + k / n * math.pi * 2 + rng:Range(-0.25, 0.25)
		local out = V(math.cos(a), 0, math.sin(a))
		local el = math.rad(rng:Range(40, 66))
		local len = rng:Range(3.6, 5) * s
		local root = pos + V(0, 0.2, 0)
		local tip = root + (out * math.cos(el) + UP * math.sin(el)) * len
		Nature.Leaf(m, root, tip, rng:Range(1.1, 1.4) * s, 0.16, UP, rng:Next() < 0.5, { Name = "Leaf", Mat = "SmoothPlastic", Color = shade(color, rng:Range(0.92, 1.08)), CanQuery = false })
	end
	return m
end

-- Hibiscus bush: rounded leaves dotted with big red and pink flowers
function Nature.Hibiscus(parent: any, pos: any, rng: any, scale: number?)
	local m = P.model(parent, "Hibiscus")
	local s = scale or 1
	local green = pick(rng, CANOPY_DARK)
	local r = rng:Range(3.4, 4.4) * s
	P.part(m, { Name = "Leaves", Shape = "Ball", Size = V(r, r, r), CFrame = CF(pos + V(0, r * 0.3, 0)), Mat = "Grass", Color = green, CanCollide = false })
	local r2 = r * 0.75
	local oa = rng:Range(0, math.pi * 2)
	P.part(m, { Name = "Leaves", Shape = "Ball", Size = V(r2, r2, r2), CFrame = CF(pos + V(math.cos(oa) * r * 0.45, r2 * 0.25, math.sin(oa) * r * 0.45)), Mat = "Grass", Color = shade(green, 1.15), CanCollide = false })
	local flower = pick(rng, HIBISCUS)
	for k = 1, 3 do
		local a = oa + k * 2.1 + rng:Range(-0.3, 0.3)
		local el = rng:Range(0.15, 0.9)
		local n = V(math.cos(a) * math.cos(el), math.sin(el), math.sin(a) * math.cos(el))
		local c = pos + V(0, r * 0.3, 0) + n * (r * 0.5)
		-- flat disc facing outward (cylinder axis = normal)
		P.part(m, { Name = "Flower", Shape = "Cylinder", Size = V(0.35, 1.5 * s, 1.5 * s), CFrame = P.lookAt(c, c + n) * Angles(0, math.pi / 2, 0), Mat = "SmoothPlastic", Color = flower, CanCollide = false, CanQuery = false })
	end
	return m
end

-- Leafy bush (2-3 rounded clumps)
function Nature.Bush(parent: any, pos: any, rng: any, scale: number?)
	local m = P.model(parent, "Bush")
	local s = scale or 1
	local green = pick(rng, CANOPY_MID)
	for i = 1, rng:Int(2, 3) do
		local r = rng:Range(2.6, 4.2) * s
		P.part(m, { Name = "Leaves", Shape = "Ball", Size = V(r, r, r), CFrame = CF(pos + V(rng:Range(-1.4, 1.4), r * 0.22, rng:Range(-1.4, 1.4))), Mat = "Grass", Color = shade(green, rng:Range(0.85, 1.15)), CanCollide = false })
	end
	return m
end

-- A stack of rough slabs (layered sandstone look). cf = base centre, facing -Z = front.
-- Each slab is smaller, shifted and turned a little against the one below.
-- Returns the model and the height of its top.
function Nature.SlabStack(parent: any, cf: any, width: number, depth: number, height: number, rng: any, palette: { any }, material: string, cap: boolean?)
	local m = P.model(parent, "RockStack")
	local y = 0
	local w, d = width, depth
	local layer = 0
	local ox, oz = 0, 0
	local yaw = 0
	while y < height - 0.5 do
		layer += 1
		local th = math.min(rng:Range(0.22, 0.34) * math.max(width, 8), height - y + 0.6)
		yaw += rng:Range(-0.35, 0.35)
		ox += rng:Range(-0.1, 0.1) * w
		oz += rng:Range(-0.1, 0.1) * d
		local color = shade(palette[(layer - 1) % #palette + 1], rng:Range(0.94, 1.04))
		local lcf = cf * CF(ox, y + th / 2, oz) * Angles(rng:Range(-0.06, 0.06), yaw, rng:Range(-0.06, 0.06))
		-- two boxes turned 45 degrees against each other read as a rounder stone
		P.part(m, { Name = "Slab", Size = V(w, th, d), CFrame = lcf, Mat = material, Color = color })
		P.part(m, { Name = "Slab", Size = V(w * 0.84, th * rng:Range(0.85, 1.0), d * 0.84), CFrame = lcf * Angles(0, math.pi / 4, 0), Mat = material, Color = shade(color, 0.96) })
		y += th * 0.94
		w *= rng:Range(0.7, 0.9)
		d *= rng:Range(0.72, 0.92)
	end
	if cap then
		P.part(m, { Name = "GrassCap", Size = V(w * 1.1, 0.6, d * 1.1), CFrame = cf * CF(ox, y + 0.15, oz) * Angles(0, yaw + rng:Range(-0.2, 0.2), 0), Mat = "LeafyGrass", Color = pick(rng, Nature.GRASS_CAP) })
		y += 0.45
	end
	return m, y
end

function Nature.Coral(parent: any, pos: any, rng: any)
	local colors = { rgb(255, 110, 140), rgb(255, 160, 60), rgb(180, 90, 230), rgb(255, 230, 90), rgb(80, 220, 200) }
	local m = P.model(parent, "Coral")
	local c = pick(rng, colors)
	for i = 1, rng:Int(2, 3) do
		local h = rng:Range(1.5, 3.5)
		local p0 = pos + V(rng:Range(-1.5, 1.5), 0, rng:Range(-1.5, 1.5))
		local p1 = p0 + V(rng:Range(-0.8, 0.8), h, rng:Range(-0.8, 0.8))
		P.beam(m, p0, p1, rng:Range(0.5, 0.9), { Name = "Branch", Color = c, CanCollide = false })
		P.part(m, { Name = "Tip", Shape = "Ball", Size = V(1.1, 1.1, 1.1), CFrame = CF(p1), Color = c, CanCollide = false })
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

-- Distance from (x, z) to the segment a-b
local function segDist(x: number, z: number, x1: number, z1: number, x2: number, z2: number): number
	local vx, vz = x2 - x1, z2 - z1
	local len2 = vx * vx + vz * vz
	local t = if len2 > 0 then math.clamp(((x - x1) * vx + (z - z1) * vz) / len2, 0, 1) else 0
	local cx, cz = x1 + vx * t, z1 + vz * t
	return math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
end

-- Does (x, z) sit in a spot that must stay clear (buildings, paths, piers, props)?
-- margin = extra clearance from the paths (trees need more than ferns)
local function blocked(x: number, z: number, World: any, clear: { any }, margin: number): boolean
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
	if z > 288 and z < 318 and math.abs(x) < 92 then
		return true -- boardwalk
	end
	local town = World.Town
	if (x - town.X) ^ 2 + (z - town.Z) ^ 2 < (town.SquareRadius + 8) ^ 2 then
		return true -- town square
	end
	for _, path in World.Paths do
		local reach = path.Width / 2 + margin
		for i = 1, #path.Points - 1 do
			local a, b = path.Points[i], path.Points[i + 1]
			if x > math.min(a[1], b[1]) - reach and x < math.max(a[1], b[1]) + reach and z > math.min(a[2], b[2]) - reach and z < math.max(a[2], b[2]) + reach then
				if segDist(x, z, a[1], a[2], b[1], b[2]) < reach then
					return true
				end
			end
		end
	end
	local lh = World.Lighthouse
	if (x - lh.X) ^ 2 + (z - lh.Z) ^ 2 < 22 * 22 then
		return true
	end
	return false
end
Nature.Blocked = blocked

local ROCK_COLORS = {
	Rock = { rgb(132, 126, 116), rgb(118, 112, 104), rgb(146, 138, 126) },
	Slate = { rgb(120, 116, 112), rgb(104, 100, 98), rgb(134, 128, 122) },
	Basalt = { rgb(58, 54, 58), rgb(70, 64, 66), rgb(48, 46, 50) },
	Sandstone = Nature.SANDSTONE,
	Limestone = { rgb(220, 214, 196), rgb(206, 198, 178), rgb(230, 224, 206) },
}

-- Spatial hash of placed things so trees keep their distance from each other
local function newGrid(cell: number)
	local cells: { [number]: { { number } } } = {}
	local grid = {}
	local function key(ix: number, iz: number): number
		return ix * 100003 + iz
	end
	function grid.add(x: number, z: number, r: number)
		local k = key(x // cell, z // cell)
		local list = cells[k]
		if not list then
			list = {}
			cells[k] = list
		end
		table.insert(list, { x, z, r })
	end
	-- true if a circle (x, z, r) overlaps anything closer than (r + other) * f
	function grid.hits(x: number, z: number, r: number, f: number): boolean
		local ix, iz = x // cell, z // cell
		for dx = -2, 2 do
			for dz = -2, 2 do
				local list = cells[key(ix + dx, iz + dz)]
				if list then
					for _, o in list do
						local need = (r + o[3]) * f
						if (o[1] - x) ^ 2 + (o[2] - z) ^ 2 < need * need then
							return true
						end
					end
				end
			end
		end
		return false
	end
	return grid
end

-- Dense jungle for Kingshaven ----------------------------------------------------------
-- Part budgets: the jungle is densest along the paths, in groves and on the beaches,
-- and thins out where nobody walks.
local JUNGLE_BUDGET = { Tree = 2450, Palm = 1100, Small = 600, Mound = 300 }

local function countParts(m: any): number
	local n = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function kingshavenJungle(folder: any, island: any, H: any, World: any, Noise: any, clear: { any }, stats: { [string]: number })
	local rng = Noise.Rng(island.Seed * 7919 + 4242)
	local town = World.Town
	local trees = newGrid(16)
	local small = newGrid(8)
	local CELL = 6
	local R = island.Radius * 1.04
	local segs = {}
	for _, path in World.Paths do
		for i = 1, #path.Points - 1 do
			local a, b = path.Points[i], path.Points[i + 1]
			table.insert(segs, { a[1], a[2], b[1], b[2] })
		end
	end
	local function pathDistance(x: number, z: number): number
		local best = math.huge
		for _, sg in segs do
			best = math.min(best, segDist(x, z, sg[1], sg[2], sg[3], sg[4]))
		end
		return best
	end
	-- candidate spots with a score per kind
	local lists = { Tree = {}, Palm = {}, Small = {} }
	for gx = -R, R, CELL do
		for gz = -R, R, CELL do
			if gx * gx + gz * gz > R * R then
				continue
			end
			local x = island.X + gx + rng:Range(0, CELL)
			local z = island.Z + gz + rng:Range(0, CELL)
			local h, owner = H.GetHeight(x, z)
			if owner ~= island or h < 2.8 then
				continue
			end
			local slope = H.GetSlope(x, z)
			if slope > 0.6 then
				continue
			end
			local td = math.sqrt((x - town.X) ^ 2 + (z - town.Z) ^ 2)
			local inTown = td < town.Radius - 6
			local pd = pathDistance(x, z)
			local near = 1 - math.clamp((pd - 18) / 60, 0, 0.75) -- 1 near the paths, 0.25 far away
			local grove = (Noise.Fbm2(x * 0.011, z * 0.011, 4711, 2) + 1) * 0.5
			local beach = h < 7.5 and not inTown
			local r = rng:Next()
			if inTown then
				-- the town plateau: palms and flowers around its edge only
				if td > town.Radius - 50 then
					table.insert(lists.Palm, { x, z, h, 0.5 + r * 0.6, slope })
					table.insert(lists.Small, { x, z, h, 0.4 + r * 0.6, slope })
				end
			elseif beach then
				table.insert(lists.Palm, { x, z, h, 0.8 + r * 0.7, slope })
				table.insert(lists.Small, { x, z, h, 0.3 + r * 0.5, slope })
			else
				table.insert(lists.Tree, { x, z, h, grove * 0.9 + near * 0.6 + r * 0.45, slope, pd })
				table.insert(lists.Palm, { x, z, h, near * 0.5 + (1 - grove) * 0.3 + r * 0.6, slope })
				table.insert(lists.Small, { x, z, h, near * 1.2 + grove * 0.2 + r * 0.4, slope })
			end
		end
	end
	for _, list in lists do
		table.sort(list, function(a, b)
			return a[4] > b[4]
		end)
	end
	local used = { Tree = 0, Palm = 0, Small = 0, Mound = 0 }
	-- broadleaf trees first: they make the canopy
	for _, c in lists.Tree do
		if used.Tree >= JUNGLE_BUDGET.Tree then
			break
		end
		local x, z, h = c[1], c[2], c[3]
		local s = rng:Range(1.2, 1.65)
		local lh = World.Lighthouse
		if (x - lh.X) ^ 2 + (z - lh.Z) ^ 2 < (lh.SummitRadius + 24) ^ 2 then
			continue -- keep the lighthouse summit open (the view from up there is the best on the island)
		end
		if c[5] > 0.42 or trees.hits(x, z, 7.5 * s, 0.8) or blocked(x, z, World, clear, 5) then
			continue
		end
		-- full detail where people walk, lighter trees deep in the jungle
		used.Tree += countParts(Nature.JungleTree(folder, V(x, h, z), rng, s, if c[6] < 70 then 1 else 0))
		trees.add(x, z, 7.5 * s)
		stats.Trees += 1
	end
	-- leafy mounds under and between the trees (cheap undergrowth that fills the gaps)
	for _, c in lists.Tree do
		if used.Mound >= JUNGLE_BUDGET.Mound then
			break
		end
		local x, z, h = c[1], c[2], c[3]
		if c[5] > 0.5 or not trees.hits(x, z, 6, 1.0) or trees.hits(x, z, 1.5, 1.0) or small.hits(x, z, 4, 1.0) or blocked(x, z, World, clear, 2.5) then
			continue
		end
		local m = P.model(folder, "Undergrowth")
		local green = pick(rng, CANOPY_DARK)
		for _ = 1, 2 do
			local r = rng:Range(5, 8)
			P.part(m, { Name = "Leaves", Shape = "Ball", Size = V(r, r, r), CFrame = CF(x + rng:Range(-2.5, 2.5), h - r * 0.22, z + rng:Range(-2.5, 2.5)), Mat = "Grass", Color = shade(green, rng:Range(0.9, 1.15)), CanCollide = false })
		end
		used.Mound += 2
		small.add(x, z, 4)
	end
	for _, c in lists.Palm do
		if used.Palm >= JUNGLE_BUDGET.Palm then
			break
		end
		local x, z, h = c[1], c[2], c[3]
		if c[5] > 0.42 or trees.hits(x, z, 4.5, 1.0) or blocked(x, z, World, clear, 4) then
			continue
		end
		used.Palm += countParts(Nature.Palm(folder, V(x, h, z), rng, rng:Range(0.95, 1.2), 1))
		trees.add(x, z, 4.5)
		stats.Palms += 1
	end
	for _, c in lists.Small do
		if used.Small >= JUNGLE_BUDGET.Small then
			break
		end
		local x, z, h = c[1], c[2], c[3]
		if small.hits(x, z, 2.6, 1.0) or trees.hits(x, z, 0.6, 1.0) or blocked(x, z, World, clear, 1.5) then
			continue
		end
		local s = rng:Range(0.9, 1.3)
		local r = rng:Next()
		local m
		if r < 0.36 then
			m = Nature.Fern(folder, V(x, h - 0.2, z), rng, s)
		elseif r < 0.66 then
			m = Nature.RedPlant(folder, V(x, h - 0.2, z), rng, s)
		elseif r < 0.86 then
			m = Nature.Hibiscus(folder, V(x, h - 0.4, z), rng, s)
		else
			m = Nature.Bush(folder, V(x, h - 0.5, z), rng, s)
		end
		used.Small += countParts(m)
		small.add(x, z, 2.6)
		stats.Bushes += 1
	end
end

function Nature.Build(parent: any, H: any, World: any, Noise: any, clear: { any })
	local root = P.folder(parent, "Nature")
	local stats = { Palms = 0, Trees = 0, Rocks = 0, Bushes = 0 }
	for _, island in World.Islands do
		local folder = P.folder(root, island.Name)
		local rng = Noise.Rng(island.Seed * 7919 + 17)
		local isMain = island.Kind == "Main"
		local function samplePoint(maxFrac: number)
			local a = rng:Range(0, math.pi * 2)
			local d = math.sqrt(rng:Next()) * island.Radius * maxFrac
			return island.X + math.cos(a) * d, island.Z + math.sin(a) * d
		end
		local function ok(x: number, z: number, margin: number): boolean
			local _, owner = H.GetHeight(x, z)
			if owner ~= island then
				return false
			end
			return not (isMain and blocked(x, z, World, clear, margin))
		end

		if isMain then
			kingshavenJungle(folder, island, H, World, Noise, clear, stats)
			continue -- Kingshaven's rocks and cliffs are built by MainIsland
		end

		local trees = newGrid(16)
		-- Palms: prefer beaches and gentle ground
		local target = math.floor(island.Palms * 0.72 + 0.5)
		local placed = 0
		local tries = 0
		while placed < target and tries < target * 30 do
			tries += 1
			local x, z = samplePoint(1.05)
			local h = H.GetHeight(x, z)
			if h > 2.6 and h < math.min(island.Height * 0.85, 45) and ok(x, z, 4) and H.GetSlope(x, z) < 0.55 and not trees.hits(x, z, 4, 1) then
				if h < 9 or rng:Next() < 0.45 then
					Nature.Palm(folder, V(x, h, z), rng, if island.Kind == "Rocky" then 0.85 else 1, 0)
					trees.add(x, z, 4)
					placed += 1
				end
			end
		end
		stats.Palms += placed

		-- Broadleaf trees inland
		local treeShare = if island.Kind == "Tropical" then 0.3 elseif island.Kind == "Atoll" then 0 else 0.12
		target = math.floor(island.Palms * treeShare + 0.5)
		placed, tries = 0, 0
		while placed < target and tries < target * 40 do
			tries += 1
			local x, z = samplePoint(0.8)
			local h = H.GetHeight(x, z)
			local s = rng:Range(0.8, 1.1)
			if h > 6 and ok(x, z, 6) and H.GetSlope(x, z) < 0.45 and not trees.hits(x, z, 7 * s, 1) then
				Nature.JungleTree(folder, V(x, h, z), rng, s, 0)
				trees.add(x, z, 7 * s)
				placed += 1
			end
		end
		stats.Trees += placed

		-- Rocks (some sit in the shallows): layered slabs in the island's rock colours
		local palette = ROCK_COLORS[island.RockMaterial] or ROCK_COLORS.Rock
		local rockMat = if island.RockMaterial == "Sandstone" or island.RockMaterial == "Limestone" then "Sandstone" else "Slate"
		placed, tries = 0, 0
		while placed < island.Rocks and tries < island.Rocks * 30 do
			tries += 1
			local x, z = samplePoint(1.15)
			local h = H.GetHeight(x, z)
			if h > -3 and ok(x, z, 3) then
				local size = if island.Kind == "Rocky" then rng:Range(6, 13) else rng:Range(4, 9)
				local cf = CF(x, h - size * 0.25, z) * Angles(0, rng:Range(0, math.pi * 2), 0)
				Nature.SlabStack(folder, cf, size * 1.3, size, size * rng:Range(0.5, 0.9), rng, palette, rockMat, false)
				placed += 1
			end
		end
		stats.Rocks += placed

		-- Undergrowth: ferns, red plants, hibiscus and bushes
		local count = math.floor(island.Palms * 0.5)
		placed, tries = 0, 0
		while placed < count and tries < count * 30 do
			tries += 1
			local x, z = samplePoint(0.95)
			local h = H.GetHeight(x, z)
			if h > 4 and h < 50 and ok(x, z, 1.5) and H.GetSlope(x, z) < 0.7 then
				local r = rng:Next()
				if r < 0.4 then
					Nature.Fern(folder, V(x, h - 0.2, z), rng)
				elseif r < 0.62 then
					Nature.RedPlant(folder, V(x, h - 0.2, z), rng)
				elseif r < 0.8 then
					Nature.Hibiscus(folder, V(x, h - 0.4, z), rng)
				else
					Nature.Bush(folder, V(x, h - 0.6, z), rng)
				end
				placed += 1
			end
		end
		stats.Bushes += placed

		-- Landmarks
		if island.Name == "Skull Rock" then
			local bestH, bx, bz = -math.huge, island.X, island.Z
			for _ = 1, 200 do
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
			for _ = 1, 30 do
				local x, z = samplePoint(0.6)
				local h = H.GetHeight(x, z)
				if h < -2 and h > -10 then
					Nature.Coral(folder, V(x, h - 0.5, z), rng)
				end
			end
		end
		if island.Name == "Smuggler's Bay" or island.Name == "Sunken Grove" or island.Name == "Thieves' Haven" then
			for _ = 1, 200 do
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
