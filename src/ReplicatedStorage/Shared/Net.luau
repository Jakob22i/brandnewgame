--!strict
-- Access to the RemoteEvents/RemoteFunctions in ReplicatedStorage.Remotes
-- (they are created by the build script, see build/build.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = ReplicatedStorage:WaitForChild("Remotes")

function Net.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

-- Server only: show a toast message on a player's screen.
-- kind: "info" | "good" | "bad" | "gold" | "warn"
function Net.Notify(player: Player, text: string, kind: string?)
	Net.Event("Notify"):FireClient(player, text, kind or "info")
end

function Net.NotifyAll(text: string, kind: string?)
	Net.Event("Notify"):FireAllClients(text, kind or "info")
end

return Net
