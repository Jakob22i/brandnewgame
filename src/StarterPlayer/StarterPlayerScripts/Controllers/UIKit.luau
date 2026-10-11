-- Tiny UI toolkit with the game's tropical-pirate look (parchment, dark wood, gold).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UIKit = {}

UIKit.Colors = Config.Colors
UIKit.Fonts = {
	Title = Enum.Font.LuckiestGuy,
	Body = Enum.Font.FredokaOne,
	Small = Enum.Font.GothamMedium,
}

local player = Players.LocalPlayer

function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UIKit.Corner(parent: Instance, radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function UIKit.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or UIKit.Colors.WoodDark,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.Padding(parent: Instance, px: number)
	return UIKit.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		Parent = parent,
	})
end

function UIKit.List(parent: Instance, padding: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?)
	return UIKit.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UIKit.Screen(name: string, displayOrder: number?): ScreenGui
	local gui = UIKit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 1,
		IgnoreGuiInset = false,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function UIKit.Label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = UIKit.Fonts.Body,
		TextColor3 = UIKit.Colors.Ink,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = parent,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 28, Parent = label })
	if props then
		for k, v in props do
			(label :: any)[k] = v
		end
	end
	return label
end

-- Parchment panel
function UIKit.Panel(parent: Instance, props: { [string]: any }?): Frame
	local frame = UIKit.new("Frame", {
		BackgroundColor3 = UIKit.Colors.Parchment,
		BorderSizePixel = 0,
		Parent = parent,
	})
	UIKit.Corner(frame, 14)
	UIKit.Stroke(frame, UIKit.Colors.Wood, 4)
	UIKit.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 246, 220), Color3.fromRGB(232, 210, 160)),
		Rotation = 90,
		Parent = frame,
	})
	if props then
		for k, v in props do
			(frame :: any)[k] = v
		end
	end
	return frame
end

function UIKit.Button(parent: Instance, text: string, color: Color3?, onClick: (() -> ())?, props: { [string]: any }?): TextButton
	local base = color or UIKit.Colors.Teal
	local button = UIKit.new("TextButton", {
		BackgroundColor3 = base,
		Text = text,
		Font = UIKit.Fonts.Body,
		TextColor3 = UIKit.Colors.White,
		TextScaled = true,
		AutoButtonColor = false,
		Size = UDim2.new(0, 140, 0, 40),
		Parent = parent,
	})
	UIKit.Corner(button, 10)
	UIKit.Stroke(button, UIKit.Colors.WoodDark, 2.5)
	UIKit.Padding(button, 6)
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 24, Parent = button })
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(30, 20, 10)
	stroke.Transparency = 0.5
	stroke.Thickness = 1.5
	stroke.Parent = button
	local hover = base:Lerp(Color3.new(1, 1, 1), 0.18)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = hover }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	if props then
		for k, v in props do
			(button :: any)[k] = v
		end
	end
	return button
end

export type Window = { Gui: ScreenGui, Frame: Frame, Body: Frame, Title: TextLabel, Close: () -> (), OnClose: BindableEvent }

-- A centred window with a wooden title bar and an X button
function UIKit.Window(name: string, title: string, size: UDim2, displayOrder: number?): Window
	local gui = UIKit.Screen(name, displayOrder or 5)
	gui.Enabled = false
	local frame = UIKit.Panel(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
	})
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(size.X.Offset, size.Y.Offset), Parent = frame })
	frame.Size = UDim2.new(0.94, 0, 0.86, 0)
	local bar = UIKit.new("Frame", {
		BackgroundColor3 = UIKit.Colors.Wood,
		Size = UDim2.new(1, 0, 0, 52),
		BorderSizePixel = 0,
		Parent = frame,
	})
	UIKit.Corner(bar, 12)
	UIKit.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(130, 84, 46), Color3.fromRGB(84, 52, 28)),
		Rotation = 90,
		Parent = bar,
	})
	local titleLabel = UIKit.Label(bar, title, {
		Font = UIKit.Fonts.Title,
		TextColor3 = UIKit.Colors.Gold,
		Size = UDim2.new(1, -110, 1, -10),
		Position = UDim2.fromOffset(16, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local tStroke = Instance.new("UIStroke")
	tStroke.Color = Color3.fromRGB(40, 20, 8)
	tStroke.Thickness = 2
	tStroke.Parent = titleLabel
	local onClose = Instance.new("BindableEvent")
	local function close()
		gui.Enabled = false
		onClose:Fire()
	end
	local x = UIKit.Button(bar, "X", UIKit.Colors.Red, close, {
		Size = UDim2.fromOffset(40, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
	})
	x.Font = UIKit.Fonts.Title
	local body = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		Parent = frame,
	})
	UIKit.Padding(body, 12)
	return { Gui = gui, Frame = frame, Body = body, Title = titleLabel, Close = close, OnClose = onClose }
end

function UIKit.Clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

-- Scrolling list that grows with its content
function UIKit.Scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local scroll = UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UIKit.Colors.Wood,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(scroll :: any)[k] = v
		end
	end
	return scroll
end

-- Card used in shop lists
function UIKit.Card(parent: Instance, height: number, order: number?): Frame
	local card = UIKit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 250, 236),
		BackgroundTransparency = 0.15,
		Size = UDim2.new(1, -12, 0, height),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	UIKit.Corner(card, 10)
	UIKit.Stroke(card, UIKit.Colors.ParchmentDark, 2)
	return card
end

function UIKit.Coin(parent: Instance, size: number): Frame
	local coin = UIKit.new("Frame", {
		BackgroundColor3 = UIKit.Colors.Gold,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	UIKit.Corner(coin, size)
	UIKit.Stroke(coin, UIKit.Colors.GoldDark, 2)
	UIKit.Label(coin, "$", {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = UIKit.Colors.GoldDark,
		Font = UIKit.Fonts.Title,
	})
	return coin
end

return UIKit
