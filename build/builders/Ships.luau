-- Builds the ship templates (ServerStorage.Ships.*), Sea of Thieves style.
-- Ship space: origin at the waterline centre, bow towards -Z, starboard towards +X.
-- Every part is welded (classic Weld) to the invisible "Root" part. Moving parts
-- (wheel, sails, cannon barrels, anchor) hang off named Welds the server animates.
--
-- The hull is a smooth parametric surface planked with strakes of box parts:
--   u = 0 (stem) .. 1 (transom) along the ship,
--   v = 0 (keel) .. 1 (waist sheer line) .. 2 (castle sheer line) up the side.
-- The lower zone (v 0..1) is the hull proper with wales and gun ports; the upper zone
-- (v 1..2) only has height where the forecastle and quarterdeck rise above the waist,
-- so the castles grow out of the hull with a smooth S-shaped sheer. Strakes are cut
-- adaptively: long planks where the hull is straight, short ones around the bow.
local P = require("./Parts")

local V = P.Vector3.new
local CF = P.CFrame.new
local Angles = P.CFrame.Angles
local fromMatrix = P.CFrame.fromMatrix
local Color3 = P.Color3
local rgb = P.rgb

local Ships = {}

local function clamp(x: number, a: number, b: number): number
	return math.max(a, math.min(b, x))
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smooth(t: number): number
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- deterministic pseudo random in [0, 1)
local function hash(a: number, b: number, c: number): number
	local x = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
	return x - math.floor(x)
end

local function shade(color: any, k: number): any
	return Color3.new(clamp(color.R * k, 0, 1), clamp(color.G * k, 0, 1), clamp(color.B * k, 0, 1))
end

local SAIL_BLACK = rgb(28, 26, 30)
local ROPE = rgb(58, 46, 34)
local IRON = rgb(48, 47, 50)
local SPAR = rgb(66, 48, 34)
local LAMP = rgb(255, 178, 92)

-- Shared shape language; per ship only proportions and accents change.
-- Rows = strake boundaries of the lower hull (absolute y amidships, keel .. waist sheer),
-- Kinds = strake type above each boundary. Mast/yard Y values are above DeckTop.
local STYLES = {
	Sloop = {
		DeckTop = 3.3,
		Keel = -3.8,
		StemFoot = -1.0,
		SternKeel = -2.2,
		ForefootT = 0.3,
		Rake = 5,
		SternRake = 1.8,
		Bulwark = 2.6,
		CastleBulwark = 1.5,
		Spring = 0.35,
		BowSpring = 0.9,
		BowRise = 1.6,
		SternRise = 1.0,
		BowRamp = 6,
		SternRamp = 4.5,
		UB = 0.36,
		US = 0.7,
		Transom = 0.74,
		Tumble = 0.026,
		FC = { Len = 8, H = 1.6, Stair = 2.6 },
		QD = { Len = 12, H = 3.6, Stair = 5.4 },
		StairW = 3.4,
		Rows = { -3.8, 0.2, 1.3, 2.1, 3.0, 3.8, 5.9 },
		Kinds = { "bottom", "side", "wale", "side", "wale", "side" },
		CastleRowH = 1.7,
		LaneW = 2.4,
		Masts = {
			{
				Z = -4,
				Base = "Main",
				Top = 37,
				Main = true,
				Nest = 30.2,
				Yards = {
					{ Y = 17, W = 20, H = 10, Belly = 1.7, Strips = 5, Emblem = true },
					{ Y = 28.6, W = 15, H = 10.6, Belly = 1.3, Strips = 3 },
				},
			},
		},
		Cannons = { { Z = 2.5, Side = 1 }, { Z = 2.5, Side = -1 } },
		Ports = 0,
		CastleTrim = false,
		Holes = 6,
		Windows = 3,
		Gallery = false,
		QuarterGallery = false,
		Bowsprit = { Heel = 4.5, Len = 13, Angle = 23, Jib = 6 },
		Capstan = { Z = -10, Deck = "Main" },
		Ladder = 7,
		Barrels = { { X = -0.66, Z = -12.5 }, { X = 0.7, Z = 8.4 }, { X = -0.7, Z = 8.6 } },
		Crates = { { X = 0.72, Z = -13.3, Stack = 2 } },
		Hatch = nil,
		Hull = rgb(92, 68, 50),
		Figure = rgb(176, 134, 64),
		Wale = rgb(46, 35, 28),
		Bottom = rgb(58, 52, 46),
		Trim = rgb(170, 128, 62),
		Deck = rgb(152, 118, 84),
		Rail = rgb(74, 52, 37),
		Accent = rgb(110, 34, 30),
		Pennant = rgb(120, 28, 26),
	},
	Brigantine = {
		DeckTop = 3.5,
		Keel = -4.2,
		StemFoot = -1.2,
		SternKeel = -2.6,
		ForefootT = 0.3,
		Rake = 6.5,
		SternRake = 2.4,
		Bulwark = 2.8,
		CastleBulwark = 1.6,
		Spring = 0.4,
		BowSpring = 1.0,
		BowRise = 1.8,
		SternRise = 1.3,
		BowRamp = 8,
		SternRamp = 5,
		UB = 0.33,
		US = 0.7,
		Transom = 0.75,
		Tumble = 0.026,
		FC = { Len = 11, H = 3.8, Stair = 5.6 },
		QD = { Len = 17, H = 5.0, Stair = 7.2 },
		StairW = 4.0,
		Rows = { -4.2, -0.3, 1.0, 1.8, 3.1, 4.0, 6.3 },
		Kinds = { "bottom", "side", "wale", "side", "wale", "side" },
		CastleRowH = 2.3,
		LaneW = 2.6,
		Masts = {
			{
				Z = -13,
				Base = "Main",
				Top = 41,
				Yards = {
					{ Y = 21, W = 23, H = 12, Belly = 1.9, Strips = 5, Emblem = true },
					{ Y = 34, W = 17.5, H = 12, Belly = 1.4, Strips = 3 },
				},
			},
			{
				Z = 4,
				Base = "Main",
				Top = 47,
				Main = true,
				Nest = 37.5,
				Yards = {
					{ Y = 22, W = 25, H = 13, Belly = 2.0, Strips = 5, Emblem = true },
					{ Y = 36, W = 19, H = 13, Belly = 1.5, Strips = 3 },
				},
			},
		},
		Cannons = { { Z = -6, Side = 1 }, { Z = -6, Side = -1 }, { Z = 9.5, Side = 1 }, { Z = 9.5, Side = -1 } },
		Ports = 0,
		CastleTrim = true,
		Holes = 8,
		Windows = 4,
		UpperWindows = 0,
		Gallery = true,
		QuarterGallery = true,
		Bowsprit = { Heel = 6, Len = 17, Angle = 22, Jib = 8 },
		Capstan = { Z = -23.6, Deck = "FC" },
		Ladder = -1.5,
		Barrels = { { X = -0.7, Z = -18.6 }, { X = 0.72, Z = -18.6 }, { X = 0.72, Z = 13.2 } },
		Crates = { { X = -0.72, Z = 13.0, Stack = 2 } },
		Hatch = { Z = -1 },
		Hull = rgb(80, 60, 46),
		Figure = rgb(196, 150, 66),
		Wale = rgb(40, 31, 26),
		Bottom = rgb(54, 49, 45),
		Trim = rgb(126, 36, 32),
		Deck = rgb(146, 112, 80),
		Rail = rgb(66, 46, 33),
		Accent = rgb(126, 36, 32),
		Pennant = rgb(128, 30, 28),
	},
	Galleon = {
		DeckTop = 3.8,
		Keel = -4.8,
		StemFoot = -1.5,
		SternKeel = -3.2,
		ForefootT = 0.27,
		Rake = 8,
		SternRake = 3.0,
		Bulwark = 3.0,
		CastleBulwark = 2.0,
		Spring = 0.45,
		BowSpring = 1.1,
		BowRise = 2.6,
		SternRise = 2.6,
		BowRamp = 10,
		SternRamp = 6,
		UB = 0.3,
		US = 0.72,
		Transom = 0.76,
		Tumble = 0.026,
		FC = { Len = 19, H = 5.5, Stair = 8.0 },
		QD = { Len = 25, H = 6.5, Stair = 9.4 },
		StairW = 4.4,
		Rows = { -4.8, -0.3, 1.0, 1.9, 3.4, 4.3, 5.6, 6.8 },
		Kinds = { "bottom", "side", "wale", "side", "wale", "side", "side" },
		CastleRowH = 2.2,
		LaneW = 2.8,
		Masts = {
			{
				Z = -33,
				Base = "FC",
				Top = 51,
				Yards = {
					{ Y = 26, W = 27, H = 13, Belly = 2.2, Strips = 5, Emblem = true },
					{ Y = 39.5, W = 20, H = 12.4, Belly = 1.6, Strips = 3 },
				},
			},
			{
				Z = -4,
				Base = "Main",
				Top = 63,
				Main = true,
				Nest = 41.6,
				Yards = {
					{ Y = 25, W = 32, H = 15.5, Belly = 2.6, Strips = 5, Emblem = true },
					{ Y = 40, W = 25, H = 14.3, Belly = 2.0, Strips = 5 },
					{ Y = 55, W = 17, H = 9.6, Belly = 1.4, Strips = 3 },
				},
			},
			{
				Z = 27,
				Base = "QD",
				Top = 52,
				Yards = {
					{ Y = 30, W = 23, H = 12, Belly = 2.3, Strips = 5, Emblem = true },
					{ Y = 42, W = 17, H = 11.2, Belly = 1.7, Strips = 3 },
				},
			},
		},
		Cannons = {
			{ Z = -17, Side = 1 },
			{ Z = -17, Side = -1 },
			{ Z = -7.5, Side = 1 },
			{ Z = -7.5, Side = -1 },
			{ Z = 3, Side = 1 },
			{ Z = 3, Side = -1 },
			{ Z = 11, Side = 1 },
			{ Z = 11, Side = -1 },
		},
		Ports = 5,
		CastleTrim = true,
		Holes = 10,
		Windows = 5,
		UpperWindows = 3,
		Gallery = true,
		QuarterGallery = true,
		Bowsprit = { Heel = 8, Len = 22, Angle = 22, Jib = 10 },
		Capstan = { Z = -27.9, Deck = "FC" },
		Ladder = -12.2,
		Barrels = { { X = -0.74, Z = 16.6 }, { X = 0.74, Z = 16.6 }, { X = -0.72, Z = -37.5 }, { X = 0.72, Z = -37.5 } },
		Crates = { { X = 0.75, Z = -22.8, Stack = 2 }, { X = -0.75, Z = -22.6, Stack = 1 } },
		Hatch = { Z = -12 },
		Hull = rgb(66, 50, 41),
		Figure = rgb(206, 160, 70),
		Wale = rgb(30, 24, 22),
		Bottom = rgb(44, 40, 38),
		Trim = rgb(196, 150, 66),
		Deck = rgb(134, 102, 74),
		Rail = rgb(58, 41, 31),
		Accent = rgb(196, 150, 66),
		Pennant = rgb(130, 28, 26),
	},
}
Ships.Styles = STYLES

-------------------------------------------------------------------------------
-- Hull surface
-------------------------------------------------------------------------------

local function hullGeometry(s: any, L: number, W: number)
	local G = {}
	local deck = s.DeckTop
	local zF = -L / 2 + s.FC.Len
	local zQ = L / 2 - s.QD.Len
	local waistTop = deck + s.Bulwark
	local fcDeck = deck + s.FC.H
	local qdDeck = deck + s.QD.H
	G.zF, G.zQ = zF, zQ
	G.FCDeck, G.QDDeck = fcDeck, qdDeck
	G.WaistTop = waistTop

	-- waist sheer line: a gentle spring, lifting more towards the bow
	function G.base(z: number): number
		local t = clamp(z / (L / 2), -1, 1)
		local y = waistTop + s.Spring * t * t
		if t < 0 then
			y += s.BowSpring * t ^ 4
		end
		return y
	end

	-- full sheer: the castles rise out of the waist line with smooth S-curves
	function G.sheer(z: number): number
		local b = G.base(z)
		local fcTop = fcDeck + s.CastleBulwark
		if z < zF then
			fcTop += s.BowRise * ((zF - z) / s.FC.Len) ^ 2
		end
		local qdTop = qdDeck + s.CastleBulwark
		if z > zQ then
			qdTop += s.SternRise * ((z - zQ) / s.QD.Len) ^ 2
		end
		local wf = smooth((zF + s.BowRamp - z) / s.BowRamp)
		local wq = smooth((z - (zQ - s.SternRamp)) / s.SternRamp)
		return b + math.max(0, fcTop - b) * wf + math.max(0, qdTop - b) * wq
	end

	-- keel line: curves up into the forefoot at the bow and slightly at the stern
	function G.keel(z: number): number
		local t = (z + L / 2) / L
		local y = s.Keel
		if t < s.ForefootT then
			y += (s.StemFoot - s.Keel) * (1 - t / s.ForefootT) ^ 2
		end
		if t > 0.8 then
			y += (s.SternKeel - s.Keel) * ((t - 0.8) / 0.2) ^ 2
		end
		return y
	end

	-- stem and transom profiles as functions of height: raked stem (forefoot further
	-- aft) and a raked counter (transom top further aft)
	local yStemFoot, yStemTop = G.keel(-L / 2), G.sheer(-L / 2)
	local ySternFoot, ySternTop = G.keel(L / 2), G.sheer(L / 2)
	function G.zStem(y: number): number
		local hn = clamp((y - yStemFoot) / (yStemTop - yStemFoot), 0, 1)
		return -L / 2 + s.Rake * (1 - hn) ^ 1.6
	end
	function G.zEnd(y: number): number
		local hn = clamp((y - ySternFoot) / (ySternTop - ySternFoot), 0, 1)
		return L / 2 - s.SternRake * (1 - hn) ^ 1.2
	end

	-- plan shape (fraction of the beam) along the length; hn = height fraction
	function G.plan(u: number, hn: number): number
		if u < s.UB then
			local t = u / s.UB
			local e = 1.6 + 1.0 * hn
			return 1 - (1 - t) ^ e
		elseif u > s.US then
			local t = (u - s.US) / (1 - s.US)
			local tf = lerp(0.3, s.Transom, hn ^ 0.6)
			return 1 - (1 - tf) * t ^ 2
		end
		return 1
	end

	-- cross section: round bilge below the max beam, tumblehome above it
	local ymb = deck - 0.6
	function G.sec(y: number, yk: number): number
		if y >= ymb then
			return math.max(0.62, 1 - s.Tumble * (y - ymb))
		end
		local d = clamp((ymb - y) / math.max(0.5, ymb - yk), 0, 1)
		return 0.1 + 0.9 * math.sqrt(math.max(0, 1 - d ^ 2.2))
	end

	-- height at (u, v) plus the station's keel and sheer
	function G.yAt(u: number, v: number): (number, number, number)
		local z0 = -L / 2 + u * L
		local yk, yb, ys = G.keel(z0), G.base(z0), G.sheer(z0)
		if v <= 1 then
			return yk + (yb - yk) * v, yk, ys
		end
		return yb + (ys - yb) * (v - 1), yk, ys
	end

	-- v of height y at station u
	function G.vAt(u: number, y: number): number
		local z0 = -L / 2 + u * L
		local yk, yb, ys = G.keel(z0), G.base(z0), G.sheer(z0)
		if y <= yb then
			return clamp((y - yk) / (yb - yk), 0, 1)
		end
		if ys - yb < 1e-3 then
			return 1
		end
		return 1 + clamp((y - yb) / (ys - yb), 0, 1)
	end

	function G.point(u: number, v: number, side: number): any
		local y, yk, ys = G.yAt(u, v)
		local hn = clamp((y - yk) / (ys - yk), 0, 1)
		local z = lerp(G.zStem(y), G.zEnd(y), u)
		local x = W / 2 * G.plan(u, hn) * G.sec(y, yk)
		return V(side * x, y, z)
	end

	-- (z, y) -> (u, v)
	function G.solve(z: number, y: number): (number, number)
		local u, v = clamp((z + L / 2) / L, 0, 1), 1
		for _ = 1, 14 do
			v = G.vAt(u, y)
			local yy = G.yAt(u, v)
			local zs, ze = G.zStem(yy), G.zEnd(yy)
			u = clamp((z - zs) / (ze - zs), 0, 1)
		end
		return u, v
	end

	-- outer half breadth of the hull at (z, y)
	function G.halfWidth(z: number, y: number): number
		local u, v = G.solve(z, y)
		return G.point(u, v, 1).X
	end

	-- top of the hull side (sheer) at z
	function G.top(z: number, side: number): any
		return G.point(clamp((z + L / 2) / L, 0, 1), 2, side)
	end

	-- outward horizontal normal of the hull at (u, v)
	function G.normal(u: number, v: number, side: number): any
		local a = G.point(math.max(0, u - 0.01), v, side)
		local b = G.point(math.min(1, u + 0.01), v, side)
		local d = b - a
		local n = V(d.Z, 0, -d.X)
		if n.Magnitude < 1e-4 then
			return V(side, 0, 0)
		end
		n = n.Unit
		if n.X * side < 0 then
			n = n * -1
		end
		return n
	end

	return G
end

-------------------------------------------------------------------------------
-- Part helpers
-------------------------------------------------------------------------------

local function merge(base: { [string]: any }, extra: { [string]: any }?): { [string]: any }
	if extra then
		for k, v in extra do
			base[k] = v
		end
	end
	return base
end

-- Box whose outer face spans the (roughly planar) quad A B (bottom edge, fore->aft)
-- C D (top edge). It is pushed `thick` inward (away from `outward`) and `proud` outward.
local function quadPlank(parent: any, A: any, B: any, C: any, D: any, thick: number, outward: any, proud: number, props: { [string]: any })
	local along = (B + D - A - C) * 0.5
	local upv = (C + D - A - B) * 0.5
	local len = along.Magnitude
	if len < 0.05 then
		return nil
	end
	local Z = along.Unit
	local up = upv - Z * upv:Dot(Z)
	local h = up.Magnitude
	if h < 0.05 then
		return nil
	end
	local Y = up.Unit
	local X = Y:Cross(Z)
	local n = if X:Dot(outward) >= 0 then X else X * -1
	local center = (A + B + C + D) * 0.25 - n * (thick / 2 - proud)
	-- overlap the neighbours just enough to close the gaps a box leaves on a tapered quad
	local spread = math.abs((B - A).Magnitude - (D - C).Magnitude)
	return P.part(parent, merge({
		Size = V(thick, h + 0.14, len + 0.08 + spread * 0.5),
		CFrame = fromMatrix(center, X, Y, Z),
	}, props))
end

-- Greedy polyline simplification: indices of the points to keep so that every dropped
-- point lies within `tol` of the kept segment.
local function simplify(points: { any }, tol: number, maxLen: number): { number }
	local keep = { 1 }
	local n = #points
	local i = 1
	while i < n do
		local j = i + 1
		while j < n do
			local k2 = j + 1
			local a, b = points[i], points[k2]
			local d = b - a
			local len2 = d:Dot(d)
			if math.sqrt(len2) > maxLen then
				break
			end
			local ok = true
			for k = i + 1, j do
				local p = points[k]
				local t = if len2 > 1e-9 then clamp((p - a):Dot(d) / len2, 0, 1) else 0
				if (a + d * t - p).Magnitude > tol then
					ok = false
					break
				end
			end
			if not ok then
				break
			end
			j = k2
		end
		table.insert(keep, j)
		i = j
	end
	return keep
end

-- Adaptive strake segments between v0 and v1: returns {uStart, uEnd} pairs whose box
-- approximates the surface within `tol` and whose height changes by at most `taper`.
local function rowSegments(G: any, us: { number }, v0: (number) -> number, v1: (number) -> number, tol: number, taper: number, twist: number, maxLen: number, exists: ((number) -> boolean)?): { { number } }
	local n = #us
	local b, t, h, on = {}, {}, {}, {}
	for i = 1, n do
		b[i] = G.point(us[i], v0(us[i]), 1)
		t[i] = G.point(us[i], v1(us[i]), 1)
		h[i] = (t[i] - b[i]).Magnitude
		on[i] = if exists then exists(us[i]) else h[i] >= 0.08
	end
	if exists then
		-- grow by one station so a strake starts just before it becomes visible
		local grown = {}
		for i = 1, n do
			grown[i] = on[i] or (i > 1 and on[i - 1]) or (i < n and on[i + 1])
		end
		on = grown
	end
	local out = {}
	local i = 1
	while i < n do
		if not (on[i] and on[i + 1]) then
			i += 1
			continue
		end
		local j = i + 1
		while j < n do
			local k2 = j + 1
			if not on[k2] then
				break
			end
			if (b[k2] - b[i]).Magnitude > maxLen or math.abs(h[k2] - h[i]) > taper then
				break
			end
			-- twist: how far the quad's corners leave the plane of the box face
			local along = (b[k2] + t[k2] - b[i] - t[i]) * 0.5
			local upv = (t[i] + t[k2] - b[i] - b[k2]) * 0.5
			if along.Magnitude > 1e-3 then
				local Z = along.Unit
				local up = upv - Z * upv:Dot(Z)
				if up.Magnitude > 1e-3 then
					local X = up.Unit:Cross(Z)
					local c = (b[i] + b[k2] + t[i] + t[k2]) * 0.25
					local dev = math.max(math.abs((b[i] - c):Dot(X)), math.abs((b[k2] - c):Dot(X)), math.abs((t[i] - c):Dot(X)), math.abs((t[k2] - c):Dot(X)))
					if dev > twist then
						break
					end
				end
			end
			local ok = true
			local span = us[k2] - us[i]
			for k = i + 1, j do
				local f = (us[k] - us[i]) / span
				if (b[i] + (b[k2] - b[i]) * f - b[k]).Magnitude > tol or (t[i] + (t[k2] - t[i]) * f - t[k]).Magnitude > tol then
					ok = false
					break
				end
			end
			if not ok then
				break
			end
			j = k2
		end
		table.insert(out, { us[i], us[j] })
		i = j
	end
	return out
end

local function rope(parent: any, a: any, b: any, d: number?)
	return P.beam(parent, a, b, d or 0.16, { Name = "Rope", Mat = "Fabric", Color = ROPE, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
end

local function deco(props: { [string]: any }): { [string]: any }
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return props
end

local function lantern(parent: any, pos: any, scale: number, light: boolean)
	local body = P.part(parent, deco({ Name = "Lantern", Size = V(0.8, 1.05, 0.8) * scale, CFrame = CF(pos), Mat = "Neon", Color = LAMP }))
	P.part(parent, deco({ Name = "LanternCap", Class = "WedgePart", Size = V(1.05, 0.5, 1.05) * scale, CFrame = CF(pos + V(0, 0.76 * scale, 0)), Mat = "Metal", Color = IRON }))
	if light then
		P.pointLight(body, rgb(255, 182, 100), 16 * scale, 1.4, false)
	end
	return body
end

-------------------------------------------------------------------------------
-- Cannon (contract: Carriage + CannonPrompt + OperatorPoint, Pivot + AimWeld + MuzzleOffset)
-------------------------------------------------------------------------------

local CANNON_PIVOT_Y = 1.35
local CANNON_MUZZLE = 3.3

local function buildCannon(parent: any, s: any)
	local m = P.model(parent, "Cannon")
	local wood = rgb(86, 58, 38)
	local carriage = P.part(m, { Name = "Carriage", Size = V(1.7, 0.5, 2.9), CFrame = CF(0, 0.55, 0.35), Mat = "WoodPlanks", Color = wood })
	for _, x in { -0.72, 0.72 } do
		P.part(m, deco({ Name = "Cheek", Size = V(0.3, 0.85, 2.4), CFrame = CF(x, 1.1, 0.45), Mat = "Wood", Color = shade(wood, 0.86) }))
	end
	for _, z in { -0.6, 1.3 } do
		P.part(m, deco({ Name = "Axle", Shape = "Cylinder", Size = V(2.1, 0.78, 0.78), CFrame = CF(0, 0.39, z), Mat = "Wood", Color = rgb(56, 38, 27) }))
	end
	local pivotCF = CF(0, CANNON_PIVOT_Y, -0.15)
	local pivot = P.part(m, { Name = "Pivot", Size = V(0.3, 0.3, 0.3), CFrame = pivotCF, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local barrel = {
		P.part(m, { Name = "Barrel", Shape = "Cylinder", Size = V(1.9, 1.04, 1.04), CFrame = pivotCF * CF(0, 0, 0.1) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = IRON }),
		P.part(m, { Name = "Chase", Shape = "Cylinder", Size = V(2.3, 0.82, 0.82), CFrame = pivotCF * CF(0, 0, -1.95) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = IRON }),
		P.part(m, { Name = "Muzzle", Shape = "Cylinder", Size = V(0.45, 1.04, 1.04), CFrame = pivotCF * CF(0, 0, -CANNON_MUZZLE + 0.23) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = IRON }),
		P.part(m, { Name = "Breech", Shape = "Ball", Size = V(0.66, 0.66, 0.66), CFrame = pivotCF * CF(0, 0, 1.15), Mat = "Metal", Color = IRON }),
	}
	for _, part in barrel do
		part.CanCollide = false
		P.weld(pivot, part)
	end
	P.weld(carriage, pivot, "AimWeld")
	pivot:SetAttribute("MuzzleOffset", CANNON_MUZZLE)
	P.attachment(carriage, "OperatorPoint", CF(0, 0, 3.05))
	P.attachment(pivot, "Muzzle", pivotCF * CF(0, 0, -CANNON_MUZZLE))
	P.prompt(carriage, { Name = "CannonPrompt", ActionText = "Use Cannon", ObjectText = "Cannon", MaxActivationDistance = 7 })
	return m
end

-------------------------------------------------------------------------------
-- Sails: vertical strips that bow forward (see build/CONTRACTS.md)
-------------------------------------------------------------------------------

local SAIL_GAP = 0.45
local SAIL_THICK = 0.26

local function buildSail(folder: any, yard: any, y: any, mastIndex: number, yardIndex: number)
	local width, height, belly = y.W, y.H, y.Belly * 1.25
	-- a wide flat centre cloth (carries the emblem) and side cloths curving aft
	local fr = if y.Strips >= 5 then { -0.5, -0.35, -0.19, 0.19, 0.35, 0.5 } else { -0.5, -0.22, 0.22, 0.5 }
	local flat = if y.Strips >= 5 then 0.19 else 0.22
	local function zAt(x: number): number
		local t = clamp((math.abs(x) / width - flat) / (0.5 - flat), 0, 1)
		return -0.5 - belly * (1 - t ^ 1.7)
	end
	local pts = {}
	for i, f in fr do
		local x = f * width
		pts[i] = V(x, 0, zAt(x))
	end
	local centerWidth, centerZ, centerH = 0, 0, height
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local mid = (a + b) * 0.5
		local d = b - a
		local yaw = math.atan2(-d.Z, d.X)
		local edge = math.abs(mid.X) / (width / 2)
		-- the foot curves up a little in the middle
		local h = height * (1 - 0.05 * (1 - edge ^ 1.5))
		local c0 = CF(mid.X, -(SAIL_GAP + h / 2), mid.Z) * Angles(0, yaw, 0)
		local sail = P.part(folder, {
			Name = "Sail",
			Size = V(d.Magnitude + 0.12, h, SAIL_THICK),
			CFrame = yard.CFrame * c0,
			Mat = "Fabric",
			Color = shade(SAIL_BLACK, 1 + 0.08 * (hash(mastIndex, yardIndex, i) - 0.5)),
			CanCollide = false,
			CanQuery = true,
			CanTouch = false,
		})
		sail:SetAttribute("FullHeight", h)
		sail:SetAttribute("Gap", SAIL_GAP)
		sail:SetAttribute("XOffset", mid.X)
		sail:SetAttribute("ZOffset", mid.Z)
		sail:SetAttribute("SailYaw", yaw)
		P.weld(yard, sail, "SailWeld")
		if math.abs(mid.X) < 0.01 then
			centerWidth, centerZ, centerH = d.Magnitude, mid.Z, h
		end
	end
	if y.Emblem then
		-- transparent emblem plate through the centre cloth (symbols are added by the server)
		local he = math.min(centerH * 0.62, centerWidth * 0.95)
		local gap = SAIL_GAP + (centerH - he) / 2
		local emblem = P.part(folder, {
			Name = "SailEmblem",
			Size = V(centerWidth * 0.95, he, SAIL_THICK + 0.12),
			CFrame = yard.CFrame * CF(0, -(gap + he / 2), centerZ),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		emblem:SetAttribute("FullHeight", he)
		emblem:SetAttribute("Gap", gap)
		emblem:SetAttribute("XOffset", 0)
		emblem:SetAttribute("ZOffset", centerZ)
		P.weld(yard, emblem, "SailWeld")
	end
end

-------------------------------------------------------------------------------
-- Ship
-------------------------------------------------------------------------------

function Ships.Build(id: string, def: any)
	local s = STYLES[id]
	local L, W = def.Length, def.Width
	local G = hullGeometry(s, L, W)
	local model = P.model(nil, id)
	local deckTop = s.DeckTop
	local zF, zQ = G.zF, G.zQ
	local fcDeck, qdDeck = G.FCDeck, G.QDDeck
	local big = L > 70

	local root = P.part(model, {
		Name = "Root",
		Size = V(W * 0.6, 1, L * 0.6),
		CFrame = CF(0, 0, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	model.PrimaryPart = root

	local hull = P.folder(model, "Hull")
	local decks = P.folder(model, "Decks")
	local railings = P.folder(model, "Railings")
	local fittings = P.folder(model, "Fittings")
	local rigging = P.folder(model, "Rigging")
	local sails = P.folder(model, "Sails")
	local cannons = P.folder(model, "Cannons")
	P.folder(model, "Cargo")
	P.folder(model, "Holes")

	-- obstacles on the decks (for hole spots): { x, z, radius }
	local blocked: { { number } } = {}
	local function block(x: number, z: number, r: number)
		table.insert(blocked, { x, z, r })
	end

	---------------------------------------------------------------------------
	-- Hull planking
	---------------------------------------------------------------------------
	-- candidate stations: denser towards the bow and stern; the staggered set is used
	-- on every other strake so the plank butts do not line up
	local N_FINE = 64
	local fineA, fineB = {}, { 0 }
	for i = 0, N_FINE do
		local t = i / N_FINE
		fineA[i + 1] = 0.45 * t + 0.55 * (1 - math.cos(t * math.pi)) / 2
	end
	for i = 1, N_FINE do
		table.insert(fineB, (fineA[i] + fineA[i + 1]) / 2)
	end
	table.insert(fineB, 1)

	-- lower hull strakes are fractions of keel..waist line; castle strakes hang from the
	-- sheer with a constant height and are clipped by the waist line
	local rows = {}
	local function constV(v: number): (number) -> number
		return function(_u: number): number
			return v
		end
	end
	for r = 1, #s.Rows - 1 do
		local v0 = if r == 1 then 0 else (s.Rows[r] - s.Keel) / (G.WaistTop - s.Keel)
		local v1 = if r == #s.Rows - 1 then 1 else (s.Rows[r + 1] - s.Keel) / (G.WaistTop - s.Keel)
		table.insert(rows, { V0 = constV(v0), V1 = constV(v1), Kind = s.Kinds[r] })
	end
	-- castle strakes: constant-height bands hanging from the sheer. Where a band reaches
	-- below the waist line it tucks (slightly recessed) behind the lower strakes, so the
	-- castles need no tapered slivers.
	local maxCastle = 0
	for k = 0, 100 do
		local z = lerp(-L / 2, L / 2, k / 100)
		maxCastle = math.max(maxCastle, G.sheer(z) - G.base(z))
	end
	local hr = s.CastleRowH
	local nCastle = math.ceil(maxCastle / hr - 0.05)
	local function castleV(depth: number): (number) -> number
		return function(u: number): number
			return G.vAt(u, G.sheer(-L / 2 + u * L) - depth)
		end
	end
	for k = 1, nCastle do
		local top = (k - 1) * hr
		table.insert(rows, {
			V0 = castleV(k * hr),
			V1 = castleV(top),
			Kind = "castle",
			Recess = 0.25,
			Exists = function(u: number): boolean
				local z0 = -L / 2 + u * L
				return G.sheer(z0) - G.base(z0) > top + 0.06
			end,
		})
	end

	local function rowColor(kind: string, r: number, i: number, side: number): any
		local base = if kind == "bottom" then s.Bottom elseif kind == "wale" then s.Wale else s.Hull
		if kind == "castle" and r == #s.Rows then
			base = shade(s.Wale, 1.35)
		end
		local k = 1 + 0.16 * (hash(r, 3.1, 0.7) - 0.5) + 0.05 * (hash(r, i, side) - 0.5)
		return shade(base, k)
	end

	for r, row in rows do
		local kind = row.Kind
		local us = if r % 2 == 0 then fineB else fineA
		local bottom = kind == "bottom"
		local tol = if bottom then 0.7 elseif kind == "castle" and r > #s.Rows then 0.28 else 0.2
		local taper = if bottom then 2.5 elseif kind == "castle" then 0.65 else 0.5
		local segs = rowSegments(G, us, row.V0, row.V1, tol, taper, if bottom then 0.5 else 0.08, if bottom then 40 else 26, row.Exists)
		local thick = if kind == "wale" then 0.85 else 0.6
		local proud = if kind == "wale" then 0.22 else -(row.Recess or 0)
		for i, seg in segs do
			local ua, ub = seg[1], seg[2]
			for _, side in { -1, 1 } do
				local A, B = G.point(ua, row.V0(ua), side), G.point(ub, row.V0(ub), side)
				local C, D = G.point(ua, row.V1(ua), side), G.point(ub, row.V1(ub), side)
				quadPlank(hull, A, B, C, D, thick, V(side, 0, 0), proud, {
					Name = if kind == "wale" then "Wale" else "Strake",
					Mat = "WoodPlanks",
					Color = rowColor(kind, r, i, side),
					CanCollide = not bottom,
				})
			end
		end
		-- transom strake
		if not row.Exists or row.Exists(1) then
			local A, B = G.point(1, row.V0(1), -1), G.point(1, row.V0(1), 1)
			local C, D = G.point(1, row.V1(1), -1), G.point(1, row.V1(1), 1)
			quadPlank(hull, A, B, C, D, 0.6, V(0, 0, 1), proud, {
				Name = "Transom",
				Mat = "WoodPlanks",
				Color = rowColor(kind, r, 99, 0),
				CanCollide = not bottom,
			})
		end
	end

	-- fine polyline along a hull line (u from 0 to 1 at fixed v)
	local function hullLine(v: number, side: number, offset: number?): { any }
		local pts = {}
		for i, u in fineA do
			local p = G.point(u, v, side)
			if offset then
				p = p + G.normal(u, v, side) * offset
			end
			pts[i] = p
		end
		return pts
	end

	-- rail cap along the sheer and a trim line just below the waist rail
	local vTrim = (G.WaistTop - 0.6 - s.Keel) / (G.WaistTop - s.Keel)
	for _, side in { -1, 1 } do
		local top = hullLine(2, side)
		local keep = simplify(top, 0.15, 30)
		for k = 1, #keep - 1 do
			local a, b = top[keep[k]], top[keep[k + 1]]
			local inA = V(-side * 0.3, 0.15, 0)
			P.plank(hull, a + inA, b + inA, 1.0, 0.46, { Name = "RailCap", Mat = "Wood", Color = s.Rail })
		end
		local trim = hullLine(vTrim, side, 0.26)
		keep = simplify(trim, 0.18, 36)
		for k = 1, #keep - 1 do
			P.plank(hull, trim[keep[k]], trim[keep[k + 1]], 0.2, 0.28, deco({ Name = "Trim", Mat = "Metal", Color = s.Trim }))
		end
	end
	-- moulding along the top of the castles, just under the rail
	for _, side in if s.CastleTrim then { -1, 1 } else {} do
		local run = {}
		local function flush()
			if #run >= 2 then
				local keep = simplify(run, 0.15, 30)
				for k = 1, #keep - 1 do
					P.plank(hull, run[keep[k]], run[keep[k + 1]], 0.2, 0.24, deco({ Name = "CastleTrim", Mat = "Metal", Color = s.Trim }))
				end
			end
			run = {}
		end
		for _, u in fineA do
			local z0 = -L / 2 + u * L
			local ch = G.sheer(z0) - G.base(z0)
			if ch > 1.2 then
				local v = 2 - 0.62 / ch
				table.insert(run, G.point(u, v, side) + G.normal(u, v, side) * -0.12)
			else
				flush()
			end
		end
		flush()
	end
	-- taffrail cap across the stern
	do
		local a, b = G.point(1, 2, -1), G.point(1, 2, 1)
		P.plank(hull, a + V(0, 0.15, -0.3), b + V(0, 0.15, -0.3), 1.0, 0.46, { Name = "RailCap", Mat = "Wood", Color = s.Rail })
	end

	-- stem (cutwater) rising into the beakhead, and the keel
	-- (wide enough to hide where the planking of both bows meets)
	local stemPts = {}
	for i = 0, 16 do
		local p = G.point(0, i / 8, 1)
		table.insert(stemPts, V(0, p.Y, p.Z + 0.1))
	end
	local stemTop = stemPts[#stemPts] + V(0, 0.8, -1.1)
	table.insert(stemPts, stemTop)
	do
		local keep = simplify(stemPts, 0.07, 30)
		for k = 1, #keep - 1 do
			local a, b = stemPts[keep[k]], stemPts[keep[k + 1]]
			P.plank(hull, a, b, 1.3, 2.1, { Name = "Stem", Mat = "Wood", Color = shade(s.Wale, 1.2), CanCollide = false })
		end
		local keelPts = {}
		for i, u in fineA do
			local p = G.point(u, 0, 1)
			keelPts[i] = V(0, p.Y - 0.35, p.Z)
		end
		keep = simplify(keelPts, 0.15, 60)
		for k = 1, #keep - 1 do
			P.plank(hull, keelPts[keep[k]], keelPts[keep[k + 1]], 0.9, 0.8, { Name = "Keel", Mat = "Wood", Color = s.Wale, CanCollide = false })
		end
	end
	-- rudder on the sternpost
	do
		local bottom = G.point(1, 0, 1)
		local top = G.point(1, G.vAt(1, deckTop + 0.8), 1)
		local a = V(0, bottom.Y - 0.3, bottom.Z + 1.0)
		local b = V(0, top.Y, top.Z + 0.9)
		P.plank(hull, a, b, 0.7, 2.4, { Name = "Rudder", Mat = "WoodPlanks", Color = s.Wale, CanCollide = false })
		P.plank(hull, b - V(0, 0.4, 0.6), b + V(0, -0.4, 1.4), 0.5, 0.5, { Name = "RudderHead", Mat = "Wood", Color = s.Wale, CanCollide = false })
	end

	---------------------------------------------------------------------------
	-- Decks
	---------------------------------------------------------------------------
	local function hwIn(z: number, y: number): number
		return G.halfWidth(z, y) - 0.45
	end

	local function deckRun(name: string, z0: number, z1: number, yTop: number, laneW: number)
		local y = yTop - 0.2
		-- lanes: full-length planks running fore/aft where the hull is wide enough
		local hwMax = 0
		for k = 0, 20 do
			hwMax = math.max(hwMax, hwIn(lerp(z0, z1, k / 20), yTop))
		end
		local nLanes = math.max(1, math.floor(2 * hwMax / laneW))
		local x0 = -nLanes * laneW / 2
		for j = 1, nLanes do
			local xa, xb = x0 + (j - 1) * laneW, x0 + j * laneW
			local need = math.max(math.abs(xa), math.abs(xb))
			local samples = 40
			local za, zb = nil, nil
			for k = 0, samples do
				local z = lerp(z0, z1, k / samples)
				if hwIn(z, yTop) >= need then
					za = za or z
					zb = z
				end
			end
			if za and zb and zb - za > 0.5 then
				local step = (z1 - z0) / samples
				local lo = math.max(z0, za - step)
				for _ = 1, 8 do
					local mid = (lo + za) / 2
					if hwIn(mid, yTop) >= need then
						za = mid
					else
						lo = mid
					end
				end
				local hi = math.min(z1, zb + step)
				for _ = 1, 8 do
					local mid = (zb + hi) / 2
					if hwIn(mid, yTop) >= need then
						zb = mid
					else
						hi = mid
					end
				end
				local tone = 1 + 0.14 * (hash(j, yTop, 5) - 0.5)
				P.part(decks, {
					Name = name,
					Size = V(xb - xa + 0.02, 0.4, zb - za),
					CFrame = CF((xa + xb) / 2, y, (za + zb) / 2),
					Mat = "WoodPlanks",
					Color = shade(s.Deck, tone),
				})
			end
		end
		-- waterways: planks following the hull side, covering the stepped lane ends
		local wW = laneW + 0.5
		local edge = {}
		local nE = math.max(4, math.ceil((z1 - z0) / 0.75))
		for k = 0, nE do
			local z = lerp(z0, z1, k / nE)
			table.insert(edge, V(math.max(0.3, hwIn(z, yTop) - wW / 2), 0, z))
		end
		local keep = simplify(edge, 0.4, 36)
		for _, side in { -1, 1 } do
			for k = 1, #keep - 1 do
				local a, b = edge[keep[k]], edge[keep[k + 1]]
				local width = math.min(wW, 2 * math.min(hwIn(a.Z, yTop), hwIn(b.Z, yTop)) + 0.4)
				P.plank(decks, V(side * a.X, y + 0.02, a.Z), V(side * b.X, y + 0.02, b.Z), width, 0.4, {
					Name = "Waterway",
					Mat = "WoodPlanks",
					Color = shade(s.Deck, 0.8),
				})
			end
		end
	end

	local _, vTop = G.solve(-L / 2, fcDeck)
	local fcStart = G.point(0, vTop, 1).Z + 0.9
	local _, vQ = G.solve(L / 2, qdDeck)
	local qdEnd = G.point(1, vQ, 1).Z - 0.55
	deckRun("Deck", zF - 0.1, zQ + 0.1, deckTop, s.LaneW)
	deckRun("ForecastleDeck", fcStart, zF + 0.55, fcDeck, s.LaneW)
	deckRun("QuarterDeck", zQ - 0.55, qdEnd, qdDeck, s.LaneW)

	-- bulkheads (castle front walls) with doors and lanterns
	local function bulkhead(zWall: number, dir: number, yTopDeck: number, stairW: number, cabin: boolean)
		-- dir = direction from the waist into the castle (+1 = towards stern)
		local h = yTopDeck - deckTop
		local hw = math.min(hwIn(zWall, deckTop), hwIn(zWall, yTopDeck)) + 0.15
		local z = zWall + dir * 0.3
		P.part(decks, { Name = "Bulkhead", Size = V(hw * 2, h, 0.6), CFrame = CF(0, deckTop + h / 2, z), Mat = "WoodPlanks", Color = shade(s.Hull, 1.2) })
		-- beam under the castle edge
		P.part(decks, deco({ Name = "BreakBeam", Size = V(hw * 2, 0.5, 0.7), CFrame = CF(0, yTopDeck - 0.6, zWall - dir * 0.1), Mat = "Wood", Color = s.Rail }))
		if h >= 2.8 then
			local doorH = math.min(h - 0.6, 3.6)
			for _, side in { -1, 1 } do
				local x = side * (stairW / 2 + (hw - stairW / 2) * 0.38)
				P.part(decks, deco({ Name = "DoorFrame", Size = V(2.3, doorH + 0.25, 0.3), CFrame = CF(x, deckTop + (doorH + 0.25) / 2, z - dir * 0.35), Mat = "Wood", Color = s.Rail }))
				P.part(decks, deco({ Name = "Door", Size = V(1.8, doorH, 0.3), CFrame = CF(x, deckTop + doorH / 2, z - dir * 0.45), Mat = "WoodPlanks", Color = shade(s.Wale, 1.3) }))
				if cabin then
					-- lit cabin window further out
					local wx = side * (stairW / 2 + (hw - stairW / 2) * 0.76)
					P.part(decks, deco({ Name = "WindowFrame", Size = V(1.9, 1.6, 0.3), CFrame = CF(wx, deckTop + doorH - 1.0, z - dir * 0.35), Mat = "Wood", Color = s.Rail }))
					P.part(decks, deco({ Name = "Window", Size = V(1.4, 1.1, 0.3), CFrame = CF(wx, deckTop + doorH - 1.0, z - dir * 0.42), Mat = "Neon", Color = LAMP }))
				end
				if side == 1 or cabin then
					local lampPos = V(x + side * 1.75, deckTop + doorH - 0.2, z - dir * 0.75)
					lantern(fittings, lampPos, 0.8, side == 1)
				end
			end
		end
	end
	bulkhead(zF, -1, fcDeck, s.StairW, false)
	bulkhead(zQ, 1, qdDeck, s.StairW, s.QD.H >= 4)

	-- stairs: invisible collidable ramp + visual steps + handrails
	local function stairs(zTop: number, dir: number, h: number, run: number, width: number)
		-- dir = +1 when the stairs climb towards +Z
		local zMid = zTop - dir * run / 2
		P.part(decks, {
			Class = "WedgePart",
			Name = "StairRamp",
			Size = V(width, h, run),
			CFrame = CF(0, deckTop + h / 2, zMid) * (if dir > 0 then CF() else Angles(0, math.pi, 0)),
			Transparency = 1,
			Mat = "WoodPlanks",
			Color = s.Deck,
		})
		local n = math.max(2, math.ceil(h / 1.0))
		local rise, tread = h / n, run / n
		for k = 1, n do
			local yTop = deckTop + k * rise
			local zc = zTop - dir * (run - (k - 0.5) * tread)
			P.part(decks, deco({ Name = "Step", Size = V(width - 0.5, 0.3, tread + 0.25), CFrame = CF(0, yTop - 0.15, zc), Mat = "WoodPlanks", Color = shade(s.Deck, 0.95 + 0.1 * hash(k, h, 1)) }))
		end
		for _, side in { -1, 1 } do
			local x = side * (width / 2 - 0.15)
			P.plank(decks, V(x, deckTop + 0.1, zTop - dir * run), V(x, deckTop + h - 0.2, zTop), 0.3, 0.8, deco({ Name = "Stringer", Mat = "Wood", Color = s.Rail }))
			if h > 2 then
				P.pillar(railings, x, zTop - dir * (run - 0.3), deckTop, deckTop + 2.7, 0.36, deco({ Name = "Newel", Mat = "Wood", Color = s.Rail }))
				P.plank(railings, V(x, deckTop + 2.6, zTop - dir * (run - 0.3)), V(x, deckTop + h + 2.6, zTop + dir * 0.35), 0.25, 0.25, { Name = "HandRail", Mat = "Wood", Color = s.Rail, CanCollide = false })
			end
		end
		for t = 0, run, 1.2 do
			block(0, zTop - dir * t, width / 2 + 1.3)
		end
	end
	stairs(zF, -1, s.FC.H, s.FC.Stair, s.StairW)
	stairs(zQ, 1, s.QD.H, s.QD.Stair, s.StairW)

	---------------------------------------------------------------------------
	-- Railings (balustrades) along the castle fronts and the stern
	---------------------------------------------------------------------------
	local RAIL_H = 1.5
	local function balustrade(a: any, b: any, spacing: number, height: number, posts: boolean)
		-- a, b = bottom line; rail on top
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / spacing + 0.5))
		for k = 0, n do
			local p = a + (b - a) * (k / n)
			local isPost = posts and (k == 0 or k == n)
			-- collidable so nobody slips between the balusters off a castle edge
			P.pillar(railings, p.X, p.Z, p.Y, p.Y + height + (if isPost then 0.45 else 0), if isPost then 0.42 else 0.24, {
				Name = if isPost then "Post" else "Baluster",
				Mat = "Wood",
				Color = if isPost then s.Rail else shade(s.Rail, 1.3),
				CanQuery = false,
				CanTouch = false,
			})
		end
		P.plank(railings, a + V(0, height, 0), b + V(0, height, 0), 0.4, 0.3, { Name = "Rail", Mat = "Wood", Color = s.Rail })
	end

	-- breast rails along the castle edges (gap for the stairs)
	local function breastRail(zEdge: number, yDeck: number, stairW: number)
		local hw = hwIn(zEdge, yDeck + 1) - 0.1
		for _, side in { -1, 1 } do
			local a = V(side * (stairW / 2), yDeck, zEdge)
			local b = V(side * hw, yDeck, zEdge)
			balustrade(a, b, 1.6, RAIL_H + 0.5, true)
		end
	end
	if s.FC.H > 2 then
		breastRail(zF + 0.3, fcDeck, s.StairW)
	end
	breastRail(zQ - 0.3, qdDeck, s.StairW)

	---------------------------------------------------------------------------
	-- Stern: windows, gallery, lanterns, quarter galleries
	---------------------------------------------------------------------------
	local function transomAt(y: number): (number, number)
		-- z of the transom face and half width at height y
		local p = G.point(1, G.vAt(1, y), 1)
		return p.Z, p.X
	end
	do
		local wy1 = qdDeck - 0.8
		local wy0 = math.max(deckTop + 1.1, wy1 - 2.8)
		local wh = wy1 - wy0
		local wyc = (wy0 + wy1) / 2
		local zt, hwT = transomAt(wyc)
		local n = s.Windows
		local span = hwT * 1.45
		local winW = math.min(2.0, span / n * 0.62)
		for i = 1, n do
			local x = if n == 1 then 0 else lerp(-span / 2, span / 2, (i - 1) / (n - 1))
			P.part(fittings, deco({ Name = "WindowFrame", Size = V(winW + 0.5, wh + 0.5, 0.36), CFrame = CF(x, wyc, zt + 0.12), Mat = "Wood", Color = s.Wale }))
			local glass = P.part(fittings, deco({ Name = "Window", Size = V(winW, wh, 0.3), CFrame = CF(x, wyc, zt + 0.22), Mat = "Neon", Color = LAMP }))
			if i == math.ceil(n / 2) then
				P.pointLight(glass, rgb(255, 170, 90), 14, 1.2, false)
			end
		end
		-- cornice above the windows
		local zc, hwc = transomAt(wy1 + 0.45)
		P.part(fittings, deco({ Name = "Cornice", Size = V(hwc * 2 - 0.6, 0.35, 0.5), CFrame = CF(0, wy1 + 0.45, zc + 0.15), Mat = "Metal", Color = s.Trim }))
		if s.Gallery then
			local gy = wy0 - 0.35
			local zg, hwg = transomAt(gy)
			local depth = 1.7
			P.part(fittings, { Name = "Gallery", Size = V(hwg * 2 - 0.4, 0.35, depth), CFrame = CF(0, gy, zg + depth / 2), Mat = "WoodPlanks", Color = s.Rail })
			local a = V(-(hwg - 0.4), gy + 0.17, zg + depth - 0.2)
			local b = V(hwg - 0.4, gy + 0.17, zg + depth - 0.2)
			balustrade(a, b, 1.1, 1.15, true)
		end
		-- carved board on the taffrail, and small lit windows of the upper stern
		local yt = G.point(1, 2, 1).Y - 0.75
		local zb, hwb = transomAt(yt)
		P.part(fittings, deco({ Name = "TaffrailBoard", Size = V(hwb * 1.4, 0.9, 0.3), CFrame = CF(0, yt, zb + 0.2), Mat = "Metal", Color = s.Trim }))
		local nUp = s.UpperWindows or 0
		if nUp > 0 then
			local uy = qdDeck + 1.6
			local zu, hwu = transomAt(uy)
			for i = 1, nUp do
				local x = if nUp == 1 then 0 else lerp(-hwu * 0.5, hwu * 0.5, (i - 1) / (nUp - 1))
				P.part(fittings, deco({ Name = "WindowFrame", Size = V(1.7, 1.9, 0.36), CFrame = CF(x, uy, zu + 0.12), Mat = "Wood", Color = s.Wale }))
				P.part(fittings, deco({ Name = "Window", Size = V(1.15, 1.35, 0.3), CFrame = CF(x, uy, zu + 0.2), Mat = "Neon", Color = LAMP }))
			end
		end
	end
	-- stern lanterns
	do
		local a = G.point(1, 2, 1)
		for _, side in { -1, 1 } do
			local base = V(side * (a.X - 0.4), a.Y + 0.35, a.Z - 0.3)
			P.beam(fittings, base, base + V(side * 0.6, 2.4, 0.9), 0.24, deco({ Name = "LanternArm", Mat = "Metal", Color = IRON }))
			lantern(fittings, base + V(side * 0.6, 1.8, 0.9), 1.05, true)
		end
		if big then
			local base = V(0, a.Y + 0.35, a.Z + 0.3)
			P.pillar(fittings, base.X, base.Z, base.Y, base.Y + 3.2, 0.3, deco({ Name = "LanternPost", Mat = "Metal", Color = IRON }))
			lantern(fittings, base + V(0, 3.8, 0), 1.35, true)
		end
	end
	-- quarter galleries (little window boxes on the hull sides near the stern)
	if s.QuarterGallery then
		local len = s.QD.Len * 0.26
		local zg = L / 2 - len / 2 - 1.2
		local y1 = qdDeck - 0.2
		local y0 = math.max(deckTop + 0.4, y1 - 3.4)
		local yc = (y0 + y1) / 2
		local depth = 1.3
		for _, side in { -1, 1 } do
			local hw = G.halfWidth(zg, yc) - 0.3
			local function at(dx: number, y: number, dz: number?): any
				return CF(side * (hw + dx), y, zg + (dz or 0))
			end
			P.part(fittings, deco({ Name = "QuarterGallery", Size = V(depth, y1 - y0, len), CFrame = at(depth / 2, yc), Mat = "WoodPlanks", Color = shade(s.Hull, 0.9) }))
			-- roof sloping down outboard, and a tapering drop below
			P.part(fittings, deco({ Class = "WedgePart", Name = "GalleryRoof", Size = V(len + 0.4, 1.0, depth + 0.5), CFrame = at(depth / 2 + 0.1, y1 + 0.5) * Angles(0, -side * math.pi / 2, 0), Mat = "WoodPlanks", Color = s.Wale }))
			P.part(fittings, deco({ Class = "WedgePart", Name = "GalleryDrop", Size = V(len - 0.4, 1.6, depth), CFrame = at(depth / 2, y0 - 0.8) * Angles(0, side * math.pi / 2, 0) * Angles(math.pi, 0, 0), Mat = "WoodPlanks", Color = s.Wale }))
			P.part(fittings, deco({ Name = "GalleryTrim", Size = V(depth + 0.2, 0.3, len + 0.2), CFrame = at(depth / 2 + 0.05, y1 - 0.1), Mat = "Metal", Color = s.Trim }))
			P.part(fittings, deco({ Name = "Window", Size = V(0.2, (y1 - y0) * 0.55, len * 0.62), CFrame = at(depth + 0.02, yc + 0.1), Mat = "Neon", Color = LAMP }))
			P.part(fittings, deco({ Name = "Mullion", Size = V(0.25, (y1 - y0) * 0.6, 0.2), CFrame = at(depth + 0.06, yc + 0.1), Mat = "Wood", Color = s.Wale }))
		end
	end

	---------------------------------------------------------------------------
	-- Bow: bowsprit, jib boom, figurehead, head rails, catheads, anchor, capstan
	---------------------------------------------------------------------------
	local bs = s.Bowsprit
	local dirB = V(0, math.sin(math.rad(bs.Angle)), -math.cos(math.rad(bs.Angle)))
	local bowZ = G.point(0, 2, 1).Z
	local heel = V(0, fcDeck + 0.6, bowZ + bs.Heel)
	-- the bowsprit passes just over the stem head
	local tHead = (stemTop.Z - heel.Z) / dirB.Z
	local over = heel + dirB * tHead
	heel = heel + V(0, math.max(0, stemTop.Y + 0.45 - over.Y), 0)
	local spritEnd = heel + dirB * (tHead + bs.Len)
	local spritD = if big then 1.3 else 1.0
	P.beam(fittings, heel, spritEnd, spritD, { Name = "Bowsprit", Mat = "Wood", Color = SPAR, CanCollide = false })
	P.part(fittings, deco({ Name = "Bitts", Size = V(2.2, 1.2, 0.6), CFrame = CF(heel + V(0, -0.1, 0.4)), Mat = "Wood", Color = s.Rail }))
	local jibStart = spritEnd - dirB * 3
	local jibEnd = spritEnd + dirB * bs.Jib
	local jibUp = V(0, spritD * 0.55, 0)
	P.beam(fittings, jibStart + jibUp, jibEnd + jibUp, spritD * 0.55, deco({ Name = "JibBoom", Mat = "Wood", Color = SPAR }))
	P.part(fittings, deco({ Name = "BowspritCap", Size = V(spritD + 0.4, spritD * 1.9, 0.6), CFrame = P.lookAt(spritEnd, spritEnd + dirB) * CF(0, spritD * 0.3, 0), Mat = "Wood", Color = s.Wale }))
	jibEnd = jibEnd + jibUp
	-- figurehead under the bowsprit
	do
		local head = stemTop + V(0, -1.7, -0.8)
		P.plank(fittings, stemTop + V(0, -0.2, 0.2), head, 0.8, 1.0, deco({ Name = "Figurehead", Mat = "Metal", Color = s.Figure }))
		P.part(fittings, deco({ Name = "FigureheadHead", Shape = "Ball", Size = V(1.15, 1.15, 1.15), CFrame = CF(head + V(0, 0.25, -0.2)), Mat = "Metal", Color = s.Figure }))
		for _, side in { -1, 1 } do
			P.plank(fittings, head + V(0, 0.1, 0.4), head + V(side * 1.3, 0.9, 1.6), 0.25, 0.7, deco({ Name = "FigureheadWing", Mat = "Metal", Color = s.Figure }))
		end
	end
	-- bobstay
	rope(rigging, spritEnd, G.point(0, 0.35, 1) + V(0, 0, -0.4), 0.2)

	-- catheads + anchor (starboard)
	local zCat = bowZ + s.FC.Len * 0.42
	local catTop = G.top(zCat, 1)
	local catY = catTop.Y - 0.5
	local mountCF = CF()
	for _, side in { -1, 1 } do
		local hw = G.halfWidth(zCat, catY)
		local a = V(side * (hw - 1.2), catY, zCat)
		local b = V(side * (hw + 1.6), catY + 0.3, zCat - 0.6)
		P.plank(fittings, a, b, 0.7, 0.7, { Name = "Cathead", Mat = "Wood", Color = s.Wale, CanCollide = false })
		if side == 1 then
			mountCF = CF(b + V(0.1, -0.5, 0))
		end
	end
	local mount = P.part(fittings, deco({ Name = "AnchorMount", Size = V(0.5, 0.5, 0.5), CFrame = mountCF, Mat = "Metal", Color = IRON }))
	do
		local anchorModel = P.model(fittings, "Anchor")
		local top = mountCF * CF(0, -0.6, 0)
		local anchorRoot = P.part(anchorModel, { Name = "AnchorRoot", Size = V(0.3, 0.3, 0.3), CFrame = top, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local shankLen = if big then 5.0 elseif L > 50 then 4.2 else 3.4
		local a = {
			P.part(anchorModel, { Name = "Ring", Shape = "Cylinder", Size = V(0.2, 0.9, 0.9), CFrame = top * CF(0, -0.2, 0) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = IRON }),
			P.part(anchorModel, { Name = "Stock", Size = V(0.4, 0.4, shankLen * 0.75), CFrame = top * CF(0, -0.8, 0), Mat = "Wood", Color = SPAR }),
			P.part(anchorModel, { Name = "Shank", Size = V(0.45, shankLen, 0.45), CFrame = top * CF(0, -0.6 - shankLen / 2, 0), Mat = "Metal", Color = IRON }),
		}
		local crown = top * CF(0, -0.6 - shankLen, 0)
		for _, dz in { -1, 1 } do
			local arm = crown * CF(0, 0.75, dz * 0.95) * Angles(dz * math.rad(-50), 0, 0)
			table.insert(a, P.part(anchorModel, { Name = "Arm", Size = V(0.42, 2.4, 0.42), CFrame = arm, Mat = "Metal", Color = IRON }))
			table.insert(a, P.part(anchorModel, { Class = "WedgePart", Name = "Fluke", Size = V(0.3, 1.1, 0.9), CFrame = crown * CF(0, 1.6, dz * 1.75) * Angles(0, if dz > 0 then 0 else math.pi, 0), Mat = "Metal", Color = IRON }))
		end
		for _, part in a do
			part.CanCollide = false
			part.CanQuery = false
			P.weld(anchorRoot, part)
		end
		P.weld(mount, anchorRoot, "AnchorWeld")
	end

	-- capstan
	do
		local zCap = s.Capstan.Z
		local y0 = if s.Capstan.Deck == "FC" then fcDeck else deckTop
		local capstan = P.pillar(fittings, 0, zCap, y0, y0 + 1.7, 1.9, { Name = "Capstan", Mat = "Wood", Color = rgb(108, 74, 48) })
		P.pillar(fittings, 0, zCap, y0, y0 + 0.35, 2.5, deco({ Name = "CapstanBase", Mat = "Wood", Color = s.Rail }))
		P.pillar(fittings, 0, zCap, y0 + 1.7, y0 + 2.05, 2.3, deco({ Name = "CapstanTop", Mat = "Metal", Color = s.Trim }))
		for i = 0, 1 do
			P.part(fittings, deco({ Name = "CapstanBar", Size = V(4.6, 0.26, 0.26), CFrame = CF(0, y0 + 1.5, zCap) * Angles(0, i * math.pi / 2 + math.pi / 4, 0), Mat = "Wood", Color = SPAR }))
		end
		P.prompt(capstan, { Name = "AnchorPrompt", ActionText = "Raise Anchor", ObjectText = "Anchor", HoldDuration = 1.0, MaxActivationDistance = 8 })
		if y0 == deckTop then
			block(0, zCap, 3.2)
		end
	end

	---------------------------------------------------------------------------
	-- Helm on the quarterdeck
	---------------------------------------------------------------------------
	local zWheel = L / 2 - s.QD.Len * 0.4 - 1.5
	do
		local y0 = qdDeck
		local post = P.part(fittings, { Name = "HelmPost", Size = V(0.9, 3.2, 0.9), CFrame = CF(0, y0 + 1.6, zWheel), Mat = "Wood", Color = s.Rail })
		P.part(fittings, deco({ Name = "HelmPlinth", Size = V(1.6, 0.4, 1.6), CFrame = CF(0, y0 + 0.2, zWheel), Mat = "Wood", Color = s.Wale }))
		P.part(fittings, deco({ Name = "HelmCap", Size = V(1.2, 0.3, 1.2), CFrame = CF(0, y0 + 3.3, zWheel), Mat = "Metal", Color = s.Trim }))
		P.part(fittings, deco({ Name = "Axle", Shape = "Cylinder", Size = V(1.1, 0.4, 0.4), CFrame = CF(0, y0 + 3.0, zWheel + 0.55) * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = IRON }))
		local hubCF = CF(0, y0 + 3.0, zWheel + 1.0)
		local wheelModel = P.model(fittings, "Wheel")
		local hub = P.part(wheelModel, { Name = "WheelHub", Size = V(0.4, 0.4, 0.4), CFrame = hubCF, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local wheelParts = {}
		table.insert(wheelParts, P.part(wheelModel, { Name = "HubCap", Shape = "Cylinder", Size = V(0.5, 0.9, 0.9), CFrame = hubCF * Angles(0, math.pi / 2, 0), Mat = "Metal", Color = s.Trim }))
		local R = 1.9
		local nRim = 8
		for i = 0, nRim - 1 do
			local phi = i * math.pi * 2 / nRim
			table.insert(wheelParts, P.part(wheelModel, { Name = "Rim", Size = V(2 * R * math.sin(math.pi / nRim) + 0.14, 0.3, 0.3), CFrame = hubCF * Angles(0, 0, phi) * CF(0, R, 0), Mat = "Wood", Color = rgb(126, 84, 50) }))
		end
		for k = 0, 3 do
			table.insert(wheelParts, P.part(wheelModel, { Name = "Spoke", Size = V(0.2, 2 * R + 1.3, 0.2), CFrame = hubCF * Angles(0, 0, k * math.pi / 4 + math.pi / 8), Mat = "Wood", Color = rgb(140, 96, 58) }))
		end
		for _, part in wheelParts do
			part.CanCollide = false
			part.CanQuery = false
			P.weld(hub, part)
		end
		P.weld(post, hub, "WheelWeld")
		P.prompt(post, { Name = "HelmPrompt", ActionText = "Take the Helm", ObjectText = "Ship's Wheel", MaxActivationDistance = 8 })
		P.attachment(root, "HelmPoint", CF(0, y0, zWheel + 3.0))
	end

	---------------------------------------------------------------------------
	-- Masts, yards, sails, rigging
	---------------------------------------------------------------------------
	local mainMastTop = 0
	local mastInfo = {}
	for mi, m in s.Masts do
		local baseY = if m.Base == "FC" then fcDeck elseif m.Base == "QD" then qdDeck else deckTop
		local d0 = if big then 1.9 else 1.55
		local lowerTopY = deckTop + m.Yards[1].Y + 2.2
		local topmastTopY = deckTop + m.Yards[2].Y + 2.4
		local yTop = deckTop + m.Top
		mainMastTop = math.max(mainMastTop, yTop)
		P.pillar(rigging, 0, m.Z, baseY - 0.4, lowerTopY + 0.6, d0, { Name = "Mast", Mat = "Wood", Color = SPAR })
		P.pillar(rigging, 0, m.Z + 0.05, lowerTopY - 1.6, topmastTopY + 0.4, d0 * 0.7, { Name = "Topmast", Mat = "Wood", Color = SPAR })
		P.pillar(rigging, 0, m.Z + 0.08, topmastTopY - 1.4, yTop, d0 * 0.48, deco({ Name = "TopgallantMast", Mat = "Wood", Color = SPAR }))
		-- mast cap (doubling) and the top platform
		P.part(rigging, deco({ Name = "MastCap", Size = V(d0 + 0.3, 0.6, d0 * 2 + 0.3), CFrame = CF(0, lowerTopY + 0.4, m.Z + d0 * 0.35), Mat = "Wood", Color = s.Wale }))
		P.part(rigging, deco({ Name = "Top", Shape = "Cylinder", Size = V(0.45, d0 * 2.6, d0 * 2.6), CFrame = CF(0, lowerTopY - 1.0, m.Z + 0.4) * Angles(0, 0, math.pi / 2), Mat = "WoodPlanks", Color = s.Rail }))
		-- mast foot: collar with the sail prompt + fife rail
		local base = P.pillar(rigging, 0, m.Z, baseY, baseY + 1.0, d0 + 1.0, { Name = "MastBase", Mat = "Wood", Color = s.Rail })
		P.pillar(rigging, 0, m.Z, baseY + 1.0, baseY + 1.25, d0 + 0.5, deco({ Name = "MastBand", Mat = "Metal", Color = s.Trim }))
		P.prompt(base, { Name = "SailPrompt", ActionText = "Lower Sails", ObjectText = "Sails", HoldDuration = 0.4, MaxActivationDistance = 8 })
		P.part(rigging, deco({ Name = "FifeRail", Size = V(d0 + 3.4, 0.3, 0.45), CFrame = CF(0, baseY + 2.2, m.Z + d0 / 2 + 1.0), Mat = "Wood", Color = s.Rail }))
		for _, sx in { -1, 1 } do
			P.pillar(rigging, sx * (d0 / 2 + 1.3), m.Z + d0 / 2 + 1.0, baseY, baseY + 2.2, 0.32, deco({ Name = "FifePost", Mat = "Wood", Color = s.Rail }))
		end
		P.pillar(rigging, d0 / 2 + 1.0, m.Z - d0 / 2 - 0.9, baseY, baseY + 0.32, 1.5, deco({ Name = "RopeCoil", Mat = "Fabric", Color = ROPE }))
		if baseY == deckTop then
			block(0, m.Z, d0 / 2 + 2.2)
		end

		if m.Nest then
			local ny = deckTop + m.Nest
			P.pillar(rigging, 0, m.Z, ny, ny + 0.4, 5.0, { Name = "CrowsNestFloor", Mat = "WoodPlanks", Color = s.Rail, CanCollide = false })
			P.pillar(rigging, 0, m.Z, ny + 0.4, ny + 2.1, 4.7, deco({ Name = "CrowsNest", Mat = "WoodPlanks", Color = shade(s.Hull, 1.15) }))
			P.pillar(rigging, 0, m.Z, ny + 2.1, ny + 2.45, 5.1, deco({ Name = "CrowsNestRim", Mat = "Wood", Color = s.Rail }))
			P.pillar(rigging, 0, m.Z, ny + 0.75, ny + 1.0, 4.85, deco({ Name = "CrowsNestBand", Mat = "Metal", Color = s.Trim }))
		end

		-- yards + sails
		for yi, y in m.Yards do
			local yy = deckTop + y.Y
			local r = if yi == 1 then d0 * 0.5 elseif yi == 2 then d0 * 0.35 else d0 * 0.24
			local yz = m.Z - r - 0.42
			local yd = (if yi == 1 then 0.75 elseif yi == 2 then 0.62 else 0.48) + (if big then 0.1 else 0)
			local yard = P.part(rigging, { Name = "Yard", Shape = "Cylinder", Size = V(y.W + 2.4, yd, yd), CFrame = CF(0, yy, yz), Mat = "Wood", Color = SPAR, CanCollide = false })
			buildSail(sails, yard, y, mi, yi)
			-- lifts from the mast to the yard arms
			for _, sx in { -1, 1 } do
				rope(rigging, V(0, yy + 3.2, m.Z), V(sx * (y.W / 2 + 0.9), yy + 0.2, yz), 0.12)
			end
		end

		-- flag / pennant
		P.pillar(rigging, 0, m.Z + 0.1, yTop, yTop + 2.6, 0.24, deco({ Name = "FlagPole", Mat = "Wood", Color = SPAR }))
		P.part(rigging, deco({ Name = "MastTruck", Shape = "Ball", Size = V(0.6, 0.6, 0.6), CFrame = CF(0, yTop + 2.7, m.Z + 0.1), Mat = "Metal", Color = s.Trim }))
		if m.Main then
			local flag = P.part(rigging, deco({ Name = "Flag", Size = V(0.12, 2.8, 4.4), CFrame = CF(0, yTop + 1.2, m.Z + 2.35), Mat = "Fabric", Color = rgb(22, 20, 24) }))
			for _, face in { "Left", "Right" } do
				P.surfaceText(flag, face, "☠️", { Name = "Emblem", Color = rgb(240, 236, 226), StrokeTransparency = 1, PixelsPerStud = 20, Padding = 0.1 })
			end
		else
			P.part(rigging, deco({ Class = "WedgePart", Name = "Pennant", Size = V(0.1, 1.3, 6), CFrame = CF(0, yTop + 1.75, m.Z + 3.1) * Angles(0, math.pi, 0), Mat = "Fabric", Color = s.Pennant }))
		end

		mastInfo[mi] = { Z = m.Z, BaseY = baseY, LowerTop = lowerTopY, TopmastTop = topmastTopY, Top = yTop, D = d0 }

		-- shrouds with ratlines down to the channels
		local zc = m.Z + 0.9
		local yc = G.top(zc, 1).Y
		local hwc = G.halfWidth(zc, yc - 0.6)
		local nShrouds = if big and m.Main then 4 else 3
		for _, side in { -1, 1 } do
			local chA = V(side * (hwc + 0.55), yc - 0.6, zc - 2.0)
			local chB = V(side * (hwc + 0.55), yc - 0.6, zc + 2.4)
			P.plank(rigging, chA + V(-side * 0.3, 0, -0.4), chB + V(-side * 0.3, 0, 0.4), 1.0, 0.3, { Name = "Channel", Mat = "Wood", Color = s.Wale, CanCollide = false })
			local topP = V(side * d0 * 0.5, lowerTopY - 0.6, m.Z)
			local feet = {}
			for k = 0, nShrouds - 1 do
				local foot = chA + (chB - chA) * (k / (nShrouds - 1)) + V(0, 0.2, 0)
				feet[k + 1] = foot
				rope(rigging, foot, topP + V(0, 0, (k - (nShrouds - 1) / 2) * 0.35), 0.16)
			end
			local hShroud = topP.Y - feet[1].Y
			local spacing = if big then 2.1 else 2.0
			local nRat = math.floor(hShroud * 0.6 / spacing)
			for k = 1, nRat do
				local f = k * spacing / hShroud
				local a = feet[1] + (topP - feet[1]) * f
				local b = feet[nShrouds] + (topP - feet[nShrouds]) * f
				rope(rigging, a, b, 0.09)
			end
			-- topmast shroud from the top rim, and a long backstay
			local topRim = V(side * d0 * 1.25, lowerTopY - 0.9, m.Z + 0.5)
			rope(rigging, topRim, V(side * d0 * 0.35, topmastTopY - 0.5, m.Z), 0.12)
			local back = V(side * (hwc + 0.3), yc - 0.3, zc + 6.5)
			rope(rigging, back, V(side * d0 * 0.3, topmastTopY - 0.3, m.Z), 0.12)
		end
	end

	-- fore-and-aft stays
	do
		local first = mastInfo[1]
		rope(rigging, spritEnd + V(0, spritD * 0.4, 0), V(0, first.LowerTop - 0.4, first.Z - first.D * 0.5), 0.2)
		rope(rigging, jibEnd, V(0, first.TopmastTop - 0.3, first.Z - first.D * 0.35), 0.15)
		for mi = 2, #mastInfo do
			local m, prev = mastInfo[mi], mastInfo[mi - 1]
			rope(rigging, V(0, m.LowerTop - 0.4, m.Z - m.D * 0.5), V(0, prev.BaseY + 1.3, prev.Z + prev.D * 0.5 + 0.4), 0.18)
			rope(rigging, V(0, m.TopmastTop - 0.3, m.Z - m.D * 0.35), V(0, prev.LowerTop + 0.2, prev.Z + prev.D * 0.5), 0.14)
		end
	end

	---------------------------------------------------------------------------
	-- Cannons + gun ports
	---------------------------------------------------------------------------
	local portY = deckTop + CANNON_PIVOT_Y
	local function gunPort(z: number, side: number, open: boolean, y: number)
		local u, v = G.solve(z, y)
		local p = G.point(u, v, side)
		local n = G.normal(u, v, side)
		local cf = P.lookAt(p + n * 0.06, p + n * 2)
		if open then
			P.part(hull, deco({ Name = "GunPort", Size = V(1.55, 1.4, 0.3), CFrame = cf, Mat = "Wood", Color = rgb(18, 14, 12) }))
			local lidCF = cf * CF(0, 0.72, -0.18) * Angles(math.rad(72), 0, 0) * CF(0, -0.78, 0)
			P.part(hull, deco({ Name = "PortLid", Size = V(1.75, 1.6, 0.22), CFrame = lidCF, Mat = "WoodPlanks", Color = shade(s.Wale, 1.3) }))
		else
			P.part(hull, deco({ Name = "PortLid", Size = V(1.6, 1.45, 0.26), CFrame = cf * CF(0, 0, -0.1), Mat = "WoodPlanks", Color = shade(s.Wale, 1.25) }))
		end
	end
	for _, c in s.Cannons do
		local cannon = buildCannon(cannons, s)
		local hw = G.halfWidth(c.Z, portY)
		local pivotX = hw + 1.0 - CANNON_MUZZLE
		-- model origin is 0.15 inboard of the pivot
		local x = c.Side * (pivotX - 0.15)
		P.transform(cannon, CF(x, deckTop, c.Z) * Angles(0, -c.Side * math.pi / 2, 0))
		cannon:SetAttribute("Side", c.Side)
		gunPort(c.Z, c.Side, true, portY)
		block(c.Side * (pivotX - 1.6), c.Z, 3.0)
	end
	-- closed decorative ports on the lower hull
	if s.Ports > 0 then
		local y = (s.Rows[4] + s.Rows[5]) / 2
		for _, side in { -1, 1 } do
			for k = 1, s.Ports do
				local z = lerp(zF + 3, zQ + s.QD.Len * 0.3, (k - 0.5) / s.Ports)
				gunPort(z, side, false, y)
			end
		end
	end

	---------------------------------------------------------------------------
	-- Deck clutter: hatch, barrels
	---------------------------------------------------------------------------
	if s.Hatch then
		local hz = s.Hatch.Z
		local w = math.min(5, W * 0.26)
		P.part(decks, { Name = "HatchCoaming", Size = V(w + 0.6, 0.35, w + 0.6), CFrame = CF(0, deckTop + 0.175, hz), Mat = "Wood", Color = s.Rail })
		P.part(decks, deco({ Name = "Grating", Size = V(w - 0.3, 0.38, w - 0.3), CFrame = CF(0, deckTop + 0.18, hz), Mat = "WoodPlanks", Color = rgb(40, 30, 22) }))
		block(0, hz, w * 0.75 + 1.2)
	end
	for i, b in s.Barrels do
		local yb = deckTop
		if b.Z > zQ then
			yb = qdDeck
		elseif b.Z < zF then
			yb = fcDeck
		end
		local hw = hwIn(b.Z, yb + 1)
		local x = b.X * hw
		x = if x > 0 then math.min(x, hw - 0.95) else math.max(x, -(hw - 0.95))
		P.pillar(fittings, x, b.Z, yb, yb + 2.2, 1.7, { Name = "Barrel", Mat = "WoodPlanks", Color = shade(rgb(112, 76, 48), 0.9 + 0.2 * hash(i, 1, 2)) })
		for _, hy in { 0.45, 1.75 } do
			P.pillar(fittings, x, b.Z, yb + hy - 0.08, yb + hy + 0.08, 1.78, deco({ Name = "Hoop", Mat = "Metal", Color = IRON }))
		end
		block(x, b.Z, 1.6)
	end
	for i, c in s.Crates do
		local hw = hwIn(c.Z, deckTop + 1)
		local x = c.X * hw
		x = if x > 0 then math.min(x, hw - 1.25) else math.max(x, -(hw - 1.25))
		local color = shade(rgb(124, 90, 58), 0.9 + 0.2 * hash(i, 7, 3))
		P.part(fittings, { Name = "Crate", Size = V(2.1, 1.9, 2.1), CFrame = CF(x, deckTop + 0.95, c.Z) * Angles(0, 0.12 * i, 0), Mat = "WoodPlanks", Color = color, CanQuery = false })
		if c.Stack > 1 then
			P.part(fittings, { Name = "Crate", Size = V(1.5, 1.4, 1.5), CFrame = CF(x - 0.1 * math.sign(x), deckTop + 2.6, c.Z + 0.1) * Angles(0, 0.5 + 0.2 * i, 0), Mat = "WoodPlanks", Color = shade(color, 1.12), CanQuery = false })
		end
		block(x, c.Z, 1.8)
	end

	---------------------------------------------------------------------------
	-- Ladders (climbable truss + wooden cleats on the hull)
	---------------------------------------------------------------------------
	for _, side in { -1, 1 } do
		local z = s.Ladder
		local top = G.top(z, side).Y + 1.0
		local hwMax = G.halfWidth(z, deckTop - 0.6)
		local x = side * (hwMax + 0.75)
		local h = 14
		P.part(hull, { Class = "TrussPart", Name = "Ladder", Size = V(2, h, 2), CFrame = CF(x, top - h / 2, z), Transparency = 1, Color = s.Rail, Mat = "Wood" })
		local rungY = top - 1.4
		while rungY > -1.2 do
			local hwR = G.halfWidth(z, rungY)
			P.part(fittings, deco({ Name = "LadderRung", Size = V(0.35, 0.3, 1.7), CFrame = CF(side * (hwR + 0.2), rungY, z), Mat = "Wood", Color = SPAR }))
			rungY -= 1.6
		end
		for _, dz in { -0.95, 0.95 } do
			local a = G.top(z + dz, side) + V(side * 0.15, 0.1, 0)
			local b = V(side * (G.halfWidth(z + dz, -1) + 0.2), -1.2, z + dz)
			P.plank(fittings, a, b, 0.2, 0.2, deco({ Name = "LadderRope", Mat = "Fabric", Color = ROPE }))
		end
		block(side * (hwMax - 1.5), z, 1.5)
	end

	---------------------------------------------------------------------------
	-- Attachments: hole spots, crew spawn, wakes, name tag
	---------------------------------------------------------------------------
	local function isFree(x: number, z: number): boolean
		for _, b in blocked do
			local dx, dz = x - b[1], z - b[2]
			if dx * dx + dz * dz < b[3] * b[3] then
				return false
			end
		end
		return true
	end
	local candidates = {}
	do
		local z = zF + 2.5
		while z < zQ - 1.5 do
			local hw = hwIn(z, deckTop)
			for _, fx in { -0.45, 0, 0.45 } do
				local x = fx * hw
				if isFree(x, z) then
					table.insert(candidates, V(x, deckTop + 0.02, z))
				end
			end
			z += 2.6
		end
	end
	local step = math.max(1, #candidates / s.Holes)
	local i = 1
	local nSpots = 0
	while i <= #candidates and nSpots < s.Holes do
		P.attachment(root, "HoleSpot", CF(candidates[math.floor(i)]))
		nSpots += 1
		i += step
	end

	do
		local hz = if s.Hatch then s.Hatch.Z else (zF + zQ) / 2
		local spawnZ = hz + 4.5
		local x = 0
		if not isFree(0, spawnZ) then
			spawnZ = hz - 4.5
		end
		if not isFree(0, spawnZ) then
			x = hwIn(spawnZ, deckTop) * 0.4
		end
		P.attachment(root, "CrewSpawn", CF(x, deckTop, spawnZ))
	end

	local bowAtt = P.attachment(root, "BowSpray", CF(0, 0.6, G.point(0, G.vAt(0, 0.6), 1).Z + 1.0))
	P.emitter(bowAtt, {
		Name = "Wake",
		Rate = 0,
		Color = P.ColorSequence.new(rgb(255, 255, 255)),
		Size = P.seq(1.5, 5),
		Transparency = P.seq(0.35, 1),
		Lifetime = P.NumberRange.new(0.8, 1.4),
		Speed = P.NumberRange.new(6, 12),
		SpreadAngle = P.Vector2.new(50, 15),
		Acceleration = V(0, -14, 0),
		Drag = 1.5,
		LightEmission = 0.25,
	})
	local sternAtt = P.attachment(root, "SternWake", CF(0, 0.3, L / 2 + 1.5))
	P.emitter(sternAtt, {
		Name = "Wake",
		Rate = 0,
		Color = P.ColorSequence.new(rgb(230, 250, 255)),
		Size = P.seq(3, 10),
		Transparency = P.seq(0.45, 1),
		Lifetime = P.NumberRange.new(2, 3),
		Speed = P.NumberRange.new(1, 3),
		SpreadAngle = P.Vector2.new(25, 25),
		LightEmission = 0.2,
	})

	P.billboard(root, "NameTag", "Ship", { Offset = V(0, mainMastTop + 6, 0), MaxDistance = 700, Size = P.UDim2.fromOffset(300, 46), Color = rgb(255, 230, 160) })

	-- Physics: only Root is anchored in the template; everything is welded to it.
	for _, part in P.descendantParts(model) do
		if part ~= root then
			part.Anchored = false
			part.Massless = true
		end
	end
	P.weldAllTo(model, root)

	model:SetAttribute("ShipType", id)
	model:SetAttribute("Length", L)
	model:SetAttribute("Width", W)
	return model
end

return Ships
