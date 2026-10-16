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
local CLIFF_BUDGET = 1050 -- terrace cliffs and the lagoon walls
local COAST_BUDGET = 440 -- sea cliffs
local BOULDERS = 14
local SEA_STACKS = 8
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

-- Stacked slabs on a cliff face. foot = cliff foot (on the lower ground), n = outward
-- (downhill) direction, yb/yt = bottom/top heights, run = horizontal run of the cliff,
-- capColor = colour of the grass on the terrace above (the cap blends into it).
local function cliffRock(parent: any, rng: any, foot: any, n: any, yb: number, yt: number, run: number, width: number, capColor: any): number
	local m = P.model(parent, "CliffRock")
	local cf = frame(V(foot.X, yb, foot.Z), n)
	local height = yt - yb
	local depth = run + rng:Range(3, 4.5)
	local layers = math.max(1, math.floor((height + 2.5) / math.max(4.6, height / 7) + 0.5))
	local layerT = (height + 2.5) / layers
	local y = -2.5
	local maxOut = 0
	local count = 0
	for i = 1, layers do
		local th = layerT * rng:Range(0.88, 1.12)
		if i == layers then
			th = height - 0.3 - y
		end
		local out = rng:Range(-0.5, 1.6) + (if i == layers then 0.5 else 0)
		maxOut = math.max(maxOut, out)
		local w = width * rng:Range(0.8, 1.02)
		local color = Nature.Shade(Nature.SANDSTONE[(i + rng:Int(0, 1)) % #Nature.SANDSTONE + 1], rng:Range(0.95, 1.04))
		P.part(m, {
			Name = "Slab",
			Size = V(w, th + 0.15, depth + out),
			CFrame = cf * CF(rng:Range(-0.08, 0.08) * width, y + th / 2, (depth - out) / 2) * Angles(rng:Range(-0.02, 0.02), rng:Range(-0.1, 0.1), rng:Range(-0.03, 0.03)),
			Mat = "Sandstone",
			Color = color,
		})
		count += 1
		if th > 2.5 and rng:Next() < 0.3 then
			-- a rounded bulge sticking out of this layer
			local bw = w * rng:Range(0.25, 0.45)
			local bOut = out + rng:Range(0.8, 1.8)
			maxOut = math.max(maxOut, bOut)
			P.part(m, {
				Name = "Slab",
				Size = V(bw, th * rng:Range(0.7, 0.95), 4 + bOut),
				CFrame = cf * CF(rng:Range(-0.3, 0.3) * width, y + th * 0.45, (4 - bOut) / 2) * Angles(0, rng:Range(-0.2, 0.2), 0),
				Mat = "Sandstone",
				Color = Nature.Shade(color, rng:Range(0.92, 1.06)),
			})
			count += 1
		end
		y += th
	end
	-- a lip of grass hanging over the edge, flush with the terrace above
	local capOut = maxOut + 0.3
	local capBack = 2.5
	P.part(m, {
		Name = "GrassCap",
		Size = V(width * rng:Range(0.86, 0.96), 0.7, capOut + capBack),
		CFrame = cf * CF(0, height - 0.25, (capBack - capOut) / 2) * Angles(rng:Range(0.03, 0.1), rng:Range(-0.05, 0.05), 0),
		Mat = "LeafyGrass",
		Color = capColor,
	})
	count += 1
	-- overgrowth curtain under the cap and vines hanging down the face
	if rng:Next() < 0.6 then
		local cw = width * rng:Range(0.3, 0.6)
		local ch = math.min(height * 0.3, rng:Range(1.8, 3.2))
		P.part(m, { Name = "Overgrowth", Size = V(cw, ch, 0.5), CFrame = cf * CF(rng:Range(-0.25, 0.25) * width, height - ch / 2 - 0.45, -capOut + 0.5), Mat = "LeafyGrass", Color = pick(rng, VINES), CanCollide = false })
		count += 1
	end
	local vines = if height > 9 then rng:Int(1, 2) else rng:Int(0, 1)
	for _ = 1, vines do
		local len = math.min(height * rng:Range(0.3, 0.75), rng:Range(8, 16))
		local vx = rng:Range(-0.42, 0.42) * width
		local vw = rng:Range(0.8, 1.8)
		P.part(m, { Name = "Vine", Size = V(vw, len, 0.25), CFrame = cf * CF(vx, height - len / 2 - 0.3, -capOut + 0.2), Mat = "LeafyGrass", Color = pick(rng, VINES), CanCollide = false, CanQuery = false })
		count += 1
	end
	return count
end

-- A tall pillar of stacked slabs (sea stacks and landmark rocks): chunky layers of similar
-- size, each turned and shifted a little, with a grass cap and a vine or two.
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
		local th = math.min(rng:Range(0.34, 0.5) * width, height - y + 0.4)
		w = width * (0.82 + 0.28 * math.sin(math.pi * math.min(1, t * 0.8 + 0.25))) * rng:Range(0.9, 1.05)
		d = w * rng:Range(0.72, 0.95)
		yaw += rng:Range(-0.32, 0.32)
		ox += math.cos(la) * drift + rng:Range(-0.05, 0.05) * width
		oz += math.sin(la) * drift + rng:Range(-0.05, 0.05) * width
		local color = Nature.Shade(Nature.SANDSTONE[(layer + rng:Int(0, 2)) % #Nature.SANDSTONE + 1], rng:Range(0.94, 1.04))
		local cf = CF(base + V(ox, y + th / 2, oz)) * Angles(rng:Range(-0.04, 0.04), yaw, rng:Range(-0.04, 0.04))
		-- two boxes turned 45 degrees against each other: an eight-sided, rounder layer
		P.part(m, { Name = "Slab", Size = V(w, th + 0.1, d), CFrame = cf, Mat = "Sandstone", Color = color })
		P.part(m, { Name = "Slab", Size = V(w * 0.86, th + 0.1 - rng:Range(0, 0.4), d * 0.86), CFrame = cf * Angles(0, math.pi / 4, 0), Mat = "Sandstone", Color = Nature.Shade(color, 0.97) })
		count += 2
		y += th
	end
	local capCF = CF(base + V(ox, y + 0.1, oz)) * Angles(0, yaw + rng:Range(-0.15, 0.15), 0)
	P.part(m, { Name = "GrassCap", Size = V(w * 0.92, 0.8, d * 0.92), CFrame = capCF, Mat = "LeafyGrass", Color = pick(rng, Nature.GRASS_CAP) })
	count += 1
	for _ = 1, rng:Int(1, 2) do
		local side = rng:Int(0, 3)
		local len = math.min(height * rng:Range(0.25, 0.5), 14)
		local off = if side % 2 == 0 then CF(rng:Range(-0.3, 0.3) * w, -len / 2, (if side == 0 then 1 else -1) * (d * 0.46 + 0.2)) else CF((if side == 1 then 1 else -1) * (w * 0.46 + 0.2), -len / 2, rng:Range(-0.3, 0.3) * d)
		local rot = if side % 2 == 0 then CF() else Angles(0, math.pi / 2, 0)
		P.part(m, { Name = "Vine", Size = V(rng:Range(0.9, 1.6), len, 0.25), CFrame = capCF * off * rot, Mat = "LeafyGrass", Color = pick(rng, VINES), CanCollide = false, CanQuery = false })
		count += 1
	end
	return count, y + 0.5
end

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
	local spots = {}
	for _, c in candidates do
		local fx, fz, fh, dDown = walk(c[1], c[2], c[3], c[4], 1)
		local tx, tz, th, dUp = walk(c[1], c[2], c[3], c[4], -1)
		local height = th - fh
		if height >= 5 then
			table.insert(spots, { Fx = fx, Fz = fz, Fh = fh, Th = th, Run = dDown + dUp, Nx = c[3], Nz = c[4], Mx = (fx + tx) / 2, Mz = (fz + tz) / 2, Height = height, Score = math.min(height, 16) + c[5] * 12 + (if nearPath(c[1], c[2]) then 14 else 0) + (if (c[1] - town.X) ^ 2 + (c[2] - town.Z) ^ 2 < (town.Radius + 130) ^ 2 then 10 else 0) })
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
		local coast = s.Fh < 2
		if (coast and coastParts >= COAST_BUDGET) or (not coast and parts >= CLIFF_BUDGET) then
			continue
		end
		local width = if s.Height > 20 then rng:Range(24, 32) else rng:Range(15, 23)
		local tooClose = false
		for _, p in placed do
			local need = (width + p[3]) * 0.42
			if (p[1] - s.Mx) ^ 2 + (p[2] - s.Mz) ^ 2 < need * need then
				tooClose = true
				break
			end
		end
		if tooClose then
			continue
		end
		-- the footprint must stay off the paths and out of the keep-clear zones
		local nx, nz = s.Nx, s.Nz
		local lx, lz = -nz, nx
		local depth = s.Run + 7
		local blockedHere = false
		for _, a in { -0.5, 0, 0.5 } do
			for _, b in { -0.5, 0.2, 1 } do
				local px = s.Fx + lx * a * width - nx * b * depth
				local pz = s.Fz + lz * a * width - nz * b * depth
				if Nature.Blocked(px, pz, World, clear, 3) then
					blockedHere = true
					break
				end
			end
			if blockedHere then
				break
			end
		end
		if blockedHere then
			continue
		end
		-- the lowest ground along the foot (so the slabs never float) and the lowest top
		-- edge along the width (so they never stick up out of the terrace)
		local yb = s.Fh
		local yt = s.Th
		local tx, tz = s.Fx - nx * (s.Run + 2.5), s.Fz - nz * (s.Run + 2.5)
		local lopsided = false
		for _, a in { -0.45, 0.45 } do
			yb = math.min(yb, (H.GetHeight(s.Fx + lx * a * width + nx * 1.5, s.Fz + lz * a * width + nz * 1.5)))
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
		local capColor = if capMat == "LeafyGrass" then rgb(70, 160, 56) elseif capMat == "Sand" then rgb(240, 216, 160) else rgb(98, 182, 68)
		local n = cliffRock(folder, rng, V(s.Fx + nx * 0.8, 0, s.Fz + nz * 0.8), V(nx, 0, nz), yb, yt, s.Run + 0.8, width, capColor)
		if coast then
			coastParts += n
		else
			parts += n
		end
		count += 1
		table.insert(placed, { s.Mx, s.Mz, width })
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
				local m, top = Nature.SlabStack(folder, cf, size * 1.3, size, size * rng:Range(0.55, 0.9), rng, Nature.SANDSTONE, "Sandstone", true)
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

-- Paths: helpers ------------------------------------------------------------------------------

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
		-- stairs where the ramp is steep
		if path.Ramp then
			local run = {}
			local function flush()
				if #run >= 4 then
					local stair = P.model(stairsFolder, path.Name .. "Stairs")
					for k, smp in ipairs(run) do
						smp.Stair = true
						local dir = V(smp.Dx, 0, smp.Dz)
						local h0 = H.GetHeight(smp.X - smp.Dx * 1.0, smp.Z - smp.Dz * 1.0)
						local h1 = H.GetHeight(smp.X + smp.Dx * 1.0, smp.Z + smp.Dz * 1.0)
						local top = math.max(h0, h1, smp.H) + 0.3
						local cf = frame(V(smp.X, top - 0.6, smp.Z), dir)
						P.part(stair, { Name = "Step", Size = V(path.Width - 0.6, 1.2, 1.9), CFrame = cf * Angles(0, rng:Range(-0.03, 0.03), 0), Mat = "WoodPlanks", Color = pick(rng, PLANKS) })
						-- rope rail posts every few steps
						if k % 5 == 1 or k == #run then
							for _, side in { -1, 1 } do
								local p = V(smp.X, top - 0.3, smp.Z) + dir:Cross(UP) * side * (half + 0.2)
								P.part(stair, { Name = "RailPost", Size = V(0.55, 3.4, 0.55), CFrame = CF(p + V(0, 1.2, 0)), Mat = "Wood", Color = DARK_WOOD })
								smp["Post" .. side] = p
							end
						end
					end
					-- ropes between the posts
					for _, side in { -1, 1 } do
						local last = nil
						for _, smp in ipairs(run) do
							local p = smp["Post" .. side]
							if p then
								if last then
									P.beam(stair, last + V(0, 2.6, 0), p + V(0, 2.6, 0), 0.22, { Name = "Rope", Mat = "Fabric", Color = ROPE, CanCollide = false })
								end
								last = p
							end
						end
					end
					local mid = run[math.floor(#run / 2) + 1]
					table.insert(clear, { X = mid.X, Z = mid.Z, R = #run * STEP / 2 + half })
				end
				run = {}
			end
			for k = 1, #samples do
				local a = samples[math.max(1, k - 1)]
				local b = samples[math.min(#samples, k + 1)]
				local ds = math.max(0.1, b.S - a.S)
				local slope = math.abs(b.H - a.H) / ds
				local smp = samples[k]
				local sameLine = #run == 0 or (smp.S - run[#run].S) < STEP * 1.5
				if slope > 0.2 and sameLine then
					table.insert(run, smp)
				else
					flush()
					if slope > 0.2 then
						table.insert(run, smp)
					end
				end
			end
			flush()
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
					local inTown = (smp.X - town.X) ^ 2 + (smp.Z - town.Z) ^ 2 < (town.Radius - 5) ^ 2
					if drop > 4 and not inTown and not smp.Stair then
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
						nextS = smp.S + 36
					end
				end
			end
		end
	end
end

-- Raised plank walkways (path.Planks segments): boards across two stringers
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
				t0 = 6.5
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
			local top = h + 0.6
			local n = math.floor((t1 - t0) / 1.15)
			for k = 0, n do
				local t = t0 + (t1 - t0) * (k / n)
				local c = V(a[1] + dx * t, top - 0.2, a[2] + dz * t)
				P.part(m, { Name = "Board", Size = V(path.Width + rng:Range(0.2, 0.7), 0.4, 1.0), CFrame = frame(c, dir) * CF(rng:Range(-0.15, 0.15), rng:Range(-0.03, 0.03), 0) * Angles(0, rng:Range(-0.04, 0.04), 0), Mat = "WoodPlanks", Color = pick(rng, PLANKS) })
			end
			local mid = V((ax + bx) / 2, top - 0.75, (az + bz) / 2)
			for _, side in { -1, 1 } do
				P.part(m, { Name = "Stringer", Size = V(0.6, 0.8, t1 - t0 + 0.6), CFrame = frame(mid + right * side * (path.Width / 2 - 0.6), dir), Mat = "Wood", Color = DARK_WOOD })
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

local function buildSignposts(model: any, World: any, rng: any, clear: { any })
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
	local sp = World.SpawnPoint
	local posts = {
		{ At = { sp.X - 10.5, sp.Z + 9 }, To = { "Shipwright", "Merchant", "Piers", "Armory", "Tavern", "TradingPost" } },
		{ At = { -10, 262 }, To = { "Shipwright", "Merchant", "Piers", "Square" } },
		{ At = { 9, 60 }, To = { "Lighthouse", "TradingPost", "Square" } },
		{ At = { 50, 88 }, To = { "Lagoon", "Square" } },
		{ At = { -50, 88 }, To = { "Lookout", "Square" } },
		{ At = { 88, 292 }, To = { "Beach", "Piers", "Square" } },
		{ At = { -88, 292 }, To = { "Beach", "Piers", "Square" } },
	}
	for _, post in posts do
		local boards = {}
		for _, id in post.To do
			local target = targets[id]
			if target then
				local dx, dz = routeDirection(nodes, edges, post.At, target)
				table.insert(boards, { labels[id] or id, dx, dz })
			end
		end
		signpost(folder, V(post.At[1], World.Town.Height, post.At[2]), boards, rng)
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
	buildSignposts(model, World, rng, clear)
	buildWalkways(model, H, World, rng)
	buildBridges(model, H, World, rng, clear)
	buildTrails(model, H, World, rng, clear)
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
