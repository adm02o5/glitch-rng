--!strict
-- NULL (NPC): typed dialogue line, current quest with progress + claim, and the black-market stall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)

local Kit = require(script.Parent.Parent.Kit)
local W = require(script.Parent.Parent.Widgets)
local Ctx = require(script.Parent.Parent.Parent.Ctx)
local Sfx = require(script.Parent.Parent.Parent.Sfx)

local P = Kit.P
local new = Kit.new

local LINES = {
	"Connection established.",
	"The odds are just code. And code can be rewritten.",
	"Everyone rolls. Few understand the pattern.",
	"I don't sell luck. I sell exploits.",
	"Control is an illusion. Luck can be engineered.",
	"Don't trust the RNG. Trust the process.",
	"They watch the leaderboard. I watch the logs.",
}

return function()
	local win = Kit.window("NULL", "// encrypted contact · quests & black market", Vector2.new(860, 540), P.Lime)
	local tab = "Quest"
	local lineIdx = 0

	-- Portrait block: stylised terminal avatar.
	local portrait = Kit.panel(win.body, {
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = P.Bg,
	}, P.Lime)
	local face = Kit.label(portrait, "[ o_o ]", 26, {
		FontFace = Kit.Pixel,
		TextColor3 = P.Lime,
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Kit.label(portrait, "NULL", 14, {
		FontFace = Kit.Title,
		TextColor3 = P.Text,
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Kit.label(portrait, "status: online", 11, {
		TextColor3 = P.Dim,
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- Dialogue bubble.
	local bubble = Kit.panel(win.body, {
		Position = UDim2.fromOffset(166, 0),
		Size = UDim2.new(1, -166, 0, 70),
		BackgroundColor3 = P.Bg,
	}, P.Lime)
	local say = Kit.label(bubble, "", 17, {
		FontFace = Kit.MonoBold,
		TextColor3 = P.Lime,
		TextWrapped = true,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 1, -20),
		TextYAlignment = Enum.TextYAlignment.Center,
	})

	local bitsL = Kit.label(win.body, "", 16, {
		FontFace = Kit.MonoBold,
		TextColor3 = P.Lime,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 84),
		Size = UDim2.fromOffset(260, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local tabsHolder = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(166, 80),
		Size = UDim2.new(1, -440, 0, 34),
		Parent = win.body,
	})
	local content = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(166, 124),
		Size = UDim2.new(1, -166, 1, -124),
		Parent = win.body,
	})

	local render: () -> ()

	local function questView()
		local d = Ctx.Data
		local qs = d.Quest or { i = 1, n = 0 }
		local q = Config.QuestAt(qs.i)
		local done = qs.n >= q.goal.n
		local card = Kit.panel(content, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.Bg }, P.Lime)
		local num = if qs.i <= #Config.Quests then string.format("QUEST %d / %d", qs.i, #Config.Quests) else "REPEATABLE CONTRACT"
		Kit.label(card, num, 12, {
			FontFace = Kit.MonoBold,
			TextColor3 = P.Dim,
			Position = UDim2.fromOffset(18, 14),
			Size = UDim2.new(1, -36, 0, 14),
		})
		Kit.label(card, q.title, 24, {
			FontFace = Kit.Title,
			TextColor3 = P.Lime,
			Position = UDim2.fromOffset(18, 32),
			Size = UDim2.new(1, -36, 0, 28),
		})
		Kit.label(card, q.text, 15, {
			TextColor3 = P.Text,
			TextWrapped = true,
			Position = UDim2.fromOffset(18, 66),
			Size = UDim2.new(1, -36, 0, 40),
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		-- Progress bar.
		local barBg = new("Frame", {
			BackgroundColor3 = P.Panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(18, 118),
			Size = UDim2.new(1, -36, 0, 16),
			Parent = card,
		})
		Kit.corner(barBg, 4)
		Kit.stroke(barBg, P.Line, 1)
		local k = math.clamp(qs.n / q.goal.n, 0, 1)
		local fill = new("Frame", {
			BackgroundColor3 = if done then P.Lime else P.Cyan,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(k, 1),
			Parent = barBg,
		})
		Kit.corner(fill, 4)
		Kit.label(barBg, string.format("%s / %s", RNG.Commas(qs.n), RNG.Commas(q.goal.n)), 12, {
			FontFace = Kit.MonoBold,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		-- Reward.
		local reward = { string.format("◆ %s BITS", RNG.Commas(q.bits)) }
		for id, n in (q.scripts or {}) :: { [string]: number } do
			table.insert(reward, string.format("%s x%d", Config.ScriptById[id].name, n))
		end
		Kit.label(card, "REWARD:  " .. table.concat(reward, "   +   "), 14, {
			FontFace = Kit.MonoBold,
			TextColor3 = P.Amber,
			Position = UDim2.fromOffset(18, 148),
			Size = UDim2.new(1, -36, 0, 18),
		})
		Kit.button({
			text = if done then "CLAIM REWARD" else "IN PROGRESS",
			size = UDim2.new(1, -36, 0, 54),
			position = UDim2.new(0, 18, 1, -70),
			color = if done then P.Lime else P.Line,
			textSize = 20,
			font = Kit.Title,
			parent = card,
		}, function()
			if not done then
				Sfx.Play("Error")
				return
			end
			local r = Ctx.Request("QuestClaim")
			if r then
				Sfx.Play("QuestDone", { volume = 0.8 })
				Ctx.Toast(string.format("Quest complete  <b>+%s BITS</b>", RNG.Commas(r.bits)), P.Lime)
				say.Text = "Good. There's more where that came from."
			end
		end)
	end

	local function shopView()
		local d = Ctx.Data
		local list = Kit.scroll(content)
		new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), Parent = list })
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
		for i, item in Config.Shop do
			local s = Config.ScriptById[item.id]
			local afford = (d.Bits or 0) >= item.price
			local row = Kit.panel(list, { Size = UDim2.new(1, 0, 0, 84), LayoutOrder = i, BackgroundColor3 = P.Bg }, s.color)
			Kit.label(row, "> " .. s.name, 20, {
				FontFace = Kit.MonoBold,
				TextColor3 = s.color,
				Position = UDim2.fromOffset(16, 12),
				Size = UDim2.new(1, -220, 0, 24),
			})
			Kit.label(row, s.desc .. "   ·   owned x" .. tostring(d.Scripts and d.Scripts[s.id] or 0), 13, {
				TextColor3 = P.Dim,
				Position = UDim2.fromOffset(16, 44),
				Size = UDim2.new(1, -220, 0, 16),
			})
			Kit.button({
				text = "◆ " .. RNG.Commas(item.price),
				size = UDim2.fromOffset(170, 50),
				position = UDim2.new(1, -16, 0.5, 0),
				anchor = Vector2.new(1, 0.5),
				color = if afford then P.Lime else P.Red,
				textSize = 18,
				font = Kit.Title,
				parent = row,
			}, function()
				if afford and Ctx.Request("ShopBuy", item.id) then
					Sfx.Play("Buy", { volume = 0.7 })
					Ctx.Toast("Bought <b>" .. s.name .. "</b>", s.color)
					say.Text = "Pleasure doing business."
				else
					Sfx.Play("Error")
					say.Text = "Not enough BITS, friend. Keep rolling."
				end
			end)
		end
	end

	render = function()
		W.clear(content)
		bitsL.Text = "◆ " .. RNG.Commas(Ctx.Data.Bits or 0) .. " BITS"
		if tab == "Quest" then
			questView()
		else
			shopView()
		end
	end

	local select = W.tabs(tabsHolder, { "Quest", "Market" }, function(name)
		tab = name
		render()
	end)

	win.onOpen = function()
		lineIdx = lineIdx % #LINES + 1
		task.spawn(Kit.type, say, LINES[lineIdx], 45, function()
			Sfx.Play("NpcTalk", { volume = 0.3, pitch = 0.9 + math.random() * 0.25 })
		end)
		face.Text = ({ "[ o_o ]", "[ -_- ]", "[ o_O ]" })[math.random(1, 3)]
		select(tab)
	end
	Ctx.Changed.Event:Connect(function()
		if win.open then
			render()
		end
	end)
	return win
end
