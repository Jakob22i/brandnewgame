--!strict
-- All tunable game numbers live here: prices, ships, weapons, treasure, enemies.

local Config = {}

Config.GameName = "King of the Pirates"
Config.StartingGold = 250
Config.RespawnTime = 6
Config.WaterLevel = 0
Config.AutosaveInterval = 120

-- Ships ---------------------------------------------------------------------
export type ShipDef = {
	Id: string,
	Order: number,
	DisplayName: string,
	Price: number,
	MaxHP: number,
	MaxSpeed: number, -- studs per second at full sail with a good wind
	Accel: number,
	Decel: number,
	TurnRate: number, -- radians per second at full rudder and speed
	Cannons: number,
	Crew: number,
	Draft: number, -- how deep the hull goes; shallower water stops the ship
	Length: number,
	Width: number,
	Description: string,
}

Config.Ships = {
	Sloop = {
		Id = "Sloop",
		Order = 1,
		DisplayName = "Sloop",
		Price = 0,
		MaxHP = 450,
		MaxSpeed = 40,
		Accel = 7,
		Decel = 9,
		TurnRate = math.rad(17),
		Cannons = 2,
		Crew = 2,
		Draft = 3.5,
		Length = 46,
		Width = 14,
		Description = "Quick and nimble single-mast ship. Great for solo pirates.",
	},
	Brigantine = {
		Id = "Brigantine",
		Order = 2,
		DisplayName = "Brigantine",
		Price = 3500,
		MaxHP = 750,
		MaxSpeed = 46,
		Accel = 6,
		Decel = 8,
		TurnRate = math.rad(13),
		Cannons = 4,
		Crew = 3,
		Draft = 3.5,
		Length = 64,
		Width = 18,
		Description = "Two masts, four cannons. A fast raider for a small crew.",
	},
	Galleon = {
		Id = "Galleon",
		Order = 3,
		DisplayName = "Galleon",
		Price = 10000,
		MaxHP = 1200,
		MaxSpeed = 50,
		Accel = 4.5,
		Decel = 7,
		TurnRate = math.rad(10),
		Cannons = 8,
		Crew = 4,
		Draft = 3.5,
		Length = 88,
		Width = 24,
		Description = "Three masts and eight cannons. The terror of the seas.",
	},
} :: { [string]: ShipDef }

Config.Sailing = {
	RudderRate = 0.9, -- how fast the wheel turns (full lock in ~1.1 s)
	SailRate = 0.45, -- how fast sails go up/down per second (0..1)
	AnchorDecel = 22,
	AnchorSpinBoost = 2.6, -- dropping anchor at speed spins the ship (like Sea of Thieves)
	MinTurnFactor = 0.3, -- fraction of turn rate available when standing still
	WindBonus = 0.45, -- sailing with the wind is up to this much faster
	HarbourRepairPerSecond = 12,
	BoundaryDamagePerSecond = 10,
	RamDamagePerSpeed = 1.2,
}

Config.Cannon = {
	Speed = 240,
	Gravity = 70,
	Cooldown = 2.2,
	ShipDamage = 60,
	PlayerDamage = 70,
	BlastRadius = 9,
	MaxYaw = math.rad(40),
	MinPitch = math.rad(-6),
	MaxPitch = math.rad(32),
	Lifetime = 8,
}

Config.Holes = {
	DrainPerSecond = 3, -- hp lost per second per open hole
	RepairHeal = 25,
	MaxHoles = 8,
	RepairTime = 2.5,
}

Config.SinkReward = 250

-- Items ---------------------------------------------------------------------
export type ItemDef = {
	Id: string,
	DisplayName: string,
	Price: number,
	Starter: boolean,
	Tradeable: boolean,
	Shop: string?,
	Description: string,
	Damage: number?,
	Cooldown: number?,
	Range: number?,
	DigStrikes: number?,
	Order: number,
	Icon: string?, -- emoji shown in shops and trades
}

Config.Items = {
	Cutlass = { Id = "Cutlass", DisplayName = "Cutlass", Price = 0, Starter = true, Tradeable = false, Description = "Trusty pirate sword.", Damage = 24, Cooldown = 0.55, Range = 7, Order = 1, Icon = "🗡️" },
	Shovel = { Id = "Shovel", DisplayName = "Shovel", Price = 0, Starter = true, Tradeable = false, Description = "Dig up buried treasure.", DigStrikes = 3, Order = 2, Icon = "⛏️" },
	Spyglass = { Id = "Spyglass", DisplayName = "Spyglass", Price = 0, Starter = true, Tradeable = false, Description = "Spot ships and islands from afar.", Order = 3, Icon = "🔭" },
	Flintlock = { Id = "Flintlock", DisplayName = "Flintlock Pistol", Price = 400, Starter = false, Tradeable = true, Shop = "Armory", Description = "One shot, big bang. Slow reload.", Damage = 45, Cooldown = 2.6, Range = 260, Order = 4, Icon = "💥" },
	GoldenCutlass = { Id = "GoldenCutlass", DisplayName = "Golden Cutlass", Price = 1800, Starter = false, Tradeable = true, Shop = "Armory", Description = "A captain's blade. Hits harder and faster.", Damage = 34, Cooldown = 0.5, Range = 7.5, Order = 5, Icon = "⚔️" },
	GoldenShovel = { Id = "GoldenShovel", DisplayName = "Golden Shovel", Price = 1200, Starter = false, Tradeable = true, Shop = "Armory", Description = "Digs treasure up in just 2 strikes.", DigStrikes = 2, Order = 6, Icon = "⛏️" },
} :: { [string]: ItemDef }

Config.SellBackRate = 0.5

-- Treasure ------------------------------------------------------------------
export type MapTier = {
	Id: string,
	DisplayName: string,
	Price: number,
	Chest: string,
	Guards: number,
	FarIslands: boolean?,
	NearIslands: boolean?,
	Order: number,
}

Config.MapTiers = {
	Castaway = { Id = "Castaway", DisplayName = "Castaway's Map", Price = 40, Chest = "Castaway", Guards = 0, NearIslands = true, Order = 1 },
	Seafarer = { Id = "Seafarer", DisplayName = "Seafarer's Map", Price = 150, Chest = "Seafarer", Guards = 1, Order = 2 },
	Marauder = { Id = "Marauder", DisplayName = "Marauder's Map", Price = 400, Chest = "Marauder", Guards = 2, Order = 3 },
	Captain = { Id = "Captain", DisplayName = "Captain's Map", Price = 900, Chest = "Captain", Guards = 3, FarIslands = true, Order = 4 },
} :: { [string]: MapTier }

export type ChestDef = {
	Id: string,
	DisplayName: string,
	Value: number,
	WalkSpeed: number,
	Order: number,
}

Config.Chests = {
	Castaway = { Id = "Castaway", DisplayName = "Castaway's Chest", Value = 80, WalkSpeed = 13, Order = 1 },
	Seafarer = { Id = "Seafarer", DisplayName = "Seafarer's Chest", Value = 260, WalkSpeed = 12.5, Order = 2 },
	Marauder = { Id = "Marauder", DisplayName = "Marauder's Chest", Value = 650, WalkSpeed = 12, Order = 3 },
	Captain = { Id = "Captain", DisplayName = "Captain's Chest", Value = 1500, WalkSpeed = 11, Order = 4 },
	King = { Id = "King", DisplayName = "Chest of the Pirate King", Value = 4000, WalkSpeed = 10, Order = 5 },
} :: { [string]: ChestDef }

Config.KingChestChance = 0.08 -- chance a Captain's map holds the Pirate King's chest
Config.MaxMaps = 5
Config.Dig = { Radius = 12, Cooldown = 0.75 }
Config.BeachChests = { Max = 8, Interval = 75, SeafarerChance = 0.25 }
Config.LooseChestLifetime = 20 * 60

-- Enemies -------------------------------------------------------------------
Config.Skeleton = {
	Health = 90,
	Damage = 12,
	AttackCooldown = 1.3,
	AttackRange = 5.5,
	AggroRange = 75,
	WalkSpeed = 14,
	RewardMin = 15,
	RewardMax = 30,
	ActivateDistance = 220, -- spawn skeletons when a player is this close to an island's shore
	DespawnDelay = 45,
	SpawnInterval = 7,
}

-- Player weapons ------------------------------------------------------------
Config.CarryWalkSpeed = 12
Config.DefaultWalkSpeed = 16

-- Trading / crews -----------------------------------------------------------
Config.MaxCrew = 4
Config.InviteTimeout = 25

-- Tavern
Config.GrogPrice = 10

-- World ---------------------------------------------------------------------
Config.DayLengthMinutes = 20 -- full day/night cycle (nights pass twice as fast)

-- Ship cosmetics (bought from the Shipwright) ---------------------------------
-- Every ship starts with black sails and no symbol.
export type SailColorDef = {
	Id: string,
	DisplayName: string,
	Color: Color3,
	Price: number,
	Order: number,
	Description: string,
}

Config.DefaultSailColor = "Black"
Config.SailColors = {
	Black = { Id = "Black", DisplayName = "Midnight Black", Color = Color3.fromRGB(30, 28, 32), Price = 0, Order = 1, Description = "Tarred black canvas. Feared on every sea." },
	White = { Id = "White", DisplayName = "Sailcloth White", Color = Color3.fromRGB(238, 232, 214), Price = 1200, Order = 2, Description = "Clean, bright canvas that shines in the sun." },
	Red = { Id = "Red", DisplayName = "Blood Red", Color = Color3.fromRGB(156, 28, 32), Price = 2000, Order = 3, Description = "Crimson sails tell rivals you mean business." },
} :: { [string]: SailColorDef }

export type SailSymbolDef = {
	Id: string,
	DisplayName: string,
	Glyph: string, -- emoji painted on the sail
	Price: number,
	BadgeColor: Color3, -- round badge behind the glyph
	Order: number,
}

Config.SailSymbols = {
	JollyRoger = { Id = "JollyRoger", DisplayName = "Jolly Roger", Glyph = "☠️", Price = 400, BadgeColor = Color3.fromRGB(44, 40, 46), Order = 1 },
	CrossedBlades = { Id = "CrossedBlades", DisplayName = "Crossed Blades", Glyph = "⚔️", Price = 600, BadgeColor = Color3.fromRGB(140, 32, 36), Order = 2 },
	Anchor = { Id = "Anchor", DisplayName = "Old Anchor", Glyph = "⚓", Price = 300, BadgeColor = Color3.fromRGB(32, 64, 122), Order = 3 },
	Palm = { Id = "Palm", DisplayName = "Castaway Palm", Glyph = "🌴", Price = 350, BadgeColor = Color3.fromRGB(214, 184, 116), Order = 4 },
	Crab = { Id = "Crab", DisplayName = "Hermit Crab", Glyph = "🦀", Price = 450, BadgeColor = Color3.fromRGB(232, 214, 168), Order = 5 },
	Star = { Id = "Star", DisplayName = "North Star", Glyph = "⭐", Price = 500, BadgeColor = Color3.fromRGB(26, 38, 84), Order = 6 },
	Moon = { Id = "Moon", DisplayName = "Crescent Moon", Glyph = "🌙", Price = 600, BadgeColor = Color3.fromRGB(34, 32, 72), Order = 7 },
	Compass = { Id = "Compass", DisplayName = "Compass Rose", Glyph = "🧭", Price = 700, BadgeColor = Color3.fromRGB(196, 156, 96), Order = 8 },
	Rose = { Id = "Rose", DisplayName = "Captain's Rose", Glyph = "🌹", Price = 700, BadgeColor = Color3.fromRGB(242, 228, 202), Order = 9 },
	Parrot = { Id = "Parrot", DisplayName = "Polly", Glyph = "🦜", Price = 800, BadgeColor = Color3.fromRGB(32, 122, 74), Order = 10 },
	Flame = { Id = "Flame", DisplayName = "Sea Fire", Glyph = "🔥", Price = 900, BadgeColor = Color3.fromRGB(66, 22, 18), Order = 11 },
	Lightning = { Id = "Lightning", DisplayName = "Storm Bolt", Glyph = "⚡", Price = 900, BadgeColor = Color3.fromRGB(58, 64, 84), Order = 12 },
	Shark = { Id = "Shark", DisplayName = "Great White", Glyph = "🦈", Price = 1000, BadgeColor = Color3.fromRGB(22, 104, 150), Order = 13 },
	Ghost = { Id = "Ghost", DisplayName = "Ghost Ship", Glyph = "👻", Price = 1200, BadgeColor = Color3.fromRGB(28, 92, 104), Order = 14 },
	Kraken = { Id = "Kraken", DisplayName = "Kraken", Glyph = "🐙", Price = 1400, BadgeColor = Color3.fromRGB(92, 42, 122), Order = 15 },
	Treasure = { Id = "Treasure", DisplayName = "Pieces of Eight", Glyph = "💰", Price = 1500, BadgeColor = Color3.fromRGB(122, 82, 22), Order = 16 },
	Whale = { Id = "Whale", DisplayName = "Leviathan", Glyph = "🐋", Price = 1600, BadgeColor = Color3.fromRGB(18, 58, 96), Order = 17 },
	Trident = { Id = "Trident", DisplayName = "Poseidon's Trident", Glyph = "🔱", Price = 1800, BadgeColor = Color3.fromRGB(16, 132, 142), Order = 18 },
	Dragon = { Id = "Dragon", DisplayName = "Sea Dragon", Glyph = "🐉", Price = 2000, BadgeColor = Color3.fromRGB(22, 112, 82), Order = 19 },
	Crown = { Id = "Crown", DisplayName = "Pirate Crown", Glyph = "👑", Price = 2500, BadgeColor = Color3.fromRGB(74, 32, 112), Order = 20 },
} :: { [string]: SailSymbolDef }

-- Fonts (asset ids; the client builds Font objects from these) ----------------
Config.Fonts = {
	Display = "rbxassetid://12187372175", -- Rye: titles, buttons, HUD, names
	Text = "rbxasset://fonts/families/Merriweather.json", -- readable serif for small print
}

-- UI palette ----------------------------------------------------------------
Config.Colors = {
	Parchment = Color3.fromRGB(247, 233, 196),
	ParchmentDark = Color3.fromRGB(226, 202, 150),
	Wood = Color3.fromRGB(96, 60, 32),
	WoodDark = Color3.fromRGB(62, 38, 20),
	Gold = Color3.fromRGB(255, 205, 80),
	GoldDark = Color3.fromRGB(196, 140, 30),
	Teal = Color3.fromRGB(24, 178, 186),
	Sea = Color3.fromRGB(18, 120, 150),
	Green = Color3.fromRGB(70, 175, 90),
	Red = Color3.fromRGB(210, 70, 60),
	Ink = Color3.fromRGB(52, 34, 20),
	White = Color3.fromRGB(255, 255, 255),
	WoodLight = Color3.fromRGB(150, 98, 56),
	Rope = Color3.fromRGB(200, 166, 110),
	Crimson = Color3.fromRGB(150, 34, 38),
	Navy = Color3.fromRGB(26, 46, 80),
	Shadow = Color3.fromRGB(22, 13, 6),
}

return Config
