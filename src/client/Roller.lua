--!strict
-- Roll flow on the client: ask the server, spin the name reel, play the tier cutscene, reveal the result card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)

local Kit = require(script.Parent.UI.Kit)
local Hud = require(script.Parent.UI.Hud)
local Ctx = require(script.Parent.Ctx)
local Sfx = require(script.Parent.Sfx)
local Cutscene = require(script.Parent.Cutscene)

local P = Kit.P
local new = Kit.new
local player = Players.LocalPlayer

local Roller = {}

local card: Frame
local nameL: TextLabel
local nameGrad: UIGradient
local nameStroke: UIStroke
local tierL: TextLabel
local chanceL: TextLabel
local tagL: TextLabel
local cardScale: UIScale
local rolling = false

local function buildCard()
	card = new("Frame", {
		Name = "RollCard",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(900, 190),
		Visible = false,
		Parent = Kit.Top,
	})
	cardScale = new("UIScale", { Parent = card })
	tierL = Kit.label(card, "", 18, {
		FontFace = Kit.MonoBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 22),
	})
	new("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.3, Parent = tierL })
	nameL = Kit.label(card, "", 64, {
		FontFace = Kit.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 80),
		ZIndex = 3,
	})
	nameGrad = new("UIGradient", { Rotation = 90, Parent = nameL })
	nameStroke = new("UIStroke", { Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 0.15, Parent = nameL })
	chanceL = Kit.label(card, "", 22, {
		FontFace = Kit.MonoBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 122),
		Size = UDim2.new(1, 0, 0, 26),
	})
	new("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.3, Parent = chanceL })
	tagL = Kit.label(card, "", 15, {
		FontFace = Kit.MonoBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 154),
		Size = UDim2.new(1, 0, 0, 20),
		RichText = true,
	})
	new("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.3, Parent = tagL })
end

local function show(a: Config.Aura, final: boolean)
	local tier = Config.TierOf(a.chance)
	nameL.Text = a.name
	nameGrad.Color = ColorSequence.new(a.color:Lerp(Color3.new(1, 1, 1), 0.25), a.color2:Lerp(a.color, 0.4))
	tierL.Text = if final then "[ " .. tier.name .. " ]" else ""
	tierL.TextColor3 = tier.color
	chanceL.Text = RNG.ChanceText(a.chance)
	chanceL.TextColor3 = if final then tier.color:Lerp(Color3.new(1, 1, 1), 0.35) else P.Dim
	nameStroke.Color = if final and a.color.R + a.color.G + a.color.B < 0.3 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
end

-- Weighted toward common auras so the reel feels honest, with rares flashing by now and then.
local function reelPick(pool: { Config.Aura }, rng: Random): Config.Aura
	local total = 0
	for _, a in pool do
		total += a.chance ^ -0.55
	end
	local r = rng:NextNumber() * total
	for _, a in pool do
		r -= a.chance ^ -0.55
		if r <= 0 then
			return a
		end
	end
	return pool[1]
end

local function spin(final: Config.Aura, duration: number)
	local pool = RNG.Pool(ReplicatedStorage:GetAttribute("Biome") or "Normal")
	local rng = Random.new()
	card.Visible = true
	tagL.Text = ""
	nameL.TextTransparency = 0
	chanceL.TextTransparency = 0
	tierL.TextTransparency = 0
	tagL.TextTransparency = 0
	local t = 0
	local step = 0.035
	local i = 0
	while t < duration do
		i += 1
		local a = reelPick(pool, rng)
		show(a, false)
		cardScale.Scale = 1.06
		Kit.tween(cardScale, step * 0.9, { Scale = 1 })
		Sfx.Play("Tick", { volume = 0.35, pitch = 0.9 + math.min(t / duration, 1) * 0.5 })
		task.wait(step)
		t += step
		-- Ease out: ticks get slower towards the end.
		local k = t / duration
		step = 0.035 + (k ^ 2.2) * 0.22
	end
	show(final, true)
end

local function reveal(a: Config.Aura, res: { [string]: any })
	local tier = Config.TierOf(a.chance)
	show(a, true)
	card.Visible = true
	local tags = {}
	if res.first then
		table.insert(tags, '<font color="#50FF8C">NEW AURA</font>')
	end
	if res.boot then
		table.insert(tags, '<font color="#FF2BD6">BOOT ROLL</font>')
	end
	if res.breach then
		table.insert(tags, '<font color="#FF1F3D">BREACH</font>')
	end
	tagL.Text = table.concat(tags, "   ")
	cardScale.Scale = 1.35
	Kit.tween(cardScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.glitch(nameL, 0.25 + tier.cutscene * 0.12)
	Sfx.Play("Reveal" .. math.clamp(tier.cutscene, 1, 5), { volume = 0.7 })
	Sfx.Play("Land", { volume = 0.5 })
	task.wait(1.1 + tier.cutscene * 0.4)
	for _, l in { nameL, chanceL, tierL, tagL } do
		Kit.tween(l, 0.35, { TextTransparency = 1 })
	end
	task.wait(0.36)
	card.Visible = false
end

function Roller.Roll(): boolean
	if rolling or Ctx.Busy or not player:GetAttribute("Loaded") then
		return false
	end
	rolling = true
	Ctx.Busy = true
	local res = Ctx.Request("Roll")
	if not (res and res.ok) then
		rolling = false
		Ctx.Busy = false
		return false
	end
	local a = Config.AuraById[res.aura]
	local tier = Config.TierOf(a.chance)
	local settings = Ctx.Data.Settings or {}
	Hud.Cooldown(res.cd)
	local t0 = os.clock()

	local quick = settings.Quick and tier.cutscene == 0
	spin(a, if quick then 0.25 else math.max(res.cd * 0.75, 1.1))

	local skipBelow = tonumber(settings.Skip) or 0
	if tier.cutscene > 0 and tier.cutscene > skipBelow then
		card.Visible = false
		Cutscene.Play(a, { first = res.first, boot = res.boot, breach = res.breach })
	end
	reveal(a, res)

	-- Respect the server cooldown before the next roll.
	local left = res.cd - (os.clock() - t0)
	if left > 0 then
		task.wait(left)
	end
	rolling = false
	Ctx.Busy = false
	return true
end

function Roller.Start()
	buildCard()
	Hud.OnRoll.Event:Connect(function()
		task.spawn(Roller.Roll)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonX then
			task.spawn(Roller.Roll)
		end
	end)
	task.spawn(function()
		while true do
			if Hud.Auto then
				if not Roller.Roll() then
					task.wait(0.25)
				end
			else
				task.wait(0.1)
			end
		end
	end)
end

return Roller
