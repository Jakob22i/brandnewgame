-- Helpers for building models out of parts inside Lune.
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum
local UDim2 = roblox.UDim2
local Font = roblox.Font

local P = {}

-- Rye (Roblox Creator Store font family 12187372175): the game's pirate font
P.RYE = Font.new("rbxassetid://12187372175")

P.Instance = Instance
P.Vector3 = Vector3
P.CFrame = CFrame
P.Color3 = Color3
P.Enum = Enum
P.UDim2 = UDim2
P.Font = Font
P.Vector2 = roblox.Vector2
P.NumberSequence = roblox.NumberSequence
P.NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
P.ColorSequence = roblox.ColorSequence
P.NumberRange = roblox.NumberRange

function P.rgb(r: number, g: number, b: number)
	return Color3.fromRGB(r, g, b)
end

function P.v3(x: number, y: number, z: number)
	return Vector3.new(x, y, z)
end

local CYLINDER_UP = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's X axis to point up

-- Same as Roblox's CFrame.lookAt (Lune's version gives wrong results for tilted directions)
function P.lookAt(pos: any, target: any)
	local back = (pos - target).Unit
	local up = Vector3.new(0, 1, 0)
	if math.abs(back.Y) > 0.999 then
		up = Vector3.new(0, 0, 1)
	end
	local x = up:Cross(back).Unit
	local y = back:Cross(x)
	return CFrame.fromMatrix(pos, x, y, back)
end

-- Create an anchored, smooth part. props may contain any property plus:
--   Class = "WedgePart" / "TrussPart" / ...
--   Shape = "Cylinder" | "Ball" (string shortcuts)
--   Mat = "WoodPlanks" (material name shortcut)
function P.part(parent: any, props: { [string]: any })
	local part = Instance.new(props.Class or "Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key == "Class" then
			continue
		elseif key == "Shape" then
			part.Shape = Enum.PartType[value]
		elseif key == "Mat" then
			part.Material = Enum.Material[value]
		else
			part[key] = value
		end
	end
	if part.Name == "Part" or part.Name == "WedgePart" then
		part.Name = props.Name or part.Name
	end
	part.Parent = parent
	return part
end

-- Vertical cylinder from y0 to y1 at (x, z)
function P.pillar(parent: any, x: number, z: number, y0: number, y1: number, diameter: number, props: { [string]: any }?)
	local p = props or {}
	local merged: { [string]: any } = {
		Shape = "Cylinder",
		Size = Vector3.new(y1 - y0, diameter, diameter),
		CFrame = CFrame.new(x, (y0 + y1) / 2, z) * CYLINDER_UP,
	}
	for k, v in p do
		merged[k] = v
	end
	return P.part(parent, merged)
end

-- Cylinder between two points
function P.beam(parent: any, a: any, b: any, diameter: number, props: { [string]: any }?)
	local mid = (a + b) / 2
	local dir = b - a
	local length = dir.Magnitude
	local merged: { [string]: any } = {
		Shape = "Cylinder",
		Size = Vector3.new(length, diameter, diameter),
		CFrame = P.lookAt(mid, mid + dir) * CFrame.Angles(0, math.pi / 2, 0),
	}
	for k, v in props or {} do
		merged[k] = v
	end
	return P.part(parent, merged)
end

-- Block between two points (thickness x height, long along the segment)
function P.plank(parent: any, a: any, b: any, width: number, height: number, props: { [string]: any }?)
	local mid = (a + b) / 2
	local dir = b - a
	local merged: { [string]: any } = {
		Size = Vector3.new(width, height, dir.Magnitude),
		CFrame = P.lookAt(mid, mid + dir),
	}
	for k, v in props or {} do
		merged[k] = v
	end
	return P.part(parent, merged)
end

-- Right-angled horizontal wedge used for pointed bows and roofs.
-- Builds the triangle (0,0) (sx,0) (0,-sz) in the XZ plane (x to the given side, z forward),
-- extruded from y0 to y1. side = 1 (right/+X) or -1 (left/-X). zBack = z of the flat edge.
function P.bowWedge(parent: any, side: number, halfWidth: number, length: number, zBack: number, y0: number, y1: number, props: { [string]: any })
	local vX = if side > 0 then Vector3.new(0, -1, 0) else Vector3.new(0, 1, 0)
	local vY = Vector3.new(side, 0, 0)
	local vZ = Vector3.new(0, 0, 1)
	local center = Vector3.new(side * halfWidth / 2, (y0 + y1) / 2, zBack - length / 2)
	local merged: { [string]: any } = {
		Class = "WedgePart",
		Size = Vector3.new(y1 - y0, halfWidth, length),
		CFrame = CFrame.fromMatrix(center, vX, vY, vZ),
	}
	for k, v in props do
		merged[k] = v
	end
	return P.part(parent, merged)
end

-- Gable roof made of two wedges. Ridge runs along local Z. Returns both parts.
-- (cx, cz) centre, width along X, depth along Z, baseY = top of the walls.
function P.gableRoof(parent: any, origin: any, width: number, depth: number, baseY: number, rise: number, overhang: number, props: { [string]: any })
	local half = width / 2 + overhang
	local parts = {}
	for _, side in { -1, 1 } do
		local vX = Vector3.new(0, 0, side)
		local vY = Vector3.new(0, 1, 0)
		local vZ = Vector3.new(-side, 0, 0)
		local center = Vector3.new(side * half / 2, baseY + rise / 2, 0)
		local merged: { [string]: any } = {
			Class = "WedgePart",
			Size = Vector3.new(depth + overhang * 2, rise, half),
			CFrame = origin * CFrame.fromMatrix(center, vX, vY, vZ),
		}
		for k, v in props do
			merged[k] = v
		end
		table.insert(parts, P.part(parent, merged))
	end
	return parts
end

-- Weld part1 to part0 keeping their current offset (classic Weld, survives cloning)
function P.weld(part0: any, part1: any, name: string?)
	local weld = Instance.new("Weld")
	weld.Name = name or "Weld"
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = part0.CFrame:Inverse() * part1.CFrame
	weld.C1 = CFrame.new()
	weld.Parent = part1
	return weld
end

function P.descendantParts(root: any)
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- Weld every part of a model to `root` except parts listed in `skip` (set) and parts
-- that already have a Weld inside them.
function P.weldAllTo(model: any, root: any, skip: { [any]: boolean }?)
	for _, part in P.descendantParts(model) do
		if part ~= root and not (skip and skip[part]) and not part:FindFirstChildOfClass("Weld") then
			P.weld(root, part)
		end
	end
end

-- Move/rotate every part of a model (Lune has no PivotTo)
function P.transform(model: any, cf: any)
	for _, part in P.descendantParts(model) do
		part.CFrame = cf * part.CFrame
	end
end

function P.setAll(model: any, props: { [string]: any })
	for _, part in P.descendantParts(model) do
		for k, v in props do
			part[k] = v
		end
	end
end

function P.model(parent: any, name: string)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function P.folder(parent: any, name: string)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Text on a part face (SurfaceGui + TextLabel)
function P.surfaceText(part: any, face: string, text: string, opts: { [string]: any }?)
	local o = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = o.Name or "SurfaceGui"
	gui.Face = Enum.NormalId[face]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.PixelsPerStud or 40
	gui.LightInfluence = o.LightInfluence or 0.6
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = o.Color or Color3.fromRGB(255, 220, 120)
	label.TextStrokeTransparency = o.StrokeTransparency or 0.4
	label.TextStrokeColor3 = o.StrokeColor or Color3.fromRGB(40, 20, 10)
	label.FontFace = if o.FontFace then o.FontFace elseif o.Font then Font.fromEnum(o.Font) else P.RYE
	label.TextTransparency = o.TextTransparency or 0
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	local p = o.Padding or 0.08
	pad.PaddingLeft = roblox.UDim.new(p, 0)
	pad.PaddingRight = roblox.UDim.new(p, 0)
	pad.PaddingTop = roblox.UDim.new(p, 0)
	pad.PaddingBottom = roblox.UDim.new(p, 0)
	pad.Parent = label
	return gui, label
end

function P.pointLight(parent: any, color: any, range: number, brightness: number, shadows: boolean?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

function P.prompt(parent: any, props: { [string]: any })
	local prompt = Instance.new("ProximityPrompt")
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 9
	for k, v in props do
		prompt[k] = v
	end
	prompt.Parent = parent
	return prompt
end

function P.attachment(parent: any, name: string, worldCFrame: any)
	local att = Instance.new("Attachment")
	att.Name = name
	att.CFrame = parent.CFrame:Inverse() * worldCFrame
	att.Parent = parent
	return att
end

function P.billboard(parent: any, name: string, text: string, opts: { [string]: any }?)
	local o = opts or {}
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = o.Size or UDim2.fromOffset(240, 50)
	gui.StudsOffset = o.Offset or Vector3.new(0, 3, 0)
	gui.MaxDistance = o.MaxDistance or 120
	gui.AlwaysOnTop = o.AlwaysOnTop == true
	gui.LightInfluence = 0
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = o.Color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(30, 20, 10)
	label.FontFace = if o.FontFace then o.FontFace elseif o.Font then Font.fromEnum(o.Font) else P.RYE
	label.Parent = gui
	return gui, label
end

-- Particle emitter with sane defaults
function P.emitter(parent: any, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

function P.seq(a: number, b: number)
	return roblox.NumberSequence.new(a, b)
end

return P
