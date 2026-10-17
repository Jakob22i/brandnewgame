-- Day/night cycle, the wind, and the crown: the richest pirate online is crowned
-- "King of the Pirates" (their name on the statue in Kingshaven).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = require(script.Parent.DataService)

local WorldService = {}

local windAngle = math.random() * math.pi * 2
local windTarget = windAngle
local windVector = Vector3.new(math.cos(windAngle), 0, math.sin(windAngle))
local currentKing: Player? = nil

-- Unit vector the wind blows towards
function WorldService.GetWind(): Vector3
	return windVector
end

local function plaqueLabel(): TextLabel?
	local town = workspace:FindFirstChild("Kingshaven")
	local statue = town and town:FindFirstChild("KingStatue")
	local plaque = statue and statue:FindFirstChild("Plaque")
	local gui = plaque and plaque:FindFirstChild("PlaqueGui")
	local label = gui and gui:FindFirstChild("Label")
	return if label and label:IsA("TextLabel") then label else nil
end

local function removeCrown(player: Player)
	player:SetAttribute("IsKing", nil)
end

-- The king only gets their name on the statue plaque (no crown or title on the character)
function WorldService.ApplyCrown(player: Player)
	if currentKing == player then
		player:SetAttribute("IsKing", true)
	end
end

local function updateKing()
	local richest: Player? = nil
	local most = 0
	for _, player in Players:GetPlayers() do
		local gold = DataService.GetGold(player)
		if gold > most then
			richest, most = player, gold
		end
	end
	if richest ~= currentKing then
		local old = currentKing
		currentKing = richest
		if old and old.Parent then
			removeCrown(old)
		end
		if richest then
			WorldService.ApplyCrown(richest)
			Net.NotifyAll(("%s is the new King of the Pirates!"):format(richest.DisplayName), "gold")
		end
	end
	local label = plaqueLabel()
	if label then
		label.Text = if richest
			then ("KING OF THE PIRATES\n%s\n%s gold"):format(richest.DisplayName, Util.FormatNumber(most))
			else "KING OF THE PIRATES\nNo king yet..."
	end
	workspace:SetAttribute("KingName", if richest then richest.DisplayName else "")
end

function WorldService.Init()
	workspace:SetAttribute("WindAngle", windAngle)
	-- Day/night: nights pass twice as fast as days
	local hoursPerSecond = 24 / (Config.DayLengthMinutes * 60) * 1.333
	RunService.Heartbeat:Connect(function(dt)
		local clock = Lighting.ClockTime
		local night = clock < 6 or clock > 18.5
		Lighting.ClockTime = (clock + dt * hoursPerSecond * (if night then 2 else 0.75)) % 24
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			-- the wind slowly changes direction
			if math.random() < 0.03 then
				windTarget = windAngle + (math.random() - 0.5) * math.pi
			end
			windAngle += Util.AngleDiff(windTarget, windAngle) * 0.05
			windVector = Vector3.new(math.cos(windAngle), 0, math.sin(windAngle))
			workspace:SetAttribute("WindAngle", windAngle)
		end
	end)
	task.spawn(function()
		while true do
			updateKing()
			task.wait(5)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			WorldService.ApplyCrown(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		if currentKing == player then
			currentKing = nil
		end
	end)
end

return WorldService
