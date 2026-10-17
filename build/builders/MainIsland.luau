-- Kingshaven's landscape dressing (Workspace.MainIsland):
--   * stacked sandstone slabs with grass caps, overgrowth and hanging vines on the terrace
--     cliffs, the lagoon walls and the sea cliffs (found by scanning the Heightmap)
--   * boulders on the terraces and sea stacks off the cliff coast
--   * path furniture: plank stairs on the steep trail ramps, raised plank walkways,
--     a rope bridge, rope fences along drops, lanterns and signposts whose arrow boards
--     point along the paths to every shop (routes found on the path network)
-- Returns the model; adds keep-clear zones to `clear` so the jungle leaves room.
local P = require("./Parts")
local Nature = require("./Nature")

local V = P.Vector3.new
local CF = P.CFrame.new
local Angles = P.CFrame.Angles
local rgb = P.rgb
local UP = V(0, 1, 0)

local MainIsland = {}

local WOOD = rgb(138, 98, 62)
local DARK_WOOD = rgb(86, 60, 40)
local PLANKS = { rgb(160, 120, 78), rgb(146, 106, 68), rgb(170, 130, 86), rgb(136, 98, 64) }
local ROPE = rgb(200, 176, 128)
local IRON = rgb(52, 48, 50)
local WARM = rgb(255, 190, 110)
local VINES = { rgb(52, 122, 44), rgb(64, 138, 50), rgb(44, 108, 42), rgb(74, 146, 52) }
local SIGN_TEXT = rgb(246, 232, 200)

-- Part budgets (Kingshaven as a whole stays under ~7000 parts with the jungle)
local CLIFF_BUDGET = 2700 -- the town bowl first, then the terrace cliffs and the lagoon walls
local COAST_BUDGET = 440 -- sea cliffs
local BOULDERS = 7
local SEA_STACKS = 7
local LANDMARKS = 7

local function pick(rng: any, list: { any })
	return list[rng:Int(1, #list)]
end

local function flat(v: any)
	return V(v.X, 0, v.Z)
end

-- Frame at `pos` whose -Z (LookVector) is `forward` and Y is up (forward must be horizontal)
local function frame(pos: any, forward: any)
	local f = flat(forward).Unit
	local right = f:Cross(UP)
	return P.CFrame.fromMatrix(pos, right, UP, -f)
end

-- Cliff formations -------------------------------------------------------------------------

-- Stacked, rounded sandstone slabs on a cliff face. foot = cliff foot (on the lower ground),
-- n = outward (downhill) direction, yb/yt = bottom/top heights, run = horizontal run of the
-- cliff, capColor = colour of the grass on the terrace above (the cap blends into it).
local function cliffRock(parent: any, rng: any, foot: any, n: any, yb: number, yt: number, run: number, width: number, capColor: any, noCap: boolean?): number
	local m = P.model(parent, "CliffRock")
	local cf = frame(V(foot.X, yb, foot.Z), n)
	local height = yt - yb
	local depth = run + rng:Range(4, 6)
	local layers = math.max(1, math.floor((height + 2) / math.max(5.5, height / 5) + 0.5))
	local layerT = (height + 2) / layers
	local y = -2
	local maxOut = 0
	local count = 0
	local shift = 0
	for i = 1, layers do
		local th = layerT * rng:Range(0.85, 1.15)
		if i == layers then
			th = height - 0.2 - y
		end
		-- layers step back as they rise, each juts out a little differently
		local out = rng:Range(-0.6, 1.8) + (if i == 1 then 1.2 else 0) - (i - 1) * 0.35
		maxOut = math.max(maxOut, out)
		shift += rng:Range(-0.08, 0.08) * width
		local w = width * rng:Range(0.82, 1.04)
		local color = Nature.Shade(Nature.SANDSTONE[(i + rng:Int(0, 2)) % #Nature.SANDSTONE + 1], rng:Range(0.95, 1.05))
		local d = depth + out
		local lcf = cf * CF(shift, y + th / 2, (depth - out) / 2) * Angles(rng:Range(-0.015, 0.015), rng:Range(-0.08, 0.08), rng:Range(-0.025, 0.025))
		count += Nature.RoundSlab(m, lcf, w, th + 0.1, d, color, "Sandstone", true)
		if th > 3 and rng:Next() < 0.28 then
			-- a rounded boulder bulging out of this layer
			local bw = w * rng:Range(0.22, 0.4)
			local bOut = out + rng:Range(1.0, 2.2)
			maxOut = math.max(maxOut, bOut)
			local bcf = cf * CF(shift + rng:Range(-0.3, 0.3) * width, y + th * 0.45, (5 - bOut) / 2) * Angles(0, rng:Range(-0.25, 0.25), 0)
			count += Nature.RoundSlab(m, bcf, bw, th * rng:Range(0.7, 0.92), 5 + bOut, Nature.Shade(color, rng:Range(0.92, 1.06)), "Sandstone", true)
		end
		y += th
	end
	-- a rounded lip of grass hanging over the edge, flush with the terrace above (low steps
	-- keep their bare rounded stone: a flat grass plate on them reads as a floating slab)
	local capOut = maxOut + 0.4
	-- (nor do the lower tiers of a stepped wall, where more cliff rises right behind the lip)
	if height >= 13 and not noCap then
		local capW = width * rng:Range(0.9, 1.0)
		local capD = capOut + 4
		local capCF = cf * CF(shift * 0.5, height - 0.15, -capOut + capD / 2) * Angles(0, rng:Range(-0.04, 0.04), 0)
		P.part(m, { Name = "GrassCap", Size = V(capW, 1.2, capD - 1.4), CFrame = capCF * CF(0, -0.2, 0.7), Mat = "LeafyGrass", Color = capColor })
		Nature.Blob(m, V(capW + 0.6, 2.0, 3.4), capCF * CF(0, -0.45, -capD / 2 + 1.5), { Name = "GrassCap", Mat = "LeafyGrass", Color = Nature.Shade(capColor, 0.97), CanCollide = true, CanQuery = true })
		count += 2
	end
	-- ivy spilling over the lip: hanging curtains of overlapping leafy clumps that taper
	-- downwards (some long like vines)
	local curtains = if width > 18 then rng:Int(0, 2) else rng:Int(0, 1)
	for _ = 1, curtains do
		local cx = rng:Range(-0.4, 0.4) * width
		local cw = rng:Range(4, 8)
		local long = height > 12 and rng:Next() < 0.4
		local len = if long then math.min(height * rng:Range(0.45, 0.7), 14) else math.min(height * 0.4, rng:Range(2.5, 4.5))
		local pieces = if long then 2 else 1
		local y = height + 0.4
		local color = pick(rng, VINES)
		for k = 1, pieces do
			local ph = len / pieces * 1.5
			local pw = cw * (1 - (k - 1) * 0.4)
			Nature.Blob(m, V(pw, ph, 1.1), cf * CF(cx + rng:Range(-0.5, 0.5), y - ph / 2, -capOut + 0.55 + k * 0.1), { Name = "Ivy", Mat = "LeafyGrass", Color = Nature.Shade(color, 1 - (k - 1) * 0.06) })
			y -= len / pieces
			count += 1
		end
	end
	return count
end
MainIsland.CliffRock = cliffRock

-- A tall pillar of stacked rounded slabs (sea stacks and landmark rocks): chunky layers of
-- similar size, each turned and shifted a little, with a grass cap and a vine or two.
-- Returns the part count and the height of the cap.
local function rockPillar(parent: any, base: any, width: number, height: number, rng: any): (number, number)
	local m = P.model(parent, "RockPillar")
	local y = 0
	local layer = 0
	local yaw = rng:Range(0, math.pi * 2)
	local ox, oz = 0, 0
	local la = rng:Range(0, math.pi * 2)
	local drift = rng:Range(0, 0.05) * width
	local w, d = width, width
	local count = 0
	while y < height - 0.6 do
		layer += 1
		local t = y / height
		local th = math.min(rng:Range(0.3, 0.45) * width, height - y + 0.4)
		w = width * (0.82 + 0.28 * math.sin(math.pi * math.min(1, t * 0.8 + 0.25))) * rng:Range(0.9, 1.05)
		d = w * rng:Range(0.7, 0.92)
		yaw += math.pi / 2 + rng:Range(-0.35, 0.35) -- alternate the rounded sides
		ox += math.cos(la) * drift + rng:Range(-0.05, 0.05) * width
		oz += math.sin(la) * drift + rng:Range(-0.05, 0.05) * width
		local color = Nature.Shade(Nature.SANDSTONE[(layer + rng:Int(0, 2)) % #Nature.SANDSTONE + 1], rng:Range(0.94, 1.04))
		local cf = CF(base + V(ox, y + th / 2, oz)) * Angles(rng:Range(-0.03, 0.03), yaw, rng:Range(-0.03, 0.03))
		count += Nature.RoundSlab(m, cf, w, math.min(th + 0.1, d * 0.9), d, color, "Sandstone")
		y += th
	end
	local capCF = CF(base + V(ox, y + 0.2, oz)) * Angles(0, yaw + rng:Range(-0.15, 0.15), 0)
	Nature.Blob(m, V(w * 0.95, 2.2, d * 0.95), capCF, { Name = "GrassCap", Mat = "LeafyGrass", Color = pick(rng, Nature.GRASS_CAP), CanCollide = true, CanQuery = true })
	count += 1
	for _ = 1, rng:Int(1, 2) do
		local va = rng:Range(0, math.pi * 2)
		local len = math.min(height * rng:Range(0.25, 0.5), 14)
		local r = math.max(w, d) * 0.5
		Nature.Blob(m, V(rng:Range(1.4, 2.4), len, 1), CF(base + V(ox + math.cos(va) * r, y - len / 2, oz + math.sin(va) * r)) * Angles(0, -va, 0), { Name = "Vine", Mat = "LeafyGrass", Color = pick(rng, VINES) })
		count += 1
	end
	return count, y + 0.9
end
MainIsland.RockPillar = rockPillar

local function buildCliffs(model: any, island: any, H: any, World: any, rng: any, clear: { any })
	local folder = P.folder(model, "Cliffs")
	local GRID = 4
	local R = island.Radius * 1.14
	local n = math.floor(R * 2 / GRID)
	local x0, z0 = island.X - R, island.Z - R
	local hs: { { number } } = {}
	for ix = 0, n do
		local row = {}
		for iz = 0, n do
			local h, owner = H.GetHeight(x0 + ix * GRID, z0 + iz * GRID)
			row[iz] = if owner == island then h else -60
		end
		hs[ix] = row
	end
	-- candidate cells on steep ground
	local candidates = {}
	for ix = 1, n - 1 do
		for iz = 1, n - 1 do
			local h = hs[ix][iz]
			if h > -2 then
				local gx = (hs[ix + 1][iz] - hs[ix - 1][iz]) / (2 * GRID)
				local gz = (hs[ix][iz + 1] - hs[ix][iz - 1]) / (2 * GRID)
				local g = math.sqrt(gx * gx + gz * gz)
				if g > 0.9 and g < 30 then
					table.insert(candidates, { x0 + ix * GRID, z0 + iz * GRID, -gx / g, -gz / g, rng:Next() })
				end
			end
		end
	end
	-- walk along the slope to find the foot and the top edge of each cliff
	local function walk(x: number, z: number, dx: number, dz: number, sign: number): (number, number, number, number)
		local hPrev = H.GetHeight(x, z)
		local d = 0
		while d < 36 do
			d += 1.5
			local h = H.GetHeight(x + dx * d * sign, z + dz * d * sign)
			if (h - hPrev) * -sign < 0.3 then
				return x + dx * (d - 1.5) * sign, z + dz * (d - 1.5) * sign, hPrev, d - 1.5
			end
			hPrev = h
		end
		return x + dx * d * sign, z + dz * d * sign, hPrev, d
	end
	local segs = {}
	for _, path in World.Paths do
		for i = 1, #path.Points - 1 do
			table.insert(segs, { path.Points[i], path.Points[i + 1] })
		end
	end
	local function nearPath(x: number, z: number): boolean
		for _, sg in segs do
			local a, b = sg[1], sg[2]
			local vx, vz = b[1] - a[1], b[2] - a[2]
			local len2 = vx * vx + vz * vz
			local t = math.clamp(((x - a[1]) * vx + (z - a[2]) * vz) / len2, 0, 1)
			if (a[1] + vx * t - x) ^ 2 + (a[2] + vz * t - z) ^ 2 < 45 * 45 then
				return true
			end
		end
		return false
	end
	local town = World.Town
	local lagoon = World.Lagoon
	local pool = World.Pool
	-- the town bowl (the basin, its ledges and the walls around it) is dressed first, and more
	-- densely: there the rocks hug the cliff feet right behind the buildings, so only the solid
	-- footprints, the cores of the keep-clear zones and the paths themselves keep them out
	local basin = World.Basin
	local function inBowl(x: number, z: number): boolean
		return z < 300 and (x - basin.X) ^ 2 + (z - basin.Z) ^ 2 < (basin.Radius + 60) ^ 2
	end
	local function blockedCore(x: number, z: number): boolean
		for _, c in clear do
			local dx, dz = x - c.X, z - c.Z
			if c.Hx then
				if c.Solid and dx * dx + dz * dz < c.R * c.R then
					local lx = dx * c.C - dz * c.S
					local lz = dx * c.S + dz * c.C
					if math.abs(lx) < c.Hx and math.abs(lz) < c.Hz then
						return true
					end
				end
			else
				local r = c.Core or c.R * 0.6
				if dx * dx + dz * dz < r * r then
					return true
				end
			end
		end
		for _, path in World.Paths do
			local reach = path.Width / 2 + 1.5
			for i = 1, #path.Points - 1 do
				local a, b = path.Points[i], path.Points[i + 1]
				local vx, vz = b[1] - a[1], b[2] - a[2]
				local len2 = vx * vx + vz * vz
				local t = if len2 > 0 then math.clamp(((x - a[1]) * vx + (z - a[2]) * vz) / len2, 0, 1) else 0
				if (a[1] + vx * t - x) ^ 2 + (a[2] + vz * t - z) ^ 2 < reach * reach then
					return true
				end
			end
		end
		return false
	end
	local spots = {}
	for _, c in candidates do
		local fx, fz, fh, dDown = walk(c[1], c[2], c[3], c[4], 1)
		local tx, tz, th, dUp = walk(c[1], c[2], c[3], c[4], -1)
		local height = th - fh
		if height >= 4 then
			-- the town's ledges and the pool walls come first (they frame every view of the town)
			local dPool = math.sqrt((c[1] - pool.X) ^ 2 + (c[2] - pool.Z - 30) ^ 2)
			local townScore = (if dPool < 190 then 40 - dPool * 0.08 else 0) + (if inBowl(c[1], c[2]) then 40 else 0)
			table.insert(spots, { Fx = fx, Fz = fz, Fh = fh, Th = th, Run = dDown + dUp, Nx = c[3], Nz = c[4], Mx = (fx + tx) / 2, Mz = (fz + tz) / 2, Height = height, Score = math.min(height, 16) + c[5] * 12 + townScore + (if nearPath(c[1], c[2]) then 14 else 0) + (if (c[1] - town.X) ^ 2 + (c[2] - town.Z) ^ 2 < (town.Radius + 130) ^ 2 then 10 else 0) + (if lagoon and (c[1] - lagoon.X) ^ 2 + (c[2] - lagoon.Z) ^ 2 < (lagoon.Radius + 40) ^ 2 then 16 else 0) })
		end
	end
	table.sort(spots, function(a, b)
		return a.Score > b.Score
	end)
	local placed = {}
	local parts = 0
	local count = 0
	-- landmark rocks: a few big pillars rising out of the tallest inland cliffs
	local landmarks = {}
	for _, s in spots do
		if #landmarks >= LANDMARKS then
			break
		end
		if s.Height < 12 or s.Fh < 10 or s.Height > 26 then
			continue
		end
		local far = true
		for _, l in landmarks do
			if (l[1] - s.Mx) ^ 2 + (l[2] - s.Mz) ^ 2 < 120 * 120 then
				far = false
				break
			end
		end
		if not far or (s.Mx - town.X) ^ 2 + (s.Mz - town.Z) ^ 2 < (town.Radius + 20) ^ 2 then
			continue
		end
		if Nature.Blocked(s.Mx, s.Mz, World, clear, 16) or Nature.Blocked(s.Fx + s.Nx * 6, s.Fz + s.Nz * 6, World, clear, 10) then
			continue
		end
		local width = rng:Range(15, 21)
		local base = V(s.Fx - s.Nx * (width * 0.25), s.Fh - 1.5, s.Fz - s.Nz * (width * 0.25))
		local n, _ = rockPillar(folder, base, width, s.Height + rng:Range(10, 20), rng)
		parts += n
		count += 1
		table.insert(landmarks, { s.Mx, s.Mz })
		table.insert(placed, { s.Mx, s.Mz, width * 1.3 })
		table.insert(clear, { X = base.X, Z = base.Z, R = width * 0.7 })
	end
	local coastParts = 0
	for _, s in spots do
		-- (the walls of the town pool count as the bowl, not as sea cliffs)
		local coast = s.Fh < 2 and not inBowl(s.Mx, s.Mz)
		if (coast and (coastParts >= COAST_BUDGET or s.Height < 9)) or (not coast and (parts >= CLIFF_BUDGET or s.Height < 6)) then
			continue
		end
		-- the towering walls get the biggest blocks (fewer, larger pieces)
		local width = if s.Height > 34 then rng:Range(32, 42) elseif s.Height > 20 then rng:Range(24, 32) else rng:Range(15, 23)
		local bowlSpot = not coast and inBowl(s.Mx, s.Mz)
		local spacing = if bowlSpot then 0.36 else 0.42
		-- (rocks on different tiers of a stepped wall do not crowd each other: only those whose
		-- height ranges overlap by more than a third count)
		local tooClose = false
		for _, p in placed do
			local need = (width + p[3]) * spacing
			if (p[1] - s.Mx) ^ 2 + (p[2] - s.Mz) ^ 2 < need * need then
				local overlap = math.min(s.Th, p[5] or math.huge) - math.max(s.Fh, p[4] or -math.huge)
				if overlap > math.min(s.Th - s.Fh, (p[5] or math.huge) - (p[4] or -math.huge)) / 3 then
					tooClose = true
					break
				end
			end
		end
		if tooClose then
			continue
		end
		-- the footprint must stay off the paths and out of the keep-clear zones
		local nx, nz = s.Nx, s.Nz
		local lx, lz = -nz, nx
		local depth = s.Run + 7
		-- (in the bowl only the face and its top edge are tested, in studs from the foot: the
		-- rest of the rock is buried in the cliff; where the full width does not fit, beside a
		-- waterfall or a path, a narrower rock shifted along the cliff is tried)
		local along = if bowlSpot then { -0.5, -0.25, 0, 0.25, 0.5 } else { -0.5, 0, 0.5 }
		local reach = if bowlSpot then { -1.5, s.Run * 0.5, s.Run + 2 } else { -0.5 * depth, 0.2 * depth, depth }
		local tries = if bowlSpot then { { 1, 0 }, { 0.6, 0 }, { 0.6, 0.25 }, { 0.6, -0.25 }, { 0.4, 0.38 }, { 0.4, -0.38 } } else { { 1, 0 } }
		local full = width
		local shift = nil
		for _, try in tries do
			local w, sh = full * try[1], full * try[2]
			local blockedHere = false
			for _, a in along do
				for _, b in reach do
					local px = s.Fx + lx * (a * w + sh) - nx * b
					local pz = s.Fz + lz * (a * w + sh) - nz * b
					if if bowlSpot then blockedCore(px, pz) else Nature.Blocked(px, pz, World, clear, 3) then
						blockedHere = true
						break
					end
				end
				if blockedHere then
					break
				end
			end
			if not blockedHere then
				width, shift = w, sh
				break
			end
		end
		if shift == nil then
			continue
		end
		local fx, fz = s.Fx + lx * shift, s.Fz + lz * shift
		-- the lowest ground along the foot (so the slabs never float) and the lowest top
		-- edge along the width (so they never stick up out of the terrace)
		local yb = s.Fh
		local yt = s.Th
		local tx, tz = fx - nx * (s.Run + 2.5), fz - nz * (s.Run + 2.5)
		local lopsided = false
		for _, a in { -0.45, 0.45 } do
			yb = math.min(yb, (H.GetHeight(fx + lx * a * width + nx * 1.5, fz + lz * a * width + nz * 1.5)))
			local top = H.GetHeight(tx + lx * a * width, tz + lz * a * width)
			if top < s.Th - 3 then
				lopsided = true
			end
			yt = math.min(yt, top)
		end
		if lopsided then
			width *= 0.6
			yt = s.Th
		end
		local capMat = H.GetMaterial(tx, tz, s.Th, 0, island)
		local capRgb = World.TerrainColors[if capMat == "Grass" or capMat == "Sand" then capMat else "LeafyGrass"]
		local capColor = rgb(capRgb[1], capRgb[2], capRgb[3])
		local tier = H.GetHeight(tx - nx * 5, tz - nz * 5) > yt + 3
		local n = cliffRock(folder, rng, V(fx + nx * 0.8, 0, fz + nz * 0.8), V(nx, 0, nz), yb, yt, s.Run + 0.8, width, capColor, tier)
		if coast then
			coastParts += n
		else
			parts += n
		end
		count += 1
		table.insert(placed, { s.Mx + lx * shift, s.Mz + lz * shift, width, s.Fh, s.Th })
	end
	return parts + coastParts, count
end

-- Boulders and sea stacks ---------------------------------------------------------------------

local function buildRocks(model: any, island: any, H: any, World: any, rng: any, clear: { any })
	local folder = P.folder(model, "Rocks")
	local parts = 0
	local function add(m: any)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
	end
	-- boulders on the terraces and beaches
	local placed, tries = 0, 0
	while placed < BOULDERS and tries < 4000 do
		tries += 1
		local a = rng:Range(0, math.pi * 2)
		local d = math.sqrt(rng:Next()) * island.Radius
		local x, z = island.X + math.cos(a) * d, island.Z + math.sin(a) * d
		local h, owner = H.GetHeight(x, z)
		if owner == island and h > 3 and H.GetSlope(x, z) < 0.35 and not Nature.Blocked(x, z, World, clear, 9) then
			local t = World.Town
			if (x - t.X) ^ 2 + (z - t.Z) ^ 2 > (t.Radius - 10) ^ 2 then
				local size = rng:Range(7, 15)
				local cf = CF(x, h - 1.5, z) * Angles(0, rng:Range(0, math.pi * 2), 0)
				local m, top = Nature.SlabStack(folder, cf, size * 1.3, size, size * rng:Range(0.55, 0.9), rng, Nature.SANDSTONE, "Sandstone", true, true)
				add(m)
				table.insert(clear, { X = x, Z = z, R = size * 0.7 })
				if rng:Next() < 0.25 then
					local fern = Nature.Fern(m, V(x, h - 1.5 + top, z), rng, 0.9)
					add(fern)
				end
				placed += 1
			end
		end
	end
	-- sea stacks off the cliff coast (not on the harbour side)
	placed, tries = 0, 0
	while placed < SEA_STACKS and tries < 6000 do
		tries += 1
		local a = rng:Range(0, math.pi * 2)
		local d = island.Radius * rng:Range(1.0, 1.2)
		local x, z = island.X + math.cos(a) * d, island.Z + math.sin(a) * d
		if math.sin(a) > 0.25 then
			continue
		end
		local h = H.GetHeight(x, z)
		if h > -9 and h < -2 then
			local tooClose = false
			for _, c in clear do
				if (c.X - x) ^ 2 + (c.Z - z) ^ 2 < (c.R + 26) ^ 2 then
					tooClose = true
					break
				end
			end
			if not tooClose then
				local size = rng:Range(13, 20)
				local n, top = rockPillar(folder, V(x, h - 1, z), size, rng:Range(18, 36) - h, rng)
				parts += n
				if rng:Next() < 0.3 then
					add(Nature.Palm(folder, V(x, h - 1 + top - 0.3, z), rng, 0.8, 0))
				end
				table.insert(clear, { X = x, Z = z, R = size })
				placed += 1
			end
		end
	end
	return parts
end

-- Rocks of the town's water: rounded stones half sunk along the pool's shores, a little rock
-- island with a palm in the pool, and boulders on the harbour beach either side of the cut
local function buildTownRocks(model: any, H: any, World: any, rng: any, clear: { any }): number
	local folder = P.folder(model, "PoolRocks")
	local pool = World.Pool
	local parts = 0
	local function count(m: any)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
	end
	for _, deg in { 6, 26, 148, 170, 194, 216, 238, 300, 326, 348 } do
		local a = math.rad(deg + rng:Range(-5, 5))
		local f = rng:Range(0.86, 0.97)
		local x, z = pool.X + pool.Rx * f * math.cos(a), pool.Z + pool.Rz * f * math.sin(a)
		local h = H.GetHeight(x, z)
		local size = rng:Range(5, 9)
		count(Nature.SlabStack(folder, CF(x, h - 0.5, z) * Angles(0, rng:Range(0, math.pi * 2), 0), size * 1.3, size, -h + size * rng:Range(0.3, 0.6), rng, Nature.SANDSTONE, "Sandstone", rng:Next() < 0.4, false))
	end
	-- the rock island
	local ix, iz = pool.X - 13, pool.Z + 3
	local ih = H.GetHeight(ix, iz)
	local isle, top = Nature.SlabStack(folder, CF(ix, ih - 0.5, iz) * Angles(0, 0.6, 0), 12, 9, -ih + 3.5, rng, Nature.SANDSTONE, "Sandstone", true, true)
	count(isle)
	count(Nature.Palm(folder, V(ix + 1, ih - 0.5 + top - 0.4, iz), rng, 0.8, 0))
	-- the harbour beach below the quay wall: boulders where the wall ends, against the banks of
	-- the pier roots and the creek mouth, and palms leaning over the sand
	for _, spec in { { -121, 321, 10 }, { 123, 321, 10 }, { 58.5, 325, 5 }, { 82, 324.5, 5.5 }, { -82, 324.5, 5 }, { -34.5, 327, 6 }, { -113, 333, 6 } } do
		local x, z, size = spec[1], spec[2], spec[3]
		local h = H.GetHeight(x, z)
		local m, rtop = Nature.SlabStack(folder, CF(x, h - 1.2, z) * Angles(0, rng:Range(0, math.pi * 2), 0), size * 1.3, size, size * rng:Range(0.6, 0.85), rng, Nature.SANDSTONE, "Sandstone", true, true)
		count(m)
		if size >= 9 then
			count(Nature.Palm(folder, V(x, h - 1.2 + rtop - 0.3, z), rng, 0.9, 0))
		end
		table.insert(clear, { X = x, Z = z, R = size * 0.8 })
	end
	for _, spec in { { 48, 323.5, 0.3 }, { -110, 325, -0.5 }, { 88, 322, -0.2 }, { -36, 321.5, 0.2 } } do
		local x, z = spec[1], spec[2]
		local h = H.GetHeight(x, z)
		if h > 1 then
			count(Nature.Palm(folder, V(x, h - 0.3, z), rng, rng:Range(1.0, 1.2), 0))
			table.insert(clear, { X = x, Z = z, R = 4 })
		end
	end
	return parts
end

-- Big layered rock formations on the rim of the lighthouse summit (they frame the view
-- south over the island, like the great sandstone blocks in the reference)
local SUMMIT_ROCKS = { { 50, 38, 24 }, { -54, 36, 22 }, { 46, -40, 20 }, { -52, -36, 18 } } -- dx, dz from the lighthouse, size

local function buildSummitRocks(model: any, island: any, H: any, World: any, rng: any, clear: { any }): number
	local folder = P.folder(model, "SummitRocks")
	local lh = World.Lighthouse
	local parts = 0
	for _, spec in SUMMIT_ROCKS do
		local cx, cz = lh.X + spec[1], lh.Z + spec[2]
		local size = spec[3]
		if Nature.Blocked(cx, cz, World, clear, size * 0.5) then
			continue
		end
		-- the lowest ground under the footprint, so nothing floats
		local base = math.huge
		for _, o in { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			base = math.min(base, (H.GetHeight(cx + o[1] * size * 0.5, cz + o[2] * size * 0.5)))
		end
		-- a main block with a lower shoulder and a small rock at its foot
		local away = V(spec[1], 0, spec[2]).Unit
		local side = away:Cross(UP)
		local n1 = rockPillar(folder, V(cx, base - 2, cz), size, size * rng:Range(0.8, 1.0) + 2, rng)
		local s2 = size * rng:Range(0.6, 0.72)
		local p2 = V(cx, 0, cz) + side * (size * 0.55) * (if rng:Next() < 0.5 then 1 else -1) - away * size * 0.15
		local n2 = rockPillar(folder, V(p2.X, H.GetHeight(p2.X, p2.Z) - 2, p2.Z), s2, s2 * rng:Range(0.7, 0.9) + 2, rng)
		parts += n1 + n2
		table.insert(clear, { X = cx, Z = cz, R = size * 0.75 })
		table.insert(clear, { X = p2.X, Z = p2.Z, R = s2 * 0.75 })
	end
	return parts
end

-- Paths: helpers ------------------------------------------------------------------------------

local stairFlights: (folder: any, H: any, World: any, path: any, skip: { [number]: boolean }, rng: any, clear: { any }) -> { { number } }

-- Walks a polyline in steps of `step` studs, calling fn(x, z, dirX, dirZ, segIndex, s)
local function walkPath(points: { { number } }, step: number, skip: { [number]: boolean }, fn: (number, number, number, number, number, number) -> ())
	local s = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		if len < 0.01 then
			continue
		end
		dx, dz = dx / len, dz / len
		if not skip[i] then
			local t = (step - s % step) % step
			while t <= len do
				fn(a[1] + dx * t, a[2] + dz * t, dx, dz, i, s + t)
				t += step
			end
		end
		s += len
	end
end

local function lantern(parent: any, pos: any, facing: any, rng: any)
	local m = P.model(parent, "PathLantern")
	local cf = frame(pos, facing) -- -Z points at the path
	local h = 7.2
	P.part(m, { Name = "Post", Size = V(0.7, h + 1.5, 0.7), CFrame = cf * CF(0, h / 2 - 0.75, 0) * Angles(0, rng:Range(-0.2, 0.2), 0), Mat = "Wood", Color = DARK_WOOD })
	P.part(m, { Name = "Arm", Size = V(0.35, 0.35, 2.2), CFrame = cf * CF(0, h - 0.6, -0.9), Mat = "Wood", Color = DARK_WOOD })
	local glass = P.part(m, { Name = "Lantern", Size = V(0.85, 1.15, 0.85), CFrame = cf * CF(0, h - 1.75, -1.7), Mat = "Neon", Color = rgb(255, 196, 110), CanCollide = false })
	P.part(m, { Name = "LanternCap", Size = V(1.15, 0.35, 1.15), CFrame = cf * CF(0, h - 1.05, -1.7), Mat = "Metal", Color = IRON, CanCollide = false })
	P.pointLight(glass, WARM, 16, 1.1, false)
	return m
end

local function ropeFence(parent: any, a: any, b: any, postA: boolean)
	if postA then
		P.part(parent, { Name = "RopePost", Shape = "Cylinder", Size = V(3.4, 0.6, 0.6), CFrame = CF(a + V(0, 1.2, 0)) * Angles(0, 0, math.pi / 2), Mat = "Wood", Color = DARK_WOOD })
	end
	P.part(parent, { Name = "RopePost", Shape = "Cylinder", Size = V(3.4, 0.6, 0.6), CFrame = CF(b + V(0, 1.2, 0)) * Angles(0, 0, math.pi / 2), Mat = "Wood", Color = DARK_WOOD })
	P.beam(parent, a + V(0, 2.4, 0), b + V(0, 2.4, 0), 0.22, { Name = "Rope", Mat = "Fabric", Color = ROPE, CanCollide = false })
end

-- Plank stair flights ------------------------------------------------------------------------

-- One straight flight from a to b (points on the ground): treads at an even rise along the
-- line between the ends (each a solid block reaching down into the ramp, so no gaps show), a
-- stringer along each side, a hidden walking ramp through the treads and a railing on every
-- side that is open to a drop (none against the rock of a cutting).
local function stairFlight(parent: any, H: any, rng: any, a: any, b: any, width: number, riseStep: number, wooden: boolean): number
	local lo, hi = a, b
	if b.Y < a.Y then
		lo, hi = b, a
	end
	local d = flat(hi - lo)
	local len = d.Magnitude
	local dir = d.Unit
	local rgt = dir:Cross(UP)
	local rise = hi.Y - lo.Y
	local n = math.max(2, math.ceil(rise / riseStep))
	local run, h = len / n, rise / n
	local half = width / 2
	local m = P.model(parent, "StairFlight")
	local count = 0
	local function lineAt(t: number): any
		return lo + dir * (len * t) + V(0, rise * t, 0)
	end
	for k = 1, n do
		local c = lo + dir * (run * (k - 0.5))
		local top = lo.Y + h * k
		local blockH = h + 2.2
		P.part(m, { Name = "Step", Size = V(width - 0.2 + rng:Range(-0.12, 0.12), blockH, run + 0.1), CFrame = P.CFrame.fromMatrix(V(c.X, top - blockH / 2, c.Z), rgt, UP, -dir) * Angles(0, rng:Range(-0.012, 0.012), 0), Mat = "WoodPlanks", Color = pick(rng, PLANKS), CanCollide = false })
		count += 1
	end
	-- the walking surface: a hidden slab whose top runs just under the tread nosings
	local mid = (lo + hi) / 2
	P.part(m, { Name = "StairRamp", Size = V(width, 0.6, (hi - lo).Magnitude + 0.4), CFrame = P.lookAt(mid, hi) * CF(0, -0.05, 0), Transparency = 1, Mat = "Wood", Color = DARK_WOOD })
	count += 1
	for _, sd in { -1, 1 } do
		local off = rgt * sd * (half + 0.1)
		P.plank(m, lo + off + V(0, h * 0.5 - 0.45, 0) - dir * 0.2, hi + off + V(0, h * 0.5 - 0.45, 0) + dir * 0.1, 0.5, 1.2, { Name = "Stringer", Mat = "Wood", Color = DARK_WOOD })
		count += 1
		-- railing posts where this side is open (the ground beside the flight is not a wall)
		local posts = math.max(1, math.ceil(len / (if wooden then 3.6 else 7.5)))
		local last = nil
		for k = 0, posts do
			local t = k / posts
			local p = lineAt(t) + off + V(0, h * 0.5, 0)
			local side = lineAt(t) + rgt * sd * (half + 2.5)
			local wall = H.GetHeight(side.X, side.Z) > lineAt(t).Y + 2.2
			if wall then
				last = nil
				continue
			end
			if wooden then
				P.part(m, { Name = "RailPost", Size = V(0.5, 3.4, 0.5), CFrame = CF(p + V(0, 1.4, 0)), Mat = "Wood", Color = Nature.Shade(DARK_WOOD, rng:Range(0.92, 1.08)) })
				if last then
					P.plank(m, last + V(0, 3.0, 0), p + V(0, 3.0, 0), 0.45, 0.4, { Name = "Rail", Mat = "Wood", Color = WOOD })
					count += 1
				end
			else
				P.part(m, { Name = "RailPost", Shape = "Cylinder", Size = V(3.4, 0.55, 0.55), CFrame = CF(p + V(0, 1.4, 0)) * Angles(0, 0, math.pi / 2), Mat = "Wood", Color = DARK_WOOD })
				if last then
					P.beam(m, last + V(0, 2.7, 0), p + V(0, 2.7, 0), 0.22, { Name = "Rope", Mat = "Fabric", Color = ROPE, CanCollide = false })
					count += 1
				end
			end
			count += 1
			last = p
		end
	end
	return count
end

-- Finds the steep stretches of a ramp path (at 1-stud samples) and builds a straight flight on
-- each piece of them between two path points. Returns the covered stretches { s0, s1 }.
function stairFlights(folder: any, H: any, World: any, path: any, skip: { [number]: boolean }, rng: any, clear: { any }): { { number } }
	local samples = {}
	walkPath(path.Points, 1, skip, function(x, z, dx, dz, seg, s)
		table.insert(samples, { X = x, Z = z, Seg = seg, S = s, H = H.GetHeight(x, z) })
	end)
	local town = World.Town
	local covered = {}
	local runs = {}
	local cur = nil
	for k = 2, #samples - 1 do
		local a, b = samples[k - 1], samples[k + 1]
		local steep = b.S - a.S < 2.5 and math.abs(b.H - a.H) / (b.S - a.S) > 0.2
		if steep then
			if cur and samples[k].S - cur[#cur].S <= 3.1 then
				table.insert(cur, samples[k])
			else
				cur = { samples[k] }
				table.insert(runs, cur)
			end
		end
	end
	for _, run in runs do
		-- split at the path's corners: one straight flight per segment
		local pieces = {}
		for _, smp in run do
			local last = pieces[#pieces]
			if last and last[#last].Seg == smp.Seg then
				table.insert(last, smp)
			else
				table.insert(pieces, { smp })
			end
		end
		for _, piece in pieces do
			local a, b = piece[1], piece[#piece]
			-- each flight reaches to its corner (or the end of the steep stretch) on both ends
			local pa, pb = V(a.X, a.H, a.Z), V(b.X, b.H, b.Z)
			if (pb - pa).Magnitude < 2.5 or math.abs(pb.Y - pa.Y) < 0.8 then
				continue
			end
			local inTown = (a.X - town.X) ^ 2 + (a.Z - town.Z) ^ 2 < (town.Radius + 30) ^ 2
			stairFlight(folder, H, rng, pa, pb, path.Width, if inTown then 0.8 else 1.35, inTown)
			table.insert(covered, { a.S, b.S })
			for t = 0, 1, 0.25 do
				local p = pa:Lerp(pb, t)
				table.insert(clear, { X = p.X, Z = p.Z, R = path.Width / 2 + 2 })
			end
		end
	end
	return covered
end

-- Plank stairs on the steep parts of the trail ramps, rope fences along drops, lanterns
local function buildTrails(model: any, H: any, World: any, rng: any, clear: { any })
	local folder = P.folder(model, "Trails")
	local stairsFolder = P.folder(folder, "Stairs")
	local fences = P.folder(folder, "Fences")
	local lights = P.folder(folder, "Lanterns")
	local town = World.Town
	local STEP = 2.2
	for _, path in World.Paths do
		local skip = {}
		for _, i in path.Bridges or {} do
			skip[i] = true
		end
		for _, i in path.Planks or {} do
			skip[i] = true
		end
		local half = path.Width / 2
		-- samples along the path
		local samples = {}
		walkPath(path.Points, STEP, skip, function(x, z, dx, dz, seg, s)
			table.insert(samples, { X = x, Z = z, Dx = dx, Dz = dz, Seg = seg, S = s, H = H.GetHeight(x, z) })
		end)
		-- plank stair flights on the steep stretches of the ramp
		if path.Ramp then
			for _, f in stairFlights(stairsFolder, H, World, path, skip, rng, clear) do
				for _, smp in samples do
					if smp.S >= f[1] - 1 and smp.S <= f[2] + 1 then
						smp.Stair = true
					end
				end
			end
		end
		-- rope fences along drops beside the trails (outside the town)
		if path.Ramp then
			for _, side in { -1, 1 } do
				local last = nil
				local lastS = -1e9
				for k = 1, #samples, 3 do
					local smp = samples[k]
					local lx, lz = -smp.Dz * side, smp.Dx * side
					local ex, ez = smp.X + lx * (half + 0.8), smp.Z + lz * (half + 0.8)
					local drop = smp.H - H.GetHeight(smp.X + lx * (half + 5), smp.Z + lz * (half + 5))
					local onPlaza = (smp.X - town.X) ^ 2 + (smp.Z - town.Z) ^ 2 < (town.SquareRadius + 6) ^ 2
					if drop > 4 and not onPlaza and not smp.Stair then
						local p = V(ex, H.GetHeight(ex, ez), ez)
						if last and smp.S - lastS < 3 * STEP + 0.5 then
							ropeFence(fences, last, p, false)
						elseif not last or smp.S - lastS >= 3 * STEP + 0.5 then
							P.part(fences, { Name = "RopePost", Shape = "Cylinder", Size = V(3.4, 0.6, 0.6), CFrame = CF(p + V(0, 1.2, 0)) * Angles(0, 0, math.pi / 2), Mat = "Wood", Color = DARK_WOOD })
						end
						last = p
						lastS = smp.S
					end
				end
			end
		end
		-- lanterns along the trails (the town lights its own streets)
		if path.Ramp then
			local side = 1
			local nextS = 14
			for _, smp in samples do
				if smp.S >= nextS then
					local lx, lz = -smp.Dz * side, smp.Dx * side
					local x, z = smp.X + lx * (half + 1.6), smp.Z + lz * (half + 1.6)
					local h = H.GetHeight(x, z)
					if math.abs(h - smp.H) < 2.5 and not Nature.Blocked(x, z, World, clear, 0.5) then
						lantern(lights, V(x, h, z), V(-lx, 0, -lz), rng)
						table.insert(clear, { X = x, Z = z, R = 3 })
						side = -side
						-- (closer together in and around the town, further apart out on the island)
						local inTown = (x - World.Town.X) ^ 2 + (z - World.Town.Z) ^ 2 < (World.Town.Radius + 30) ^ 2
						nextS = smp.S + (if inTown then 36 else 52)
					end
				end
			end
		end
	end
end

-- Railings along the cliff edges of the town's shop ledges: walks the outline of every flat
-- ledge (WorldData.Ledges with Rough = 0), finds the real edge on the terrain along the outward
-- normal (the outlines wobble) and puts a post wherever the ground falls away by more than a
-- few studs. Neighbouring posts are joined by a rail and a rope; gaps are left where the paths
-- and stairs come up, and around the buildings.
local function ledgeRailings(model: any, H: any, World: any, rng: any, clear: { any }): number
	local folder = P.folder(model, "LedgeRailings")
	local segs = {}
	for _, path in World.Paths do
		for i = 1, #path.Points - 1 do
			table.insert(segs, { path.Points[i], path.Points[i + 1], path.Width / 2 + 1.8 })
		end
	end
	local function nearPath(x: number, z: number): boolean
		for _, sg in segs do
			local a, b = sg[1], sg[2]
			local vx, vz = b[1] - a[1], b[2] - a[2]
			local len2 = vx * vx + vz * vz
			local t = if len2 > 0 then math.clamp(((x - a[1]) * vx + (z - a[2]) * vz) / len2, 0, 1) else 0
			if (a[1] + vx * t - x) ^ 2 + (a[2] + vz * t - z) ^ 2 < sg[3] * sg[3] then
				return true
			end
		end
		return false
	end
	local function nearBuilding(x: number, z: number): boolean
		for _, c in clear do
			local dx, dz = x - c.X, z - c.Z
			if dx * dx + dz * dz < c.R * c.R then
				if c.Hx then
					local lx = dx * c.C - dz * c.S
					local lz = dx * c.S + dz * c.C
					if math.abs(lx) < c.Hx and math.abs(lz) < c.Hz then
						return true
					end
				elseif c.R >= 6 then
					return true
				end
			end
		end
		return false
	end
	local count = 0
	for _, l in World.Ledges do
		if l.Rough > 0 then
			continue
		end
		local C, S = math.cos(l.Yaw), math.sin(l.Yaw)
		local perim = math.pi * (3 * (l.Rx + l.Rz) - math.sqrt((3 * l.Rx + l.Rz) * (l.Rx + 3 * l.Rz)))
		local n = math.floor(perim / 4)
		local posts = {}
		for k = 0, n - 1 do
			local th = k / n * math.pi * 2
			local lx, lz = l.Rx * math.cos(th), l.Rz * math.sin(th)
			local nx, nz = math.cos(th) / l.Rx, math.sin(th) / l.Rz
			local nl = math.sqrt(nx * nx + nz * nz)
			nx, nz = nx / nl, nz / nl
			-- to world (the inverse of the Heightmap's turn by the ledge's yaw)
			local px, pz = l.X + lx * C + lz * S, l.Z - lx * S + lz * C
			local ox, oz = nx * C + nz * S, -nx * S + nz * C
			local edge = nil
			for step = -10, 10, 0.5 do
				local x, z = px + ox * step, pz + oz * step
				local h = H.GetHeight(x, z)
				if math.abs(h - l.H) < 0.6 then
					edge = { x, z }
				elseif edge and h < l.H - 0.8 then
					break
				end
			end
			if edge then
				local ex, ez = edge[1] - ox * 1.0, edge[2] - oz * 1.0
				local drop = l.H - H.GetHeight(edge[1] + ox * 6, edge[2] + oz * 6)
				local h = H.GetHeight(ex, ez)
				if drop > 3.5 and math.abs(h - l.H) < 0.7 and not nearPath(ex, ez) and not nearBuilding(ex, ez) then
					posts[k] = V(ex, h, ez)
				end
			end
		end
		for k = 0, n - 1 do
			local p = posts[k]
			if p then
				P.pillar(folder, p.X, p.Z, p.Y - 0.6, p.Y + 3.3, 0.65, { Name = "RailPost", Mat = "Wood", Color = Nature.Shade(DARK_WOOD, rng:Range(0.9, 1.1)) })
				count += 1
				local q = posts[(k + 1) % n]
				if q and (q - p).Magnitude < 6.5 then
					P.plank(folder, p + V(0, 3.0, 0), q + V(0, 3.0, 0), 0.4, 0.35, { Name = "Rail", Mat = "Wood", Color = Nature.Shade(WOOD, rng:Range(0.92, 1.06)) })
					P.beam(folder, p + V(0, 1.6, 0), q + V(0, 1.6, 0), 0.18, { Name = "Rope", Mat = "Fabric", Color = ROPE, CanCollide = false })
					count += 2
				end
			end
		end
	end
	return count
end

-- Raised plank walkways (path.Planks segments): boards across two stringers on short
-- posts, with rope rails between the posts
local function buildWalkways(model: any, H: any, World: any, rng: any)
	local folder = P.folder(model, "Walkways")
	for _, path in World.Paths do
		for _, i in path.Planks or {} do
			local a, b = path.Points[i], path.Points[i + 1]
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.sqrt(dx * dx + dz * dz)
			dx, dz = dx / len, dz / len
			-- trim where the walkway starts inside a wider street or ends at a shop front
			local t0, t1 = 0, len
			if i == 1 then
				t0 = 7
			end
			if i + 1 == #path.Points then
				t1 = len - 5
			end
			if t1 - t0 < 3 then
				continue
			end
			local ax, az = a[1] + dx * t0, a[2] + dz * t0
			local bx, bz = a[1] + dx * t1, a[2] + dz * t1
			local h = math.max(H.GetHeight(ax, az), H.GetHeight(bx, bz), (H.GetHeight((ax + bx) / 2, (az + bz) / 2)))
			local dir = V(dx, 0, dz)
			local right = dir:Cross(UP)
			local m = P.model(folder, path.Name .. "Walkway")
			local top = h + 0.7
			local half = path.Width / 2
			local n = math.max(1, math.floor((t1 - t0) / 1.3 + 0.5))
			local step = (t1 - t0) / n
			for k = 0, n - 1 do
				local t = t0 + step * (k + 0.5)
				local c = V(a[1] + dx * t, top - 0.2, a[2] + dz * t)
				P.part(m, { Name = "Board", Size = V(path.Width + rng:Range(0.1, 0.6), 0.4, step - 0.14), CFrame = frame(c, dir) * CF(rng:Range(-0.12, 0.12), rng:Range(-0.03, 0.03), 0) * Angles(0, rng:Range(-0.035, 0.035), 0), Mat = "WoodPlanks", Color = pick(rng, PLANKS) })
			end
			local mid = V((ax + bx) / 2, top - 0.75, (az + bz) / 2)
			for _, side in { -1, 1 } do
				P.part(m, { Name = "Stringer", Size = V(0.6, 0.8, t1 - t0), CFrame = frame(mid + right * side * (half - 0.5), dir), Mat = "Wood", Color = DARK_WOOD })
				-- posts and a rope rail along the side
				local posts = math.max(1, math.floor((t1 - t0) / 7 + 0.5))
				local last = nil
				for k = 0, posts do
					local t = t0 + 0.5 + (t1 - t0 - 1) * k / posts
					local p = V(a[1] + dx * t, top, a[2] + dz * t) + right * side * (half + 0.25)
					P.part(m, { Name = "RailPost", Shape = "Cylinder", Size = V(3.6, 0.7, 0.7), CFrame = CF(p + V(0, 0.9, 0)) * Angles(0, 0, math.pi / 2), Mat = "Wood", Color = DARK_WOOD })
					if last then
						P.beam(m, last + V(0, 2.3, 0), p + V(0, 2.3, 0), 0.22, { Name = "Rope", Mat = "Fabric", Color = ROPE, CanCollide = false })
					end
					last = p
				end
			end
		end
	end
end

-- Rope bridges (path.Bridges segments): planks hung between rope rails
local function buildBridges(model: any, H: any, World: any, rng: any, clear: { any })
	local folder = P.folder(model, "Bridges")
	for _, path in World.Paths do
		for _, i in path.Bridges or {} do
			local a, b = path.Points[i], path.Points[i + 1]
			local ha, hb = H.GetHeight(a[1], a[2]), H.GetHeight(b[1], b[2])
			local pa, pb = V(a[1], ha, a[2]), V(b[1], hb, b[2])
			local dir = flat(pb - pa).Unit
			local right = dir:Cross(UP)
			local len = flat(pb - pa).Magnitude
			local half = path.Width / 2
			local m = P.model(folder, path.Name .. "Bridge")
			local sag = math.min(3, len * 0.05)
			local function deckAt(t: number)
				return pa:Lerp(pb, t) - V(0, sag * 4 * t * (1 - t), 0) + V(0, 0.2, 0)
			end
			local n = math.floor(len / 1.45)
			for k = 0, n do
				local t = k / n
				local p = deckAt(t)
				local p2 = deckAt(math.min(1, t + 0.02))
				local p1 = deckAt(math.max(0, t - 0.02))
				local along = (p2 - p1).Unit
				P.part(m, { Name = "Plank", Size = V(path.Width + 0.4, 0.35, 1.1), CFrame = P.CFrame.fromMatrix(p, right, along:Cross(right) * -1, -along) * Angles(0, rng:Range(-0.04, 0.04), 0), Mat = "WoodPlanks", Color = pick(rng, PLANKS) })
			end
			-- posts at both ends and rope rails with a sag
			for _, side in { -1, 1 } do
				for _, t in { 0, 1 } do
					local base = (if t == 0 then pa else pb) + right * side * (half + 0.6) - dir * (if t == 0 then 1 else -1) * 0.8
					P.part(m, { Name = "BridgePost", Size = V(0.9, 6, 0.9), CFrame = CF(base + V(0, 1.6, 0)), Mat = "Wood", Color = DARK_WOOD })
				end
				local segs = 6
				for k = 0, segs - 1 do
					local q0 = deckAt(k / segs) + right * side * (half + 0.4) + V(0, 2.8, 0)
					local q1 = deckAt((k + 1) / segs) + right * side * (half + 0.4) + V(0, 2.8, 0)
					P.beam(m, q0, q1, 0.25, { Name = "Rope", Mat = "Fabric", Color = ROPE, CanCollide = false })
				end
				for k = 0, segs - 1 do
					local q0 = deckAt(k / segs) + right * side * (half + 0.3)
					local q1 = deckAt((k + 1) / segs) + right * side * (half + 0.3)
					P.beam(m, q0, q1, 0.3, { Name = "Rope", Mat = "Fabric", Color = ROPE, CanCollide = false })
				end
			end
			-- invisible side walls so nobody slips off the swaying planks
			for _, side in { -1, 1 } do
				local c = pa:Lerp(pb, 0.5) - V(0, sag, 0) + right * side * (half + 0.5) + V(0, 2.2, 0)
				P.part(m, { Name = "Guard", Size = V(0.4, 5, len), CFrame = frame(c, dir), Transparency = 1, CanQuery = false })
			end
			table.insert(clear, { X = a[1], Z = a[2], R = 6 })
			table.insert(clear, { X = b[1], Z = b[2], R = 6 })
		end
	end
end

-- Streams and waterfalls -------------------------------------------------------------------------

local WATER = rgb(70, 186, 206)
local WATER_LIGHT = rgb(150, 222, 232)
local FOAM = rgb(238, 248, 250)

local function waterPart(parent: any, props: { [string]: any })
	props.Mat = props.Mat or "Glass"
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	return P.part(parent, props)
end

-- One waterfall: a sheet of water arching over the lip, lighter streaks in front, foam at
-- the lip and the foot, spray rising from the plunge pool
local function waterfall(parent: any, rng: any, top: any, bottom: any, flow: any, width: number)
	local m = P.model(parent, "Waterfall")
	local lip = top + flow * 0.6
	local foot = bottom + flow * 2.2
	waterPart(m, { Name = "FallSheet", Size = V(width, 0.8, (foot - lip).Magnitude), CFrame = P.lookAt((lip + foot) / 2, foot), Color = WATER, Transparency = 0.3, Reflectance = 0.05 })
	local right = flow:Cross(UP).Unit
	-- white water streaks tumbling down the front (more on the wide falls)
	local streaks = if width >= 10 then { -0.36, -0.12, 0.12, 0.36 } else { -0.22, 0.22 }
	for i, k in streaks do
		local off = right * (k + rng:Range(-0.05, 0.05)) * width + flow * (0.5 + (i % 2) * 0.25)
		local a = lip + off
		local b = foot + off + flow * 0.4
		local color = if i % 2 == 0 then FOAM else WATER_LIGHT
		waterPart(m, { Name = "FallStreak", Size = V(width * rng:Range(0.16, 0.24), 0.5, (b - a).Magnitude * rng:Range(0.75, 1)), CFrame = P.lookAt((a + b) / 2, b) * CF(0, 0, -(b - a).Magnitude * 0.05), Mat = "SmoothPlastic", Color = color, Transparency = 0.12 })
	end
	-- the curl of water over the lip
	Nature.Blob(m, V(width * 1.02, 1.6, 3), CF(top + flow * 0.4 + V(0, 0.1, 0)) * P.CFrame.fromMatrix(V(), right, UP, -flow), { Name = "Lip", Mat = "Glass", Color = WATER_LIGHT, Transparency = 0.15 })
	-- foam and spray at the foot
	local base = V(foot.X, bottom.Y, foot.Z)
	local foam = Nature.Blob(m, V(width * 1.7, 1.6, width * 1.5), CF(base + flow * 1.0 + V(0, 0.25, 0)), { Name = "Foam", Mat = "SmoothPlastic", Color = FOAM, Transparency = 0.1 })
	Nature.Blob(m, V(width * 1.1, 2.2, width * 0.9), CF(base + V(0, 0.6, 0)), { Name = "Foam", Mat = "SmoothPlastic", Color = FOAM, Transparency = 0.05 })
	P.emitter(foam, {
		Name = "Spray",
		Rate = 14,
		Lifetime = P.NumberRange.new(1.2, 2.2),
		Speed = P.NumberRange.new(3, 6),
		SpreadAngle = P.Vector2.new(35, 35),
		Size = P.NumberSequence.new({ P.NumberSequenceKeypoint.new(0, 2), P.NumberSequenceKeypoint.new(1, 6) }),
		Transparency = P.NumberSequence.new({ P.NumberSequenceKeypoint.new(0, 0.55), P.NumberSequenceKeypoint.new(1, 1) }),
		Color = P.ColorSequence.new(FOAM),
		Acceleration = V(0, 1.5, 0),
		LightEmission = 0.2,
	})
	return m
end

-- Water along WorldData.Streams: calm runs in the carved bed, waterfalls where it drops
local function buildStreams(model: any, H: any, World: any, rng: any, clear: { any })
	local folder = P.folder(model, "Streams")
	for _, stream in World.Streams or {} do
		local m = P.model(folder, stream.Name)
		local samples = {}
		walkPath(stream.Points, 2, {}, function(x, z, dx, dz)
			table.insert(samples, { X = x, Z = z, Dx = dx, Dz = dz, H = H.GetHeight(x, z) })
		end)
		for k, smp in samples do
			if k % 3 == 1 then
				table.insert(clear, { X = smp.X, Z = smp.Z, R = stream.Width / 2 + 3, Core = stream.Width / 2 + 1.5 })
			end
		end
		local level = stream.Depth * 0.55 -- water surface above the bed
		local k = 1
		while k < #samples do
			local a, b = samples[k], samples[k + 1]
			if a.H - b.H > 1.6 then
				-- a drop: follow it to the bottom
				-- (a narrow ledge in the rock face does not break the fall: it carries on when the
				-- ground drops again within two samples)
				local j = k + 1
				local function dropsAt(i: number): boolean
					return i < #samples and samples[i].H - samples[i + 1].H > 0.5
				end
				while dropsAt(j) or (dropsAt(j + 1) and samples[j].H - samples[j + 2].H > 1.2) or (dropsAt(j + 2) and samples[j].H - samples[j + 3].H > 1.2) do
					j += 1
				end
				local bot = samples[j]
				local flow = V(a.Dx, 0, a.Dz)
				waterfall(m, rng, V(a.X, a.H + level, a.Z), V(bot.X, math.max(bot.H + level, World.WaterLevel), bot.Z), flow, stream.Width - 1)
				-- boulders flanking the plunge pool
				for _, sd in { -1, 1 } do
					local side = flow:Cross(UP).Unit * sd
					local p = V(bot.X, 0, bot.Z) + side * (stream.Width * 0.5 + rng:Range(1.5, 3)) + flow * rng:Range(-1, 3)
					local h = H.GetHeight(p.X, p.Z)
					if h > -4 then
						local size = rng:Range(4, 6.5)
						Nature.SlabStack(m, CF(p.X, h - size * 0.3, p.Z) * Angles(0, rng:Range(0, math.pi), 0), size * 1.3, size, size * 0.8, rng, Nature.SANDSTONE, "Sandstone", rng:Next() < 0.5, true)
					end
				end
				k = j
			else
				-- a calm run: water strips every few samples up to the next drop
				local j = k
				while j < #samples and samples[j].H - samples[j + 1].H <= 1.6 do
					j += 1
				end
				local i0 = k
				while i0 < j do
					local i1 = math.min(j, i0 + 4)
					local p0, p1 = samples[i0], samples[i1]
					local y0 = p0.H + level
					local y1 = p1.H + level
					local a3 = V(p0.X, y0, p0.Z) - V(p0.Dx, 0, p0.Dz) * 0.8
					local b3 = V(p1.X, y1, p1.Z) + V(p1.Dx, 0, p1.Dz) * 0.8
					waterPart(m, { Name = "Water", Size = V(stream.Width - 0.6, 0.6, (b3 - a3).Magnitude), CFrame = P.lookAt((a3 + b3) / 2, b3), Color = WATER, Transparency = 0.25, Reflectance = 0.08 })
					i0 = i1
				end
				k = j
			end
		end
	end
end

-- Lookout deck on the south rim of the lighthouse summit: planks reaching out over the cliff,
-- a railing, a telescope and a lantern. The best view of the island.
local function buildLookout(model: any, H: any, World: any, rng: any, clear: { any })
	local lh = World.Lighthouse
	local cx, cz = lh.X + 4, lh.Z + 52 -- deck centre, the rim is a few studs further south
	local top = H.GetHeight(cx, cz - 6) + 0.6
	local m = P.model(model, "Lookout")
	local W, D = 16, 12
	local cf = CF(cx, top, cz) -- +Z faces the view (south)
	-- boards across the deck
	local n = 10
	for k = 0, n - 1 do
		local z = -D / 2 + (k + 0.5) * D / n
		P.part(m, { Name = "Board", Size = V(W + rng:Range(-0.2, 0.4), 0.4, D / n - 0.12), CFrame = cf * CF(rng:Range(-0.15, 0.15), -0.2, z) * Angles(0, rng:Range(-0.02, 0.02), 0), Mat = "WoodPlanks", Color = pick(rng, PLANKS) })
	end
	for _, x in { -W / 2 + 0.6, W / 2 - 0.6 } do
		P.part(m, { Name = "Joist", Size = V(0.8, 1, D), CFrame = cf * CF(x, -0.9, 0), Mat = "Wood", Color = DARK_WOOD })
	end
	-- posts down to the ground (long ones at the front, over the drop)
	for _, x in { -W / 2 + 0.6, 0, W / 2 - 0.6 } do
		for _, z in { -D / 2 + 0.6, D / 2 - 0.6 } do
			local p = (cf * CF(x, 0, z)).Position
			local g = H.GetHeight(p.X, p.Z)
			if g < top - 1.2 then
				P.pillar(m, p.X, p.Z, g - 1, top - 0.4, 1.1, { Name = "Post", Mat = "Wood", Color = DARK_WOOD })
			end
		end
	end
	-- bracing under the front edge
	local fl = (cf * CF(-W / 2 + 0.6, -1, D / 2 - 0.6)).Position
	local fr = (cf * CF(W / 2 - 0.6, -1, D / 2 - 0.6)).Position
	local gy = math.min((H.GetHeight(fl.X, fl.Z)), (H.GetHeight(fr.X, fr.Z))) + 2
	P.beam(m, fl, V(fr.X, math.max(gy, top - 9), fr.Z), 0.6, { Name = "Brace", Mat = "Wood", Color = DARK_WOOD })
	P.beam(m, fr, V(fl.X, math.max(gy, top - 9), fl.Z), 0.6, { Name = "Brace", Mat = "Wood", Color = DARK_WOOD })
	-- railing on the three open sides
	local rail = { { -W / 2 + 0.3, D / 2 - 0.3, W / 2 - 0.3, D / 2 - 0.3 }, { -W / 2 + 0.3, -D / 2 + 1.5, -W / 2 + 0.3, D / 2 - 0.3 }, { W / 2 - 0.3, -D / 2 + 1.5, W / 2 - 0.3, D / 2 - 0.3 } }
	for _, r in rail do
		local a = (cf * CF(r[1], 0, r[2])).Position
		local b = (cf * CF(r[3], 0, r[4])).Position
		local len = (b - a).Magnitude
		local posts = math.max(1, math.floor(len / 4 + 0.5))
		for k = 0, posts do
			local p = a:Lerp(b, k / posts)
			P.part(m, { Name = "RailPost", Size = V(0.5, 3.4, 0.5), CFrame = CF(p + V(0, 1.7, 0)), Mat = "Wood", Color = DARK_WOOD })
		end
		P.plank(m, a + V(0, 3.3, 0), b + V(0, 3.3, 0), 0.5, 0.35, { Name = "Rail", Mat = "Wood", Color = WOOD })
		P.plank(m, a + V(0, 1.8, 0), b + V(0, 1.8, 0), 0.3, 0.25, { Name = "Rail", Mat = "Wood", Color = WOOD })
	end
	-- a brass telescope on a tripod, looking out to sea
	local tp = (cf * CF(3, 0, D / 2 - 2.2)).Position
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3 + 0.3
		P.beam(m, tp + V(0, 3.4, 0), tp + V(math.cos(a) * 1.1, 0, math.sin(a) * 1.1), 0.22, { Name = "Tripod", Mat = "Wood", Color = DARK_WOOD })
	end
	local tube = CF(tp + V(0, 3.9, 0)) * Angles(math.rad(8), math.rad(-10), 0)
	P.part(m, { Name = "Telescope", Shape = "Cylinder", Size = V(3.2, 0.55, 0.55), CFrame = tube * CF(0, 0, 0.4) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = rgb(196, 150, 60) })
	P.part(m, { Name = "Telescope", Shape = "Cylinder", Size = V(1.0, 0.75, 0.75), CFrame = tube * CF(0, 0, 1.9) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = rgb(150, 110, 44) })
	lantern(m, (cf * CF(-W / 2 + 1.2, 0, -D / 2 + 1.2)).Position, (cf * CF(1, 0, 1)).Position - (cf * CF(0, 0, 0)).Position, rng)
	table.insert(clear, { X = cx, Z = cz, R = 13 })
	table.insert(clear, { X = cx, Z = cz + 16, R = 12 })
end

-- Signposts -------------------------------------------------------------------------------------

-- The path network as a graph (path points + junctions + the town square as a hub)
local function buildGraph(World: any)
	local nodes: { { number } } = {}
	local edges: { [number]: { { number } } } = {}
	local function node(x: number, z: number): number
		for i, nd in nodes do
			if (nd[1] - x) ^ 2 + (nd[2] - z) ^ 2 < 1 then
				return i
			end
		end
		table.insert(nodes, { x, z })
		edges[#nodes] = {}
		return #nodes
	end
	local function link(i: number, j: number)
		if i == j then
			return
		end
		local d = math.sqrt((nodes[i][1] - nodes[j][1]) ^ 2 + (nodes[i][2] - nodes[j][2]) ^ 2)
		table.insert(edges[i], { j, d })
		table.insert(edges[j], { i, d })
	end
	local town = World.Town
	local square = node(town.X, town.Z)
	local ids, splits = {}, {}
	for pi, path in World.Paths do
		ids[pi], splits[pi] = {}, {}
		for k, pt in path.Points do
			ids[pi][k] = node(pt[1], pt[2])
		end
	end
	-- path ends that join the square, or another path in the middle of a segment
	for pi, path in World.Paths do
		for _, k in { 1, #path.Points } do
			local pt = path.Points[k]
			if (pt[1] - town.X) ^ 2 + (pt[2] - town.Z) ^ 2 < (town.SquareRadius + 8) ^ 2 then
				link(ids[pi][k], square)
			end
			for qi, other in World.Paths do
				if qi == pi then
					continue
				end
				for j = 1, #other.Points - 1 do
					local a, b = other.Points[j], other.Points[j + 1]
					local vx, vz = b[1] - a[1], b[2] - a[2]
					local len2 = vx * vx + vz * vz
					local t = math.clamp(((pt[1] - a[1]) * vx + (pt[2] - a[2]) * vz) / len2, 0, 1)
					local cx, cz = a[1] + vx * t, a[2] + vz * t
					if (cx - pt[1]) ^ 2 + (cz - pt[2]) ^ 2 < 4 and t > 0.001 and t < 0.999 then
						local mid = node(cx, cz)
						link(ids[pi][k], mid)
						splits[qi][j] = splits[qi][j] or {}
						table.insert(splits[qi][j], { t, mid })
					end
				end
			end
		end
	end
	-- the segments, split at their junctions
	for pi, path in World.Paths do
		for j = 1, #path.Points - 1 do
			local chain = { { 0, ids[pi][j] }, { 1, ids[pi][j + 1] } }
			for _, sp in splits[pi][j] or {} do
				table.insert(chain, sp)
			end
			table.sort(chain, function(a, b)
				return a[1] < b[1]
			end)
			for c = 1, #chain - 1 do
				link(chain[c][2], chain[c + 1][2])
			end
		end
	end
	-- the boardwalk along the beach (built by the town) joins the main street and the beach trails
	local west, mid, east = node(-80, 300), node(0, 299), node(80, 300)
	link(west, mid)
	link(mid, east)
	return nodes, edges
end

local function nearestNode(nodes: { { number } }, x: number, z: number): number
	local best, bestD = 1, math.huge
	for i, nd in nodes do
		local d = (nd[1] - x) ^ 2 + (nd[2] - z) ^ 2
		if d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

-- Direction to follow from the signpost towards `target`: the route starts where the post
-- stands beside the network (its projection onto the nearest path) and the arrow points
-- along the first stretch of that route.
local function routeDirection(nodes: { { number } }, edges: any, from: { number }, target: { number }): (number, number)
	-- nearest edge and the projection of the post onto it
	local bestD, pi, pj, px, pz = math.huge, 1, 1, from[1], from[2]
	for i, list in edges do
		for _, e in list do
			local a, b = nodes[i], nodes[e[1]]
			local vx, vz = b[1] - a[1], b[2] - a[2]
			local len2 = vx * vx + vz * vz
			local t = if len2 > 0 then math.clamp(((from[1] - a[1]) * vx + (from[2] - a[2]) * vz) / len2, 0, 1) else 0
			local cx, cz = a[1] + vx * t, a[2] + vz * t
			local d = (cx - from[1]) ^ 2 + (cz - from[2]) ^ 2
			if d < bestD then
				bestD, pi, pj, px, pz = d, i, e[1], cx, cz
			end
		end
	end
	local goal = nearestNode(nodes, target[1], target[2])
	local dist, prev, done = {}, {}, {}
	dist[pi] = math.sqrt((nodes[pi][1] - px) ^ 2 + (nodes[pi][2] - pz) ^ 2)
	dist[pj] = math.min(dist[pj] or math.huge, math.sqrt((nodes[pj][1] - px) ^ 2 + (nodes[pj][2] - pz) ^ 2))
	while true do
		local u, best = nil, math.huge
		for i, d in dist do
			if not done[i] and d < best then
				u, best = i, d
			end
		end
		if u == nil or u == goal then
			break
		end
		done[u] = true
		for _, e in edges[u] do
			local nd = best + e[2]
			if dist[e[1]] == nil or nd < dist[e[1]] then
				dist[e[1]] = nd
				prev[e[1]] = u
			end
		end
	end
	-- the route as points, starting at the projection
	local ids = { goal }
	while prev[ids[1]] do
		table.insert(ids, 1, prev[ids[1]])
	end
	local pts = { { px, pz } }
	for _, id in ids do
		table.insert(pts, nodes[id])
	end
	-- the branch point is the last route point next to the post (a junction beside it);
	-- the arrow points from there to the spot 10 studs further along the route
	local startK = 1
	for k = 2, #pts do
		if (pts[k][1] - from[1]) ^ 2 + (pts[k][2] - from[2]) ^ 2 < 16 * 16 then
			startK = k
		else
			break
		end
	end
	local sx, sz = pts[startK][1], pts[startK][2]
	local togo = 10
	for k = startK, #pts - 1 do
		local a, b = pts[k], pts[k + 1]
		local seg = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		if seg >= togo or k == #pts - 1 then
			local t = if seg > 0 then math.min(1, togo / seg) else 1
			local dx, dz = a[1] + (b[1] - a[1]) * t - sx, a[2] + (b[2] - a[2]) * t - sz
			local d = math.sqrt(dx * dx + dz * dz)
			if d > 0.5 then
				return dx / d, dz / d
			end
		end
		togo -= seg
	end
	local dx, dz = target[1] - from[1], target[2] - from[2]
	local d = math.max(0.01, math.sqrt(dx * dx + dz * dz))
	return dx / d, dz / d
end

local function signpost(parent: any, pos: any, boards: { { any } }, rng: any)
	local m = P.model(parent, "Signpost")
	local top = 9 + math.max(0, #boards - 5) * 1.2
	P.part(m, { Name = "Post", Size = V(0.9, top + 1.5, 0.9), CFrame = CF(pos + V(0, top / 2 - 0.75, 0)), Mat = "Wood", Color = DARK_WOOD })
	P.part(m, { Name = "PostCap", Size = V(1.3, 0.5, 1.3), CFrame = CF(pos + V(0, top, 0)), Mat = "Wood", Color = rgb(70, 48, 32) })
	for k, b in boards do
		local text, dx, dz = b[1], b[2], b[3]
		local d = V(dx, 0, dz)
		local y = top - 1.0 - (k - 1) * 1.25
		local len = math.clamp(#text * 0.62 + 1.6, 5.5, 9)
		local tilt = rng:Range(-0.04, 0.04)
		local centre = pos + V(0, y, 0) + d * (len / 2 + 0.35)
		local normal = d:Cross(UP)
		local cf = P.CFrame.fromMatrix(centre, d, UP, normal) * Angles(0, 0, tilt)
		local board = P.part(m, { Name = "ArrowBoard", Size = V(len, 1.05, 0.3), CFrame = cf, Mat = "WoodPlanks", Color = pick(rng, PLANKS) })
		-- the arrow point: a square turned 45 degrees at the end of the board
		P.part(m, { Name = "ArrowTip", Size = V(0.74, 0.74, 0.3), CFrame = cf * CF(len / 2, 0, 0) * Angles(0, 0, math.pi / 4), Mat = "WoodPlanks", Color = board.Color })
		for _, face in { "Front", "Back" } do
			P.surfaceText(board, face, text, { Name = "Text" .. face, Color = SIGN_TEXT, StrokeColor = rgb(50, 30, 16), StrokeTransparency = 0.3, PixelsPerStud = 40, Padding = 0.06 })
		end
	end
	return m
end

local LABELS = { Shipwright = "Shipwright", Merchant = "Merchant", Armory = "Armory", Tavern = "Tavern", TradingPost = "Trading Post" }

local function buildSignposts(model: any, H: any, World: any, rng: any, clear: { any })
	local folder = P.folder(model, "Signposts")
	local nodes, edges = buildGraph(World)
	local targets: { [string]: { number } } = {}
	for _, shop in World.Shops do
		targets[shop.Id] = { shop.FrontX, shop.FrontZ }
	end
	for _, path in World.Paths do
		if path.To and not targets[path.To] then
			local last = path.Points[#path.Points]
			targets[path.To] = { last[1], last[2] }
		end
	end
	targets.Piers = { 0, 299 }
	targets.Square = { World.Town.X, World.Town.Z }
	local labels = {
		Piers = "Piers",
		Lighthouse = "Lighthouse",
		Lagoon = "Lagoon",
		Lookout = "Lookout",
		Beach = "Beach",
		Square = "Town Square",
	}
	for id, text in LABELS do
		labels[id] = text
	end
	-- on the plaza (beside the statue, in view of the spawn and the arch: every shop), at every
	-- junction where the stairs climb to the next ledge, and at the ends of the boardwalk
	local posts = {
		-- (its arrows are routed from the middle of the plaza, the hub of the paths)
		{ At = { -14, 270 }, From = { World.Town.X, World.Town.Z }, To = { "Shipwright", "Merchant", "Armory", "TradingPost", "Tavern", "Piers" } },
		{ At = { -57, 268 }, To = { "Merchant", "TradingPost", "Tavern", "Square" } },
		{ At = { 40, 268 }, To = { "Shipwright", "Armory", "Lagoon", "Square" } },
		{ At = { -64, 210 }, To = { "TradingPost", "Tavern", "Lighthouse", "Lookout", "Square" } },
		{ At = { 64, 210 }, To = { "Armory", "Lagoon", "Square" } },
		{ At = { -40, 160 }, To = { "Tavern", "Lighthouse", "Square" } },
		{ At = { 88, 292 }, To = { "Beach", "Piers", "Square" } },
		{ At = { -88, 292 }, To = { "Beach", "Piers", "Square" } },
	}
	for _, post in posts do
		local boards = {}
		for _, id in post.To do
			local target = targets[id]
			if target then
				local dx, dz = routeDirection(nodes, edges, post.From or post.At, target)
				table.insert(boards, { labels[id] or id, dx, dz })
			end
		end
		signpost(folder, V(post.At[1], H.GetHeight(post.At[1], post.At[2]), post.At[2]), boards, rng)
		table.insert(clear, { X = post.At[1], Z = post.At[2], R = 4 })
	end
end

function MainIsland.Build(parent: any, H: any, World: any, Noise: any, clear: { any })
	local island = World.GetIsland(World.MainIslandName)
	local model = P.model(parent, "MainIsland")
	if not island then
		return model, {}
	end
	local rng = Noise.Rng(island.Seed * 104729 + 3)
	-- props along the paths first (they claim their space), then rocks and cliffs
	buildSignposts(model, H, World, rng, clear)
	buildWalkways(model, H, World, rng)
	buildBridges(model, H, World, rng, clear)
	buildTrails(model, H, World, rng, clear)
	ledgeRailings(model, H, World, rng, clear)
	buildStreams(model, H, World, rng, clear)
	buildTownRocks(model, H, World, rng, clear)
	buildSummitRocks(model, island, H, World, rng, clear)
	buildLookout(model, H, World, rng, clear)
	local cliffParts, cliffs = buildCliffs(model, island, H, World, rng, clear)
	local rockParts = buildRocks(model, island, H, World, rng, clear)
	local total = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			total += 1
		end
	end
	return model, { Cliffs = cliffs, CliffParts = cliffParts, RockParts = rockParts, Parts = total }
end

return MainIsland
