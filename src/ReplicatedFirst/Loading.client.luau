-- Loading screen shown while the islands are being generated.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(14, 120, 150)
background.BorderSizePixel = 0
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 210, 240)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(24, 170, 180)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 70, 110)),
})
gradient.Rotation = 90
gradient.Parent = background

local function label(text: string, y: number, size: number, font: Enum.Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.new(0.9, 0, 0, size)
	l.Text = text
	l.TextScaled = true
	l.Font = font
	l.TextColor3 = color
	l.Parent = background
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(50, 26, 10)
	stroke.Thickness = 3
	stroke.Parent = l
	return l
end

local title = label("KING OF THE PIRATES", 0.36, 90, Enum.Font.LuckiestGuy, Color3.fromRGB(255, 210, 80))
label("~ a tropical pirate adventure ~", 0.47, 30, Enum.Font.FredokaOne, Color3.fromRGB(255, 248, 230))
-- a spinning ship's wheel drawn with frames
local wheel = Instance.new("Frame")
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.62)
wheel.Size = UDim2.fromOffset(76, 76)
wheel.BackgroundTransparency = 1
wheel.Parent = background
local rim = Instance.new("Frame")
rim.AnchorPoint = Vector2.new(0.5, 0.5)
rim.Position = UDim2.fromScale(0.5, 0.5)
rim.Size = UDim2.fromScale(0.78, 0.78)
rim.BackgroundTransparency = 1
rim.Parent = wheel
local rimCorner = Instance.new("UICorner")
rimCorner.CornerRadius = UDim.new(1, 0)
rimCorner.Parent = rim
local rimStroke = Instance.new("UIStroke")
rimStroke.Color = Color3.fromRGB(255, 214, 120)
rimStroke.Thickness = 6
rimStroke.Parent = rim
for i = 0, 3 do
	local spoke = Instance.new("Frame")
	spoke.AnchorPoint = Vector2.new(0.5, 0.5)
	spoke.Position = UDim2.fromScale(0.5, 0.5)
	spoke.Size = UDim2.new(0, 6, 1, 0)
	spoke.Rotation = i * 45
	spoke.BackgroundColor3 = Color3.fromRGB(255, 214, 120)
	spoke.BorderSizePixel = 0
	spoke.Parent = wheel
end
local status = label("Raising the islands from the sea...", 0.74, 26, Enum.Font.FredokaOne, Color3.fromRGB(255, 255, 255))
local tip = label("", 0.86, 22, Enum.Font.GothamMedium, Color3.fromRGB(230, 250, 255))

ReplicatedFirst:RemoveDefaultLoadingScreen()

local TIPS = {
	"Tip: buy a treasure map from the Merchant, then dig at the X.",
	"Tip: sail with the wind for extra speed.",
	"Tip: dropping anchor at full speed spins your ship around!",
	"Tip: repair holes on deck before your ship sinks.",
	"Tip: the richest pirate online is crowned King of the Pirates.",
	"Tip: chests on your deck can be stolen by rival pirates!",
}

local started = os.clock()
local tipIndex = math.random(1, #TIPS)
local spinning = true
task.spawn(function()
	while spinning do
		wheel.Rotation = (wheel.Rotation + 3) % 360
		title.Rotation = math.sin(os.clock() * 1.5) * 2
		task.wait()
	end
end)
task.spawn(function()
	while spinning do
		tip.Text = TIPS[tipIndex]
		tipIndex = tipIndex % #TIPS + 1
		task.wait(4)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
while not workspace:GetAttribute("MainIslandReady") and os.clock() - started < 90 do
	task.wait(0.25)
end
status.Text = "Ahoy! Coming ashore..."
local deadline = os.clock() + 20
while not player.Character and os.clock() < deadline do
	task.wait(0.2)
end
task.wait(math.max(0, 2.5 - (os.clock() - started)))

local fade = TweenInfo.new(1.2)
TweenService:Create(background, fade, { BackgroundTransparency = 1 }):Play()
for _, child in background:GetDescendants() do
	if child:IsA("TextLabel") then
		TweenService:Create(child, fade, { TextTransparency = 1 }):Play()
	elseif child:IsA("UIStroke") then
		TweenService:Create(child, fade, { Transparency = 1 }):Play()
	end
end
for _, child in background:GetDescendants() do
	if child:IsA("Frame") then
		TweenService:Create(child, fade, { BackgroundTransparency = 1 }):Play()
	end
end
task.wait(1.3)
spinning = false
gui:Destroy()
