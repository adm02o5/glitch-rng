--!strict
-- AuraFX/AurasHigh: LEGENDARY, MYTHIC, CORRUPTED and SINGULARITY tier auras.
--
-- Scale guide (stud radius of the outer silhouette): Legendary 5-8, Mythic 6-10,
-- Corrupted 7-12, Singularity 10-16 plus sky-reaching beams. Every aura has a ground
-- sigil, a coloured root light and at least one silhouette-breaking element that reads
-- from the gameplay camera (15-20 studs behind the player).

local Workspace = game:GetService("Workspace")

local Core = require(script.Parent.Core)
local B = require(script.Parent.Blocks)

type Ctx = Core.Ctx

local T, F = Core.TEX, Core.FONT
local V, V2, CF, ANG = Vector3.new, Vector2.new, CFrame.new, CFrame.Angles
local ns, nr, cs = Core.ns, Core.nr, Core.cs
local TAU = Core.TAU
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local NEON = Enum.Material.Neon
local FF = Enum.Material.ForceField
local SMOOTH = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal
local FLAT = ANG(0, 0, math.pi / 2) -- cylinder axis X -> Y
local AXIS_Z = ANG(0, math.pi / 2, 0) -- cylinder axis X -> Z
local BOX = Enum.ParticleEmitterShape.Box
local SPHERE = Enum.ParticleEmitterShape.Sphere
local SURFACE = Enum.ParticleEmitterShapeStyle.Surface
local INWARD = Enum.ParticleEmitterShapeInOut.Inward
local PERP = Enum.ParticleOrientation.VelocityPerpendicular

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

-- Root-local frame on a horizontal circle whose -Z (front face) points outward.
local function outward(a: number, r: number, y: number): CFrame
	return ANG(0, -a, 0) * CF(r, y, 0) * ANG(0, -math.pi / 2, 0)
end

local function smooth01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function jitter(rng: Random, amp: number): Vector3
	return V((rng:NextNumber() - 0.5) * amp, (rng:NextNumber() - 0.5) * amp, (rng:NextNumber() - 0.5) * amp)
end

local A: { [string]: (Ctx) -> () } = {}

---------------------------------------------------------------- LEGENDARY

-- server-rack panels with blinking LEDs orbiting, cable beams
-- parts ~65, emitters 4
A.Mainframe = function(c: Ctx)
	local rng = c.rng
	local shell = Color3.fromRGB(10, 16, 26)
	local green = Color3.fromRGB(80, 255, 140)
	local amber = Color3.fromRGB(255, 176, 32)
	local ledCols = { c.c1, green, amber, Color3.fromRGB(20, 30, 40) }
	local NR, RR = 5, 4.4
	local RW, RH, RD = 1.3, 2.5, 0.7
	type Rack = {
		body: BasePart,
		bars: { BasePart },
		leds: { BasePart },
		status: BasePart,
		a0: Attachment,
		a0n: Attachment,
		up0: Attachment,
		up1: Attachment,
		pulse: BasePart,
	}
	local hubAtt = Core.att(c, nil, CF(0, c.chestY, 0.8))
	local racks: { Rack } = {}
	for i = 1, NR do
		local body = Core.part(c, V(RW, RH, RD), shell, SMOOTH)
		local sg = Core.surface(body, Enum.NormalId.Front, 60)
		Core.label(
			sg,
			string.format("SRV-%02d", i),
			c.c1,
			F.mono,
			UDim2.fromScale(0.08, 0.86),
			UDim2.fromScale(0.6, 0.08),
			Enum.TextXAlignment.Left
		)
		Core.label(
			sg,
			string.format("LOAD %d%%", rng:NextInteger(61, 99)),
			green,
			F.mono,
			UDim2.fromScale(0.08, 0.04),
			UDim2.fromScale(0.6, 0.07),
			Enum.TextXAlignment.Left
		)
		local leds = {}
		for k = 1, 4 do
			leds[k] = Core.part(c, V(RW * 0.72, 0.09, 0.04), c.c1)
		end
		local a0, a0n = Core.att(c), Core.att(c)
		local up0, up1 = Core.att(c), Core.att(c)
		racks[i] = {
			body = body,
			bars = { Core.part(c, V(RW + 0.06, 0.09, RD + 0.06), c.c1), Core.part(c, V(RW + 0.06, 0.09, RD + 0.06), c.c1) },
			leds = leds,
			status = Core.part(c, V(0.14, 0.14, 0.05), c.c1),
			a0 = a0,
			a0n = a0n,
			up0 = up0,
			up1 = up1,
			pulse = Core.part(c, V(0.3, 0.3, 0.3), WHITE, NEON, 0, BALL),
		}
		Core.beam(c, a0, hubAtt, Color3.fromRGB(16, 22, 30), 0.2, { light = 0, bright = 1, c0 = 1.6, c1 = 1.6, segs = 16 })
		Core.beam(
			c,
			a0n,
			hubAtt,
			c.c1,
			0.08,
			{ c0 = 1.6, c1 = 1.6, segs = 16, tex = T.square, texLen = 0.4, texSpeed = 3, zoff = 0.02 }
		)
		-- data uplink column above every rack
		Core.beam(c, up0, up1, c.c1, 0.35, { w1 = 0.05, tr = ns(0.25, 1), tex = T.square, texLen = 0.8, texSpeed = 4, segs = 2 })
	end
	local hub = Core.part(c, V(0.9, 0.7, 0.3), Color3.fromRGB(20, 26, 36), METAL)
	local hubStrip = Core.part(c, V(0.8, 0.08, 0.32), c.c1)
	B.sigil(c, { radius = 5.6, color = c.c1, color2 = c.c2:Lerp(c.c1, 0.5), ticks = 16, spokes = 5, glow = 0.9, spin = 0.2 })
	local _, title = B.glyph(c, "MAINFRAME://ONLINE", c.c1, V2(4.4, 0.55), F.tech, CF(0, c.topY + 1.5, 0), c.c2)
	local back = Core.att(c, c.torso, CF(0, 0.1, c.torso.Size.Z / 2 + 0.3))
	Core.emit(back, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0.35, 0),
		rate = 14,
		life = nr(0.4, 0.8),
		speed = nr(3, 6),
		spread = V2(60, 60),
		dir = Enum.NormalId.Back,
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.glow,
		color = cs(c.c1, c.c2),
		size = ns(3.5, 5),
		transp = ns(0.8, 1),
		rate = 3,
		life = nr(0.9, 1.3),
		locked = true,
	})
	B.floorEmit(c, 5, {
		tex = T.square,
		color = cs(c.c1, green),
		size = ns(0.24, 0),
		transp = ns(0.05, 1),
		rate = 22,
		life = nr(1.4, 2.4),
		speed = nr(1.5, 3),
		rot = nr(0, 0),
	})
	local hubE = Core.emit(hubAtt, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0.5, 0),
		rate = 0,
		life = nr(0.3, 0.5),
		speed = nr(3, 5),
		spread = V2(180, 180),
	})
	B.rootLight(c, c.c1, 2.4, 16, { pulse = 1.6, amp = 1.2 })
	local nextLed = 0
	local ledOff = { -0.75, -0.25, 0.25, 0.75 }
	local lastS: { number } = table.create(NR, 0)
	Core.on(c, function(t, _, root)
		local blink = t >= nextLed
		if blink then
			nextLed = t + 0.1
		end
		local hubWorld = c.torso.CFrame * CF(0, 0.1, c.torso.Size.Z / 2 + 0.16)
		Core.put(hub, hubWorld)
		Core.put(hubStrip, hubWorld)
		local hubL = root:ToObjectSpace(hubWorld)
		hubAtt.CFrame = CFrame.fromMatrix(hubL.Position, Vector3.yAxis, Vector3.xAxis)
		for i, r in racks do
			local a = (i - 1) / NR * TAU + t * 0.3
			local cfL = outward(a, RR, c.chestY + 0.2 + math.sin(t * 0.9 + i) * 0.25)
			local cf = root * cfL
			Core.put(r.body, cf)
			Core.put(r.bars[1], cf * CF(0, RH / 2, 0))
			Core.put(r.bars[2], cf * CF(0, -RH / 2, 0))
			for k, led in r.leds do
				Core.put(led, cf * CF(-0.08, ledOff[k], -RD / 2 - 0.01))
				if blink and rng:NextNumber() < 0.3 then
					led.Color = ledCols[rng:NextInteger(1, #ledCols)]
				end
			end
			Core.put(r.status, cf * CF(RW / 2 - 0.18, RH / 2 - 0.3, -RD / 2 - 0.02))
			r.status.Transparency = if math.sin(t * 6 + i) > 0 then 0 else 0.8
			local backL = (cfL * CF(0, -0.5, RD / 2 + 0.01)).Position
			local m = CFrame.fromMatrix(backL, -Vector3.yAxis, Vector3.xAxis)
			r.a0.CFrame = m
			r.a0n.CFrame = m
			local topL = (cfL * CF(0, RH / 2 + 0.05, 0)).Position
			r.up0.Position = topL
			r.up1.Position = topL + V(0, 5 + math.sin(t * 2 + i) * 1.2, 0)
			-- data pulse riding the cable towards the hub
			local s = (t * 0.6 + i / NR) % 1
			if s < lastS[i] and rng:NextNumber() < 0.5 then
				hubE:Emit(4)
			end
			lastS[i] = s
			local p = B.bez(backL, backL - V(0, 1.6, 0), hubL.Position - V(0, 1.6, 0), hubL.Position, s)
			Core.put(r.pulse, root * CF(p))
			r.pulse.Transparency = 1 - math.sin(s * math.pi)
		end
		title.Text = if (t % 1) < 0.5 then "MAINFRAME://ONLINE_" else "MAINFRAME://ONLINE"
	end)
end

-- electron orbit rings and superposition ghosts phasing
-- parts ~60, emitters 5
A.Quantum = function(c: Ctx)
	local rng = c.rng
	local OR = 4.6
	local cy = c.chestY + 0.3
	local function orbit(k: number): (t: number) -> CFrame
		return function(t: number): CFrame
			return CF(0, cy, 0) * ANG(0, t * 0.25 + k * TAU / 3, 0) * ANG(1.15, 0, 0)
		end
	end
	type El = { core: BasePart, shell: BasePart, k: number, skip: number }
	local els: { El } = {}
	for k = 1, 3 do
		local col = if k == 2 then c.c2 else c.c1
		B.circle(c, { radius = OR, color = col, width = 0.13, tr = 0.1, anchor = orbit(k), n = 10 })
		B.circle(c, { radius = OR + 0.3, color = c.c1:Lerp(c.c2, 0.5), width = 0.04, tr = 0.55, anchor = orbit(k), n = 10 })
		local core = Core.part(c, V(0.55, 0.55, 0.55), WHITE, NEON, 0, BALL)
		Core.trail(core, c.c1, 0.5, 0.55, c.c2)
		els[k] = { core = core, shell = Core.part(c, V(1.15, 1.15, 1.15), c.c1, FF, 0, BALL), k = k, skip = 0 }
	end
	local side = 1
	local ga = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = FF,
		map = function(cf, root, t)
			return root * CF(2.6 * side + math.sin(t * 31) * 0.05, 0, 0.4) * root:ToObjectSpace(cf)
		end,
	})
	local gb = B.clones(c, {
		set = "lite",
		color = c.c2,
		mat = NEON,
		tr = 0.8,
		map = function(cf, root, t)
			return root * CF(-2.6 * side + math.sin(t * 27) * 0.05, 0, 0.4) * root:ToObjectSpace(cf)
		end,
	})
	-- nucleus atom above the head
	local yA = c.topY + 1.5
	local nucleus = Core.part(c, V(0.6, 0.6, 0.6), c.c1, NEON, 0, BALL)
	for k = 1, 3 do
		B.circle(c, {
			radius = 0.95,
			color = c.c2,
			width = 0.06,
			n = 6,
			anchor = function(t)
				return CF(0, yA, 0) * ANG(0, t * 0.8 + k * TAU / 3, 0) * ANG(1.1, 0, 0)
			end,
		})
	end
	-- probability wave around the feet
	local wave = B.ring(c, {
		n = 28,
		radius = 5.3,
		seg = V(0.14, 0.12, 0),
		color = c.c1,
		color2 = c.c2,
		wave = 0.4,
		waveFreq = 4,
		waveSpeed = 3,
		spin = 0.15,
		anchor = function()
			return CF(0, c.groundY + 0.5, 0)
		end,
	})
	B.sigil(c, { radius = 6, color = c.c1, color2 = c.c2, rings = 2, glow = 0.9 })
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.glow,
		color = cs(c.c1, c.c2),
		size = ns(3.5, 5.5),
		transp = ns(0.8, 1),
		rate = 4,
		life = nr(1.2, 1.8),
		speed = nr(0.2, 0.5),
		spread = V2(180, 180),
	})
	Core.emit(torso, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0, 0.4, 0),
		rate = 14,
		life = nr(0.8, 1.4),
		speed = nr(2, 4),
		spread = V2(180, 180),
		drag = 2,
	})
	local jumpAtt = Core.att(c)
	local flashA = Core.emit(jumpAtt, {
		tex = T.glow,
		color = cs(WHITE, c.c1),
		size = ns(2.2, 0),
		transp = ns(0.2, 1),
		rate = 0,
		life = nr(0.35),
	})
	local flashB = Core.emit(jumpAtt, {
		tex = T.spark,
		color = cs(WHITE, c.c2),
		size = ns(0.45, 0),
		rate = 0,
		life = nr(0.3, 0.6),
		speed = nr(4, 8),
		spread = V2(180, 180),
		drag = 3,
	})
	B.floorEmit(c, 5, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.28, 0),
		transp = ns(0, 0.7, 0, 0.7, 1),
		rate = 18,
		life = nr(1.4, 2.2),
		speed = nr(1.2, 2.5),
		rot = nr(0, 0),
	})
	B.rootLight(c, c.c1, 2.2, 16, { pulse = 2, amp = 1.4 })
	local nextJump = 0
	Core.on(c, function(t, _, root)
		side = if (t % 7.4) < 3.7 then 1 else -1
		if t >= nextJump then
			nextJump = t + 0.9 + rng:NextNumber() * 1.2
			local e = els[rng:NextInteger(1, 3)]
			local th = t * 3.2 + e.k * 2 + e.skip
			jumpAtt.Position = (orbit(e.k)(t) * CF(math.cos(th) * OR, 0, math.sin(th) * OR)).Position
			flashA:Emit(1)
			flashB:Emit(6)
			e.skip += math.pi * (0.6 + rng:NextNumber() * 0.8)
			th = t * 3.2 + e.k * 2 + e.skip
			jumpAtt.Position = (orbit(e.k)(t) * CF(math.cos(th) * OR, 0, math.sin(th) * OR)).Position
			flashA:Emit(1)
			flashB:Emit(6)
		end
		for _, e in els do
			local th = t * 3.2 + e.k * 2 + e.skip
			local cf = root * orbit(e.k)(t) * CF(math.cos(th) * OR, 0, math.sin(th) * OR)
			Core.put(e.core, cf)
			local s = 1.05 + Core.pulse(t, 0.6, e.k / 3) * 0.3
			e.shell.Size = V(s, s, s)
			Core.put(e.shell, cf)
		end
		local w = 0.5 + 0.5 * math.sin(t * 2)
		for _, p in ga do
			p.Transparency = w * 0.9
		end
		for _, p in gb do
			p.Transparency = 0.7 + (1 - w) * 0.3
		end
		for k, p in wave do
			p.Transparency = 0.5 + 0.5 * math.sin(t * 4 + k * 0.9)
		end
		Core.put(nucleus, root * CF(0, yA + math.sin(t * 1.4) * 0.12, 0))
	end)
end

-- orange heat haze, lightning arcs, fan-blade halo spinning fast
-- parts ~63, emitters 6
A.Overclocked = function(c: Ctx)
	local rng = c.rng
	local FR = 2.7
	local fanL = CF(0, c.chestY + 0.7, 1.3) -- big cooling fan on the back
	local function fanPlane(): CFrame
		return fanL * ANG(math.pi / 2, 0, 0)
	end
	B.ring(c, {
		n = 22,
		radius = FR,
		seg = V(0.2, 0.18, 0),
		color = c.c1,
		color2 = Color3.fromRGB(110, 45, 0),
		spin = 0.4,
		anchor = fanPlane,
	})
	B.circle(c, { radius = FR + 0.25, color = c.c2, width = 0.08, tr = 0.3, anchor = fanPlane, n = 8 })
	B.circle(c, { radius = FR * 0.35, color = c.c2, width = 0.06, tr = 0.2, anchor = fanPlane, n = 6 })
	local blades: { BasePart } = {}
	for i = 1, 9 do
		blades[i] = Core.part(c, V(0.7, FR * 0.82, 0.06), c.c1:Lerp(c.c2, (i % 3) / 4), NEON, 0.1)
	end
	local hubP = Core.part(c, V(0.3, 0.8, 0.8), c.c2, NEON, 0, CYL)
	local blur = Core.part(c, V(0.03, FR * 2, FR * 2), c.c1, NEON, 0.88, CYL)
	-- fast spinning fan halo above the head
	B.ring(c, {
		n = 12,
		radius = 1.15,
		seg = V(0.12, 0.08, 0),
		color = c.c2,
		color2 = c.c1,
		spin = 7,
		anchor = function()
			return CF(0, c.topY + 0.7, 0) * ANG(0.12, 0, 0)
		end,
	})
	local function sphere(r: number): Vector3
		local u = rng:NextUnitVector()
		return V(u.X * r, c.chestY + 0.5 + u.Y * r * 0.7, u.Z * r)
	end
	for _ = 1, 3 do
		B.bolt(c, {
			segs = 7,
			color = c.c2,
			color2 = c.c1,
			width = 0.16,
			jitter = 0.6,
			interval = 0.06,
			flicker = 0.3,
			ends = function()
				return V(0, c.chestY + 0.3, 0), sphere(4.8 + rng:NextNumber() * 1.2)
			end,
		})
	end
	B.bolt(c, {
		segs = 6,
		color = WHITE,
		color2 = c.c1,
		width = 0.12,
		jitter = 0.4,
		interval = 0.05,
		flicker = 0.4,
		ends = function()
			local a = rng:NextNumber() * TAU
			return V(0, c.chestY + 0.5, 0.8), (fanL * CF(math.cos(a) * FR, math.sin(a) * FR, 0)).Position
		end,
	})
	B.sigil(c, {
		radius = 5.4,
		color = c.c1,
		color2 = c.c2,
		ticks = 16,
		tickSize = V(0.35, 0.07, 0.22),
		spin = 1.4,
		glow = 0.88,
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.smoke,
		color = cs(c.c1, c.c2),
		size = ns(2, 5),
		transp = ns(0.86, 1),
		rate = 8,
		life = nr(1, 1.6),
		speed = nr(1.5, 3),
		spread = V2(30, 30),
		rotSpeed = nr(-50, 50),
		light = 0.5,
	})
	local sx = c.torso.Size.X * 0.42
	local sy = c.torso.Size.Y * 0.45
	local vent: Core.EmitSpec = {
		tex = T.fire,
		color = cs(c.c2, c.c1),
		size = ns(0.8, 0.2),
		transp = ns(0.25, 1),
		rate = 30,
		life = nr(0.3, 0.5),
		speed = nr(4, 6),
		spread = V2(12, 12),
		dir = Enum.NormalId.Back,
	}
	Core.emit(Core.att(c, c.torso, CF(sx, sy, 0.4)), vent)
	Core.emit(Core.att(c, c.torso, CF(-sx, sy, 0.4)), vent)
	Core.emit(torso, {
		tex = T.fireSpark,
		color = cs(c.c2, c.c1),
		size = ns(0.3, 0),
		rate = 30,
		life = nr(0.6, 1.2),
		speed = nr(3, 6),
		spread = V2(180, 180),
		accel = V(0, 4, 0),
		bright = 2.5,
	})
	B.floorEmit(c, 4.5, {
		tex = T.fire,
		color = cs(c.c2, c.c1, Color3.fromRGB(120, 30, 0)),
		size = ns(0.7, 0),
		transp = ns(0.35, 1),
		rate = 26,
		life = nr(0.6, 1),
		speed = nr(2, 4),
	})
	local fanAtt = Core.att(c, nil, fanL)
	Core.emit(fanAtt, {
		tex = T.fireSpark,
		color = cs(WHITE, c.c1),
		size = ns(0.3, 0),
		rate = 18,
		life = nr(0.4, 0.8),
		speed = nr(6, 10),
		spread = V2(80, 80),
		dir = Enum.NormalId.Back,
		accel = V(0, -6, 0),
	})
	local _, temp = B.glyph(c, "TEMP 97C", c.c2, V2(2.8, 0.5), F.pixel, CF(0, c.topY + 1.6, 0), Color3.fromRGB(80, 20, 0))
	local light = B.rootLight(c, c.c1, 2.6, 17)
	Core.on(c, function(t, _, root)
		local fan = root * fanL
		local rot = t * 24
		for i, b in blades do
			Core.put(b, fan * ANG(0, 0, rot + (i - 1) / 9 * TAU) * CF(0, FR * 0.5, 0) * ANG(0, 0.5, 0))
		end
		Core.put(hubP, fan * AXIS_Z)
		Core.put(blur, fan * AXIS_Z * CF(0.03, 0, 0))
		local deg = 95 + math.noise(t * 0.8, 4) * 26
		if deg > 103 then
			temp.Text = if math.sin(t * 20) > 0 then "THROTTLING!" else string.format("TEMP %dC", math.floor(deg))
			temp.TextColor3 = Color3.fromRGB(255, 40, 30)
		else
			temp.Text = string.format("TEMP %dC", math.floor(deg))
			temp.TextColor3 = c.c2
		end
		light.Brightness = 2 + rng:NextNumber() * 2.2
	end)
end

-- glowing neuron web around the head with synapse sparks
-- parts ~51, emitters 4
A.NeuralLink = function(c: Ctx)
	local rng = c.rng
	local N = 16
	local dirs: { Vector3 } = {}
	for i = 1, N do
		local y = -0.75 + (i - 0.5) / N * 1.7
		local r = math.sqrt(math.max(0, 1 - y * y))
		local a = i * 2.39996
		dirs[i] = V(math.cos(a) * r, y * 0.8, math.sin(a) * r)
	end
	local links: { { number } } = {}
	local seen: { [string]: boolean } = {}
	for i = 1, N do
		local d = {}
		for j = 1, N do
			if j ~= i then
				table.insert(d, { j = j, d = (dirs[i] - dirs[j]).Magnitude })
			end
		end
		table.sort(d, function(x, y)
			return x.d < y.d
		end)
		for m = 1, 2 do
			local j = d[m].j
			local key = if i < j then i .. ":" .. j else j .. ":" .. i
			if not seen[key] then
				seen[key] = true
				table.insert(links, { i, j })
			end
		end
	end
	local nodes: { BasePart } = {}
	local atts: { Attachment } = {}
	local flash: { number } = {}
	for i = 1, N do
		nodes[i] = Core.part(c, V(0.42, 0.42, 0.42), c.c1, NEON, 0, BALL)
		atts[i] = Core.att(c)
		flash[i] = 0
	end
	for _, l in links do
		Core.beam(c, atts[l[1]], atts[l[2]], c.c1, 0.08, { color2 = c.c2, tr = ns(0.25) })
	end
	local spineAtt = Core.att(c, c.torso, CF(0, c.torso.Size.Y * 0.35, c.torso.Size.Z / 2 + 0.05))
	for _, i in { 1, 2, 3, 4 } do
		Core.beam(
			c,
			atts[i],
			spineAtt,
			c.c2,
			0.12,
			{ w1 = 0.04, tex = T.square, texLen = 0.4, texSpeed = 3, tr = ns(0.15, 0.5) }
		)
	end
	-- dendrites reaching out of the web
	type Den = { tip: Attachment, from: number, a: number, y: number, r: number }
	local dens: { Den } = {}
	for i = 1, 8 do
		local tip = Core.att(c)
		local from = rng:NextInteger(1, N)
		Core.beam(c, atts[from], tip, c.c1, 0.07, {
			w1 = 0.01,
			color2 = c.c2,
			tr = ns(0.2, 0.9),
			c0 = (rng:NextNumber() - 0.5) * 3,
			c1 = (rng:NextNumber() - 0.5) * 3,
			segs = 10,
			tex = T.square,
			texLen = 0.6,
			texSpeed = -2,
		})
		dens[i] = {
			tip = tip,
			from = from,
			a = (i - 1) / 8 * TAU,
			y = c.headY + (rng:NextNumber() - 0.6) * 3,
			r = 5 + rng:NextNumber() * 1.2,
		}
	end
	type Syn = { p: BasePart, from: number, to: number, t0: number }
	local syns: { Syn } = {}
	for i = 1, 8 do
		local l = links[rng:NextInteger(1, #links)]
		local p = Core.part(c, V(0.24, 0.24, 0.24), WHITE, NEON, 0, BALL)
		Core.trail(p, WHITE, 0.18, 0.25, c.c2)
		syns[i] = { p = p, from = l[1], to = l[2], t0 = os.clock() - i * 0.06 }
	end
	B.ring(c, {
		n = 18,
		gap = 3,
		radius = 1.2,
		seg = V(0.08, 0.11, 0),
		color = c.c2,
		spin = 1.2,
		anchor = function()
			return CF(0, c.headY + 0.1, 0) * ANG(0.12, 0, 0)
		end,
	})
	B.sigil(c, { radius = 5.2, color = c.c1, color2 = c.c2, ticks = 12, spokes = 6, glow = 0.9, spin = 0.4 })
	local headAtt = Core.att(c, c.head)
	Core.emit(headAtt, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0, 0.4, 0),
		rate = 14,
		life = nr(0.8, 1.4),
		speed = nr(1, 2.5),
		spread = V2(180, 180),
	})
	local synE = Core.emit(headAtt, {
		tex = T.spark,
		color = cs(c.c2),
		size = ns(0.6, 0),
		rate = 0,
		life = nr(0.25, 0.45),
		speed = nr(3, 5),
		spread = V2(180, 180),
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.glow,
		color = cs(c.c1, c.c2),
		size = ns(3.5, 5),
		transp = ns(0.82, 1),
		rate = 3,
		life = nr(1, 1.5),
		spread = V2(180, 180),
		speed = nr(0.2, 0.4),
	})
	B.floorEmit(c, 4.5, {
		tex = T.spark,
		color = cs(c.c2, c.c1),
		size = ns(0, 0.35, 0),
		rate = 16,
		life = nr(1.5, 2.5),
		speed = nr(1.5, 3),
	})
	B.rootLight(c, c.c1, 2.4, 16, { y = c.headY, pulse = 1.1, amp = 1.2 })
	local pos: { Vector3 } = table.create(N, Vector3.zero)
	local R = 3
	Core.on(c, function(t, _, root)
		local rot = ANG(0, t * 0.3, 0)
		local r = R + math.sin(t * 1.2) * 0.15
		local hc = V(0, c.headY + 0.5, 0)
		for i = 1, N do
			local p = hc + rot:VectorToWorldSpace(dirs[i]) * r
			pos[i] = p
			atts[i].Position = p
			Core.put(nodes[i], root * CF(p))
			local f = math.max(0, 1 - (t - flash[i]) / 0.3)
			nodes[i].Color = c.c1:Lerp(WHITE, f)
			local s = 0.42 + f * 0.25
			nodes[i].Size = V(s, s, s)
		end
		for i, d in dens do
			local a = d.a + t * 0.2 + math.sin(t * 0.7 + i) * 0.2
			d.tip.Position = V(math.cos(a) * d.r, d.y + math.sin(t * 1.1 + i) * 0.5, math.sin(a) * d.r)
		end
		for _, s in syns do
			local f = (t - s.t0) / 0.32
			if f >= 1 then
				flash[s.to] = t
				local opts = {}
				for _, l in links do
					if l[1] == s.to then
						table.insert(opts, l[2])
					elseif l[2] == s.to then
						table.insert(opts, l[1])
					end
				end
				s.from = s.to
				s.to = if #opts > 0 then opts[rng:NextInteger(1, #opts)] else s.from
				s.t0 = t
				f = 0
				if rng:NextNumber() < 0.3 then
					synE:Emit(4)
				end
			end
			Core.put(s.p, root * CF(pos[s.from]:Lerp(pos[s.to], f)))
		end
	end)
end

-- hexagon shield plates orbiting, golden eye above
-- parts ~72, emitters 4
A.Sentinel = function(c: Ctx)
	local gold = c.c1
	type Plate = { inner: { BasePart }, rim: { BasePart }, emblem: BasePart, att: Attachment }
	local plates: { Plate } = {}
	local yE = c.topY + 2.7
	local eyeAtt = Core.att(c, nil, CF(0, yE, 0))
	for i = 1, 6 do
		local att = Core.att(c)
		Core.beam(c, eyeAtt, att, gold, 0.05, { tr = ns(0.75, 0.4), segs = 2 })
		plates[i] = {
			inner = B.hex(c, 0.95, 0.1, Color3.fromRGB(10, 22, 38), SMOOTH),
			rim = B.hex(c, 1.12, 0.07, gold),
			emblem = Core.part(c, V(0.32, 0.13, 0.32), c.c2),
			att = att,
		}
	end
	local wall = {
		CF(-1.9, 0.8, 0),
		CF(0, 0.8, 0),
		CF(1.9, 0.8, 0),
		CF(-0.95, -0.85, 0),
		CF(0.95, -0.85, 0),
		CF(0, 2.45, 0),
	}
	local sclera, mesh = Core.ellipsoid(c, V(2.6, 1.25, 0.4), gold, NEON)
	local iris = Core.part(c, V(0.06, 0.85, 0.85), c.c2, NEON, 0, CYL)
	local pupil = Core.part(c, V(0.07, 0.4, 0.4), BLACK, SMOOTH, 0, CYL)
	for k = 1, 6 do
		local a = (k - 1) / 6 * TAU
		local tgt = Core.att(c, nil, CF(math.cos(a) * 3.6, c.groundY + 0.05, math.sin(a) * 3.6))
		Core.beam(c, eyeAtt, tgt, gold, 0.1, { w1 = 0.9, tr = ns(0.55, 0.95), segs = 2 })
	end
	B.ring(c, {
		n = 12,
		radius = 2,
		seg = V(0.12, 0.1, 0),
		color = gold,
		color2 = c.c2,
		spin = 0.8,
		anchor = function(t)
			return CF(0, yE + math.sin(t * 1.3) * 0.15, 0) * ANG(0.25, 0, 0)
		end,
	})
	B.circle(c, { radius = 1.6, color = gold, width = 0.08, tr = 0.3, at = CF(0, yE - 0.9, 0) })
	B.sigil(c, { radius = 5.6, color = gold, color2 = c.c2, ticks = 12, spokes = 6, glow = 0.9, spin = 0.3 })
	Core.emit(eyeAtt, {
		tex = T.spark,
		color = cs(gold, WHITE),
		size = ns(0, 0.45, 0),
		rate = 12,
		life = nr(0.8, 1.4),
		speed = nr(0.8, 2),
		spread = V2(180, 180),
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.spark,
		color = cs(c.c2),
		size = ns(0.35, 0),
		rate = 10,
		life = nr(0.6, 1),
		speed = nr(2, 4),
		spread = V2(180, 180),
	})
	Core.emit(torso, {
		tex = T.glow,
		color = cs(gold, c.c2),
		size = ns(4, 5.5),
		transp = ns(0.84, 1),
		rate = 3,
		life = nr(0.9, 1.3),
		locked = true,
	})
	B.floorEmit(c, 4.8, {
		tex = T.spark,
		color = cs(gold, WHITE),
		size = ns(0, 0.4, 0),
		rate = 16,
		life = nr(1.5, 2.5),
		speed = nr(1.2, 2.5),
	})
	Core.light(eyeAtt, gold, 2.4, 14)
	B.rootLight(c, gold, 2.2, 16, { pulse = 2.4, amp = 0.8 })
	local nextBlink = 0
	Core.on(c, function(t, _, root)
		-- shield wall forms in front, later behind (readable from both cameras)
		local cyc = t % 14
		local wF = smooth01((cyc - 5) / 0.4) * (1 - smooth01((cyc - 6.6) / 0.4))
		local wB = smooth01((cyc - 12) / 0.4) * (1 - smooth01((cyc - 13.6) / 0.4))
		local w = math.max(wF, wB)
		local wz = if wB > wF then 3.5 else -3.5
		local wrot = if wB > wF then ANG(0, math.pi, 0) else CFrame.identity
		for i, p in plates do
			local a = (i - 1) / 6 * TAU + t * 0.55
			local orbitCF = outward(a, 4.4, c.chestY + 0.3 + math.sin(t + i) * 0.45)
			local wallCF = CF(0, c.chestY + 0.3, wz) * wrot * wall[i]
			local cf = root * orbitCF:Lerp(wallCF, w) * ANG(math.pi / 2, 0, 0) * ANG(0, t * 0.5 * (1 - w), 0)
			B.putHex(p.inner, cf)
			B.putHex(p.rim, cf * CF(0, 0.04, 0))
			Core.put(p.emblem, cf * CF(0, -0.07, 0) * ANG(0, math.pi / 4, 0))
			p.att.Position = root:PointToObjectSpace(cf.Position)
		end
		local eyePos = (root * CF(0, yE + math.sin(t * 1.3) * 0.15, 0)).Position
		local look = CFrame.lookAt(eyePos, camPos())
		Core.put(sclera, look)
		local blinkK = 1
		if t >= nextBlink then
			nextBlink = t + 3 + c.rng:NextNumber() * 3
		end
		local b = nextBlink - t
		if b < 0.16 then
			blinkK = math.max(0.08, math.abs(b - 0.08) / 0.08)
		end
		mesh.Scale = V(1, blinkK, 1)
		local hide = if blinkK < 0.5 then 1 else 0
		iris.Transparency = hide
		pupil.Transparency = hide
		Core.put(iris, look * CF(0, 0, -0.19) * AXIS_Z)
		Core.put(pupil, look * CF(0, 0, -0.23) * AXIS_Z)
	end)
end

---------------------------------------------------------------- MYTHIC

-- concentric rings 0..3 around the body, core orb at chest
-- parts ~86, emitters 5
A.Kernel = function(c: Ctx)
	local cy = c.chestY + 0.4
	local function anchor(k: number): (t: number) -> CFrame
		local amp = 0.55 / (1 + k * 0.6)
		return function(t: number): CFrame
			return CF(0, cy, 0)
				* ANG(
					math.sin(t * 0.4 + k) * amp,
					t * (0.3 + k * 0.1) * (if k % 2 == 0 then 1 else -1),
					math.cos(t * 0.5 + k * 1.3) * amp
				)
		end
	end
	local spins = { 1.6, -1.2, 0.9, -0.6 }
	local counts = { 10, 14, 18, 22 }
	local radii = { 2.3, 3.7, 5.1, 6.6 }
	local coreL = V(0, cy, -1.15)
	local coreAtt = Core.att(c, nil, CF(coreL))
	local labels: { Attachment } = {}
	for k = 0, 3 do
		local col = if k % 2 == 0 then c.c1 else c.c2
		B.ring(c, {
			n = counts[k + 1],
			radius = radii[k + 1],
			seg = V(0.16, 0.24, 0),
			color = col,
			color2 = col:Lerp(WHITE, 0.4),
			spin = spins[k + 1],
			anchor = anchor(k),
		})
		B.circle(c, { radius = radii[k + 1], color = col, width = 0.05, tr = 0.4, anchor = anchor(k), n = 10 })
		local att, lbl = B.glyph(c, "RING " .. k, col, V2(1.7, 0.42), F.tech, nil, BLACK)
		lbl.TextStrokeTransparency = 0.2
		labels[k + 1] = att
		Core.beam(c, coreAtt, att, col, 0.06, { tr = ns(0.15, 0.7), tex = T.square, texLen = 0.5, texSpeed = 3 })
	end
	local core = Core.part(c, V(1.1, 1.1, 1.1), c.c1, NEON, 0.25, BALL)
	local inner = Core.part(c, V(0.55, 0.55, 0.55), WHITE, NEON, 0, BALL)
	local shell = Core.part(c, V(1.9, 1.9, 1.9), c.c2, FF, 0, BALL)
	B.pillar(c, { color = c.c1, color2 = c.c2, height = 45, width = 1.8, tr = 0.45, streams = 3, radius = 1.4 })
	B.sigil(c, { radius = 7.2, color = c.c1, color2 = c.c2, ticks = 16, spokes = 8, glow = 0.88, spin = 0.3, pulse = 1.2 })
	Core.emit(coreAtt, {
		tex = T.glow,
		color = cs(c.c1, c.c2),
		size = ns(2.5, 4),
		transp = ns(0.35, 1),
		rate = 6,
		life = nr(0.4, 0.6),
		locked = true,
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0.45, 0),
		rate = 14,
		life = nr(1, 1.6),
		speed = nr(3, 6),
		spread = V2(180, 180),
		drag = 1,
	})
	Core.emit(torso, {
		tex = T.spark,
		color = cs(c.c2, WHITE),
		size = ns(0.45, 0),
		rate = 14,
		life = nr(1, 1.6),
		speed = nr(3, 6),
		spread = V2(180, 180),
		drag = 1,
	})
	B.floorEmit(c, 6, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.3, 0),
		transp = ns(0.05, 1),
		rate = 26,
		life = nr(1.5, 2.5),
		speed = nr(2, 4),
		rot = nr(0, 0),
	})
	local light = B.rootLight(c, c.c1, 3, 18, { y = cy })
	Core.on(c, function(t, _, root)
		for k = 0, 3 do
			local a = t * spins[k + 1] + k
			local r = radii[k + 1]
			labels[k + 1].Position = (anchor(k)(t) * CF(math.cos(a) * r, 0.55, math.sin(a) * r)).Position
		end
		local beat = Core.pulse(t, 1.2)
		local cf = root * CF(coreL)
		Core.put(core, cf)
		Core.put(inner, cf)
		local s = 1.8 + beat * 0.5
		shell.Size = V(s, s, s)
		Core.put(shell, cf)
		light.Brightness = 2.4 + beat * 2.2
	end)
end

-- body semi-transparent, white wisps, cloak of fading pixels
-- parts ~90, emitters 4
A.GhostProtocol = function(c: Ctx)
	local holder = c.folder.Parent
	for _, d in c.char:GetDescendants() do
		if holder and d:IsDescendantOf(holder) then
			continue
		end
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			Core.override(c, d, "Transparency", math.max(d.Transparency, 0.6))
		elseif d:IsA("Decal") then
			Core.override(c, d, "Transparency", math.max(d.Transparency, 0.7))
		end
	end
	local pale = WHITE:Lerp(c.c1, 0.5)
	local skin = B.clones(c, { set = "lite", color = c.c1, mat = FF, scale = 1.02 })
	-- delayed echoes drifting around the player ("everywhere")
	local echoA = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = FF,
		delay = 0.35,
		map = B.offsetMap(function(t)
			local a = t * 0.5
			return CF(math.cos(a) * 3.4, 0, math.sin(a) * 3.4)
		end),
	})
	local echoB = B.clones(c, {
		set = "lite",
		color = c.c2:Lerp(WHITE, 0.4),
		mat = FF,
		delay = 0.7,
		map = B.offsetMap(function(t)
			local a = t * 0.5 + math.pi
			return CF(math.cos(a) * 3.4, 0, math.sin(a) * 3.4)
		end),
	})
	local COLS, ROWS = 7, 7
	type Px = { p: BasePart, col: number, row: number, seed: number }
	local px: { Px } = {}
	for row = 0, ROWS - 1 do
		for col = 0, COLS - 1 do
			local p = Core.part(c, V(0.42, 0.42, 0.05), c.c1:Lerp(c.c2, row / (ROWS - 1)))
			table.insert(px, { p = p, col = col, row = row, seed = (col * 7 + row * 13) % 17 / 17 })
		end
	end
	B.orbiters(c, {
		n = 4,
		radius = 4.8,
		y = c.chestY + 0.5,
		color = WHITE,
		color2 = c.c1,
		size = 0.35,
		speed = 0.9,
		tilt = ANG(0.25, 0, 0.1),
		bob = 1.2,
		trail = 0.7,
		life = 1.4,
	})
	B.sigil(c, { radius = 6.5, color = pale, color2 = c.c2, rings = 3, glow = 0.93, pulse = 2.5 })
	local _, tag = B.glyph(c, "[ DISAVOWED ]", pale, V2(3.6, 0.5), F.tech, CF(0, c.topY + 1.5, 0), c.c2)
	local back = Core.att(c, c.torso, CF(0, -c.torso.Size.Y * 0.4, c.torso.Size.Z / 2 + 0.4))
	Core.emit(back, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.3, 0),
		transp = ns(0.05, 1),
		rate = 18,
		life = nr(1.5, 2.5),
		speed = nr(1, 2.5),
		spread = V2(45, 45),
		dir = Enum.NormalId.Back,
		accel = V(0, 1.2, 0),
		rot = nr(0, 0),
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.smoke,
		color = cs(WHITE, c.c1),
		size = ns(2, 5),
		transp = ns(0.82, 1),
		rate = 7,
		life = nr(1.8, 2.8),
		speed = nr(0.6, 1.4),
		spread = V2(180, 180),
		rotSpeed = nr(-40, 40),
		accel = V(0, 0.8, 0),
		light = 0.7,
	})
	B.floorEmit(c, 5, {
		tex = T.smoke,
		color = cs(WHITE, c.c2),
		size = ns(3, 6),
		transp = ns(0.84, 1),
		rate = 6,
		life = nr(2.5, 3.5),
		speed = nr(0.3, 0.8),
		rotSpeed = nr(-20, 20),
		light = 0.5,
	})
	Core.emit(torso, {
		tex = T.glow,
		color = cs(WHITE, c.c1),
		size = ns(0, 0.9, 0),
		transp = ns(0.2, 1),
		rate = 12,
		life = nr(2, 3),
		speed = nr(2, 4),
		spread = V2(180, 180),
		drag = 1.2,
		accel = V(0, 1.5, 0),
	})
	B.rootLight(c, pale, 1.8, 16, { pulse = 2.5, amp = 1.2 })
	local ts = c.torso.Size
	Core.on(c, function(t)
		local tcf = c.torso.CFrame
		local cloakOff = (t % 6) < 0.3
		for _, sp in skin do
			sp.Transparency = if cloakOff then 1 else 0
		end
		local ea = 0.55 + 0.45 * Core.pulse(t, 3.2)
		local eb = 0.55 + 0.45 * Core.pulse(t, 3.2, 0.5)
		for _, p in echoA do
			p.Transparency = ea
		end
		for _, p in echoB do
			p.Transparency = eb
		end
		for _, q in px do
			local row, col = q.row, q.col
			local flare = row / (ROWS - 1)
			local x = (col - (COLS - 1) / 2) * 0.46 * (1 + flare * 0.45)
			local y = ts.Y / 2 + 0.1 - row * 0.46
			local z = ts.Z / 2 + 0.15 + flare * 0.7 + math.sin(t * 2.6 + row * 0.7 + col * 0.5) * 0.12 * flare
			local tr = math.clamp(math.noise(col * 0.7, row * 0.7, t * 0.8) * 1.2 + 0.1, 0, 0.7)
			local drift = Vector3.zero
			if row >= ROWS - 3 then
				local ph = (t * 0.3 + q.seed) % 1
				if ph > 0.5 then
					local f = (ph - 0.5) / 0.5
					drift = V(math.sin(q.seed * 20) * f * 1.4, f * 2.6, f * 4)
					tr = math.max(tr, f)
				end
			end
			q.p.Transparency = tr
			Core.put(q.p, tcf * CF(V(x, y, z) + drift) * ANG(-0.25 * flare, 0, 0))
		end
		tag.TextTransparency = if math.noise(t * 2, 7) > 0.25 then 0.85 else 0.1
	end)
end

-- six neon wings, halo of code, feather pixels falling
-- parts ~84, emitters 6
A.CyberSeraph = function(c: Ctx)
	local rng = c.rng
	type WingSpec = { y: number, p0: number, p1: number, l0: number, l1: number, yaw: number, ph: number, w: number }
	local specs: { WingSpec } = {
		{ y = c.chestY + 0.75, p0 = 0.2, p1 = 1.05, l0 = 7.2, l1 = 4.6, yaw = 0.26, ph = 0, w = 0.6 },
		{ y = c.chestY + 0.35, p0 = 1.08, p1 = 1.78, l0 = 6, l1 = 3.8, yaw = 0.34, ph = 0.45, w = 0.55 },
		{ y = c.chestY - 0.05, p0 = 1.9, p1 = 2.6, l0 = 4.4, l1 = 2.7, yaw = 0.42, ph = 0.9, w = 0.48 },
	}
	type Wing = { spec: WingSpec, s: number, bone: BasePart, feathers: { BasePart } }
	local wings: { Wing } = {}
	local NF = 6
	for _, sp in specs do
		for _, s in { 1, -1 } do
			local fs = {}
			for j = 1, NF do
				local f = (j - 1) / (NF - 1)
				local L = sp.l0 + (sp.l1 - sp.l0) * f
				local fp = Core.part(c, V(sp.w * (1 - f * 0.25), L, 0.08), WHITE:Lerp(c.c2, 0.15 + f * 0.75), NEON, 0.04)
				fs[j] = fp
				if j == 1 then
					local hw = sp.w / 2
					B.tipTrail(fp, V(-hw, L / 2 - 0.05, 0), V(hw, L / 2 - 0.05, 0), WHITE, 0.6, c.c2)
				end
			end
			table.insert(
				wings,
				{ spec = sp, s = s, bone = Core.part(c, V(0.24, sp.l0 * 0.62, 0.16), c.c2), feathers = fs }
			)
		end
	end
	-- halo of code
	local yH = c.topY + 0.95
	local haloTilt = ANG(0.15, 0, 0)
	B.ring(c, {
		n = 20,
		radius = 1.3,
		seg = V(0.12, 0.12, 0),
		color = WHITE,
		color2 = c.c2,
		spin = 0.6,
		anchor = function(t)
			return CF(0, yH + math.sin(t * 1.5) * 0.08, 0) * haloTilt
		end,
	})
	B.circle(c, { radius = 1.3, color = c.c2, width = 0.16, tr = 0.05, at = CF(0, yH, 0) * haloTilt })
	B.circle(c, { radius = 1.75, color = WHITE, width = 0.05, tr = 0.35, at = CF(0, yH, 0) * haloTilt })
	-- sun disc behind the head (reads from the front and from behind)
	local discCF = CF(0, c.headY + 0.5, 0.75) * ANG(math.pi / 2, 0, 0)
	B.circle(c, { radius = 2.3, color = c.c2, width = 0.12, tr = 0.25, at = discCF, n = 8 })
	B.circle(c, { radius = 2.65, color = WHITE, width = 0.05, tr = 0.4, at = discCF, n = 8 })
	type Gl = { att: Attachment, lbl: TextLabel }
	local code: { Gl } = {}
	for i = 1, 12 do
		local att, lbl = B.glyph(c, "1", c.c2, V2(0.5, 0.5), F.pixel, nil, WHITE)
		lbl.TextStrokeTransparency = 0.6
		code[i] = { att = att, lbl = lbl }
	end
	B.pillar(c, { color = WHITE, color2 = c.c2, height = 55, width = 3.4, tr = 0.6, streams = 3, radius = 1.6 })
	B.sigil(c, { radius = 7, color = WHITE, color2 = c.c2, ticks = 16, spokes = 6, glow = 0.9, spin = 0.25 })
	-- falling light feathers from above
	local sky = Core.volume(c, V(10, 1, 6), CF(0, c.topY + 6, 0.8))
	Core.emit(sky, {
		tex = T.square,
		color = cs(WHITE, c.c2),
		size = ns(0.42, 0.36, 0),
		transp = ns(0.6, 0, 0, 1),
		squash = ns(1.4),
		rate = 14,
		life = nr(4, 5.5),
		speed = nr(0.3, 0.7),
		dir = Enum.NormalId.Bottom,
		accel = V(0, -0.8, 0),
		drag = 0.6,
		rotSpeed = nr(-70, 70),
		shape = BOX,
	})
	local wingVol = Core.volume(c, V(13, 7, 1.4), CF(0, 1.6, 1.4), c.torso)
	Core.emit(wingVol, {
		tex = T.spark,
		color = cs(WHITE, c.c2),
		size = ns(0, 0.5, 0),
		rate = 24,
		life = nr(0.8, 1.5),
		speed = nr(0.3, 0.9),
		spread = V2(180, 180),
		shape = BOX,
	})
	Core.emit(wingVol, {
		tex = T.square,
		color = cs(WHITE, c.c2),
		size = ns(0.26, 0),
		transp = ns(0, 1),
		squash = ns(1.2),
		rate = 16,
		life = nr(1.8, 2.8),
		speed = nr(0.2, 0.5),
		accel = V(0, -1.6, 0),
		drag = 0.8,
		rotSpeed = nr(-90, 90),
		shape = BOX,
	})
	local haloAtt = Core.att(c, nil, CF(0, yH, 0))
	Core.emit(haloAtt, {
		tex = T.spark,
		color = cs(WHITE, c.c2),
		size = ns(0, 0.4, 0),
		rate = 10,
		life = nr(0.8, 1.3),
		speed = nr(0.5, 1.2),
		spread = V2(180, 180),
	})
	Core.emit(Core.att(c, c.torso, CF(0, 0.6, 1.2)), {
		tex = T.glow,
		color = cs(WHITE, c.c2),
		size = ns(6, 8),
		transp = ns(0.82, 1),
		rate = 3,
		life = nr(0.9, 1.3),
		locked = true,
	})
	B.floorEmit(c, 5.5, {
		tex = T.glow,
		color = cs(WHITE, c.c2),
		size = ns(0, 0.6, 0),
		transp = ns(0.2, 1),
		rate = 16,
		life = nr(2, 3),
		speed = nr(1, 2.2),
	})
	B.rootLight(c, WHITE, 2.8, 18, { pulse = 3, amp = 1 })
	Core.light(haloAtt, c.c2, 2, 12)
	local nextC = 0
	Core.on(c, function(t, _, root)
		for _, w in wings do
			local sp = w.spec
			local s = w.s
			local flap = math.sin(t * 1.5 + sp.ph)
			local base = root
				* CF(s * 0.35, sp.y + flap * 0.08, 0.6)
				* ANG(0, -s * (sp.yaw + flap * 0.22), 0)
				* ANG(-0.12 + flap * 0.06, 0, 0)
			Core.put(w.bone, base * ANG(0, 0, -s * (sp.p0 - 0.1)) * CF(0, sp.l0 * 0.31, -0.04))
			for j, f in w.feathers do
				local phi = (sp.p0 + (sp.p1 - sp.p0) * (j - 1) / (NF - 1)) * (1 + flap * 0.07)
				Core.put(f, base * ANG(0, 0, -s * phi) * CF(0, f.Size.Y / 2, 0.03 * j))
			end
		end
		local change = t >= nextC
		if change then
			nextC = t + 0.12
		end
		local hcf = CF(0, yH, 0) * haloTilt
		for i, g in code do
			local a = (i - 1) / 12 * TAU - t * 0.9
			g.att.Position = (hcf * CF(math.cos(a) * 1.75, 0.1, math.sin(a) * 1.75)).Position
			if change and rng:NextNumber() < 0.3 then
				g.lbl.Text = if rng:NextNumber() < 0.5 then "0" else "1"
			end
		end
	end)
end

-- blue panels with sad face text orbiting, error popups
-- parts ~67, emitters 4
A.BlueScreen = function(c: Ctx)
	local rng = c.rng
	type Panel = { body: BasePart, bar: BasePart, pct: TextLabel }
	local panels: { Panel } = {}
	local pcts: { TextLabel } = {}
	local function bsod(part: BasePart, face: Enum.NormalId, pps: number): TextLabel
		local sg = Core.surface(part, face, pps)
		local bg = Core.frame(sg, c.c1, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		Core.label(bg, ":(", WHITE, F.mono, UDim2.fromScale(0.06, 0.04), UDim2.fromScale(0.3, 0.38), Enum.TextXAlignment.Left)
		Core.label(
			bg,
			"Your PC ran into a problem and needs to restart.",
			WHITE,
			F.mono,
			UDim2.fromScale(0.06, 0.45),
			UDim2.fromScale(0.88, 0.16),
			Enum.TextXAlignment.Left
		)
		local pct = Core.label(
			bg,
			"0% complete",
			WHITE,
			F.mono,
			UDim2.fromScale(0.06, 0.63),
			UDim2.fromScale(0.5, 0.1),
			Enum.TextXAlignment.Left
		)
		local qr = Core.frame(bg, WHITE, UDim2.fromScale(0.06, 0.77), UDim2.fromScale(0.13, 0.2))
		for i = 0, 4 do
			for j = 0, 4 do
				if rng:NextNumber() < 0.5 then
					Core.frame(qr, c.c1, UDim2.fromScale(i * 0.2, j * 0.2), UDim2.fromScale(0.2, 0.2))
				end
			end
		end
		Core.label(
			bg,
			"Stop code: GLITCH_RNG_OVERFLOW",
			WHITE,
			F.mono,
			UDim2.fromScale(0.24, 0.84),
			UDim2.fromScale(0.7, 0.09),
			Enum.TextXAlignment.Left
		)
		table.insert(pcts, pct)
		return pct
	end
	for i = 1, 6 do
		local body = Core.part(c, V(2.6, 1.6, 0.06), c.c1, SMOOTH)
		panels[i] = {
			body = body,
			bar = Core.part(c, V(2.6, 0.08, 0.09), c.c1:Lerp(WHITE, 0.6)),
			pct = bsod(body, Enum.NormalId.Front, 70),
		}
	end
	-- giant monitor floating behind, BSOD on both faces
	local monitor = Core.part(c, V(5.2, 3.1, 0.08), c.c1, SMOOTH)
	bsod(monitor, Enum.NormalId.Front, 45)
	bsod(monitor, Enum.NormalId.Back, 45)
	local monFrame = Core.part(c, V(5.4, 3.3, 0.05), c.c1:Lerp(WHITE, 0.5), NEON)
	type Pop = { win: BasePart, title: BasePart, x: BasePart, cf: CFrame, t0: number, life: number }
	local pops: { Pop } = {}
	local codes = { "0x000000EF", "0x0000007B", "0xC000021A", "0x00000050", "0x0000001E" }
	local msgs = {
		"Critical process died.",
		"Inaccessible boot device.",
		"Page fault in nonpaged area.",
		"Kernel security check failure.",
		"IRQL not less or equal.",
	}
	local PW, PH = 1.9, 1.05
	for i = 1, 5 do
		local win = Core.part(c, V(PW, PH, 0.05), Color3.fromRGB(225, 228, 235), SMOOTH)
		local sg = Core.surface(win, Enum.NormalId.Front, 80)
		local icon = Core.label(sg, "X", WHITE, F.tech, UDim2.fromScale(0.05, 0.3), UDim2.fromScale(0.16, 0.3))
		icon.BackgroundTransparency = 0
		icon.BackgroundColor3 = Color3.fromRGB(220, 30, 40)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = icon
		Core.label(
			sg,
			"ERROR " .. codes[i],
			Color3.fromRGB(20, 20, 30),
			F.mono,
			UDim2.fromScale(0.26, 0.3),
			UDim2.fromScale(0.7, 0.16),
			Enum.TextXAlignment.Left
		)
		Core.label(
			sg,
			msgs[i],
			Color3.fromRGB(60, 60, 80),
			F.mono,
			UDim2.fromScale(0.26, 0.5),
			UDim2.fromScale(0.7, 0.12),
			Enum.TextXAlignment.Left
		)
		local ok = Core.frame(sg, Color3.fromRGB(200, 205, 215), UDim2.fromScale(0.7, 0.72), UDim2.fromScale(0.24, 0.18))
		Core.label(ok, "OK", Color3.fromRGB(20, 20, 30), F.mono, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		pops[i] = {
			win = win,
			title = Core.part(c, V(PW, 0.22, 0.06), Color3.fromRGB(0, 90, 220), SMOOTH),
			x = Core.part(c, V(0.16, 0.16, 0.07), Color3.fromRGB(255, 40, 50)),
			cf = CF(0, -50, 0),
			t0 = os.clock() + i * 0.45,
			life = 1.6,
		}
	end
	local spinner: { BasePart } = {}
	for i = 1, 8 do
		spinner[i] = Core.part(c, V(0.2, 0.2, 0.2), WHITE, NEON, 0, BALL)
	end
	type Px = { p: BasePart, cf: CFrame, nextT: number }
	local pixels: { Px } = {}
	for i = 1, 12 do
		pixels[i] = { p = Core.part(c, V(0.4, 0.4, 0.4), if i % 3 == 0 then WHITE else c.c1), cf = CF(0, -50, 0), nextT = 0 }
	end
	B.sigil(c, { radius = 6.6, color = c.c1, color2 = c.c2, ticks = 16, spokes = 8, glow = 0.88, spin = 0.35 })
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.25, 0),
		rate = 16,
		life = nr(0.5, 0.9),
		speed = nr(3, 6),
		spread = V2(180, 180),
		rot = nr(0, 0),
	})
	Core.emit(torso, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0, 0.45, 0),
		rate = 10,
		life = nr(0.8, 1.2),
		speed = nr(1, 2),
		spread = V2(180, 180),
	})
	Core.emit(torso, {
		tex = T.glow,
		color = cs(c.c1),
		size = ns(4, 6),
		transp = ns(0.82, 1),
		rate = 3,
		life = nr(0.8, 1.2),
		locked = true,
	})
	B.floorEmit(c, 5.5, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.3, 0),
		transp = ns(0.05, 1),
		rate = 22,
		life = nr(1.4, 2.2),
		speed = nr(1.5, 3.5),
		rot = nr(0, 0),
	})
	local light = B.rootLight(c, c.c1, 2.8, 18)
	local lastPct = -1
	Core.on(c, function(t, _, root)
		local flash = (t % 5) < 0.12
		local pct = math.floor((t * 7) % 101)
		if pct ~= lastPct then
			lastPct = pct
			local s = pct .. "% complete"
			for _, l in pcts do
				l.Text = s
			end
		end
		for i, p in panels do
			local a = (i - 1) / 6 * TAU + t * 0.35
			local cf = root
				* outward(a, 5.2, c.chestY + 0.4 + math.sin(t * 1.2 + i) * 0.3 + (if flash then 0.15 else 0))
			Core.put(p.body, cf)
			Core.put(p.bar, cf * CF(0, 0.84, 0))
		end
		local mcf = root * CF(0, c.topY + 2.4 + math.sin(t * 0.8) * 0.15, 2.4) * ANG(0, math.pi, 0) * ANG(-0.15, 0, 0)
		Core.put(monitor, mcf)
		Core.put(monFrame, mcf * CF(0, 0, 0.02))
		for _, p in pops do
			local age = t - p.t0
			if age > p.life + 0.3 then
				p.t0 = t
				p.life = 1.2 + rng:NextNumber()
				age = 0
				local a = rng:NextNumber() * TAU
				local r = 3 + rng:NextNumber() * 1.6
				p.cf = outward(a, r, c.chestY - 0.2 + rng:NextNumber() * 2.4) * ANG(0, 0, (rng:NextNumber() - 0.5) * 0.3)
			end
			local s
			if age < 0 or age > p.life then
				s = 0.05
			elseif age < 0.12 then
				s = 0.2 + age / 0.12 * 0.9
			elseif age < 0.2 then
				s = 1.1 - (age - 0.12) / 0.08 * 0.1
			else
				s = 1
			end
			local hidden = s < 0.1
			p.win.Size = V(PW * s, PH * s, 0.05)
			p.title.Size = V(PW * s, 0.22 * s, 0.06)
			p.win.Transparency = if hidden then 1 else 0
			p.title.Transparency = if hidden then 1 else 0
			p.x.Transparency = if hidden then 1 else 0
			local cf = root * p.cf
			Core.put(p.win, cf)
			Core.put(p.title, cf * CF(0, (PH / 2 + 0.11) * s, 0))
			Core.put(p.x, cf * CF((PW / 2 - 0.12) * s, (PH / 2 + 0.11) * s, -0.03))
		end
		local scf = CFrame.lookAt((root * CF(0, c.topY + 1.2, 0)).Position, camPos())
		for i, d in spinner do
			local a = (i - 1) * 0.4 - t * 5
			Core.put(d, scf * CF(math.cos(a) * 0.55, math.sin(a) * 0.55, 0))
			d.Transparency = (i - 1) / 9
		end
		for _, q in pixels do
			if t >= q.nextT then
				q.nextT = t + 0.08 + rng:NextNumber() * 0.2
				local a = rng:NextNumber() * TAU
				local r = 2 + rng:NextNumber() * 4.5
				q.cf = CF(math.cos(a) * r, c.groundY + 0.5 + rng:NextNumber() * 5, math.sin(a) * r)
				local s = 0.15 + rng:NextNumber() * 0.5
				q.p.Size = V(s * (1 + rng:NextNumber() * 2), s, s)
				q.p.Transparency = if rng:NextNumber() < 0.25 then 1 else 0
			end
			Core.put(q.p, root * q.cf)
		end
		light.Brightness = if flash then 7 else 2.4 + Core.pulse(t, 1.5) * 0.8
	end)
end

---------------------------------------------------------------- CORRUPTED

-- black-red tearing shards, ground cracks, inverted ghosts
-- parts ~88, emitters 5
A.Corruption = function(c: Ctx)
	local rng = c.rng
	local blood = Color3.fromRGB(120, 0, 10)
	type Shard = {
		slab: BasePart,
		edge: BasePart,
		a: number,
		r: number,
		y: number,
		w: number,
		rot: CFrame,
		tear: number,
		tdir: CFrame,
	}
	local shards: { Shard } = {}
	for i = 1, 22 do
		local h = 0.8 + rng:NextNumber() * 1.4
		local wd = 0.4 + rng:NextNumber() * 0.7
		shards[i] = {
			slab = Core.part(c, V(0.08, h, wd), Color3.fromRGB(6, 2, 4), SMOOTH),
			edge = Core.part(c, V(0.1, h, 0.07), c.c1),
			a = rng:NextNumber() * TAU,
			r = 3 + rng:NextNumber() * 4.2,
			y = c.groundY + 0.8 + rng:NextNumber() * (c.topY - c.groundY + 2.5),
			w = (0.25 + rng:NextNumber() * 0.4) * (if i % 2 == 0 then 1 else -1),
			rot = ANG(rng:NextNumber() * TAU, rng:NextNumber() * TAU, rng:NextNumber() * TAU),
			tear = -10,
			tdir = CFrame.identity,
		}
	end
	local g = c.groundY
	local disc = Core.part(c, V(0.04, 13, 13), Color3.fromRGB(8, 0, 3), SMOOTH, 0.15, CYL)
	type Crack = { beams: { Beam }, off: number }
	local cracks: { Crack } = {}
	for k = 1, 9 do
		local a = (k - 1) / 9 * TAU + rng:NextNumber() * 0.4
		local pts = {}
		local rad = 0.4
		for _ = 0, 6 do
			a += (rng:NextNumber() - 0.5) * 0.6
			table.insert(pts, V(math.cos(a) * rad, g + 0.07, math.sin(a) * rad))
			rad += 1 + rng:NextNumber() * 0.5
		end
		local poly = B.poly(c, pts, c.c1, 0.24, { w1 = 0.1, segs = 1, bright = 3 })
		table.insert(cracks, { beams = poly.beams, off = rng:NextNumber() })
	end
	local top = c.topY + 0.15
	B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = FF,
		map = function(cf, root)
			return root * B.mirrorY(root:ToObjectSpace(cf), top)
		end,
	})
	B.clones(c, { set = "lite", color = BLACK, mat = NEON, tr = 0.35, delay = 0.2, fps = 10 })
	-- corrupted block halo, glitch-jumping
	B.ring(c, {
		n = 18,
		radius = 8.2,
		seg = V(0.5, 0.5, 0.5),
		color = c.c1,
		color2 = Color3.fromRGB(14, 2, 6),
		spin = 0.25,
		anchor = function(t)
			return CF(0, c.chestY + 1.2, 0) * ANG(math.sin(t * 0.3) * 0.18, 0, math.cos(t * 0.27) * 0.18)
		end,
		paint = function(k, t, p)
			local n = math.noise(k * 0.37, t * 2.5)
			p.Transparency = if n > 0.3 then 1 else 0
			p.Size = if n < -0.35 then V(0.9, 0.25, 0.9) else V(0.5, 0.5, 0.5)
		end,
	})
	B.sigil(c, { radius = 8.5, color = c.c1, color2 = blood, rings = 3, glow = 0.88, pulse = 0.7 })
	B.pillar(c, { color = c.c1, color2 = BLACK, height = 50, width = 2.4, tr = 0.45, streams = 2, radius = 1.4 })
	local _, err = B.glyph(c, "SAVE FILE CORRUPTED", c.c1, V2(5, 0.6), F.tech, CF(0, c.topY + 2.2, 0), BLACK)
	err.TextStrokeTransparency = 0
	local feet = Core.volume(c, V(13, 0.1, 13), CF(0, g + 0.1, 0))
	Core.emit(feet, {
		tex = T.fireSpark,
		color = cs(c.c1, blood),
		size = ns(0.35, 0),
		rate = 30,
		life = nr(1.2, 2),
		speed = nr(1.5, 3.5),
		accel = V(0, 1, 0),
		bright = 2.5,
		shape = BOX,
	})
	Core.emit(feet, {
		tex = T.smoke,
		color = cs(BLACK, Color3.fromRGB(40, 0, 8)),
		size = ns(3, 7),
		transp = ns(0.45, 1),
		rate = 7,
		life = nr(2, 3),
		speed = nr(0.5, 1.2),
		light = 0,
		rotSpeed = nr(-30, 30),
		shape = BOX,
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.square,
		color = cs(c.c1, BLACK),
		size = ns(0.4, 0.15),
		rate = 18,
		life = nr(0.2, 0.4),
		speed = nr(6, 10),
		spread = V2(180, 180),
		rot = nr(0, 0),
		light = 0.6,
	})
	local storm = Core.volume(c, V(12, 9, 12), CF(0, c.chestY + 1.5, 0))
	Core.emit(storm, {
		tex = T.square,
		color = cs(c.c1, WHITE, c.c1),
		size = ns(0.5, 0.2),
		transp = ns(0, 0.3, 1),
		squash = ns(-0.6),
		rate = 30,
		life = nr(0.1, 0.25),
		speed = nr(0, 0),
		rot = nr(0, 0),
		shape = BOX,
	})
	Core.emit(torso, {
		tex = T.glow,
		color = cs(c.c1, blood),
		size = ns(5, 7),
		transp = ns(0.78, 1),
		rate = 3,
		life = nr(0.6, 1),
		locked = true,
	})
	local light = B.rootLight(c, c.c1, 3, 20)
	Core.on(c, function(t, _, root)
		Core.put(disc, root * CF(0, g + 0.02, 0) * FLAT)
		for _, ck in cracks do
			for j, bm in ck.beams do
				local w = ((t * 0.8 + ck.off) % 1) * 7 - j
				bm.Transparency = NumberSequence.new(math.clamp(0.4 - math.exp(-w * w) * 0.4, 0, 1))
			end
		end
		for _, s in shards do
			if rng:NextNumber() < 0.004 then
				s.tear = t
				s.tdir = ANG((rng:NextNumber() - 0.5) * 2, (rng:NextNumber() - 0.5) * 2, 0)
			end
			local age = t - s.tear
			local k = if age < 0.1 then 1 elseif age < 0.45 then 1 - smooth01((age - 0.1) / 0.35) else 0
			local a = s.a + t * s.w
			local r = s.r + k * 1.4
			local cf = root
				* CF(math.cos(a) * r, s.y + math.sin(t + s.a) * 0.3, math.sin(a) * r)
				* s.rot
				* ANG(t * s.w, 0, 0)
			if k > 0 then
				cf *= CFrame.identity:Lerp(s.tdir, k)
			end
			Core.put(s.slab, cf)
			Core.put(s.edge, cf * CF(0.01, 0, s.slab.Size.Z / 2))
		end
		err.TextTransparency = if rng:NextNumber() < 0.1 then 0.8 else 0
		err.Text = if rng:NextNumber() < 0.04 then "S@VE F1LE C0RRUPT#D" else "SAVE FILE CORRUPTED"
		light.Brightness = 2.4 + math.noise(t * 5, 1) * 3
	end)
end

-- violent red glitch storm, warning triangles, shaking light
-- parts ~76, emitters 5
A.KernelPanic = function(c: Ctx)
	local rng = c.rng
	local amber = Color3.fromRGB(255, 190, 0)
	type Blk = { p: BasePart, cf: CFrame, nextT: number }
	local blocks: { Blk } = {}
	for i = 1, 28 do
		blocks[i] =
			{ p = Core.part(c, V(0.3, 0.3, 0.3), if i % 3 == 0 then c.c2 else c.c1), cf = CF(0, -50, 0), nextT = 0 }
	end
	local TS = 1.7
	type Tri = { bars: { BasePart }, att: Attachment, a: number, y: number }
	local tris: { Tri } = {}
	for i = 1, 6 do
		local att, lbl = B.glyph(c, "!", amber, V2(0.9, 0.9), F.tech, nil, BLACK)
		lbl.TextStrokeTransparency = 0
		tris[i] = {
			bars = B.tri(c, TS, 0.15, if i % 2 == 0 then amber else c.c1),
			att = att,
			a = (i - 1) / 6 * TAU,
			y = c.chestY + (i % 2) * 1.6 - 0.1,
		}
	end
	for _ = 1, 4 do
		B.bolt(c, {
			segs = 8,
			color = WHITE,
			color2 = c.c1,
			width = 0.2,
			jitter = 0.7,
			interval = 0.05,
			flicker = 0.3,
			ends = function()
				local u = rng:NextUnitVector()
				local r = 5 + rng:NextNumber() * 2.5
				return V(0, c.chestY, 0), V(u.X * r, c.chestY + 0.5 + u.Y * 3, u.Z * r)
			end,
		})
	end
	-- lightning striking down from the sky around the player
	for _ = 1, 2 do
		B.bolt(c, {
			segs = 10,
			color = WHITE,
			color2 = c.c1,
			width = 0.4,
			jitter = 2.2,
			interval = 0.12,
			flicker = 0.65,
			ends = function()
				local a = rng:NextNumber() * TAU
				local r = 3 + rng:NextNumber() * 5
				local x, z = math.cos(a) * r, math.sin(a) * r
				return V(x * 0.4, 40, z * 0.4), V(x, c.groundY + 0.05, z)
			end,
		})
	end
	local _, title = B.glyph(c, "KERNEL PANIC", c.c1, V2(5.6, 0.85), F.tech, CF(0, c.topY + 2.2, 0), BLACK)
	title.TextStrokeTransparency = 0
	local streams: { { att: Attachment, lbl: TextLabel } } = {}
	local errs = { "0xDEADBEEF", "SEGFAULT", "STACK SMASH", "NULL DEREF", "DOUBLE FAULT", "0xBAADF00D", "PANIC()" }
	for i = 1, 4 do
		local att, lbl = B.glyph(c, errs[i], WHITE, V2(2.4, 0.4), F.mono, nil, c.c1)
		lbl.TextStrokeTransparency = 0
		streams[i] = { att = att, lbl = lbl }
	end
	B.ring(c, {
		n = 24,
		radius = 6.6,
		seg = V(0.7, 0.09, 0),
		color = c.c1,
		color2 = Color3.fromRGB(18, 18, 18),
		spin = 1.5,
		anchor = function()
			return CF(0, c.groundY + 0.05, 0)
		end,
	})
	B.sigil(c, { radius = 8, color = c.c1, color2 = amber, rings = 2, glow = 0.86, pulse = 0.4 })
	-- rotating alarm searchlights
	local alarm = Core.att(c, nil, CF(0, c.topY + 1, 0))
	local spots: { Attachment } = {}
	for k = 1, 2 do
		spots[k] = Core.att(c)
		Core.beam(c, alarm, spots[k], c.c1, 0.3, { w1 = 4, tr = ns(0.4, 0.95), segs = 2 })
	end
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.fireSpark,
		color = cs(WHITE, c.c1),
		size = ns(0.4, 0),
		rate = 36,
		life = nr(0.4, 0.8),
		speed = nr(8, 14),
		spread = V2(180, 180),
		accel = V(0, -12, 0),
		bright = 3,
	})
	Core.emit(torso, {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.3, 0.1),
		rate = 20,
		life = nr(0.15, 0.3),
		speed = nr(5, 9),
		spread = V2(180, 180),
		rot = nr(0, 0),
	})
	B.floorEmit(c, 6, {
		tex = T.smoke,
		color = cs(c.c1, Color3.fromRGB(60, 0, 0)),
		size = ns(3, 6),
		transp = ns(0.7, 1),
		rate = 8,
		life = nr(1.2, 2),
		speed = nr(1.5, 3),
		light = 0.5,
		rotSpeed = nr(-60, 60),
	})
	local storm = Core.volume(c, V(14, 10, 14), CF(0, c.chestY + 2, 0))
	Core.emit(storm, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.35, 0.1),
		squash = ns(-1.5),
		rate = 40,
		life = nr(0.2, 0.4),
		speed = nr(10, 16),
		dir = Enum.NormalId.Bottom,
		rot = nr(0, 0),
		shape = BOX,
	})
	Core.emit(torso, {
		tex = T.glow,
		color = cs(c.c1),
		size = ns(5, 7),
		transp = ns(0.75, 1),
		rate = 4,
		life = nr(0.3, 0.5),
		locked = true,
	})
	local shakeAtt = Core.att(c, c.torso)
	local shake = Core.light(shakeAtt, c.c1, 3, 22)
	local nextS = 0
	Core.on(c, function(t, _, root)
		for _, b in blocks do
			if t >= b.nextT then
				b.nextT = t + 0.04 + rng:NextNumber() * 0.08
				local u = rng:NextUnitVector() * (2 + rng:NextNumber() * 6)
				b.cf = CF(u.X, c.chestY + 1 + u.Y * 1.1, u.Z) * ANG(rng:NextNumber() * TAU, rng:NextNumber() * TAU, 0)
				local s = 0.15 + rng:NextNumber() * 0.9
				b.p.Size = V(s * (0.5 + rng:NextNumber() * 2), s * (0.3 + rng:NextNumber()), s)
				b.p.Transparency = if rng:NextNumber() < 0.2 then 1 else 0
			end
			Core.put(b.p, root * b.cf)
		end
		for i, tr in tris do
			local a = tr.a + t * 1.1 + math.noise(i, t * 2) * 0.8
			local cf = outward(a, 5, tr.y + math.sin(t * 3 + i) * 0.3) * CF(jitter(rng, 0.12))
			B.putTri(tr.bars, root * cf, TS)
			tr.att.Position = (cf * CF(0, -0.08, -0.08)).Position
		end
		if t >= nextS then
			nextS = t + 0.15
			for i, s in streams do
				if rng:NextNumber() < 0.4 then
					s.lbl.Text = errs[rng:NextInteger(1, #errs)]
				end
				local a = rng:NextNumber() * TAU
				s.att.Position = V(math.cos(a) * 3.6, c.groundY + 1 + i * 1.1, math.sin(a) * 3.6)
			end
		end
		for k, sp in spots do
			local a = t * 2.4 + k * math.pi
			sp.Position = V(math.cos(a) * 12, c.groundY, math.sin(a) * 12)
		end
		title.TextTransparency = if rng:NextNumber() < 0.12 then 0.8 else 0
		title.Rotation = (rng:NextNumber() - 0.5) * 4
		shakeAtt.Position = jitter(rng, 2.5)
		shake.Brightness = 1.5 + rng:NextNumber() * 6
		shake.Color = if rng:NextNumber() < 0.2 then WHITE else c.c1
	end)
end

-- black hole orb above with accretion disc, particles sucked in
-- parts ~70, emitters 5
A.EventHorizon = function(c: Ctx)
	local rng = c.rng
	local O = V(0, c.topY + 5, 0)
	local hot = c.c1:Lerp(WHITE, 0.6)
	local ember = Color3.fromRGB(255, 60, 20)
	local orb = Core.part(c, V(3.4, 3.4, 3.4), BLACK, SMOOTH, 0, BALL)
	local photon = Core.part(c, V(3.7, 3.7, 3.7), c.c1, FF, 0, BALL)
	local function facing(): CFrame
		local camL = c.root.CFrame:PointToObjectSpace(camPos())
		if (camL - O).Magnitude < 0.1 then
			return CF(O)
		end
		return CFrame.lookAt(O, camL) * ANG(math.pi / 2, 0, 0)
	end
	B.circle(c, { radius = 2.0, color = hot, width = 0.32, n = 8, anchor = facing })
	B.circle(c, { radius = 2.6, color = c.c1, width = 0.14, n = 8, tr = 0.35, anchor = facing })
	local function disc(t: number): CFrame
		return CF(O) * ANG(0.3, t * 0.1, 0.12)
	end
	B.ring(c, { n = 24, radius = 3.2, seg = V(1, 0.08, 0), color = hot, color2 = c.c1, spin = 2.2, anchor = disc })
	B.ring(c, {
		n = 28,
		radius = 4.9,
		seg = V(1.3, 0.06, 0),
		color = c.c1,
		color2 = c.c1:Lerp(Color3.fromRGB(120, 10, 0), 0.6),
		spin = 1.1,
		tr = 0.15,
		anchor = disc,
	})
	B.circle(c, { radius = 6.6, color = ember, width = 0.5, n = 10, tr = 0.6, anchor = disc })
	local pN = Core.att(c, nil, CF(O + V(0, 1.7, 0)))
	local pNT = Core.att(c, nil, CF(O + V(0, 38, 0)))
	local pS = Core.att(c, nil, CF(O - V(0, 1.7, 0)))
	local pST = Core.att(c, nil, CF(O - V(0, 4, 0)))
	Core.beam(c, pN, pNT, WHITE, 0.9, { w1 = 0.1, color2 = c.c1, tr = ns(0, 1) })
	Core.beam(c, pN, pNT, c.c1, 2.4, { w1 = 0.3, tr = ns(0.5, 1), zoff = -0.05 })
	Core.beam(c, pS, pST, WHITE, 0.6, { w1 = 0.05, color2 = c.c1, tr = ns(0, 1) })
	-- matter spiralling up from the floor into the hole
	type Stream = { base: Attachment, a: number }
	local streams: { Stream } = {}
	for k = 1, 3 do
		local base = Core.att(c)
		Core.beam(c, base, pS, c.c1, 0.6, {
			w1 = 0.1,
			color2 = hot,
			c0 = 4,
			c1 = -2,
			segs = 20,
			tex = T.square,
			texLen = 0.6,
			texSpeed = 3,
			tr = ns(0.6, 0.1),
		})
		streams[k] = { base = base, a = (k - 1) / 3 * TAU }
	end
	-- debris falling in
	type Deb = { p: BasePart, off: number, a0: number }
	local debris: { Deb } = {}
	for i = 1, 12 do
		local p = Core.part(c, V(0.35, 0.35, 0.35), if i % 2 == 0 then c.c1 else ember)
		Core.trail(p, c.c1, 0.25, 0.4, ember)
		debris[i] = { p = p, off = i / 12, a0 = rng:NextNumber() * TAU }
	end
	-- gravity well: circles contracting towards the player
	for k = 1, 3 do
		B.circle(c, {
			radius = 9,
			color = c.c1,
			width = 0.12,
			n = 10,
			at = CF(0, c.groundY + 0.06, 0),
			radiusFn = function(t)
				return 0.5 + 9 * (1 - ((t * 0.22 + k / 3) % 1))
			end,
		})
	end
	B.sigil(c, { radius = 9.5, color = c.c1, color2 = ember, rings = 2, glow = 0.9 })
	local vol = Core.volume(c, V(16, 16, 16), CF(O))
	Core.emit(vol, {
		tex = T.spark,
		color = cs(c.c1, hot),
		size = ns(0.6, 0.1),
		transp = ns(0.4, 0),
		rate = 50,
		life = nr(1.4, 1.4),
		speed = nr(5.4, 5.8),
		locked = true,
		shape = SPHERE,
		shapeStyle = SURFACE,
		inout = INWARD,
	})
	local dust = Core.volume(c, V(12, 12, 12), CF(O))
	Core.emit(dust, {
		tex = T.smoke,
		color = cs(ember, c.c1),
		size = ns(3, 1),
		transp = ns(0.85, 0.6, 1),
		rate = 8,
		life = nr(1.6, 1.6),
		speed = nr(3.4, 3.8),
		locked = true,
		light = 0.6,
		rotSpeed = nr(-80, 80),
		shape = SPHERE,
		shapeStyle = SURFACE,
		inout = INWARD,
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.spark,
		color = cs(c.c1, hot),
		size = ns(0.35, 0),
		rate = 18,
		life = nr(0.8, 1),
		speed = nr(4, 6),
		spread = V2(15, 15),
		accel = V(0, 3, 0),
	})
	Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.1, 0)), {
		tex = T.shock,
		color = cs(c.c1),
		size = ns(14, 1),
		transp = ns(1, 0.4, 0.9),
		rate = 0.7,
		life = nr(1.4, 1.4),
		speed = nr(0.01, 0.01),
		orient = PERP,
		rot = nr(0, 360),
	})
	local orbAtt = Core.att(c, nil, CF(O))
	Core.emit(orbAtt, {
		tex = T.glow,
		color = cs(c.c1, ember),
		size = ns(9, 11),
		transp = ns(0.7, 1),
		rate = 3,
		life = nr(0.8, 1.2),
		locked = true,
	})
	local ol = Core.light(orbAtt, c.c1, 3.5, 22)
	B.rootLight(c, ember, 2, 16, { pulse = 0.9, amp = 1 })
	Core.on(c, function(t, _, root)
		local cf = root * CF(O)
		Core.put(orb, cf)
		local s = 3.7 + Core.pulse(t, 0.9) * 0.18
		photon.Size = V(s, s, s)
		Core.put(photon, cf)
		for _, st in streams do
			local a = st.a + t * 0.4
			st.base.CFrame = CFrame.fromMatrix(
				V(math.cos(a) * 7, c.groundY + 0.1, math.sin(a) * 7),
				V(-math.sin(a), 0, math.cos(a)),
				Vector3.yAxis
			)
		end
		for _, d in debris do
			local f = (t * 0.18 + d.off) % 1
			local r = 9 * (1 - f) ^ 1.5 + 1.8
			local a = d.a0 + f * f * 9 + t * 0.3
			local y = (c.groundY + 0.5) + (O.Y - c.groundY - 0.5) * smooth01(f)
			Core.put(d.p, root * CF(math.cos(a) * r, y, math.sin(a) * r) * ANG(t * 3, t * 2, 0))
			d.p.Transparency = if f > 0.92 then (f - 0.92) / 0.08 else 0
		end
		ol.Brightness = 3 + Core.pulse(t, 0.9) * 1.6
	end)
end

-- pure black void silhouette with white outline and inverted pixels
-- parts ~75, emitters 4
A.NullPointer = function(c: Ctx)
	local rng = c.rng
	local holder = c.folder.Parent
	for _, d in c.char:GetDescendants() do
		if holder and d:IsDescendantOf(holder) then
			continue
		end
		if d:IsA("Decal") then
			Core.override(c, d, "Transparency", 1)
		elseif d:IsA("BasePart") and d.Parent and d.Parent:IsA("Accessory") then
			Core.override(c, d, "Transparency", 1)
		end
	end
	local void = Instance.new("Model")
	void.Name = "Void"
	void.Parent = c.folder
	local sil = B.clones(c, { set = "full", color = BLACK, mat = SMOOTH, scale = 1.06 })
	for _, p in sil do
		p.Parent = void
	end
	local hl = Instance.new("Highlight")
	hl.Adornee = void
	hl.FillColor = BLACK
	hl.FillTransparency = 0
	hl.OutlineColor = WHITE
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = c.folder
	-- inverted pixels: black ones live in the void model and get the white outline
	type Px = { p: BasePart, a: number, r: number, y: number, nextT: number, w: number }
	local pix: { Px } = {}
	for i = 1, 28 do
		local black = i % 2 == 1
		local p = Core.part(c, V(0.5, 0.5, 0.05), if black then BLACK else WHITE, if black then SMOOTH else NEON)
		if black then
			p.Parent = void
		end
		pix[i] = {
			p = p,
			a = rng:NextNumber() * TAU,
			r = 2 + rng:NextNumber() * 5,
			y = c.groundY + 0.6 + rng:NextNumber() * (c.topY - c.groundY + 3),
			nextT = 0,
			w = (0.15 + rng:NextNumber() * 0.25) * (if i % 4 < 2 then 1 else -1),
		}
	end
	local words = { "NULL", "0x00000000", "nil", "void*", "&null", "SIGSEGV", "*ptr = ?" }
	type Gl = { att: Attachment, lbl: TextLabel, a: number, y: number }
	local glyphs: { Gl } = {}
	for i = 1, 6 do
		local att, lbl = B.glyph(c, words[i], WHITE, V2(2.2, 0.42), F.tech, nil, BLACK)
		glyphs[i] = { att = att, lbl = lbl, a = (i - 1) / 6 * TAU, y = c.groundY + 1 + i * 0.85 }
	end
	-- the pointer: a giant cursor arrow that keeps pointing at nothing
	local arrow = {
		Core.part(c, V(0.3, 2.4, 0.3), WHITE),
		Core.part(c, V(0.3, 1.3, 0.3), WHITE),
		Core.part(c, V(0.3, 1.3, 0.3), WHITE),
	}
	local g = c.groundY
	local disc = Core.part(c, V(0.04, 14, 14), BLACK, SMOOTH, 0, CYL)
	B.sigil(c, { radius = 7, color = WHITE, rings = 3, glow = nil, pulse = 1.6 })
	B.ring(c, {
		n = 20,
		gap = 2,
		radius = 6,
		seg = V(0.12, 0.06, 0),
		color = WHITE,
		spin = -0.4,
		anchor = function()
			return CF(0, g + 0.06, 0)
		end,
	})
	B.ring(c, {
		n = 24,
		gap = 3,
		radius = 6.8,
		seg = V(0.25, 0.25, 0.6),
		color = WHITE,
		color2 = BLACK,
		spin = 0.3,
		anchor = function(t)
			return CF(0, c.chestY + 1, 0) * ANG(0.35, t * 0.1, 0.2)
		end,
	})
	local vol = Core.volume(c, V(13, 13, 13), CF(0, c.chestY, 0))
	Core.emit(vol, {
		tex = T.square,
		color = cs(WHITE),
		size = ns(0.3, 0.08),
		transp = ns(0.2, 0),
		rate = 40,
		life = nr(1.1, 1.1),
		speed = nr(5.6, 6),
		rot = nr(0, 0),
		locked = true,
		shape = SPHERE,
		shapeStyle = SURFACE,
		inout = INWARD,
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.smoke,
		color = cs(BLACK),
		size = ns(2.5, 6),
		transp = ns(0.4, 1),
		rate = 7,
		life = nr(1.8, 2.6),
		speed = nr(0.6, 1.4),
		spread = V2(180, 180),
		light = 0,
		rotSpeed = nr(-30, 30),
	})
	B.floorEmit(c, 6, {
		tex = T.square,
		color = cs(WHITE),
		size = ns(0.3, 0),
		transp = ns(0, 1),
		rate = 24,
		life = nr(1.5, 2.5),
		speed = nr(2, 4),
		rot = nr(0, 0),
	})
	local light = B.rootLight(c, WHITE, 2, 16)
	local ptrAt, ptrFrom = V(0, c.topY + 0.6, 0), V(0, c.topY + 0.6, 0)
	local ptrT, nextPtr = 0, 0
	Core.on(c, function(t, _, root)
		Core.put(disc, root * CF(0, g + 0.02, 0) * FLAT)
		for _, q in pix do
			if t >= q.nextT then
				q.nextT = t + 0.15 + rng:NextNumber() * 0.5
				q.p.Transparency = if rng:NextNumber() < 0.15 then 1 else 0
			end
			local a = q.a + t * q.w
			Core.put(
				q.p,
				root * CF(math.cos(a) * q.r, q.y + math.sin(t + q.a) * 0.3, math.sin(a) * q.r) * ANG(0, -a, 0)
			)
		end
		for i, gl in glyphs do
			local a = gl.a - t * 0.3
			gl.att.Position = V(math.cos(a) * 4.2, gl.y + math.sin(t * 0.8 + i) * 0.25, math.sin(a) * 4.2)
			local inv = math.noise(i, t * 1.5) > 0.3
			gl.lbl.TextColor3 = if inv then BLACK else WHITE
			gl.lbl.TextStrokeColor3 = if inv then WHITE else BLACK
		end
		-- pointer glitch-jumps between the player and empty spots
		if t >= nextPtr then
			nextPtr = t + 0.8 + rng:NextNumber() * 1.2
			ptrFrom = ptrAt
			ptrT = t
			if rng:NextNumber() < 0.4 then
				ptrAt = V(0, c.topY + 0.6, 0)
			else
				local a = rng:NextNumber() * TAU
				local r = 2.5 + rng:NextNumber() * 3
				ptrAt = V(math.cos(a) * r, g + 0.5 + rng:NextNumber() * 3, math.sin(a) * r)
			end
		end
		local f = smooth01((t - ptrT) / 0.12)
		local tip = ptrFrom:Lerp(ptrAt, f) + V(0, 0.3 + Core.pulse(t, 0.8) * 0.4, 0)
		local up = CF(tip) * ANG(0, t * 0.8, 0) -- tip at origin, arrow points down
		Core.put(arrow[1], root * up * CF(0, 1.4, 0))
		Core.put(arrow[2], root * up * ANG(0, 0, 0.6) * CF(0, 0.6, 0))
		Core.put(arrow[3], root * up * ANG(0, 0, -0.6) * CF(0, 0.6, 0))
		local off = rng:NextNumber() < 0.03
		for _, p in arrow do
			p.Transparency = if off then 1 else 0
		end
		light.Brightness = if off then 0.2 else 1.8 + Core.pulse(t, 1.6) * 0.8
	end)
end

---------------------------------------------------------------- SINGULARITY

-- white core star, galaxy spiral, gravitational rings, light beams
-- parts ~86, emitters 7
A.Singularity = function(c: Ctx)
	local yS = c.topY + 4
	local SP = V(0, yS, 0)
	local star = Core.part(c, V(2.2, 2.2, 2.2), WHITE, NEON, 0, BALL)
	local shellA = Core.part(c, V(3.2, 3.2, 3.2), c.c2, FF, 0, BALL)
	local shellB = Core.part(c, V(4.4, 4.4, 4.4), WHITE, NEON, 0.86, BALL)
	local spikes: { BasePart } = {}
	for i = 1, 4 do
		spikes[i] = Core.part(c, V(if i <= 2 then 16 else 9, 0.14, 0.04), WHITE, NEON, 0.1)
	end
	local function collapse(t: number): number
		local ph = t % 7
		if ph > 6.3 then
			return 1 - smooth01((ph - 6.3) / 0.7) * 0.85
		end
		return 1
	end
	-- galaxy spiral around the waist
	local NS = 16
	type Star = { p: BasePart, th: number, r: number }
	local arms: { { Star } } = {}
	local armPolys: { B.Poly } = {}
	for arm = 1, 2 do
		local list = {}
		for j = 1, NS do
			local s = 0.62 - j * 0.026
			list[j] = {
				p = Core.part(c, V(s, s, s), WHITE:Lerp(c.c2, j / NS), NEON, 0, BALL),
				th = j * 0.42 + (arm - 1) * math.pi,
				r = 1.6 + j * 0.52,
			}
		end
		arms[arm] = list
		local pts = {}
		for j = 1, NS, 2 do
			table.insert(pts, V(j * 0.1, -0.2, 0))
		end
		armPolys[arm] = B.poly(c, pts, c.c2, 0.24, { w1 = 0.1, tr = ns(0.35), segs = 4 })
	end
	-- gravitational rings
	for k = 1, 3 do
		local r0 = 3.8 + k * 2.2
		B.circle(c, {
			radius = r0,
			color = if k == 2 then WHITE else c.c2,
			width = 0.16,
			n = 10,
			tr = 0.1,
			anchor = function(t)
				return CF(0, c.chestY + 0.5, 0)
					* ANG(math.sin(t * 0.3 + k) * 0.3, t * 0.1 * k, math.cos(t * 0.27 + k) * 0.3)
			end,
			radiusFn = function(t)
				return (r0 + math.sin(t * 2 - k) * 0.3) * collapse(t)
			end,
		})
	end
	B.ring(c, {
		n = 20,
		radius = 3,
		seg = V(0.14, 0.18, 0),
		color = WHITE,
		color2 = c.c2,
		spin = 1.8,
		anchor = function(t)
			return CF(SP) * ANG(0.5, t * 0.2, 0.2)
		end,
		radiusFn = function(t)
			return 3 * collapse(t)
		end,
	})
	B.ring(c, {
		n = 30,
		gap = 3,
		radius = 11,
		seg = V(0.22, 0.09, 0),
		color = c.c2,
		spin = -0.25,
		anchor = function()
			return CF(0, c.groundY + 0.05, 0)
		end,
	})
	B.sigil(c, { radius = 13, color = WHITE, color2 = c.c2, rings = 4, spokes = 12, glow = 0.9, spin = 0.12, pulse = 3.5 })
	B.orbiters(c, {
		n = 4,
		radius = 7.5,
		y = c.chestY + 1,
		color = WHITE,
		color2 = c.c2,
		size = 0.7,
		speed = 0.7,
		tilt = ANG(0.4, 0, -0.2),
		bob = 0.6,
		trail = 0.8,
		life = 0.9,
	})
	-- god beams into the sky + the main light pillar
	local starAtt = Core.att(c, nil, CF(SP))
	local tops: { Attachment } = {}
	for k = 1, 6 do
		tops[k] = Core.att(c)
		Core.beam(c, starAtt, tops[k], WHITE, 1.2, { w1 = 7, color2 = c.c2, tr = ns(0.25, 1), segs = 2 })
	end
	B.pillar(c, { color = WHITE, color2 = c.c2, height = 130, width = 5, tr = 0.3, streams = 4, radius = 2.2 })
	local floorAtt = Core.att(c, nil, CF(0, c.groundY + 0.05, 0))
	Core.beam(c, starAtt, floorAtt, WHITE, 1, { w1 = 6, color2 = c.c2, tr = ns(0.5, 0.9), segs = 2 })
	Core.emit(starAtt, {
		tex = T.vortex,
		color = cs(c.c2, WHITE),
		size = ns(7, 11),
		transp = ns(0.35, 1),
		rate = 2,
		life = nr(1, 1),
		rotSpeed = nr(90, 140),
		locked = true,
	})
	Core.emit(starAtt, {
		tex = T.glow,
		color = cs(WHITE),
		size = ns(9, 11),
		transp = ns(0.55, 1),
		rate = 3,
		life = nr(0.6, 0.8),
		locked = true,
	})
	local burst = Core.emit(starAtt, {
		tex = T.spark,
		color = cs(WHITE, c.c2),
		size = ns(1, 0),
		rate = 0,
		life = nr(1, 1.8),
		speed = nr(16, 28),
		spread = V2(180, 180),
		drag = 2,
		bright = 3,
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(WHITE, c.c2),
		size = ns(0, 0.55, 0),
		rate = 20,
		life = nr(1, 1.8),
		speed = nr(2, 5),
		spread = V2(180, 180),
	})
	Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.1, 0)), {
		tex = T.shock,
		color = cs(c.c2, WHITE),
		size = ns(2, 20),
		transp = ns(0.35, 1),
		rate = 0.5,
		life = nr(1.8, 1.8),
		speed = nr(0.01, 0.01),
		orient = PERP,
	})
	B.floorEmit(c, 9, {
		tex = T.glow,
		color = cs(WHITE, c.c2),
		size = ns(0, 0.8, 0),
		transp = ns(0.1, 1),
		rate = 30,
		life = nr(2, 3.5),
		speed = nr(2, 4),
	})
	local sky = Core.volume(c, V(16, 1, 16), CF(0, yS + 10, 0))
	Core.emit(sky, {
		tex = T.spark,
		color = cs(WHITE, c.c2),
		size = ns(0, 0.6, 0),
		rate = 24,
		life = nr(3, 4),
		speed = nr(2, 3),
		dir = Enum.NormalId.Bottom,
		shape = BOX,
	})
	local sl = Core.light(starAtt, WHITE, 5, 26)
	B.rootLight(c, c.c2, 3, 20, { pulse = 1.3, amp = 1.2 })
	local lastPh = 0
	Core.on(c, function(t, _, root)
		local col = collapse(t)
		local ph = t % 7
		if ph < lastPh then
			burst:Emit(80)
		end
		lastPh = ph
		local scf = root * CF(SP)
		Core.put(star, scf)
		local sa = 3.2 + Core.pulse(t, 1.3) * 0.5
		shellA.Size = V(sa, sa, sa)
		Core.put(shellA, scf)
		local sb = 4.4 * (0.9 + Core.pulse(t, 2.1) * 0.25) * col
		shellB.Size = V(sb, sb, sb)
		Core.put(shellB, scf)
		local look = CFrame.lookAt(scf.Position, camPos())
		for i, s in spikes do
			Core.put(s, look * ANG(0, 0, (i - 1) * math.pi / 4 + t * 0.2 * (if i % 2 == 0 then 1 else -1)))
		end
		local gl = CF(0, -0.2, 0) * ANG(0, t * 0.5, 0)
		local gbase = root * gl
		for arm, list in arms do
			local poly = armPolys[arm]
			local ai = 0
			for j, st in list do
				local r = st.r * col
				local lp = V(math.cos(st.th) * r, math.sin(st.th * 2 + t) * 0.15, math.sin(st.th) * r)
				Core.put(st.p, gbase * CF(lp))
				if j % 2 == 1 then
					ai += 1
					poly.atts[ai].Position = (gl * CF(lp)).Position
				end
			end
		end
		for k, a in tops do
			local ang = (k - 1) / 6 * TAU + t * 0.15
			a.Position = SP + V(math.cos(ang) * 12, 90, math.sin(ang) * 12)
		end
		sl.Brightness = if ph > 6.3 then 5 + (ph - 6.3) * 12 else 4.5 + Core.pulse(t, 1.3)
	end)
end

-- giant wireframe grid sphere, floating code pages, green god-rays
-- parts ~80, emitters 5
A.Architect = function(c: Ctx)
	local rng = c.rng
	local R = 8.5
	local S = V(0, c.groundY + R * 0.55, 0)
	local function meridian(k: number): (t: number) -> CFrame
		return function(t: number): CFrame
			return CF(S) * ANG(0, t * 0.15 + k * math.pi / 6, 0) * ANG(0, 0, math.pi / 2)
		end
	end
	for k = 0, 5 do
		B.circle(c, { radius = R, color = c.c1, width = 0.1, tr = 0.3, n = 10, anchor = meridian(k) })
	end
	local par = { -3.6, -1.8, 0, 2.4, 4.8, 6.9 }
	for _, y in par do
		B.circle(c, {
			radius = math.sqrt(R * R - y * y),
			color = c.c1,
			width = 0.09,
			tr = 0.35,
			n = 10,
			at = CF(S + V(0, y, 0)),
		})
	end
	local nodeY = { 2.4, -1.8 }
	local nodes: { BasePart } = {}
	for i = 1, 24 do
		nodes[i] = Core.part(c, V(0.34, 0.34, 0.34), WHITE:Lerp(c.c1, 0.3))
	end
	local codeLines = {
		"local world = {}",
		"for i = 1, inf do",
		"  world[i] = rand()",
		"end",
		"if luck > 1e9 then",
		"  return ARCHITECT",
		"-- TODO: fix reality",
		"error(404)",
		"while true do",
		"  render(world)",
	}
	type Page = { p: BasePart, bar: BasePart, a: number, r: number, y: number }
	local pages: { Page } = {}
	for i = 1, 8 do
		local p = Core.part(c, V(1.6, 2.1, 0.03), WHITE:Lerp(c.c1, 0.6), NEON, 0.5)
		local sg = Core.surface(p, Enum.NormalId.Front, 80)
		if i == 1 or i == 5 then
			Core.label(sg, "404", WHITE, F.tech, UDim2.fromScale(0.05, 0.25), UDim2.fromScale(0.9, 0.3))
			Core.label(sg, "PAGE NOT FOUND", c.c2, F.mono, UDim2.fromScale(0.05, 0.58), UDim2.fromScale(0.9, 0.1))
		else
			for j = 1, 8 do
				local line = codeLines[(i * 3 + j) % #codeLines + 1]
				Core.label(
					sg,
					line,
					Color3.fromRGB(10, 40, 25),
					F.mono,
					UDim2.fromScale(0.06, 0.06 + (j - 1) * 0.11),
					UDim2.fromScale(0.88, 0.09),
					Enum.TextXAlignment.Left
				)
			end
		end
		pages[i] = {
			p = p,
			bar = Core.part(c, V(1.6, 0.12, 0.05), c.c1),
			a = (i - 1) / 8 * TAU,
			r = 4.6 + (i % 2) * 1.1,
			y = c.chestY + 0.5 + ((i % 3) - 1) * 1.6,
		}
	end
	-- god-rays from the sky converging on the player
	local skyAtts: { Attachment } = {}
	local hit = Core.att(c, nil, CF(0, c.chestY, 0))
	for k = 1, 7 do
		skyAtts[k] = Core.att(c)
		Core.beam(c, skyAtts[k], hit, c.c1, 6, { w1 = 1.2, color2 = WHITE, tr = ns(0.9, 0.55), segs = 2 })
	end
	B.pillar(c, { color = c.c1, color2 = WHITE, height = 110, width = 3.6, tr = 0.45, streams = 3, radius = 1.8 })
	-- floor grid
	local g = c.groundY + 0.04
	local GR = 10
	for k = -4, 4 do
		local x = k * 2.4
		local half = math.sqrt(math.max(0, GR * GR - x * x))
		local a0 = Core.att(c, nil, CF(x, g, -half))
		local a1 = Core.att(c, nil, CF(x, g, half))
		Core.beam(c, a0, a1, c.c1, 0.07, { tr = ns(0.85, 0.3, 0.85), segs = 2 })
		local b0 = Core.att(c, nil, CF(-half, g, x))
		local b1 = Core.att(c, nil, CF(half, g, x))
		Core.beam(c, b0, b1, c.c1, 0.07, { tr = ns(0.85, 0.3, 0.85), segs = 2 })
	end
	B.ring(c, {
		n = 32,
		gap = 4,
		radius = GR,
		seg = V(0.18, 0.07, 0),
		color = c.c1,
		spin = 0.1,
		anchor = function()
			return CF(0, g + 0.01, 0)
		end,
	})
	B.sigil(c, { radius = GR + 1.2, color = c.c1, color2 = WHITE, rings = 2, glow = 0.92, pulse = 2 })
	-- voxels materialising: the world being written
	type Vox = { p: BasePart, pos: Vector3, t0: number, life: number, s: number }
	local voxels: { Vox } = {}
	for i = 1, 12 do
		voxels[i] = {
			p = Core.part(c, V(1, 1, 1), if i % 3 == 0 then WHITE else c.c1, NEON, 1),
			pos = Vector3.zero,
			t0 = os.clock() - i * 0.2,
			life = 0,
			s = 1,
		}
	end
	local cursor = Core.part(c, V(0.3, 0.55, 0.06), WHITE)
	local _, title = B.glyph(
		c,
		"404 // PAGE NOT FOUND",
		c.c1,
		V2(5.4, 0.6),
		F.tech,
		CF(0, c.topY + 2.3, 0),
		Color3.fromRGB(0, 40, 20)
	)
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0, 0.5, 0),
		rate = 20,
		life = nr(1.2, 2),
		speed = nr(2, 4),
		spread = V2(180, 180),
	})
	Core.emit(torso, {
		tex = T.glow,
		color = cs(c.c1),
		size = ns(6, 8),
		transp = ns(0.78, 1),
		rate = 3,
		life = nr(0.8, 1.2),
		locked = true,
	})
	B.floorEmit(c, 9, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.3, 0),
		transp = ns(0.1, 1),
		rate = 30,
		life = nr(1.6, 2.6),
		speed = nr(1.5, 3),
		rot = nr(0, 0),
	})
	Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.1, 0)), {
		tex = T.shock,
		color = cs(c.c1),
		size = ns(3, 22),
		transp = ns(0.45, 1),
		rate = 0.45,
		life = nr(2, 2),
		speed = nr(0.01, 0.01),
		orient = PERP,
	})
	local rain = Core.volume(c, V(18, 1, 18), CF(0, c.topY + 12, 0))
	Core.emit(rain, {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.22, 0.1),
		transp = ns(0.2, 0.6, 1),
		squash = ns(-2),
		rate = 40,
		life = nr(1.6, 2.2),
		speed = nr(7, 10),
		dir = Enum.NormalId.Bottom,
		rot = nr(0, 0),
		shape = BOX,
	})
	B.rootLight(c, c.c1, 3.2, 24, { pulse = 2, amp = 1.5 })
	Core.on(c, function(t, _, root)
		local rot = t * 0.15
		for i, n in nodes do
			local k = (i - 1) % 12
			local y = nodeY[if i <= 12 then 1 else 2]
			local rr = math.sqrt(R * R - y * y)
			local a = rot + k * math.pi / 6
			Core.put(n, root * CF(S + V(math.cos(a) * rr, y, -math.sin(a) * rr)) * ANG(t, t * 0.7, 0))
		end
		for i, pg in pages do
			local a = pg.a + t * 0.18
			local cf = root
				* outward(a, pg.r, pg.y + math.sin(t * 0.8 + i) * 0.35)
				* ANG(0, math.sin(t * 0.5 + i) * 0.5, math.sin(t * 0.6 + i) * 0.08)
			Core.put(pg.p, cf)
			Core.put(pg.bar, cf * CF(0, 1.1, 0))
		end
		for k, a in skyAtts do
			local ang = (k - 1) / 7 * TAU + t * 0.08
			a.Position = V(math.cos(ang) * 12, 70, math.sin(ang) * 12)
		end
		for _, v in voxels do
			local age = t - v.t0
			if age > v.life then
				v.t0 = t
				v.life = 1.2 + rng:NextNumber() * 0.8
				v.s = 0.5 + rng:NextNumber() * 0.8
				local a = rng:NextNumber() * TAU
				local r = 2.5 + rng:NextNumber() * 6.5
				v.pos = V(math.cos(a) * r, c.groundY + v.s / 2, math.sin(a) * r)
				age = 0
			end
			local f = age / math.max(v.life, 0.01)
			local grow = smooth01(f / 0.2)
			v.p.Size = V(v.s, v.s * grow, v.s)
			v.p.Transparency = 0.15 + 0.85 * smooth01((f - 0.6) / 0.4)
			Core.put(v.p, root * CF(v.pos + V(0, v.s * (grow - 1) / 2 + f * 0.6, 0)))
		end
		Core.put(cursor, root * CF(2.95, c.topY + 2.3, 0))
		cursor.Transparency = if (t % 1) < 0.5 then 0 else 1
		title.TextTransparency = if rng:NextNumber() < 0.03 then 0.7 else 0
	end)
end

-- black censor bars orbiting, red classified stamps, reality tearing
-- parts ~70, emitters 6
A.Redacted = function(c: Ctx)
	local rng = c.rng
	local red = c.c2
	local ink = Color3.fromRGB(4, 4, 4)
	type Bar = { p: BasePart, edge: BasePart, a: number, r: number, y: number, w: number, tilt: number }
	local bars: { Bar } = {}
	local function barY(): number
		return c.groundY + 0.6 + rng:NextNumber() * (c.topY - c.groundY + 3)
	end
	for i = 1, 14 do
		bars[i] = {
			p = Core.part(c, V(3.4, 0.55, 0.06), ink, SMOOTH),
			edge = Core.part(c, V(3.4, 0.07, 0.08), red),
			a = rng:NextNumber() * TAU,
			r = 3 + rng:NextNumber() * 4,
			y = barY(),
			w = (0.3 + rng:NextNumber() * 0.5) * (if i % 2 == 0 then 1 else -1),
			tilt = (rng:NextNumber() - 0.5) * 0.6,
		}
	end
	local hw = c.head.Size.X * 1.15
	local faceBar = Core.part(c, V(hw, 0.28, 0.06), ink, SMOOTH)
	local faceEdge = Core.part(c, V(hw, 0.03, 0.07), red)
	-- giant censor bar hanging in the sky, turned to the camera
	local skyBar = Core.part(c, V(9, 1.5, 0.12), ink, SMOOTH)
	local skyEdge = Core.part(c, V(9.3, 1.8, 0.08), red)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Core.surface(skyBar, face, 30)
		Core.label(sg, "[ REDACTED ]", red, F.tech, UDim2.fromScale(0.05, 0.15), UDim2.fromScale(0.9, 0.7))
	end
	type Stamp = { att: Attachment, gui: BillboardGui, lbl: TextLabel, stroke: UIStroke, t0: number }
	local stamps: { Stamp } = {}
	local words = { "CLASSIFIED", "[REDACTED]", "TOP SECRET", "EYES ONLY", "DENIED", "LEVEL 5" }
	local function relocate(s: Stamp, t: number)
		s.t0 = t
		local a = rng:NextNumber() * TAU
		local r = 3 + rng:NextNumber() * 1.5
		s.att.Position = V(math.cos(a) * r, c.chestY + (rng:NextNumber() - 0.3) * 3, math.sin(a) * r)
		s.lbl.Text = words[rng:NextInteger(1, #words)]
		s.lbl.Rotation = (rng:NextNumber() - 0.5) * 30
	end
	for i = 1, 4 do
		local att, lbl, gui = B.glyph(c, "CLASSIFIED", red, V2(3.2, 0.8), F.tech)
		lbl.TextStrokeTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = red
		stroke.Thickness = 4
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = lbl
		local s: Stamp = { att = att, gui = gui, lbl = lbl, stroke = stroke, t0 = 0 }
		relocate(s, os.clock() - i * 0.7)
		stamps[i] = s
	end
	-- reality tears: black core polyline over a wider red glowing edge
	type Tear = { core: B.Poly, edge: B.Poly, w: number, off: number, base: { Vector3 } }
	local tears: { Tear } = {}
	for k = 1, 8 do
		local giant = k >= 7
		local a = if giant then (k - 7) * math.pi else (k - 1) / 6 * TAU + math.pi / 6
		local r = if giant then 9.5 else 5.5 + rng:NextNumber() * 1.5
		local h = if giant then 34 else 4 + rng:NextNumber() * 2
		local y0 = c.groundY + (if giant then 0.1 else 0.4 + rng:NextNumber())
		local w = if giant then 1.1 else 0.45
		local pts = {}
		for j = 0, 6 do
			local sway = if j > 0 and j < 6 then (rng:NextNumber() - 0.5) * (if giant then 2 else 0.6) else 0
			table.insert(pts, V(math.cos(a) * r + sway, y0 + j / 6 * h, math.sin(a) * r + sway * 0.5))
		end
		tears[k] = {
			edge = B.poly(c, pts, red, w, { segs = 1, bright = 3 }),
			core = B.poly(c, pts, BLACK, w * 0.6, { segs = 1, light = 0, zoff = 0.05 }),
			w = w,
			off = rng:NextNumber() * 4,
			base = pts,
		}
	end
	type Cens = { att: Attachment, frames: { Frame }, a: number, y: number }
	local cens: { Cens } = {}
	for i = 1, 5 do
		local att = Core.att(c)
		local gui = Core.glyph(c, att, "", WHITE, V2(2.2, 0.9))
		local frames = {}
		for j = 1, 3 do
			local f = Core.frame(gui, ink, UDim2.fromScale(0, (j - 1) * 0.34), UDim2.fromScale(0.8, 0.24))
			local st = Instance.new("UIStroke")
			st.Color = red
			st.Thickness = 1.5
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Parent = f
			frames[j] = f
		end
		cens[i] = { att = att, frames = frames, a = (i - 1) / 5 * TAU, y = c.groundY + 1.2 + i * 0.9 }
	end
	local g = c.groundY
	local disc = Core.part(c, V(0.04, 16, 16), Color3.fromRGB(4, 2, 3), SMOOTH, 0, CYL)
	local stampFloor = Core.part(c, V(6, 0.02, 6), BLACK, SMOOTH, 1)
	local fsg = Core.surface(stampFloor, Enum.NormalId.Top, 40)
	local fl = Core.label(fsg, "[REDACTED]", red, F.tech, UDim2.fromScale(0, 0.4), UDim2.fromScale(1, 0.2))
	fl.TextTransparency = 0.2
	B.ring(c, {
		n = 28,
		gap = 5,
		radius = 8,
		seg = V(0.16, 0.07, 0),
		color = red,
		spin = 0.4,
		anchor = function()
			return CF(0, g + 0.06, 0)
		end,
	})
	B.sigil(c, { radius = 8.8, color = red, rings = 3, glow = nil, pulse = 1.1 })
	local ox, burstUntil = 0, 0
	B.clones(c, {
		set = "lite",
		color = BLACK,
		mat = NEON,
		tr = 0.45,
		scale = 1.02,
		map = function(cf, root)
			if ox == 0 then
				return cf
			end
			return root * CF(ox, 0, 0) * root:ToObjectSpace(cf)
		end,
	})
	local sky = Core.att(c, c.root, CF(0, c.topY + 8, 0))
	Core.emit(sky, {
		tex = T.square,
		color = cs(Color3.fromRGB(8, 8, 8)),
		size = ns(0.5, 0.3),
		rate = 22,
		life = nr(1.8, 2.6),
		speed = nr(3, 6),
		spread = V2(55, 55),
		dir = Enum.NormalId.Bottom,
		rotSpeed = nr(-200, 200),
		light = 0,
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.fireSpark,
		color = cs(red, WHITE),
		size = ns(0.4, 0),
		rate = 24,
		life = nr(0.6, 1.2),
		speed = nr(3, 7),
		spread = V2(180, 180),
		bright = 2.5,
	})
	Core.emit(torso, {
		tex = T.vortex,
		color = cs(red),
		size = ns(8, 12),
		transp = ns(0.72, 1),
		rate = 1.5,
		life = nr(1, 1.4),
		rotSpeed = nr(100, 160),
		locked = true,
	})
	B.floorEmit(c, 7, {
		tex = T.smoke,
		color = cs(BLACK),
		size = ns(3, 7),
		transp = ns(0.4, 1),
		rate = 8,
		life = nr(2, 3),
		speed = nr(0.5, 1.2),
		light = 0,
		rotSpeed = nr(-30, 30),
	})
	local glitchVol = Core.volume(c, V(12, 9, 12), CF(0, c.chestY + 1.5, 0))
	Core.emit(glitchVol, {
		tex = T.square,
		color = cs(red, WHITE),
		size = ns(0.45, 0.15),
		squash = ns(-0.8),
		transp = ns(0, 1),
		rate = 26,
		life = nr(0.12, 0.3),
		rot = nr(0, 0),
		shape = BOX,
	})
	local light = B.rootLight(c, red, 3, 22)
	local nextC = 0
	Core.on(c, function(t, _, root)
		if rng:NextNumber() < 0.02 then
			burstUntil = t + 0.12
		end
		ox = if t < burstUntil then (rng:NextNumber() - 0.5) * 0.8 else 0
		for i, b in bars do
			if rng:NextNumber() < 0.003 then
				b.y = barY()
			end
			local a = b.a + t * b.w
			local cf = root
				* outward(a, b.r, b.y + math.sin(t * 1.3 + i) * 0.25)
				* ANG(0, 0, b.tilt + math.sin(t * 0.7 + i) * 0.1)
			Core.put(b.p, cf)
			Core.put(b.edge, cf * CF(0, -0.31, 0))
		end
		local hcf = c.head.CFrame * CF(0, 0.1, -c.head.Size.Z / 2 - 0.04)
		Core.put(faceBar, hcf)
		Core.put(faceEdge, hcf * CF(0, -0.155, 0))
		local skyPos = (root * CF(0, c.topY + 5 + math.sin(t * 0.7) * 0.3, 0)).Position
		local cam = camPos()
		local flatCam = V(cam.X, skyPos.Y, cam.Z)
		local scf = if (flatCam - skyPos).Magnitude > 0.1 then CFrame.lookAt(skyPos, flatCam) else CF(skyPos)
		scf *= ANG(0, 0, math.sin(t * 0.9) * 0.06) * CF(jitter(rng, if t < burstUntil then 0.6 else 0))
		Core.put(skyBar, scf)
		Core.put(skyEdge, scf) -- thinner than the bar: only the rim shows, on both faces
		for _, s in stamps do
			local age = t - s.t0
			if age > 2.6 then
				relocate(s, t)
				age = 0
			end
			local sc = if age < 0.12 then 2.2 - age / 0.12 * 1.2 else 1
			local fade = math.clamp((age - 2.2) / 0.4, 0, 1)
			local appear = math.clamp(age / 0.12, 0, 1)
			s.gui.Size = UDim2.new(3.2 * sc, 0, 0.8 * sc, 0)
			local tr = math.max(1 - appear, fade)
			s.lbl.TextTransparency = tr
			s.stroke.Transparency = tr
		end
		for _, tr in tears do
			local ph = ((t + tr.off) % 4) / 4
			local open = math.sin(math.clamp(ph / 0.7, 0, 1) * math.pi)
			if ph > 0.95 and rng:NextNumber() < 0.2 then
				for j = 2, #tr.base - 1 do
					local jit = V((rng:NextNumber() - 0.5) * 0.7, 0, (rng:NextNumber() - 0.5) * 0.7)
					tr.core.atts[j].Position = tr.base[j] + jit
					tr.edge.atts[j].Position = tr.base[j] + jit
				end
			end
			for j, bm in tr.core.beams do
				local env = math.sin((j - 0.5) / #tr.core.beams * math.pi)
				local wc = tr.w * 0.6 * open * env
				bm.Width0 = wc
				bm.Width1 = wc
				local eb = tr.edge.beams[j]
				eb.Width0 = (wc + tr.w * 0.35) * (if open > 0.02 then 1 else 0)
				eb.Width1 = eb.Width0
			end
		end
		if t >= nextC then
			nextC = t + 0.18
			for _, ce in cens do
				for _, f in ce.frames do
					if rng:NextNumber() < 0.4 then
						f.Size = UDim2.fromScale(0.3 + rng:NextNumber() * 0.7, 0.24)
					end
				end
			end
		end
		for i, ce in cens do
			local a = ce.a - t * 0.35
			ce.att.Position = V(math.cos(a) * 4.2, ce.y + math.sin(t + i) * 0.2, math.sin(a) * 4.2)
		end
		Core.put(disc, root * CF(0, g + 0.02, 0) * FLAT)
		Core.put(stampFloor, root * CF(0, g + 0.06, 0) * ANG(0, t * 0.2, 0))
		light.Brightness = if t < burstUntil then 7 else 2.6 + math.noise(t * 3, 2) * 1.4
	end)
end

return A
