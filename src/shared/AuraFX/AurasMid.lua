--!strict
-- AuraFX/AurasMid: RARE and EPIC tier auras.
-- Rare: ~3-5 stud radius, Epic: ~4-6 stud radius; every aura has a silhouette-breaking
-- element, readable particles and a coloured root light so it reads from the gameplay camera.

local Workspace = game:GetService("Workspace")

local Core = require(script.Parent.Core)
local B = require(script.Parent.Blocks)
local Sync = require(script.Parent.Sync)

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
	local pixA = Core.emit(torso, pix)
	pix.color = cs(mag)
	local pixB = Core.emit(torso, pix)
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

	-- Synced to the Blender animation (tools/blender/anim/auras/Glitch.py): the body's own
	-- glitch snaps drive the RGB-split bursts instead of a random timer.
	--   snap "head"/"body"/"rhand"  2-3 broken frames  -> burst (+ head glyphs / hand pixel spray)
	--   tear                        the big tear       -> long burst, every tear beam, tiles flash
	--   slump / reboot              power loss / boot  -> light + ghosts dim, then a white flash
	--   skip (walk), crash (landing), land, step       -> short bursts, a tile under each footfall
	-- A random burst still fires after ~2.5 s without any synced one (no clip playing / air).
	local headTip = Core.tip(c, "head")
	local handTip = Core.tip(c, "rhand")
	local feet = { R = Core.tip(c, "rfoot"), L = Core.tip(c, "lfoot") }
	local handFx = handTip
		and Core.emit(handTip, {
			tex = T.square,
			color = cs(WHITE, cyan, mag),
			size = ns(0.3, 0.16, 0),
			rate = 0,
			life = nr(0.2, 0.45),
			speed = nr(5, 10),
			drag = 3,
			spread = V2(35, 35),
			dir = Enum.NormalId.Bottom,
			rot = nr(0, 0),
			bright = 3,
		})
	local tearUntil, tileFlash, headWordUntil, nextTile = 0, 0, 0, 1
	local function burst(dur: number, n: number)
		local t = os.clock()
		burstUntil = math.max(burstUntil, t + dur)
		nextBurst = t + 2.4 + rng:NextNumber() * 1.5
		burstFx:Emit(n)
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("snap", function(arg)
		burst(0.17, 26)
		if arg == "rhand" and handFx then
			handFx:Emit(22)
		elseif arg == "head" then
			headWordUntil = os.clock() + 0.35
		elseif arg == "body" then
			for _, tl in tiles do
				tl.nextT = 0
			end
		end
	end)
	onEv("tear", function()
		burst(0.45, 60)
		tearUntil = os.clock() + 0.45
		tileFlash = os.clock()
		for _, tl in tiles do
			tl.nextT = 0
		end
	end)
	onEv("skip", function()
		burst(0.1, 10)
	end)
	onEv("crash", function()
		burst(0.25, 34)
		tileFlash = os.clock()
	end)
	onEv("reboot", function()
		burst(0.12, 18)
	end)
	-- every footfall corrupts the floor tile right under that foot
	onEv("step", function(side)
		local ft = feet[side :: string]
		local root = c.realRoot.CFrame
		if not ft then
			return
		end
		local p = root:PointToObjectSpace(ft.WorldPosition)
		local tl = tiles[nextTile]
		nextTile = nextTile % #tiles + 1
		tl.cf = CF(math.floor(p.X / 0.8 + 0.5) * 0.8, g + 0.05, math.floor(p.Z / 0.8 + 0.5) * 0.8)
		tl.p.Color = if rng:NextNumber() < 0.5 then cyan else mag
		tl.p.Transparency = 0
		tl.p.Size = V(1.1, 0.06, 1.1)
		tl.nextT = os.clock() + 0.45
	end)

	Core.on(c, function(t, _, root)
		if t >= nextBurst then
			nextBurst = t + 2.4 + rng:NextNumber() * 1.5
			burstUntil = t + 0.16 + rng:NextNumber() * 0.08
			burstFx:Emit(26)
		end
		-- slump -> reboot: the power drains while the head hangs
		local slumping = Sync.since(c.bus, "slump") < Sync.since(c.bus, "reboot")
			and Sync.since(c.bus, "slump") < 1
		local boot = Sync.env(c.bus, "reboot", 5)
		local tearing = t < tearUntil
		pixA.Enabled = not slumping
		pixB.Enabled = not slumping
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
		local idleTr = if slumping then 0.9 else 0.6 - boot * 0.4
		for _, p in ghostA do
			p.Transparency = if bursting then (if rng:NextNumber() < 0.25 then 1 else 0.3) else idleTr
		end
		for _, p in ghostB do
			p.Transparency = if bursting then (if rng:NextNumber() < 0.25 then 1 else 0.3) else idleTr
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
			-- tear / crash: the whole floor grid flashes white for a moment
			local fl = t - tileFlash
			if fl < 0.3 then
				tl.p.Color = WHITE:Lerp(if fl < 0.1 then WHITE else cyan, fl / 0.3)
				tl.p.Transparency = fl / 0.3 * 0.4
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
			if t >= tr.untilT and (tearing or rng:NextNumber() < (if bursting then 0.5 else 0.03)) then
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
		-- head snap: error words burst right where the head jerked to
		local headWords = t < headWordUntil and headTip ~= nil
		local hp = if headTip then root:PointToObjectSpace(headTip.WorldPosition) else V(0, c.headY, 0)
		for i, gl in glyphs do
			if (headWords and i <= 3) or (boot > 0.5 and i == 1) then
				if t >= gl.nextT then
					gl.nextT = t + 0.05
					gl.att.Position = hp + V((i - 2) * 0.8 + (rng:NextNumber() - 0.5) * 0.3, 0.6 + (i % 2) * 0.4, 0)
					gl.lbl.Text = if boot > 0.5 and i == 1 then "BOOT" else Core.pick(WORDS, rng)
					gl.lbl.TextColor3 = if rng:NextNumber() < 0.5 then cyan else WHITE
					gl.lbl.TextTransparency = 0
				end
			elseif t >= gl.nextT then
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
		light.Color = if bursting or boot > 0.3 then WHITE elseif useA then cyan else mag
		light.Brightness = if slumping
			then 0.35 + math.noise(t * 9, 3) * 0.3
			elseif bursting then (if tearing then 7 else 5)
			else 2 + math.noise(t * 5, 2) * 0.6 + boot * 4
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
	local knightFx = Core.emit(ka, {
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

	-- Synced to the Blender animation (tools/blender/anim/auras/Trojan.py):
	--   offer  the right hand is held out   -> gift #1 leaves its orbit and lands in the palm,
	--                                          spark burst from the hand
	--   push   "go on, take it" nudges      -> the gift bounces in the palm, small sparks
	--   creep  the creepy head tilt         -> the lid flies open, the knight blazes (no flicker),
	--                                          TROJAN.EXE in white-hot red, light surge, spark rain
	--   hide   the hand whips back          -> the gift flies back into its orbit, GIFT.EXE again
	--   tap    rocking onto the toes        -> sparks puff from both feet
	--   step   (free) each footfall          -> sparks drip from that foot
	-- And the other way round: a random gift pop emits "giftpop", the body's "peek" clip
	-- makes the head dart toward it.
	local handTip = Core.tip(c, "rhand")
	local footR, footL = Core.tip(c, "rfoot"), Core.tip(c, "lfoot")
	local spark: Core.EmitSpec = {
		tex = T.fireSpark,
		color = cs(c.c1:Lerp(WHITE, 0.4), c.c1),
		size = ns(0.28, 0),
		rate = 0,
		life = nr(0.35, 0.7),
		speed = nr(2.5, 5),
		spread = V2(70, 70),
		accel = V(0, -6, 0),
		bright = 3,
	}
	local handFx = if handTip then Core.emit(handTip, spark) else nil
	local footFx: { [string]: ParticleEmitter } = {}
	if footR then
		footFx.R = Core.emit(footR, spark)
	end
	if footL then
		footFx.L = Core.emit(footL, spark)
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("offer", function()
		if handFx then
			handFx:Emit(18)
		end
	end)
	onEv("push", function()
		if handFx then
			handFx:Emit(6)
		end
	end)
	onEv("creep", function()
		knightFx:Emit(30)
		sparks:Emit(14)
	end)
	onEv("tap", function()
		for _, e in footFx do
			e:Emit(6)
		end
	end)
	onEv("step", function(side)
		local e = footFx[side :: string]
		if e then
			e:Emit(5)
		end
	end)
	-- 0 = gift #1 orbits, 1 = it sits in the offered palm (eased both ways)
	local function held(): number
		local so, sh = Sync.since(c.bus, "offer"), Sync.since(c.bus, "hide")
		if so == math.huge then
			return 0
		end
		if so < sh then
			local w = math.clamp(so / 0.25, 0, 1)
			return 1 - (1 - w) ^ 3
		end
		local w = math.clamp(sh / 0.3, 0, 1)
		return 1 - w * w
	end
	local function creeping(): boolean
		local sc = Sync.since(c.bus, "creep")
		return sc < Sync.since(c.bus, "hide") and sc < 3
	end

	Core.on(c, function(t, _, root)
		local creep = creeping()
		if not creep and rng:NextNumber() < 0.02 then
			flickUntil = t + 0.07 + rng:NextNumber() * 0.1
		end
		local fl = t < flickUntil
		local base = root * CF(0, yK, 0) * ANG(0, t * 0.9, 0)
		for _, k in knight do
			Core.put(k.p, base * k.cf)
			k.p.Transparency = if fl then 0.75 elseif creep then k.base * 0.2 else k.base
		end
		local sy = (t * 0.8) % 1
		Core.put(scan, base * CF(0.05 * S, sy * 1.35 * S, 0))
		scan.Transparency = 0.3 + sy * 0.6
		for i, gf in gifts do
			local a = (i - 1) / 4 * TAU - t * 0.7
			local cf = root
				* CF(math.cos(a) * 2.7, -0.1 + math.sin(t * 2 + i) * 0.2, math.sin(a) * 2.7)
				* ANG(0.3, t * 1.2 + i, 0.2)
			local hw = if i == 1 then held() else 0
			if gf.pop < t and hw == 0 and rng:NextNumber() < 0.004 then
				gf.pop = t + 0.5
				sparks:Emit(10)
				Sync.emit(c.bus, "giftpop", i)
			end
			local open = if t < gf.pop then 0.35 else 0
			if hw > 0 and handTip then
				-- in the palm: the arm's -Z face looks up while it is held out
				local bounce = Sync.env(c.bus, "push", 9) * 0.35
				local palm = handTip.WorldCFrame * CF(0, 0.15, -0.82 - bounce) * ANG(-math.pi / 2, 0, 0)
				cf = cf:Lerp(palm * ANG(0, t * 0.6, 0), hw)
				if creep then
					open = 0.45 + math.sin(t * 30) * 0.05
				end
			end
			Core.put(gf.box, cf)
			Core.put(gf.rx, cf * CF(0, open, 0))
			Core.put(gf.rz, cf * CF(0, open, 0))
		end
		lbl.Text = if creep then "TROJAN.EXE" elseif (t % 1.8) < 0.9 then "TROJAN.EXE" else "GIFT.EXE"
		if held() > 0 and not creep then
			lbl.Text = "GIFT.EXE"
		end
		lbl.TextColor3 = if creep then c.c1:Lerp(WHITE, 0.45 + 0.2 * math.sin(t * 25)) else c.c1
		local surge = Sync.env(c.bus, "creep", 2.5)
		kl.Brightness = if fl then 0.6 elseif creep then 4 + surge * 3 else 2.5
		light.Brightness = 1.8 + Core.pulse(t, 1.6) * 0.8 + surge * 3 + Sync.env(c.bus, "offer", 6) * 1.5
	end)
end

-- ghostly pale rings and floating notification badges
-- 27 parts / 4 emitters
A.PhantomPing = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local span = c.topY - g + 1
	-- every ring / floor cycle runs on the bus clock (Sync.age), so it shares its beat with
	-- the 6 s Blender idle clip (= two 3 s ring cycles)
	local function age(): number
		return Sync.age(c.bus)
	end
	local rings: { B.Circle } = {}
	for k = 1, 3 do
		local function ph(_t: number): number
			return ((age() + k) / 3) % 1
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
	-- floor pings expanding outward (period 3 s on the bus clock)
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
			radiusFn = function(_t)
				return 1 + (((age() + k * 1.5) / 3) % 1) * 3.6
			end,
		})
	end
	-- Synced to the Blender animation (tools/blender/anim/auras/PhantomPing.py):
	--   ping "R"/"L"  a notification from nobody  -> a big badge pops beside the head on that
	--                                               side, a floor shock ring, head sparkles, flash
	--   swipe         the dismiss gesture          -> every visible badge is flicked away to the
	--                                               left, spark spray from the right hand
	--   sigh          shoulders sink               -> the light and the rings dim
	--   stare         looking back at the phantom  -> the echo behind the player flares
	--   step  (free)  each footfall                -> a small ripple under that foot
	-- And VFX -> body: while walking a phantom badge pops behind the right shoulder now and
	-- then ("ghostping"), the "glance" clip whips the head toward it.
	local shockFrom = 0
	local shock = B.circle(c, {
		radius = 1,
		color = WHITE,
		color2 = c.c1,
		width = 0.2,
		n = 8,
		anchor = function()
			return CF(0, g + 0.06, 0)
		end,
		radiusFn = function(_t)
			return 0.8 + math.clamp((os.clock() - shockFrom) / 0.8, 0, 1) * 4.6
		end,
	})
	local stepAt, stepFrom = V(0, g + 0.05, 0), 0
	local ripple = B.circle(c, {
		radius = 0.4,
		color = c.c1,
		width = 0.08,
		n = 6,
		anchor = function()
			return CF(stepAt)
		end,
		radiusFn = function(_t)
			return 0.3 + math.clamp((os.clock() - stepFrom) / 0.5, 0, 1) * 1.3
		end,
	})
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
	type Badge = {
		att: Attachment,
		lbl: TextLabel,
		gui: BillboardGui,
		t0: number,
		life: number,
		big: number,
		flick: number,
	}
	local badges: { Badge } = {}
	local counts = { "1", "2", "3", "7", "9+", "99+", "!" }
	local function relocate(b: Badge, t: number)
		b.t0 = t
		b.life = 2.2 + rng:NextNumber() * 1.4
		local a = rng:NextNumber() * TAU
		local r = 1.6 + rng:NextNumber() * 1.6
		b.att.Position = V(math.cos(a) * r, c.headY + (rng:NextNumber() - 0.3) * 2.2, math.sin(a) * r)
		b.lbl.Text = Core.pick(counts, rng)
		b.big = 1
		b.flick = 0
	end
	-- a synced notification: the oldest badge pops big right beside the head
	local function popAt(pos: Vector3, t: number, text: string)
		local oldest: Badge? = nil
		for _, b in badges do
			if not oldest or b.t0 < oldest.t0 then
				oldest = b
			end
		end
		if oldest then
			relocate(oldest, t)
			oldest.att.Position = pos
			oldest.life = 2.8
			oldest.big = 1.6
			oldest.lbl.Text = text
		end
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
		local b: Badge = { att = att, lbl = lbl, gui = gui, t0 = 0, life = 1, big = 1, flick = 0 }
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
	local headFx = Core.emit(Core.att(c, c.head), {
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
	local handTip = Core.tip(c, "rhand")
	local feet = { R = Core.tip(c, "rfoot"), L = Core.tip(c, "lfoot") }
	local handFx = handTip
		and Core.emit(handTip, {
			tex = T.spark,
			color = cs(WHITE, c.c1),
			size = ns(0.32, 0),
			rate = 0,
			life = nr(0.3, 0.6),
			speed = nr(3, 6),
			drag = 3,
			spread = V2(60, 60),
			bright = 2,
		})
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("ping", function(side)
		local t = os.clock()
		local sx = if side == "L" then -1 else 1
		-- "L" is the ping from behind-left (the body looks over its left shoulder)
		popAt(V(sx * 1.7, c.headY + 0.5, if side == "L" then 1.1 else -0.3), t, if side == "L" then "!" else "1")
		shockFrom = t
		headFx:Emit(14)
	end)
	onEv("swipe", function()
		local t = os.clock()
		for _, b in badges do
			if t - b.t0 < b.life - 0.3 then
				b.flick = t
			end
		end
		if handFx then
			handFx:Emit(20)
		end
	end)
	onEv("step", function(side)
		local ft = feet[side :: string]
		if ft then
			local p = c.realRoot.CFrame:PointToObjectSpace(ft.WorldPosition)
			stepAt = V(p.X, g + 0.05, p.Z)
			stepFrom = os.clock()
		end
	end)
	local nextGhost = os.clock() + 3
	Core.on(c, function(t)
		local a = age()
		-- walking: a phantom notification pops behind the right shoulder now and then
		if Sync.get(c.bus, "move") > 0.6 then
			if t >= nextGhost then
				nextGhost = t + 4 + rng:NextNumber() * 3
				popAt(V(1.6, c.headY + 0.4, 1.3), t, "1")
				headFx:Emit(8)
				Sync.emit(c.bus, "ghostping")
			end
		else
			nextGhost = math.max(nextGhost, t + 2)
		end
		local sigh = Sync.env(c.bus, "sigh", 1.6)
		for k, r in rings do
			B.setBeamsTransparency(r.beams, math.min(1, 0.1 + (((a + k) / 3) % 1) * 0.85 + sigh * 0.4))
		end
		for k, r in floor do
			B.setBeamsTransparency(r.beams, math.min(1, 0.1 + (((a + k * 1.5) / 3) % 1) * 0.9 + sigh * 0.4))
		end
		local sk = (t - shockFrom) / 0.8
		B.setBeamsTransparency(shock.beams, if sk < 1 then 0.05 + sk * 0.95 else 1)
		local rk = (t - stepFrom) / 0.5
		B.setBeamsTransparency(ripple.beams, if rk < 1 then 0.3 + rk * 0.7 else 1)
		local stare = Sync.env(c.bus, "stare", 0.9)
		local fade = 0.35 + 0.3 * Core.pulse(a, 3) - stare * 0.3
		for _, p in ghost do
			p.Transparency = math.max(0.02, fade)
		end
		for _, b in badges do
			local age = t - b.t0
			if age > b.life or (b.flick > 0 and t - b.flick > 0.35) then
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
			if b.flick > 0 then
				-- swiped away: fly off to the left (the hand's sweep direction) and fade
				local fk = math.clamp((t - b.flick) / 0.35, 0, 1)
				fd = math.max(fd, fk)
				b.att.Position += V(-0.12, 0.02, 0)
			end
			s *= b.big
			b.gui.Size = UDim2.new(0.9 * s, 0, 0.9 * s, 0)
			b.lbl.TextTransparency = fd
			b.lbl.BackgroundTransparency = 0.15 + fd * 0.85
			b.att.Position += V(0, 0.004, 0)
		end
		local ping = Sync.env(c.bus, "ping", 5) + Sync.env(c.bus, "ghostping", 6) * 0.6
		light.Brightness = (1.5 + Core.pulse(a, 3) * 1) * (1 - sigh * 0.6) + ping * 2.5 + stare * 1.2
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
	-- Synced to the Blender animation: every "beat" marker (heartbeat LUB in the idle clip,
	-- each footfall in the walk clip) launches a pulse up the tubes and a floor shock ring;
	-- the "dub" marker flashes the light. Falls back to a 1.6 s beat if no clip is playing.
	local TRAVEL = 1.05
	local function beatAge(): number
		local s = Sync.since(c.bus, "beat")
		if s == math.huge then
			return Sync.age(c.bus) % 1.6
		end
		return s
	end
	local function pulsePos(_t: number): number
		return beatAge() / TRAVEL - 0.15
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
		radiusFn = function(_t)
			return 2 + math.clamp(beatAge() / 0.9, 0, 1) * 2.8
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
		B.setBeamsTransparency(beat.beams, 0.1 + math.clamp(beatAge() / 0.9, 0, 1) * 0.9)
		pa.Position = V(0, y0 + math.clamp(u, 0, 1) * (y1 - y0), 0)
		local thump = Sync.env(c.bus, "beat", 9) + Sync.env(c.bus, "dub", 12) * 0.6
		light.Brightness = 1.6 + (if inside then (1 - math.abs(u - 0.5) * 2) * 2.4 else 0) + thump * 2.2
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
			-- the floor ring pulses outward on every "wave" snap of the greeting
			return 3.6 * (1 + 0.035 * math.sin(t * 1.7 + 2)) + Sync.env(c.bus, "wave", 6) * 0.7
		end,
	})
	local headFx = Core.emit(headAtt, {
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
	local headLight = Core.light(headAtt, c.c1, 1.5, 10)
	local light = rootLight(c, c.c1, 1.8, 13)

	-- Synced to the Blender animation (tools/blender/anim/auras/Botnet.py):
	--   tick    head servo snap         -> every drone eye blinks ON in unison, rotors flash white,
	--                                      square puff from the head node
	--   cmd     right arm points up      -> the swarm breaks orbit and locks into a spinning halo
	--                                      around the RIGHT HAND (rides the hand through the wave),
	--                                      the command cube flies up to it, spark burst, light surge
	--   wave    each "hi" snap           -> the halo drones hop in a ripple, the floor ring pulses,
	--                                      square puff from the hand
	--   drop    the arm drops            -> the drones release back into their orbit
	--   reboot  take-off glitch (jump)   -> drones scatter outward, every eye goes dark for a beat
	--   step    (free) each footfall     -> square puff from that foot, laser #1 snaps onto it
	local handTip = Core.tip(c, "rhand")
	local footR, footL = Core.tip(c, "rfoot"), Core.tip(c, "lfoot")
	local puff: Core.EmitSpec = {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.2, 0),
		rate = 0,
		life = nr(0.3, 0.6),
		speed = nr(2, 4.5),
		spread = V2(180, 180),
		rot = nr(0, 0),
		bright = 2,
	}
	local handFx = if handTip then Core.emit(handTip, puff) else nil
	local handSpark = if handTip
		then Core.emit(handTip, {
			tex = T.spark,
			color = cs(WHITE, c.c1),
			size = ns(0.32, 0),
			rate = 0,
			life = nr(0.35, 0.7),
			speed = nr(4, 8),
			spread = V2(180, 180),
			drag = 4,
			bright = 3,
		})
		else nil
	local footFx: { [string]: ParticleEmitter } = {}
	if footR then
		footFx.R = Core.emit(footR, puff)
	end
	if footL then
		footFx.L = Core.emit(footL, puff)
	end
	local stepWorld: Vector3? = nil
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	local tickPending = false
	onEv("tick", function()
		tickPending = true
		headFx:Emit(8)
	end)
	onEv("cmd", function()
		if handSpark then
			handSpark:Emit(22)
		end
		headFx:Emit(12)
	end)
	onEv("wave", function()
		if handFx then
			handFx:Emit(10)
		end
	end)
	onEv("step", function(side)
		local e = footFx[side :: string]
		if e then
			e:Emit(5)
		end
		local tip = if side == "R" then footR else footL
		stepWorld = if tip then tip.WorldPosition else nil
	end)
	-- 0 = free orbit, 1 = locked into the halo around the hand (eased in and out)
	local function formation(): number
		local sc, sd = Sync.since(c.bus, "cmd"), Sync.since(c.bus, "drop")
		if sc == math.huge then
			return 0
		end
		if sc < sd then
			local w = math.clamp(sc / 0.22, 0, 1)
			return 1 - (1 - w) ^ 3
		end
		local w = math.clamp(sd / 0.6, 0, 1)
		return 1 - w * w * (3 - 2 * w)
	end

	local dpos: { Vector3 } = table.create(N, Vector3.zero)
	local cubeSpin = 0
	Core.on(c, function(t, dt, root)
		local form = formation()
		local scatter = Sync.env(c.bus, "reboot", 3.5) * 1.6
		local dark = Sync.since(c.bus, "reboot") < 0.3
		local flash = Sync.env(c.bus, "tick", 10)
		local rotorCol = c.c1:Lerp(WHITE, flash * 0.9)
		local halo = V(0, c.topY + 1.5, 0)
		if form > 0 and handTip then
			halo = root:PointToObjectSpace(handTip.WorldPosition) + V(0, 0.5, 0)
		end
		local sw = Sync.since(c.bus, "wave")
		local tickNow = tickPending
		tickPending = false
		for i, d in drones do
			local a = (i - 1) / N * TAU + t * 0.5
			local r = 3.2 + math.noise(i * 1.7, t * 0.4) * 2 + scatter
			local y = c.chestY + 0.7 + math.noise(i * 3.1, t * 0.5 + 9) * 2.8
			local pos = V(math.cos(a) * r, y, math.sin(a) * r)
			if form > 0 then
				local ha = (i - 1) / N * TAU + t * 3.2
				local hr = 1.15 + math.sin(t * 5 + i) * 0.12
				local hop = 0
				if sw < 0.7 then
					local u = math.clamp((sw - (i - 1) * 0.035) / 0.32, 0, 1)
					hop = math.sin(u * math.pi) * 0.55
				end
				local hp = halo + V(math.cos(ha) * hr, math.sin(ha * 2) * 0.18 + hop, math.sin(ha) * hr)
				pos = pos:Lerp(hp, form)
			end
			dpos[i] = pos
			d.att.Position = pos
			local tilt = math.noise(i, t) * 0.5 * (1 - form * 0.6)
			local cf = root * CF(pos) * ANG(tilt, -a, tilt * 0.6)
			Core.put(d.body, cf)
			Core.put(d.eye, cf * CF(0, -0.1, 0))
			Core.put(d.rotor, cf * CF(0, 0.1, 0) * ANG(0, t * 40 + i, 0))
			d.rotor.Color = rotorCol
			if dark then
				d.eye.Transparency = 1
			elseif tickNow then
				-- ten thousand machines blink as one
				d.eye.Transparency = 0
				d.blink = t + 0.35 + rng:NextNumber() * 1.5
			elseif t > d.blink then
				d.blink = t + 0.4 + rng:NextNumber() * 2.5
				d.eye.Transparency = if d.eye.Transparency > 0.5 then 0 else 0.85
			end
		end
		local stepAt: Vector3? = nil
		if stepWorld and Sync.since(c.bus, "step") < 0.25 then
			local sp = root:PointToObjectSpace(stepWorld)
			stepAt = V(sp.X, g + 0.05, sp.Z)
		end
		for k, lz in lasers do
			local p = dpos[lz.from]
			local swp = t * 2 + k * 2
			if k == 1 and stepAt then
				lz.spot.Position = stepAt
			else
				lz.spot.Position = V(p.X + math.cos(swp) * 1.2, g + 0.05, p.Z + math.sin(swp) * 1.2)
			end
		end
		-- the command cube leaves the head and rides the halo while the swarm obeys
		local cubeAt = V(0, c.topY + 1.1, 0):Lerp(halo, form)
		cubeSpin += dt * (1 + form * 3)
		Core.put(cmd, root * CF(cubeAt) * ANG(cubeSpin * 1.2, cubeSpin * 1.7, t * 0.5))
		cmd.Color = c.c1:Lerp(WHITE, Sync.env(c.bus, "cmd", 4) * 0.8 + flash * 0.3)
		local surge = Sync.env(c.bus, "cmd", 3)
		headLight.Brightness = 1.5 + flash * 1.5
		light.Brightness = 1.6 + Core.pulse(t, 1.8) * 0.6 + surge * 2.6 + Sync.env(c.bus, "wave", 7) * 0.8
			- (if dark then 1.2 else 0)
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
	-- the rings shudder when the cipher re-locks (the hands clap) or slips (landing)
	local function shudder(): number
		local s = math.min(Sync.since(c.bus, "lock"), Sync.since(c.bus, "slip"))
		if s > 0.5 then
			return 0
		end
		return math.exp(-s * 7) * math.sin(s * 70)
	end
	B.ring(c, {
		n = 20,
		radius = R,
		seg = V(0.08, 0.26, 0.24),
		color = gold,
		color2 = deep,
		spin = 0.5,
		anchor = function()
			return CF(0, y, 0) * ANG(shudder() * 0.08, 0, shudder() * 0.06)
		end,
		paint = function(k, t, p)
			p.Transparency = if ((k + math.floor(t * 6)) % 6) == 0 then 0 else 0.15
		end,
	})
	B.circle(c, { radius = R, color = gold, width = 0.08, at = CF(0, y, 0), tr = 0.2 })
	B.circle(c, {
		radius = R + 0.3,
		color = deep,
		width = 0.06,
		at = CF(0, y, 0),
		tr = 0.45,
		radiusFn = function()
			return R + 0.3 + shudder() * 0.25 + Sync.env(c.bus, "unlock", 3) * 0.5
		end,
	})
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
			return 3.9 * (1 + 0.035 * math.sin(t * 1.7 + 3)) + Sync.env(c.bus, "unlock", 2.5) * 0.6
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
	local chestFx = Core.emit(Core.att(c, c.torso), {
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

	-- Synced to the Blender animation (tools/blender/anim/auras/Cryptic.py). The scramble ->
	-- decrypt -> lock cycle is driven by the body (falls back to a 4 s timer without a clip):
	--   turn    dial click (right wrist)  -> the key turns one notch, both glyph rings jump a
	--                                        notch, the floor wheel rescrambles, sparks from the hand
	--   unlock  arms thrown open          -> decryption: the ring glyphs resolve into the phrases
	--                                        one by one, [ACCESS?], light surge, rings spin up,
	--                                        spark bursts from both hands
	--   lock    hands clap shut           -> instant re-scramble, [LOCKED] flashes white, the rings
	--                                        shudder, a spark burst between the hands
	--   slip    landing jolt              -> scramble burst + ring shudder
	--   step    (free) each footfall      -> gold cipher squares puff from that foot
	local rTip, lTip = Core.tip(c, "rhand"), Core.tip(c, "lhand")
	local footR, footL = Core.tip(c, "rfoot"), Core.tip(c, "lfoot")
	local goldSpark: Core.EmitSpec = {
		tex = T.spark,
		color = cs(WHITE, gold),
		size = ns(0.3, 0),
		rate = 0,
		life = nr(0.35, 0.8),
		speed = nr(2.5, 6),
		spread = V2(180, 180),
		drag = 3,
		bright = 3,
	}
	local cipherPuff: Core.EmitSpec = {
		tex = T.square,
		color = cs(gold, deep),
		size = ns(0.18, 0),
		rate = 0,
		life = nr(0.4, 0.8),
		speed = nr(1.5, 3),
		spread = V2(70, 70),
		dir = Enum.NormalId.Top,
		rot = nr(0, 0),
		rotSpeed = nr(-180, 180),
	}
	local rFx = if rTip then Core.emit(rTip, goldSpark) else nil
	local lFx = if lTip then Core.emit(lTip, goldSpark) else nil
	local footFx: { [string]: ParticleEmitter } = {}
	if footR then
		footFx.R = Core.emit(footR, cipherPuff)
	end
	if footL then
		footFx.L = Core.emit(footL, cipherPuff)
	end
	local function burst(n: number)
		if rFx then
			rFx:Emit(n)
		end
		if lFx then
			lFx:Emit(n)
		end
	end
	local scramblePending = false
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("turn", function()
		scramblePending = true
		if rFx then
			rFx:Emit(9)
		end
	end)
	onEv("unlock", function()
		burst(16)
		chestFx:Emit(14)
	end)
	onEv("lock", function()
		scramblePending = true
		burst(12)
	end)
	onEv("slip", function()
		scramblePending = true
		chestFx:Emit(8)
	end)
	onEv("step", function(side)
		local e = footFx[side :: string]
		if e then
			e:Emit(4)
		end
	end)
	-- eased notch count: every dial click advances by one, settling in ~0.15 s
	local function notches(): number
		local n = Sync.count(c.bus, "turn")
		if n == 0 then
			return 0
		end
		return n - math.exp(-Sync.since(c.bus, "turn") * 22)
	end
	-- seconds since the cipher opened, or nil while locked
	local function decryptAge(t: number): number?
		local su, sl = Sync.since(c.bus, "unlock"), Sync.since(c.bus, "lock")
		if su == math.huge then
			local cyc = t % 4
			return if cyc > 3 then cyc - 3 else nil
		end
		return if su < sl then su else nil
	end

	local nextS = 0
	local spin = 0
	Core.on(c, function(t, dt, root)
		local dAge = decryptAge(t)
		local decrypt = dAge ~= nil
		local force = scramblePending
		scramblePending = false
		if t >= nextS or force then
			nextS = t + 0.09
			for _, gr in grings do
				for i, lbl in gr.glyphs do
					if dAge and dAge * 18 > i then
						lbl.Text = string.sub(gr.phrase, i, i)
						lbl.TextColor3 = WHITE:Lerp(gold, 0.3)
					elseif force or rng:NextNumber() < 0.45 then
						lbl.Text = randChar(rng, SCRAMBLE)
						lbl.TextColor3 = deep:Lerp(gold, rng:NextNumber())
					end
				end
			end
			for _, wl in wheel do
				if force or rng:NextNumber() < 0.2 then
					wl.Text = randChar(rng, "0123456789ABCDEF")
				end
			end
		end
		-- the rings spin up while the cipher is open
		spin += dt * (1 + (if decrypt then 1.6 else 0) + Sync.env(c.bus, "unlock", 2) * 3)
		local notch = notches()
		local sh = 1 + shudder() * 0.08
		for _, gr in grings do
			local anchor = CF(0, y + 0.2, 0) * ANG(0, t * 0.3, 0) * ANG(gr.tilt, 0, 0)
			local jump = notch * TAU / 11 * (if gr.spd > 0 then 1 else -1)
			for i, att in gr.atts do
				local a = (i - 1) / 11 * TAU + spin * gr.spd + jump
				att.Position = (anchor * CF(math.cos(a) * gr.r * sh, 0, math.sin(a) * gr.r * sh)).Position
			end
		end
		for i, att in wheelAtt do
			local a = (i - 1) / 12 * TAU - t * 0.25 - notch * TAU / 12
			att.Position = V(math.cos(a) * 3.6, g + 0.35, math.sin(a) * 3.6)
		end
		-- the key floats between the weaving hands (or in front of the chest without them) and
		-- turns one notch with every dial click
		local kpos = root * V(0, c.chestY + 0.2 + math.sin(t * 1.5) * 0.12, -1.9)
		if rTip and lTip then
			local mid = (rTip.WorldPosition + lTip.WorldPosition) / 2 + root.LookVector * 0.35 + V(0, 0.25, 0)
			kpos = kpos:Lerp(mid, 0.8)
		end
		local turnAng = notch * (math.pi / 2)
		local kcf = CFrame.new(kpos) * root.Rotation * ANG(0, t * 1.1 * 0.4, 0.4) * ANG(0, 0, turnAng)
		if decrypt then
			kcf *= ANG(0, t * 4, 0)
		end
		for _, k in key do
			Core.put(k.p, kcf * k.cf)
		end
		local lk = Sync.env(c.bus, "lock", 5)
		lock.Text = if decrypt then "[ACCESS?]" else "[LOCKED]"
		lock.TextColor3 = gold:Lerp(WHITE, math.max(lk, Sync.env(c.bus, "unlock", 4)))
		light.Brightness = (if decrypt then 3.2 else 1.8)
			+ Sync.env(c.bus, "unlock", 3) * 2.5
			+ lk * 1.5
			+ Sync.env(c.bus, "turn", 10) * 0.6
	end)
end

---------------------------------------------------------------- EPIC

-- purple roots of light crawling up from the ground
-- 49 parts / 4 emitters
A.Rootkit = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local discCol = c.c2:Lerp(c.c1, 0.25)
	local disc = Core.part(c, V(0.04, 9, 9), discCol, NEON, 0.35, CYL)
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
	type Tendril = { segs: { BasePart }, tip: BasePart, a: number, h: number, turn: number, off: number, lag: number }
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
			-- erupt as a staggered crown right after the slam
			lag = (k - 1) * 0.06 + rng:NextNumber() * 0.05,
		}
	end
	local vol = Core.volume(c, V(8, 0.1, 8), CF(0, g + 0.1, 0))
	local floorSparks = Core.emit(vol, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0, 0.34, 0),
		rate = 14,
		life = nr(2, 3),
		speed = nr(0.6, 1.4),
		accel = V(0, 0.4, 0),
		shape = BOX,
	})
	local smoke = Core.emit(vol, {
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
	local chestFx = Core.emit(Core.att(c, c.torso), {
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

	-- Synced to the Blender animation (tools/blender/anim/auras/Rootkit.py):
	--   scratch "rhand"/"lhand"  claw rakes the floor -> purple sparks rake out of that hand, the
	--                                                    cracks flicker
	--   slam    double-arm impact      -> floor shock ring, the cracks flash from the centre
	--                                     outward, disc flare, smoke + spark burst, sparks from
	--                                     both hands, light surge, the tendrils (re)erupt from
	--                                     the floor (their 4.5 s growth cycle starts here)
	--   pull    the palms-up heave     -> the tendrils glow hot while they climb, sparks stream
	--                                     up from both palms
	--   twitch  head snaps             -> the kernel glyphs flash on, chest square burst
	--   touch   landing hand-plant     -> a smaller shock ring + crack flash (the "crouch" clip)
	--   step    (free) each footfall   -> purple sparks kick up from that foot
	local rTip, lTip = Core.tip(c, "rhand"), Core.tip(c, "lhand")
	local footR, footL = Core.tip(c, "rfoot"), Core.tip(c, "lfoot")
	local claw: Core.EmitSpec = {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0.32, 0),
		rate = 0,
		life = nr(0.4, 0.8),
		speed = nr(3, 6),
		spread = V2(60, 60),
		accel = V(0, 3, 0),
		drag = 2,
		bright = 3,
	}
	local handFx: { [string]: ParticleEmitter } = {}
	if rTip then
		handFx.rhand = Core.emit(rTip, claw)
	end
	if lTip then
		handFx.lhand = Core.emit(lTip, claw)
	end
	local footFx: { [string]: ParticleEmitter } = {}
	local kick: Core.EmitSpec = {
		tex = T.spark,
		color = cs(c.c1, c.c2),
		size = ns(0.24, 0),
		rate = 0,
		life = nr(0.3, 0.6),
		speed = nr(1.5, 3),
		spread = V2(80, 80),
		accel = V(0, -4, 0),
		bright = 2,
	}
	if footR then
		footFx.R = Core.emit(footR, kick)
	end
	if footL then
		footFx.L = Core.emit(footL, kick)
	end
	-- shock ring on the floor (slam = big, touch = small); hidden when idle
	local shockScale = 1
	local function shockAge(): number
		return math.min(Sync.since(c.bus, "slam"), Sync.since(c.bus, "touch"))
	end
	local shock = B.circle(c, {
		radius = 1,
		color = WHITE,
		color2 = c.c1,
		width = 0.3,
		n = 8,
		bright = 3,
		anchor = function()
			return CF(0, g + 0.06, 0)
		end,
		radiusFn = function()
			local u = math.clamp(shockAge() / 0.7, 0, 1)
			return (0.8 + (1 - (1 - u) ^ 3) * 4.6) * shockScale
		end,
	})
	B.setBeamsTransparency(shock.beams, 1)
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("scratch", function(hand)
		local e = handFx[hand :: string]
		if e then
			e:Emit(12)
		end
	end)
	onEv("slam", function()
		shockScale = 1
		for _, e in handFx do
			e:Emit(18)
		end
		floorSparks:Emit(30)
		smoke:Emit(8)
	end)
	onEv("touch", function()
		shockScale = 0.55
		if handFx.rhand then
			handFx.rhand:Emit(12)
		end
		smoke:Emit(3)
	end)
	onEv("twitch", function()
		chestFx:Emit(10)
	end)
	onEv("step", function(side)
		local e = footFx[side :: string]
		if e then
			e:Emit(5)
		end
	end)

	local function pt(td: Tendril, s: number, t: number): Vector3
		local a = td.a + s * td.turn + math.sin(t * 1.3 + td.off + s * 3) * 0.1
		local r = 2.6 - s * 1.6 + math.noise(td.off, s * 2, t * 0.6) * 0.3
		return V(math.cos(a) * r, g + 0.05 + s * (td.h - g), math.sin(a) * r)
	end
	Core.on(c, function(t, _, root)
		local slamAge = Sync.since(c.bus, "slam")
		local slamEnv = Sync.env(c.bus, "slam", 3)
		local pullW = Sync.window(c.bus, "pull", 1.3)
		local pulling = if pullW >= 0 then math.sin(pullW * math.pi) else 0
		for _, e in handFx do
			e.Rate = pulling * 22
			e.Acceleration = V(0, 3 + pulling * 6, 0)
		end
		Core.put(disc, root * CF(0, g + 0.02, 0) * FLAT)
		disc.Transparency = 0.35 - slamEnv * 0.3
		disc.Color = discCol:Lerp(c.c1:Lerp(WHITE, 0.4), slamEnv)
		-- crack flashes: the slam wave races outward along every crack, scratches flicker them
		local wave = math.min(slamAge, Sync.since(c.bus, "touch")) * 11
		local flick = Sync.env(c.bus, "scratch", 9) * 0.25
		for _, ck in cracks do
			for j, bm in ck.beams do
				local w = (((t * 0.8 + ck.off) % 1) * 6 - j)
				local sw = wave - j
				local k = math.max(math.exp(-w * w) * 0.5, math.exp(-sw * sw * 0.7) * 0.5, flick)
				bm.Transparency = NumberSequence.new(math.clamp(0.5 - k, 0, 1))
			end
		end
		local sa = shockAge()
		B.setBeamsTransparency(shock.beams, if sa < 0.7 then 0.05 + (sa / 0.7) ^ 1.5 * 0.95 else 1)
		-- tendril growth is timed from the slam (falls back to the old free-running clock)
		local base = if slamAge == math.huge then t else slamAge
		local hot = pulling * 0.45 + slamEnv * 0.3
		for _, td in tendrils do
			local ph = if slamAge == math.huge then ((base + td.off) / 4.5) % 1 else ((base - td.lag) / 4.5) % 1
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
					p.Color = c.c1:Lerp(WHITE, math.min(1, math.exp(-d * d) * 0.7 + hot))
					p.Transparency = fade
					Core.put(p, root * CFrame.lookAt((p0 + p1) / 2, p1) * ANG(0, math.pi / 2, 0))
					last = p1
				end
			end
			Core.put(td.tip, root * CF(last))
			td.tip.Transparency = math.max(fade, if grow < 1 then 0 else 0.3)
		end
		local tw = Sync.since(c.bus, "twitch") < 0.28
		g1.TextTransparency = if tw then 0 elseif math.noise(t * 2, 1) > 0.2 then 0.8 else 0.1
		g2.TextTransparency = if tw then 0 elseif math.noise(t * 2, 7) > 0.2 then 0.8 else 0.1
		g3.TextTransparency = if tw then 0 elseif math.noise(t * 2, 13) > 0.2 then 0.8 else 0.1
		light.Brightness = 2 + Core.pulse(t, 2.2) * 1.4 + slamEnv * 4 + pulling * 1.5 + Sync.env(c.bus, "touch", 5) * 2
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
		local r = R0 + f * (R1 - R0)
		B.circle(c, {
			radius = r,
			color = c.c1,
			width = 0.08 + f * 0.06,
			tr = 0.45,
			anchor = function(t)
				return CF(math.sin(t * 1.3 + k) * 0.2 * f, g + 0.2 + f * H, math.cos(t * 1.1 + k) * 0.2 * f)
			end,
			-- the gust (Blender marker) blows the tornado rings outward, upper rings the most
			radiusFn = function()
				return r * (1 + (0.12 + 0.2 * f) * Sync.env(c.bus, "gust", 2.6) + 0.06 * Sync.env(c.bus, "swirl", 3))
			end,
		})
	end
	local sky = Core.att(c, c.root, CF(0, c.topY + 5, 0))
	local skyFx = Core.emit(sky, {
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
	local smokeFx = Core.emit(Core.att(c, c.root, CF(0, g + 0.1, 0)), {
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
	local floorFx = Core.emit(Core.volume(c, V(8, 0.1, 8), CF(0, g + 0.1, 0)), {
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
	-- Synced to the Blender animation (tools/blender/anim/auras/Datastorm.py, idle 4.8 s):
	--   swirl  (x3) each stir sweep whips      -> the tornado spins faster, glyphs flash white,
	--                                            streaks brighten, rings breathe out a little
	--   charge  arms haul up to the sky        -> sky code rain bursts, sparks stream up off
	--                                            both hands, the light swells until the strike
	--   strike  the right arm drives down      -> the lightning bolt hits the floor right where
	--                                            the hand points, ground pixel + smoke burst,
	--                                            hand spark, light 6 (also on the "touchdown"
	--                                            landing clip: the bolt hits the fist)
	--   gust    arms fling wide                -> outward blast of floor pixels, rings swell
	--   step    (free) each footfall           -> a code splash under that foot
	-- A timer bolt still fires if no strike came for 9 s (no clip playing / airborne).
	local hands: { Attachment? } = { Core.tip(c, "rhand"), Core.tip(c, "lhand") }
	local handTip = hands[1]
	local feet: { [string]: Attachment? } = { R = Core.tip(c, "rfoot"), L = Core.tip(c, "lfoot") }
	local handSpec: Core.EmitSpec = {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.2, 0),
		rate = 0,
		life = nr(0.4, 0.8),
		speed = nr(4, 8),
		spread = V2(30, 30),
		dir = Enum.NormalId.Bottom,
		drag = 2,
		rot = nr(0, 0),
		bright = 3,
	}
	local handFx: { ParticleEmitter } = {}
	for _, h in hands do
		if h then
			table.insert(handFx, Core.emit(h, handSpec))
		end
	end
	local footFx: { [string]: ParticleEmitter } = {}
	for side, ft in feet do
		if ft then
			footFx[side] = Core.emit(ft, {
				tex = T.square,
				color = cs(WHITE, c.c1),
				size = ns(0.18, 0),
				rate = 0,
				life = nr(0.3, 0.6),
				speed = nr(2, 4),
				spread = V2(70, 70),
				dir = Enum.NormalId.Bottom,
				accel = V(0, -8, 0),
				rot = nr(0, 0),
				bright = 2,
			})
		end
	end
	local boltEnd = V(2, g, 0)
	local lastStrike = -math.huge
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("strike", function()
		lastStrike = os.clock()
		-- aim at the floor under / beyond the right hand
		local d = V(2.6, 0, -1.2)
		if handTip then
			local p = c.root.CFrame:PointToObjectSpace(handTip.WorldPosition)
			local flat = V(p.X, 0, p.Z)
			if flat.Magnitude > 0.2 then
				d = flat.Unit * math.clamp(flat.Magnitude + 1.4, 2.2, 4)
			end
		end
		boltEnd = V(d.X, g, d.Z)
		floorFx:Emit(30)
		smokeFx:Emit(4)
		if handFx[1] then
			handFx[1]:Emit(16)
		end
	end)
	onEv("charge", function()
		skyFx:Emit(40)
		for _, e in handFx do
			e:Emit(10)
		end
	end)
	onEv("gust", function()
		floorFx:Emit(45)
		smokeFx:Emit(3)
	end)
	onEv("step", function(side)
		local e = footFx[side :: string]
		if e then
			e:Emit(7)
		end
	end)
	local function striking(t: number): boolean
		if Sync.since(c.bus, "strike") < 0.32 then
			return true
		end
		return t - lastStrike > 9 and (t % 3.7) < 0.28
	end
	B.bolt(c, {
		segs = 8,
		color = WHITE,
		color2 = c.c1,
		width = 0.26,
		jitter = 0.7,
		interval = 0.05,
		active = striking,
		ends = function(t)
			if Sync.since(c.bus, "strike") >= 0.32 and (t % 3.7) < 0.03 then
				local a = rng:NextNumber() * TAU
				boltEnd = V(math.cos(a) * 3.8, g, math.sin(a) * 3.8)
			end
			return V(0, g + H, 0), boltEnd
		end,
	})
	local nextT = 0
	local spin = 0
	Core.on(c, function(t, dt, root)
		local sw = Sync.env(c.bus, "swirl", 2.2)
		local gust = Sync.env(c.bus, "gust", 2)
		spin += dt * (1 + sw * 1.3 + gust * 0.8)
		local change = t >= nextT
		if change then
			nextT = t + 0.08
		end
		local flash = Sync.since(c.bus, "swirl") < 0.12 or Sync.since(c.bus, "strike") < 0.15
		for i, gl in glyphs do
			local u = (t * 0.2 + gl.off) % 1
			local a = i * 2.39 + spin * (3 - u * 1.4)
			local r = (R0 + u * (R1 - R0)) * (1 + gust * 0.25)
			gl.att.Position = V(math.cos(a) * r, g + 0.2 + u * H, math.sin(a) * r)
			gl.lbl.TextTransparency = 1 - math.sin(u * math.pi) ^ 0.5
			gl.lbl.TextColor3 = if flash and i % 3 == 0 then WHITE else c.c1
			if change and rng:NextNumber() < 0.35 then
				gl.lbl.Text = randChar(rng, "0123456789ABCDEF<>{}#$")
			end
		end
		for i, p in streaks do
			local u = (t * 0.28 + i / 24) % 1
			local a = i * 1.7 + spin * (3.4 - u * 1.4)
			local r = (R0 - 0.1 + u * (R1 - R0)) * (1 + gust * 0.25)
			Core.put(p, root * CF(math.cos(a) * r, g + 0.3 + u * H, math.sin(a) * r) * ANG(0, -a, 0) * ANG(0.9, 0, 0))
			p.Transparency = 1 - math.sin(u * math.pi) * (0.9 + 0.1 * sw)
		end
		-- the charge builds until the strike releases it
		local sc, ss = Sync.since(c.bus, "charge"), Sync.since(c.bus, "strike")
		local build = if sc < ss and sc < 1.2 then math.clamp(sc / 0.75, 0, 1) else 0
		skyFx.Rate = 34 + build * 40
		light.Brightness = if striking(t) then 6 + rng:NextNumber() * 2
			else 2 + Core.pulse(t, 1.5) * 0.6 + build * 2.5 + sw * 0.8 + gust * 1.5
	end)
end

-- scanlines sweeping the body, blue projector cone from below
-- 43 parts / 3 emitters
A.Hologram = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local base = Core.part(c, V(0.14, 3.6, 3.6), Color3.fromRGB(18, 22, 32), METAL, 0, CYL)
	local lens = Core.part(c, V(0.5, 0.5, 0.5), c.c1, NEON, 0, BALL)
	local baseRing = B.ring(c, {
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
	local lensFx = Core.emit(lensAtt, {
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
	local floorFx = Core.emit(Core.volume(c, V(7, 0.1, 7), CF(0, g + 0.1, 0)), {
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

	-- Synced to the Blender animation (tools/blender/anim/auras/Hologram.py, idle 4.4 s, the
	-- body itself moves in 15 fps projector steps):
	--   hand / turn   it studies its hand       -> pixel sparkles off the right hand, panel 1
	--                                              reads HAND.OBJ, a skin flicker on the turn
	--   drop          the signal dropout         -> skin jumps sideways and flickers for the
	--                                              whole dropout, discs blink out, panels almost
	--                                              vanish, light dips, lens spits pixels
	--   calib         the T-pose snap            -> all three scan discs sweep top -> bottom
	--                                              together, panels read CALIBRATING, the base
	--                                              ring flashes white, light flash
	--   scan  (x3)    head scan steps            -> pixel puff off the head
	--   glance        it looks at a panel        -> the panel on its left lights up
	--   flick (walk)  the sideways signal jump   -> skin offset for two frames
	--   rez (landing clip) re-materialise        -> disc sweep + sparkles from the floor
	--   step (free)   footfall                   -> a pixel splash at that foot
	-- And back: a random projector glitch emits "flicker", the body's additive "twitch" clip
	-- jerks the head and shoulders on the same frame.
	local handTip, headTip = Core.tip(c, "rhand"), Core.tip(c, "head")
	local feet: { [string]: Attachment? } = { R = Core.tip(c, "rfoot"), L = Core.tip(c, "lfoot") }
	local pix: Core.EmitSpec = {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.16, 0),
		rate = 0,
		life = nr(0.35, 0.7),
		speed = nr(1.5, 3.5),
		spread = V2(180, 180),
		drag = 3,
		rot = nr(0, 0),
		bright = 2.5,
	}
	local handFx = if handTip then Core.emit(handTip, pix) else nil
	local headFx = if headTip then Core.emit(headTip, pix) else nil
	local footFx: { [string]: ParticleEmitter } = {}
	for side, ft in feet do
		if ft then
			footFx[side] = Core.emit(ft, pix)
		end
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	local function glitchFor(dur: number)
		gUntil = math.max(gUntil, os.clock() + dur)
	end
	local handUntil = 0
	onEv("hand", function()
		if handFx then
			handFx:Emit(14)
		end
		handUntil = os.clock() + 1.6
		panels[1].lbl.Text = "HAND.OBJ"
	end)
	onEv("turn", function()
		if handFx then
			handFx:Emit(10)
		end
		glitchFor(0.07)
	end)
	onEv("drop", function()
		glitchFor(0.38)
		lensFx:Emit(20)
	end)
	onEv("calib", function()
		floorFx:Emit(16)
		for _, pn in panels do
			pn.lbl.Text = "CALIBRATING"
		end
		nextTxt = os.clock() + 1.4
	end)
	onEv("scan", function()
		if headFx then
			headFx:Emit(8)
		end
	end)
	onEv("flick", function()
		glitchFor(0.07)
	end)
	onEv("rez", function()
		glitchFor(0.12)
		floorFx:Emit(24)
	end)
	onEv("step", function(side)
		local e = footFx[side :: string]
		if e then
			e:Emit(6)
		end
	end)
	local nextRand = os.clock() + 2
	local ringCols: { Color3 } = {}
	for k, rp in baseRing do
		ringCols[k] = rp.Color
	end
	local ringLit = false
	Core.on(c, function(t, _, root)
		-- random projector glitch (rarer now: the animation supplies the big ones)
		if t >= nextRand then
			nextRand = t + 2.2 + rng:NextNumber() * 3
			glitchFor(0.1)
			Sync.emit(c.bus, "flicker")
		end
		local glitching = t < gUntil
		gx = if glitching then (rng:NextNumber() - 0.5) * (if Sync.since(c.bus, "drop") < 0.4 then 1 else 0.6) else 0
		local fl = if glitching then (if rng:NextNumber() < 0.5 then 0.6 else 0.9) else 0
		for _, p in skin do
			p.Transparency = fl
		end
		Core.put(base, root * CF(0, g + 0.07, 0) * FLAT)
		Core.put(lens, root * CF(0, g + 0.25, 0))
		-- scan discs: shared beat with the idle (2 sweeps per loop); calib / rez = one fast
		-- top -> bottom sweep of all three together
		local cw = Sync.window(c.bus, "calib", 0.7)
		local rw = Sync.window(c.bus, "rez", 0.6)
		local sweep = if cw >= 0 then cw elseif rw >= 0 then rw else -1
		local ph = Sync.phase(c.bus, 2.2)
		for k, d in discs do
			if sweep >= 0 then
				local u = math.clamp(1 - sweep * 1.15 + (k - 1) * 0.08, 0, 1)
				Core.put(d, root * CF(0, g + u * span, 0) * FLAT)
				d.Transparency = 0.15 + sweep * 0.5
			else
				local u = (ph + k / 3) % 1
				Core.put(d, root * CF(0, g + u * span, 0) * FLAT)
				d.Transparency = if glitching and Sync.since(c.bus, "drop") < 0.4 then 1
					else 0.55 + 0.45 * math.abs(u - 0.5) * 2
			end
		end
		local calibFlash = Sync.env(c.bus, "calib", 4)
		if calibFlash > 0.002 or ringLit then
			ringLit = calibFlash > 0.002
			for k, rp in baseRing do
				rp.Color = ringCols[k]:Lerp(WHITE, calibFlash)
			end
		end
		if t >= nextTxt and t >= handUntil then
			nextTxt = t + 1.2
			local k = rng:NextInteger(1, 3)
			panels[k].lbl.Text = Core.pick(texts, rng)
		end
		-- glance: the panel closest to its left side lights up
		local gw = Sync.window(c.bus, "glance", 0.9)
		local best, bestScore = 0, -math.huge
		if gw >= 0 then
			for i = 1, #panels do
				local a = (i - 1) / 3 * TAU + t * 0.4
				local score = -math.cos(a) - 0.4 * math.sin(a)
				if score > bestScore then
					best, bestScore = i, score
				end
			end
		end
		for i, pn in panels do
			local a = (i - 1) / 3 * TAU + t * 0.4
			local cf = root * outward(a, 3.4, c.chestY + 0.4 + math.sin(t * 1.3 + i) * 0.2)
			Core.put(pn.p, cf)
			Core.put(pn.top, cf * CF(0, 0.52, 0))
			Core.put(pn.bot, cf * CF(0, -0.52, 0))
			pn.p.Transparency = if glitching then 0.95
				elseif i == best then 0.7 - 0.5 * (1 - gw)
				elseif cw >= 0 then 0.45
				else 0.7
		end
		light.Brightness = if glitching and Sync.since(c.bus, "drop") < 0.4 then 0.6
			else 2 + math.noise(t * 4, 2) * 1 + calibFlash * 3
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
	-- Synced to the Blender animation (tools/blender/anim/auras/ZeroDay.py): the countdown
	-- runs on the idle's 6 s loop (Sync.phase, shared from the attach moment), so the digits
	-- hit 00.0 on the very frame the body detonates (marker "zero", 5.6 s into the loop).
	local PERIOD = 6
	local ZERO_T = 5.6
	local function cycle(): number
		return Sync.phase(c.bus, PERIOD) * PERIOD
	end
	local function remaining(): number
		return (ZERO_T - cycle()) % PERIOD
	end
	local function strike(_t: number): boolean
		local tc = cycle()
		return (tc >= ZERO_T and tc < ZERO_T + 0.4) or Sync.since(c.bus, "slam") < 0.3
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
	-- "charge" marker (the crouch before zero) until the detonation: 1, else 0
	local function chargeOn(): number
		local sc, sz = Sync.since(c.bus, "charge"), Sync.since(c.bus, "zero")
		return if sc < sz and sc < 1.6 then 1 else 0
	end
	-- charge arcs: fast white-hot crackle from the floor ring up into the crouching body
	B.bolt(c, {
		segs = 6,
		color = WHITE,
		color2 = c.c1,
		width = 0.16,
		jitter = 0.4,
		interval = 0.03,
		flicker = 0.25,
		active = function()
			return chargeOn() > 0
		end,
		ends = function()
			local a = rng:NextNumber() * TAU
			return V(math.cos(a) * 4.6, g + 0.05, math.sin(a) * 4.6), V(math.cos(a) * 0.6, c.chestY - 0.8, math.sin(a) * 0.6)
		end,
	})
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
	local _, big, bigGui = B.glyph(c, "T-06.0", c.c1, V2(2.6, 0.55), F.pixel, CF(0, c.topY + 1.1, 0), Color3.new(0.1, 0, 0))
	local feet = Core.volume(c, V(7, 0.1, 7), CF(0, g + 0.1, 0))
	local floorFx = Core.emit(feet, {
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
	local smokeFx = Core.emit(feet, {
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
	--   tap   (x3) toe slaps            -> a white tick chases round the floor ring, sparks
	--                                       pop from the right foot
	--   watch       the wrist comes up    -> a small countdown lights up on the left wrist
	--   tick  (x2)  the index taps it     -> wrist digits flash white, tiny sparks
	--   look        it looks up           -> the big T- label flares and swells
	--   charge      the crouch            -> arcs crackle faster, smoke thickens, light builds
	--   zero        DETONATION            -> (the phase-timed lightning starts on this frame)
	--                                       spark bursts from both hands and the floor
	--   slam  (landing clip) fist hits    -> lightning + ring flash + floor sparks
	--   step  (free) footfall             -> sparks kick off that foot
	local handR, handL = Core.tip(c, "rhand"), Core.tip(c, "lhand")
	local footR, footL = Core.tip(c, "rfoot"), Core.tip(c, "lfoot")
	local spark: Core.EmitSpec = {
		tex = T.fireSpark,
		color = cs(WHITE, c.c1),
		size = ns(0.26, 0),
		rate = 0,
		life = nr(0.3, 0.65),
		speed = nr(3, 7),
		spread = V2(80, 80),
		accel = V(0, -10, 0),
		bright = 3,
	}
	local fx: { [string]: ParticleEmitter } = {}
	local tips: { [string]: Attachment? } = { rhand = handR, lhand = handL, R = footR, L = footL }
	for name, tip in tips do
		if tip then
			fx[name] = Core.emit(tip, spark)
		end
	end
	local function burst(name: string, n: number)
		local e = fx[name]
		if e then
			e:Emit(n)
		end
	end
	-- wrist countdown (rides the left hand, faces the camera)
	local wristLbl: TextLabel? = nil
	if handL then
		local _, l = Core.glyph(c, handL, "", c.c1, V2(1.3, 0.35), F.pixel, Color3.new(0.1, 0, 0))
		l.TextTransparency = 1
		wristLbl = l
	end
	local bigSize = bigGui.Size
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("tap", function()
		burst("R", 7)
	end)
	onEv("tick", function()
		burst("lhand", 5)
	end)
	onEv("zero", function()
		burst("rhand", 26)
		burst("lhand", 26)
		floorFx:Emit(30)
		smokeFx:Emit(4)
	end)
	onEv("slam", function()
		burst("rhand", 20)
		floorFx:Emit(24)
	end)
	onEv("step", function(side)
		burst(side :: string, 5)
	end)
	Core.on(c, function(t, _, root)
		local rem = remaining()
		local st = strike(t)
		local charging = chargeOn()
		local disp = string.format("%04.1f", rem)
		-- watch: fade in while the wrist is up (~0.7 s), white flash on every tap of the index
		if wristLbl then
			local sw = Sync.since(c.bus, "watch")
			local vis = if sw < 0.75 then math.min(1, sw / 0.12, (0.75 - sw) / 0.15) else 0
			wristLbl.TextTransparency = 1 - vis
			wristLbl.Text = "T-" .. disp
			wristLbl.TextColor3 = if Sync.since(c.bus, "tick") < 0.1 then WHITE else c.c1
		end
		local look = Sync.env(c.bus, "look", 1.6)
		bigGui.Size = UDim2.new(bigSize.X.Scale * (1 + look * 0.35), 0, bigSize.Y.Scale * (1 + look * 0.35), 0)
		smokeFx.Rate = 6 + charging * 10
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
				p.lbl.Text = prefixes[i] .. disp
			end
		end
		local lit = rem / PERIOD * NR
		local tapS = Sync.since(c.bus, "tap")
		local chase = if tapS < 0.3 then math.floor(tapS / 0.3 * NR) + 1 else -1
		for k, p in ringParts do
			if st or k == chase or k == chase - 1 then
				p.Color = WHITE
				p.Transparency = 0
			elseif k <= lit then
				p.Color = c.c1
				p.Transparency = if rem < 2 and math.sin(t * 20) > 0 then 0.5 else 0
			else
				p.Color = c.c2:Lerp(c.c1, 0.15)
				p.Transparency = 0.6
			end
		end
		big.Text = if st then "ZERO DAY" else "T-" .. disp
		big.TextColor3 = if st or look > 0.4 then WHITE else c.c1
		light.Brightness = if st then 6 + rng:NextNumber() * 4
			else 1.8 + Core.pulse(t, 1) * 0.8 + charging * 1.5 * math.min(1, Sync.since(c.bus, "charge")) + look * 1.5
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
	local floorSmoke = Core.emit(Core.att(c, c.root, CF(0, g + 0.3, 0)), smoke)
	smoke.spread = V2(180, 180)
	smoke.rate = 8
	smoke.size = ns(2, 4.5)
	local bodySmoke = Core.emit(Core.att(c, c.torso), smoke)
	local S = 1.5
	local yb = c.topY + 1
	local metal = Color3.fromRGB(22, 22, 26)
	local base = Core.part(c, V(0.14, 0.55, 0.55) * S, metal, METAL, 0, CYL)
	local dome = Core.part(c, V(0.44, 0.44, 0.44) * S, c.c1, NEON, 0.35, BALL)
	local refl = Core.part(c, V(0.05, 0.28, 0.14) * S, WHITE, NEON, 0)
	local spotAtt = Core.att(c, nil, CF(0, yb + 0.25, 0))
	local spots: { SpotLight } = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local s = Instance.new("SpotLight")
		s.Face = face
		s.Angle = 50
		s.Range = 22
		s.Brightness = 8
		s.Color = c.c1
		s.Shadows = false
		s.Parent = spotAtt
		table.insert(spots, s)
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
	local sparkSpec: Core.EmitSpec = {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0.36, 0),
		rate = 0,
		life = nr(0.25, 0.5),
		speed = nr(6, 10),
		spread = V2(180, 180),
		accel = V(0, -20, 0),
		bright = 3,
	}
	local sparkAtt = Core.att(c, c.torso)
	local sparks = Core.emit(sparkAtt, sparkSpec)
	bodyGlow(c, c.c1, 8, 0.9)
	local _, sign =
		B.glyph(c, "GRID://OFFLINE", c.c1, V2(2.8, 0.38), F.pixel, CF(0, yb + 0.95, 0), Color3.new(0.15, 0, 0))

	-- Synced to the Blender animation (tools/blender/anim/auras/Blackout.py). The idle is 4.8 s =
	-- four strobe periods, and the strobe runs on the bus clock (Sync.phase 1.2 s), so every
	-- marker lands on a flash:
	--   "wake"  -> AWAKE: strobes / pillars / beacon at full power, sparks burst from both hands,
	--              the floor ring flashes, a smoke burst rolls out, the sign reads "IT WAKES"
	--   "dark"  -> DORMANT: the power drains to an ember, the smoke thickens
	--   "twitch"-> the dome blinks out, sparks crackle at the head, the sign glitches
	--   "scan"  -> the beacon spotlights stop spinning and lock onto where the head looks
	--   "surge" -> chest spark explosion, every pillar and LED flares, light spike
	--   "stomp" (walk, payload "R"/"L") -> red shock ring + smoke puff under that foot
	--   "jolt" (reaction "short", fired by the VFX on a random spark crackle) -> hand sparks
	--   "impact" (reaction "slam" on landing) -> big smoke burst + shock ring + floor sparks
	local function tipEmit(which: string, spec: Core.EmitSpec): ParticleEmitter?
		local a = Core.tip(c, which)
		return if a then Core.emit(a, spec) else nil
	end
	sparkSpec.speed = nr(8, 14)
	sparkSpec.life = nr(0.3, 0.6)
	local handSparks = { tipEmit("rhand", sparkSpec), tipEmit("lhand", sparkSpec) }
	sparkSpec.speed = nr(3, 6)
	sparkSpec.size = ns(0.26, 0)
	local headSparks = tipEmit("head", sparkSpec)
	local headAtt = Core.tip(c, "head")
	local feet: { [string]: Attachment? } = { R = Core.tip(c, "rfoot"), L = Core.tip(c, "lfoot") }
	local stompAtt = Core.att(c, c.root, CF(0, g + 0.08, 0))
	local shock = Core.emit(stompAtt, {
		tex = T.shock,
		color = cs(WHITE, c.c1),
		size = ns(0.6, 5),
		transp = ns(0.1, 1),
		rate = 0,
		life = nr(0.45),
		speed = nr(0.01),
		orient = Enum.ParticleOrientation.VelocityPerpendicular,
		bright = 3,
	})
	local puff = Core.emit(stompAtt, {
		tex = T.smoke,
		color = cs(Color3.fromRGB(10, 4, 6), Color3.fromRGB(40, 6, 8)),
		size = ns(1, 3.2),
		transp = ns(0.4, 1),
		rate = 0,
		life = nr(0.8, 1.3),
		speed = nr(2, 4),
		spread = V2(80, 80),
		drag = 3,
		rotSpeed = nr(-40, 40),
		light = 0,
		bright = 1,
	})
	local function emitAll(list: { ParticleEmitter? }, k: number)
		for _, e in list do
			if e then
				e:Emit(k)
			end
		end
	end
	local function on(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	on("wake", function()
		emitAll(handSparks, 18)
		floorSmoke:Emit(10)
		stompAtt.Position = V(0, g + 0.08, 0)
		shock:Emit(1)
	end)
	on("dark", function()
		bodySmoke:Emit(8)
		floorSmoke:Emit(6)
	end)
	on("twitch", function()
		if headSparks then
			headSparks:Emit(10)
		end
	end)
	on("surge", function()
		sparkAtt.Position = V(0, 0.3, -0.4)
		sparks:Emit(40)
		emitAll(handSparks, 10)
	end)
	on("jolt", function()
		emitAll(handSparks, 8)
	end)
	on("stomp", function(side)
		local a = feet[if side == "L" then "L" else "R"]
		if not a then
			return
		end
		local p = c.root.CFrame:PointToObjectSpace(a.WorldPosition)
		stompAtt.Position = V(p.X, g + 0.08, p.Z)
		shock:Emit(1)
		puff:Emit(4)
	end)
	on("impact", function()
		stompAtt.Position = V(0, g + 0.08, 0)
		shock:Emit(2)
		puff:Emit(14)
		floorSmoke:Emit(8)
		sparkAtt.Position = V(0, -0.8, 0)
		sparks:Emit(24)
	end)
	local function awake(): boolean
		local sw, sd = Sync.since(c.bus, "wake"), Sync.since(c.bus, "dark")
		if sw == math.huge and sd == math.huge then
			return true -- no clip playing: stay powered
		end
		return sw < sd
	end
	local power = 1
	local beaconYaw = 0
	local ringHead = 0
	local nextSpark = 0
	local lastText = ""
	local function setText(s: string)
		if s ~= lastText then
			lastText = s
			sign.Text = s
		end
	end
	Core.on(c, function(t, dt, root)
		-- power level: snaps up on wake, drains slowly on dark
		local target = if awake() then 1 else 0.18
		power += (target - power) * math.min(1, dt * (if target > power then 14 else 1.6))
		local wake = Sync.env(c.bus, "wake", 3)
		local surge = Sync.window(c.bus, "surge", 0.35) >= 0
		local twitch = Sync.window(c.bus, "twitch", 0.12) >= 0
		floorSmoke.Rate = 12 + (1 - power) * 10
		-- beacon: spins with the power; during a scan it locks onto the head's look direction
		local scan = Sync.window(c.bus, "scan", 1.2)
		if scan >= 0 and headAtt then
			local d = root:VectorToObjectSpace(headAtt.WorldCFrame.LookVector)
			local want = math.atan2(-d.X, -d.Z)
			local diff = (want - beaconYaw + math.pi) % TAU - math.pi
			beaconYaw += diff * math.min(1, dt * 18)
		else
			beaconYaw += dt * 6 * (0.25 + power * 0.75)
		end
		local bcf = root * CF(0, yb, 0)
		Core.put(base, bcf * FLAT)
		Core.put(dome, bcf * CF(0, 0.15 * S, 0))
		Core.put(refl, bcf * CF(0, 0.17 * S, 0) * ANG(0, beaconYaw, 0))
		spotAtt.CFrame = CF(0, yb + 0.25, 0) * ANG(0, beaconYaw, 0)
		for _, s in spots do
			s.Brightness = 8 * power + wake * 6 + (if scan >= 0 then 4 else 0)
		end
		-- strobe on the bus clock (same 1.2 s grid as the idle markers)
		local ph = Sync.phase(c.bus, 1.2) * 1.2
		local on = ph < 0.06 or (ph > 0.14 and ph < 0.2)
		strobe.Brightness = (if on then 8 * power else 0.4 * power) + wake * 10 + (if surge then 9 else 0)
		dome.Transparency = if twitch then 1 elseif on then 0.3 * (1 - power) else 0.35 + (1 - power) * 0.4
		ringHead = (ringHead + dt * 10 * (0.3 + power * 0.7)) % n
		local flash = math.max(wake, Sync.env(c.bus, "impact", 4))
		for k, p in ring do
			local d = (ringHead - (k - 1)) % n
			p.Color = c.c2:Lerp(c.c1, math.exp(-d * 0.6) * (0.35 + power * 0.65)):Lerp(WHITE, flash * 0.8)
		end
		local pairOn = math.floor(t / 0.6) % 2
		for i, p in pillars do
			local a = (i - 1) / 4 * TAU + math.pi / 4
			Core.put(p, root * CF(math.cos(a) * 4.2, g + PH / 2, math.sin(a) * 4.2))
			local mine = (i % 2) == pairOn
			local tr = if mine and on then 0 elseif mine then 0.55 else 0.9
			tr = 1 - (1 - tr) * power
			p.Transparency = if surge then 0 else math.min(tr, 1 - wake)
		end
		for i, p in leds do
			local a = (i - 1) / 4 * TAU - t * 0.8
			Core.put(p, root * CF(math.cos(a) * 2, -0.2 + math.sin(t + i) * 0.4, math.sin(a) * 2))
			p.Transparency = if surge or (math.sin(t * 5 + i * 2) > 0.3 and power > 0.5) then 0 else 0.9
		end
		if t >= nextSpark then
			nextSpark = t + (0.5 + rng:NextNumber() * 1.4) / (0.4 + power * 0.6)
			sparkAtt.Position =
				V((rng:NextNumber() - 0.5) * 1.6, (rng:NextNumber() - 0.5) * 1.6, (rng:NextNumber() - 0.5) * 0.6)
			local k = rng:NextInteger(8, 14)
			sparks:Emit(k)
			-- a big crackle shocks the body (one-shot "short" clip)
			if k >= 12 and Sync.since(c.bus, "short") > 2.5 then
				Sync.emit(c.bus, "short")
			end
		end
		if Sync.window(c.bus, "wake", 1.4) >= 0 then
			setText("!! IT WAKES !!")
			sign.TextTransparency = if math.floor(t * 8) % 2 == 0 then 0 else 0.3
		else
			setText("GRID://OFFLINE")
			local glitch = twitch or math.noise(t * 3, 3) > 0.25
			sign.TextTransparency = if glitch then 0.85 else 0.05 + (1 - power) * 0.5
		end
	end)
end

-- rainbow-cycling prism rings and colour-split ghosts
-- 77 parts / 3 emitters
A.Chromatic = function(c: Ctx)
	-- Synced to the Blender animation (tools/blender/anim/auras/Chromatic.py). The idle loop is
	-- 4.0 s = one hue cycle on the bus clock, so every dance move always lands on the same colour.
	--   "arc" (payload "rhand") -> rainbow ribbon trails the right hand through the big sweep
	--   "strike"   -> prism flashes and spins fast, rays flare, rings punch out, burst from the
	--                 raised right hand, light spike
	--   "split"    -> the colour ghosts tear far apart and the hue jumps half a cycle
	--   "spectrum" -> rainbow bursts + ribbons from both hands, rays flare wide, rings pulse
	--   "pop" (walk, payload "R"/"L") -> rainbow pixel splash from that foot, floor ring flash
	--   "flare" (reaction "vogue" on landing) -> big chest burst, every ring punches out
	local function env(name: string, rate: number): number
		return Sync.env(c.bus, name, rate)
	end
	local function hue(): number
		return (Sync.phase(c.bus, 4) + env("split", 2.5) * 0.5) % 1
	end
	local function punch(): number
		return env("strike", 5) * 1.1 + env("spectrum", 4) * 0.9 + env("flare", 4) * 1.4
	end
	B.ring(c, {
		n = 20,
		radius = 3.4,
		seg = V(0.14, 0.16, 0),
		color = c.c1,
		spin = 1.2,
		anchor = function()
			return CF(0, -0.2, 0)
		end,
		radiusFn = function()
			return 3.4 + punch()
		end,
		paint = function(k, _t, p)
			p.Color = Color3.fromHSV((k / 20 + hue()) % 1, 0.85, 1)
		end,
	})
	B.ring(c, {
		n = 18,
		radius = 2.7,
		seg = V(0.12, 0.14, 0),
		color = c.c2,
		spin = -1.6,
		anchor = function(t)
			return CF(0, c.chestY + 0.1, 0) * ANG(0, -t * 0.4, 0) * ANG(1.2 - env("spectrum", 3) * 0.9, 0, 0)
		end,
		radiusFn = function()
			return 2.7 + punch() * 0.7
		end,
		paint = function(k, _t, p)
			p.Color = Color3.fromHSV((k / 18 + hue() + 0.5) % 1, 0.85, 1)
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
		radiusFn = function()
			return 4.4 + punch() * 0.6 + env("pop", 9) * 0.35
		end,
		paint = function(k, _t, p)
			p.Color = Color3.fromHSV((k / 14 - hue() * 1.2) % 1, 0.9, 1):Lerp(WHITE, env("pop", 8) * 0.6)
		end,
	})
	-- colour-split ghosts: they tear apart on "split" and widen on "spectrum"
	local function sep(t: number): number
		return math.sin(t * 2) * 0.12 + env("split", 3) * 1.3 + env("spectrum", 4) * 0.5
	end
	local g1 = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = NEON,
		tr = 0.65,
		delay = 0.08,
		map = B.offsetMap(function(t)
			return CF(-0.45 - sep(t), env("split", 3) * 0.2, 0.2)
		end),
	})
	local g2 = B.clones(c, {
		set = "lite",
		color = c.c2,
		mat = NEON,
		tr = 0.7,
		delay = 0.17,
		map = B.offsetMap(function(t)
			return CF(0.45 + sep(t), -env("split", 3) * 0.2, 0.35)
		end),
	})
	local yP = c.topY + 1.3
	local PS = 1
	local prism = B.tri(c, PS, 0.1, WHITE)
	local center = Core.att(c, nil, CF(0, yP, 0))
	local src = Core.att(c, nil, CF(-2.8, yP + 0.4, 0))
	local inBeam = Core.beam(c, src, center, WHITE, 0.12, { tr = ns(0.7, 0) })
	local rays: { Beam } = {}
	local rayOut: { Attachment } = {}
	for k = 1, 5 do
		local out = Core.att(c, nil, CF(3, yP - 0.6 + (k - 1) * 0.3, 0))
		rayOut[k] = out
		rays[k] =
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
	-- body-driven pieces: hand bursts + ribbons, foot splashes, chest burst
	local burst: Core.EmitSpec = {
		tex = T.spark,
		color = Core.rainbow(6),
		size = ns(0.45, 0),
		rate = 0,
		life = nr(0.5, 1),
		speed = nr(6, 12),
		spread = V2(180, 180),
		drag = 3,
		bright = 3,
	}
	local function tipEmit(which: string, spec: Core.EmitSpec, off: CFrame?): ParticleEmitter?
		local a = Core.tip(c, which, off)
		return if a then Core.emit(a, spec) else nil
	end
	local rBurst = tipEmit("rhand", burst)
	local lBurst = tipEmit("lhand", burst)
	local chestBurst = tipEmit("chest", burst)
	local pix: Core.EmitSpec = {
		tex = T.square,
		color = Core.rainbow(6),
		size = ns(0.3, 0),
		rate = 0,
		life = nr(0.4, 0.8),
		speed = nr(3, 6),
		spread = V2(70, 70),
		accel = V(0, -6, 0),
		rotSpeed = nr(-200, 200),
		bright = 2,
	}
	local feet: { [string]: ParticleEmitter? } = { R = tipEmit("rfoot", pix), L = tipEmit("lfoot", pix) }
	local function ribbon(which: string): Trail?
		local a0 = Core.tip(c, which, CF(0, 0.15, 0))
		local a1 = Core.tip(c, which, CF(0, 0.85, 0))
		if not (a0 and a1) then
			return nil
		end
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = Core.rainbow(6)
		tr.Transparency = ns(0.15, 1)
		tr.Lifetime = 0.4
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.Enabled = false
		tr.Parent = a0
		return tr
	end
	local rTrail = ribbon("rhand")
	local lTrail = ribbon("lhand")
	local function emit(e: ParticleEmitter?, k: number)
		if e then
			e:Emit(k)
		end
	end
	local function on(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	on("strike", function()
		emit(rBurst, 26)
	end)
	on("spectrum", function()
		emit(rBurst, 22)
		emit(lBurst, 22)
	end)
	on("split", function()
		emit(chestBurst, 12)
	end)
	on("pop", function(side)
		emit(feet[if side == "L" then "L" else "R"], 10)
	end)
	on("flare", function()
		emit(chestBurst, 40)
		emit(rBurst, 12)
		emit(lBurst, 12)
	end)
	local spin = 0
	Core.on(c, function(_t, dt, root)
		local h = hue()
		local ca = Color3.fromHSV(h, 0.9, 1)
		local cb = Color3.fromHSV((h + 0.33) % 1, 0.9, 1)
		for _, p in g1 do
			p.Color = ca
		end
		for _, p in g2 do
			p.Color = cb
		end
		local hit = env("strike", 4)
		local spec = env("spectrum", 3)
		spin += dt * (1.4 + hit * 14 + spec * 8)
		B.putTri(prism, root * CF(0, yP + hit * 0.25, 0) * ANG(0, spin, 0), PS)
		local flare = math.max(hit, spec)
		for k, b in rays do
			b.Width1 = 0.3 + flare * 0.9
			b.Width0 = 0.08 + flare * 0.12
			rayOut[k].Position = V(3 + spec * 1.5, yP - 0.6 + (k - 1) * (0.3 + spec * 0.35), 0)
		end
		inBeam.Width0 = 0.12 + hit * 0.25
		if rTrail then
			rTrail.Enabled = Sync.window(c.bus, "arc", 0.5) >= 0 or Sync.window(c.bus, "spectrum", 0.6) >= 0
				or Sync.window(c.bus, "flare", 0.5) >= 0
		end
		if lTrail then
			lTrail.Enabled = Sync.window(c.bus, "spectrum", 0.6) >= 0 or Sync.window(c.bus, "flare", 0.5) >= 0
		end
		light.Color = ca
		light.Brightness = 2.4 + hit * 4 + spec * 4 + env("flare", 4) * 5 + env("pop", 9) * 0.8
		glow.Color = cs(ca)
	end)
end

return A
