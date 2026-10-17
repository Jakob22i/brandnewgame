-- Talking to the shopkeepers of Kingshaven. Triggering a ShopPrompt makes the server
-- fire OpenShop(shopId); instead of dumping you into a shop window the shopkeeper
-- greets you in a speech panel at the bottom of the screen: name plate, typewriter
-- text and 2-4 answers (click, tap or press 1-4). The camera gently frames the NPC.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local HUD = require(script.Parent.HUD)
local ShopUI = require(script.Parent.ShopUI)
local State = require(script.Parent.State)
local UIKit = require(script.Parent.UIKit)

local DialogueUI = {}

local player = Players.LocalPlayer
local C = UIKit.Colors

local PANEL_W, PANEL_H = 920, 220
local CHOICES_W = 316
local CLOSE_DISTANCE = 18
local TYPE_SPEED = 55 -- letters per second

type Person = {
	Name: string,
	Role: string,
	Icon: string,
	Accent: Color3,
	Greetings: { string },
	News: { string },
	Farewells: { string },
	About: { string }?,
	AboutQuestion: string?,
}

-- The shopkeepers and how they talk -------------------------------------------
local PEOPLE: { [string]: Person } = {
	Shipwright = {
		Name = "Captain Barnaby",
		Role = "Shipwright of Kingshaven",
		Icon = "⚓",
		Accent = Color3.fromRGB(40, 92, 140),
		Greetings = {
			"Ahoy, {player}! Barnaby's the name, and ships be me trade.",
			"Mind the sawdust, matey. Lookin' for a vessel worthy o' the sea?",
			"Back again, {player}? She'll float, I promise. Most of 'em do.",
			"Every plank on these docks I nailed meself. What can I build ye?",
			"Ye've the look of a captain in need of a faster ship!",
		},
		News = {
			"Sail with the wind at yer back and ye'll fly. Mind the arrow on yer compass!",
			"Drop anchor at full speed and she'll spin like a top. Handy for a sharp turn.",
			"A Galleon carries eight cannons. Eight! Enough to make the Kraken blush.",
			"Black sails strike fear, aye. But blood-red sails? They tell rivals ye mean business.",
			"Holes in the hull bleed yer ship dry. Patch 'em quick, or swim home.",
			"Anchor here in Kingshaven and my lads will mend yer hull for free.",
			"I paint any symbol ye fancy on yer sails. A kraken looks mighty fine on white canvas.",
		},
		Farewells = { "Fair winds, {player}!", "Bring her back in one piece, aye?", "May yer hull stay dry!" },
	},
	Merchant = {
		Name = "Madame Coralie",
		Role = "Merchant of Maps & Treasure",
		Icon = "🗺️",
		Accent = Color3.fromRGB(118, 52, 120),
		Greetings = {
			"Bonjour, chéri! Maps, secrets and treasure... Coralie has them all.",
			"Ah, {player}! You smell of salt and adventure. I like that.",
			"Every X on my maps hides a fortune... for those brave enough to dig.",
			"Welcome to the Trading Company, mon ami. What shall it be?",
		},
		News = {
			"A Captain's map sometimes leads to the Chest of the Pirate King himself... so they whisper.",
			"Guarded treasure? Bring friends, chéri. Skeletons do not share.",
			"Lost a chest overboard? It floats! Swim after it before the sharks get curious.",
			"Bring chests to my counter and I pay in gold. Heavier chests, heavier purses.",
			"Castaway maps lead to the little islands nearby. Perfect for a first voyage.",
			"Equip your map to see the island, then dig where X marks the spot.",
		},
		Farewells = { "Au revoir, chéri!", "Come back rich, oui?", "Bonne chance out there!" },
	},
	Armory = {
		Name = "Old Ironhook",
		Role = "Keeper of the Armory",
		Icon = "⚔️",
		Accent = Color3.fromRGB(128, 34, 34),
		Greetings = {
			"Hrmph. Lookin' to arm yerself, {player}?",
			"Careful. That blade's sharper than me temper.",
			"Ironhook's the name. Steel's the game.",
			"Ye look like ye've never swung a cutlass. Let's fix that.",
		},
		News = {
			"A flintlock hits hard from afar, but the reload takes an age. Make the shot count.",
			"Skeletons crawl out o' the sand at night. Steel sends 'em back to their graves.",
			"The Golden Cutlass swings faster. Speed wins fights, lad.",
			"Kingshaven's a safe haven. Out there it's every pirate for 'imself.",
			"Crewmates can't hurt each other. Strangers can. Watch yer back.",
		},
		AboutQuestion = "What happened to your hand?",
		About = {
			"Lost it to a shark off Skull Rock. It ate me hand, so I ate the shark. Fair trade.",
			"Duel with a skeleton captain. He lost his head, I lost me hand. I won, mind ye.",
			"Hrmph. Ask me again and ye'll find out how sharp the hook is.",
		},
		Farewells = { "Stay sharp.", "Don't come back with holes in ye.", "Hrmph. Off with ye, then." },
	},
	Tavern = {
		Name = "Rosie the Barkeep",
		Role = "The Rusty Anchor Tavern",
		Icon = "🍺",
		Accent = Color3.fromRGB(46, 112, 64),
		Greetings = {
			"Welcome to the Rusty Anchor, love! Pull up a barrel.",
			"Back again, {player}? The grog's fresh. Well... fresh-ish.",
			"Oi! Wipe yer boots! Now, what'll it be?",
			"Ahoy, sweetheart! Sit, sit. Ye look parched.",
		},
		News = {
			"They say a Chest of the Pirate King hides behind some Captain's maps...",
			"Skull Rock and Devil's Ridge are crawling with the undead. I'd stay away. You won't, will ye?",
			"Treasure on your deck sails with you... and rivals can steal it right off the boards!",
			"Old Ironhook says he lost his hand to a shark. Last week it was a skeleton. Next week, a mermaid.",
			"Madame Coralie's maps never lie. Her prices, though...",
			"Past the edge of the chart lies the Devil's Sea. It tears ships apart. Turn back, love.",
			"Drop anchor at full speed and yer ship spins like a top. Barnaby swears by it.",
		},
		Farewells = { "Mind the door on yer way out!", "Come back when ye're thirsty!", "Don't sink, love!" },
	},
	TradingPost = {
		Name = "Jules the Trader",
		Role = "Trading Post",
		Icon = "🦜",
		Accent = Color3.fromRGB(40, 104, 170),
		Greetings = {
			"Jules at your service! SQUAWK! ...That was the parrot, not me.",
			"Fair trades only! Well... mostly fair.",
			"Got something to swap, {player}? I know every pirate in port.",
		},
		News = {
			"Trades only work here in Kingshaven. Out at sea it's cannons, not contracts.",
			"Crewmates respawn on the crew's ship. A good crew is worth more than gold!",
			"Starter gear can't be traded, but maps and fine weapons can.",
			"Both pirates press Ready, then Confirm. No take-backs, savvy?",
			"The richest pirate online gets their name on the King's statue. Gold talks, and it talks loud!",
		},
		AboutQuestion = "Who's your feathered friend?",
		About = {
			"This is Captain Squawks. He handles the accounting. SQUAWK!",
			"Squawks once sold a ship he didn't own. Proudest day of my life.",
		},
		Farewells = { "Pleasure doing business!", "SQUAWK! Bye bye!", "Come back with something shiny!" },
	},
}

local GROG_OK = {
	"There ye go! Drink up, love. On second thought... maybe sip it.",
	"One grog, extra rum! Yer wounds won't know what hit 'em.",
	"Bottoms up, {player}! Yo ho ho!",
}

-- Runtime state ------------------------------------------------------------------
type Choice = { Text: string, Run: () -> () }

local gui: ScreenGui
local root: Frame
local namePlate: Frame
local nameLabel: TextLabel
local roleLabel: TextLabel
local iconLabel: TextLabel
local iconMedal: Frame
local speech: TextLabel
local choicesFrame: Frame
local skipHint: TextLabel
local scale: UIScale

local current: string? = nil -- shop id
local npcModel: Model? = nil
local person: Person? = nil
local lastLine: { [string]: string? } = {}
local typingToken = 0
local pendingDone: (() -> ())? = nil
local choiceList: { Choice } = {}
local closing = false
local conversationId = 0

local savedCamera: { CFrame: CFrame, Type: Enum.CameraType, Fov: number }? = nil

local function format(text: string): string
	local king = Workspace:GetAttribute("KingName")
	local out = string.gsub(text, "{player}", player.DisplayName)
	out = string.gsub(out, "{king}", if type(king) == "string" and king ~= "" then king else "Nobody")
	return out
end

local function pick(list: { string }, key: string): string
	if #list == 0 then
		return "..."
	end
	local line = list[math.random(1, #list)]
	if #list > 1 and line == lastLine[key] then
		line = list[(table.find(list, line) or 1) % #list + 1]
	end
	lastLine[key] = line
	return format(line)
end

local function findNpc(shopId: string): Model?
	for _, npc in CollectionService:GetTagged("ShopNPC") do
		if npc:GetAttribute("ShopId") == shopId and npc:IsA("Model") then
			return npc
		end
	end
	return nil
end

local function npcRoot(): BasePart?
	local model = npcModel
	local hrp = model and model:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp else nil
end

-- Use the NPC model's own name when the town builder gave it one
local function displayName(shopId: string, fallback: string): string
	local model = npcModel
	if model then
		local name = model.Name
		if name ~= "" and name ~= shopId and name ~= "Npc" and name ~= "NPC" and name ~= "Model" then
			return name
		end
	end
	return fallback
end

-- The default hotbar also listens to the number keys; hide it while talking
local function setBackpack(enabled: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
	end)
end

---------------------------------------------------------------------------
-- Camera
---------------------------------------------------------------------------
local function frameNpc()
	local camera = Workspace.CurrentCamera
	local hrp = npcRoot()
	local model = npcModel
	local head = model and model:FindFirstChild("Head")
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not camera or not hrp or not myRoot or not myRoot:IsA("BasePart") or State.Mode ~= nil then
		return
	end
	local headPos = if head and head:IsA("BasePart") then head.Position else hrp.Position + Vector3.new(0, 1.5, 0)
	local away = myRoot.Position - headPos
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.5 then
		away = hrp.CFrame.LookVector
	end
	away = away.Unit
	local screenRight = (-away):Cross(Vector3.yAxis)
	-- over the player's right shoulder, slightly above eye level; the NPC sits above
	-- the speech panel
	local eye = headPos + away * 10 + screenRight * 2.6 + Vector3.new(0, 1.6, 0)
	local focus = headPos + Vector3.new(0, -1.1, 0) - screenRight * 0.8
	if not savedCamera then
		savedCamera = { CFrame = camera.CFrame, Type = camera.CameraType, Fov = camera.FieldOfView }
	end
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(eye, focus),
		FieldOfView = 52,
	}):Play()
end

local function restoreCamera()
	local saved = savedCamera
	local camera = Workspace.CurrentCamera
	savedCamera = nil
	if not saved or not camera then
		return
	end
	if State.Mode ~= nil then
		camera.FieldOfView = saved.Fov
		return
	end
	local tween = TweenService:Create(camera, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		CFrame = saved.CFrame,
		FieldOfView = saved.Fov,
	})
	tween:Play()
	tween.Completed:Once(function()
		if savedCamera == nil and camera.CameraType == Enum.CameraType.Scriptable and State.Mode == nil then
			camera.CameraType = if saved.Type == Enum.CameraType.Scriptable then Enum.CameraType.Custom else saved.Type
		end
	end)
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function finishTyping()
	typingToken += 1
	speech.MaxVisibleGraphemes = -1
	skipHint.Visible = false
	local done = pendingDone
	pendingDone = nil
	if done then
		done()
	end
end

local function typeLine(text: string, onDone: () -> ())
	typingToken += 1
	local token = typingToken
	pendingDone = onDone
	speech.Text = text
	speech.MaxVisibleGraphemes = 0
	skipHint.Visible = true
	local total = utf8.len(text) or #text
	task.spawn(function()
		local shown = 0
		local started = os.clock()
		while shown < total do
			task.wait(1 / 30)
			if token ~= typingToken then
				return
			end
			shown = math.floor((os.clock() - started) * TYPE_SPEED)
			speech.MaxVisibleGraphemes = math.min(shown, total)
		end
		if token == typingToken then
			finishTyping()
		end
	end)
end

local function clearChoices()
	choiceList = {}
	for _, child in choicesFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function choose(index: number)
	if not current or closing then
		return
	end
	if pendingDone then
		finishTyping()
		return
	end
	local choice = choiceList[index]
	if choice then
		choice.Run()
	end
end

local function showChoices(list: { Choice })
	clearChoices()
	choiceList = list
	for i, choice in list do
		-- the holder sits in the list layout; the button inside it can slide
		local holder = UIKit.new("Frame", {
			Name = "Choice" .. i,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 42),
			LayoutOrder = i,
			Parent = choicesFrame,
		})
		local button = UIKit.Button(holder, choice.Text, C.Wood, function()
			choose(i)
		end, {
			Name = "Button",
			Size = UDim2.fromScale(1, 1),
			TextColor3 = C.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local pad = button:FindFirstChildOfClass("UIPadding")
		if pad then
			pad.PaddingLeft = UDim.new(0, 44)
		end
		local constraint = button:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint then
			constraint.MaxTextSize = 18
		end
		-- number key medallion
		local key = UIKit.new("TextLabel", {
			Name = "Key",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -36, 0.5, 1),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = C.Gold,
			Text = tostring(i),
			FontFace = UIKit.Fonts.Title,
			TextSize = 16,
			TextColor3 = C.WoodDark,
			Parent = button,
		})
		UIKit.Round(key)
		UIKit.Stroke(key, C.Shadow, 1.5)
		if i == 1 and UserInputService.GamepadEnabled then
			GuiService.SelectedObject = button
		end
		-- slide in one after another
		button.Position = UDim2.fromOffset(28, 0)
		TweenService:Create(button, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.05 * (i - 1)), {
			Position = UDim2.fromOffset(0, 0),
		}):Play()
	end
end

-- Say a line, then offer choices once it has been typed out
local function say(text: string, choices: { Choice })
	clearChoices()
	typeLine(text, function()
		showChoices(choices)
	end)
end

---------------------------------------------------------------------------
-- Conversation
---------------------------------------------------------------------------
local rootChoices: () -> { Choice }

local function close(instant: boolean?)
	if not current then
		return
	end
	current = nil
	npcModel = nil
	person = nil
	closing = false
	typingToken += 1
	pendingDone = nil
	clearChoices()
	ProximityPromptService.Enabled = true
	HUD.SetDialogueOpen(false)
	setBackpack(true)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	restoreCamera()
	if instant then
		gui.Enabled = false
		return
	end
	local tween = TweenService:Create(root, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 1, PANEL_H),
	})
	tween:Play()
	tween.Completed:Once(function()
		if not current then
			gui.Enabled = false
		end
	end)
end

-- The shopkeeper says goodbye; the panel closes by itself (or on the next click/key)
local function farewell()
	local p = person
	if not p or closing then
		return
	end
	closing = true
	clearChoices()
	typeLine(pick(p.Farewells, "Bye"), function() end)
	local conversation = conversationId
	task.delay(1.8, function()
		if closing and current and conversationId == conversation then
			close()
		end
	end)
end

local function openShop(shopId: string, tab: string?)
	close(true)
	ShopUI.Open(shopId, tab)
end

local function news()
	local p = person
	if not p then
		return
	end
	local pool = table.clone(p.News)
	local king = Workspace:GetAttribute("KingName")
	if type(king) == "string" and king ~= "" and king ~= player.DisplayName then
		table.insert(pool, "{king} is King of the Pirates these days. Richest pirate on the seas, they say. For now...")
	elseif king == player.DisplayName then
		table.insert(pool, "Look who it is! The King of the Pirates himself, in my humble shop!")
	end
	say(pick(pool, "News"), rootChoices())
end

-- Ask the server; returns nil if the conversation ended while waiting for the answer
local function request(action: string, arg: any?): any
	local conversation = conversationId
	clearChoices()
	local result = ShopUI.Request(action, arg)
	if conversationId ~= conversation or not current or closing then
		return nil, true
	end
	return result, false
end

rootChoices = function(): { Choice }
	local shopId = current
	local p = person
	local list: { Choice } = {}
	if not shopId or not p then
		return list
	end
	local function add(text: string, run: () -> ())
		table.insert(list, { Text = text, Run = run })
	end
	if shopId == "Shipwright" then
		add("Show me your ships", function()
			openShop("Shipwright", "Ships")
		end)
		add("I want to paint my sails", function()
			openShop("Shipwright", "Customize")
		end)
	elseif shopId == "Merchant" then
		add("Show me your maps", function()
			openShop("Merchant", "Maps")
		end)
		local carrying = player:GetAttribute("CarryingTier")
		if type(carrying) == "string" then
			local value = player:GetAttribute("CarryingValue")
			add(("Sell my treasure (%sg)"):format(Util.FormatNumber(if type(value) == "number" then value else 0)), function()
				local result, gone = request("SellTreasure")
				if gone then
					return
				elseif result and result.Ok then
					say("Magnifique! " .. result.Message .. " A pleasure doing business, chéri.", rootChoices())
				else
					say(if result then result.Message else "Hmm? Speak up, chéri.", rootChoices())
				end
			end)
		else
			add("I have goods to sell", function()
				openShop("Merchant", "Sell")
			end)
		end
	elseif shopId == "Armory" then
		add("Show me your weapons", function()
			openShop("Armory")
		end)
	elseif shopId == "Tavern" then
		add(("A grog, please! (%dg)"):format(Config.GrogPrice), function()
			local result, gone = request("BuyGrog")
			if gone then
				return
			elseif result and result.Ok then
				say(pick(GROG_OK, "Grog"), rootChoices())
			else
				say(if result then "No coin, no grog, sweetheart. " .. result.Message else "Eh? Say that again, love.", rootChoices())
			end
		end)
	elseif shopId == "TradingPost" then
		add("I want to trade", function()
			close(true)
			if ShopUI.OpenTrading then
				ShopUI.OpenTrading()
			end
		end)
	end
	add(if lastLine.News then "Anything else new?" else "Any news?", news)
	if shopId == "Tavern" then
		add("What's on the menu?", function()
			openShop("Tavern")
		end)
	elseif p.About and p.AboutQuestion then
		local about = p.About
		add(p.AboutQuestion, function()
			say(pick(about, "About"), rootChoices())
		end)
	end
	add("Goodbye", farewell)
	return list
end

function DialogueUI.IsOpen(): boolean
	return current ~= nil
end

function DialogueUI.Close()
	close()
end

function DialogueUI.Open(shopId: string)
	if type(shopId) ~= "string" then
		return
	end
	local p = PEOPLE[shopId]
	if not p then
		-- unknown shop: fall back to the plain shop window
		ShopUI.Open(shopId)
		return
	end
	if current == shopId and not closing then
		return
	end
	if current then
		close(true)
	end
	ShopUI.CloseWindow()
	current = shopId
	closing = false
	conversationId += 1
	lastLine.News = nil
	npcModel = findNpc(shopId)
	person = p
	nameLabel.Text = displayName(shopId, p.Name)
	roleLabel.Text = p.Role
	iconLabel.Text = p.Icon
	iconMedal.BackgroundColor3 = p.Accent
	gui.Enabled = true
	root.Position = UDim2.new(0.5, 0, 1, PANEL_H)
	TweenService:Create(root, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -18),
	}):Play()
	ProximityPromptService.Enabled = false
	HUD.SetDialogueOpen(true)
	setBackpack(false)
	frameNpc()
	say(pick(p.Greetings, "Greet" .. shopId), rootChoices())
end

local function build()
	gui = UIKit.Screen("Dialogue", 9)
	gui.Enabled = false
	root = UIKit.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(PANEL_W, PANEL_H),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	scale = UIKit.new("UIScale", { Parent = root })
	local function rescale()
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.clamp(math.min(viewport.X * 0.96 / PANEL_W, viewport.Y * 0.42 / (PANEL_H + 30)), 0.45, 1)
		end
	end
	rescale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	local shadow = UIKit.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Parent = root,
	})
	UIKit.Corner(shadow, 18)
	local wood = UIKit.new("Frame", {
		Name = "Wood",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.WoodLight,
		Parent = root,
	})
	UIKit.Corner(wood, 16)
	UIKit.Stroke(wood, C.Shadow, 3)
	UIKit.Planks(wood, 4)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		UIKit.Rivet(wood, UDim2.new(corner.X, if corner.X == 0 then 9 else -9, corner.Y, if corner.Y == 0 then 9 else -9), 8)
	end
	local page = UIKit.Panel(wood, {
		Name = "Page",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
	})
	local pageCorner = page:FindFirstChildOfClass("UICorner")
	if pageCorner then
		pageCorner.CornerRadius = UDim.new(0, 9)
	end

	-- clicking the text skips the typewriter
	local textButton = UIKit.new("TextButton", {
		Name = "SpeechArea",
		BackgroundTransparency = 1,
		Text = "",
		Position = UDim2.fromOffset(26, 40),
		Size = UDim2.new(1, -(CHOICES_W + 64), 1, -56),
		Parent = page,
	})
	textButton.Activated:Connect(function()
		if pendingDone then
			finishTyping()
		elseif closing then
			close()
		end
	end)
	speech = UIKit.new("TextLabel", {
		Name = "Speech",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		FontFace = UIKit.Fonts.Small,
		TextSize = 21,
		LineHeight = 1.2,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.Ink,
		Parent = textButton,
	})
	skipHint = UIKit.new("TextLabel", {
		Name = "SkipHint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 4),
		Size = UDim2.fromOffset(160, 16),
		BackgroundTransparency = 1,
		Text = "click to skip  ▸",
		FontFace = UIKit.Fonts.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.WoodLight,
		TextTransparency = 0.3,
		Visible = false,
		Parent = textButton,
	})

	-- rope divider between the speech and the answers
	UIKit.new("Frame", {
		Name = "Rope",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(CHOICES_W + 30), 0.5, 0),
		Size = UDim2.new(0, 3, 1, -40),
		BackgroundColor3 = C.Rope,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = page,
	})
	choicesFrame = UIKit.new("Frame", {
		Name = "Choices",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0, CHOICES_W, 1, -24),
		BackgroundTransparency = 1,
		Parent = page,
	})
	local list = UIKit.List(choicesFrame, 6, false, Enum.HorizontalAlignment.Right)
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	-- name plate hanging over the top edge
	namePlate = UIKit.new("Frame", {
		Name = "NamePlate",
		Position = UDim2.fromOffset(30, -30),
		Size = UDim2.fromOffset(0, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.WoodDark,
		Parent = root,
	})
	UIKit.Corner(namePlate, 10)
	UIKit.Stroke(namePlate, C.GoldDark, 2)
	UIKit.Gradient(namePlate, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 64), PaddingRight = UDim.new(0, 22), Parent = namePlate })
	iconMedal = UIKit.Icon(namePlate, "⚓", 46, C.Sea, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -58, 0.5, 0),
	})
	local glyph = iconMedal:FindFirstChild("Glyph")
	iconLabel = if glyph and glyph:IsA("TextLabel") then glyph else UIKit.Label(iconMedal, "")
	local stack = UIKit.new("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = namePlate,
	})
	local stackList = UIKit.List(stack, 0, false, Enum.HorizontalAlignment.Left)
	stackList.VerticalAlignment = Enum.VerticalAlignment.Center
	nameLabel = UIKit.new("TextLabel", {
		Name = "NpcName",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		FontFace = UIKit.Fonts.Title,
		TextSize = 25,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = stack,
	})
	UIKit.TextStroke(nameLabel, C.Shadow, 2)
	UIKit.Gradient(nameLabel, Color3.fromRGB(255, 248, 214), Color3.fromRGB(255, 196, 70))
	roleLabel = UIKit.new("TextLabel", {
		Name = "Role",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		FontFace = UIKit.Fonts.Small,
		TextSize = 13,
		TextColor3 = C.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = stack,
	})
	-- little "x" in the corner for touch players
	UIKit.Button(root, "X", C.Crimson, function()
		farewell()
	end, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -12),
		Size = UDim2.fromOffset(34, 34),
	})
end

local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
}

function DialogueUI.Init()
	build()
	Net.Event("OpenShop").OnClientEvent:Connect(DialogueUI.Open)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not current or processed then
			return
		end
		local index = KEYS[input.KeyCode]
		if index then
			choose(index)
		elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			if pendingDone then
				finishTyping()
			elseif closing then
				close()
			end
		elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.ButtonB then
			farewell()
		end
	end)
	-- walk away (or die) and the conversation ends
	player.CharacterRemoving:Connect(function()
		close(true)
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if current then
				local hrp = npcRoot()
				local character = player.Character
				local myRoot = character and character:FindFirstChild("HumanoidRootPart")
				if not myRoot or not myRoot:IsA("BasePart") then
					close(true)
				elseif hrp and (myRoot.Position - hrp.Position).Magnitude > CLOSE_DISTANCE then
					close()
				end
			end
		end
	end)
end

return DialogueUI
