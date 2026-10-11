-- Steering a ship from the wheel (one pirate at a time, like Sea of Thieves).
--   A / D  turn the wheel (it stays where you leave it)   C  centre the wheel
--   W / S  lower / raise the sails                        Space or F  leave the helm

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local State = require(script.Parent.State)
local Station = require(script.Parent.Station)
local UIKit = require(script.Parent.UIKit)

local HelmController = {}

local player = Players.LocalPlayer
local C = UIKit.Colors
local ship: Model? = nil
local keys = { Left = false, Right = false, Up = false, Down = false }
local sentTurn, sentSail = 0, 0
local gui: ScreenGui
local rudderMarker: Frame
local sailLabel: TextLabel

local KEYMAP: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.A] = "Left",
	[Enum.KeyCode.Left] = "Left",
	[Enum.KeyCode.D] = "Right",
	[Enum.KeyCode.Right] = "Right",
	[Enum.KeyCode.W] = "Up",
	[Enum.KeyCode.Up] = "Up",
	[Enum.KeyCode.S] = "Down",
	[Enum.KeyCode.Down] = "Down",
}

local function send()
	local turn = (if keys.Right then 1 else 0) - (if keys.Left then 1 else 0)
	local sail = (if keys.Up then 1 else 0) - (if keys.Down then 1 else 0)
	if turn ~= sentTurn or sail ~= sentSail then
		sentTurn, sentSail = turn, sail
		Net.Event("ShipAction"):FireServer("HelmInput", turn, sail)
	end
end

local function leave()
	if ship then
		Net.Event("ShipAction"):FireServer("LeaveHelm")
	end
end

local function exit()
	ship = nil
	for k in keys do
		keys[k] = false
	end
	sentTurn, sentSail = 0, 0
	Station.Unlock()
	Station.SetControlsEnabled(true)
	State.SetMode(nil)
	gui.Enabled = false
end

local function enter(model: Model)
	if not model or not model.PrimaryPart then
		return
	end
	local root = model.PrimaryPart :: BasePart
	local point = root:FindFirstChild("HelmPoint")
	if not point or not point:IsA("Attachment") then
		return
	end
	ship = model
	State.SetMode("Helm")
	Station.SetControlsEnabled(false)
	local height = Station.RootHeight()
	Station.Lock(function()
		return if point.Parent then point.WorldCFrame * CFrame.new(0, height, 0) else nil
	end, function()
		return root.AssemblyLinearVelocity
	end)
	gui.Enabled = true
end

-- Button that reports press/release (for touch screens)
local function holdButton(parent: Instance, text: string, position: UDim2, key: string)
	local button = UIKit.Button(parent, text, C.Wood, nil, { Size = UDim2.fromOffset(64, 64), Position = position })
	button.Font = UIKit.Fonts.Title
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			keys[key] = true
			send()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			keys[key] = false
			send()
		end
	end)
	return button
end

local function buildGui()
	gui = UIKit.Screen("HelmControls", 3)
	gui.Enabled = false
	local hint = UIKit.Panel(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -196),
		Size = UDim2.fromOffset(470, 74),
	})
	UIKit.Label(hint, "A/D steer  -  W/S sails  -  C centre wheel  -  Space leave", {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 22),
		Font = UIKit.Fonts.Small,
	})
	local track = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 32),
		Size = UDim2.new(0.6, 0, 0, 12),
		BackgroundColor3 = C.ParchmentDark,
		Parent = hint,
	})
	UIKit.Corner(track, 6)
	UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 2, 1, 6), BackgroundColor3 = C.Wood, Parent = track })
	rudderMarker = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 20),
		BackgroundColor3 = C.Red,
		Parent = track,
	})
	UIKit.Corner(rudderMarker, 4)
	UIKit.Label(hint, "port", { Position = UDim2.new(0.2, -50, 0, 28), Size = UDim2.fromOffset(44, 18), Font = UIKit.Fonts.Small })
	UIKit.Label(hint, "starboard", { Position = UDim2.new(0.8, 6, 0, 28), Size = UDim2.fromOffset(70, 18), Font = UIKit.Fonts.Small })
	sailLabel = UIKit.Label(hint, "", { Position = UDim2.fromOffset(10, 50), Size = UDim2.new(1, -20, 0, 20), Font = UIKit.Fonts.Small })

	-- on-screen controls (useful on phones and tablets)
	local pad = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -150),
		Size = UDim2.fromOffset(212, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	holdButton(pad, "<", UDim2.fromOffset(0, 72), "Left")
	holdButton(pad, ">", UDim2.fromOffset(148, 72), "Right")
	holdButton(pad, "^", UDim2.fromOffset(74, 0), "Up")
	holdButton(pad, "v", UDim2.fromOffset(74, 72), "Down")
	UIKit.Button(gui, "Leave Helm", C.Red, leave, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -300),
		Size = UDim2.fromOffset(150, 44),
	})
	UIKit.Button(gui, "Centre", C.Teal, function()
		Net.Event("ShipAction"):FireServer("CenterWheel")
	end, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -180, 1, -300),
		Size = UDim2.fromOffset(110, 44),
	})
end

function HelmController.Init()
	buildGui()
	Net.Event("ShipClient").OnClientEvent:Connect(function(kind, model)
		if kind == "EnterHelm" then
			enter(model)
		elseif kind == "ExitHelm" then
			exit()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not ship or processed then
			return
		end
		local key = KEYMAP[input.KeyCode]
		if key then
			keys[key] = true
			send()
		elseif input.KeyCode == Enum.KeyCode.C then
			Net.Event("ShipAction"):FireServer("CenterWheel")
		elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonB then
			leave()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local key = KEYMAP[input.KeyCode]
		if ship and key then
			keys[key] = false
			send()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if ship and input.KeyCode == Enum.KeyCode.Thumbstick1 then
			keys.Left = input.Position.X < -0.5
			keys.Right = input.Position.X > 0.5
			keys.Up = input.Position.Y > 0.5
			keys.Down = input.Position.Y < -0.5
			send()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if ship then
			local rudder = ship:GetAttribute("Rudder") or 0
			rudderMarker.Position = UDim2.fromScale(0.5 + rudder * 0.5, 0.5)
			local sail = ship:GetAttribute("Sail") or 0
			local anchored = ship:GetAttribute("Anchored")
			sailLabel.Text = ("Sails %d%%%s"):format(math.floor(sail * 100 + 0.5), if anchored then "  -  ANCHOR DOWN (raise it at the capstan)" else "")
			sailLabel.TextColor3 = if anchored then C.Red else C.Ink
		end
	end)
	-- dying / respawning ends steering
	player.CharacterAdded:Connect(function()
		if ship then
			exit()
		end
	end)
end

return HelmController
