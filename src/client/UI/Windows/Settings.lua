--!strict
-- SETTINGS: volumes, other players' auras, cutscene skipping, reduced flashing, tutorial replay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Kit = require(script.Parent.Parent.Kit)
local W = require(script.Parent.Parent.Widgets)
local Ctx = require(script.Parent.Parent.Parent.Ctx)
local Tutorial = require(script.Parent.Parent.Parent.Tutorial)

local P = Kit.P
local new = Kit.new

-- Cutscene levels a player can choose to skip (tier.cutscene <= value is skipped).
local SKIP_NAMES = { [0] = "NONE", [1] = "RARE", [2] = "EPIC", [3] = "LEGENDARY", [4] = "CORRUPTED" }

return function()
	local win = Kit.window("SETTINGS", "// local configuration", Vector2.new(560, 580), P.Dim)
	local list = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = win.body })
	new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local function row(order: number, title: string, hint: string): Frame
		local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = order, Parent = list })
		Kit.label(r, title, 16, { FontFace = Kit.MonoBold, Size = UDim2.new(0.5, 0, 0, 20) })
		Kit.label(r, hint, 12, { TextColor3 = P.Dim, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(0.5, 0, 0, 14) })
		return r
	end

	local function render()
		W.clear(list)
		new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		local s = Ctx.Data.Settings or {}

		local r1 = row(1, "SOUND EFFECTS", "rolls, interface, cutscenes")
		local h1 = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0.5, 0, 0, 20), Parent = r1 })
		W.slider(h1, math.clamp(tonumber(s.Sfx) or 1, 0, 1), P.Cyan, function(v)
			Ctx.Setting("Sfx", v)
		end)

		local r2 = row(2, "MUSIC", "biome soundtrack")
		local h2 = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0.5, 0, 0, 20), Parent = r2 })
		W.slider(h2, math.clamp(tonumber(s.Music) or 0.6, 0, 1), P.Magenta, function(v)
			Ctx.Setting("Music", v)
		end)

		local r3 = row(3, "OTHER PLAYERS' AURAS", "turn off for more FPS")
		Kit.button({
			text = if s.Others == false then "HIDDEN" else "VISIBLE",
			size = UDim2.new(0.5, 0, 0, 42),
			position = UDim2.new(0.5, 0, 0, 4),
			color = if s.Others == false then P.Red else P.Lime,
			textSize = 15,
			parent = r3,
		}, function()
			Ctx.Setting("Others", s.Others == false)
			render()
		end)

		local r4 = row(4, "SKIP CUTSCENES UP TO", "rarer auras always play")
		local skip = math.clamp(tonumber(s.Skip) or 0, 0, 4)
		Kit.button({
			text = "◀  " .. SKIP_NAMES[skip] .. "  ▶",
			size = UDim2.new(0.5, 0, 0, 42),
			position = UDim2.new(0.5, 0, 0, 4),
			color = if skip == 0 then P.Dim else Config.Tiers[({ 3, 4, 5, 7 })[skip]].color,
			textSize = 15,
			parent = r4,
		}, function()
			Ctx.Setting("Skip", (skip + 1) % 5)
			render()
		end)

		local r5 = row(5, "REDUCE FLASHING", "photosensitivity: softer flashes and strobes")
		local calm = s.Calm == true
		Kit.button({
			text = if calm then "ON" else "OFF",
			icon = if calm then "◉" else "○",
			size = UDim2.new(0.5, 0, 0, 42),
			position = UDim2.new(0.5, 0, 0, 4),
			color = if calm then P.Lime else P.Dim,
			textSize = 15,
			parent = r5,
		}, function()
			Ctx.Setting("Calm", not calm)
			render()
		end)

		local r6 = row(6, "TUTORIAL", "the guided tour of the city")
		local replay = Kit.button({
			text = if Tutorial.Running then "RUNNING..." else "REPLAY TUTORIAL",
			icon = "▶",
			size = UDim2.new(0.5, 0, 0, 42),
			position = UDim2.new(0.5, 0, 0, 4),
			color = P.Cyan,
			textSize = 15,
			parent = r6,
		}, function()
			if Tutorial.Running then
				return
			end
			win:Close()
			task.delay(0.25, Tutorial.Start)
		end)
		replay.Name = "ReplayTutorial"
	end

	win.onOpen = render
	return win
end
