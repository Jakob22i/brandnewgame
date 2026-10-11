-- Builds treasure chest templates (ServerStorage.Chests.*).
-- "Body" is the PrimaryPart; the rest is welded to it. Body is anchored in the
-- template; the server toggles that when chests are carried or placed.
local P = require("./Parts")

local V = P.Vector3.new
local CF = P.CFrame.new
local rgb = P.rgb

local Chests = {}

local TIERS = {
	Castaway = { Size = V(2.6, 1.4, 1.7), Wood = rgb(150, 104, 62), Band = rgb(76, 54, 36), Lock = rgb(120, 120, 126) },
	Seafarer = { Size = V(3.0, 1.6, 1.9), Wood = rgb(124, 82, 48), Band = rgb(92, 92, 98), Lock = rgb(200, 160, 70) },
	Marauder = { Size = V(3.2, 1.7, 2.0), Wood = rgb(110, 46, 40), Band = rgb(196, 196, 206), Lock = rgb(220, 220, 230), Light = rgb(220, 230, 255) },
	Captain = { Size = V(3.6, 1.9, 2.2), Wood = rgb(58, 38, 28), Band = rgb(244, 192, 64), Lock = rgb(255, 214, 90), Light = rgb(255, 200, 90) },
	King = { Size = V(4.0, 2.2, 2.5), Wood = rgb(255, 200, 70), Band = rgb(170, 30, 40), Lock = rgb(80, 200, 255), Light = rgb(255, 214, 110), Gems = true },
}

function Chests.Build(tier: string, def: any)
	local t = TIERS[tier]
	local model = P.model(nil, tier)
	local size = t.Size
	local body = P.part(model, { Name = "Body", Size = size, CFrame = CF(), Mat = if t.Gems then "Metal" else "WoodPlanks", Color = t.Wood, Reflectance = if t.Gems then 0.2 else 0 })
	model.PrimaryPart = body
	-- rounded lid (half of a cylinder sticks out of the top)
	P.part(model, { Name = "Lid", Shape = "Cylinder", Size = V(size.X, size.Z, size.Z), CFrame = CF(0, size.Y / 2, 0), Mat = if t.Gems then "Metal" else "WoodPlanks", Color = t.Wood, Reflectance = if t.Gems then 0.2 else 0 })
	-- metal bands
	for _, x in { -size.X * 0.32, size.X * 0.32 } do
		P.part(model, { Name = "Band", Size = V(0.22, size.Y + 0.04, size.Z + 0.06), CFrame = CF(x, 0, 0), Mat = "Metal", Color = t.Band })
		P.part(model, { Name = "BandLid", Shape = "Cylinder", Size = V(0.22, size.Z + 0.06, size.Z + 0.06), CFrame = CF(x, size.Y / 2, 0), Mat = "Metal", Color = t.Band })
	end
	P.part(model, { Name = "Rim", Size = V(size.X + 0.06, 0.18, size.Z + 0.06), CFrame = CF(0, size.Y / 2 - 0.05, 0), Mat = "Metal", Color = t.Band })
	P.part(model, { Name = "Lock", Size = V(0.5, 0.6, 0.15), CFrame = CF(0, size.Y / 2 - 0.25, -size.Z / 2 - 0.08), Mat = "Metal", Color = t.Lock, Reflectance = 0.2 })
	if t.Gems then
		for i, color in { rgb(255, 60, 80), rgb(80, 220, 255), rgb(90, 255, 120) } do
			P.part(model, { Name = "Gem", Shape = "Ball", Size = V(0.35, 0.35, 0.35), CFrame = CF((i - 2) * 0.9, 0.1, -size.Z / 2 - 0.05), Mat = "Neon", Color = color })
		end
	end
	if t.Light then
		P.pointLight(body, t.Light, 12, 1.2, false)
		local sparkle = P.emitter(body, {
			Name = "Sparkle",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = if t.Gems then 10 else 4,
			Lifetime = P.NumberRange.new(0.6, 1.2),
			Speed = P.NumberRange.new(0.5, 1.5),
			Size = P.seq(0.4, 0),
			Color = P.ColorSequence.new(t.Light),
			LightEmission = 1,
		})
		sparkle.SpreadAngle = P.Vector2.new(180, 180)
	end
	for _, part in P.descendantParts(model) do
		part.CanTouch = false
		if part ~= body then
			part.Anchored = false
			part.Massless = true
			P.weld(body, part)
		end
	end
	model:SetAttribute("Tier", tier)
	model:SetAttribute("Value", def.Value)
	model:SetAttribute("DisplayName", def.DisplayName)
	return model
end

return Chests
