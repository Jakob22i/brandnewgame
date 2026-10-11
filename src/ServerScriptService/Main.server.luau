-- King of the Pirates - server entry point.
-- Starts every service, then generates the world terrain (Kingshaven first).

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")

local ORDER = {
	"DataService",
	"CrewService",
	"InventoryService",
	"WorldService",
	"CombatService",
	"CarryService",
	"ShipService",
	"EnemyService",
	"TreasureService",
	"ShopService",
	"TradeService",
	"SpawnService",
}

local modules: { [string]: any } = {}
for _, name in ORDER do
	modules[name] = require(Services:WaitForChild(name))
end
for _, name in ORDER do
	local module = modules[name]
	if module.Init then
		local ok, err = pcall(module.Init)
		if not ok then
			warn(("[Main] %s failed to start: %s"):format(name, tostring(err)))
		end
	end
end

local TerrainGenerator = require(Services:WaitForChild("TerrainGenerator"))
task.spawn(function()
	TerrainGenerator.Generate(false, function()
		modules.SpawnService.SetWorldReady()
	end)
	modules.SpawnService.SetWorldReady()
	workspace:SetAttribute("WorldReady", true)
end)

print("[King of the Pirates] Server started")
