-- Pre-computed spots on every island: flat dry land (for treasure X's and skeleton
-- spawns) and beach spots (for washed-up chests).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Heightmap = require(Shared:WaitForChild("Heightmap"))
local WorldData = require(Shared:WaitForChild("WorldData"))

local IslandPoints = {}

type Spot = { X: number, Z: number, H: number }
local land: { [string]: { Spot } } = {}
local beach: { [string]: { Spot } } = {}
local built = false

local function build()
	if built then
		return
	end
	built = true
	local rng = Random.new(1234)
	for _, island in WorldData.Islands do
		local landList, beachList = {}, {}
		for _ = 1, 500 do
			local a = rng:NextNumber() * math.pi * 2
			local d = math.sqrt(rng:NextNumber()) * island.Radius * 1.05
			local x, z = island.X + math.cos(a) * d, island.Z + math.sin(a) * d
			local h, owner = Heightmap.GetHeight(x, z)
			if owner == island and h > 2.8 then
				local slope = Heightmap.GetSlope(x, z)
				if slope < 0.45 then
					local spot = { X = x, Z = z, H = h }
					if h < 6 then
						table.insert(beachList, spot)
					end
					if h > 3.5 and h < island.Height * 0.95 + 4 then
						table.insert(landList, spot)
					end
				end
			end
		end
		land[island.Name] = landList
		beach[island.Name] = beachList
	end
end

function IslandPoints.Land(islandName: string): { Spot }
	build()
	return land[islandName] or {}
end

function IslandPoints.Beach(islandName: string): { Spot }
	build()
	return beach[islandName] or {}
end

function IslandPoints.Random(islandName: string, kind: string?): Spot?
	local list = if kind == "Beach" then IslandPoints.Beach(islandName) else IslandPoints.Land(islandName)
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

-- Ground position under (x, z): raycast against terrain/parts, falling back to the heightmap
function IslandPoints.Ground(x: number, z: number, exclude: { Instance }?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude or {}
	params.IgnoreWater = true
	local result = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
	if result then
		return result.Position
	end
	return Vector3.new(x, Heightmap.GetHeight(x, z), z)
end

IslandPoints.Build = build

return IslandPoints
