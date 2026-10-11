-- Visual and sound effects sent by the server: cannon fire and cannonballs,
-- splashes, pistol shots, digging, skeletons, coins and a tipsy grog camera.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local HUD = require(script.Parent.HUD)

local Effects = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SOUNDS = {
	Cannon = "rbxasset://sounds/Rocket shot.wav",
	Splash = "rbxasset://sounds/impact_water.mp3",
	Slash = "rbxasset://sounds/swordslash.wav",
	Shot = "rbxasset://sounds/Rocket shot.wav",
	Dig = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Coins = "rbxasset://sounds/electronicpingshort.wav",
	Bones = "rbxasset://sounds/swordlunge.wav",
}

local folder: Instance

local function anchorAt(position: Vector3, life: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(position)
	part.Parent = folder
	Debris:AddItem(part, life)
	return part
end

local function sound(id: string, position: Vector3?, volume: number?, speed: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 400
	if position then
		s.Parent = anchorAt(position, 4)
	else
		s.Parent = workspace.CurrentCamera
		Debris:AddItem(s, 4)
	end
	s:Play()
end

local function burst(position: Vector3, props: { [string]: any }, count: number)
	local part = anchorAt(position, 4)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SMOKE
	emitter.Rate = 0
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = part
	emitter:Emit(count)
end

local function splash(position: Vector3, big: boolean?)
	burst(position, {
		Color = ColorSequence.new(Color3.fromRGB(235, 255, 255)),
		Size = NumberSequence.new(if big then 3 else 2, if big then 9 else 6),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, -50, 0),
		LightEmission = 0.3,
	}, if big then 40 else 22)
	sound(SOUNDS.Splash, position, 0.8)
end

local function cannonball(origin: Vector3, velocity: Vector3, gravity: number, shipModel: Instance?)
	-- muzzle flash + smoke
	burst(origin, {
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(120, 110, 100)),
		Size = NumberSequence.new(2, 8),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(4, 10),
		SpreadAngle = Vector2.new(30, 30),
		LightEmission = 0.4,
	}, 25)
	sound(SOUNDS.Cannon, origin, 1, 0.55)
	local flash = anchorAt(origin, 0.15)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Range = 30
	light.Brightness = 6
	light.Parent = flash

	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.1, 1.1, 1.1)
	ball.Color = Color3.fromRGB(30, 30, 32)
	ball.Material = Enum.Material.Metal
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CFrame = CFrame.new(origin)
	ball.Parent = folder
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = SMOKE
	trail.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	trail.Size = NumberSequence.new(0.8, 2.5)
	trail.Transparency = NumberSequence.new(0.5, 1)
	trail.Lifetime = NumberRange.new(0.5, 0.8)
	trail.Rate = 40
	trail.Speed = NumberRange.new(0, 0)
	trail.Parent = ball

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, shipModel :: Instance }
	params.IgnoreWater = true
	local pos, vel, age = origin, velocity, 0
	local g = Vector3.new(0, -gravity, 0)
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		age += dt
		local nextVel = vel + g * dt
		local nextPos = pos + vel * dt + g * (0.5 * dt * dt)
		local hit = workspace:Raycast(pos, nextPos - pos, params)
		if hit or nextPos.Y <= Config.WaterLevel or age > Config.Cannon.Lifetime then
			connection:Disconnect()
			trail.Enabled = false
			ball.Transparency = 1
			Debris:AddItem(ball, 1)
			return
		end
		pos, vel = nextPos, nextVel
		ball.CFrame = CFrame.new(pos)
	end)
end

local function shot(origin: Vector3, hitPos: Vector3)
	local dir = hitPos - origin
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 230, 160)
	tracer.Size = Vector3.new(0.12, 0.12, dir.Magnitude)
	tracer.CFrame = CFrame.lookAt(origin + dir / 2, hitPos)
	tracer.Parent = folder
	Debris:AddItem(tracer, 0.08)
	burst(origin, {
		Color = ColorSequence.new(Color3.fromRGB(220, 220, 220)),
		Size = NumberSequence.new(0.6, 2),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(1, 3),
	}, 8)
	sound(SOUNDS.Shot, origin, 0.7, 1.6)
end

local function dirt(position: Vector3, count: number, sparkle: boolean?)
	burst(position, {
		Color = ColorSequence.new(Color3.fromRGB(200, 170, 120), Color3.fromRGB(150, 110, 70)),
		Size = NumberSequence.new(0.8, 1.6),
		Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -40, 0),
	}, count)
	if sparkle then
		burst(position + Vector3.new(0, 2, 0), {
			Texture = SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(255, 220, 110)),
			Size = NumberSequence.new(0.8, 0),
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(4, 10),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
		}, 40)
	end
	sound(SOUNDS.Dig, position, 0.8, 0.7)
end

local grogUntil = 0
local function startGrog()
	grogUntil = os.clock() + 10
end

function Effects.Init()
	folder = workspace:WaitForChild("Effects")
	Net.Event("Fx").OnClientEvent:Connect(function(kind, a, b, c, d)
		if kind == "Cannon" then
			cannonball(a, b, c, d)
		elseif kind == "Splash" then
			splash(a, true)
		elseif kind == "Slash" then
			sound(SOUNDS.Slash, a, 0.6)
		elseif kind == "Shot" then
			shot(a, b)
		elseif kind == "Dig" then
			dirt(a, 14)
		elseif kind == "Unearth" then
			dirt(a, 40, true)
		elseif kind == "HitMarker" then
			HUD.HitMarker()
		elseif kind == "Coins" then
			HUD.CoinBurst()
			sound(SOUNDS.Coins, nil, 0.5)
		elseif kind == "Grog" then
			startGrog()
		elseif kind == "Bones" then
			burst(a, {
				Color = ColorSequence.new(Color3.fromRGB(240, 232, 210)),
				Size = NumberSequence.new(1, 2.5),
				Transparency = NumberSequence.new(0.2, 1),
				Lifetime = NumberRange.new(0.8, 1.2),
				Speed = NumberRange.new(3, 7),
				SpreadAngle = Vector2.new(180, 180),
			}, 20)
			sound(SOUNDS.Bones, a, 0.6, 0.6)
		elseif kind == "SkeletonRise" then
			dirt(a, 20)
			burst(a + Vector3.new(0, 1, 0), {
				Color = ColorSequence.new(Color3.fromRGB(110, 255, 150)),
				Size = NumberSequence.new(2, 0),
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(2, 5),
				SpreadAngle = Vector2.new(60, 60),
				LightEmission = 1,
			}, 18)
		end
	end)
	-- wobbly camera after a grog
	RunService:BindToRenderStep("GrogWobble", Enum.RenderPriority.Camera.Value + 2, function()
		local remaining = grogUntil - os.clock()
		if remaining > 0 then
			local t = os.clock()
			local strength = math.min(1, remaining / 3) * 0.05
			local camera = workspace.CurrentCamera
			camera.CFrame = camera.CFrame * CFrame.Angles(math.sin(t * 1.3) * strength * 0.4, 0, math.sin(t * 0.9) * strength)
		end
	end)
end

return Effects
