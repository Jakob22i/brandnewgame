-- Tiny UI toolkit with the game's pirate-outpost look: dark planks, parchment,
-- brass and the "Rye" western display font.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local UIKit = {}

UIKit.Colors = Config.Colors

-- Rye dominates (titles, buttons, names, numbers); a sturdy serif keeps small print readable
local RYE = Font.new(Config.Fonts.Display)
UIKit.Fonts = {
	Title = RYE,
	Body = RYE,
	Button = RYE,
	Small = Font.new(Config.Fonts.Text, Enum.FontWeight.Bold),
	Text = Font.new(Config.Fonts.Text, Enum.FontWeight.Regular),
}

local C = UIKit.Colors
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

local function apply(inst: Instance, props: { [string]: any }?)
	if props then
		for k, v in props do
			(inst :: any)[k] = v
		end
	end
end

function UIKit.Corner(parent: Instance, radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function UIKit.Round(parent: Instance): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = parent })
end

function UIKit.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or C.WoodDark,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- Dark outline around text (makes Rye pop on any background)
function UIKit.TextStroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or C.Shadow,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = parent,
	})
end

-- Vertical colour gradient (multiplies the background colour)
function UIKit.Gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	return UIKit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

-- Horizontal planks with hard seams, laid over a wood-coloured frame
function UIKit.Planks(parent: Instance, count: number?, rotation: number?): UIGradient
	local n = math.clamp(count or 6, 2, 9)
	local shades = { 1, 0.9, 0.97, 0.86, 0.95, 0.88, 1, 0.92, 0.85 }
	local keys = {}
	for i = 0, n - 1 do
		local s = shades[i + 1]
		local a = i / n
		local b = (i + 1) / n
		table.insert(keys, ColorSequenceKeypoint.new(if i == 0 then 0 else a + 0.004, Color3.new(s, s, s)))
		local e = s * 0.9
		table.insert(keys, ColorSequenceKeypoint.new(if i == n - 1 then 1 else b - 0.004, Color3.new(e, e, e)))
	end
	return UIKit.new("UIGradient", {
		Color = ColorSequence.new(keys),
		Rotation = rotation or 90,
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

-- Shrinks a fixed-size element on small screens (phones). designHeight = screen
-- height (px) at which the element is shown at 100%.
function UIKit.AutoScale(target: GuiObject, designHeight: number, minScale: number?): UIScale
	local scale = UIKit.new("UIScale", { Parent = target })
	local function update()
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			local s = math.min(viewport.Y / designHeight, viewport.X / (designHeight * 1.5))
			scale.Scale = math.clamp(s, minScale or 0.55, 1)
		end
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return scale
end

function UIKit.Label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		FontFace = UIKit.Fonts.Body,
		TextColor3 = C.Ink,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = parent,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 28, Parent = label })
	apply(label, props)
	return label
end

-- A Rye heading in dark wood ink
function UIKit.Heading(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = UIKit.Label(parent, text, {
		FontFace = UIKit.Fonts.Title,
		TextColor3 = C.Wood,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 28),
	})
	apply(label, props)
	return label
end

-- Parchment panel
function UIKit.Panel(parent: Instance, props: { [string]: any }?): Frame
	local frame = UIKit.new("Frame", {
		BackgroundColor3 = C.Parchment,
		BorderSizePixel = 0,
		Parent = parent,
	})
	UIKit.Corner(frame, 12)
	UIKit.Stroke(frame, C.WoodDark, 3)
	UIKit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 232)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(246, 230, 190)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(226, 202, 150)),
		}),
		Rotation = 90,
		Parent = frame,
	})
	apply(frame, props)
	return frame
end

-- Dark wooden panel (HUD pieces, name plates)
function UIKit.WoodPanel(parent: Instance, props: { [string]: any }?): Frame
	local frame = UIKit.new("Frame", {
		BackgroundColor3 = C.WoodLight,
		BorderSizePixel = 0,
		Parent = parent,
	})
	UIKit.Corner(frame, 10)
	UIKit.Stroke(frame, C.Shadow, 2.5)
	UIKit.Planks(frame, 3)
	apply(frame, props)
	return frame
end

-- Small brass rivet
function UIKit.Rivet(parent: Instance, position: UDim2, size: number?): Frame
	local s = size or 8
	local rivet = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(s, s),
		BackgroundColor3 = C.Gold,
		Parent = parent,
	})
	UIKit.Round(rivet)
	UIKit.Stroke(rivet, C.Shadow, 1).Transparency = 0.3
	UIKit.Gradient(rivet, Color3.new(1, 1, 1), Color3.fromRGB(150, 120, 80), 45)
	return rivet
end

function UIKit.Button(parent: Instance, text: string, color: Color3?, onClick: (() -> ())?, props: { [string]: any }?): TextButton
	local base = color or C.Teal
	local button = UIKit.new("TextButton", {
		BackgroundColor3 = base,
		Text = text,
		FontFace = UIKit.Fonts.Button,
		TextColor3 = C.White,
		TextScaled = true,
		AutoButtonColor = false,
		Size = UDim2.new(0, 140, 0, 40),
		Parent = parent,
	})
	UIKit.Corner(button, 9)
	UIKit.Stroke(button, C.Shadow, 2)
	UIKit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 8),
		Parent = button,
	})
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 22, Parent = button })
	local textStroke = UIKit.TextStroke(button, C.Shadow, 1.5, 0.25)
	-- bevel: lit top edge, darker lip along the bottom
	UIKit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(236, 236, 236)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(214, 214, 214)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(160, 160, 160)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 140, 140)),
		}),
		Rotation = 90,
		Parent = button,
	})
	local scale = UIKit.new("UIScale", { Parent = button })
	local quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	button.MouseEnter:Connect(function()
		local current = button:GetAttribute("BaseColor") or base
		TweenService:Create(button, quick, { BackgroundColor3 = (current :: Color3):Lerp(Color3.new(1, 1, 1), 0.16) }):Play()
		TweenService:Create(scale, quick, { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		local current = button:GetAttribute("BaseColor") or base
		TweenService:Create(button, quick, { BackgroundColor3 = current }):Play()
		TweenService:Create(scale, quick, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, quick, { Scale = 0.96 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, quick, { Scale = 1.04 }):Play()
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	apply(button, props)
	-- dark letters on a light button don't need an outline
	local t = button.TextColor3
	textStroke.Enabled = (t.R * 0.3 + t.G * 0.59 + t.B * 0.11) > 0.45
	return button
end

-- Change a button's colour after creation (keeps the hover effect correct)
function UIKit.SetButtonColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	button.BackgroundColor3 = color
end

-- Highlights a card while the mouse is over it
function UIKit.Hover(target: GuiObject, stroke: UIStroke?)
	local s = stroke or target:FindFirstChildOfClass("UIStroke")
	if not s then
		return
	end
	local color, thickness = s.Color, s.Thickness
	local quick = TweenInfo.new(0.12)
	target.MouseEnter:Connect(function()
		TweenService:Create(s, quick, { Color = C.GoldDark, Thickness = thickness + 1 }):Play()
	end)
	target.MouseLeave:Connect(function()
		TweenService:Create(s, quick, { Color = color, Thickness = thickness }):Play()
	end)
end

-- Windows keep their design size and are scaled down to fit small screens (phones);
-- if even the smallest scale is too tall, the window gets shorter (lists scroll).
local MIN_WINDOW_SCALE = 0.62
local function fitWindow(holder: Frame): number
	local camera = Workspace.CurrentCamera
	local w = holder:GetAttribute("DesignWidth") or 600
	local h = holder:GetAttribute("DesignHeight") or 500
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	local inset = GuiService:GetGuiInset()
	local availW, availH = viewport.X * 0.96, (viewport.Y - inset.Y) * 0.94
	local s = math.clamp(math.min(availW / w, availH / h), MIN_WINDOW_SCALE, 1)
	holder.Size = UDim2.fromOffset(w, math.min(h, availH / s))
	local scale = holder:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = s
	end
	return s
end

export type Window = {
	Gui: ScreenGui,
	Frame: Frame,
	Header: Frame,
	Body: Frame,
	Title: TextLabel,
	Close: () -> (),
	OnClose: BindableEvent,
}

-- A centred wooden window: plank frame, parchment page, a title plaque and a red
-- wax-seal close button. Shrinks to fit small screens.
function UIKit.Window(name: string, title: string, size: UDim2, displayOrder: number?): Window
	local gui = UIKit.Screen(name, displayOrder or 5)
	gui.Enabled = false
	local holder = UIKit.new("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X.Offset, size.Y.Offset),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	holder:SetAttribute("DesignWidth", size.X.Offset)
	holder:SetAttribute("DesignHeight", size.Y.Offset)
	-- one UIScale both fits the window to small screens and plays the pop-in
	local pop = UIKit.new("UIScale", { Name = "Fit", Parent = holder })
	fitWindow(holder)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			fitWindow(holder)
		end)
	end
	-- soft drop shadow
	local shadow = UIKit.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		Parent = holder,
	})
	UIKit.Corner(shadow, 18)
	local frame = UIKit.new("Frame", {
		Name = "Frame",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.WoodLight,
		BorderSizePixel = 0,
		Parent = holder,
	})
	UIKit.Corner(frame, 16)
	UIKit.Stroke(frame, C.Shadow, 3)
	UIKit.Planks(frame, 8)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		UIKit.Rivet(frame, UDim2.new(corner.X, if corner.X == 0 then 9 else -9, corner.Y, if corner.Y == 0 then 9 else -9), 8)
	end

	local header = UIKit.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 60),
		Parent = frame,
	})
	-- title plaque
	local plaque = UIKit.new("Frame", {
		Name = "Plaque",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.WoodDark,
		Parent = header,
	})
	UIKit.Corner(plaque, 8)
	UIKit.Stroke(plaque, C.GoldDark, 2)
	UIKit.Gradient(plaque, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 150))
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 34), PaddingRight = UDim.new(0, 34), Parent = plaque })
	UIKit.Rivet(plaque, UDim2.new(0, -20, 0.5, 0), 7)
	UIKit.Rivet(plaque, UDim2.new(1, 20, 0.5, 0), 7)
	local titleLabel = UIKit.new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Text = title,
		FontFace = UIKit.Fonts.Title,
		TextSize = 26,
		TextColor3 = C.Gold,
		Parent = plaque,
	})
	UIKit.TextStroke(titleLabel, C.Shadow, 2)
	UIKit.Gradient(titleLabel, Color3.fromRGB(255, 248, 214), Color3.fromRGB(255, 196, 70))

	local onClose = Instance.new("BindableEvent")
	local function close()
		gui.Enabled = false
		onClose:Fire()
	end
	local x = UIKit.Button(header, "X", C.Crimson, close, {
		Name = "Close",
		Size = UDim2.fromOffset(40, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, 30),
	})
	local xCorner = x:FindFirstChildOfClass("UICorner")
	if xCorner then
		xCorner.CornerRadius = UDim.new(0.5, 0)
	end
	local xPad = x:FindFirstChildOfClass("UIPadding")
	if xPad then
		xPad:Destroy()
	end

	-- the parchment page
	local page = UIKit.Panel(frame, {
		Name = "Page",
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 1, -72),
	})
	local pageCorner = page:FindFirstChildOfClass("UICorner")
	if pageCorner then
		pageCorner.CornerRadius = UDim.new(0, 8)
	end
	local body = UIKit.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = page,
	})
	UIKit.Padding(body, 12)

	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			local fit = fitWindow(holder)
			pop.Scale = fit * 0.92
			TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fit }):Play()
		end
	end)
	return { Gui = gui, Frame = frame, Header = header, Body = body, Title = titleLabel, Close = close, OnClose = onClose }
end

-- Change a window's maximum size (it still shrinks to fit small screens)
function UIKit.SetWindowSize(window: Window, size: Vector2)
	local holder = window.Frame.Parent
	if holder and holder:IsA("Frame") then
		holder:SetAttribute("DesignWidth", size.X)
		holder:SetAttribute("DesignHeight", size.Y)
		local scale = holder:FindFirstChildOfClass("UIScale")
		local fit = fitWindow(holder)
		if scale then
			scale.Scale = fit
		end
	end
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
		ScrollBarImageColor3 = C.Wood,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6), Parent = scroll })
	apply(scroll, props)
	return scroll
end

-- Paper slip used for shop entries
function UIKit.Card(parent: Instance, height: number, order: number?): Frame
	local card = UIKit.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 251, 238),
		Size = UDim2.new(1, -14, 0, height),
		LayoutOrder = order or 0,
		Parent = parent,
	})
	UIKit.Corner(card, 10)
	UIKit.Stroke(card, Color3.fromRGB(190, 152, 98), 1.5)
	UIKit.Gradient(card, Color3.new(1, 1, 1), Color3.fromRGB(240, 230, 210))
	return card
end

-- Round medallion with an emoji
function UIKit.Icon(parent: Instance, glyph: string, size: number, color: Color3?, props: { [string]: any }?): Frame
	local medal = UIKit.new("Frame", {
		Name = "Icon",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color or C.Sea,
		Parent = parent,
	})
	UIKit.Round(medal)
	UIKit.Stroke(medal, C.GoldDark, math.max(2, size / 22))
	UIKit.Gradient(medal, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	UIKit.new("TextLabel", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.66, 0.66),
		BackgroundTransparency = 1,
		Text = glyph,
		TextScaled = true,
		TextColor3 = C.White,
		Parent = medal,
	})
	apply(medal, props)
	return medal
end

function UIKit.Coin(parent: Instance, size: number): Frame
	local coin = UIKit.new("Frame", {
		BackgroundColor3 = C.Gold,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	UIKit.Round(coin)
	UIKit.Stroke(coin, C.GoldDark, math.max(1.5, size / 14))
	UIKit.Gradient(coin, Color3.new(1, 1, 1), Color3.fromRGB(214, 170, 90), 45)
	UIKit.Label(coin, "$", {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = C.GoldDark,
		FontFace = UIKit.Fonts.Title,
	})
	return coin
end

-- Little price tag: coin + amount ("FREE" when 0)
function UIKit.PriceTag(parent: Instance, price: number, props: { [string]: any }?): Frame
	local tag = UIKit.new("Frame", {
		Name = "PriceTag",
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.WoodDark,
		Parent = parent,
	})
	UIKit.Round(tag)
	UIKit.Stroke(tag, C.GoldDark, 1.5)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), Parent = tag })
	local list = UIKit.List(tag, 5, true, Enum.HorizontalAlignment.Left)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local coin = UIKit.Coin(tag, 20)
	coin.LayoutOrder = 1
	local amount = UIKit.new("TextLabel", {
		Name = "Amount",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Text = if price <= 0 then "FREE" else UIKit.FormatNumber(price),
		FontFace = UIKit.Fonts.Title,
		TextSize = 17,
		TextColor3 = C.Gold,
		LayoutOrder = 2,
		Parent = tag,
	})
	UIKit.TextStroke(amount, C.Shadow, 1, 0.3)
	apply(tag, props)
	return tag
end

-- Small status ribbon: "OWNED", "RIGGED", "NEW"...
function UIKit.Badge(parent: Instance, text: string, color: Color3?, props: { [string]: any }?): TextLabel
	local badge = UIKit.new("TextLabel", {
		Name = "Badge",
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color or C.Green,
		Text = text,
		FontFace = UIKit.Fonts.Title,
		TextSize = 14,
		TextColor3 = C.White,
		Parent = parent,
	})
	UIKit.Corner(badge, 6)
	UIKit.Stroke(badge, C.Shadow, 1.5).Transparency = 0.2
	UIKit.TextStroke(badge, C.Shadow, 1, 0.3)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = badge })
	apply(badge, props)
	return badge
end

-- Row of tabs; the selected one is dark wood with gold letters
function UIKit.Tabs(parent: Instance, tabs: { { Id: string, Text: string } }, selected: string, onSelect: (string) -> (), props: { [string]: any }?): Frame
	local row = UIKit.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = parent,
	})
	UIKit.List(row, 8, true, Enum.HorizontalAlignment.Left)
	for i, tab in tabs do
		local on = tab.Id == selected
		UIKit.Button(row, tab.Text, if on then C.Wood else C.ParchmentDark, function()
			onSelect(tab.Id)
		end, {
			Name = tab.Id,
			Size = UDim2.fromOffset(176, 38),
			LayoutOrder = i,
			TextColor3 = if on then C.Gold else C.Ink,
		})
	end
	apply(row, props)
	return row
end

-- Thin rope-coloured divider line
function UIKit.Divider(parent: Instance, props: { [string]: any }?): Frame
	local line = UIKit.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, -20, 0, 2),
		BackgroundColor3 = C.Rope,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = parent,
	})
	apply(line, props)
	return line
end

UIKit.FormatNumber = Util.FormatNumber

return UIKit
