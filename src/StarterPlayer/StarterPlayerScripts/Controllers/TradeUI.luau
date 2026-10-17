-- Trade window: put gold, weapons and treasure maps on the table.
-- Both pirates press Ready, then Confirm.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local State = require(script.Parent.State)
local UIKit = require(script.Parent.UIKit)

local TradeUI = {}

local C = UIKit.Colors
local window: UIKit.Window
local trade: any = nil

local function send(action: string, arg: any?)
	Net.Event("TradeAction"):FireServer(action, arg)
end

local function offerText(offer: any): string
	local lines = {}
	if offer.Gold > 0 then
		table.insert(lines, Util.FormatNumber(offer.Gold) .. " gold")
	end
	for _, id in offer.Items do
		local item = Config.Items[id]
		table.insert(lines, if item then item.DisplayName else id)
	end
	for _, map in offer.Maps do
		local tier = Config.MapTiers[map.Tier]
		table.insert(lines, ("%s (%s)"):format(tier and tier.DisplayName or map.Tier, map.Island))
	end
	return if #lines == 0 then "(nothing yet)" else table.concat(lines, "\n")
end

local function render()
	if not trade then
		return
	end
	UIKit.Clear(window.Body)
	window.Title.Text = "Trading with " .. trade.TheirName
	local data = State.Data

	-- Your side
	local mine = UIKit.Card(window.Body, 0, 1)
	mine.Size = UDim2.new(0.5, -6, 1, -64)
	UIKit.Label(mine, "Your offer" .. (if trade.YouReady then "  (ready)" else ""), {
		FontFace = UIKit.Fonts.Title,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 26),
		TextColor3 = if trade.YouReady then C.Green else C.Wood,
	})
	local goldBox = UIKit.new("TextBox", {
		Position = UDim2.fromOffset(10, 38),
		Size = UDim2.new(1, -20, 0, 36),
		BackgroundColor3 = C.White,
		Text = tostring(trade.You.Gold),
		PlaceholderText = "Gold to give",
		FontFace = UIKit.Fonts.Body,
		TextSize = 20,
		TextColor3 = C.Ink,
		ClearTextOnFocus = false,
		Parent = mine,
	})
	UIKit.Corner(goldBox, 8)
	goldBox.FocusLost:Connect(function()
		local amount = tonumber(goldBox.Text) or 0
		send("SetGold", math.max(0, math.floor(amount)))
	end)
	local list = UIKit.Scroll(mine, { Position = UDim2.fromOffset(6, 82), Size = UDim2.new(1, -12, 1, -88) })
	UIKit.List(list, 6)
	local offeredItems: { [string]: boolean } = {}
	for _, id in trade.You.Items do
		offeredItems[id] = true
	end
	local offeredMaps: { [number]: boolean } = {}
	for _, map in trade.You.Maps do
		offeredMaps[map.Id] = true
	end
	local any = false
	if data then
		for id, owned in data.Items do
			local item = Config.Items[id]
			if owned and item and item.Tradeable then
				any = true
				local on = offeredItems[id] == true
				UIKit.Button(list, (if on then "[x] " else "[ ] ") .. item.DisplayName, if on then C.Gold else C.ParchmentDark, function()
					send("ToggleItem", id)
				end, { Size = UDim2.new(1, -10, 0, 34), TextColor3 = C.Ink, LayoutOrder = item.Order })
			end
		end
		for i, map in data.Maps do
			any = true
			local tier = Config.MapTiers[map.Tier]
			local on = offeredMaps[map.Id] == true
			UIKit.Button(list, (if on then "[x] " else "[ ] ") .. ("%s - %s"):format(tier and tier.DisplayName or map.Tier, map.Island), if on then C.Gold else C.ParchmentDark, function()
				send("ToggleMap", map.Id)
			end, { Size = UDim2.new(1, -10, 0, 34), TextColor3 = C.Ink, LayoutOrder = 100 + i })
		end
	end
	if not any then
		UIKit.Label(list, "No tradeable items or maps. Starter gear can't be traded.", { Size = UDim2.new(1, -10, 0, 44), TextWrapped = true, FontFace = UIKit.Fonts.Small })
	end

	-- Their side
	local theirs = UIKit.Card(window.Body, 0, 2)
	theirs.Size = UDim2.new(0.5, -6, 1, -64)
	theirs.Position = UDim2.new(0.5, 6, 0, 0)
	UIKit.Label(theirs, trade.TheirName .. (if trade.ThemReady then "  (ready)" else ""), {
		FontFace = UIKit.Fonts.Title,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 26),
		TextColor3 = if trade.ThemReady then C.Green else C.Wood,
	})
	UIKit.Label(theirs, offerText(trade.Them), {
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 1, -50),
		TextWrapped = true,
		TextScaled = false,
		TextSize = 18,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Buttons
	local bar = UIKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 50), Parent = window.Body })
	UIKit.List(bar, 12, true)
	if trade.Phase == "Confirm" then
		UIKit.Button(bar, if trade.YouConfirmed then "Waiting..." else "CONFIRM TRADE", C.Green, function()
			send("Confirm")
		end, { Size = UDim2.fromOffset(200, 46) })
	else
		UIKit.Button(bar, if trade.YouReady then "Not ready" else "Ready", if trade.YouReady then C.ParchmentDark else C.Teal, function()
			send("Ready", not trade.YouReady)
		end, { Size = UDim2.fromOffset(160, 46), TextColor3 = if trade.YouReady then C.Ink else C.White })
	end
	UIKit.Button(bar, "Cancel", C.Red, function()
		send("Cancel")
	end, { Size = UDim2.fromOffset(140, 46) })
end

function TradeUI.Init()
	window = UIKit.Window("TradeWindow", "Trade", UDim2.fromOffset(700, 520), 7)
	window.OnClose.Event:Connect(function()
		if trade then
			send("Cancel")
		end
	end)
	Net.Event("TradeClient").OnClientEvent:Connect(function(kind, payload)
		if kind == "Open" then
			window.Gui.Enabled = true
		elseif kind == "State" then
			trade = payload
			window.Gui.Enabled = true
			render()
		elseif kind == "Close" then
			trade = nil
			window.Gui.Enabled = false
		end
	end)
	State.DataChanged.Event:Connect(render)
end

return TradeUI
