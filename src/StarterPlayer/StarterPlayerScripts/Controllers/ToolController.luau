-- What happens when you click with a tool: swing the cutlass, fire the flintlock,
-- dig with the shovel, look through the spyglass, or read your treasure map.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local HUD = require(script.Parent.HUD)
local MapUI = require(script.Parent.MapUI)
local UIKit = require(script.Parent.UIKit)

local ToolController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local lastUse: { [string]: number } = {}
local spyglassOn = false
local spyGui: ScreenGui
local connected: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function ready(key: string, cooldown: number): boolean
	local now = os.clock()
	if lastUse[key] and now - lastUse[key] < cooldown then
		return false
	end
	lastUse[key] = now
	return true
end

local function setSpyglass(on: boolean)
	spyglassOn = on
	spyGui.Enabled = on
	local camera = workspace.CurrentCamera
	TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { FieldOfView = if on then 18 else 70 }):Play()
end

local function onActivated(tool: Tool)
	local name = tool.Name
	if name == "Cutlass" or name == "GoldenCutlass" then
		local item = Config.Items[name]
		if ready("Swing", (item.Cooldown or 0.5) * 0.95) then
			Net.Event("CombatAction"):FireServer("Swing")
		end
	elseif name == "Flintlock" then
		if ready("Shoot", Config.Items.Flintlock.Cooldown or 2.5) then
			Net.Event("CombatAction"):FireServer("Shoot", mouse.Hit.Position)
		else
			HUD.Notify("Reloading...", "info")
		end
	elseif name == "Shovel" or name == "GoldenShovel" then
		if ready("Dig", Config.Dig.Cooldown) then
			Net.Event("TreasureAction"):FireServer("Dig")
		end
	elseif name == "Spyglass" then
		setSpyglass(not spyglassOn)
	end
end

local function watchTool(tool: Tool)
	if connected[tool] then
		return
	end
	connected[tool] = true
	tool.Activated:Connect(function()
		onActivated(tool)
	end)
	tool.Equipped:Connect(function()
		if tool.Name == "TreasureMap" then
			MapUI.ShowTreasureMap(true)
		end
	end)
	tool.Unequipped:Connect(function()
		if tool.Name == "TreasureMap" then
			MapUI.ShowTreasureMap(false)
		elseif tool.Name == "Spyglass" and spyglassOn then
			setSpyglass(false)
		end
	end)
end

local function watchContainer(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") then
			watchTool(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			watchTool(child)
		end
	end)
end

function ToolController.Init()
	spyGui = UIKit.Screen("Spyglass", 1)
	spyGui.IgnoreGuiInset = true
	spyGui.Enabled = false
	-- dark vignette ring around the lens
	local ring = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.92),
		BackgroundTransparency = 1,
		Parent = spyGui,
	})
	UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height, Parent = ring })
	UIKit.Corner(ring, 2000)
	local edge = UIKit.Stroke(ring, Color3.new(0, 0, 0), 900)
	edge.Transparency = 0.05

	player.CharacterAdded:Connect(function(character)
		watchContainer(character)
		if spyglassOn then
			setSpyglass(false)
		end
		MapUI.ShowTreasureMap(false)
	end)
	if player.Character then
		watchContainer(player.Character)
	end
	local function watchBackpack(backpack: Instance)
		if backpack:IsA("Backpack") then
			watchContainer(backpack)
		end
	end
	player.ChildAdded:Connect(watchBackpack)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watchBackpack(backpack)
	end

	-- no tools while carrying treasure
	local function updateBackpack()
		local carrying = player:GetAttribute("CarryingTier") ~= nil
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not carrying)
		end)
	end
	player:GetAttributeChangedSignal("CarryingTier"):Connect(updateBackpack)
	updateBackpack()
end

return ToolController
