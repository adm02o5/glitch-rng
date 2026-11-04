--!strict
-- AuraFX/AurasMid: RARE and EPIC tier auras.
-- Rare: ~3-5 stud radius, Epic: ~4-6 stud radius; every aura has a silhouette-breaking
-- element, readable particles and a coloured root light so it reads from the gameplay camera.

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
local METAL = Enum.Material.Metal
local FLAT = ANG(0, 0, math.pi / 2)
local BOX = Enum.ParticleEmitterShape.Box

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

-- root-local frame on a horizontal circle whose -Z (Front face) points outward
local function outward(a: number, r: number, y: number): CFrame
	return ANG(0, -a, 0) * CF(r, y, 0) * ANG(0, -math.pi / 2, 0)
end

local SCRAMBLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$%&@"
local function randChar(rng: Random, set: string): string
	local k = rng:NextInteger(1, #set)
	return string.sub(set, k, k)
end

-- Coloured PointLight on the HumanoidRootPart (tints the character and the floor).
local function rootLight(c: Ctx, color: Color3, bright: number, range: number, y: number?): PointLight
	return Core.light(Core.att(c, c.root, CF(0, y or 0, 0)), color, bright, range)
end

-- Soft glow sprite locked to the torso, drawn behind the body.
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

-- Horizontal unit vectors (root-local): towards the camera, and to its right.
local function camAxes(root: CFrame): (Vector3, Vector3)
	local cl = root:PointToObjectSpace(camPos())
	local fl = V(cl.X, 0, cl.Z)
	local d = if fl.Magnitude > 1e-3 then fl.Unit else V(0, 0, -1)
	return d, V(-d.Z, 0, d.X)
end

local A: { [string]: (Ctx) -> () } = {}

---------------------------------------------------------------- RARE

-- cyan/magenta RGB-split shards jittering around the body (the signature aura)
-- 47 parts / 5 emitters
A.Glitch = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local h = c.topY - g
	local cyan, mag = c.c1, c.c2
	local ox, oy, oz, yaw = 0.14, 0, 0, 0
	local burstUntil, nextBurst = 0, 0
	-- RGB-split ghost copies of the body
	local ghostA = B.clones(c, {
		set = "lite",
		color = cyan,
		mat = NEON,
		tr = 0.6,
		scale = 1.03,
		map = function(cf, root)
			return root * CF(-ox, oy, oz) * ANG(0, yaw, 0) * root:ToObjectSpace(cf)
		end,
	})
	local ghostB = B.clones(c, {
		set = "lite",
		color = mag,
		mat = NEON,
		tr = 0.6,
		scale = 1.03,
		map = function(cf, root)
			return root * CF(ox, -oy, -oz) * ANG(0, -yaw, 0) * root:ToObjectSpace(cf)
		end,
	})
	-- split shards: each one is a cyan/magenta pair
	type Shard = { a: BasePart, b: BasePart, cf: CFrame, nextT: number }
	local shards: { Shard } = {}
	for i = 1, 7 do
		local a = Core.part(c, V(0.06, 0.8, 0.4), if i % 2 == 0 then cyan else mag)
		local b = Core.part(c, V(0.06, 0.8, 0.4), if i % 2 == 0 then mag else cyan, NEON, 0.3)
		shards[i] = { a = a, b = b, cf = CF(0, -50, 0), nextT = 0 }
	end
	-- corrupted floor tiles
	type Tile = { p: BasePart, cf: CFrame, nextT: number }
	local tiles: { Tile } = {}
	for i = 1, 9 do
		tiles[i] = { p = Core.part(c, V(0.8, 0.06, 0.8), cyan), cf = CF(0, -50, 0), nextT = 0 }
	end
	-- dead-pixel blocks popping near the body
	local blocks = {
		Core.part(c, V(0.5, 0.5, 0.5), WHITE, NEON, 1),
		Core.part(c, V(0.35, 0.35, 0.35), mag, NEON, 1),
	}
	-- scanline tears: camera-facing horizontal beams across the body
	type Tear = { a0: Attachment, a1: Attachment, beam: Beam, y: number, w: number, shift: number, untilT: number }
	local tears: { Tear } = {}
	for i = 1, 3 do
		local a0, a1 = Core.att(c), Core.att(c)
		local col = if i == 1 then cyan elseif i == 2 then mag else WHITE
		local beam = Core.beam(c, a0, a1, col, 0.14, { segs = 1, bright = 3, tr = ns(0.6, 0, 0, 0.6) })
		beam.Enabled = false
		tears[i] = { a0 = a0, a1 = a1, beam = beam, y = 0, w = 4, shift = 0, untilT = 0 }
	end
	-- RGB-split halo over the head and on the floor
	B.circle(c, {
		radius = 1,
		color = cyan,
		width = 0.12,
		n = 6,
		anchor = function(t)
			return CF(-ox * 1.5, c.topY + 0.75 + math.sin(t * 2) * 0.06, 0) * ANG(yaw * 0.6, 0, 0.12)
		end,
	})
	B.circle(c, {
		radius = 1,
		color = mag,
		width = 0.12,
		n = 6,
		anchor = function(t)
			return CF(ox * 1.5, c.topY + 0.75 + math.sin(t * 2) * 0.06, 0) * ANG(-yaw * 0.6, 0, -0.12)
		end,
	})
	B.circle(c, {
		radius = 3.7,
		color = cyan,
		width = 0.13,
		anchor = function()
			return CF(-ox * 2, g + 0.04, 0)
		end,
	})
	B.circle(c, {
		radius = 3.7,
		color = mag,
		width = 0.13,
		anchor = function()
			return CF(ox * 2, g + 0.04, oz)
		end,
	})
	type Gl = { att: Attachment, lbl: TextLabel, nextT: number }
	local glyphs: { Gl } = {}
	for i = 1, 6 do
		local att, lbl = B.glyph(c, "#", cyan, V2(0.7, 0.7), F.pixel)
		glyphs[i] = { att = att, lbl = lbl, nextT = 0 }
	end
	local WORDS = { "ERR", "NaN", "0x0", "???", "NULL", "404" }
	local torso = Core.att(c, c.torso)
	local pix: Core.EmitSpec = {
		tex = T.square,
		color = cs(cyan),
		size = ns(0.22, 0.1),
		transp = ns(0, 0.6),
		rate = 16,
		life = nr(0.12, 0.3),
		speed = nr(4, 8),
		spread = V2(180, 180),
		rot = nr(0, 0),
		bright = 2.5,
	}
	Core.emit(torso, pix)
	pix.color = cs(mag)
	Core.emit(torso, pix)
	local burstFx = Core.emit(torso, {
		tex = T.square,
		color = cs(cyan, WHITE, mag),
		size = ns(0.45, 0.3, 0),
		rate = 0,
		life = nr(0.3, 0.6),
		speed = nr(7, 13),
		drag = 4,
		spread = V2(180, 180),
		rot = nr(0, 0),
		bright = 3,
	})
	Core.emit(Core.volume(c, V(7, 0.1, 7), CF(0, g + 0.1, 0)), {
		tex = T.square,
		color = cs(cyan, mag),
		size = ns(0.26, 0.2, 0),
		transp = ns(0.1, 0.3, 1),
		rate = 14,
		life = nr(0.6, 1.2),
		speed = nr(1.5, 3.5),
		rot = nr(0, 0),
		shape = BOX,
	})
	local glow = bodyGlow(c, cyan, 7, 0.86)
	local light = rootLight(c, cyan, 2.2, 14)
	Core.on(c, function(t, _, root)
		if t >= nextBurst then
			nextBurst = t + 0.6 + rng:NextNumber() * 1.1
			burstUntil = t + 0.16 + rng:NextNumber() * 0.08
			burstFx:Emit(26)
		end
		local bursting = t < burstUntil
		if bursting then
			ox = 0.3 + rng:NextNumber() * 0.4
			oy = (rng:NextNumber() - 0.5) * 0.3
			oz = (rng:NextNumber() - 0.5) * 0.4
			yaw = (rng:NextNumber() - 0.5) * 0.35
		else
			ox = 0.12 + math.sin(t * 13) * 0.04
			oy, oz, yaw = 0, 0, 0
		end
		-- ghosts: drop random limbs ("missing slices") while bursting
		for _, p in ghostA do
			p.Transparency = if bursting then (if rng:NextNumber() < 0.25 then 1 else 0.3) else 0.6
		end
		for _, p in ghostB do
			p.Transparency = if bursting then (if rng:NextNumber() < 0.25 then 1 else 0.3) else 0.6
		end
		for _, s in shards do
			if t >= s.nextT then
				s.nextT = t + (if bursting then 0.04 else 0.1) + rng:NextNumber() * 0.3
				local a = rng:NextNumber() * TAU
				local r = 1.6 + rng:NextNumber() * 2.2
				s.cf = CF(math.cos(a) * r, g + 0.3 + rng:NextNumber() * (h + 1), math.sin(a) * r)
					* ANG(0, -a + (rng:NextNumber() - 0.5), (rng:NextNumber() - 0.5) * 0.9)
				local sz = V(0.06, 0.3 + rng:NextNumber() * 1.3, 0.2 + rng:NextNumber() * 0.7)
				s.a.Size = sz
				s.b.Size = sz
				s.a.Transparency = if rng:NextNumber() < 0.12 then 1 else 0
			end
			local cf = root * s.cf
			Core.put(s.a, cf)
			Core.put(s.b, cf * CF(0.03, 0.06, if bursting then 0.35 else 0.12))
		end
		for _, tl in tiles do
			if t >= tl.nextT then
				tl.nextT = t + 0.1 + rng:NextNumber() * 0.4
				local a = rng:NextNumber() * TAU
				local r = 1.2 + rng:NextNumber() * 2.6
				local x = math.floor(math.cos(a) * r / 0.8 + 0.5) * 0.8
				local z = math.floor(math.sin(a) * r / 0.8 + 0.5) * 0.8
				tl.cf = CF(x, g + 0.04, z)
				local q = rng:NextNumber()
				tl.p.Color = if q < 0.45 then cyan elseif q < 0.9 then mag else WHITE
				tl.p.Transparency = if rng:NextNumber() < 0.2 then 1 else 0.15 + rng:NextNumber() * 0.4
				local sz = if rng:NextNumber() < 0.3 then 1.2 else 0.75
				tl.p.Size = V(sz, 0.06, sz)
			end
			Core.put(tl.p, root * tl.cf)
		end
		local d, right = camAxes(root)
		for _, bk in blocks do
			if bursting then
				if rng:NextNumber() < 0.3 then
					local a = rng:NextNumber() * TAU
					Core.put(bk, root * CF(math.cos(a) * 1.3, g + 0.6 + rng:NextNumber() * h, math.sin(a) * 1.3))
				end
				bk.Transparency = 0
			else
				bk.Transparency = 1
			end
		end
		for k, tr in tears do
			if t >= tr.untilT and rng:NextNumber() < (if bursting then 0.5 else 0.03) then
				tr.untilT = t + 0.05 + rng:NextNumber() * 0.14
				tr.y = g + 0.3 + rng:NextNumber() * (h + 0.4)
				tr.w = 3.4 + rng:NextNumber() * 2.6
				tr.shift = (rng:NextNumber() - 0.5) * 1.4
				tr.beam.Width0 = 0.08 + rng:NextNumber() * 0.2
				tr.beam.Width1 = tr.beam.Width0
			end
			local on = t < tr.untilT
			tr.beam.Enabled = on
			if on then
				local cen = d * (1 + k * 0.05) + right * tr.shift + V(0, tr.y, 0)
				tr.a0.Position = cen - right * (tr.w / 2)
				tr.a1.Position = cen + right * (tr.w / 2)
			end
		end
		for _, gl in glyphs do
			if t >= gl.nextT then
				gl.nextT = t + 0.06 + rng:NextNumber() * 0.25
				local a = rng:NextNumber() * TAU
				local r = 2 + rng:NextNumber() * 1.6
				gl.att.Position = V(math.cos(a) * r, g + 0.6 + rng:NextNumber() * (h + 0.8), math.sin(a) * r)
				gl.lbl.Text = if rng:NextNumber() < 0.2 then Core.pick(WORDS, rng) else randChar(rng, "#%&@$/\\|<>=_01")
				gl.lbl.TextColor3 = if rng:NextNumber() < 0.5 then cyan else mag
				gl.lbl.TextTransparency = if rng:NextNumber() < 0.3 then 1 else 0
			end
		end
		local useA = math.sin(t * 17) > 0
		light.Color = if bursting then WHITE elseif useA then cyan else mag
		light.Brightness = if bursting then 5 else 2 + math.noise(t * 5, 2) * 0.6
		glow.Color = cs(if useA then cyan else mag)
	end)
end

-- red horse-head glyph hologram above, red sparks
-- 46 parts / 4 emitters
A.Trojan = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local S = 1.7
	local yK = c.topY + 1.3
	-- knight piece: size, offset, roll (all scaled by S)
	local spec: { { sz: Vector3, pos: Vector3, rz: number, hi: boolean? } } = {
		{ sz = V(0.9, 0.12, 0.5), pos = V(0, 0, 0), rz = 0 },
		{ sz = V(0.7, 0.1, 0.4), pos = V(0, 0.11, 0), rz = 0 },
		{ sz = V(0.42, 0.75, 0.32), pos = V(-0.05, 0.5, 0), rz = -0.15 },
		{ sz = V(0.75, 0.34, 0.3), pos = V(0.17, 0.95, 0), rz = -0.45 },
		{ sz = V(0.26, 0.2, 0.28), pos = V(0.48, 0.75, 0), rz = -0.6 },
		{ sz = V(0.1, 0.28, 0.12), pos = V(-0.08, 1.25, 0.07), rz = 0.25 },
		{ sz = V(0.1, 0.28, 0.12), pos = V(-0.08, 1.25, -0.07), rz = 0.25 },
		{ sz = V(0.1, 0.72, 0.36), pos = V(-0.29, 0.76, 0), rz = -0.35, hi = true },
		{ sz = V(0.07, 0.07, 0.34), pos = V(0.2, 1.02, 0), rz = 0, hi = true },
	}
	local knight: { { p: BasePart, cf: CFrame, base: number } } = {}
	for _, s in spec do
		local base = if s.hi then 0.05 else 0.25
		local p = Core.part(c, s.sz * S, if s.hi then c.c1:Lerp(WHITE, 0.5) else c.c1, NEON, base)
		table.insert(knight, { p = p, cf = CF(s.pos * S) * ANG(0, 0, s.rz), base = base })
	end
	local scan = Core.part(c, V(1.1 * S, 0.04, 0.6 * S), WHITE, NEON, 0.4)
	B.ring(c, {
		n = 12,
		radius = 1.2,
		seg = V(0.08, 0.08, 0),
		color = c.c1,
		spin = 1.5,
		anchor = function()
			return CF(0, yK - 0.1, 0)
		end,
	})
	B.circle(c, { radius = 1.45, color = c.c1, width = 0.08, at = CF(0, yK - 0.1, 0), tr = 0.3 })
	local headTop = Core.att(c, c.head, CF(0, Core.headSize(c.head).Y / 2, 0))
	for k = 1, 4 do
		local a = (k - 1) / 4 * TAU + math.pi / 4
		local top = Core.att(c, nil, CF(math.cos(a) * 1.4, yK - 0.1, math.sin(a) * 1.4))
		Core.beam(c, headTop, top, c.c1, 0.06, { w1 = 0.6, tr = ns(0.4, 0.85) })
	end
	local _, lbl =
		B.glyph(c, "TROJAN.EXE", c.c1, V2(2.8, 0.42), F.pixel, CF(0, yK + 1.45 * S + 0.3, 0), Color3.new(0.2, 0, 0))
	-- "gift" boxes orbiting the waist (lids pop open now and then)
	type Gift = { box: BasePart, rx: BasePart, rz: BasePart, pop: number }
	local gifts: { Gift } = {}
	local dark = c.c1:Lerp(c.c2, 0.6)
	for i = 1, 4 do
		gifts[i] = {
			box = Core.part(c, V(0.6, 0.6, 0.6), dark, SMOOTH),
			rx = Core.part(c, V(0.64, 0.64, 0.14), c.c1),
			rz = Core.part(c, V(0.14, 0.64, 0.64), c.c1),
			pop = 0,
		}
	end
	-- floor ring
	B.ring(c, {
		n = 16,
		gap = 4,
		radius = 3.5,
		seg = V(0.18, 0.1, 0),
		color = c.c1,
		spin = 0.6,
		anchor = function()
			return CF(0, g + 0.05, 0)
		end,
	})
	B.circle(c, {
		radius = 3.1,
		color = c.c1,
		width = 0.1,
		at = CF(0, g + 0.04, 0),
		tr = 0.35,
		radiusFn = function(t)
			return 3.1 * (1 + 0.035 * math.sin(t * 1.7 + 1))
		end,
	})
	local torso = Core.att(c, c.torso)
	local sparks = Core.emit(torso, {
		tex = T.fireSpark,
		color = cs(c.c1:Lerp(WHITE, 0.3), c.c1),
		size = ns(0.32, 0),
		rate = 16,
		life = nr(0.5, 0.9),
		speed = nr(3, 5),
		spread = V2(180, 180),
		accel = V(0, -4, 0),
		bright = 2.5,
	})
	Core.emit(Core.volume(c, V(6, 0.1, 6), CF(0, g + 0.1, 0)), {
		tex = T.spark,
		color = cs(c.c1),
		size = ns(0.3, 0),
		transp = ns(0.1, 1),
		rate = 10,
		life = nr(1.4, 2.2),
		speed = nr(0.8, 1.6),
		shape = BOX,
	})
	local ka = Core.att(c, nil, CF(0, yK + 0.9, 0))
	Core.emit(ka, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.18, 0),
		transp = ns(0.1, 1),
		rate = 10,
		life = nr(0.6, 1),
		speed = nr(0.8, 1.6),
		spread = V2(180, 180),
		rot = nr(0, 0),
	})
	bodyGlow(c, c.c1, 7, 0.86)
	local kl = Core.light(ka, c.c1, 2.5, 12)
	local light = rootLight(c, c.c1, 2, 13)
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
		Core.put(scan, base * CF(0.05 * S, sy * 1.35 * S, 0))
		scan.Transparency = 0.3 + sy * 0.6
		for i, gf in gifts do
			local a = (i - 1) / 4 * TAU - t * 0.7
			local cf = root
				* CF(math.cos(a) * 2.7, -0.1 + math.sin(t * 2 + i) * 0.2, math.sin(a) * 2.7)
				* ANG(0.3, t * 1.2 + i, 0.2)
			if gf.pop < t and rng:NextNumber() < 0.004 then
				gf.pop = t + 0.5
				sparks:Emit(10)
			end
			local open = if t < gf.pop then 0.35 else 0
			Core.put(gf.box, cf)
			Core.put(gf.rx, cf * CF(0, open, 0))
			Core.put(gf.rz, cf * CF(0, open, 0))
		end
		lbl.Text = if (t % 1.8) < 0.9 then "TROJAN.EXE" else "GIFT.EXE"
		kl.Brightness = if fl then 0.6 else 2.5
		light.Brightness = 1.8 + Core.pulse(t, 1.6) * 0.8
	end)
end

-- ghostly pale rings and floating notification badges
-- 27 parts / 4 emitters
A.PhantomPing = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local span = c.topY - g + 1
	local rings: { B.Circle } = {}
	for k = 1, 3 do
		local function ph(t: number): number
			return ((t + k) / 3) % 1
		end
		rings[k] = B.circle(c, {
			radius = 2.8,
			color = c.c1,
			width = 0.14,
			color2 = c.c2,
			anchor = function(t)
				return CF(0, g + ph(t) * span, 0)
			end,
			radiusFn = function(t)
				return 2.8 - ph(t) * 0.9
			end,
		})
	end
	-- floor pings expanding outward
	local floor: { B.Circle } = {}
	for k = 1, 2 do
		floor[k] = B.circle(c, {
			radius = 1,
			color = c.c1,
			width = 0.12,
			n = 8,
			anchor = function()
				return CF(0, g + 0.04, 0)
			end,
			radiusFn = function(t)
				return 1 + (((t + k * 1.25) / 2.5) % 1) * 3.6
			end,
		})
	end
	B.ring(c, {
		n = 24,
		gap = 3,
		radius = 3.6,
		seg = V(0.08, 0.08, 0),
		color = c.c1,
		tr = 0.3,
		spin = -0.35,
		anchor = function(t)
			return CF(0, c.chestY - 0.3, 0) * ANG(0.15 * math.sin(t * 0.5), 0, 0.1)
		end,
	})
	-- the phantom itself: a pale echo hovering behind the player
	local ghost = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = FF,
		delay = 0.5,
		scale = 1.05,
		map = B.offsetMap(function(t)
			return CF(math.sin(t * 0.7) * 0.4, 0.5 + math.sin(t * 1.3) * 0.15, 1.5)
		end),
	})
	type Badge = { att: Attachment, lbl: TextLabel, gui: BillboardGui, t0: number, life: number }
	local badges: { Badge } = {}
	local counts = { "1", "2", "3", "7", "9+", "99+", "!" }
	local function relocate(b: Badge, t: number)
		b.t0 = t
		b.life = 2.2 + rng:NextNumber() * 1.4
		local a = rng:NextNumber() * TAU
		local r = 1.6 + rng:NextNumber() * 1.6
		b.att.Position = V(math.cos(a) * r, c.headY + (rng:NextNumber() - 0.3) * 2.2, math.sin(a) * r)
		b.lbl.Text = Core.pick(counts, rng)
	end
	for i = 1, 6 do
		local att, lbl, gui = B.glyph(c, "1", WHITE, V2(0.9, 0.9), F.tech)
		lbl.BackgroundTransparency = 0.15
		lbl.BackgroundColor3 = c.c2
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = lbl
		local stroke = Instance.new("UIStroke")
		stroke.Color = c.c1
		stroke.Thickness = 3
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
		size = ns(2, 4),
		transp = ns(0.85, 1),
		rate = 4,
		life = nr(2, 3),
		speed = nr(0.4, 0.9),
		spread = V2(180, 180),
		rotSpeed = nr(-20, 20),
		light = 0.6,
	})
	Core.emit(Core.att(c, c.head), {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0, 0.34, 0),
		rate = 7,
		life = nr(0.8, 1.4),
		speed = nr(0.6, 1.2),
		spread = V2(180, 180),
	})
	Core.emit(Core.volume(c, V(6, 0.1, 6), CF(0, g + 0.1, 0)), {
		tex = T.glow,
		color = cs(c.c1),
		size = ns(0.3, 0.6),
		transp = ns(0.4, 1),
		rate = 8,
		life = nr(1.5, 2.5),
		speed = nr(0.5, 1),
		shape = BOX,
	})
	bodyGlow(c, c.c1, 7, 0.86)
	local light = rootLight(c, c.c1, 1.8, 13)
	Core.on(c, function(t)
		for k, r in rings do
			B.setBeamsTransparency(r.beams, 0.1 + (((t + k) / 3) % 1) * 0.85)
		end
		for k, r in floor do
			B.setBeamsTransparency(r.beams, 0.1 + (((t + k * 1.25) / 2.5) % 1) * 0.9)
		end
		local fade = 0.35 + 0.3 * Core.pulse(t, 4)
		for _, p in ghost do
			p.Transparency = fade
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
			local fd = math.clamp((age - (b.life - 0.35)) / 0.35, 0, 1)
			b.gui.Size = UDim2.new(0.9 * s, 0, 0.9 * s, 0)
			b.lbl.TextTransparency = fd
			b.lbl.BackgroundTransparency = 0.15 + fd * 0.85
			b.att.Position += V(0, 0.004, 0)
		end
		light.Brightness = 1.5 + Core.pulse(t, 3) * 1
	end)
end

-- magenta neon tubes spiralling up the body, pulsing
-- 40 parts / 4 emitters
A.NeonPulse = function(c: Ctx)
	local g = c.groundY
	local nSeg = 18
	local turns = 2.2
	local r = 2
	local y0 = g + 0.2
	local y1 = c.topY + 0.8
	type Seg = { p: BasePart, cf: CFrame, s: number }
	local segs: { Seg } = {}
	for h = 1, 2 do
		local ph0 = (h - 1) * math.pi
		local function pt(k: number): Vector3
			local f = k / nSeg
			local a = ph0 + f * turns * TAU
			local rr = r - f * 0.5
			return V(math.cos(a) * rr, y0 + f * (y1 - y0), math.sin(a) * rr)
		end
		for k = 0, nSeg - 1 do
			local p0, p1 = pt(k), pt(k + 1)
			local len = (p1 - p0).Magnitude
			local p = Core.part(c, V(len + 0.08, 0.24, 0.24), c.c1, NEON, 0, CYL)
			local cf = CFrame.lookAt((p0 + p1) / 2, p1) * ANG(0, math.pi / 2, 0)
			table.insert(segs, { p = p, cf = cf, s = (k + 0.5) / nSeg })
		end
	end
	local caps: { { p: BasePart, cf: CFrame } } = {}
	for h = 1, 2 do
		local ph0 = (h - 1) * math.pi
		local a1 = ph0 + turns * TAU
		table.insert(caps, {
			p = Core.part(c, V(0.42, 0.42, 0.42), c.c2, NEON, 0, BALL),
			cf = CF(math.cos(ph0) * r, y0, math.sin(ph0) * r),
		})
		table.insert(caps, {
			p = Core.part(c, V(0.42, 0.42, 0.42), c.c2, NEON, 0, BALL),
			cf = CF(math.cos(a1) * (r - 0.5), y1, math.sin(a1) * (r - 0.5)),
		})
	end
	B.circle(c, { radius = r, color = c.c1, width = 0.12, at = CF(0, y0, 0), tr = 0.25 })
	B.circle(c, { radius = r - 0.5, color = c.c1, width = 0.1, at = CF(0, y1, 0), tr = 0.3 })
	local function pulsePos(t: number): number
		return (t * 0.7) % 1.3 - 0.15
	end
	local pr = B.circle(c, {
		radius = r + 0.1,
		color = c.c2,
		color2 = WHITE,
		width = 0.22,
		anchor = function(t)
			return CF(0, y0 + math.clamp(pulsePos(t), 0, 1) * (y1 - y0), 0)
		end,
		radiusFn = function(t)
			return r + 0.15 - math.clamp(pulsePos(t), 0, 1) * 0.5
		end,
	})
	-- heartbeat shock on the floor every time a pulse starts
	local beat = B.circle(c, {
		radius = 2,
		color = c.c1,
		color2 = c.c2,
		width = 0.18,
		n = 8,
		anchor = function()
			return CF(0, g + 0.05, 0)
		end,
		radiusFn = function(t)
			return 2 + ((t * 0.7) % 1.3) / 1.3 * 2.8
		end,
	})
	local feet = Core.att(c, c.root, CF(0, y0, 0))
	Core.emit(feet, {
		tex = T.spark,
		color = cs(c.c1, c.c2),
		size = ns(0.36, 0),
		rate = 12,
		life = nr(1, 1.6),
		speed = nr(1.5, 3),
		spread = V2(40, 40),
		accel = V(0, 1, 0),
	})
	local pa = Core.att(c, c.root, CF(0, y0, 0))
	Core.emit(pa, {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.2, 0),
		rate = 20,
		life = nr(0.3, 0.6),
		speed = nr(3, 5),
		spread = V2(180, 5),
		dir = Enum.NormalId.Front,
		rot = nr(0, 0),
	})
	Core.emit(Core.volume(c, V(5, 0.1, 5), CF(0, g + 0.1, 0)), {
		tex = T.glow,
		color = cs(c.c1),
		size = ns(0.3, 0.7),
		transp = ns(0.3, 1),
		rate = 8,
		life = nr(1, 1.6),
		speed = nr(0.4, 0.9),
		shape = BOX,
	})
	bodyGlow(c, c.c1, 7, 0.85)
	local light = rootLight(c, c.c1, 2, 13)
	Core.on(c, function(t, _, root)
		local base = root * ANG(0, t * 0.8, 0)
		local u = pulsePos(t)
		for _, s in segs do
			Core.put(s.p, base * s.cf)
			local d = (s.s - u) / 0.09
			local k = math.exp(-d * d)
			s.p.Color = c.c1:Lerp(WHITE, k * 0.8)
		end
		for _, cp in caps do
			Core.put(cp.p, base * cp.cf)
		end
		local inside = u >= 0 and u <= 1
		B.setBeamsTransparency(pr.beams, if inside then 0.05 else 1)
		B.setBeamsTransparency(beat.beams, 0.1 + ((t * 0.7) % 1.3) / 1.3 * 0.9)
		pa.Position = V(0, y0 + math.clamp(u, 0, 1) * (y1 - y0), 0)
		light.Brightness = 1.6 + (1 - math.abs(u - 0.5) * 2) * 2.4
	end)
end

-- swarm of small drones linked with beams
-- 31 parts / 3 emitters
A.Botnet = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	type Drone = { body: BasePart, eye: BasePart, rotor: BasePart, att: Attachment, blink: number }
	local drones: { Drone } = {}
	local shell = Color3.fromRGB(14, 20, 16)
	local N = 10
	for i = 1, N do
		drones[i] = {
			body = Core.part(c, V(0.7, 0.14, 0.7), shell, METAL),
			eye = Core.part(c, V(0.24, 0.24, 0.24), c.c1, NEON, 0, BALL),
			rotor = Core.part(c, V(0.95, 0.04, 0.09), c.c1, NEON, 0.15),
			att = Core.att(c),
			blink = 0,
		}
	end
	local headAtt = Core.att(c, nil, CF(0, c.topY + 1.1, 0))
	for i = 1, N do
		local nxt = drones[i % N + 1]
		Core.beam(c, drones[i].att, nxt.att, c.c1, 0.08, { tex = T.square, texLen = 0.3, texSpeed = 2.5, tr = ns(0.2) })
		if i % 3 == 1 then
			Core.beam(c, drones[i].att, headAtt, c.c2:Lerp(c.c1, 0.5), 0.05, {
				tr = ns(0.15, 0.5),
				tex = T.square,
				texLen = 0.25,
				texSpeed = -3,
			})
		end
	end
	-- three drones sweep scan lasers over the floor
	type Laser = { from: number, spot: Attachment }
	local lasers: { Laser } = {}
	for k = 1, 3 do
		local spot = Core.att(c)
		local from = k * 3
		Core.beam(c, drones[from].att, spot, c.c1, 0.04, { w1 = 0.4, tr = ns(0.2, 0.7) })
		lasers[k] = { from = from, spot = spot }
	end
	local cmd = Core.part(c, V(0.5, 0.5, 0.5), c.c1)
	B.circle(c, { radius = 0.7, color = c.c1, width = 0.08, at = CF(0, c.topY + 1.1, 0), tr = 0.2 })
	B.circle(c, {
		radius = 3.6,
		color = c.c1,
		width = 0.1,
		at = CF(0, g + 0.04, 0),
		tr = 0.45,
		radiusFn = function(t)
			return 3.6 * (1 + 0.035 * math.sin(t * 1.7 + 2))
		end,
	})
	Core.emit(headAtt, {
		tex = T.square,
		color = cs(c.c1),
		size = ns(0.15, 0),
		rate = 10,
		life = nr(0.5, 0.8),
		speed = nr(2.5, 4),
		spread = V2(70, 70),
		dir = Enum.NormalId.Bottom,
		rot = nr(0, 0),
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0.26, 0),
		rate = 7,
		life = nr(0.6, 1),
		speed = nr(1.5, 3),
		spread = V2(180, 180),
	})
	bodyGlow(c, c.c1, 7, 0.86)
	Core.light(headAtt, c.c1, 1.5, 10)
	local light = rootLight(c, c.c1, 1.8, 13)
	local dpos: { Vector3 } = table.create(N, Vector3.zero)
	Core.on(c, function(t, _, root)
		for i, d in drones do
			local a = (i - 1) / N * TAU + t * 0.5
			local r = 3.2 + math.noise(i * 1.7, t * 0.4) * 2
			local y = c.chestY + 0.7 + math.noise(i * 3.1, t * 0.5 + 9) * 2.8
			local pos = V(math.cos(a) * r, y, math.sin(a) * r)
			dpos[i] = pos
			d.att.Position = pos
			local tilt = math.noise(i, t) * 0.5
			local cf = root * CF(pos) * ANG(tilt, -a, tilt * 0.6)
			Core.put(d.body, cf)
			Core.put(d.eye, cf * CF(0, -0.1, 0))
			Core.put(d.rotor, cf * CF(0, 0.1, 0) * ANG(0, t * 40 + i, 0))
			if t > d.blink then
				d.blink = t + 0.4 + rng:NextNumber() * 2.5
				d.eye.Transparency = if d.eye.Transparency > 0.5 then 0 else 0.85
			end
		end
		for k, lz in lasers do
			local p = dpos[lz.from]
			local sw = t * 2 + k * 2
			lz.spot.Position = V(p.X + math.cos(sw) * 1.2, g + 0.05, p.Z + math.sin(sw) * 1.2)
		end
		Core.put(cmd, root * CF(0, c.topY + 1.1, 0) * ANG(t * 1.2, t * 1.7, t * 0.5))
		light.Brightness = 1.6 + Core.pulse(t, 1.8) * 0.6
	end)
end

-- golden rotating cipher rings with symbols
-- 25 parts / 3 emitters
A.Cryptic = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local gold = c.c1
	local deep = c.c1:Lerp(c.c2, 0.45)
	local y = c.chestY
	local R = 3
	B.ring(c, {
		n = 20,
		radius = R,
		seg = V(0.08, 0.26, 0.24),
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
	B.circle(c, { radius = R, color = gold, width = 0.08, at = CF(0, y, 0), tr = 0.2 })
	B.circle(c, { radius = R + 0.3, color = deep, width = 0.06, at = CF(0, y, 0), tr = 0.45 })
	type GRing = { r: number, tilt: number, spd: number, phrase: string, glyphs: { TextLabel }, atts: { Attachment } }
	local grings: { GRing } = {
		{ r = 2.5, tilt = 1.05, spd = 0.8, phrase = "ENCRYPTED!!", glyphs = {}, atts = {} },
		{ r = 3.6, tilt = -1.05, spd = -0.55, phrase = "XOR-AES-256", glyphs = {}, atts = {} },
	}
	for _, gr in grings do
		local yy = y + 0.2
		local tl = gr.tilt
		B.circle(c, {
			radius = gr.r,
			color = gold,
			width = 0.07,
			tr = 0.25,
			anchor = function(t)
				return CF(0, yy, 0) * ANG(0, t * 0.3, 0) * ANG(tl, 0, 0)
			end,
		})
		for i = 1, 11 do
			local att, lbl = B.glyph(c, "A", deep, V2(0.62, 0.62), F.tech, nil, Color3.fromRGB(40, 25, 0))
			gr.atts[i] = att
			gr.glyphs[i] = lbl
		end
	end
	-- floor cipher wheel
	B.circle(c, {
		radius = 3.9,
		color = gold,
		width = 0.12,
		at = CF(0, g + 0.04, 0),
		tr = 0.3,
		radiusFn = function(t)
			return 3.9 * (1 + 0.035 * math.sin(t * 1.7 + 3))
		end,
	})
	B.circle(c, {
		radius = 3.3,
		color = deep,
		width = 0.07,
		at = CF(0, g + 0.04, 0),
		tr = 0.4,
		radiusFn = function(t)
			return 3.3 * (1 + 0.035 * math.sin(t * 1.7 + 4))
		end,
	})
	local wheel: { TextLabel } = {}
	local wheelAtt: { Attachment } = {}
	for i = 1, 12 do
		local att, lbl = B.glyph(c, "0", gold, V2(0.55, 0.55), F.tech)
		wheel[i] = lbl
		wheelAtt[i] = att
	end
	-- floating golden key
	local K = 1.6
	local key = {
		{ p = Core.part(c, V(0.07, 0.36, 0.36) * K, gold, NEON, 0, CYL), cf = CF(0, 0, 0) },
		{ p = Core.part(c, V(0.08, 0.17, 0.17) * K, c.c2, SMOOTH, 0, CYL), cf = CF(0, 0, 0) },
		{ p = Core.part(c, V(0.07, 0.07, 0.62) * K, gold), cf = CF(0, 0, 0.45 * K) },
		{ p = Core.part(c, V(0.06, 0.16, 0.06) * K, gold), cf = CF(0, -0.09 * K, 0.62 * K) },
		{ p = Core.part(c, V(0.06, 0.11, 0.06) * K, gold), cf = CF(0, -0.07 * K, 0.72 * K) },
	}
	local _, lock =
		B.glyph(c, "[LOCKED]", gold, V2(2.4, 0.42), F.tech, CF(0, c.topY + 0.95, 0), Color3.fromRGB(60, 35, 0))
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(gold, WHITE),
		size = ns(0, 0.36, 0),
		rate = 9,
		life = nr(1, 1.8),
		speed = nr(0.8, 1.6),
		spread = V2(180, 180),
	})
	Core.emit(Core.volume(c, V(7, 0.1, 7), CF(0, g + 0.1, 0)), {
		tex = T.square,
		color = cs(gold, deep),
		size = ns(0.2, 0),
		transp = ns(0.1, 1),
		rate = 9,
		life = nr(1.4, 2.2),
		speed = nr(0.6, 1.2),
		rotSpeed = nr(-90, 90),
		shape = BOX,
	})
	bodyGlow(c, gold, 7, 0.86)
	local light = rootLight(c, gold, 2, 13)
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
			for _, wl in wheel do
				if rng:NextNumber() < 0.2 then
					wl.Text = randChar(rng, "0123456789ABCDEF")
				end
			end
		end
		for _, gr in grings do
			local anchor = CF(0, y + 0.2, 0) * ANG(0, t * 0.3, 0) * ANG(gr.tilt, 0, 0)
			for i, att in gr.atts do
				local a = (i - 1) / 11 * TAU + t * gr.spd
				att.Position = (anchor * CF(math.cos(a) * gr.r, 0, math.sin(a) * gr.r)).Position
			end
		end
		for i, att in wheelAtt do
			local a = (i - 1) / 12 * TAU - t * 0.25
			att.Position = V(math.cos(a) * 3.6, g + 0.35, math.sin(a) * 3.6)
		end
		local kcf = root * CF(0, c.chestY + 0.2 + math.sin(t * 1.5) * 0.12, -1.9) * ANG(0, t * 1.1, 0.4)
		for _, k in key do
			Core.put(k.p, kcf * k.cf)
		end
		lock.Text = if decrypt then "[ACCESS?]" else "[LOCKED]"
		light.Brightness = if decrypt then 3.2 else 1.8
	end)
end

---------------------------------------------------------------- EPIC

-- purple roots of light crawling up from the ground
-- 49 parts / 4 emitters
A.Rootkit = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local disc = Core.part(c, V(0.04, 9, 9), c.c2:Lerp(c.c1, 0.25), NEON, 0.35, CYL)
	local cracks: { { beams: { Beam }, off: number } } = {}
	for k = 1, 10 do
		local a = (k - 1) / 10 * TAU + rng:NextNumber() * 0.5
		local pts = {}
		local rad = 0.5
		for _ = 0, 5 do
			a += (rng:NextNumber() - 0.5) * 0.6
			table.insert(pts, V(math.cos(a) * rad, g + 0.05, math.sin(a) * rad))
			rad += 0.8 + rng:NextNumber() * 0.35
		end
		local poly = B.poly(c, pts, c.c1, 0.18, { w1 = 0.1, segs = 1, bright = 3 })
		table.insert(cracks, { beams = poly.beams, off = rng:NextNumber() })
	end
	B.circle(c, {
		radius = 4.6,
		color = c.c1,
		width = 0.14,
		at = CF(0, g + 0.04, 0),
		tr = 0.3,
		radiusFn = function(t)
			return 4.6 * (1 + 0.035 * math.sin(t * 1.7 + 5))
		end,
	})
	type Tendril = { segs: { BasePart }, tip: BasePart, a: number, h: number, turn: number, off: number }
	local tendrils: { Tendril } = {}
	local NS = 7
	for k = 1, 6 do
		local segs = {}
		for i = 1, NS do
			segs[i] = Core.part(c, V(0.28, 0.28, 0.5), c.c1, NEON, 0, CYL)
		end
		tendrils[k] = {
			segs = segs,
			tip = Core.part(c, V(0.36, 0.36, 0.36), WHITE, NEON, 0, BALL),
			a = (k - 1) / 6 * TAU + rng:NextNumber() * 0.5,
			h = c.chestY + rng:NextNumber() * (c.topY - c.chestY + 1.6),
			turn = (1.3 + rng:NextNumber() * 0.7) * (if k % 2 == 0 then 1 else -1),
			off = k * 0.75,
		}
	end
	local vol = Core.volume(c, V(8, 0.1, 8), CF(0, g + 0.1, 0))
	Core.emit(vol, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0, 0.34, 0),
		rate = 14,
		life = nr(2, 3),
		speed = nr(0.6, 1.4),
		accel = V(0, 0.4, 0),
		shape = BOX,
	})
	Core.emit(vol, {
		tex = T.smoke,
		color = cs(c.c1, c.c2),
		size = ns(1.5, 3.5),
		transp = ns(0.75, 1),
		rate = 6,
		life = nr(1.8, 2.6),
		speed = nr(0.3, 0.8),
		rotSpeed = nr(-30, 30),
		light = 0.6,
		shape = BOX,
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.18, 0),
		transp = ns(0, 1),
		rate = 10,
		life = nr(0.8, 1.4),
		speed = nr(1, 2),
		spread = V2(180, 180),
		rot = nr(0, 0),
	})
	bodyGlow(c, c.c1, 8, 0.84)
	local _, g1 = B.glyph(c, "root#", c.c1, V2(1.6, 0.36), F.mono, CF(2.4, g + 0.4, -1.8))
	local _, g2 = B.glyph(c, "sudo -s", c.c1, V2(1.9, 0.36), F.mono, CF(-2.5, g + 0.4, 1.5))
	local _, g3 = B.glyph(c, "/dev/kmem", c.c1, V2(2.1, 0.36), F.mono, CF(-1.6, g + 0.4, -2.6))
	local light = rootLight(c, c.c1, 2.4, 15, g + 0.8)
	local function pt(td: Tendril, s: number, t: number): Vector3
		local a = td.a + s * td.turn + math.sin(t * 1.3 + td.off + s * 3) * 0.1
		local r = 2.6 - s * 1.6 + math.noise(td.off, s * 2, t * 0.6) * 0.3
		return V(math.cos(a) * r, g + 0.05 + s * (td.h - g), math.sin(a) * r)
	end
	Core.on(c, function(t, _, root)
		Core.put(disc, root * CF(0, g + 0.02, 0) * FLAT)
		for _, ck in cracks do
			for j, bm in ck.beams do
				local w = (((t * 0.8 + ck.off) % 1) * 6 - j)
				bm.Transparency = NumberSequence.new(math.clamp(0.5 - math.exp(-w * w) * 0.5, 0, 1))
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
					local th = 0.32 * (1 - s0 * 0.65)
					p.Size = V(len + 0.06, th, th)
					local d = (s0 - pulse) / 0.12
					p.Color = c.c1:Lerp(WHITE, math.exp(-d * d) * 0.7)
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
		g3.TextTransparency = if math.noise(t * 2, 13) > 0.2 then 0.8 else 0.1
		light.Brightness = 2 + Core.pulse(t, 2.2) * 1.4
	end)
end

-- green code rain swirling as a tornado
-- 24 parts / 4 emitters
A.Datastorm = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local H = c.topY - g + 5
	local R0, R1 = 1, 5.2
	type Gl = { att: Attachment, lbl: TextLabel, off: number }
	local glyphs: { Gl } = {}
	for i = 1, 30 do
		local att, lbl = B.glyph(c, "0", c.c1, V2(0.6, 0.6), F.pixel, nil, c.c2)
		glyphs[i] = { att = att, lbl = lbl, off = (i - 1) / 30 }
	end
	local streaks: { BasePart } = {}
	for i = 1, 24 do
		streaks[i] = Core.part(c, V(0.09, 1.3, 0.09), c.c1, NEON, 0.15)
	end
	for k = 1, 5 do
		local f = (k - 1) / 4
		B.circle(c, {
			radius = R0 + f * (R1 - R0),
			color = c.c1,
			width = 0.08 + f * 0.06,
			tr = 0.45,
			anchor = function(t)
				return CF(math.sin(t * 1.3 + k) * 0.2 * f, g + 0.2 + f * H, math.cos(t * 1.1 + k) * 0.2 * f)
			end,
		})
	end
	local sky = Core.att(c, c.root, CF(0, c.topY + 5, 0))
	Core.emit(sky, {
		tex = T.square,
		color = cs(c.c1:Lerp(WHITE, 0.3), c.c1),
		size = ns(0.12),
		transp = ns(0.1, 0.5),
		rate = 34,
		life = nr(0.5, 0.65),
		speed = nr(14, 18),
		spread = V2(32, 32),
		dir = Enum.NormalId.Bottom,
		orient = Enum.ParticleOrientation.VelocityParallel,
		squash = ns(2.5),
	})
	Core.emit(Core.att(c, c.root, CF(0, g + 0.1, 0)), {
		tex = T.smoke,
		color = cs(c.c1, c.c2),
		size = ns(2, 5),
		transp = ns(0.75, 1),
		rate = 7,
		life = nr(1.2, 1.8),
		speed = nr(2.5, 4),
		spread = V2(85, 85),
		rotSpeed = nr(-60, 60),
		light = 0.7,
	})
	Core.emit(Core.volume(c, V(8, 0.1, 8), CF(0, g + 0.1, 0)), {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.22, 0),
		transp = ns(0, 1),
		rate = 14,
		life = nr(0.6, 1.1),
		speed = nr(2, 4),
		spread = V2(25, 25),
		rot = nr(0, 0),
		shape = BOX,
	})
	bodyGlow(c, c.c1, 8, 0.84)
	local light = rootLight(c, c.c1, 2.2, 15, c.topY)
	local boltEnd = V(2, g, 0)
	B.bolt(c, {
		segs = 8,
		color = WHITE,
		color2 = c.c1,
		width = 0.22,
		jitter = 0.7,
		interval = 0.05,
		active = function(t)
			return (t % 3.7) < 0.28
		end,
		ends = function(t)
			if (t % 3.7) < 0.03 then
				local a = rng:NextNumber() * TAU
				boltEnd = V(math.cos(a) * 3.8, g, math.sin(a) * 3.8)
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
			local u = (t * 0.2 + gl.off) % 1
			local a = i * 2.39 + t * (3 - u * 1.4)
			local r = R0 + u * (R1 - R0)
			gl.att.Position = V(math.cos(a) * r, g + 0.2 + u * H, math.sin(a) * r)
			gl.lbl.TextTransparency = 1 - math.sin(u * math.pi) ^ 0.5
			if change and rng:NextNumber() < 0.35 then
				gl.lbl.Text = randChar(rng, "0123456789ABCDEF<>{}#$")
			end
		end
		for i, p in streaks do
			local u = (t * 0.28 + i / 24) % 1
			local a = i * 1.7 + t * (3.4 - u * 1.4)
			local r = R0 - 0.1 + u * (R1 - R0)
			Core.put(p, root * CF(math.cos(a) * r, g + 0.3 + u * H, math.sin(a) * r) * ANG(0, -a, 0) * ANG(0.9, 0, 0))
			p.Transparency = 1 - math.sin(u * math.pi) * 0.9
		end
		light.Brightness = if (t % 3.7) < 0.28 then 6 else 2 + Core.pulse(t, 1.5) * 0.6
	end)
end

-- scanlines sweeping the body, blue projector cone from below
-- 43 parts / 3 emitters
A.Hologram = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local base = Core.part(c, V(0.14, 3.6, 3.6), Color3.fromRGB(18, 22, 32), METAL, 0, CYL)
	local lens = Core.part(c, V(0.5, 0.5, 0.5), c.c1, NEON, 0, BALL)
	B.ring(c, {
		n = 18,
		radius = 1.85,
		seg = V(0.12, 0.08, 0),
		color = c.c1,
		color2 = c.c2,
		spin = 0.6,
		anchor = function()
			return CF(0, g + 0.16, 0)
		end,
	})
	B.circle(c, {
		radius = 4.4,
		color = c.c1,
		width = 0.1,
		at = CF(0, g + 0.04, 0),
		tr = 0.4,
		radiusFn = function(t)
			return 4.4 * (1 + 0.035 * math.sin(t * 1.7 + 6))
		end,
	})
	local lensAtt = Core.att(c, c.root, CF(0, g + 0.25, 0))
	for k = 1, 8 do
		local a = (k - 1) / 8 * TAU
		local top = Core.att(c, nil, CF(math.cos(a) * 2.6, c.topY + 0.8, math.sin(a) * 2.6))
		Core.beam(c, lensAtt, top, c.c1, 0.12, { w1 = 1.5, tr = ns(0.45, 0.9), color2 = c.c2, segs = 4 })
	end
	B.circle(c, { radius = 2.6, color = c.c1, width = 0.08, at = CF(0, c.topY + 0.8, 0), tr = 0.4 })
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
		discs[k] = Core.part(c, V(0.03, 3.6, 3.6), c.c2, NEON, 0.75, CYL)
	end
	-- holo UI panels orbiting
	type Panel = { p: BasePart, top: BasePart, bot: BasePart, lbl: TextLabel }
	local panels: { Panel } = {}
	local texts = { "SYS 98%", "LINK OK", "RENDER", "FPS 60", "SIG ++" }
	for i = 1, 3 do
		local p = Core.part(c, V(1.7, 1, 0.04), c.c1, NEON, 0.7)
		local sg = Core.surface(p, Enum.NormalId.Front, 80)
		local lbl = Core.label(sg, texts[i], WHITE, F.tech, UDim2.fromScale(0.06, 0.3), UDim2.fromScale(0.88, 0.4))
		panels[i] = {
			p = p,
			top = Core.part(c, V(1.7, 0.05, 0.06), c.c2),
			bot = Core.part(c, V(1.7, 0.05, 0.06), c.c2),
			lbl = lbl,
		}
	end
	Core.emit(lensAtt, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.14, 0.06),
		transp = ns(0.1, 1),
		rate = 16,
		life = nr(1.2, 1.8),
		speed = nr(2, 3.2),
		spread = V2(22, 22),
		rot = nr(0, 0),
	})
	Core.emit(Core.volume(c, V(7, 0.1, 7), CF(0, g + 0.1, 0)), {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0, 0.3, 0),
		rate = 10,
		life = nr(1.4, 2.2),
		speed = nr(0.5, 1),
		shape = BOX,
	})
	bodyGlow(c, c.c1, 8, 0.85)
	local light = rootLight(c, c.c1, 2.4, 15, g + 0.5)
	local span = c.topY - g + 0.6
	local nextTxt = 0
	Core.on(c, function(t, _, root)
		if rng:NextNumber() < 0.015 then
			gUntil = t + 0.1
		end
		gx = if t < gUntil then (rng:NextNumber() - 0.5) * 0.6 else 0
		local fl = if t < gUntil then 0.6 else 0
		for _, p in skin do
			p.Transparency = fl
		end
		Core.put(base, root * CF(0, g + 0.07, 0) * FLAT)
		Core.put(lens, root * CF(0, g + 0.25, 0))
		for k, d in discs do
			local u = (t * 0.45 + k / 3) % 1
			Core.put(d, root * CF(0, g + u * span, 0) * FLAT)
			d.Transparency = 0.55 + 0.45 * math.abs(u - 0.5) * 2
		end
		if t >= nextTxt then
			nextTxt = t + 1.2
			local k = rng:NextInteger(1, 3)
			panels[k].lbl.Text = Core.pick(texts, rng)
		end
		for i, pn in panels do
			local a = (i - 1) / 3 * TAU + t * 0.4
			local cf = root * outward(a, 3.4, c.chestY + 0.4 + math.sin(t * 1.3 + i) * 0.2)
			Core.put(pn.p, cf)
			Core.put(pn.top, cf * CF(0, 0.52, 0))
			Core.put(pn.bot, cf * CF(0, -0.52, 0))
			pn.p.Transparency = if t < gUntil then 0.95 else 0.7
		end
		light.Brightness = 2 + math.noise(t * 4, 2) * 1
	end)
end

-- black-red countdown digits orbiting, red lightning
-- 38 parts / 3 emitters
A.ZeroDay = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local prefixes = { "T-", "ETA ", "0DAY ", "PATCH ", "CVE ", "EXP " }
	type Plate = { body: BasePart, top: BasePart, bot: BasePart, lbl: TextLabel }
	local plates: { Plate } = {}
	for i = 1, 6 do
		local body = Core.part(c, V(1.4, 0.7, 0.08), Color3.fromRGB(8, 8, 10), SMOOTH)
		local sg = Core.surface(body, Enum.NormalId.Front, 100)
		local lbl = Core.label(sg, "", c.c1, F.pixel, UDim2.fromScale(0.05, 0.2), UDim2.fromScale(0.9, 0.6))
		plates[i] = {
			body = body,
			top = Core.part(c, V(1.4, 0.06, 0.09), c.c1),
			bot = Core.part(c, V(1.4, 0.06, 0.09), c.c1),
			lbl = lbl,
		}
	end
	local PERIOD = 10
	local function strike(t: number): boolean
		return (t % PERIOD) > PERIOD - 0.4
	end
	-- floor countdown ring: segments go dark as time runs out
	local NR = 20
	local ringParts = B.ring(c, {
		n = NR,
		radius = 4.6,
		seg = V(0.24, 0.1, 0),
		color = c.c1,
		anchor = function()
			return CF(0, g + 0.05, 0)
		end,
	})
	B.circle(c, { radius = 3.4, color = c.c1, width = 0.08, at = CF(0, c.chestY, 0) * ANG(0.25, 0, 0.1), tr = 0.45 })
	for k = 1, 3 do
		local fromP, toP = V(0, 10, 0), Vector3.zero
		B.bolt(c, {
			segs = 9,
			color = WHITE,
			color2 = c.c1,
			width = 0.3,
			jitter = 0.8,
			interval = 0.045,
			flicker = 0.2,
			active = strike,
			ends = function()
				if rng:NextNumber() < 0.3 then
					local a = rng:NextNumber() * TAU
					local r = 1.5 + rng:NextNumber() * 3
					toP = V(math.cos(a) * r, g, math.sin(a) * r)
					fromP = toP + V((rng:NextNumber() - 0.5) * 3, 10 + k, (rng:NextNumber() - 0.5) * 3)
				end
				return fromP, toP
			end,
		})
	end
	-- ambient arcs crackling between the plates' orbit and the body
	B.bolt(c, {
		segs = 6,
		color = c.c1,
		color2 = WHITE,
		width = 0.12,
		jitter = 0.35,
		interval = 0.08,
		flicker = 0.35,
		ends = function()
			local a1 = rng:NextNumber() * TAU
			local a2 = a1 + (rng:NextNumber() - 0.5) * 1.2
			local y1 = g + 0.5 + rng:NextNumber() * (c.topY - g)
			return V(math.cos(a1) * 0.9, y1, math.sin(a1) * 0.9), V(math.cos(a2) * 3.3, c.chestY, math.sin(a2) * 3.3)
		end,
	})
	local _, big = B.glyph(c, "T-10.0", c.c1, V2(2.6, 0.55), F.pixel, CF(0, c.topY + 1.1, 0), Color3.new(0.1, 0, 0))
	local feet = Core.volume(c, V(7, 0.1, 7), CF(0, g + 0.1, 0))
	Core.emit(feet, {
		tex = T.fireSpark,
		color = cs(WHITE, c.c1),
		size = ns(0.28, 0),
		rate = 16,
		life = nr(1, 1.6),
		speed = nr(1.5, 3),
		accel = V(0, 0.5, 0),
		shape = BOX,
		bright = 2.5,
	})
	Core.emit(feet, {
		tex = T.smoke,
		color = cs(Color3.fromRGB(10, 0, 0)),
		size = ns(2, 4),
		transp = ns(0.55, 1),
		rate = 6,
		life = nr(1.5, 2.5),
		speed = nr(0.4, 0.8),
		light = 0,
		rotSpeed = nr(-30, 30),
		shape = BOX,
	})
	bodyGlow(c, c.c1, 8, 0.84)
	local light = rootLight(c, c.c1, 2.2, 15)
	Core.on(c, function(t, _, root)
		local rem = PERIOD - (t % PERIOD)
		local st = strike(t)
		local anchor = root * CF(0, c.chestY, 0) * ANG(0.25, 0, 0.1)
		for i, p in plates do
			local a = (i - 1) / 6 * TAU + t * 0.5
			local cf = anchor * outward(a, 3.4, math.sin(t * 2 + i) * 0.12)
			Core.put(p.body, cf)
			Core.put(p.top, cf * CF(0, 0.38, 0))
			Core.put(p.bot, cf * CF(0, -0.38, 0))
			if st then
				p.lbl.Text = if math.sin(t * 50) > 0 then "0DAY" else ""
			else
				p.lbl.Text = prefixes[i] .. string.format("%04.1f", rem)
			end
		end
		local lit = rem / PERIOD * NR
		for k, p in ringParts do
			if st then
				p.Color = WHITE
				p.Transparency = 0
			elseif k <= lit then
				p.Color = c.c1
				p.Transparency = if rem < 3 and math.sin(t * 20) > 0 then 0.5 else 0
			else
				p.Color = c.c2:Lerp(c.c1, 0.15)
				p.Transparency = 0.6
			end
		end
		big.Text = if st then "ZERO DAY" else string.format("T-%04.1f", rem)
		big.TextColor3 = if st then WHITE else c.c1
		light.Brightness = if st then 6 + rng:NextNumber() * 4 else 1.8 + Core.pulse(t, 1) * 0.8
	end)
end

-- dark smoke aura with red emergency strobes
-- 31 parts / 4 emitters
A.Blackout = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local smoke: Core.EmitSpec = {
		tex = T.smoke,
		color = cs(Color3.fromRGB(6, 4, 6), Color3.fromRGB(32, 4, 6)),
		size = ns(2.5, 6),
		transp = ns(0.45, 0.7, 1),
		rate = 12,
		life = nr(2, 3),
		speed = nr(0.8, 1.6),
		spread = V2(75, 75),
		accel = V(0, 0.6, 0),
		rotSpeed = nr(-30, 30),
		light = 0,
		bright = 1,
	}
	Core.emit(Core.att(c, c.root, CF(0, g + 0.3, 0)), smoke)
	smoke.spread = V2(180, 180)
	smoke.rate = 8
	smoke.size = ns(2, 4.5)
	Core.emit(Core.att(c, c.torso), smoke)
	local S = 1.5
	local yb = c.topY + 1
	local metal = Color3.fromRGB(22, 22, 26)
	local base = Core.part(c, V(0.14, 0.55, 0.55) * S, metal, METAL, 0, CYL)
	local dome = Core.part(c, V(0.44, 0.44, 0.44) * S, c.c1, NEON, 0.35, BALL)
	local refl = Core.part(c, V(0.05, 0.28, 0.14) * S, WHITE, NEON, 0)
	local spotAtt = Core.att(c, nil, CF(0, yb + 0.25, 0))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local s = Instance.new("SpotLight")
		s.Face = face
		s.Angle = 50
		s.Range = 22
		s.Brightness = 8
		s.Color = c.c1
		s.Shadows = false
		s.Parent = spotAtt
	end
	local strobe = rootLight(c, c.c1, 0, 18)
	local n = 20
	local ring = B.ring(c, {
		n = n,
		radius = 3.4,
		seg = V(0.16, 0.08, 0),
		color = c.c2:Lerp(c.c1, 0.2),
		anchor = function()
			return CF(0, g + 0.05, 0)
		end,
	})
	-- emergency strobe pillars around the player
	local pillars: { BasePart } = {}
	local PH = 4.5
	for i = 1, 4 do
		pillars[i] = Core.part(c, V(0.22, PH, 0.22), c.c1, NEON, 0.85)
	end
	local leds: { BasePart } = {}
	for i = 1, 4 do
		leds[i] = Core.part(c, V(0.16, 0.16, 0.16), c.c1)
	end
	local sparkAtt = Core.att(c, c.torso)
	local sparks = Core.emit(sparkAtt, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0.36, 0),
		rate = 0,
		life = nr(0.25, 0.5),
		speed = nr(6, 10),
		spread = V2(180, 180),
		accel = V(0, -20, 0),
		bright = 3,
	})
	bodyGlow(c, c.c1, 8, 0.9)
	local _, sign =
		B.glyph(c, "GRID://OFFLINE", c.c1, V2(2.8, 0.38), F.pixel, CF(0, yb + 0.95, 0), Color3.new(0.15, 0, 0))
	local nextSpark = 0
	Core.on(c, function(t, _, root)
		local bcf = root * CF(0, yb, 0)
		Core.put(base, bcf * FLAT)
		Core.put(dome, bcf * CF(0, 0.15 * S, 0))
		Core.put(refl, bcf * CF(0, 0.17 * S, 0) * ANG(0, t * 6, 0))
		spotAtt.CFrame = CF(0, yb + 0.25, 0) * ANG(0, t * 6, 0)
		local ph = t % 1.2
		local on = ph < 0.06 or (ph > 0.14 and ph < 0.2)
		strobe.Brightness = if on then 8 else 0.4
		dome.Transparency = if on then 0 else 0.35
		local head = (t * 10) % n
		for k, p in ring do
			local d = (head - (k - 1)) % n
			p.Color = c.c2:Lerp(c.c1, math.exp(-d * 0.6))
		end
		local pairOn = math.floor(t / 0.6) % 2
		for i, p in pillars do
			local a = (i - 1) / 4 * TAU + math.pi / 4
			Core.put(p, root * CF(math.cos(a) * 4.2, g + PH / 2, math.sin(a) * 4.2))
			local mine = (i % 2) == pairOn
			p.Transparency = if mine and on then 0 elseif mine then 0.55 else 0.9
		end
		for i, p in leds do
			local a = (i - 1) / 4 * TAU - t * 0.8
			Core.put(p, root * CF(math.cos(a) * 2, -0.2 + math.sin(t + i) * 0.4, math.sin(a) * 2))
			p.Transparency = if math.sin(t * 5 + i * 2) > 0.3 then 0 else 0.9
		end
		if t >= nextSpark then
			nextSpark = t + 0.5 + rng:NextNumber() * 1.4
			sparkAtt.Position =
				V((rng:NextNumber() - 0.5) * 1.6, (rng:NextNumber() - 0.5) * 1.6, (rng:NextNumber() - 0.5) * 0.6)
			sparks:Emit(rng:NextInteger(8, 14))
		end
		sign.TextTransparency = if math.noise(t * 3, 3) > 0.25 then 0.85 else 0.05
	end)
end

-- rainbow-cycling prism rings and colour-split ghosts
-- 77 parts / 3 emitters
A.Chromatic = function(c: Ctx)
	B.ring(c, {
		n = 20,
		radius = 3.4,
		seg = V(0.14, 0.16, 0),
		color = c.c1,
		spin = 1.2,
		anchor = function()
			return CF(0, -0.2, 0)
		end,
		paint = function(k, t, p)
			p.Color = Color3.fromHSV((k / 20 + t * 0.25) % 1, 0.85, 1)
		end,
	})
	B.ring(c, {
		n = 18,
		radius = 2.7,
		seg = V(0.12, 0.14, 0),
		color = c.c2,
		spin = -1.6,
		anchor = function(t)
			return CF(0, c.chestY + 0.1, 0) * ANG(0, -t * 0.4, 0) * ANG(1.2, 0, 0)
		end,
		paint = function(k, t, p)
			p.Color = Color3.fromHSV((k / 18 + t * 0.25 + 0.5) % 1, 0.85, 1)
		end,
	})
	B.ring(c, {
		n = 14,
		radius = 4.4,
		seg = V(0.14, 0.12, 0),
		color = c.c1,
		spin = 0.7,
		anchor = function(t)
			return CF(0, c.groundY + 0.06, 0) * ANG(0, t * 0.2, 0)
		end,
		paint = function(k, t, p)
			p.Color = Color3.fromHSV((k / 14 - t * 0.3) % 1, 0.9, 1)
		end,
	})
	local g1 = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = NEON,
		tr = 0.65,
		delay = 0.08,
		map = B.offsetMap(function(t)
			return CF(-0.45 - math.sin(t * 2) * 0.12, 0, 0.2)
		end),
	})
	local g2 = B.clones(c, {
		set = "lite",
		color = c.c2,
		mat = NEON,
		tr = 0.7,
		delay = 0.17,
		map = B.offsetMap(function(t)
			return CF(0.45 + math.sin(t * 2) * 0.12, 0, 0.35)
		end),
	})
	local yP = c.topY + 1.3
	local PS = 1
	local prism = B.tri(c, PS, 0.1, WHITE)
	local center = Core.att(c, nil, CF(0, yP, 0))
	local src = Core.att(c, nil, CF(-2.8, yP + 0.4, 0))
	Core.beam(c, src, center, WHITE, 0.12, { tr = ns(0.7, 0) })
	for k = 1, 5 do
		local out = Core.att(c, nil, CF(3, yP - 0.6 + (k - 1) * 0.3, 0))
		Core.beam(c, center, out, Color3.fromHSV((k - 1) / 5 * 0.8, 1, 1), 0.08, { w1 = 0.3, tr = ns(0, 0.6) })
	end
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = Core.rainbow(6),
		size = ns(0.36, 0),
		rate = 14,
		life = nr(0.8, 1.4),
		speed = nr(1.5, 3),
		spread = V2(180, 180),
	})
	Core.emit(Core.volume(c, V(8, 0.1, 8), CF(0, c.groundY + 0.1, 0)), {
		tex = T.square,
		color = Core.rainbow(6),
		size = ns(0.24, 0),
		transp = ns(0, 1),
		rate = 14,
		life = nr(1, 1.6),
		speed = nr(1, 2.5),
		rotSpeed = nr(-120, 120),
		shape = BOX,
	})
	local glow = bodyGlow(c, c.c1, 8, 0.85)
	local light = rootLight(c, c.c1, 2.4, 15)
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
		B.putTri(prism, root * CF(0, yP, 0) * ANG(0, t * 1.4, 0), PS)
		light.Color = ca
		glow.Color = cs(ca)
	end)
end

return A
