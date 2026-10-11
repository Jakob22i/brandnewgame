-- King of the Pirates - client entry point.

local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"State",
	"HUD",
	"ShopUI",
	"PlayersUI",
	"TradeUI",
	"MapUI",
	"HelpUI",
	"HelmController",
	"CannonController",
	"ToolController",
	"ShipRider",
	"Effects",
	"Ambience",
}

local modules: { [string]: any } = {}
for _, name in ORDER do
	modules[name] = require(Controllers:WaitForChild(name))
end
for _, name in ORDER do
	local module = modules[name]
	if module.Init then
		local ok, err = pcall(module.Init)
		if not ok then
			warn(("[Client] %s failed to start: %s"):format(name, tostring(err)))
		end
	end
end

modules.ShopUI.OpenTrading = modules.PlayersUI.Open
