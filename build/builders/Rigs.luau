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
	-- like Roblox's own R6 characters: only the torso and head collide
	for _, limb in { rArm, lArm, rLeg, lLeg } do
		limb.CanCollide = false
	end

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


-- Shopkeepers ------------------------------------------------------------------------------
-- Everything below decorates an R6 rig (Rigs.Base). Offsets are given in the space of the body
-- part they are welded to; the rig faces -Z, so "front" is -Z and the character's right is +X.
-- The R6 limbs stay as invisible joint carriers (so animations still work) and carry rounded
-- clothes: capsule sleeves and trousers, boots with round toes, layered vests and coats.

local Angles = P.CFrame.Angles
local fromMatrix = P.CFrame.fromMatrix
local GOLD = rgb(232, 184, 72)
local BRASS = rgb(204, 160, 74)

local function merge(a: { [string]: any }, b: { [string]: any }?)
	if b then
		for k, v in b do
			a[k] = v
		end
	end
	return a
end

-- Box welded to `body` at `offset` (a CFrame in the body part's space)
local function on(model: any, body: any, name: string, size: any, offset: any, color: any, mat: string?, extra: { [string]: any }?)
	return deco(model, body, merge({ Name = name, Size = size, CFrame = body.CFrame * offset, Color = color, Mat = mat or "SmoothPlastic" }, extra))
end

-- Cylinder welded to `body`; its axis is the offset's Y axis
local function onCyl(model: any, body: any, name: string, length: number, diameter: number, offset: any, color: any, mat: string?)
	return on(model, body, name, V(length, diameter, diameter), offset * Angles(0, 0, math.pi / 2), color, mat, { Shape = "Cylinder" })
end

local function onBall(model: any, body: any, name: string, d: number, offset: any, color: any, mat: string?)
	return on(model, body, name, V(d, d, d), offset, color, mat, { Shape = "Ball" })
end

-- Ellipsoid (a block with a Sphere mesh, which stretches with the part's size)
local function onEgg(model: any, body: any, name: string, size: any, offset: any, color: any, mat: string?)
	local part = on(model, body, name, size, offset, color, mat)
	local mesh = P.Instance.new("SpecialMesh")
	mesh.MeshType = P.Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Wedge welded to `body`: right angle at `corner`, legs `a` and `b` (body space vectors)
local function onWedge(model: any, body: any, name: string, corner: any, a: any, b: any, thick: number, color: any, mat: string?)
	local vZ = -a.Unit
	local vY = b.Unit
	local vX = vY:Cross(vZ)
	local centre = corner + a / 2 + b / 2
	return on(model, body, name, V(thick, b.Magnitude, a.Magnitude), fromMatrix(centre, vX, vY, vZ), color, mat, { Class = "WedgePart" })
end

local function shade(c: any, f: number)
	return P.Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

-- Hats -------------------------------------------------------------------------------------------

-- Big three-cornered hat with upturned brims (one corner points forward)
local function bigTricorn(model: any, head: any, color: any, trim: any?)
	onEgg(model, head, "HatCrown", V(1.34, 0.95, 1.34), CF(0, 0.72, 0.03), color, "Fabric")
	local R = 1.25
	local up = V(0, 1, 0)
	for k = 0, 2 do
		local m = math.rad(-90 + k * 120 + 60) -- edge midpoint direction
		local radial = V(math.cos(m), 0, math.sin(m))
		local along = V(-math.sin(m), 0, math.cos(m))
		local tilt = math.rad(22)
		local wallUp = up * math.cos(tilt) + radial * math.sin(tilt)
		local pos = radial * (R * 0.5) + V(0, 0.62, 0) + wallUp * 0.26
		local frame = fromMatrix(pos, along, wallUp, along:Cross(wallUp))
		on(model, head, "HatBrim", V(R * 1.8, 0.66, 0.14), frame, color, "Fabric")
		if trim then
			on(model, head, "HatTrim", V(R * 1.82, 0.1, 0.2), frame * CF(0, 0.33, 0), trim, "Fabric")
		end
	end
	onCyl(model, head, "HatBase", 0.1, 1.55, CF(0, 0.46, 0), color, "Fabric")
end

local function wideBrim(model: any, head: any, color: any, band: any?)
	local tilt = CF(0, 0.52, 0) * Angles(math.rad(-8), 0, math.rad(6))
	onCyl(model, head, "HatBrim", 0.1, 2.9, tilt, color, "Fabric")
	onEgg(model, head, "HatCrown", V(1.3, 1.0, 1.3), tilt * CF(0, 0.3, 0), color, "Fabric")
	onCyl(model, head, "HatBand", 0.2, 1.3, tilt * CF(0, 0.12, 0), band or shade(color, 0.6), "Fabric")
end

local function bandana(model: any, head: any, color: any, longTails: boolean?)
	onEgg(model, head, "Bandana", V(1.34, 1.0, 1.36), CF(0, 0.36, 0.03), color, "Fabric")
	onCyl(model, head, "BandanaBand", 0.24, 1.33, CF(0, 0.2, 0), shade(color, 0.85), "Fabric")
	onBall(model, head, "BandanaKnot", 0.4, CF(0, 0.22, 0.68), shade(color, 0.85), "Fabric")
	local tail = if longTails then 1.0 else 0.6
	for _, side in { -1, 1 } do
		on(model, head, "BandanaTail", V(0.24, tail, 0.07), CF(side * 0.12, 0.22 - tail / 2, 0.72) * Angles(math.rad(12), 0, side * math.rad(14)), shade(color, 0.92), "Fabric")
	end
end

local function feather(model: any, head: any, offset: any, color: any)
	onEgg(model, head, "Feather", V(0.12, 1.6, 0.36), offset, color, "Fabric")
	onEgg(model, head, "Feather", V(0.1, 1.1, 0.26), offset * CF(0.05, 0.25, 0.12) * Angles(math.rad(-18), 0, 0), shade(color, 0.85), "Fabric")
end

-- Shopkeeper NPC. look fields (all optional except Skin):
--   Skin, Shirt, Pants, Sleeves = "Coat" | "Shirt" | "Rolled", Coat, CoatTrim, LongCoat, Vest, Belt,
--   Buckle, Sash, Boots, Apron, Skirt, Neckerchief, Bandolier,
--   Hat = "Tricorn" | "WideBrim" | "Bandana" | "Headscarf", HatColor, HatTrim, Feather,
--   Hair, HairStyle = "Short" | "Long" | "Bun" | "Ponytail", Beard, BeardStyle = "Full" | "Long" | "Goatee",
--   Mustache, EyePatch, Earring, Parrot, Hook, Cutlass, Prop = "Hammer" | "Mug" | "Ledger" | "Spyglass"
function Rigs.Npc(name: string, look: { [string]: any })
	local skin = look.Skin
	local shirt = look.Shirt or rgb(236, 228, 210)
	local sleeves = look.Sleeves or (if look.Coat then "Coat" else "Shirt")
	local pants = look.Pants or rgb(80, 66, 54)
	local model, r = Rigs.Base({ Name = name, Skin = skin, Torso = shirt, Arms = skin, Legs = pants })
	local torso, head = r.Torso, r.Head

	for _, limb in { r.RightArm, r.LeftArm, r.RightLeg, r.LeftLeg } do
		limb.Transparency = 1
	end

	-- Arms: capsule sleeves, cuffs and round hands ---------------------------------------------------
	local sleeveColor = if sleeves == "Coat" then look.Coat else shirt
	for _, arm in { r.RightArm, r.LeftArm } do
		local isLeft = arm == r.LeftArm
		onBall(model, arm, "Shoulder", 0.92, CF(0, 0.55, 0), sleeveColor, "Fabric")
		if sleeves == "Rolled" then
			onCyl(model, arm, "Sleeve", 0.6, 0.94, CF(0, 0.25, 0), sleeveColor, "Fabric")
			onCyl(model, arm, "SleeveRoll", 0.3, 1.0, CF(0, -0.05, 0), shade(shirt, 0.9), "Fabric")
			onCyl(model, arm, "Forearm", 0.75, 0.74, CF(0, -0.5, 0), skin)
		else
			onCyl(model, arm, "Sleeve", 1.15, 0.92, CF(0, -0.02, 0), sleeveColor, "Fabric")
			if sleeves == "Coat" then
				onCyl(model, arm, "Cuff", 0.42, 1.04, CF(0, -0.5, 0), look.CoatTrim or shade(look.Coat, 0.7), "Fabric")
				onCyl(model, arm, "Ruffle", 0.16, 0.86, CF(0, -0.78, 0), shirt, "Fabric")
			else
				onCyl(model, arm, "Cuff", 0.26, 1.0, CF(0, -0.56, 0), shade(shirt, 0.9), "Fabric")
			end
		end
		if look.Hook and isLeft then
			onCyl(model, arm, "HookCuff", 0.35, 0.8, CF(0, -0.92, 0), rgb(70, 50, 34), "Wood")
			on(model, arm, "Hook", V(0.14, 0.6, 0.14), CF(0, -1.3, 0), rgb(186, 190, 196), "Metal")
			on(model, arm, "Hook", V(0.14, 0.14, 0.45), CF(0, -1.57, -0.17), rgb(186, 190, 196), "Metal")
			on(model, arm, "Hook", V(0.14, 0.32, 0.14), CF(0, -1.45, -0.38), rgb(186, 190, 196), "Metal")
		else
			onEgg(model, arm, "Hand", V(0.66, 0.74, 0.66), CF(0, -0.93, -0.02), skin)
		end
	end

	-- Legs: capsule trousers and boots with round toes, or a tiered skirt ----------------------------------
	local boots = look.Boots or rgb(52, 38, 28)
	for _, leg in { r.RightLeg, r.LeftLeg } do
		if not look.Skirt then
			onCyl(model, leg, "Trousers", 1.3, 0.94, CF(0, 0.38, 0), pants, "Fabric")
			onCyl(model, leg, "BootCuff", 0.3, 1.04, CF(0, -0.22, 0), shade(boots, 1.3), "Fabric")
		end
		onCyl(model, leg, "Boot", 0.72, 0.96, CF(0, -0.6, 0.02), boots, "Fabric")
		onEgg(model, leg, "BootToe", V(0.9, 0.56, 1.25), CF(0, -0.8, -0.3), boots, "Fabric")
		on(model, leg, "Sole", V(0.94, 0.12, 1.3), CF(0, -0.95, -0.22), shade(boots, 0.55), "SmoothPlastic")
	end
	if look.Skirt then
		-- an A-line skirt: four panels hanging from the waist, flaring out a little
		local sk = look.Skirt
		local len = 1.85
		local flare = math.rad(7)
		for _, side in { -1, 1 } do
			local hang = CF(0, -0.85, side * 0.56) * Angles(-side * flare, 0, 0)
			on(model, torso, "Skirt", V(2.16, len, 0.12), hang * CF(0, -len / 2, 0), shade(sk, if side > 0 then 0.92 else 1), "Fabric")
			on(model, torso, "SkirtHem", V(2.2, 0.16, 0.16), hang * CF(0, -len + 0.06, 0), shade(sk, 0.65), "Fabric")
			local sideHang = CF(side * 1.06, -0.85, 0) * Angles(0, 0, side * flare)
			on(model, torso, "Skirt", V(0.12, len, 1.24), sideHang * CF(0, -len / 2, 0), shade(sk, 0.96), "Fabric")
		end
	end

	-- Torso layers ---------------------------------------------------------------------------------
	onCyl(model, torso, "Collar", 0.24, 1.12, CF(0, 1.0, 0), shade(shirt, 0.92), "Fabric")
	if look.Apron then
		if look.Skirt then
			on(model, torso, "Apron", V(1.5, 1.6, 0.06), CF(0, -0.9, -0.66) * Angles(math.rad(7), 0, 0) * CF(0, -0.8, 0), look.Apron, "Fabric")
			on(model, torso, "ApronBand", V(2.2, 0.22, 1.2), CF(0, -0.98, 0), look.Apron, "Fabric")
		else
			on(model, torso, "Apron", V(1.7, 2.7, 0.08), CF(0, -0.55, -0.56), look.Apron, "Fabric")
			on(model, torso, "ApronPocket", V(0.9, 0.55, 0.06), CF(0.2, -0.85, -0.62), shade(look.Apron, 0.78), "Fabric")
			for _, x in { -0.5, 0.5 } do
				on(model, torso, "ApronStrap", V(0.22, 0.5, 0.06), CF(x, 0.78, -0.56) * Angles(0, 0, x * -0.5), shade(look.Apron, 0.85), "Fabric")
			end
		end
	end
	if look.Vest then
		on(model, torso, "Vest", V(2.06, 1.72, 1.07), CF(0, 0.12, 0), look.Vest, "Fabric")
		for _, side in { -1, 1 } do
			onWedge(model, torso, "VestOpening", V(0, 0.98, -0.55), V(side * 0.42, 0, 0), V(0, -0.72, 0), 0.06, shirt, "Fabric")
		end
		for i = 0, 2 do
			onBall(model, torso, "Button", 0.15, CF(0, 0.12 - i * 0.28, -0.56), GOLD, "Metal")
		end
	end
	if look.Coat then
		local coat = look.Coat
		local trim = look.CoatTrim or shade(coat, 0.7)
		local tail = if look.LongCoat then 1.75 else 1.3
		on(model, torso, "Coat", V(2.14, 2.0, 1.13), CF(0, 0.02, 0), coat, "Fabric")
		on(model, torso, "CoatOpening", V(0.82, 1.96, 0.06), CF(0, 0, -0.57), look.Vest or shirt, "Fabric")
		for _, side in { -1, 1 } do
			onWedge(model, torso, "Lapel", V(side * 0.41, 0.98, -0.6), V(side * 0.42, 0, 0), V(0, -0.9, 0), 0.08, trim, "Fabric")
			for i = 0, 2 do
				onBall(model, torso, "CoatButton", 0.14, CF(side * 0.6, -0.25 - i * 0.26, -0.6), GOLD, "Metal")
			end
			-- tails over the legs
			on(model, torso, "CoatTail", V(0.12, tail, 1.1), CF(side * 1.06, -0.95 - tail / 2, 0.02), coat, "Fabric")
			on(model, torso, "CoatTail", V(0.62, tail, 0.12), CF(side * 0.76, -0.95 - tail / 2, -0.58) * Angles(0, 0, side * math.rad(-3)), coat, "Fabric")
			on(model, torso, "CoatHem", V(0.66, 0.16, 0.16), CF(side * 0.78, -0.95 - tail + 0.06, -0.6) * Angles(0, 0, side * math.rad(-3)), trim, "Fabric")
		end
		on(model, torso, "CoatTail", V(2.14, tail, 0.12), CF(0, -0.95 - tail / 2, 0.57) * Angles(math.rad(-4), 0, 0), coat, "Fabric")
		on(model, torso, "CoatCollar", V(2.0, 0.32, 1.17), CF(0, 0.9, 0.02), trim, "Fabric")
	end
	if look.Bandolier then
		on(model, torso, "Bandolier", V(0.36, 2.7, 1.2), CF(0, 0.05, 0) * Angles(0, 0, math.rad(38)), look.Bandolier, "Fabric")
		on(model, torso, "BandolierBuckle", V(0.3, 0.3, 0.08), CF(0.18, 0.2, -0.63) * Angles(0, 0, math.rad(38)), GOLD, "Metal")
	end
	if look.Sash then
		on(model, torso, "Sash", V(2.18, 0.44, 1.18), CF(0, -0.45, 0), look.Sash, "Fabric")
		onEgg(model, torso, "SashKnot", V(0.46, 0.46, 0.26), CF(-0.7, -0.45, -0.6), shade(look.Sash, 0.85), "Fabric")
		on(model, torso, "SashEnd", V(0.3, 1.0, 0.08), CF(-0.74, -1.05, -0.64) * Angles(0, 0, math.rad(-8)), look.Sash, "Fabric")
	end
	local belt = look.Belt or rgb(56, 36, 22)
	on(model, torso, "Belt", V(2.2, 0.34, 1.2), CF(0, -0.8, 0), belt, "Fabric")
	on(model, torso, "Buckle", V(0.56, 0.46, 0.08), CF(0, -0.8, -0.63), look.Buckle or GOLD, "Metal")
	on(model, torso, "BuckleHole", V(0.3, 0.22, 0.06), CF(0, -0.8, -0.66), belt, "Fabric")
	if look.Neckerchief then
		onWedge(model, torso, "Neckerchief", V(0, 0.98, -0.6), V(0.4, 0, 0), V(0, -0.55, 0), 0.08, look.Neckerchief, "Fabric")
		onWedge(model, torso, "Neckerchief", V(0, 0.98, -0.6), V(-0.4, 0, 0), V(0, -0.55, 0), 0.08, look.Neckerchief, "Fabric")
		onCyl(model, torso, "NeckerchiefBand", 0.22, 1.2, CF(0, 0.98, 0), look.Neckerchief, "Fabric")
	end
	if look.Cutlass then
		local hip = CF(-1.14, -1.15, -0.15) * Angles(math.rad(-10), 0, math.rad(-18))
		on(model, torso, "Scabbard", V(0.16, 1.9, 0.36), hip, rgb(50, 34, 24), "Fabric")
		on(model, torso, "ScabbardTip", V(0.2, 0.2, 0.4), hip * CF(0, -0.95, 0), GOLD, "Metal")
		on(model, torso, "SwordGuard", V(0.26, 0.2, 0.7), hip * CF(0, 1.02, 0), GOLD, "Metal")
		on(model, torso, "SwordGrip", V(0.18, 0.55, 0.18), hip * CF(0, 1.38, 0), rgb(40, 28, 20), "Wood")
	end

	-- Head: hair, beard, face details, hat ---------------------------------------------------
	if look.Hair then
		local hair = look.Hair
		onEgg(model, head, "Hair", V(1.32, 1.12, 1.3), CF(0, 0.16, 0.1), hair, "Fabric")
		if look.HairStyle == "Long" then
			onEgg(model, head, "HairLong", V(1.36, 1.9, 0.62), CF(0, -0.55, 0.42), hair, "Fabric")
		elseif look.HairStyle == "Bun" then
			onBall(model, head, "HairBun", 0.7, CF(0, 0.32, 0.7), hair, "Fabric")
		elseif look.HairStyle == "Ponytail" then
			onEgg(model, head, "Ponytail", V(0.42, 1.2, 0.42), CF(0, -0.45, 0.72) * Angles(math.rad(-12), 0, 0), hair, "Fabric")
			onCyl(model, head, "PonytailTie", 0.14, 0.34, CF(0, 0.08, 0.66), rgb(150, 30, 30), "Fabric")
		end
	end
	if look.Beard then
		local beard = look.Beard
		local style = look.BeardStyle or "Full"
		if style == "Goatee" then
			onEgg(model, head, "Beard", V(0.34, 0.44, 0.26), CF(0, -0.68, -0.5) * Angles(math.rad(-15), 0, 0), beard, "Fabric")
		else
			onEgg(model, head, "Beard", V(1.28, 0.86, 0.9), CF(0, -0.42, -0.2), beard, "Fabric")
			if style == "Long" then
				onEgg(model, head, "BeardTip", V(0.95, 1.1, 0.62), CF(0, -0.9, -0.34) * Angles(math.rad(-10), 0, 0), beard, "Fabric")
			end
		end
	end
	if look.Mustache then
		for _, side in { -1, 1 } do
			onEgg(model, head, "Mustache", V(0.52, 0.18, 0.18), CF(side * 0.24, -0.2, -0.6) * Angles(0, 0, side * math.rad(-18)), look.Mustache, "Fabric")
		end
	end
	if look.EyePatch then
		onEgg(model, head, "EyePatch", V(0.36, 0.32, 0.1), CF(0.22, 0.1, -0.62), rgb(18, 16, 16), "Fabric")
		onCyl(model, head, "EyePatchStrap", 0.07, 1.27, CF(0, 0.2, 0) * Angles(0, 0, math.rad(-20)), rgb(18, 16, 16), "Fabric")
	end
	if look.Earring then
		onCyl(model, head, "Earring", 0.06, 0.28, CF(-0.64, -0.36, 0.04) * Angles(0, 0, math.pi / 2), GOLD, "Metal")
		if look.Earring == "Both" then
			onCyl(model, head, "Earring", 0.06, 0.28, CF(0.64, -0.36, 0.04) * Angles(0, 0, math.pi / 2), GOLD, "Metal")
		end
	end
	local hatColor = look.HatColor or rgb(36, 30, 30)
	if look.Hat == "Tricorn" then
		bigTricorn(model, head, hatColor, look.HatTrim)
	elseif look.Hat == "WideBrim" then
		wideBrim(model, head, hatColor, look.HatTrim)
	elseif look.Hat == "Bandana" or look.Hat == "Headscarf" then
		bandana(model, head, hatColor, look.Hat == "Headscarf")
	end
	if look.Feather then
		feather(model, head, CF(0.6, 1.05, 0.3) * Angles(math.rad(14), 0, math.rad(-38)), look.Feather)
	end

	-- Parrot on the left shoulder ------------------------------------------------------------------
	if look.Parrot then
		local base = CF(-1.5, 1.05, 0.08)
		local red, blue, yellow = rgb(214, 44, 36), rgb(40, 96, 200), rgb(250, 200, 40)
		onEgg(model, torso, "ParrotBody", V(0.5, 0.85, 0.6), base * CF(0, 0.45, 0.05) * Angles(math.rad(-14), 0, 0), red)
		onBall(model, torso, "ParrotHead", 0.48, base * CF(0, 0.98, -0.08), red)
		onEgg(model, torso, "ParrotBeak", V(0.18, 0.28, 0.3), base * CF(0, 0.92, -0.36) * Angles(math.rad(25), 0, 0), yellow)
		onBall(model, torso, "ParrotEye", 0.1, base * CF(0.2, 1.04, -0.2), rgb(15, 15, 15))
		onBall(model, torso, "ParrotEye", 0.1, base * CF(-0.2, 1.04, -0.2), rgb(15, 15, 15))
		for _, side in { -1, 1 } do
			onEgg(model, torso, "ParrotWing", V(0.14, 0.7, 0.5), base * CF(side * 0.27, 0.4, 0.1) * Angles(math.rad(-14), 0, 0), blue)
		end
		on(model, torso, "ParrotTail", V(0.24, 0.95, 0.1), base * CF(0, -0.05, 0.42) * Angles(math.rad(-28), 0, 0), blue)
		on(model, torso, "ParrotTail", V(0.16, 0.7, 0.08), base * CF(0, 0.0, 0.48) * Angles(math.rad(-34), 0, 0), yellow)
	end

	-- Something in the right hand ---------------------------------------------------------------------
	local hand = r.RightArm
	if look.Prop == "Hammer" then
		on(model, hand, "HammerHandle", V(0.18, 0.18, 1.6), CF(0, -0.95, -0.5), rgb(150, 100, 56), "Wood")
		on(model, hand, "HammerHead", V(0.34, 0.34, 0.8), CF(0, -0.95, -1.25) * Angles(math.pi / 2, 0, 0), rgb(70, 70, 76), "Metal")
	elseif look.Prop == "Mug" then
		onCyl(model, hand, "Mug", 0.8, 0.62, CF(0, -1.0, -0.45), rgb(150, 104, 60), "Wood")
		onCyl(model, hand, "MugFoam", 0.12, 0.58, CF(0, -0.58, -0.45), rgb(250, 244, 226), "SmoothPlastic")
		onCyl(model, hand, "MugBand", 0.1, 0.66, CF(0, -1.2, -0.45), rgb(70, 66, 70), "Metal")
	elseif look.Prop == "Ledger" then
		on(model, hand, "Ledger", V(0.3, 1.1, 0.85), CF(0, -1.05, -0.35), rgb(120, 40, 40), "Fabric")
		on(model, hand, "LedgerPages", V(0.32, 1.0, 0.75), CF(0.02, -1.05, -0.36), rgb(236, 224, 190), "SmoothPlastic")
	elseif look.Prop == "Spyglass" then
		onCyl(model, hand, "Spyglass", 1.4, 0.3, CF(0, -0.95, -0.55) * Angles(math.pi / 2, 0, 0), BRASS, "Metal")
		onCyl(model, hand, "SpyglassGrip", 0.6, 0.36, CF(0, -0.95, -0.1) * Angles(math.pi / 2, 0, 0), rgb(60, 40, 28), "Fabric")
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
