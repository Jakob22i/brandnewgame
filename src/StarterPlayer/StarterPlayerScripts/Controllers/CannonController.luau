-- Manning a cannon: aim with the mouse (or drag on touch), click to fire, Space to leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local State = require(script.Parent.State)
local Station = require(script.Parent.Station)
local UIKit = require(script.Parent.UIKit)

local CannonController = {}

local player = Players.LocalPlayer
local C = UIKit.Colors
local cannon: Model? = nil
local carriage: BasePart? = nil
local pivot: BasePart? = nil
local yaw, pitch = 0, math.rad(4)
local maxYaw, minPitch, maxPitch = Config.Cannon.MaxYaw, Config.Cannon.MinPitch, Config.Cannon.MaxPitch
local lastFire = 0
local lastSent = 0
local dirty = false
local gui: ScreenGui
local reloadFill: Frame
local SENSITIVITY = 0.0035

local function aimCFrame(): CFrame?
	if not carriage or not pivot then
		return nil
	end
	return CFrame.new(pivot.Position) * carriage.CFrame.Rotation * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

local function fire()
	if not cannon then
		return
	end
	local now = os.clock()
	if now - lastFire < Config.Cannon.Cooldown then
		return
	end
	lastFire = now
	Net.Event("ShipAction"):FireServer("CannonFire", yaw, pitch)
end

local function leave()
	if cannon then
		Net.Event("ShipAction"):FireServer("LeaveCannon")
	end
end

local function exit()
	cannon, carriage, pivot = nil, nil, nil
	Station.Unlock()
	Station.SetControlsEnabled(true)
	State.SetMode(nil)
	gui.Enabled = false
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function enter(model: Model, _ship: Model, yawLimit: number?, pitchMin: number?, pitchMax: number?)
	local c = model:FindFirstChild("Carriage")
	local p = model:FindFirstChild("Pivot")
	if not c or not c:IsA("BasePart") or not p or not p:IsA("BasePart") then
		return
	end
	local point = c:FindFirstChild("OperatorPoint")
	if not point or not point:IsA("Attachment") then
		return
	end
	cannon, carriage, pivot = model, c, p
	maxYaw = yawLimit or maxYaw
	minPitch = pitchMin or minPitch
	maxPitch = pitchMax or maxPitch
	yaw, pitch = 0, math.rad(4)
	State.SetMode("Cannon")
	Station.SetControlsEnabled(false)
	local height = Station.RootHeight()
	Station.Lock(function()
		return if point.Parent then point.WorldCFrame * CFrame.new(0, height, 0) else nil
	end, function()
		return c.AssemblyLinearVelocity
	end)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseIconEnabled = false
	gui.Enabled = true
end

local function buildGui()
	gui = UIKit.Screen("CannonControls", 3)
	gui.Enabled = false
	local cross = UIKit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Text = "+",
		Font = UIKit.Fonts.Body,
		TextSize = 40,
		TextColor3 = C.White,
		Parent = gui,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = cross
	local hint = UIKit.Panel(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(440, 66),
	})
	UIKit.Label(hint, "Move mouse to aim  -  Click to fire  -  Space to leave", {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 24),
		Font = UIKit.Fonts.Small,
	})
	local back = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.new(0.8, 0, 0, 14),
		BackgroundColor3 = C.ParchmentDark,
		Parent = hint,
	})
	UIKit.Corner(back, 7)
	reloadFill = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Green, Parent = back })
	UIKit.Corner(reloadFill, 7)
	UIKit.Button(gui, "FIRE!", C.Red, fire, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -170),
		Size = UDim2.fromOffset(120, 120),
	})
	UIKit.Button(gui, "Leave", C.Wood, leave, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -300),
		Size = UDim2.fromOffset(120, 44),
	})
end

function CannonController.Init()
	buildGui()
	Net.Event("ShipClient").OnClientEvent:Connect(function(kind, model, ship, a, b, c)
		if kind == "EnterCannon" then
			enter(model, ship, a, b, c)
		elseif kind == "ExitCannon" then
			exit()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not cannon then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonB then
			if not processed then
				leave()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			if not processed then
				fire()
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not cannon then
			return
		end
		local delta: Vector3? = nil
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			delta = input.Delta
		elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
			delta = input.Delta * 1.5
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			delta = Vector3.new(input.Position.X * 12, -input.Position.Y * 12, 0)
		end
		if delta then
			yaw = math.clamp(yaw - delta.X * SENSITIVITY, -maxYaw, maxYaw)
			pitch = math.clamp(pitch - delta.Y * SENSITIVITY, minPitch, maxPitch)
			dirty = true
		end
	end)
	RunService:BindToRenderStep("CannonCamera", Enum.RenderPriority.Camera.Value + 1, function()
		if not cannon then
			return
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		local aim = aimCFrame()
		if aim then
			local camera = workspace.CurrentCamera
			local eye = aim * CFrame.new(1.2, 3.4, 10)
			camera.CFrame = CFrame.lookAt(eye.Position, (aim * CFrame.new(0, 2, -80)).Position)
		end
		local now = os.clock()
		reloadFill.Size = UDim2.fromScale(math.clamp((now - lastFire) / Config.Cannon.Cooldown, 0, 1), 1)
		if dirty and now - lastSent > 0.1 then
			dirty = false
			lastSent = now
			Net.Event("ShipAction"):FireServer("CannonAim", yaw, pitch)
		end
	end)
	player.CharacterAdded:Connect(function()
		if cannon then
			exit()
		end
	end)
end

return CannonController
