-- R6 character rigs built from parts: skeleton pirates and the shopkeepers of Kingshaven.
-- Feet stand on y = 0, the rig faces -Z.
local P = require("./Parts")

local V = P.Vector3.new
local CF = P.CFrame.new
local rgb = P.rgb

local Rigs = {}

local function joint(name: string, part0: any, part1: any, c0: any, c1: any)
	local m = P.Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.MaxVelocity = 0.1
	m.Parent = part0
	part1.CFrame = part0.CFrame * c0 * c1:Inverse()
	return m
end

local ROOT_ROT = CF(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
local R_ROT = CF(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
local L_ROT = CF(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)

-- opts: Name, Skin, Torso, Arms, Legs, LimbWidth, Skeleton (bool)
function Rigs.Base(opts: { [string]: any })
	local model = P.model(nil, opts.Name or "Rig")
	local limbW = opts.LimbWidth or 1
	local hrp = P.part(model, { Name = "HumanoidRootPart", Size = V(2, 2, 1), CFrame = CF(0, 3, 0), Transparency = 1, CanCollide = false })
	local torso = P.part(model, { Name = "Torso", Size = V(2, 2, 1), CFrame = CF(0, 3, 0), Color = opts.Torso, Transparency = if opts.Skeleton then 1 else 0 })
	local head = P.part(model, {
		Name = "Head",
		Size = if opts.Skeleton then V(1.3, 1.3, 1.3) else V(2, 1, 1),
		Shape = if opts.Skeleton then "Ball" else nil,
		Color = opts.Skin,
		CFrame = CF(0, 4.5, 0),
	})
	if not opts.Skeleton then
		local mesh = P.Instance.new("SpecialMesh")
		mesh.MeshType = P.Enum.MeshType.Head
		mesh.Scale = V(1.25, 1.25, 1.25)
		mesh.Parent = head
		local face = P.Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = P.Enum.NormalId.Front
		face.Parent = head
	end
	local rArm = P.part(model, { Name = "Right Arm", Size = V(limbW * 0.95, 2, limbW * 0.95), Color = opts.Arms or opts.Skin, CFrame = CF() })
	local lArm = P.part(model, { Name = "Left Arm", Size = V(limbW * 0.95, 2, limbW * 0.95), Color = opts.Arms or opts.Skin, CFrame = CF() })
	local rLeg = P.part(model, { Name = "Right Leg", Size = V(limbW, 2, limbW), Color = opts.Legs, CFrame = CF() })
	local lLeg = P.part(model, { Name = "Left Leg", Size = V(limbW, 2, limbW), Color = opts.Legs, CFrame = CF() })

	joint("RootJoint", hrp, torso, ROOT_ROT, ROOT_ROT)
	joint("Neck", torso, head, CF(0, 1, 0) * ROOT_ROT, CF(0, -0.5, 0) * ROOT_ROT)
	local aw = limbW * 0.95 / 2
	joint("Right Shoulder", torso, rArm, CF(1, 0.5, 0) * R_ROT, CF(-aw, 0.5, 0) * R_ROT)
	joint("Left Shoulder", torso, lArm, CF(-1, 0.5, 0) * L_ROT, CF(aw, 0.5, 0) * L_ROT)
	joint("Right Hip", torso, rLeg, CF(1, -1, 0) * R_ROT, CF(0.5, 1, 0) * R_ROT)
	joint("Left Hip", torso, lLeg, CF(-1, -1, 0) * L_ROT, CF(-0.5, 1, 0) * L_ROT)

	local humanoid = P.Instance.new("Humanoid")
	humanoid.RigType = P.Enum.HumanoidRigType.R6
	humanoid.Parent = model
	local animator = P.Instance.new("Animator")
	animator.Parent = humanoid

	model.PrimaryPart = hrp
	return model, { HRP = hrp, Torso = torso, Head = head, RightArm = rArm, LeftArm = lArm, RightLeg = rLeg, LeftLeg = lLeg, Humanoid = humanoid }
end

-- Decorations welded to body parts
local function deco(model: any, attachTo: any, props: { [string]: any })
	props.CanCollide = false
	props.Massless = true
	local part = P.part(model, props)
	P.weld(attachTo, part)
	return part
end
Rigs.Deco = deco

local function tricorn(model: any, head: any, color: any, trim: any?)
	local top = head.CFrame.Position.Y + head.Size.Y / 2
	deco(model, head, { Name = "HatBrim", Shape = "Cylinder", Size = V(0.25, 2.5, 2.5), CFrame = CF(head.CFrame.Position.X, top - 0.05, head.CFrame.Position.Z) * P.CFrame.Angles(0, 0, math.pi / 2), Color = color, Mat = "Fabric" })
	deco(model, head, { Name = "HatCrown", Size = V(1.4, 0.75, 1.3), CFrame = CF(head.CFrame.Position.X, top + 0.35, head.CFrame.Position.Z), Color = color, Mat = "Fabric" })
	if trim then
		deco(model, head, { Name = "HatBand", Size = V(1.45, 0.18, 1.35), CFrame = CF(head.CFrame.Position.X, top + 0.05, head.CFrame.Position.Z), Color = trim, Mat = "Fabric" })
	end
end
Rigs.Tricorn = tricorn

function Rigs.Skeleton()
	local bone = rgb(232, 224, 198)
	local model, r = Rigs.Base({ Name = "Skeleton", Skin = bone, Torso = bone, Legs = bone, LimbWidth = 0.55, Skeleton = true })
	local torso = r.Torso
	local tp = torso.CFrame.Position
	deco(model, torso, { Name = "Spine", Size = V(0.32, 2, 0.32), CFrame = CF(tp.X, tp.Y, tp.Z + 0.2), Color = bone })
	deco(model, torso, { Name = "Collar", Size = V(2.0, 0.3, 0.45), CFrame = CF(tp.X, tp.Y + 0.85, tp.Z), Color = bone })
	for i = 0, 2 do
		deco(model, torso, { Name = "Rib", Size = V(1.6 - i * 0.2, 0.18, 0.85), CFrame = CF(tp.X, tp.Y + 0.4 - i * 0.42, tp.Z - 0.05), Color = bone })
	end
	deco(model, torso, { Name = "Pelvis", Size = V(1.7, 0.45, 0.7), CFrame = CF(tp.X, tp.Y - 0.8, tp.Z), Color = bone })
	-- skull details
	local hp = r.Head.CFrame.Position
	deco(model, r.Head, { Name = "Jaw", Size = V(0.85, 0.32, 0.75), CFrame = CF(hp.X, hp.Y - 0.6, hp.Z - 0.1), Color = bone })
	for _, x in { -0.28, 0.28 } do
		deco(model, r.Head, { Name = "Socket", Shape = "Ball", Size = V(0.4, 0.4, 0.4), CFrame = CF(hp.X + x, hp.Y + 0.05, hp.Z - 0.5), Color = rgb(20, 18, 16) })
		local eye = deco(model, r.Head, { Name = "Eye", Shape = "Ball", Size = V(0.18, 0.18, 0.18), CFrame = CF(hp.X + x, hp.Y + 0.05, hp.Z - 0.62), Color = rgb(90, 255, 140), Mat = "Neon" })
		if x > 0 then
			P.pointLight(eye, rgb(90, 255, 140), 7, 1.2, false)
		end
	end
	tricorn(model, r.Head, rgb(28, 24, 26), rgb(160, 30, 30))
	-- rusty cutlass in the right hand, pointing forward
	local ap = r.RightArm.CFrame.Position
	deco(model, r.RightArm, { Name = "SwordHilt", Size = V(0.25, 0.25, 0.6), CFrame = CF(ap.X, ap.Y - 1.05, ap.Z - 0.1), Color = rgb(90, 60, 30) })
	deco(model, r.RightArm, { Name = "SwordBlade", Size = V(0.1, 0.35, 2.4), CFrame = CF(ap.X, ap.Y - 1.05, ap.Z - 1.6), Color = rgb(150, 120, 96), Mat = "Metal" })
	-- tattered sash
	deco(model, torso, { Name = "Sash", Size = V(1.75, 0.35, 0.75), CFrame = CF(tp.X, tp.Y - 0.5, tp.Z), Color = rgb(150, 34, 34), Mat = "Fabric" })

	local h = r.Humanoid
	h.WalkSpeed = 14
	h.MaxHealth = 90
	h.Health = 90
	h.DisplayName = "Skeleton Pirate"
	h.HealthDisplayType = P.Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	h.BreakJointsOnDeath = true
	for _, part in P.descendantParts(model) do
		part.Anchored = false
	end
	model:SetAttribute("Enemy", true)
	return model
end

-- Shopkeeper NPC. look: { Skin, Shirt, Pants, Hat = "Tricorn"|"Bandana"|nil, HatColor, Beard }
function Rigs.Npc(name: string, look: { [string]: any })
	local model, r = Rigs.Base({ Name = name, Skin = look.Skin, Torso = look.Shirt, Arms = look.Sleeves or look.Shirt, Legs = look.Pants })
	local tp = r.Torso.CFrame.Position
	deco(model, r.Torso, { Name = "Belt", Size = V(2.05, 0.35, 1.05), CFrame = CF(tp.X, tp.Y - 0.7, tp.Z), Color = rgb(50, 32, 20) })
	deco(model, r.Torso, { Name = "Buckle", Size = V(0.4, 0.3, 0.1), CFrame = CF(tp.X, tp.Y - 0.7, tp.Z - 0.55), Color = rgb(230, 186, 70), Mat = "Metal" })
	if look.Vest then
		deco(model, r.Torso, { Name = "Vest", Size = V(2.04, 1.6, 1.04), CFrame = CF(tp.X, tp.Y + 0.15, tp.Z), Color = look.Vest, Mat = "Fabric" })
		deco(model, r.Torso, { Name = "Shirt", Size = V(0.7, 1.6, 0.1), CFrame = CF(tp.X, tp.Y + 0.15, tp.Z - 0.53), Color = look.Shirt, Mat = "Fabric" })
	end
	local hp = r.Head.CFrame.Position
	if look.Hat == "Tricorn" then
		tricorn(model, r.Head, look.HatColor or rgb(30, 26, 26), look.HatTrim)
	elseif look.Hat == "Bandana" then
		deco(model, r.Head, { Name = "Bandana", Size = V(2.1, 0.5, 1.15), CFrame = CF(hp.X, hp.Y + 0.4, hp.Z), Color = look.HatColor or rgb(200, 40, 40), Mat = "Fabric" })
	end
	if look.Beard then
		deco(model, r.Head, { Name = "Beard", Size = V(1.2, 0.6, 0.4), CFrame = CF(hp.X, hp.Y - 0.45, hp.Z - 0.45), Color = look.Beard, Mat = "Fabric" })
	end
	if look.EyePatch then
		deco(model, r.Head, { Name = "EyePatch", Size = V(0.35, 0.35, 0.1), CFrame = CF(hp.X + 0.25, hp.Y + 0.1, hp.Z - 0.62), Color = rgb(15, 15, 15) })
		deco(model, r.Head, { Name = "Strap", Size = V(2.12, 0.1, 1.12), CFrame = CF(hp.X, hp.Y + 0.2, hp.Z) * P.CFrame.Angles(0, 0, math.rad(-12)), Color = rgb(15, 15, 15) })
	end
	if look.Parrot then
		local sp = r.LeftArm.CFrame.Position
		deco(model, r.Torso, { Name = "Parrot", Size = V(0.5, 0.8, 0.6), CFrame = CF(sp.X, sp.Y + 1.4, sp.Z), Color = rgb(40, 200, 80) })
		deco(model, r.Torso, { Name = "ParrotHead", Shape = "Ball", Size = V(0.5, 0.5, 0.5), CFrame = CF(sp.X, sp.Y + 1.95, sp.Z - 0.1), Color = rgb(230, 50, 40) })
		deco(model, r.Torso, { Name = "ParrotBeak", Size = V(0.18, 0.18, 0.25), CFrame = CF(sp.X, sp.Y + 1.9, sp.Z - 0.4), Color = rgb(255, 200, 40) })
	end
	local h = r.Humanoid
	h.DisplayDistanceType = P.Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = P.Enum.HumanoidHealthDisplayType.AlwaysOff
	h.MaxHealth = 1000
	h.Health = 1000
	for _, part in P.descendantParts(model) do
		part.Anchored = part.Name == "HumanoidRootPart"
	end
	return model, r
end

return Rigs
