--!strict
-- Cutscene/Mythic: themed ~7.5s scenes for every MYTHIC aura.
--
--   Kernel         ring-0 terminal: privilege escalation lights the protection rings 3 -> 0, prompt turns into
--                  root, CRT switches off, the rings reappear around the player in the world
--   GhostProtocol  classified dossier with the player's photo, DISAVOWED stamp, the file dissolves into
--                  drifting pixels, the world goes pale while trace messages fail
--   CyberSeraph    camera looks up into a brightening sky, a pillar of light slams down onto the player,
--                  six wings of light unfold, a halo forms, feather pixels fall
--   BlueScreen     frozen "Not responding" window trail, full BSOD with counter, reboot spinner, back online

local Players = game:GetService("Players")

local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local U = require(script.Parent.Util)
local Fx = require(script.Parent.Fx)

local P = Kit.P
local WHITE, BLACK = U.WHITE, U.BLACK
local lerp, seg = U.lerp, U.seg
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

-- Classic CRT switch-off: black closes to a white line, the line shrinks to a dot and dies. Blocking.
local function crtOff(S: any, z: number, dur: number)
	local top = S:frame({ BackgroundColor3 = BLACK, Size = UDim2.fromScale(1, 0), ZIndex = z })
	local bot = S:frame({
		BackgroundColor3 = BLACK,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		ZIndex = z,
	})
	local line = S:frame({
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 4),
		ZIndex = z + 1,
	})
	S:phase(dur, function(k: number)
		local c = inCubic(seg(k, 0, 0.45))
		top.Size = UDim2.fromScale(1, 0.5 * c)
		bot.Size = UDim2.fromScale(1, 0.5 * c)
		line.BackgroundTransparency = 1 - seg(k, 0.3, 0.45)
		local w = 1 - outCubic(seg(k, 0.5, 0.85))
		line.Size = UDim2.new(w, 6, 0, 4)
		if k > 0.85 then
			line.BackgroundTransparency = seg(k, 0.85, 1)
		end
	end)
	line:Destroy()
	return top, bot
end

--------------------------------------------------------------------------------------------------------
-- KERNEL: ring zero, absolute control
--------------------------------------------------------------------------------------------------------

function Scenes.Kernel(S: any)
	local a = S.aura
	local mag, cyan = a.color, a.color2
	local sz = S.gui.AbsoluteSize
	S:hideHud()
	local cc = S:cc()
	local black = S:fill(Color3.fromRGB(4, 2, 8), 20, 1)
	S:sfx("Glitch", 0.5, 0.7)
	S:phase(0.25, function(k: number)
		black.BackgroundTransparency = 1 - outCubic(k)
	end)
	local lines = S:scanlines(21, BLACK, 4, 0.75)
	S:orbitShot({ dur = 8, deg = 120, r0 = 12, r1 = 8, h0 = 1.2, h1 = 2.2, fov0 = 58, fov1 = 50, blend = 0 })

	-- Protection rings on the right.
	local rcx, rcy = sz.X * 0.74, sz.Y * 0.5
	local ringNames = { "RING 3  USER", "RING 2  DRIVERS", "RING 1  HYPERVISOR", "RING 0  KERNEL" }
	local rings = {}
	for i = 1, 4 do
		local s = 0.78 - (i - 1) * 0.18
		local r = S:circle(22, P.Line, s, 3)
		r.Position = UDim2.fromOffset(rcx, rcy)
		local tag = mono(S, 13, {
			Text = ringNames[i],
			TextColor3 = P.Dim,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(rcx, rcy - sz.Y * s * 0.5 + 12),
			Size = UDim2.fromOffset(220, 16),
			ZIndex = 23,
		})
		local marks = {}
		for m = 0, 3 do
			local mk = S:frame({
				BackgroundColor3 = P.Line,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(6, 6),
				ZIndex = 23,
			})
			marks[m + 1] = mk
		end
		rings[i] = { f = r, st = r:FindFirstChildOfClass("UIStroke") :: UIStroke, tag = tag, s = s, lit = 0, marks = marks }
	end
	local core = S:circle(24, mag, 0.06)
	core.Position = UDim2.fromOffset(rcx, rcy)
	core.BackgroundTransparency = 1
	S:loop(function(now: number)
		for i, r in ipairs(rings) do
			local spin = now * (0.4 + i * 0.35) * (if i % 2 == 0 then -1 else 1)
			for m, mk in r.marks do
				local ang = spin + (m - 1) * math.pi / 2
				local rr = sz.Y * r.s * 0.5
				mk.Position = UDim2.fromOffset(rcx + math.cos(ang) * rr, rcy + math.sin(ang) * rr)
				mk.BackgroundColor3 = r.st.Color
			end
		end
		return false
	end)
	local function light(i: number)
		local r = rings[i]
		r.st.Color = if i == 4 then mag else cyan
		r.st.Thickness = 6
		r.tag.TextColor3 = WHITE
		Kit.tween(r.st, 0.4, { Thickness = 3 })
		S:ring(23, if i == 4 then mag else cyan, 0.5, r.s * 1.2, 4, UDim2.fromOffset(rcx, rcy))
	end

	-- Terminal on the left.
	local term = S:frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(40, 40),
		Size = UDim2.new(0.5, 0, 1, -80),
		ZIndex = 22,
	})
	local lh = math.floor(26 * S.vs + 0.5)
	local n = 0
	local function say(text: string, color: Color3, cps: number, hold: number)
		n += 1
		local l = mono(S, 19, {
			TextColor3 = color,
			Position = UDim2.fromOffset(0, (n - 1) * lh),
			Size = UDim2.new(1, 0, 0, lh),
			ZIndex = 22,
			Parent = term,
		})
		S:typeInto(l, text, cps, 0.22)
		S:phase((utf8.len(text) or #text) / cps + hold)
		return l
	end
	S:sfx("Type", 0.5, 0.6)
	say("kernel@fate:~$ whoami", P.Text, 50, 0.05)
	say("user", P.Dim, 60, 0.1)
	light(1)
	S:sfx("Click", 0.5, 0.8)
	for i, nm in { "ring2", "ring1", "ring0" } do
		say("kernel@fate:~$ ./escalate --target " .. nm, P.Text, 85, 0.02)
		local lab = ({ "device drivers", "hypervisor", "KERNEL" })[i]
		local l = say("[+] " .. nm .. " :: " .. lab .. " ....... PWNED", if i == 3 then mag else cyan, 110, 0.1)
		Kit.glitch(l, 0.25)
		light(i + 1)
		S:sfx("Boom", 0.35 + i * 0.12, 1.3 - i * 0.15)
		S:sfx("Glitch", 0.3, 1.2)
		S.shake = 0.4 + i * 0.15
		S:after(0.15, function()
			S.shake = 0
		end)
		cc.TintColor = WHITE:Lerp(mag, 0.08 * i)
	end
	core.BackgroundTransparency = 0
	S:ring(24, WHITE, 0.6, 0.4, 3, UDim2.fromOffset(rcx, rcy))
	say("kernel@fate:~# whoami", mag, 55, 0.02)
	local root = say("root", WHITE, 30, 0.2)
	root.TextSize = math.floor(34 * S.vs + 0.5)
	S:sfx("Reveal4", 0.45, 1)
	local big = S:text({
		Text = "ABSOLUTE CONTROL",
		FontFace = Kit.Title,
		TextSize = math.floor(44 * S.vs + 0.5),
		TextColor3 = mag,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 40, 1, -110),
		Size = UDim2.new(0.6, 0, 0, 60),
		ZIndex = 24,
	})
	Kit.glitch(big, 0.5)
	S:phase(0.55, function(k: number)
		core.Size = UDim2.fromScale(0.06 + 0.04 * bump(k), 0.06 + 0.04 * bump(k))
	end)

	-- CRT off, then the rings around the player in the world.
	S:sfx("Whoosh", 0.5, 0.6)
	local top, bot = crtOff(S, 60, 0.45)
	term:Destroy()
	big:Destroy()
	lines:Destroy()
	black.BackgroundTransparency = 1
	for _, r in rings do
		r.tag.Visible = false
	end
	S:sfx("Boom", 0.8, 0.7)
	S:burst(2.2)
	S:worldFlash(mag, 0.7)
	local lb = S:letterbox(40, "// RING 0  ::  ROOT ACCESS GRANTED  ::  SECTOR " .. S.biomeName, U.spaced(S.tier.name) .. "     S I G N A T U R E", mag)
	S:phase(1.6, function(k: number, e: number)
		top.Size = UDim2.fromScale(1, 0.5 * (1 - outCubic(seg(e, 0, 0.35))))
		bot.Size = top.Size
		lb.k = outCubic(seg(e, 0.1, 0.5))
		local hp, on = S:toScreen(S:focusPos() + Vector3.new(0, 0.6, 0))
		local cxp = if on then hp.X else sz.X / 2
		local cyp = if on then hp.Y else sz.Y / 2
		rcx, rcy = cxp, cyp
		for i, r in rings do
			r.f.Position = UDim2.fromOffset(cxp, cyp)
			local s = r.s * lerp(1.3, 0.9, outCubic(k))
			r.f.Size = UDim2.fromScale(s, s * 0.35)
			r.f.SizeConstraint = Enum.SizeConstraint.RelativeYY
			r.st.Transparency = 0.1 + 0.2 * math.sin(e * 4 + i) ^ 2
		end
		core.Position = UDim2.fromOffset(cxp, cyp)
		cc.TintColor = WHITE:Lerp(mag, 0.2)
		cc.Contrast = 0.2
		S.fovPunch = -5 * bump(seg(e, 0, 0.6))
	end)
	S:outro(mag:Lerp(WHITE, 0.6), 0.16, 0.5)
end

--------------------------------------------------------------------------------------------------------
-- GHOST PROTOCOL: disavowed, invisible, everywhere
--------------------------------------------------------------------------------------------------------

function Scenes.GhostProtocol(S: any)
	local a = S.aura
	local pale, steel = a.color, a.color2
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	S:hideHud()
	local cc = S:cc()
	local dim = S:fill(Color3.fromRGB(6, 8, 12), 8, 1)
	S:frontShot({ dur = 4, d0 = 14, d1 = 11, h0 = 3, h1 = 2, fov0 = 50, fov1 = 46, blend = 0.6 })

	-- The dossier lives on a full-screen page so it can be shattered later.
	local page = S:frame({ Name = "Page", BackgroundTransparency = 1, ZIndex = 20 })
	local W, H = math.floor(sz.Y * 0.95), math.floor(sz.Y * 0.62)
	local doc = Kit.panel(page, {
		Name = "Dossier",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.6),
		Size = UDim2.fromOffset(W, H),
		Rotation = -3,
		BackgroundTransparency = 0.02,
		ZIndex = 20,
	}, steel:Lerp(WHITE, 0.3))
	local header = S:frame({
		BackgroundColor3 = steel,
		BackgroundTransparency = 0.35,
		Size = UDim2.new(1, 0, 0, math.floor(40 * S.vs)),
		ZIndex = 21,
		Parent = doc,
	})
	mono(S, 16, {
		Text = "//  CLASSIFIED  ::  EYES ONLY  ::  FILE " .. U.hex(rng, 6) .. "  //",
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 22,
		Parent = header,
	})
	local photoBox = S:frame({
		BackgroundColor3 = Color3.fromRGB(20, 24, 30),
		Position = UDim2.new(0, 20, 0, math.floor(56 * S.vs)),
		Size = UDim2.new(0.34, 0, 1, -math.floor(76 * S.vs)),
		ZIndex = 21,
		Parent = doc,
	})
	Kit.new("UIStroke", { Color = steel, Thickness = 2, Parent = photoBox })
	local photo = S:charView({
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = Color3.fromRGB(215, 225, 240),
		ZIndex = 22,
		Parent = photoBox,
	}, { dist = 7.5, height = 1.6, lookY = 1.2, fov = 30, ambient = Color3.fromRGB(170, 175, 185), light = Color3.fromRGB(200, 205, 215) })
	S:scanlines(23, BLACK, 3, 0.8, photoBox)
	local fields = {
		{ "AGENT", string.upper(player.DisplayName) },
		{ "CODENAME", "GHOST" },
		{ "CLEARANCE", "OMEGA-BLACK" },
		{ "LAST SEEN", "[ NO DATA ]" },
		{ "STATUS", "ACTIVE" },
	}
	local vals: { TextLabel } = {}
	local fy = math.floor(64 * S.vs)
	local fh = math.floor(34 * S.vs)
	for i, f in fields do
		mono(S, 15, {
			Text = f[1],
			TextColor3 = P.Dim,
			Position = UDim2.new(0.39, 0, 0, fy + (i - 1) * fh),
			Size = UDim2.new(0.2, 0, 0, fh),
			ZIndex = 22,
			Parent = doc,
		})
		vals[i] = mono(S, 18, {
			Text = f[2],
			TextColor3 = WHITE,
			Position = UDim2.new(0.6, 0, 0, fy + (i - 1) * fh),
			Size = UDim2.new(0.38, 0, 0, fh),
			MaxVisibleGraphemes = 0,
			ZIndex = 22,
			Parent = doc,
		})
	end

	S:sfx("Whoosh", 0.5, 0.8)
	S:sfx("Open", 0.5, 0.7)
	-- 1) File slides in, fields type out.
	S:phase(0.6, function(k: number)
		doc.Position = UDim2.fromScale(0.5, lerp(1.6, 0.5, outBack(k)))
		dim.BackgroundTransparency = 1 - 0.55 * k
		cc.Saturation = -0.6 * k
	end)
	for i = 1, #fields do
		S:typeInto(vals[i], fields[i][2], 40, 0.2)
		S:phase(0.28, function(_: number, e: number)
			photo.set(math.sin(e * 2) * 0.3, 7.5, 1.6, 1.2)
		end)
	end
	S:phase(0.35)
	-- 2) DISAVOWED.
	vals[5].Text = "DISAVOWED"
	vals[5].MaxVisibleGraphemes = -1
	vals[5].TextColor3 = P.Red
	S:stamp("DISAVOWED", P.Red, UDim2.fromScale(0.62, 0.62), -14, 56, 26, doc)
	S:sfx("Boom", 0.7, 0.6)
	S:sfx("Click", 0.7, 0.5)
	S.shake = 0.6
	S:phase(0.9, function(k: number)
		S.shake = 0.6 * (1 - k) ^ 2
		doc.Rotation = -3 + 1.5 * bump(seg(k, 0, 0.2))
	end)
	-- 3) The file dissolves into drifting pixels.
	S:sfx("Glitch", 0.6, 0.6)
	S:sfx("Whoosh", 0.5, 1.4)
	local wisps = S:particles(15, {
		colors = { pale, WHITE, steel:Lerp(WHITE, 0.5) },
		size = { 3, 9 },
		speed = { 20, 70 },
		angle = { -math.pi * 0.65, -math.pi * 0.35 },
		life = { 1.2, 2.2 },
		alpha = 0.3,
		from = function()
			return rng:NextNumber(0, sz.X), rng:NextNumber(sz.Y * 0.3, sz.Y * 1.05)
		end,
	})
	S:shatter(page, 12, 7, 20, 0.5, 0.5, -0.25)
	S:lowShot({ dur = 3.6, d0 = 9, d1 = 6.5, a0 = 150, a1 = 200, h = -1, roll0 = 4, roll1 = 0, fov0 = 60, fov1 = 50, blend = 0.8 })
	-- 4) Pale world, trace attempts fail everywhere.
	local msgs = { "SIGNAL LOST", "TRACE FAILED", "NO RECORD FOUND", "SUBJECT NOT FOUND", "404 :: AGENT", "FACE MATCH 0.0%" }
	local nextMsg = 0
	S:phase(2.8, function(k: number, e: number)
		dim.BackgroundTransparency = lerp(0.45, 0.85, seg(e, 0, 0.5))
		wisps.rate = 40 + 40 * k
		cc.Saturation = lerp(-0.6, -0.85, k)
		cc.Brightness = 0.12 * k
		cc.Contrast = -0.1 * k
		cc.TintColor = WHITE:Lerp(pale, 0.3)
		if e >= nextMsg then
			nextMsg = e + 0.22
			local l = mono(S, rng:NextInteger(13, 20), {
				Text = msgs[rng:NextInteger(1, #msgs)],
				TextColor3 = if rng:NextNumber() < 0.3 then P.Red else pale,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(rng:NextNumber(0.12, 0.88), rng:NextNumber(0.12, 0.88)),
				Size = UDim2.fromOffset(300, 24),
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 30,
			})
			S:sfx("Error", 0.18, 1.5 + rng:NextNumber() * 0.3)
			local t0 = os.clock()
			S:loop(function(now: number)
				local t = now - t0
				l.TextTransparency = if t < 0.5 then (if rng:NextNumber() < 0.25 then 0.7 else 0.1) else seg(t, 0.5, 0.9)
				if t > 0.9 then
					l:Destroy()
					return true
				end
				return false
			end)
		end
	end)
	S:burst(2)
	S:sfx("Reveal4", 0.45, 0.9)
	S:sfx("Boom", 0.5, 0.7)
	S:outro(WHITE, 0.25, 0.55)
end

--------------------------------------------------------------------------------------------------------
-- CYBER SERAPH: an angel compiled from light
--------------------------------------------------------------------------------------------------------

function Scenes.CyberSeraph(S: any)
	local a = S.aura
	local cyan = a.color2
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	S:hideHud()
	local cc = S:cc()
	local rays = S:sunRays()
	local bloom = S:bloom()
	local glow = S:edges(WHITE, 0.4, 9)
	setT(glow, 1)

	-- Feather pixels drift down from the sky the whole time.
	local feathers = S:particles(14, {
		colors = { WHITE, cyan, cyan:Lerp(WHITE, 0.5) },
		size = { 3, 8 },
		speed = { 40, 110 },
		angle = { math.pi * 0.4, math.pi * 0.6 },
		life = { 2, 3.4 },
		spin = { -90, 90 },
		alpha = 0.1,
		from = function()
			return rng:NextNumber(-0.05, 1.05) * sz.X, -10
		end,
	})

	-- 1) Look up into the sky as it brightens.
	S:lookUpShot({ dur = 2.2, pitch0 = 12, pitch1 = 78, d = 6, h = 1, fov0 = 60, fov1 = 75, spin = 25, blend = 0.6 })
	S:sfx("Riser", 0.55, 0.7)
	S:sfx("Announce", 0.35, 0.6)
	S:phase(2.1, function(k: number)
		local q = inOutCubic(k)
		feathers.rate = 20 + 40 * q
		cc.Brightness = 0.2 * q
		cc.Contrast = 0.1 * q
		cc.TintColor = WHITE:Lerp(cyan, 0.12 * q)
		rays.Intensity = 0.25 * q
		bloom.Intensity = 1.2 * q
		setT(glow, 1 - 0.5 * q)
	end)

	-- 2) A pillar of light slams down onto the player.
	local c0 = S:focusPos()
	local beam = S:part({
		Name = "SeraphBeam",
		Shape = Enum.PartType.Cylinder,
		Color = WHITE,
		Transparency = 0.15,
		Size = Vector3.new(800, 0.1, 0.1),
		CFrame = CFrame.new(c0 + Vector3.new(0, 400, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local halo3d = S:part({
		Name = "SeraphGlow",
		Shape = Enum.PartType.Cylinder,
		Color = cyan,
		Transparency = 0.7,
		Size = Vector3.new(800, 0.1, 0.1),
		CFrame = beam.CFrame,
	})
	Kit.new("PointLight", { Color = WHITE, Brightness = 6, Range = 40, Parent = beam })
	S:frontShot({ dur = 4.6, d0 = 20, d1 = 15, h0 = 0, h1 = 0.4, look = 3.2, fov0 = 70, fov1 = 62, blend = 0 })
	S:sfx("Boom", 0.95, 0.7)
	S:sfx("Whoosh", 0.7, 0.7)
	S:flash(WHITE, 0.95, 0.5, 40)
	S:burst(2.4)
	S:worldFlash(WHITE, 0.8)
	S:phase(0.9, function(k: number)
		local r = lerp(14, 5, outCubic(k))
		local c = S:focusPos()
		beam.Size = Vector3.new(800, r * 0.5, r * 0.5)
		halo3d.Size = Vector3.new(800, r * 1.6, r * 1.6)
		beam.CFrame = CFrame.new(c + Vector3.new(0, 400, 0)) * CFrame.Angles(0, 0, math.rad(90))
		halo3d.CFrame = beam.CFrame
		S.shake = 0.9 * (1 - k)
	end)

	-- 3) Six wings of light unfold from the back; a halo forms above the head.
	local wings = S:frame({ Name = "Wings", BackgroundTransparency = 1, ZIndex = 12 })
	local feathersUI = {}
	local pairsSpec = { { base = 38, spread = 40, len = 1.0 }, { base = 6, spread = 30, len = 1.15 }, { base = -26, spread = 26, len = 0.8 } }
	for w, spec in pairsSpec do
		for side = -1, 1, 2 do
			for f = 1, 8 do
				local fr = S:frame({
					BackgroundColor3 = WHITE:Lerp(cyan, (f - 1) / 9 + (w - 1) * 0.15),
					BackgroundTransparency = 0.15,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(0, 8),
					ZIndex = 12 + w,
					Parent = wings,
				})
				Kit.corner(fr, 4)
				Kit.new("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.5),
						NumberSequenceKeypoint.new(0.3, 0),
						NumberSequenceKeypoint.new(1, 0.9),
					}),
					Parent = fr,
				})
				table.insert(feathersUI, { f = fr, side = side, idx = f, spec = spec, w = w })
			end
		end
	end
	local halo = S:frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 16 })
	Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = halo })
	local haloSt = Kit.new("UIStroke", { Color = cyan:Lerp(WHITE, 0.4), Thickness = 4, Transparency = 1, Parent = halo })
	local cap = mono(S, 18, {
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 30,
	})
	S:sfx("Reveal4", 0.5, 0.8)
	S:sfx("Riser", 0.4, 1.3)
	S:typeInto(cap, "AN ANGEL COMPILED FROM LIGHT", 22, 0.2)
	local function place(unfold: number, flap: number, e: number)
		local ch = player.Character
		local torso = ch and ch:FindFirstChild("Torso")
		local c = if torso and torso:IsA("BasePart") then torso.Position else S:focusPos()
		local back, on = S:toScreen(c + Vector3.new(0, 0.6, 0))
		local headP = S:toScreen(S:headPos() + Vector3.new(0, 1.3, 0))
		local feet = S:toScreen(c - Vector3.new(0, 3, 0))
		local scale = math.clamp((feet - headP).Magnitude, 40, sz.Y)
		wings.Visible = on
		for _, it in feathersUI do
			local sp = it.spec
			local t = (it.idx - 1) / 7
			-- Elevation above the horizon in degrees; folded wings point straight up behind the back.
			local elev = sp.base + sp.spread * (t - 0.5)
			elev = elev * unfold + (1 - unfold) * 70 - flap * (14 - it.w * 3)
			elev += math.sin(e * 2 + it.idx) * 1.5
			local deg = if it.side < 0 then 180 + elev else -elev
			local len = scale * sp.len * (0.55 + 0.45 * math.sin(t * math.pi)) * math.max(0.05, unfold)
			-- Rotation pivots at the centre: put the centre half a feather out so the root sits on the back.
			local rad = math.rad(deg)
			it.f.Size = UDim2.fromOffset(len, math.max(3, scale * 0.035))
			it.f.Rotation = deg
			it.f.Position = UDim2.fromOffset(back.X + math.cos(rad) * len * 0.5, back.Y + math.sin(rad) * len * 0.5)
		end
		halo.Position = UDim2.fromOffset(headP.X, headP.Y)
		halo.Size = UDim2.fromOffset(scale * 0.32, scale * 0.08)
	end
	S:phase(2.8, function(k: number, e: number)
		local u = outBack(seg(k, 0, 0.45))
		place(u, 0, e)
		haloSt.Transparency = 1 - seg(k, 0.3, 0.6)
		local c = S:focusPos()
		local r = lerp(5, 2.5, k)
		beam.Size = Vector3.new(800, r * 0.5, r * 0.5)
		halo3d.Size = Vector3.new(800, r * 1.6, r * 1.6)
		beam.CFrame = CFrame.new(c + Vector3.new(0, 400, 0)) * CFrame.Angles(0, 0, math.rad(90))
		halo3d.CFrame = beam.CFrame
		beam.Transparency = lerp(0.15, 0.5, k)
		feathers.rate = 60
		rays.Intensity = 0.25 + 0.1 * math.sin(e * 3)
	end)
	-- 4) One mighty flap, then light.
	S:sfx("Whoosh", 0.8, 0.6)
	S:phase(0.6, function(k: number, e: number)
		place(1, bump(k), e + 2.2)
		S.fovPunch = -6 * bump(k)
		feathers.emit(3)
	end)
	S:sfx("Boom", 0.7, 1)
	S:burst(2.4)
	S:outro(WHITE, 0.2, 0.55)
end

--------------------------------------------------------------------------------------------------------
-- BLUE SCREEN: your PC ran into a problem
--------------------------------------------------------------------------------------------------------

function Scenes.BlueScreen(S: any)
	local a = S.aura
	local blue = a.color
	S:hideHud()
	local cc = S:cc()
	local gl = S:glitchLayer(50, { blue, WHITE, P.Cyan, BLACK })
	S:frontShot({ dur = 2.4, d0 = 10, d1 = 9, h0 = 1.5, h1 = 1.4, fov0 = 54, fov1 = 52, blend = 0.4 })

	-- 1) A frozen "Not responding" window leaves a trail as it is dragged around.
	S:sfx("Error", 0.6, 1)
	local pops: { Frame } = {}
	local spinner = S:circle(55, blue, 0.07, 6)
	spinner.Position = UDim2.fromScale(0.5, 0.5)
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.9),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = spinner:FindFirstChildOfClass("UIStroke"),
	})
	local nextPop = 0
	local lastErr = 0
	S:phase(2.1, function(k: number, e: number)
		spinner.Rotation = e * 400
		if e >= nextPop then
			nextPop = e + lerp(0.07, 0.03, k)
			local t = e * 1.6
			local pos = UDim2.fromScale(0.5 + 0.32 * math.sin(t * 1.3), 0.5 + 0.28 * math.sin(t * 2.1 + 0.6))
			table.insert(pops, S:errorPopup(30 + #pops % 20, "FATE.EXE is not responding.", false, "FATE.EXE (Not Responding)", pos))
		end
		if e - lastErr > lerp(0.35, 0.12, k) then
			lastErr = e
			S:sfx("Error", 0.3, 0.9 + k * 0.4)
		end
		cc.Saturation = -0.5 * k
		gl.k = 0.05 + 0.2 * k ^ 2
	end)
	-- 2) Freeze.
	S:sfx("Glitch", 0.8, 0.5)
	S:phase(0.25, function()
		gl.k = 1
	end)
	for _, p in pops do
		p:Destroy()
	end
	spinner:Destroy()
	gl.k = 0

	-- 3) BSOD.
	local crash = S:crashScreen(false, 60)
	gl.holder.ZIndex = 62
	S:sfx("Error", 0.9, 0.6)
	S:sfx("Boom", 0.5, 0.5)
	S:lowShot({ dur = 5 })
	local lastStep = -1
	S:phase(2.6, function(k: number, e: number)
		gl.k = if e < 0.15 then 1 - e / 0.15 else 0.02
		local q = seg(k, 0.05, 0.9)
		local pct = math.floor((q ^ 1.6) * 100)
		if q > 0.5 and q < 0.62 then
			pct = math.floor((0.5 ^ 1.6) * 100)
		end
		crash.update(os.clock(), e, math.clamp(pct, 0, 100))
		if math.floor(pct / 5) ~= lastStep then
			lastStep = math.floor(pct / 5)
			S:sfx("Tick", 0.3, 0.8 + pct / 100 * 0.8)
		end
	end)
	crash.update(os.clock(), 2.6, 100)

	-- 4) Reboot: black, logo, spinner dots.
	local black = S:fill(BLACK, 70, 0)
	crash.root:Destroy()
	local logo = S:text({
		Text = "GLITCH OS",
		FontFace = Kit.Title,
		TextSize = math.floor(48 * S.vs + 0.5),
		TextColor3 = blue:Lerp(WHITE, 0.3),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(1, 0, 0, 60),
		TextTransparency = 1,
		ZIndex = 71,
	})
	local status = S:text({
		Text = "Restarting reality",
		FontFace = Kit.Mono,
		TextSize = math.floor(18 * S.vs + 0.5),
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.new(1, 0, 0, 24),
		TextTransparency = 1,
		ZIndex = 71,
	})
	local dots: { Frame } = {}
	for i = 1, 5 do
		local d = S:frame({
			BackgroundColor3 = WHITE,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(math.floor(7 * S.vs), math.floor(7 * S.vs)),
			ZIndex = 71,
		})
		Kit.corner(d, 4)
		dots[i] = d
	end
	S:sfx("Click", 0.5, 0.5)
	local sz = S.gui.AbsoluteSize
	S:phase(1.4, function(_: number, e: number)
		logo.TextTransparency = 1 - seg(e, 0.1, 0.4)
		status.TextTransparency = 1 - seg(e, 0.3, 0.5)
		status.Text = "Restarting reality" .. string.rep(".", math.floor(e * 4) % 4)
		for i, d in dots do
			local t = (e * 0.9 - i * 0.09) % 1
			local ang = math.pi * 2 * (inOutCubic(t)) - math.pi / 2
			local r = sz.Y * 0.035
			d.Position = UDim2.fromOffset(sz.X * 0.5 + math.cos(ang) * r, sz.Y * 0.55 + math.sin(ang) * r)
			d.BackgroundTransparency = if t > 0.95 then 1 else 0
		end
	end)
	S:sfx("Reveal4", 0.5, 1)
	S:sfx("Boom", 0.6, 0.9)
	S:burst(2.2)
	S:worldFlash(blue, 0.7)
	logo:Destroy()
	status:Destroy()
	for _, d in dots do
		d:Destroy()
	end
	local toast = S:text({
		Text = "Aura installed successfully.  " .. string.upper(a.name) .. " is ready to use.",
		FontFace = Kit.MonoBold,
		TextSize = math.floor(18 * S.vs + 0.5),
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -50),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 72,
	})
	Kit.new("UIStroke", { Thickness = 2, Color = blue, Transparency = 0.2, Parent = toast })
	S:phase(1.0, function(k: number)
		black.BackgroundTransparency = outCubic(k)
		cc.Saturation = lerp(-0.5, 0.1, k)
		cc.TintColor = WHITE:Lerp(blue, 0.15)
	end)
	S:ring(40, blue, 0.8, 1.4, 4)
	S:outro(blue:Lerp(WHITE, 0.6), 0.16, 0.5)
end

return Scenes
