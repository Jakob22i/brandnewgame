-- TEMP preview harness (not committed): builds a lineup of vegetation models
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local loader = require("./lib/loader")
local P = require("./builders/Parts")
local Nature = require("./builders/Nature")
local Noise = loader.load("src/ReplicatedStorage/Shared/Noise.luau")
local game = roblox.deserializePlace(fs.readFile("place/base.rbxl"))
local ws = game:GetService("Workspace")
local f = P.folder(ws, "Test")
local V = P.Vector3.new
local rng = Noise.Rng(5)
P.part(f, { Name = "Ground", Size = V(200, 2, 120), CFrame = P.CFrame.new(0, -1, 0), Mat = "Grass", Color = P.rgb(98, 182, 68) })
for i = 0, 3 do
	Nature.Palm(f, V(-60 + i * 14, 0, -20), rng, 1, 1)
	Nature.Palm(f, V(-60 + i * 14, 0, 10), rng, 1, 0)
end
for i = 0, 2 do
	Nature.JungleTree(f, V(10 + i * 26, 0, -20), rng, 1, 1)
	Nature.JungleTree(f, V(10 + i * 26, 0, 14), rng, 1, 0)
end
for i = 0, 4 do
	Nature.Fern(f, V(-60 + i * 8, 0, 34), rng, 1)
	Nature.RedPlant(f, V(-20 + i * 8, 0, 34), rng, 1)
	Nature.Hibiscus(f, V(20 + i * 8, 0, 34), rng, 1)
	Nature.Bush(f, V(60 + i * 8, 0, 34), rng, 1)
end
Nature.SlabStack(f, P.CFrame.new(-80, 0, 40), 18, 12, 14, rng, Nature.SANDSTONE, "Sandstone", true)
local n = 0
for _, d in f:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
print("parts", n)
fs.writeFile(process.args[1], roblox.serializePlace(game))
