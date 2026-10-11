--!strict
--!native
-- The shape of the world. GetHeight(x, z) returns the terrain surface height.
-- Used by: the terrain generator (runtime), ship grounding checks, enemy spawns,
-- the treasure map UI and the Lune build script (to place palms and buildings).

local Noise = require(script.Parent.Noise)
local WorldData = require(script.Parent.WorldData)

local Heightmap = {}

local FLOOR = WorldData.FloorLevel
local SHELF = 0.7 -- how far the underwater shelf reaches, as a fraction of the radius
local BEACH = 0.12 -- beach width, as a fraction of the radius
local Town = WorldData.Town
local Harbor = WorldData.Harbor
local Lighthouse = WorldData.Lighthouse

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

	if island.Kind == "Main" then
		if t > 0 then
			local lx = x - Lighthouse.X
			local lz = z - Lighthouse.Z
			local bump = math.exp(-(lx * lx + lz * lz) / (2 * Lighthouse.HillRadius * Lighthouse.HillRadius))
			h += bump * Lighthouse.HillHeight * smooth(t / 0.35)
		end
		local tx = x - Town.X
		local tz = z - Town.Z
		local townDist = math.sqrt(tx * tx + tz * tz)
		local w = 1 - smoothstep(Town.Radius, Town.Radius + Town.Blend, townDist)
		if w > 0 then
			h += (Town.Height - h) * w
		end
		local hw = rectMask(x, z, Harbor)
		if hw > 0 then
			h = math.min(h, h + (Harbor.Depth - h) * hw)
		end
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

local function distToSegment(px: number, pz: number, x1: number, z1: number, x2: number, z2: number): number
	local vx, vz = x2 - x1, z2 - z1
	local len2 = vx * vx + vz * vz
	local t = if len2 > 0 then math.clamp(((px - x1) * vx + (pz - z1) * vz) / len2, 0, 1) else 0
	local cx, cz = x1 + vx * t, z1 + vz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- Returns the name of a road material if (x, z) is on a road, otherwise nil
function Heightmap.GetRoadMaterial(x: number, z: number): string?
	for _, road in WorldData.Roads do
		if distToSegment(x, z, road.X1, road.Z1, road.X2, road.Z2) <= road.Width / 2 then
			return road.Material
		end
	end
	return nil
end

-- Terrain material name for a column (string so the module stays engine-agnostic)
function Heightmap.GetMaterial(x: number, z: number, h: number, slope: number, island: WorldData.Island?): string
	if h < 3.3 or island == nil then
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
