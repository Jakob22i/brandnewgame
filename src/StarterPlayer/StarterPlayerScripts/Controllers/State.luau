-- Client-side state shared by the controllers: save data, current mode, crew.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local State = {}

export type MapData = { Id: number, Tier: string, Island: string, X: number, Z: number }
export type Cosmetics = {
	SailColors: { [string]: boolean },
	Symbols: { [string]: boolean },
	SailColor: string,
	Symbol: string, -- "" = no symbol
}
export type Data = {
	Gold: number,
	Ships: { [string]: boolean },
	Items: { [string]: boolean },
	Maps: { MapData },
	Stats: { [string]: number },
	Cosmetics: Cosmetics?,
}

State.Data = nil :: Data?
State.Mode = nil :: string? -- nil | "Helm" | "Cannon"
State.Crew = nil :: any
State.DataChanged = Instance.new("BindableEvent")
State.ModeChanged = Instance.new("BindableEvent")
State.CrewChanged = Instance.new("BindableEvent")

function State.SetMode(mode: string?)
	if State.Mode ~= mode then
		State.Mode = mode
		State.ModeChanged:Fire(mode)
	end
end

function State.Init()
	Net.Event("PlayerData").OnClientEvent:Connect(function(data)
		State.Data = data
		State.DataChanged:Fire(data)
	end)
	Net.Event("CrewClient").OnClientEvent:Connect(function(kind, payload)
		if kind == "Update" then
			State.Crew = payload
			State.CrewChanged:Fire(payload)
		end
	end)
end

return State
