--!strict
-- Cutscene/Corrupted: themed ~9.5s scenes for every CORRUPTED aura.
--
--   Corruption    a LOAD GAME menu with the player's save; loading stalls, the save corrupts, hex floods in,
--                 CHECKSUM FAILED, the menu cracks and shatters into a red, inverted world
--   KernelPanic   boot log, then total alarm: sweeping red beacons, hazard tape, a real-looking panic trace,
--                 siren; SYSTEM HALTED in dead silence; red detonation
--   EventHorizon  a black hole opens with an accretion disc, the screen is dragged in (debris, streaks, FOV
--                 warp, time dilation clock), the disc swallows everything, Hawking flash
--   NullPointer   NULL dereference, segfault, the world drains to black and white, strobing inverted void
--                 with the player's silhouette, the pointer points at nothing

local Players = game:GetService("Players")

local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local Ctx = require(Client.Ctx)
local U = require(script.Parent.Util)
local Fx = require(script.Parent.Fx)

local P = Kit.P
local WHITE, BLACK = U.WHITE, U.BLACK
local clamp01, lerp, seg = U.clamp01, U.lerp, U.seg
local outCubic, inCubic, inOutCubic, outBack, bump = U.outCubic, U.inCubic, U.inOutCubic, U.outBack, U.bump
local setT = Fx.setT
local player = Players.LocalPlayer

local Scenes = {}

local function mono(S: any, size: number, props: { [string]: any }): TextLabel
	local p: { [string]: any } = { FontFace = Kit.MonoBold, TextSize = math.floor(size * S.vs + 0.5) }
	for k, v in props do
		p[k] = v
	end
	local l = S:text(p)
	Kit.new("UIStroke", { Thickness = 1.5, Color = BLACK, Transparency = 0.4, Parent = l })
	return l
end

local function hexDump(rng: Random, rows: number): string
	local out = {}
	for _ = 1, rows do
		local parts = { "0x" .. U.hex(rng, 8) .. ":" }
		for _ = 1, 12 do
			table.insert(parts, U.hex(rng, 2))
		end
		table.insert(out, table.concat(parts, " "))
	end
	return table.concat(out, "\n")
end

--------------------------------------------------------------------------------------------------------
-- CORRUPTION: the save file is damaged, so are you
--------------------------------------------------------------------------------------------------------

function Scenes.Corruption(S: any)
	local a = S.aura
	local red = a.color
	local rng = S.rng
	S:hideHud()
	local cc = S:cc()
	local gl = S:glitchLayer(40, { red, BLACK, WHITE, Color3.fromRGB(90, 0, 20) })
	S:frontShot({ dur = 5, d0 = 11, d1 = 9, h0 = 2, h1 = 1.6, fov0 = 52, fov1 = 50, blend = 0.5 })

	-- The menu sits on a full-screen page so it can shatter as one piece.
	local page = S:frame({ Name = "Menu", BackgroundColor3 = Color3.fromRGB(5, 6, 10), BackgroundTransparency = 1, ZIndex = 20 })
	local dump = mono(S, 13, {
		Text = hexDump(rng, 48),
		TextColor3 = red,
		TextTransparency = 1,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromScale(0.02, 0),
		Size = UDim2.fromScale(0.96, 2),
		ZIndex = 21,
		Parent = page,
	})
	local title = S:text({
		Text = "LOAD GAME",
		FontFace = Kit.Pixel,
		TextSize = math.floor(34 * S.vs + 0.5),
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.new(1, 0, 0, 44),
		ZIndex = 23,
		Parent = page,
	})
	local rolls = player:GetAttribute("Rolls")
	local hours = rng:NextInteger(3, 199)
	local slots = {}
	local slotText = {
		{ "SLOT 1   " .. string.upper(player.DisplayName), "ROLLS " .. U.commas(tonumber(rolls) or rng:NextInteger(1000, 99999)) .. "   //   PLAYTIME " .. string.format("%03d:%02d:%02d", hours, rng:NextInteger(0, 59), rng:NextInteger(0, 59)) .. "   //   " .. S.biomeName },
		{ "SLOT 2", "- EMPTY -" },
		{ "SLOT 3", "- EMPTY -" },
	}
	for i, t in slotText do
		local panel = Kit.panel(page, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.27 + (i - 1) * 0.17),
			Size = UDim2.fromScale(0.56, 0.14),
			ZIndex = 23,
			BackgroundTransparency = 0.05,
		}, if i == 1 then P.Cyan else P.Line)
		local l1 = mono(S, 20, {
			Text = t[1],
			TextColor3 = WHITE,
			Position = UDim2.new(0, 22, 0.12, 0),
			Size = UDim2.new(1, -44, 0.4, 0),
			ZIndex = 24,
			Parent = panel,
		})
		local l2 = mono(S, 15, {
			Text = t[2],
			TextColor3 = P.Dim,
			Position = UDim2.new(0, 22, 0.55, 0),
			Size = UDim2.new(1, -44, 0.35, 0),
			ZIndex = 24,
			Parent = panel,
		})
		slots[i] = { panel = panel, l1 = l1, l2 = l2, t1 = t[1], t2 = t[2] }
	end
	local arrow = S:text({
		Text = ">",
		FontFace = Kit.Pixel,
		TextSize = math.floor(28 * S.vs + 0.5),
		TextColor3 = P.Cyan,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.2, 0.34),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 24,
		Parent = page,
	})
	local load = mono(S, 17, {
		Text = "",
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 24,
		Parent = page,
	})

	-- 1) Menu fades in, the cursor picks slot 1.
	S:sfx("Open", 0.6, 0.8)
	S:phase(0.5, function(k: number)
		page.BackgroundTransparency = 1 - 0.95 * outCubic(k)
	end)
	S:sfx("Click", 0.6, 1)
	S:phase(0.35, function(_: number, e: number)
		arrow.TextTransparency = if U.blink(e, 6) > 0 then 0 else 0.6
	end)
	S:sfx("Click", 0.7, 1.2)
	slots[1].panel.BackgroundColor3 = Color3.fromRGB(10, 30, 40)
	-- 2) Loading... stalls at 37% and the data rots.
	local lastE = 0
	S:sfx("Riser", 0.4, 0.7)
	S:phase(2.8, function(k: number, e: number)
		local pct = math.min(37, math.floor(e / 0.6 * 37))
		local bar = math.floor(pct / 100 * 30)
		load.Text = "LOADING  [" .. string.rep("#", bar) .. string.rep(".", 30 - bar) .. "]  " .. pct .. "%"
		local rot = seg(k, 0.25, 1) ^ 1.3
		if e - lastE > 1 / 15 then
			lastE = e
			for i, sl in slots do
				local amt = rot * (if i == 1 then 1 else 0.7)
				sl.l1.Text = U.corrupt(rng, sl.t1, amt * 0.6)
				sl.l2.Text = if i == 1 then U.corrupt(rng, sl.t2, amt) else U.corrupt(rng, U.hex(rng, 24), amt)
				sl.l1.TextColor3 = WHITE:Lerp(red, rot)
			end
			title.Text = U.corrupt(rng, "LOAD GAME", rot * 0.4)
			dump.Position = UDim2.new(0.02, 0, -((e * 0.15) % 1), 0)
			if rng:NextNumber() < rot * 0.4 then
				dump.Text = hexDump(rng, 48)
			end
		end
		dump.TextTransparency = 1 - 0.55 * rot
		gl.k = 0.05 + 0.6 * rot ^ 2
		S.shake = 0.4 * rot
		cc.TintColor = WHITE:Lerp(red, 0.3 * rot)
		if rot > 0.2 and rng:NextNumber() < 0.04 + rot * 0.06 then
			S:errorPopup(30, "SAVE FILE DAMAGED (0x" .. U.hex(rng, 4) .. ")", true, "save_01.dat - FATAL")
			S:sfx("Error", 0.4, 0.8 + rot * 0.5)
		end
	end)
	-- 3) CHECKSUM FAILED.
	load.Text = "CHECKSUM FAILED. SAVE DATA LOST."
	load.TextColor3 = red
	Kit.glitch(load, 0.4)
	S:stamp("CORRUPTED", red, UDim2.fromScale(0.5, 0.45), -8, 76, 45)
	S:sfx("Boom", 0.85, 0.55)
	S:sfx("Error", 0.8, 0.6)
	S:phase(0.6, function(k: number)
		gl.k = 0.2
		S.shake = 0.7 * (1 - k)
	end)
	-- 4) Cracks, then the menu shatters.
	for _, ch in S.gui:GetChildren() do
		if ch.Name == "ErrorPopup" or ch.Name == "Stamp" then
			ch.Parent = page
		end
	end
	S:sfx("Glitch", 0.9, 0.5)
	local cr = S:cracks(46, red, 0.5, 0.36)
	S:phase(0.35, function(k: number)
		cr.set(k)
		S.shake = 0.4 * k
	end)
	S:sfx("Boom", 1, 0.8)
	S:sfx("Whoosh", 0.8, 0.8)
	local lb = S:letterbox(50, "// SAVE_01.DAT  ::  INTEGRITY 0%  ::  RESTORE IMPOSSIBLE", U.spaced(S.tier.name) .. "     S I G N A T U R E", red)
	S:shatter(page, 8, 5, 30, cr.cx, cr.cy)
	cr.holder:Destroy()
	S:burst(2.8)
	S:worldFlash(red, 0.8)
	S:lowShot({ dur = 4 })
	-- 5) The world, corrupted: red, inverted ghosts, the name decrypts itself.
	local name = string.upper(a.name)
	local big = S:text({
		Text = "",
		FontFace = Kit.Title,
		TextSize = math.floor(80 * S.vs + 0.5),
		TextColor3 = red,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 100),
		ZIndex = 45,
	})
	Kit.new("UIStroke", { Thickness = 3, Color = BLACK, Transparency = 0.1, Parent = big })
	local ghost = big:Clone()
	ghost.TextColor3 = WHITE
	ghost.TextTransparency = 0.6
	ghost.ZIndex = 44
	ghost.Parent = S.gui
	local inv = S:fill(WHITE, 35, 1)
	local lastT = 0
	S:phase(3.0, function(k: number, e: number)
		lb.k = outCubic(seg(e, 0, 0.4))
		local amt = 1 - seg(k, 0.15, 0.8)
		if e - lastT > 1 / 20 then
			lastT = e
			big.Text = U.corrupt(rng, name, amt)
			ghost.Text = U.corrupt(rng, name, math.min(1, amt + 0.3))
		end
		ghost.Position = UDim2.new(0.5, rng:NextNumber(-10, 10) * (amt + 0.2), 0.5, rng:NextNumber(-4, 4))
		gl.k = 0.15 + 0.5 * amt
		cc.TintColor = WHITE:Lerp(red, 0.45)
		cc.Saturation = -0.5
		cc.Contrast = 0.5
		cc.Brightness = -0.05
		-- Brief inverted frames.
		inv.BackgroundTransparency = if rng:NextNumber() < 0.05 * amt then 0.3 else 1
		if inv.BackgroundTransparency < 1 then
			cc.Brightness = -0.3
		end
		S.shake = 0.5 * (1 - k) ^ 2
	end)
	big.Text = name
	ghost.Text = name
	Kit.glitch(big, 0.5)
	S:sfx("Reveal5", 0.5, 0.8)
	S:sfx("Boom", 0.8, 0.6)
	S:burst(2.2)
	S:phase(0.5, function(k: number)
		big.TextSize = math.floor(lerp(80, 92, outBack(k)) * S.vs + 0.5)
	end)
	S:outro(red, 0.2, 0.55)
end

--------------------------------------------------------------------------------------------------------
-- KERNEL PANIC: only during total system failure
--------------------------------------------------------------------------------------------------------

local PANIC_TRACE = {
	"Kernel panic - not syncing: Attempted to kill init! exitcode=0x0000000b",
	"CPU: 0 PID: 1 Comm: fate Not tainted 6.6.6-glitch #1",
	"Hardware name: GLITCH RNG Reality Engine/MB-0xDEAD, BIOS 4.04",
	"Call Trace:",
	" <TASK>",
	"  dump_stack_lvl+0x48/0x70",
	"  panic+0x118/0x2f0",
	"  do_exit.cold+0x15/0x15",
	"  roll_luck+0x1337/0xdead",
	"  probability_overflow+0xfa/0x120",
	"  sanity_check+0x0/0x0",
	"  entry_SYSCALL_64_after_hwframe+0x6e/0xd8",
	" </TASK>",
	"Kernel Offset: disabled",
	"---[ end Kernel panic - not syncing: Attempted to kill init! ]---",
}

function Scenes.KernelPanic(S: any)
	local a = S.aura
	local red = a.color
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	S:hideHud()
	local cc = S:cc()
	local black = S:fill(BLACK, 10, 1)
	S:orbitShot({ dur = 6, deg = 60, r0 = 13, r1 = 10, h0 = 3, h1 = 2, fov0 = 56, fov1 = 54, blend = 0.5 })

	-- 1) Boot log scrolls happily... then stops.
	local logL = mono(S, 15, {
		Text = "",
		TextColor3 = Color3.fromRGB(200, 205, 215),
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -60, 1, -30),
		RichText = true,
		LineHeight = 1.1,
		ZIndex = 12,
	})
	local services = { "network.target", "luck-daemon.service", "fate-core.service", "biome-scheduler.service", "aura-render.service", "roll-queue.socket", "entropy-pool.service", "probability.mount" }
	local log = {}
	S:sfx("Click", 0.5, 0.7)
	local nextLine = 0
	S:phase(1.1, function(k: number, e: number)
		black.BackgroundTransparency = 1 - 0.85 * outCubic(seg(e, 0, 0.2))
		if e >= nextLine then
			nextLine = e + 0.06
			local svc = services[rng:NextInteger(1, #services)]
			local bad = k > 0.75 and rng:NextNumber() < 0.6
			table.insert(log, (if bad then '[<font color="#FF1F3D">FAILED</font>] ' else '[  <font color="#50FF8C">OK</font>  ] ') .. (if bad then "Failed to start " else "Started ") .. svc)
			if #log > 26 then
				table.remove(log, 1)
			end
			logL.Text = table.concat(log, "\n")
			S:sfx("Type", 0.2, 1.2)
		end
	end)

	-- 2) Panic: alarm beacons, hazard tape, trace, siren.
	S:sfx("Error", 0.9, 0.5)
	S:sfx("Boom", 0.6, 0.5)
	logL.Text = ""
	local beacons = {}
	for i = 1, 2 do
		local holder = S:frame({
			Name = "Beacon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(if i == 1 then 0 else 1, 0, 0, 0),
			Size = UDim2.fromOffset(sz.Magnitude * 2.2, sz.Magnitude * 2.2),
			ZIndex = 14,
		})
		local cone = S:frame({
			BackgroundColor3 = red,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.5, 0, 0.12, 0),
			ZIndex = 14,
			Parent = holder,
		})
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = cone,
		})
		beacons[i] = { holder = holder, cone = cone }
	end
	-- Hazard tape: frames with hard-stop gradients, scrolled sideways inside a clipping band.
	local tapes = {}
	for i = 1, 2 do
		local band = S:frame({
			Name = "Tape",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			AnchorPoint = Vector2.new(0, if i == 1 then 0 else 1),
			Position = UDim2.fromScale(0, if i == 1 then 0 else 1),
			Size = UDim2.new(1, 0, 0, math.floor(34 * S.vs)),
			ZIndex = 30,
		})
		local strip = S:frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 400, 1, 0), ZIndex = 30, Parent = band })
		local n = 8
		for j = 0, n - 1 do
			local seg8 = S:frame({
				BackgroundColor3 = WHITE,
				Position = UDim2.fromScale(j / n, 0),
				Size = UDim2.new(1 / n, 1, 1, 0),
				ZIndex = 30,
				Parent = strip,
			})
			local kp = {}
			for s = 0, 9 do
				local c = if s % 2 == 0 then red else Color3.fromRGB(14, 0, 2)
				table.insert(kp, ColorSequenceKeypoint.new(s / 10, c))
				table.insert(kp, ColorSequenceKeypoint.new(math.min(1, (s + 1) / 10 - 0.0001), c))
			end
			kp[#kp] = ColorSequenceKeypoint.new(1, kp[#kp].Value)
			Kit.new("UIGradient", { Color = ColorSequence.new(kp), Rotation = 0, Parent = seg8 })
		end
		local lbl = mono(S, 15, {
			Text = "  KERNEL PANIC  //  KERNEL PANIC  //  KERNEL PANIC  //  KERNEL PANIC  //  KERNEL PANIC  //  KERNEL PANIC",
			TextColor3 = WHITE,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 31,
			Parent = band,
		})
		tapes[i] = { band = band, strip = strip, lbl = lbl, dir = if i == 1 then 1 else -1 }
	end
	local traceL = mono(S, 15, {
		Text = "",
		TextColor3 = WHITE,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.new(0, 34, 0, math.floor(54 * S.vs)),
		Size = UDim2.new(1, -68, 1, -math.floor(110 * S.vs)),
		LineHeight = 1.15,
		ZIndex = 20,
	})
	local tris = {}
	for i = 1, 6 do
		local t = S:text({
			Text = "/!\\",
			FontFace = Kit.Pixel,
			TextSize = math.floor(rng:NextNumber(28, 54) * S.vs + 0.5),
			TextColor3 = if i % 2 == 0 then red else Color3.fromRGB(255, 200, 40),
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(0.55, 0.92), rng:NextNumber(0.2, 0.8)),
			Size = UDim2.fromOffset(160, 60),
			ZIndex = 22,
		})
		tris[i] = t
	end
	local edge = S:edges(red, 0.35, 13)
	local shown = 0
	local lastSiren = -1
	S:phase(4.3, function(k: number, e: number)
		black.BackgroundTransparency = lerp(0.15, 0.55, seg(e, 0, 0.5))
		-- Alarm cycle.
		local cyc = (e % 0.8) / 0.8
		local pulse = bump(cyc)
		setT(edge, 1 - (0.25 + 0.6 * pulse))
		cc.TintColor = WHITE:Lerp(red, 0.25 + 0.35 * pulse)
		cc.Saturation = -0.4
		cc.Contrast = 0.3 + 0.2 * pulse
		cc.Brightness = -0.1 + 0.08 * pulse
		for i, b in beacons do
			b.holder.Rotation = e * 260 * (if i == 1 then 1 else -1) + (if i == 1 then 0 else 180)
			b.cone.BackgroundTransparency = 0.3 + 0.3 * (1 - pulse)
		end
		for _, t in tapes do
			local off = (e * 220 * t.dir) % 400
			t.strip.Position = UDim2.fromOffset(-off, 0)
			t.lbl.Position = UDim2.fromOffset(-((e * 140 * t.dir) % 300), 0)
		end
		local n = math.min(#PANIC_TRACE, math.floor(e / 0.18) + 1)
		if n ~= shown then
			shown = n
			traceL.Text = table.concat(PANIC_TRACE, "\n", 1, n)
			traceL.TextColor3 = WHITE
			S:sfx("Type", 0.35, 0.8)
		end
		for i, t in tris do
			t.TextTransparency = if ((e * 3 + i * 0.37) % 1) < 0.5 then 0 else 1
		end
		local siren = math.floor(e / 0.4)
		if siren ~= lastSiren then
			lastSiren = siren
			S:sfx("Error", 0.5, if siren % 2 == 0 then 1.25 else 0.85)
		end
		S.shake = 0.3 + 0.5 * k + 0.3 * pulse
	end)

	-- 3) SYSTEM HALTED: everything freezes, then silence.
	S.loops = {}
	S.shake = 0
	S:sfx("Glitch", 0.9, 0.4)
	S:duck(0)
	S:phase(0.35)
	for _, ch in S.gui:GetChildren() do
		if ch ~= S.hint then
			ch:Destroy()
		end
	end
	local dead = S:fill(BLACK, 60, 0)
	local halted = mono(S, 22, {
		Text = "SYSTEM HALTED",
		TextColor3 = red,
		Position = UDim2.fromOffset(40, 40),
		Size = UDim2.fromOffset(600, 30),
		ZIndex = 61,
	})
	cc.TintColor = WHITE
	cc.Contrast = 0
	cc.Saturation = 0
	cc.Brightness = 0
	S:phase(1.1, function(_: number, e: number)
		halted.Text = "SYSTEM HALTED" .. (if U.blink(e, 2.5) > 0 then " _" else "")
	end)
	-- 4) Red detonation.
	halted:Destroy()
	S:sfx("Boom", 1, 0.5)
	S:sfx("Reveal5", 0.55, 0.7)
	S:sfx("Glitch", 0.8, 0.6)
	S:duck(0.6)
	S:burst(3)
	S:worldFlash(red, 1)
	S:flash(red, 0.9, 0.5, 70)
	local gl = S:glitchLayer(50, { red, WHITE, BLACK, Color3.fromRGB(255, 120, 120) })
	S:orbitShot({ dur = 2.6, deg = 140, r0 = 7, r1 = 10, h0 = 1, h1 = 3, fov0 = 75, fov1 = 58, roll = 6, blend = 0, ease = outCubic })
	local lb = S:letterbox(55, "// KERNEL PANIC  ::  NOT SYNCING  ::  SECTOR " .. S.biomeName, U.spaced(S.tier.name) .. "     S I G N A T U R E", red)
	S:phase(2.2, function(k: number, e: number)
		dead.BackgroundTransparency = outCubic(seg(e, 0, 0.25))
		lb.k = outCubic(seg(e, 0.1, 0.5))
		gl.k = 0.9 * (1 - k) + 0.1
		S.shake = 1.2 * (1 - k) ^ 2
		cc.TintColor = WHITE:Lerp(red, 0.4 * (1 - k) + 0.15)
		cc.Contrast = 0.3
		S.fovPunch = 12 * (1 - outCubic(k))
	end)
	S:outro(red, 0.18, 0.55)
end

--------------------------------------------------------------------------------------------------------
-- EVENT HORIZON: nothing escapes, not even light
--------------------------------------------------------------------------------------------------------

function Scenes.EventHorizon(S: any)
	local a = S.aura
	local orange = a.color
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	local cx, cy = sz.X * 0.5, sz.Y * 0.45
	S:hideHud()
	local cc = S:cc()
	local blur = S:blur()
	local vig = S:edges(BLACK, 0.55, 10)
	setT(vig, 1)

	-- Black hole: disc + photon ring + accretion disc particles (back half behind, front half over the disc).
	local hole = S:frame({ Name = "Hole", BackgroundTransparency = 1, ZIndex = 20 })
	local glowF = S:circle(19, orange, 0, nil, hole)
	glowF.Position = UDim2.fromOffset(cx, cy)
	glowF.BackgroundTransparency = 0.75
	local disc = S:circle(21, BLACK, 0, nil, hole)
	disc.Position = UDim2.fromOffset(cx, cy)
	local photon = S:circle(22, orange:Lerp(WHITE, 0.5), 0, 3, hole)
	photon.Position = UDim2.fromOffset(cx, cy)
	local acc = {}
	for i = 1, 90 do
		local d = S:frame({
			BackgroundColor3 = if i % 4 == 0 then WHITE else orange:Lerp(Color3.fromRGB(255, 60, 0), rng:NextNumber()),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(4, 4),
			ZIndex = 20,
			Parent = hole,
		})
		Kit.corner(d, 3)
		acc[i] = { f = d, ang = rng:NextNumber(0, math.pi * 2), r = rng:NextNumber(1.25, 2.6), sp = rng:NextNumber(1.2, 2.4) }
	end
	local R = 0 -- disc radius in px, animated
	local tilt = 0.28
	S:loop(function(_: number, dt: number)
		local rs = R * 2 / sz.Y
		disc.Size = UDim2.fromScale(rs, rs)
		photon.Size = UDim2.fromScale(rs * 1.08, rs * 1.08)
		glowF.Size = UDim2.fromScale(rs * 3.2, rs * 3.2)
		for _, p in acc do
			p.ang += p.sp * dt * (2.6 / p.r)
			local x = cx + math.cos(p.ang) * p.r * R
			local y = cy + math.sin(p.ang) * p.r * R * tilt
			p.f.Position = UDim2.fromOffset(x, y)
			p.f.ZIndex = if math.sin(p.ang) > 0 then 23 else 19
			local s = math.max(2, R * 0.05 * (3 - p.r))
			p.f.Size = UDim2.fromOffset(s * 2.2, s)
			p.f.Rotation = math.deg(p.ang) + 90
		end
		return false
	end)
	local streaks = S:streaks(18, 40, orange)
	streaks.cy = 0.45
	local debris = S:particles(17, {
		colors = { orange, WHITE, Color3.fromRGB(255, 90, 20), P.Dim },
		size = { 3, 10 },
		speed = { 10, 60 },
		life = { 2.5, 4 },
		spin = { -300, 300 },
		pull = function()
			return cx, cy
		end,
		pullStrength = 900,
		swirl = 1400,
		from = function()
			local side = rng:NextInteger(1, 4)
			if side == 1 then
				return rng:NextNumber(0, sz.X), -10
			elseif side == 2 then
				return rng:NextNumber(0, sz.X), sz.Y + 10
			elseif side == 3 then
				return -10, rng:NextNumber(0, sz.Y)
			end
			return sz.X + 10, rng:NextNumber(0, sz.Y)
		end,
	})
	local clock = mono(S, 16, {
		TextColor3 = orange:Lerp(WHITE, 0.3),
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(30, 30),
		Size = UDim2.fromOffset(500, 70),
		LineHeight = 1.2,
		ZIndex = 30,
	})

	-- Camera: rise above the player, then the frame is dragged in (FOV warp + roll).
	local warp, roll = 0, 0
	local lv = S:focusLook()
	S:shot(function(e: number, c: Vector3)
		local k = clamp01(e / 6)
		local h = lerp(4, 26, U.outQuart(k))
		local pos = c - lv * lerp(10, 14, k) + Vector3.new(0, h, 0)
		local look = c + Vector3.new(0, lerp(1.5, 12, k), 0) + lv * lerp(0, 10, k)
		return CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, roll), lerp(60, 112, warp)
	end, 0.6)

	S:sfx("Riser", 0.55, 0.5)
	S:sfx("Glitch", 0.3, 0.4)
	-- 1) The hole opens.
	S:phase(1.5, function(k: number, e: number)
		R = sz.Y * 0.075 * outBack(seg(k, 0.1, 1))
		setT(vig, 1 - 0.5 * k)
		cc.Brightness = -0.15 * k
		cc.Saturation = -0.4 * k
		cc.TintColor = WHITE:Lerp(orange, 0.15 * k)
		debris.rate = 15 * k
		clock.Text = string.format("T+ %09.3f s\nTIME DILATION  x%.2f", e, 1)
	end)
	-- 2) Everything is dragged in.
	S:sfx("Whoosh", 0.7, 0.5)
	S:sfx("Riser", 0.6, 0.8)
	local tt = 1.5
	local lastTick = 0
	S:phase(3.8, function(k: number, e: number)
		local q = inCubic(k)
		R = sz.Y * lerp(0.075, 0.12, q)
		streaks.k = 0.3 + 0.7 * k
		streaks.mode = "in"
		debris.rate = 15 + 90 * k
		warp = 0.75 * q
		roll = math.rad(lerp(0, 35, q) * math.sin(e * 0.7))
		blur.Size = 10 * q
		setT(vig, 1 - (0.5 + 0.45 * q))
		cc.Brightness = -0.15 - 0.15 * q
		cc.Contrast = 0.2 + 0.3 * q
		local dil = 1 + 60 * q * q
		tt += (1 / 60) / dil
		clock.Text = string.format("T+ %09.3f s\nTIME DILATION  x%.2f", tt, dil)
		S.shake = 0.2 + 0.5 * q
		if e - lastTick > lerp(0.35, 0.9, q) then
			lastTick = e
			S:sfx("Tick", 0.35, lerp(1, 0.4, q))
		end
	end)
	-- 3) The disc swallows the screen; total silence.
	S:sfx("Boom", 0.7, 0.35)
	S:phase(1.0, function(k: number)
		R = sz.Y * lerp(0.12, 1.6, U.inExpo(k))
		streaks.k = 1 - k
		debris.rate = 0
		S:duck(1 - k)
		S.shake = 0.6 * (1 - k)
	end)
	local void = S:fill(BLACK, 60, 0)
	clock.Text = string.format("T+ %09.3f s\nTIME DILATION  x INF", tt)
	clock.ZIndex = 61
	S.shake = 0
	warp, roll = 0, 0
	blur.Size = 0
	S:lowShot({ dur = 4, blend = 0 })
	S:phase(0.6)
	clock:Destroy()
	-- 4) Hawking flash: a point, then light escapes after all.
	local pt = S:circle(62, orange:Lerp(WHITE, 0.5), 0)
	S:sfx("Riser", 0.4, 1.8)
	S:phase(0.45, function(k: number)
		local s = 0.004 + 0.02 * inCubic(k)
		pt.Size = UDim2.fromScale(s, s)
	end)
	pt:Destroy()
	S:sfx("Boom", 1, 0.6)
	S:sfx("Reveal5", 0.5, 0.8)
	S:burst(3)
	S:worldFlash(orange, 0.9)
	S:flash(orange:Lerp(WHITE, 0.6), 1, 0.6, 70)
	S:ring(64, WHITE, 1, 2.4, 6)
	S:ring(64, orange, 1.3, 2, 3)
	S:duck(0.7)
	hole:Destroy()
	local cap = mono(S, 20, {
		TextColor3 = orange:Lerp(WHITE, 0.4),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -50),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 66,
	})
	S:typeInto(cap, "NOTHING ESCAPES.  NOT EVEN LIGHT.", 30, 0.2)
	S:phase(1.4, function(k: number)
		void.BackgroundTransparency = outCubic(k)
		cc.Brightness = lerp(0.1, 0, k)
		cc.TintColor = WHITE:Lerp(orange, 0.2)
		cc.Contrast = 0.15
		cc.Saturation = -0.1
		setT(vig, 1 - 0.5 * (1 - k))
	end)
	S:outro(orange:Lerp(WHITE, 0.6), 0.2, 0.55)
end

--------------------------------------------------------------------------------------------------------
-- NULL POINTER: points at nothing, nothing points back
--------------------------------------------------------------------------------------------------------

function Scenes.NullPointer(S: any)
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	S:hideHud()
	local cc = S:cc()
	local dim = S:fill(BLACK, 10, 1)
	S:frontShot({ dur = 3, d0 = 10, d1 = 8, h0 = 1.5, h1 = 1.2, fov0 = 54, fov1 = 50, blend = 0.5 })

	-- 1) The dereference.
	local code = mono(S, 22, {
		TextColor3 = WHITE,
		TextYAlignment = Enum.TextYAlignment.Top,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(math.floor(560 * S.vs), math.floor(160 * S.vs)),
		LineHeight = 1.3,
		ZIndex = 20,
	})
	S:sfx("Type", 0.5, 0.7)
	S:phase(0.3, function(k: number)
		dim.BackgroundTransparency = 1 - 0.75 * k
	end)
	S:typeInto(code, "int *ptr = NULL;\n*ptr = luck;", 22, 0.3, true)
	S:phase(1.15)
	local seg2 = mono(S, 22, {
		Text = "Segmentation fault (core dumped)",
		TextColor3 = P.Red,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, math.floor(50 * S.vs)),
		Size = UDim2.fromOffset(math.floor(560 * S.vs), 30),
		ZIndex = 20,
	})
	Kit.glitch(seg2, 0.4)
	S:sfx("Error", 0.9, 0.5)
	S:sfx("Glitch", 0.7, 0.4)
	S:phase(0.5)
	code:Destroy()
	seg2:Destroy()

	-- 2) Black and white strobe with the silhouette.
	local white = S:fill(WHITE, 20, 1)
	local silB = S:charView({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.fromScale(0.55, 0.8),
		ZIndex = 22,
		Visible = false,
	}, { silhouette = BLACK, ambient = BLACK, light = BLACK, dist = 11 })
	local silW = S:charView({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.fromScale(0.55, 0.8),
		ZIndex = 22,
		Visible = false,
	}, { silhouette = WHITE, ambient = WHITE, light = WHITE, dist = 11 })
	local nullL = S:text({
		Text = "NULL",
		FontFace = Kit.Title,
		TextSize = math.floor(120 * S.vs + 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.18),
		Size = UDim2.new(1, 0, 0, 130),
		ZIndex = 24,
	})
	local pix = {}
	for i = 1, 40 do
		pix[i] = S:frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 23,
			Visible = false,
		})
	end
	S:sfx("Riser", 0.5, 0.6)
	local lastFlip = -1
	-- reduced flashing: the strobe stays under 3 Hz and never goes fully opaque
	local calm = Ctx.Calm()
	S:phase(2.6, function(k: number, e: number)
		cc.Saturation = -1
		cc.Contrast = lerp(0.2, if calm then 0.5 else 1, k)
		dim.BackgroundTransparency = 1
		local rate = if calm then lerp(1, 2.5, k) else lerp(3, 14, k ^ 1.5)
		local flip = math.floor(e * rate)
		local inv = flip % 2 == 1
		local strobe = k > 0.15
		white.BackgroundTransparency = if strobe then (if calm then 0.55 else 0) else 1 - k * 4
		white.BackgroundColor3 = if inv then BLACK else WHITE
		silB.vp.Visible = strobe and not inv
		silW.vp.Visible = strobe and inv
		silB.set(e * 1.5)
		silW.set(e * 1.5)
		nullL.TextColor3 = if inv then WHITE else BLACK
		nullL.TextTransparency = if strobe then 0 else 1
		nullL.Position = UDim2.new(0.5, rng:NextNumber(-6, 6) * k, 0.18, 0)
		if flip ~= lastFlip and strobe then
			lastFlip = flip
			S:sfx("Tick", 0.35, if inv then 0.6 else 1.2)
			for _, p in pix do
				local on = rng:NextNumber() < 0.6 * k
				p.Visible = on
				if on then
					local s = rng:NextNumber(10, 60) * S.vs
					p.Size = UDim2.fromOffset(s, s)
					p.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
					p.BackgroundColor3 = if inv then WHITE else BLACK
				end
			end
		end
		S.shake = 0.3 * k
	end)
	for _, p in pix do
		p.Visible = false
	end
	-- 3) The void: the silhouette shrinks to a single address, then returns inverted.
	S:sfx("Boom", 0.5, 0.4)
	S:duck(0.2)
	S.shake = 0
	white.BackgroundColor3 = WHITE
	silB.vp.Visible = true
	silW.vp.Visible = false
	nullL.Visible = false
	local addr = mono(S, 18, {
		Text = "0x00000000",
		TextColor3 = BLACK,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(300, 24),
		ZIndex = 25,
	})
	local ptrLine = S:line(sz.X * 0.15, sz.Y * 0.2, sz.X * 0.15, sz.Y * 0.2, 3, BLACK, 25)
	local ptrTag = mono(S, 16, {
		Text = "*ptr",
		TextColor3 = BLACK,
		Position = UDim2.new(0.15, -20, 0.2, -30),
		Size = UDim2.fromOffset(120, 22),
		ZIndex = 25,
	})
	S:phase(1.2, function(k: number)
		local s = lerp(1, 0.04, inOutCubic(k))
		silB.vp.Size = UDim2.fromScale(0.55 * s, 0.8 * s)
		local g = outCubic(seg(k, 0.3, 0.8))
		Fx.setLine(ptrLine, sz.X * 0.15, sz.Y * 0.2, lerp(sz.X * 0.15, sz.X * 0.5 - 12, g), lerp(sz.Y * 0.2, sz.Y * 0.5 - 12, g), 3)
	end)
	S:sfx("Glitch", 0.6, 0.5)
	white.BackgroundColor3 = BLACK
	addr.TextColor3 = WHITE
	ptrTag.TextColor3 = WHITE
	ptrTag.Text = "*ptr  ->  nothing"
	ptrLine.BackgroundColor3 = WHITE
	silB.vp.Visible = false
	silW.vp.Visible = true
	S:phase(0.9, function(k: number, e: number)
		local s = lerp(0.04, 1.1, outBack(k))
		silW.vp.Size = UDim2.fromScale(0.55 * s, 0.8 * s)
		silW.set(math.pi + e * 2)
	end)
	-- 4) Back to a black-and-white world.
	S:sfx("Boom", 0.9, 0.6)
	S:sfx("Reveal5", 0.45, 0.6)
	S:burst(2.6)
	S:worldFlash(WHITE, 0.8)
	S:flash(WHITE, 1, 0.5, 60)
	white:Destroy()
	silW.vp:Destroy()
	addr:Destroy()
	ptrLine:Destroy()
	ptrTag:Destroy()
	S:duck(0.7)
	S:lowShot({ dur = 3, blend = 0 })
	local cap = mono(S, 19, {
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -50),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 66,
	})
	S:typeInto(cap, "POINTS AT NOTHING.  NOTHING POINTS BACK.", 32, 0.2)
	local inv = S:fill(WHITE, 30, 1)
	S:phase(1.6, function(k: number)
		cc.Saturation = -1
		cc.Contrast = lerp(1, 0.4, k)
		inv.BackgroundTransparency = if rng:NextNumber() < 0.04 then 0.2 else 1
	end)
	S:outro(BLACK, 0.2, 0.55)
end

return Scenes
