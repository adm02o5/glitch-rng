--!strict
-- Rare roll announcements: chat system message plus a banner for very rare ones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)

local Kit = require(script.Parent.UI.Kit)
local Sfx = require(script.Parent.Sfx)

local P = Kit.P
local new = Kit.new

local Announce = {}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function chat(text: string)
	task.spawn(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral") :: TextChannel?
		if general then
			pcall(general.DisplaySystemMessage, general, text)
		end
	end)
end

local function banner(name: string, a: Config.Aura, tier: Config.Tier, global: boolean)
	local f = Kit.panel(Kit.Top, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -90),
		Size = UDim2.fromOffset(620, 70),
	}, tier.color)
	Kit.label(f, if global then "// GLOBAL BROADCAST" else "// SERVER BROADCAST", 11, {
		TextColor3 = P.Dim,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 12),
	})
	local l = Kit.label(f, "", 20, {
		RichText = true,
		FontFace = Kit.MonoBold,
		Position = UDim2.fromOffset(16, 26),
		Size = UDim2.new(1, -32, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	l.Text = string.format(
		'%s just rolled <font color="%s"><b>%s</b></font>  <font color="#788CA0">%s</font>',
		name,
		hex(tier.color),
		a.name,
		RNG.ChanceText(a.chance)
	)
	Kit.tween(f, 0.5, { Position = UDim2.new(0.5, 0, 0, 96) }, Enum.EasingStyle.Back)
	Kit.glitch(l, 0.6)
	task.delay(6, function()
		Kit.tween(f, 0.4, { Position = UDim2.new(0.5, 0, 0, -90) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.45)
		f:Destroy()
	end)
	new("UIScale", { Parent = f })
end

function Announce.Show(d: { [string]: any })
	local a = Config.AuraById[d.aura]
	if not a then
		return
	end
	local tier = Config.TierOf(a.chance)
	local prefix = if d.global then "[GLOBAL] " else ""
	chat(string.format(
		'<font color="%s">%s%s rolled %s (%s)</font>',
		hex(tier.color),
		prefix,
		tostring(d.name),
		a.name,
		RNG.ChanceText(a.chance)
	))
	if a.chance >= 100000 then
		Sfx.Play("Announce", { volume = 0.6 })
		banner(tostring(d.name), a, tier, d.global == true)
	end
end

return Announce
