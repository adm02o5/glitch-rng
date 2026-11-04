--!strict
-- Cutscene/Legendary: themed ~5s scenes for every LEGENDARY aura (skippable unless first time).
--
--   Mainframe    CRT power-on, BIOS POST screen with memory test, server racks boot LED by LED, fans spin up,
--                the rack doors open on the world while cable beams lock onto the player
--   Quantum      wave function + four superposed copies of the avatar, camera jumps between states, the
--                observer collapses everything into one
--   Overclocked  clock gauge redlines past 300%, heat haze, sparks and arcs, thermal alarms
--   NeuralLink   close-up cortex scan: a neuron web grows out of the head, synapse pulses, EEG locks to sync
--   Sentinel     hex shield plates assemble into a honeycomb, a golden eye opens and scans the player

local Players = game:GetService("Players")

local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local U = require(script.Parent.Util)
local Fx = require(script.Parent.Fx)

local P = Kit.P
local WHITE, BLACK = U.WHITE, U.BLACK
local clamp01, lerp, seg = U.clamp01, U.lerp, U.seg
local outCubic, inCubic, inOutCubic, outBack, bump = U.outCubic, U.inCubic, U.inOutCubic, U.outBack, U.bump
local setT, setLine = Fx.setT, Fx.setLine
local player = Players.LocalPlayer

local Scenes = {}

local function round(f: GuiObject)
	Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
end

local function mono(S: any, size: number, props: { [string]: any }): TextLabel
	local p: { [string]: any } = { FontFace = Kit.MonoBold, TextSize = math.floor(size * S.vs + 0.5) }
	for k, v in props do
		p[k] = v
	end
	local l = S:text(p)
	Kit.new("UIStroke", { Thickness = 1.5, Color = BLACK, Transparency = 0.4, Parent = l })
	return l
end

-- CRT power-on: a bright line opens vertically into a black screen. Returns the black frame.
local function crtOn(S: any, z: number, dur: number): Frame
	local black = S:fill(BLACK, z, 1)
	local line = S:frame({
		BackgroundColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 3),
		ZIndex = z + 1,
	})
	S:phase(dur, function(k: number)
		black.BackgroundTransparency = 1 - outCubic(seg(k, 0, 0.3))
		local w = outCubic(seg(k, 0.15, 0.55))
		local h = inCubic(seg(k, 0.55, 1))
		line.Size = UDim2.new(w, 0, h, 3)
		line.BackgroundTransparency = seg(k, 0.6, 1)
	end)
	line:Destroy()
	return black
end

--------------------------------------------------------------------------------------------------------
-- MAINFRAME: the machine that runs the machines
--------------------------------------------------------------------------------------------------------

function Scenes.Mainframe(S: any)
	local a = S.aura
	local col = a.color
	local rng = S.rng
	S:hideHud()
	local cc = S:cc()
	S:sfx("Click", 0.6, 0.6)
	S:sfx("Glitch", 0.3, 0.6)
	local black = crtOn(S, 20, 0.3)
	S:orbitShot({ dur = 5, deg = 70, r0 = 15, r1 = 10, h0 = 6, h1 = 2.5, fov0 = 60, fov1 = 52, blend = 0 })

	-- 1) POST screen.
	local post = S:frame({ Name = "Post", BackgroundTransparency = 1, ZIndex = 22 })
	local logo = Kit.panel(post, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -30, 0, 30),
		Size = UDim2.fromOffset(math.floor(250 * S.vs), math.floor(90 * S.vs)),
		ZIndex = 23,
	}, col)
	mono(S, 22, {
		Text = "FATE//BIOS\nMEGA-NODE",
		TextColor3 = col,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 24,
		Parent = logo,
	})
	local lines = {
		"GLITCH BIOS v4.04   (C) 2026 Fate Systems Inc.",
		"Mainframe node " .. U.hex(rng, 8) .. "   Sector: " .. S.biomeName,
		"",
		"CPU0-CPU127 : FATE-CORE x128 @ 9.99 THz",
		"@MEM",
		"Detecting rack units ........ 42U found",
		"Cooling ..................... LIQUID N2  [ OK ]",
		"Probability engine .......... [ OK ]",
		"Luck coprocessor ............ [ OK ]",
		"",
		"Press DEL to enter SETUP",
	}
	local labels: { TextLabel } = {}
	local lh = math.floor(22 * S.vs + 0.5)
	for i, t in lines do
		labels[i] = mono(S, 17, {
			Text = if t == "@MEM" then "" else t,
			TextColor3 = if i == 1 then WHITE else Color3.fromRGB(190, 200, 215),
			Position = UDim2.fromOffset(36, 34 + (i - 1) * lh),
			Size = UDim2.new(0.7, 0, 0, lh),
			Visible = false,
			ZIndex = 23,
			Parent = post,
		})
	end
	S:sfx("Tick", 0.6, 2)
	local memIdx = table.find(lines, "@MEM") or 5
	local shownN = 0
	S:phase(1.6, function(_: number, e: number)
		local n = math.min(#lines, math.floor(e / 0.11) + 1)
		while shownN < n do
			shownN += 1
			labels[shownN].Visible = true
			if lines[shownN] ~= "" then
				S:sfx("Type", 0.3, 0.8 + rng:NextNumber() * 0.4)
			end
		end
		if shownN >= memIdx then
			local me = clamp01((e - (memIdx - 1) * 0.11) / 0.6)
			local kb = math.floor(33554432 * me ^ 2 / 1024) * 1024
			labels[memIdx].Text = "Memory Test : " .. U.commas(kb) .. "K" .. (if me >= 1 then "  OK" else "")
		end
		labels[#lines].TextTransparency = if U.blink(e, 3) > 0 then 0 else 0.8
	end)

	-- 2) Server racks boot.
	S:sfx("Riser", 0.45, 1.1)
	post:Destroy()
	local racks = S:frame({ Name = "Racks", BackgroundTransparency = 1, ZIndex = 22 })
	local nR, nU, nL = 4, 12, 7
	local leds: { { f: Frame, row: number, rack: number } } = {}
	local fans: { Frame } = {}
	local rackFrames: { Frame } = {}
	for r = 1, nR do
		local rf = S:frame({
			Name = "Rack",
			BackgroundColor3 = Color3.fromRGB(6, 10, 16),
			BackgroundTransparency = 0.08,
			Position = UDim2.fromScale((r - 1) / nR, 0),
			Size = UDim2.new(1 / nR, 1, 1, 0),
			ZIndex = 22,
			Parent = racks,
		})
		Kit.new("UIStroke", { Color = col:Lerp(BLACK, 0.4), Thickness = 2, Parent = rf })
		rackFrames[r] = rf
		-- Fan at the top.
		local fan = S:frame({
			Name = "Fan",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.1),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			Size = UDim2.fromScale(0.42, 0.42),
			ZIndex = 23,
			Parent = rf,
		})
		local ring = S:circle(23, col, 1, 2, fan)
		ring.SizeConstraint = Enum.SizeConstraint.RelativeXY
		for b = 0, 2 do
			local blade = S:frame({
				BackgroundColor3 = col:Lerp(WHITE, 0.2),
				BackgroundTransparency = 0.35,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.95, 0.16),
				Rotation = b * 60,
				ZIndex = 24,
				Parent = fan,
			})
			Kit.corner(blade, 6)
		end
		fans[r] = fan
		for u = 1, nU do
			local y = 0.22 + (u - 1) * (0.74 / nU)
			local unit = S:frame({
				BackgroundColor3 = Color3.fromRGB(14, 20, 30),
				Position = UDim2.new(0.06, 0, y, 0),
				Size = UDim2.new(0.88, 0, 0.74 / nU, -4),
				ZIndex = 23,
				Parent = rf,
			})
			Kit.corner(unit, 2)
			mono(S, 11, {
				Text = string.format("U%02d", (nU - u + 1) + (r - 1) * nU),
				TextColor3 = P.Dim,
				Position = UDim2.fromOffset(6, 0),
				Size = UDim2.new(0.2, 0, 1, 0),
				ZIndex = 24,
				Parent = unit,
			})
			for l = 1, nL do
				local led = S:frame({
					BackgroundColor3 = P.Line,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0.3 + (l - 1) * 0.095, 0, 0.5, 0),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
					Size = UDim2.fromScale(0.32, 0.32),
					ZIndex = 24,
					Parent = unit,
				})
				Kit.corner(led, 3)
				table.insert(leds, { f = led, row = nU - u + 1, rack = r })
			end
		end
	end
	local bootL = mono(S, 18, {
		TextColor3 = col,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 30,
	})
	local ledCols = { P.Lime, col, P.Amber, col:Lerp(WHITE, 0.3) }
	local lastRow = 0
	local fanAng = 0
	S:phase(1.5, function(k: number)
		black.BackgroundTransparency = lerp(0, 0.6, seg(k, 0.4, 1))
		local row = math.floor(k * nU * 1.15)
		if row ~= lastRow and row <= nU then
			lastRow = row
			S:sfx("Tick", 0.3, 0.7 + row / nU * 0.8)
		end
		for _, l in leds do
			if l.row <= row then
				if rng:NextNumber() < 0.18 then
					local on = rng:NextNumber() < 0.7
					l.f.BackgroundColor3 = if on then ledCols[rng:NextInteger(1, #ledCols)] else P.Line
				end
			end
		end
		fanAng += (200 + 2400 * k * k) * (1 / 60)
		for _, f in fans do
			f.Rotation = fanAng
		end
		bootL.Text = "BOOTING MAINFRAME  [" .. string.rep("|", math.floor(k * 30)) .. string.rep(".", 30 - math.floor(k * 30)) .. "]  " .. math.floor(k * 100) .. "%"
		cc.TintColor = WHITE:Lerp(col, 0.15 * k)
	end)

	-- 3) Rack doors open on the world; cable beams lock onto the player.
	S:sfx("Boom", 0.6, 0.8)
	S:sfx("Whoosh", 0.6, 0.9)
	S:burst(1.7)
	S:worldFlash(col, 0.6)
	bootL.Text = "MAINFRAME ONLINE"
	bootL.TextColor3 = WHITE
	Kit.glitch(bootL, 0.3)
	local sz = S.gui.AbsoluteSize
	local cables = {}
	for i = 1, 8 do
		local sx = if i <= 4 then 0 else sz.X
		local sy = sz.Y * ((i - 1) % 4 + 0.5) / 4
		local f = S:line(sx, sy, sx, sy, 3, col, 26)
		local g = S:line(sx, sy, sx, sy, 10, col, 25)
		g.BackgroundTransparency = 0.7
		table.insert(cables, { f = f, g = g, x = sx, y = sy })
	end
	S:phase(1.0, function(k: number, e: number)
		local q = inOutCubic(k)
		for r, rf in rackFrames do
			local dir = if r <= nR / 2 then -1 else 1
			rf.Position = UDim2.fromScale((r - 1) / nR + dir * 0.55 * q, 0)
		end
		black.BackgroundTransparency = lerp(0.6, 1, q)
		local hp, on = S:toScreen(S:focusPos() + Vector3.new(0, 1, 0))
		for _, c in cables do
			local grow = outCubic(seg(k, 0.2, 0.7))
			local tx = c.x + ((if on then hp.X else sz.X / 2) - c.x) * grow
			local ty = c.y + ((if on then hp.Y else sz.Y / 2) - c.y) * grow
			setLine(c.f, c.x, c.y, tx, ty, 3)
			setLine(c.g, c.x, c.y, tx, ty, 10)
			c.f.BackgroundTransparency = 0.1 + 0.4 * math.sin(e * 30 + c.y) ^ 2
		end
		cc.Brightness = 0.1 * bump(k)
		S.fovPunch = -6 * bump(k)
	end)
	S:outro(col:Lerp(WHITE, 0.6), 0.16, 0.45)
end

--------------------------------------------------------------------------------------------------------
-- QUANTUM: both rolled and not rolled
--------------------------------------------------------------------------------------------------------

function Scenes.Quantum(S: any)
	local a = S.aura
	local col = a.color
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	S:hideHud()
	local cc = S:cc()
	local dim = S:fill(Color3.fromRGB(8, 4, 20), 8, 1)
	local vig = S:edges(col, 0.25, 9)
	setT(vig, 1)

	-- Wave function across the lower third.
	local nDots = 72
	local dots: { Frame } = {}
	for i = 1, nDots do
		local d = S:frame({
			BackgroundColor3 = if i % 2 == 0 then col else WHITE,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(5, 5),
			BackgroundTransparency = 1,
			ZIndex = 12,
		})
		Kit.corner(d, 3)
		dots[i] = d
	end
	local eq = mono(S, 18, {
		Text = "|psi> = a|ROLLED> + b|NOT ROLLED>",
		TextColor3 = col:Lerp(WHITE, 0.4),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.new(1, 0, 0, 24),
		TextTransparency = 1,
		ZIndex = 30,
	})

	-- Four superposed copies of the avatar.
	local states = { "|0>", "|1>", "|+>", "|->" }
	local spots = { Vector2.new(0.24, 0.42), Vector2.new(0.76, 0.42), Vector2.new(0.38, 0.5), Vector2.new(0.62, 0.5) }
	local copies = {}
	for i = 1, 4 do
		local holder = S:frame({
			Name = "State",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spots[i].X, spots[i].Y),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Size = UDim2.fromScale(0.3, 0.5),
			ZIndex = 14,
		})
		local v = S:charView({
			Size = UDim2.fromScale(1, 1),
			ImageColor3 = col:Lerp(WHITE, 0.3 + 0.15 * (i % 2)),
			ImageTransparency = 1,
			ZIndex = 14,
			Parent = holder,
		}, { dist = 12, height = 0.6, ambient = WHITE, light = col })
		Kit.brackets(holder, col, 16, 15)
		local tag = mono(S, 16, {
			Text = states[i] .. "  50.0%",
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 1.02),
			Size = UDim2.new(1.6, 0, 0, 20),
			ZIndex = 16,
			Parent = holder,
		})
		copies[i] = { holder = holder, v = v, tag = tag, ph = rng:NextNumber(0, math.pi * 2), base = spots[i] }
		holder.Visible = false
	end

	-- Camera: jumps between superposed angles, then settles.
	local mode = "jump"
	local angles = { 0, 2.1, 4.2, 1.05, 3.15, 5.25 }
	local look0 = S:focusLook()
	local base = math.atan2(look0.Z, look0.X)
	S:shot(function(e: number, c: Vector3)
		local look = c + Vector3.new(0, 1.3, 0)
		if mode == "jump" then
			local idx = math.floor(e / 0.28) % #angles + 1
			local ang = base + angles[idx]
			local R = 10 + (idx % 2) * 3
			local pos = S:safe(look, c + Vector3.new(math.cos(ang) * R, 2.5 + (idx % 3), math.sin(ang) * R))
			return CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, math.rad((idx % 2) * 6 - 3)), 55
		end
		local ang = base + e * 0.4
		local pos = S:safe(look, c + Vector3.new(math.cos(ang) * 8, 2, math.sin(ang) * 8))
		return CFrame.lookAt(pos, look), 48
	end, 0.25)

	S:sfx("Riser", 0.45, 0.9)
	S:sfx("Glitch", 0.35, 1.4)
	local function wave(e: number, amp: number, collapse: number)
		for i, d in dots do
			local x = (i - 1) / (nDots - 1)
			local y = math.sin(x * 14 + e * 5) * 0.5 + math.sin(x * 23 - e * 7) * 0.3 + math.sin(x * 5 + e * 2) * 0.2
			local g = math.exp(-((x - 0.5) ^ 2) / 0.0012)
			local yy = lerp(y * amp, -g * 2.2, collapse)
			d.Position = UDim2.fromOffset(sz.X * (0.08 + 0.84 * x), sz.Y * 0.82 + yy * sz.Y * 0.05)
		end
	end
	-- 1) Superposition.
	local lastJump = -1
	S:phase(2.4, function(k: number, e: number)
		dim.BackgroundTransparency = 1 - 0.5 * outCubic(seg(e, 0, 0.4))
		setT(vig, 1 - 0.35 * outCubic(seg(e, 0, 0.4)))
		eq.TextTransparency = 1 - seg(e, 0.1, 0.4)
		for _, d in dots do
			d.BackgroundTransparency = 1 - 0.8 * seg(e, 0, 0.4)
		end
		wave(e, 0.6 + 0.4 * k, 0)
		for i, c in copies do
			c.holder.Visible = e > 0.15 + i * 0.12
			local phase = 0.5 + 0.5 * math.sin(e * 7 + c.ph)
			c.v.vp.ImageTransparency = 0.25 + 0.55 * phase + (if rng:NextNumber() < 0.06 then 0.3 else 0)
			c.v.set(e * (if i % 2 == 0 then 1.2 else -1.2) + c.ph)
			c.holder.Position = UDim2.new(c.base.X, math.sin(e * 3 + c.ph) * 8, c.base.Y, math.cos(e * 2.5 + c.ph) * 6)
			local p = 50 + 49.9 * math.sin(e * 11 + c.ph)
			c.tag.Text = states[i] .. string.format("  %4.1f%%", p)
		end
		cc.TintColor = WHITE:Lerp(col, 0.18)
		cc.Saturation = -0.35
		local j = math.floor(e / 0.28)
		if j ~= lastJump then
			lastJump = j
			S:sfx("Glitch", 0.2, 1.6 + rng:NextNumber() * 0.4)
		end
	end)
	-- 2) Observation: everything rushes into one state.
	mode = "settle"
	eq.Text = "OBSERVING..."
	eq.TextColor3 = WHITE
	S:sfx("Riser", 0.5, 1.6)
	local reticle = S:circle(20, WHITE, 0.6, 2)
	S:phase(0.9, function(k: number, e: number)
		local q = inCubic(k)
		for _, c in copies do
			local x = lerp(c.base.X, 0.5, q)
			local y = lerp(c.base.Y, 0.5, q)
			c.holder.Position = UDim2.fromScale(x, y)
			c.v.vp.ImageTransparency = lerp(0.4, 0.1, q)
		end
		wave(e + 2.4, 1 - k, q)
		local rs = lerp(0.9, 0.32, outCubic(k))
		reticle.Size = UDim2.fromScale(rs, rs)
		reticle.Rotation = e * 90
		S.shake = 0.5 * q
	end)
	-- 3) Collapse.
	for _, c in copies do
		c.holder:Destroy()
	end
	reticle:Destroy()
	eq.Text = "STATE COLLAPSED  ::  |ROLLED>"
	Kit.glitch(eq, 0.35)
	S:sfx("Boom", 0.75, 0.9)
	S:sfx("Reveal4", 0.4, 1.2)
	S:burst(1.8)
	S:worldFlash(col, 0.6)
	S:flash(WHITE, 0.85, 0.35, 40)
	S:ring(30, WHITE, 0.8, 1.6, 5)
	S:ring(30, col, 1.1, 1.2, 3)
	S:phase(0.8, function(k: number, e: number)
		wave(e, 0, 1)
		dim.BackgroundTransparency = lerp(0.5, 0.85, k)
		S.shake = 0.6 * (1 - k)
	end)
	S:outro(col:Lerp(WHITE, 0.6), 0.16, 0.45)
end

--------------------------------------------------------------------------------------------------------
-- OVERCLOCKED: running at 300%, smells like burning
--------------------------------------------------------------------------------------------------------

function Scenes.Overclocked(S: any)
	local a = S.aura
	local col = a.color
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	S:hideHud()
	local cc = S:cc()
	local blur = S:blur()
	local heat = S:edges(col, 0.35, 9)
	setT(heat, 1)
	local dim = S:fill(BLACK, 8, 1)

	-- Gauge: 240 degree dial at the bottom centre.
	local R = sz.Y * 0.24
	local cx, cy = sz.X * 0.5, sz.Y * 0.74
	local dial = S:frame({ Name = "Dial", BackgroundTransparency = 1, ZIndex = 20 })
	local back = S:circle(20, BLACK, 0.56, nil, dial)
	back.Position = UDim2.fromOffset(cx, cy)
	back.BackgroundTransparency = 0.25
	Kit.new("UIStroke", { Color = col, Thickness = 2, Transparency = 0.3, Parent = back })
	local A0, A1 = -120, 120
	local ticks = {}
	for i = 0, 30 do
		local t = i / 30
		local ang = math.rad(lerp(A0, A1, t))
		local major = i % 5 == 0
		local r1 = R * (if major then 0.78 else 0.85)
		local tc = if t < 0.5 then P.Lime:Lerp(P.Amber, t * 2) else P.Amber:Lerp(P.Red, (t - 0.5) * 2)
		local f = S:line(cx + math.sin(ang) * r1, cy - math.cos(ang) * r1, cx + math.sin(ang) * R * 0.95, cy - math.cos(ang) * R * 0.95, if major then 4 else 2, tc, 22, dial)
		f.BackgroundTransparency = 0.6
		ticks[i] = { f = f, t = t }
		if major then
			mono(S, 14, {
				Text = tostring(math.floor(t * 300)),
				TextColor3 = tc,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(cx + math.sin(ang) * R * 0.64, cy - math.cos(ang) * R * 0.64),
				Size = UDim2.fromOffset(50, 18),
				ZIndex = 22,
				Parent = dial,
			})
		end
	end
	local needle = S:line(cx, cy, cx, cy - R * 0.9, 5, WHITE, 24, dial)
	local hub = S:circle(25, col, 0.04, nil, dial)
	hub.Position = UDim2.fromOffset(cx, cy)
	local pctL = S:text({
		Text = "100%",
		FontFace = Kit.Title,
		TextSize = math.floor(34 * S.vs + 0.5),
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(cx, cy + R * 0.18),
		Size = UDim2.fromOffset(300, 40),
		ZIndex = 24,
		Parent = dial,
	})
	local read = mono(S, 17, {
		TextColor3 = col:Lerp(WHITE, 0.3),
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(30, 30),
		Size = UDim2.fromOffset(520, 120),
		LineHeight = 1.2,
		ZIndex = 30,
	})
	local alarm = S:text({
		Text = "!! THERMAL LIMIT EXCEEDED !!",
		FontFace = Kit.Title,
		TextSize = math.floor(30 * S.vs + 0.5),
		TextColor3 = P.Red,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.18),
		Size = UDim2.new(1, 0, 0, 40),
		TextTransparency = 1,
		ZIndex = 32,
	})
	Kit.new("UIStroke", { Thickness = 2, Color = BLACK, Transparency = 0.2, Parent = alarm })
	local sparks = S:particles(26, {
		colors = { col, P.Amber, Color3.fromRGB(255, 240, 160) },
		size = { 3, 7 },
		speed = { 250, 700 },
		angle = { -math.pi * 0.85, -math.pi * 0.15 },
		gravity = 900 * S.vs,
		life = { 0.4, 0.9 },
		aspect = 0.5,
		spin = { -400, 400 },
		from = function()
			return cx + rng:NextNumber(-R, R), sz.Y + 4
		end,
	})

	S:orbitShot({ dur = 4.4, deg = 150, r0 = 12, r1 = 7.5, h0 = 3, h1 = 1.5, fov0 = 55, fov1 = 68, roll = 3, blend = 0.4, ease = inCubic })
	S:sfx("Riser", 0.55, 0.9)
	S:sfx("Equip", 0.4, 0.7)
	local nextArc, lastAlarm = 1.2, -1
	local exclusive = if S.exclusive then "   SECTOR: " .. S.biomeName else ""
	S:phase(3.5, function(k: number, e: number)
		local q = U.inQuart(seg(k, 0, 0.92) ^ 0.8)
		local pct = 100 + 210 * q + math.noise(e * 9, 1.3) * 12 * k
		local t = clamp01(pct / 300)
		local ang = math.rad(lerp(A0, A1, t))
		setLine(needle, cx, cy, cx + math.sin(ang) * R * 0.9, cy - math.cos(ang) * R * 0.9, 5)
		for _, tk in ticks do
			tk.f.BackgroundTransparency = if tk.t <= t then 0 else 0.65
		end
		pctL.Text = math.floor(pct) .. "%"
		pctL.TextColor3 = WHITE:Lerp(P.Red, seg(pct, 200, 300))
		local ghz = 4.2 * pct / 100
		local temp = 45 + 70 * q
		read.Text = string.format("CORE CLOCK  %.2f GHz\nVOLTAGE     %.2f V\nTEMP        %d C\nFAN         %d RPM%s", ghz, 1.2 + 0.8 * q, math.floor(temp), math.floor(1800 + 9000 * q), exclusive)
		dim.BackgroundTransparency = 1 - 0.35 * seg(e, 0, 0.4)
		setT(heat, 1 - (0.15 + 0.6 * q) * (0.8 + 0.2 * math.sin(e * 13)))
		blur.Size = 2 + 6 * q * (0.5 + 0.5 * math.sin(e * 9))
		cc.TintColor = WHITE:Lerp(col, 0.12 + 0.3 * q)
		cc.Contrast = 0.1 + 0.35 * q
		cc.Brightness = 0.05 * q
		S.shake = 0.1 + 0.9 * q
		sparks.rate = 10 + 120 * q
		if pct > 250 then
			alarm.TextTransparency = if U.blink(e, 5) > 0 then 0 else 0.7
			local beat = math.floor(e * 5)
			if beat ~= lastAlarm then
				lastAlarm = beat
				S:sfx("Error", 0.4, 1.2)
			end
		end
		if e >= nextArc then
			nextArc = e + lerp(0.5, 0.12, q)
			local ox = cx + rng:NextNumber(-R, R)
			local arc = S:branches(27, { { ox, cy - R * 0.3, -math.pi / 2 + rng:NextNumber(-1, 1) } }, {
				color = col,
				core = Color3.fromRGB(255, 250, 200),
				steps = 7,
				len = sz.Y / 14 / S.vs,
				jitter = 0.9,
				branch = 0.4,
				thick = 2.5,
			})
			arc.set(1)
			S:sfx("Glitch", 0.25, 1.8)
			S:after(0.09, function()
				arc.holder:Destroy()
			end)
		end
	end)
	-- Redline: needle pinned, everything flashes.
	setLine(needle, cx, cy, cx + math.sin(math.rad(A1)) * R * 0.9, cy - math.cos(math.rad(A1)) * R * 0.9, 5)
	pctL.Text = "300%"
	alarm.Text = "OVERCLOCKED"
	alarm.TextColor3 = col
	alarm.TextTransparency = 0
	Kit.glitch(alarm, 0.4)
	S:sfx("Boom", 0.9, 0.75)
	S:sfx("Whoosh", 0.6, 1.2)
	S:burst(1.9)
	S:worldFlash(col, 0.7)
	S:flash(Color3.fromRGB(255, 230, 160), 0.8, 0.35, 40)
	sparks.emit(60)
	S:phase(0.5, function(k: number)
		S.shake = 1 - k
		S.fovPunch = -10 * bump(k)
		blur.Size = 10 * (1 - k)
	end)
	S:outro(Color3.fromRGB(255, 220, 150), 0.14, 0.45)
end

--------------------------------------------------------------------------------------------------------
-- NEURAL LINK: mind, meet machine
--------------------------------------------------------------------------------------------------------

function Scenes.NeuralLink(S: any)
	local a = S.aura
	local c1, c2 = a.color, a.color2
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	S:hideHud()
	local cc = S:cc()
	local dim = S:fill(Color3.fromRGB(14, 0, 14), 8, 1)
	local vig = S:edges(BLACK, 0.5, 9)
	setT(vig, 1)

	S:frontShot({ dur = 4.6, d0 = 7.5, d1 = 3.6, side0 = 1.2, side1 = -0.6, h0 = 2.2, h1 = 1.7, look = 1.9, fov0 = 50, fov1 = 40, blend = 0.5 })

	-- Neuron web: nodes ordered by distance from the head (grown outwards from it).
	local headP = S:toScreen(S:headPos())
	local nodes: { any } = {}
	for _ = 1, 30 do
		local x, y = rng:NextNumber(0.04, 0.96) * sz.X, rng:NextNumber(0.08, 0.9) * sz.Y
		table.insert(nodes, { x = x, y = y, d = (Vector2.new(x, y) - headP).Magnitude })
	end
	table.sort(nodes, function(p, q)
		return p.d < q.d
	end)
	local maxD = nodes[#nodes].d
	local web = S:frame({ Name = "Web", BackgroundTransparency = 1, ZIndex = 12 })
	local edges: { any } = {}
	for i, n in nodes do
		n.f = S:circle(14, if i % 3 == 0 then c2 else c1, 0.014, nil, web)
		n.f.Position = UDim2.fromOffset(n.x, n.y)
		n.f.BackgroundTransparency = 1
		local best = {}
		for j = 1, i - 1 do
			table.insert(best, { j = j, d = (Vector2.new(n.x, n.y) - Vector2.new(nodes[j].x, nodes[j].y)).Magnitude })
		end
		table.sort(best, function(p, q)
			return p.d < q.d
		end)
		for b = 1, math.min(2, #best) do
			local m = nodes[best[b].j]
			local l = S:line(m.x, m.y, m.x, m.y, 2, if (i + b) % 2 == 0 then c1 else c2, 13, web)
			l.BackgroundTransparency = 0.35
			table.insert(edges, { f = l, a = m, b = n, t = n.d / maxD })
		end
		-- Every early node also links to the head.
		if i <= 5 then
			local l = S:line(headP.X, headP.Y, headP.X, headP.Y, 2, c1, 13, web)
			l.BackgroundTransparency = 0.3
			table.insert(edges, { f = l, head = true, b = n, t = 0 })
		end
	end
	local pulses: { any } = {}
	for i = 1, 16 do
		local p = S:circle(15, WHITE, 0.012, nil, web)
		p.Visible = false
		pulses[i] = { f = p, e = nil, t = 0, sp = rng:NextNumber(1.5, 3) }
	end
	-- Head reticle.
	local ret = S:circle(18, c2, 0.26, 2)
	local retIn = S:circle(18, c1, 0.18, 1)
	local retTag = mono(S, 13, {
		Text = "CORTEX SCAN",
		TextColor3 = c2,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(200, 16),
		ZIndex = 18,
	})
	local scanBar = S:frame({
		BackgroundColor3 = c2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.new(0.3, 0, 0, 2),
		ZIndex = 19,
	})
	-- EEG strip.
	local eegN = 64
	local eeg = {}
	local eegY = sz.Y * 0.9
	for i = 1, eegN do
		local f = S:line(0, eegY, 0, eegY, 2, c1, 20)
		eeg[i] = f
	end
	local eegL = mono(S, 14, {
		TextColor3 = c1,
		Position = UDim2.new(0, 30, 0.9, -40),
		Size = UDim2.fromOffset(400, 18),
		ZIndex = 20,
	})
	local log = mono(S, 16, {
		TextColor3 = c1:Lerp(WHITE, 0.4),
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(30, 30),
		Size = UDim2.fromOffset(560, 100),
		LineHeight = 1.2,
		ZIndex = 30,
	})

	S:sfx("Riser", 0.45, 1)
	S:sfx("Open", 0.4, 0.6)
	S:typeInto(log, "> neural_link --pair --deep\nSYNAPTIC HANDSHAKE ...... OK\nMIND :: MACHINE ......... LINKING", 45, 0.18)
	local function eegDraw(e: number, amp: number, sync: number)
		local prevX, prevY = sz.X * 0.03, eegY
		for i = 1, eegN do
			local x = sz.X * (0.03 + 0.94 * i / eegN)
			local tt = i / eegN * 18 - e * 9
			local chaos = math.noise(tt * 0.9, e * 0.7) * 1.4
			local clean = math.sin(tt * 1.3) * 0.8
			local y = eegY - lerp(chaos, clean, sync) * amp * sz.Y * 0.035
			setLine(eeg[i], prevX, prevY, x, y, 2)
			eeg[i].BackgroundColor3 = c1:Lerp(c2, sync)
			prevX, prevY = x, y
		end
	end
	local lastSync = -1
	S:phase(3.4, function(k: number, e: number)
		dim.BackgroundTransparency = 1 - 0.5 * seg(e, 0, 0.4)
		setT(vig, 1 - 0.75 * seg(e, 0, 0.4))
		local hp, on = S:toScreen(S:headPos())
		if not on then
			hp = Vector2.new(sz.X / 2, sz.Y * 0.4)
		end
		local grow = outCubic(seg(k, 0.05, 0.75))
		for _, n in nodes do
			n.f.BackgroundTransparency = if n.d / maxD <= grow then 0.1 + 0.3 * math.sin(e * 6 + n.x) ^ 2 else 1
		end
		for _, ed in edges do
			local g = clamp01((grow - ed.t) * 6)
			local ax = if ed.head then hp.X else ed.a.x
			local ay = if ed.head then hp.Y else ed.a.y
			setLine(ed.f, ax, ay, ax + (ed.b.x - ax) * g, ay + (ed.b.y - ay) * g, 2)
			ed.f.Visible = g > 0
		end
		for _, p in pulses do
			if not p.e or p.t >= 1 then
				local cand = edges[rng:NextInteger(1, #edges)]
				if clamp01((grow - cand.t) * 6) >= 1 then
					p.e, p.t = cand, 0
				end
			end
			if p.e then
				p.t += p.sp / 60
				local ed = p.e
				local ax = if ed.head then hp.X else ed.a.x
				local ay = if ed.head then hp.Y else ed.a.y
				p.f.Visible = true
				p.f.Position = UDim2.fromOffset(lerp(ax, ed.b.x, clamp01(p.t)), lerp(ay, ed.b.y, clamp01(p.t)))
			end
		end
		ret.Position = UDim2.fromOffset(hp.X, hp.Y)
		retIn.Position = ret.Position
		ret.Rotation = e * 60
		local rs = lerp(0.5, 0.26, outCubic(seg(e, 0, 0.8)))
		ret.Size = UDim2.fromScale(rs, rs)
		retIn.Size = UDim2.fromScale(rs * 0.7, rs * 0.7)
		retTag.Position = UDim2.fromOffset(hp.X + sz.Y * rs * 0.55, hp.Y)
		scanBar.Position = UDim2.fromOffset(hp.X, hp.Y + sz.Y * rs * 0.45 * math.sin(e * 5))
		local sync = seg(k, 0.35, 0.9)
		eegDraw(e, 0.6 + 0.6 * k, sync)
		local sp = math.floor(sync * 100)
		eegL.Text = "EEG  //  SYNC " .. sp .. "%"
		if math.floor(sp / 10) ~= lastSync then
			lastSync = math.floor(sp / 10)
			S:sfx("Tick", 0.3, 0.8 + sync * 0.8)
		end
		cc.TintColor = WHITE:Lerp(c1, 0.18 * k)
		cc.Saturation = -0.3 * k
		S.shake = 0.1 * k
	end)
	-- Link: every neuron flashes, lines converge on the head.
	log.Text = "> neural_link --pair --deep\nSYNAPTIC HANDSHAKE ...... OK\nMIND :: MACHINE ......... LINKED"
	eegL.Text = "EEG  //  SYNC 100%  ::  LINK ESTABLISHED"
	Kit.glitch(eegL, 0.3)
	S:sfx("Boom", 0.7, 1)
	S:sfx("Reveal4", 0.45, 1.1)
	S:burst(1.8, S:headPos())
	S:worldFlash(c1, 0.6)
	for _, n in nodes do
		n.f.BackgroundColor3 = WHITE
		n.f.BackgroundTransparency = 0
	end
	local hp = S:toScreen(S:headPos())
	S:ring(30, c2, 0.7, 1.1, 4, UDim2.fromOffset(hp.X, hp.Y))
	S:phase(0.6, function(k: number)
		local q = inCubic(k)
		for _, n in nodes do
			n.f.Position = UDim2.fromOffset(lerp(n.x, hp.X, q), lerp(n.y, hp.Y, q))
		end
		for _, ed in edges do
			ed.f.BackgroundTransparency = lerp(0.3, 1, k)
		end
		S.fovPunch = -8 * bump(k)
	end)
	S:outro(c1:Lerp(WHITE, 0.55), 0.14, 0.45)
end

--------------------------------------------------------------------------------------------------------
-- SENTINEL: the firewall's last guardian
--------------------------------------------------------------------------------------------------------

function Scenes.Sentinel(S: any)
	local a = S.aura
	local gold, cyan = a.color, a.color2
	local sz = S.gui.AbsoluteSize
	local rng = S.rng
	S:hideHud()
	local cc = S:cc()
	local dim = S:fill(Color3.fromRGB(10, 8, 2), 8, 1)
	local vig = S:edges(BLACK, 0.5, 9)
	setT(vig, 1)
	S:frontShot({ dur = 4.6, d0 = 16, d1 = 9, h0 = 0.2, h1 = 0.4, look = 2.2, fov0 = 60, fov1 = 48, roll0 = 0, roll1 = 0, blend = 0.5 })

	-- Honeycomb of hex plates (outline hexagons made of 6 lines each).
	local hr = sz.Y * 0.095
	local cx, cy = sz.X * 0.5, sz.Y * 0.47
	local hexes = {}
	local offsets = { { 0, 0 } }
	for i = 0, 5 do
		local ang = math.rad(30 + i * 60)
		table.insert(offsets, { math.cos(ang) * hr * 1.78, math.sin(ang) * hr * 1.78 })
	end
	for i, off in offsets do
		local holder = S:frame({ Name = "Hex", BackgroundTransparency = 1, ZIndex = 14 })
		local segs = {}
		for s = 0, 5 do
			local a1, a2 = math.rad(s * 60), math.rad((s + 1) * 60)
			local l = S:line(0, 0, 0, 0, 3, gold, 15, holder)
			table.insert(segs, { f = l, a1 = a1, a2 = a2 })
		end
		local fromAng = rng:NextNumber(0, math.pi * 2)
		hexes[i] = {
			holder = holder,
			segs = segs,
			tx = cx + off[1],
			ty = cy + off[2],
			fx = cx + math.cos(fromAng) * sz.X,
			fy = cy + math.sin(fromAng) * sz.X,
			delay = (i - 1) * 0.11,
			locked = false,
		}
	end
	local function placeHex(h: any, x: number, y: number, r: number, t: number)
		for _, sgm in h.segs do
			setLine(sgm.f, x + math.cos(sgm.a1) * r, y + math.sin(sgm.a1) * r, x + math.cos(sgm.a2) * r, y + math.sin(sgm.a2) * r, 3)
			sgm.f.BackgroundTransparency = t
		end
	end
	-- The eye (inside the centre hex).
	local eyeW, eyeH = hr * 1.5, hr * 0.8
	local eye = Instance.new("CanvasGroup")
	eye.Name = "Eye"
	eye.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
	eye.BorderSizePixel = 0
	eye.AnchorPoint = Vector2.new(0.5, 0.5)
	eye.Position = UDim2.fromOffset(cx, cy)
	eye.Size = UDim2.fromOffset(eyeW, 0)
	eye.ZIndex = 16
	eye.Parent = S.gui
	round(eye)
	Kit.new("UIStroke", { Color = gold, Thickness = 3, Parent = eye })
	local iris = S:frame({
		BackgroundColor3 = cyan,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(eyeH * 0.95, eyeH * 0.95),
		ZIndex = 17,
		Parent = eye,
	})
	round(iris)
	Kit.new("UIStroke", { Color = gold, Thickness = 3, Parent = iris })
	Kit.new("UIGradient", { Color = ColorSequence.new(cyan:Lerp(WHITE, 0.3), cyan:Lerp(BLACK, 0.4)), Rotation = 90, Parent = iris })
	local pupil = S:frame({
		BackgroundColor3 = BLACK,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.42, 0.42),
		ZIndex = 18,
		Parent = iris,
	})
	round(pupil)
	local glint = S:frame({
		BackgroundColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.3, 0.3),
		Size = UDim2.fromScale(0.16, 0.16),
		ZIndex = 19,
		Parent = iris,
	})
	round(glint)
	local scanV = S:frame({
		BackgroundColor3 = cyan,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 2, 1, 0),
		ZIndex = 20,
		Parent = eye,
	})
	local log = mono(S, 17, {
		TextColor3 = gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, cy + hr * 2.9),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 30,
	})
	local idL = mono(S, 14, {
		Text = "SUBJECT: " .. string.upper(player.DisplayName) .. "  //  UID " .. player.UserId,
		TextColor3 = cyan,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, cy - hr * 2.9),
		Size = UDim2.new(1, 0, 0, 20),
		TextTransparency = 1,
		ZIndex = 30,
	})

	S:sfx("Riser", 0.45, 0.8)
	-- 1) Plates fly in and lock.
	S:phase(1.4, function(_: number, e: number)
		dim.BackgroundTransparency = 1 - 0.45 * seg(e, 0, 0.4)
		setT(vig, 1 - 0.7 * seg(e, 0, 0.4))
		for _, h in hexes do
			local t = clamp01((e - h.delay) / 0.45)
			local q = outBack(t)
			placeHex(h, lerp(h.fx, h.tx, q), lerp(h.fy, h.ty, q), hr * lerp(2.5, 1, outCubic(t)), 1 - math.min(1, t * 2))
			if t >= 1 and not h.locked then
				h.locked = true
				S:sfx("Click", 0.45, 0.8 + rng:NextNumber() * 0.3)
			end
		end
		cc.TintColor = WHITE:Lerp(gold, 0.15 * seg(e, 0, 0.6))
	end)
	-- 2) The eye opens and looks around.
	S:sfx("Open", 0.55, 0.6)
	log.Text = "GUARDIAN AWAKENING"
	local looks = { Vector2.new(-0.25, -0.1), Vector2.new(0.28, 0.05), Vector2.new(-0.1, 0.15), Vector2.new(0, 0) }
	S:phase(1.3, function(k: number, e: number)
		eye.Size = UDim2.fromOffset(eyeW, eyeH * outBack(seg(k, 0, 0.35)))
		local li = math.min(#looks, math.floor(seg(k, 0.3, 1) * #looks) + 1)
		local tgt = looks[li]
		local cur = iris.Position
		iris.Position = UDim2.fromScale(lerp(cur.X.Scale, 0.5 + tgt.X, 0.25), lerp(cur.Y.Scale, 0.5 + tgt.Y, 0.25))
		pupil.Size = UDim2.fromScale(0.42 + 0.06 * math.sin(e * 3), 0.42 + 0.06 * math.sin(e * 3))
		for _, h in hexes do
			placeHex(h, h.tx, h.ty, hr * (1 + 0.03 * math.sin(e * 4 + h.tx)), 0.15 + 0.2 * math.sin(e * 3 + h.ty) ^ 2)
		end
	end)
	-- 3) Retina scan.
	S:sfx("Type", 0.5, 0.6)
	idL.TextTransparency = 0
	Kit.glitch(idL, 0.25)
	local lastRing = 0
	S:phase(1.2, function(k: number, e: number)
		scanV.Position = UDim2.fromScale(0.5 + 0.48 * math.sin(e * 6), 0.5)
		log.Text = "BIOMETRIC SCAN  " .. math.floor(k * 100) .. "%"
		if e - lastRing > 0.25 then
			lastRing = e
			S:ring(21, cyan, 0.7, 0.45, 2, UDim2.fromOffset(cx, cy))
			S:sfx("Tick", 0.3, 1.3)
		end
		pupil.Size = UDim2.fromScale(lerp(0.42, 0.25, k), lerp(0.42, 0.25, k))
	end)
	-- 4) Verified.
	scanV.Visible = false
	log.Text = "IDENTITY VERIFIED  //  GUARDIAN PROTOCOL ONLINE"
	log.TextColor3 = WHITE
	Kit.glitch(log, 0.35)
	S:sfx("Reveal4", 0.5, 1)
	S:sfx("Boom", 0.65, 1.1)
	S:burst(1.8)
	S:worldFlash(gold, 0.6)
	S:flash(gold:Lerp(WHITE, 0.5), 0.6, 0.3, 40)
	S:phase(0.6, function(k: number)
		local q = outCubic(k)
		for _, h in hexes do
			placeHex(h, lerp(h.tx, cx + (h.tx - cx) * 3, q), lerp(h.ty, cy + (h.ty - cy) * 3, q), hr * (1 + q), q)
		end
		S.fovPunch = -7 * bump(k)
	end)
	S:outro(gold:Lerp(WHITE, 0.6), 0.14, 0.45)
end

return Scenes
