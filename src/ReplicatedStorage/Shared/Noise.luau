--!strict
-- Deterministic noise + random numbers.
-- Only integer-exact arithmetic is used, so the results are identical in Roblox
-- and in the Lune build script (which places trees/buildings on the same terrain).

local Noise = {}

local TWO32 = 4294967296

-- (a * b) mod 2^32 without losing precision in doubles
local function mul32(a: number, b: number): number
	local aHi = a // 65536
	local aLo = a % 65536
	return (aLo * b + ((aHi * b) % 65536) * 65536) % TWO32
end

local function hash3(a: number, b: number, c: number): number
	local h = bit32.bxor(mul32(a % TWO32, 0x27d4eb2d), mul32(b % TWO32, 0x165667b1))
	h = bit32.bxor(h, mul32(c % TWO32, 0x1b873593))
	h = bit32.bxor(h, bit32.rshift(h, 15))
	h = mul32(h, 0x85ebca6b)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xc2b2ae35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / TWO32
end
Noise.Hash = hash3

-- Smooth value noise in the range [-1, 1]
function Noise.Value2(x: number, z: number, seed: number): number
	local ix = math.floor(x)
	local iz = math.floor(z)
	local fx = x - ix
	local fz = z - iz
	local ux = fx * fx * (3 - 2 * fx)
	local uz = fz * fz * (3 - 2 * fz)
	local a = hash3(ix, iz, seed)
	local b = hash3(ix + 1, iz, seed)
	local c = hash3(ix, iz + 1, seed)
	local d = hash3(ix + 1, iz + 1, seed)
	local top = a + (b - a) * ux
	local bottom = c + (d - c) * ux
	return (top + (bottom - top) * uz) * 2 - 1
end

-- Fractal (layered) value noise in roughly [-1, 1]
function Noise.Fbm2(x: number, z: number, seed: number, octaves: number): number
	local sum = 0
	local amp = 1
	local freq = 1
	local norm = 0
	for i = 1, octaves do
		sum += Noise.Value2(x * freq, z * freq, seed + i * 101) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.03
	end
	return sum / norm
end

export type Rng = {
	Next: (self: Rng) -> number,
	Range: (self: Rng, min: number, max: number) -> number,
	Int: (self: Rng, min: number, max: number) -> number,
	Pick: <T>(self: Rng, list: { T }) -> T,
}

-- Small deterministic PRNG (LCG + hash finaliser)
function Noise.Rng(seed: number): Rng
	local state = math.floor(seed) % TWO32
	local rng = {}
	function rng.Next(_self: any): number
		state = (mul32(state, 1664525) + 1013904223) % TWO32
		return hash3(state, 7919, 104729)
	end
	function rng.Range(self: any, min: number, max: number): number
		return min + (max - min) * self:Next()
	end
	function rng.Int(self: any, min: number, max: number): number
		return math.min(max, min + math.floor(self:Next() * (max - min + 1)))
	end
	function rng.Pick(self: any, list: { any }): any
		return list[self:Int(1, #list)]
	end
	return (rng :: any) :: Rng
end

return Noise
