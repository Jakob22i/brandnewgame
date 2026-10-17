-- "How to play" window (opens automatically the first time you spawn).

local Players = game:GetService("Players")

local HUD = require(script.Parent.HUD)
local UIKit = require(script.Parent.UIKit)

local HelpUI = {}

local C = UIKit.Colors
local window: UIKit.Window

local SECTIONS = {
	{ "Your first voyage", "1. Talk to Madame Coralie (Merchant) and buy a Castaway's Map.\n2. Talk to Captain Barnaby (Shipwright) and Launch your free Sloop.\n3. Equip your map to see which island has the X.\n4. Sail there, equip the Shovel and click on the X to dig.\n5. Carry the chest back and sell it to Madame Coralie!" },
	{ "Shopkeepers", "Press E near a shopkeeper to talk. Pick an answer with the mouse, a tap or the keys 1-4.\nAsk them for news - they know the best tips and rumours.\nCaptain Barnaby also paints your sails: new colours and symbols for your ship." },
	{ "Sailing", "Press E at the wheel to take the helm (one pirate at a time).\nA/D turn the wheel - it stays where you leave it (C centres it).\nW/S lower and raise the sails. Raise the anchor at the capstan first!\nSail with the wind (arrow on the compass) to go faster." },
	{ "Fighting", "Cutlass: click to swing. Flintlock: click to shoot.\nCannons: press E at a cannon, aim with the mouse, click to fire.\nCannonballs blast holes in ships - repair holes on deck before you sink!\nKingshaven is a safe haven: no fighting there." },
	{ "Plunder", "Chests on your deck sail with you - and can be stolen.\nDefeat pirates carrying treasure to make them drop it.\nSink rival ships for a reward. Their cargo floats to the surface.\nThe richest pirate online is crowned King of the Pirates!" },
	{ "Crew & trading", "Open CREW [P] to invite pirates or trade with them.\nCrewmates can't hurt each other and respawn on the crew's ship.\nTrades only work in Kingshaven." },
}

function HelpUI.Toggle()
	window.Gui.Enabled = not window.Gui.Enabled
end

function HelpUI.Init()
	window = UIKit.Window("HelpWindow", "How to be a Pirate", UDim2.fromOffset(640, 560), 6)
	local scroll = UIKit.Scroll(window.Body)
	UIKit.List(scroll, 8)
	for i, section in SECTIONS do
		local card = UIKit.Card(scroll, 0, i)
		card.AutomaticSize = Enum.AutomaticSize.Y
		UIKit.Padding(card, 10)
		UIKit.List(card, 4, false, Enum.HorizontalAlignment.Left)
		UIKit.Label(card, section[1], { FontFace = UIKit.Fonts.Title, TextColor3 = C.Wood, Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
		UIKit.Label(card, section[2], {
			TextScaled = false,
			TextSize = 16,
			LineHeight = 1.2,
			FontFace = UIKit.Fonts.Text,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
		})
	end
	HUD.AddMenuButton("HELP", Enum.KeyCode.H, 3, C.Green, HelpUI.Toggle)
	local player = Players.LocalPlayer
	task.spawn(function()
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(2)
		window.Gui.Enabled = true
	end)
end

return HelpUI
