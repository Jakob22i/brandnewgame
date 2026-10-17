-- Loading screen shown while the islands are being generated.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Rye (western display font) for the titles, Merriweather for the small print
local RYE = Font.new("rbxassetid://12187372175")
local SERIF = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local GOLD = Color3.fromRGB(255, 205, 80)
local INK = Color3.fromRGB(40, 22, 10)

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
background.BorderSizePixel = 0
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 196, 120)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(110, 200, 226)),
	ColorSequenceKeypoint.new(0.62, Color3.fromRGB(24, 160, 176)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 52, 84)),
})
gradient.Rotation = 90
gradient.Parent = background

local function label(text: string, y: number, height: number, font: Font, color: Color3, strokeThickness: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.new(0.9, 0, 0, height)
	l.Text = text
	l.TextScaled = true
	l.FontFace = font
	l.TextColor3 = color
	l.Parent = background
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = strokeThickness
	stroke.Parent = l
	return l
end

local title = label("KING OF THE PIRATES", 0.34, 96, RYE, GOLD, 4)
local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new(Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 180, 50))
titleGradient.Rotation = 90
titleGradient.Parent = title
label("~ a tropical pirate adventure ~", 0.45, 30, RYE, Color3.fromRGB(255, 246, 226), 2.5)

-- a spinning ship's wheel drawn with frames
local wheel = Instance.new("Frame")
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.fromScale(0.5, 0.61)
wheel.Size = UDim2.fromOffset(84, 84)
wheel.BackgroundTransparency = 1
wheel.Parent = background
local rim = Instance.new("Frame")
rim.AnchorPoint = Vector2.new(0.5, 0.5)
rim.Position = UDim2.fromScale(0.5, 0.5)
rim.Size = UDim2.fromScale(0.76, 0.76)
rim.BackgroundTransparency = 1
rim.Parent = wheel
local rimCorner = Instance.new("UICorner")
rimCorner.CornerRadius = UDim.new(0.5, 0)
rimCorner.Parent = rim
local rimStroke = Instance.new("UIStroke")
rimStroke.Color = Color3.fromRGB(120, 74, 38)
rimStroke.Thickness = 7
rimStroke.Parent = rim
for i = 0, 3 do
	local spoke = Instance.new("Frame")
	spoke.AnchorPoint = Vector2.new(0.5, 0.5)
	spoke.Position = UDim2.fromScale(0.5, 0.5)
	spoke.Size = UDim2.new(0, 7, 1, 0)
	spoke.Rotation = i * 45
	spoke.BackgroundColor3 = Color3.fromRGB(120, 74, 38)
	spoke.BorderSizePixel = 0
	spoke.Parent = wheel
	local spokeCorner = Instance.new("UICorner")
	spokeCorner.CornerRadius = UDim.new(0.5, 0)
	spokeCorner.Parent = spoke
end
local hub = Instance.new("Frame")
hub.AnchorPoint = Vector2.new(0.5, 0.5)
hub.Position = UDim2.fromScale(0.5, 0.5)
hub.Size = UDim2.fromOffset(20, 20)
hub.BackgroundColor3 = GOLD
hub.Parent = wheel
local hubCorner = Instance.new("UICorner")
hubCorner.CornerRadius = UDim.new(0.5, 0)
hubCorner.Parent = hub

local status = label("Raising the islands from the sea...", 0.74, 28, RYE, Color3.fromRGB(255, 255, 255), 2)
local tip = label("", 0.86, 22, SERIF, Color3.fromRGB(230, 250, 255), 1.5)

ReplicatedFirst:RemoveDefaultLoadingScreen()
-- download the Rye font early so the game's UI doesn't pop from a fallback font
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ title, tip })
	end)
end)

local TIPS = {
	"Tip: buy a treasure map from Madame Coralie, then dig at the X.",
	"Tip: sail with the wind for extra speed.",
	"Tip: dropping anchor at full speed spins your ship around!",
	"Tip: repair holes on deck before your ship sinks.",
	"Tip: the richest pirate online is crowned King of the Pirates.",
	"Tip: chests on your deck can be stolen by rival pirates!",
	"Tip: Captain Barnaby paints new colours and symbols on your sails.",
	"Tip: talk to the shopkeepers - they know the latest rumours.",
}

local started = os.clock()
local tipIndex = math.random(1, #TIPS)
local spinning = true
task.spawn(function()
	while spinning do
		wheel.Rotation = (wheel.Rotation + 3) % 360
		title.Rotation = math.sin(os.clock() * 1.5) * 1.5
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
	elseif child:IsA("Frame") then
		TweenService:Create(child, fade, { BackgroundTransparency = 1 }):Play()
	end
end
task.wait(1.3)
spinning = false
gui:Destroy()
