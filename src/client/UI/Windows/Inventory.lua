--!strict
-- AURAS window: owned auras grid + detail panel with equip; RIGS tab for owned hand gear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)

local Kit = require(script.Parent.Parent.Kit)
local W = require(script.Parent.Parent.Widgets)
local Ctx = require(script.Parent.Parent.Parent.Ctx)

local P = Kit.P
local new = Kit.new

return function()
	local win = Kit.window("AURAS", "// local storage · equip one aura at a time", Vector2.new(900, 560))
	local tab = "Auras"
	local selected: string? = nil

	local content = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		Parent = win.body,
	})
	local left = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -300, 1, 0), Parent = content })
	local detail = Kit.panel(content, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 284, 1, 0),
		BackgroundColor3 = P.Bg,
	})
	local grid = W.grid(left, Vector2.new(124, 96))

	local function renderDetail()
		W.clear(detail)
		local d = Ctx.Data
		if tab == "Rigs" then
			local rig = selected and Config.RigById[selected]
			if not rig then
				Kit.label(detail, "Select a rig", 14, {
					TextColor3 = P.Dim,
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				return
			end
			Kit.label(detail, rig.name, 22, {
				FontFace = Kit.Title,
				TextColor3 = rig.color,
				Position = UDim2.fromOffset(16, 20),
				Size = UDim2.new(1, -32, 0, 26),
				TextWrapped = true,
			})
			Kit.label(detail, rig.desc, 13, {
				TextColor3 = P.Dim,
				TextWrapped = true,
				Position = UDim2.fromOffset(16, 56),
				Size = UDim2.new(1, -32, 0, 40),
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			Kit.label(detail, string.format("LUCK   +%d%%", math.floor(rig.luck * 100 + 0.5)), 16, {
				FontFace = Kit.MonoBold,
				TextColor3 = P.Lime,
				Position = UDim2.fromOffset(16, 110),
				Size = UDim2.new(1, -32, 0, 20),
			})
			Kit.label(detail, string.format("SPEED  +%d%%", math.floor(rig.speed * 100 + 0.5)), 16, {
				FontFace = Kit.MonoBold,
				TextColor3 = P.Amber,
				Position = UDim2.fromOffset(16, 134),
				Size = UDim2.new(1, -32, 0, 20),
			})
			local equipped = d.Rig == rig.id
			Kit.button({
				text = if equipped then "UNEQUIP" else "EQUIP",
				size = UDim2.new(1, -32, 0, 48),
				position = UDim2.new(0, 16, 1, -64),
				color = if equipped then P.Red else rig.color,
				textSize = 18,
				font = Kit.Title,
				sound = "Equip",
				parent = detail,
			}, function()
				Ctx.Request("EquipRig", if equipped then "" else rig.id)
			end)
			return
		end

		local a = selected and Config.AuraById[selected]
		if not a or (d.Inv and (d.Inv[a.id] or 0) <= 0) then
			Kit.label(detail, "Select an aura", 14, {
				TextColor3 = P.Dim,
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			return
		end
		local tier = Config.TierOf(a.chance)
		W.swatch(detail, a, UDim2.new(1, -32, 0, 120), UDim2.fromOffset(16, 18))
		W.tierTag(detail, tier, UDim2.fromOffset(16, 150))
		if a.biome then
			local bm = Config.BiomeById[a.biome]
			local l = Kit.label(detail, bm.name .. " ONLY", 11, {
				FontFace = Kit.MonoBold,
				TextColor3 = bm.color,
				Position = UDim2.fromOffset(120, 150),
				Size = UDim2.fromOffset(140, 18),
			})
			l.TextXAlignment = Enum.TextXAlignment.Right
		end
		local nameL = Kit.label(detail, a.name, 26, {
			FontFace = Kit.Title,
			TextColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.3),
			Position = UDim2.fromOffset(16, 176),
			Size = UDim2.new(1, -32, 0, 30),
			TextScaled = true,
		})
		new("UITextSizeConstraint", { MaxTextSize = 26, Parent = nameL })
		Kit.label(detail, RNG.ChanceText(a.chance), 15, {
			FontFace = Kit.MonoBold,
			TextColor3 = tier.color,
			Position = UDim2.fromOffset(16, 210),
			Size = UDim2.new(1, -32, 0, 18),
		})
		Kit.label(detail, '"' .. a.desc .. '"', 13, {
			TextColor3 = P.Dim,
			TextWrapped = true,
			Position = UDim2.fromOffset(16, 238),
			Size = UDim2.new(1, -32, 0, 54),
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		Kit.label(detail, "OWNED  x" .. RNG.Commas(d.Inv[a.id] or 0), 14, {
			FontFace = Kit.MonoBold,
			Position = UDim2.fromOffset(16, 296),
			Size = UDim2.new(1, -32, 0, 18),
		})
		local equipped = d.Aura == a.id
		local b = Kit.button({
			text = if equipped then "EQUIPPED" else "EQUIP",
			size = UDim2.new(1, -32, 0, 48),
			position = UDim2.new(0, 16, 1, -64),
			color = if equipped then P.Lime else tier.color,
			textSize = 18,
			font = Kit.Title,
			sound = "Equip",
			parent = detail,
		}, function()
			if not equipped then
				Ctx.Request("Equip", a.id)
			end
		end)
		b.AutoButtonColor = false
	end

	local function renderGrid()
		W.clear(grid)
		local d = Ctx.Data
		if tab == "Rigs" then
			for _, rig in Config.Rigs do
				if d.Rigs and d.Rigs[rig.id] then
					local b = Kit.button({
						text = rig.name,
						size = UDim2.fromOffset(124, 96),
						color = rig.color,
						textSize = 13,
						parent = grid,
					}, function()
						selected = rig.id
						renderDetail()
					end)
					if d.Rig == rig.id then
						Kit.brackets(b, P.Lime)
					end
				end
			end
			if #grid:GetChildren() <= 2 then
				Kit.label(grid, "No rigs yet. Craft them at the RIG FORGE terminal.", 14, {
					TextColor3 = P.Dim,
					Size = UDim2.fromOffset(500, 40),
				})
			end
			return
		end
		local any = false
		for _, a in Config.Auras do
			local n = d.Inv and d.Inv[a.id] or 0
			if n > 0 then
				any = true
				local t = W.auraTile(grid, a, n, true, function()
					selected = a.id
					renderDetail()
				end)
				t.LayoutOrder = -a.chance
				if d.Aura == a.id then
					Kit.brackets(t, P.Lime, 10)
				end
			end
		end
		if not any then
			Kit.label(grid, "Nothing here yet. Press ROLL.", 14, { TextColor3 = P.Dim, Size = UDim2.fromOffset(400, 40) })
		end
	end

	local select = W.tabs(win.body, { "Auras", "Rigs" }, function(name)
		tab = name
		selected = if name == "Auras" then Ctx.Data.Aura else Ctx.Data.Rig
		renderGrid()
		renderDetail()
	end)

	win.onOpen = function()
		select(tab)
	end
	Ctx.Changed.Event:Connect(function()
		if win.open then
			renderGrid()
			renderDetail()
		end
	end)
	return win
end
