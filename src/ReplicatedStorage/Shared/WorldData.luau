--!strict
-- Layout of the world: islands, the town of Kingshaven, harbour and dock slots.
-- Plain numbers only, so the Lune build script can use this module as well.
-- Compass: north is -Z, south is +Z, east is +X, west is -X.

local WorldData = {}

WorldData.WaterLevel = 0
WorldData.FloorLevel = -56 -- ocean floor
WorldData.HalfSize = 3584 -- terrain is generated from -HalfSize to +HalfSize on X and Z
WorldData.BoundaryRadius = 3300 -- ships beyond this get battered by the wild sea
WorldData.TerrainVersion = 5 -- bump when the terrain recipe changes

-- Terrain material colours as plain RGB numbers (applied with Terrain:SetMaterialColor by the
-- TerrainGenerator; the build tools read them too)
-- Warm Sea of Thieves tones: sunny yellow-green meadows over a deeper leafy floor, warm
-- sandstone cliffs with brown rock strata, dirt and mud where people walk.
WorldData.TerrainColors = {
	Sand = { 236, 210, 156 },
	Grass = { 136, 170, 62 },
	LeafyGrass = { 90, 138, 50 },
	Rock = { 156, 122, 92 },
	Slate = { 118, 114, 110 },
	Basalt = { 58, 54, 60 },
	Cobblestone = { 170, 154, 132 },
	Ground = { 142, 108, 72 },
	Mud = { 108, 84, 60 },
	Sandstone = { 214, 176, 124 },
	Limestone = { 226, 220, 200 },
} :: { [string]: { number } }

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

-- Town of Kingshaven: a waterfall lagoon outpost. The town wraps around an inner pool fed by
-- a cascade down the northern cliffs; shops sit on rocky ledges at different heights around
-- it and the pool drains through a rocky cut to the harbour beach.
--   X, Z         = the plaza (King statue) on the harbour level, SquareRadius its cobbles
--   Height       = the harbour level (the plaza, the quay and the boardwalk)
--   Radius       = how far the town dressing reaches around the plaza
WorldData.Town = { X = 0, Z = 258, Radius = 175, Blend = 0, Height = 6, SquareRadius = 17 }

-- Inside the basin the island stays at Town.Height; the ledges below rise out of it
WorldData.Basin = { X = 0, Z = 205, Radius = 115 }

-- The inner pool (sea level, so the terrain fills it with water) and its outlet cut to the beach
WorldData.Pool = { X = 0, Z = 192, Rx = 40, Rz = 30, Depth = -6 }
WorldData.PoolCut = { Width = 7, Depth = -3, Points = { { -22, 214, 7 }, { -34, 238, 7 }, { -39, 266, 8 }, { -43, 294, 12 }, { -48, 318, 22 }, { -52, 340, 30 } } }

-- Rocky ledges and outcrops of the town: rounded blocks with flat tops at H and cliffs
-- (Edge = studs over which the cliff falls) around an ellipse Rx x Rz turned by Yaw.
-- Rough = bumpiness of the top (0 for the shop pads). The levels: harbour 6, low ledges 10,
-- mid ledges 24, high ledges 40, rim 52-76.
export type Ledge = { Name: string, X: number, Z: number, Rx: number, Rz: number, Yaw: number, H: number, Edge: number, Rough: number }
WorldData.Ledges = {
	-- low ledges by the water (Merchant, Shipwright)
	{ Name = "LowWest", X = -68, Z = 240, Rx = 32, Rz = 25, Yaw = 0.15, H = 10, Edge = 5, Rough = 0 },
	{ Name = "LowEast", X = 68, Z = 240, Rx = 32, Rz = 25, Yaw = -0.15, H = 10, Edge = 5, Rough = 0 },
	-- mid ledges (Trading Post, Armory) and the cascade's first step behind the pool
	{ Name = "MidWest", X = -86, Z = 188, Rx = 30, Rz = 30, Yaw = 0.3, H = 24, Edge = 7, Rough = 0 },
	{ Name = "MidEast", X = 86, Z = 188, Rx = 30, Rz = 30, Yaw = -0.3, H = 24, Edge = 7, Rough = 0 },
	{ Name = "CascadeLow", X = 8, Z = 152, Rx = 50, Rz = 17, Yaw = 0, H = 24, Edge = 7, Rough = 0.6 },
	-- high ledges (the Tavern) and the cascade's second step
	{ Name = "HighWest", X = -58, Z = 136, Rx = 36, Rz = 26, Yaw = 0.25, H = 40, Edge = 8, Rough = 0 },
	{ Name = "CascadeMid", X = 14, Z = 126, Rx = 46, Rz = 16, Yaw = 0, H = 40, Edge = 8, Rough = 0.8 },
	{ Name = "HighEast", X = 64, Z = 132, Rx = 28, Rz = 20, Yaw = -0.2, H = 46, Edge = 8, Rough = 0.8 },
	-- the rim: the cascade's top step and the towering outcrops that frame the town
	{ Name = "CascadeTop", X = 12, Z = 98, Rx = 76, Rz = 22, Yaw = 0, H = 56, Edge = 9, Rough = 1.2 },
	{ Name = "RimWest", X = -96, Z = 98, Rx = 40, Rz = 26, Yaw = 0.3, H = 60, Edge = 9, Rough = 1.2 },
	{ Name = "TowerWest", X = -118, Z = 134, Rx = 25, Rz = 24, Yaw = 0, H = 66, Edge = 9, Rough = 0.8 },
	{ Name = "WallWest", X = -136, Z = 226, Rx = 22, Rz = 32, Yaw = 0.1, H = 52, Edge = 9, Rough = 0.8 },
	{ Name = "TowerEast", X = 122, Z = 126, Rx = 28, Rz = 24, Yaw = 0, H = 74, Edge = 10, Rough = 0.8 },
	{ Name = "WallEast", X = 142, Z = 226, Rx = 22, Rz = 34, Yaw = -0.1, H = 60, Edge = 9, Rough = 0.8 },
	-- headlands either side of the harbour
	{ Name = "HeadWest", X = -152, Z = 266, Rx = 36, Rz = 26, Yaw = -0.2, H = 40, Edge = 8, Rough = 1.0 },
	{ Name = "HeadEast", X = 154, Z = 262, Rx = 38, Rz = 28, Yaw = 0.2, H = 46, Edge = 8, Rough = 1.0 },
} :: { Ledge }

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
	-- the harbour level: from the piers to the plaza, then out to the two low ledges
	{ Name = "MainStreet", Width = 12, Material = "Sand", Points = { { 0, 299 }, { 0, 272 } }, To = "Piers" },
	{ Name = "ShipwrightPath", Width = 8, Material = "Sand", Ramp = true, Points = { { 12, 264 }, { 34, 262 }, { 48, 261 }, { 64.6, 259.3 } }, To = "Shipwright" },
	{ Name = "MerchantPath", Width = 8, Material = "Sand", Ramp = true, Bridges = { 2 }, Points = { { -12, 264 }, { -25, 263 }, { -52, 261 }, { -67.6, 259.3 } }, To = "Merchant" },
	-- stairs up from the low ledges to the mid ledges, and on up to the tavern
	{ Name = "ArmoryPath", Width = 7, Material = "Sand", Ramp = true, Points = { { 48, 261 }, { 45, 240 }, { 50, 214 }, { 73.7, 201.4 } }, To = "Armory" },
	{ Name = "TradingPostPath", Width = 7, Material = "Sand", Ramp = true, Points = { { -52, 261 }, { -50, 240 }, { -54, 216 }, { -73.7, 201.4 } }, To = "TradingPost" },
	{ Name = "TavernPath", Width = 7, Material = "Sand", Ramp = true, Points = { { -73.7, 201.4 }, { -66, 184 }, { -90, 168 }, { -78, 150 }, { -51, 153.2 } }, To = "Tavern" },
	-- trails from the ledges out over the island
	{
		Name = "LighthouseTrail", Width = 7, Material = "Sand", Ramp = true, To = "Lighthouse",
		Points = { { -51, 153.2 }, { -30, 140 }, { -36, 112 }, { -40, 80 }, { -20, 44 }, { 10, 10 }, { 28, -28 }, { 46, -74 }, { 50, -112 }, { 22, -140 }, { -14, -158 }, { -30, -190 }, { -20, -222 }, { 0, -234 } },
	},
	-- a spur along the rim to the lookout deck over the falls (after its trunk, the trail)
	{ Name = "LookoutPath", Width = 5, Material = "Sand", Ramp = true, To = "Viewpoint", Points = { { -37.375, 101 }, { -24, 103 }, { -12, 104 } } },
	{
		Name = "LagoonTrail", Width = 6, Material = "Sand", Ramp = true, To = "Lagoon", Bridges = { 11 },
		Points = { { 73.7, 201.4 }, { 100, 182 }, { 132, 172 }, { 165, 166 }, { 200, 120 }, { 230, 70 }, { 258, 24 }, { 296, 24 }, { 336, 22 }, { 372, 14 }, { 390, -6 }, { 392, -66 }, { 398, -84 } },
	},
	{
		Name = "WestTrail", Width = 6, Material = "Sand", Ramp = true, To = "Lookout",
		Points = { { -73.7, 201.4 }, { -100, 184 }, { -134, 177 }, { -170, 170 }, { -205, 128 }, { -240, 70 }, { -260, 22 }, { -302, 12 }, { -340, 4 } },
	},
	{ Name = "EastBeachTrail", Width = 6, Material = "Sand", Ramp = true, To = "Beach", Points = { { 80, 300 }, { 130, 306 }, { 186, 318 }, { 236, 330 }, { 280, 340 } } },
	{ Name = "WestBeachTrail", Width = 6, Material = "Sand", Ramp = true, To = "Beach", Points = { { -80, 300 }, { -130, 306 }, { -186, 318 }, { -236, 330 }, { -280, 340 } } },
} :: { Path }

-- The paths as straight segments (everything but the bridges): painted onto the terrain
export type Road = { X1: number, Z1: number, X2: number, Z2: number, Width: number, Material: string, Path: string }
WorldData.Roads = {} :: { Road }
for _, path in WorldData.Paths do
	local bridges = {}
	local bridgeList: { number } = path.Bridges or {}
	for _, i in bridgeList do
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

-- Streams of Kingshaven: the Heightmap cuts a shallow bed along each one (deeper notches
-- where it tumbles over a terrace cliff) and the build fills it with water parts and
-- waterfalls. Points are { x, z }; Width is the bed width.
export type Stream = { Name: string, Width: number, Depth: number, Points: { { number } } }
WorldData.Streams = {
	-- from the north-east highlands down two terraces into the lagoon
	{ Name = "LagoonFalls", Width = 9, Depth = 2, Points = { { 214, -142 }, { 232, -124 }, { 246, -108 }, { 252, -92 }, { 263, -79 }, { 274, -66 }, { 290, -52 } } },
	-- the town's great cascade: from a spring on the rim down three rock steps into the pool
	{ Name = "PoolFalls", Width = 13, Depth = 2.5, Points = { { 16, 72 }, { 14, 92 }, { 12, 110 }, { 10, 126 }, { 8, 140 }, { 5, 152 }, { 2, 166 }, { 0, 180 } } },
	-- a thinner fall from the eastern ledges into the pool
	{ Name = "EastFalls", Width = 7, Depth = 2, Points = { { 72, 118 }, { 68, 134 }, { 60, 150 }, { 50, 164 }, { 40, 176 }, { 30, 184 } } },
} :: { Stream }

-- The waterfront: a paved quay at the harbour level (Town.Height) runs from the boardwalk to a
-- timber quay wall at Z, below which a strip of beach (Beach studs high at the wall) slopes into
-- the sea. Between MinX and MaxX (fading out over Blend at the ends); the banks under the pier
-- roots stay as they are, so the pier ramps keep their gentle slope.
WorldData.Quay = { MinX = -114, MaxX = 116, Z = 318, Beach = 3, Blend = 14 }

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
	-- low ledges either side of the plaza, by the pool
	{ Id = "Shipwright", Title = "SHIPWRIGHT", X = 70, Z = 238, Yaw = -0.25, Width = 26, Depth = 20 },
	{ Id = "Merchant", Title = "MERCHANT", X = -73, Z = 238, Yaw = 0.25, Width = 26, Depth = 20 },
	-- mid ledges looking down over the pool
	{ Id = "Armory", Title = "ARMORY", X = 88, Z = 186, Yaw = -0.75, Width = 22, Depth = 18 },
	-- the tavern up on the high western ledge beside the falls
	{ Id = "Tavern", Title = "THE RUSTY ANCHOR", X = -60, Z = 132, Yaw = 0.4, Width = 28, Depth = 22 },
	{ Id = "TradingPost", Title = "TRADING POST", X = -88, Z = 186, Yaw = 0.75, Width = 24, Depth = 18 },
} :: { Shop })
for _, shop in WorldData.Shops do
	local reach = shop.Depth / 2 + 12
	shop.FrontX = shop.X + math.sin(shop.Yaw) * reach
	shop.FrontZ = shop.Z + math.cos(shop.Yaw) * reach
end

WorldData.SpawnPoint = { X = 0, Z = 281 }
-- The lighthouse stands on a flat summit (SummitRadius) on top of the northern terraces
WorldData.Lighthouse = { X = 0, Z = -250, HillHeight = 30, HillRadius = 130, SummitRadius = 30 }

-- No PvP, no cannon damage and no skeletons inside the haven
WorldData.SafeZone = { X = 0, Z = 220, Radius = 800 }

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
