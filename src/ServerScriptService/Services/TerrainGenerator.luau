--!native
-- Generates the ocean and all islands as smooth Roblox terrain from the shared Heightmap.
--
-- Runs automatically when the server starts. To bake the terrain into the place so
-- you can see it while editing in Studio, run this in the Studio command bar:
--     require(game.ServerScriptService.Services.TerrainGenerator).Generate(true)
-- and save the place. The server then skips generation (it checks the version
-- attribute on Terrain).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Heightmap = require(Shared:WaitForChild("Heightmap"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local TerrainGenerator = {}

local CHUNK = 256 -- studs per chunk side
local RES = 4 -- voxel size
local Y_MIN = -64 -- bottom of the ocean floor slab (multiple of 4)
local VERSION_ATTRIBUTE = "KOTP_TerrainVersion"

local MATERIAL_COLORS: { [Enum.Material]: Color3 } = {}
for name, rgb in WorldData.TerrainColors do
	MATERIAL_COLORS[(Enum.Material :: any)[name]] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local materialCache: { [string]: Enum.Material } = {}
local function toMaterial(name: string): Enum.Material
	local m = materialCache[name]
	if not m then
		m = (Enum.Material :: any)[name] or Enum.Material.Sand
		materialCache[name] = m
	end
	return m :: Enum.Material
end

local function chunkTouchesIsland(x0: number, z0: number): boolean
	for _, island in WorldData.Islands do
		local r = island.Influence or island.Radius * 2
		local cx = math.clamp(island.X, x0, x0 + CHUNK)
		local cz = math.clamp(island.Z, z0, z0 + CHUNK)
		local dx, dz = island.X - cx, island.Z - cz
		if dx * dx + dz * dz <= r * r then
			return true
		end
	end
	return false
end

local function fillOcean(terrain: Terrain, x0: number, z0: number)
	local cx, cz = x0 + CHUNK / 2, z0 + CHUNK / 2
	local floorTop = WorldData.FloorLevel
	terrain:FillBlock(CFrame.new(cx, (Y_MIN + floorTop) / 2, cz), Vector3.new(CHUNK, floorTop - Y_MIN, CHUNK), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(cx, (floorTop + WorldData.WaterLevel) / 2, cz), Vector3.new(CHUNK, WorldData.WaterLevel - floorTop, CHUNK), Enum.Material.Water)
end

local function writeIslandChunk(terrain: Terrain, x0: number, z0: number)
	local n = CHUNK // RES
	-- heights with a 1-column border for slopes
	local heights: { { number } } = {}
	local owners: { { any } } = {}
	local maxH = WorldData.WaterLevel
	for ix = 0, n + 1 do
		local hr, orow = {}, {}
		for iz = 0, n + 1 do
			local x = x0 + (ix - 0.5) * RES
			local z = z0 + (iz - 0.5) * RES
			local h, island = Heightmap.GetHeight(x, z)
			hr[iz] = h
			orow[iz] = island
			if h > maxH then
				maxH = h
			end
		end
		heights[ix] = hr
		owners[ix] = orow
	end
	local yMax = math.ceil((maxH + 2) / RES) * RES
	local ny = (yMax - Y_MIN) // RES
	local region = Region3.new(Vector3.new(x0, Y_MIN, z0), Vector3.new(x0 + CHUNK, yMax, z0 + CHUNK))

	local materials = table.create(n)
	local occupancy = table.create(n)
	local water = Enum.Material.Water
	local air = Enum.Material.Air
	for ix = 1, n do
		local matX = table.create(ny)
		local occX = table.create(ny)
		for iy = 1, ny do
			matX[iy] = table.create(n)
			occX[iy] = table.create(n)
		end
		materials[ix] = matX
		occupancy[ix] = occX
		local hRow = heights[ix]
		for iz = 1, n do
			local h = hRow[iz]
			local gx = (heights[ix + 1][iz] - heights[ix - 1][iz]) / (2 * RES)
			local gz = (hRow[iz + 1] - hRow[iz - 1]) / (2 * RES)
			local slope = math.sqrt(gx * gx + gz * gz)
			local x = x0 + (ix - 0.5) * RES
			local z = z0 + (iz - 0.5) * RES
			local surface = toMaterial(Heightmap.GetMaterial(x, z, h, slope, owners[ix][iz]))
			for iy = 1, ny do
				local yb = Y_MIN + (iy - 1) * RES
				local yt = yb + RES
				local m, o
				if yt <= h then
					m, o = surface, 1
				elseif yb < h then
					m, o = surface, (h - yb) / RES
					-- thin solid voxels under water read better as water (smoother shorelines)
					if yt <= WorldData.WaterLevel and o < 0.5 then
						m, o = water, 1
					end
				elseif yt <= WorldData.WaterLevel then
					m, o = water, 1
				else
					m, o = air, 0
				end
				matX[iy][iz] = m
				occX[iy][iz] = o
			end
		end
	end
	terrain:WriteVoxels(region, RES, materials, occupancy)
end

local generating = false

-- Generates the whole world. Main island first so players can spawn quickly.
-- onMainIslandReady is called as soon as Kingshaven exists.
function TerrainGenerator.Generate(force: boolean?, onMainIslandReady: (() -> ())?)
	local terrain = workspace.Terrain
	if generating then
		return
	end
	if not force and terrain:GetAttribute(VERSION_ATTRIBUTE) == WorldData.TerrainVersion then
		if onMainIslandReady then
			onMainIslandReady()
		end
		return
	end
	generating = true
	local started = os.clock()
	terrain:Clear()
	for material, color in MATERIAL_COLORS do
		terrain:SetMaterialColor(material, color)
	end

	local half = WorldData.HalfSize
	local main = WorldData.GetIsland(WorldData.MainIslandName)
	local chunks = {}
	for x0 = -half, half - CHUNK, CHUNK do
		for z0 = -half, half - CHUNK, CHUNK do
			local cx, cz = x0 + CHUNK / 2, z0 + CHUNK / 2
			local distMain = if main then math.sqrt((cx - main.X) ^ 2 + (cz - main.Z) ^ 2) else 0
			table.insert(chunks, { X = x0, Z = z0, Island = chunkTouchesIsland(x0, z0), Dist = distMain })
		end
	end
	table.sort(chunks, function(a, b)
		return a.Dist < b.Dist
	end)

	local mainRadius = if main then (main.Influence or 900) + CHUNK else 0
	local mainReported = false
	local budget = os.clock()
	local inStudioEdit = RunService:IsStudio() and not RunService:IsRunning()
	for i, chunk in chunks do
		if chunk.Island then
			writeIslandChunk(terrain, chunk.X, chunk.Z)
		else
			fillOcean(terrain, chunk.X, chunk.Z)
		end
		if not mainReported and (chunk.Dist > mainRadius or i == #chunks) then
			mainReported = true
			if onMainIslandReady then
				task.spawn(onMainIslandReady)
			end
		end
		-- yield regularly so the server stays responsive
		if not inStudioEdit and os.clock() - budget > 0.03 then
			task.wait()
			budget = os.clock()
		end
	end
	terrain:SetAttribute(VERSION_ATTRIBUTE, WorldData.TerrainVersion)
	generating = false
	print(("[TerrainGenerator] World generated in %.1fs (%d chunks)"):format(os.clock() - started, #chunks))
end

return TerrainGenerator
