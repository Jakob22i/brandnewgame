-- Outpost kit: the building blocks of a Sea of Thieves-style wooden pirate outpost.
-- Clapboard plank walls, shingle and thatch roofs, stilts, decks, stairs, railings and
-- props (lanterns, barrels, crates, sacks, rope, nets, bunting, flags, carved signs...).
--
-- Everything is built in local space: callers pass CFrames relative to their own model
-- and move the finished model once with P.transform (Lune has no PivotTo).
local P = require("./Parts")

local V = P.Vector3.new
local CF = P.CFrame.new
local Angles = P.CFrame.Angles
local fromMatrix = P.CFrame.fromMatrix
local rgb = P.rgb
local Color3 = P.Color3

local O = {}

-- Deterministic random numbers (Lune has no Random) --------------------------------
local state = 1
function O.Seed(n: number)
	state = math.floor(n) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
end
function O.Rand(): number
	state = (state * 16807) % 2147483647
	return state / 2147483647
end
function O.Range(a: number, b: number): number
	return a + (b - a) * O.Rand()
end
function O.Pick(list: { any }): any
	return list[math.floor(O.Rand() * #list) + 1]
end

-- Colours ----------------------------------------------------------------------------
function O.Shade(c: any, f: number)
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end
function O.Jitter(c: any, amount: number?)
	return O.Shade(c, 1 + O.Range(-(amount or 0.07), amount or 0.07))
end

O.WOOD = { rgb(142, 104, 70), rgb(128, 92, 60), rgb(156, 116, 78), rgb(118, 86, 58), rgb(136, 100, 66), rgb(150, 110, 72) }
O.DRIFT = { rgb(140, 124, 106), rgb(126, 112, 98), rgb(152, 134, 112), rgb(116, 104, 92), rgb(134, 116, 96) }
O.TEAL = { rgb(72, 120, 124), rgb(62, 108, 114), rgb(84, 132, 132), rgb(58, 100, 106), rgb(78, 126, 126) }
O.RUST = { rgb(150, 72, 52), rgb(136, 62, 46), rgb(162, 82, 58), rgb(128, 60, 46) }
O.HONEY = { rgb(170, 124, 74), rgb(158, 112, 66), rgb(182, 134, 82), rgb(150, 106, 64) }
O.STRAW = { rgb(190, 150, 84), rgb(174, 134, 72), rgb(202, 162, 94), rgb(162, 124, 66), rgb(184, 140, 76) }
O.SHINGLE = { rgb(104, 80, 62), rgb(92, 70, 54), rgb(116, 90, 68), rgb(84, 64, 50) }
O.SLATE = { rgb(82, 88, 98), rgb(72, 78, 88), rgb(92, 96, 104), rgb(66, 70, 80) }
O.TEAL_ROOF = { rgb(64, 110, 112), rgb(56, 98, 102), rgb(74, 120, 118), rgb(50, 90, 96) }
O.RED_ROOF = { rgb(150, 70, 52), rgb(136, 60, 46), rgb(164, 82, 60), rgb(124, 56, 44) }

O.DARK = rgb(74, 52, 36)
O.DARKER = rgb(48, 34, 24)
O.IRON = rgb(50, 48, 52)
O.BRASS = rgb(204, 160, 74)
O.GOLD = rgb(255, 204, 72)
O.ROPE = rgb(196, 168, 118)
O.CANVAS = rgb(230, 218, 188)
O.BURLAP = rgb(176, 146, 100)
O.GLOW = rgb(255, 178, 92)
O.LIGHT = rgb(255, 190, 120)

-- Part shortcuts ------------------------------------------------------------------------
local function merge(a: { [string]: any }, b: { [string]: any }?)
	if b then
		for k, v in b do
			a[k] = v
		end
	end
	return a
end

-- Box part. extra: any part properties (CanCollide, Transparency, Shape, Class...)
local function part(parent: any, name: string, size: any, cf: any, color: any, mat: string?, extra: { [string]: any }?)
	return P.part(parent, merge({ Name = name, Size = size, CFrame = cf, Color = color, Mat = mat or "SmoothPlastic" }, extra))
end
O.Part = part

local UPRIGHT = Angles(0, 0, math.pi / 2) -- turns a cylinder's X axis up
local ALONG_Z = Angles(0, math.pi / 2, 0) -- turns a cylinder's X axis along Z

-- Cylinder centred at cf whose axis is cf's Y axis
local function cyl(parent: any, name: string, cf: any, length: number, diameter: number, color: any, mat: string?, extra: { [string]: any }?)
	return part(parent, name, V(length, diameter, diameter), cf * UPRIGHT, color, mat, merge({ Shape = "Cylinder" }, extra))
end
O.Cyl = cyl

-- Cylinder centred at cf whose axis is cf's Z axis
local function cylZ(parent: any, name: string, cf: any, length: number, diameter: number, color: any, mat: string?, extra: { [string]: any }?)
	return part(parent, name, V(length, diameter, diameter), cf * ALONG_Z, color, mat, merge({ Shape = "Cylinder" }, extra))
end
O.CylZ = cylZ

local function ball(parent: any, name: string, pos: any, d: number, color: any, mat: string?, extra: { [string]: any }?)
	return part(parent, name, V(d, d, d), CF(pos), color, mat, merge({ Shape = "Ball" }, extra))
end
O.Ball = ball

-- Block between two points (a and b are local Vector3s)
local function stick(parent: any, name: string, a: any, b: any, w: number, h: number, color: any, mat: string?, extra: { [string]: any }?)
	return P.plank(parent, a, b, w, h, merge({ Name = name, Color = color, Mat = mat or "Wood" }, extra))
end
O.Stick = stick

-- Cylinder between two points
local function rod(parent: any, name: string, a: any, b: any, d: number, color: any, mat: string?, extra: { [string]: any }?)
	return P.beam(parent, a, b, d, merge({ Name = name, Color = color, Mat = mat or "Wood" }, extra))
end
O.Rod = rod

-- Wedge filling the right triangle with corners at the frame origin `corner`, `corner + a` and
-- `corner + b` (a and b perpendicular), `thick` studs thick along a x b.
local function triangle(parent: any, name: string, corner: any, a: any, b: any, thick: number, color: any, mat: string?, extra: { [string]: any }?)
	-- WedgePart: right angle at local (y = -1/2, z = +1/2); the legs run along -Z and +Y
	local la, lb = a.Magnitude, b.Magnitude
	local vZ = -a.Unit
	local vY = b.Unit
	local vX = vY:Cross(vZ)
	local centre = corner + a / 2 + b / 2
	return part(parent, name, V(thick, lb, la), fromMatrix(centre, vX, vY, vZ), color, mat, merge({ Class = "WedgePart" }, extra))
end
O.Triangle = triangle

-- Walls ------------------------------------------------------------------------------------

-- x intervals of the band [y0, y1] that are not covered by any hole {x0, x1, y0, y1}
local function freeSegments(half: number, holes: { any }, y0: number, y1: number)
	local segs = { { -half, half } }
	for _, h in holes do
		if h[3] < y1 - 0.01 and h[4] > y0 + 0.01 then
			local out = {}
			for _, s in segs do
				if h[2] <= s[1] or h[1] >= s[2] then
					table.insert(out, s)
				else
					if h[1] > s[1] then
						table.insert(out, { s[1], h[1] })
					end
					if h[2] < s[2] then
						table.insert(out, { h[2], s[2] })
					end
				end
			end
			segs = out
		end
	end
	return segs
end

-- Horizontal clapboard wall. cf: bottom centre of the wall's outer face (+X along the wall,
-- +Y up, +Z out of the building). opts: Holes = {{x0, x1, y0, y1}}, Colors, PlankH,
-- Back (colour of the solid backing), Depth (backing thickness), MaxLen (plank length)
function O.PlankWall(parent: any, cf: any, length: number, height: number, opts: { [string]: any }?)
	local o = opts or {}
	local colors = o.Colors or O.WOOD
	local holes = o.Holes or {}
	local half = length / 2
	local depth = o.Depth or 0.6
	local back = o.Back or O.DARKER
	local maxLen = o.MaxLen or 28
	-- solid backing in bands between the hole edges (collision, no see-through gaps).
	-- SolidBack: one backing part for the whole wall (doors and windows are only on the outside)
	local backHoles = if o.SolidBack then {} else holes
	local ys = { 0, height }
	for _, h in backHoles do
		table.insert(ys, math.clamp(h[3], 0, height))
		table.insert(ys, math.clamp(h[4], 0, height))
	end
	table.sort(ys)
	for i = 1, #ys - 1 do
		local y0, y1 = ys[i], ys[i + 1]
		if y1 - y0 > 0.05 then
			for _, s in freeSegments(half, backHoles, y0, y1) do
				if s[2] - s[1] > 0.05 then
					part(parent, "Wall", V(s[2] - s[1], y1 - y0, depth), cf * CF((s[1] + s[2]) / 2, (y0 + y1) / 2, -depth / 2), back, "WoodPlanks")
				end
			end
		end
	end
	-- overlapping planks, bottom edge kicked out a little
	local rows = math.max(1, math.floor(height / (o.PlankH or 1.2) + 0.5))
	local rh = height / rows
	for r = 0, rows - 1 do
		local y0, y1 = r * rh, (r + 1) * rh
		for _, s in freeSegments(half, holes, y0 + 0.05, y1 - 0.05) do
			local w = s[2] - s[1]
			if w > 0.25 then
				local pieces = math.max(1, math.ceil(w / maxLen))
				local cuts = { s[1] }
				for k = 1, pieces - 1 do
					table.insert(cuts, s[1] + w * (k + O.Range(-0.25, 0.25)) / pieces)
				end
				table.insert(cuts, s[2])
				for k = 1, pieces do
					local a, b = cuts[k], cuts[k + 1]
					local gap = if k < pieces then 0.08 else 0
					part(parent, "Plank", V(b - a - gap, rh + 0.1, 0.24), cf * CF((a + b - gap) / 2, (y0 + y1) / 2 + 0.03, 0.14) * Angles(math.rad(-3.5), 0, 0), O.Jitter(O.Pick(colors), 0.06), "WoodPlanks", { CanCollide = false })
				end
			end
		end
	end
end

-- Triangular gable end (base along X at y = 0, apex at (0, rise)). cf as for PlankWall.
function O.GableWall(parent: any, cf: any, base: number, rise: number, opts: { [string]: any }?)
	local o = opts or {}
	local colors = o.Colors or O.WOOD
	local depth = o.Depth or 0.6
	local back = O.Shade(colors[1], 0.82)
	local half = base / 2
	for _, side in { -1, 1 } do
		triangle(parent, "Gable", (cf * CF(0, 0, -depth / 2)).Position, cf:VectorToWorldSpace(V(side * half, 0, 0)), cf:VectorToWorldSpace(V(0, rise, 0)), depth, back, "WoodPlanks")
	end
	local rows = math.max(1, math.floor(rise / (o.PlankH or 1.2) + 0.5))
	local rh = rise / rows
	for r = 0, rows - 1 do
		local yc = (r + 0.5) * rh
		local w = base * (1 - (r + 1) * rh / rise) - 0.1
		if w > 0.4 then
			part(parent, "Plank", V(w, rh + 0.1, 0.24), cf * CF(0, yc + 0.03, 0.14) * Angles(math.rad(-3.5), 0, 0), O.Jitter(O.Pick(colors), 0.06), "WoodPlanks", { CanCollide = false })
		end
	end
end

-- Vertical board-and-batten wall (used for doors, shutters, sheds). cf as for PlankWall.
function O.BoardPanel(parent: any, cf: any, width: number, height: number, colors: { any }?, boardW: number?)
	local bw = boardW or 0.9
	local n = math.max(1, math.floor(width / bw + 0.5))
	local w = width / n
	for i = 0, n - 1 do
		local x = -width / 2 + (i + 0.5) * w
		local h = height - O.Range(0, 0.15)
		part(parent, "Board", V(w - 0.06, h, 0.22), cf * CF(x, h / 2, 0.11), O.Jitter(O.Pick(colors or O.WOOD), 0.07), "WoodPlanks")
	end
	for _, y in { height * 0.22, height * 0.78 } do
		part(parent, "Batten", V(width - 0.2, 0.4, 0.18), cf * CF(0, y, 0.3), O.DARK, "Wood")
	end
end

-- Door with frame, planks, iron hinges and a ring handle. cf: bottom centre of the outer face.
function O.Door(parent: any, cf: any, w: number, h: number, colors: { any }?)
	O.BoardPanel(parent, cf * CF(0, 0, 0.02), w, h, colors or O.SHINGLE, 0.75)
	for _, x in { -w / 2 - 0.25, w / 2 + 0.25 } do
		part(parent, "DoorFrame", V(0.5, h + 0.3, 0.5), cf * CF(x, (h + 0.3) / 2, 0.2), O.DARK, "Wood")
	end
	part(parent, "DoorFrame", V(w + 1.2, 0.5, 0.55), cf * CF(0, h + 0.3, 0.22), O.DARK, "Wood")
	for _, y in { h * 0.22, h * 0.78 } do
		part(parent, "Hinge", V(w * 0.55, 0.22, 0.1), cf * CF(-w * 0.2, y, 0.42), O.IRON, "Metal")
	end
	cylZ(parent, "Handle", cf * CF(w * 0.3, h * 0.5, 0.42), 0.08, 0.45, O.IRON, "Metal")
end

-- Window with frame, cross bars, a warm glass pane and two open shutters. cf: centre of the opening on the outer face.
function O.Window(parent: any, cf: any, w: number, h: number, shutter: any?)
	part(parent, "WindowGlass", V(w, h, 0.1), cf * CF(0, 0, -0.25), rgb(255, 214, 150), "Glass", { Transparency = 0.3 })
	for _, x in { -w / 2 - 0.2, w / 2 + 0.2 } do
		part(parent, "WindowFrame", V(0.4, h + 0.4, 0.45), cf * CF(x, 0, 0.12), O.DARK, "Wood")
	end
	part(parent, "WindowFrame", V(w + 0.8, 0.4, 0.45), cf * CF(0, h / 2 + 0.2, 0.12), O.DARK, "Wood")
	part(parent, "Sill", V(w + 1.2, 0.35, 0.8), cf * CF(0, -h / 2 - 0.15, 0.3), O.DARK, "Wood")
	part(parent, "WindowBar", V(0.15, h, 0.15), cf * CF(0, 0, -0.15), O.DARK, "Wood")
	part(parent, "WindowBar", V(w, 0.15, 0.15), cf * CF(0, 0, -0.15), O.DARK, "Wood")
	if shutter then
		for _, side in { -1, 1 } do
			local hinge = cf * CF(side * (w / 2 + 0.4), 0, 0.3) * Angles(0, side * math.rad(-28), 0)
			local panel = hinge * CF(side * w / 4, 0, 0)
			part(parent, "Shutter", V(w / 2, h + 0.2, 0.18), panel, O.Jitter(shutter, 0.05), "WoodPlanks", { CanCollide = false })
		end
	end
end

-- Roofs ----------------------------------------------------------------------------------------

-- Gable roof. cf: centre of the building at wall-top height; the ridge runs along local Z.
-- W = width across the ridge, D = length along it.
-- opts: Style = "Shingle" | "Thatch", Rise, Over (eave overhang), Front / Back (overhang past
-- +D/2 / -D/2), Colors, Edge (barge board colour). Returns the ridge height above cf.
function O.Roof(parent: any, cf: any, W: number, D: number, opts: { [string]: any }?)
	local o = opts or {}
	local thatch = o.Style == "Thatch"
	local colors = o.Colors or (if thatch then O.STRAW else O.SHINGLE)
	local half = W / 2
	local rise = o.Rise or half * 0.85
	local over = o.Over or (if thatch then 2.2 else 1.6)
	local zFront = D / 2 + (o.Front or 1.4)
	local zBack = -D / 2 - (o.Back or 1.4)
	local len = zFront - zBack
	local zc = (zFront + zBack) / 2
	local theta = math.atan2(rise, half)
	local c, s = math.cos(theta), math.sin(theta)
	local slopeLen = (half + over) / c
	local thick = if thatch then 0.7 else 0.45
	local rowW = if thatch then 2.4 else 1.75
	local step = if thatch then 1.45 else 1.3
	local rowT = if thatch then 0.85 else 0.32
	local tilt = math.rad(if thatch then 10 else 4.5)
	local edge = o.Edge or O.DARK
	for _, side in { -1, 1 } do
		local xA = V(side * c, -s, 0) -- down the slope
		local yA = V(side * s, c, 0) -- out of the roof
		local zA = xA:Cross(yA)
		local function frame(u: number, lift: number, z: number?)
			return cf * fromMatrix(V(0, rise, zc + (z or 0)) + xA * u + yA * lift, xA, yA, zA)
		end
		part(parent, "Roof", V(slopeLen, thick, len), frame(slopeLen / 2, thick / 2), if thatch then O.Shade(colors[2], 0.62) else rgb(86, 62, 44), if thatch then "Grass" else "WoodPlanks")
		-- rows of shingles / thatch bundles from the eave up to the ridge
		if thatch then
			-- thatch: rounded straw bundles (cylinders) lying along the roof, overlapping a little
			local d = 1.7
			local stepT = 1.32
			local rows = math.ceil((slopeLen - 0.5) / stepT)
			for k = 0, rows - 1 do
				local u = math.max(d * 0.42, slopeLen - d * 0.55 - k * stepT)
				local segs = if len > 20 then 2 else 1
				local zs = { -len / 2 - 0.2 }
				if segs == 2 then
					table.insert(zs, -len / 2 + len * (1 + O.Range(-0.3, 0.3)) / 2)
				end
				table.insert(zs, len / 2 + 0.2)
				for i = 1, segs do
					local z0, z1 = zs[i], zs[i + 1]
					local gap = if i < segs then 0.05 else 0
					local wob = Angles(O.Range(-0.015, 0.015), O.Range(-0.02, 0.02), 0)
					cylZ(parent, "Thatch", frame(u + O.Range(-0.2, 0.2), thick + d * 0.18 + O.Range(-0.08, 0.08), (z0 + z1 - gap) / 2) * wob, z1 - z0 - gap, d * O.Range(0.9, 1.1), O.Jitter(O.Pick(colors), 0.08), "Grass", { CanCollide = false })
				end
			end
		else
			local rows = math.ceil((slopeLen - 0.3) / step)
			for k = 0, rows - 1 do
				local u = math.max(rowW / 2, slopeLen - rowW / 2 - k * step)
				local lift = thick + rowT / 2 - 0.05 + rowW / 2 * math.sin(tilt) * 0.6
				local segs = 2
				local zs = { -len / 2 - 0.15 }
				for i = 1, segs - 1 do
					table.insert(zs, -len / 2 + len * (i + O.Range(-0.3, 0.3)) / segs)
				end
				table.insert(zs, len / 2 + 0.15)
				for i = 1, segs do
					local z0, z1 = zs[i], zs[i + 1]
					local gap = if i < segs then 0.12 else 0
					part(parent, "Shingles", V(rowW, rowT, z1 - z0 - gap), frame(u, lift, (z0 + z1 - gap) / 2) * Angles(0, 0, tilt), O.Jitter(O.Pick(colors), 0.08), "WoodPlanks", { CanCollide = false })
				end
			end
		end
		if thatch then
			-- thick rounded eave and gable edges
			cylZ(parent, "ThatchEave", frame(slopeLen - 0.35, thick + 0.3), len + 0.5, 1.95, O.Shade(colors[2], 0.95), "Grass", { CanCollide = false })
			for _, z in { zBack - 0.1, zFront + 0.1 } do
				rod(parent, "ThatchEdge", (frame(0.2, thick + 0.4, z - zc)).Position, (frame(slopeLen - 0.4, thick + 0.4, z - zc)).Position, 1.45, O.Shade(colors[2], 0.9), "Grass", { CanCollide = false })
			end
		else
			part(parent, "Fascia", V(0.35, 0.9, len + 0.3), frame(slopeLen + 0.05, thick / 2), edge, "Wood", { CanCollide = false })
			for _, z in { zBack - 0.15, zFront + 0.15 } do
				local a = (frame(0, thick + 0.15, z - zc)).Position
				local b = (frame(slopeLen + 0.2, thick + 0.15, z - zc)).Position
				stick(parent, "BargeBoard", a, b, 0.4, 1.05, edge, "Wood", { CanCollide = false })
			end
		end
	end
	-- ridge cap
	local ridgeY = rise + thick / c
	if thatch then
		cylZ(parent, "ThatchRidge", cf * CF(0, ridgeY + 0.1, zc), len + 0.8, 1.9, O.Shade(colors[1], 0.85), "Grass", { CanCollide = false })
	else
		part(parent, "Ridge", V(0.95, 0.95, len + 0.5), cf * CF(0, ridgeY - 0.05, zc) * Angles(0, 0, math.pi / 4), edge, "Wood", { CanCollide = false })
	end
	return ridgeY
end

-- Lean-to roof sloping down towards +Z. cf: centre of the high edge; covers w (X) by d (Z).
function O.LeanTo(parent: any, cf: any, w: number, d: number, drop: number, colors: { any }?, thatch: boolean?)
	local cols = colors or O.SHINGLE
	local slope = math.sqrt(d * d + drop * drop)
	local frame = cf * P.lookAt(V(0, 0, 0), V(0, -drop, d))
	-- lookAt: -Z points down the slope; the part's long side follows it
	part(parent, "Roof", V(w, 0.4, slope), frame * CF(0, 0, -slope / 2), O.Shade(cols[1], 0.7), if thatch then "Grass" else "WoodPlanks")
	local step = if thatch then 1.6 else 1.25
	local rowW = if thatch then 2.2 else 1.6
	local rows = math.ceil(slope / step)
	for k = 0, rows - 1 do
		local u = math.max(rowW / 2, slope - rowW / 2 - k * step)
		if thatch then
			part(parent, "Thatch", V(w + 0.3, 1.5, 1.5), frame * CF(0, 0.45, -u), O.Jitter(O.Pick(cols), 0.08), "Grass", { CanCollide = false, Shape = "Cylinder" })
		else
			part(parent, "Shingles", V(w + 0.3, 0.3, rowW), frame * CF(0, 0.35, -u) * Angles(math.rad(4), 0, 0), O.Jitter(O.Pick(cols), 0.08), "WoodPlanks", { CanCollide = false })
		end
	end
end

-- Structure ---------------------------------------------------------------------------------------

-- Posts under a raised floor, rim beams and cross braces.
-- ground(x, z) returns the local ground height under (x, z); floorY = underside of the floor.
function O.Stilts(parent: any, x0: number, x1: number, z0: number, z1: number, floorY: number, ground: (number, number) -> number, opts: { [string]: any }?)
	local o = opts or {}
	local spacing = o.Spacing or 6.5
	local d = o.Diameter or 1.1
	local color = o.Color or rgb(98, 72, 50)
	local nx = math.max(1, math.ceil((x1 - x0) / spacing))
	local nz = math.max(1, math.ceil((z1 - z0) / spacing))
	local points = {}
	for i = 0, nx do
		table.insert(points, { x0 + (x1 - x0) * i / nx, z0 })
		table.insert(points, { x0 + (x1 - x0) * i / nx, z1 })
	end
	for j = 1, nz - 1 do
		table.insert(points, { x0, z0 + (z1 - z0) * j / nz })
		table.insert(points, { x1, z0 + (z1 - z0) * j / nz })
	end
	for _, p in points do
		local g = ground(p[1], p[2])
		P.pillar(parent, p[1], p[2], g - 2, floorY, d, { Name = "Stilt", Mat = "Wood", Color = O.Jitter(color, 0.06) })
		P.pillar(parent, p[1], p[2], g - 0.3, g + 0.35, d + 0.35, { Name = "Footing", Mat = "Slate", Color = rgb(120, 116, 108) })
	end
	-- rim beams
	local rimY = floorY - 0.45
	part(parent, "Rim", V(x1 - x0 + 0.6, 0.9, 0.7), CF((x0 + x1) / 2, rimY, z0), O.DARK, "Wood")
	part(parent, "Rim", V(x1 - x0 + 0.6, 0.9, 0.7), CF((x0 + x1) / 2, rimY, z1), O.DARK, "Wood")
	part(parent, "Rim", V(0.7, 0.9, z1 - z0), CF(x0, rimY, (z0 + z1) / 2), O.DARK, "Wood")
	part(parent, "Rim", V(0.7, 0.9, z1 - z0), CF(x1, rimY, (z0 + z1) / 2), O.DARK, "Wood")
	-- braces between neighbouring posts (alternating directions)
	if o.Braces ~= false then
		local function brace(ax: number, az: number, bx: number, bz: number, flip: boolean)
			local ga = ground(ax, az)
			local gb = ground(bx, bz)
			if floorY - math.max(ga, gb) < 1.6 then
				return
			end
			local top = floorY - 0.9
			local a = if flip then V(ax, top, az) else V(ax, math.max(ga, gb) + 0.5, az)
			local b = if flip then V(bx, math.max(ga, gb) + 0.5, bz) else V(bx, top, bz)
			stick(parent, "Brace", a, b, 0.35, 0.5, O.Jitter(color, 0.08), "Wood", { CanCollide = false })
		end
		for i = 0, nx - 1 do
			local xa, xb = x0 + (x1 - x0) * i / nx, x0 + (x1 - x0) * (i + 1) / nx
			if not o.NoBackBraces then
				brace(xa, z0 - 0.1, xb, z0 - 0.1, i % 2 == 0)
			end
			brace(xa, z1 + 0.1, xb, z1 + 0.1, i % 2 == 1)
		end
		for j = 0, nz - 1 do
			local za, zb = z0 + (z1 - z0) * j / nz, z0 + (z1 - z0) * (j + 1) / nz
			brace(x0 - 0.1, za, x0 - 0.1, zb, j % 2 == 0)
			brace(x1 + 0.1, za, x1 + 0.1, zb, j % 2 == 1)
		end
	end
end

-- Plank deck between x0..x1, z0..z1 with its top at y. Planks run along X unless opts.AlongZ.
function O.Deck(parent: any, x0: number, x1: number, z0: number, z1: number, y: number, opts: { [string]: any }?)
	local o = opts or {}
	local colors = o.Colors or O.WOOD
	part(parent, "DeckBase", V(x1 - x0, 0.5, z1 - z0), CF((x0 + x1) / 2, y - 0.45, (z0 + z1) / 2), O.DARKER, "Wood")
	local alongZ = o.AlongZ == true
	local across = if alongZ then x1 - x0 else z1 - z0
	local long = if alongZ then z1 - z0 else x1 - x0
	local pw = o.PlankW or 1.1
	local n = math.max(1, math.floor(across / pw + 0.5))
	local w = across / n
	local maxLen = o.MaxLen or 14
	for i = 0, n - 1 do
		local a = (if alongZ then x0 else z0) + (i + 0.5) * w
		local pieces = math.max(1, math.ceil(long / maxLen))
		local start = if alongZ then z0 else x0
		local cuts = { start }
		for k = 1, pieces - 1 do
			table.insert(cuts, start + long * (k + O.Range(-0.3, 0.3)) / pieces)
		end
		table.insert(cuts, start + long)
		for k = 1, pieces do
			local l0, l1 = cuts[k], cuts[k + 1] - (if k < pieces then 0.1 else 0)
			local sink = O.Range(0, 0.04)
			local size = if alongZ then V(w - 0.1, 0.26, l1 - l0) else V(l1 - l0, 0.26, w - 0.1)
			local pos = if alongZ then V(a, y - 0.13 - sink, (l0 + l1) / 2) else V((l0 + l1) / 2, y - 0.13 - sink, a)
			part(parent, "DeckPlank", size, CF(pos), O.Jitter(O.Pick(colors), 0.07), "WoodPlanks")
		end
	end
end

-- Steps from a deck edge down to the ground. cf: top centre of the deck edge; the stairs go
-- down towards +Z. A hidden wedge ramp (through the tread nosings) makes walking up smooth.
-- Returns the horizontal length of the stairs.
function O.Stairs(parent: any, cf: any, width: number, rise: number, opts: { [string]: any }?)
	local o = opts or {}
	local n = math.max(1, math.ceil(rise / 0.7) - 1) -- treads
	local h = rise / (n + 1)
	local run = o.Run or 1.2
	local total = (n + 1) * run
	local colors = o.Colors or O.WOOD
	for i = 1, n do
		part(parent, "Step", V(width, 0.3, run + 0.2), cf * CF(0, -i * h - 0.15, (i - 0.5) * run), O.Jitter(O.Pick(colors), 0.07), "WoodPlanks", { CanCollide = false })
		part(parent, "Riser", V(width - 0.2, h, 0.12), cf * CF(0, -i * h + h / 2 - 0.1, (i - 1) * run + 0.05), O.DARKER, "Wood", { CanCollide = false })
	end
	for _, side in { -1, 1 } do
		stick(parent, "Stringer", (cf * CF(side * (width / 2 + 0.2), -0.35, -0.1)).Position, (cf * CF(side * (width / 2 + 0.2), -rise - 0.2, total + 0.1)).Position, 0.4, 1.0, O.DARK, "Wood", { CanCollide = false })
	end
	-- the walkable ramp (high side at the deck)
	part(parent, "StairRamp", V(width, rise, total), cf * CF(0, -rise / 2, total / 2) * Angles(0, math.pi, 0), O.DARK, "SmoothPlastic", { Class = "WedgePart", Transparency = 1 })
	return total
end

-- Wooden railing along a deck edge from a to b (deck surface points).
function O.Railing(parent: any, a: any, b: any, opts: { [string]: any }?)
	local o = opts or {}
	local h = o.Height or 3
	local color = o.Color or O.DARK
	local dir = b - a
	local len = dir.Magnitude
	local n = math.max(1, math.ceil(len / (o.Spacing or 4)))
	for i = 0, n do
		local p = a + dir * (i / n)
		part(parent, "RailPost", V(0.45, h, 0.45), CF(p.X, p.Y + h / 2, p.Z), O.Jitter(color, 0.06), "Wood")
	end
	local up = V(0, h - 0.15, 0)
	stick(parent, "Rail", a + up, b + up, 0.4, 0.35, color, "Wood")
	if o.Rope then
		for i = 0, n - 1 do
			local p0 = a + dir * (i / n) + V(0, h * 0.5, 0)
			local p1 = a + dir * ((i + 1) / n) + V(0, h * 0.5, 0)
			local mid = (p0 + p1) / 2 - V(0, 0.35, 0)
			rod(parent, "Rope", p0, mid, 0.16, O.ROPE, "Fabric", { CanCollide = false })
			rod(parent, "Rope", mid, p1, 0.16, O.ROPE, "Fabric", { CanCollide = false })
		end
	else
		stick(parent, "Rail", a + V(0, h * 0.45, 0), b + V(0, h * 0.45, 0), 0.25, 0.3, color, "Wood", { CanCollide = false })
	end
end

-- Props ----------------------------------------------------------------------------------------------

-- Hanging lantern. cf: the hook point (the lantern hangs below it). Returns the glowing part.
-- Six parts: chain, cap, glass, two crossed cage plates (they read as four corner bars), base.
function O.Lantern(parent: any, cf: any, opts: { [string]: any }?)
	local o = opts or {}
	local s = o.Scale or 1
	local nc = { CanCollide = false, CanQuery = false }
	part(parent, "LanternChain", V(0.1 * s, 0.6 * s, 0.1 * s), cf * CF(0, -0.3 * s, 0), O.IRON, "Metal", nc)
	cyl(parent, "LanternCap", cf * CF(0, -0.7 * s, 0), 0.36 * s, 0.84 * s, O.IRON, "Metal", nc)
	local glow = cyl(parent, "LanternGlow", cf * CF(0, -1.2 * s, 0), 0.72 * s, 0.6 * s, o.Color or O.GLOW, "Neon", { CanCollide = false, CanQuery = false, Transparency = 0.05 })
	part(parent, "LanternBar", V(0.7 * s, 0.76 * s, 0.08 * s), cf * CF(0, -1.2 * s, 0), O.IRON, "Metal", nc)
	cyl(parent, "LanternBase", cf * CF(0, -1.65 * s, 0), 0.2 * s, 0.8 * s, O.IRON, "Metal", nc)
	if o.Light ~= false then
		P.pointLight(glow, O.LIGHT, o.Range or 16, o.Brightness or 1.3, false)
	end
	return glow
end

-- Lantern on an iron bracket sticking out of a wall. cf: on the wall surface, +Z out of the wall.
function O.WallLantern(parent: any, cf: any, opts: { [string]: any }?)
	local arm = (opts and opts.Arm) or 1.3
	part(parent, "BracketPlate", V(0.5, 0.9, 0.12), cf * CF(0, 0, 0.06), O.IRON, "Metal", { CanCollide = false })
	part(parent, "Bracket", V(0.14, 0.14, arm), cf * CF(0, 0.2, arm / 2), O.IRON, "Metal", { CanCollide = false })
	stick(parent, "Bracket", (cf * CF(0, -0.35, 0.1)).Position, (cf * CF(0, 0.2, arm * 0.7)).Position, 0.1, 0.1, O.IRON, "Metal", { CanCollide = false })
	return O.Lantern(parent, cf * CF(0, 0.15, arm - 0.1), opts)
end

-- Wooden post with an arm and a hanging lantern. cf: base of the post on the ground, the arm points to +Z.
function O.LanternPost(parent: any, cf: any, height: number?, opts: { [string]: any }?)
	local h = height or 8
	part(parent, "LanternPost", V(0.7, h, 0.7), cf * CF(0, h / 2 - 0.5, 0), O.Jitter(O.DARK, 0.05), "Wood")
	part(parent, "PostCap", V(0.9, 0.3, 0.9), cf * CF(0, h - 0.4, 0), O.DARKER, "Wood")
	part(parent, "LanternArm", V(0.4, 0.4, 2.2), cf * CF(0, h - 1.1, 0.9), O.DARK, "Wood", { CanCollide = false })
	stick(parent, "LanternBrace", (cf * CF(0, h - 2.6, 0.2)).Position, (cf * CF(0, h - 1.2, 1.3)).Position, 0.25, 0.25, O.DARK, "Wood", { CanCollide = false })
	return O.Lantern(parent, cf * CF(0, h - 1.3, 1.75), opts)
end

-- Barrel standing on its bottom (cf: bottom centre). opts: Color, Lying (bool), Scale
function O.Barrel(parent: any, cf: any, opts: { [string]: any }?)
	local o = opts or {}
	local s = o.Scale or 1
	local color = O.Jitter(o.Color or rgb(130, 88, 52), 0.08)
	local base = if o.Lying then cf * CF(0, 0.95 * s, 0) * Angles(math.pi / 2, 0, 0) * CF(0, -1.3 * s, 0) else cf
	cyl(parent, "Barrel", base * CF(0, 1.3 * s, 0), 1.5 * s, 2.0 * s, color, "WoodPlanks")
	cyl(parent, "Barrel", base * CF(0, 0.4 * s, 0), 0.8 * s, 1.75 * s, O.Shade(color, 0.95), "WoodPlanks")
	cyl(parent, "Barrel", base * CF(0, 2.2 * s, 0), 0.8 * s, 1.75 * s, O.Shade(color, 0.95), "WoodPlanks")
	for _, y in { 0.62, 1.98 } do
		cyl(parent, "Hoop", base * CF(0, y * s, 0), 0.18 * s, 1.93 * s, O.IRON, "Metal", { CanCollide = false })
	end
end

-- Crate (cf: bottom centre). size = edge length.
function O.Crate(parent: any, cf: any, size: number?, color: any?)
	local s = size or 2.4
	local c = O.Jitter(color or rgb(176, 132, 82), 0.08)
	part(parent, "Crate", V(s, s, s), cf * CF(0, s / 2, 0), c, "WoodPlanks")
	local frame = O.Shade(c, 0.72)
	part(parent, "CrateFrame", V(s + 0.12, s * 0.14, s + 0.12), cf * CF(0, s * 0.07, 0), frame, "Wood", { CanCollide = false })
	part(parent, "CrateFrame", V(s + 0.12, s * 0.14, s + 0.12), cf * CF(0, s * 0.93, 0), frame, "Wood", { CanCollide = false })
	part(parent, "CrateSlat", V(s * 0.14, s * 1.25, s + 0.1), cf * CF(0, s / 2, 0) * Angles(0, 0, math.rad(45)), frame, "Wood", { CanCollide = false })
end

-- Burlap sack (cf: bottom centre)
function O.Sack(parent: any, cf: any, color: any?)
	local c = O.Jitter(color or O.BURLAP, 0.07)
	cyl(parent, "Sack", cf * CF(0, 0.6, 0), 1.2, 1.5, c, "Fabric")
	ball(parent, "Sack", (cf * CF(0, 1.15, 0)).Position, 1.45, c, "Fabric")
	cyl(parent, "SackTie", cf * CF(0, 1.85, 0), 0.35, 0.5, O.Shade(c, 0.8), "Fabric", { CanCollide = false })
	ball(parent, "SackTop", (cf * CF(0, 2.1, 0)).Position, 0.45, c, "Fabric", { CanCollide = false })
end

-- Coil of rope lying on the floor (cf: bottom centre)
function O.RopeCoil(parent: any, cf: any, size: number?)
	local s = size or 1
	for i = 0, 2 do
		cyl(parent, "RopeCoil", cf * CF(0.05 * i * s, (0.12 + i * 0.2) * s, 0), 0.22 * s, (1.8 - i * 0.18) * s, O.Jitter(O.ROPE, 0.06), "Fabric", { CanCollide = false })
	end
	cyl(parent, "RopeHole", cf * CF(0.1 * s, 0.3 * s, 0), 0.62 * s, 0.6 * s, O.Shade(O.ROPE, 0.45), "Fabric", { CanCollide = false })
	stick(parent, "RopeEnd", (cf * CF(0.8 * s, 0.1, 0)).Position, (cf * CF(1.7 * s, 0.08, 0.6 * s)).Position, 0.16, 0.16, O.ROPE, "Fabric", { CanCollide = false })
end

-- Fishing net hanging flat. cf: centre of the net, net in the XY plane. Adds a few floats.
function O.Net(parent: any, cf: any, w: number, h: number)
	local nc = { CanCollide = false, CanQuery = false }
	local cols = math.max(2, math.floor(w / 0.9))
	local rows = math.max(2, math.floor(h / 0.9))
	for i = 0, cols do
		local x = -w / 2 + w * i / cols
		part(parent, "NetCord", V(0.06, h, 0.06), cf * CF(x, 0, 0) * Angles(0, 0, math.rad(O.Range(-3, 3))), rgb(70, 60, 46), "Fabric", nc)
	end
	for j = 0, rows do
		local y = -h / 2 + h * j / rows
		part(parent, "NetCord", V(w, 0.06, 0.06), cf * CF(0, y, 0), rgb(70, 60, 46), "Fabric", nc)
	end
	for k = 1, 3 do
		local col = if k % 2 == 0 then rgb(240, 120, 50) else rgb(90, 170, 170)
		ball(parent, "NetFloat", (cf * CF(O.Range(-w / 2.5, w / 2.5), O.Range(-h / 2.5, h / 2.5), 0.15)).Position, 0.55, col, "SmoothPlastic", nc)
	end
end

-- String of pennant flags from a to b (sags in the middle)
function O.Bunting(parent: any, a: any, b: any, colors: { any }, count: number?, sag: number?)
	local n = count or 8
	local mid = (a + b) / 2 - V(0, sag or 1.2, 0)
	local nc = { CanCollide = false, CanQuery = false }
	rod(parent, "BuntingRope", a, mid, 0.1, O.ROPE, "Fabric", nc)
	rod(parent, "BuntingRope", mid, b, 0.1, O.ROPE, "Fabric", nc)
	local up = V(0, 1, 0)
	for i = 1, n do
		local t = (i - 0.5) / n
		local p = if t < 0.5 then a:Lerp(mid, t * 2) else mid:Lerp(b, (t - 0.5) * 2)
		local dir = (b - a)
		dir = V(dir.X, 0, dir.Z).Unit
		local w = math.min(1.4, (b - a).Magnitude / n * 0.75)
		local color = colors[(i - 1) % #colors + 1]
		triangle(parent, "Pennant", p - dir * (w / 2), dir * w, up * -1.4, 0.05, color, "Fabric", nc)
	end
end

-- Flag pole with a fluttering flag (cf: base of the pole, flag towards +X)
function O.FlagPole(parent: any, cf: any, height: number, color: any, opts: { [string]: any }?)
	local o = opts or {}
	cyl(parent, "FlagPole", cf * CF(0, height / 2, 0), height, o.Diameter or 0.45, O.DARK, "Wood")
	ball(parent, "PoleTop", (cf * CF(0, height + 0.15, 0)).Position, 0.6, O.BRASS, "Metal", { CanCollide = false })
	local fw, fh = o.Width or 5, o.Height or 3.2
	local segs = 3
	local first
	for i = 0, segs - 1 do
		local x = (i + 0.5) * fw / segs
		local f = part(parent, "Flag", V(fw / segs + 0.05, fh, 0.1), cf * CF(x + 0.2, height - fh / 2 - 0.3, math.sin(i * 1.7) * 0.25) * Angles(0, math.rad(if i % 2 == 0 then 10 else -10), 0), O.Shade(color, 1 - i * 0.04), "Fabric", { CanCollide = false })
		first = first or f
	end
	return first
end

-- Treasure chest (cf: bottom centre, front towards -Z)
function O.Chest(parent: any, cf: any, opts: { [string]: any }?)
	local o = opts or {}
	local s = o.Scale or 1
	local wood = O.Jitter(o.Color or rgb(120, 72, 40), 0.06)
	local band = o.Band or O.BRASS
	part(parent, "Chest", V(2.6 * s, 1.3 * s, 1.6 * s), cf * CF(0, 0.65 * s, 0), wood, "WoodPlanks")
	part(parent, "ChestLid", V(2.6 * s, 1.6 * s, 1.6 * s), cf * CF(0, 1.3 * s, 0) * Angles(0, 0, math.pi / 2), wood, "WoodPlanks", { Shape = "Cylinder", Size = V(2.6 * s, 1.6 * s, 1.6 * s), CFrame = cf * CF(0, 1.3 * s, 0) })
	for _, x in { -0.85, 0.85 } do
		part(parent, "ChestBand", V(0.2 * s, 1.35 * s, 1.66 * s), cf * CF(x * s, 0.66 * s, 0), band, "Metal", { CanCollide = false })
		part(parent, "ChestBand", V(0.2 * s, 1.66 * s, 1.66 * s), cf * CF(x * s, 1.3 * s, 0), band, "Metal", { Shape = "Cylinder", CanCollide = false })
	end
	part(parent, "ChestLock", V(0.45 * s, 0.55 * s, 0.12 * s), cf * CF(0, 1.25 * s, -0.83 * s), band, "Metal", { CanCollide = false })
	if o.Gold then
		ball(parent, "Gold", (cf * CF(0, 1.55 * s, 0)).Position, 1.2 * s, O.GOLD, "Metal", { CanCollide = false })
	end
end

-- Shop emblems (carved / painted props drawn above signs). cf: centre of the emblem, facing +Z.
-- kind = "Anchor" | "Wheel" | "Swords" | "Coin" | "Barrel" | "Mug"; k = scale (about 2.4 studs tall at 1)
function O.Emblem(parent: any, cf: any, kind: string, k: number?)
	local s = k or 1
	local nc = { CanCollide = false, CanQuery = false }
	if kind == "Anchor" then
		O.Anchor(parent, cf * CF(0, 1.25 * s, 0), 0.55 * s)
	elseif kind == "Wheel" then
		local wood = rgb(128, 84, 48)
		cylZ(parent, "EmblemWheel", cf, 0.22 * s, 2.0 * s, wood, "Wood", nc)
		cylZ(parent, "EmblemWheel", cf * CF(0, 0, 0.04 * s), 0.22 * s, 1.5 * s, O.Shade(wood, 0.62), "Wood", nc)
		for i = 0, 3 do
			part(parent, "EmblemSpoke", V(2.9 * s, 0.2 * s, 0.2 * s), cf * CF(0, 0, 0.16 * s) * Angles(0, 0, i * math.pi / 4), O.Shade(wood, 1.12), "Wood", nc)
		end
		cylZ(parent, "EmblemHub", cf * CF(0, 0, 0.24 * s), 0.25 * s, 0.6 * s, O.BRASS, "Metal", nc)
	elseif kind == "Swords" then
		for _, side in { -1, 1 } do
			O.Cutlass(parent, cf * CF(side * 0.6 * s, -0.7 * s, 0) * Angles(0, 0, side * math.rad(35)), 0.95 * s)
		end
	elseif kind == "Coin" then
		cylZ(parent, "EmblemCoin", cf, 0.24 * s, 2.0 * s, O.GOLD, "Metal", nc)
		cylZ(parent, "EmblemCoin", cf * CF(0, 0, 0.06 * s), 0.24 * s, 1.55 * s, O.Shade(O.GOLD, 0.82), "Metal", nc)
		ball(parent, "EmblemSkull", (cf * CF(0, 0.1 * s, 0.2 * s)).Position, 0.7 * s, O.GOLD, "Metal", nc)
		part(parent, "EmblemJaw", V(0.42 * s, 0.26 * s, 0.2 * s), cf * CF(0, -0.32 * s, 0.22 * s), O.GOLD, "Metal", nc)
	elseif kind == "Barrel" then
		local c = rgb(150, 100, 58)
		part(parent, "EmblemBarrel", V(2.0 * s, 1.4 * s, 1.4 * s), cf, c, "WoodPlanks", merge({ Shape = "Cylinder" }, nc))
		for _, x in { -0.62, 0.62 } do
			part(parent, "EmblemHoop", V(0.16 * s, 1.48 * s, 1.48 * s), cf * CF(x * s, 0, 0), O.IRON, "Metal", merge({ Shape = "Cylinder" }, nc))
		end
	elseif kind == "Mug" then
		cyl(parent, "EmblemMug", cf, 1.5 * s, 1.1 * s, rgb(150, 104, 60), "Wood", nc)
		cyl(parent, "EmblemFoam", cf * CF(0, 0.82 * s, 0), 0.3 * s, 1.15 * s, rgb(250, 244, 226), "SmoothPlastic", nc)
		part(parent, "EmblemHandle", V(0.22 * s, 0.9 * s, 0.3 * s), cf * CF(0.72 * s, 0, 0), rgb(110, 76, 46), "Wood", nc)
	end
end

-- Carved wooden sign with Rye lettering. cf: centre of the board, readable from +Z (and -Z if TwoSided).
-- A framed board with rolled scroll ends. opts: Color, TextColor, TwoSided, Hang (height of chains
-- above the board), Emblem (kind for O.Emblem above the board), EmblemScale, PixelsPerStud
function O.Sign(parent: any, cf: any, w: number, h: number, text: string, opts: { [string]: any }?)
	local o = opts or {}
	local wood = o.Color or rgb(96, 62, 38)
	local board = part(parent, "SignBoard", V(w, h, 0.35), cf, wood, "WoodPlanks", { CanCollide = false })
	part(parent, "SignBack", V(w + 0.4, h + 0.4, 0.22), cf, O.Shade(wood, 0.55), "Wood", { CanCollide = false })
	-- rolled ends, like a scroll
	for _, side in { -1, 1 } do
		cyl(parent, "SignScroll", cf * CF(side * (w / 2 + 0.25), 0, 0), h + 0.5, math.min(0.9, h * 0.36), O.Shade(wood, 0.8), "Wood", { CanCollide = false })
		ball(parent, "SignNail", (cf * CF(side * (w / 2 - 0.4), 0, 0.17)).Position, 0.24, O.BRASS, "Metal", { CanCollide = false })
	end
	local tc = o.TextColor or rgb(255, 216, 128)
	P.surfaceText(board, "Back", text, { Name = "SignText", Color = tc, PixelsPerStud = o.PixelsPerStud or 32, StrokeTransparency = 0.25 })
	if o.TwoSided then
		P.surfaceText(board, "Front", text, { Name = "SignText", Color = tc, PixelsPerStud = o.PixelsPerStud or 32, StrokeTransparency = 0.25 })
	end
	if o.Hang then
		for _, side in { -1, 1 } do
			part(parent, "SignChain", V(0.1, o.Hang, 0.1), cf * CF(side * w * 0.36, h / 2 + o.Hang / 2, 0), O.IRON, "Metal", { CanCollide = false })
		end
	end
	if o.Emblem then
		local es = o.EmblemScale or 1
		O.Emblem(parent, cf * CF(0, h / 2 + 1.25 * es, 0.15), o.Emblem, es)
	end
	return board
end

-- A carved sign hanging from a gallows post (cf: foot of the post on the ground; the arm reaches
-- along +X and the board faces +Z). Readable from both sides.
function O.PostSign(parent: any, cf: any, text: string, opts: { [string]: any }?)
	local o = opts or {}
	local h = o.Height or 7.5
	local arm = o.Arm or 3.6
	local wood = o.Color or rgb(110, 72, 44)
	part(parent, "SignPost", V(0.7, h + 1, 0.7), cf * CF(0, (h - 1) / 2, 0), O.Jitter(O.DARK, 0.05), "Wood")
	part(parent, "SignPostCap", V(0.95, 0.3, 0.95), cf * CF(0, h - 0.35, 0), O.DARKER, "Wood", { CanCollide = false })
	part(parent, "SignArm", V(arm + 0.4, 0.45, 0.45), cf * CF(arm / 2, h - 1.0, 0), O.DARK, "Wood", { CanCollide = false })
	stick(parent, "SignBrace", (cf * CF(0.2, h - 2.6, 0)).Position, (cf * CF(1.5, h - 1.1, 0)).Position, 0.3, 0.3, O.DARK, "Wood", { CanCollide = false })
	local bw, bh = o.Width or 3.2, o.BoardH or 1.5
	local hang = 0.6
	local board = cf * CF(arm / 2 + 0.3, h - 1.2 - hang - bh / 2, 0)
	for _, side in { -1, 1 } do
		part(parent, "SignChain", V(0.08, hang + 0.1, 0.08), board * CF(side * bw * 0.36, bh / 2 + hang / 2, 0), O.IRON, "Metal", { CanCollide = false, CanQuery = false })
	end
	local b = part(parent, "SignBoard", V(bw, bh, 0.25), board, wood, "WoodPlanks", { CanCollide = false })
	part(parent, "SignBack", V(bw + 0.3, bh + 0.3, 0.16), board, O.Shade(wood, 0.55), "Wood", { CanCollide = false })
	local tc = o.TextColor or rgb(255, 222, 140)
	for _, face in { "Front", "Back" } do
		P.surfaceText(b, face, text, { Name = "SignText", Color = tc, PixelsPerStud = 40, StrokeTransparency = 0.3, Padding = 0.06 })
	end
	if o.Lantern then
		O.Lantern(parent, cf * CF(arm - 0.2, h - 1.0, 0), { Range = 12, Brightness = 1, Scale = 0.8, Light = o.Light })
	end
	return b
end

-- Simple table (cf: floor centre). Top w x d at height 2.6.
function O.Table(parent: any, cf: any, w: number, d: number, color: any?)
	local c = color or rgb(128, 90, 58)
	for i = 0, 2 do
		part(parent, "TableTop", V(w, 0.3, d / 3 - 0.06), cf * CF(0, 2.65, -d / 2 + (i + 0.5) * d / 3), O.Jitter(c, 0.06), "WoodPlanks")
	end
	for _, x in { -w / 2 + 0.4, w / 2 - 0.4 } do
		for _, z in { -d / 2 + 0.4, d / 2 - 0.4 } do
			part(parent, "TableLeg", V(0.4, 2.5, 0.4), cf * CF(x, 1.25, z), O.Shade(c, 0.75), "Wood")
		end
	end
end

-- Stool (cf: floor centre)
function O.Stool(parent: any, cf: any)
	cyl(parent, "StoolSeat", cf * CF(0, 1.7, 0), 0.25, 1.3, O.Jitter(rgb(130, 92, 58), 0.08), "Wood")
	for k = 0, 1 do
		part(parent, "StoolLeg", V(1.1, 1.6, 0.16), cf * CF(0, 0.8, 0) * Angles(0, k * math.pi / 2, 0), O.DARK, "Wood", { CanCollide = false })
	end
end

-- Tankard / mug (cf: bottom centre)
function O.Mug(parent: any, cf: any)
	local nc = { CanCollide = false, CanQuery = false }
	cyl(parent, "Mug", cf * CF(0, 0.32, 0), 0.64, 0.5, rgb(140, 100, 60), "Wood", nc)
	cyl(parent, "Foam", cf * CF(0, 0.67, 0), 0.08, 0.46, rgb(250, 244, 226), "SmoothPlastic", nc)
	part(parent, "MugHandle", V(0.1, 0.4, 0.22), cf * CF(0.32, 0.34, 0), rgb(110, 76, 46), "Wood", nc)
end

-- Bottle (cf: bottom centre)
function O.Bottle(parent: any, cf: any, color: any?)
	local nc = { CanCollide = false, CanQuery = false }
	local c = color or rgb(60, 120, 70)
	cyl(parent, "Bottle", cf * CF(0, 0.35, 0), 0.7, 0.38, c, "Glass", merge({ Transparency = 0.2 }, nc))
	cyl(parent, "BottleNeck", cf * CF(0, 0.85, 0), 0.4, 0.16, c, "Glass", merge({ Transparency = 0.2 }, nc))
end

-- Keg lying in a cradle with a tap (cf: floor centre, tap towards -Z... the barrel lies along X)
function O.Keg(parent: any, cf: any, color: any?)
	for _, x in { -0.75, 0.75 } do
		part(parent, "KegCradle", V(0.35, 0.8, 1.9), cf * CF(x, 0.4, 0), O.DARK, "Wood")
	end
	local c = O.Jitter(color or rgb(140, 92, 52), 0.08)
	local axis = cf * CF(0, 1.55, 0)
	part(parent, "Keg", V(2.4, 1.9, 1.9), axis, c, "WoodPlanks", { Shape = "Cylinder" })
	for _, x in { -0.8, 0.8 } do
		part(parent, "Hoop", V(0.16, 1.98, 1.98), axis * CF(x, 0, 0), O.IRON, "Metal", { Shape = "Cylinder", CanCollide = false })
	end
	part(parent, "Tap", V(0.4, 0.2, 0.2), axis * CF(1.35, -0.3, 0), O.BRASS, "Metal", { CanCollide = false })
	part(parent, "Tap", V(0.14, 0.4, 0.14), axis * CF(1.5, -0.5, 0), O.BRASS, "Metal", { CanCollide = false })
end

-- Pyramid of cannonballs (cf: bottom centre)
function O.Cannonballs(parent: any, cf: any, d: number?)
	local s = d or 1
	local nc = { CanCollide = false }
	local layers = { { { -0.5, -0.29 }, { 0.5, -0.29 }, { 0, 0.58 }, { -1, 0.58 }, { 1, 0.58 }, { 0, -1.15 } }, { { 0, 0 }, { -0.5, 0.29 + 0.58 }, { 0.5, 0.29 + 0.58 } }, { { 0, 0.58 } } }
	for li, layer in layers do
		for _, p in layer do
			ball(parent, "Cannonball", (cf * CF(p[1] * s, (0.5 + (li - 1) * 0.82) * s, (p[2] - 0.1) * s)).Position, s, O.Jitter(rgb(40, 40, 44), 0.1), "Metal", nc)
		end
	end
end

-- Deck cannon on a wooden carriage (cf: floor centre, barrel points towards +Z)
function O.Cannon(parent: any, cf: any, s: number?)
	local k = s or 1
	local wood = rgb(110, 70, 40)
	part(parent, "CannonCarriage", V(2.0 * k, 0.9 * k, 3.2 * k), cf * CF(0, 0.85 * k, 0), wood, "WoodPlanks")
	part(parent, "CannonCarriage", V(1.8 * k, 0.7 * k, 1.6 * k), cf * CF(0, 1.5 * k, -0.6 * k), O.Shade(wood, 0.85), "WoodPlanks")
	for _, x in { -1.05, 1.05 } do
		for _, z in { -1.1, 1.1 } do
			part(parent, "CannonWheel", V(0.3 * k, 1.1 * k, 1.1 * k), cf * CF(x * k, 0.55 * k, z * k), O.DARK, "Wood", { Shape = "Cylinder" })
		end
	end
	local axis = cf * CF(0, 1.9 * k, 0.4 * k) * Angles(math.rad(6), 0, 0)
	cylZ(parent, "CannonBarrel", axis, 4.2 * k, 1.05 * k, O.IRON, "Metal")
	cylZ(parent, "CannonBarrel", axis * CF(0, 0, -1.9 * k), 0.6 * k, 1.35 * k, O.IRON, "Metal")
	cylZ(parent, "CannonMuzzle", axis * CF(0, 0, 2.0 * k), 0.4 * k, 1.3 * k, O.IRON, "Metal")
	ball(parent, "CannonKnob", (axis * CF(0, 0, -2.35 * k)).Position, 0.6 * k, O.IRON, "Metal")
end

-- Cutlass (cf: point where the hilt meets the blade, blade along +Y)
function O.Cutlass(parent: any, cf: any, s: number?)
	local k = s or 1
	local nc = { CanCollide = false, CanQuery = false }
	part(parent, "Blade", V(0.12 * k, 2.6 * k, 0.4 * k), cf * CF(0, 1.3 * k, 0.05 * k) * Angles(math.rad(-4), 0, 0), rgb(214, 218, 224), "Metal", nc)
	part(parent, "Guard", V(0.2 * k, 0.18 * k, 0.9 * k), cf, O.BRASS, "Metal", nc)
	part(parent, "Grip", V(0.2 * k, 0.75 * k, 0.2 * k), cf * CF(0, -0.42 * k, 0), O.DARKER, "Wood", nc)
	ball(parent, "Pommel", (cf * CF(0, -0.85 * k, 0)).Position, 0.26 * k, O.BRASS, "Metal", nc)
end

-- Musket (cf: butt of the stock, barrel along +Y)
function O.Musket(parent: any, cf: any)
	local nc = { CanCollide = false, CanQuery = false }
	part(parent, "Stock", V(0.25, 1.6, 0.45), cf * CF(0, 0.8, 0), rgb(110, 66, 36), "Wood", nc)
	part(parent, "Stock", V(0.22, 1.4, 0.28), cf * CF(0, 2.2, 0.06), rgb(110, 66, 36), "Wood", nc)
	cyl(parent, "MusketBarrel", cf * CF(0, 2.9, 0.1), 2.6, 0.16, O.IRON, "Metal", nc)
	part(parent, "Lock", V(0.28, 0.3, 0.2), cf * CF(0, 1.55, 0.14), O.BRASS, "Metal", nc)
end

-- Weapon rack with cutlasses and muskets (cf: floor centre, weapons face +Z)
function O.WeaponRack(parent: any, cf: any, w: number?)
	local width = w or 6
	for _, x in { -width / 2, width / 2 } do
		part(parent, "RackPost", V(0.4, 4.4, 0.4), cf * CF(x, 2.2, 0), O.DARK, "Wood")
	end
	part(parent, "RackBar", V(width + 0.6, 0.35, 0.5), cf * CF(0, 3.9, 0), O.DARK, "Wood")
	part(parent, "RackBar", V(width + 0.2, 0.3, 0.9), cf * CF(0, 0.4, 0.2), O.DARK, "Wood")
	local n = math.max(2, math.floor(width / 1.3))
	for i = 0, n - 1 do
		local x = -width / 2 + (i + 0.5) * width / n
		if i % 2 == 0 then
			O.Cutlass(parent, cf * CF(x, 1.4, 0.35) * Angles(math.rad(-8), 0, 0))
		else
			O.Musket(parent, cf * CF(x, 0.55, 0.35) * Angles(math.rad(-7), 0, 0))
		end
	end
end

-- Merchant's balance scales (cf: bottom centre on a table)
function O.Scales(parent: any, cf: any)
	local nc = { CanCollide = false, CanQuery = false }
	cyl(parent, "ScaleBase", cf * CF(0, 0.1, 0), 0.2, 1.2, O.BRASS, "Metal", nc)
	cyl(parent, "ScalePost", cf * CF(0, 1.1, 0), 1.9, 0.16, O.BRASS, "Metal", nc)
	part(parent, "ScaleBeam", V(2.4, 0.1, 0.1), cf * CF(0, 2.05, 0) * Angles(0, 0, math.rad(6)), O.BRASS, "Metal", nc)
	for _, side in { -1, 1 } do
		local y = 2.05 + side * -0.12
		part(parent, "ScaleString", V(0.04, 1.0, 0.04), cf * CF(side * 1.15, y - 0.5, 0), O.IRON, "Metal", nc)
		cyl(parent, "ScalePan", cf * CF(side * 1.15, y - 1.0, 0), 0.08, 0.9, O.BRASS, "Metal", nc)
	end
	ball(parent, "Gold", (cf * CF(-1.15, 1.3, 0)).Position, 0.35, O.GOLD, "Metal", nc)
end

-- Rolled maps / scrolls (cf: on a surface)
function O.Scrolls(parent: any, cf: any, n: number?)
	local nc = { CanCollide = false, CanQuery = false }
	for i = 1, n or 3 do
		local a = O.Range(-0.6, 0.6)
		local scroll = cf * CF(O.Range(-0.5, 0.5), 0.18 + (i - 1) * 0.05, (i - 2) * 0.45) * Angles(0, a, 0)
		part(parent, "Scroll", V(1.6, 0.34, 0.34), scroll, rgb(236, 220, 176), "SmoothPlastic", merge({ Shape = "Cylinder" }, nc))
		part(parent, "ScrollTie", V(0.12, 0.38, 0.38), scroll, rgb(170, 40, 40), "Fabric", merge({ Shape = "Cylinder" }, nc))
	end
end

-- Open map lying on a table (cf: on the surface)
function O.MapSheet(parent: any, cf: any, w: number?, d: number?)
	local nc = { CanCollide = false, CanQuery = false }
	local mw, md = w or 2.2, d or 1.6
	part(parent, "Map", V(mw, 0.04, md), cf * CF(0, 0.02, 0), rgb(232, 214, 168), "SmoothPlastic", nc)
	part(parent, "MapIsland", V(mw * 0.3, 0.05, md * 0.25), cf * CF(-mw * 0.15, 0.03, md * 0.1) * Angles(0, 0.5, 0), rgb(140, 170, 100), "SmoothPlastic", nc)
	part(parent, "MapX", V(0.32, 0.06, 0.08), cf * CF(mw * 0.2, 0.04, -md * 0.15) * Angles(0, math.rad(45), 0), rgb(190, 40, 40), "SmoothPlastic", nc)
	part(parent, "MapX", V(0.32, 0.06, 0.08), cf * CF(mw * 0.2, 0.04, -md * 0.15) * Angles(0, math.rad(-45), 0), rgb(190, 40, 40), "SmoothPlastic", nc)
	for _, side in { -1, 1 } do
		part(parent, "MapRoll", V(md + 0.1, 0.22, 0.22), cf * CF(side * mw / 2, 0.11, 0) * Angles(0, math.pi / 2, 0), rgb(222, 202, 154), "SmoothPlastic", merge({ Shape = "Cylinder" }, nc))
	end
end

-- Ship's anchor (cf: the ring at the top, anchor hangs down along -Y, flukes in the XY plane)
function O.Anchor(parent: any, cf: any, s: number?)
	local k = s or 1
	local nc = { CanCollide = false }
	local col = rgb(60, 58, 62)
	cylZ(parent, "AnchorRing", cf, 0.2 * k, 0.9 * k, col, "Metal", nc)
	part(parent, "AnchorShank", V(0.45 * k, 4.2 * k, 0.45 * k), cf * CF(0, -2.4 * k, 0), col, "Metal", nc)
	part(parent, "AnchorStock", V(2.6 * k, 0.4 * k, 0.4 * k), cf * CF(0, -0.9 * k, 0), rgb(110, 76, 46), "Wood", nc)
	for _, side in { -1, 1 } do
		stick(parent, "AnchorArm", (cf * CF(0, -4.4 * k, 0)).Position, (cf * CF(side * 1.6 * k, -3.0 * k, 0)).Position, 0.4 * k, 0.4 * k, col, "Metal", nc)
		part(parent, "AnchorFluke", V(0.7 * k, 0.9 * k, 0.25 * k), cf * CF(side * 1.65 * k, -2.85 * k, 0) * Angles(0, 0, side * math.rad(-35)), col, "Metal", nc)
	end
	ball(parent, "AnchorCrown", (cf * CF(0, -4.5 * k, 0)).Position, 0.6 * k, col, "Metal", nc)
end

-- Stack of lumber (cf: bottom centre, boards along Z)
function O.Lumber(parent: any, cf: any, len: number?, layers: number?)
	local l = len or 12
	for layer = 0, (layers or 3) - 1 do
		local n = 4 - layer % 2
		for i = 0, n - 1 do
			local x = (i - (n - 1) / 2) * 1.1
			part(parent, "Lumber", V(1.0, 0.45, l - O.Range(0, 1.6)), cf * CF(x, 0.6 + layer * 0.48, O.Range(-0.4, 0.4)), O.Jitter(rgb(196, 152, 98), 0.08), "WoodPlanks")
		end
		part(parent, "Spacer", V(4.6, 0.35, 0.5), cf * CF(0, 0.2 + layer * 0.48, -l / 3), O.DARK, "Wood", { CanCollide = false })
	end
end

-- Stack of logs (cf: bottom centre, logs along X)
function O.Logs(parent: any, cf: any, len: number?)
	local l = len or 7
	local rows = { { -1.05, 0 }, { 0, 0 }, { 1.05, 0 }, { -0.52, 1 }, { 0.52, 1 }, { 0, 2 } }
	for _, r in rows do
		part(parent, "Log", V(l + O.Range(-0.6, 0.6), 1.05, 1.05), cf * CF(O.Range(-0.3, 0.3), 0.52 + r[2] * 0.9, r[1]), O.Jitter(rgb(120, 84, 54), 0.08), "Wood", { Shape = "Cylinder" })
	end
end

-- Sawhorse with a board and a saw (cf: floor centre, board along X)
function O.Sawhorse(parent: any, cf: any)
	for _, x in { -1.4, 1.4 } do
		for _, z in { -1, 1 } do
			stick(parent, "SawhorseLeg", (cf * CF(x, 2.2, 0)).Position, (cf * CF(x + O.Range(-0.05, 0.05), 0, z * 0.8)).Position, 0.25, 0.25, O.DARK, "Wood")
		end
	end
	part(parent, "SawhorseBeam", V(3.6, 0.35, 0.4), cf * CF(0, 2.3, 0), O.DARK, "Wood")
	part(parent, "Board", V(6, 0.3, 1.0), cf * CF(0.6, 2.62, 0) * Angles(0, 0.08, 0), O.Jitter(rgb(196, 152, 98), 0.06), "WoodPlanks")
	part(parent, "SawBlade", V(1.8, 0.7, 0.05), cf * CF(2.6, 3.0, 0.2) * Angles(0, 0.1, math.rad(-20)), rgb(200, 204, 210), "Metal", { CanCollide = false })
	part(parent, "SawHandle", V(0.5, 0.6, 0.18), cf * CF(1.6, 3.35, 0.2) * Angles(0, 0.1, math.rad(-20)), rgb(140, 80, 40), "Wood", { CanCollide = false })
end

-- Hammer lying down (cf: centre, on a surface)
function O.Hammer(parent: any, cf: any)
	local nc = { CanCollide = false, CanQuery = false }
	part(parent, "HammerHandle", V(1.4, 0.16, 0.16), cf * CF(0, 0.08, 0), rgb(150, 100, 56), "Wood", nc)
	part(parent, "HammerHead", V(0.3, 0.3, 0.7), cf * CF(0.7, 0.15, 0), O.IRON, "Metal", nc)
end

-- Bolt of cloth (cf: bottom centre, lying along X)
function O.Cloth(parent: any, cf: any, color: any)
	part(parent, "Cloth", V(2.2, 0.8, 0.8), cf * CF(0, 0.4, 0), color, "Fabric", { Shape = "Cylinder", CanCollide = false })
	part(parent, "ClothCore", V(2.4, 0.25, 0.25), cf * CF(0, 0.4, 0), O.DARK, "Wood", { Shape = "Cylinder", CanCollide = false })
end

-- Basket of round goods (fruit, coconuts...). cf: bottom centre
function O.Basket(parent: any, cf: any, colors: { any })
	cyl(parent, "Basket", cf * CF(0, 0.45, 0), 0.9, 1.7, O.Jitter(rgb(186, 146, 90), 0.06), "Fabric")
	for i = 1, 5 do
		local a = i * 1.26
		ball(parent, "Fruit", (cf * CF(math.cos(a) * 0.42, 1.0 + (i % 2) * 0.12, math.sin(a) * 0.42)).Position, 0.6, O.Pick(colors), "SmoothPlastic", { CanCollide = false, CanQuery = false })
	end
end

-- Hanging fish (cf: hook point)
function O.Fish(parent: any, cf: any, color: any?)
	local nc = { CanCollide = false, CanQuery = false }
	local c = color or rgb(150, 170, 180)
	part(parent, "FishString", V(0.05, 0.5, 0.05), cf * CF(0, -0.25, 0), O.ROPE, "Fabric", nc)
	part(parent, "Fish", V(0.3, 1.3, 0.6), cf * CF(0, -1.15, 0), c, "SmoothPlastic", nc)
	triangle(parent, "FishTail", (cf * CF(-0.0, -1.8, 0)).Position, cf:VectorToWorldSpace(V(0, 0, 0.4)), cf:VectorToWorldSpace(V(0, -0.5, 0)), 0.08, O.Shade(c, 0.85), "SmoothPlastic", nc)
	triangle(parent, "FishTail", (cf * CF(-0.0, -1.8, 0)).Position, cf:VectorToWorldSpace(V(0, 0, -0.4)), cf:VectorToWorldSpace(V(0, -0.5, 0)), 0.08, O.Shade(c, 0.85), "SmoothPlastic", nc)
end

-- Wooden A-frame hoist (cf: ground centre between the legs, legs spread along X). A rope with a
-- pulley block hangs from the top beam and lifts a bundle of planks.
function O.Hoist(parent: any, cf: any, h: number?, spread: number?)
	local height = h or 13
	local sx = spread or 5
	local wood = rgb(116, 84, 56)
	for _, side in { -1, 1 } do
		for _, z in { -1.6, 1.6 } do
			stick(parent, "HoistLeg", (cf * CF(side * sx, 0, z)).Position, (cf * CF(side * 1.2, height, z * 0.35)).Position, 0.7, 0.7, O.Jitter(wood, 0.06), "Wood")
		end
		part(parent, "HoistTie", V(0.4, 0.4, 3.4), cf * CF(side * sx * 0.55, height * 0.45, 0), O.DARK, "Wood", { CanCollide = false })
	end
	part(parent, "HoistBeam", V(3.6, 0.8, 1.6), cf * CF(0, height + 0.1, 0), O.DARK, "Wood")
	part(parent, "HoistArm", V(0.6, 0.6, 4.2), cf * CF(0, height + 0.5, 1.6), O.DARK, "Wood", { CanCollide = false })
	cylZ(parent, "HoistPulley", cf * CF(0, height - 0.2, 3.4), 0.35, 0.9, O.IRON, "Metal", { CanCollide = false })
	local bottom = height * 0.58
	part(parent, "HoistRope", V(0.14, height - bottom - 0.4, 0.14), cf * CF(0, (height + bottom) / 2 - 0.2, 3.4), O.ROPE, "Fabric", { CanCollide = false, CanQuery = false })
	for i = 0, 2 do
		part(parent, "HoistLoad", V(0.9, 0.4, 5), cf * CF(-0.95 + i * 0.95, bottom - 0.3, 3.4) * Angles(0, 0, math.rad(O.Range(-3, 3))), O.Jitter(rgb(196, 152, 98), 0.08), "WoodPlanks", { CanCollide = false })
	end
	part(parent, "HoistSling", V(3.1, 0.12, 0.12), cf * CF(0, bottom + 0.0, 3.4), O.ROPE, "Fabric", { CanCollide = false, CanQuery = false })
end

-- Straw training dummy on a post (cf: foot of the post, faces +Z)
function O.Dummy(parent: any, cf: any)
	local straw = O.Jitter(rgb(206, 170, 96), 0.06)
	part(parent, "DummyPost", V(0.45, 5.4, 0.45), cf * CF(0, 2.5, 0), O.DARK, "Wood")
	part(parent, "DummyArms", V(3.6, 0.35, 0.35), cf * CF(0, 4.0, 0), O.DARK, "Wood", { CanCollide = false })
	cyl(parent, "DummyBody", cf * CF(0, 3.5, 0), 2.3, 1.5, straw, "Fabric")
	ball(parent, "DummyHead", (cf * CF(0, 5.2, 0)).Position, 1.25, straw, "Fabric", { CanCollide = false })
	cyl(parent, "DummyBelt", cf * CF(0, 3.0, 0), 0.3, 1.58, O.ROPE, "Fabric", { CanCollide = false })
	part(parent, "DummyBandana", V(1.3, 0.35, 1.3), cf * CF(0, 5.55, 0), rgb(170, 40, 40), "Fabric", { CanCollide = false })
end

-- Round shooting target on a stand (cf: ground centre, the face looks to +Z)
function O.Target(parent: any, cf: any)
	for _, side in { -1, 1 } do
		stick(parent, "TargetLeg", (cf * CF(side * 1.1, 0, -0.6)).Position, (cf * CF(side * 0.6, 4.6, 0)).Position, 0.3, 0.3, O.DARK, "Wood", { CanCollide = false })
	end
	local face = cf * CF(0, 3.6, 0.15) * Angles(math.rad(-10), 0, 0)
	cylZ(parent, "Target", face, 0.35, 3.2, rgb(232, 220, 190), "Fabric")
	cylZ(parent, "TargetRing", face * CF(0, 0, 0.05), 0.35, 2.2, rgb(180, 40, 36), "Fabric", { CanCollide = false })
	cylZ(parent, "TargetRing", face * CF(0, 0, 0.1), 0.35, 1.3, rgb(232, 220, 190), "Fabric", { CanCollide = false })
	cylZ(parent, "Bullseye", face * CF(0, 0, 0.15), 0.35, 0.55, rgb(180, 40, 36), "Fabric", { CanCollide = false })
end

-- Two-wheeled hand cart loaded with goods (cf: ground centre, handles towards -X)
function O.Cart(parent: any, cf: any, goods: { any }?)
	local wood = rgb(140, 100, 62)
	part(parent, "CartBed", V(4.4, 0.35, 2.8), cf * CF(0.3, 1.75, 0), O.Jitter(wood, 0.05), "WoodPlanks")
	for _, z in { -1.35, 1.35 } do
		part(parent, "CartSide", V(4.4, 0.9, 0.2), cf * CF(0.3, 2.35, z), O.Shade(wood, 0.85), "WoodPlanks")
		cylZ(parent, "CartWheel", cf * CF(0.6, 1.25, z * 1.12), 0.3, 2.5, O.DARK, "Wood")
		cylZ(parent, "CartHub", cf * CF(0.6, 1.25, z * 1.22), 0.3, 0.6, O.IRON, "Metal", { CanCollide = false })
		stick(parent, "CartHandle", (cf * CF(-1.6, 1.85, z * 0.9)).Position, (cf * CF(-3.8, 1.1, z * 1.0)).Position, 0.25, 0.25, O.DARK, "Wood", { CanCollide = false })
	end
	part(parent, "CartFoot", V(0.3, 1.5, 0.3), cf * CF(-1.4, 0.95, 0), O.DARK, "Wood", { CanCollide = false })
	local cols = goods or { rgb(196, 170, 120), O.BURLAP }
	O.Sack(parent, cf * CF(1.2, 1.9, 0.6) * Angles(0, 0, math.rad(-12)), cols[1])
	O.Sack(parent, cf * CF(-0.3, 1.9, -0.5) * Angles(math.rad(10), 0, 0), cols[2])
	O.Crate(parent, cf * CF(1.4, 1.92, -0.6) * Angles(0, 0.3, 0), 1.3)
end

-- Bollard for mooring lines (cf: deck surface)
function O.Bollard(parent: any, cf: any)
	cyl(parent, "Bollard", cf * CF(0, 0.75, 0), 1.5, 1.1, O.IRON, "Metal")
	cyl(parent, "BollardCap", cf * CF(0, 1.6, 0), 0.3, 1.45, O.IRON, "Metal")
end

-- Wooden torch with fire (cf: base on the ground)
function O.Torch(parent: any, cf: any, h: number?)
	local height = h or 5
	cyl(parent, "TorchPole", cf * CF(0, height / 2, 0), height, 0.35, O.DARK, "Wood")
	local head = cyl(parent, "TorchHead", cf * CF(0, height + 0.25, 0), 0.7, 0.55, rgb(70, 50, 36), "Fabric", { CanCollide = false })
	local fire = P.Instance.new("Fire")
	fire.Size = 2.4
	fire.Heat = 5
	fire.Parent = head
	P.pointLight(head, rgb(255, 160, 80), 14, 1.2, false)
	return head
end

return O
