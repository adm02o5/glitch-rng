--!strict
-- AuraFX/AurasLow: BASIC and ENHANCED tier auras (subtle, readable, still detailed).

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

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

local A: { [string]: (Ctx) -> () } = {}

---------------------------------------------------------------- BASIC

-- few slow white square pixels drifting up
A.Pixel = function(c: Ctx)
	local feet = Core.att(c, c.root, CF(0, c.groundY + 0.2, 0))
	Core.emit(feet, {
		tex = T.square,
		color = cs(c.c1),
		size = ns(0.13, 0.1, 0),
		transp = ns(1, 0.15, 0.3, 1),
		rate = 4,
		life = nr(2.6, 3.6),
		speed = nr(0.5, 1),
		spread = V2(40, 40),
		accel = V(0, 0.3, 0),
		rot = nr(0, 0),
		bright = 2,
	})
	local px: { BasePart } = {}
	for i = 1, 6 do
		px[i] = Core.part(c, V(0.17, 0.17, 0.17), if i % 3 == 0 then c.c2:Lerp(c.c1, 0.5) else c.c1)
	end
	local span = c.topY - c.groundY + 1.2
	Core.on(c, function(t, _, root)
		for i, p in px do
			local per = 3.4 + i * 0.41
			local u = t / per + i * 0.173
			local ph = u % 1
			local cyc = math.floor(u)
			local a = i * 2.39 + cyc * 2.1
			local r = 1.3 + ((i + cyc) % 3) * 0.3
			local sway = math.sin(t * 1.3 + i) * 0.12
			Core.put(
				p,
				root * CF(math.cos(a) * r + sway, c.groundY + 0.2 + ph * span, math.sin(a) * r) * ANG(0, t * 0.6 + i, 0)
			)
			p.Transparency = 1 - math.sin(ph * math.pi) * 0.95
		end
	end)
end

-- grey flickering noise specks around the body
A.Static = function(c: Ctx)
	local rng = c.rng
	local h = c.topY - c.groundY
	local vol = Core.volume(c, V(2.6, h, 1.8), CF(0, (c.topY + c.groundY) / 2, 0))
	local e = Core.emit(vol, {
		tex = T.square,
		color = cs(c.c2, WHITE, c.c1),
		size = ns(0.09, 0.07),
		transp = ns(0.1, 0.6),
		rate = 40,
		life = nr(0.05, 0.16),
		rot = nr(0, 0),
		light = 0.6,
		shape = Enum.ParticleEmitterShape.Box,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	local specks: { BasePart } = {}
	local loc: { CFrame } = {}
	local nextT: { number } = {}
	for i = 1, 9 do
		specks[i] = Core.part(c, V(0.02, 0.05 + rng:NextNumber() * 0.05, 0.14 + rng:NextNumber() * 0.12), c.c1)
		loc[i] = CF(0, -50, 0)
		nextT[i] = 0
	end
	local track = Core.part(c, V(2.4, 0.03, 0.03), c.c1, NEON, 0.4)
	Core.on(c, function(t, _, root)
		for i, p in specks do
			if t >= nextT[i] then
				nextT[i] = t + 0.04 + rng:NextNumber() * 0.12
				local a = rng:NextNumber() * TAU
				local r = 0.9 + rng:NextNumber() * 0.8
				loc[i] = CF(math.cos(a) * r, c.groundY + 0.3 + rng:NextNumber() * h, math.sin(a) * r) * ANG(0, -a, 0)
				p.Color = if rng:NextNumber() < 0.5 then c.c1 else c.c2:Lerp(WHITE, rng:NextNumber())
				p.Transparency = if rng:NextNumber() < 0.25 then 1 else rng:NextNumber() * 0.4
			end
			Core.put(p, root * loc[i])
		end
		-- VHS tracking line rolling up the body
		local ph = (t / 1.3) % 1
		Core.put(track, root * CF(0, c.groundY + ph * (h + 0.4), -0.05))
		track.Transparency = 0.35 + 0.6 * ph
		-- periodic "lost signal" bursts
		e.Rate = if (t % 5.3) < 0.35 then 170 else 40
	end)
end

-- 8 tiny cyan cubes orbiting the waist
A.Byte = function(c: Ctx)
	local rng = c.rng
	local y = -0.15
	local cubes: { BasePart } = {}
	local bits: { boolean } = {}
	for i = 1, 8 do
		cubes[i] = Core.part(c, V(0.26, 0.26, 0.26), c.c1)
		Core.trail(cubes[i], c.c1, 0.16, 0.22)
		bits[i] = rng:NextNumber() < 0.5
	end
	B.circle(c, { radius = 1.85, color = c.c2, width = 0.035, at = CF(0, y, 0), tr = 0.5 })
	local _, lbl = B.glyph(c, "", c.c1, V2(1.6, 0.26), F.pixel, CF(0, y + 0.5, -2.05), c.c2)
	Core.light(Core.att(c, c.root, CF(0, y, 0)), c.c1, 0.6, 7)
	local nextFlip = 0
	local spinUntil: { number } = table.create(8, 0)
	Core.on(c, function(t, _, root)
		if t >= nextFlip then
			nextFlip = t + 0.4
			local k = rng:NextInteger(1, 8)
			bits[k] = not bits[k]
			spinUntil[k] = t + 0.35
		end
		local s = table.create(8)
		for i, p in cubes do
			local a = t * 1.1 + (i - 1) / 8 * TAU
			local bob = math.sin(t * 2 + i * 0.8) * 0.12
			local flip = if t < spinUntil[i] then (spinUntil[i] - t) * 18 else 0
			Core.put(
				p,
				root * CF(math.cos(a) * 1.85, y + bob, math.sin(a) * 1.85) * ANG(t * 1.5 + i + flip, t * 2 + i, 0)
			)
			p.Color = if bits[i] then c.c1 else c.c2
			p.Transparency = if bits[i] then 0 else 0.3
			s[i] = if bits[i] then "1" else "0"
		end
		lbl.Text = table.concat(s)
	end)
end

-- green radar pulse ring expanding from feet every 2s
A.Ping = function(c: Ctx)
	local g = c.groundY + 0.05
	local dot = Core.part(c, V(0.06, 0.34, 0.34), c.c1, NEON, 0, CYL)
	B.circle(c, { radius = 0.9, color = c.c2, width = 0.05, at = CF(0, g, 0), tr = 0.25 })
	B.circle(c, { radius = 1.8, color = c.c2, width = 0.04, at = CF(0, g, 0), tr = 0.45 })
	local arm = Core.part(c, V(1.8, 0.03, 0.06), c.c1)
	local fan: { BasePart } = {}
	for i = 1, 4 do
		fan[i] = Core.part(c, V(1.8, 0.02, 0.05), c.c1, NEON, 0.3 + i * 0.16)
	end
	local waves: { B.Circle } = {}
	for w = 1, 2 do
		waves[w] = B.circle(c, {
			radius = 0.3,
			color = c.c1,
			width = if w == 1 then 0.12 else 0.07,
			n = 8,
			anchor = function()
				return CF(0, g + 0.01, 0)
			end,
			radiusFn = function(t)
				return 0.3 + (((t - (w - 1) * 0.22) % 2) / 2) * 5.6
			end,
		})
	end
	B.ring(c, {
		n = 20,
		radius = 1,
		seg = V(0.07, 0.05, 0.22),
		color = c.c1,
		spin = 0.4,
		anchor = function()
			return CF(0, g + 0.03, 0)
		end,
		radiusFn = function(t)
			return 0.3 + ((t % 2) / 2) * 5.6
		end,
		paint = function(_, t, p)
			p.Transparency = ((t % 2) / 2) ^ 0.7
		end,
	})
	local blips: { BasePart } = {}
	local blipA: { number } = {}
	local blipR: { number } = {}
	for i = 1, 4 do
		blips[i] = Core.part(c, V(0.16, 0.16, 0.16), c.c1, NEON, 1, BALL)
		blipA[i] = c.rng:NextNumber() * TAU
		blipR[i] = 0.6 + c.rng:NextNumber() * 1.1
	end
	local la = Core.att(c, c.root, CF(0, g + 0.4, 0))
	local light = Core.light(la, c.c1, 1, 8)
	Core.emit(la, {
		tex = T.spark,
		color = cs(c.c1),
		size = ns(0.15, 0),
		transp = ns(0.3, 1),
		rate = 3,
		life = nr(1, 1.6),
		speed = nr(0.4, 0.8),
		spread = V2(60, 60),
	})
	Core.on(c, function(t, _, root)
		for w, circ in waves do
			B.setBeamsTransparency(circ.beams, (((t - (w - 1) * 0.22) % 2) / 2) ^ 0.8)
		end
		light.Brightness = 0.4 + 2.2 * math.max(0, 1 - (t % 2) * 2)
		local a = t * 2.4
		local base = root * CF(0, g, 0)
		Core.put(dot, base * FLAT)
		Core.put(arm, base * CF(0, 0.02, 0) * ANG(0, -a, 0) * CF(0.9, 0, 0))
		for i, f in fan do
			Core.put(f, base * CF(0, 0.015, 0) * ANG(0, -(a - i * 0.1), 0) * CF(0.9, 0, 0))
		end
		for i, bp in blips do
			local diff = (a - blipA[i]) % TAU
			bp.Transparency = 1 - math.exp(-diff * 1.4) * 0.95
			if diff > TAU - 0.05 then
				blipA[i] = (blipA[i] + 1.3 + i) % TAU
			end
			Core.put(bp, base * CF(math.cos(blipA[i]) * blipR[i], 0.05, math.sin(blipA[i]) * blipR[i]))
		end
	end)
end

-- warm crumbs and small hex icons orbiting
A.Cookie = function(c: Ctx)
	local chest = Core.att(c, c.torso, CF(0, 0, 0))
	Core.emit(chest, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.12, 0.08, 0.04),
		transp = ns(0, 0.1, 1),
		rate = 6,
		life = nr(1, 1.6),
		speed = nr(0.8, 1.6),
		spread = V2(180, 180),
		accel = V(0, -6, 0),
		rotSpeed = nr(-200, 200),
		light = 0.25,
		bright = 1.2,
	})
	local head = Core.att(c, c.head, CF(0, 0, 0))
	local hexes: { { BasePart } } = {}
	local chips: { { BasePart } } = {}
	local tracks: { Attachment } = {}
	for i = 1, 4 do
		hexes[i] = B.hex(c, 0.3, 0.07, c.c1)
		chips[i] = {
			Core.part(c, V(0.07, 0.06, 0.07), c.c2, SMOOTH),
			Core.part(c, V(0.06, 0.06, 0.06), c.c2, SMOOTH),
			Core.part(c, V(0.05, 0.06, 0.05), c.c2, SMOOTH),
		}
		tracks[i] = Core.att(c)
		Core.beam(c, tracks[i], head, c.c1, 0.03, {
			tr = ns(0.55, 0.9),
			tex = T.square,
			texLen = 0.35,
			texSpeed = 1.2,
		})
	end
	local chipOff = { CF(0.08, 0.05, 0.06), CF(-0.09, 0.05, -0.03), CF(0.02, 0.05, -0.12) }
	Core.light(chest, c.c1, 0.5, 6)
	Core.on(c, function(t, _, root)
		for i, hx in hexes do
			local a = t * 0.7 + (i - 1) / 4 * TAU
			local y = c.chestY + math.sin(t * 1.4 + i * 1.7) * 0.35
			local pos = V(math.cos(a) * 2, y, math.sin(a) * 2)
			local cf = root * CF(pos) * ANG(0, -a, 0) * FLAT * ANG(0, t * 1.3 + i, 0)
			B.putHex(hx, cf)
			for k, ch in chips[i] do
				Core.put(ch, cf * chipOff[k])
			end
			tracks[i].Position = pos
		end
	end)
end

-- stacked blue translucent panels floating behind the back
A.Cache = function(c: Ctx)
	local rng = c.rng
	local panels: { BasePart } = {}
	local bars: { BasePart } = {}
	local lines: { { TextLabel } } = {}
	for k = 1, 4 do
		local p = Core.part(c, V(1.8, 1.15, 0.04), c.c1:Lerp(c.c2, k / 6), NEON, 0.6)
		panels[k] = p
		bars[k] = Core.part(c, V(1.8, 0.05, 0.06), c.c1)
		local sg = Core.surface(p, Enum.NormalId.Back, 100)
		local ls = {}
		for j = 1, 6 do
			ls[j] = Core.label(
				sg,
				string.format("%04X  %s %s", rng:NextInteger(0, 65535), Core.hex(2, rng), Core.hex(6, rng)),
				Color3.fromRGB(210, 225, 255),
				F.mono,
				UDim2.fromScale(0.05, 0.08 + (j - 1) * 0.145),
				UDim2.fromScale(0.9, 0.13),
				Enum.TextXAlignment.Left
			)
		end
		lines[k] = ls
	end
	local back = Core.att(c, c.torso, CF(0, 0, 0.6))
	Core.emit(back, {
		tex = T.square,
		color = cs(c.c1),
		size = ns(0.08, 0),
		transp = ns(0.2, 1),
		rate = 4,
		life = nr(1.2, 2),
		speed = nr(0.3, 0.6),
		spread = V2(50, 50),
		dir = Enum.NormalId.Back,
		rot = nr(0, 0),
	})
	Core.light(back, c.c1, 0.8, 7)
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
		end
		for k, p in panels do
			local bob = math.sin(t * 1.1 + k * 0.9) * 0.08
			local sway = math.sin(t * 0.7 + k) * 0.06
			local cf = root
				* CF(sway + (k - 2.5) * 0.12, c.chestY + 0.2 + (k - 1) * 0.2 + bob, 0.75 + (k - 1) * 0.32)
				* ANG(-0.08, (if k % 2 == 0 then 0.1 else -0.1) + sway, 0)
			Core.put(p, cf)
			Core.put(bars[k], cf * CF(0, 0.6, 0))
		end
	end)
end

-- low orange digital flames at the feet with hex sparks
A.Firewall = function(c: Ctx)
	local g = c.groundY
	local vol = Core.volume(c, V(3.2, 0.2, 3.2), CF(0, g + 0.1, 0))
	local hot = Color3.fromRGB(255, 220, 120)
	Core.emit(vol, {
		tex = T.fire,
		color = cs(hot, c.c1, c.c2),
		size = ns(0.75, 0.5, 0.05),
		transp = ns(0.35, 0.45, 1),
		rate = 38,
		life = nr(0.4, 0.7),
		speed = nr(1.2, 2),
		accel = V(0, 2, 0),
		spread = V2(8, 8),
		rotSpeed = nr(-40, 40),
		shape = Enum.ParticleEmitterShape.Cylinder,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		zoff = 0.3,
	})
	Core.emit(vol, {
		tex = T.fireSpark,
		color = cs(hot, c.c1),
		size = ns(0.18, 0),
		rate = 9,
		life = nr(0.8, 1.3),
		speed = nr(2, 3.5),
		spread = V2(20, 20),
		accel = V(0, 0.8, 0),
		rotSpeed = nr(-180, 180),
		bright = 2.5,
		shape = Enum.ParticleEmitterShape.Cylinder,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	local base = Core.part(c, V(0.04, 3.7, 3.7), c.c2, NEON, 0.72, CYL)
	local n = 16
	local bricks: { BasePart } = {}
	for i = 1, n do
		bricks[i] = Core.part(c, V(0.12, 0.4, 0.5), c.c1)
	end
	local la = Core.att(c, c.root, CF(0, g + 0.6, 0))
	local light = Core.light(la, c.c1, 1.4, 9)
	Core.on(c, function(t, _, root)
		Core.put(base, root * CF(0, g + 0.02, 0) * FLAT)
		for i, p in bricks do
			local a = (i - 1) / n * TAU + t * 0.25
			local f = math.clamp(0.5 + math.noise(i * 0.37, t * 3.1) * 1.4, 0, 1)
			local h = 0.15 + f * 0.55
			p.Size = V(0.12, h, 0.5)
			p.Color = c.c2:Lerp(c.c1, f):Lerp(hot, math.max(0, f - 0.7) * 2)
			Core.put(p, root * CF(0, g + h / 2, 0) * ANG(0, -a, 0) * CF(1.6, 0, 0))
		end
		light.Brightness = 1.1 + math.noise(t * 6, 0.5) * 1.2
	end)
end

-- purple afterimage ghosts trailing the body
A.Lag = function(c: Ctx)
	B.clones(c, { set = "lite", color = c.c1, mat = FF, delay = 0.12, fps = 12 })
	B.clones(c, { set = "lite", color = c.c2, mat = NEON, tr = 0.82, delay = 0.27, fps = 7 })
	local dots: { BasePart } = {}
	for i = 1, 8 do
		dots[i] = Core.part(c, V(0.12, 0.12, 0.12), c.c1, NEON, 0, BALL)
	end
	local torso = Core.att(c, c.torso, CF(0, 0, 0))
	Core.emit(torso, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.5, 0.35),
		transp = ns(0.75, 1),
		rate = 5,
		life = nr(0.5, 0.7),
		rot = nr(0, 0),
		light = 0.8,
	})
	Core.on(c, function(t, _, root)
		local center = (root * CF(0, c.topY + 0.8, 0)).Position
		local look = CFrame.lookAt(center, camPos())
		for i, p in dots do
			local a = (i - 1) / 8 * TAU
			Core.put(p, look * CF(math.sin(a) * 0.42, math.cos(a) * 0.42, 0))
			local chase = ((i - 1) / 8 - t * 1.4) % 1
			p.Transparency = chase * 0.92
		end
	end)
end

---------------------------------------------------------------- ENHANCED

-- teal data packets streaming in arcs over the head
A.Packet = function(c: Ctx)
	type Arc = { p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, dir: number }
	local arcs: { Arc } = {}
	for k = 1, 2 do
		local z = if k == 1 then -0.35 else 0.45
		local yb = c.chestY - 0.1
		local L = V(-2.1, yb, z)
		local R = V(2.1, yb, z)
		local peak = c.topY + (if k == 1 then 1.2 else 1.7)
		local h = (peak - yb) / 0.75
		local up = V(0, h, 0)
		arcs[k] = { p0 = L, p1 = L + up, p2 = R + up, p3 = R, dir = if k == 1 then 1 else -1 }
		local a0 = Core.att(c, nil, CFrame.fromMatrix(L, Vector3.yAxis, -Vector3.xAxis))
		local a1 = Core.att(c, nil, CFrame.fromMatrix(R, -Vector3.yAxis, Vector3.xAxis))
		Core.beam(c, a0, a1, c.c1, 0.06, { c0 = h, c1 = h, segs = 24, tr = ns(0.75, 0.45, 0.75), color2 = c.c2 })
		Core.emit(a0, {
			tex = T.spark,
			color = cs(c.c1),
			size = ns(0.2, 0),
			rate = 3,
			life = nr(0.4, 0.7),
			speed = nr(0.5, 1),
			spread = V2(180, 180),
		})
	end
	local nodes = { Core.part(c, V(0.24, 0.24, 0.24), c.c2), Core.part(c, V(0.24, 0.24, 0.24), c.c2) }
	type Pk = { body: BasePart, cap: BasePart, arc: Arc, off: number }
	local pks: { Pk } = {}
	for i = 1, 6 do
		local body = Core.part(c, V(0.2, 0.2, 0.34), c.c1)
		local cap = Core.part(c, V(0.23, 0.23, 0.08), c.c2:Lerp(WHITE, 0.4))
		Core.trail(body, c.c1, 0.14, 0.25)
		pks[i] = { body = body, cap = cap, arc = arcs[(i - 1) % 2 + 1], off = math.floor((i - 1) / 2) / 3 }
	end
	Core.light(Core.att(c, c.head, CF(0, 1, 0)), c.c1, 0.7, 8)
	Core.on(c, function(t, _, root)
		for _, pk in pks do
			local a = pk.arc
			local s = (t * 0.45 + pk.off) % 1
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
			Core.put(pk.cap, cf * CF(0, 0, -0.2))
			local vis = math.sin(s * math.pi) ^ 0.35
			pk.body.Transparency = 1 - vis
			pk.cap.Transparency = 1 - vis
		end
		Core.put(nodes[1], root * CF(arcs[1].p0) * ANG(t, t * 1.3, 0))
		Core.put(nodes[2], root * CF(arcs[1].p3) * ANG(-t, t * 1.1, 0))
	end)
end

-- yellow mirrored silhouette offset beside the player
A.Proxy = function(c: Ctx)
	local rng = c.rng
	local off = 3.4
	local jx, jy, jUntil, nextJ = 0, 0, 0, 0
	local parts = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = FF,
		map = function(cf, root)
			return root * CF(off + jx, jy, 0) * B.mirrorX(root:ToObjectSpace(cf))
		end,
	})
	local h = c.topY - c.groundY + 0.4
	local mx = off / 2
	local ym = c.groundY + h / 2
	local frame: { { p: BasePart, cf: CFrame } } = {
		{ p = Core.part(c, V(0.06, h, 0.06), c.c1), cf = CF(mx, ym, 0.85) },
		{ p = Core.part(c, V(0.06, h, 0.06), c.c1), cf = CF(mx, ym, -0.85) },
		{ p = Core.part(c, V(0.06, 0.06, 1.76), c.c1), cf = CF(mx, c.groundY + h, 0) },
		{ p = Core.part(c, V(0.06, 0.06, 1.76), c.c1), cf = CF(mx, c.groundY, 0) },
		{ p = Core.part(c, V(0.02, h, 1.7), c.c1, NEON, 0.92), cf = CF(mx, ym, 0) },
	}
	local scan = Core.part(c, V(0.03, 0.05, 1.7), WHITE, NEON, 0.2)
	local a0 = Core.att(c, nil, CF(0.4, c.chestY, 0))
	local a1 = Core.att(c, nil, CF(off - 0.4, c.chestY, 0))
	Core.beam(c, a0, a1, c.c1, 0.07, { tex = T.square, texLen = 0.45, texSpeed = 2, tr = ns(0.2) })
	local _, ip = B.glyph(c, "127.0.0.1", c.c1, V2(2.2, 0.32), F.pixel, CF(off, c.topY + 0.7, 0), c.c2)
	local _, tag = B.glyph(c, "SPOOFED", c.c2:Lerp(c.c1, 0.5), V2(1.2, 0.2), F.tech, CF(off, c.topY + 0.42, 0))
	local pa = Core.att(c, nil, CF(off, c.chestY, 0))
	Core.emit(pa, {
		tex = T.spark,
		color = cs(c.c1, c.c2),
		size = ns(0.22, 0),
		transp = ns(0.2, 1),
		rate = 5,
		life = nr(0.8, 1.4),
		speed = nr(0.5, 1.2),
		spread = V2(180, 180),
	})
	Core.light(pa, c.c1, 1.1, 9)
	local ports = { ":8080", ":3128", ":1080", ":443" }
	local nextP = 0
	Core.on(c, function(t, _, root)
		if t >= nextJ then
			nextJ = t + 0.9 + rng:NextNumber() * 1.6
			jUntil = t + 0.12
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
		for _, f in frame do
			Core.put(f.p, root * f.cf)
		end
		Core.put(scan, root * CF(mx, c.groundY + ((t * 0.6) % 1) * h, 0))
		if t >= nextP then
			nextP = t + 1.6
			ip.Text = "127.0.0.1" .. Core.pick(ports, rng)
		end
		tag.TextTransparency = if math.sin(t * 9) > 0.6 then 0.8 else 0.1
	end)
end

-- equalizer bars pulsing in a ring on the ground
A.Bitrate = function(c: Ctx)
	local n = 18
	local r = 1.9
	local g = c.groundY
	local bars: { BasePart } = {}
	local caps: { BasePart } = {}
	local capY: { number } = {}
	for i = 1, n do
		bars[i] = Core.part(c, V(0.2, 0.2, 0.2), c.c1)
		caps[i] = Core.part(c, V(0.24, 0.05, 0.24), WHITE)
		capY[i] = 0.2
	end
	B.circle(c, { radius = r, color = c.c1, width = 0.05, at = CF(0, g + 0.02, 0), tr = 0.35 })
	B.circle(c, { radius = r + 0.35, color = c.c2, width = 0.03, at = CF(0, g + 0.02, 0), tr = 0.55 })
	local la = Core.att(c, c.root, CF(0, g + 0.5, 0))
	local light = Core.light(la, c.c2, 1, 9)
	local e = Core.emit(la, {
		tex = T.spark,
		color = cs(c.c1, c.c2),
		size = ns(0.25, 0),
		rate = 0,
		life = nr(0.5, 0.9),
		speed = nr(2, 4),
		spread = V2(70, 70),
		accel = V(0, -4, 0),
	})
	Core.on(c, function(t, dt, root)
		local beat = math.max(0, math.sin(t * TAU * 2)) ^ 8
		e.Rate = beat * 40
		light.Brightness = 0.6 + beat * 2.4
		local base = root * CF(0, g, 0) * ANG(0, t * 0.3, 0)
		for i, p in bars do
			local band = (i - 1) / (n - 1)
			local v = 0.22
				+ 0.55 * math.abs(math.noise(band * 3.1, t * 2.3)) * 2
				+ beat * (1 - band) * 0.7
				+ 0.12 * math.sin(t * 7 + i)
			v = math.clamp(v, 0.05, 1)
			local h = 0.12 + v * 1.6
			p.Size = V(0.2, h, 0.2)
			p.Color = c.c1:Lerp(c.c2, v)
			local a = (i - 1) / n * TAU
			local cf = base * ANG(0, -a, 0) * CF(r, 0, 0)
			Core.put(p, cf * CF(0, h / 2, 0))
			capY[i] = math.max(capY[i] - dt * 1.1, h + 0.08)
			Core.put(caps[i], cf * CF(0, capY[i], 0))
		end
	end)
end

-- red numbers spilling upward like a fountain
A.Overflow = function(c: Ctx)
	local rng = c.rng
	local origin = V(0, c.topY + 0.25, 0)
	type Drop = { att: Attachment, lbl: TextLabel, t0: number, v: Vector3 }
	local drops: { Drop } = {}
	local LIFE = 1.4
	local function relaunch(d: Drop, t: number)
		d.t0 = t - rng:NextNumber() * 0.05
		local a = rng:NextNumber() * TAU
		local hs = 1.1 + rng:NextNumber() * 1.1
		d.v = V(math.cos(a) * hs, 6.2 + rng:NextNumber() * 1.8, math.sin(a) * hs)
		d.lbl.Text = if rng:NextNumber() < 0.6 then tostring(rng:NextInteger(0, 9)) else Core.hex(2, rng)
	end
	for i = 1, 14 do
		local att, lbl = B.glyph(c, "0", c.c1, V2(0.45, 0.45), F.pixel, CF(origin), Color3.new(0.2, 0, 0))
		local d: Drop = { att = att, lbl = lbl, t0 = 0, v = Vector3.zero }
		relaunch(d, os.clock() - i * LIFE / 14)
		drops[i] = d
	end
	-- buffer meter that fills and overflows
	local segs: { BasePart } = {}
	for i = 1, 10 do
		segs[i] = Core.part(c, V(0.34, 0.13, 0.12), c.c2:Lerp(c.c1, (i - 1) / 9))
	end
	local _, meterLbl = B.glyph(c, "0x0000", c.c1, V2(1.1, 0.24), F.pixel, CF(1.45, c.chestY + 1.25, 0))
	B.ring(c, {
		n = 10,
		radius = 0.55,
		seg = V(0.06, 0.06, 0),
		color = c.c1,
		color2 = c.c2,
		spin = 3,
		anchor = function()
			return CF(0, c.topY + 0.12, 0)
		end,
	})
	local top = Core.att(c, c.head, CF(0, c.head.Size.Y / 2, 0))
	Core.emit(top, {
		tex = T.fireSpark,
		color = cs(c.c2, c.c1),
		size = ns(0.2, 0),
		rate = 10,
		life = nr(0.6, 1),
		speed = nr(4, 6),
		spread = V2(25, 25),
		accel = V(0, -9, 0),
		bright = 2,
	})
	local light = Core.light(top, c.c1, 1, 9)
	Core.on(c, function(t, _, root)
		for _, d in drops do
			local age = t - d.t0
			if age > LIFE then
				relaunch(d, t)
				age = 0
			end
			local f = age / LIFE
			d.att.Position = origin + d.v * age + V(0, -4.6 * age * age, 0)
			d.lbl.TextColor3 = c.c1:Lerp(c.c2, f)
			d.lbl.TextTransparency = f * f
		end
		local cyc = (t / 3.2) % 1
		local fill = math.min(1, cyc / 0.85)
		local over = cyc > 0.85
		for i, p in segs do
			Core.put(p, root * CF(1.45, c.chestY - 0.55 + (i - 1) * 0.16, 0) * ANG(0, -0.4, 0))
			local lit = (i - 1) / 10 < fill
			p.Transparency = if over then (if math.sin(t * 40) > 0 then 0 else 0.6) elseif lit then 0 else 0.85
		end
		meterLbl.Text = if over then "OVERFLOW" else string.format("0x%04X", math.floor(fill * 65535))
		meterLbl.TextColor3 = if over then c.c2 else c.c1
		light.Brightness = if over then 2.5 else 1
	end)
end

-- toxic green drips and skull-like hex glyphs
A.Malware = function(c: Ctx)
	local rng = c.rng
	B.clones(c, { set = "lite", color = c.c1, mat = FF, scale = 1.02 })
	local drip: Core.EmitSpec = {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.13, 0.11, 0.05),
		transp = ns(0, 0.1, 0.8),
		rate = 5,
		life = nr(0.55, 0.8),
		speed = nr(0, 0.3),
		accel = V(0, -16, 0),
		rot = nr(45, 45),
		light = 0.8,
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
	local puddle = Core.part(c, V(0.04, 3.2, 3.2), c.c2:Lerp(c.c1, 0.35), NEON, 0.35, CYL)
	B.circle(c, { radius = 1.55, color = c.c1, width = 0.06, at = CF(0, g + 0.04, 0), tr = 0.2 })
	local pv = Core.volume(c, V(2.6, 0.1, 2.6), CF(0, g + 0.05, 0))
	Core.emit(pv, {
		tex = T.spark,
		color = cs(c.c1),
		size = ns(0.12, 0.28, 0),
		transp = ns(0.2, 0.4),
		rate = 9,
		life = nr(0.8, 1.4),
		speed = nr(0.3, 0.8),
		shape = Enum.ParticleEmitterShape.Box,
	})
	local hexes = { "0xDEAD", "0xBADC0DE", "0xC0FFEE", "0xFA11", "0x0BAD" }
	type Sk = { att: Attachment, a: number, y: number, gui: BillboardGui }
	local skulls: { Sk } = {}
	for i = 1, 5 do
		local att, lbl, gui = B.glyph(c, "☠", c.c1, V2(0.8, 1), F.mono, nil, c.c2)
		lbl.Size = UDim2.fromScale(1, 0.72)
		local sub = Core.label(gui, hexes[i], c.c1, F.pixel, UDim2.fromScale(-0.3, 0.74), UDim2.fromScale(1.6, 0.24))
		sub.TextStrokeTransparency = 0.3
		skulls[i] = { att = att, a = (i - 1) / 5 * TAU, y = c.groundY + 1.2 + (i % 3) * 0.9, gui = gui }
	end
	local la = Core.att(c, c.root, CF(0, g + 0.4, 0))
	local light = Core.light(la, c.c1, 1.2, 9)
	Core.on(c, function(t, _, root)
		local d = 3 + math.sin(t * 2.1) * 0.2
		puddle.Size = V(0.04, d, d)
		Core.put(puddle, root * CF(0, g + 0.02, 0) * FLAT)
		for i, s in skulls do
			local a = s.a + t * 0.6
			local jit = if math.noise(i, t * 3) > 0.35 then (rng:NextNumber() - 0.5) * 0.2 else 0
			s.att.Position = V(math.cos(a) * 2 + jit, s.y + math.sin(t * 1.7 + i) * 0.2, math.sin(a) * 2)
		end
		light.Brightness = 0.9 + Core.pulse(t, 1.4) * 0.9
	end)
end

return A
