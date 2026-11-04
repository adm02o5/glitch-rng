--!strict
-- RIG FORGE (terminal): craft hand gear from auras.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Kit = require(script.Parent.Parent.Kit)
local W = require(script.Parent.Parent.Widgets)
local Ctx = require(script.Parent.Parent.Parent.Ctx)
local Sfx = require(script.Parent.Parent.Parent.Sfx)

local P = Kit.P
local new = Kit.new

return function()
	local win = Kit.window("RIG FORGE", "// fuse auras into hand gear · luck & speed", Vector2.new(860, 540), P.Amber)
	local selected = Config.Rigs[1].id

	local list = Kit.scroll(win.body, { Size = UDim2.new(0, 300, 1, 0) })
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), Parent = list })
	local detail = Kit.panel(win.body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -316, 1, 0),
		BackgroundColor3 = P.Bg,
	}, P.Amber)

	local renderList: () -> ()

	local function renderDetail()
		W.clear(detail)
		local rig = Config.RigById[selected]
		local d = Ctx.Data
		local owned = d.Rigs and d.Rigs[rig.id]
		Kit.label(detail, rig.name, 26, {
			FontFace = Kit.Title,
			TextColor3 = rig.color,
			Position = UDim2.fromOffset(18, 16),
			Size = UDim2.new(1, -36, 0, 30),
		})
		Kit.label(detail, rig.desc, 13, {
			TextColor3 = P.Dim,
			Position = UDim2.fromOffset(18, 50),
			Size = UDim2.new(1, -36, 0, 18),
			TextWrapped = true,
		})
		Kit.label(detail, string.format("+%d%% LUCK", math.floor(rig.luck * 100 + 0.5)), 18, {
			FontFace = Kit.MonoBold,
			TextColor3 = P.Lime,
			Position = UDim2.fromOffset(18, 80),
			Size = UDim2.fromOffset(200, 22),
		})
		Kit.label(detail, string.format("+%d%% SPEED", math.floor(rig.speed * 100 + 0.5)), 18, {
			FontFace = Kit.MonoBold,
			TextColor3 = P.Amber,
			Position = UDim2.fromOffset(220, 80),
			Size = UDim2.fromOffset(200, 22),
		})
		Kit.label(detail, "// REQUIRED AURAS", 12, {
			TextColor3 = P.Dim,
			Position = UDim2.fromOffset(18, 116),
			Size = UDim2.new(1, -36, 0, 14),
		})
		local rows = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(18, 136),
			Size = UDim2.new(1, -36, 1, -220),
			Parent = detail,
		})
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rows })
		local can = W.recipe(rows, rig.recipe, d.Inv or {})
		local text, color = "CRAFT", rig.color
		if owned then
			text = if d.Rig == rig.id then "EQUIPPED" else "EQUIP"
			color = P.Lime
		elseif not can then
			text, color = "MISSING AURAS", P.Red
		end
		Kit.button({
			text = text,
			size = UDim2.new(1, -36, 0, 54),
			position = UDim2.new(0, 18, 1, -70),
			color = color,
			textSize = 20,
			font = Kit.Title,
			parent = detail,
		}, function()
			if owned then
				if d.Rig ~= rig.id then
					Ctx.Request("EquipRig", rig.id)
				end
			elseif can then
				if Ctx.Request("CraftRig", rig.id) then
					Sfx.Play("Craft")
					Ctx.Toast("Crafted <b>" .. rig.name .. "</b>", rig.color)
				end
			else
				Sfx.Play("Error")
			end
		end)
	end

	renderList = function()
		W.clear(list)
		local d = Ctx.Data
		for i, rig in Config.Rigs do
			local owned = d.Rigs and d.Rigs[rig.id]
			local b = Kit.button({
				text = "",
				size = UDim2.new(1, 0, 0, 62),
				color = rig.color,
				parent = list,
			}, function()
				selected = rig.id
				renderList()
				renderDetail()
			end)
			b.LayoutOrder = i
			Kit.label(b, rig.name, 16, {
				FontFace = Kit.MonoBold,
				TextColor3 = rig.color,
				Position = UDim2.fromOffset(14, 10),
				Size = UDim2.new(1, -28, 0, 20),
				ZIndex = b.ZIndex + 1,
			})
			Kit.label(b, if owned then "OWNED" else string.format("+%d%% luck", math.floor(rig.luck * 100 + 0.5)), 12, {
				TextColor3 = if owned then P.Lime else P.Dim,
				Position = UDim2.fromOffset(14, 34),
				Size = UDim2.new(1, -28, 0, 16),
				ZIndex = b.ZIndex + 1,
			})
			if rig.id == selected then
				Kit.brackets(b, rig.color, 10)
			end
		end
	end

	win.onOpen = function()
		renderList()
		renderDetail()
	end
	Ctx.Changed.Event:Connect(function()
		if win.open then
			renderList()
			renderDetail()
		end
	end)
	return win
end
