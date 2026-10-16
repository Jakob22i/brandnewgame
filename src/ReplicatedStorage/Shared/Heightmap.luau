--!strict
--!native
-- The shape of the world. GetHeight(x, z) returns the terrain surface height.
-- Used by: the terrain generator (runtime), ship grounding checks, enemy spawns,
-- the treasure map UI and the Lune build script (to place trees, rocks and buildings).
--
-- Kingshaven (the main island) has its own recipe: the town sits in a flat basin on the
-- south side, sandstone terraces with steep cliffs climb towards the lighthouse summit in
-- the north and the sea cliffs in the east and west, beaches open up to the south, and a
-- lagoon is cut into the eastern cliffs. Trails cut smooth ramps through the terraces.

local Noise = require(script.Parent.Noise)
local WorldData = require(script.Parent.WorldData)

local Heightmap = {}

local FLOOR = WorldData.FloorLevel
local SHELF = 0.7 -- how far the underwater shelf reaches, as a fraction of the radius
local BEACH = 0.12 -- beach width, as a fraction of the radius
local Town = WorldData.Town
local Harbor = WorldData.Harbor
local Lighthouse = WorldData.Lighthouse
local Lagoon = WorldData.Lagoon

-- Kingshaven terraces
local STEP = 16 -- height of one terrace level
local RISER = 0.08 -- part of a level taken by the cliff up to the next terrace
local CLIFF_COAST = 30 -- studs over which the sea cliffs drop from the terraces to the sea
local PATH_BANK = 7 -- studs beside a trail where the ground blends back into the terraces
-- Highlands of Kingshaven: flat-topped hills that the terracing turns into stacked mesas
local MESAS = {
	{ X = 235, Z = -195, R = 115, H = 22 }, -- north-east highlands
	{ X = -235, Z = -165, R = 120, H = 18 }, -- north-west highlands
	{ X = -330, Z = 40, R = 75, H = 12 }, -- west lookout
	{ X = 150, Z = -340, R = 60, H = 10 }, -- north bluff
}

for _, island in WorldData.Islands do
	island.Influence = island.Radius * (1 + island.Wobble + 0.08) * (1 + SHELF) + 8
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function smoothstep(e0: number, e1: number, x: number): number
	return smooth((x - e0) / (e1 - e0))
end

local function shelfHeight(t: number): number
	-- t <= 0: 0 at the coastline, -SHELF at the edge of the shelf
	local f = math.clamp(-t / SHELF, 0, 1)
	return -2.5 - (-2.5 - FLOOR) * f ^ 1.7
end

local function landHeight(island: WorldData.Island, t: number, x: number, z: number): number
	if t < BEACH then
		return -2.5 + 5.5 * smooth(t / BEACH)
	end
	local u = (t - BEACH) / (1 - BEACH)
	local hills = (Noise.Fbm2(x * 0.009, z * 0.009, island.Seed + 9, 3) + 1) * 0.5
	local shape = smooth(u) ^ island.Steep
	local h = 3 + (island.Height - 3) * shape * (0.55 + 0.9 * hills)
	h += Noise.Fbm2(x * 0.05, z * 0.05, island.Seed + 13, 2) * 1.6 * math.min(1, u * 4)
	return h
end

local function rectMask(x: number, z: number, r: typeof(Harbor)): number
	local dx = math.max(r.MinX - x, 0, x - r.MaxX)
	local dz = math.max(r.MinZ - z, 0, z - r.MaxZ)
	local d = math.sqrt(dx * dx + dz * dz)
	return 1 - smoothstep(0, r.Blend, d)
end

local function distToSegment(px: number, pz: number, x1: number, z1: number, x2: number, z2: number): number
	local vx, vz = x2 - x1, z2 - z1
	local len2 = vx * vx + vz * vz
	local t = if len2 > 0 then math.clamp(((px - x1) * vx + (pz - z1) * vz) / len2, 0, 1) else 0
	local cx, cz = x1 + vx * t, z1 + vz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- Quantises a height into flat terraces with steep risers between them
local function terrace(h: number): number
	local k = (h - Town.Height) / STEP
	local i = math.floor(k)
	local f = k - i
	if f < 1 - RISER then
		return Town.Height + i * STEP
	end
	return Town.Height + (i + smooth((f - (1 - RISER)) / RISER)) * STEP
end

-- Kingshaven ---------------------------------------------------------------------------

local summitLevel: number? = nil -- terrace height of the lighthouse summit (set below)

-- Height of the main island without the trails
local function mainRaw(island: WorldData.Island, x: number, z: number): number
	local dx = x - island.X
	local dz = z - island.Z
	local d = math.sqrt(dx * dx + dz * dz)
	local angle = math.atan2(dz, dx)
	local wobble = Noise.Fbm2(math.cos(angle) * 1.7 + island.Seed * 3.1, math.sin(angle) * 1.7 - island.Seed * 1.7, island.Seed, 3)
	local detail = Noise.Fbm2(x * 0.012, z * 0.012, island.Seed + 5, 2)
	local rEff = island.Radius * (1 + wobble * island.Wobble + detail * 0.05)
	local cd = rEff - d -- studs inland from the coastline

	-- beaches face south (the harbour side); everywhere else the coast is cliffs
	local south = dz / math.max(d, 1) + Noise.Fbm2(x * 0.006, z * 0.006, island.Seed + 21, 2) * 0.22
	local cliff = smoothstep(0.42, 0.12, south)

	local h: number
	if cd <= 0 then
		local t = cd / rEff
		h = shelfHeight(t) - cliff * 7 * (1 - smoothstep(0, 0.1, -t))
	else
		-- the land rises away from the town basin, highest in the north
		local tx, tz = x - Town.X, z - Town.Z
		local dT = math.max(0, math.sqrt(tx * tx + tz * tz) - Town.Radius)
		local hmax = 10 + 32 * smoothstep(0.55, 0.05, south) + 12 * smoothstep(-0.3, -0.9, south)
		local n = Noise.Fbm2(x * 0.011, z * 0.011, island.Seed + 9, 3)
		local e = Town.Height + hmax * (1 - math.exp(-dT / 80)) * (0.8 + 0.2 * (n + 1))
		local lx, lz = x - Lighthouse.X, z - Lighthouse.Z
		local ld = math.sqrt(lx * lx + lz * lz)
		e += Lighthouse.HillHeight * smooth(1 - ld / Lighthouse.HillRadius)
		for _, m in MESAS do
			local mx, mz = x - m.X, z - m.Z
			local md = mx * mx + mz * mz
			if md < m.R * m.R then
				e += m.H * smoothstep(m.R, m.R * 0.45, math.sqrt(md))
			end
		end

		-- terraces (sharp on the cliff sides, soft hills towards the beaches)
		if e > Town.Height then
			local jitter = (n + 1) * 2.4 + Noise.Fbm2(x * 0.03, z * 0.03, island.Seed + 31, 2) * 1.5
			local q = terrace(e + jitter)
			e += (math.max(q, Town.Height) - e) * (0.45 + 0.55 * cliff)
		end

		-- coast: one tall sea cliff drops into deep water, beaches slope gently into the shallows
		local cliffH = -7 + (e + 7) * smoothstep(0, CLIFF_COAST, cd)
		local beachW = island.Radius * BEACH
		local beachH = if cd < beachW then -2.5 + 5.5 * smooth(cd / beachW) else 3 + (e - 3) * smoothstep(beachW, beachW + 70, cd)
		h = beachH + (cliffH - beachH) * cliff
		h += Noise.Fbm2(x * 0.06, z * 0.06, island.Seed + 13, 2) * 0.6 * smoothstep(3, 8, h)

		-- flat summit for the lighthouse
		if summitLevel and ld < Lighthouse.SummitRadius + 10 then
			h += ((summitLevel :: number) - h) * (1 - smoothstep(Lighthouse.SummitRadius, Lighthouse.SummitRadius + 10, ld))
		end
	end

	-- the lagoon and its channel to the sea
	local lgx, lgz = x - Lagoon.X, z - Lagoon.Z
	if lgx > -Lagoon.Radius - 30 and lgz > -Lagoon.Radius - 30 and lgz < Lagoon.Radius + 30 then
		local edgeNoise = Noise.Fbm2(x * 0.05, z * 0.05, island.Seed + 41, 2) * 5
		local dl = math.sqrt(lgx * lgx + lgz * lgz) - Lagoon.Radius
		local dc = distToSegment(x, z, Lagoon.X, Lagoon.Z, Lagoon.ChannelX, Lagoon.ChannelZ) - Lagoon.ChannelWidth / 2
		local edge = math.min(dl, dc) + edgeNoise
		if edge < 12 then
			local floor = Lagoon.Depth + Noise.Fbm2(x * 0.04, z * 0.04, island.Seed + 43, 2) * 2
			h += (math.min(h, floor) - h) * (1 - smoothstep(0, 12, edge))
		end
	end

	-- the town basin is flat
	local tx, tz = x - Town.X, z - Town.Z
	if tx * tx + tz * tz < Town.Radius * Town.Radius then
		h = Town.Height
	end
	return h
end

do
	local main = WorldData.GetIsland(WorldData.MainIslandName)
	if main then
		local v = mainRaw(main, Lighthouse.X, Lighthouse.Z)
		summitLevel = Town.Height + math.floor((v - Town.Height) / STEP + 0.5) * STEP
	end
end

-- Trails: the ground along them is a smoothed version of the terrain (ramps instead of
-- cliffs). Each run of non-bridge segments is one track with a height profile.
type Track = {
	Segs: { { number } }, -- x1, z1, x2, z2, s0, length
	Profile: { number }, -- heights every SAMPLE studs along the track
	Half: number,
	MinX: number,
	MaxX: number,
	MinZ: number,
	MaxZ: number,
}
local SAMPLE = 2
local tracks: { Track } = {}

local function buildTracks()
	local main = WorldData.GetIsland(WorldData.MainIslandName)
	if not main then
		return
	end
	for _, path in WorldData.Paths do
		if not path.Ramp then
			continue
		end
		local bridges = {}
		for _, i in path.Bridges or {} do
			bridges[i] = true
		end
		local i = 1
		local n = #path.Points
		while i < n do
			if bridges[i] then
				i += 1
				continue
			end
			local track: Track = { Segs = {}, Profile = {}, Half = path.Width / 2, MinX = math.huge, MaxX = -math.huge, MinZ = math.huge, MaxZ = -math.huge }
			local s = 0
			while i < n and not bridges[i] do
				local a, b = path.Points[i], path.Points[i + 1]
				local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
				table.insert(track.Segs, { a[1], a[2], b[1], b[2], s, len })
				s += len
				track.MinX = math.min(track.MinX, a[1], b[1])
				track.MaxX = math.max(track.MaxX, a[1], b[1])
				track.MinZ = math.min(track.MinZ, a[2], b[2])
				track.MaxZ = math.max(track.MaxZ, a[2], b[2])
				i += 1
			end
			local pad = track.Half + PATH_BANK
			track.MinX -= pad
			track.MaxX += pad
			track.MinZ -= pad
			track.MaxZ += pad
			-- sample the terrain along the track, then smooth it twice (box filter)
			local raw = {}
			local count = math.floor(s / SAMPLE) + 1
			local segIndex = 1
			for k = 0, count - 1 do
				local sk = math.min(k * SAMPLE, s)
				while segIndex < #track.Segs and sk > track.Segs[segIndex][5] + track.Segs[segIndex][6] do
					segIndex += 1
				end
				local seg = track.Segs[segIndex]
				local t = if seg[6] > 0 then math.clamp((sk - seg[5]) / seg[6], 0, 1) else 0
				raw[k + 1] = mainRaw(main, seg[1] + (seg[3] - seg[1]) * t, seg[2] + (seg[4] - seg[2]) * t)
			end
			local radius = 7 -- samples
			for _ = 1, 2 do
				local out = table.create(count)
				for k = 1, count do
					local sum, w = 0, 0
					for j = math.max(1, k - radius), math.min(count, k + radius) do
						sum += raw[j]
						w += 1
					end
					out[k] = sum / w
				end
				raw = out
			end
			track.Profile = raw
			table.insert(tracks, track)
		end
	end
end
buildTracks()

-- Blends the terrain height towards the trail profiles near trails
local function applyTracks(x: number, z: number, h: number): number
	local bestW = 0
	local bestH = h
	for _, track in tracks do
		if x < track.MinX or x > track.MaxX or z < track.MinZ or z > track.MaxZ then
			continue
		end
		local bestD = math.huge
		local bestS = 0
		for _, seg in track.Segs do
			local vx, vz = seg[3] - seg[1], seg[4] - seg[2]
			local len2 = vx * vx + vz * vz
			local t = if len2 > 0 then math.clamp(((x - seg[1]) * vx + (z - seg[2]) * vz) / len2, 0, 1) else 0
			local cx, cz = seg[1] + vx * t, seg[2] + vz * t
			local dd = (x - cx) ^ 2 + (z - cz) ^ 2
			if dd < bestD then
				bestD = dd
				bestS = seg[5] + seg[6] * t
			end
		end
		local d = math.sqrt(bestD)
		local w = 1 - smoothstep(track.Half, track.Half + PATH_BANK, d)
		if w > bestW then
			local profile = track.Profile
			local f = bestS / SAMPLE + 1
			local k = math.clamp(math.floor(f), 1, #profile)
			local k2 = math.min(k + 1, #profile)
			local frac = math.clamp(f - k, 0, 1)
			bestW = w
			bestH = profile[k] + (profile[k2] - profile[k]) * frac
		end
	end
	return h + (bestH - h) * bestW
end

local function islandHeight(island: WorldData.Island, x: number, z: number): number
	local dx = x - island.X
	local dz = z - island.Z
	local influence = island.Influence :: number
	if math.abs(dx) > influence or math.abs(dz) > influence then
		return FLOOR
	end
	local d = math.sqrt(dx * dx + dz * dz)
	if d > influence then
		return FLOOR
	end

	if island.Kind == "Main" then
		local h = applyTracks(x, z, mainRaw(island, x, z))
		local hw = rectMask(x, z, Harbor)
		if hw > 0 then
			h = math.min(h, h + (Harbor.Depth - h) * hw)
		end
		return h
	end

	local angle = math.atan2(dz, dx)
	local wobble = Noise.Fbm2(math.cos(angle) * 1.7 + island.Seed * 3.1, math.sin(angle) * 1.7 - island.Seed * 1.7, island.Seed, 3)
	local detail = Noise.Fbm2(x * 0.012, z * 0.012, island.Seed + 5, 2)
	local rEff = island.Radius * (1 + wobble * island.Wobble + detail * 0.06)
	local dn = d / rEff
	local h: number

	if island.Kind == "Atoll" then
		if dn >= 0.86 then
			h = shelfHeight(0.86 - dn)
		else
			local ringT = 1 - math.abs(dn - 0.72) / 0.14
			-- two channels through the ring so ships can sail into the lagoon
			local gap = smoothstep(0.82, 0.96, math.cos(angle * 2 + island.Seed))
			ringT -= gap * 1.4
			if ringT > 0 then
				h = landHeight(island, ringT, x, z)
			else
				h = math.max(-7, -2.5 + ringT * 9) + Noise.Fbm2(x * 0.03, z * 0.03, island.Seed + 3, 2) * 0.8
			end
		end
		return h
	end

	local t = 1 - dn
	if t <= 0 then
		h = shelfHeight(t)
	else
		h = landHeight(island, t, x, z)
	end
	return h
end

-- Returns the terrain height and the island that owns this spot (nil = open sea)
function Heightmap.GetHeight(x: number, z: number): (number, WorldData.Island?)
	local best = FLOOR
	local bestIsland: WorldData.Island? = nil
	for _, island in WorldData.Islands do
		local h = islandHeight(island, x, z)
		if h > best then
			best = h
			bestIsland = island
		end
	end
	return best, bestIsland
end

function Heightmap.GetSlope(x: number, z: number): number
	local s = 3
	local hx1 = Heightmap.GetHeight(x + s, z)
	local hx0 = Heightmap.GetHeight(x - s, z)
	local hz1 = Heightmap.GetHeight(x, z + s)
	local hz0 = Heightmap.GetHeight(x, z - s)
	local gx = (hx1 - hx0) / (2 * s)
	local gz = (hz1 - hz0) / (2 * s)
	return math.sqrt(gx * gx + gz * gz)
end

-- Height of the terrace levels on Kingshaven (flat terraces sit at Town.Height + k * step)
Heightmap.TerraceStep = STEP

-- Returns the name of a road material if (x, z) is on a road, otherwise nil
function Heightmap.GetRoadMaterial(x: number, z: number): string?
	local wiggle = Noise.Value2(x * 0.15, z * 0.15, 909) * 0.8
	for _, road in WorldData.Roads do
		local half = road.Width / 2 + wiggle
		if x < math.min(road.X1, road.X2) - half or x > math.max(road.X1, road.X2) + half then
			continue
		end
		if z < math.min(road.Z1, road.Z2) - half or z > math.max(road.Z1, road.Z2) + half then
			continue
		end
		if distToSegment(x, z, road.X1, road.Z1, road.X2, road.Z2) <= half then
			return road.Material
		end
	end
	return nil
end

-- Terrain material name for a column (string so the module stays engine-agnostic)
function Heightmap.GetMaterial(x: number, z: number, h: number, slope: number, island: WorldData.Island?): string
	if island == nil then
		return "Sand"
	end
	if island.Kind == "Main" then
		local tx, tz = x - Town.X, z - Town.Z
		if tx * tx + tz * tz < Town.SquareRadius * Town.SquareRadius then
			return "Cobblestone"
		end
		local road = Heightmap.GetRoadMaterial(x, z)
		if road then
			return road
		end
		if slope > 0.7 then
			-- terrace cliffs are layered sandstone, the sea cliffs below them rock
			if h < 5 + Noise.Value2(x * 0.08, z * 0.08, 515) * 3 then
				return "Rock"
			end
			return "Sandstone"
		end
		if h < 3.3 then
			return "Sand"
		end
		if slope > 0.45 then
			return "Ground"
		end
		-- lush leafy jungle floor on the terraces, brighter meadows in and around the town
		local n = Noise.Fbm2(x * 0.02, z * 0.02, 777, 2)
		local inTown = tx * tx + tz * tz < (Town.Radius + 15) * (Town.Radius + 15)
		if n > (if inTown or h < 9 then 0.25 else -0.3) then
			return "LeafyGrass"
		end
		return "Grass"
	end
	if h < 3.3 then
		return "Sand"
	end
	if island.Kind == "Rocky" then
		if slope > 0.55 or h > island.Height * 0.55 then
			return island.RockMaterial
		end
	elseif slope > 0.95 then
		return island.RockMaterial
	end
	if island.Kind == "Flat" and h < 6 then
		return "Sand"
	end
	if Noise.Fbm2(x * 0.02, z * 0.02, 777, 2) > 0.18 then
		return "LeafyGrass"
	end
	return "Grass"
end

-- Is this spot dry land that is reasonably flat? (used for spawning things)
function Heightmap.IsGoodLand(x: number, z: number, minHeight: number?, maxSlope: number?): boolean
	local h = Heightmap.GetHeight(x, z)
	if h < (minHeight or 3.5) then
		return false
	end
	return Heightmap.GetSlope(x, z) < (maxSlope or 0.5)
end

return Heightmap
