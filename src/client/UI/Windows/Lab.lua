--!strict
-- SCRIPT LAB (terminal): compile consumable boost scripts from auras.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Kit = require(script.Parent.Parent.Kit)
local W = require(script.Parent.Parent.Widgets)
local Ctx = require(script.Parent.Parent.Parent.Ctx)
local Sfx = require(script.Parent.Parent.Parent.Sfx)

local P = Kit.P
local new = Kit.new

return function()
	local win = Kit.window("SCRIPT LAB", "// compile boost scripts · run them from the SCRIPTS menu", Vector2.new(860, 520), P.Lime)
	local selected = Config.Scripts[1].id

	local list = Kit.scroll(win.body, { Size = UDim2.new(0, 300, 1, 0) })
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), Parent = list })
	local detail = Kit.panel(win.body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -316, 1, 0),
		BackgroundColor3 = P.Bg,
	}, P.Lime)

	local renderList: () -> ()

	local function craft(id: string, n: number)
		local made = Ctx.Request("CraftScript", { id = id, n = n })
		if made then
			Sfx.Play("Craft")
			Ctx.Toast(string.format("Compiled <b>%s</b> x%d", Config.ScriptById[id].name, made), Config.ScriptById[id].color)
		else
			Sfx.Play("Error")
		end
	end

	local function renderDetail()
		W.clear(detail)
		local s = Config.ScriptById[selected]
		local d = Ctx.Data
		Kit.label(detail, s.name, 28, {
			FontFace = Kit.MonoBold,
			TextColor3 = s.color,
			Position = UDim2.fromOffset(18, 16),
			Size = UDim2.new(1, -36, 0, 32),
		})
		Kit.label(detail, s.desc, 14, {
			TextColor3 = P.Text,
			Position = UDim2.fromOffset(18, 54),
			Size = UDim2.new(1, -36, 0, 18),
		})
		Kit.label(detail, "OWNED  x" .. tostring(d.Scripts and d.Scripts[s.id] or 0), 13, {
			FontFace = Kit.MonoBold,
			TextColor3 = P.Dim,
			Position = UDim2.fromOffset(18, 80),
			Size = UDim2.new(1, -36, 0, 16),
		})
		Kit.label(detail, "// SOURCE AURAS", 12, {
			TextColor3 = P.Dim,
			Position = UDim2.fromOffset(18, 110),
			Size = UDim2.new(1, -36, 0, 14),
		})
		local rows = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(18, 130),
			Size = UDim2.new(1, -36, 1, -210),
			Parent = detail,
		})
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rows })
		local can = W.recipe(rows, s.recipe, d.Inv or {})
		Kit.button({
			text = if can then "COMPILE x1" else "MISSING AURAS",
			size = UDim2.new(0.5, -24, 0, 52),
			position = UDim2.new(0, 18, 1, -68),
			color = if can then s.color else P.Red,
			textSize = 17,
			font = Kit.Title,
			parent = detail,
		}, function()
			craft(s.id, 1)
		end)
		Kit.button({
			text = "COMPILE x5",
			size = UDim2.new(0.5, -24, 0, 52),
			position = UDim2.new(0.5, 6, 1, -68),
			color = if can then s.color else P.Line,
			textSize = 17,
			font = Kit.Title,
			parent = detail,
		}, function()
			craft(s.id, 5)
		end)
	end

	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	renderList = function()
		W.clear(list)
		for i, s in Config.Scripts do
			local b = Kit.button({
				text = "",
				size = UDim2.new(1, 0, 0, 70),
				color = s.color,
				parent = list,
			}, function()
				selected = s.id
				renderList()
				renderDetail()
			end)
			b.LayoutOrder = i
			Kit.label(b, "> " .. s.name, 18, {
				FontFace = Kit.MonoBold,
				TextColor3 = s.color,
				Position = UDim2.fromOffset(14, 12),
				Size = UDim2.new(1, -28, 0, 22),
				ZIndex = b.ZIndex + 1,
			})
			Kit.label(b, s.desc, 12, {
				TextColor3 = P.Dim,
				Position = UDim2.fromOffset(14, 40),
				Size = UDim2.new(1, -28, 0, 16),
				ZIndex = b.ZIndex + 1,
			})
			if s.id == selected then
				Kit.brackets(b, s.color, 10)
			end
		end
	end

	win.onOpen = function()
		renderList()
		renderDetail()
	end
	Ctx.Changed.Event:Connect(function()
		if win.open then
			renderDetail()
		end
	end)
	return win
end
