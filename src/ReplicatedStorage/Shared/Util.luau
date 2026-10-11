--!strict
-- Small helpers shared by server and client.

local WorldData = require(script.Parent.WorldData)

local Util = {}

function Util.FormatNumber(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local negative = string.sub(s, 1, 1) == "-"
	if negative then
		s = string.sub(s, 2)
	end
	local formatted = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return (if negative then "-" else "") .. formatted
end

function Util.Approach(current: number, target: number, maxDelta: number): number
	if current < target then
		return math.min(current + maxDelta, target)
	end
	return math.max(current - maxDelta, target)
end

function Util.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Smallest signed difference between two angles (radians)
function Util.AngleDiff(a: number, b: number): number
	local d = (a - b) % (2 * math.pi)
	if d > math.pi then
		d -= 2 * math.pi
	end
	return d
end

function Util.FlatDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function Util.InSafeZone(position: Vector3): boolean
	local zone = WorldData.SafeZone
	local dx = position.X - zone.X
	local dz = position.Z - zone.Z
	return dx * dx + dz * dz <= zone.Radius * zone.Radius
end

-- Nearest island and the distance from its coast (negative = on the island)
function Util.NearestIsland(position: Vector3): (WorldData.Island, number)
	local best = WorldData.Islands[1]
	local bestDist = math.huge
	for _, island in WorldData.Islands do
		local dx = position.X - island.X
		local dz = position.Z - island.Z
		local d = math.sqrt(dx * dx + dz * dz) - island.Radius
		if d < bestDist then
			bestDist = d
			best = island
		end
	end
	return best, bestDist
end

-- Heading (radians) of a look vector; 0 = north (-Z), increasing clockwise
function Util.Heading(look: Vector3): number
	return math.atan2(look.X, -look.Z) % (2 * math.pi)
end

function Util.IsFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Util.IsValidVector(value: any): boolean
	return typeof(value) == "Vector3"
		and Util.IsFiniteNumber(value.X)
		and Util.IsFiniteNumber(value.Y)
		and Util.IsFiniteNumber(value.Z)
end

-- Find the ship model a part belongs to (ships carry a ShipId attribute)
function Util.FindShipModel(instance: Instance?): Model?
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("ShipId") ~= nil then
			return current
		end
		current = current.Parent
	end
	return nil
end

function Util.Shuffle<T>(list: { T }): { T }
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

return Util
