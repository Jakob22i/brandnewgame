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

-- Palette (stylised, warm and saturated like the reference)
local FROND = { rgb(74, 158, 52), rgb(88, 170, 56), rgb(62, 144, 50), rgb(102, 180, 60) }
local CANOPY_DARK = { rgb(40, 110, 46), rgb(50, 122, 42), rgb(36, 102, 52), rgb(56, 118, 38) }
local CANOPY_MID = { rgb(66, 146, 50), rgb(78, 156, 46), rgb(60, 138, 60), rgb(86, 150, 42) }
local CANOPY_LIGHT = { rgb(110, 182, 62), rgb(126, 192, 66), rgb(100, 176, 74), rgb(140, 196, 70) }
local FERN = { rgb(58, 140, 52), rgb(74, 156, 50), rgb(48, 124, 56), rgb(88, 160, 46) }
local PALM_TRUNK = { rgb(176, 136, 92), rgb(148, 110, 74) }
local TREE_BARK = { rgb(112, 86, 64), rgb(98, 76, 60), rgb(124, 98, 72), rgb(132, 110, 86) }
local RED_LEAF = { rgb(206, 38, 52), rgb(228, 60, 70), rgb(186, 30, 64), rgb(240, 90, 80) }
local HIBISCUS = { rgb(236, 40, 70), rgb(255, 86, 132), rgb(255, 120, 60), rgb(250, 60, 110), rgb(255, 200, 70) }
local VINE = rgb(52, 120, 44)
Nature.VINES = { rgb(52, 122, 44), rgb(64, 138, 50), rgb(44, 108, 42), rgb(74, 146, 52) }
Nature.CANOPY_DARK = CANOPY_DARK

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

-- An ellipsoid (a part with a sphere mesh, so it can be squashed): leafy clumps, moss, drapes.
-- Decoration only: no collisions, no raycasts.
function Nature.Blob(parent: any, size: any, cf: any, props: { [string]: any })
	local merged: { [string]: any } = { Size = size, CFrame = cf, Mat = "Grass", CanCollide = false, CanQuery = false, CanTouch = false }
	for k, v in props do
		merged[k] = v
	end
	local part = P.part(parent, merged)
	local mesh = P.Instance.new("SpecialMesh")
	mesh.MeshType = P.Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end
local blob = Nature.Blob

-- Half of a pointed leaf (WedgePart): the straight edge runs along the spine from `a` (the
-- wide base) to `b` (the point); the blade reaches `width` towards `side`.
function Nature.HalfLeaf(parent: any, a: any, b: any, side: any, width: number, thickness: number, props: { [string]: any })
	local dir = (b - a).Unit
	local vY = side - dir * side:Dot(dir)
	if vY.Magnitude < 0.01 then
		vY = V(0, 1, 0) - dir * dir.Y
	end
	vY = vY.Unit
	local vZ = -dir
	local vX = vY:Cross(vZ)
	local merged: { [string]: any } = {
		Class = "WedgePart",
		Size = V(thickness, width, (b - a).Magnitude),
		CFrame = P.CFrame.fromMatrix((a + b) / 2 + vY * (width / 2), vX, vY, vZ),
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}
	for k, v in props do
		merged[k] = v
	end
	return P.part(parent, merged)
end
local halfLeaf = Nature.HalfLeaf

-- A whole pointed leaf from a to b: two halves folded down along the spine like a roof
-- (fold = how far the edges hang below the spine, 0..1)
local function foldedLeaf(parent: any, a: any, b: any, width: number, fold: number, props: { [string]: any })
	local dir = (b - a).Unit
	local right = dir:Cross(UP)
	if right.Magnitude < 0.05 then
		right = V(1, 0, 0)
	end
	right = right.Unit
	local down = right:Cross(dir).Unit * -1 -- below the blade
	for _, sd in { -1, 1 } do
		halfLeaf(parent, a, b, right * sd + down * fold, width / 2, 0.16, props)
	end
end
Nature.FoldedLeaf = foldedLeaf

-- Palm tree: curved, ringed trunk, layered drooping fronds and coconuts.
-- detail 1 = Kingshaven (about 36 parts), 0 = other islands (about 26 parts)
function Nature.Palm(parent: any, base: any, rng: any, scale: number?, detail: number?)
	local m = P.model(parent, "Palm")
	local s = scale or 1
	local full = (detail or 1) >= 1
	local height = rng:Range(18, 26) * s
	local lean = rng:Range(0, math.pi * 2)
	local leanDir = V(math.cos(lean), 0, math.sin(lean))
	local segments = if full then 5 else 4
	local segLen = height / segments
	local p0 = base - V(0, 1.2, 0)
	local tilt = rng:Range(0.0, 0.08)
	local bend = rng:Range(0.08, 0.16)
	local dir = UP
	for i = 1, segments do
		tilt += bend * (0.3 + i * 0.28)
		dir = (UP + leanDir * tilt).Unit
		local p1 = p0 + dir * segLen
		local d = (1.9 - (i - 1) / (segments - 1) * 0.75) * s
		P.beam(m, p0 - dir * 0.15, p1 + dir * 0.15, d, {
			Name = "Trunk",
			Mat = "Wood",
			Color = shade(PALM_TRUNK[i % 2 + 1], 1 + (i - 1) * 0.03),
			CanCollide = i <= 2,
		})
		p0 = p1
	end
	local top = p0 + dir * 0.3
	P.part(m, { Name = "Crown", Shape = "Ball", Size = V(2.2, 2.2, 2.2) * s, CFrame = CF(top), Mat = "Grass", Color = rgb(96, 116, 46), CanCollide = false })
	local fronds = if full then 7 else 5
	local spin = rng:Range(0, math.pi * 2)
	local base_color = pick(rng, FROND)
	for k = 1, fronds do
		local a = spin + (k / fronds) * math.pi * 2 + rng:Range(-0.22, 0.22)
		local out = V(math.cos(a), 0, math.sin(a))
		local young = k % 3 == 1 -- every third frond is younger and stands higher
		local color = shade(base_color, rng:Range(0.9, 1.1))
		local props = { Name = "Frond", Mat = "Grass", Color = color }
		local rise = math.rad(if young then rng:Range(34, 48) else rng:Range(10, 26))
		local droop = math.rad(if young then rng:Range(18, 34) else rng:Range(48, 72))
		local len1 = rng:Range(4.6, 5.6) * s * (if young then 0.85 else 1)
		local len2 = rng:Range(6.2, 8) * s * (if young then 0.85 else 1)
		local mid = top + (out * math.cos(rise) + UP * math.sin(rise)) * len1
		local tip = mid + (out * math.cos(droop) - UP * math.sin(droop)) * len2
		-- a long diamond-shaped frond, bent at its widest point
		local w = rng:Range(3.6, 4.4) * s
		foldedLeaf(m, mid, top, w, 0.45, { Name = "Frond", Mat = "Grass", Color = shade(color, 0.9) })
		foldedLeaf(m, mid, tip, w, 0.6, props)
	end
	for i = 1, if full then 2 else 1 do
		local ca = rng:Range(0, math.pi * 2)
		P.part(m, {
			Name = "Coconut",
			Shape = "Ball",
			Size = V(1.1, 1.1, 1.1) * s,
			CFrame = CF(top + V(math.cos(ca) * 0.9, -0.95, math.sin(ca) * 0.9) * s),
			Color = if i == 1 then rgb(104, 72, 38) else rgb(122, 140, 52),
			CanCollide = false,
		})
	end
	return m
end

-- Broadleaf jungle tree: twisted trunk with buttress roots, branches reaching out to
-- layered, rounded canopy pads (dark below, sunlit clumps on top).
-- detail 1 = about 17 parts, 0 = about 10 parts
function Nature.JungleTree(parent: any, base: any, rng: any, scale: number?, detail: number?)
	local m = P.model(parent, "JungleTree")
	local s = scale or 1
	local full = (detail or 1) >= 1
	local height = rng:Range(11, 16) * s
	local bark = pick(rng, TREE_BARK)
	local p0 = base - V(0, 1.5, 0)
	local a = rng:Range(0, math.pi * 2)
	local segs = 3
	for i = 1, segs do
		a += rng:Range(1.8, 2.6) -- the trunk twists back and forth
		local off = V(math.cos(a), 0, math.sin(a)) * rng:Range(0.9, 1.8) * s
		local p1 = p0 + V(0, (height + 1.5) / segs, 0) + off
		local d = (2.6 - (i - 1) * 0.5) * s
		P.beam(m, p0, p1 + (p1 - p0).Unit * 0.4, d, { Name = "Trunk", Mat = "Wood", Color = shade(bark, 1 + (i - 2) * 0.07) })
		p0 = p1
	end
	local top = p0
	if full then
		-- buttress roots
		local ra = rng:Range(0, math.pi * 2)
		for i = 1, 3 do
			ra += rng:Range(1.7, 2.5)
			local foot = base + V(math.cos(ra) * 3.2 * s, -0.7, math.sin(ra) * 3.2 * s)
			P.beam(m, base + V(0, 3.0 * s, 0), foot, 1.1 * s, { Name = "Root", Mat = "Wood", Color = shade(bark, 0.9) })
		end
	end
	local R = rng:Range(7.5, 9.5) * s
	local dark = pick(rng, CANOPY_DARK)
	local mid = pick(rng, CANOPY_MID)
	local light = pick(rng, CANOPY_LIGHT)
	if rng:Next() < 0.28 then
		-- a lime-green tree among the dark ones
		dark, mid, light = rgb(86, 146, 40), rgb(118, 174, 48), rgb(164, 206, 72)
	end
	local function pad(c: any, size: number, yaw: number, layered: boolean)
		blob(m, V(size * 2, size * 1.35, size * 1.85), CF(c) * Angles(0, yaw, 0), { Name = "Leaves", Color = shade(dark, rng:Range(0.92, 1.08)) })
		if layered then
			local hs = size * rng:Range(0.62, 0.74)
			blob(m, V(hs * 2, hs * 1.4, hs * 1.9), CF(c + V(rng:Range(-0.2, 0.2) * size, size * 0.42, rng:Range(-0.2, 0.2) * size)) * Angles(0, yaw + 0.6, 0), { Name = "Leaves", Color = shade(mid, rng:Range(0.95, 1.08)) })
		end
	end
	-- branches out to the side pads
	local nb = if full then 3 else 2
	local spin = rng:Range(0, math.pi * 2)
	for k = 1, nb do
		local ka = spin + k / nb * math.pi * 2 + rng:Range(-0.35, 0.35)
		local out = V(math.cos(ka), 0, math.sin(ka))
		local c = top + out * R * rng:Range(0.75, 0.95) + V(0, R * rng:Range(-0.12, 0.18), 0)
		P.beam(m, top - V(0, 1.2 * s, 0), c - V(0, R * 0.2, 0), 0.9 * s, { Name = "Branch", Mat = "Wood", Color = bark, CanCollide = false, CanQuery = false })
		pad(c, R * rng:Range(0.62, 0.76), ka, full)
	end
	-- the crown on top with a sunlit clump
	local crown = top + V(rng:Range(-0.15, 0.15) * R, R * 0.55, rng:Range(-0.15, 0.15) * R)
	pad(crown, R * rng:Range(0.85, 0.98), rng:Range(0, math.pi), true)
	if full then
		local tp = crown + V(rng:Range(-0.25, 0.25) * R, R * 0.55, rng:Range(-0.25, 0.25) * R)
		local ts = R * rng:Range(0.42, 0.52)
		blob(m, V(ts * 2, ts * 1.45, ts * 1.9), CF(tp) * Angles(0, rng:Range(0, math.pi), 0), { Name = "Leaves", Color = shade(light, rng:Range(0.95, 1.05)) })
		if rng:Next() < 0.55 then
			-- a hanging vine
			local va = rng:Range(0, math.pi * 2)
			local vp = top + V(math.cos(va) * R * 0.7, -R * 0.15, math.sin(va) * R * 0.7)
			local len = rng:Range(5, 9) * s
			blob(m, V(0.9, len, 0.9), CF(vp - V(0, len / 2, 0)), { Name = "Vine", Color = VINE })
		end
	end
	return m, R * 1.6
end

-- Fern: a fan of folded fronds arching out of the ground (5-6 fronds, 2 parts each)
function Nature.Fern(parent: any, pos: any, rng: any, scale: number?)
	local m = P.model(parent, "Fern")
	local s = scale or 1
	local n = rng:Int(4, 5)
	local spin = rng:Range(0, math.pi * 2)
	local color = pick(rng, FERN)
	for k = 1, n do
		local a = spin + k / n * math.pi * 2 + rng:Range(-0.3, 0.3)
		local out = V(math.cos(a), 0, math.sin(a))
		local el = math.rad(rng:Range(22, 46))
		local len = rng:Range(3.4, 4.8) * s
		local root = pos + V(0, 0.2, 0) + out * 0.3
		local tip = root + (out * math.cos(el) + UP * math.sin(el)) * len
		foldedLeaf(m, root, tip, rng:Range(1.6, 2.1) * s, 0.45, { Name = "Frond", Mat = "Grass", Color = shade(color, rng:Range(0.9, 1.1)) })
	end
	return m
end

-- Red tropical plant (ti plant): broad red leaves standing up and arching out
function Nature.RedPlant(parent: any, pos: any, rng: any, scale: number?)
	local m = P.model(parent, "RedPlant")
	local s = scale or 1
	local n = rng:Int(4, 5)
	local spin = rng:Range(0, math.pi * 2)
	local color = pick(rng, RED_LEAF)
	for k = 1, n do
		local a = spin + k / n * math.pi * 2 + rng:Range(-0.25, 0.25)
		local out = V(math.cos(a), 0, math.sin(a))
		local el = math.rad(rng:Range(42, 68))
		local len = rng:Range(3.4, 4.6) * s
		local root = pos + V(0, 0.2, 0)
		local tip = root + (out * math.cos(el) + UP * math.sin(el)) * len
		foldedLeaf(m, root, tip, rng:Range(1.5, 1.9) * s, 0.3, { Name = "Leaf", Mat = "SmoothPlastic", Color = shade(color, rng:Range(0.92, 1.08)) })
	end
	return m
end

-- Hibiscus bush: rounded leafy clumps dotted with big flowers (petal disc + yellow heart)
function Nature.Hibiscus(parent: any, pos: any, rng: any, scale: number?)
	local m = P.model(parent, "Hibiscus")
	local s = scale or 1
	local green = pick(rng, CANOPY_DARK)
	local r = rng:Range(2.0, 2.6) * s
	local c0 = pos + V(0, r * 0.45, 0)
	blob(m, V(r * 2.3, r * 1.6, r * 2.1), CF(c0) * Angles(0, rng:Range(0, math.pi), 0), { Name = "Leaves", Color = green })
	local oa = rng:Range(0, math.pi * 2)
	local c1 = pos + V(math.cos(oa) * r * 0.7, r * 0.6, math.sin(oa) * r * 0.7)
	blob(m, V(r * 1.6, r * 1.3, r * 1.5), CF(c1), { Name = "Leaves", Color = shade(green, 1.18) })
	local flower = pick(rng, HIBISCUS)
	for k = 1, 4 do
		local fa = oa + k * 1.6 + rng:Range(-0.3, 0.3)
		local el = rng:Range(0.25, 0.9)
		local n = V(math.cos(fa) * math.cos(el), math.sin(el), math.sin(fa) * math.cos(el))
		local c = c0 + V(n.X * r * 1.1, n.Y * r * 0.78, n.Z * r * 1.0)
		local disc = P.lookAt(c, c + n) * Angles(0, math.pi / 2, 0)
		P.part(m, { Name = "Flower", Shape = "Cylinder", Size = V(0.3, 2.1 * s, 2.1 * s), CFrame = disc, Mat = "SmoothPlastic", Color = flower, CanCollide = false, CanQuery = false, CanTouch = false })
		P.part(m, { Name = "Stamen", Shape = "Ball", Size = V(0.5, 0.5, 0.5) * s, CFrame = CF(c + n * 0.25), Mat = "SmoothPlastic", Color = rgb(255, 226, 90), CanCollide = false, CanQuery = false, CanTouch = false })
	end
	return m
end

-- Thicket: a big mass of jungle leaves (3 clumps) that fills the ground between trees
function Nature.Thicket(parent: any, pos: any, rng: any, R: number)
	local m = P.model(parent, "Thicket")
	local dark = pick(rng, CANOPY_DARK)
	local yaw = rng:Range(0, math.pi)
	local x, h, z = pos.X, pos.Y, pos.Z
	blob(m, V(R * 2.3, R * 1.3, R * 2.0), CF(x, h + R * 0.25, z) * Angles(0, yaw, 0), { Name = "Leaves", Color = shade(dark, rng:Range(0.92, 1.08)) })
	local oa = rng:Range(0, math.pi * 2)
	blob(m, V(R * 1.6, R * 1.1, R * 1.5), CF(x + math.cos(oa) * R * 0.35, h + R * 0.7, z + math.sin(oa) * R * 0.35) * Angles(0, yaw + 0.8, 0), { Name = "Leaves", Color = pick(rng, CANOPY_MID) })
	blob(m, V(R * 0.95, R * 0.65, R * 0.9), CF(x - math.cos(oa) * R * 0.2, h + R * 1.12, z - math.sin(oa) * R * 0.2), { Name = "Leaves", Color = pick(rng, CANOPY_LIGHT) })
	return m
end

-- Leafy bush (2-3 rounded clumps)
function Nature.Bush(parent: any, pos: any, rng: any, scale: number?)
	local m = P.model(parent, "Bush")
	local s = scale or 1
	local green = pick(rng, CANOPY_MID)
	for i = 1, rng:Int(2, 3) do
		local r = rng:Range(2.4, 3.6) * s
		blob(m, V(r * 2, r * 1.3, r * 1.8), CF(pos + V(rng:Range(-1.6, 1.6), r * 0.35, rng:Range(-1.6, 1.6))) * Angles(0, rng:Range(0, math.pi), 0), { Name = "Leaves", Color = shade(green, rng:Range(0.85, 1.15) + (i - 1) * 0.06) })
	end
	return m
end

-- A slab of layered sandstone with a rounded top edge along the front (and the back unless
-- frontOnly): blocks plus a half-buried cylinder, so the slab reads soft like the
-- reference rocks. cf = slab centre, X = length, -Z = front. Returns the number of parts.
function Nature.RoundSlab(parent: any, cf: any, length: number, thick: number, depth: number, color: any, material: string, frontOnly: boolean?): number
	local r = math.min(thick * 0.36, depth * 0.3, 3)
	local backR = if frontOnly then 0 else r
	-- lower block (full depth) and upper block (set back from the rounded edges)
	P.part(parent, { Name = "Slab", Size = V(length, thick - r, depth), CFrame = cf * CF(0, -r / 2, 0), Mat = material, Color = color })
	P.part(parent, { Name = "Slab", Size = V(length, r * 1.02, depth - r - backR), CFrame = cf * CF(0, thick / 2 - r / 2, (r - backR) / 2), Mat = material, Color = color })
	local n = 2
	for _, sd in (if frontOnly then { -1 } else { -1, 1 }) :: { number } do
		P.part(parent, { Name = "Slab", Shape = "Cylinder", Size = V(length, r * 2, r * 2), CFrame = cf * CF(0, thick / 2 - r, sd * (depth / 2 - r)), Mat = material, Color = shade(color, 1.03) })
		n += 1
	end
	return n
end

-- A stack of rounded slabs (layered sandstone boulder). cf = base centre.
-- Each slab is smaller, shifted and turned a little against the one below.
-- Returns the model and the height of its top.
function Nature.SlabStack(parent: any, cf: any, width: number, depth: number, height: number, rng: any, palette: { any }, material: string, cap: boolean?, rounded: boolean?)
	local m = P.model(parent, "RockStack")
	local y = 0
	local w, d = width, depth
	local layer = 0
	local ox, oz = 0, 0
	local yaw = 0
	while y < height - 0.5 do
		layer += 1
		local th = math.min(rng:Range(0.24, 0.36) * math.max(width, 8), height - y + 0.6, d * 0.8)
		yaw += rng:Range(-0.4, 0.4)
		ox += rng:Range(-0.1, 0.1) * w
		oz += rng:Range(-0.1, 0.1) * d
		local color = shade(palette[(layer - 1) % #palette + 1], rng:Range(0.94, 1.04))
		local lcf = cf * CF(ox, y + th / 2, oz) * Angles(rng:Range(-0.05, 0.05), yaw, rng:Range(-0.05, 0.05))
		if rounded then
			Nature.RoundSlab(m, lcf, w, th, d, color, material)
		else
			-- two boxes turned 45 degrees against each other read as a rounder stone
			P.part(m, { Name = "Slab", Size = V(w, th, d), CFrame = lcf, Mat = material, Color = color })
			P.part(m, { Name = "Slab", Size = V(w * 0.84, th * rng:Range(0.85, 1.0), d * 0.84), CFrame = lcf * Angles(0, math.pi / 4, 0), Mat = material, Color = shade(color, 0.96) })
		end
		y += th * 0.92
		w *= rng:Range(0.72, 0.9)
		d *= rng:Range(0.74, 0.92)
	end
	if cap then
		blob(m, V(w * 1.05, 1.6, d * 1.05), cf * CF(ox, y + 0.1, oz) * Angles(0, yaw + rng:Range(-0.2, 0.2), 0), { Name = "GrassCap", Mat = "LeafyGrass", Color = pick(rng, Nature.GRASS_CAP), CanCollide = true, CanQuery = true })
		y += 0.6
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
local JUNGLE_BUDGET = { Tree = 1900, Palm = 1150, Small = 400, Mound = 240, Thicket = 900 }

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
					table.insert(lists.Palm, { x, z, h, 0.5 + r * 0.6, slope, pd, true })
					table.insert(lists.Small, { x, z, h, 0.4 + r * 0.6, slope })
				end
			elseif beach then
				table.insert(lists.Palm, { x, z, h, 0.8 + r * 0.7, slope, pd })
				table.insert(lists.Small, { x, z, h, 0.3 + r * 0.5, slope })
			else
				table.insert(lists.Tree, { x, z, h, grove * 0.45 + near * 0.5 + r * 0.6, slope, pd })
				table.insert(lists.Palm, { x, z, h, near * 0.5 + (1 - grove) * 0.3 + r * 0.6, slope, pd })
				table.insert(lists.Small, { x, z, h, near * 1.2 + grove * 0.2 + r * 0.4, slope })
			end
		end
	end
	for _, list in lists do
		table.sort(list, function(a, b)
			return a[4] > b[4]
		end)
	end
	local used = { Tree = 0, Palm = 0, Small = 0, Mound = 0, Thicket = 0 }
	-- broadleaf trees first: they make the canopy
	for _, c in lists.Tree do
		if used.Tree >= JUNGLE_BUDGET.Tree then
			break
		end
		local x, z, h = c[1], c[2], c[3]
		local s = rng:Range(1.1, 1.45)
		local lh = World.Lighthouse
		if (x - lh.X) ^ 2 + (z - lh.Z) ^ 2 < (lh.SummitRadius - 4) ^ 2 then
			continue -- keep the lighthouse yard open
		end
		if c[5] > 0.42 or trees.hits(x, z, 7.5 * s, 0.8) or blocked(x, z, World, clear, 5) then
			continue
		end
		-- full detail where people walk, lighter trees deep in the jungle
		used.Tree += countParts(Nature.JungleTree(folder, V(x, h, z), rng, s, if c[6] < 34 then 1 else 0))
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
			blob(m, V(r * 1.3, r * 0.75, r * 1.15), CF(x + rng:Range(-2.5, 2.5), h + r * 0.05, z + rng:Range(-2.5, 2.5)) * Angles(0, rng:Range(0, math.pi), 0), { Name = "Leaves", Color = shade(green, rng:Range(0.9, 1.15)) })
		end
		used.Mound += 2
		small.add(x, z, 4)
	end
	-- thickets: big leafy masses that fill the jungle away from the paths (cheap canopy)
	local far = table.clone(lists.Tree)
	for _, c in far do
		c[7] = c[6] + rng:Range(0, 50)
	end
	table.sort(far, function(a, b)
		return a[7] > b[7]
	end)
	for _, c in far do
		if used.Thicket >= JUNGLE_BUDGET.Thicket then
			break
		end
		local x, z, h = c[1], c[2], c[3]
		local R = rng:Range(7, 11)
		if c[5] > 0.45 or trees.hits(x, z, R * 1.1, 0.8) or blocked(x, z, World, clear, R * 0.8) then
			continue
		end
		Nature.Thicket(folder, V(x, h, z), rng, R)
		used.Thicket += 3
		trees.add(x, z, R * 1.1)
	end
	for _, c in lists.Palm do
		if used.Palm >= JUNGLE_BUDGET.Palm then
			break
		end
		local x, z, h = c[1], c[2], c[3]
		if c[5] > 0.42 or trees.hits(x, z, 4.5, 1.0) or blocked(x, z, World, clear, 4) then
			continue
		end
		-- palms in the jungle grow tall enough to poke out of the canopy
		local ps = if h > 9 and not c[8] then rng:Range(1.2, 1.5) else rng:Range(0.95, 1.25)
		used.Palm += countParts(Nature.Palm(folder, V(x, h, z), rng, ps, if c[6] < 30 then 1 else 0))
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
		local groves = {}
		-- Palms: prefer beaches and gentle ground
		local target = math.floor(island.Palms * 0.3 + 0.5)
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
					table.insert(groves, { x, z })
					placed += 1
				end
			end
		end
		stats.Palms += placed

		-- Broadleaf trees inland
		local treeShare = if island.Kind == "Tropical" then 0.36 elseif island.Kind == "Atoll" then 0 else 0.14
		target = math.floor(island.Palms * treeShare + 0.5)
		placed, tries = 0, 0
		while placed < target and tries < target * 40 do
			tries += 1
			local x, z = samplePoint(0.8)
			local h = H.GetHeight(x, z)
			local s = rng:Range(0.95, 1.25)
			if h > 6 and ok(x, z, 6) and H.GetSlope(x, z) < 0.45 and not trees.hits(x, z, 7 * s, 1) then
				Nature.JungleTree(folder, V(x, h, z), rng, s, 0)
				trees.add(x, z, 7 * s)
				table.insert(groves, { x, z })
				placed += 1
			end
		end
		stats.Trees += placed

		-- Thickets: cheap masses of jungle that make the islands look lush
		local thicketShare = if island.Kind == "Tropical" then 2.0 elseif island.Kind == "Rocky" then 0.5 elseif island.Kind == "Atoll" then 0.4 else 0.6
		target = math.floor(island.Palms * thicketShare + 0.5)
		placed, tries = 0, 0
		while placed < target and tries < target * 40 do
			tries += 1
			local x, z = samplePoint(0.85)
			if #groves > 0 and rng:Next() < 0.6 then
				-- most thickets gather around the trees and palms into groves
				local g = groves[rng:Int(1, #groves)]
				local a = rng:Range(0, math.pi * 2)
				local d = rng:Range(6, 22)
				x, z = g[1] + math.cos(a) * d, g[2] + math.sin(a) * d
			end
			local h = H.GetHeight(x, z)
			local R = rng:Range(5.5, 8.5)
			if h > 4.5 and ok(x, z, 4) and H.GetSlope(x, z) < 0.6 and not trees.hits(x, z, R, 0.75) then
				Nature.Thicket(folder, V(x, h - 0.5, z), rng, R)
				trees.add(x, z, R)
				placed += 1
			end
		end

		-- Rocks (some sit in the shallows): layered slabs in the island's rock colours
		local palette = ROCK_COLORS[island.RockMaterial] or ROCK_COLORS.Rock
		local rockMat = if island.RockMaterial == "Sandstone" or island.RockMaterial == "Limestone" then "Sandstone" else "Slate"
		placed, tries = 0, 0
		local rockTarget = math.floor(island.Rocks * 0.8 + 0.5)
		while placed < rockTarget and tries < rockTarget * 30 do
			tries += 1
			local x, z = samplePoint(1.15)
			local h = H.GetHeight(x, z)
			if h > -3 and ok(x, z, 3) then
				local size = if island.Kind == "Rocky" then rng:Range(7, 14) else rng:Range(5, 10)
				local cf = CF(x, h - size * 0.25, z) * Angles(0, rng:Range(0, math.pi * 2), 0)
				Nature.SlabStack(folder, cf, size * 1.3, size, size * rng:Range(0.5, 0.9), rng, palette, rockMat, h > 4 and rng:Next() < 0.5)
				placed += 1
			end
		end
		stats.Rocks += placed

		-- Undergrowth: ferns, red plants, hibiscus and bushes
		local count = math.floor(island.Palms * 0.25)
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
