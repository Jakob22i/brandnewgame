--!strict
-- Layout of the world: islands, the town of Kingshaven, harbour and dock slots.
-- Plain numbers only, so the Lune build script can use this module as well.
-- Compass: north is -Z, south is +Z, east is +X, west is -X.

local WorldData = {}

WorldData.WaterLevel = 0
WorldData.FloorLevel = -56 -- ocean floor
WorldData.HalfSize = 3584 -- terrain is generated from -HalfSize to +HalfSize on X and Z
WorldData.BoundaryRadius = 3300 -- ships beyond this get battered by the wild sea
WorldData.TerrainVersion = 3 -- bump when the terrain recipe changes

export type Shop = {
	Id: string,
	Title: string,
	X: number,
	Z: number,
	Yaw: number,
	Width: number,
	Depth: number,
	FrontX: number?,
	FrontZ: number?,
}

export type Island = {
	Name: string,
	X: number,
	Z: number,
	Radius: number,
	Height: number,
	Kind: string, -- "Main" | "Tropical" | "Flat" | "Rocky" | "Atoll"
	Seed: number,
	Wobble: number, -- how irregular the coastline is
	Steep: number, -- < 1 = cliffs, > 1 = gentle hills
	RockMaterial: string,
	Palms: number,
	Rocks: number,
	Skeletons: number, -- max skeletons guarding the island at once
	Blurb: string,
	Influence: number?, -- filled in by Heightmap
}

WorldData.Islands = {
	{ Name = "Kingshaven", X = 0, Z = 0, Radius = 430, Height = 60, Kind = "Main", Seed = 11, Wobble = 0.08, Steep = 1.2, RockMaterial = "Sandstone", Palms = 70, Rocks = 18, Skeletons = 0, Blurb = "Pirate capital. Shops, ships and safe harbour." },
	{ Name = "Parrot Cay", X = 1250, Z = -700, Radius = 150, Height = 24, Kind = "Tropical", Seed = 23, Wobble = 0.16, Steep = 1.0, RockMaterial = "Rock", Palms = 22, Rocks = 8, Skeletons = 3, Blurb = "Small, green and full of parrots." },
	{ Name = "Turtle Isle", X = -1300, Z = -600, Radius = 170, Height = 18, Kind = "Flat", Seed = 37, Wobble = 0.18, Steep = 1.5, RockMaterial = "Rock", Palms = 24, Rocks = 6, Skeletons = 3, Blurb = "Long white beaches where turtles nest." },
	{ Name = "Cutlass Cove", X = 500, Z = -1700, Radius = 220, Height = 42, Kind = "Tropical", Seed = 41, Wobble = 0.24, Steep = 0.9, RockMaterial = "Rock", Palms = 30, Rocks = 14, Skeletons = 4, Blurb = "A jagged cove with hidden beaches." },
	{ Name = "Mermaid's Hideaway", X = -800, Z = 1650, Radius = 190, Height = 30, Kind = "Tropical", Seed = 53, Wobble = 0.2, Steep = 1.0, RockMaterial = "Rock", Palms = 28, Rocks = 10, Skeletons = 4, Blurb = "Turquoise shallows and singing rocks." },
	{ Name = "Smuggler's Bay", X = 1750, Z = 1000, Radius = 240, Height = 46, Kind = "Tropical", Seed = 67, Wobble = 0.22, Steep = 0.95, RockMaterial = "Rock", Palms = 34, Rocks = 14, Skeletons = 5, Blurb = "Smugglers left more than footprints here." },
	{ Name = "Golden Sands", X = -1950, Z = 1150, Radius = 230, Height = 14, Kind = "Flat", Seed = 71, Wobble = 0.15, Steep = 1.6, RockMaterial = "Sandstone", Palms = 30, Rocks = 6, Skeletons = 4, Blurb = "Endless golden dunes." },
	{ Name = "Skull Rock", X = 2350, Z = -1500, Radius = 200, Height = 85, Kind = "Rocky", Seed = 83, Wobble = 0.2, Steep = 0.6, RockMaterial = "Slate", Palms = 8, Rocks = 22, Skeletons = 6, Blurb = "Cursed rock. Skeletons gather here." },
	{ Name = "Devil's Ridge", X = -2150, Z = -1800, Radius = 260, Height = 100, Kind = "Rocky", Seed = 97, Wobble = 0.22, Steep = 0.55, RockMaterial = "Basalt", Palms = 10, Rocks = 26, Skeletons = 6, Blurb = "Black volcanic cliffs. Only the brave climb it." },
	{ Name = "Coral Atoll", X = 350, Z = 2400, Radius = 240, Height = 9, Kind = "Atoll", Seed = 101, Wobble = 0.1, Steep = 1.2, RockMaterial = "Limestone", Palms = 26, Rocks = 6, Skeletons = 4, Blurb = "A ring of sand around a glowing lagoon." },
	{ Name = "Thieves' Haven", X = -2750, Z = -150, Radius = 210, Height = 40, Kind = "Tropical", Seed = 113, Wobble = 0.2, Steep = 1.0, RockMaterial = "Rock", Palms = 28, Rocks = 12, Skeletons = 5, Blurb = "Old pirate hideout on the western edge." },
	{ Name = "Sunken Grove", X = 2850, Z = 250, Radius = 210, Height = 34, Kind = "Tropical", Seed = 127, Wobble = 0.24, Steep = 1.0, RockMaterial = "Rock", Palms = 32, Rocks = 10, Skeletons = 5, Blurb = "A jungle half swallowed by the sea." },
	{ Name = "Castaway Key", X = 1400, Z = 2550, Radius = 120, Height = 14, Kind = "Flat", Seed = 131, Wobble = 0.15, Steep = 1.4, RockMaterial = "Rock", Palms = 14, Rocks = 4, Skeletons = 2, Blurb = "A lonely sandbar with a few palms." },
	{ Name = "Lonely Palm", X = -350, Z = -2650, Radius = 90, Height = 9, Kind = "Flat", Seed = 139, Wobble = 0.12, Steep = 1.4, RockMaterial = "Rock", Palms = 6, Rocks = 3, Skeletons = 2, Blurb = "One island, one palm... or so they say." },
	{ Name = "Shark Fin Rocks", X = -1300, Z = 2650, Radius = 120, Height = 55, Kind = "Rocky", Seed = 149, Wobble = 0.25, Steep = 0.6, RockMaterial = "Rock", Palms = 6, Rocks = 12, Skeletons = 3, Blurb = "Sharp rocks shaped like a shark's fin." },
} :: { Island }

WorldData.MainIslandName = "Kingshaven"

-- Town of Kingshaven (a flattened plateau on the main island)
WorldData.Town = { X = 0, Z = 120, Radius = 175, Blend = 70, Height = 6, SquareRadius = 46 }

-- Paths of Kingshaven: sand paths from the spawn and the town square to every shop front,
-- and trails that climb the terraces to the lighthouse, the lagoon bridge, the west lookout
-- and the beaches. Points are { x, z }; Width is the total path width.
--   Ramp    = the Heightmap smooths the ground along the path, cutting ramps through the
--             terrace cliffs (the build puts plank stairs on the steep parts)
--   Bridges = segment numbers (point i -> i + 1) that are plank bridges (no ground under them)
--   Planks  = segment numbers covered by a raised plank walkway
--   To      = shop Id (or place) the path leads to, used by the signposts
export type Path = {
	Name: string,
	Width: number,
	Material: string,
	Points: { { number } },
	Ramp: boolean?,
	Bridges: { number }?,
	Planks: { number }?,
	To: string?,
}
WorldData.Paths = {
	{ Name = "MainStreet", Width = 12, Material = "Sand", Points = { { 0, 299 }, { 0, 222 }, { 0, 166 } }, To = "Piers" },
	{ Name = "ShipwrightPath", Width = 8, Material = "Sand", Points = { { 0, 252 }, { 20, 247 }, { 38, 250 } }, Planks = { 1, 2 }, To = "Shipwright" },
	{ Name = "MerchantPath", Width = 8, Material = "Sand", Points = { { 0, 252 }, { -20, 247 }, { -38, 250 } }, Planks = { 1, 2 }, To = "Merchant" },
	{ Name = "ArmoryPath", Width = 8, Material = "Sand", Points = { { 30, 120 }, { 55, 120 } }, To = "Armory" },
	{ Name = "TavernPath", Width = 8, Material = "Sand", Points = { { -30, 120 }, { -57, 120 } }, To = "Tavern" },
	{ Name = "TradingPostPath", Width = 8, Material = "Sand", Points = { { 0, 80 }, { 0, 43 } }, To = "TradingPost" },
	{
		Name = "LighthouseTrail", Width = 7, Material = "Sand", Ramp = true, To = "Lighthouse",
		Points = { { 0, 54 }, { 22, 50 }, { 32, 22 }, { 28, -28 }, { 46, -74 }, { 50, -112 }, { 22, -140 }, { -14, -158 }, { -30, -190 }, { -20, -222 }, { 0, -234 } },
	},
	{
		Name = "LagoonTrail", Width = 6, Material = "Sand", Ramp = true, To = "Lagoon", Bridges = { 10 },
		Points = { { 28, 86 }, { 70, 74 }, { 120, 64 }, { 170, 50 }, { 215, 34 }, { 258, 24 }, { 296, 24 }, { 336, 22 }, { 372, 14 }, { 390, -6 }, { 392, -66 }, { 398, -84 } },
	},
	{
		Name = "WestTrail", Width = 6, Material = "Sand", Ramp = true, To = "Lookout",
		Points = { { -28, 86 }, { -70, 74 }, { -120, 64 }, { -170, 52 }, { -215, 36 }, { -260, 22 }, { -302, 12 }, { -340, 4 } },
	},
	{ Name = "EastBeachTrail", Width = 6, Material = "Sand", Ramp = true, To = "Beach", Points = { { 80, 300 }, { 130, 296 }, { 186, 302 }, { 236, 318 }, { 280, 334 } } },
	{ Name = "WestBeachTrail", Width = 6, Material = "Sand", Ramp = true, To = "Beach", Points = { { -80, 300 }, { -130, 296 }, { -186, 302 }, { -236, 318 }, { -280, 334 } } },
} :: { Path }

-- The paths as straight segments (everything but the bridges): painted onto the terrain
export type Road = { X1: number, Z1: number, X2: number, Z2: number, Width: number, Material: string, Path: string }
WorldData.Roads = {} :: { Road }
for _, path in WorldData.Paths do
	local bridges = {}
	for _, i in path.Bridges or {} do
		bridges[i] = true
	end
	for i = 1, #path.Points - 1 do
		if not bridges[i] then
			local a, b = path.Points[i], path.Points[i + 1]
			table.insert(WorldData.Roads, { X1 = a[1], Z1 = a[2], X2 = b[1], Z2 = b[2], Width = path.Width, Material = path.Material, Path = path.Name })
		end
	end
end

-- A sea lagoon in the eastern cliffs, open to the sea through a channel
WorldData.Lagoon = { X = 318, Z = -36, Radius = 42, Depth = -10, ChannelX = 500, ChannelZ = -44, ChannelWidth = 30 }

-- Dredged harbour basin on the south side so ships can moor at the piers
WorldData.Harbor = { MinX = -175, MaxX = 175, MinZ = 380, MaxZ = 950, Depth = -18, Blend = 60 }

WorldData.Piers = {
	{ X = -70, MinZ = 296, MaxZ = 700, HalfWidth = 6, Height = 5 },
	{ X = 70, MinZ = 296, MaxZ = 700, HalfWidth = 6, Height = 5 },
}

-- Where newly launched ships appear. Ships face south (Yaw = pi), out to sea.
-- X is computed from the pier + ship width so the deck sits right next to the pier.
WorldData.DockSlots = {
	{ Pier = 1, Side = 1, Z = 500 },
	{ Pier = 2, Side = -1, Z = 500 },
	{ Pier = 1, Side = -1, Z = 500 },
	{ Pier = 2, Side = 1, Z = 500 },
	{ Pier = 1, Side = 1, Z = 630 },
	{ Pier = 2, Side = -1, Z = 630 },
	{ Pier = 1, Side = -1, Z = 630 },
	{ Pier = 2, Side = 1, Z = 630 },
}
-- Overflow anchorage if all pier slots are taken
WorldData.AnchorageSlots = {
	{ X = -300, Z = 820 },
	{ X = -150, Z = 860 },
	{ X = 0, Z = 880 },
	{ X = 150, Z = 860 },
	{ X = 300, Z = 820 },
	{ X = -420, Z = 760 },
	{ X = 420, Z = 760 },
}

-- The shops of Kingshaven. A shop's front (where the shopkeeper stands and players
-- walk up) faces local +Z rotated by Yaw. Width is along the front, Depth front-to-back.
-- The build script places buildings here and the island paths lead to each FrontX/FrontZ.
WorldData.Shops = ({
	{ Id = "Shipwright", Title = "SHIPWRIGHT", X = 60, Z = 250, Yaw = -math.pi / 2, Width = 26, Depth = 20 },
	{ Id = "Merchant", Title = "MERCHANT", X = -60, Z = 250, Yaw = math.pi / 2, Width = 26, Depth = 20 },
	{ Id = "Armory", Title = "ARMORY", X = 76, Z = 120, Yaw = -math.pi / 2, Width = 22, Depth = 18 },
	{ Id = "Tavern", Title = "THE RUSTY ANCHOR", X = -80, Z = 120, Yaw = math.pi / 2, Width = 28, Depth = 22 },
	{ Id = "TradingPost", Title = "TRADING POST", X = 0, Z = 22, Yaw = 0, Width = 24, Depth = 18 },
} :: { Shop })
for _, shop in WorldData.Shops do
	local reach = shop.Depth / 2 + 12
	shop.FrontX = shop.X + math.sin(shop.Yaw) * reach
	shop.FrontZ = shop.Z + math.cos(shop.Yaw) * reach
end

WorldData.SpawnPoint = { X = 0, Z = 182 }
-- The lighthouse stands on a flat summit (SummitRadius) on top of the northern terraces
WorldData.Lighthouse = { X = 0, Z = -250, HillHeight = 30, HillRadius = 130, SummitRadius = 30 }

-- No PvP, no cannon damage and no skeletons inside the haven
WorldData.SafeZone = { X = 0, Z = 160, Radius = 800 }

function WorldData.GetIsland(name: string): Island?
	for _, island in WorldData.Islands do
		if island.Name == name then
			return island
		end
	end
	return nil
end

function WorldData.GetSlotPosition(slotIndex: number, shipWidth: number): (number, number, number)
	local slot = WorldData.DockSlots[slotIndex]
	local pier = WorldData.Piers[slot.Pier]
	local x = pier.X + slot.Side * (pier.HalfWidth + shipWidth / 2 + 1.5)
	return x, slot.Z, math.pi
end

return WorldData
