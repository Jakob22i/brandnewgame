-- Player-to-player trading of gold, weapons and treasure maps.
-- Trades can only happen inside Kingshaven (the safe zone). Both pirates must press
-- Ready and then Confirm; any change to an offer resets both.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

local TradeService = {}

type Offer = { Gold: number, Items: { [string]: boolean }, Maps: { [number]: boolean } }
type Session = {
	A: Player,
	B: Player,
	Offers: { [Player]: Offer },
	Ready: { [Player]: boolean },
	Confirmed: { [Player]: boolean },
	Phase: string,
}

local sessions: { [Player]: Session } = {}
local invites: { [Player]: { From: Player, Expires: number } } = {}

local function inHaven(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and Util.InSafeZone(root.Position)
end

local function other(session: Session, player: Player): Player
	return if session.A == player then session.B else session.A
end

local function offerView(offer: Offer, owner: Player)
	local data = DataService.Get(owner)
	local items, maps = {}, {}
	for id in offer.Items do
		table.insert(items, id)
	end
	if data then
		for _, map in data.Maps do
			if offer.Maps[map.Id] then
				table.insert(maps, { Id = map.Id, Tier = map.Tier, Island = map.Island })
			end
		end
	end
	return { Gold = offer.Gold, Items = items, Maps = maps }
end

local function push(session: Session)
	for _, player in { session.A, session.B } do
		local them = other(session, player)
		Net.Event("TradeClient"):FireClient(player, "State", {
			TheirName = them.DisplayName,
			You = offerView(session.Offers[player], player),
			Them = offerView(session.Offers[them], them),
			YouReady = session.Ready[player] == true,
			ThemReady = session.Ready[them] == true,
			YouConfirmed = session.Confirmed[player] == true,
			ThemConfirmed = session.Confirmed[them] == true,
			Phase = session.Phase,
		})
	end
end

local function close(session: Session, message: string?, kind: string?)
	for _, player in { session.A, session.B } do
		if sessions[player] == session then
			sessions[player] = nil
		end
		if player.Parent then
			Net.Event("TradeClient"):FireClient(player, "Close")
			if message then
				Net.Notify(player, message, kind)
			end
		end
	end
end

local function resetReady(session: Session)
	session.Ready = {}
	session.Confirmed = {}
	session.Phase = "Edit"
end

local function validate(session: Session): (boolean, string?)
	for _, giver in { session.A, session.B } do
		local receiver = other(session, giver)
		local gData, rData = DataService.Get(giver), DataService.Get(receiver)
		if not gData or not rData then
			return false, "Trade failed: data not loaded."
		end
		local offer = session.Offers[giver]
		if offer.Gold > gData.Gold then
			return false, giver.DisplayName .. " doesn't have that much gold."
		end
		for id in offer.Items do
			local item = Config.Items[id]
			if not gData.Items[id] or not item or not item.Tradeable then
				return false, giver.DisplayName .. " no longer has " .. id .. "."
			end
			if rData.Items[id] then
				return false, receiver.DisplayName .. " already owns a " .. item.DisplayName .. "."
			end
		end
		local incoming = 0
		for mapId in offer.Maps do
			local found = false
			for _, map in gData.Maps do
				if map.Id == mapId then
					found = true
				end
			end
			if not found then
				return false, "A treasure map in the trade is gone."
			end
			incoming += 1
		end
		local outgoing = 0
		for _ in session.Offers[receiver].Maps do
			outgoing += 1
		end
		if #rData.Maps - outgoing + incoming > Config.MaxMaps then
			return false, receiver.DisplayName .. " can't carry that many maps (max " .. Config.MaxMaps .. ")."
		end
	end
	return true, nil
end

local function execute(session: Session)
	local ok, err = validate(session)
	if not ok then
		resetReady(session)
		push(session)
		for _, p in { session.A, session.B } do
			Net.Notify(p, err or "Trade failed.", "bad")
		end
		return
	end
	-- take everything out first, then hand it over
	local moved: { [Player]: { Gold: number, Items: { string }, Maps: { any } } } = {}
	for _, giver in { session.A, session.B } do
		local data = DataService.Get(giver) :: DataService.PlayerData
		local offer = session.Offers[giver]
		local bundle = { Gold = offer.Gold, Items = {}, Maps = {} }
		data.Gold -= offer.Gold
		for id in offer.Items do
			data.Items[id] = nil
			table.insert(bundle.Items, id)
		end
		for i = #data.Maps, 1, -1 do
			local map = data.Maps[i]
			if offer.Maps[map.Id] then
				table.remove(data.Maps, i)
				table.insert(bundle.Maps, map)
			end
		end
		moved[giver] = bundle
	end
	for _, giver in { session.A, session.B } do
		local receiver = other(session, giver)
		local data = DataService.Get(receiver) :: DataService.PlayerData
		local bundle = moved[giver]
		data.Gold += bundle.Gold
		for _, id in bundle.Items do
			data.Items[id] = true
		end
		for _, map in bundle.Maps do
			map.Id = data.NextMapId
			data.NextMapId += 1
			table.insert(data.Maps, map)
		end
	end
	for _, player in { session.A, session.B } do
		DataService.Changed(player)
		InventoryService.Refresh(player)
		DataService.Save(player)
	end
	close(session, "Trade complete! Fair winds, matey.", "good")
end

local function openSession(a: Player, b: Player)
	local session: Session = {
		A = a,
		B = b,
		Offers = {
			[a] = { Gold = 0, Items = {}, Maps = {} },
			[b] = { Gold = 0, Items = {}, Maps = {} },
		},
		Ready = {},
		Confirmed = {},
		Phase = "Edit",
	}
	sessions[a] = session
	sessions[b] = session
	for _, player in { a, b } do
		Net.Event("TradeClient"):FireClient(player, "Open")
	end
	push(session)
end

local function onAction(player: Player, action: any, arg: any)
	if action == "Request" then
		local target = if type(arg) == "number" then Players:GetPlayerByUserId(arg) else nil
		if not target or target == player then
			return
		end
		if not inHaven(player) or not inHaven(target) then
			Net.Notify(player, "Both pirates must be in Kingshaven to trade.", "bad")
			return
		end
		if sessions[player] or sessions[target] then
			Net.Notify(player, "One of you is already trading.", "bad")
			return
		end
		invites[target] = { From = player, Expires = os.clock() + Config.InviteTimeout }
		Net.Event("TradeClient"):FireClient(target, "Invite", { UserId = player.UserId, Name = player.DisplayName, Timeout = Config.InviteTimeout })
		Net.Notify(player, "Trade request sent to " .. target.DisplayName .. ".", "info")
		return
	elseif action == "Respond" then
		local invite = invites[player]
		invites[player] = nil
		if not invite or os.clock() > invite.Expires or not invite.From.Parent then
			return
		end
		if arg ~= true then
			Net.Notify(invite.From, player.DisplayName .. " declined the trade.", "info")
			return
		end
		if sessions[player] or sessions[invite.From] or not inHaven(player) or not inHaven(invite.From) then
			Net.Notify(player, "The trade can't start right now.", "bad")
			return
		end
		openSession(invite.From, player)
		return
	end

	local session = sessions[player]
	if not session then
		return
	end
	local offer = session.Offers[player]
	local data = DataService.Get(player)
	if not data then
		return
	end
	if action == "Cancel" then
		close(session, player.DisplayName .. " cancelled the trade.", "info")
		return
	elseif action == "SetGold" then
		if not Util.IsFiniteNumber(arg) then
			return
		end
		offer.Gold = math.clamp(math.floor(arg), 0, data.Gold)
		resetReady(session)
	elseif action == "ToggleItem" then
		local item = if type(arg) == "string" then Config.Items[arg] else nil
		if item and item.Tradeable and data.Items[item.Id] then
			offer.Items[item.Id] = if offer.Items[item.Id] then nil else true
			resetReady(session)
		end
	elseif action == "ToggleMap" then
		if type(arg) == "number" then
			for _, map in data.Maps do
				if map.Id == arg then
					offer.Maps[arg] = if offer.Maps[arg] then nil else true
					resetReady(session)
				end
			end
		end
	elseif action == "Ready" then
		session.Ready[player] = arg == true
		session.Confirmed = {}
		session.Phase = if session.Ready[session.A] and session.Ready[session.B] then "Confirm" else "Edit"
	elseif action == "Confirm" then
		if session.Phase ~= "Confirm" then
			return
		end
		session.Confirmed[player] = true
		if session.Confirmed[session.A] and session.Confirmed[session.B] then
			execute(session)
			return
		end
	end
	push(session)
end

function TradeService.Init()
	Net.Event("TradeAction").OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		local session = sessions[player]
		if session then
			close(session, "The other pirate left. Trade cancelled.", "info")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local checked: { [Session]: boolean } = {}
			for _, session in sessions do
				if not checked[session] then
					checked[session] = true
					if not inHaven(session.A) or not inHaven(session.B) then
						close(session, "Trade cancelled: both pirates must stay in Kingshaven.", "bad")
					end
				end
			end
		end
	end)
end

return TradeService
