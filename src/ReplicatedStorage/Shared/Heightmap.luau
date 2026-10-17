--!strict
--!native
-- The shape of the world. GetHeight(x, z) returns the terrain surface height.
-- Used by: the terrain generator (runtime), ship grounding checks, enemy spawns,
-- the treasure map UI and the Lune build script (to place trees, rocks and buildings).
--
-- Kingshaven (the main island) has its own recipe: the town wraps around an inner pool in a
-- basin on the south side. Rounded sandstone ledges (WorldData.Ledges) rise out of the basin
-- at the town's levels, with towering outcrops on the rim; a cascade drops down three rock
-- steps into the pool, which drains through a rocky cut to the harbour beach. Beyond the rim,
-- sandstone terraces climb towards the lighthouse summit in the north and the sea cliffs in
-- the east and west, and a lagoon is cut into the eastern cliffs. Trails cut smooth ramps
-- (with plank stairs) through the cliffs.

local Noise = require(script.Parent.Noise)
local WorldData = require(script.Parent.WorldData)

local Heightmap = {}

local FLOOR = WorldData.FloorLevel
local SHELF = 0.7 -- how far the underwater shelf reaches, as a fraction of the radius
local BEACH = 0.12 -- beach width, as a fraction of the radius
local Town = WorldData.Town
local Basin = WorldData.Basin
local Pool = WorldData.Pool
local PoolCut = WorldData.PoolCut
local Harbor = WorldData.Harbor
local Lighthouse = WorldData.Lighthouse
local Lagoon = WorldData.Lagoon

-- Kingshaven terraces
local STEP = 16 -- height of one terrace level
local RISER = 0.08 -- part of a level taken by the cliff up to the next terrace
local CLIFF_COAST = 46 -- studs over which the sea cliffs drop from the terraces to the sea
local PATH_BANK = 7 -- studs beside a trail where the ground blends back into the terraces
-- Highlands of Kingshaven: flat-topped hills that the terracing turns into stacked mesas
local MESAS = {
	{ X = 235, Z = -195, R = 115, H = 22 }, -- north-east highlands
	{ X = -235, Z = -165, R = 120, H = 18 }, -- north-west highlands
	{ X = -330, Z = 40, R = 75, H = 12 }, -- west lookout
	{ X = 150, Z = -340, R = 60, H = 10 }, -- north bluff
	{ X = 0, Z = 30, R = 190, H = 34 }, -- highland behind the town's rim
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

-- Kingshaven: the town's ledges, the pool and its cut ---------------------------------------

-- Ledges prepared for fast lookups (cos/sin of the yaw, a bounding square)
type PreparedLedge = { X: number, Z: number, Rx: number, Rz: number, C: number, S: number, H: number, Edge: number, Rough: number, Bound: number }
local ledges: { PreparedLedge } = {}
local ledgeBox = { math.huge, -math.huge, math.huge, -math.huge }
for _, l in WorldData.Ledges do
	local bound = math.max(l.Rx, l.Rz) + l.Edge + 8
	table.insert(ledges, { X = l.X, Z = l.Z, Rx = l.Rx, Rz = l.Rz, C = math.cos(l.Yaw), S = math.sin(l.Yaw), H = l.H, Edge = l.Edge, Rough = l.Rough, Bound = bound })
	ledgeBox[1] = math.min(ledgeBox[1], l.X - bound)
	ledgeBox[2] = math.max(ledgeBox[2], l.X + bound)
	ledgeBox[3] = math.min(ledgeBox[3], l.Z - bound)
	ledgeBox[4] = math.max(ledgeBox[4], l.Z + bound)
end

-- Signed distance (studs, negative inside) from (x, z) to the rim of an ellipse, a first-order
-- estimate that is exact on the rim and scales with the radius in that direction elsewhere.
-- (lx, lz) = position in the ellipse's own frame
local function ellipseDistance(lx: number, lz: number, rx: number, rz: number): number
	local u, v = lx / rx, lz / rz
	local q = math.sqrt(u * u + v * v)
	local g = math.sqrt((u / rx) ^ 2 + (v / rz) ^ 2)
	if g < 1e-6 then
		return -math.min(rx, rz)
	end
	return (q - 1) * q / g
end

-- The town's rock ledges over the ground height h: flat tops at the ledge level with rounded
-- lips and steep cliffs falling off the edge (the highest ledge wins)
local function applyLedges(x: number, z: number, h: number): number
	if x < ledgeBox[1] or x > ledgeBox[2] or z < ledgeBox[3] or z > ledgeBox[4] then
		return h
	end
	local wob: number? = nil
	local rough = 0
	for _, l in ledges do
		local dx, dz = x - l.X, z - l.Z
		if math.abs(dx) > l.Bound or math.abs(dz) > l.Bound then
			continue
		end
		if wob == nil then
			-- one wobble for the outlines (strata line up from ledge to ledge) and one for the tops
			wob = Noise.Fbm2(x * 0.032, z * 0.032, 6101, 2) + Noise.Value2(x * 0.11, z * 0.11, 6113) * 0.25
			rough = Noise.Fbm2(x * 0.05, z * 0.05, 6131, 2)
		end
		-- the rims wobble more than the shop ledges
		local d = ellipseDistance(dx * l.C - dz * l.S, dx * l.S + dz * l.C, l.Rx, l.Rz) + (wob :: number) * (5 + 4 * l.Rough)
		local lh
		if d <= 0 then
			lh = l.H + rough * l.Rough * smoothstep(0, 12, -d)
		else
			-- the cliff comes down in rounded steps (strata), with a lip at the top
			local t = math.min(d / l.Edge, 1) * 3
			local k = math.floor(t)
			lh = l.H - (l.H + 12) * (k + smooth((t - k) * 1.5)) / 3
		end
		if lh > h then
			h = lh
		end
	end
	return h
end

-- Distance from (x, z) to the pool's shore and to the cut's banks (negative = in the water)
local function poolDistance(x: number, z: number): number
	return ellipseDistance(x - Pool.X, z - Pool.Z, Pool.Rx, Pool.Rz)
end

local cutBox = { math.huge, -math.huge, math.huge, -math.huge }
for _, pt in PoolCut.Points do
	cutBox[1] = math.min(cutBox[1], pt[1] - 30)
	cutBox[2] = math.max(cutBox[2], pt[1] + 30)
	cutBox[3] = math.min(cutBox[3], pt[2] - 30)
	cutBox[4] = math.max(cutBox[4], pt[2] + 30)
end
local poolBox = { Pool.X - Pool.Rx - 30, Pool.X + Pool.Rx + 30, Pool.Z - Pool.Rz - 30, Pool.Z + Pool.Rz + 30 }

-- (points may carry their own width as a third number; the cut widens into a creek mouth)
local function cutDistance(x: number, z: number): number
	if x < cutBox[1] or x > cutBox[2] or z < cutBox[3] or z > cutBox[4] then
		return math.huge
	end
	local best = math.huge
	local pts = PoolCut.Points
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local vx, vz = b[1] - a[1], b[2] - a[2]
		local len2 = vx * vx + vz * vz
		local t = if len2 > 0 then math.clamp(((x - a[1]) * vx + (z - a[2]) * vz) / len2, 0, 1) else 0
		local wa, wb = a[3] or PoolCut.Width, b[3] or PoolCut.Width
		local d = math.sqrt((x - a[1] - vx * t) ^ 2 + (z - a[2] - vz * t) ^ 2) - (wa + (wb - wa) * t) / 2
		best = math.min(best, d)
	end
	return best
end

-- The pool is a turquoise bowl with steep rock walls; the cut a narrow channel to the sea.
-- Applied last, so trails and ledges never fill them in.
local function carveWater(x: number, z: number, h: number): number
	local inPool = x > poolBox[1] and x < poolBox[2] and z > poolBox[3] and z < poolBox[4]
	local inCut = x > cutBox[1] and x < cutBox[2] and z > cutBox[3] and z < cutBox[4]
	if not inPool and not inCut then
		return h
	end
	local w = Noise.Fbm2(x * 0.06, z * 0.06, 917, 2)
	if inPool then
		local dp = poolDistance(x, z) + w * 3.5
		local floor = if dp < 0 then 0.8 + (Pool.Depth - 0.8) * smoothstep(0, -10, dp) else 0.8 + dp * 3.2
		h = math.min(h, floor)
	end
	if inCut then
		local dc = cutDistance(x, z) + w * 1.5
		local floor = if dc < 0 then PoolCut.Depth else PoolCut.Depth + dc * 2.6
		h = math.min(h, floor)
	end
	return h
end

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
		local tx, tz = x - Basin.X, z - Basin.Z
		local dB = math.sqrt(tx * tx + tz * tz)
		local dT = math.max(0, dB - Basin.Radius)
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
		-- the floor of the town basin stays at the harbour level (the ledges rise out of it)
		e += (Town.Height - e) * (1 - smoothstep(Basin.Radius - 10, Basin.Radius + 30, dB))

		-- terraces (sharp on the cliff sides, soft hills towards the beaches)
		if e > Town.Height then
			local jitter = (n + 1) * 2.4 + Noise.Fbm2(x * 0.03, z * 0.03, island.Seed + 31, 2) * 1.5
			local q = terrace(e + jitter)
			e += (math.max(q, Town.Height) - e) * (0.45 + 0.55 * cliff)
		end

		-- coast: one tall sea cliff drops into deep water, beaches slope gently into the shallows
		-- the sea cliffs come down in broken, layered steps (ledges of the terrace height)
		local reach = CLIFF_COAST * (0.75 + 0.5 * (Noise.Fbm2(x * 0.02, z * 0.02, island.Seed + 51, 2) + 1) * 0.5)
		local cliffH = -7 + (e + 7) * smoothstep(0, reach, cd)
		if cliffH > Town.Height + 2 then
			local k = (cliffH - Town.Height) / STEP
			local i = math.floor(k)
			local f = k - i
			cliffH = Town.Height + (i + smooth((f - 0.62) / 0.38)) * STEP
		end
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

	-- the town's rock ledges and outcrops
	return applyLedges(x, z, h)
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
local MAX_RAMP = 0.58 -- steepest trail ramp (about 30 degrees; plank stairs cover the steep parts)
local LEAD_IN = 3 -- samples at each end of a trail that stay level
local tracks: { Track } = {}

local applyTracks: (x: number, z: number, h: number) -> number

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
		local bridgeList: { number } = path.Bridges or {}
		for _, i in bridgeList do
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
				-- (the ground with the tracks built so far, so a branch meets its trunk level)
				local sx, sz = seg[1] + (seg[3] - seg[1]) * t, seg[2] + (seg[4] - seg[2]) * t
				raw[k + 1] = applyTracks(sx, sz, mainRaw(main, sx, sz))
			end
			-- the window shrinks towards the ends, so a track ends at the true ground height
			-- (shop fronts and junctions stay level; the ramp fits between them)
			local radius = 7 -- samples
			for _ = 1, 2 do
				local out = table.create(count)
				for k = 1, count do
					local sum, w = 0, 0
					local r = math.min(radius, k - 1, count - k)
					for j = k - r, k + r do
						sum += raw[j]
						w += 1
					end
					out[k] = sum / w
				end
				raw = out
			end
			-- no stretch steeper than MAX_RAMP, with both ends kept: from the start the ramp
			-- cuts into the ground ahead, from the end it is built up over the ground behind
			-- both ends stay level for a few studs (shop fronts, and junctions where a branch
			-- leaves its trunk), then no stretch is steeper than MAX_RAMP
			local lead = math.min(LEAD_IN, (count - 1) // 3)
			for k = 2, lead + 1 do
				raw[k] = raw[1]
				raw[count + 1 - k] = raw[count]
			end
			local drop = MAX_RAMP * SAMPLE
			local endH = raw[count]
			for k = 2, count do
				raw[k] = math.clamp(raw[k], raw[k - 1] - drop, raw[k - 1] + drop)
			end
			raw[count] = endH
			for k = count - 1, 1, -1 do
				raw[k] = math.clamp(raw[k], raw[k + 1] - drop, raw[k + 1] + drop)
			end
			track.Profile = raw
			table.insert(tracks, track)
		end
	end
end

-- Blends the terrain height towards the trail profiles near trails
function applyTracks(x: number, z: number, h: number): number
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

buildTracks()

-- Stream beds: a shallow trough along each stream (only on dry land)
local streamBox = { math.huge, -math.huge, math.huge, -math.huge }
for _, stream in WorldData.Streams do
	for _, pt in stream.Points do
		streamBox[1] = math.min(streamBox[1], pt[1] - 12)
		streamBox[2] = math.max(streamBox[2], pt[1] + 12)
		streamBox[3] = math.min(streamBox[3], pt[2] - 12)
		streamBox[4] = math.max(streamBox[4], pt[2] + 12)
	end
end

local function streamDistance(x: number, z: number): (number, WorldData.Stream?)
	if x < streamBox[1] or x > streamBox[2] or z < streamBox[3] or z > streamBox[4] then
		return math.huge, nil
	end
	local best, bestStream = math.huge, nil
	for _, stream in WorldData.Streams do
		local pts = stream.Points
		for i = 1, #pts - 1 do
			local d = distToSegment(x, z, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]) - stream.Width / 2
			if d < best then
				best, bestStream = d, stream
			end
		end
	end
	return best, bestStream
end

local function carveStreams(x: number, z: number, h: number): number
	if h < 3 then
		return h
	end
	local d, stream = streamDistance(x, z)
	if stream == nil or d > 3 then
		return h
	end
	local depth = (stream :: WorldData.Stream).Depth * (1 - smoothstep(-1.5, 3, d))
	return math.max(h - depth, math.min(h, 3))
end

-- The waterfront: in front of the quay wall the harbour level drops to a strip of beach that
-- slopes into the sea (not under the pier roots, whose banks carry the pier ramps)
local Quay = WorldData.Quay
local function applyQuay(x: number, z: number, h: number): number
	if z < Quay.Z or x < Quay.MinX - Quay.Blend or x > Quay.MaxX + Quay.Blend then
		return h
	end
	local w = smoothstep(Quay.MinX - Quay.Blend, Quay.MinX, x) * (1 - smoothstep(Quay.MaxX, Quay.MaxX + Quay.Blend, x))
	for _, pier in WorldData.Piers do
		w *= smoothstep(1.5, 7, math.abs(x - pier.X) - pier.HalfWidth)
	end
	if w <= 0 then
		return h
	end
	local dz = z - Quay.Z
	local u = math.max(0, dz - 1.6)
	local beach = Quay.Beach - u * 0.1 - u * u * 0.01 + Noise.Fbm2(x * 0.07, z * 0.07, 4411, 2) * 0.35 * smoothstep(1.6, 6, dz)
	local target = if dz < 1.6 then h + (beach - h) * smooth(dz / 1.6) else beach
	return h + (math.min(h, target) - h) * w
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
		local h = carveStreams(x, z, carveWater(x, z, applyQuay(x, z, applyTracks(x, z, mainRaw(island, x, z)))))
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

-- How far (x, z) is outside the nearest road edge (<= 0 on a road, at most `reach`) and the
-- material of that road
local function roadDistance(x: number, z: number, reach: number): (number, string?)
	local wiggle = Noise.Value2(x * 0.15, z * 0.15, 909) * 0.8
	local best, material = reach, nil
	for _, road in WorldData.Roads do
		local half = road.Width / 2 + wiggle
		local pad = half + reach
		if x < math.min(road.X1, road.X2) - pad or x > math.max(road.X1, road.X2) + pad then
			continue
		end
		if z < math.min(road.Z1, road.Z2) - pad or z > math.max(road.Z1, road.Z2) + pad then
			continue
		end
		local d = distToSegment(x, z, road.X1, road.Z1, road.X2, road.Z2) - half
		if d < best then
			best, material = d, road.Material
			if d <= 0 then
				break
			end
		end
	end
	return best, material
end

-- Terrain material name for a column (string so the module stays engine-agnostic)
function Heightmap.GetMaterial(x: number, z: number, h: number, slope: number, island: WorldData.Island?): string
	if island == nil then
		return "Sand"
	end
	if island.Kind == "Main" then
		local tx, tz = x - Town.X, z - Town.Z
		local plaza = tx * tx + tz * tz
		if plaza < Town.SquareRadius * Town.SquareRadius then
			return "Cobblestone"
		end
		local rd, road = roadDistance(x, z, 4)
		if road and rd <= 0 then
			return road
		end
		local sd = if h > 3 then streamDistance(x, z) else math.huge
		if sd < 1.5 then
			return if slope > 0.7 then "Rock" else "Ground" -- stream bed
		end
		local n = Noise.Fbm2(x * 0.045, z * 0.045, 801, 2) -- small patches
		if slope > 0.7 then
			-- cliffs are warm layered sandstone with darker rock strata, rock at the sea
			if h < 5 + Noise.Value2(x * 0.08, z * 0.08, 515) * 3 then
				return "Rock"
			end
			if math.sin(h * 0.5 + n * 2.5) > 0.62 then
				return "Rock" -- darker strata
			end
			return "Sandstone"
		end
		if h < 4.6 then
			return "Sand" -- the beaches
		end
		if slope > 0.45 then
			return if n > 0.12 then "Rock" else "Ground" -- broken slopes
		end
		-- the quay: paved from the boardwalk to the quay wall
		if z > 305 and z < Quay.Z + 1.8 and x > Quay.MinX - 6 and x < Quay.MaxX + 6 and h < 7.5 then
			return "Cobblestone"
		end
		-- worn dirt along the paths and around the plaza, wet mud along the streams
		local worn = 2 + n * 1.6
		if rd < worn or plaza < (Town.SquareRadius + 2.5 + n * 2) ^ 2 then
			return "Ground"
		end
		if sd < 4 + n * 2 then
			return "Mud"
		end
		if h < 7.5 then
			-- the harbour level is open sand. Green creeps out only from the feet of the ledges,
			-- away from the waterfront, in broad soft patches (small noisy tufts of grass or dirt
			-- on the sand read as square blotches on the terrain voxels)
			if z < 284 and Noise.Fbm2(x * 0.018, z * 0.018, 779, 2) > 0.2 then
				return "LeafyGrass"
			end
			return "Sand"
		end
		-- the ground: leafy jungle floor and warm grass meadows in patches, bare dirt and mud
		-- in the hollows, sandstone breaking through on the high ledges
		if n < -0.45 then
			return if h < 12 then "Mud" else "Ground"
		end
		if n > 0.48 and h > 18 then
			return "Sandstone"
		end
		-- sunny meadow patches in and around the town, deep leafy floor in the wild jungle
		local big = Noise.Fbm2(x * 0.016, z * 0.016, 777, 2)
		local townish = plaza < 240 * 240
		if big * 0.7 + n * 0.6 > (if townish then 0.18 else 0.42) then
			return "Grass"
		end
		return "LeafyGrass"
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
