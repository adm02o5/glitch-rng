--!strict
-- SCRIPTS window: run owned boost scripts.

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

return function()
	local win = Kit.window("SCRIPTS", "// execute compiled boosts · craft more at the SCRIPT LAB", Vector2.new(660, 580), P.Lime)
	local list = Kit.scroll(win.body)
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2), Parent = list })

	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local function render()
		W.clear(list)
		local d = Ctx.Data
		for i, s in Config.Scripts do
			local owned = d.Scripts and d.Scripts[s.id] or 0
			local row = Kit.panel(list, { Size = UDim2.new(1, 0, 0, 84), LayoutOrder = i, BackgroundColor3 = P.Bg }, s.color)
			Kit.label(row, "> " .. s.name, 20, {
				FontFace = Kit.MonoBold,
				TextColor3 = s.color,
				Position = UDim2.fromOffset(16, 12),
				Size = UDim2.new(1, -200, 0, 24),
			})
			local active = d.Active and d.Active[s.id]
			local info = s.desc
			if active then
				info ..= "   ·   running " .. RNG.Time(active)
			elseif d.NextRolls and (d.NextRolls[s.id] or 0) > 0 then
				info ..= "   ·   armed x" .. tostring(d.NextRolls[s.id])
			end
			Kit.label(row, info, 13, {
				TextColor3 = P.Dim,
				Position = UDim2.fromOffset(16, 44),
				Size = UDim2.new(1, -200, 0, 16),
			})
			Kit.label(row, "x" .. tostring(owned), 22, {
				FontFace = Kit.MonoBold,
				TextColor3 = if owned > 0 then P.Text else P.Line,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -150, 0.5, 0),
				Size = UDim2.fromOffset(60, 26),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			Kit.button({
				text = "RUN",
				size = UDim2.fromOffset(110, 48),
				position = UDim2.new(1, -16, 0.5, 0),
				anchor = Vector2.new(1, 0.5),
				color = if owned > 0 then s.color else P.Line,
				textSize = 18,
				font = Kit.Title,
				parent = row,
			}, function()
				if owned > 0 and Ctx.Request("UseScript", s.id) then
					Sfx.Play("Glitch")
					Ctx.Toast("Executed <b>" .. s.name .. "</b>", s.color)
				else
					Sfx.Play("Error")
				end
			end)
		end
	end

	win.onOpen = render
	Ctx.Changed.Event:Connect(function()
		if win.open then
			render()
		end
	end)
	return win
end
