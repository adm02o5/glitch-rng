--!strict
-- ADMIN panel (only for Config.Admins; the server checks again): preview every aura's look,
-- roll cutscene and burst, wear any aura, give auras, switch biomes, auto-play all auras.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)
local AuraFX = require(Shared.AuraFX)

local Kit = require(script.Parent.Parent.Kit)
local W = require(script.Parent.Parent.Widgets)
local Ctx = require(script.Parent.Parent.Parent.Ctx)
local Roller = require(script.Parent.Parent.Parent.Roller)

local P = Kit.P
local new = Kit.new
local player = Players.LocalPlayer

return function(): any
	if not Config.Admins[player.UserId] then
		return nil
	end

	local win = Kit.window("ADMIN", "// root access · preview every aura animation", Vector2.new(1000, 620), P.Red)
	local selected = Config.Auras[1].id
	local demo = false

	-- Biome switcher row.
	local biomes = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = win.body })
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = biomes,
	})
	Kit.label(biomes, "BIOME", 13, { FontFace = Kit.MonoBold, TextColor3 = P.Dim, Size = UDim2.fromOffset(56, 20) })
	for _, b in Config.Biomes do
		Kit.button({ text = b.name, size = UDim2.fromOffset(124, 32), color = b.color, textSize = 12, parent = biomes }, function()
			Ctx.Request("AdminBiome", b.id)
		end)
	end

	local left = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, -316, 1, -46),
		Parent = win.body,
	})
	local grid = W.grid(left, Vector2.new(118, 96))
	local detail = Kit.panel(win.body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 46),
		Size = UDim2.new(0, 300, 1, -46),
		BackgroundColor3 = P.Bg,
	}, P.Red)

	-- Floating stop button shown while the auto demo runs (the window is closed then).
	local stop = Kit.button({
		text = "STOP DEMO",
		size = UDim2.fromOffset(170, 44),
		position = UDim2.new(1, -24, 0, 110),
		anchor = Vector2.new(1, 0),
		color = P.Red,
		textSize = 15,
		font = Kit.Title,
		parent = Kit.Top,
	}, function()
		demo = false
	end)
	stop.Visible = false
	local nowPlaying = Kit.label(Kit.Top, "", 14, {
		FontFace = Kit.MonoBold,
		TextColor3 = P.Red,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 160),
		Size = UDim2.fromOffset(300, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
	})
	-- Phones: bigger stop button, docked left of the HUD menu tiles so it covers nothing.
	Kit.OnLayout(function(mobile: boolean)
		local inset = Kit.Inset()
		stop.Size = if mobile then UDim2.fromOffset(190, 76) else UDim2.fromOffset(170, 44)
		stop.Position = if mobile then UDim2.new(1, -208, 0, inset + 58) else UDim2.new(1, -24, 0, 110)
		nowPlaying.Position = if mobile then UDim2.new(1, -208, 0, inset + 142) else UDim2.new(1, -24, 0, 160)
	end)

	local function burst(id: string)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			AuraFX.Burst(root.Position, id, 1)
		end
	end

	-- Close the window, run fn, reopen it afterwards.
	local function hidden(fn: () -> ())
		win:Close()
		task.wait(0.25)
		fn()
		win:Open()
	end

	local render: () -> ()

	local function runDemo(from: string)
		if demo or Ctx.Busy then
			return
		end
		demo = true
		win:Close()
		stop.Visible = true
		nowPlaying.Visible = true
		local started = false
		for _, a in Config.Auras do
			if not demo then
				break
			end
			if a.id == from then
				started = true
			end
			if started then
				selected = a.id
				nowPlaying.Text = string.format("%s  ·  1/%s", a.name, RNG.Short(a.chance))
				Ctx.Request("AdminWear", a.id)
				Roller.Preview(a, false)
				local t0 = os.clock()
				while demo and os.clock() - t0 < 2.5 do
					task.wait(0.1) -- time to look at the aura on the character
				end
			end
		end
		demo = false
		stop.Visible = false
		nowPlaying.Visible = false
		win:Open()
	end

	local function renderDetail()
		W.clear(detail)
		local a = Config.AuraById[selected]
		local tier = Config.TierOf(a.chance)
		W.swatch(detail, a, UDim2.new(1, -32, 0, 90), UDim2.fromOffset(16, 16))
		W.tierTag(detail, tier, UDim2.fromOffset(16, 116))
		if a.biome then
			local bm = Config.BiomeById[a.biome]
			Kit.label(detail, bm.name .. " ONLY", 11, {
				FontFace = Kit.MonoBold,
				TextColor3 = bm.color,
				Position = UDim2.fromOffset(120, 117),
				Size = UDim2.fromOffset(160, 16),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
		Kit.label(detail, a.name, 22, {
			FontFace = Kit.Title,
			TextColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.3),
			Position = UDim2.fromOffset(16, 142),
			Size = UDim2.new(1, -32, 0, 26),
		})
		Kit.label(detail, RNG.ChanceText(a.chance) .. "   ·   cutscene lvl " .. tier.cutscene, 13, {
			FontFace = Kit.MonoBold,
			TextColor3 = tier.color,
			Position = UDim2.fromOffset(16, 172),
			Size = UDim2.new(1, -32, 0, 16),
		})
		Kit.label(detail, a.look, 12, {
			TextColor3 = P.Dim,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(16, 196),
			Size = UDim2.new(1, -32, 0, 46),
		})

		local y = 250
		local function action(text: string, color: Color3, fn: () -> ())
			Kit.button({
				text = text,
				size = UDim2.new(1, -32, 0, 40),
				position = UDim2.fromOffset(16, y),
				color = color,
				textSize = 14,
				font = Kit.MonoBold,
				parent = detail,
			}, fn)
			y += 48
		end
		action("▶  PLAY ROLL + CUTSCENE", tier.color, function()
			hidden(function()
				Roller.Preview(a, true)
			end)
		end)
		action("WEAR AURA", P.Cyan, function()
			Ctx.Request("AdminWear", a.id)
		end)
		action("BURST EFFECT", P.Magenta, function()
			hidden(function()
				burst(a.id)
				task.wait(2.5)
			end)
		end)
		action("GIVE x1 TO INVENTORY", P.Lime, function()
			if Ctx.Request("AdminGive", { id = a.id, n = 1 }) then
				Ctx.Toast("Given <b>" .. a.name .. "</b>", P.Lime)
			end
		end)
		action("TAKE OFF (BACK TO MY AURA)", P.Dim, function()
			Ctx.Request("AdminWear", "")
		end)
		Kit.button({
			text = "▶  PLAY ALL FROM HERE",
			size = UDim2.new(1, -32, 0, 46),
			position = UDim2.new(0, 16, 1, -62),
			color = P.Red,
			textSize = 15,
			font = Kit.Title,
			parent = detail,
		}, function()
			task.spawn(runDemo, a.id)
		end)
	end

	render = function()
		W.clear(grid)
		for _, a in Config.Auras do
			local t = W.auraTile(grid, a, nil, true, function()
				selected = a.id
				render()
				renderDetail()
			end)
			if a.id == selected then
				Kit.brackets(t, P.Red, 10)
			end
		end
	end

	win.onOpen = function()
		render()
		renderDetail()
	end
	return win
end
