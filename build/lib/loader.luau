-- Loads Roblox-style ModuleScripts (that use `require(script.Parent.X)`) inside Lune,
-- so the build script can share code with the game (Heightmap, WorldData, Config...).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

-- Roblox datatypes that shared modules may use at load time
local robloxGlobals = {
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	Enum = roblox.Enum,
}

local cache: { [string]: any } = {}

local function load(path: string): any
	if cache[path] ~= nil then
		return cache[path]
	end
	local dir = string.match(path, "^(.*)/[^/]+$") or "."
	local parentProxy = setmetatable({}, {
		__index = function(_, key)
			return { __path = dir .. "/" .. key .. ".luau" }
		end,
	})
	local env: { [string]: any } = { script = { Parent = parentProxy } }
	for name, value in robloxGlobals do
		env[name] = value
	end
	env.require = function(target: any)
		if type(target) == "table" and target.__path then
			return load(target.__path)
		end
		error("loader: unsupported require target " .. tostring(target))
	end
	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

return { load = load }
