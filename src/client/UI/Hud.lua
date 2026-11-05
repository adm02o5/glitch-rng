--!strict
-- Always-on HUD: roll controls, boot-roll meter, left menu, biome banner, stats, toasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)

local Kit = require(script.Parent.Kit)
local Ctx = require(script.Parent.Parent.Ctx)
local Sfx = require(script.Parent.Parent.Sfx)

local P = Kit.P
local new = Kit.new

local Hud = {}

Hud.RollButton = nil :: TextButton?
Hud.AutoButton = nil :: TextButton?
Hud.OnRoll = Instance.new("BindableEvent") -- fired when the player asks for a roll
Hud.OnAuto = Instance.new("BindableEvent") -- fired with the new auto state
Hud.Auto = false
Hud.Root = nil :: Frame?

local cooldownFill: Frame
local bootPips: { Frame } = {}
local bootLabel: TextLabel
local statsLabels: { [string]: TextLabel } = {}
local boostList: Frame
local rollCount: TextLabel
local biomeName: TextLabel
local biomeDesc: TextLabel
local biomeTimer: TextLabel
local biomeBar: Frame
local biomePanel: Frame
local toastHolder: Frame
local cdStart, cdLen = 0, 0

function Hud.Cooldown(seconds: number)
	cdStart, cdLen = os.clock(), seconds
end

function Hud.Toast(text: string, color: Color3?)
	local c = color or P.Cyan
	local f = Kit.panel(toastHolder, {
		Size = UDim2.fromOffset(380, 40),
		BackgroundTransparency = 0.15,
		LayoutOrder = -math.floor(os.clock() * 100),
	}, c)
	local l = Kit.label(f, text, 15, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = c:Lerp(Color3.new(1, 1, 1), 0.4),
		RichText = true,
		TextWrapped = true,
	})
	local sc = new("UIScale", { Scale = 0.6, Parent = f })
	Kit.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.glitch(l, 0.3)
	task.delay(3.2, function()
		Kit.tween(sc, 0.2, { Scale = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Kit.tween(f, 0.2, { BackgroundTransparency = 1 })
		Kit.tween(l, 0.2, { TextTransparency = 1 })
		task.wait(0.22)
		f:Destroy()
	end)
end

local function menuButton(parent: Instance, order: number, glyph: string, text: string, color: Color3, win: string)
	local b = Kit.button({
		text = text,
		icon = glyph,
		size = UDim2.fromOffset(150, 46),
		color = color,
		textSize = 15,
		parent = parent,
	}, function()
		Ctx.Toggle(win)
	end)
	b.LayoutOrder = order
	local lbl = b:FindFirstChild("Label") :: TextLabel
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), Parent = lbl })
	return b
end

local function buildRoll(root: Frame)
	local holder = new("Frame", {
		Name = "RollArea",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(480, 140),
		Parent = root,
	})

	-- Boot roll meter: 10 pips.
	local meter = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(300, 30),
		Parent = holder,
	})
	bootLabel = Kit.label(meter, "BOOT ROLL IN 10", 12, {
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = P.Dim,
		FontFace = Kit.MonoBold,
	})
	for i = 1, Config.Roll.BonusEvery do
		local pip = new("Frame", {
			BackgroundColor3 = P.Line,
			BorderSizePixel = 0,
			Size = UDim2.new(1 / Config.Roll.BonusEvery, -4, 0, 6),
			Position = UDim2.new((i - 1) / Config.Roll.BonusEvery, 2, 0, 20),
			Parent = meter,
		})
		Kit.corner(pip, 2)
		bootPips[i] = pip
	end

	-- Main roll button.
	local roll = Kit.button({
		text = "ROLL",
		size = UDim2.fromOffset(240, 72),
		position = UDim2.new(0.5, 0, 1, 0),
		anchor = Vector2.new(0.5, 1),
		color = P.Cyan,
		textSize = 30,
		font = Kit.Title,
		sound = "RollStart",
		parent = holder,
	}, function()
		Hud.OnRoll:Fire()
	end)
	Hud.RollButton = roll
	Kit.brackets(roll, P.Cyan, 16)
	cooldownFill = new("Frame", {
		Name = "Cooldown",
		BackgroundColor3 = P.Cyan,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = roll.ZIndex,
		Parent = roll,
	})
	Kit.corner(cooldownFill, 3)
	Kit.label(roll, "[ R ]", 10, {
		TextColor3 = P.Dim,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 12),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = roll.ZIndex + 1,
	})

	-- Auto roll toggle.
	local auto: TextButton
	auto = Kit.button({
		text = "AUTO: OFF",
		size = UDim2.fromOffset(110, 50),
		position = UDim2.new(0.5, 132, 1, -11),
		anchor = Vector2.new(0, 1),
		color = P.Magenta,
		textSize = 14,
		parent = holder,
	}, function()
		Hud.Auto = not Hud.Auto
		Kit.setButtonText(auto, if Hud.Auto then "AUTO: ON" else "AUTO: OFF")
		local st = auto:FindFirstChildOfClass("UIStroke")
		if st then
			st.Thickness = if Hud.Auto then 3 else 1.5
		end
		Hud.OnAuto:Fire(Hud.Auto)
	end)
	Hud.AutoButton = auto

	-- Quick roll toggle (skips the reel animation for low tiers).
	local quick: TextButton
	quick = Kit.button({
		text = "QUICK: OFF",
		size = UDim2.fromOffset(110, 50),
		position = UDim2.new(0.5, -132, 1, -11),
		anchor = Vector2.new(1, 1),
		color = P.Amber,
		textSize = 14,
		parent = holder,
	}, function()
		local v = not (Ctx.Data.Settings and Ctx.Data.Settings.Quick)
		Ctx.Setting("Quick", v)
	end)
	Ctx.Changed.Event:Connect(function(d)
		local on = d.Settings and d.Settings.Quick
		Kit.setButtonText(quick, if on then "QUICK: ON" else "QUICK: OFF")
	end)
end

local function buildMenu(root: Frame)
	local list = new("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		Size = UDim2.fromOffset(150, 260),
		Parent = root,
	})
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	menuButton(list, 1, "◈", "AURAS", P.Cyan, "Inventory")
	menuButton(list, 2, "▤", "INDEX", P.Magenta, "Index")
	menuButton(list, 3, "▶", "SCRIPTS", P.Lime, "Scripts")
	menuButton(list, 4, "⚙", "SETTINGS", P.Dim, "Settings")
	if Config.Admins[game:GetService("Players").LocalPlayer.UserId] then
		menuButton(list, 5, "#", "ADMIN", P.Red, "Admin")
		list.Size = UDim2.fromOffset(150, 330)
	end
end

local function buildBiome(root: Frame)
	biomePanel = Kit.panel(root, {
		Name = "Biome",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(360, 74),
	})
	biomeName = Kit.label(biomePanel, "NORMAL", 22, {
		FontFace = Kit.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 26),
	})
	biomeDesc = Kit.label(biomePanel, "", 12, {
		TextColor3 = P.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 14),
	})
	biomeTimer = Kit.label(biomePanel, "", 12, {
		FontFace = Kit.MonoBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 14),
	})
	biomeBar = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = P.Cyan,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		Parent = biomePanel,
	})
end

local function buildStats(root: Frame)
	local panel = Kit.panel(root, {
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -24),
		Size = UDim2.fromOffset(250, 96),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	-- Content lives in its own frame so the list layout doesn't move the corner brackets.
	local body = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = panel,
	})
	panel.Size = UDim2.fromOffset(250, 0)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		Parent = body,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	Kit.label(body, "// SYSTEM STATUS", 11, { TextColor3 = P.Dim, LayoutOrder = 0 })
	for i, key in { "Luck", "Speed" } do
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, Parent = body })
		Kit.label(row, if key == "Luck" then "LUCK" else "ROLL SPEED", 15, {
			FontFace = Kit.MonoBold,
			TextColor3 = if key == "Luck" then P.Lime else P.Amber,
			Size = UDim2.fromScale(0.6, 1),
		})
		statsLabels[key] = Kit.label(row, "x1.00", 17, {
			FontFace = Kit.MonoBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromScale(1, 1),
		})
	end
	boostList = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Parent = body,
	})
	new("UIListLayout", { Padding = UDim.new(0, 2), Parent = boostList })
end

local function refreshBoosts(d: { [string]: any })
	for _, c in boostList:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	for id, left in (d.Active or {}) :: { [string]: number } do
		local s = Config.ScriptById[id]
		if s then
			local l = Kit.label(boostList, "", 13, { TextColor3 = s.color, Name = "Boost_" .. id })
			l:SetAttribute("Ends", os.clock() + left)
			l:SetAttribute("Title", "> " .. s.name)
		end
	end
	for id, n in (d.NextRolls or {}) :: { [string]: number } do
		local s = Config.ScriptById[id]
		if s and n > 0 then
			Kit.label(boostList, string.format("> %s armed  x%d", s.name, n), 13, { TextColor3 = s.color })
		end
	end
end

function Hud.Start()
	local root = new("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = Kit.Gui,
	})
	Hud.Root = root
	buildRoll(root)
	buildMenu(root)
	buildBiome(root)
	buildStats(root)

	rollCount = Kit.label(root, "0 ROLLS", 14, {
		FontFace = Kit.MonoBold,
		TextColor3 = P.Dim,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 70),
		Size = UDim2.fromOffset(240, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	toastHolder = new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(380, 300),
		Parent = Kit.Top,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toastHolder,
	})
	Ctx.Toast = Hud.Toast

	local bitsL = Kit.label(root, "◆ 0 BITS", 16, {
		FontFace = Kit.MonoBold,
		TextColor3 = P.Lime,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 46),
		Size = UDim2.fromOffset(240, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local lastBits = -1
	Ctx.Changed.Event:Connect(function(d)
		local b = d.Bits or 0
		bitsL.Text = "◆ " .. RNG.Commas(b) .. " BITS"
		if lastBits >= 0 and b > lastBits then
			Kit.glitch(bitsL, 0.2)
		end
		lastBits = b
	end)

	Ctx.Changed.Event:Connect(function(d)
		statsLabels.Luck.Text = string.format("x%.2f", d.Luck or 1)
		statsLabels.Speed.Text = string.format("x%.2f", d.Speed or 1)
		rollCount.Text = RNG.Commas(d.Rolls or 0) .. " ROLLS"
		local nextBoot = d.NextBoot or Config.Roll.BonusEvery
		local filled = Config.Roll.BonusEvery - nextBoot
		for i, pip in bootPips do
			local on = i <= filled
			pip.BackgroundColor3 = if on then P.Magenta else P.Line
		end
		if nextBoot == 1 then
			bootLabel.Text = "NEXT ROLL: BOOT ROLL  x" .. Config.Roll.BonusLuck .. " LUCK"
			bootLabel.TextColor3 = P.Magenta
		else
			bootLabel.Text = "BOOT ROLL IN " .. nextBoot
			bootLabel.TextColor3 = P.Dim
		end
		refreshBoosts(d)
	end)

	-- Biome banner updates.
	local lastBiome = ""
	local function biomeChanged()
		local id = ReplicatedStorage:GetAttribute("Biome") or "Normal"
		local b = Config.BiomeById[id] or Config.BiomeById.Normal
		biomeName.Text = b.name
		biomeName.TextColor3 = b.color
		biomeDesc.Text = b.desc
		biomeBar.BackgroundColor3 = b.color
		for _, br in biomePanel:GetChildren() do
			if br.Name == "Bracket" then
				(br :: Frame).BackgroundColor3 = b.color
			end
		end
		if lastBiome ~= "" and id ~= lastBiome then
			Kit.glitch(biomeName, 0.8)
			if id ~= "Normal" then
				Sfx.Play("BiomeStart_" .. id, { volume = 0.8 })
				local extra = {}
				if b.luck ~= 1 then
					table.insert(extra, string.format("x%.2g luck", b.luck))
				end
				if b.speed ~= 1 then
					table.insert(extra, string.format("x%.2g speed", b.speed))
				end
				Hud.Toast(
					string.format("<b>%s</b> has begun  %s", b.name, table.concat(extra, " · ")),
					b.color
				)
			end
		end
		lastBiome = id
	end
	ReplicatedStorage:GetAttributeChangedSignal("Biome"):Connect(biomeChanged)
	biomeChanged()

	-- Per-frame: cooldown bar, biome timer, boost countdowns.
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		if cdLen > 0 then
			local k = math.clamp((os.clock() - cdStart) / cdLen, 0, 1)
			cooldownFill.Size = UDim2.fromScale(1 - k, 1)
		end
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local now = workspace:GetServerTimeNow()
		local ends = ReplicatedStorage:GetAttribute("BiomeEnds") or 0
		local id = ReplicatedStorage:GetAttribute("Biome") or "Normal"
		if id ~= "Normal" and ends > 0 then
			local b = Config.BiomeById[id]
			local left = ends - now
			biomeTimer.Text = "ENDS IN " .. RNG.Time(left)
			biomeTimer.TextColor3 = b.color
			biomeBar.Size = UDim2.new(math.clamp(left / b.duration, 0, 1), 0, 0, 2)
		else
			local nx = ReplicatedStorage:GetAttribute("BiomeNext") or 0
			biomeTimer.Text = "NEXT SCAN IN " .. RNG.Time(nx - now)
			biomeTimer.TextColor3 = P.Dim
			biomeBar.Size = UDim2.new(math.clamp(1 - (nx - now) / Config.BiomeCheckEvery, 0, 1), 0, 0, 2)
		end
		for _, l in boostList:GetChildren() do
			if l:IsA("TextLabel") and l:GetAttribute("Ends") then
				local left = (l:GetAttribute("Ends") :: number) - os.clock()
				l.Text = string.format("%s  %s", l:GetAttribute("Title") :: string, RNG.Time(left))
			end
		end
	end)
end

return Hud
