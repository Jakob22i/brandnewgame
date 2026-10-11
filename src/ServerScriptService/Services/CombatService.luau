-- Damage rules (PvP, crews, safe zone) and the player weapons: cutlass and flintlock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CrewService = require(script.Parent.CrewService)
local InventoryService = require(script.Parent.InventoryService)

local CombatService = {}

type Hit = { Player: Player?, Time: number }
local lastAttacker: { [Humanoid]: Hit } = setmetatable({}, { __mode = "k" }) :: any
local cooldowns: { [Player]: { [string]: number } } = {}

local function rootOf(model: Instance?): BasePart?
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function CombatService.IsAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Can `attacker` (nil = the world / an enemy) hurt this humanoid?
function CombatService.CanDamage(attacker: Player?, humanoid: Humanoid): boolean
	local model = humanoid.Parent
	if not model or humanoid.Health <= 0 then
		return false
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		local root = rootOf(model)
		if root and Util.InSafeZone(root.Position) then
			return false
		end
		if attacker then
			if CrewService.AreAllies(attacker, victim) then
				return false
			end
			local attackerRoot = rootOf(attacker.Character)
			if attackerRoot and Util.InSafeZone(attackerRoot.Position) then
				return false
			end
		end
		return true
	end
	-- NPCs: only enemies can be hurt, and only by players
	return model:GetAttribute("Enemy") == true and attacker ~= nil
end

function CombatService.DamageHumanoid(attacker: Player?, humanoid: Humanoid, amount: number): boolean
	if not CombatService.CanDamage(attacker, humanoid) then
		return false
	end
	lastAttacker[humanoid] = { Player = attacker, Time = os.clock() }
	humanoid:TakeDamage(amount)
	if attacker then
		Net.Event("Fx"):FireClient(attacker, "HitMarker")
	end
	return true
end

function CombatService.GetLastAttacker(humanoid: Humanoid, within: number?): Player?
	local hit = lastAttacker[humanoid]
	if hit and os.clock() - hit.Time <= (within or 15) then
		return hit.Player
	end
	return nil
end

function CombatService.CooldownReady(player: Player, key: string, cooldown: number): boolean
	local list = cooldowns[player]
	if not list then
		list = {}
		cooldowns[player] = list
	end
	local now = os.clock()
	if list[key] and now - list[key] < cooldown then
		return false
	end
	list[key] = now
	return true
end

function CombatService.PlayToolAnimation(tool: Tool, animation: string)
	local value = Instance.new("StringValue")
	value.Name = "toolanim"
	value.Value = animation
	value.Parent = tool
	task.delay(1, function()
		if value.Parent then
			value:Destroy()
		end
	end)
end

-- Humanoids in front of a character within range
function CombatService.FindTargetsInFront(character: Model, range: number): { Humanoid }
	local root = rootOf(character)
	if not root then
		return {}
	end
	local look = root.CFrame.LookVector
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local parts = workspace:GetPartBoundsInRadius(root.Position + look * (range * 0.5), range * 0.75, params)
	local found: { [Humanoid]: boolean } = {}
	local list = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and not found[humanoid] and humanoid.Health > 0 then
			local targetRoot = rootOf(model) or part
			local offset = targetRoot.Position - root.Position
			if offset.Magnitude <= range + 2.5 and (offset.Magnitude < 2 or look:Dot(offset.Unit) > 0.05) then
				found[humanoid] = true
				table.insert(list, humanoid)
			end
		end
	end
	return list
end

local function swing(player: Player)
	local character = player.Character
	local tool = InventoryService.GetEquipped(player, { "Cutlass", "GoldenCutlass" })
	if not character or not tool or not CombatService.IsAlive(player) then
		return
	end
	local item = Config.Items[tool.Name]
	if not CombatService.CooldownReady(player, "Swing", (item.Cooldown or 0.5) * 0.9) then
		return
	end
	CombatService.PlayToolAnimation(tool, "Slash")
	local root = rootOf(character)
	if root then
		Net.Event("Fx"):FireAllClients("Slash", root.Position)
	end
	for _, humanoid in CombatService.FindTargetsInFront(character, item.Range or 7) do
		CombatService.DamageHumanoid(player, humanoid, item.Damage or 20)
	end
end

local function shoot(player: Player, aim: any)
	if not Util.IsValidVector(aim) then
		return
	end
	local character = player.Character
	local tool = InventoryService.GetEquipped(player, { "Flintlock" })
	local head = character and character:FindFirstChild("Head")
	if not character or not tool or not head or not head:IsA("BasePart") or not CombatService.IsAlive(player) then
		return
	end
	local item = Config.Items.Flintlock
	if not CombatService.CooldownReady(player, "Shoot", (item.Cooldown or 2.5) * 0.9) then
		return
	end
	local handle = tool:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("MuzzleAttachment")
	local origin = if muzzle and muzzle:IsA("Attachment") then muzzle.WorldPosition else head.Position
	if (origin - head.Position).Magnitude > 8 then
		origin = head.Position
	end
	local direction = aim - origin
	if direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit * (item.Range or 250)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("Effects") :: Instance }
	params.IgnoreWater = true
	local result = workspace:Raycast(origin, direction, params)
	local hitPosition = if result then result.Position else origin + direction
	if result then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local damage = item.Damage or 40
			if result.Instance.Name == "Head" then
				damage *= 1.5
			end
			CombatService.DamageHumanoid(player, humanoid, damage)
		end
	end
	Net.Event("Fx"):FireAllClients("Shot", origin, hitPosition)
end

function CombatService.Init()
	Net.Event("CombatAction").OnServerEvent:Connect(function(player, action, arg)
		if action == "Swing" then
			swing(player)
		elseif action == "Shoot" then
			shoot(player, arg)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
end

return CombatService
