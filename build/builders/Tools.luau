-- Builds the Tool templates (ServerStorage.Tools.*).
-- Hand grip convention (R15 RightGripAttachment): with the arm held forward the
-- handle's +Y points up and its -Z points forward.
local P = require("./Parts")

local V = P.Vector3.new
local CF = P.CFrame.new
local Angles = P.CFrame.Angles
local rgb = P.rgb

local Tools = {}

local function newTool(name: string, tip: string, grip: any?)
	local tool = P.Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = grip or CF()
	return tool
end

local function finish(tool: any, handle: any)
	for _, part in P.descendantParts(tool) do
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
		part.CanTouch = false
		if part ~= handle then
			P.weld(handle, part)
		end
	end
	return tool
end

local function sword(name: string, tip: string, bladeColor: any, guardColor: any, golden: boolean)
	local tool = newTool(name, tip)
	local handle = P.part(tool, { Name = "Handle", Size = V(0.35, 1.2, 0.35), CFrame = CF(), Mat = "Wood", Color = rgb(70, 44, 26) })
	P.part(tool, { Name = "Pommel", Shape = "Ball", Size = V(0.42, 0.42, 0.42), CFrame = CF(0, -0.7, 0), Mat = "Metal", Color = guardColor })
	P.part(tool, { Name = "Guard", Size = V(0.22, 0.22, 1.3), CFrame = CF(0, 0.68, 0), Mat = "Metal", Color = guardColor })
	P.part(tool, { Name = "Knuckle", Size = V(0.16, 1.2, 0.16), CFrame = CF(0, 0.05, -0.55), Mat = "Metal", Color = guardColor })
	P.part(tool, { Name = "Blade", Size = V(0.1, 2.5, 0.42), CFrame = CF(0, 2.0, 0.02), Mat = "Metal", Color = bladeColor, Reflectance = if golden then 0.25 else 0.15 })
	P.part(tool, { Class = "WedgePart", Name = "BladeTip", Size = V(0.1, 1.5, 0.42), CFrame = CF(0, 4.0, 0.06) * Angles(math.rad(-8), 0, 0) * Angles(0, 0, 0), Mat = "Metal", Color = bladeColor, Reflectance = if golden then 0.25 else 0.15 })
	if golden then
		local sparkle = P.emitter(tool:FindFirstChild("Blade"), {
			Name = "Sparkle",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Rate = 4,
			Lifetime = P.NumberRange.new(0.5, 0.9),
			Speed = P.NumberRange.new(0.2, 0.6),
			Size = P.seq(0.25, 0),
			Color = P.ColorSequence.new(rgb(255, 230, 140)),
			LightEmission = 1,
		})
		sparkle.SpreadAngle = P.Vector2.new(180, 180)
	end
	return finish(tool, handle)
end

local function shovel(name: string, tip: string, bladeColor: any, golden: boolean)
	local tool = newTool(name, tip, CF(0, 1.0, 0))
	local handle = P.part(tool, { Name = "Handle", Size = V(0.28, 4.2, 0.28), CFrame = CF(), Mat = "Wood", Color = rgb(128, 88, 52) })
	P.part(tool, { Name = "Grip", Size = V(0.9, 0.25, 0.25), CFrame = CF(0, 2.15, 0), Mat = "Wood", Color = rgb(96, 64, 36) })
	P.part(tool, { Name = "Socket", Shape = "Cylinder", Size = V(0.6, 0.4, 0.4), CFrame = CF(0, -2.1, 0) * Angles(0, 0, math.pi / 2), Mat = "Metal", Color = bladeColor })
	P.part(tool, { Name = "Spade", Size = V(1.2, 1.3, 0.12), CFrame = CF(0, -2.9, -0.05), Mat = "Metal", Color = bladeColor, Reflectance = if golden then 0.25 else 0.1 })
	P.part(tool, { Class = "WedgePart", Name = "SpadeTip", Size = V(1.2, 0.5, 0.12), CFrame = CF(0, -3.8, -0.05) * Angles(math.pi, 0, 0), Mat = "Metal", Color = bladeColor })
	return finish(tool, handle)
end

function Tools.Build()
	local list = {}

	table.insert(list, sword("Cutlass", "Swing at skeletons and rival pirates", rgb(200, 204, 212), rgb(196, 150, 60), false))
	table.insert(list, sword("GoldenCutlass", "A captain's blade", rgb(255, 206, 80), rgb(255, 230, 140), true))
	table.insert(list, shovel("Shovel", "Click at the X on your treasure map to dig", rgb(150, 150, 156), false))
	table.insert(list, shovel("GoldenShovel", "Digs treasure in 2 strikes", rgb(255, 204, 70), true))

	-- Flintlock pistol: barrel points forward (-Z)
	do
		local tool = newTool("Flintlock", "Click to shoot (slow reload)")
		local handle = P.part(tool, { Name = "Handle", Size = V(0.32, 1.0, 0.5), CFrame = CF(0, 0, 0.1), Mat = "Wood", Color = rgb(96, 58, 32) })
		P.part(tool, { Name = "Barrel", Shape = "Cylinder", Size = V(2.0, 0.28, 0.28), CFrame = CF(0, 0.45, -0.9) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = rgb(60, 60, 66) })
		P.part(tool, { Name = "Stock", Size = V(0.3, 0.32, 1.2), CFrame = CF(0, 0.38, -0.4), Mat = "Wood", Color = rgb(96, 58, 32) })
		P.part(tool, { Name = "Lock", Size = V(0.36, 0.3, 0.4), CFrame = CF(0, 0.55, 0.0), Mat = "Metal", Color = rgb(210, 170, 70) })
		P.part(tool, { Name = "Muzzle", Shape = "Cylinder", Size = V(0.18, 0.36, 0.36), CFrame = CF(0, 0.45, -1.88) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = rgb(210, 170, 70) })
		finish(tool, handle)
		P.attachment(handle, "MuzzleAttachment", CF(0, 0.45, -2.0))
		table.insert(list, tool)
	end

	-- Spyglass: brass tube pointing forward
	do
		local tool = newTool("Spyglass", "Click to look through the spyglass")
		local handle = P.part(tool, { Name = "Handle", Shape = "Cylinder", Size = V(1.4, 0.42, 0.42), CFrame = CF(0, 0, -0.2) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = rgb(196, 150, 70), Reflectance = 0.15 })
		P.part(tool, { Name = "Tube", Shape = "Cylinder", Size = V(1.2, 0.34, 0.34), CFrame = CF(0, 0, -1.4) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = rgb(200, 160, 80), Reflectance = 0.15 })
		P.part(tool, { Name = "Leather", Shape = "Cylinder", Size = V(0.8, 0.46, 0.46), CFrame = CF(0, 0, 0.3) * Angles(0, math.pi / 2, 0), Mat = "Fabric", Color = rgb(90, 50, 30) })
		P.part(tool, { Name = "Lens", Shape = "Cylinder", Size = V(0.1, 0.36, 0.36), CFrame = CF(0, 0, -2.0) * Angles(0, math.pi / 2, 0), Mat = "Glass", Color = rgb(170, 220, 255), Transparency = 0.3 })
		table.insert(list, finish(tool, handle))
	end

	-- Treasure map: a rolled parchment
	do
		local tool = newTool("TreasureMap", "Equip to read your treasure maps")
		local handle = P.part(tool, { Name = "Handle", Shape = "Cylinder", Size = V(1.8, 0.45, 0.45), CFrame = CF(0, 0, -0.3), Mat = "Fabric", Color = rgb(238, 220, 172) })
		P.part(tool, { Name = "Ribbon", Shape = "Cylinder", Size = V(0.2, 0.5, 0.5), CFrame = CF(0, 0, -0.3), Mat = "Fabric", Color = rgb(190, 40, 36) })
		table.insert(list, finish(tool, handle))
	end

	return list
end

return Tools
