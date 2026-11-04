--!strict
-- AuraFX/AurasHigh: LEGENDARY, MYTHIC, CORRUPTED and SINGULARITY tier auras.

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

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

local function outward(a: number, r: number, y: number): CFrame
	return ANG(0, -a, 0) * CF(r, y, 0) * ANG(0, -math.pi / 2, 0)
end

local function smooth01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local A: { [string]: (Ctx) -> () } = {}

---------------------------------------------------------------- LEGENDARY

-- server-rack panels with blinking LEDs orbiting, cable beams
A.Mainframe = function(c: Ctx)
	local rng = c.rng
	local shell = Color3.fromRGB(10, 16, 26)
	local ledCols = { c.c1, Color3.fromRGB(80, 255, 140), Color3.fromRGB(255, 176, 32), Color3.fromRGB(20, 30, 40) }
	type Rack = {
		body: BasePart,
		bars: { BasePart },
		leds: { BasePart },
		status: BasePart,
		a0: Attachment,
		a0n: Attachment,
		pulse: BasePart,
	}
	local hubLocal = CF(0, c.chestY + 0.1, 0.75)
	local hubAtt = Core.att(c, nil, CFrame.fromMatrix(hubLocal.Position, Vector3.yAxis, Vector3.xAxis))
	local racks: { Rack } = {}
	for i = 1, 4 do
		local body = Core.part(c, V(0.9, 1.6, 0.5), shell, SMOOTH)
		local sg = Core.surface(body, Enum.NormalId.Front, 100)
		local tag = Core.label(
			sg,
			string.format("SRV-%02d", i),
			c.c1,
			F.mono,
			UDim2.fromScale(0.08, 0.88),
			UDim2.fromScale(0.5, 0.09),
			Enum.TextXAlignment.Left
		)
		tag.TextTransparency = 0.2
		local leds = {}
		for k = 1, 4 do
			leds[k] = Core.part(c, V(0.6, 0.05, 0.03), c.c1)
		end
		local a0 = Core.att(c)
		local a0n = Core.att(c)
		local r: Rack = {
			body = body,
			bars = { Core.part(c, V(0.92, 0.05, 0.06), c.c1), Core.part(c, V(0.92, 0.05, 0.06), c.c1) },
			leds = leds,
			status = Core.part(c, V(0.07, 0.07, 0.04), c.c1),
			a0 = a0,
			a0n = a0n,
			pulse = Core.part(c, V(0.14, 0.14, 0.14), WHITE, NEON, 0, BALL),
		}
		Core.beam(
			c,
			a0,
			hubAtt,
			Color3.fromRGB(16, 22, 30),
			0.11,
			{ light = 0, bright = 1, c0 = 0.9, c1 = 0.9, segs = 16 }
		)
		Core.beam(
			c,
			a0n,
			hubAtt,
			c.c1,
			0.035,
			{ c0 = 0.9, c1 = 0.9, segs = 16, tex = T.square, texLen = 0.3, texSpeed = 2, zoff = 0.02 }
		)
		racks[i] = r
	end
	local hub = Core.part(c, V(0.7, 0.5, 0.25), Color3.fromRGB(20, 26, 36), METAL)
	local hubStrip = Core.part(c, V(0.6, 0.05, 0.27), c.c1)
	B.circle(c, { radius = 2.6, color = c.c1, width = 0.05, at = CF(0, c.groundY + 0.03, 0), tr = 0.4 })
	B.circle(c, { radius = 1.5, color = c.c2:Lerp(c.c1, 0.4), width = 0.04, at = CF(0, c.groundY + 0.03, 0), tr = 0.4 })
	local _, title = B.glyph(c, "MAINFRAME://ONLINE", c.c1, V2(2.6, 0.3), F.tech, CF(0, c.topY + 0.75, 0), c.c2)
	local back = Core.att(c, c.torso, CF(0, 0.1, c.torso.Size.Z / 2 + 0.2))
	Core.emit(back, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0.18, 0),
		rate = 6,
		life = nr(0.3, 0.6),
		speed = nr(2, 4),
		spread = V2(60, 60),
		dir = Enum.NormalId.Back,
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.square,
		color = cs(c.c1),
		size = ns(0.07, 0),
		rate = 8,
		life = nr(1.2, 2),
		speed = nr(0.6, 1.2),
		spread = V2(180, 180),
		rot = nr(0, 0),
	})
	local light = Core.light(back, c.c1, 1.6, 12)
	local nextLed = 0
	local ledOff = { -0.5, -0.17, 0.17, 0.5 }
	Core.on(c, function(t, _, root)
		local blink = t >= nextLed
		if blink then
			nextLed = t + 0.1
		end
		local hubWorld = c.torso.CFrame * CF(0, 0.1, c.torso.Size.Z / 2 + 0.13)
		Core.put(hub, hubWorld)
		Core.put(hubStrip, hubWorld)
		local hubL = root:ToObjectSpace(hubWorld)
		hubAtt.CFrame = CFrame.fromMatrix(hubL.Position, Vector3.yAxis, Vector3.xAxis)
		for i, r in racks do
			local a = (i - 1) / 4 * TAU + t * 0.35
			local cfL = outward(a, 2.6, c.chestY - 0.1 + math.sin(t * 0.9 + i) * 0.12)
			local cf = root * cfL
			Core.put(r.body, cf)
			Core.put(r.bars[1], cf * CF(0, 0.78, -0.24))
			Core.put(r.bars[2], cf * CF(0, -0.78, -0.24))
			for k, led in r.leds do
				Core.put(led, cf * CF(-0.06, ledOff[k], -0.26))
				if blink and rng:NextNumber() < 0.3 then
					led.Color = ledCols[rng:NextInteger(1, #ledCols)]
				end
			end
			Core.put(r.status, cf * CF(0.36, 0.62, -0.26))
			r.status.Transparency = if math.sin(t * 6 + i) > 0 then 0 else 0.8
			local backL = (cfL * CF(0, -0.3, 0.26)).Position
			local m = CFrame.fromMatrix(backL, -Vector3.yAxis, Vector3.xAxis)
			r.a0.CFrame = m
			r.a0n.CFrame = m
			-- data pulse riding the cable towards the hub
			local s = (t * 0.7 + i / 4) % 1
			local p = B.bez(backL, backL - V(0, 0.9, 0), hubL.Position - V(0, 0.9, 0), hubL.Position, s)
			Core.put(r.pulse, root * CF(p))
			r.pulse.Transparency = 1 - math.sin(s * math.pi)
		end
		title.Text = if (t % 1) < 0.5 then "MAINFRAME://ONLINE_" else "MAINFRAME://ONLINE"
		light.Brightness = 1.3 + Core.pulse(t, 1.6) * 0.8
	end)
end

-- electron orbit rings and superposition ghosts phasing
A.Quantum = function(c: Ctx)
	local function orbit(k: number): (t: number) -> CFrame
		return function(t: number): CFrame
			return CF(0, c.chestY, 0) * ANG(0, t * 0.25 + k * TAU / 3, 0) * ANG(1.1, 0, 0)
		end
	end
	type El = { core: BasePart, shell: BasePart, k: number }
	local els: { El } = {}
	for k = 1, 3 do
		B.circle(
			c,
			{ radius = 2.3, color = if k == 2 then c.c2 else c.c1, width = 0.05, tr = 0.2, anchor = orbit(k), n = 8 }
		)
		local core = Core.part(c, V(0.26, 0.26, 0.26), WHITE, NEON, 0, BALL)
		Core.trail(core, c.c1, 0.2, 0.35, c.c2)
		els[k] = { core = core, shell = Core.part(c, V(0.52, 0.52, 0.52), c.c1, FF, 0, BALL), k = k }
	end
	local side = 1
	local ga = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = FF,
		map = function(cf, root, t)
			return root * CF(1.5 * side + math.sin(t * 31) * 0.03, 0, 0) * root:ToObjectSpace(cf)
		end,
	})
	local gb = B.clones(c, {
		set = "lite",
		color = c.c2,
		mat = NEON,
		tr = 0.8,
		map = function(cf, root, t)
			return root * CF(-1.5 * side + math.sin(t * 27) * 0.03, 0, 0) * root:ToObjectSpace(cf)
		end,
	})
	local yA = c.topY + 0.95
	local nucleus = Core.part(c, V(0.3, 0.3, 0.3), c.c1, NEON, 0, BALL)
	for k = 1, 3 do
		B.circle(c, {
			radius = 0.45,
			color = c.c2,
			width = 0.025,
			n = 4,
			anchor = function(t)
				return CF(0, yA, 0) * ANG(0, t * 0.8 + k * TAU / 3, 0) * ANG(1.1, 0, 0)
			end,
		})
	end
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.glow,
		color = cs(c.c1, c.c2),
		size = ns(2, 3.2),
		transp = ns(0.85, 1),
		rate = 4,
		life = nr(1.2, 1.8),
		speed = nr(0.2, 0.5),
		spread = V2(180, 180),
	})
	Core.emit(torso, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0, 0.22, 0),
		rate = 8,
		life = nr(0.8, 1.4),
		speed = nr(1.5, 3),
		spread = V2(180, 180),
		drag = 2,
	})
	local light = Core.light(torso, c.c1, 1.8, 12)
	Core.on(c, function(t, _, root)
		side = if (t % 7.4) < 3.7 then 1 else -1
		for _, e in els do
			local th = t * 3.2 + e.k * 2
			local cf = root * orbit(e.k)(t) * CF(math.cos(th) * 2.3, 0, math.sin(th) * 2.3)
			Core.put(e.core, cf)
			Core.put(e.shell, cf)
		end
		local w = 0.5 + 0.5 * math.sin(t * 2)
		for _, p in ga do
			p.Transparency = w * 0.9
		end
		for _, p in gb do
			p.Transparency = 0.75 + (1 - w) * 0.25
		end
		Core.put(nucleus, root * CF(0, yA, 0))
		light.Brightness = 1.4 + w * 1.2
	end)
end

-- orange heat haze, lightning arcs, fan-blade halo spinning fast
A.Overclocked = function(c: Ctx)
	local rng = c.rng
	local fanL = CF(0, c.chestY + 0.55, 0.95)
	B.ring(c, {
		n = 14,
		radius = 0.98,
		seg = V(0.1, 0.09, 0),
		color = c.c1,
		color2 = Color3.fromRGB(110, 45, 0),
		spin = 0.4,
		anchor = function()
			return fanL * ANG(math.pi / 2, 0, 0)
		end,
	})
	local blades: { BasePart } = {}
	for i = 1, 7 do
		blades[i] = Core.part(c, V(0.3, 0.78, 0.035), c.c1, NEON, 0.1)
	end
	local hubP = Core.part(c, V(0.14, 0.32, 0.32), c.c2, NEON, 0, CYL)
	local blur = Core.part(c, V(0.02, 1.85, 1.85), c.c1, NEON, 0.86, CYL)
	for _ = 1, 3 do
		B.bolt(c, {
			segs = 6,
			color = c.c2,
			color2 = c.c1,
			width = 0.08,
			jitter = 0.3,
			interval = 0.05,
			flicker = 0.25,
			ends = function()
				local function sp(): Vector3
					local u = rng:NextUnitVector()
					return V(u.X * 1.2, c.chestY + u.Y * 1.3, u.Z * 0.9)
				end
				return sp(), sp()
			end,
		})
	end
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.smoke,
		color = cs(c.c1, c.c2),
		size = ns(1, 2.6),
		transp = ns(0.88, 1),
		rate = 6,
		life = nr(1, 1.6),
		speed = nr(1, 2),
		spread = V2(30, 30),
		rotSpeed = nr(-50, 50),
		light = 0.4,
	})
	local sx = c.torso.Size.X * 0.42
	local sy = c.torso.Size.Y * 0.45
	local vent: Core.EmitSpec = {
		tex = T.fire,
		color = cs(c.c2, c.c1),
		size = ns(0.35, 0.1),
		transp = ns(0.3, 1),
		rate = 18,
		life = nr(0.25, 0.4),
		speed = nr(2.5, 3.5),
		spread = V2(10, 10),
		dir = Enum.NormalId.Back,
	}
	Core.emit(Core.att(c, c.torso, CF(sx, sy, 0.4)), vent)
	Core.emit(Core.att(c, c.torso, CF(-sx, sy, 0.4)), vent)
	Core.emit(torso, {
		tex = T.fireSpark,
		color = cs(c.c2, c.c1),
		size = ns(0.15, 0),
		rate = 12,
		life = nr(0.5, 1),
		speed = nr(2, 4),
		spread = V2(180, 180),
		accel = V(0, 3, 0),
		bright = 2.5,
	})
	local _, temp =
		B.glyph(c, "TEMP 97C", c.c2, V2(1.6, 0.28), F.pixel, CF(0, c.topY + 0.7, 0), Color3.fromRGB(80, 20, 0))
	local light = Core.light(torso, c.c1, 2, 12)
	Core.on(c, function(t, _, root)
		local fan = root * fanL
		local rot = t * 26
		for i, b in blades do
			Core.put(b, fan * ANG(0, 0, rot + (i - 1) / 7 * TAU) * CF(0, 0.5, 0) * ANG(0, 0.5, 0))
		end
		Core.put(hubP, fan * AXIS_Z)
		Core.put(blur, fan * AXIS_Z * CF(0.02, 0, 0))
		local deg = 95 + math.noise(t * 0.8, 4) * 26
		if deg > 103 then
			temp.Text = if math.sin(t * 20) > 0 then "THROTTLING!" else string.format("TEMP %dC", math.floor(deg))
			temp.TextColor3 = Color3.fromRGB(255, 40, 30)
		else
			temp.Text = string.format("TEMP %dC", math.floor(deg))
			temp.TextColor3 = c.c2
		end
		light.Brightness = 1.6 + rng:NextNumber() * 1.4
	end)
end

-- glowing neuron web around the head with synapse sparks
A.NeuralLink = function(c: Ctx)
	local rng = c.rng
	local N = 12
	local dirs: { Vector3 } = {}
	for i = 1, N do
		local y = -0.35 + (i - 0.5) / N * 1.3
		local r = math.sqrt(math.max(0, 1 - y * y))
		local a = i * 2.39996
		dirs[i] = V(math.cos(a) * r, y, math.sin(a) * r)
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
		nodes[i] = Core.part(c, V(0.17, 0.17, 0.17), c.c1, NEON, 0, BALL)
		atts[i] = Core.att(c)
		flash[i] = 0
	end
	for _, l in links do
		Core.beam(c, atts[l[1]], atts[l[2]], c.c1, 0.035, { color2 = c.c2, tr = ns(0.35) })
	end
	local spineAtt = Core.att(c, c.torso, CF(0, c.torso.Size.Y * 0.35, c.torso.Size.Z / 2 + 0.05))
	for _, i in { 1, 2, 3 } do
		Core.beam(
			c,
			atts[i],
			spineAtt,
			c.c2,
			0.05,
			{ w1 = 0.02, tex = T.square, texLen = 0.25, texSpeed = 3, tr = ns(0.2, 0.5) }
		)
	end
	type Syn = { p: BasePart, link: number, from: number, to: number, t0: number }
	local syns: { Syn } = {}
	for i = 1, 6 do
		local l = links[rng:NextInteger(1, #links)]
		syns[i] =
			{ p = Core.part(c, V(0.1, 0.1, 0.1), WHITE), link = 1, from = l[1], to = l[2], t0 = os.clock() - i * 0.06 }
	end
	B.ring(c, {
		n = 16,
		gap = 4,
		radius = 0.85,
		seg = V(0.05, 0.07, 0),
		color = c.c2,
		spin = 0.8,
		anchor = function()
			return CF(0, c.headY + 0.05, 0) * ANG(0.12, 0, 0)
		end,
	})
	local headAtt = Core.att(c, c.head)
	Core.emit(headAtt, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0, 0.22, 0),
		rate = 8,
		life = nr(0.7, 1.2),
		speed = nr(0.5, 1),
		spread = V2(180, 180),
	})
	local synE = Core.emit(headAtt, {
		tex = T.spark,
		color = cs(c.c2),
		size = ns(0.3, 0),
		rate = 0,
		life = nr(0.2, 0.35),
		speed = nr(2, 3),
		spread = V2(180, 180),
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.glow,
		color = cs(c.c1),
		size = ns(1.6, 2.4),
		transp = ns(0.88, 1),
		rate = 3,
		life = nr(1, 1.5),
		spread = V2(180, 180),
		speed = nr(0.2, 0.4),
	})
	local light = Core.light(headAtt, c.c1, 1.6, 11)
	local pos: { Vector3 } = table.create(N, Vector3.zero)
	Core.on(c, function(t, _, root)
		local rot = ANG(0, t * 0.3, 0)
		local r = 1.25 + math.sin(t * 1.2) * 0.05
		local hc = V(0, c.headY + 0.15, 0)
		for i = 1, N do
			local p = hc + rot:VectorToWorldSpace(dirs[i]) * r
			pos[i] = p
			atts[i].Position = p
			Core.put(nodes[i], root * CF(p))
			local f = math.max(0, 1 - (t - flash[i]) / 0.25)
			nodes[i].Color = c.c1:Lerp(WHITE, f)
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
					synE:Emit(3)
				end
			end
			Core.put(s.p, root * CF(pos[s.from]:Lerp(pos[s.to], f)))
		end
		light.Brightness = 1.3 + Core.pulse(t, 1.1) * 0.9
	end)
end

-- hexagon shield plates orbiting, golden eye above
A.Sentinel = function(c: Ctx)
	local gold = c.c1
	type Plate = { inner: { BasePart }, rim: { BasePart }, emblem: BasePart }
	local plates: { Plate } = {}
	for i = 1, 6 do
		plates[i] = {
			inner = B.hex(c, 0.5, 0.06, Color3.fromRGB(10, 22, 38), SMOOTH),
			rim = B.hex(c, 0.6, 0.04, gold),
			emblem = Core.part(c, V(0.14, 0.08, 0.14), c.c2),
		}
	end
	local wall = {
		CF(-0.9, 0.45, 0),
		CF(0, 0.45, 0),
		CF(0.9, 0.45, 0),
		CF(-0.45, -0.35, 0),
		CF(0.45, -0.35, 0),
		CF(0, 1.25, 0),
	}
	local yE = c.topY + 1.45
	local sclera, mesh = Core.ellipsoid(c, V(1.3, 0.62, 0.25), gold, NEON)
	local iris = Core.part(c, V(0.04, 0.42, 0.42), c.c2, NEON, 0, CYL)
	local pupil = Core.part(c, V(0.05, 0.2, 0.2), BLACK, SMOOTH, 0, CYL)
	local eyeAtt = Core.att(c, nil, CF(0, yE, 0))
	for k = 1, 6 do
		local a = (k - 1) / 6 * TAU
		local tgt = Core.att(c, nil, CF(math.cos(a) * 1.5, c.chestY + 0.4, math.sin(a) * 1.5))
		Core.beam(c, eyeAtt, tgt, gold, 0.06, { w1 = 0.4, tr = ns(0.6, 0.97), segs = 2 })
	end
	B.circle(c, { radius = 0.85, color = gold, width = 0.04, tr = 0.4, at = CF(0, yE - 0.55, 0) })
	Core.emit(eyeAtt, {
		tex = T.spark,
		color = cs(gold, WHITE),
		size = ns(0, 0.25, 0),
		rate = 6,
		life = nr(0.8, 1.4),
		speed = nr(0.4, 1),
		spread = V2(180, 180),
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(c.c2),
		size = ns(0.2, 0),
		rate = 5,
		life = nr(0.6, 1),
		speed = nr(1.5, 3),
		spread = V2(180, 180),
	})
	Core.light(eyeAtt, gold, 2.4, 12)
	Core.light(Core.att(c, c.torso), c.c2, 0.9, 9)
	local nextBlink = 0
	Core.on(c, function(t, _, root)
		local cyc = t % 7
		local w = smooth01((cyc - 5) / 0.4) * (1 - smooth01((cyc - 6.4) / 0.4))
		for i, p in plates do
			local a = (i - 1) / 6 * TAU + t * 0.6
			local orbitCF = outward(a, 2.3, c.chestY + math.sin(t + i) * 0.3)
			local wallCF = CF(0, c.chestY, -1.9) * wall[i]
			local cf = root * orbitCF:Lerp(wallCF, w) * ANG(math.pi / 2, 0, 0) * ANG(0, t * 0.5 * (1 - w), 0)
			B.putHex(p.inner, cf)
			B.putHex(p.rim, cf * CF(0, 0.03, 0))
			Core.put(p.emblem, cf * CF(0, -0.05, 0) * ANG(0, math.pi / 4, 0))
		end
		local eyePos = (root * CF(0, yE + math.sin(t * 1.3) * 0.1, 0)).Position
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
		Core.put(iris, look * CF(0, 0, -0.11) * AXIS_Z)
		Core.put(pupil, look * CF(0, 0, -0.135) * AXIS_Z)
	end)
end

---------------------------------------------------------------- MYTHIC

-- concentric rings 0..3 around the body, core orb at chest
A.Kernel = function(c: Ctx)
	local function anchor(k: number): (t: number) -> CFrame
		return function(t: number): CFrame
			return CF(0, c.chestY, 0)
				* ANG(
					math.sin(t * 0.4 + k) * 0.6,
					t * (0.3 + k * 0.1) * (if k % 2 == 0 then 1 else -1),
					math.cos(t * 0.5 + k * 1.3) * 0.5
				)
		end
	end
	local spins = { 1.6, -1.3, 1.0, -0.7 }
	local counts = { 8, 10, 12, 14 }
	local coreL = V(0, c.chestY, -0.85)
	local coreAtt = Core.att(c, nil, CF(coreL))
	local labels: { Attachment } = {}
	for k = 0, 3 do
		local col = if k % 2 == 0 then c.c1 else c.c2
		B.ring(c, {
			n = counts[k + 1],
			radius = 1.4 + k * 0.5,
			seg = V(0.08, 0.12, 0),
			color = col,
			color2 = col:Lerp(WHITE, 0.35),
			spin = spins[k + 1],
			anchor = anchor(k),
		})
		local att, lbl = B.glyph(c, "RING " .. k, col, V2(0.95, 0.24), F.tech, nil, BLACK)
		lbl.TextStrokeTransparency = 0.3
		labels[k + 1] = att
		Core.beam(c, coreAtt, att, col, 0.03, { tr = ns(0.2, 0.7), tex = T.square, texLen = 0.4, texSpeed = 3 })
	end
	local core = Core.part(c, V(0.5, 0.5, 0.5), c.c1, NEON, 0.3, BALL)
	local inner = Core.part(c, V(0.24, 0.24, 0.24), WHITE, NEON, 0, BALL)
	local shell = Core.part(c, V(0.95, 0.95, 0.95), c.c2, FF, 0, BALL)
	B.ring(c, {
		n = 8,
		radius = 2.4,
		seg = V(0.3, 0.04, 0.12),
		color = c.c1,
		spin = 0.3,
		anchor = function()
			return CF(0, c.groundY + 0.04, 0)
		end,
	})
	B.circle(c, { radius = 2.2, color = c.c2, width = 0.05, at = CF(0, c.groundY + 0.03, 0), tr = 0.25 })
	B.circle(c, { radius = 2.65, color = c.c1, width = 0.04, at = CF(0, c.groundY + 0.03, 0), tr = 0.35 })
	Core.emit(coreAtt, {
		tex = T.glow,
		color = cs(c.c1, c.c2),
		size = ns(1.2, 2),
		transp = ns(0.4, 1),
		rate = 6,
		life = nr(0.4, 0.6),
		locked = true,
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.spark,
		color = cs(c.c1),
		size = ns(0.22, 0),
		rate = 7,
		life = nr(0.8, 1.3),
		speed = nr(1.5, 3),
		spread = V2(180, 180),
	})
	Core.emit(torso, {
		tex = T.spark,
		color = cs(c.c2),
		size = ns(0.22, 0),
		rate = 7,
		life = nr(0.8, 1.3),
		speed = nr(1.5, 3),
		spread = V2(180, 180),
	})
	local light = Core.light(coreAtt, c.c1, 2.6, 15)
	Core.on(c, function(t, _, root)
		for k = 0, 3 do
			local a = t * spins[k + 1] + k
			local r = 1.4 + k * 0.5
			labels[k + 1].Position = (anchor(k)(t) * CF(math.cos(a) * r, 0.3, math.sin(a) * r)).Position
		end
		local beat = Core.pulse(t, 1.2)
		local cf = root * CF(coreL)
		Core.put(core, cf)
		Core.put(inner, cf)
		local s = 0.9 + beat * 0.25
		shell.Size = V(s, s, s)
		Core.put(shell, cf)
		light.Brightness = 2 + beat * 1.6
	end)
end

-- body semi-transparent, white wisps, cloak of fading pixels
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
	local skin = B.clones(c, { set = "lite", color = c.c1, mat = FF, scale = 1.01 })
	local COLS, ROWS = 6, 6
	type Px = { p: BasePart, col: number, row: number, seed: number }
	local px: { Px } = {}
	for row = 0, ROWS - 1 do
		for col = 0, COLS - 1 do
			local p = Core.part(c, V(0.3, 0.3, 0.04), c.c1:Lerp(c.c2, row / (ROWS - 1)))
			table.insert(px, { p = p, col = col, row = row, seed = (col * 7 + row * 13) % 17 / 17 })
		end
	end
	local back = Core.att(c, c.torso, CF(0, -c.torso.Size.Y * 0.4, c.torso.Size.Z / 2 + 0.3))
	Core.emit(back, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.12, 0),
		transp = ns(0.1, 1),
		rate = 9,
		life = nr(1.2, 2),
		speed = nr(0.5, 1.2),
		spread = V2(40, 40),
		dir = Enum.NormalId.Back,
		accel = V(0, 0.8, 0),
		rot = nr(0, 0),
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.smoke,
		color = cs(WHITE, c.c1),
		size = ns(0.8, 2.2),
		transp = ns(0.82, 1),
		rate = 5,
		life = nr(1.5, 2.5),
		speed = nr(0.4, 1),
		spread = V2(180, 180),
		rotSpeed = nr(-40, 40),
		accel = V(0, 0.6, 0),
		light = 0.6,
	})
	Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.2, 0)), {
		tex = T.smoke,
		color = cs(WHITE),
		size = ns(1, 2.6),
		transp = ns(0.85, 1),
		rate = 3,
		life = nr(2, 3),
		speed = nr(0.6, 1.2),
		spread = V2(80, 80),
		light = 0.4,
	})
	local light = Core.light(torso, c.c1, 0.8, 9)
	local ts = c.torso.Size
	Core.on(c, function(t)
		local tcf = c.torso.CFrame
		local cloakOff = (t % 6) < 0.3
		for _, sp in skin do
			sp.Transparency = if cloakOff then 1 else 0
		end
		for _, q in px do
			local row, col = q.row, q.col
			local flare = row / (ROWS - 1)
			local x = (col - (COLS - 1) / 2) * 0.33 * (1 + flare * 0.35)
			local y = ts.Y / 2 - 0.15 - row * 0.33
			local z = ts.Z / 2 + 0.1 + flare * 0.35 + math.sin(t * 3 + row * 0.7 + col * 0.5) * 0.07 * flare
			local tr = math.clamp(math.noise(col * 0.7, row * 0.7, t * 0.8) * 1.2 + 0.15, 0, 0.7)
			local drift = Vector3.zero
			if row >= ROWS - 2 then
				local ph = (t * 0.35 + q.seed) % 1
				if ph > 0.55 then
					local f = (ph - 0.55) / 0.45
					drift = V(math.sin(q.seed * 20) * f * 0.6, f * 1.4, f * 2.4)
					tr = math.max(tr, f)
				end
			end
			q.p.Transparency = tr
			Core.put(q.p, tcf * CF(V(x, y, z) + drift) * ANG(-0.15 * flare, 0, 0))
		end
		light.Brightness = 0.6 + Core.pulse(t, 2.5) * 0.6
	end)
end

-- six neon wings, halo of code, feather pixels falling
A.CyberSeraph = function(c: Ctx)
	local rng = c.rng
	type WingSpec = { y: number, p0: number, p1: number, l0: number, l1: number, yaw: number, ph: number }
	local specs: { WingSpec } = {
		{ y = c.chestY + 0.55, p0 = 0.25, p1 = 1.1, l0 = 4.8, l1 = 2.9, yaw = 0.35, ph = 0 },
		{ y = c.chestY + 0.2, p0 = 1.05, p1 = 1.75, l0 = 3.9, l1 = 2.3, yaw = 0.45, ph = 0.5 },
		{ y = c.chestY - 0.15, p0 = 1.75, p1 = 2.35, l0 = 2.8, l1 = 1.6, yaw = 0.55, ph = 1 },
	}
	type Wing = { spec: WingSpec, s: number, bone: BasePart, feathers: { BasePart } }
	local wings: { Wing } = {}
	local NF = 5
	for _, sp in specs do
		for _, s in { 1, -1 } do
			local fs = {}
			for j = 1, NF do
				local L = sp.l0 + (sp.l1 - sp.l0) * (j - 1) / (NF - 1)
				fs[j] = Core.part(c, V(0.22, L, 0.05), WHITE:Lerp(c.c2, (j - 1) / NF), NEON, 0.05)
			end
			table.insert(
				wings,
				{ spec = sp, s = s, bone = Core.part(c, V(0.16, sp.l0 * 0.55, 0.08), c.c2), feathers = fs }
			)
		end
	end
	local yH = c.topY + 0.55
	B.ring(c, {
		n = 16,
		radius = 0.6,
		seg = V(0.05, 0.05, 0),
		color = WHITE,
		color2 = c.c2,
		spin = 0.6,
		anchor = function()
			return CF(0, yH, 0) * ANG(0.15, 0, 0)
		end,
	})
	B.circle(c, { radius = 0.6, color = c.c2, width = 0.04, tr = 0.2, at = CF(0, yH, 0) * ANG(0.15, 0, 0) })
	type Gl = { att: Attachment, lbl: TextLabel }
	local code: { Gl } = {}
	for i = 1, 8 do
		local att, lbl = B.glyph(c, "1", c.c2, V2(0.26, 0.26), F.pixel)
		code[i] = { att = att, lbl = lbl }
	end
	local sky = Core.att(c, nil, CF(0, c.topY + 9, 0))
	local haloAtt = Core.att(c, nil, CF(0, yH + 0.1, 0))
	Core.beam(c, sky, haloAtt, WHITE, 1.6, { w1 = 0.6, tr = ns(1, 0.8), color2 = c.c2, segs = 2 })
	local vol = Core.volume(c, V(3.2, 2, 0.6), CF(0, 0.3, 0.9), c.torso)
	Core.emit(vol, {
		tex = T.square,
		color = cs(WHITE, c.c2),
		size = ns(0.12, 0.1, 0),
		transp = ns(0, 0.2, 1),
		rate = 10,
		life = nr(2.5, 3.5),
		speed = nr(0.2, 0.5),
		accel = V(0, -1.1, 0),
		drag = 1,
		rotSpeed = nr(-90, 90),
		shape = Enum.ParticleEmitterShape.Box,
	})
	Core.emit(vol, {
		tex = T.spark,
		color = cs(WHITE, c.c2),
		size = ns(0, 0.28, 0),
		rate = 8,
		life = nr(0.8, 1.4),
		speed = nr(0.3, 0.8),
		spread = V2(180, 180),
		shape = Enum.ParticleEmitterShape.Box,
	})
	B.circle(c, { radius = 2.1, color = c.c2, width = 0.05, tr = 0.4, at = CF(0, c.groundY + 0.03, 0) })
	Core.light(Core.att(c, c.torso, CF(0, 0.3, 0.9)), WHITE, 2.2, 15)
	Core.light(haloAtt, c.c2, 1.2, 8)
	local nextC = 0
	Core.on(c, function(t, _, root)
		for _, w in wings do
			local sp = w.spec
			local s = w.s
			local flap = math.sin(t * 1.6 + sp.ph)
			local base = root
				* CF(s * 0.3, sp.y, 0.5)
				* ANG(0, -s * (sp.yaw + flap * 0.25), 0)
				* ANG(-0.15 + flap * 0.05, 0, 0)
			Core.put(w.bone, base * ANG(0, 0, -s * (sp.p0 - 0.12)) * CF(0, sp.l0 * 0.275, 0))
			for j, f in w.feathers do
				local phi = (sp.p0 + (sp.p1 - sp.p0) * (j - 1) / (NF - 1)) * (1 + flap * 0.06)
				Core.put(f, base * ANG(0, 0, -s * phi) * CF(0, f.Size.Y / 2, 0.02 * j))
			end
		end
		local change = t >= nextC
		if change then
			nextC = t + 0.12
		end
		local hcf = CF(0, yH, 0) * ANG(0.15, 0, 0)
		for i, g in code do
			local a = (i - 1) / 8 * TAU - t * 0.9
			g.att.Position = (hcf * CF(math.cos(a) * 0.88, 0.05, math.sin(a) * 0.88)).Position
			if change and rng:NextNumber() < 0.3 then
				g.lbl.Text = if rng:NextNumber() < 0.5 then "0" else "1"
			end
		end
	end)
end

-- blue panels with sad face text orbiting, error popups
A.BlueScreen = function(c: Ctx)
	local rng = c.rng
	type Panel = { body: BasePart, bar: BasePart, pct: TextLabel }
	local panels: { Panel } = {}
	local function bsod(part: BasePart, big: boolean): TextLabel
		local sg = Core.surface(part, Enum.NormalId.Front, if big then 70 else 110)
		local bg = Core.frame(sg, c.c1, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		Core.label(
			bg,
			":(",
			WHITE,
			F.mono,
			UDim2.fromScale(0.06, 0.04),
			UDim2.fromScale(0.3, 0.38),
			Enum.TextXAlignment.Left
		)
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
		return pct
	end
	for i = 1, 4 do
		local body = Core.part(c, V(1.6, 1, 0.05), c.c1, SMOOTH)
		panels[i] =
			{ body = body, bar = Core.part(c, V(1.6, 0.04, 0.07), c.c1:Lerp(WHITE, 0.6)), pct = bsod(body, false) }
	end
	local monitor = Core.part(c, V(3, 1.8, 0.06), c.c1, SMOOTH)
	local monPct = bsod(monitor, true)
	local monFrame = Core.part(c, V(3.12, 1.92, 0.04), Color3.fromRGB(12, 14, 22), METAL)
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
	for i = 1, 5 do
		local win = Core.part(c, V(1.1, 0.62, 0.04), Color3.fromRGB(225, 228, 235), SMOOTH)
		local sg = Core.surface(win, Enum.NormalId.Front, 110)
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
		local ok =
			Core.frame(sg, Color3.fromRGB(200, 205, 215), UDim2.fromScale(0.7, 0.72), UDim2.fromScale(0.24, 0.18))
		Core.label(ok, "OK", Color3.fromRGB(20, 20, 30), F.mono, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		pops[i] = {
			win = win,
			title = Core.part(c, V(1.1, 0.14, 0.05), Color3.fromRGB(0, 90, 220), SMOOTH),
			x = Core.part(c, V(0.1, 0.1, 0.06), Color3.fromRGB(255, 40, 50)),
			cf = CF(0, -50, 0),
			t0 = os.clock() + i * 0.45,
			life = 1.6,
		}
	end
	local spinner: { BasePart } = {}
	for i = 1, 6 do
		spinner[i] = Core.part(c, V(0.1, 0.1, 0.1), WHITE, NEON, 0, BALL)
	end
	B.circle(c, { radius = 2.7, color = c.c1, width = 0.06, tr = 0.3, at = CF(0, c.groundY + 0.03, 0) })
	B.circle(c, { radius = 1.8, color = c.c2, width = 0.03, tr = 0.6, at = CF(0, c.groundY + 0.03, 0) })
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.12, 0),
		rate = 9,
		life = nr(0.4, 0.7),
		speed = nr(1.5, 3),
		spread = V2(180, 180),
		rot = nr(0, 0),
	})
	Core.emit(torso, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0, 0.24, 0),
		rate = 6,
		life = nr(0.8, 1.2),
		speed = nr(0.5, 1),
		spread = V2(180, 180),
	})
	local light = Core.light(torso, c.c1, 2, 14)
	local lastPct = -1
	Core.on(c, function(t, _, root)
		local flash = (t % 5) < 0.1
		local pct = math.floor((t * 7) % 101)
		if pct ~= lastPct then
			lastPct = pct
			local s = pct .. "% complete"
			for _, p in panels do
				p.pct.Text = s
			end
			monPct.Text = s
		end
		for i, p in panels do
			local a = (i - 1) / 4 * TAU + t * 0.4
			local cf = root
				* outward(a, 2.7, c.chestY + 0.1 + math.sin(t * 1.2 + i) * 0.15 + (if flash then 0.1 else 0))
			Core.put(p.body, cf)
			Core.put(p.bar, cf * CF(0, 0.52, 0))
		end
		local mcf = root * CF(0, c.chestY + 0.9, 1.6) * ANG(0, math.pi, 0) * ANG(-0.1, 0, 0)
		Core.put(monitor, mcf)
		Core.put(monFrame, mcf * CF(0, 0, 0.05))
		for _, p in pops do
			local age = t - p.t0
			if age > p.life + 0.3 then
				p.t0 = t
				p.life = 1.2 + rng:NextNumber()
				age = 0
				local a = rng:NextNumber() * TAU
				local r = 1.6 + rng:NextNumber() * 0.8
				p.cf = outward(a, r, c.chestY - 0.2 + rng:NextNumber() * 1.6)
					* ANG(0, 0, (rng:NextNumber() - 0.5) * 0.3)
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
			p.win.Size = V(1.1 * s, 0.62 * s, 0.04)
			p.title.Size = V(1.1 * s, 0.14 * s, 0.05)
			p.win.Transparency = if hidden then 1 else 0
			p.title.Transparency = if hidden then 1 else 0
			p.x.Transparency = if hidden then 1 else 0
			local cf = root * p.cf
			Core.put(p.win, cf)
			Core.put(p.title, cf * CF(0, 0.38 * s, 0))
			Core.put(p.x, cf * CF(0.47 * s, 0.38 * s, -0.02))
		end
		local scf = CFrame.lookAt((root * CF(0, c.topY + 0.75, 0)).Position, camPos())
		for i, d in spinner do
			local a = (i - 1) * 0.42 - t * 5
			Core.put(d, scf * CF(math.cos(a) * 0.32, math.sin(a) * 0.32, 0))
			d.Transparency = (i - 1) / 7
		end
		light.Brightness = if flash then 6 else 1.8
	end)
end

---------------------------------------------------------------- CORRUPTED

-- black-red tearing shards, ground cracks, inverted ghosts
A.Corruption = function(c: Ctx)
	local rng = c.rng
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
	for i = 1, 14 do
		local h = 0.3 + rng:NextNumber() * 0.7
		local wd = 0.2 + rng:NextNumber() * 0.4
		shards[i] = {
			slab = Core.part(c, V(0.05, h, wd), Color3.fromRGB(6, 2, 4), SMOOTH),
			edge = Core.part(c, V(0.06, h, 0.03), c.c1),
			a = rng:NextNumber() * TAU,
			r = 1.6 + rng:NextNumber() * 1.2,
			y = c.groundY + 0.5 + rng:NextNumber() * (c.topY - c.groundY + 0.6),
			w = (0.3 + rng:NextNumber() * 0.5) * (if i % 2 == 0 then 1 else -1),
			rot = ANG(rng:NextNumber() * TAU, rng:NextNumber() * TAU, rng:NextNumber() * TAU),
			tear = -10,
			tdir = CFrame.identity,
		}
	end
	local g = c.groundY
	local disc = Core.part(c, V(0.04, 5.4, 5.4), Color3.fromRGB(8, 0, 3), SMOOTH, 0.1, CYL)
	type Crack = { beams: { Beam }, off: number }
	local cracks: { Crack } = {}
	for k = 1, 7 do
		local a = (k - 1) / 7 * TAU + rng:NextNumber() * 0.4
		local pts = {}
		local rad = 0.3
		for _ = 0, 4 do
			a += (rng:NextNumber() - 0.5) * 0.7
			table.insert(pts, V(math.cos(a) * rad, g + 0.06, math.sin(a) * rad))
			rad += 0.5 + rng:NextNumber() * 0.3
		end
		local poly = B.poly(c, pts, c.c1, 0.1, { w1 = 0.05, segs = 1, bright = 3 })
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
	local feet = Core.volume(c, V(3, 0.1, 3), CF(0, g + 0.1, 0))
	Core.emit(feet, {
		tex = T.fireSpark,
		color = cs(c.c1, Color3.fromRGB(120, 0, 10)),
		size = ns(0.18, 0),
		rate = 12,
		life = nr(1, 1.8),
		speed = nr(1, 2.2),
		accel = V(0, 0.6, 0),
		bright = 2.5,
		shape = Enum.ParticleEmitterShape.Box,
	})
	Core.emit(feet, {
		tex = T.smoke,
		color = cs(BLACK, Color3.fromRGB(40, 0, 8)),
		size = ns(1.2, 3),
		transp = ns(0.5, 1),
		rate = 6,
		life = nr(1.6, 2.6),
		speed = nr(0.4, 0.9),
		light = 0,
		rotSpeed = nr(-30, 30),
		shape = Enum.ParticleEmitterShape.Box,
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.square,
		color = cs(c.c1, BLACK),
		size = ns(0.2, 0.1),
		rate = 10,
		life = nr(0.15, 0.3),
		speed = nr(4, 7),
		spread = V2(180, 180),
		rot = nr(0, 0),
		light = 0.5,
	})
	local light = Core.light(Core.att(c, c.root, CF(0, g + 0.4, 0)), c.c1, 2, 12)
	Core.on(c, function(t, _, root)
		Core.put(disc, root * CF(0, g + 0.02, 0) * FLAT)
		for _, ck in cracks do
			for j, bm in ck.beams do
				local w = ((t * 0.9 + ck.off) % 1) * 5 - j
				bm.Transparency = NumberSequence.new(math.clamp(0.45 - math.exp(-w * w) * 0.45, 0, 1))
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
			local r = s.r + k * 0.8
			local cf = root
				* CF(math.cos(a) * r, s.y + math.sin(t + s.a) * 0.15, math.sin(a) * r)
				* s.rot
				* ANG(t * s.w, 0, 0)
			if k > 0 then
				cf *= CFrame.identity:Lerp(s.tdir, k)
			end
			Core.put(s.slab, cf)
			Core.put(s.edge, cf * CF(0.005, 0, s.slab.Size.Z / 2))
		end
		light.Brightness = 1.5 + math.noise(t * 5, 1) * 1.5
	end)
end

-- violent red glitch storm, warning triangles, shaking light
A.KernelPanic = function(c: Ctx)
	local rng = c.rng
	local amber = Color3.fromRGB(255, 190, 0)
	type Blk = { p: BasePart, cf: CFrame, nextT: number }
	local blocks: { Blk } = {}
	for i = 1, 18 do
		blocks[i] =
			{ p = Core.part(c, V(0.3, 0.3, 0.3), if i % 3 == 0 then c.c2 else c.c1), cf = CF(0, -50, 0), nextT = 0 }
	end
	type Tri = { bars: { BasePart }, att: Attachment, a: number, y: number }
	local tris: { Tri } = {}
	for i = 1, 4 do
		local att, lbl = B.glyph(c, "!", amber, V2(0.4, 0.4), F.tech, nil, BLACK)
		lbl.TextStrokeTransparency = 0
		tris[i] = {
			bars = B.tri(c, 0.75, 0.07, if i % 2 == 0 then amber else c.c1),
			att = att,
			a = (i - 1) / 4 * TAU,
			y = c.chestY + (i % 2) * 0.9 - 0.2,
		}
	end
	for _ = 1, 3 do
		B.bolt(c, {
			segs = 6,
			color = WHITE,
			color2 = c.c1,
			width = 0.1,
			jitter = 0.35,
			interval = 0.04,
			flicker = 0.3,
			ends = function()
				local u = rng:NextUnitVector()
				return V(0, c.chestY, 0), V(u.X * 3.2, c.chestY + u.Y * 2.2, u.Z * 3.2)
			end,
		})
	end
	local _, title = B.glyph(c, "KERNEL PANIC", c.c1, V2(3.2, 0.45), F.tech, CF(0, c.topY + 1.1, 0), BLACK)
	title.TextStrokeTransparency = 0
	local streams: { { att: Attachment, lbl: TextLabel } } = {}
	local errs = { "0xDEADBEEF", "SEGFAULT", "STACK SMASH", "NULL DEREF", "DOUBLE FAULT", "0xBAADF00D" }
	for i = 1, 3 do
		local att, lbl = B.glyph(c, errs[i], WHITE, V2(1.4, 0.22), F.mono, nil, c.c1)
		streams[i] = { att = att, lbl = lbl }
	end
	B.ring(c, {
		n = 16,
		radius = 2,
		seg = V(0.25, 0.05, 0),
		color = c.c1,
		color2 = Color3.fromRGB(18, 18, 18),
		spin = 1.5,
		anchor = function()
			return CF(0, c.groundY + 0.04, 0)
		end,
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.fireSpark,
		color = cs(WHITE, c.c1),
		size = ns(0.22, 0),
		rate = 24,
		life = nr(0.3, 0.6),
		speed = nr(6, 10),
		spread = V2(180, 180),
		accel = V(0, -10, 0),
		bright = 3,
	})
	Core.emit(torso, {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.15, 0.05),
		rate = 14,
		life = nr(0.1, 0.25),
		speed = nr(3, 6),
		spread = V2(180, 180),
		rot = nr(0, 0),
	})
	Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.3, 0)), {
		tex = T.smoke,
		color = cs(c.c1, Color3.fromRGB(60, 0, 0)),
		size = ns(1.5, 3.5),
		transp = ns(0.7, 1),
		rate = 6,
		life = nr(1, 1.8),
		speed = nr(1, 2),
		spread = V2(80, 80),
		light = 0.5,
		rotSpeed = nr(-60, 60),
	})
	local shakeAtt = Core.att(c, c.torso)
	local shake = Core.light(shakeAtt, c.c1, 3, 16)
	local nextS = 0
	Core.on(c, function(t, _, root)
		for _, b in blocks do
			if t >= b.nextT then
				b.nextT = t + 0.04 + rng:NextNumber() * 0.08
				local u = rng:NextUnitVector() * (1.3 + rng:NextNumber() * 1.7)
				b.cf = CF(u.X, c.chestY + u.Y * 1.3, u.Z) * ANG(rng:NextNumber() * TAU, rng:NextNumber() * TAU, 0)
				local s = 0.08 + rng:NextNumber() * 0.4
				b.p.Size = V(s * (0.5 + rng:NextNumber() * 2), s * (0.3 + rng:NextNumber()), s)
				b.p.Transparency = if rng:NextNumber() < 0.2 then 1 else 0
			end
			Core.put(b.p, root * b.cf)
		end
		for i, tr in tris do
			local a = tr.a + t * 1.3 + math.noise(i, t * 2) * 0.8
			local jit = V((rng:NextNumber() - 0.5) * 0.08, (rng:NextNumber() - 0.5) * 0.08, 0)
			local cf = outward(a, 2.3, tr.y + math.sin(t * 3 + i) * 0.2) * CF(jit)
			B.putTri(tr.bars, root * cf, 0.75)
			tr.att.Position = (cf * CF(0, -0.03, -0.05)).Position
		end
		if t >= nextS then
			nextS = t + 0.15
			for i, s in streams do
				if rng:NextNumber() < 0.4 then
					s.lbl.Text = errs[rng:NextInteger(1, #errs)]
				end
				local a = rng:NextNumber() * TAU
				s.att.Position = V(math.cos(a) * 1.9, c.groundY + 1 + i * 0.8, math.sin(a) * 1.9)
			end
		end
		title.TextTransparency = if rng:NextNumber() < 0.12 then 0.8 else 0
		title.Rotation = (rng:NextNumber() - 0.5) * 4
		shakeAtt.Position = V((rng:NextNumber() - 0.5) * 2, (rng:NextNumber() - 0.5) * 2, (rng:NextNumber() - 0.5) * 2)
		shake.Brightness = 1 + rng:NextNumber() * 6
		shake.Color = if rng:NextNumber() < 0.2 then WHITE else c.c1
	end)
end

-- black hole orb above with accretion disc, particles sucked in
A.EventHorizon = function(c: Ctx)
	local O = V(0, c.topY + 2.6, 0)
	local hot = c.c1:Lerp(WHITE, 0.6)
	local orb = Core.part(c, V(1.6, 1.6, 1.6), BLACK, SMOOTH, 0, BALL)
	local photon = Core.part(c, V(1.74, 1.74, 1.74), c.c1, FF, 0, BALL)
	local function facing(): CFrame
		local camL = c.root.CFrame:PointToObjectSpace(camPos())
		if (camL - O).Magnitude < 0.1 then
			return CF(O)
		end
		return CFrame.lookAt(O, camL) * ANG(math.pi / 2, 0, 0)
	end
	B.circle(c, { radius = 0.98, color = hot, width = 0.14, n = 8, anchor = facing })
	B.circle(c, { radius = 1.25, color = c.c1, width = 0.06, n = 8, tr = 0.4, anchor = facing })
	local function disc(t: number): CFrame
		return CF(O) * ANG(0.32, t * 0.1, 0.15)
	end
	B.ring(c, { n = 20, radius = 1.55, seg = V(0.5, 0.05, 0), color = hot, color2 = c.c1, spin = 2.2, anchor = disc })
	B.ring(c, {
		n = 24,
		radius = 2.35,
		seg = V(0.6, 0.04, 0),
		color = c.c1,
		color2 = c.c1:Lerp(Color3.fromRGB(120, 10, 0), 0.6),
		spin = 1.1,
		tr = 0.15,
		anchor = disc,
	})
	local pN = Core.att(c, nil, CF(O + V(0, 0.85, 0)))
	local pNT = Core.att(c, nil, CF(O + V(0, 5.5, 0)))
	local pS = Core.att(c, nil, CF(O - V(0, 0.85, 0)))
	local pST = Core.att(c, nil, CF(O - V(0, 2, 0)))
	Core.beam(c, pN, pNT, WHITE, 0.35, { w1 = 0.02, color2 = c.c1, tr = ns(0, 1) })
	Core.beam(c, pS, pST, WHITE, 0.3, { w1 = 0.02, color2 = c.c1, tr = ns(0, 1) })
	local vol = Core.volume(c, V(7, 7, 7), CF(O))
	Core.emit(vol, {
		tex = T.spark,
		color = cs(c.c1, hot),
		size = ns(0.3, 0.05),
		transp = ns(0.4, 0),
		rate = 30,
		life = nr(0.85, 0.85),
		speed = nr(3.6, 4),
		locked = true,
		shape = Enum.ParticleEmitterShape.Sphere,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		inout = Enum.ParticleEmitterShapeInOut.Inward,
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.spark,
		color = cs(c.c1, hot),
		size = ns(0.2, 0),
		rate = 10,
		life = nr(0.6, 0.8),
		speed = nr(3, 4),
		spread = V2(15, 15),
		accel = V(0, 2, 0),
	})
	local sx = c.torso.Size.X * 0.4
	for _, s in { 1, -1 } do
		local sh = Core.att(c, c.torso, CF(s * sx, c.torso.Size.Y * 0.4, 0))
		Core.beam(
			c,
			sh,
			pS,
			c.c1,
			0.09,
			{ w1 = 0.02, c0 = 1.3 * s, c1 = -1.3 * s, tex = T.square, texLen = 0.5, texSpeed = 2.5, tr = ns(0.6, 0.2) }
		)
	end
	Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.1, 0)), {
		tex = T.shock,
		color = cs(c.c1),
		size = ns(1, 6),
		transp = ns(0.5, 1),
		rate = 0.6,
		life = nr(1.4, 1.4),
		speed = nr(0.01, 0.01),
		orient = Enum.ParticleOrientation.VelocityPerpendicular,
		rot = nr(0, 360),
	})
	B.circle(c, { radius = 2.4, color = c.c1, width = 0.05, tr = 0.45, at = CF(0, c.groundY + 0.03, 0) })
	local ol = Core.light(Core.att(c, nil, CF(O)), c.c1, 3, 18)
	Core.light(Core.att(c, c.root, CF(0, c.groundY + 0.5, 0)), Color3.fromRGB(255, 60, 20), 1, 9)
	Core.on(c, function(t, _, root)
		local cf = root * CF(O)
		Core.put(orb, cf)
		local s = 1.74 + Core.pulse(t, 0.9) * 0.08
		photon.Size = V(s, s, s)
		Core.put(photon, cf)
		ol.Brightness = 2.6 + Core.pulse(t, 0.9) * 1.2
	end)
end

-- pure black void silhouette with white outline and inverted pixels
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
	type Px = { p: BasePart, a: number, r: number, y: number, nextT: number }
	local pix: { Px } = {}
	for i = 1, 16 do
		pix[i] = {
			p = Core.part(c, V(0.22, 0.22, 0.03), if i % 2 == 0 then WHITE else BLACK, SMOOTH),
			a = rng:NextNumber() * TAU,
			r = 1.2 + rng:NextNumber(),
			y = c.groundY + 0.6 + rng:NextNumber() * (c.topY - c.groundY + 0.6),
			nextT = 0,
		}
	end
	local words = { "NULL", "0x00000000", "nil", "void*", "&null", "SIGSEGV" }
	type Gl = { att: Attachment, lbl: TextLabel, a: number, y: number }
	local glyphs: { Gl } = {}
	for i = 1, 4 do
		local att, lbl = B.glyph(c, words[i], WHITE, V2(1.3, 0.26), F.tech, nil, BLACK)
		glyphs[i] = { att = att, lbl = lbl, a = (i - 1) / 4 * TAU, y = c.groundY + 1 + i * 0.7 }
	end
	local g = c.groundY
	local disc = Core.part(c, V(0.04, 4.8, 4.8), BLACK, SMOOTH, 0, CYL)
	B.circle(c, { radius = 2.4, color = WHITE, width = 0.06, at = CF(0, g + 0.05, 0) })
	B.ring(c, {
		n = 20,
		gap = 2,
		radius = 2,
		seg = V(0.06, 0.04, 0),
		color = WHITE,
		spin = -0.4,
		anchor = function()
			return CF(0, g + 0.05, 0)
		end,
	})
	local vol = Core.volume(c, V(5, 5, 5), CF(0, c.chestY - 0.3, 0))
	Core.emit(vol, {
		tex = T.square,
		color = cs(WHITE),
		size = ns(0.12, 0.05),
		transp = ns(0.2, 0),
		rate = 22,
		life = nr(0.6, 0.6),
		speed = nr(3.6, 4),
		rot = nr(0, 0),
		locked = true,
		shape = Enum.ParticleEmitterShape.Sphere,
		shapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		inout = Enum.ParticleEmitterShapeInOut.Inward,
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.smoke,
		color = cs(BLACK),
		size = ns(1, 2.6),
		transp = ns(0.5, 1),
		rate = 5,
		life = nr(1.5, 2.2),
		speed = nr(0.5, 1),
		spread = V2(180, 180),
		light = 0,
		rotSpeed = nr(-30, 30),
	})
	Core.light(Core.att(c, c.root, CF(0, g + 0.3, 0)), WHITE, 0.7, 8)
	Core.on(c, function(t, _, root)
		Core.put(disc, root * CF(0, g + 0.02, 0) * FLAT)
		for _, q in pix do
			if t >= q.nextT then
				q.nextT = t + 0.1 + rng:NextNumber() * 0.4
				local white = q.p.Color.R < 0.5
				q.p.Color = if white then WHITE else BLACK
				q.p.Material = if white then NEON else SMOOTH
			end
			local a = q.a + t * 0.25
			Core.put(
				q.p,
				root * CF(math.cos(a) * q.r, q.y + math.sin(t + q.a) * 0.2, math.sin(a) * q.r) * ANG(0, -a, 0)
			)
		end
		for i, gl in glyphs do
			local a = gl.a - t * 0.3
			gl.att.Position = V(math.cos(a) * 2.2, gl.y + math.sin(t * 0.8 + i) * 0.2, math.sin(a) * 2.2)
			local inv = math.noise(i, t * 1.5) > 0.3
			gl.lbl.TextColor3 = if inv then BLACK else WHITE
			gl.lbl.TextStrokeColor3 = if inv then WHITE else BLACK
		end
	end)
end

---------------------------------------------------------------- SINGULARITY

-- white core star, galaxy spiral, gravitational rings, light beams
A.Singularity = function(c: Ctx)
	local yS = c.topY + 1.9
	local SP = V(0, yS, 0)
	local star = Core.part(c, V(1.1, 1.1, 1.1), WHITE, NEON, 0, BALL)
	local shellA = Core.part(c, V(1.6, 1.6, 1.6), c.c2, FF, 0, BALL)
	local shellB = Core.part(c, V(2.1, 2.1, 2.1), WHITE, NEON, 0.85, BALL)
	local spikes: { BasePart } = {}
	for i = 1, 4 do
		spikes[i] = Core.part(c, V(if i <= 2 then 7 else 3.6, 0.06, 0.02), WHITE, NEON, 0.15)
	end
	local function collapse(t: number): number
		local ph = t % 7
		if ph > 6.3 then
			return 1 - smooth01((ph - 6.3) / 0.7) * 0.85
		end
		return 1
	end
	-- galaxy spiral
	type Star = { p: BasePart, th: number, r: number }
	local arms: { { Star } } = {}
	local armPolys: { B.Poly } = {}
	for arm = 1, 2 do
		local list = {}
		for j = 1, 13 do
			local s = 0.32 - j * 0.018
			list[j] = {
				p = Core.part(c, V(s, s, s), WHITE:Lerp(c.c2, j / 13), NEON, 0, BALL),
				th = j * 0.5 + (arm - 1) * math.pi,
				r = 0.9 + j * 0.27,
			}
		end
		arms[arm] = list
		local pts = {}
		for j = 1, 13, 2 do
			table.insert(pts, V(j * 0.1, -0.2, 0))
		end
		armPolys[arm] = B.poly(c, pts, c.c2, 0.1, { w1 = 0.04, tr = ns(0.45), segs = 4 })
	end
	-- gravitational rings
	for k = 1, 3 do
		local r0 = 2.6 + k * 0.6
		B.circle(c, {
			radius = r0,
			color = if k == 2 then WHITE else c.c2,
			width = 0.06,
			n = 8,
			tr = 0.2,
			anchor = function(t)
				return CF(0, c.chestY, 0)
					* ANG(math.sin(t * 0.3 + k) * 0.35, t * 0.1 * k, math.cos(t * 0.27 + k) * 0.35)
			end,
			radiusFn = function(t)
				return (r0 + math.sin(t * 2 - k) * 0.15) * collapse(t)
			end,
		})
	end
	B.ring(c, {
		n = 16,
		radius = 1.5,
		seg = V(0.06, 0.08, 0),
		color = WHITE,
		color2 = c.c2,
		spin = 1.8,
		anchor = function(t)
			return CF(SP) * ANG(0.5, t * 0.2, 0.2)
		end,
		radiusFn = function(t)
			return 1.5 * collapse(t)
		end,
	})
	B.ring(c, {
		n = 24,
		gap = 3,
		radius = 3,
		seg = V(0.08, 0.04, 0),
		color = c.c2,
		spin = -0.3,
		anchor = function()
			return CF(0, c.groundY + 0.04, 0)
		end,
	})
	B.circle(c, { radius = 2.6, color = WHITE, width = 0.04, tr = 0.4, at = CF(0, c.groundY + 0.03, 0) })
	B.circle(c, { radius = 3.4, color = c.c2, width = 0.05, tr = 0.3, at = CF(0, c.groundY + 0.03, 0) })
	-- god beams
	local starAtt = Core.att(c, nil, CF(SP))
	local tops: { Attachment } = {}
	for k = 1, 4 do
		tops[k] = Core.att(c)
		Core.beam(c, starAtt, tops[k], WHITE, 0.6, { w1 = 4, color2 = c.c2, tr = ns(0.3, 1), segs = 2 })
	end
	local floorAtt = Core.att(c, nil, CF(0, c.groundY + 0.05, 0))
	Core.beam(c, starAtt, floorAtt, WHITE, 0.5, { w1 = 2.6, color2 = c.c2, tr = ns(0.55, 0.9), segs = 2 })
	Core.emit(starAtt, {
		tex = T.vortex,
		color = cs(c.c2, WHITE),
		size = ns(3, 5),
		transp = ns(0.4, 1),
		rate = 2,
		life = nr(1, 1),
		rotSpeed = nr(90, 140),
		locked = true,
	})
	Core.emit(starAtt, {
		tex = T.glow,
		color = cs(WHITE),
		size = ns(4, 5),
		transp = ns(0.6, 1),
		rate = 3,
		life = nr(0.6, 0.8),
		locked = true,
	})
	local burst = Core.emit(starAtt, {
		tex = T.spark,
		color = cs(WHITE, c.c2),
		size = ns(0.5, 0),
		rate = 0,
		life = nr(0.8, 1.4),
		speed = nr(8, 14),
		spread = V2(180, 180),
		drag = 2,
		bright = 3,
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(WHITE, c.c2),
		size = ns(0, 0.3, 0),
		rate = 12,
		life = nr(1, 1.8),
		speed = nr(1, 3),
		spread = V2(180, 180),
	})
	Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.1, 0)), {
		tex = T.shock,
		color = cs(c.c2, WHITE),
		size = ns(1, 9),
		transp = ns(0.4, 1),
		rate = 0.5,
		life = nr(1.6, 1.6),
		speed = nr(0.01, 0.01),
		orient = Enum.ParticleOrientation.VelocityPerpendicular,
	})
	local sl = Core.light(starAtt, WHITE, 4, 22)
	Core.light(Core.att(c, c.root, CF(0, c.groundY + 0.5, 0)), c.c2, 2, 12)
	local lastPh = 0
	Core.on(c, function(t, _, root)
		local col = collapse(t)
		local ph = t % 7
		if ph < lastPh then
			burst:Emit(45)
		end
		lastPh = ph
		local scf = root * CF(SP)
		Core.put(star, scf)
		local sa = 1.6 + Core.pulse(t, 1.3) * 0.25
		shellA.Size = V(sa, sa, sa)
		Core.put(shellA, scf)
		local sb = 2.1 * (0.9 + Core.pulse(t, 2.1) * 0.25) * col
		shellB.Size = V(sb, sb, sb)
		Core.put(shellB, scf)
		local look = CFrame.lookAt(scf.Position, camPos())
		for i, s in spikes do
			Core.put(s, look * ANG(0, 0, (i - 1) * math.pi / 4 + t * 0.2 * (if i % 2 == 0 then 1 else -1)))
		end
		local gbase = root * CF(0, -0.2, 0) * ANG(0, t * 0.5, 0)
		for arm, list in arms do
			local poly = armPolys[arm]
			local ai = 0
			for j, st in list do
				local r = st.r * col
				local lp = V(math.cos(st.th) * r, math.sin(st.th * 2 + t) * 0.06, math.sin(st.th) * r)
				Core.put(st.p, gbase * CF(lp))
				if j % 2 == 1 then
					ai += 1
					poly.atts[ai].Position = (CF(0, -0.2, 0) * ANG(0, t * 0.5, 0) * CF(lp)).Position
				end
			end
		end
		for k, a in tops do
			local ang = (k - 1) / 4 * TAU + t * 0.15
			a.Position = SP + V(math.cos(ang) * 6, 40, math.sin(ang) * 6)
		end
		sl.Brightness = if ph > 6.3 then 4 + (ph - 6.3) * 10 else 3.5 + Core.pulse(t, 1.3)
	end)
end

-- giant wireframe grid sphere, floating code pages, green god-rays
A.Architect = function(c: Ctx)
	local rng = c.rng
	local S = V(0, c.chestY, 0)
	local R = 5.2
	for k = 0, 4 do
		B.circle(c, {
			radius = R,
			color = c.c1,
			width = 0.05,
			tr = 0.35,
			n = 8,
			anchor = function(t)
				return CF(S) * ANG(0, t * 0.15 + k * math.pi / 5, 0) * ANG(0, 0, math.pi / 2)
			end,
		})
	end
	for _, y in { -4, -2.2, 0, 2.2, 4 } do
		B.circle(
			c,
			{ radius = math.sqrt(R * R - y * y), color = c.c1, width = 0.045, tr = 0.4, n = 8, at = CF(S + V(0, y, 0)) }
		)
	end
	local nodes: { BasePart } = {}
	for i = 1, 20 do
		nodes[i] = Core.part(c, V(0.18, 0.18, 0.18), WHITE:Lerp(c.c1, 0.3))
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
	for i = 1, 6 do
		local p = Core.part(c, V(0.9, 1.2, 0.02), WHITE:Lerp(c.c1, 0.6), NEON, 0.55)
		local sg = Core.surface(p, Enum.NormalId.Front, 120)
		if i == 1 then
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
			bar = Core.part(c, V(0.9, 0.08, 0.03), c.c1),
			a = (i - 1) / 6 * TAU,
			r = 2.6 + (i % 2) * 0.6,
			y = c.chestY + ((i % 3) - 1) * 0.9,
		}
	end
	local skyAtts: { Attachment } = {}
	local hit = Core.att(c, nil, CF(0, c.chestY, 0))
	for k = 1, 5 do
		skyAtts[k] = Core.att(c)
		Core.beam(c, skyAtts[k], hit, c.c1, 3, { w1 = 0.8, color2 = WHITE, tr = ns(0.95, 0.65), segs = 2 })
	end
	local g = c.groundY + 0.03
	for k = -2, 2 do
		local x = k * 2
		local half = math.sqrt(math.max(0, 25 - x * x))
		local a0 = Core.att(c, nil, CF(x, g, -half))
		local a1 = Core.att(c, nil, CF(x, g, half))
		Core.beam(c, a0, a1, c.c1, 0.04, { tr = ns(0.85, 0.4, 0.85), segs = 2 })
		local b0 = Core.att(c, nil, CF(-half, g, x))
		local b1 = Core.att(c, nil, CF(half, g, x))
		Core.beam(c, b0, b1, c.c1, 0.04, { tr = ns(0.85, 0.4, 0.85), segs = 2 })
	end
	B.ring(c, {
		n = 20,
		gap = 4,
		radius = 5.2,
		seg = V(0.1, 0.05, 0),
		color = c.c1,
		spin = 0.1,
		anchor = function()
			return CF(0, g + 0.01, 0)
		end,
	})
	local cursor = Core.part(c, V(0.22, 0.38, 0.05), WHITE)
	local _, title = B.glyph(
		c,
		"404 // PAGE NOT FOUND",
		c.c1,
		V2(3, 0.32),
		F.tech,
		CF(0, c.topY + 1.25, 0),
		Color3.fromRGB(0, 40, 20)
	)
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0, 0.3, 0),
		rate = 12,
		life = nr(1.2, 2),
		speed = nr(1, 2.5),
		spread = V2(180, 180),
	})
	Core.emit(torso, {
		tex = T.glow,
		color = cs(c.c1),
		size = ns(2.5, 3.5),
		transp = ns(0.8, 1),
		rate = 3,
		life = nr(0.8, 1.2),
		locked = true,
	})
	local fv = Core.volume(c, V(6, 0.1, 6), CF(0, c.groundY + 0.1, 0))
	Core.emit(fv, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.1, 0),
		transp = ns(0.2, 1),
		rate = 16,
		life = nr(1.4, 2.4),
		speed = nr(1, 2),
		rot = nr(0, 0),
		shape = Enum.ParticleEmitterShape.Box,
	})
	Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.1, 0)), {
		tex = T.shock,
		color = cs(c.c1),
		size = ns(2, 11),
		transp = ns(0.5, 1),
		rate = 0.45,
		life = nr(2, 2),
		speed = nr(0.01, 0.01),
		orient = Enum.ParticleOrientation.VelocityPerpendicular,
	})
	local light = Core.light(torso, c.c1, 3, 20)
	Core.on(c, function(t, _, root)
		local rot = t * 0.15
		for i, n in nodes do
			local k = (i - 1) % 10
			local y = if i <= 10 then 2.2 else -2.2
			local rr = math.sqrt(R * R - y * y)
			local a = rot + k * math.pi / 5
			Core.put(n, root * CF(S + V(math.cos(a) * rr, y, -math.sin(a) * rr)) * ANG(t, t * 0.7, 0))
		end
		for i, pg in pages do
			local a = pg.a + t * 0.2
			local cf = root
				* outward(a, pg.r, pg.y + math.sin(t * 0.8 + i) * 0.25)
				* ANG(0, math.sin(t * 0.5 + i) * 0.5, math.sin(t * 0.6 + i) * 0.08)
			Core.put(pg.p, cf)
			Core.put(pg.bar, cf * CF(0, 0.62, 0))
		end
		for k, a in skyAtts do
			local ang = (k - 1) / 5 * TAU + t * 0.08
			a.Position = V(math.cos(ang) * 7, 45, math.sin(ang) * 7)
		end
		Core.put(cursor, root * CF(1.75, c.topY + 1.25, 0))
		cursor.Transparency = if (t % 1) < 0.5 then 0 else 1
		title.TextTransparency = if rng:NextNumber() < 0.03 then 0.7 else 0
		light.Brightness = 2.6 + Core.pulse(t, 2) * 1.2
	end)
end

-- black censor bars orbiting, red classified stamps, reality tearing
A.Redacted = function(c: Ctx)
	local rng = c.rng
	local red = c.c2
	type Bar = { p: BasePart, edge: BasePart, a: number, r: number, y: number, w: number, tilt: number }
	local bars: { Bar } = {}
	for i = 1, 8 do
		bars[i] = {
			p = Core.part(c, V(2.2, 0.36, 0.05), Color3.fromRGB(4, 4, 4), SMOOTH),
			edge = Core.part(c, V(2.2, 0.04, 0.06), red),
			a = rng:NextNumber() * TAU,
			r = 1.7 + rng:NextNumber() * 0.7,
			y = c.groundY + 0.6 + rng:NextNumber() * (c.topY - c.groundY + 0.8),
			w = (0.4 + rng:NextNumber() * 0.6) * (if i % 2 == 0 then 1 else -1),
			tilt = (rng:NextNumber() - 0.5) * 0.6,
		}
	end
	local hw = c.head.Size.X * 1.15
	local faceBar = Core.part(c, V(hw, 0.28, 0.06), Color3.fromRGB(4, 4, 4), SMOOTH)
	local faceEdge = Core.part(c, V(hw, 0.03, 0.07), red)
	type Stamp = { att: Attachment, gui: BillboardGui, lbl: TextLabel, stroke: UIStroke, t0: number }
	local stamps: { Stamp } = {}
	local words = { "CLASSIFIED", "[REDACTED]", "TOP SECRET", "EYES ONLY", "DENIED" }
	local function relocate(s: Stamp, t: number)
		s.t0 = t
		local a = rng:NextNumber() * TAU
		local r = 1.6 + rng:NextNumber() * 0.6
		s.att.Position = V(math.cos(a) * r, c.chestY + (rng:NextNumber() - 0.3) * 1.8, math.sin(a) * r)
		s.lbl.Text = words[rng:NextInteger(1, #words)]
		s.lbl.Rotation = (rng:NextNumber() - 0.5) * 30
	end
	for i = 1, 3 do
		local att, lbl, gui = B.glyph(c, "CLASSIFIED", red, V2(2, 0.5), F.tech)
		lbl.TextStrokeTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = red
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = lbl
		local s: Stamp = { att = att, gui = gui, lbl = lbl, stroke = stroke, t0 = 0 }
		relocate(s, os.clock() - i * 0.9)
		stamps[i] = s
	end
	-- reality tears: black core polyline over a wider red glowing edge
	type Tear = {
		core: B.Poly,
		edge: B.Poly,
		a: number,
		h: number,
		y0: number,
		r: number,
		off: number,
		base: { Vector3 },
	}
	local tears: { Tear } = {}
	for k = 1, 5 do
		local big = k == 5
		local a = if big then math.pi / 2 else (k - 1) / 4 * TAU + math.pi / 4
		local r = if big then 2.2 else 2.6
		local h = if big then 6 else 2.6 + rng:NextNumber()
		local y0 = c.groundY + (if big then 0.2 else 0.6 + rng:NextNumber())
		local pts = {}
		for j = 0, 6 do
			table.insert(pts, V(math.cos(a) * r, y0 + j / 6 * h, math.sin(a) * r))
		end
		tears[k] = {
			edge = B.poly(c, pts, red, 0.5, { segs = 1, bright = 3 }),
			core = B.poly(c, pts, BLACK, 0.3, { segs = 1, light = 0, zoff = 0.05 }),
			a = a,
			h = h,
			y0 = y0,
			r = r,
			off = rng:NextNumber() * 4,
			base = pts,
		}
	end
	type Cens = { att: Attachment, frames: { Frame }, a: number, y: number }
	local cens: { Cens } = {}
	for i = 1, 4 do
		local att = Core.att(c)
		local gui = Core.glyph(c, att, "", WHITE, V2(1.4, 0.6))
		local frames = {}
		for j = 1, 3 do
			local f =
				Core.frame(gui, Color3.fromRGB(4, 4, 4), UDim2.fromScale(0, (j - 1) * 0.34), UDim2.fromScale(0.8, 0.24))
			local st = Instance.new("UIStroke")
			st.Color = red
			st.Thickness = 1
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Parent = f
			frames[j] = f
		end
		cens[i] = { att = att, frames = frames, a = (i - 1) / 4 * TAU, y = c.groundY + 1.2 + i * 0.6 }
	end
	local g = c.groundY
	local disc = Core.part(c, V(0.04, 5.6, 5.6), Color3.fromRGB(4, 2, 3), SMOOTH, 0, CYL)
	local stampFloor = Core.part(c, V(3.6, 0.02, 3.6), BLACK, SMOOTH, 1)
	local fsg = Core.surface(stampFloor, Enum.NormalId.Top, 60)
	local fl = Core.label(fsg, "[REDACTED]", red, F.tech, UDim2.fromScale(0, 0.4), UDim2.fromScale(1, 0.2))
	fl.TextTransparency = 0.25
	B.ring(c, {
		n = 20,
		gap = 5,
		radius = 2.8,
		seg = V(0.08, 0.05, 0),
		color = red,
		spin = 0.4,
		anchor = function()
			return CF(0, g + 0.05, 0)
		end,
	})
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
	local sky = Core.att(c, c.root, CF(0, c.topY + 5, 0))
	Core.emit(sky, {
		tex = T.square,
		color = cs(Color3.fromRGB(8, 8, 8)),
		size = ns(0.25, 0.15),
		rate = 10,
		life = nr(1.4, 2),
		speed = nr(2, 4),
		spread = V2(40, 40),
		dir = Enum.NormalId.Bottom,
		rotSpeed = nr(-200, 200),
		light = 0,
	})
	local torso = Core.att(c, c.torso)
	Core.emit(torso, {
		tex = T.fireSpark,
		color = cs(red, WHITE),
		size = ns(0.2, 0),
		rate = 12,
		life = nr(0.5, 1),
		speed = nr(2, 5),
		spread = V2(180, 180),
		bright = 2.5,
	})
	Core.emit(torso, {
		tex = T.vortex,
		color = cs(red),
		size = ns(4, 6.5),
		transp = ns(0.75, 1),
		rate = 1.5,
		life = nr(1, 1.4),
		rotSpeed = nr(100, 160),
		locked = true,
	})
	Core.emit(Core.att(c, c.root, CF(0, g + 0.2, 0)), {
		tex = T.smoke,
		color = cs(BLACK),
		size = ns(1.5, 3.5),
		transp = ns(0.45, 1),
		rate = 6,
		life = nr(2, 3),
		speed = nr(0.4, 1),
		spread = V2(80, 80),
		light = 0,
		rotSpeed = nr(-30, 30),
	})
	local light = Core.light(torso, red, 2.4, 15)
	local nextC = 0
	Core.on(c, function(t, _, root)
		if rng:NextNumber() < 0.02 then
			burstUntil = t + 0.12
		end
		ox = if t < burstUntil then (rng:NextNumber() - 0.5) * 0.6 else 0
		for i, b in bars do
			if rng:NextNumber() < 0.003 then
				b.y = c.groundY + 0.6 + rng:NextNumber() * (c.topY - c.groundY + 0.8)
			end
			local a = b.a + t * b.w
			local cf = root
				* outward(a, b.r, b.y + math.sin(t * 1.3 + i) * 0.15)
				* ANG(0, 0, b.tilt + math.sin(t * 0.7 + i) * 0.1)
			Core.put(b.p, cf)
			Core.put(b.edge, cf * CF(0, -0.2, 0))
		end
		local hcf = c.head.CFrame * CF(0, 0.1, -c.head.Size.Z / 2 - 0.04)
		Core.put(faceBar, hcf)
		Core.put(faceEdge, hcf * CF(0, -0.155, 0))
		for _, s in stamps do
			local age = t - s.t0
			if age > 2.6 then
				relocate(s, t)
				age = 0
			end
			local sc = if age < 0.12 then 2.2 - age / 0.12 * 1.2 else 1
			local fade = math.clamp((age - 2.2) / 0.4, 0, 1)
			local appear = math.clamp(age / 0.12, 0, 1)
			s.gui.Size = UDim2.new(2 * sc, 0, 0.5 * sc, 0)
			local tr = math.max(1 - appear, fade)
			s.lbl.TextTransparency = tr
			s.stroke.Transparency = tr
		end
		for _, tr in tears do
			local ph = ((t + tr.off) % 4) / 4
			local open = math.sin(math.clamp(ph / 0.7, 0, 1) * math.pi)
			if ph > 0.95 and rng:NextNumber() < 0.2 then
				for j = 2, #tr.base - 1 do
					local jit = V((rng:NextNumber() - 0.5) * 0.5, 0, (rng:NextNumber() - 0.5) * 0.5)
					tr.core.atts[j].Position = tr.base[j] + jit
					tr.edge.atts[j].Position = tr.base[j] + jit
				end
			end
			for j, bm in tr.core.beams do
				local env = math.sin((j - 0.5) / #tr.core.beams * math.pi)
				bm.Width0 = 0.3 * open * env
				bm.Width1 = 0.3 * open * env
				local eb = tr.edge.beams[j]
				eb.Width0 = (0.3 * open * env + 0.14) * (if open > 0.02 then 1 else 0)
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
			ce.att.Position = V(math.cos(a) * 2.2, ce.y + math.sin(t + i) * 0.15, math.sin(a) * 2.2)
		end
		Core.put(disc, root * CF(0, g + 0.02, 0) * FLAT)
		Core.put(stampFloor, root * CF(0, g + 0.06, 0) * ANG(0, t * 0.2, 0))
		light.Brightness = if t < burstUntil then 6 else 2 + math.noise(t * 3, 2) * 1.2
	end)
end

return A
