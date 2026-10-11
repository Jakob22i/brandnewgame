-- "Pirates" window: everyone on the server, with buttons to invite to your crew or
-- trade. Also shows incoming crew / trade invitations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local HUD = require(script.Parent.HUD)
local State = require(script.Parent.State)
local UIKit = require(script.Parent.UIKit)

local PlayersUI = {}

local player = Players.LocalPlayer
local C = UIKit.Colors
local window: UIKit.Window
local inviteGui: ScreenGui
local inviteFrame: Frame?

local function isCrewmate(userId: number): boolean
	if not State.Crew then
		return false
	end
	for _, member in State.Crew.Members do
		if member.UserId == userId then
			return true
		end
	end
	return false
end

function PlayersUI.Refresh()
	if not window.Gui.Enabled then
		return
	end
	UIKit.Clear(window.Body)
	local scroll = UIKit.Scroll(window.Body)
	UIKit.List(scroll, 8)

	-- crew section
	local crewCard = UIKit.Card(scroll, 70, 0)
	local crewText = "You sail alone. Invite pirates to your crew: crewmates can't hurt each other and respawn on the crew's ship."
	if State.Crew then
		local names = {}
		for _, member in State.Crew.Members do
			local tag = if member.UserId == State.Crew.Captain then " (Captain)" else ""
			table.insert(names, member.Name .. tag)
		end
		crewText = "Your crew: " .. table.concat(names, ", ")
	end
	UIKit.Label(crewCard, crewText, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, if State.Crew then -170 else -24, 1, -12),
		TextWrapped = true,
		Font = UIKit.Fonts.Small,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	if State.Crew then
		UIKit.Button(crewCard, "Leave Crew", C.Red, function()
			Net.Event("CrewAction"):FireServer("Leave")
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 40) })
	end

	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then
			table.insert(others, p)
		end
	end
	table.sort(others, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	if #others == 0 then
		UIKit.Label(scroll, "No other pirates on this server yet.", { LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 40) })
	end
	for i, other in others do
		local row = UIKit.Card(scroll, 56, i + 1)
		local leaderstats = other:FindFirstChild("leaderstats")
		local gold = leaderstats and leaderstats:FindFirstChild("Gold")
		local goldText = if gold and gold:IsA("IntValue") then Util.FormatNumber(gold.Value) .. "g" else ""
		UIKit.Label(row, other.DisplayName .. (if isCrewmate(other.UserId) then "  [crew]" else ""), {
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -330, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UIKit.Label(row, goldText, {
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -330, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = UIKit.Fonts.Small,
			TextColor3 = C.GoldDark,
		})
		UIKit.Button(row, "Trade", C.Gold, function()
			Net.Event("TradeAction"):FireServer("Request", other.UserId)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -164, 0.5, 0), Size = UDim2.fromOffset(140, 40), TextColor3 = C.Ink })
		if not isCrewmate(other.UserId) then
			UIKit.Button(row, "Invite to Crew", C.Teal, function()
				Net.Event("CrewAction"):FireServer("Invite", other.UserId)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(146, 40) })
		end
	end
	UIKit.Label(scroll, "Trades only work in Kingshaven.", { LayoutOrder = 999, Size = UDim2.new(1, -12, 0, 22), Font = UIKit.Fonts.Small })
end

function PlayersUI.Toggle()
	window.Gui.Enabled = not window.Gui.Enabled
	PlayersUI.Refresh()
end

function PlayersUI.Open()
	window.Gui.Enabled = true
	PlayersUI.Refresh()
end

-- A small popup with Accept / Decline and a countdown
local function showInvite(text: string, timeout: number, onAnswer: (boolean) -> ())
	if inviteFrame then
		inviteFrame:Destroy()
	end
	local frame = UIKit.Panel(inviteGui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(380, 120),
	})
	inviteFrame = frame
	UIKit.Label(frame, text, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 50),
		TextWrapped = true,
	})
	local answered = false
	local function answer(value: boolean)
		if answered then
			return
		end
		answered = true
		onAnswer(value)
		frame:Destroy()
		if inviteFrame == frame then
			inviteFrame = nil
		end
	end
	local buttons = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 44), Parent = frame })
	UIKit.List(buttons, 12, true)
	local accept = UIKit.Button(buttons, "Accept", C.Green, function()
		answer(true)
	end, { Size = UDim2.fromOffset(150, 40) })
	UIKit.Button(buttons, "Decline", C.Red, function()
		answer(false)
	end, { Size = UDim2.fromOffset(150, 40) })
	task.spawn(function()
		for t = timeout, 1, -1 do
			if answered then
				return
			end
			accept.Text = ("Accept (%d)"):format(t)
			task.wait(1)
		end
		answer(false)
	end)
end

function PlayersUI.Init()
	window = UIKit.Window("PiratesWindow", "Pirates of the Seas", UDim2.fromOffset(600, 520))
	inviteGui = UIKit.Screen("Invites", 8)
	HUD.AddMenuButton("CREW", Enum.KeyCode.P, 2, C.Teal, PlayersUI.Toggle)

	Net.Event("CrewClient").OnClientEvent:Connect(function(kind, payload)
		if kind == "Invite" and type(payload) == "table" then
			showInvite(payload.Name .. " invites you to join their crew!", payload.Timeout or 20, function(accepted)
				Net.Event("CrewAction"):FireServer("Respond", accepted)
			end)
		end
	end)
	Net.Event("TradeClient").OnClientEvent:Connect(function(kind, payload)
		if kind == "Invite" and type(payload) == "table" then
			showInvite(payload.Name .. " wants to trade with you.", payload.Timeout or 20, function(accepted)
				Net.Event("TradeAction"):FireServer("Respond", accepted)
			end)
		end
	end)
	State.CrewChanged.Event:Connect(PlayersUI.Refresh)
	Players.PlayerAdded:Connect(PlayersUI.Refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(PlayersUI.Refresh)
	end)
end

return PlayersUI
