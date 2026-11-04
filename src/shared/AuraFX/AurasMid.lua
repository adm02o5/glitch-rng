--!strict
-- AuraFX/AurasMid: RARE and EPIC tier auras.

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
local METAL = Enum.Material.Metal
local FLAT = ANG(0, 0, math.pi / 2)

-- root-local frame on a horizontal circle whose -Z (Front face) points outward
local function outward(a: number, r: number, y: number): CFrame
	return ANG(0, -a, 0) * CF(r, y, 0) * ANG(0, -math.pi / 2, 0)
end

local SCRAMBLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$%&@"
local function randChar(rng: Random, set: string): string
	local k = rng:NextInteger(1, #set)
	return string.sub(set, k, k)
end

local A: { [string]: (Ctx) -> () } = {}

---------------------------------------------------------------- RARE

-- cyan/magenta RGB-split shards jittering around the body
A.Glitch = function(c: Ctx)
	local rng = c.rng
	local ox, oy, burstUntil, nextBurst = 0.08, 0, 0, 0
	B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = NEON,
		tr = 0.78,
		scale = 1.02,
		map = function(cf, root)
			return root * CF(-ox, oy, 0) * root:ToObjectSpace(cf)
		end,
	})
	B.clones(c, {
		set = "lite",
		color = c.c2,
		mat = NEON,
		tr = 0.78,
		scale = 1.02,
		map = function(cf, root)
			return root * CF(ox, -oy, 0) * root:ToObjectSpace(cf)
		end,
	})
	type Shard = { a: BasePart, b: BasePart, cf: CFrame, nextT: number }
	local shards: { Shard } = {}
	for i = 1, 8 do
		local a = Core.part(c, V(0.05, 0.6, 0.3), if i % 2 == 0 then c.c1 else c.c2)
		local b = Core.part(c, V(0.05, 0.6, 0.3), if i % 2 == 0 then c.c2 else c.c1, NEON, 0.35)
		shards[i] = { a = a, b = b, cf = CF(0, -50, 0), nextT = 0 }
	end
	local slices = {
		Core.part(c, V(2.6, 0.07, 0.02), c.c1, NEON, 1),
		Core.part(c, V(2.2, 0.05, 0.02), c.c2, NEON, 1),
	}
	local sliceY = { 0, 0 }
	type Gl = { att: Attachment, lbl: TextLabel, nextT: number }
	local glyphs: { Gl } = {}
	for i = 1, 4 do
		local att, lbl = B.glyph(c, "#", c.c1, V2(0.45, 0.45), F.pixel)
		glyphs[i] = { att = att, lbl = lbl, nextT = 0 }
	end
	local torso = Core.att(c, c.torso)
	local pix: Core.EmitSpec = {
		tex = T.square,
		color = cs(c.c1),
		size = ns(0.14, 0.06),
		transp = ns(0, 0.6),
		rate = 12,
		life = nr(0.1, 0.25),
		speed = nr(3, 6),
		spread = V2(180, 180),
		rot = nr(0, 0),
		bright = 2,
	}
	Core.emit(torso, pix)
	pix.color = cs(c.c2)
	Core.emit(torso, pix)
	local light = Core.light(torso, c.c1, 1.5, 10)
	local h = c.topY - c.groundY
	Core.on(c, function(t, _, root)
		if t >= nextBurst then
			nextBurst = t + 0.5 + rng:NextNumber() * 0.9
			burstUntil = t + 0.15
		end
		local bursting = t < burstUntil
		if bursting then
			ox = 0.22 + rng:NextNumber() * 0.25
			oy = (rng:NextNumber() - 0.5) * 0.2
		else
			ox = 0.07 + math.sin(t * 13) * 0.025
			oy = 0
		end
		for _, s in shards do
			if t >= s.nextT then
				s.nextT = t + 0.08 + rng:NextNumber() * 0.35
				local a = rng:NextNumber() * TAU
				local r = 1.2 + rng:NextNumber() * 1.1
				s.cf = CF(math.cos(a) * r, c.groundY + 0.4 + rng:NextNumber() * h, math.sin(a) * r)
					* ANG(0, -a + (rng:NextNumber() - 0.5), (rng:NextNumber() - 0.5) * 0.8)
				local sz = V(0.04, 0.2 + rng:NextNumber() * 0.9, 0.1 + rng:NextNumber() * 0.5)
				s.a.Size = sz
				s.b.Size = sz
			end
			local cf = root * s.cf
			Core.put(s.a, cf)
			Core.put(s.b, cf * CF(0.02, 0.03, if bursting then 0.18 else 0.07))
		end
		for k, sl in slices do
			if rng:NextNumber() < 0.06 then
				sliceY[k] = c.groundY + 0.5 + rng:NextNumber() * h
			end
			sl.Transparency = if bursting or rng:NextNumber() < 0.08 then 0.1 else 1
			Core.put(sl, root * CF((rng:NextNumber() - 0.5) * 0.3, sliceY[k], -0.7))
		end
		for _, g in glyphs do
			if t >= g.nextT then
				g.nextT = t + 0.06 + rng:NextNumber() * 0.25
				local a = rng:NextNumber() * TAU
				g.att.Position = V(math.cos(a) * 1.7, c.groundY + 0.6 + rng:NextNumber() * h, math.sin(a) * 1.7)
				g.lbl.Text = randChar(rng, "#%&@$/\\|<>=_")
				g.lbl.TextColor3 = if rng:NextNumber() < 0.5 then c.c1 else c.c2
				g.lbl.TextTransparency = if rng:NextNumber() < 0.3 then 1 else 0
			end
		end
		light.Color = if math.sin(t * 17) > 0 then c.c1 else c.c2
		light.Brightness = if bursting then 3 else 1.3
	end)
end

-- red horse-head glyph hologram above, red sparks
A.Trojan = function(c: Ctx)
	local rng = c.rng
	local yK = c.topY + 1.25
	local spec: { { V: Vector3, cf: CFrame, hi: boolean? } } = {
		{ V = V(0.9, 0.12, 0.5), cf = CF(0, 0, 0) },
		{ V = V(0.7, 0.1, 0.4), cf = CF(0, 0.11, 0) },
		{ V = V(0.42, 0.75, 0.32), cf = CF(-0.05, 0.5, 0) * ANG(0, 0, -0.15) },
		{ V = V(0.75, 0.34, 0.3), cf = CF(0.17, 0.95, 0) * ANG(0, 0, -0.45) },
		{ V = V(0.26, 0.2, 0.28), cf = CF(0.48, 0.75, 0) * ANG(0, 0, -0.6) },
		{ V = V(0.1, 0.28, 0.12), cf = CF(-0.08, 1.25, 0.07) * ANG(0, 0, 0.25) },
		{ V = V(0.1, 0.28, 0.12), cf = CF(-0.08, 1.25, -0.07) * ANG(0, 0, 0.25) },
		{ V = V(0.1, 0.72, 0.36), cf = CF(-0.29, 0.76, 0) * ANG(0, 0, -0.35), hi = true },
		{ V = V(0.07, 0.07, 0.34), cf = CF(0.2, 1.02, 0), hi = true },
	}
	local knight: { { p: BasePart, cf: CFrame, base: number } } = {}
	for _, s in spec do
		local base = if s.hi then 0.05 else 0.3
		local p = Core.part(c, s.V, if s.hi then c.c1:Lerp(WHITE, 0.5) else c.c1, NEON, base)
		table.insert(knight, { p = p, cf = s.cf, base = base })
	end
	local scan = Core.part(c, V(1.1, 0.03, 0.6), WHITE, NEON, 0.4)
	B.ring(c, {
		n = 12,
		radius = 0.75,
		seg = V(0.05, 0.05, 0),
		color = c.c1,
		spin = 1.5,
		anchor = function()
			return CF(0, yK - 0.08, 0)
		end,
	})
	B.circle(c, { radius = 0.95, color = c.c1, width = 0.04, at = CF(0, yK - 0.08, 0), tr = 0.35 })
	local headTop = Core.att(c, c.head, CF(0, c.head.Size.Y / 2, 0))
	for k = 1, 4 do
		local a = (k - 1) / 4 * TAU + math.pi / 4
		local top = Core.att(c, nil, CF(math.cos(a) * 0.9, yK - 0.08, math.sin(a) * 0.9))
		Core.beam(c, headTop, top, c.c1, 0.04, { w1 = 0.35, tr = ns(0.45, 0.88) })
	end
	local _, lbl = B.glyph(c, "TROJAN.EXE", c.c1, V2(1.9, 0.26), F.pixel, CF(0, yK + 1.55, 0), Color3.new(0.2, 0, 0))
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.fireSpark,
		color = cs(c.c1:Lerp(WHITE, 0.3), c.c1),
		size = ns(0.2, 0),
		rate = 14,
		life = nr(0.5, 0.9),
		speed = nr(2, 4),
		spread = V2(180, 180),
		accel = V(0, -3, 0),
		bright = 2.5,
	})
	Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.2, 0)), {
		tex = T.spark,
		color = cs(c.c1),
		size = ns(0.18, 0),
		transp = ns(0.2, 1),
		rate = 6,
		life = nr(1.4, 2.2),
		speed = nr(0.6, 1.2),
		spread = V2(50, 50),
	})
	local kl = Core.light(Core.att(c, nil, CF(0, yK + 0.6, 0)), c.c1, 2, 10)
	local flickUntil = 0
	Core.on(c, function(t, _, root)
		if rng:NextNumber() < 0.02 then
			flickUntil = t + 0.07 + rng:NextNumber() * 0.1
		end
		local fl = t < flickUntil
		local base = root * CF(0, yK, 0) * ANG(0, t * 0.9, 0)
		for _, k in knight do
			Core.put(k.p, base * k.cf)
			k.p.Transparency = if fl then 0.75 else k.base
		end
		local sy = (t * 0.8) % 1
		Core.put(scan, base * CF(0.05, sy * 1.35, 0))
		scan.Transparency = 0.3 + sy * 0.6
		lbl.Text = if (t % 1.8) < 0.9 then "TROJAN.EXE" else "GIFT.EXE"
		kl.Brightness = if fl then 0.6 else 2
	end)
end

-- ghostly pale rings and floating notification badges
A.PhantomPing = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local span = c.topY - g + 0.6
	local rings: { B.Circle } = {}
	for k = 1, 3 do
		local function ph(t: number): number
			return ((t + k) / 3) % 1
		end
		rings[k] = B.circle(c, {
			radius = 1.7,
			color = c.c1,
			width = 0.07,
			color2 = c.c2,
			anchor = function(t)
				return CF(0, g + ph(t) * span, 0)
			end,
			radiusFn = function(t)
				return 1.7 - ph(t) * 0.55
			end,
		})
	end
	B.ring(c, {
		n = 24,
		gap = 3,
		radius = 2.2,
		seg = V(0.04, 0.04, 0),
		color = c.c1,
		tr = 0.4,
		spin = -0.35,
		anchor = function(t)
			return CF(0, c.chestY - 0.3, 0) * ANG(0.15 * math.sin(t * 0.5), 0, 0.1)
		end,
	})
	type Badge = { att: Attachment, lbl: TextLabel, gui: BillboardGui, t0: number, life: number }
	local badges: { Badge } = {}
	local counts = { "1", "2", "3", "7", "9+", "99+", "!" }
	local function relocate(b: Badge, t: number)
		b.t0 = t
		b.life = 2.2 + rng:NextNumber() * 1.4
		local a = rng:NextNumber() * TAU
		local r = 1.1 + rng:NextNumber() * 0.9
		b.att.Position = V(math.cos(a) * r, c.headY + (rng:NextNumber() - 0.3) * 1.6, math.sin(a) * r)
		b.lbl.Text = Core.pick(counts, rng)
	end
	for i = 1, 5 do
		local att, lbl, gui = B.glyph(c, "1", WHITE, V2(0.55, 0.55), F.tech)
		lbl.BackgroundTransparency = 0.15
		lbl.BackgroundColor3 = c.c2
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = lbl
		local stroke = Instance.new("UIStroke")
		stroke.Color = c.c1
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = lbl
		local b: Badge = { att = att, lbl = lbl, gui = gui, t0 = 0, life = 1 }
		relocate(b, os.clock() - i * 0.6)
		badges[i] = b
	end
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.smoke,
		color = cs(c.c1),
		size = ns(1, 2.6),
		transp = ns(0.85, 1),
		rate = 3,
		life = nr(2, 3),
		speed = nr(0.3, 0.7),
		spread = V2(180, 180),
		rotSpeed = nr(-20, 20),
		light = 0.5,
	})
	Core.emit(Core.att(c, c.head), {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0, 0.22, 0),
		rate = 5,
		life = nr(0.8, 1.4),
		speed = nr(0.4, 0.9),
		spread = V2(180, 180),
	})
	local light = Core.light(torso, c.c1, 1, 10)
	Core.on(c, function(t)
		for k, r in rings do
			B.setBeamsTransparency(r.beams, 0.15 + (((t + k) / 3) % 1) * 0.85)
		end
		for _, b in badges do
			local age = t - b.t0
			if age > b.life then
				relocate(b, t)
				age = 0
			end
			local s
			if age < 0.18 then
				local f = age / 0.18
				s = 1.25 * math.sin(f * math.pi * 0.5) ^ 0.5
			elseif age < 0.3 then
				s = 1.25 - (age - 0.18) / 0.12 * 0.25
			else
				s = 1
			end
			local fade = math.clamp((age - (b.life - 0.35)) / 0.35, 0, 1)
			b.gui.Size = UDim2.new(0.55 * s, 0, 0.55 * s, 0)
			b.lbl.TextTransparency = fade
			b.lbl.BackgroundTransparency = 0.15 + fade * 0.85
			b.att.Position += V(0, 0.003, 0)
		end
		light.Brightness = 0.8 + Core.pulse(t, 3) * 0.8
	end)
end

-- magenta neon tubes spiralling up the body, pulsing
A.NeonPulse = function(c: Ctx)
	local nSeg = 15
	local turns = 2.1
	local r = 1.35
	local y0 = c.groundY + 0.2
	local y1 = c.topY + 0.4
	type Seg = { p: BasePart, cf: CFrame, s: number }
	local segs: { Seg } = {}
	for h = 1, 2 do
		local ph0 = (h - 1) * math.pi
		local function pt(k: number): Vector3
			local f = k / nSeg
			local a = ph0 + f * turns * TAU
			return V(math.cos(a) * r, y0 + f * (y1 - y0), math.sin(a) * r)
		end
		for k = 0, nSeg - 1 do
			local p0, p1 = pt(k), pt(k + 1)
			local len = (p1 - p0).Magnitude
			local p = Core.part(c, V(len + 0.05, 0.14, 0.14), c.c1, NEON, 0, CYL)
			local cf = CFrame.lookAt((p0 + p1) / 2, p1) * ANG(0, math.pi / 2, 0)
			table.insert(segs, { p = p, cf = cf, s = (k + 0.5) / nSeg })
		end
	end
	local caps: { { p: BasePart, cf: CFrame } } = {}
	for h = 1, 2 do
		local ph0 = (h - 1) * math.pi
		local a1 = ph0 + turns * TAU
		table.insert(
			caps,
			{
				p = Core.part(c, V(0.28, 0.28, 0.28), c.c2, NEON, 0, BALL),
				cf = CF(math.cos(ph0) * r, y0, math.sin(ph0) * r),
			}
		)
		table.insert(
			caps,
			{
				p = Core.part(c, V(0.28, 0.28, 0.28), c.c2, NEON, 0, BALL),
				cf = CF(math.cos(a1) * r, y1, math.sin(a1) * r),
			}
		)
	end
	B.circle(c, { radius = r, color = c.c1, width = 0.05, at = CF(0, y0, 0), tr = 0.3 })
	B.circle(c, { radius = r, color = c.c1, width = 0.05, at = CF(0, y1, 0), tr = 0.3 })
	local function pulsePos(t: number): number
		return (t * 0.7) % 1.3 - 0.15
	end
	local pr = B.circle(c, {
		radius = r + 0.08,
		color = c.c2,
		width = 0.1,
		anchor = function(t)
			return CF(0, y0 + math.clamp(pulsePos(t), 0, 1) * (y1 - y0), 0)
		end,
	})
	local feet = Core.att(c, c.root, CF(0, y0, 0))
	Core.emit(feet, {
		tex = T.spark,
		color = cs(c.c1, c.c2),
		size = ns(0.25, 0),
		rate = 8,
		life = nr(1, 1.6),
		speed = nr(1, 2),
		spread = V2(35, 35),
		accel = V(0, 1, 0),
	})
	local light = Core.light(Core.att(c, c.torso), c.c1, 1.5, 11)
	Core.on(c, function(t, _, root)
		local base = root * ANG(0, t * 0.8, 0)
		local u = pulsePos(t)
		for _, s in segs do
			Core.put(s.p, base * s.cf)
			local d = (s.s - u) / 0.09
			local k = math.exp(-d * d)
			s.p.Color = c.c1:Lerp(WHITE, k * 0.75)
		end
		for _, cp in caps do
			Core.put(cp.p, base * cp.cf)
		end
		local vis = if u < 0 or u > 1 then 1 else 0.1
		B.setBeamsTransparency(pr.beams, vis)
		light.Brightness = 1 + (1 - math.abs(u - 0.5) * 2) * 1.5
	end)
end

-- swarm of small drones linked with beams
A.Botnet = function(c: Ctx)
	local rng = c.rng
	type Drone = { body: BasePart, eye: BasePart, rotor: BasePart, att: Attachment, blink: number }
	local drones: { Drone } = {}
	local shell = Color3.fromRGB(14, 20, 16)
	for i = 1, 8 do
		drones[i] = {
			body = Core.part(c, V(0.42, 0.08, 0.42), shell, METAL),
			eye = Core.part(c, V(0.13, 0.13, 0.13), c.c1, NEON, 0, BALL),
			rotor = Core.part(c, V(0.56, 0.02, 0.05), c.c1, NEON, 0.2),
			att = Core.att(c),
			blink = 0,
		}
	end
	local headAtt = Core.att(c, nil, CF(0, c.topY + 0.9, 0))
	for i = 1, 8 do
		local nxt = drones[i % 8 + 1]
		Core.beam(
			c,
			drones[i].att,
			nxt.att,
			c.c1,
			0.04,
			{ tex = T.square, texLen = 0.3, texSpeed = 2.5, tr = ns(0.25) }
		)
		if i % 3 == 1 then
			Core.beam(
				c,
				drones[i].att,
				headAtt,
				c.c2:Lerp(c.c1, 0.4),
				0.025,
				{ tr = ns(0.2, 0.6), tex = T.square, texLen = 0.25, texSpeed = -3 }
			)
		end
	end
	local cmd = Core.part(c, V(0.3, 0.3, 0.3), c.c1)
	B.circle(c, { radius = 0.42, color = c.c1, width = 0.04, at = CF(0, c.topY + 0.75, 0), tr = 0.2 })
	Core.emit(headAtt, {
		tex = T.square,
		color = cs(c.c1),
		size = ns(0.09, 0),
		rate = 8,
		life = nr(0.5, 0.8),
		speed = nr(2.5, 4),
		spread = V2(70, 70),
		dir = Enum.NormalId.Bottom,
		rot = nr(0, 0),
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(c.c1),
		size = ns(0.16, 0),
		rate = 5,
		life = nr(0.6, 1),
		speed = nr(1, 2),
		spread = V2(180, 180),
	})
	Core.light(headAtt, c.c1, 1.2, 10)
	Core.on(c, function(t, _, root)
		for i, d in drones do
			local a = (i - 1) / 8 * TAU + t * 0.5
			local r = 2.4 + math.noise(i * 1.7, t * 0.4) * 1.6
			local y = c.chestY + 0.5 + math.noise(i * 3.1, t * 0.5 + 9) * 2.2
			local pos = V(math.cos(a) * r, y, math.sin(a) * r)
			d.att.Position = pos
			local tilt = math.noise(i, t) * 0.5
			local cf = root * CF(pos) * ANG(tilt, -a, tilt * 0.6)
			Core.put(d.body, cf)
			Core.put(d.eye, cf * CF(0, -0.07, 0))
			Core.put(d.rotor, cf * CF(0, 0.07, 0) * ANG(0, t * 40 + i, 0))
			if t > d.blink then
				d.blink = t + 0.4 + rng:NextNumber() * 2.5
				d.eye.Transparency = if d.eye.Transparency > 0.5 then 0 else 0.85
			end
		end
		Core.put(cmd, root * CF(0, c.topY + 0.9, 0) * ANG(t * 1.2, t * 1.7, t * 0.5))
	end)
end

-- golden rotating cipher rings with symbols
A.Cryptic = function(c: Ctx)
	local rng = c.rng
	local gold = c.c1
	local deep = c.c1:Lerp(c.c2, 0.45)
	local y = c.chestY
	B.ring(c, {
		n = 18,
		radius = 2.1,
		seg = V(0.05, 0.16, 0.14),
		color = gold,
		color2 = deep,
		spin = 0.5,
		anchor = function()
			return CF(0, y, 0)
		end,
		paint = function(k, t, p)
			p.Transparency = if ((k + math.floor(t * 6)) % 6) == 0 then 0 else 0.15
		end,
	})
	B.circle(c, { radius = 2.1, color = gold, width = 0.04, at = CF(0, y, 0), tr = 0.25 })
	B.circle(c, { radius = 2.28, color = deep, width = 0.03, at = CF(0, y, 0), tr = 0.5 })
	type GRing = { r: number, tilt: number, spd: number, phrase: string, glyphs: { TextLabel }, atts: { Attachment } }
	local grings: { GRing } = {
		{ r = 1.8, tilt = 1.05, spd = 0.8, phrase = "ENCRYPTED!", glyphs = {}, atts = {} },
		{ r = 2.45, tilt = -1.05, spd = -0.55, phrase = "XOR-AES256", glyphs = {}, atts = {} },
	}
	for _, gr in grings do
		local yy = y + 0.2
		local tl = gr.tilt
		B.circle(c, {
			radius = gr.r,
			color = gold,
			width = 0.035,
			tr = 0.3,
			anchor = function(t)
				return CF(0, yy, 0) * ANG(0, t * 0.3, 0) * ANG(tl, 0, 0)
			end,
		})
		for i = 1, 10 do
			local att, lbl = B.glyph(c, "A", deep, V2(0.42, 0.42), F.tech, nil, Color3.fromRGB(40, 25, 0))
			gr.atts[i] = att
			gr.glyphs[i] = lbl
		end
	end
	-- floating golden key
	local key = {
		{ p = Core.part(c, V(0.07, 0.36, 0.36), gold, NEON, 0, CYL), cf = CF(0, 0, 0) },
		{ p = Core.part(c, V(0.08, 0.17, 0.17), c.c2, SMOOTH, 0, CYL), cf = CF(0, 0, 0) },
		{ p = Core.part(c, V(0.07, 0.07, 0.62), gold), cf = CF(0, 0, 0.45) },
		{ p = Core.part(c, V(0.06, 0.16, 0.06), gold), cf = CF(0, -0.09, 0.62) },
		{ p = Core.part(c, V(0.06, 0.11, 0.06), gold), cf = CF(0, -0.07, 0.72) },
	}
	local _, lock =
		B.glyph(c, "[LOCKED]", gold, V2(1.7, 0.3), F.tech, CF(0, c.topY + 0.7, 0), Color3.fromRGB(60, 35, 0))
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(gold, WHITE),
		size = ns(0, 0.25, 0),
		rate = 7,
		life = nr(1, 1.8),
		speed = nr(0.5, 1.2),
		spread = V2(180, 180),
	})
	local light = Core.light(Core.att(c, c.torso), gold, 1.4, 11)
	local nextS = 0
	Core.on(c, function(t, _, root)
		local cyc = t % 4
		local decrypt = cyc > 3
		if t >= nextS then
			nextS = t + 0.09
			for _, gr in grings do
				for i, lbl in gr.glyphs do
					if decrypt and ((cyc - 3) * 14 > i) then
						lbl.Text = string.sub(gr.phrase, i, i)
						lbl.TextColor3 = WHITE:Lerp(gold, 0.3)
					elseif rng:NextNumber() < 0.45 then
						lbl.Text = randChar(rng, SCRAMBLE)
						lbl.TextColor3 = deep:Lerp(gold, rng:NextNumber())
					end
				end
			end
		end
		for _, gr in grings do
			local anchor = CF(0, y + 0.2, 0) * ANG(0, t * 0.3, 0) * ANG(gr.tilt, 0, 0)
			for i, att in gr.atts do
				local a = (i - 1) / 10 * TAU + t * gr.spd
				att.Position = (anchor * CF(math.cos(a) * gr.r, 0, math.sin(a) * gr.r)).Position
			end
		end
		local kcf = root * CF(0, c.chestY + 0.15 + math.sin(t * 1.5) * 0.1, -1.25) * ANG(0, t * 1.1, 0.4)
		for _, k in key do
			Core.put(k.p, kcf * k.cf)
		end
		lock.Text = if decrypt then "[ACCESS?]" else "[LOCKED]"
		light.Brightness = if decrypt then 2.4 else 1.3
	end)
end

---------------------------------------------------------------- EPIC

-- purple roots of light crawling up from the ground
A.Rootkit = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local disc = Core.part(c, V(0.04, 4.8, 4.8), c.c2:Lerp(c.c1, 0.25), NEON, 0.3, CYL)
	local cracks: { { beams: { Beam }, off: number } } = {}
	for k = 1, 8 do
		local a = (k - 1) / 8 * TAU + rng:NextNumber() * 0.5
		local pts = {}
		local rad = 0.4
		for j = 0, 4 do
			a += (rng:NextNumber() - 0.5) * 0.6
			table.insert(pts, V(math.cos(a) * rad, g + 0.05, math.sin(a) * rad))
			rad += 0.55 + rng:NextNumber() * 0.25
		end
		local poly = B.poly(c, pts, c.c1, 0.08, { w1 = 0.05, segs = 1 })
		table.insert(cracks, { beams = poly.beams, off = rng:NextNumber() })
	end
	type Tendril = { segs: { BasePart }, tip: BasePart, a: number, h: number, turn: number, off: number }
	local tendrils: { Tendril } = {}
	local NS = 7
	for k = 1, 5 do
		local segs = {}
		for i = 1, NS do
			segs[i] = Core.part(c, V(0.15, 0.15, 0.4), c.c1, NEON, 0, CYL)
		end
		tendrils[k] = {
			segs = segs,
			tip = Core.part(c, V(0.2, 0.2, 0.2), WHITE, NEON, 0, BALL),
			a = (k - 1) / 5 * TAU + rng:NextNumber() * 0.6,
			h = c.chestY + rng:NextNumber() * (c.headY - c.chestY + 0.3),
			turn = (1.3 + rng:NextNumber() * 0.7) * (if k % 2 == 0 then 1 else -1),
			off = k * 0.9,
		}
	end
	local vol = Core.volume(c, V(3.5, 0.1, 3.5), CF(0, g + 0.1, 0))
	Core.emit(vol, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0, 0.2, 0),
		rate = 8,
		life = nr(2, 3),
		speed = nr(0.4, 0.9),
		accel = V(0, 0.3, 0),
		shape = Enum.ParticleEmitterShape.Box,
	})
	local _, g1 = B.glyph(c, "root#", c.c1, V2(1, 0.22), F.mono, CF(1.4, g + 0.25, -1.1))
	local _, g2 = B.glyph(c, "sudo -s", c.c1, V2(1.2, 0.22), F.mono, CF(-1.5, g + 0.25, 0.9))
	local light = Core.light(Core.att(c, c.root, CF(0, g + 0.5, 0)), c.c1, 1.6, 10)
	local function pt(td: Tendril, s: number, t: number): Vector3
		local a = td.a + s * td.turn + math.sin(t * 1.3 + td.off + s * 3) * 0.1
		local r = 1.6 - s * 0.75 + math.noise(td.off, s * 2, t * 0.6) * 0.25
		return V(math.cos(a) * r, g + 0.05 + s * (td.h - g), math.sin(a) * r)
	end
	Core.on(c, function(t, _, root)
		Core.put(disc, root * CF(0, g + 0.02, 0) * FLAT)
		for _, ck in cracks do
			for j, bm in ck.beams do
				local w = (((t * 0.8 + ck.off) % 1) * 5 - j)
				bm.Transparency = NumberSequence.new(math.clamp(0.55 - math.exp(-w * w) * 0.55, 0, 1))
			end
		end
		for _, td in tendrils do
			local ph = ((t + td.off) / 4.5) % 1
			local grow = math.min(1, ph / 0.35)
			local fade = math.clamp((ph - 0.8) / 0.2, 0, 1)
			local pulse = (t * 1.2 + td.off * 0.3) % 1.4 - 0.2
			local last = pt(td, 0, t)
			for i, p in td.segs do
				local s0 = (i - 1) / NS
				local s1 = math.min(i / NS, grow)
				if s0 >= grow then
					p.Transparency = 1
					Core.put(p, root * CF(last))
				else
					local p0 = pt(td, s0, t)
					local p1 = pt(td, s1, t)
					local len = math.max((p1 - p0).Magnitude, 0.02)
					local th = 0.17 * (1 - s0 * 0.7)
					p.Size = V(len + 0.04, th, th)
					local d = (s0 - pulse) / 0.12
					p.Color = c.c1:Lerp(WHITE, math.exp(-d * d) * 0.65)
					p.Transparency = fade
					Core.put(p, root * CFrame.lookAt((p0 + p1) / 2, p1) * ANG(0, math.pi / 2, 0))
					last = p1
				end
			end
			Core.put(td.tip, root * CF(last))
			td.tip.Transparency = math.max(fade, if grow < 1 then 0 else 0.3)
		end
		g1.TextTransparency = if math.noise(t * 2, 1) > 0.2 then 0.8 else 0.1
		g2.TextTransparency = if math.noise(t * 2, 7) > 0.2 then 0.8 else 0.1
		light.Brightness = 1.2 + Core.pulse(t, 2.2) * 1.2
	end)
end

-- green code rain swirling as a tornado
A.Datastorm = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local H = c.topY - g + 2.4
	type Gl = { att: Attachment, lbl: TextLabel, off: number }
	local glyphs: { Gl } = {}
	for i = 1, 24 do
		local att, lbl = B.glyph(c, "0", c.c1, V2(0.36, 0.36), F.pixel, nil, c.c2)
		glyphs[i] = { att = att, lbl = lbl, off = (i - 1) / 24 }
	end
	local streaks: { BasePart } = {}
	for i = 1, 14 do
		streaks[i] = Core.part(c, V(0.05, 0.75, 0.05), c.c1, NEON, 0.2)
	end
	for k = 1, 4 do
		local f = (k - 1) / 3
		B.circle(c, {
			radius = 0.8 + f * 2.6,
			color = c.c1,
			width = 0.05,
			tr = 0.55,
			anchor = function(t)
				return CF(math.sin(t * 1.3 + k) * 0.12 * f, g + 0.2 + f * H, math.cos(t * 1.1 + k) * 0.12 * f)
			end,
		})
	end
	local sky = Core.att(c, c.root, CF(0, c.topY + 4, 0))
	Core.emit(sky, {
		tex = T.square,
		color = cs(c.c1:Lerp(WHITE, 0.3), c.c1),
		size = ns(0.07),
		transp = ns(0.2, 0.6),
		rate = 22,
		life = nr(0.45, 0.6),
		speed = nr(14, 18),
		spread = V2(28, 28),
		dir = Enum.NormalId.Bottom,
		orient = Enum.ParticleOrientation.VelocityParallel,
		squash = ns(2.5),
	})
	Core.emit(Core.att(c, c.root, CF(0, g + 0.1, 0)), {
		tex = T.smoke,
		color = cs(c.c1, c.c2),
		size = ns(1.2, 3),
		transp = ns(0.8, 1),
		rate = 5,
		life = nr(1, 1.6),
		speed = nr(2, 3),
		spread = V2(85, 85),
		rotSpeed = nr(-60, 60),
		light = 0.6,
	})
	local bl = Core.light(Core.att(c, c.root, CF(0, c.topY, 0)), c.c1, 1.4, 12)
	local boltEnd = V(2, g, 0)
	B.bolt(c, {
		segs = 7,
		color = WHITE,
		color2 = c.c1,
		width = 0.13,
		jitter = 0.5,
		interval = 0.05,
		active = function(t)
			return (t % 3.7) < 0.28
		end,
		ends = function(t)
			if (t % 3.7) < 0.03 then
				local a = rng:NextNumber() * TAU
				boltEnd = V(math.cos(a) * 2.6, g, math.sin(a) * 2.6)
			end
			return V(0, g + H, 0), boltEnd
		end,
	})
	local nextT = 0
	Core.on(c, function(t, _, root)
		local change = t >= nextT
		if change then
			nextT = t + 0.08
		end
		for i, gl in glyphs do
			local u = (t * 0.22 + gl.off) % 1
			local a = i * 2.39 + t * (3 - u * 1.4)
			local r = 0.8 + u * 2.6
			gl.att.Position = V(math.cos(a) * r, g + 0.2 + u * H, math.sin(a) * r)
			gl.lbl.TextTransparency = 1 - math.sin(u * math.pi) ^ 0.5
			if change and rng:NextNumber() < 0.35 then
				gl.lbl.Text = randChar(rng, "0123456789ABCDEF<>{}#$")
			end
		end
		for i, p in streaks do
			local u = (t * 0.3 + i / 14) % 1
			local a = i * 1.7 + t * (3.4 - u * 1.4)
			local r = 0.75 + u * 2.6
			Core.put(p, root * CF(math.cos(a) * r, g + 0.3 + u * H, math.sin(a) * r) * ANG(0, -a, 0) * ANG(0.9, 0, 0))
			p.Transparency = 1 - math.sin(u * math.pi) * 0.85
		end
		bl.Brightness = if (t % 3.7) < 0.28 then 4 else 1.3
	end)
end

-- scanlines sweeping the body, blue projector cone from below
A.Hologram = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local base = Core.part(c, V(0.12, 2.4, 2.4), Color3.fromRGB(18, 22, 32), METAL, 0, CYL)
	local lens = Core.part(c, V(0.36, 0.36, 0.36), c.c1, NEON, 0, BALL)
	B.ring(c, {
		n = 16,
		radius = 1.25,
		seg = V(0.08, 0.06, 0),
		color = c.c1,
		color2 = c.c2,
		spin = 0.6,
		anchor = function()
			return CF(0, g + 0.14, 0)
		end,
	})
	local lensAtt = Core.att(c, c.root, CF(0, g + 0.2, 0))
	for k = 1, 8 do
		local a = (k - 1) / 8 * TAU
		local top = Core.att(c, nil, CF(math.cos(a) * 1.5, c.topY + 0.3, math.sin(a) * 1.5))
		Core.beam(c, lensAtt, top, c.c1, 0.08, { w1 = 0.95, tr = ns(0.55, 0.93), color2 = c.c2, segs = 4 })
	end
	local gx, gUntil = 0, 0
	local skin = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = FF,
		scale = 1.03,
		map = function(cf, root)
			if gx == 0 then
				return cf
			end
			return root * CF(gx, 0, 0) * root:ToObjectSpace(cf)
		end,
	})
	local discs: { BasePart } = {}
	for k = 1, 3 do
		discs[k] = Core.part(c, V(0.025, 2.6, 2.6), c.c2, NEON, 0.75, CYL)
	end
	Core.emit(lensAtt, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.08, 0.04),
		transp = ns(0.1, 1),
		rate = 10,
		life = nr(1.2, 1.8),
		speed = nr(1.5, 2.5),
		spread = V2(18, 18),
		rot = nr(0, 0),
	})
	local light = Core.light(lensAtt, c.c1, 1.6, 11)
	local span = c.topY - g + 0.2
	Core.on(c, function(t, _, root)
		if rng:NextNumber() < 0.015 then
			gUntil = t + 0.1
		end
		gx = if t < gUntil then (rng:NextNumber() - 0.5) * 0.5 else 0
		local fl = if t < gUntil then 0.6 else 0
		for _, p in skin do
			p.Transparency = fl
		end
		Core.put(base, root * CF(0, g + 0.06, 0) * FLAT)
		Core.put(lens, root * CF(0, g + 0.2, 0))
		for k, d in discs do
			local u = (t * 0.45 + k / 3) % 1
			Core.put(d, root * CF(0, g + u * span, 0) * FLAT)
			d.Transparency = 0.6 + 0.4 * math.abs(u - 0.5) * 2
		end
		light.Brightness = 1.3 + math.noise(t * 4, 2) * 0.8
	end)
end

-- black-red countdown digits orbiting, red lightning
A.ZeroDay = function(c: Ctx)
	local rng = c.rng
	local prefixes = { "T-", "ETA ", "0DAY ", "PATCH ", "CVE ", "EXP " }
	type Plate = { body: BasePart, top: BasePart, bot: BasePart, lbl: TextLabel }
	local plates: { Plate } = {}
	for i = 1, 6 do
		local body = Core.part(c, V(0.95, 0.5, 0.06), Color3.fromRGB(8, 8, 10), SMOOTH)
		local sg = Core.surface(body, Enum.NormalId.Front, 120)
		local lbl = Core.label(sg, "", c.c1, F.pixel, UDim2.fromScale(0.05, 0.2), UDim2.fromScale(0.9, 0.6))
		plates[i] = {
			body = body,
			top = Core.part(c, V(0.95, 0.04, 0.07), c.c1),
			bot = Core.part(c, V(0.95, 0.04, 0.07), c.c1),
			lbl = lbl,
		}
	end
	local function strike(t: number): boolean
		return (t % 10) > 9.6
	end
	for k = 1, 3 do
		local fromP, toP = V(0, 10, 0), Vector3.zero
		B.bolt(c, {
			segs = 9,
			color = WHITE,
			color2 = c.c1,
			width = 0.22,
			jitter = 0.7,
			interval = 0.045,
			flicker = 0.2,
			active = strike,
			ends = function()
				if rng:NextNumber() < 0.3 then
					local a = rng:NextNumber() * TAU
					local r = 1.4 + rng:NextNumber() * 1.6
					toP = V(math.cos(a) * r, c.groundY, math.sin(a) * r)
					fromP = toP + V((rng:NextNumber() - 0.5) * 3, 9 + k, (rng:NextNumber() - 0.5) * 3)
				end
				return fromP, toP
			end,
		})
	end
	B.bolt(c, {
		segs = 6,
		color = c.c1,
		width = 0.07,
		jitter = 0.25,
		interval = 0.08,
		flicker = 0.35,
		ends = function()
			local a1 = rng:NextNumber() * TAU
			local a2 = a1 + 1 + rng:NextNumber() * 2
			local y1 = c.groundY + 0.5 + rng:NextNumber() * (c.topY - c.groundY)
			local y2 = c.groundY + 0.5 + rng:NextNumber() * (c.topY - c.groundY)
			return V(math.cos(a1) * 0.9, y1, math.sin(a1) * 0.9), V(math.cos(a2) * 0.9, y2, math.sin(a2) * 0.9)
		end,
	})
	local feet = Core.volume(c, V(2.6, 0.1, 2.6), CF(0, c.groundY + 0.1, 0))
	Core.emit(feet, {
		tex = T.fireSpark,
		color = cs(c.c1),
		size = ns(0.16, 0),
		rate = 10,
		life = nr(1, 1.6),
		speed = nr(1, 2),
		accel = V(0, 0.5, 0),
		shape = Enum.ParticleEmitterShape.Box,
		bright = 2,
	})
	Core.emit(feet, {
		tex = T.smoke,
		color = cs(Color3.fromRGB(10, 0, 0)),
		size = ns(1.2, 2.4),
		transp = ns(0.6, 1),
		rate = 4,
		life = nr(1.5, 2.5),
		speed = nr(0.3, 0.6),
		light = 0,
		rotSpeed = nr(-30, 30),
		shape = Enum.ParticleEmitterShape.Box,
	})
	local light = Core.light(Core.att(c, c.torso), c.c1, 1.4, 12)
	Core.on(c, function(t, _, root)
		local rem = 10 - (t % 10)
		local st = strike(t)
		local anchor = root * CF(0, c.chestY, 0) * ANG(0.25, 0, 0.1)
		for i, p in plates do
			local a = (i - 1) / 6 * TAU + t * 0.5
			local cf = anchor * outward(a, 2.2, math.sin(t * 2 + i) * 0.08)
			Core.put(p.body, cf)
			Core.put(p.top, cf * CF(0, 0.27, 0))
			Core.put(p.bot, cf * CF(0, -0.27, 0))
			if st then
				p.lbl.Text = if math.sin(t * 50) > 0 then "0DAY" else ""
			else
				p.lbl.Text = prefixes[i] .. string.format("%04.1f", rem)
			end
		end
		light.Brightness = if st then 5 + rng:NextNumber() * 4 else 1.2 + Core.pulse(t, 1) * 0.6
	end)
end

-- dark smoke aura with red emergency strobes
A.Blackout = function(c: Ctx)
	local rng = c.rng
	local smoke: Core.EmitSpec = {
		tex = T.smoke,
		color = cs(Color3.fromRGB(6, 4, 6), Color3.fromRGB(28, 4, 6)),
		size = ns(1.5, 3.6),
		transp = ns(0.5, 0.75, 1),
		rate = 10,
		life = nr(2, 3),
		speed = nr(0.5, 1.2),
		spread = V2(70, 70),
		accel = V(0, 0.6, 0),
		rotSpeed = nr(-30, 30),
		light = 0,
		bright = 1,
	}
	Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.3, 0)), smoke)
	smoke.spread = V2(180, 180)
	smoke.rate = 7
	Core.emit(Core.att(c, c.torso), smoke)
	local yb = c.topY + 0.85
	local metal = Color3.fromRGB(22, 22, 26)
	local base = Core.part(c, V(0.14, 0.55, 0.55), metal, METAL, 0, CYL)
	local dome = Core.part(c, V(0.44, 0.44, 0.44), c.c1, NEON, 0.35, BALL)
	local refl = Core.part(c, V(0.05, 0.28, 0.14), WHITE, NEON, 0)
	local spotAtt = Core.att(c, nil, CF(0, yb + 0.2, 0))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local s = Instance.new("SpotLight")
		s.Face = face
		s.Angle = 50
		s.Range = 18
		s.Brightness = 7
		s.Color = c.c1
		s.Shadows = false
		s.Parent = spotAtt
	end
	local torso = Core.att(c, c.torso)
	local strobe = Core.light(torso, c.c1, 0, 14)
	local n = 14
	local ring = B.ring(c, {
		n = n,
		radius = 1.75,
		seg = V(0.1, 0.06, 0),
		color = c.c2:Lerp(c.c1, 0.2),
		anchor = function()
			return CF(0, c.groundY + 0.04, 0)
		end,
	})
	local leds: { BasePart } = {}
	for i = 1, 4 do
		leds[i] = Core.part(c, V(0.1, 0.1, 0.1), c.c1)
	end
	local sparkAtt = Core.att(c, c.torso)
	local sparks = Core.emit(sparkAtt, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0.25, 0),
		rate = 0,
		life = nr(0.2, 0.45),
		speed = nr(5, 9),
		spread = V2(180, 180),
		accel = V(0, -20, 0),
		bright = 3,
	})
	local _, sign =
		B.glyph(c, "GRID://OFFLINE", c.c1, V2(1.9, 0.24), F.pixel, CF(0, yb + 0.7, 0), Color3.new(0.15, 0, 0))
	local nextSpark = 0
	Core.on(c, function(t, _, root)
		local bcf = root * CF(0, yb, 0)
		Core.put(base, bcf * FLAT)
		Core.put(dome, bcf * CF(0, 0.15, 0))
		Core.put(refl, bcf * CF(0, 0.17, 0) * ANG(0, t * 6, 0))
		spotAtt.CFrame = CF(0, yb + 0.17, 0) * ANG(0, t * 6, 0)
		local ph = t % 1.2
		local on = ph < 0.06 or (ph > 0.14 and ph < 0.2)
		strobe.Brightness = if on then 7 else 0
		dome.Transparency = if on then 0 else 0.35
		local head = (t * 10) % n
		for k, p in ring do
			local d = (head - (k - 1)) % n
			p.Color = c.c2:Lerp(c.c1, math.exp(-d * 0.6))
		end
		for i, p in leds do
			local a = (i - 1) / 4 * TAU - t * 0.8
			Core.put(p, root * CF(math.cos(a) * 1.25, -0.2 + math.sin(t + i) * 0.3, math.sin(a) * 1.25))
			p.Transparency = if math.sin(t * 5 + i * 2) > 0.3 then 0 else 0.9
		end
		if t >= nextSpark then
			nextSpark = t + 0.6 + rng:NextNumber() * 1.6
			sparkAtt.Position =
				V((rng:NextNumber() - 0.5) * 1.6, (rng:NextNumber() - 0.5) * 1.6, (rng:NextNumber() - 0.5) * 0.6)
			sparks:Emit(rng:NextInteger(5, 10))
		end
		sign.TextTransparency = if math.noise(t * 3, 3) > 0.25 then 0.85 else 0.05
	end)
end

-- rainbow-cycling prism rings and colour-split ghosts
A.Chromatic = function(c: Ctx)
	B.ring(c, {
		n = 16,
		radius = 2,
		seg = V(0.08, 0.1, 0),
		color = c.c1,
		spin = 1.2,
		anchor = function()
			return CF(0, -0.2, 0)
		end,
		paint = function(k, t, p)
			p.Color = Color3.fromHSV((k / 16 + t * 0.25) % 1, 0.85, 1)
		end,
	})
	B.ring(c, {
		n = 14,
		radius = 1.7,
		seg = V(0.07, 0.09, 0),
		color = c.c2,
		spin = -1.6,
		anchor = function(t)
			return CF(0, c.chestY + 0.1, 0) * ANG(0, -t * 0.4, 0) * ANG(1.2, 0, 0)
		end,
		paint = function(k, t, p)
			p.Color = Color3.fromHSV((k / 14 + t * 0.25 + 0.5) % 1, 0.85, 1)
		end,
	})
	local g1 = B.clones(c, { set = "lite", color = c.c1, mat = NEON, tr = 0.72, delay = 0.08 })
	local g2 = B.clones(c, { set = "lite", color = c.c2, mat = NEON, tr = 0.78, delay = 0.17 })
	local yP = c.topY + 1
	local prism = B.tri(c, 0.6, 0.06, WHITE)
	local center = Core.att(c, nil, CF(0, yP, 0))
	local src = Core.att(c, nil, CF(-1.7, yP + 0.25, 0))
	Core.beam(c, src, center, WHITE, 0.06, { tr = ns(0.6, 0) })
	for k = 1, 4 do
		local out = Core.att(c, nil, CF(1.6, yP - 0.3 + (k - 1) * 0.2, 0))
		Core.beam(c, center, out, Color3.fromHSV((k - 1) / 4 * 0.75, 1, 1), 0.04, { w1 = 0.12, tr = ns(0, 0.7) })
	end
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = Core.rainbow(6),
		size = ns(0.25, 0),
		rate = 10,
		life = nr(0.8, 1.4),
		speed = nr(1, 2),
		spread = V2(180, 180),
	})
	local light = Core.light(Core.att(c, c.torso), c.c1, 1.6, 11)
	Core.on(c, function(t, _, root)
		local h = (t * 0.25) % 1
		local ca = Color3.fromHSV(h, 0.9, 1)
		local cb = Color3.fromHSV((h + 0.33) % 1, 0.9, 1)
		for _, p in g1 do
			p.Color = ca
		end
		for _, p in g2 do
			p.Color = cb
		end
		B.putTri(prism, root * CF(0, yP, 0) * ANG(0, t * 1.4, 0), 0.6)
		light.Color = ca
	end)
end

return A
