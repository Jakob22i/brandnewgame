-- Small world touches that only need to run on each player's screen:
-- the lighthouse beam at night and the spray/wake behind sailing ships.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Ambience = {}

function Ambience.Init()
	local beams = CollectionService:GetTagged("LighthouseBeam")
	local base: { [BasePart]: CFrame } = {}
	for _, beam in beams do
		if beam:IsA("BasePart") then
			base[beam] = beam.CFrame
		end
	end
	RunService.RenderStepped:Connect(function()
		local clock = Lighting.ClockTime
		local night = clock < 6.3 or clock > 18.2
		local angle = os.clock() * 0.6
		for beam, cf in base do
			beam.Transparency = if night then 0.84 else 1
			if night then
				beam.CFrame = cf * CFrame.Angles(0, angle, 0)
			end
		end
	end)

	task.spawn(function()
		local shipsFolder = workspace:WaitForChild("Ships")
		while true do
			task.wait(0.15)
			for _, ship in shipsFolder:GetChildren() do
				local root = ship:IsA("Model") and ship.PrimaryPart
				if root then
					local speed = root.AssemblyLinearVelocity.Magnitude
					for _, attachmentName in { "BowSpray", "SternWake" } do
						local attachment = root:FindFirstChild(attachmentName)
						local emitter = attachment and attachment:FindFirstChild("Wake")
						if emitter and emitter:IsA("ParticleEmitter") then
							emitter.Rate = if speed > 6 then math.min(speed * 1.6, 90) else 0
						end
					end
				end
			end
		end
	end)
end

return Ambience
