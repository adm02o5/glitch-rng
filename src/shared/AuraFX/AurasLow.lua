--!strict
-- AuraFX/AurasLow: BASIC and ENHANCED tier auras.
-- Basic: ~2.5-3.5 stud radius, subtle but clearly visible from the gameplay camera.
-- Enhanced: ~3-5 stud radius, a silhouette-breaking element + particles + root light.

local Workspace = game:GetService("Workspace")

local Core = require(script.Parent.Core)
local B = require(script.Parent.Blocks)

type Ctx = Core.Ctx

local T, F = Core.TEX, Core.FONT
local V, V2, CF, ANG = Vector3.new, Vector2.new, CFrame.new, CFrame.Angles
local ns, nr, cs = Core.ns, Core.nr, Core.cs
local TAU = Core.TAU
local WHITE = Color3.new(1, 1, 1)
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local NEON = Enum.Material.Neon
local FF = Enum.Material.ForceField
local SMOOTH = Enum.Material.SmoothPlastic
local FLAT = ANG(0, 0, math.pi / 2) -- cylinder axis X -> vertical (disc lying flat)
local BOX = Enum.ParticleEmitterShape.Box
local VOLUME = Enum.ParticleEmitterShapeStyle.Volume

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

-- Coloured PointLight on the HumanoidRootPart (tints the character and the floor).
local function rootLight(c: Ctx, color: Color3, bright: number, range: number, y: number?): PointLight
	return Core.light(Core.att(c, c.root, CF(0, y or 0, 0)), color, bright, range)
end

-- Soft glow sprite locked to the torso, drawn behind the body: the "aura haze".
local function bodyGlow(c: Ctx, color: Color3, size: number, tr: number, rate: number?): ParticleEmitter
	return Core.emit(Core.att(c, c.torso), {
		tex = T.glow,
		color = cs(color),
		size = ns(size * 0.8, size),
		transp = ns(1, tr, 1),
		rate = rate or 3,
		life = nr(1.2, 1.6),
		rotSpeed = nr(-25, 25),
		bright = 1,
		locked = true,
		zoff = -1.5,
	})
end

local function snap(x: number, q: number): number
	return math.floor(x / q + 0.5) * q
end

local A: { [string]: (Ctx) -> () } = {}

---------------------------------------------------------------- BASIC

-- few slow white square pixels drifting up
-- 26 parts / 2 emitters
A.Pixel = function(c: Ctx)
	local g = c.groundY
	local span = c.topY - g + 2.4
	local px: { BasePart } = {}
	local N = 12
	for i = 1, N do
		px[i] = Core.part(c, V(0.34, 0.34, 0.34), if i % 3 == 0 then c.c2:Lerp(c.c1, 0.45) else c.c1)
	end
	-- slowly turning square "selection frame" on the floor
	local frame: { BasePart } = {}
	local corners: { BasePart } = {}
	for k = 1, 4 do
		frame[k] = Core.part(c, V(0.1, 0.05, 3.7), c.c1, NEON, 0.4)
		corners[k] = Core.part(c, V(0.34, 0.12, 0.34), WHITE)
	end
	B.circle(c, { radius = 3, color = c.c2, width = 0.1, at = CF(0, g + 0.04, 0), tr = 0.55, n = 8 })
	-- tiny pixel halo stepping around above the head
	local halo: { BasePart } = {}
	for k = 1, 6 do
		halo[k] = Core.part(c, V(0.2, 0.2, 0.2), c.c1)
	end
	local vol = Core.volume(c, V(5, 0.1, 5), CF(0, g + 0.1, 0))
	Core.emit(vol, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.24, 0.2, 0.06),
		transp = ns(1, 0.1, 0.25, 1),
		rate = 9,
		life = nr(2.6, 3.6),
		speed = nr(0.6, 1.1),
		spread = V2(10, 10),
		rot = nr(0, 0),
		bright = 2,
		shape = BOX,
		shapeStyle = VOLUME,
	})
	bodyGlow(c, c.c1, 5.5, 0.9)
	local light = rootLight(c, c.c1, 1.1, 9, g + 1.2)
	Core.on(c, function(t, _, root)
		for i, p in px do
			local per = 4 + i * 0.29
			local u = t / per + i * 0.173
			local ph = u % 1
			local cyc = math.floor(u)
			local a = i * 2.39 + cyc * 2.1
			local r = 1.6 + ((i * 7 + cyc) % 4) * 0.36
			-- pixel-stepped positions: they "tick" upward like a low-res sprite
			local x = snap(math.cos(a) * r, 0.2)
			local z = snap(math.sin(a) * r, 0.2)
			local y = snap(g + 0.3 + ph * span, 0.2)
			Core.put(p, root * CF(x, y, z))
			p.Transparency = 1 - math.sin(ph * math.pi) * 0.95
		end
		local fb = root * CF(0, g + 0.03, 0) * ANG(0, t * 0.15, 0)
		local blink = math.floor(t * 2) % 4
		for k = 1, 4 do
			local rot = ANG(0, (k - 1) * math.pi / 2, 0)
			Core.put(frame[k], fb * rot * CF(1.85, 0, 0))
			Core.put(corners[k], fb * rot * CF(1.85, 0.03, 1.85))
			corners[k].Transparency = if blink == k - 1 then 0 else 0.55
		end
		local step = math.floor(t * 6) / 6
		local hb = root * CF(0, c.topY + 0.75 + math.sin(t * 1.5) * 0.08, 0)
		for k, p in halo do
			local a = step * 1.2 + (k - 1) / 6 * TAU
			Core.put(p, hb * CF(math.cos(a) * 0.75, 0, math.sin(a) * 0.75))
			p.Transparency = (((k - 1) / 6 - t * 0.6) % 1) * 0.8
		end
		light.Brightness = 0.9 + Core.pulse(t, 3) * 0.6
	end)
end

-- grey flickering noise specks around the body
-- 19 parts / 3 emitters
A.Static = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local h = c.topY - g
	local vol = Core.volume(c, V(4.6, h + 1, 4.6), CF(0, (c.topY + g) / 2 + 0.3, 0))
	local noise = Core.emit(vol, {
		tex = T.square,
		color = cs(c.c2, WHITE, c.c1),
		size = ns(0.16, 0.12),
		transp = ns(0.05, 0.5),
		rate = 70,
		life = nr(0.05, 0.16),
		rot = nr(0, 0),
		light = 0.8,
		bright = 2,
		shape = BOX,
		shapeStyle = VOLUME,
	})
	local specks: { BasePart } = {}
	local loc: { CFrame } = {}
	local nextT: { number } = {}
	for i = 1, 18 do
		specks[i] = Core.part(c, V(0.05, 0.12, 0.3), c.c1)
		loc[i] = CF(0, -50, 0)
		nextT[i] = 0
	end
	-- VHS tracking rings rolling up the body
	local rolls: { B.Circle } = {}
	for k = 1, 2 do
		rolls[k] = B.circle(c, {
			radius = 2.3,
			color = WHITE,
			color2 = c.c1,
			width = 0.16,
			n = 6,
			anchor = function(t)
				return CF(0, g + (((t + k * 0.65) / 1.3) % 1) * (h + 0.8), 0)
			end,
		})
	end
	B.circle(c, { radius = 2.9, color = c.c2, width = 0.1, at = CF(0, g + 0.04, 0), tr = 0.45 })
	-- horizontal picture tear, always facing the camera
	local tear = Core.part(c, V(4.2, 0.09, 0.02), WHITE, NEON, 1)
	local tearY, tearUntil = 0, 0
	local _, _, nosigGui = B.glyph(c, "NO SIGNAL", WHITE, V2(2.6, 0.42), F.pixel, CF(0, c.topY + 1, 0), c.c2)
	nosigGui.Enabled = false
	bodyGlow(c, c.c1, 5, 0.92)
	local light = rootLight(c, c.c1, 1.2, 9, g + 1.5)
	Core.on(c, function(t, _, root)
		local lost = (t % 5.3) < 0.4
		for i, p in specks do
			if t >= nextT[i] then
				nextT[i] = t + 0.04 + rng:NextNumber() * 0.12
				local a = rng:NextNumber() * TAU
				local r = 1.3 + rng:NextNumber() * 1.7
				loc[i] = CF(math.cos(a) * r, g + 0.2 + rng:NextNumber() * (h + 0.6), math.sin(a) * r) * ANG(0, -a, 0)
				p.Size = V(0.05, 0.08 + rng:NextNumber() * 0.16, 0.18 + rng:NextNumber() * 0.45)
				p.Color = if rng:NextNumber() < 0.5 then c.c1 else c.c2:Lerp(WHITE, rng:NextNumber())
				p.Transparency = if rng:NextNumber() < 0.2 then 1 else rng:NextNumber() * 0.3
			end
			Core.put(p, root * loc[i])
		end
		for k, r in rolls do
			local ph = ((t + k * 0.65) / 1.3) % 1
			B.setBeamsTransparency(r.beams, 0.3 + 0.65 * ph)
		end
		if t >= tearUntil and rng:NextNumber() < (if lost then 0.4 else 0.025) then
			tearUntil = t + 0.06 + rng:NextNumber() * 0.12
			tearY = g + 0.3 + rng:NextNumber() * h
		end
		local center = (root * CF(0, tearY, 0)).Position
		Core.put(tear, CFrame.lookAt(center, camPos()) * CF((rng:NextNumber() - 0.5) * 0.3, 0, -1.1))
		tear.Transparency = if t < tearUntil then 0.05 else 1
		noise.Rate = if lost then 260 else 70
		nosigGui.Enabled = lost and math.sin(t * 40) > -0.3
		light.Brightness = if lost then 2.6 else 0.9 + math.noise(t * 7, 1.3) * 0.7
		light.Color = if lost then WHITE else c.c1
	end)
end

-- 8 tiny cyan cubes orbiting the waist
-- 24 parts / 3 emitters
A.Byte = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local y = -0.15
	local R = 2.7
	local cubes: { BasePart } = {}
	local cols: { BasePart } = {}
	local bits: { boolean } = {}
	for i = 1, 8 do
		cubes[i] = Core.part(c, V(0.48, 0.48, 0.48), c.c1)
		Core.trail(cubes[i], c.c1, 0.32, 0.3, c.c2)
		bits[i] = rng:NextNumber() < 0.5
		cols[i] = Core.part(c, V(0.12, 1, 0.12), c.c1, NEON, 0.4)
	end
	B.circle(c, { radius = R, color = c.c1, width = 0.1, at = CF(0, y, 0), tr = 0.4, n = 8 })
	B.circle(c, { radius = R + 0.25, color = c.c2, width = 0.05, at = CF(0, y, 0), tr = 0.5, n = 8 })
	-- floor bit-register: 8 segments, lit = 1
	B.ring(c, {
		n = 8,
		radius = R,
		seg = V(0.3, 0.07, 1.4),
		color = c.c1,
		anchor = function()
			return CF(0, g + 0.04, 0)
		end,
		paint = function(k, _, p)
			p.Color = if bits[k] then c.c1 else c.c2
			p.Transparency = if bits[k] then 0.05 else 0.7
		end,
	})
	local _, lbl = B.glyph(c, "", c.c1, V2(2.8, 0.42), F.pixel, CF(0, c.topY + 0.95, 0), c.c2)
	local ra = Core.att(c, c.root, CF(0, y, 0))
	local sparks = Core.emit(ra, {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.18, 0),
		transp = ns(0, 0.4),
		rate = 6,
		life = nr(0.5, 0.9),
		speed = nr(2.5, 4),
		spread = V2(180, 10),
		dir = Enum.NormalId.Front,
		rot = nr(0, 0),
	})
	bodyGlow(c, c.c1, 6, 0.9)
	local light = rootLight(c, c.c1, 1.3, 10, y)
	local nextFlip = 0
	local spinUntil: { number } = table.create(8, 0)
	local s = table.create(8, "0")
	Core.on(c, function(t, _, root)
		if t >= nextFlip then
			nextFlip = t + 0.4
			local k = rng:NextInteger(1, 8)
			bits[k] = not bits[k]
			spinUntil[k] = t + 0.35
			sparks:Emit(4)
		end
		local value = 0
		for i, p in cubes do
			local a = t * 1.1 + (i - 1) / 8 * TAU
			local bob = math.sin(t * 2 + i * 0.8) * 0.18
			local flip = if t < spinUntil[i] then (spinUntil[i] - t) * 18 else 0
			Core.put(p, root * CF(math.cos(a) * R, y + bob, math.sin(a) * R) * ANG(t * 1.5 + i + flip, t * 2 + i, 0))
			p.Color = if bits[i] then c.c1 else c.c2
			p.Transparency = if bits[i] then 0 else 0.35
			s[i] = if bits[i] then "1" else "0"
			if bits[i] then
				value += 2 ^ (8 - i)
			end
			-- floor column under each fixed register slot
			local ca = (i - 1) / 8 * TAU
			local hgt = if bits[i] then 0.9 + math.sin(t * 3 + i) * 0.15 else 0.15
			cols[i].Size = V(0.12, hgt, 0.12)
			Core.put(cols[i], root * CF(math.cos(ca) * R, g + hgt / 2, math.sin(ca) * R))
			cols[i].Transparency = if bits[i] then 0.25 else 0.8
		end
		lbl.Text = table.concat(s) .. string.format(" %02X", value)
		light.Brightness = 1.1 + Core.pulse(t, 0.4) * 0.4
	end)
end

-- green radar pulse ring expanding from feet every 2s
-- 26 parts / 3 emitters
A.Ping = function(c: Ctx)
	local g = c.groundY + 0.05
	local span = c.topY - c.groundY + 0.6
	local REACH = 4.2
	local dot = Core.part(c, V(0.08, 0.55, 0.55), c.c1, NEON, 0, CYL)
	B.circle(c, { radius = 1.4, color = c.c2, width = 0.08, at = CF(0, g, 0), tr = 0.3 })
	B.circle(c, { radius = 2.8, color = c.c2, width = 0.08, at = CF(0, g, 0), tr = 0.4 })
	local arm = Core.part(c, V(2.8, 0.04, 0.1), c.c1)
	local fan: { BasePart } = {}
	for i = 1, 4 do
		fan[i] = Core.part(c, V(2.8, 0.03, 0.09), c.c1, NEON, 0.3 + i * 0.16)
	end
	local waves: { B.Circle } = {}
	for w = 1, 2 do
		waves[w] = B.circle(c, {
			radius = 0.4,
			color = c.c1,
			width = if w == 1 then 0.24 else 0.13,
			n = 8,
			anchor = function()
				return CF(0, g + 0.02, 0)
			end,
			radiusFn = function(t)
				return 0.4 + (((t - (w - 1) * 0.22) % 2) / 2) * REACH
			end,
		})
	end
	-- sonar ring climbing the body with every ping
	local climb = B.circle(c, {
		radius = 1.6,
		color = c.c1,
		color2 = WHITE,
		width = 0.13,
		anchor = function(t)
			return CF(0, g + math.min(1, (t % 2) / 0.9) * span, 0)
		end,
		radiusFn = function(t)
			return 1.7 - math.min(1, (t % 2) / 0.9) * 0.5
		end,
	})
	B.ring(c, {
		n = 16,
		radius = 1,
		seg = V(0.14, 0.08, 0.5),
		color = c.c1,
		spin = 0.4,
		anchor = function()
			return CF(0, g + 0.03, 0)
		end,
		radiusFn = function(t)
			return 0.4 + ((t % 2) / 2) * REACH
		end,
		paint = function(_, t, p)
			p.Transparency = ((t % 2) / 2) ^ 0.7
		end,
	})
	local blips: { BasePart } = {}
	local blipA: { number } = {}
	local blipR: { number } = {}
	for i = 1, 4 do
		blips[i] = Core.part(c, V(0.28, 0.28, 0.28), c.c1, NEON, 1, BALL)
		blipA[i] = c.rng:NextNumber() * TAU
		blipR[i] = 0.8 + c.rng:NextNumber() * 1.8
	end
	local la = Core.att(c, c.root, CF(0, g + 0.4, 0))
	local light = Core.light(la, c.c1, 1, 10)
	Core.emit(la, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0.25, 0),
		transp = ns(0.2, 1),
		rate = 4,
		life = nr(1.2, 1.8),
		speed = nr(0.6, 1.2),
		spread = V2(50, 50),
	})
	local ga = Core.att(c, c.root, CF(0, g + 0.1, 0))
	local burst = Core.emit(ga, {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.2, 0),
		rate = 0,
		life = nr(0.6, 0.9),
		speed = nr(4, 6),
		spread = V2(90, 90),
		accel = V(0, -2, 0),
		drag = 2,
		rot = nr(0, 0),
	})
	bodyGlow(c, c.c1, 5.5, 0.9)
	local lastCycle = -1
	Core.on(c, function(t, _, root)
		local cycle = math.floor(t / 2)
		if cycle ~= lastCycle then
			lastCycle = cycle
			burst:Emit(14)
		end
		for w, circ in waves do
			B.setBeamsTransparency(circ.beams, (((t - (w - 1) * 0.22) % 2) / 2) ^ 0.8)
		end
		B.setBeamsTransparency(climb.beams, if (t % 2) < 0.9 then 0.15 + ((t % 2) / 0.9) * 0.75 else 1)
		light.Brightness = 0.6 + 2.8 * math.max(0, 1 - (t % 2) * 2)
		local a = t * 2.4
		local base = root * CF(0, g, 0)
		Core.put(dot, base * FLAT)
		Core.put(arm, base * CF(0, 0.02, 0) * ANG(0, -a, 0) * CF(1.4, 0, 0))
		for i, f in fan do
			Core.put(f, base * CF(0, 0.015, 0) * ANG(0, -(a - i * 0.1), 0) * CF(1.4, 0, 0))
		end
		for i, bp in blips do
			local diff = (a - blipA[i]) % TAU
			bp.Transparency = 1 - math.exp(-diff * 1.4) * 0.95
			if diff > TAU - 0.05 then
				blipA[i] = (blipA[i] + 1.3 + i) % TAU
				blipR[i] = 0.8 + c.rng:NextNumber() * 1.8
			end
			Core.put(bp, base * CF(math.cos(blipA[i]) * blipR[i], 0.08, math.sin(blipA[i]) * blipR[i]))
		end
	end)
end

-- warm crumbs and small hex icons orbiting
-- 24 parts / 4 emitters
A.Cookie = function(c: Ctx)
	local g = c.groundY
	local R = 2.7
	local head = Core.att(c, c.head, CF(0, 0, 0))
	local hexes: { { BasePart } } = {}
	local chips: { { BasePart } } = {}
	local tracks: { Attachment } = {}
	local crumbs: Core.EmitSpec = {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.16, 0.12, 0.05),
		transp = ns(0, 0.1, 1),
		rate = 5,
		life = nr(1.2, 1.8),
		speed = nr(0.4, 1),
		spread = V2(180, 180),
		accel = V(0, -5, 0),
		rotSpeed = nr(-200, 200),
		light = 0.4,
		bright = 1.4,
	}
	for i = 1, 4 do
		hexes[i] = B.hex(c, 0.55, 0.12, c.c1)
		chips[i] = {
			Core.part(c, V(0.14, 0.1, 0.14), c.c2, SMOOTH),
			Core.part(c, V(0.12, 0.1, 0.12), c.c2, SMOOTH),
			Core.part(c, V(0.1, 0.1, 0.1), c.c2, SMOOTH),
		}
		tracks[i] = Core.att(c)
		Core.beam(c, tracks[i], head, c.c1, 0.07, {
			w1 = 0.02,
			tr = ns(0.35, 0.85),
			tex = T.square,
			texLen = 0.35,
			texSpeed = 1.2,
		})
		if i <= 2 then
			Core.emit(hexes[i][1], crumbs)
		end
	end
	B.circle(c, { radius = R, color = c.c1, width = 0.1, at = CF(0, g + 0.04, 0), tr = 0.45 })
	B.circle(c, { radius = R - 0.3, color = c.c2, width = 0.06, at = CF(0, g + 0.04, 0), tr = 0.5 })
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0, 0.3, 0),
		rate = 4,
		life = nr(1, 1.6),
		speed = nr(0.6, 1.2),
		spread = V2(180, 180),
	})
	bodyGlow(c, c.c1, 6, 0.88)
	local light = rootLight(c, c.c1, 1.3, 10)
	local chipOff = { CF(0.16, 0.08, 0.12), CF(-0.18, 0.08, -0.06), CF(0.04, 0.08, -0.24) }
	Core.on(c, function(t, _, root)
		for i, hx in hexes do
			local a = t * 0.7 + (i - 1) / 4 * TAU
			local y = c.chestY + math.sin(t * 1.4 + i * 1.7) * 0.5
			local pos = V(math.cos(a) * R, y, math.sin(a) * R)
			-- hex "icons" stand up facing outward, wobbling
			local cf = root * CF(pos) * ANG(0, -a + math.pi / 2, 0) * ANG(math.pi / 2, 0, 0) * ANG(0, t * 1.3 + i, 0)
			B.putHex(hx, cf)
			for k, ch in chips[i] do
				Core.put(ch, cf * chipOff[k])
			end
			tracks[i].Position = pos
		end
		light.Brightness = 1.1 + Core.pulse(t, 2.5) * 0.5
	end)
end

-- stacked blue translucent panels floating behind the back
-- 22 parts / 3 emitters
A.Cache = function(c: Ctx)
	local rng = c.rng
	local panels: { BasePart } = {}
	local bars: { BasePart } = {}
	local sides: { BasePart } = {}
	local lines: { { TextLabel } } = {}
	local heads: { TextLabel } = {}
	local W, H = 2.4, 1.5
	for k = 1, 4 do
		local p = Core.part(c, V(W, H, 0.05), c.c1:Lerp(c.c2, k / 6), NEON, 0.55)
		panels[k] = p
		bars[k] = Core.part(c, V(W, 0.08, 0.08), c.c1)
		sides[k] = Core.part(c, V(0.06, H, 0.07), c.c1, NEON, 0.2)
		local sg = Core.surface(p, Enum.NormalId.Back, 80)
		local ls = {}
		for j = 1, 6 do
			ls[j] = Core.label(
				sg,
				string.format("%04X  %s %s", rng:NextInteger(0, 65535), Core.hex(2, rng), Core.hex(6, rng)),
				Color3.fromRGB(215, 230, 255),
				F.mono,
				UDim2.fromScale(0.05, 0.08 + (j - 1) * 0.145),
				UDim2.fromScale(0.9, 0.13),
				Enum.TextXAlignment.Left
			)
		end
		lines[k] = ls
		local fg = Core.surface(p, Enum.NormalId.Front, 80)
		heads[k] = Core.label(fg, "CACHE HIT", WHITE, F.pixel, UDim2.fromScale(0.08, 0.38), UDim2.fromScale(0.84, 0.24))
		heads[k].TextTransparency = 0.25
	end
	local function panelCF(k: number, t: number): CFrame
		local bob = math.sin(t * 1.1 + k * 0.9) * 0.1
		local sway = math.sin(t * 0.7 + k) * 0.06
		local x = (k - 2.5) * 0.35 + sway
		return CF(x, c.chestY + 0.05 + (k - 1) * 0.38 + bob, 0.95 + (k - 1) * 0.42)
			* ANG(-0.1, (if k % 2 == 0 then 0.14 else -0.14) + sway, 0)
	end
	-- cache lines shuttling between the panels and the body
	type Line = { p: BasePart, k: number, off: number }
	local shuttles: { Line } = {}
	for i = 1, 6 do
		local p = Core.part(c, V(0.22, 0.22, 0.22), WHITE)
		Core.trail(p, c.c1, 0.14, 0.25)
		shuttles[i] = { p = p, k = (i - 1) % 4 + 1, off = i / 6 }
	end
	local back = Core.att(c, c.torso, CF(0, 0, 0.6))
	Core.emit(back, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.14, 0),
		transp = ns(0.1, 1),
		rate = 7,
		life = nr(1.2, 2),
		speed = nr(0.5, 1),
		spread = V2(50, 50),
		dir = Enum.NormalId.Back,
		rot = nr(0, 0),
	})
	local vol = Core.volume(c, V(2.6, 1.6, 1.6), CF(0, c.chestY + 0.6, 1.6))
	Core.emit(vol, {
		tex = T.spark,
		color = cs(c.c1),
		size = ns(0, 0.3, 0),
		rate = 6,
		life = nr(0.8, 1.4),
		speed = nr(0.2, 0.5),
		shape = BOX,
		shapeStyle = VOLUME,
	})
	bodyGlow(c, c.c1, 6, 0.9)
	local light = rootLight(c, c.c1, 1.4, 10)
	local nextW = 0
	Core.on(c, function(t, _, root)
		if t >= nextW then
			nextW = t + 0.22
			local k = rng:NextInteger(1, 4)
			local ls = lines[k]
			for j = 1, 5 do
				ls[j].Text = ls[j + 1].Text
			end
			ls[6].Text = string.format("%04X  %s %s", rng:NextInteger(0, 65535), Core.hex(2, rng), Core.hex(6, rng))
			heads[k].Text = if rng:NextNumber() < 0.8 then "CACHE HIT" else "MISS"
		end
		for k, p in panels do
			local cf = root * panelCF(k, t)
			Core.put(p, cf)
			Core.put(bars[k], cf * CF(0, H / 2 + 0.04, 0))
			Core.put(sides[k], cf * CF((if k % 2 == 0 then 1 else -1) * W / 2, 0, 0))
		end
		local chest = V(0, c.chestY, 0.3)
		for _, s in shuttles do
			local u = (t * 0.55 + s.off) % 2
			local f = if u < 1 then u else 2 - u
			local tgt = panelCF(s.k, t).Position
			local p = B.bez(chest, chest + V(0, 1.2, 0), tgt + V(0, 1.2, 0), tgt, f)
			Core.put(s.p, root * CF(p) * ANG(t * 3, t * 2, 0))
			s.p.Transparency = 1 - math.sin(f * math.pi) * 0.95
		end
		light.Brightness = 1.2 + Core.pulse(t, 2) * 0.5
	end)
end

-- low orange digital flames at the feet with hex sparks
-- 27 parts / 3 emitters
A.Firewall = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local R = 2.5
	local vol = Core.volume(c, V(5.2, 0.2, 5.2), CF(0, g + 0.1, 0))
	local hot = Color3.fromRGB(255, 220, 120)
	Core.emit(vol, {
		tex = T.fire,
		color = cs(hot, c.c1, c.c2),
		size = ns(1.2, 0.85, 0.1),
		transp = ns(0.3, 0.45, 1),
		rate = 55,
		life = nr(0.45, 0.8),
		speed = nr(1.5, 2.6),
		accel = V(0, 2.5, 0),
		spread = V2(8, 8),
		rotSpeed = nr(-40, 40),
		shape = Enum.ParticleEmitterShape.Cylinder,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		zoff = 0.3,
	})
	Core.emit(vol, {
		tex = T.square,
		color = cs(hot, c.c1),
		size = ns(0.22, 0),
		rate = 14,
		life = nr(0.9, 1.5),
		speed = nr(2.5, 4.5),
		spread = V2(20, 20),
		accel = V(0, 0.8, 0),
		rotSpeed = nr(-180, 180),
		bright = 2.5,
		shape = Enum.ParticleEmitterShape.Cylinder,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	local base = Core.part(c, V(0.04, 5.6, 5.6), c.c2, NEON, 0.72, CYL)
	B.circle(c, { radius = R + 0.35, color = c.c1, width = 0.12, at = CF(0, g + 0.05, 0), tr = 0.2 })
	local n = 20
	local bricks: { BasePart } = {}
	for i = 1, n do
		bricks[i] = Core.part(c, V(0.18, 0.4, 0.66), c.c1)
	end
	-- hex embers rising out of the wall
	type Ember = { hx: { BasePart }, t0: number, life: number, a: number }
	local embers: { Ember } = {}
	for i = 1, 2 do
		embers[i] = { hx = B.hex(c, 0.24, 0.05, hot), t0 = -10, life = 1, a = 0 }
	end
	bodyGlow(c, c.c1, 6, 0.88)
	local light = rootLight(c, c.c1, 1.6, 11, g + 0.8)
	Core.on(c, function(t, _, root)
		Core.put(base, root * CF(0, g + 0.02, 0) * FLAT)
		for i, p in bricks do
			local a = (i - 1) / n * TAU + t * 0.25
			local f = math.clamp(0.5 + math.noise(i * 0.37, t * 3.1) * 1.4, 0, 1)
			local h = 0.25 + f * 1.15
			p.Size = V(0.18, h, 0.66)
			p.Color = c.c2:Lerp(c.c1, f):Lerp(hot, math.max(0, f - 0.7) * 2)
			Core.put(p, root * CF(0, g + h / 2, 0) * ANG(0, -a, 0) * CF(R, 0, 0))
		end
		for _, e in embers do
			local age = t - e.t0
			if age > e.life then
				e.t0 = t
				e.life = 1.2 + rng:NextNumber() * 0.8
				e.a = rng:NextNumber() * TAU
				age = 0
			end
			local f = age / e.life
			local cf = root
				* CF(math.cos(e.a) * R, g + 0.5 + f * 3.4, math.sin(e.a) * R)
				* ANG(t * 2, t * 3, 0)
			B.putHex(e.hx, cf)
			for _, p in e.hx do
				p.Transparency = f
			end
		end
		light.Brightness = 1.4 + math.noise(t * 6, 0.5) * 1.4
	end)
end

-- purple afterimage ghosts trailing the body
-- 30 parts / 3 emitters
A.Lag = function(c: Ctx)
	local rng = c.rng
	local jit = { 0, 0 }
	local g1 = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = FF,
		delay = 0.16,
		fps = 12,
		map = B.offsetMap(function()
			return CF(0.4 + jit[1], 0.05, 0.55)
		end),
	})
	local g2 = B.clones(c, {
		set = "lite",
		color = c.c2:Lerp(c.c1, 0.4),
		mat = NEON,
		tr = 0.6,
		delay = 0.36,
		fps = 6,
		map = B.offsetMap(function()
			return CF(-0.7 + jit[2], 0.1, 1.15)
		end),
	})
	-- buffering spinner over the head
	local dots: { BasePart } = {}
	for i = 1, 8 do
		dots[i] = Core.part(c, V(0.2, 0.2, 0.2), c.c1, NEON, 0, BALL)
	end
	local torso = Core.att(c, c.torso, CF(0, 0, 0.4))
	Core.emit(torso, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.9, 0.6),
		transp = ns(0.65, 1),
		rate = 6,
		life = nr(0.5, 0.8),
		speed = nr(0.6, 1.2),
		dir = Enum.NormalId.Back,
		spread = V2(25, 25),
		rot = nr(0, 0),
		light = 0.8,
	})
	Core.emit(Core.volume(c, V(4, 0.1, 4), CF(0, c.groundY + 0.1, 0.6)), {
		tex = T.square,
		color = cs(c.c1),
		size = ns(0.2, 0.15, 0),
		transp = ns(0.2, 1),
		rate = 7,
		life = nr(1, 1.6),
		speed = nr(0.6, 1.2),
		rot = nr(0, 0),
		shape = BOX,
	})
	B.circle(c, { radius = 2.6, color = c.c1, width = 0.08, at = CF(0, c.groundY + 0.04, 0.5), tr = 0.5 })
	bodyGlow(c, c.c1, 6, 0.9)
	local light = rootLight(c, c.c1, 1.3, 10)
	local nextSkip = 0
	Core.on(c, function(t, _, root)
		if t >= nextSkip then
			nextSkip = t + 0.6 + rng:NextNumber() * 1.4
			jit[1] = (rng:NextNumber() - 0.5) * 0.5
			jit[2] = (rng:NextNumber() - 0.5) * 0.7
		end
		local stall = (t % 3.1) < 0.25 -- frame drop: ghosts flash
		for _, p in g1 do
			p.Transparency = if stall then 0.5 else 0
		end
		for _, p in g2 do
			p.Transparency = if stall then 0.3 else 0.6
		end
		local center = (root * CF(0, c.topY + 0.95, 0)).Position
		local look = CFrame.lookAt(center, camPos())
		for i, p in dots do
			local a = (i - 1) / 8 * TAU
			Core.put(p, look * CF(math.sin(a) * 0.55, math.cos(a) * 0.55, 0))
			local chase = ((i - 1) / 8 - t * 1.4) % 1
			p.Transparency = chase * 0.92
		end
		light.Brightness = if stall then 2.4 else 1.2
	end)
end

---------------------------------------------------------------- ENHANCED

-- teal data packets streaming in arcs over the head
-- 34 parts / 4 emitters
A.Packet = function(c: Ctx)
	local g = c.groundY
	type Arc = { p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, dir: number }
	local arcs: { Arc } = {}
	local yb = c.chestY - 0.1
	local SX = 3.2
	for k = 1, 2 do
		local z = if k == 1 then -0.5 else 0.6
		local L = V(-SX, yb, z)
		local R = V(SX, yb, z)
		local peak = c.topY + (if k == 1 then 1.6 else 2.4)
		local h = (peak - yb) / 0.75
		local up = V(0, h, 0)
		arcs[k] = { p0 = L, p1 = L + up, p2 = R + up, p3 = R, dir = if k == 1 then 1 else -1 }
		local a0 = Core.att(c, nil, CFrame.fromMatrix(L, Vector3.yAxis, -Vector3.xAxis))
		local a1 = Core.att(c, nil, CFrame.fromMatrix(R, -Vector3.yAxis, Vector3.xAxis))
		Core.beam(c, a0, a1, c.c1, 0.16, {
			c0 = h,
			c1 = h,
			segs = 24,
			tr = ns(0.6, 0.3, 0.6),
			color2 = c.c2,
			tex = T.square,
			texLen = 0.6,
			texSpeed = 2 * (if k == 1 then 1 else -1),
		})
	end
	-- router nodes on posts at both ends
	local nodes: { BasePart } = {}
	local posts: { BasePart } = {}
	local nodePos: { Vector3 } = { arcs[1].p0, arcs[1].p3, arcs[2].p0, arcs[2].p3 }
	local postH = yb - g
	for i = 1, 4 do
		nodes[i] = Core.part(c, V(0.5, 0.5, 0.5), c.c2:Lerp(c.c1, 0.5))
		posts[i] = Core.part(c, V(0.1, postH, 0.1), c.c1, NEON, 0.45)
	end
	local nodeAtts = { Core.att(c, nil, CF(-SX, yb, 0)), Core.att(c, nil, CF(SX, yb, 0)) }
	local nodeFx: { ParticleEmitter } = {}
	for i, na in nodeAtts do
		nodeFx[i] = Core.emit(na, {
			tex = T.spark,
			color = cs(WHITE, c.c1),
			size = ns(0.35, 0),
			rate = 4,
			life = nr(0.4, 0.8),
			speed = nr(1, 2.5),
			spread = V2(180, 180),
		})
	end
	type Pk = { body: BasePart, cap: BasePart, arc: Arc, off: number, last: number }
	local pks: { Pk } = {}
	for i = 1, 10 do
		local body = Core.part(c, V(0.34, 0.34, 0.6), c.c1)
		local cap = Core.part(c, V(0.38, 0.38, 0.12), c.c2:Lerp(WHITE, 0.4))
		Core.trail(body, c.c1, 0.26, 0.3, c.c2)
		pks[i] = { body = body, cap = cap, arc = arcs[(i - 1) % 2 + 1], off = math.floor((i - 1) / 2) / 5, last = 0 }
	end
	B.ring(c, {
		n = 12,
		gap = 2,
		radius = 3.5,
		seg = V(0.16, 0.06, 0),
		color = c.c1,
		spin = 0.35,
		anchor = function()
			return CF(0, g + 0.04, 0)
		end,
	})
	B.circle(c, { radius = 3.5, color = c.c2, width = 0.1, at = CF(0, g + 0.03, 0), tr = 0.4 })
	bodyGlow(c, c.c1, 6.5, 0.88)
	local light = rootLight(c, c.c1, 1.8, 12, c.topY)
	Core.on(c, function(t, _, root)
		for _, pk in pks do
			local a = pk.arc
			local s = (t * 0.4 + pk.off) % 1
			if s < pk.last then
				-- delivered: ACK flash at the receiving node
				nodeFx[if a.dir > 0 then 2 else 1]:Emit(5)
			end
			pk.last = s
			if a.dir < 0 then
				s = 1 - s
			end
			local p = B.bez(a.p0, a.p1, a.p2, a.p3, s)
			local q = B.bez(a.p0, a.p1, a.p2, a.p3, math.clamp(s + 0.01 * a.dir, 0, 1))
			if (q - p).Magnitude < 1e-4 then
				q = p + V(a.dir, 0, 0)
			end
			local cf = root * CFrame.lookAt(p, q)
			Core.put(pk.body, cf)
			Core.put(pk.cap, cf * CF(0, 0, -0.34))
			local vis = math.sin(s * math.pi) ^ 0.35
			pk.body.Transparency = 1 - vis
			pk.cap.Transparency = 1 - vis
		end
		for i, nd in nodes do
			local np = nodePos[i]
			Core.put(nd, root * CF(np) * ANG(t * (1 + i * 0.1), t * 1.3, 0))
			Core.put(posts[i], root * CF(np.X, g + postH / 2, np.Z))
		end
		light.Brightness = 1.6 + Core.pulse(t, 1.25) * 0.6
	end)
end

-- yellow mirrored silhouette offset beside the player (hops sides)
-- 17 parts / 4 emitters
A.Proxy = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local off = 3.8
	local side = 1
	local jx, jy, jUntil, nextJ = 0, 0, 0, 0
	local hopAt = os.clock() + 6
	local parts = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = FF,
		map = function(cf, root)
			return root * CF(side * off + jx, jy, 0) * B.mirrorX(root:ToObjectSpace(cf))
		end,
	})
	local h = c.topY - g + 0.5
	local ym = g + h / 2
	local frame: { { p: BasePart, cf: CFrame } } = {
		{ p = Core.part(c, V(0.1, h, 0.1), c.c1), cf = CF(0, ym, 1) },
		{ p = Core.part(c, V(0.1, h, 0.1), c.c1), cf = CF(0, ym, -1) },
		{ p = Core.part(c, V(0.1, 0.1, 2.1), c.c1), cf = CF(0, g + h, 0) },
		{ p = Core.part(c, V(0.1, 0.1, 2.1), c.c1), cf = CF(0, g, 0) },
		{ p = Core.part(c, V(0.02, h, 2), c.c1, NEON, 0.9), cf = CF(0, ym, 0) },
	}
	local scan = Core.part(c, V(0.04, 0.08, 2), WHITE, NEON, 0.2)
	local a0 = Core.att(c, nil, CF(0.5, c.chestY, 0))
	local a1 = Core.att(c, nil, CF(off - 0.5, c.chestY, 0))
	Core.beam(c, a0, a1, c.c1, 0.14, { tex = T.square, texLen = 0.45, texSpeed = 2, tr = ns(0.15), color2 = c.c2 })
	B.circle(c, { radius = 1.5, color = c.c1, width = 0.12, at = CF(0, g + 0.04, 0), tr = 0.3 })
	B.circle(c, {
		radius = 1.5,
		color = c.c1,
		width = 0.14,
		color2 = c.c2,
		anchor = function()
			return CF(side * off, g + 0.04, 0)
		end,
	})
	local ipAtt, ip = B.glyph(c, "127.0.0.1", c.c1, V2(2.8, 0.42), F.pixel, CF(off, c.topY + 0.95, 0), c.c2)
	local tagAtt, tag =
		B.glyph(c, "SPOOFED", c.c2:Lerp(c.c1, 0.5), V2(1.6, 0.28), F.tech, CF(off, c.topY + 0.55, 0))
	local pa = Core.att(c, nil, CF(off, c.chestY, 0))
	local psp = Core.emit(pa, {
		tex = T.spark,
		color = cs(c.c1, c.c2),
		size = ns(0.32, 0),
		transp = ns(0.1, 1),
		rate = 6,
		life = nr(0.8, 1.4),
		speed = nr(0.8, 1.6),
		spread = V2(180, 180),
	})
	local fa = Core.att(c, nil, CF(off, g + 0.1, 0))
	Core.emit(fa, {
		tex = T.square,
		color = cs(c.c1),
		size = ns(0.2, 0),
		transp = ns(0.1, 1),
		rate = 8,
		life = nr(0.8, 1.3),
		speed = nr(1, 2.2),
		spread = V2(20, 20),
		rot = nr(0, 0),
	})
	local pl = Core.light(pa, c.c1, 1.4, 10)
	bodyGlow(c, c.c1, 6, 0.9)
	local light = rootLight(c, c.c1, 1.5, 11)
	local ports = { ":8080", ":3128", ":1080", ":443" }
	local nextP = 0
	Core.on(c, function(t, _, root)
		if t >= hopAt then
			-- hop to the other side through a glitch
			hopAt = t + 5 + rng:NextNumber() * 3
			side = -side
			jUntil = t + 0.3
			psp:Emit(20)
		end
		if t >= nextJ then
			nextJ = t + 0.9 + rng:NextNumber() * 1.6
			jUntil = math.max(jUntil, t + 0.12)
			jx = (rng:NextNumber() - 0.5) * 0.6
			jy = (rng:NextNumber() - 0.5) * 0.25
		end
		if t > jUntil then
			jx, jy = 0, 0
		end
		local fl = if t < jUntil then 0.5 else 0
		for _, p in parts do
			p.Transparency = fl
		end
		local mx = side * off / 2
		for _, f in frame do
			Core.put(f.p, root * CF(mx, 0, 0) * f.cf)
		end
		Core.put(scan, root * CF(mx, g + ((t * 0.6) % 1) * h, 0))
		a0.Position = V(side * 0.5, c.chestY, 0)
		a1.Position = V(side * (off - 0.5), c.chestY, 0)
		ipAtt.Position = V(side * off, c.topY + 0.95, 0)
		tagAtt.Position = V(side * off, c.topY + 0.55, 0)
		pa.Position = V(side * off, c.chestY, 0)
		fa.Position = V(side * off, g + 0.1, 0)
		if t >= nextP then
			nextP = t + 1.6
			ip.Text = "127.0.0.1" .. Core.pick(ports, rng)
		end
		tag.TextTransparency = if math.sin(t * 9) > 0.6 then 0.8 else 0.1
		pl.Brightness = if t < jUntil then 3 else 1.4
		light.Brightness = 1.3 + Core.pulse(t, 2) * 0.5
	end)
end

-- equalizer bars pulsing in a ring on the ground
-- 44 parts / 3 emitters
A.Bitrate = function(c: Ctx)
	local n = 22
	local r = 3
	local g = c.groundY
	local bars: { BasePart } = {}
	local caps: { BasePart } = {}
	local capY: { number } = {}
	for i = 1, n do
		bars[i] = Core.part(c, V(0.32, 0.2, 0.32), c.c1)
		caps[i] = Core.part(c, V(0.38, 0.07, 0.38), WHITE)
		capY[i] = 0.2
	end
	B.circle(c, { radius = r, color = c.c1, width = 0.1, at = CF(0, g + 0.02, 0), tr = 0.3 })
	B.circle(c, { radius = r + 0.45, color = c.c2, width = 0.07, at = CF(0, g + 0.02, 0), tr = 0.45 })
	local shock = B.circle(c, {
		radius = 1,
		color = c.c2,
		color2 = c.c1,
		width = 0.2,
		n = 8,
		anchor = function()
			return CF(0, g + 0.05, 0)
		end,
		radiusFn = function(t)
			return 0.6 + ((t * 2) % 1) * 4.4
		end,
	})
	local la = Core.att(c, c.root, CF(0, g + 0.5, 0))
	local light = Core.light(la, c.c2, 1.5, 12)
	local e = Core.emit(la, {
		tex = T.spark,
		color = cs(c.c1, c.c2),
		size = ns(0.38, 0),
		rate = 0,
		life = nr(0.5, 0.9),
		speed = nr(3, 6),
		spread = V2(70, 70),
		accel = V(0, -5, 0),
	})
	Core.emit(Core.volume(c, V(6.4, 0.1, 6.4), CF(0, g + 0.1, 0)), {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.18, 0),
		transp = ns(0.1, 1),
		rate = 10,
		life = nr(0.8, 1.4),
		speed = nr(1.5, 3),
		rot = nr(0, 0),
		shape = BOX,
	})
	bodyGlow(c, c.c2, 6.5, 0.88)
	Core.on(c, function(t, dt, root)
		local beat = math.max(0, math.sin(t * TAU * 2)) ^ 8
		e.Rate = beat * 50
		light.Brightness = 0.8 + beat * 3.5
		light.Color = if (t * 2) % 2 < 1 then c.c2 else c.c1
		B.setBeamsTransparency(shock.beams, 0.1 + ((t * 2) % 1) * 0.9)
		local base = root * CF(0, g, 0) * ANG(0, t * 0.3, 0)
		for i, p in bars do
			local band = (i - 1) / (n - 1)
			local v = 0.22
				+ 0.55 * math.abs(math.noise(band * 3.1, t * 2.3)) * 2
				+ beat * (1 - band) * 0.7
				+ 0.12 * math.sin(t * 7 + i)
			v = math.clamp(v, 0.05, 1)
			local h = 0.15 + v * 2.6
			p.Size = V(0.32, h, 0.32)
			p.Color = c.c1:Lerp(c.c2, v)
			local a = (i - 1) / n * TAU
			local cf = base * ANG(0, -a, 0) * CF(r, 0, 0)
			Core.put(p, cf * CF(0, h / 2, 0))
			capY[i] = math.max(capY[i] - dt * 1.6, h + 0.12)
			Core.put(caps[i], cf * CF(0, capY[i], 0))
		end
	end)
end

-- red numbers spilling upward like a fountain
-- 20 parts / 3 emitters
A.Overflow = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local origin = V(0, c.topY + 0.3, 0)
	type Drop = { att: Attachment, lbl: TextLabel, t0: number, v: Vector3 }
	local drops: { Drop } = {}
	local LIFE = 2
	local function relaunch(d: Drop, t: number)
		d.t0 = t - rng:NextNumber() * 0.05
		local a = rng:NextNumber() * TAU
		local hs = 1.5 + rng:NextNumber() * 1.3
		d.v = V(math.cos(a) * hs, 6.2 + rng:NextNumber() * 1.8, math.sin(a) * hs)
		d.lbl.Text = if rng:NextNumber() < 0.6 then tostring(rng:NextInteger(0, 9)) else Core.hex(2, rng)
	end
	for i = 1, 18 do
		local att, lbl = B.glyph(c, "0", c.c1, V2(0.7, 0.7), F.pixel, CF(origin), Color3.new(0.25, 0, 0))
		local d: Drop = { att = att, lbl = lbl, t0 = 0, v = Vector3.zero }
		relaunch(d, os.clock() - i * LIFE / 18)
		drops[i] = d
	end
	-- buffer meter that fills and overflows
	local segs: { BasePart } = {}
	for i = 1, 10 do
		segs[i] = Core.part(c, V(0.5, 0.18, 0.14), c.c2:Lerp(c.c1, (i - 1) / 9))
	end
	local _, meterLbl = B.glyph(c, "0x0000", c.c1, V2(1.6, 0.34), F.pixel, CF(2.2, c.chestY + 1.45, 0))
	B.ring(c, {
		n = 10,
		radius = 0.8,
		seg = V(0.1, 0.1, 0),
		color = c.c1,
		color2 = c.c2,
		spin = 3,
		anchor = function()
			return CF(0, c.topY + 0.15, 0)
		end,
	})
	B.circle(c, {
		radius = 3.6,
		color = c.c1,
		color2 = c.c2,
		width = 0.12,
		anchor = function()
			return CF(0, g + 0.04, 0)
		end,
		radiusFn = function(t)
			return 3.4 + math.sin(t * 5) * 0.15
		end,
	})
	local top = Core.att(c, c.head, CF(0, c.head.Size.Y / 2, 0))
	Core.emit(top, {
		tex = T.fireSpark,
		color = cs(c.c2, c.c1),
		size = ns(0.3, 0),
		rate = 14,
		life = nr(0.8, 1.3),
		speed = nr(5, 7),
		spread = V2(28, 28),
		accel = V(0, -9, 0),
		bright = 2,
	})
	Core.emit(Core.volume(c, V(7, 0.1, 7), CF(0, g + 0.1, 0)), {
		tex = T.square,
		color = cs(c.c2, c.c1),
		size = ns(0.22, 0),
		transp = ns(0.1, 1),
		rate = 12,
		life = nr(0.4, 0.8),
		speed = nr(1.5, 3),
		spread = V2(30, 30),
		accel = V(0, -6, 0),
		rot = nr(0, 0),
		shape = BOX,
	})
	bodyGlow(c, c.c1, 6.5, 0.88)
	local light = rootLight(c, c.c1, 1.6, 12, c.topY)
	Core.on(c, function(t, _, root)
		for _, d in drops do
			local age = t - d.t0
			if age > LIFE then
				relaunch(d, t)
				age = 0
			end
			local f = age / LIFE
			local p = origin + d.v * age + V(0, -4.6 * age * age, 0)
			if p.Y < g + 0.3 then
				p = V(p.X, g + 0.3, p.Z)
			end
			d.att.Position = p
			d.lbl.TextColor3 = c.c1:Lerp(c.c2, f)
			d.lbl.TextTransparency = f * f
		end
		local cyc = (t / 3.2) % 1
		local fill = math.min(1, cyc / 0.85)
		local over = cyc > 0.85
		for i, p in segs do
			Core.put(p, root * CF(2.2, c.chestY - 0.75 + (i - 1) * 0.22, 0) * ANG(0, -0.4, 0))
			local lit = (i - 1) / 10 < fill
			p.Transparency = if over then (if math.sin(t * 40) > 0 then 0 else 0.6) elseif lit then 0 else 0.85
		end
		meterLbl.Text = if over then "OVERFLOW" else string.format("0x%04X", math.floor(fill * 65535))
		meterLbl.TextColor3 = if over then c.c2 else c.c1
		light.Brightness = if over then 3.5 else 1.6
	end)
end

-- toxic green drips and skull-like hex glyphs
-- 20 parts / 6 emitters
A.Malware = function(c: Ctx)
	local rng = c.rng
	B.clones(c, { set = "lite", color = c.c1, mat = FF, scale = 1.02 })
	local drip: Core.EmitSpec = {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.2, 0.16, 0.06),
		transp = ns(0, 0.1, 0.8),
		rate = 6,
		life = nr(0.55, 0.8),
		speed = nr(0, 0.3),
		accel = V(0, -16, 0),
		rot = nr(45, 45),
		light = 0.9,
	}
	local sx = c.torso.Size.X * 0.4
	local sy = c.torso.Size.Y * 0.45
	Core.emit(Core.att(c, c.torso, CF(sx, sy, 0)), drip)
	Core.emit(Core.att(c, c.torso, CF(-sx, sy, 0)), drip)
	local lh = Core.bodyPart(c.char, "LeftHand", "Left Arm")
	local rh = Core.bodyPart(c.char, "RightHand", "Right Arm")
	local hy = if c.r15 then 0 else -0.9
	if lh then
		Core.emit(Core.att(c, lh, CF(0, hy, 0)), drip)
	end
	if rh then
		Core.emit(Core.att(c, rh, CF(0, hy, 0)), drip)
	end
	local g = c.groundY
	local PR = 2.7
	local puddle = Core.part(c, V(0.04, PR * 2, PR * 2), c.c2:Lerp(c.c1, 0.35), NEON, 0.35, CYL)
	B.circle(c, { radius = PR, color = c.c1, width = 0.14, at = CF(0, g + 0.04, 0), tr = 0.15 })
	B.circle(c, { radius = PR + 0.8, color = c.c1, width = 0.06, at = CF(0, g + 0.04, 0), tr = 0.55 })
	local pv = Core.volume(c, V(PR * 1.6, 0.1, PR * 1.6), CF(0, g + 0.05, 0))
	Core.emit(pv, {
		tex = T.smoke,
		color = cs(c.c1, c.c2),
		size = ns(0.8, 2.2),
		transp = ns(0.75, 1),
		rate = 5,
		life = nr(1.2, 2),
		speed = nr(0.6, 1.2),
		rotSpeed = nr(-40, 40),
		light = 0.7,
		shape = BOX,
	})
	-- toxic bubbles swelling and popping in the puddle
	type Bub = { p: BasePart, t0: number, life: number, pos: Vector3, size: number }
	local bubs: { Bub } = {}
	for i = 1, 8 do
		bubs[i] = {
			p = Core.part(c, V(0.3, 0.3, 0.3), c.c1, NEON, 0.2, BALL),
			t0 = -10,
			life = 1,
			pos = Vector3.zero,
			size = 0.3,
		}
	end
	local hexes = { "0xDEAD", "0xBADC0DE", "0xC0FFEE", "0xFA11", "0x0BAD" }
	type Sk = { att: Attachment, a: number, y: number }
	local skulls: { Sk } = {}
	for i = 1, 5 do
		local att, lbl, gui = B.glyph(c, "☠", c.c1, V2(1.2, 1.5), F.mono, nil, c.c2)
		lbl.Size = UDim2.fromScale(1, 0.72)
		local sub = Core.label(gui, hexes[i], c.c1, F.pixel, UDim2.fromScale(-0.3, 0.74), UDim2.fromScale(1.6, 0.24))
		sub.TextStrokeTransparency = 0.3
		skulls[i] = { att = att, a = (i - 1) / 5 * TAU, y = g + 1.4 + (i % 3) * 1.1 }
	end
	local light = rootLight(c, c.c1, 1.6, 12, g + 0.6)
	Core.on(c, function(t, _, root)
		local d = PR * 2 + math.sin(t * 2.1) * 0.25
		puddle.Size = V(0.04, d, d)
		Core.put(puddle, root * CF(0, g + 0.02, 0) * FLAT)
		for _, b in bubs do
			local age = t - b.t0
			if age > b.life then
				b.t0 = t
				b.life = 0.8 + rng:NextNumber() * 1
				local a = rng:NextNumber() * TAU
				local r = 0.6 + rng:NextNumber() * (PR - 0.8)
				b.pos = V(math.cos(a) * r, g, math.sin(a) * r)
				b.size = 0.25 + rng:NextNumber() * 0.35
				age = 0
			end
			local f = age / b.life
			local s = b.size * (0.3 + f * 0.9)
			b.p.Size = V(s, s, s)
			Core.put(b.p, root * CF(b.pos + V(0, s * 0.35 + f * 0.3, 0)))
			b.p.Transparency = if f > 0.92 then 1 else 0.15 + f * 0.3
		end
		for i, s in skulls do
			local a = s.a + t * 0.6
			local jit = if math.noise(i, t * 3) > 0.35 then (rng:NextNumber() - 0.5) * 0.25 else 0
			s.att.Position = V(math.cos(a) * 3.1 + jit, s.y + math.sin(t * 1.7 + i) * 0.25, math.sin(a) * 3.1)
		end
		light.Brightness = 1.3 + Core.pulse(t, 1.4) * 1.1
	end)
end

return A
