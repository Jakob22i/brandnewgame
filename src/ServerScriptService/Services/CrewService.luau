-- Crews: up to Config.MaxCrew pirates who sail together. Crewmates can't hurt each
-- other or each other's ship, and respawn aboard the crew's ship.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local CrewService = {}

type Crew = { Id: number, Captain: Player, Members: { Player } }

local crews: { [number]: Crew } = {}
local crewOf: { [Player]: Crew } = {}
local pendingInvites: { [Player]: { From: Player, Expires: number } } = {}
local nextId = 1
local changedCallbacks: { (Player) -> () } = {}

local function broadcast(crew: Crew?)
	if not crew then
		return
	end
	local members = {}
	for _, member in crew.Members do
		table.insert(members, { UserId = member.UserId, Name = member.DisplayName })
	end
	local payload = { Captain = crew.Captain.UserId, Members = members }
	for _, member in crew.Members do
		Net.Event("CrewClient"):FireClient(member, "Update", payload)
		member:SetAttribute("CrewId", crew.Id)
	end
end

local function fireChanged(player: Player)
	for _, cb in changedCallbacks do
		task.spawn(cb, player)
	end
end

function CrewService.OnChanged(callback: (Player) -> ())
	table.insert(changedCallbacks, callback)
end

function CrewService.AreAllies(a: Player?, b: Player?): boolean
	if a == nil or b == nil then
		return false
	end
	if a == b then
		return true
	end
	local crew = crewOf[a]
	return crew ~= nil and crew == crewOf[b]
end

-- All players in the same crew (always includes the player)
function CrewService.GetMembers(player: Player): { Player }
	local crew = crewOf[player]
	if not crew then
		return { player }
	end
	return table.clone(crew.Members)
end

function CrewService.Leave(player: Player)
	local crew = crewOf[player]
	if not crew then
		return
	end
	crewOf[player] = nil
	player:SetAttribute("CrewId", nil)
	local index = table.find(crew.Members, player)
	if index then
		table.remove(crew.Members, index)
	end
	if player.Parent then
		Net.Event("CrewClient"):FireClient(player, "Update", nil)
	end
	if #crew.Members <= 1 then
		for _, member in crew.Members do
			crewOf[member] = nil
			member:SetAttribute("CrewId", nil)
			Net.Event("CrewClient"):FireClient(member, "Update", nil)
			Net.Notify(member, "Your crew has disbanded.", "info")
			fireChanged(member)
		end
		crews[crew.Id] = nil
	else
		if crew.Captain == player then
			crew.Captain = crew.Members[1]
			Net.Notify(crew.Captain, "You are now the captain of the crew!", "good")
		end
		for _, member in crew.Members do
			Net.Notify(member, player.DisplayName .. " left the crew.", "info")
		end
		broadcast(crew)
	end
	fireChanged(player)
end

local function join(player: Player, inviter: Player)
	local crew = crewOf[inviter]
	if not crew then
		crew = { Id = nextId, Captain = inviter, Members = { inviter } }
		nextId += 1
		crews[crew.Id] = crew
		crewOf[inviter] = crew
	end
	if #crew.Members >= Config.MaxCrew then
		Net.Notify(player, "That crew is full.", "bad")
		return
	end
	if crewOf[player] then
		CrewService.Leave(player)
	end
	table.insert(crew.Members, player)
	crewOf[player] = crew
	for _, member in crew.Members do
		Net.Notify(member, player.DisplayName .. " joined the crew!", "good")
	end
	broadcast(crew)
	fireChanged(player)
	fireChanged(inviter)
end

local function onAction(player: Player, action: any, arg: any)
	if action == "Invite" then
		local target = if typeof(arg) == "number" then Players:GetPlayerByUserId(arg) else nil
		if not target or target == player then
			return
		end
		if CrewService.AreAllies(player, target) then
			Net.Notify(player, target.DisplayName .. " is already in your crew.", "info")
			return
		end
		local crew = crewOf[player]
		if crew and #crew.Members >= Config.MaxCrew then
			Net.Notify(player, "Your crew is full (" .. Config.MaxCrew .. " pirates).", "bad")
			return
		end
		pendingInvites[target] = { From = player, Expires = os.clock() + Config.InviteTimeout }
		Net.Event("CrewClient"):FireClient(target, "Invite", { UserId = player.UserId, Name = player.DisplayName, Timeout = Config.InviteTimeout })
		Net.Notify(player, "Crew invite sent to " .. target.DisplayName .. ".", "info")
	elseif action == "Respond" then
		local invite = pendingInvites[player]
		pendingInvites[player] = nil
		if not invite or os.clock() > invite.Expires or not invite.From.Parent then
			return
		end
		if arg == true then
			join(player, invite.From)
		else
			Net.Notify(invite.From, player.DisplayName .. " declined your crew invite.", "info")
		end
	elseif action == "Leave" then
		CrewService.Leave(player)
	end
end

function CrewService.Init()
	Net.Event("CrewAction").OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(player)
		pendingInvites[player] = nil
		CrewService.Leave(player)
	end)
end

return CrewService
