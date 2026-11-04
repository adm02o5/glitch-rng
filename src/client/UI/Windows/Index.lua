--!strict
-- AURA INDEX: every aura in the game, undiscovered ones hidden, with discovery progress.

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
	local win = Kit.window("AURA INDEX", "// archive of every known signature", Vector2.new(900, 560), P.Magenta)
	local selected: string? = nil

	local progress = Kit.label(win.body, "", 14, {
		FontFace = Kit.MonoBold,
		TextColor3 = P.Magenta,
		Size = UDim2.new(1, -300, 0, 18),
	})
	local barBg = new("Frame", {
		BackgroundColor3 = P.Bg,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -300, 0, 6),
		Parent = win.body,
	})
	Kit.corner(barBg, 3)
	local bar = new("Frame", { BackgroundColor3 = P.Magenta, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = barBg })
	Kit.corner(bar, 3)

	local left = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, -300, 1, -42),
		Parent = win.body,
	})
	local grid = W.grid(left, Vector2.new(124, 96))
	local detail = Kit.panel(win.body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 284, 1, 0),
		BackgroundColor3 = P.Bg,
	}, P.Magenta)

	local function renderDetail()
		W.clear(detail)
		local a = selected and Config.AuraById[selected]
		if not a then
			Kit.label(detail, "Select an entry", 14, {
				TextColor3 = P.Dim,
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			return
		end
		local d = Ctx.Data
		local found = d.Found and d.Found[a.id]
		local tier = Config.TierOf(a.chance)
		if found then
			W.swatch(detail, a, UDim2.new(1, -32, 0, 120), UDim2.fromOffset(16, 18))
		else
			local q = new("Frame", {
				BackgroundColor3 = P.Panel,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(16, 18),
				Size = UDim2.new(1, -32, 0, 120),
				Parent = detail,
			})
			Kit.corner(q, 3)
			Kit.label(q, "ENCRYPTED", 16, {
				FontFace = Kit.Pixel,
				TextColor3 = P.Line,
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
		W.tierTag(detail, tier, UDim2.fromOffset(16, 150))
		Kit.label(detail, if found then a.name else "???", 24, {
			FontFace = Kit.Title,
			TextColor3 = if found then tier.color:Lerp(Color3.new(1, 1, 1), 0.3) else P.Dim,
			Position = UDim2.fromOffset(16, 178),
			Size = UDim2.new(1, -32, 0, 28),
		})
		Kit.label(detail, RNG.ChanceText(a.chance), 15, {
			FontFace = Kit.MonoBold,
			TextColor3 = tier.color,
			Position = UDim2.fromOffset(16, 210),
			Size = UDim2.new(1, -32, 0, 18),
		})
		local y = 236
		if a.biome then
			local bm = Config.BiomeById[a.biome]
			Kit.label(detail, "Only during " .. bm.name, 13, {
				FontFace = Kit.MonoBold,
				TextColor3 = bm.color,
				Position = UDim2.fromOffset(16, y),
				Size = UDim2.new(1, -32, 0, 16),
			})
			y += 22
		end
		Kit.label(detail, if found then '"' .. a.desc .. '"' else "Roll it to decrypt this entry.", 13, {
			TextColor3 = P.Dim,
			TextWrapped = true,
			Position = UDim2.fromOffset(16, y),
			Size = UDim2.new(1, -32, 0, 60),
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		if found then
			Kit.label(detail, "FIRST FOUND  " .. os.date("%Y-%m-%d", found), 12, {
				TextColor3 = P.Dim,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16, 1, -16),
				Size = UDim2.new(1, -32, 0, 14),
			})
		end
	end

	local function render()
		W.clear(grid)
		local d = Ctx.Data
		local n = 0
		for _, a in Config.Auras do
			local known = d.Found ~= nil and d.Found[a.id] ~= nil
			if known then
				n += 1
			end
			W.auraTile(grid, a, nil, known, function()
				selected = a.id
				renderDetail()
			end)
		end
		progress.Text = string.format("DISCOVERED  %d / %d", n, #Config.Auras)
		bar.Size = UDim2.fromScale(n / #Config.Auras, 1)
	end

	win.onOpen = function()
		render()
		renderDetail()
	end
	Ctx.Changed.Event:Connect(function()
		if win.open then
			render()
		end
	end)
	return win
end
