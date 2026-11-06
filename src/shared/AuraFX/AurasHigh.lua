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
local Sync = require(script.Parent.Sync)

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
-- parts ~70, emitters 8
-- Synced to the Blender animation (tools/blender/anim/auras/Mainframe.py, grounded set, idle 5.0 s).
-- The body is the operator-machine; the racks obey it:
--   "scan" "L"|"R"   head servo snaps to a side  -> the racks on that side light every LED, status
--                                                 lights blaze, a scan laser leaves the eyes, sparks
--   "type" "R"|"L"   a fist taps the keyboard    -> the next rack (round robin) rewrites its LED row,
--                                                 fires a data pulse down its cable, hub sparks
--   "exec"           fist hammer + right stomp  -> EXECUTE: all five pulses fire at once, the racks
--                                                 kick outward, uplinks shoot to 3x height, a cyan shock
--                                                 ring from the right foot, sigil disc + light flash
--   "vent"           the exhale                 -> coolant steam + sparks burst from the back hub
--   "step" (free)    each heavy footfall        -> a small shock ring from that foot, the racks dip
--   "land" (free)    landing (body: "thud")     -> a big shock ring, the racks slam down
--   "overload" (VFX -> body, every 15-22 s standing still): LEDs flicker red, OVERLOAD title; the
--               body's reaction glitches, its "down" marker blacks everything out (LEDs, uplinks,
--               pulses, light), "reboot" -> white flash, LEDs come back green, REBOOT OK.
-- Cable data waves: Sync.phase(bus, 5.0) * 3 = three staggered waves per idle loop.
A.Mainframe = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
	local IDLE = 5.0
	local shell = Color3.fromRGB(10, 16, 26)
	local green = Color3.fromRGB(80, 255, 140)
	local amber = Color3.fromRGB(255, 176, 32)
	local red = Color3.fromRGB(255, 40, 50)
	local hot = WHITE:Lerp(c.c1, 0.3)
	local ledCols = { c.c1, green, amber, Color3.fromRGB(20, 30, 40) }
	local NR, RR = 5, 4.4
	local RW, RH, RD = 1.3, 2.5, 0.7
	local PULSE_DUR = 1.1
	type Rack = {
		body: BasePart,
		bars: { BasePart },
		leds: { BasePart },
		status: BasePart,
		a0: Attachment,
		a0n: Attachment,
		up0: Attachment,
		up1: Attachment,
		uplink: Beam,
		pulse: BasePart,
		pT: number, -- launch time of the data pulse riding the cable
		pDur: number,
		flash: number, -- LEDs blaze until this time
		ang: number,
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
		Core.beam(
			c,
			a0,
			hubAtt,
			Color3.fromRGB(16, 22, 30),
			0.2,
			{ light = 0, bright = 1, c0 = 1.6, c1 = 1.6, segs = 16 }
		)
		Core.beam(
			c,
			a0n,
			hubAtt,
			c.c1,
			0.08,
			{ c0 = 1.6, c1 = 1.6, segs = 16, tex = T.square, texLen = 0.4, texSpeed = 3, zoff = 0.02 }
		)
		-- data uplink column above every rack
		local uplink = Core.beam(
			c,
			up0,
			up1,
			c.c1,
			0.35,
			{ w1 = 0.05, tr = ns(0.25, 1), tex = T.square, texLen = 0.8, texSpeed = 4, segs = 2 }
		)
		racks[i] = {
			body = body,
			bars = {
				Core.part(c, V(RW + 0.06, 0.09, RD + 0.06), c.c1),
				Core.part(c, V(RW + 0.06, 0.09, RD + 0.06), c.c1),
			},
			leds = leds,
			status = Core.part(c, V(0.14, 0.14, 0.05), c.c1),
			a0 = a0,
			a0n = a0n,
			up0 = up0,
			up1 = up1,
			uplink = uplink,
			pulse = Core.part(c, V(0.3, 0.3, 0.3), WHITE, NEON, 0, BALL),
			pT = -math.huge,
			pDur = PULSE_DUR,
			flash = 0,
			ang = 0,
		}
	end
	local hub = Core.part(c, V(0.9, 0.7, 0.3), Color3.fromRGB(20, 26, 36), METAL)
	local hubStrip = Core.part(c, V(0.8, 0.08, 0.32), c.c1)
	local sig = B.sigil(
		c,
		{
			radius = 5.6,
			color = c.c1,
			color2 = c.c2:Lerp(c.c1, 0.5),
			ticks = 16,
			spokes = 5,
			glow = 0.9,
			spin = 0.2,
			pulse = 2.6,
		}
	)
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
	-- coolant vent (the "vent" exhale)
	local steam = Core.emit(back, {
		tex = T.glow,
		color = cs(WHITE, c.c1),
		size = ns(0.6, 2.6),
		transp = ns(0.35, 1),
		rate = 0,
		life = nr(0.7, 1.2),
		speed = nr(4, 7),
		spread = V2(25, 25),
		drag = 2.5,
		accel = V(0, 3, 0),
		dir = Enum.NormalId.Back,
	})
	local ventSparks = Core.emit(back, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0.45, 0),
		rate = 0,
		life = nr(0.3, 0.6),
		speed = nr(6, 10),
		spread = V2(40, 40),
		drag = 3,
		dir = Enum.NormalId.Back,
		bright = 3,
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
	local floorFx = B.floorEmit(c, 5, {
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
	local light = B.rootLight(c, c.c1, 2.4, 16, { pulse = 1.6, amp = 1.2 })
	-- body anchors: scan laser from the eyes, shock rings from the feet
	local headTip = Core.tip(c, "head")
	local feet = { R = Core.tip(c, "rfoot"), L = Core.tip(c, "lfoot") }
	local headFx = headTip
		and Core.emit(headTip, {
			tex = T.square,
			color = cs(WHITE, c.c1),
			size = ns(0.2, 0),
			rate = 0,
			life = nr(0.2, 0.4),
			speed = nr(5, 9),
			spread = V2(25, 25),
			dir = Enum.NormalId.Front,
			drag = 3,
			rot = nr(0, 0),
			bright = 3,
		})
	local laser = Core.part(c, V(0.07, 0.07, 5), c.c1, NEON, 1)
	-- pooled shock rings on the floor (stomps / steps / landing)
	type Shock = { t0: number, k: number, at: Vector3 }
	local shocks: { Shock } = {}
	for i = 1, 3 do
		local s: Shock = { t0 = -math.huge, k = 1, at = V(0, c.groundY + 0.06, 0) }
		local cir = B.circle(c, {
			radius = 0.3,
			color = c.c1,
			color2 = WHITE,
			width = 0.3,
			tr = 1,
			n = 6,
			anchor = function()
				return CF(s.at)
			end,
			radiusFn = function()
				local age = os.clock() - s.t0
				return 0.3 + (1 - math.exp(-age * 5)) * 6 * s.k
			end,
		})
		Core.on(c, function(t)
			local age = t - s.t0
			B.setBeamsTransparency(cir.beams, if age > 0.8 then 1 else 0.05 + (age / 0.8) ^ 2 * 0.95)
		end)
		shocks[i] = s
	end
	local nextShock = 1
	local function shock(k: number, att: Attachment?)
		local s = shocks[nextShock]
		nextShock = nextShock % #shocks + 1
		s.t0 = os.clock()
		s.k = k
		local x, z = 0, 0
		if att and att.Parent then
			local p = c.root.CFrame:PointToObjectSpace(att.WorldPosition)
			x, z = p.X, p.Z
		end
		s.at = V(x, c.groundY + 0.06, z)
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, name, fn))
	end
	local function launch(r: Rack, dur: number)
		r.pT = os.clock()
		r.pDur = dur
	end
	onEv("scan", function(side)
		local now = os.clock()
		for _, r in racks do
			-- root-local x of the rack = RR * cos(angle); the character's left is -X
			local left = math.cos(r.ang) < 0
			if left == (side == "L") then
				r.flash = now + 0.4
			end
		end
		if headFx then
			headFx:Emit(10)
		end
	end)
	local typeIdx = 0
	onEv("type", function()
		typeIdx = typeIdx % NR + 1
		local r = racks[typeIdx]
		for _, led in r.leds do
			led.Color = ledCols[rng:NextInteger(1, 3)]
		end
		r.flash = os.clock() + 0.08
		launch(r, 0.7)
		hubE:Emit(2)
	end)
	onEv("exec", function()
		for _, r in racks do
			launch(r, 0.45)
			r.flash = os.clock() + 0.5
		end
		shock(1.3, feet.R)
		hubE:Emit(16)
		floorFx:Emit(30)
	end)
	onEv("vent", function()
		steam:Emit(22)
		ventSparks:Emit(14)
	end)
	onEv("step", function(side)
		shock(0.35, feet[side :: string])
	end)
	onEv("land", function(air)
		shock(math.clamp(0.8 + (tonumber(air) or 0) * 0.6, 0.8, 1.6), nil)
		hubE:Emit(10)
		floorFx:Emit(20)
	end)
	onEv("reboot", function()
		for _, r in racks do
			r.flash = os.clock() + 0.6
			for _, led in r.leds do
				led.Color = green
			end
		end
		hubE:Emit(20)
	end)
	-- VFX -> body: the system overloads now and then while the operator stands still
	local nextOverload = os.clock() + 15 + rng:NextNumber() * 7
	local nextLed = 0
	local ledOff = { -0.75, -0.25, 0.25, 0.75 }
	local lastWave = Sync.phase(bus, IDLE) * 3
	Core.on(c, function(t, _, root)
		local now = os.clock()
		local still = Sync.get(bus, "move") < 0.1 and Sync.get(bus, "air") < 0.1
		if now >= nextOverload then
			if still then
				Sync.emit(bus, "overload")
				nextOverload = now + 15 + rng:NextNumber() * 7
			else
				nextOverload = now + 2
			end
		end
		local sO, sD, sR = Sync.since(bus, "overload"), Sync.since(bus, "down"), Sync.since(bus, "reboot")
		local over = sO < sR and sO < 2.5
		local down = sD < sR and sD < 2.5
		local blink = t >= nextLed
		if blink then
			nextLed = t + (if over then 0.05 else 0.1)
		end
		local execE = Sync.env(bus, "exec", 3)
		local dip = Sync.env(bus, "step", 9) * 0.16 + Sync.env(bus, "land", 5) * 0.55
		local rebootE = Sync.env(bus, "reboot", 4)
		-- staggered cable waves on the shared idle beat (3 per loop)
		local wave = Sync.phase(bus, IDLE) * 3
		for i, r in racks do
			local off = (i - 1) / NR
			local w0, w1 = (lastWave - off) % 1, (wave - off) % 1
			if w1 < w0 and now - r.pT > r.pDur then
				launch(r, PULSE_DUR)
			end
		end
		lastWave = wave
		local hubWorld = c.torso.CFrame * CF(0, 0.1, c.torso.Size.Z / 2 + 0.16)
		Core.put(hub, hubWorld)
		Core.put(hubStrip, hubWorld)
		hubStrip.Color = if down then BLACK elseif over then red else c.c1
		local hubL = root:ToObjectSpace(hubWorld)
		hubAtt.CFrame = CFrame.fromMatrix(hubL.Position, Vector3.yAxis, Vector3.xAxis)
		for i, r in racks do
			local a = (i - 1) / NR * TAU + t * 0.3
			r.ang = a
			local rr = RR + execE * 1.1
			local cfL = outward(a, rr, c.chestY + 0.2 + math.sin(t * 0.9 + i) * 0.25 - dip)
			if over and not down then
				cfL *= CF(jitter(rng, 0.08)) -- the racks rattle
			end
			local cf = root * cfL
			Core.put(r.body, cf)
			Core.put(r.bars[1], cf * CF(0, RH / 2, 0))
			Core.put(r.bars[2], cf * CF(0, -RH / 2, 0))
			local flashing = now < r.flash
			for k, led in r.leds do
				Core.put(led, cf * CF(-0.08, ledOff[k], -RD / 2 - 0.01))
				if down then
					led.Color = BLACK
				elseif flashing then
					led.Color = hot
				elseif over then
					if blink then
						led.Color = if rng:NextNumber() < 0.6 then red else BLACK
					end
				elseif blink and rng:NextNumber() < 0.3 then
					led.Color = ledCols[rng:NextInteger(1, #ledCols)]
				end
			end
			Core.put(r.status, cf * CF(RW / 2 - 0.18, RH / 2 - 0.3, -RD / 2 - 0.02))
			r.status.Color = if over then red else c.c1
			r.status.Transparency = if down then 1 elseif flashing then 0 else (if math.sin(t * 6 + i) > 0 then 0 else 0.8)
			for _, bar in r.bars do
				bar.Color = if down then BLACK elseif over then red else c.c1:Lerp(WHITE, rebootE)
			end
			local backL = (cfL * CF(0, -0.5, RD / 2 + 0.01)).Position
			local m = CFrame.fromMatrix(backL, -Vector3.yAxis, Vector3.xAxis)
			r.a0.CFrame = m
			r.a0n.CFrame = m
			local topL = (cfL * CF(0, RH / 2 + 0.05, 0)).Position
			r.up0.Position = topL
			r.up1.Position = topL + V(0, 5 + math.sin(t * 2 + i) * 1.2 + execE * 10, 0)
			r.uplink.Enabled = not down
			-- data pulse riding the cable towards the hub
			local s = (now - r.pT) / r.pDur
			if s >= 1 and s < 1.5 then
				r.pT = -math.huge
				if r.pDur < 0.6 or rng:NextNumber() < 0.5 then
					hubE:Emit(4)
				end
			end
			if down or s < 0 or s >= 1 then
				r.pulse.Transparency = 1
			else
				local p = B.bez(backL, backL - V(0, 1.6, 0), hubL.Position - V(0, 1.6, 0), hubL.Position, s)
				Core.put(r.pulse, root * CF(p))
				r.pulse.Transparency = 1 - math.sin(s * math.pi)
				local sz = if r.pDur < 0.6 then 0.5 else 0.3
				r.pulse.Size = V(sz, sz, sz)
			end
		end
		-- scan laser out of the eyes while a scan is fresh
		local sw = Sync.window(bus, "scan", 0.3)
		if headTip and sw >= 0 then
			Core.put(laser, headTip.WorldCFrame * CF(0, -0.05, -2.9))
			laser.Transparency = 0.1 + sw * 0.9
		else
			laser.Transparency = 1
		end
		if sig.disc then
			sig.disc.Transparency = 0.9 - execE * 0.6
		end
		if down then
			light.Brightness = 0.2
		else
			light.Brightness += execE * 4 + rebootE * 3
		end
		if down then
			title.Text = if (t % 0.5) < 0.25 then "MAINFRAME://......" else "MAINFRAME://"
		elseif over then
			title.Text = if (t % 0.2) < 0.1 then "MAINFRAME://OVERLOAD" else "MAINFRAME://0VERL0AD"
		elseif sR < 1.2 then
			title.Text = "MAINFRAME://REBOOT OK"
		elseif Sync.since(bus, "exec") < 0.8 then
			title.Text = "MAINFRAME://EXECUTE"
		else
			title.Text = if (t % 1) < 0.5 then "MAINFRAME://ONLINE_" else "MAINFRAME://ONLINE"
		end
	end)
end

-- electron orbit rings and superposition ghosts phasing
-- parts ~60, emitters 7
-- Synced to the Blender animation (tools/blender/anim/auras/Quantum.py, levitating set, lift 0.8
-- studs, idle 6.0 s). The ghosts swap sides on Sync.phase(bus, 6.0) (at 0 and 3 s of the loop).
--   "flick" "R"|"L"   a hand flings out          -> an electron quantum-jumps (flash at the old AND
--                                                  the new spot), sparks spray from that hand
--   "tunnel" "L"|"R"  CONST: the body is elsewhere -> a flash where the chest is now, the ghost on
--                                                  that side blazes
--   "collapse"        back home                   -> both ghosts snap visible then fade, the probability
--                                                  wave flares, a spark burst from the chest
--   "observe" "R"|"L" the head darts at a ghost   -> that ghost flashes solid and COLLAPSES (gone for
--                                                  ~0.6 s, then fades back in), a flash where it stood
--   "split"           arms snap into a wide T     -> SUPERPOSITION: both ghosts at full strength, all
--                                                  three electrons jump, the orbit rings swell 30 %,
--                                                  white flash, light surge
--   walk "tunnel" "w" / jump "blink"              -> a small flash at the chest (+ an electron jump)
-- Without any synced jump for 2.5 s (walking, airborne) an electron still jumps on a timer.
A.Quantum = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
	local IDLE = 6.0
	local OR = 4.6
	local cy = c.chestY + 0.3
	local curOR = OR
	local function orbit(k: number): (t: number) -> CFrame
		return function(t: number): CFrame
			return CF(0, cy, 0) * ANG(0, t * 0.25 + k * TAU / 3, 0) * ANG(1.15, 0, 0)
		end
	end
	local function swell(): number
		return 1 + Sync.env(bus, "split", 2.5) * 0.3
	end
	type El = { core: BasePart, shell: BasePart, k: number, skip: number }
	local els: { El } = {}
	for k = 1, 3 do
		local col = if k == 2 then c.c2 else c.c1
		B.circle(c, {
			radius = OR,
			color = col,
			width = 0.13,
			tr = 0.1,
			anchor = orbit(k),
			n = 10,
			radiusFn = function()
				return OR * swell()
			end,
		})
		B.circle(c, {
			radius = OR + 0.3,
			color = c.c1:Lerp(c.c2, 0.5),
			width = 0.04,
			tr = 0.55,
			anchor = orbit(k),
			n = 10,
			radiusFn = function()
				return (OR + 0.3) * swell()
			end,
		})
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
	B.sigil(c, { radius = 6, color = c.c1, color2 = c.c2, rings = 2, glow = 0.9, pulse = 3.0 })
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
	local torsoSparks = Core.emit(torso, {
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
	local light = B.rootLight(c, c.c1, 2.2, 16, { pulse = 2, amp = 1.4 })
	-- hand sparks for the flicks
	local handSpark: Core.EmitSpec = {
		tex = T.spark,
		color = cs(WHITE, c.c1, c.c2),
		size = ns(0.4, 0),
		rate = 0,
		life = nr(0.25, 0.5),
		speed = nr(6, 11),
		spread = V2(30, 30),
		drag = 3,
		dir = Enum.NormalId.Bottom,
		bright = 3,
	}
	local hands: { [string]: ParticleEmitter } = {}
	local handNames: { [string]: string } = { R = "rhand", L = "lhand" }
	for key, name in handNames do
		local tip = Core.tip(c, name)
		if tip then
			hands[key] = Core.emit(tip, handSpark)
		end
	end
	local chestTip = Core.tip(c, "chest")

	local function flashAt(pRoot: Vector3, n: number)
		jumpAtt.Position = pRoot
		flashA:Emit(1)
		flashB:Emit(n)
	end
	local function elPos(e: El, t: number): Vector3
		local th = t * 3.2 + e.k * 2 + e.skip
		return (orbit(e.k)(t) * CF(math.cos(th) * curOR, 0, math.sin(th) * curOR)).Position
	end
	local lastJump = 0
	local function jump(e: El)
		local t = os.clock()
		lastJump = t
		flashAt(elPos(e, t), 6)
		e.skip += math.pi * (0.6 + rng:NextNumber() * 0.8)
		flashAt(elPos(e, t), 6)
	end
	local function chestFlash(n: number)
		if chestTip and chestTip.Parent then
			flashAt(c.root.CFrame:PointToObjectSpace(chestTip.WorldPosition), n)
		end
	end
	-- ghost state: a = the ForceField ghost (+X side when side = 1), b = the neon ghost
	local boost = { a = -math.huge, b = -math.huge }
	local gone = { a = -math.huge, b = -math.huge }
	local function ghostOn(s: string): string
		-- which ghost stands on the character's right ("R") / left ("L") right now
		return if (s == "R") == (side == 1) then "a" else "b"
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, name, fn))
	end
	onEv("flick", function(arg)
		local h = hands[arg :: string]
		if h then
			h:Emit(16)
		end
		jump(els[rng:NextInteger(1, 3)])
	end)
	onEv("tunnel", function(arg)
		if arg == "w" then
			chestFlash(4)
			return
		end
		boost[ghostOn(arg :: string)] = os.clock()
		chestFlash(8)
	end)
	onEv("collapse", function()
		boost.a, boost.b = os.clock(), os.clock()
		torsoSparks:Emit(20)
	end)
	onEv("observe", function(arg)
		local g = ghostOn(arg :: string)
		gone[g] = os.clock()
		flashAt(V((if arg == "R" then 2.6 else -2.6), c.chestY, 0.4), 10)
	end)
	onEv("split", function()
		boost.a, boost.b = os.clock(), os.clock()
		for _, e in els do
			jump(e)
		end
		chestFlash(16)
		torsoSparks:Emit(24)
	end)
	onEv("blink", function()
		chestFlash(8)
		jump(els[rng:NextInteger(1, 3)])
	end)
	-- ghost transparency: base breathing, boosted by tunnels / split, or collapsed by observation
	local function ghostTr(g: string, base: number, now: number): number
		local sg = now - gone[g]
		if sg < 0.12 then
			return 0.05 -- the measured state flashes solid...
		elseif sg < 0.7 then
			return 1 -- ...and collapses
		elseif sg < 1.2 then
			return 1 - (1 - base) * (sg - 0.7) / 0.5
		end
		local b = math.exp(-(now - boost[g]) * 3)
		return base + (0.08 - base) * b
	end
	Core.on(c, function(t, _, root)
		local now = os.clock()
		side = if Sync.phase(bus, IDLE) < 0.5 then 1 else -1
		curOR = OR * swell()
		-- fallback quantum jumps when no clip drives them (walking, airborne)
		if now - lastJump > 2.5 + rng:NextNumber() * 0.5 then
			jump(els[rng:NextInteger(1, 3)])
		end
		for _, e in els do
			local cf = root * CF(elPos(e, t))
			Core.put(e.core, cf)
			local s = 1.05 + Core.pulse(t, 0.6, e.k / 3) * 0.3
			e.shell.Size = V(s, s, s)
			Core.put(e.shell, cf)
		end
		local w = 0.5 + 0.5 * math.sin(t * 2)
		local trA = ghostTr("a", w * 0.9, now)
		local trB = ghostTr("b", 0.7 + (1 - w) * 0.3, now)
		for _, p in ga do
			p.Transparency = trA
		end
		for _, p in gb do
			p.Transparency = trB
		end
		local wf = Sync.env(bus, "collapse", 4) + Sync.env(bus, "split", 3)
		for k, p in wave do
			p.Transparency = math.max(0, 0.5 + 0.5 * math.sin(t * 4 + k * 0.9) - wf)
		end
		Core.put(nucleus, root * CF(0, yA + math.sin(t * 1.4) * 0.12, 0))
		light.Brightness += Sync.env(bus, "split", 3) * 4 + Sync.env(bus, "tunnel", 8) * 1.5
	end)
end

-- orange heat haze, lightning arcs, fan-blade halo spinning fast
-- parts ~63, emitters 13
-- Synced to the Blender animation (tools/blender/anim/auras/Overclocked.py, grounded set, idle 4.0 s
-- = one thermal cycle). The heat model (TEMP readout, fan speed, light) is driven by the body:
--   "rev"           crouch, fists to the chest  -> the back fan spins up, heat climbs
--   "stomp" "L"     the left foot slams down    -> fire shock ring + floor fire from that foot
--   "surge"         arms thrown up in a V       -> arcs leap from both fists, blades flash white-hot,
--                                                  light surge, spark bursts, TEMP jumps
--   "crackle"       CONST shake frames          -> fresh arc bursts from the fists
--   "throttle"      hand slaps the forehead     -> THROTTLING!, the fan stalls, the light browns out
--   "vent"          the hand fans the face      -> both back vents blast fire + smoke
--   "reboot"        2-frame stiff boot pose     -> fan / blades black out, TEMP "REBOOT", then restart
--   walk "step"     each footfall               -> sparks + a fire puff from that foot, heat rises
--   "zap"           (VFX -> body, every 6-10 s) -> a white arc strikes the chest from the fan; the
--                                                  body's "zap" clip electrocutes it, its "jolt"
--                                                  marker sprays sparks from both hands
--   "quake"         ("slam" clip on "land")     -> big fire shock ring + floor fire burst
-- The sigil breathes on Sync.phase(bus, 4.0) (the idle loop) and flashes on surge / quake.
A.Overclocked = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
	local IDLE = 4.0
	local FR = 2.7
	local g = c.groundY
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
	local bladeCol: { Color3 } = {}
	for i = 1, 9 do
		bladeCol[i] = c.c1:Lerp(c.c2, (i % 3) / 4)
		blades[i] = Core.part(c, V(0.7, FR * 0.82, 0.06), bladeCol[i], NEON, 0.1)
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
	local sig = B.sigil(c, {
		radius = 5.4,
		color = c.c1,
		color2 = c.c2,
		ticks = 16,
		tickSize = V(0.35, 0.07, 0.22),
		spin = 1.4,
		glow = 0.88,
	})
	local torso = Core.att(c, c.torso)
	local smoke = Core.emit(torso, {
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
	local ventR = Core.emit(Core.att(c, c.torso, CF(sx, sy, 0.4)), vent)
	local ventL = Core.emit(Core.att(c, c.torso, CF(-sx, sy, 0.4)), vent)
	local torsoSparks = Core.emit(torso, {
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
	local floorFire = B.floorEmit(c, 4.5, {
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
	local _, temp =
		B.glyph(c, "TEMP 97C", c.c2, V2(2.8, 0.5), F.pixel, CF(0, c.topY + 1.6, 0), Color3.fromRGB(80, 20, 0))
	local light = B.rootLight(c, c.c1, 2.6, 17)

	-- ---------------------------------------------------------- body sync
	local hands: { [string]: Attachment? } = { R = Core.tip(c, "rhand"), L = Core.tip(c, "lhand") }
	local feet: { [string]: Attachment? } = { R = Core.tip(c, "rfoot"), L = Core.tip(c, "lfoot") }
	local sparkSpec: Core.EmitSpec = {
		tex = T.fireSpark,
		color = cs(WHITE, c.c2, c.c1),
		size = ns(0.35, 0),
		rate = 0,
		life = nr(0.3, 0.7),
		speed = nr(5, 11),
		spread = V2(180, 180),
		accel = V(0, -10, 0),
		bright = 3,
	}
	local puffSpec: Core.EmitSpec = {
		tex = T.fire,
		color = cs(c.c2, c.c1, Color3.fromRGB(120, 30, 0)),
		size = ns(0.9, 0.2),
		transp = ns(0.3, 1),
		rate = 0,
		life = nr(0.25, 0.5),
		speed = nr(2, 4),
		spread = V2(70, 70),
		dir = Enum.NormalId.Top,
		accel = V(0, 5, 0),
	}
	local handFx: { [string]: ParticleEmitter } = {}
	local footFx: { [string]: ParticleEmitter } = {}
	local footPuff: { [string]: ParticleEmitter } = {}
	for side, a in hands do
		if a then
			handFx[side] = Core.emit(a, sparkSpec)
		end
	end
	for side, a in feet do
		if a then
			footFx[side] = Core.emit(a, sparkSpec)
			footPuff[side] = Core.emit(a, puffSpec)
		end
	end
	local function local3(a: Attachment?, fallback: Vector3): Vector3
		if not a then
			return fallback
		end
		return c.root.CFrame:PointToObjectSpace(a.WorldPosition)
	end
	-- arcs leaping out of the fists while the surge / crackle / jolt lasts
	local function arcsOn(): boolean
		return Sync.since(bus, "surge") < 0.55 or Sync.since(bus, "crackle") < 0.16 or Sync.since(bus, "jolt") < 0.3
	end
	for k = 1, 4 do
		local side = if k % 2 == 1 then "R" else "L"
		local sx0 = if side == "R" then 1.5 else -1.5
		B.bolt(c, {
			segs = 6,
			color = WHITE,
			color2 = c.c2,
			width = 0.14,
			jitter = 0.55,
			interval = 0.045,
			flicker = 0.15,
			active = arcsOn,
			ends = function()
				local h = local3(hands[side], V(sx0, c.chestY - 1, 0))
				local out = V(math.sign(h.X + 1e-3) * (1.5 + rng:NextNumber() * 2), 1.2 + rng:NextNumber() * 2.5, (rng:NextNumber() - 0.5) * 3)
				return h, h + out
			end,
		})
	end
	-- the zap: a white arc from the fan rim into the chest (VFX -> body reaction)
	B.bolt(c, {
		segs = 8,
		color = WHITE,
		color2 = c.c2,
		width = 0.22,
		jitter = 0.5,
		interval = 0.035,
		active = function()
			return Sync.since(bus, "zap") < 0.28
		end,
		ends = function()
			local a = rng:NextNumber() * TAU
			return (fanL * CF(math.cos(a) * FR, math.sin(a) * FR, 0)).Position, V(0, c.chestY + 0.2, -0.3)
		end,
	})
	-- fire shock ring on the floor (stomp / landing quake), one reusable beam circle
	local shockT, shockMax, shockDur = -math.huge, 5, 0.5
	local shockPos = V(0, g + 0.06, 0)
	local shock = B.circle(c, {
		radius = 0.6,
		color = c.c2,
		color2 = c.c1,
		width = 0.4,
		n = 10,
		bright = 3,
		anchor = function()
			return CF(shockPos)
		end,
		radiusFn = function(t)
			return 0.6 + smooth01((t - shockT) / shockDur) * shockMax
		end,
	})
	B.setBeamsTransparency(shock.beams, 1)
	local function quake(at: Vector3, size: number, n: number)
		shockPos = V(at.X, g + 0.06, at.Z)
		shockT, shockMax, shockDur = os.clock(), size, 0.35 + size * 0.04
		floorFire:Emit(n)
	end
	-- heat model: the body heats the rig, the readout shows it
	local heat = 92
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, name, fn))
	end
	onEv("rev", function()
		heat += 4
		smoke:Emit(4)
	end)
	onEv("stomp", function(side)
		heat += 2
		local s = if side == "R" then "R" else "L"
		quake(local3(feet[s], V(if s == "R" then 0.5 else -0.5, g, 0)), 4.5, 26)
		if footFx[s] then
			footFx[s]:Emit(24)
		end
	end)
	onEv("surge", function()
		heat += 14
		torsoSparks:Emit(50)
		for _, e in handFx do
			e:Emit(30)
		end
		ventR:Emit(20)
		ventL:Emit(20)
	end)
	onEv("crackle", function()
		heat += 2
		for _, e in handFx do
			e:Emit(12)
		end
	end)
	onEv("vent", function()
		heat -= 4
		ventR:Emit(28)
		ventL:Emit(28)
		smoke:Emit(6)
	end)
	onEv("reboot", function()
		heat = 84
		torsoSparks:Emit(20)
	end)
	onEv("step", function(side)
		heat += 0.35
		local s = if side == "R" then "R" else "L"
		if footFx[s] then
			footFx[s]:Emit(8)
		end
		if footPuff[s] then
			footPuff[s]:Emit(4)
		end
	end)
	onEv("zap", function()
		heat += 6
		torsoSparks:Emit(24)
	end)
	onEv("jolt", function()
		for _, e in handFx do
			e:Emit(20)
		end
	end)
	onEv("quake", function()
		quake(V(0, g, 0), 7, 45)
		for _, e in footFx do
			e:Emit(16)
		end
	end)
	local nextZap = os.clock() + 4 + rng:NextNumber() * 4
	local fanAng, fanSpd = 0, 24
	Core.on(c, function(t, dt, root)
		if t >= nextZap then
			nextZap = t + 6 + rng:NextNumber() * 4
			Sync.emit(bus, "zap")
		end
		local throttling = Sync.window(bus, "throttle", 1.1) >= 0
		local rebooting = Sync.since(bus, "reboot") < 0.12
		local surge = Sync.env(bus, "surge", 4)
		-- fan: spins up on rev / surge, stalls while throttling, restarts after the reboot
		local target = 24 + 30 * Sync.env(bus, "rev", 1.4) + 40 * Sync.env(bus, "surge", 2)
		if throttling then
			target = 3
		end
		fanSpd += (target - fanSpd) * (1 - math.exp(-dt * 6))
		fanAng += fanSpd * dt
		local fan = root * fanL
		local hot = math.max(surge, Sync.env(bus, "zap", 6))
		for i, b in blades do
			Core.put(b, fan * ANG(0, 0, fanAng + (i - 1) / 9 * TAU) * CF(0, FR * 0.5, 0) * ANG(0, 0.5, 0))
			b.Color = bladeCol[i]:Lerp(WHITE, hot)
			b.Transparency = if rebooting then 1 else 0.1
		end
		Core.put(hubP, fan * AXIS_Z)
		Core.put(blur, fan * AXIS_Z * CF(0.03, 0, 0))
		blur.Transparency = if rebooting then 1 else 0.93 - math.clamp(fanSpd / 60, 0, 1) * 0.1
		-- heat drifts to its working temperature (hotter while running), body events kick it
		heat += (90 + 12 * Sync.get(bus, "move") - heat) * (1 - math.exp(-dt * 0.35))
		local deg = heat + math.noise(t * 0.8, 4) * 3
		if rebooting or Sync.since(bus, "reboot") < 0.4 then
			temp.Text = "REBOOT..."
			temp.TextColor3 = WHITE
		elseif throttling or deg > 110 then
			temp.Text = if math.sin(t * 20) > 0 then "THROTTLING!" else string.format("TEMP %dC", math.floor(deg))
			temp.TextColor3 = Color3.fromRGB(255, 40, 30)
		else
			temp.Text = string.format("TEMP %dC", math.floor(deg))
			temp.TextColor3 = c.c2:Lerp(Color3.fromRGB(255, 60, 30), math.clamp((deg - 92) / 18, 0, 1))
		end
		-- light: flicker, browns out while throttling, surges on the big moments
		local b = 2 + rng:NextNumber() * 2.2
		if throttling then
			b *= 0.35
		end
		light.Brightness = b + surge * 6 + Sync.env(bus, "zap", 7) * 4 + Sync.env(bus, "quake", 5) * 4
		-- sigil breathes with the idle loop, flashes on surge / quake / stomp
		local br = 0.5 - 0.5 * math.cos(Sync.phase(bus, IDLE) * TAU)
		local flash = math.max(surge, Sync.env(bus, "quake", 4), Sync.env(bus, "stomp", 6) * 0.6)
		for k, cir in sig.circles do
			B.setBeamsTransparency(cir.beams, math.clamp((if k == 1 then 0.05 else 0.3) + br * 0.35 - flash * 0.35, 0, 1))
		end
		-- shock ring fade
		local sp = (t - shockT) / shockDur
		B.setBeamsTransparency(shock.beams, if sp >= 1 then 1 else 0.05 + sp * sp * 0.95)
	end)
end

-- glowing neuron web around the head with synapse sparks
-- parts ~54, emitters 9
-- Synced to the Blender animation (tools/blender/anim/auras/NeuralLink.py, grounded set, idle 5.0 s
-- = one thought: fingers on the temple, the signal arrives, a thought forms, it is transmitted):
--   "receive"        head snaps up             -> synapse storm: every node flashes, spark burst from
--                                                 the head, the spine beams surge, the web kicks out
--   "twitch"         CONST aftershocks         -> a few random nodes flash, small spark puffs
--   "thought" lhand  palm flick                -> a thought orb forms over the left palm, two
--                                                 dendrites snap onto it and hold until "transmit"
--   "transmit"       arms fling open           -> the orb shoots out ahead, a cyan shock ring rolls
--                                                 out from the chest, the web expands, dendrites
--                                                 stretch, light surge
--   "link" rhand     fingers back on temple    -> a link beam flashes from the fingertips into the
--                                                 web, the head ring flares, the web settles
--   walk "step"      each footfall             -> the lowest nodes flash, cyan sparks from that foot
--   "overload"       (VFX -> body, 7-12 s)     -> the web charges toward cyan (synapses rush in);
--                                                 the body's "overload" clip bows and snaps the head,
--                                                 its "spike" marker -> every node flashes + big burst
-- The web radius, root light and sigil breathe on Sync.phase(bus, 5.0) (the idle loop).
A.NeuralLink = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
	local IDLE = 5.0
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
	local spine: { Beam } = {}
	for _, i in { 1, 2, 3, 4 } do
		table.insert(
			spine,
			Core.beam(
				c,
				atts[i],
				spineAtt,
				c.c2,
				0.12,
				{ w1 = 0.04, tex = T.square, texLen = 0.4, texSpeed = 3, tr = ns(0.15, 0.5) }
			)
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
	local headRing = B.ring(c, {
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
	local sig = B.sigil(c, { radius = 5.2, color = c.c1, color2 = c.c2, ticks = 12, spokes = 6, glow = 0.9, spin = 0.4 })
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
	local light = B.rootLight(c, c.c1, 2.4, 16, { y = c.headY })

	-- ---------------------------------------------------------- body sync
	local lhand, rhand = Core.tip(c, "lhand"), Core.tip(c, "rhand")
	local feet: { [string]: Attachment? } = { R = Core.tip(c, "rfoot"), L = Core.tip(c, "lfoot") }
	local cyanSpec: Core.EmitSpec = {
		tex = T.spark,
		color = cs(c.c2, WHITE),
		size = ns(0.45, 0),
		rate = 0,
		life = nr(0.3, 0.6),
		speed = nr(2, 4),
		spread = V2(70, 70),
		dir = Enum.NormalId.Top,
	}
	local footFx: { [string]: ParticleEmitter } = {}
	for side, a in feet do
		if a then
			footFx[side] = Core.emit(a, cyanSpec)
		end
	end
	-- the thought orb: pink core in a cyan shell, sparks while it is held
	local orb = Core.part(c, V(0.55, 0.55, 0.55), c.c1, NEON, 1, BALL)
	local shell = Core.part(c, V(0.95, 0.95, 0.95), c.c2, FF, 1, BALL)
	local orbAtt = Core.att(c)
	local orbFx = Core.emit(orbAtt, {
		tex = T.spark,
		color = cs(c.c2, c.c1),
		size = ns(0.3, 0),
		rate = 0,
		life = nr(0.3, 0.6),
		speed = nr(1, 2.5),
		spread = V2(180, 180),
	})
	-- transmit shock ring rolling out from the chest + spark burst
	local chestAtt = Core.att(c, c.torso)
	local chestFx = Core.emit(chestAtt, {
		tex = T.spark,
		color = cs(WHITE, c.c2, c.c1),
		size = ns(0.5, 0),
		rate = 0,
		life = nr(0.4, 0.8),
		speed = nr(10, 16),
		drag = 4,
		spread = V2(180, 25),
	})
	local wave = B.circle(c, {
		radius = 1,
		color = c.c2,
		color2 = c.c1,
		width = 0.3,
		n = 10,
		bright = 3,
		anchor = function()
			return CF(0, c.chestY, 0)
		end,
		radiusFn = function()
			return 1 + smooth01(Sync.since(bus, "transmit") / 0.6) * 8
		end,
	})
	B.setBeamsTransparency(wave.beams, 1)
	-- the link beam: fingertips -> the nearest node of the web
	local linkAtt = Core.att(c)
	local linkBeam: Beam? = nil
	if rhand then
		local lb = Core.beam(c, rhand, linkAtt, WHITE, 0.2, { color2 = c.c2, w1 = 0.06, segs = 6 })
		lb.Enabled = false
		linkBeam = lb
	end
	local function flashAll(t: number)
		for i = 1, N do
			flash[i] = t
		end
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, name, fn))
	end
	local holding = false
	local orbFrom = Vector3.zero
	onEv("receive", function()
		flashAll(os.clock())
		synE:Emit(30)
	end)
	onEv("twitch", function()
		local t = os.clock()
		for _ = 1, 4 do
			flash[rng:NextInteger(1, N)] = t
		end
		synE:Emit(6)
	end)
	onEv("thought", function()
		holding = true
		orbFx:Emit(14)
	end)
	onEv("transmit", function()
		holding = false
		chestFx:Emit(45)
		orbFx:Emit(20)
		flashAll(os.clock())
	end)
	onEv("link", function()
		synE:Emit(10)
	end)
	onEv("spike", function()
		flashAll(os.clock())
		synE:Emit(40)
		chestFx:Emit(16)
	end)
	onEv("step", function(side)
		local s = if side == "R" then "R" else "L"
		if footFx[s] then
			footFx[s]:Emit(7)
		end
		local t = os.clock()
		for i = 1, 3 do -- the lowest nodes of the web
			flash[i] = t
		end
	end)
	local nextOverload = os.clock() + 5 + rng:NextNumber() * 5
	local pos: { Vector3 } = table.create(N, Vector3.zero)
	local R = 3
	Core.on(c, function(t, _, root)
		if t >= nextOverload then
			nextOverload = t + 7 + rng:NextNumber() * 5
			Sync.emit(bus, "overload")
		end
		local rot = ANG(0, t * 0.3, 0)
		local breath = 0.5 - 0.5 * math.cos(Sync.phase(bus, IDLE) * TAU)
		local kick = Sync.env(bus, "receive", 5) * 0.55 + Sync.env(bus, "spike", 5) * 0.45
		local tx = Sync.since(bus, "transmit")
		local expand = if tx < 0.25 then smooth01(tx / 0.25) else math.exp(-(tx - 0.25) * 2.2)
		expand *= if tx == math.huge then 0 else 1.1
		local r = R + (breath - 0.5) * 0.3 + kick + expand - Sync.env(bus, "link", 6) * 0.25
		local charge = 0
		local ow = Sync.window(bus, "overload", 0.3)
		if ow >= 0 then
			charge = ow
		elseif Sync.since(bus, "overload") < 0.6 then
			charge = 1 - (Sync.since(bus, "overload") - 0.3) / 0.3
		end
		local hc = V(0, c.headY + 0.5, 0)
		for i = 1, N do
			local p = hc + rot:VectorToWorldSpace(dirs[i]) * r
			pos[i] = p
			atts[i].Position = p
			Core.put(nodes[i], root * CF(p))
			local f = math.max(0, 1 - (t - flash[i]) / 0.3)
			nodes[i].Color = c.c1:Lerp(c.c2, charge):Lerp(WHITE, f)
			local s = 0.42 + f * 0.25 + charge * 0.12
			nodes[i].Size = V(s, s, s)
		end
		-- spine beams surge on receive / spike
		local surge = math.max(Sync.env(bus, "receive", 3), Sync.env(bus, "spike", 3))
		for _, b in spine do
			b.Width0 = 0.12 + surge * 0.3
			b.TextureSpeed = 3 + surge * 9
		end
		-- dendrites: wander, stretch out on transmit, two of them grab the thought orb
		local hp = if lhand then root:PointToObjectSpace(lhand.WorldPosition) + V(0, 0.75, -0.25) else V(-1, c.chestY, -1.5)
		local stretch = 1 + expand * 0.35
		for i, d in dens do
			if holding and i <= 2 then
				d.tip.Position = hp
			else
				local a = d.a + t * 0.2 + math.sin(t * 0.7 + i) * 0.2
				d.tip.Position = V(math.cos(a) * d.r * stretch, d.y + math.sin(t * 1.1 + i) * 0.5, math.sin(a) * d.r * stretch)
			end
		end
		-- thought orb: grows on the palm, shoots forward on transmit and fades
		local th = Sync.since(bus, "thought")
		if holding and th > 1.2 then -- started walking before "transmit": let the thought go
			holding = false
		end
		if holding then
			local grow = smooth01(th / 0.3)
			orbFrom = hp
			Core.put(orb, root * CF(hp) * ANG(t * 2, t * 3, 0))
			Core.put(shell, root * CF(hp))
			orbAtt.Position = hp
			orb.Size = V(0.55, 0.55, 0.55) * (0.3 + grow * 0.7 + math.sin(t * 9) * 0.05)
			orb.Transparency = 0.05 + (1 - grow) * 0.9
			shell.Transparency = 0.35 + (1 - grow) * 0.65
		elseif tx < 0.45 then
			local f = tx / 0.45
			local p = orbFrom:Lerp(V(0, c.chestY + 0.5, -9), smooth01(f))
			Core.put(orb, root * CF(p))
			Core.put(shell, root * CF(p))
			orbAtt.Position = p
			orb.Transparency = 0.05 + f * 0.95
			shell.Transparency = 0.35 + f * 0.65
		else
			orb.Transparency = 1
			shell.Transparency = 1
		end
		-- transmit wave
		local wp = tx / 0.6
		B.setBeamsTransparency(wave.beams, if wp >= 1 then 1 else 0.05 + wp * wp * 0.95)
		-- link beam: fingertips -> nearest node
		local lk = Sync.since(bus, "link")
		local lb = linkBeam
		if lb and rhand then
			if lk < 0.45 then
				local fp = root:PointToObjectSpace(rhand.WorldPosition)
				local best, bd = 1, math.huge
				for i = 1, N do
					local d = (pos[i] - fp).Magnitude
					if d < bd then
						best, bd = i, d
					end
				end
				linkAtt.Position = pos[best]
				flash[best] = t
				lb.Enabled = true
				lb.Transparency = NumberSequence.new(lk / 0.45)
			elseif lb.Enabled then
				lb.Enabled = false
			end
		end
		-- head ring flares on link / receive
		local ringF = math.max(Sync.env(bus, "link", 4), Sync.env(bus, "receive", 4))
		for _, p in headRing do
			p.Color = c.c2:Lerp(WHITE, ringF)
		end
		-- light + sigil breathe with the idle loop, surge on the big moments
		local big = math.max(Sync.env(bus, "transmit", 3), kick, Sync.env(bus, "link", 5) * 0.5)
		light.Brightness = 1.8 + breath * 1.2 + big * 4
		for k, cir in sig.circles do
			B.setBeamsTransparency(cir.beams, math.clamp((if k == 1 then 0.05 else 0.3) + breath * 0.35 - big * 0.35, 0, 1))
		end
		-- synapses race along the links (twice as fast while an overload charges the web)
		local hop = 0.32 - charge * 0.16
		for _, sy in syns do
			local f = (t - sy.t0) / hop
			if f >= 1 then
				flash[sy.to] = t
				local opts = {}
				for _, l in links do
					if l[1] == sy.to then
						table.insert(opts, l[2])
					elseif l[2] == sy.to then
						table.insert(opts, l[1])
					end
				end
				sy.from = sy.to
				sy.to = if #opts > 0 then opts[rng:NextInteger(1, #opts)] else sy.from
				sy.t0 = t
				f = 0
				if rng:NextNumber() < 0.3 then
					synE:Emit(4)
				end
			end
			Core.put(sy.p, root * CF(pos[sy.from]:Lerp(pos[sy.to], math.min(f, 1))))
		end
	end)
end

-- hexagon shield plates orbiting, golden eye above
-- parts ~72, emitters 8
-- Synced to the Blender animation (tools/blender/anim/auras/Sentinel.py, grounded set, idle 6.0 s):
-- a guardian in a wide guard stance that scans the perimeter, stomps, crosses its arms in a block
-- and shoves the shield wall outward. The plates ARE the block: they only form the wall while the
-- arms hold it.
--   "scan" L/R  head snaps over a shoulder -> the golden eye stops staring at the camera and looks
--                                            the same way, a searchlight beam sweeps the floor there
--   "stomp"     right foot slams down      -> golden shock ring from the right foot, floor sparks,
--                                            the plates jolt up, eye light pops
--   "raise"     arms cross in a block      -> the plates leave the orbit and lock into a hexagon
--                                            wall in front of the body (held until "push")
--   "push"      arms thrust apart          -> the wall is shoved 3 studs out and dissolves back into
--                                            orbit, sparks burst from both palms, the eye flashes white
--   walk "step" (runner, each footfall)    -> small ring + sparks under that foot, the plates dip
--   "slam" (brace reaction on "land")      -> big shock ring, floor sparks, plates slam down, eye flash
A.Sentinel = function(c: Ctx)
	local bus = c.bus
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
	-- searchlight: eye -> a floor point that sweeps the scanned side
	local scanAtt = Core.att(c, nil, CF(0, c.groundY + 0.05, -4))
	local search = Core.beam(c, eyeAtt, scanAtt, gold, 0.15, { w1 = 2.4, color2 = c.c2, tr = ns(1), segs = 2 })
	local scanSpot = Core.emit(scanAtt, {
		tex = T.glow,
		color = cs(gold, c.c2),
		size = ns(2.4, 3.2),
		transp = ns(0.5, 1),
		rate = 18,
		life = nr(0.25, 0.35),
		locked = true,
	})
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
	B.sigil(
		c,
		{ radius = 5.6, color = gold, color2 = c.c2, ticks = 12, spokes = 6, glow = 0.9, spin = 0.3, pulse = 3 }
	)
	-- shock rings on the floor (pooled): stomp / slam / footsteps
	type Shock = { cir: any, t0: number, k: number, at: Vector3 }
	local shocks: { Shock } = {}
	for i = 1, 3 do
		local s: Shock = { cir = nil, t0 = -math.huge, k = 1, at = V(0, c.groundY + 0.06, 0) }
		s.cir = B.circle(c, {
			radius = 0.3,
			color = gold,
			color2 = c.c2,
			width = 0.35,
			tr = 1,
			n = 6,
			anchor = function()
				return CF(s.at)
			end,
			radiusFn = function()
				local age = os.clock() - s.t0
				return 0.3 + (1 - math.exp(-age * 5)) * 6.5 * s.k
			end,
		})
		shocks[i] = s
	end
	local nextShock = 1
	local function shock(k: number, att: Attachment?)
		local s = shocks[nextShock]
		nextShock = nextShock % #shocks + 1
		s.t0 = os.clock()
		s.k = k
		local x, z = 0, 0
		if att and att.Parent then
			local p = c.root.CFrame:PointToObjectSpace(att.WorldPosition)
			x, z = p.X, p.Z
		end
		s.at = V(x, c.groundY + 0.06, z)
	end
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
	-- body-anchored bursts: sparks off each foot, from each palm
	local function burstAt(which: string, col: Color3, up: boolean): (ParticleEmitter?, Attachment?)
		local att = Core.tip(c, which)
		if not att then
			return nil, nil
		end
		local e = Core.emit(att, {
			tex = T.spark,
			color = cs(col, WHITE),
			size = ns(0.5, 0),
			rate = 0,
			life = nr(0.4, 0.8),
			speed = if up then nr(6, 12) else nr(8, 16),
			spread = if up then V2(70, 70) else V2(35, 35),
			dir = if up then Enum.NormalId.Top else Enum.NormalId.Bottom,
			accel = if up then V(0, -14, 0) else nil,
			drag = 2,
			bright = 2.5,
		})
		return e, att
	end
	local rFootE, rFoot = burstAt("rfoot", gold, true)
	local lFootE, lFoot = burstAt("lfoot", gold, true)
	local rPalmE = burstAt("rhand", c.c2, false)
	local lPalmE = burstAt("lhand", c.c2, false)
	local eyeLight = Core.light(eyeAtt, gold, 2.4, 14)
	B.rootLight(c, gold, 2.2, 16, { pulse = 2.4, amp = 0.8 })
	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	on("stomp", function()
		shock(1, rFoot)
		if rFootE then
			rFootE:Emit(26)
		end
	end)
	on("slam", function()
		shock(1.35, nil)
		if rFootE then
			rFootE:Emit(16)
		end
		if lFootE then
			lFootE:Emit(16)
		end
	end)
	on("step", function(side)
		local e = if side == "L" then lFootE else rFootE
		local a = if side == "L" then lFoot else rFoot
		shock(0.28, a)
		if e then
			e:Emit(5)
		end
	end)
	on("push", function()
		if rPalmE then
			rPalmE:Emit(22)
		end
		if lPalmE then
			lPalmE:Emit(22)
		end
	end)
	local nextBlink = 0
	Core.on(c, function(t, _, root)
		-- the wall: forms on "raise", held while the arms block, shoved out + dissolved on "push"
		local sR, sP = Sync.since(bus, "raise"), Sync.since(bus, "push")
		local w, shove = 0, 0
		if sR < sP then
			w = smooth01(sR / 0.22)
		elseif sP < 1.2 then
			shove = smooth01(sP / 0.3) * 3
			w = 1 - smooth01((sP - 0.15) / 0.6)
		end
		local jolt = Sync.env(bus, "stomp", 6) * 0.7 + Sync.env(bus, "step", 12) * -0.12 - Sync.env(bus, "slam", 6) * 0.6
		for i, p in plates do
			local a = (i - 1) / 6 * TAU + t * 0.55
			local orbitCF = outward(a, 4.4, c.chestY + 0.3 + math.sin(t + i) * 0.45 + jolt * (0.6 + (i % 2) * 0.5))
			local wallCF = CF(0, c.chestY + 0.3, -3.5 - shove) * wall[i]
			local cf = root * orbitCF:Lerp(wallCF, w) * ANG(math.pi / 2, 0, 0) * ANG(0, t * 0.5 * (1 - w), 0)
			B.putHex(p.inner, cf)
			B.putHex(p.rim, cf * CF(0, 0.04, 0))
			Core.put(p.emblem, cf * CF(0, -0.07, 0) * ANG(0, math.pi / 4, 0))
			p.att.Position = root:PointToObjectSpace(cf.Position)
		end
		-- searchlight + gaze: during a scan the eye looks where the head looks
		local scanE = Sync.env(bus, "scan", 1.3)
		local side = if Sync.payload(bus, "scan") == "L" then -1 else 1
		local sweep = math.clamp(Sync.since(bus, "scan") / 0.9, 0, 1)
		local gx, gz = side * (2 + sweep * 4.5), -3.5 + sweep * 2.5
		scanAtt.Position = V(gx, c.groundY + 0.05, gz)
		search.Transparency = ns(1 - scanE * 0.55, 1 - scanE * 0.2)
		scanSpot.Enabled = scanE > 0.15
		local eyePos = (root * CF(0, yE + math.sin(t * 1.3) * 0.15, 0)).Position
		local scanTgt = (root * CF(side * 9, yE - 2.5, -4)).Position
		local tgt = camPos():Lerp(scanTgt, math.min(1, scanE * 1.6))
		local look = CFrame.lookAt(eyePos, tgt)
		Core.put(sclera, look)
		local flash = math.max(Sync.env(bus, "push", 4), Sync.env(bus, "slam", 5))
		sclera.Color = gold:Lerp(WHITE, flash)
		eyeLight.Brightness = 2.4 + flash * 4 + Sync.env(bus, "stomp", 5) * 3
		local blinkK = 1
		if t >= nextBlink then
			nextBlink = t + 3 + c.rng:NextNumber() * 3
		end
		local b = nextBlink - t
		if b < 0.16 and scanE < 0.1 then
			blinkK = math.max(0.08, math.abs(b - 0.08) / 0.08)
		end
		mesh.Scale = V(1, blinkK, 1)
		local hide = if blinkK < 0.5 then 1 else 0
		iris.Transparency = hide
		pupil.Transparency = hide
		Core.put(iris, look * CF(0, 0, -0.19) * AXIS_Z)
		Core.put(pupil, look * CF(0, 0, -0.23) * AXIS_Z)
		-- shock rings fade out as they spread
		local now = os.clock()
		for _, s in shocks do
			local age = now - s.t0
			B.setBeamsTransparency(s.cir.beams, if age < 0.8 then 0.05 + 0.95 * (age / 0.8) else 1)
		end
	end)
end

---------------------------------------------------------------- MYTHIC

-- concentric rings 0..3 around the body, core orb at chest
-- parts ~90, emitters 10
-- Synced to the Blender animation (tools/blender/anim/auras/Kernel.py, levitating set, lift 1.6
-- studs, idle 6.0 s). The Kernel CONDUCTS its rings: every hand gesture is a command they obey.
-- Ring motion is integrated per frame (precession + spin) so it can be frozen / boosted smoothly.
--   "cmd" 1|2   a hand stabs at a ring     -> a command beam fires from that hand (1 = right,
--                                            2 = left) to the RING k label, ring k flashes white,
--                                            kicks wider and spins up, sparks from the hand
--   "lock"      arms snap into a T         -> all rings snap FLAT and FREEZE, flash, labels "LOCKED"
--   "charge"    hands cup around the core  -> rings contract, sparks stream INTO the core, the shell
--                                            compresses, labels read "RING 0"
--   "zero"      arms fling out, body surges-> core nova, shock ring on the REAL floor, rings blast out
--                                            35 % wider, the sky pillar flares, light surge
--   "unlock"    arms float down            -> rings ease back into wobble + spin
--   walk "thrust" / jump "push"            -> small / medium floor shock ring + core spark puff
--   "intrusion" (VFX -> body, every 10-16 s while hovering in place): a red UNAUTHORIZED process
--               appears on the outer ring at the front-right; the body's reaction snaps the head to
--               it and whips the right hand out, its "kill" marker -> cyan kill beam from the right
--               hand, the process bursts into red squares, ring 3 flashes
-- Core heartbeat: Sync.phase(bus, 1.5) = 4 beats per idle loop.
A.Kernel = function(c: Ctx)
	local bus = c.bus
	local rng = c.rng
	local BEAT = 1.5 -- core heartbeat (s), 4 per 6 s idle
	local RED = Color3.fromRGB(255, 40, 60)
	local cy = c.chestY + 0.4
	local spins = { 1.6, -1.2, 0.9, -0.6 }
	local counts = { 10, 14, 18, 22 }
	local radii = { 2.3, 3.7, 5.1, 6.6 }
	-- control state, integrated each frame (registered before the rings so they read fresh values)
	local lock, charge = 0, 0
	local yaw = { 0, 0, 0, 0 }
	local anti = { 0, 0, 0, 0 }
	local scale = { 1, 1, 1, 1 }
	local flash = { 0, 0, 0, 0 }
	local function kickOf(k: number): number
		local e = 0
		if Sync.payload(bus, "cmd") == tostring(k) then
			e = Sync.env(bus, "cmd", 3.5)
		end
		if k == 3 then
			e = math.max(e, Sync.env(bus, "kill", 4))
		end
		return e
	end
	Core.on(c, function(_, dt)
		dt = math.min(dt, 0.1)
		local target = if Sync.since(bus, "lock") < Sync.since(bus, "unlock") then 1 else 0
		lock += (target - lock) * (1 - math.exp(-dt * (if target > lock then 16 else 2.5)))
		local sC, sZ = Sync.since(bus, "charge"), Sync.since(bus, "zero")
		local cT = if sC < sZ and sC < 3 then 1 else 0
		charge += (cT - charge) * (1 - math.exp(-dt * (if cT > charge then 5 else 12)))
		local zeroE = Sync.env(bus, "zero", 2.2)
		local lockE = Sync.env(bus, "lock", 4)
		for k = 0, 3 do
			local i = k + 1
			local kick = kickOf(k)
			local m = (1 - lock) * (1 + kick * 3)
			anti[i] += dt * spins[i] * (1 - m)
			yaw[i] += dt * (0.3 + k * 0.1) * (if k % 2 == 0 then 1 else -1) * (1 - lock)
			scale[i] = 1 + zeroE * 0.35 + kick * 0.14 - charge * (0.12 + k * 0.05)
			flash[i] = math.min(1, math.max(kick, lockE, zeroE * 0.8))
		end
	end)
	local function anchor(k: number): (t: number) -> CFrame
		local amp = 0.55 / (1 + k * 0.6)
		local i = k + 1
		return function(t: number): CFrame
			local a = amp * (1 - lock)
			return CF(0, cy, 0)
				* ANG(math.sin(t * 0.4 + k) * a, 0, math.cos(t * 0.5 + k * 1.3) * a)
				* ANG(0, yaw[i] + anti[i], 0)
		end
	end
	local coreL = V(0, cy, -1.15)
	local coreAtt = Core.att(c, nil, CF(coreL))
	type RingVis = { parts: { BasePart }, base: { Color3 }, beams: { Beam }, lbl: TextLabel, att: Attachment, last: number, text: string }
	local rings: { RingVis } = {}
	for k = 0, 3 do
		local i = k + 1
		local col = if k % 2 == 0 then c.c1 else c.c2
		local parts = B.ring(c, {
			n = counts[i],
			radius = radii[i],
			seg = V(0.16, 0.24, 0),
			color = col,
			color2 = col:Lerp(WHITE, 0.4),
			spin = spins[i],
			anchor = anchor(k),
			radiusFn = function()
				return radii[i] * scale[i]
			end,
		})
		local base = {}
		for j, p in parts do
			base[j] = p.Color
		end
		local cir = B.circle(c, {
			radius = radii[i],
			color = col,
			width = 0.05,
			tr = 0.4,
			anchor = anchor(k),
			n = 10,
			radiusFn = function()
				return radii[i] * scale[i]
			end,
		})
		local att, lbl = B.glyph(c, "RING " .. k, col, V2(1.7, 0.42), F.tech, nil, BLACK)
		lbl.TextStrokeTransparency = 0.2
		rings[i] = { parts = parts, base = base, beams = cir.beams, lbl = lbl, att = att, last = 0, text = "RING " .. k }
		Core.beam(c, coreAtt, att, col, 0.06, { tr = ns(0.15, 0.7), tex = T.square, texLen = 0.5, texSpeed = 3 })
	end
	local core = Core.part(c, V(1.1, 1.1, 1.1), c.c1, NEON, 0.25, BALL)
	local inner = Core.part(c, V(0.55, 0.55, 0.55), WHITE, NEON, 0, BALL)
	local shell = Core.part(c, V(1.9, 1.9, 1.9), c.c2, FF, 0, BALL)
	local pillar = B.pillar(c, { color = c.c1, color2 = c.c2, height = 45, width = 1.8, tr = 0.45, streams = 3, radius = 1.4 })
	local pillarW: { { number } } = {}
	for i, b in pillar do
		pillarW[i] = { b.Width0, b.Width1 }
	end
	B.sigil(
		c,
		{ radius = 7.2, color = c.c1, color2 = c.c2, ticks = 16, spokes = 8, glow = 0.88, spin = 0.3, pulse = BEAT }
	)
	Core.emit(coreAtt, {
		tex = T.glow,
		color = cs(c.c1, c.c2),
		size = ns(2.5, 4),
		transp = ns(0.35, 1),
		rate = 6,
		life = nr(0.4, 0.6),
		locked = true,
	})
	-- core nova on "zero", sparks streaming in while charging
	local nova = Core.emit(coreAtt, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.55, 0),
		transp = ns(0, 1),
		rate = 0,
		life = nr(0.8, 1.5),
		speed = nr(14, 28),
		spread = V2(180, 180),
		drag = 3,
		rotSpeed = nr(-240, 240),
		bright = 3,
	})
	local novaGlow = Core.emit(coreAtt, {
		tex = T.glow,
		color = cs(WHITE, c.c1),
		size = ns(3, 12),
		transp = ns(0.2, 1),
		rate = 0,
		life = nr(0.35, 0.5),
		locked = true,
	})
	local inflow = Core.emit(Core.volume(c, V(6, 6, 6), CF(coreL)), {
		tex = T.spark,
		color = cs(c.c2, WHITE),
		size = ns(0.45, 0.1),
		rate = 45,
		life = nr(0.4, 0.55),
		speed = nr(7, 10),
		shape = SPHERE,
		shapeStyle = SURFACE,
		inout = INWARD,
		bright = 2.5,
	})
	inflow.Enabled = false
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
	-- command beams from the hands to the ring labels, sparks off the commanding hand
	local rHand = Core.tip(c, "rhand")
	local lHand = Core.tip(c, "lhand")
	local function handSparks(att: Attachment?, col: Color3): ParticleEmitter?
		if not att then
			return nil
		end
		return Core.emit(att, {
			tex = T.spark,
			color = cs(col, WHITE),
			size = ns(0.45, 0),
			rate = 0,
			life = nr(0.3, 0.6),
			speed = nr(5, 11),
			spread = V2(40, 40),
			dir = Enum.NormalId.Bottom,
			drag = 3,
			bright = 2.5,
		})
	end
	local rSparks, lSparks = handSparks(rHand, c.c2), handSparks(lHand, c.c2)
	local function cmdBeam(from: Attachment?, to: Attachment, col: Color3): Beam?
		if not from then
			return nil
		end
		return Core.beam(c, from, to, WHITE, 0.32, {
			w1 = 0.1,
			color2 = col,
			tr = ns(1),
			tex = T.square,
			texLen = 0.6,
			texSpeed = 9,
			segs = 4,
		})
	end
	local rBeam = cmdBeam(rHand, rings[2].att, c.c2)
	local lBeam = cmdBeam(lHand, rings[3].att, c.c1)
	-- the intruder: a red process on the outer ring, front-right of the body
	local intrAt = CF(4.6, cy + 0.7, -4.4)
	local intrAtt, intrLbl = B.glyph(c, "UNAUTHORIZED", RED, V2(2.8, 0.55), F.pixel, intrAt, BLACK)
	intrLbl.TextTransparency = 1
	intrLbl.TextStrokeTransparency = 1
	local intrBox = Core.part(c, V(0.7, 0.7, 0.7), RED, NEON, 1)
	local killBeam = cmdBeam(rHand, intrAtt, c.c2)
	local intrBurst = Core.emit(intrAtt, {
		tex = T.square,
		color = cs(RED, WHITE),
		size = ns(0.45, 0),
		transp = ns(0, 1),
		rate = 0,
		life = nr(0.5, 1),
		speed = nr(6, 14),
		spread = V2(180, 180),
		drag = 3,
		rotSpeed = nr(-300, 300),
		bright = 3,
	})
	-- shock rings on the REAL floor under the levitating body
	type Shock = { cir: any, t0: number, k: number }
	local shocks: { Shock } = {}
	for i = 1, 2 do
		local s: Shock = { cir = nil, t0 = -math.huge, k = 1 }
		s.cir = B.circle(c, {
			radius = 1,
			color = c.c1,
			color2 = c.c2,
			width = 0.35,
			tr = 1,
			n = 10,
			anchor = function()
				return CF(0, c.groundY - c.lift + 0.08, 0)
			end,
			radiusFn = function()
				local age = os.clock() - s.t0
				return 1.2 + (1 - math.exp(-age * 3.4)) * 10 * s.k
			end,
		})
		shocks[i] = s
	end
	local nextShock = 1
	local function shock(k: number)
		local s = shocks[nextShock]
		nextShock = nextShock % #shocks + 1
		s.t0 = os.clock()
		s.k = k
	end
	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	on("cmd", function(k)
		local e = if k == "2" then lSparks else rSparks
		if e then
			e:Emit(18)
		end
	end)
	on("zero", function()
		nova:Emit(80)
		novaGlow:Emit(3)
		shock(1.2)
	end)
	on("push", function()
		shock(0.75)
		novaGlow:Emit(1)
	end)
	on("thrust", function()
		shock(0.32)
		nova:Emit(6)
	end)
	on("kill", function()
		intrBurst:Emit(40)
		if rSparks then
			rSparks:Emit(14)
		end
	end)
	local light = B.rootLight(c, c.c1, 3, 18, { y = cy })
	local nextIntr = Sync.age(bus) + 10 + rng:NextNumber() * 6
	Core.on(c, function(t, _, root)
		-- VFX -> body: an unauthorized process tries to get in now and then
		local age = Sync.age(bus)
		if age >= nextIntr then
			nextIntr = age + 10 + rng:NextNumber() * 6
			if Sync.get(bus, "move") < 0.3 and lock < 0.05 and charge < 0.05 and Sync.since(bus, "zero") > 1.5 then
				Sync.emit(bus, "intrusion")
			end
		end
		local zeroE = Sync.env(bus, "zero", 2.2)
		local labelText = if charge > 0.5 then "RING 0" elseif lock > 0.5 then "LOCKED" else nil
		for k = 0, 3 do
			local i = k + 1
			local rv = rings[i]
			local a = t * spins[i] + k
			local r = radii[i] * scale[i]
			rv.att.Position = (anchor(k)(t) * ANG(0, -a, 0) * CF(r, 0.55, 0)).Position
			local f = flash[i]
			if math.abs(f - rv.last) > 0.02 or (f == 0 and rv.last ~= 0) then
				rv.last = f
				for j, p in rv.parts do
					p.Color = rv.base[j]:Lerp(WHITE, f)
				end
				B.setBeamsTransparency(rv.beams, 0.4 - 0.4 * f)
				rv.lbl.TextColor3 = rv.base[1]:Lerp(WHITE, f)
			end
			local txt = labelText or ("RING " .. k)
			if txt ~= rv.text then
				rv.text = txt
				rv.lbl.Text = txt
			end
		end
		-- command beams
		local cmdE = Sync.env(bus, "cmd", 4.5)
		local which = Sync.payload(bus, "cmd")
		if rBeam then
			rBeam.Transparency = ns(if which == "1" then 1 - cmdE else 1)
		end
		if lBeam then
			lBeam.Transparency = ns(if which == "2" then 1 - cmdE else 1)
		end
		-- the intruder
		local sI, sK = Sync.since(bus, "intrusion"), Sync.since(bus, "kill")
		local alive = sI < sK and sI < 2.5
		local blink = alive and math.noise(t * 9, 3.1) > -0.3
		intrLbl.TextTransparency = if blink then 0.05 else 1
		intrLbl.TextStrokeTransparency = if blink then 0.3 else 1
		intrBox.Transparency = if alive then 0.15 + 0.4 * math.abs(math.sin(t * 20)) else 1
		Core.put(intrBox, root * intrAt * CF(0, -0.75, 0) * ANG(t * 3, t * 4, 0))
		if killBeam then
			killBeam.Transparency = ns(1 - Sync.env(bus, "kill", 5))
		end
		-- core: heartbeat on the shared phase, compresses while charging, blows up on zero
		local ph = Sync.phase(bus, BEAT)
		local beat = math.exp(-ph * BEAT * 5)
		local cf = root * CF(coreL)
		Core.put(core, cf)
		Core.put(inner, cf)
		local s = 1.8 + beat * 0.5 - charge * 0.75 + zeroE * 1.8
		shell.Size = V(s, s, s)
		Core.put(shell, cf)
		inflow.Enabled = charge > 0.3
		light.Brightness = 2.4 + beat * 2.2 + zeroE * 6 + Sync.env(bus, "lock", 4) * 2 + charge * math.random() * 1.5
		local pw = 1 + zeroE * 1.6 + charge * 0.3
		for i, b in pillar do
			b.Width0 = pillarW[i][1] * pw
			b.Width1 = pillarW[i][2] * pw
		end
		local now = os.clock()
		for _, sh in shocks do
			local a = now - sh.t0
			B.setBeamsTransparency(sh.cir.beams, if a < 1.1 then 0.05 + 0.95 * (a / 1.1) else 1)
		end
	end)
end

-- body semi-transparent, white wisps, cloak of fading pixels
-- parts ~92, emitters 9
-- Synced to the Blender animation (tools/blender/anim/auras/GhostProtocol.py, levitating set,
-- lift 1 stud, idle 6.0 s). The delayed echoes replay the animated body 0.35 / 0.7 s late, so
-- every spy gesture ripples through the "everywhere" copies.
--   "scan" L/R   head snaps over a shoulder -> that echo (L = A, R = B) flares solid, a wisp puff
--                                             from the head, the DISAVOWED tag glitches
--   "shh"        finger to the lips          -> the tag goes solid white, a wisp from the right
--                                             hand, then SILENCE: wisps / light dim for ~0.7 s
--   "cloak"      cape swirl                  -> the body VANISHES (parts 0.97, skin off, pixel
--                                             cloak hidden), the cloak bursts off the back as
--                                             pixels, smoke puff, the echoes fade out
--   "decloak"    snaps back half a stud away -> white skin flash fading back, a ring of wisps,
--                                             the echoes snap back in
--   walk "shed" R/L                          -> pixels shed backward from the cloak
--   "blink" (walk dropped frame, jump vault) -> skin off + body flashes nearly invisible
--   "spotted" (reaction)                     -> the VFX fires it when the local camera gets within
--                                             9 studs (cooldown 9 s); its markers cloak/decloak
-- The echoes breathe twice per idle cycle (Sync.phase(bus, 6)).
A.GhostProtocol = function(c: Ctx)
	local bus = c.bus
	local rng = c.rng
	local BEAT = 6 -- idle length (s), GhostProtocol.py
	local holder = c.folder.Parent
	type Ghosted = { inst: Instance, base: number, decal: boolean }
	local ghosted: { Ghosted } = {}
	for _, d in c.char:GetDescendants() do
		if holder and d:IsDescendantOf(holder) then
			continue
		end
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			local base = math.max(d.Transparency, 0.6)
			Core.override(c, d, "Transparency", base)
			table.insert(ghosted, { inst = d :: Instance, base = base, decal = false })
		elseif d:IsA("Decal") then
			local base = math.max(d.Transparency, 0.7)
			Core.override(c, d, "Transparency", base)
			table.insert(ghosted, { inst = d :: Instance, base = base, decal = true })
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
	local backPx = Core.emit(back, {
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
	-- one-shot: the cloak tearing off as pixels (cloak / shed)
	local cloakBurst = Core.emit(Core.att(c, c.torso, CF(0, 0, c.torso.Size.Z / 2 + 0.3)), {
		tex = T.square,
		color = cs(WHITE, c.c1, c.c2),
		size = ns(0.38, 0),
		transp = ns(0, 1),
		rate = 0,
		life = nr(1.2, 2.2),
		speed = nr(3, 8),
		spread = V2(70, 70),
		dir = Enum.NormalId.Back,
		drag = 2,
		accel = V(0, 2.5, 0),
		rotSpeed = nr(-120, 120),
		shape = BOX,
	})
	local torso = Core.att(c, c.torso)
	local smoke = Core.emit(torso, {
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
	local floorSmoke = B.floorEmit(c, 5, {
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
	local wisps = Core.emit(torso, {
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
	-- one-shots: smoke puff on vanish, a ring of wisps on reappear
	local puff = Core.emit(torso, {
		tex = T.smoke,
		color = cs(WHITE, pale),
		size = ns(2.5, 6),
		transp = ns(0.55, 1),
		rate = 0,
		life = nr(1, 1.6),
		speed = nr(2, 5),
		spread = V2(180, 180),
		drag = 2.5,
		rotSpeed = nr(-60, 60),
		light = 0.8,
	})
	local ring = Core.emit(torso, {
		tex = T.glow,
		color = cs(WHITE, c.c1),
		size = ns(0.9, 0),
		transp = ns(0, 1),
		rate = 0,
		life = nr(0.6, 1),
		speed = nr(9, 14),
		spread = V2(180, 6),
		drag = 3,
		bright = 3,
		orient = PERP,
	})
	ring.Rotation = nr(0, 0)
	ring.EmissionDirection = Enum.NormalId.Front
	-- body-borne wisps: from the head on a scan, from the right hand on the "shh"
	local function tipWisp(which: string): ParticleEmitter?
		local att = Core.tip(c, which)
		if not att then
			return nil
		end
		return Core.emit(att, {
			tex = T.glow,
			color = cs(WHITE, c.c1),
			size = ns(0.6, 0),
			transp = ns(0.1, 1),
			rate = 0,
			life = nr(0.6, 1.1),
			speed = nr(1.5, 3.5),
			spread = V2(180, 180),
			drag = 2,
			accel = V(0, 2, 0),
			bright = 2,
		})
	end
	local headWisp = tipWisp("head")
	local handWisp = tipWisp("rhand")
	local light = B.rootLight(c, pale, 1.8, 16, { pulse = 2.5, amp = 1.2 })

	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	on("scan", function()
		if headWisp then
			headWisp:Emit(10)
		end
	end)
	on("shh", function()
		if handWisp then
			handWisp:Emit(12)
		end
	end)
	on("cloak", function()
		cloakBurst:Emit(46)
		puff:Emit(6)
	end)
	on("decloak", function()
		ring:Emit(36)
		puff:Emit(3)
	end)
	on("shed", function()
		cloakBurst:Emit(9)
	end)
	on("blink", function()
		cloakBurst:Emit(5)
	end)

	local ts = c.torso.Size
	local lastSpot = -math.huge
	local skinTr = -1
	Core.on(c, function(t)
		local tcf = c.torso.CFrame
		local age = Sync.age(bus)
		-- the local camera comes close -> "spotted" (the body reaction cloaks and decloaks)
		if age - lastSpot > 9 and age > 2 and Sync.get(bus, "move") < 0.3 then
			local camD = (camPos() - c.realRoot.Position).Magnitude
			if camD < 9 and camD > 2.5 then -- not in first person
				lastSpot = age
				Sync.emit(bus, "spotted")
			end
		end
		-- vanish state: from "cloak" until "decloak"; the walk / vault blink drops a frame
		local sCloak, sDecl = Sync.since(bus, "cloak"), Sync.since(bus, "decloak")
		local hidden = sCloak < sDecl and sCloak < 1.5
		local blink = Sync.since(bus, "blink") < 0.08
		local back = if hidden then 0 else math.clamp(sDecl / 0.5, 0, 1) -- fade-in after decloak
		local vis = if hidden then 0 elseif blink then 0.15 else back
		for _, g in ghosted do
			local tr = g.base + (if g.decal then 1 - g.base else 0.97 - g.base) * (1 - vis)
			;(g.inst :: any).Transparency = tr
		end
		-- skin: white flash right after decloak, off while hidden / blinking
		local flash = Sync.env(bus, "decloak", 5)
		local str = if hidden or blink then 1 else 0
		if str ~= skinTr then
			skinTr = str
			for _, sp in skin do
				sp.Transparency = str
			end
		end
		for _, sp in skin do
			sp.Color = c.c1:Lerp(WHITE, flash)
		end
		-- echoes: breathe twice per idle cycle, flare on the scan of their side, fade while hidden
		local ph = Sync.phase(bus, BEAT)
		local scanE = Sync.env(bus, "scan", 3.5)
		local scanSide = Sync.payload(bus, "scan")
		local gone = if hidden then math.clamp(sCloak / 0.4, 0, 1) else 0
		local ea = 0.55 + 0.45 * Core.pulse(ph * 2, 1)
		local eb = 0.55 + 0.45 * Core.pulse(ph * 2, 1, 0.5)
		if scanSide == "L" then
			ea -= scanE * 0.5
		elseif scanSide == "R" then
			eb -= scanE * 0.5
		end
		local snapIn = Sync.env(bus, "decloak", 7) * 0.4
		ea = math.clamp(ea - snapIn + gone, 0.05, 1)
		eb = math.clamp(eb - snapIn + gone, 0.05, 1)
		for _, p in echoA do
			p.Transparency = ea
		end
		for _, p in echoB do
			p.Transparency = eb
		end
		-- silence after the "shh": wisps and light dim for ~0.7 s
		local sShh = Sync.since(bus, "shh")
		local quiet = sShh > 0.25 and sShh < 0.95
		local enabled = not quiet and not hidden
		wisps.Enabled = enabled
		smoke.Enabled = not quiet
		floorSmoke.Enabled = not quiet
		backPx.Enabled = enabled and not blink
		light.Brightness *= if quiet then 0.35 elseif hidden then 0.6 else 1 + flash * 1.5
		-- pixel cloak on the back (hidden with the body)
		for _, q in px do
			local row, col = q.row, q.col
			local flare = row / (ROWS - 1)
			local x = (col - (COLS - 1) / 2) * 0.46 * (1 + flare * 0.45)
			local y = ts.Y / 2 + 0.1 - row * 0.46
			local z = ts.Z / 2 + 0.15 + flare * 0.7 + math.sin(t * 2.6 + row * 0.7 + col * 0.5) * 0.12 * flare
			local tr = math.clamp(math.noise(col * 0.7, row * 0.7, t * 0.8) * 1.2 + 0.1, 0, 0.7)
			local drift = Vector3.zero
			if row >= ROWS - 3 then
				local cph = (t * 0.3 + q.seed) % 1
				if cph > 0.5 then
					local f = (cph - 0.5) / 0.5
					drift = V(math.sin(q.seed * 20) * f * 1.4, f * 2.6, f * 4)
					tr = math.max(tr, f)
				end
			end
			if hidden or blink then
				tr = 1
			elseif back < 1 then
				-- pixels re-assemble row by row after decloak
				tr = math.max(tr, if back * ROWS > row then 0 else 1)
			end
			q.p.Transparency = tr
			Core.put(q.p, tcf * CF(V(x, y, z) + drift) * ANG(-0.25 * flare, 0, 0))
		end
		-- DISAVOWED tag: noise flicker, glitches on a scan, solid white on the "shh"
		if sShh < 1.2 then
			tag.TextTransparency = 0
			tag.TextColor3 = WHITE
		else
			tag.TextColor3 = pale
			local glitch = scanE > 0.6 and rng:NextNumber() < 0.5
			tag.TextTransparency = if hidden then 1
				elseif glitch then 0.95
				elseif math.noise(t * 2, 7) > 0.25 then 0.85
				else 0.1
		end
	end)
end

-- six neon wings, halo of code, feather pixels falling
-- parts ~84, emitters 9
-- Synced to the Blender animation (tools/blender/anim/auras/CyberSeraph.py, levitating set,
-- lift 2 studs, idle 6.0 s). The ARMS are the wing muscles: every frame each side's three wings
-- read that arm's elevation / forward sweep (upper wing follows fast, lower wings lag behind =
-- overlapping action), so every flap, the prayer and the V of the Blender clip are wing beats.
-- The wings ride the torso and the halo / sun disc ride the head.
--   "flap" [soft|big]  downstroke  -> wings are pushed down, a downdraft ring of light races over
--                                    the real ground, feather pixels shed, halo light pops
--   "gather"           prayer      -> the code halo is pulled in tight, light drains, sparks
--                                    stream INTO the chest until "radiate"
--   "radiate"          arms V      -> halo flash + ring pops wide, light-feather nova from the
--                                    chest, the sky pillar flares wide, big ground ring, light surge
--   walk "glide"       wing beat   -> small feather puff + soft ground ring
--   "recompile" (VFX -> body)      -> fired every 11-17 s while idle: the body's glitch reaction;
--     its "glitch" marker          -> feathers flicker out at random, the halo prints garbage
--     its "rebuild" marker         -> wings re-materialise with a sparkle burst, halo flash
-- Sigil / halo spin breathe with the idle (Sync.phase(bus, 6)).
A.CyberSeraph = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
	local BEAT = 6 -- idle length (s), CyberSeraph.py
	type WingSpec = {
		y: number,
		p0: number,
		p1: number,
		l0: number,
		l1: number,
		yaw: number,
		ph: number,
		w: number,
		rate: number,
	}
	-- y = root-space height of the wing root; rate = how fast the wing follows its arm (1/s)
	local specs: { WingSpec } = {
		{ y = c.chestY + 0.75, p0 = 0.2, p1 = 1.05, l0 = 7.2, l1 = 4.6, yaw = 0.26, ph = 0, w = 0.6, rate = 16 },
		{ y = c.chestY + 0.35, p0 = 1.08, p1 = 1.78, l0 = 6, l1 = 3.8, yaw = 0.34, ph = 0.45, w = 0.55, rate = 10 },
		{ y = c.chestY - 0.05, p0 = 1.9, p1 = 2.6, l0 = 4.4, l1 = 2.7, yaw = 0.42, ph = 0.9, w = 0.48, rate = 6.5 },
	}
	type Wing = {
		spec: WingSpec,
		s: number,
		bone: BasePart,
		feathers: { BasePart },
		r: number,
		yawS: number,
	}
	local wings: { Wing } = {}
	local NF = 6
	for _, sp in specs do
		for _, s in { 1, -1 } do
			local fs = {}
			for j = 1, NF do
				local f = (j - 1) / (NF - 1)
				local L = sp.l0 + (sp.l1 - sp.l0) * f
				local fp =
					Core.part(c, V(sp.w * (1 - f * 0.25), L, 0.08), WHITE:Lerp(c.c2, 0.15 + f * 0.75), NEON, 0.04)
				fs[j] = fp
				if j == 1 then
					local hw = sp.w / 2
					B.tipTrail(fp, V(-hw, L / 2 - 0.05, 0), V(hw, L / 2 - 0.05, 0), WHITE, 0.6, c.c2)
				end
			end
			table.insert(wings, {
				spec = sp,
				s = s,
				bone = Core.part(c, V(0.24, sp.l0 * 0.62, 0.16), c.c2),
				feathers = fs,
				r = 0,
				yawS = sp.yaw,
			})
		end
	end
	-- halo of code: rides the head (root-local frame of the head, recomputed every frame)
	local hUp = c.topY - c.headY + 0.95
	local haloTilt = ANG(0.15, 0, 0)
	local headLocal = CF(0, c.headY, 0)
	local haloR = 1.3
	-- registered first so every halo / disc anchor below reads this frame's head
	Core.on(c, function()
		headLocal = c.root.CFrame:ToObjectSpace(c.head.CFrame)
	end)
	local function haloCF(t: number): CFrame
		return headLocal * CF(0, hUp + math.sin(t * 1.5) * 0.08, 0) * haloTilt
	end
	B.ring(c, {
		n = 20,
		radius = 1.3,
		seg = V(0.12, 0.12, 0),
		color = WHITE,
		color2 = c.c2,
		spin = 0.6,
		anchor = haloCF,
		radiusFn = function()
			return haloR
		end,
	})
	local haloIn = B.circle(c, {
		radius = 1.3,
		color = c.c2,
		width = 0.16,
		tr = 0.05,
		anchor = haloCF,
		radiusFn = function()
			return haloR
		end,
	})
	local haloOut = B.circle(c, {
		radius = 1.75,
		color = WHITE,
		width = 0.05,
		tr = 0.35,
		anchor = haloCF,
		radiusFn = function()
			return haloR * 1.35
		end,
	})
	-- sun disc behind the head (reads from the front and from behind)
	local function discCF(): CFrame
		return headLocal * CF(0, 0.5, 0.75) * ANG(math.pi / 2, 0, 0)
	end
	B.circle(c, { radius = 2.3, color = c.c2, width = 0.12, tr = 0.25, anchor = discCF, n = 8 })
	B.circle(c, { radius = 2.65, color = WHITE, width = 0.05, tr = 0.4, anchor = discCF, n = 8 })
	type Gl = { att: Attachment, lbl: TextLabel }
	local code: { Gl } = {}
	for i = 1, 12 do
		local att, lbl = B.glyph(c, "1", c.c2, V2(0.5, 0.5), F.pixel, nil, WHITE)
		lbl.TextStrokeTransparency = 0.6
		code[i] = { att = att, lbl = lbl }
	end
	local pillar =
		B.pillar(c, { color = WHITE, color2 = c.c2, height = 55, width = 3.4, tr = 0.6, streams = 3, radius = 1.6 })
	local pillarW: { { number } } = {}
	for i, b in pillar do
		pillarW[i] = { b.Width0, b.Width1 }
	end
	B.sigil(
		c,
		{ radius = 7, color = WHITE, color2 = c.c2, ticks = 16, spokes = 6, glow = 0.9, spin = 0.25, pulse = 3.0 }
	)
	-- downdraft rings on the REAL ground under the levitating body (two, so beats can overlap)
	type Draft = { cir: any, t0: number, k: number }
	local drafts: { Draft } = {}
	for i = 1, 2 do
		local d: Draft = { cir = nil, t0 = -math.huge, k = 1 }
		d.cir = B.circle(c, {
			radius = 1,
			color = WHITE,
			color2 = c.c2,
			width = 0.3,
			tr = 1,
			n = 10,
			anchor = function()
				return CF(0, c.groundY - c.lift + 0.08, 0)
			end,
			radiusFn = function()
				local s = os.clock() - d.t0
				return 1.2 + (1 - math.exp(-s * 3.2)) * 9 * d.k
			end,
		})
		drafts[i] = d
	end
	local nextDraft = 1
	local function draft(k: number)
		local d = drafts[nextDraft]
		nextDraft = nextDraft % #drafts + 1
		d.t0 = os.clock()
		d.k = k
	end
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
	-- one-shot: feathers shed by a wing beat (flap / glide) and the rebuild sparkle
	local shed = Core.emit(wingVol, {
		tex = T.square,
		color = cs(WHITE, c.c2),
		size = ns(0.34, 0),
		transp = ns(0, 1),
		squash = ns(1.4),
		rate = 0,
		life = nr(1.4, 2.4),
		speed = nr(2, 5),
		spread = V2(180, 180),
		accel = V(0, -3, 0),
		drag = 1.5,
		rotSpeed = nr(-160, 160),
		shape = BOX,
	})
	local sparkle = Core.emit(wingVol, {
		tex = T.spark,
		color = cs(WHITE, c.c2),
		size = ns(0, 0.8, 0),
		rate = 0,
		life = nr(0.5, 1),
		speed = nr(0.5, 2),
		spread = V2(180, 180),
		bright = 3,
		shape = BOX,
	})
	local haloAtt = Core.att(c, nil, CF(0, c.topY + 0.95, 0))
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
	-- chest: light streams IN while praying, a nova of light feathers OUT on "radiate"
	local chest = Core.tip(c, "chest") or Core.att(c, c.torso)
	local inflow = Core.emit(Core.volume(c, V(5, 5, 5), CF(0, 0, 0), c.torso), {
		tex = T.spark,
		color = cs(c.c2, WHITE),
		size = ns(0.5, 0.1),
		rate = 40,
		life = nr(0.45, 0.6),
		speed = nr(6, 9),
		shape = SPHERE,
		shapeStyle = SURFACE,
		inout = INWARD,
		bright = 2.5,
	})
	inflow.Enabled = false
	local nova = Core.emit(chest, {
		tex = T.square,
		color = cs(WHITE, c.c2),
		size = ns(0.5, 0),
		transp = ns(0, 1),
		squash = ns(1.4),
		rate = 0,
		life = nr(1, 1.8),
		speed = nr(14, 26),
		spread = V2(180, 180),
		drag = 3,
		rotSpeed = nr(-200, 200),
		bright = 3,
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
	local rootL = B.rootLight(c, WHITE, 2.8, 18, { pulse = 3, amp = 1 })
	local haloL = Core.light(haloAtt, c.c2, 2, 12)

	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	on("flap", function(kind)
		local k = if kind == "soft" then 0.65 elseif kind == "big" then 1.35 else 1
		draft(k)
		shed:Emit(math.floor(22 * k))
	end)
	on("glide", function()
		draft(0.45)
		shed:Emit(6)
	end)
	on("radiate", function()
		nova:Emit(70)
		draft(1.5)
	end)
	on("rebuild", function()
		sparkle:Emit(50)
	end)

	-- arm -> wing drive: elevation of the arm above "hanging" and how far it sweeps fwd / back
	local rArm = Core.bodyPart(c.char, "Right Arm", "RightUpperArm")
	local lArm = Core.bodyPart(c.char, "Left Arm", "LeftUpperArm")
	local function armDrive(arm: BasePart?): (number, number)
		if not arm then
			return 0, 0
		end
		local d = c.torso.CFrame:VectorToObjectSpace(-arm.CFrame.UpVector)
		local elev = math.acos(math.clamp(-d.Y, -1, 1))
		return math.clamp((elev - 0.55) / 1.2, -0.5, 1.3), math.clamp(d.Z, -1, 1)
	end
	local GARBAGE = { "#", "%", "&", "?", "!", "/", "\\", "@", "x", "~" }
	local nextC = 0
	local nextRecompile = Sync.age(bus) + 11 + rng:NextNumber() * 6
	Core.on(c, function(t, dt)
		local age = Sync.age(bus)
		-- VFX -> body: the angel's code glitches now and then while it hovers in place
		if age >= nextRecompile then
			nextRecompile = age + 11 + rng:NextNumber() * 6
			if Sync.get(bus, "move") < 0.3 and Sync.since(bus, "radiate") > 1.5 then
				Sync.emit(bus, "recompile")
			end
		end
		local glitching = Sync.window(bus, "glitch", 0.65) >= 0 and Sync.since(bus, "rebuild") > Sync.since(bus, "glitch")
		local ePush = Sync.env(bus, "flap", 7) * (if Sync.payload(bus, "flap") == "soft" then 0.25 else 0.45)
		local eRad = Sync.env(bus, "radiate", 3)
		local eReb = Sync.env(bus, "rebuild", 6)
		local tcf = c.torso.CFrame
		local rR, rB = armDrive(rArm)
		local lR, lB = armDrive(lArm)
		for _, w in wings do
			local sp = w.spec
			local s = w.s
			local ar, ab = rR, rB
			if s < 0 then
				ar, ab = lR, lB
			end
			-- lag: upper wings follow the arm fast, lower ones slower
			local a = 1 - math.exp(-dt * sp.rate)
			w.r += (ar - ePush + eRad * 0.25 - w.r) * a
			local yawT = sp.yaw + math.max(ab, 0) * 0.5 + math.min(ab, 0) * 1.1
			w.yawS += (yawT - w.yawS) * a
			local ripple = math.sin(t * 1.5 + sp.ph) * 0.05
			local r = w.r + ripple
			local base = tcf
				* CF(s * 0.35, sp.y - c.chestY + ripple * 0.6, 0.6)
				* ANG(0, -s * w.yawS, 0)
				* ANG(-0.12 + ripple, 0, 0)
			Core.put(w.bone, base * ANG(0, 0, -s * ((sp.p0 - 0.1) * (1 - 0.22 * r) - 0.4 * r)) * CF(0, sp.l0 * 0.31, -0.04))
			for j, f in w.feathers do
				local phi = sp.p0 + (sp.p1 - sp.p0) * (j - 1) / (NF - 1)
				phi = phi * (1 - 0.22 * r) - 0.4 * r
				Core.put(f, base * ANG(0, 0, -s * phi) * CF(0, f.Size.Y / 2, 0.03 * j))
				f.Transparency = if glitching and rng:NextNumber() < 0.45 then 1 else 0.04 * (1 - eReb)
			end
		end
		-- halo radius: pulled in while praying, pops wide on radiate
		local sG, sRad = Sync.since(bus, "gather"), Sync.since(bus, "radiate")
		local praying = sG < sRad and sG < 1.2
		inflow.Enabled = praying
		local pull = if praying then smooth01(sG / 0.5) else 0
		haloR = 1.3 * (1 - pull * 0.4) * (1 + eRad * 0.6)
		local haloTr = if praying then 0.05 + pull * 0.3 else 0.05 * (1 - eRad)
		B.setBeamsTransparency(haloIn.beams, haloTr)
		B.setBeamsTransparency(haloOut.beams, 0.35 * (1 - eRad) + pull * 0.3)
		-- pillar flares wide on radiate
		local wide = 1 + eRad * 1.6 + Sync.env(bus, "flap", 5) * 0.15
		for i, b in pillar do
			b.Width0 = pillarW[i][1] * wide
			b.Width1 = pillarW[i][2] * wide
		end
		-- lights: drain while praying, pop on beats, surge on radiate
		local pop = Sync.env(bus, "flap", 6) * 0.8 + eReb * 1.5
		rootL.Brightness = rootL.Brightness * (1 - pull * 0.55) + eRad * 5 + pop
		haloL.Brightness = 2 * (1 - pull * 0.5) + eRad * 6 + pop * 2
		haloAtt.Position = (headLocal * CF(0, hUp, 0)).Position
		-- downdraft rings fade out as they spread
		for _, d in drafts do
			local s = os.clock() - d.t0
			B.setBeamsTransparency(d.cir.beams, if s < 1.1 then 0.1 + s / 1.1 * 0.9 else 1)
		end
		-- code glyphs: circle the halo, converge while praying, garbage while glitching
		local change = t >= nextC
		if change then
			nextC = t + 0.12
		end
		local hcf = haloCF(t)
		local spin = Sync.phase(bus, BEAT) * TAU * 0.9 * BEAT
		local cr = 1.75 * (1 - pull * 0.55) * (1 + eRad * 0.8)
		for i, g in code do
			local ang = (i - 1) / 12 * TAU - spin
			g.att.Position = (hcf * CF(math.cos(ang) * cr, 0.1, math.sin(ang) * cr)).Position
			if glitching then
				if change then
					g.lbl.Text = GARBAGE[rng:NextInteger(1, #GARBAGE)]
				end
				g.lbl.TextColor3 = if rng:NextNumber() < 0.3 then Color3.fromRGB(255, 43, 214) else c.c2
			else
				g.lbl.TextColor3 = c.c2:Lerp(WHITE, eRad)
				if change and rng:NextNumber() < 0.3 then
					g.lbl.Text = if rng:NextNumber() < 0.5 then "0" else "1"
				end
			end
		end
	end)
end

-- blue panels with sad face text orbiting, error popups
-- parts ~67, emitters 11
-- Synced to the Blender animation (tools/blender/anim/auras/BlueScreen.py, grounded set, idle
-- 6.0 s). The body IS the PC that crashes, the screens around it crash with it:
--   "key" R/L    finger tap while typing   -> blue/white pixels fly off that hand
--   "enter"      the enter-key slam         -> an error popup opens right in front of the player
--   "lag"        dropped frames / rewind    -> the orbiting panels hitch BACKWARDS, pixels re-scatter
--   "crash"      snap into the frozen T-pose -> BLUE SCREEN flash, every popup bursts open, the
--                                            panels kick outward and FREEZE, "% complete" races
--                                            0 -> 100 during the freeze, chest pixel burst
--   "glitch"     arm + head drop out of it  -> dead pixels re-scatter, chest burst, panels flicker
--   "restart"    the body powers off        -> lights out: screens go black, light dims, spinner,
--                                            pixels, popups hidden, emitters off until "boot"
--   "boot"       snaps upright              -> white flash, screens back at "0% complete", burst
--   "scratch"    hand on the back of the head -> little pixel squares pop off the head
--   "shrug"      ":(" arms out               -> an error popup spawns at EACH hand, soft flash
--   walk "lag"   dropped frames in the gait  -> panels hitch backwards, pixels re-scatter
--   "step" (free)                           -> a puff of blue pixel squares at that foot
-- And the other way round: every 6-10 s of walking the VFX fires "freeze" -> the body's "frozen"
-- reaction (T-pose slide): "stall" = flash + popups + panels freeze, "unfreeze" = resume + puff.
-- Landing ("stumble" reaction) -> "impact": floor pixel burst + flash.
A.BlueScreen = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
	type Panel = { body: BasePart, bar: BasePart, pct: TextLabel }
	local panels: { Panel } = {}
	local pcts: { TextLabel } = {}
	local guis: { SurfaceGui } = {}
	local function bsod(part: BasePart, face: Enum.NormalId, pps: number): TextLabel
		local sg = Core.surface(part, face, pps)
		table.insert(guis, sg)
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
	local codes = { "0x000000EF", "0x0000007B", "0xC000021A", "0x00000050", "0x0000001E", "0x00000133", "0x0000009F" }
	local msgs = {
		"Critical process died.",
		"Inaccessible boot device.",
		"Page fault in nonpaged area.",
		"Kernel security check failure.",
		"IRQL not less or equal.",
		"DPC watchdog violation.",
		"Driver power state failure.",
	}
	local PW, PH = 1.9, 1.05
	for i = 1, 7 do
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
		local ok =
			Core.frame(sg, Color3.fromRGB(200, 205, 215), UDim2.fromScale(0.7, 0.72), UDim2.fromScale(0.24, 0.18))
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
		pixels[i] =
			{ p = Core.part(c, V(0.4, 0.4, 0.4), if i % 3 == 0 then WHITE else c.c1), cf = CF(0, -50, 0), nextT = 0 }
	end
	B.sigil(
		c,
		{ radius = 6.6, color = c.c1, color2 = c.c2, ticks = 16, spokes = 8, glow = 0.88, spin = 0.35, pulse = 3.4 }
	)
	local torso = Core.att(c, c.torso)
	local eSquares = Core.emit(torso, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.25, 0),
		rate = 16,
		life = nr(0.5, 0.9),
		speed = nr(3, 6),
		spread = V2(180, 180),
		rot = nr(0, 0),
	})
	local eSparks = Core.emit(torso, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0, 0.45, 0),
		rate = 10,
		life = nr(0.8, 1.2),
		speed = nr(1, 2),
		spread = V2(180, 180),
	})
	local eGlow = Core.emit(torso, {
		tex = T.glow,
		color = cs(c.c1),
		size = ns(4, 6),
		transp = ns(0.82, 1),
		rate = 3,
		life = nr(0.8, 1.2),
		locked = true,
	})
	local eFloor = B.floorEmit(c, 5.5, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.3, 0),
		transp = ns(0.05, 1),
		rate = 22,
		life = nr(1.4, 2.2),
		speed = nr(1.5, 3.5),
		rot = nr(0, 0),
	})
	local idleRates = { [eSquares] = 16, [eSparks] = 10, [eGlow] = 3, [eFloor] = 22 }
	-- burst emitters (rate 0) fired by the animation's markers
	local chestBurst = Core.emit(Core.tip(c, "chest") or torso, {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.5, 0.1),
		rate = 0,
		life = nr(0.4, 0.9),
		speed = nr(10, 20),
		spread = V2(180, 180),
		drag = 3,
		rot = nr(0, 0),
		bright = 3,
	})
	local function pixFx(which: string, spread: number, speed: number): ParticleEmitter?
		local att = Core.tip(c, which)
		if not att then
			return nil
		end
		return Core.emit(att, {
			tex = T.square,
			color = cs(WHITE, c.c1),
			size = ns(0.22, 0.04),
			rate = 0,
			life = nr(0.25, 0.55),
			speed = nr(speed * 0.6, speed),
			spread = V2(spread, spread),
			dir = Enum.NormalId.Bottom,
			accel = V(0, -10, 0),
			drag = 2,
			rot = nr(0, 0),
			bright = 2,
		})
	end
	local hands: { [string]: ParticleEmitter? } = { R = pixFx("rhand", 60, 7), L = pixFx("lhand", 60, 7) }
	local feet: { [string]: ParticleEmitter? } = { R = pixFx("rfoot", 85, 5), L = pixFx("lfoot", 85, 5) }
	local headFx = pixFx("head", 180, 5)
	local handAtt: { [string]: Attachment? } = { R = Core.tip(c, "rhand"), L = Core.tip(c, "lhand") }
	local floorAtt = Core.att(c, nil, CF(0, c.groundY + 0.12, 0))
	local floorShock = Core.emit(floorAtt, {
		tex = T.shock,
		color = cs(WHITE, c.c1),
		size = ns(1, 14),
		transp = ns(0.1, 1),
		rate = 0,
		life = nr(0.5, 0.5),
		speed = nr(0.01, 0.01),
		orient = PERP,
		bright = 3,
	})
	local floorPix = Core.emit(floorAtt, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.4, 0.1),
		rate = 0,
		life = nr(0.5, 1),
		speed = nr(8, 14),
		spread = V2(70, 70),
		accel = V(0, -35, 0),
		rot = nr(0, 0),
	})
	local light = B.rootLight(c, c.c1, 2.8, 18)

	-- sync state --------------------------------------------------------------------------
	local now = 0
	local lastRoot = CFrame.identity
	local orbit = 0 -- accumulated panel orbit angle (frozen / rewound by the body)
	local flicker = 0 -- panel flicker until (t)
	local function frozen(): boolean
		local sc, sr = Sync.since(bus, "crash"), Sync.since(bus, "restart")
		local ss, su = Sync.since(bus, "stall"), Sync.since(bus, "unfreeze")
		return (sc < sr and sc < 1.8) or (ss < su and ss < 1.3)
	end
	local function off(): boolean
		local sr = Sync.since(bus, "restart")
		return sr < Sync.since(bus, "boot") and sr < 0.85
	end
	local function scatter()
		for _, q in pixels do
			q.nextT = 0
		end
	end
	local function openPop(cf: CFrame, life: number, delay: number?)
		-- the popup with the oldest start gets reused
		local best: Pop? = nil
		for _, p in pops do
			if not best or p.t0 < best.t0 then
				best = p
			end
		end
		if best then
			best.t0 = now + (delay or 0)
			best.life = life
			best.cf = cf
		end
	end
	local function popAround(delay: number)
		local a = rng:NextNumber() * TAU
		openPop(
			outward(a, 3 + rng:NextNumber() * 1.6, c.chestY - 0.2 + rng:NextNumber() * 2.4)
				* ANG(0, 0, (rng:NextNumber() - 0.5) * 0.3),
			1.3 + rng:NextNumber() * 0.6,
			delay
		)
	end
	local poweredOff = false
	local function setPower(on: boolean)
		if poweredOff == not on then
			return
		end
		poweredOff = not on
		for _, g in guis do
			g.Enabled = on
		end
		for e, r in idleRates do
			e.Rate = if on then r else 0
		end
		for _, p in panels do
			p.body.Color = if on then c.c1 else Color3.fromRGB(6, 8, 14)
			p.bar.Transparency = if on then 0 else 1
		end
		monitor.Color = if on then c.c1 else Color3.fromRGB(6, 8, 14)
		monFrame.Transparency = if on then 0 else 0.85
	end
	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	on("key", function(side)
		local e = hands[if side == "L" then "L" else "R"]
		if e then
			e:Emit(5)
		end
	end)
	on("enter", function()
		-- right in front of the player, facing the camera side of the character
		openPop(outward(-math.pi / 2, 2.6, c.chestY + 0.9), 1.4)
		local e = hands.R
		if e then
			e:Emit(10)
		end
	end)
	on("lag", function()
		orbit -= 0.22 -- rewind
		scatter()
	end)
	on("crash", function()
		for i = 1, 4 do
			popAround((i - 1) * 0.06)
		end
		chestBurst:Emit(30)
		floorShock:Emit(1)
	end)
	on("glitch", function()
		scatter()
		chestBurst:Emit(14)
		flicker = now + 0.12
	end)
	on("boot", function()
		chestBurst:Emit(24)
		floorPix:Emit(18)
		scatter()
	end)
	on("scratch", function()
		if headFx then
			headFx:Emit(12)
		end
	end)
	on("shrug", function()
		for side, att in handAtt do
			if att then
				local lp = lastRoot:PointToObjectSpace(att.WorldPosition)
				local a = math.atan2(lp.Z, lp.X)
				local r = math.max(1.6, math.sqrt(lp.X * lp.X + lp.Z * lp.Z) + 0.9)
				openPop(outward(a, r, lp.Y + 0.9) * ANG(0, 0, if side == "R" then -0.12 else 0.12), 1.5)
			end
			local e = hands[side]
			if e then
				e:Emit(10)
			end
		end
	end)
	on("step", function(side)
		local e = feet[if side == "L" then "L" else "R"]
		if e then
			e:Emit(4)
		end
	end)
	on("stall", function()
		for i = 1, 3 do
			popAround((i - 1) * 0.05)
		end
		chestBurst:Emit(20)
	end)
	on("unfreeze", function()
		chestBurst:Emit(10)
		floorPix:Emit(10)
	end)
	on("impact", function()
		floorShock:Emit(1)
		floorPix:Emit(22)
	end)
	local nextFreeze = Sync.age(bus) + 6 + rng:NextNumber() * 4

	local lastPct = ""
	Core.on(c, function(t, dt, root)
		now = t
		lastRoot = root
		-- walking long enough -> the PC hangs mid-stride (the body's "frozen" reaction)
		local age = Sync.age(bus)
		if Sync.get(bus, "move") > 0.6 and Sync.get(bus, "air") < 0.5 then
			if age >= nextFreeze then
				nextFreeze = age + 6 + rng:NextNumber() * 4
				Sync.emit(bus, "freeze")
			end
		elseif age > nextFreeze - 2 then
			nextFreeze = age + 2 + rng:NextNumber() * 2
		end
		local isFrozen, isOff = frozen(), off()
		setPower(not isOff)
		if not isFrozen and not isOff then
			orbit += dt * 0.35
		end
		-- "% complete": races to 100 during a crash freeze, counts slowly otherwise
		local pctN
		local sc = Sync.since(bus, "crash")
		if isFrozen and sc < 1.8 then
			pctN = math.min(100, math.floor(sc / 1.5 * 100))
		else
			local sb = Sync.since(bus, "boot")
			pctN = math.floor(((if sb < math.huge then sb else t) * 7) % 101)
		end
		local s = pctN .. "% complete"
		if s ~= lastPct then
			lastPct = s
			for _, l in pcts do
				l.Text = s
			end
		end
		-- kick outward on the crash / stall, hitch on lag
		local kick = math.max(Sync.env(bus, "crash", 5), Sync.env(bus, "stall", 6)) * 1.3
		local bob = if isFrozen or isOff then 0 else 1
		local flick = t < flicker
		for i, p in panels do
			local a = (i - 1) / 6 * TAU + orbit
			local cf = root
				* outward(a, 5.2 + kick, c.chestY + 0.4 + math.sin(t * 1.2 + i) * 0.3 * bob)
				* (if isFrozen and not isOff then CF(rng:NextNumber() * 0.04, 0, 0) else CFrame.identity)
			Core.put(p.body, cf)
			Core.put(p.bar, cf * CF(0, 0.84, 0))
			p.body.Transparency = if flick and i % 2 == 0 then 1 else 0
		end
		local mcf = root
			* CF(0, c.topY + 2.4 + math.sin(t * 0.8) * 0.15 * bob, 2.4 + kick * 0.3)
			* ANG(0, math.pi, 0)
			* ANG(-0.15, 0, 0)
		Core.put(monitor, mcf)
		Core.put(monFrame, mcf * CF(0, 0, 0.02))
		for _, p in pops do
			local pa = t - p.t0
			if pa > p.life + 0.3 and not isOff then
				p.t0 = t + rng:NextNumber() * 0.6
				p.life = 1.2 + rng:NextNumber()
				pa = p.t0 - t -- negative: waiting
				local a = rng:NextNumber() * TAU
				local r = 3 + rng:NextNumber() * 1.6
				p.cf = outward(a, r, c.chestY - 0.2 + rng:NextNumber() * 2.4)
					* ANG(0, 0, (rng:NextNumber() - 0.5) * 0.3)
			end
			local sz
			if isOff or pa < 0 or pa > p.life then
				sz = 0.05
			elseif pa < 0.12 then
				sz = 0.2 + pa / 0.12 * 0.9
			elseif pa < 0.2 then
				sz = 1.1 - (pa - 0.12) / 0.08 * 0.1
			else
				sz = 1
			end
			local hidden = sz < 0.1
			p.win.Size = V(PW * sz, PH * sz, 0.05)
			p.title.Size = V(PW * sz, 0.22 * sz, 0.06)
			p.win.Transparency = if hidden then 1 else 0
			p.title.Transparency = if hidden then 1 else 0
			p.x.Transparency = if hidden then 1 else 0
			local cf = root * p.cf
			Core.put(p.win, cf)
			Core.put(p.title, cf * CF(0, (PH / 2 + 0.11) * sz, 0))
			Core.put(p.x, cf * CF((PW / 2 - 0.12) * sz, (PH / 2 + 0.11) * sz, -0.03))
		end
		local scf = CFrame.lookAt((root * CF(0, c.topY + 1.2, 0)).Position, camPos())
		for i, d in spinner do
			local a = (i - 1) * 0.4 - (if isFrozen then 0 else t * 5)
			Core.put(d, scf * CF(math.cos(a) * 0.55, math.sin(a) * 0.55, 0))
			d.Transparency = if isOff then 1 else (i - 1) / 9
		end
		for _, q in pixels do
			if t >= q.nextT and not isFrozen then
				q.nextT = t + 0.08 + rng:NextNumber() * 0.2
				local a = rng:NextNumber() * TAU
				local r = 2 + rng:NextNumber() * 4.5
				q.cf = CF(math.cos(a) * r, c.groundY + 0.5 + rng:NextNumber() * 5, math.sin(a) * r)
				local ps = 0.15 + rng:NextNumber() * 0.5
				q.p.Size = V(ps * (1 + rng:NextNumber() * 2), ps, ps)
				q.p.Transparency = if rng:NextNumber() < 0.25 then 1 else 0
			end
			if isOff then
				q.p.Transparency = 1
				q.nextT = 0
			end
			Core.put(q.p, root * q.cf)
		end
		-- light: blue-screen flash on crash / stall, white boot flash, soft shrug flash, dark when off
		if isOff then
			light.Brightness = 0.25
			light.Color = c.c1
		else
			local fl = math.max(
				Sync.env(bus, "crash", 4) * 7,
				Sync.env(bus, "stall", 5) * 6,
				Sync.env(bus, "glitch", 12) * 5,
				Sync.env(bus, "shrug", 4) * 3.5,
				Sync.env(bus, "impact", 7) * 4,
				Sync.env(bus, "enter", 8) * 2.5
			)
			local boot = Sync.env(bus, "boot", 4)
			light.Brightness = math.max(2.4 + Core.pulse(t, 1.5) * 0.8, fl, boot * 7)
			light.Color = c.c1:Lerp(WHITE, boot)
		end
	end)
end

---------------------------------------------------------------- CORRUPTED

-- black-red tearing shards, ground cracks, inverted ghosts
-- parts ~88, emitters 15
-- Synced to the Blender animation (tools/blender/anim/auras/Corruption.py, grounded broken-doll
-- set, idle 6.0 s). The damaged save file tears around the body exactly when the body breaks:
--   "snap" head/rarm/larm  CONST limb snap   -> square burst from that limb, the 4 shards nearest
--                                             to it tear outward, red light flick, title glitches
--   "rollback"   the pose jumps back/forward  -> every shard jumps back along its orbit in step
--                                             with the pose, halo flickers, crack glow drops,
--                                             title "LOADING BACKUP..."
--   "stomp" R    the huge right-foot stomp    -> cracks flash and a glow wave runs out of them,
--                                             floor shockwave + red debris + smoke, EVERY shard
--                                             tears, big light flash, sparks from the foot
--                (walk "stomp" R = the limp's heavy step: a smaller crack pulse + shock + sparks;
--                 "stomp" "land" from the landing reaction = the full version)
--   "rip" rhand  the claw rips down           -> a red tear streak stays in the air along the hand's
--                                             path, fire sparks + black squares spray from the
--                                             hand, shards tear
--   "twitch" head/body                       -> title corrupts, small square burst from head/chest
--   walk "glitch" L  the dragged leg twitches -> square burst at the left foot, title glitch
--   "step" (free)                            -> dark smoke puff at that foot
-- And the other way round: every 4-7 s the VFX fires "tear" (a big shard rips loose and flies
-- out); the body's "wrench" reaction (CONST spine spasms) answers with "wrench" -> chest burst.
A.Corruption = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
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
		tamp: number,
		tdur: number,
		tdir: CFrame,
		pos: Vector3,
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
			tamp = 1.4,
			tdur = 0.45,
			tdir = CFrame.identity,
			pos = Vector3.zero,
		}
	end
	local now = 0
	local function tearShard(s: Shard, amp: number, dur: number)
		s.tear = now
		s.tamp = amp
		s.tdur = dur
		s.tdir = ANG((rng:NextNumber() - 0.5) * 2 * (amp / 1.4), (rng:NextNumber() - 0.5) * 2, 0)
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
	-- corrupted block halo, glitch-jumping (strobes while the save rolls back)
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
			if Sync.window(bus, "rollback", 0.3) >= 0 then
				p.Transparency = if (k + math.floor(t * 30)) % 2 == 0 then 1 else 0
				p.Size = V(0.5, 0.5, 0.5)
				return
			end
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
	-- burst emitters (rate 0), fired by the animation's markers --------------------------
	local floorAtt = Core.att(c, nil, CF(0, g + 0.12, 0))
	local floorShock = Core.emit(floorAtt, {
		tex = T.shock,
		color = cs(c.c1, blood),
		size = ns(1, 22),
		transp = ns(0.05, 1),
		rate = 0,
		life = nr(0.65, 0.65),
		speed = nr(0.01, 0.01),
		orient = PERP,
		bright = 3,
	})
	local floorDebris = Core.emit(floorAtt, {
		tex = T.square,
		color = cs(c.c1, BLACK),
		size = ns(0.5, 0.12),
		rate = 0,
		life = nr(0.6, 1.1),
		speed = nr(10, 20),
		spread = V2(70, 70),
		accel = V(0, -40, 0),
		rot = nr(0, 0),
		light = 0.5,
	})
	local floorSmoke = Core.emit(floorAtt, {
		tex = T.smoke,
		color = cs(BLACK, Color3.fromRGB(50, 0, 10)),
		size = ns(2, 6),
		transp = ns(0.35, 1),
		rate = 0,
		life = nr(1, 1.6),
		speed = nr(6, 10),
		spread = V2(85, 85),
		drag = 3,
		light = 0,
		rotSpeed = nr(-60, 60),
	})
	type Tip = { att: Attachment, sq: ParticleEmitter, sp: ParticleEmitter }
	local function tipFx(which: string, spread: number): Tip?
		local att = Core.tip(c, which)
		if not att then
			return nil
		end
		return {
			att = att,
			sq = Core.emit(att, {
				tex = T.square,
				color = cs(c.c1, BLACK),
				size = ns(0.42, 0.08),
				rate = 0,
				life = nr(0.25, 0.55),
				speed = nr(7, 13),
				spread = V2(180, 180),
				drag = 3,
				rot = nr(0, 0),
				light = 0.6,
			}),
			sp = Core.emit(att, {
				tex = T.fireSpark,
				color = cs(WHITE, c.c1, blood),
				size = ns(0.4, 0),
				rate = 0,
				life = nr(0.3, 0.7),
				speed = nr(10, 20),
				spread = V2(spread, spread),
				dir = Enum.NormalId.Bottom,
				accel = V(0, -18, 0),
				drag = 2,
				bright = 4,
			}),
		}
	end
	local tips: { [string]: Tip? } = {
		head = tipFx("head", 180),
		rarm = tipFx("rhand", 50),
		larm = tipFx("lhand", 50),
		rhand = nil,
		chest = tipFx("chest", 180),
		R = tipFx("rfoot", 80),
		L = tipFx("lfoot", 80),
	}
	tips.rhand = tips.rarm
	tips.body = tips.chest
	local function footSmoke(which: string): ParticleEmitter?
		local att = Core.tip(c, which)
		return if att
			then Core.emit(att, {
				tex = T.smoke,
				color = cs(BLACK, Color3.fromRGB(40, 0, 8)),
				size = ns(1, 2.6),
				transp = ns(0.4, 1),
				rate = 0,
				life = nr(0.6, 1),
				speed = nr(1.5, 3),
				spread = V2(80, 80),
				dir = Enum.NormalId.Bottom,
				light = 0,
				rotSpeed = nr(-40, 40),
			})
			else nil
	end
	local puffs: { [string]: ParticleEmitter? } = { R = footSmoke("rfoot"), L = footSmoke("lfoot") }
	-- the claw's tear streak: a trail along the right arm, enabled for the rip
	local ripTrail: Trail? = nil
	do
		local a0, a1 = Core.tip(c, "rhand", CF(0, 0.9, 0)), Core.tip(c, "rhand", CF(0, -0.05, 0))
		if a0 and a1 then
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Color = ColorSequence.new(WHITE, c.c1)
			tr.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.4, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			})
			tr.Lifetime = 0.75
			tr.LightEmission = 1
			tr.LightInfluence = 0
			tr.MinLength = 0.05
			tr.Enabled = false
			tr.Parent = a0
			ripTrail = tr
		end
	end
	local light = B.rootLight(c, c.c1, 3, 20)

	-- sync ---------------------------------------------------------------------------------
	local lastRoot = CFrame.identity
	local stompK, stompAt = 0, -10 -- strength (0..1) and time of the last stomp
	local function nearest(att: Attachment?, n: number)
		if not att then
			return
		end
		local lp = lastRoot:PointToObjectSpace(att.WorldPosition)
		local list = table.clone(shards)
		table.sort(list, function(x, y)
			return (x.pos - lp).Magnitude < (y.pos - lp).Magnitude
		end)
		for i = 1, math.min(n, #list) do
			tearShard(list[i], 2.2, 0.55)
		end
	end
	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	on("snap", function(which)
		local tp = tips[tostring(which)]
		if tp then
			tp.sq:Emit(20)
			tp.sp:Emit(8)
			nearest(tp.att, 4)
		end
	end)
	local function stomp(k: number, foot: string?)
		stompK, stompAt = k, now
		floorShock:Emit(if k > 0.7 then 2 else 1)
		floorDebris:Emit(math.floor(36 * k))
		floorSmoke:Emit(math.floor(12 * k))
		for _, s in shards do
			if k > 0.7 or rng:NextNumber() < 0.3 then
				tearShard(s, 1.4 + 1.6 * k, 0.4 + 0.25 * k)
			end
		end
		local which: { string } = if foot then { foot } else { "R", "L" }
		for _, f in which do
			local tp = tips[f]
			if tp then
				tp.sp:Emit(math.floor(22 * k))
				tp.sq:Emit(math.floor(10 * k))
			end
		end
	end
	on("stomp", function(arg)
		if arg == "land" then
			stomp(1, nil)
		elseif Sync.get(bus, "move") > 0.5 then
			stomp(0.4, "R") -- the limp's heavy right step
		else
			stomp(1, "R")
		end
	end)
	on("rip", function()
		local tp = tips.rhand
		if tp then
			tp.sp:Emit(30)
			tp.sq:Emit(24)
			nearest(tp.att, 6)
		end
	end)
	on("twitch", function(which)
		local tp = tips[if which == "body" then "chest" else "head"]
		if tp then
			tp.sq:Emit(12)
		end
	end)
	on("glitch", function(side)
		local tp = tips[if side == "R" then "R" else "L"]
		if tp then
			tp.sq:Emit(16)
			tp.sp:Emit(6)
		end
	end)
	on("step", function(side)
		local e = puffs[if side == "L" then "L" else "R"]
		if e then
			e:Emit(3)
		end
	end)
	on("wrench", function()
		local tp = tips.chest
		if tp then
			tp.sq:Emit(26)
			tp.sp:Emit(12)
		end
	end)
	local nextTear = Sync.age(bus) + 4 + rng:NextNumber() * 3

	Core.on(c, function(t, _, root)
		now = t
		lastRoot = root
		local age = Sync.age(bus)
		if age >= nextTear then
			nextTear = age + 4 + rng:NextNumber() * 3
			tearShard(shards[rng:NextInteger(1, #shards)], 6, 1.1) -- a big shard rips loose
			Sync.emit(bus, "tear")
		end
		if ripTrail then
			ripTrail.Enabled = Sync.window(bus, "rip", 0.22) >= 0
		end
		Core.put(disc, root * CF(0, g + 0.02, 0) * FLAT)
		-- cracks: the slow glow crawl, a flash + outward glow wave on each stomp, dim on rollback
		local rolling = Sync.window(bus, "rollback", 0.3) >= 0
		local base = if rolling then 0.85 else 0.4
		local sAge = t - stompAt
		local sFlash = if sAge < 1.5 then math.exp(-sAge * 3) * stompK else 0
		for _, ck in cracks do
			for j, bm in ck.beams do
				local w = ((t * 0.8 + ck.off) % 1) * 7 - j
				local ws = sAge * 16 - j
				local wave = if sAge < 1.5 then math.exp(-ws * ws * 0.5) * stompK else 0
				bm.Transparency =
					NumberSequence.new(math.clamp(base - math.exp(-w * w) * 0.4 - sFlash * 0.35 - wave * 0.4, 0, 1))
			end
		end
		-- shards: orbit + tears; the rollback jumps them back along the orbit in CONST steps
		local rb = Sync.window(bus, "rollback", 0.27)
		local back = if rb >= 0 and math.floor(rb * 4) % 2 == 0 then 0.9 else 0
		for _, s in shards do
			if rng:NextNumber() < 0.002 then
				tearShard(s, 1.4, 0.45)
			end
			local sa = t - s.tear
			local k = if sa < 0.1 then 1 elseif sa < s.tdur then 1 - smooth01((sa - 0.1) / (s.tdur - 0.1)) else 0
			local a = s.a + t * s.w - back * math.sign(s.w)
			local r = s.r + k * s.tamp
			local lp = V(math.cos(a) * r, s.y + math.sin(t + s.a) * 0.3 + k * (s.tamp - 1.4) * 0.3, math.sin(a) * r)
			s.pos = lp
			local cf = root * CF(lp) * s.rot * ANG(t * s.w, 0, 0)
			if k > 0 then
				cf *= CFrame.identity:Lerp(s.tdir, k)
			end
			Core.put(s.slab, cf)
			Core.put(s.edge, cf * CF(0.01, 0, s.slab.Size.Z / 2))
		end
		-- title: rollback message, corruption bursts on snaps / twitches / glitches
		local hit = math.max(
			Sync.window(bus, "snap", 0.25),
			Sync.window(bus, "twitch", 0.2),
			Sync.window(bus, "glitch", 0.2),
			Sync.window(bus, "rip", 0.3)
		) >= 0
		if Sync.window(bus, "rollback", 0.6) >= 0 then
			err.Text = "LOADING BACKUP..."
			err.TextTransparency = if math.floor(t * 12) % 2 == 0 then 0 else 0.5
		elseif hit then
			err.Text = if rng:NextNumber() < 0.5 then "S@VE F1LE C0RRUPT#D" else "5AV3 ##LE CORR\\/PTED"
			err.TextTransparency = if rng:NextNumber() < 0.35 then 0.8 else 0
		else
			err.TextTransparency = if rng:NextNumber() < 0.1 then 0.8 else 0
			err.Text = if rng:NextNumber() < 0.04 then "S@VE F1LE C0RRUPT#D" else "SAVE FILE CORRUPTED"
		end
		-- light: stomp flash, snap / rip flicks, a drop while rolling back
		local fl = math.max(
			sFlash * 10,
			Sync.env(bus, "snap", 10) * 6,
			Sync.env(bus, "rip", 6) * 7,
			Sync.env(bus, "wrench", 8) * 5,
			Sync.env(bus, "twitch", 14) * 4
		)
		light.Brightness = if rolling then 0.6 else math.max(2.4 + math.noise(t * 5, 1) * 3, fl)
	end)
end

-- violent red glitch storm, warning triangles, shaking light
-- parts ~76, emitters 12
-- Synced to the Blender animation (tools/blender/anim/auras/KernelPanic.py, grounded set, idle
-- 5.0 s). The body is the crashing machine; the storm answers every move it makes:
--   "alarm" L/R  head whips to a side   -> both searchlights snap onto that side and sweep it,
--                                          the triangles on that side flare white, alarm flash
--   "spasm"      CONST seizure frames    -> every glitch block re-scatters at once, square +
--                                          spark burst from the chest, the title tears, strobe
--   "clutch"     hands on the temples    -> the error streams collapse into a tight scrolling
--                                          ring around the head, sparks from the head
--   "scream"     arched back, arms flung -> fire-spark sprays from both hands, the triangles are
--                                          blown outward, the title swells, light surge
--   "slam"       fists slam down         -> floor shock + smoke burst, two lightning bolts
--                                          strike right beside the player, big flash
--   "blackout"   the body goes limp      -> LIGHTS OUT until "reboot": light, title, triangles,
--                                          searchlights and blocks off, emitters throttled
--   "reboot"     rigid boot pose         -> white flash, "REBOOTING..." title, blocks burst back
--   walk "hitch" R/L stumble stutter     -> sparks burst from that foot, blocks re-scatter
--   "step"  (free) each footfall         -> small red spark puff at that foot
--   "impact" (landing reaction)          -> floor shock + smoke puff
-- And the other way round: every 3.5-6.5 s the VFX fires "strike" (a huge bolt hits the ground
-- next to the player); the body's "jolt" reaction (electrocution) answers with "zap" ->
-- spark bursts from both hands and the chest + white flash.
A.KernelPanic = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
	local amber = Color3.fromRGB(255, 190, 0)
	type Blk = { p: BasePart, cf: CFrame, nextT: number }
	local blocks: { Blk } = {}
	for i = 1, 28 do
		blocks[i] =
			{ p = Core.part(c, V(0.3, 0.3, 0.3), if i % 3 == 0 then c.c2 else c.c1), cf = CF(0, -50, 0), nextT = 0 }
	end
	local TS = 1.7
	type Tri = { bars: { BasePart }, att: Attachment, lbl: TextLabel, a: number, y: number, col: Color3, lit: boolean }
	local tris: { Tri } = {}
	for i = 1, 6 do
		local att, lbl = B.glyph(c, "!", amber, V2(0.9, 0.9), F.tech, nil, BLACK)
		lbl.TextStrokeTransparency = 0
		local col = if i % 2 == 0 then amber else c.c1
		tris[i] = {
			bars = B.tri(c, TS, 0.15, col),
			att = att,
			lbl = lbl,
			a = (i - 1) / 6 * TAU,
			y = c.chestY + (i % 2) * 1.6 - 0.1,
			col = col,
			lit = false,
		}
	end
	local function lightsOut(): boolean
		return Sync.since(bus, "blackout") < Sync.since(bus, "reboot")
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
			active = function()
				return not lightsOut()
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
			active = function()
				return not lightsOut()
			end,
		})
	end
	-- synced strikes: the "strike" event (VFX timer) and the body's "slam" call two fat bolts
	-- right next to the player; they never flicker while active
	local strikeAt = { V(2, c.groundY, 0), V(-2, c.groundY, 0) }
	local function striking(): boolean
		return Sync.since(bus, "strike") < 0.3 or Sync.since(bus, "slam") < 0.35
	end
	for k = 1, 2 do
		B.bolt(c, {
			segs = 12,
			color = WHITE,
			color2 = c.c1,
			width = 0.75,
			jitter = 1.6,
			interval = 0.05,
			ends = function()
				local p = strikeAt[k]
				return V(p.X * 0.3, 45, p.Z * 0.3), p + V(0, 0.05, 0)
			end,
			active = striking,
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
	local spotBeams: { Beam } = {}
	for k = 1, 2 do
		spots[k] = Core.att(c)
		spotBeams[k] = Core.beam(c, alarm, spots[k], c.c1, 0.3, { w1 = 4, tr = ns(0.4, 0.95), segs = 2 })
	end
	local torso = Core.att(c, c.torso)
	local throttled: { { e: ParticleEmitter, rate: number } } = {}
	local function keep(e: ParticleEmitter): ParticleEmitter
		table.insert(throttled, { e = e, rate = e.Rate })
		return e
	end
	keep(Core.emit(torso, {
		tex = T.fireSpark,
		color = cs(WHITE, c.c1),
		size = ns(0.4, 0),
		rate = 36,
		life = nr(0.4, 0.8),
		speed = nr(8, 14),
		spread = V2(180, 180),
		accel = V(0, -12, 0),
		bright = 3,
	}))
	local chestBurst = keep(Core.emit(torso, {
		tex = T.square,
		color = cs(WHITE, c.c1),
		size = ns(0.3, 0.1),
		rate = 20,
		life = nr(0.15, 0.3),
		speed = nr(5, 9),
		spread = V2(180, 180),
		rot = nr(0, 0),
	}))
	local smoke = keep(B.floorEmit(c, 6, {
		tex = T.smoke,
		color = cs(c.c1, Color3.fromRGB(60, 0, 0)),
		size = ns(3, 6),
		transp = ns(0.7, 1),
		rate = 8,
		life = nr(1.2, 2),
		speed = nr(1.5, 3),
		light = 0.5,
		rotSpeed = nr(-60, 60),
	}))
	local storm = Core.volume(c, V(14, 10, 14), CF(0, c.chestY + 2, 0))
	keep(Core.emit(storm, {
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
	}))
	local glow = keep(Core.emit(torso, {
		tex = T.glow,
		color = cs(c.c1),
		size = ns(5, 7),
		transp = ns(0.75, 1),
		rate = 4,
		life = nr(0.3, 0.5),
		locked = true,
	}))
	-- burst emitters (rate 0, fired by the animation's markers)
	local chestSpark = Core.emit(Core.tip(c, "chest") or torso, {
		tex = T.fireSpark,
		color = cs(WHITE, c.c1),
		size = ns(0.5, 0),
		rate = 0,
		life = nr(0.4, 0.9),
		speed = nr(14, 24),
		spread = V2(180, 180),
		accel = V(0, -18, 0),
		drag = 2,
		bright = 4,
	})
	local floorAtt = Core.att(c, nil, CF(0, c.groundY + 0.12, 0))
	local floorShock = Core.emit(floorAtt, {
		tex = T.shock,
		color = cs(WHITE, c.c1),
		size = ns(1, 20),
		transp = ns(0.05, 1),
		rate = 0,
		life = nr(0.6, 0.6),
		speed = nr(0.01, 0.01),
		orient = PERP,
		bright = 3,
	})
	local floorDebris = Core.emit(floorAtt, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.45, 0.1),
		rate = 0,
		life = nr(0.5, 1),
		speed = nr(10, 18),
		spread = V2(70, 70),
		accel = V(0, -40, 0),
		rot = nr(0, 0),
	})
	type Tip = { att: Attachment, fx: ParticleEmitter }
	local function tipFx(which: string, spread: number): Tip?
		local att = Core.tip(c, which)
		if not att then
			return nil
		end
		return {
			att = att,
			fx = Core.emit(att, {
				tex = T.fireSpark,
				color = cs(WHITE, c.c1),
				size = ns(0.45, 0),
				rate = 0,
				life = nr(0.3, 0.7),
				speed = nr(10, 20),
				spread = V2(spread, spread),
				dir = Enum.NormalId.Bottom, -- out of the fingertips / soles
				accel = V(0, -16, 0),
				drag = 2,
				bright = 4,
			}),
		}
	end
	local hands: { [string]: Tip? } = { R = tipFx("rhand", 40), L = tipFx("lhand", 40) }
	local feet: { [string]: Tip? } = { R = tipFx("rfoot", 80), L = tipFx("lfoot", 80) }
	local headTip = Core.tip(c, "head")
	local headFx = if headTip
		then Core.emit(headTip, {
			tex = T.square,
			color = cs(WHITE, c.c1),
			size = ns(0.3, 0.05),
			rate = 0,
			life = nr(0.3, 0.6),
			speed = nr(4, 8),
			spread = V2(180, 180),
			rot = nr(0, 0),
		})
		else nil
	local shakeAtt = Core.att(c, c.torso)
	local shake = Core.light(shakeAtt, c.c1, 3, 22)

	local function scatter()
		for _, b in blocks do
			b.nextT = 0
		end
	end
	local function burst(tbl: { [string]: Tip? }, side: string?, n: number)
		for s, tp in tbl do
			if tp and (side == nil or side == s) then
				tp.fx:Emit(n)
			end
		end
	end
	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	on("spasm", function()
		scatter()
		chestBurst:Emit(18)
		chestSpark:Emit(10)
	end)
	on("clutch", function()
		if headFx then
			headFx:Emit(16)
		end
	end)
	on("scream", function()
		burst(hands, nil, 26)
		chestSpark:Emit(14)
	end)
	on("slam", function()
		local a = rng:NextNumber() * TAU
		strikeAt[1] = V(math.cos(a) * 2.2, c.groundY, math.sin(a) * 2.2)
		strikeAt[2] = V(-math.cos(a) * 2.6, c.groundY, -math.sin(a) * 2.6)
		floorShock:Emit(2)
		floorDebris:Emit(30)
		smoke:Emit(10)
		burst(hands, nil, 12)
	end)
	on("reboot", function()
		scatter()
		chestBurst:Emit(30)
		floorShock:Emit(1)
	end)
	on("hitch", function(side)
		burst(feet, side, 14)
		scatter()
	end)
	on("step", function(side)
		burst(feet, side, 4)
	end)
	on("impact", function()
		floorShock:Emit(1)
		floorDebris:Emit(14)
		smoke:Emit(6)
	end)
	on("zap", function()
		burst(hands, nil, 18)
		chestSpark:Emit(16)
	end)

	local nextS = 0
	local nextStrike = Sync.age(bus) + 2.5 + rng:NextNumber() * 2
	local wasOut = false
	Core.on(c, function(t, _, root)
		local out = lightsOut()
		-- the VFX side of the two-way sync: a huge bolt every 3.5-6.5 s (the body jolts)
		local age = Sync.age(bus)
		if age >= nextStrike then
			nextStrike = age + 3.5 + rng:NextNumber() * 3
			if not out and Sync.since(bus, "slam") > 1 then
				local a = rng:NextNumber() * TAU
				local r = 2.5 + rng:NextNumber() * 1.5
				strikeAt[1] = V(math.cos(a) * r, c.groundY, math.sin(a) * r)
				strikeAt[2] = V(math.cos(a + 0.5) * (r + 1.5), c.groundY, math.sin(a + 0.5) * (r + 1.5))
				Sync.emit(bus, "strike")
				floorShock:Emit(1)
				floorDebris:Emit(10)
			end
		end
		if out ~= wasOut then
			wasOut = out
			for _, th in throttled do
				th.e.Rate = if out then th.rate * 0.08 else th.rate
			end
			for _, bm in spotBeams do
				bm.Enabled = not out
			end
			glow.Enabled = not out
		end
		local eSpasm = Sync.env(bus, "spasm", 9)
		for _, b in blocks do
			if t >= b.nextT then
				b.nextT = t + 0.04 + rng:NextNumber() * 0.08
				local u = rng:NextUnitVector() * (2 + rng:NextNumber() * 6)
				b.cf = CF(u.X, c.chestY + 1 + u.Y * 1.1, u.Z) * ANG(rng:NextNumber() * TAU, rng:NextNumber() * TAU, 0)
				local s = (0.15 + rng:NextNumber() * 0.9) * (1 + eSpasm)
				b.p.Size = V(s * (0.5 + rng:NextNumber() * 2), s * (0.3 + rng:NextNumber()), s)
				b.p.Transparency = if out or rng:NextNumber() < 0.2 then 1 else 0
			end
			Core.put(b.p, root * b.cf)
		end
		-- triangles: blown outward by the scream, the alarmed side flares white
		local eScream = Sync.env(bus, "scream", 1.6)
		local alarmW = Sync.window(bus, "alarm", 0.45)
		local alarmSide = if Sync.payload(bus, "alarm") == "R" then 1 else -1
		for i, tr in tris do
			local a = tr.a + t * 1.1 + math.noise(i, t * 2) * 0.8
			local cf = outward(a, 5 + eScream * 3, tr.y + math.sin(t * 3 + i) * 0.3 + eScream * 0.8)
				* CF(jitter(rng, 0.12 + eSpasm * 0.5))
			B.putTri(tr.bars, root * cf, TS)
			tr.att.Position = (cf * CF(0, -0.08, -0.08)).Position
			local lit = alarmW >= 0 and cf.Position.X * alarmSide > 0
			if lit ~= tr.lit then
				tr.lit = lit
				for _, bar in tr.bars do
					bar.Color = if lit then WHITE else tr.col
				end
			end
			local hide = if out then 1 else 0
			if tr.bars[1].Transparency ~= hide then
				for _, bar in tr.bars do
					bar.Transparency = hide
				end
			end
			tr.lbl.TextTransparency = hide
			tr.lbl.TextStrokeTransparency = hide
		end
		-- error streams: scattered, or a tight scrolling ring around the clutched head
		local clutchW = Sync.window(bus, "clutch", 0.85)
		local headL = if headTip then root:PointToObjectSpace(headTip.WorldPosition) else V(0, c.headY, 0)
		if t >= nextS then
			nextS = t + (if clutchW >= 0 then 0.05 else 0.15)
			for i, s in streams do
				if rng:NextNumber() < (if clutchW >= 0 then 0.9 else 0.4) then
					s.lbl.Text = errs[rng:NextInteger(1, #errs)]
				end
				if clutchW < 0 then
					local a = rng:NextNumber() * TAU
					s.att.Position = V(math.cos(a) * 3.6, c.groundY + 1 + i * 1.1, math.sin(a) * 3.6)
				end
			end
		end
		for i, s in streams do
			s.lbl.TextTransparency = if out then 1 else 0
			s.lbl.TextStrokeTransparency = s.lbl.TextTransparency
			if clutchW >= 0 then
				local a = (i - 1) / #streams * TAU + t * 5
				s.att.Position = headL + V(math.cos(a) * 1.9, (i - 2.5) * 0.3, math.sin(a) * 1.9)
			end
		end
		-- searchlights: free sweep, or locked onto the side the head whipped to
		local alarmHold = Sync.window(bus, "alarm", 0.9)
		for k, sp in spots do
			local a
			if alarmHold >= 0 then
				a = (if alarmSide > 0 then 0 else math.pi) + math.sin(t * 9 + k) * 0.35 + (k - 1.5) * 0.4
			else
				a = t * 2.4 + k * math.pi
			end
			sp.Position = V(math.cos(a) * 12, c.groundY, math.sin(a) * 12)
		end
		-- title: tears on spasms, swells on the scream, reboots
		local rebootW = Sync.window(bus, "reboot", 0.5)
		title.Text = if rebootW >= 0 then "REBOOTING..." else "KERNEL PANIC"
		title.TextColor3 = if rebootW >= 0 then WHITE else c.c1
		title.TextTransparency = if out then 1 elseif rng:NextNumber() < 0.12 + eSpasm * 0.5 then 0.8 else 0
		title.TextStrokeTransparency = if out then 1 else 0
		title.Rotation = (rng:NextNumber() - 0.5) * (4 + eSpasm * 30)
		local sw = 1 + eScream * 0.35
		title.Size = UDim2.fromScale(sw, sw)
		title.Position = UDim2.fromScale((1 - sw) / 2 + (rng:NextNumber() - 0.5) * eSpasm * 0.4, (1 - sw) / 2)
		-- the light: shakes, flashes on every synced hit, dead during the blackout
		local flash = math.max(
			Sync.env(bus, "slam", 5),
			Sync.env(bus, "reboot", 6),
			Sync.env(bus, "zap", 7),
			Sync.env(bus, "strike", 6),
			eScream * 0.6,
			eSpasm * 0.7,
			Sync.env(bus, "alarm", 8) * 0.5
		)
		shakeAtt.Position = jitter(rng, 2.5)
		if out then
			shake.Brightness = 0
		else
			shake.Brightness = 1.5 + rng:NextNumber() * 6 + flash * 10
			shake.Color = if flash > 0.4 or rng:NextNumber() < 0.2 then WHITE else c.c1
		end
	end)
end

-- black hole orb above with accretion disc, particles sucked in
-- parts ~72, emitters 11
-- Synced to the Blender animation (tools/blender/anim/auras/EventHorizon.py, levitating set,
-- lift 2 studs, idle 6.0 s). The hole hangs FIXED above the real ground (it does not bob with
-- the body); the body is the thing being pulled. Everything on the floor stays on the floor.
--   "reach"   arms shoot up to the orb    -> spark streams are torn from both hands up into the
--                                           hole for the whole stretch (1.4 s), the matter
--                                           streams flare white-hot, the disc spins faster
--   "dilate"  the body freezes (time dilation) -> every emitter slows to 8 % (TimeScale), the
--                                           debris, disc and gravity well freeze, photon
--                                           ring flickers - then everything snaps back
--   "crush"   curled into a ball           -> the orb implodes, the gravity circles collapse to
--                                           the centre, a dark shock on the floor, light dims
--   "flare"   starfish burst               -> Hawking flash: jets widen, spark nova from the
--                                           chest, white floor shock, the orb overshoots, light surge
--   walk "stroke" R/L  swim pull          -> sparks torn from that hand, sucked up to the hole
--   "gulp" (reaction)                    -> orb flash + shock ring around the hole
--   "warp" (jump reaction)               -> jets flare, sparks from both feet
-- The gravity well, the debris spiral and the sigil breathing share the idle's 6 s beat
-- (Sync.phase). And the other way round: every second debris cycle a big chunk falls through
-- the horizon and the VFX fires "swallow" -> the body's "gulp" reaction (yanked toward it).
A.EventHorizon = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
	local LIFT = 2 -- the Blender set's hover height (EventHorizon.py)
	local BEAT = 6 -- idle length (s)
	local g = c.groundY
	-- the real ground under the levitating body: floor pieces and the hole ride it
	local gnd = Core.part(c, V(0.2, 0.2, 0.2), BLACK, SMOOTH, 1)
	local function groundCF(): CFrame
		return c.root.CFrame * CF(0, -c.lift, 0)
	end
	gnd.CFrame = groundCF()
	local O = V(0, c.topY + 5 + LIFT, 0) -- hole centre, ground frame
	local hot = c.c1:Lerp(WHITE, 0.6)
	local ember = Color3.fromRGB(255, 60, 20)
	local orb = Core.part(c, V(3.4, 3.4, 3.4), BLACK, SMOOTH, 0, BALL)
	local photon = Core.part(c, V(3.7, 3.7, 3.7), c.c1, FF, 0, BALL)
	local function facing(): CFrame
		local camL = gnd.CFrame:PointToObjectSpace(camPos())
		if (camL - O).Magnitude < 0.1 then
			return CF(O)
		end
		return CFrame.lookAt(O, camL) * ANG(math.pi / 2, 0, 0)
	end
	local ring1 = B.circle(c, { radius = 2.0, color = hot, width = 0.32, n = 8, anchor = facing, parent = gnd })
	local ring2 = B.circle(c, { radius = 2.6, color = c.c1, width = 0.14, n = 8, tr = 0.35, anchor = facing, parent = gnd })
	-- "local time": runs at 8 % during the time dilation (debris, disc, gravity well)
	local lt = 0
	local discSpin = 0
	local function disc(): CFrame
		-- B.ring places on the lifted root: take the lift back out
		return CF(0, -c.lift, 0) * CF(O) * ANG(0.3, lt * 0.1 + discSpin, 0.12)
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
	B.circle(c, {
		radius = 6.6,
		color = ember,
		width = 0.5,
		n = 10,
		tr = 0.6,
		anchor = function()
			return CF(O) * ANG(0.3, lt * 0.1 + discSpin, 0.12)
		end,
		parent = gnd,
	})
	local pN = Core.att(c, gnd, CF(O + V(0, 1.7, 0)))
	local pNT = Core.att(c, gnd, CF(O + V(0, 38, 0)))
	local pS = Core.att(c, gnd, CF(O - V(0, 1.7, 0)))
	local pST = Core.att(c, gnd, CF(O - V(0, 4, 0)))
	type Jet = { b: Beam, w0: number, w1: number }
	local jets: { Jet } = {}
	local function jet(b: Beam)
		table.insert(jets, { b = b, w0 = b.Width0, w1 = b.Width1 })
	end
	jet(Core.beam(c, pN, pNT, WHITE, 0.9, { w1 = 0.1, color2 = c.c1, tr = ns(0, 1) }))
	jet(Core.beam(c, pN, pNT, c.c1, 2.4, { w1 = 0.3, tr = ns(0.5, 1), zoff = -0.05 }))
	jet(Core.beam(c, pS, pST, WHITE, 0.6, { w1 = 0.05, color2 = c.c1, tr = ns(0, 1) }))
	-- matter spiralling up from the floor into the hole
	type Stream = { base: Attachment, a: number, beam: Beam }
	local streams: { Stream } = {}
	local streamTr, streamHot = ns(0.6, 0.1), ns(0.15, 0)
	for k = 1, 3 do
		local base = Core.att(c, gnd)
		local beam = Core.beam(c, base, pS, c.c1, 0.6, {
			w1 = 0.1,
			color2 = hot,
			c0 = 4,
			c1 = -2,
			segs = 20,
			tex = T.square,
			texLen = 0.6,
			texSpeed = 3,
			tr = streamTr,
		})
		streams[k] = { base = base, a = (k - 1) / 3 * TAU, beam = beam }
	end
	-- debris falling in
	type Deb = { p: BasePart, off: number, a0: number }
	local debris: { Deb } = {}
	for i = 1, 12 do
		local p = Core.part(c, V(0.35, 0.35, 0.35), if i % 2 == 0 then c.c1 else ember)
		Core.trail(p, c.c1, 0.25, 0.4, ember)
		debris[i] = { p = p, off = i / 12, a0 = rng:NextNumber() * TAU }
	end
	-- the big chunk whose fall through the horizon fires "swallow"
	local chunk = Core.part(c, V(0.9, 0.7, 0.8), hot)
	Core.trail(chunk, hot, 0.6, 0.6, ember)
	-- gravity well: circles contracting towards the player on the shared 6 s beat
	local crushK = 0
	for k = 1, 3 do
		B.circle(c, {
			radius = 9,
			color = c.c1,
			width = 0.12,
			n = 10,
			at = CF(0, g + 0.06, 0),
			parent = gnd,
			radiusFn = function()
				return (0.5 + 9 * (1 - ((lt / BEAT * 3 + k / 3) % 1))) * (1 - 0.92 * crushK)
			end,
		})
	end
	-- (own glow disc: the sigil's built-in one is placed on the lifted root)
	local sig = B.sigil(c, { radius = 9.5, color = c.c1, color2 = ember, rings = 2, glow = nil, pulse = BEAT / 2 })
	local sigDisc = Core.part(c, V(0.05, 9.5 * 2.1, 9.5 * 2.1), c.c1, NEON, 0.9, CYL)
	for _, cir in sig.circles do
		for _, a in cir.atts do
			a.Parent = gnd
		end
	end
	local emitters: { ParticleEmitter } = {}
	local function E(e: ParticleEmitter): ParticleEmitter
		table.insert(emitters, e)
		return e
	end
	-- emission volumes around the hole (anchored, moved with the ground frame)
	local vol = Core.part(c, V(16, 16, 16), BLACK, SMOOTH, 1)
	E(Core.emit(vol, {
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
	}))
	local dust = Core.part(c, V(12, 12, 12), BLACK, SMOOTH, 1)
	E(Core.emit(dust, {
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
	}))
	local torso = Core.att(c, c.torso)
	E(Core.emit(torso, {
		tex = T.spark,
		color = cs(c.c1, hot),
		size = ns(0.35, 0),
		rate = 18,
		life = nr(0.8, 1),
		speed = nr(4, 6),
		spread = V2(15, 15),
		accel = V(0, 3, 0),
	}))
	local floorAtt = Core.att(c, gnd, CF(0, g + 0.1, 0))
	E(Core.emit(floorAtt, {
		tex = T.shock,
		color = cs(c.c1),
		size = ns(14, 1),
		transp = ns(1, 0.4, 0.9),
		rate = 0.7,
		life = nr(1.4, 1.4),
		speed = nr(0.01, 0.01),
		orient = PERP,
		rot = nr(0, 360),
	}))
	-- synced bursts
	local floorFlash = E(Core.emit(Core.att(c, gnd, CF(0, g + 0.14, 0)), {
		tex = T.shock,
		color = cs(WHITE, c.c1),
		size = ns(1, 22),
		transp = ns(0.05, 1),
		rate = 0,
		life = nr(0.7, 0.7),
		speed = nr(0.01, 0.01),
		orient = PERP,
		bright = 3,
	}))
	local floorDark = E(Core.emit(Core.att(c, gnd, CF(0, g + 0.12, 0)), {
		tex = T.shock,
		color = cs(BLACK),
		size = ns(18, 0.5),
		transp = ns(0.2, 0.9),
		rate = 0,
		life = nr(0.55, 0.55),
		speed = nr(0.01, 0.01),
		orient = PERP,
		light = 0,
	}))
	local orbAtt = Core.att(c, gnd, CF(O))
	E(Core.emit(orbAtt, {
		tex = T.glow,
		color = cs(c.c1, ember),
		size = ns(9, 11),
		transp = ns(0.7, 1),
		rate = 3,
		life = nr(0.8, 1.2),
		locked = true,
	}))
	local orbShock = E(Core.emit(orbAtt, {
		tex = T.shock,
		color = cs(hot, c.c1),
		size = ns(3, 16),
		transp = ns(0.1, 1),
		rate = 0,
		life = nr(0.6, 0.6),
		speed = nr(0.01, 0.01),
		bright = 3,
	}))
	local chest = Core.tip(c, "chest") or torso
	local nova = E(Core.emit(chest, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0.7, 0),
		rate = 0,
		life = nr(0.6, 1.2),
		speed = nr(18, 32),
		spread = V2(180, 180),
		drag = 2.5,
		bright = 4,
	}))
	-- hands / feet: sparks leave the fingertips and are sucked up into the hole
	local function tipFx(which: string): ParticleEmitter?
		local att = Core.tip(c, which)
		if not att then
			return nil
		end
		return E(Core.emit(att, {
			tex = T.spark,
			color = cs(hot, c.c1),
			size = ns(0.4, 0),
			rate = 0,
			life = nr(0.7, 1.1),
			speed = nr(3, 7),
			spread = V2(30, 30),
			dir = Enum.NormalId.Bottom,
			accel = V(0, 26, 0),
			bright = 3,
		}))
	end
	local hands: { [string]: ParticleEmitter? } = { R = tipFx("rhand"), L = tipFx("lhand") }
	local feet: { ParticleEmitter? } = { tipFx("rfoot"), tipFx("lfoot") }
	local ol = Core.light(orbAtt, c.c1, 3.5, 22)
	B.rootLight(c, ember, 2, 16, { pulse = 0.9, amp = 1 })

	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	local function handBurst(side: string?, n: number)
		for s, e in hands do
			if e and (side == nil or s == side) then
				e:Emit(n)
			end
		end
	end
	on("reach", function()
		handBurst(nil, 24)
	end)
	on("crush", function()
		floorDark:Emit(2)
	end)
	on("flare", function()
		nova:Emit(70)
		floorFlash:Emit(2)
		orbShock:Emit(1)
	end)
	on("stroke", function(side)
		handBurst(side, 14)
	end)
	on("gulp", function()
		orbShock:Emit(2)
	end)
	on("warp", function()
		for _, e in feet do
			if e then
				e:Emit(16)
			end
		end
	end)

	local swallowed = 0
	local lastCycle = -1
	local dilated = false
	local hotStreams = false
	local ringTr = 0.35
	Core.on(c, function(_, dt, root)
		local ground = root * CF(0, -c.lift, 0)
		Core.put(gnd, ground)
		local holeCF = ground * CF(O)
		Core.put(vol, holeCF)
		Core.put(dust, holeCF)
		-- time dilation: everything slows to 8 %
		local dil = Sync.window(bus, "dilate", 0.46) >= 0
		if dil ~= dilated then
			dilated = dil
			for _, e in emitters do
				e.TimeScale = if dil then 0.08 else 1
			end
		end
		local speed = if dil then 0.08 else 1
		lt += dt * speed
		local reachW = Sync.window(bus, "reach", 1.4)
		local reaching = reachW >= 0 and not dil
		discSpin += dt * speed * (if reaching then 2.2 else 0)
		-- the orb: implodes on "crush", overshoots on "flare", flashes on "gulp"
		local eCrush = Sync.env(bus, "crush", 2.2)
		local eFlare = Sync.env(bus, "flare", 3)
		local eGulp = Sync.env(bus, "gulp", 5)
		local eWarp = Sync.env(bus, "warp", 4)
		crushK = if Sync.since(bus, "crush") < Sync.since(bus, "flare") then math.min(1, eCrush * 1.6) else 0
		local k = 1 - 0.5 * crushK + 0.35 * eFlare + 0.12 * eGulp
		Core.put(orb, holeCF)
		orb.Size = V(3.4, 3.4, 3.4) * k
		local s = (3.7 + Core.pulse(lt, 0.9) * 0.18) * k
		photon.Size = V(s, s, s)
		Core.put(photon, holeCF)
		local flick = if dil and rng:NextNumber() < 0.5 then 1 else 0.35
		if flick ~= ringTr then
			ringTr = flick
			B.setBeamsTransparency(ring2.beams, flick)
			B.setBeamsTransparency(ring1.beams, if dil then flick * 0.6 else 0)
		end
		-- jets: widen on the flare / warp / gulp
		local jw = 1 + eFlare * 2.2 + eWarp * 1.2 + eGulp * 0.6
		for _, j in jets do
			j.b.Width0 = j.w0 * jw
			j.b.Width1 = j.w1 * jw
		end
		-- matter streams: white-hot while reaching
		if reaching ~= hotStreams then
			hotStreams = reaching
			for _, st in streams do
				st.beam.Transparency = if reaching then streamHot else streamTr
				st.beam.Width0 = if reaching then 1.1 else 0.6
				st.beam.TextureSpeed = if reaching then 8 else 3
			end
		end
		for _, e in hands do
			if e then
				e.Rate = if reaching then 30 else 0
			end
		end
		for _, st in streams do
			local a = st.a + lt * 0.4
			st.base.CFrame = CFrame.fromMatrix(
				V(math.cos(a) * 7, g + 0.1, math.sin(a) * 7),
				V(-math.sin(a), 0, math.cos(a)),
				Vector3.yAxis
			)
		end
		-- debris on the shared beat
		local ph = (lt / BEAT) % 1
		for _, d in debris do
			local f = (ph + d.off) % 1
			local r = 9 * (1 - f) ^ 1.5 + 1.8
			local a = d.a0 + f * f * 9 + lt * 0.3
			local y = (g + 0.5) + (O.Y - g - 0.5) * smooth01(f)
			Core.put(d.p, ground * CF(math.cos(a) * r, y, math.sin(a) * r) * ANG(lt * 3, lt * 2, 0))
			d.p.Transparency = if f > 0.92 then (f - 0.92) / 0.08 else 0
		end
		-- the big chunk: one fall per beat, swallowed on every second one -> "swallow"
		local cyc = math.floor(lt / BEAT + 0.35)
		local f = (lt / BEAT + 0.35) % 1
		local r = 10 * (1 - f) ^ 1.4 + 1.6
		local a = f * f * 7 + lt * 0.25
		local y = (g + 1) + (O.Y - g - 1) * smooth01(f)
		local big = cyc % 2 == 0
		Core.put(chunk, ground * CF(math.cos(a) * r, y, math.sin(a) * r) * ANG(lt * 2, lt * 1.3, 0))
		chunk.Transparency = if not big then 1 elseif f > 0.94 then (f - 0.94) / 0.06 else 0
		if cyc ~= lastCycle then
			if lastCycle >= 0 and lastCycle % 2 == 0 then
				swallowed += 1
				Sync.emit(bus, "swallow", swallowed)
			end
			lastCycle = cyc
		end
		-- sigil disc stays on the floor and darkens while crushed
		Core.put(sigDisc, ground * CF(0, g + 0.015, 0) * FLAT)
		sigDisc.Transparency = 0.9 + 0.08 * crushK - 0.25 * eFlare
		ol.Brightness = math.max(
			0.3,
			(3 + Core.pulse(lt, 0.9) * 1.6) * (1 - 0.8 * crushK) + eFlare * 9 + eGulp * 4 + (if reaching then 1.5 else 0)
		)
		ol.Color = if eFlare > 0.3 then WHITE else c.c1
	end)
end

-- pure black void silhouette with white outline and inverted pixels
-- parts ~100 (incl. 2 afterimage sets), emitters 9
-- Synced to the Blender animation (tools/blender/anim/auras/NullPointer.py, levitating set, lift
-- 1.5 studs). Idle markers (4.8 s loop):
--   "point" R/L -> the cursor glitch-jumps to the empty spot that hand points at (4 studs along
--                  the arm) + pixel burst from the fingertips
--   "deref"     -> segfault: the cursor slams into the head, the whole aura INVERTS (white body,
--                  black outline, pixel colours swap), SIGSEGV glyph flash, chest shock
--   "glitch"    -> the void silhouette tears sideways for a few frames, glyphs scramble
--   "null"      -> frozen null pose: the light cuts out and the pixels freeze
--   "thud"      -> the body hits the floor: floor shock ring, square burst, disc flash
--   "repoint"   -> re-referenced: inversion ends, cursor back above the head, pixel geyser
-- Walk: "skip" R/L (dropped frame) -> a black afterimage of the body stays behind and fades +
-- pixel puff from the pointing hand. While gliding the cursor wanders; when it lands on the head
-- the VFX emits "poke" (pose flinch reaction, which itself fires "deref"). Landing plays the
-- "crash" reaction ("thud" + "glitch"). Floor pieces stay on the real ground under the hover.
A.NullPointer = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
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
	-- the real ground under the levitating body (attachments that must stay on the floor ride it)
	local gnd = Core.part(c, V(0.2, 0.2, 0.2), BLACK, SMOOTH, 1)
	local void = Instance.new("Model")
	void.Name = "Void"
	void.Parent = c.folder
	-- "glitch": the silhouette tears sideways (the offset is refreshed by the updater below)
	local tear = Vector3.zero
	local sil = B.clones(c, {
		set = "full",
		color = BLACK,
		mat = SMOOTH,
		scale = 1.06,
		map = function(cf: CFrame): CFrame
			return if tear.Magnitude > 0 then cf + tear else cf
		end,
	})
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
	-- afterimages for the walk's dropped frames (two sets, alternating R / L)
	type Ghost = { parts: { BasePart }, t0: number, pending: boolean }
	local ghosts: { Ghost } = {}
	for k = 1, 2 do
		local parts: { BasePart } = {}
		for i, src in c.body do
			parts[i] = Core.cloneShape(c, src, BLACK, SMOOTH, 1, 1.04)
		end
		ghosts[k] = { parts = parts, t0 = -math.huge, pending = false }
	end
	-- inverted pixels: black ones live in the void model and get the white outline
	type Px = { p: BasePart, a: number, r: number, y: number, nextT: number, w: number, black: boolean }
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
			black = black,
		}
	end
	local words = { "NULL", "0x00000000", "nil", "void*", "&null", "SIGSEGV", "*ptr = ?" }
	type Gl = { att: Attachment, lbl: TextLabel, a: number, y: number, word: string }
	local glyphs: { Gl } = {}
	for i = 1, 6 do
		local att, lbl = B.glyph(c, words[i], WHITE, V2(2.2, 0.42), F.tech, nil, BLACK)
		glyphs[i] = { att = att, lbl = lbl, a = (i - 1) / 6 * TAU, y = c.groundY + 1 + i * 0.85, word = words[i] }
	end
	-- SIGSEGV flash over the head on every dereference
	local _, segv = B.glyph(c, "SEGMENTATION FAULT", WHITE, V2(5, 0.6), F.tech, CF(0, c.topY + 1.6, 0), BLACK)
	segv.TextTransparency = 1
	segv.TextStrokeTransparency = 1
	-- the pointer: a giant cursor arrow that keeps pointing at nothing
	local arrow = {
		Core.part(c, V(0.3, 2.4, 0.3), WHITE),
		Core.part(c, V(0.3, 1.3, 0.3), WHITE),
		Core.part(c, V(0.3, 1.3, 0.3), WHITE),
	}
	local g = c.groundY
	local disc = Core.part(c, V(0.04, 14, 14), BLACK, SMOOTH, 0, CYL)
	local sig = B.sigil(c, { radius = 7, color = WHITE, rings = 3, glow = nil, pulse = 1.6 })
	for _, cir in sig.circles do
		for _, a in cir.atts do
			a.Parent = gnd
		end
	end
	B.ring(c, {
		n = 20,
		gap = 2,
		radius = 6,
		seg = V(0.12, 0.06, 0),
		color = WHITE,
		spin = -0.4,
		anchor = function()
			return CF(0, g + 0.06 - c.lift, 0)
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
	-- floor emitters on an anchored volume that stays on the real ground
	local floorVol = Core.part(c, V(12, 0.1, 12), BLACK, SMOOTH, 1)
	local floorSq = Core.emit(floorVol, {
		tex = T.square,
		color = cs(WHITE),
		size = ns(0.3, 0),
		transp = ns(0, 1),
		rate = 24,
		life = nr(1.5, 2.5),
		speed = nr(2, 4),
		rot = nr(0, 0),
		shape = BOX,
	})
	local geyser = Core.emit(floorVol, {
		tex = T.square,
		color = cs(WHITE, BLACK),
		size = ns(0.45, 0.1),
		transp = ns(0, 0.2, 1),
		rate = 0,
		life = nr(0.6, 1.1),
		speed = nr(8, 14),
		accel = V(0, -6, 0),
		rot = nr(0, 0),
		shape = BOX,
		bright = 2,
	})
	local gAtt = Core.att(c, gnd, CF(0, g + 0.12, 0))
	local floorShock = Core.emit(gAtt, {
		tex = T.shock,
		color = cs(WHITE),
		size = ns(1, 18),
		transp = ns(0.05, 1),
		rate = 0,
		life = nr(0.7, 0.7),
		speed = nr(0.01, 0.01),
		orient = PERP,
		bright = 3,
	})
	local chestShock = Core.emit(Core.tip(c, "chest") or Core.att(c, c.torso), {
		tex = T.shock,
		color = cs(WHITE),
		size = ns(1, 11),
		transp = ns(0.1, 1),
		rate = 0,
		life = nr(0.45, 0.45),
		bright = 3,
	})
	-- fingertip pixel bursts (pointing, dropped frames)
	type Hand = { att: Attachment, pop: ParticleEmitter }
	local hands: { [string]: Hand } = {}
	local TIPS: { [string]: string } = { R = "rhand", L = "lhand" }
	for side, tip in TIPS do
		local att = Core.tip(c, tip)
		if att then
			hands[side] = {
				att = att,
				pop = Core.emit(att, {
					tex = T.square,
					color = cs(WHITE, BLACK),
					size = ns(0.32, 0),
					transp = ns(0, 1),
					rate = 0,
					life = nr(0.35, 0.7),
					speed = nr(4, 10),
					spread = V2(35, 35),
					dir = Enum.NormalId.Bottom, -- out of the fingertips
					drag = 3,
					rot = nr(0, 0),
				}),
			}
		end
	end
	local headTip = Core.tip(c, "head")
	local light = B.rootLight(c, WHITE, 2, 16)

	-- pointer state: "rand" wanders (walk / fallback), "aim" = scripted spot, "head" = rides the head
	local ptrAt, ptrFrom = V(0, c.topY + 0.6, 0), V(0, c.topY + 0.6, 0)
	local ptrT, nextPtr = 0, 0
	local ptrMode = "rand"
	local aimSide: string? = nil -- a "point" marker waiting for the updater to read the arm
	local invUntil = 0 -- inverted colours until this os.clock()
	local inverted = false
	local darkUntil = 0
	local function jump(to: Vector3, t: number)
		ptrFrom = ptrAt
		ptrAt = to
		ptrT = t
	end
	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	on("point", function(side: any)
		local sd = if side == "L" then "L" else "R"
		aimSide = sd
		local h = hands[sd]
		if h then
			h.pop:Emit(22)
		end
	end)
	on("deref", function()
		ptrMode = "head"
		ptrT = os.clock()
		ptrFrom = ptrAt
		local walking = Sync.get(bus, "move") > 0.5
		invUntil = os.clock() + (if walking then 0.45 else 1.6)
		chestShock:Emit(2)
		for _, h in hands do
			h.pop:Emit(10)
		end
	end)
	on("null", function()
		darkUntil = os.clock() + 0.25
	end)
	on("thud", function()
		floorShock:Emit(1)
		floorSq:Emit(45)
	end)
	on("repoint", function()
		invUntil = 0
		ptrMode = "aim"
		jump(V(0, c.topY + 0.6, 0), os.clock())
		geyser:Emit(60)
		chestShock:Emit(1)
	end)
	on("skip", function(side: any)
		local gh = ghosts[if side == "L" then 2 else 1]
		gh.pending = true
		local h = hands.R
		if h then
			h.pop:Emit(8)
		end
	end)

	Core.on(c, function(t, _, root)
		local ground = root * CF(0, -c.lift, 0)
		Core.put(gnd, ground)
		Core.put(floorVol, ground * CF(0, g + 0.1, 0))
		local eThud = Sync.env(bus, "thud", 4)
		local eRep = Sync.env(bus, "repoint", 5)
		local glW = Sync.window(bus, "glitch", 0.1)
		local derefW = Sync.window(bus, "deref", 0.12)
		-- inversion
		local inv = os.clock() < invUntil
		if inv ~= inverted then
			inverted = inv
			hl.FillColor = if inv then WHITE else BLACK
			hl.OutlineColor = if inv then BLACK else WHITE
			disc.Color = if inv then WHITE else BLACK
			disc.Material = if inv then NEON else SMOOTH
			for _, q in pix do
				local b = q.black ~= inv
				q.p.Color = if b then BLACK else WHITE
				q.p.Material = if b then SMOOTH else NEON
			end
		end
		-- the silhouette tears on "glitch" / the first frames of a dereference
		if glW >= 0 or derefW >= 0 then
			tear = V(rng:NextNumber() - 0.5, (rng:NextNumber() - 0.5) * 0.3, rng:NextNumber() - 0.5) * 0.9
		else
			tear = Vector3.zero
		end
		Core.put(disc, ground * CF(0, g + 0.02, 0) * FLAT)
		local frozen = Sync.since(bus, "null") < 0.2
		for _, q in pix do
			if t >= q.nextT and not frozen then
				q.nextT = t + 0.15 + rng:NextNumber() * 0.5
				q.p.Transparency = if rng:NextNumber() < 0.15 then 1 else 0
			end
			local a = q.a + t * q.w
			Core.put(
				q.p,
				root * CF(math.cos(a) * q.r, q.y + math.sin(t + q.a) * 0.3, math.sin(a) * q.r) * ANG(0, -a, 0)
			)
		end
		local scramble = glW >= 0 or derefW >= 0
		for i, gl in glyphs do
			local a = gl.a - t * 0.3
			gl.att.Position = V(math.cos(a) * 4.2, gl.y + math.sin(t * 0.8 + i) * 0.25, math.sin(a) * 4.2)
			local flip = (math.noise(i, t * 1.5) > 0.3) ~= inv
			gl.lbl.TextColor3 = if flip then BLACK else WHITE
			gl.lbl.TextStrokeColor3 = if flip then WHITE else BLACK
			gl.lbl.Text = if scramble then Core.hex(8, rng) else gl.word
		end
		local eSeg = Sync.env(bus, "deref", 2.2)
		segv.TextTransparency = if eSeg > 0.05 and rng:NextNumber() > 0.15 then 1 - eSeg else 1
		segv.TextStrokeTransparency = segv.TextTransparency
		-- afterimages
		for _, gh in ghosts do
			if gh.pending then
				gh.pending = false
				gh.t0 = t
				for i, p in gh.parts do
					local src = c.body[i]
					if src then
						Core.put(p, src.CFrame)
					end
				end
			end
			local age = t - gh.t0
			local tr = if age < 0.45 then 0.3 + 0.7 * (age / 0.45) else 1
			if gh.parts[1] and gh.parts[1].Transparency ~= tr then
				for _, p in gh.parts do
					p.Transparency = tr
				end
			end
		end
		-- the pointer
		local move = Sync.get(bus, "move")
		local scripted = Sync.count(bus, "point") > 0 and move < 0.5
		if aimSide then
			local h = hands[aimSide]
			aimSide = nil
			if h then
				local arm = h.att.Parent :: BasePart
				local dir = -arm.CFrame.UpVector
				local spot = root:PointToObjectSpace(h.att.WorldPosition + dir * 4)
				ptrMode = "aim"
				jump(spot + V(0, -0.3, 0), t)
			end
		end
		if ptrMode == "head" and headTip then
			local hp = root:PointToObjectSpace(headTip.WorldPosition) + V(0, -0.2, 0)
			ptrAt = hp
			if t - ptrT > 1.4 or (move > 0.5 and t - ptrT > 0.5) then
				ptrMode = if scripted then "aim" else "rand"
				jump(V(0, c.topY + 0.6, 0), t)
			end
		elseif not scripted and t >= nextPtr then
			-- gliding (or no Blender clip yet): the cursor wanders, and pokes the head now and then
			ptrMode = "rand"
			nextPtr = t + 0.8 + rng:NextNumber() * 1.2
			local r0 = rng:NextNumber()
			if r0 < 0.22 and move > 0.6 and Sync.since(bus, "poke") > 3 then
				jump(V(0, c.topY + 0.1, 0), t)
				Sync.emit(bus, "poke")
			elseif r0 < 0.4 then
				jump(V(0, c.topY + 0.6, 0), t)
			else
				local a = rng:NextNumber() * TAU
				local r = 2.5 + rng:NextNumber() * 3
				jump(V(math.cos(a) * r, g + 0.5 + rng:NextNumber() * 3, math.sin(a) * r), t)
			end
		end
		local f = smooth01((t - ptrT) / 0.12)
		local bob = if ptrMode == "head" then 0 else 0.3 + Core.pulse(t, 0.8) * 0.4
		local tip = ptrFrom:Lerp(ptrAt, f) + V(0, bob, 0)
		local up = CF(tip) * ANG(0, t * 0.8, 0) -- tip at origin, arrow points down
		Core.put(arrow[1], root * up * CF(0, 1.4, 0))
		Core.put(arrow[2], root * up * ANG(0, 0, 0.6) * CF(0, 0.6, 0))
		Core.put(arrow[3], root * up * ANG(0, 0, -0.6) * CF(0, 0.6, 0))
		local off = rng:NextNumber() < 0.03 or (f < 1 and rng:NextNumber() < 0.5)
		local arrowCol = if inv then BLACK else WHITE
		for _, p in arrow do
			p.Transparency = if off then 1 else 0
			p.Color = arrowCol
		end
		local dark = os.clock() < darkUntil or (Sync.since(bus, "null") < 0.2)
		light.Brightness = if dark or off
			then 0.1
			else 1.8 + Core.pulse(t, 1.6) * 0.8 + eThud * 3 + eRep * 4 + eSeg * 2
	end)
end

---------------------------------------------------------------- SINGULARITY

-- white core star, galaxy spiral, gravitational rings, light beams
-- parts ~88, emitters 14
--
-- Synced to the Blender animation (tools/blender/anim/auras/Singularity.py, idle 6 s):
--   "gather" (right hand sweeps up)  -> both hands start streaming sparks up to the star
--   "reach"  (hands up at the star)  -> light threads hand -> star flash on
--   "pull"   (hands drag the mass down) -> galaxy, rings and star shells contract, spin speeds up
--   "collapse" (curled into a ball) -> implosion at the star, light dims, the core trembles
--   "crack"  (head snaps up)         -> star flickers white, spikes flare
--   "burst"  (body explodes open)    -> star burst, chest + ground shock, hand bursts, rings
--                                       overshoot outward (spring), light flare, floor ripple
--   "echo"   (aftershock arm flick)  -> smaller ripple + ring flash
-- Walk (comet glide): "kick" L/R -> spark puff from that foot + floor ripple under it, the
-- hands leave comet-tail sparks while moving. Every ~5 s of gliding the VFX emits "flare"
-- (spikes flash, star throws sparks) which plays the pose's flare reaction: "catch" -> a
-- light thread star -> right hand + hand burst, "fling" -> the hand throws the sparks back.
-- Runner events: "launch" (jump reaction) and "impact" (land reaction) -> ground shock + ripple.
A.Singularity = function(c: Ctx)
	local bus = c.bus
	local yS = c.topY + 4
	local SP = V(0, yS, 0)
	local star = Core.part(c, V(2.2, 2.2, 2.2), WHITE, NEON, 0, BALL)
	local shellA = Core.part(c, V(3.2, 3.2, 3.2), c.c2, FF, 0, BALL)
	local shellB = Core.part(c, V(4.4, 4.4, 4.4), WHITE, NEON, 0.86, BALL)
	local spikes: { BasePart } = {}
	for i = 1, 4 do
		spikes[i] = Core.part(c, V(if i <= 2 then 16 else 9, 0.14, 0.04), WHITE, NEON, 0.1)
	end
	local PULL_DUR = 1.0 -- "pull" -> "collapse" in the clip (frames 78 -> 108)
	local HOLD_MAX = 1.9 -- a burst always follows the pull within 1.67 s; later = clip left idle
	local function noClip(): boolean
		return Sync.count(bus, "gather") + Sync.count(bus, "kick") + Sync.count(bus, "burst") == 0
			and Sync.age(bus) > 1.2
	end
	-- Size multiplier of everything gravitational: 1 = open, 0.15 = collapsed point,
	-- > 1 = the spring overshoot after the burst. Driven by the pose markers.
	local function collapse(t: number): number
		local sP, sB = Sync.since(bus, "pull"), Sync.since(bus, "burst")
		if sP == math.huge and sB == math.huge then
			if not noClip() then
				return 1 -- the clip runs, its first pull has not come yet (or only walking)
			end
			-- no Blender clip plays on this rig: the old free-running 7 s cycle
			local ph = t % 7
			if ph > 6.3 then
				return 1 - smooth01((ph - 6.3) / 0.7) * 0.85
			end
			return 1
		end
		if sP < sB then
			if sP < PULL_DUR then
				return 1 - smooth01(sP / PULL_DUR) * 0.85
			elseif sP < HOLD_MAX then
				return 0.15
			end
			return 0.15 + 0.85 * smooth01((sP - HOLD_MAX) / 0.6) -- walked away mid-collapse
		end
		return 1 + 0.45 * math.exp(-3.2 * sB) * math.cos(7 * sB)
	end
	local function trembling(): boolean
		local sP, sB = Sync.since(bus, "pull"), Sync.since(bus, "burst")
		return sP < sB and sP > PULL_DUR - 0.05 and sP < HOLD_MAX
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
	-- gravitational rings (their width flashes on the burst / echo)
	local rings: { B.Circle } = {}
	for k = 1, 3 do
		local r0 = 3.8 + k * 2.2
		rings[k] = B.circle(c, {
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
	B.sigil(
		c,
		{ radius = 13, color = WHITE, color2 = c.c2, rings = 4, spokes = 12, glow = 0.9, spin = 0.12, pulse = 3.5 }
	)
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
	-- floor ripple: expands from under the body (or the kicking foot) on every impact-like event
	local rippleAt = V(0, 0, 0)
	local rippleT, rippleBig = -math.huge, 1
	local function ripple(big: number, at: Vector3?)
		rippleT, rippleBig, rippleAt = os.clock(), big, at or Vector3.zero
	end
	local rip = B.circle(c, {
		radius = 1,
		color = WHITE,
		color2 = c.c2,
		width = 0.3,
		n = 10,
		anchor = function()
			return CF(rippleAt.X, c.groundY + 0.08, rippleAt.Z)
		end,
		radiusFn = function()
			local u = math.clamp((os.clock() - rippleT) / 0.75, 0, 1)
			return 0.8 + (1 - (1 - u) ^ 3) * 9 * rippleBig
		end,
	})
	-- god beams into the sky + the main light pillar
	local starAtt = Core.att(c, nil, CF(SP))
	local tops: { Attachment } = {}
	local godBeams: { Beam } = {}
	for k = 1, 6 do
		tops[k] = Core.att(c)
		godBeams[k] = Core.beam(c, starAtt, tops[k], WHITE, 1.2, { w1 = 7, color2 = c.c2, tr = ns(0.25, 1), segs = 2 })
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
	-- the collapse: an implosion sucked into the star
	local implode = Core.emit(starAtt, {
		tex = T.implode,
		color = cs(WHITE, c.c2),
		size = ns(12, 0.5),
		transp = ns(0.2, 1),
		rate = 0,
		life = nr(0.9, 0.9),
		locked = true,
	})
	-- sparks sucked in from a 7-stud shell around the star (shape needs a part, not an attachment)
	local inward = Core.emit(Core.volume(c, V(14, 14, 14), CF(SP)), {
		tex = T.spark,
		color = cs(c.c2, WHITE),
		size = ns(0.5, 0),
		rate = 0,
		life = nr(0.45, 0.55),
		speed = nr(13, 15),
		shape = SPHERE,
		shapeStyle = SURFACE,
		inout = INWARD,
		bright = 2,
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
	-- chest shockwave (burst) rides the animated torso
	local chestAtt = Core.tip(c, "chest") or Core.att(c, c.torso)
	local chestShock = Core.emit(chestAtt, {
		tex = T.shock,
		color = cs(WHITE, c.c2),
		size = ns(1, 14),
		transp = ns(0.1, 1),
		rate = 0,
		life = nr(0.6, 0.6),
		bright = 3,
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
	local groundShock = Core.emit(Core.att(c, c.root, CF(0, c.groundY + 0.12, 0)), {
		tex = T.shock,
		color = cs(WHITE, c.c2),
		size = ns(1, 26),
		transp = ns(0.05, 1),
		rate = 0,
		life = nr(0.9, 0.9),
		speed = nr(0.01, 0.01),
		orient = PERP,
		bright = 3,
	})
	local floorSparks = B.floorEmit(c, 9, {
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
	-- hands: gather streams (up to the star), bursts, comet-tail sparks, light threads
	type Hand = { att: Attachment, stream: ParticleEmitter, pop: ParticleEmitter, tail: ParticleEmitter, thread: Beam }
	local hands: { [string]: Hand } = {}
	for _, side in { "rhand", "lhand" } do
		local att = Core.tip(c, side)
		if not att then
			continue
		end
		hands[side] = {
			att = att,
			stream = Core.emit(att, {
				tex = T.spark,
				color = cs(WHITE, c.c2),
				size = ns(0.45, 0),
				rate = 0,
				life = nr(0.5, 0.8),
				speed = nr(5, 9),
				spread = V2(12, 12),
				accel = V(0, 14, 0),
				dir = Enum.NormalId.Bottom, -- out of the fingertips
				bright = 2.5,
			}),
			pop = Core.emit(att, {
				tex = T.spark,
				color = cs(WHITE, c.c2),
				size = ns(0.7, 0),
				rate = 0,
				life = nr(0.4, 0.8),
				speed = nr(8, 16),
				spread = V2(180, 180),
				drag = 3,
				bright = 3,
			}),
			tail = Core.emit(att, {
				tex = T.glow,
				color = cs(WHITE, c.c2),
				size = ns(0.6, 0),
				transp = ns(0.2, 1),
				rate = 0,
				life = nr(0.5, 0.9),
				speed = nr(0, 0.4),
			}),
			thread = Core.beam(c, att, starAtt, WHITE, 0.25, { w1 = 0.05, color2 = c.c2, tr = ns(0.1, 0.4), segs = 6 }),
		}
	end
	for _, h in hands do
		h.thread.Enabled = false
	end
	local footPuff: { [string]: ParticleEmitter } = {}
	local FEET: { [string]: string } = { R = "rfoot", L = "lfoot" }
	for side, tip in FEET do
		local att = Core.tip(c, tip)
		if att then
			footPuff[side] = Core.emit(att, {
				tex = T.spark,
				color = cs(WHITE, c.c2),
				size = ns(0.5, 0),
				rate = 0,
				life = nr(0.4, 0.7),
				speed = nr(4, 8),
				spread = V2(50, 50),
				dir = Enum.NormalId.Bottom,
				drag = 2,
				bright = 2.5,
			})
		end
	end
	local sl = Core.light(starAtt, WHITE, 5, 26)
	B.rootLight(c, c.c2, 3, 20, { pulse = 1.3, amp = 1.2 })

	-- one-off reactions to the pose markers
	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	local function handPop(n: number, which: string?)
		for side, h in hands do
			if not which or side == which then
				h.pop:Emit(n)
			end
		end
	end
	on("collapse", function()
		implode:Emit(2)
		inward:Emit(60)
	end)
	on("crack", function()
		inward:Emit(30)
	end)
	on("burst", function()
		burst:Emit(90)
		chestShock:Emit(2)
		groundShock:Emit(1)
		floorSparks:Emit(40)
		handPop(30)
		ripple(1.2)
	end)
	on("echo", function()
		groundShock:Emit(1)
		burst:Emit(20)
		ripple(0.7)
	end)
	on("kick", function(side: any)
		local s = if side == "L" then -1 else 1
		local puff = footPuff[if side == "L" then "L" else "R"]
		if puff then
			puff:Emit(14)
		end
		ripple(0.45, V(0.5 * s, 0, 1.6))
	end)
	on("launch", function()
		groundShock:Emit(1)
		burst:Emit(25)
		ripple(0.8)
	end)
	on("impact", function()
		groundShock:Emit(1)
		floorSparks:Emit(30)
		ripple(1)
	end)
	on("flare", function()
		burst:Emit(18)
	end)
	on("catch", function()
		handPop(28, "rhand")
	end)
	on("fling", function()
		local h = hands.rhand
		if h then
			h.pop:Emit(40)
			h.tail:Emit(20)
		end
	end)

	local spin = 0
	local flareT = 0
	local fallbackPh = 0
	local rng = c.rng
	Core.on(c, function(t, dt, root)
		local col = collapse(t)
		local trem = trembling()
		-- fallback burst for the free-running cycle (no Blender clip has played yet)
		if noClip() then
			local ph = t % 7
			if ph < fallbackPh then
				burst:Emit(80)
			end
			fallbackPh = ph
		end
		-- gliding: every ~5 s the star throws off a flare that the body catches
		local move = Sync.get(bus, "move")
		if move > 0.6 and Sync.get(bus, "air") < 0.5 then
			flareT += dt
			if flareT > 5 then
				flareT = 0
				Sync.emit(bus, "flare")
			end
		else
			flareT = math.max(0, flareT - dt)
		end
		local eBurst = Sync.env(bus, "burst", 2.5)
		local eEcho = Sync.env(bus, "echo", 4)
		local eCrack = Sync.env(bus, "crack", 9)
		local eFlare = Sync.env(bus, "flare", 3)

		local scf = root * CF(SP)
		if trem then
			scf *= CF(jitter(rng, 0.35))
		end
		Core.put(star, scf)
		local sa = (3.2 + Core.pulse(t, 1.3) * 0.5) * math.max(col, 0.35)
		shellA.Size = V(sa, sa, sa)
		Core.put(shellA, scf)
		local sb = 4.4 * (0.9 + Core.pulse(t, 2.1) * 0.25) * col
		shellB.Size = V(sb, sb, sb)
		shellB.Transparency = 0.86 - math.max(eCrack, eBurst) * 0.5
		Core.put(shellB, scf)
		local look = CFrame.lookAt(scf.Position, camPos())
		local spikeK = 1 + eCrack * 0.6 + eBurst * 1.2 + eFlare * 0.8
		for i, s in spikes do
			local len = (if i <= 2 then 16 else 9) * spikeK * math.max(col, 0.3)
			s.Size = V(len, 0.14 * (1 + eBurst), 0.04)
			Core.put(s, look * ANG(0, 0, (i - 1) * math.pi / 4 + t * 0.2 * (if i % 2 == 0 then 1 else -1)))
		end
		-- the galaxy spins up while it is pulled in
		spin += dt * (0.5 + 3.5 * math.clamp(1 - col, 0, 1))
		local gl = CF(0, -0.2, 0) * ANG(0, spin, 0)
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
		-- rings flash on the burst / echo
		local rw = 0.16 * (1 + eBurst * 2.5 + eEcho * 1.2)
		for _, ring in rings do
			for _, b in ring.beams do
				b.Width0 = rw
				b.Width1 = rw
			end
		end
		local ru = math.clamp((os.clock() - rippleT) / 0.75, 0, 1)
		B.setBeamsTransparency(rip.beams, if ru >= 1 then 1 else 0.05 + ru * 0.95)
		-- god beams widen on the burst
		local gw = 7 * (1 + eBurst * 0.8)
		for _, b in godBeams do
			b.Width1 = gw
		end
		for k, a in tops do
			local ang = (k - 1) / 6 * TAU + t * 0.15
			a.Position = SP + V(math.cos(ang) * 12, 90, math.sin(ang) * 12)
		end
		-- hands: streams while gathering, threads while reaching / pulling / catching
		local sG, sR, sPl = Sync.since(bus, "gather"), Sync.since(bus, "reach"), Sync.since(bus, "pull")
		local gathering = sG < sPl and sG < 1.4
		local threads = (sR < sPl and sR < 1.2) or sPl < PULL_DUR
		local catchW = Sync.window(bus, "catch", 0.5)
		for side, h in hands do
			h.stream.Rate = if gathering then 45 else 0
			h.tail.Rate = 28 * math.clamp((move - 0.3) / 0.7, 0, 1)
			local on1 = threads or (side == "rhand" and catchW >= 0)
			h.thread.Enabled = on1
			if on1 then
				local w = if sPl < PULL_DUR then 0.25 + (1 - sPl / PULL_DUR) * 0.35 else 0.25
				h.thread.Width0 = w
			end
		end
		-- star light: dims while collapsed, flares on crack / burst
		local base = 4.5 + Core.pulse(t, 1.3)
		sl.Brightness = base * math.clamp(col, 0.3, 1.2) + eCrack * 6 + eBurst * 14 + eFlare * 4
		sl.Range = 26 + eBurst * 14
	end)
end

-- giant wireframe grid sphere, floating code pages, green god-rays
-- parts ~60, emitters 10
-- Synced to the Blender animation (tools/blender/anim/auras/Architect.py, levitating set, lift
-- 2.2 studs; the floor grid / sigil / ring / pillar / voxels stay on the real ground under it).
-- Idle markers (6 s loop):
--   "key" R/L x6 -> typing in the air: a voxel is written in front of the body at that hand,
--                   hand sparks, the cursor flashes solid
--   "enter"      -> every typed voxel bursts, the code pages flash, the title refreshes
--   "compile"    -> arm to the sky: god-rays widen + brighten, the sky pillar flares, code rain
--                   triples, the wireframe sphere glows
--   "build"      -> the world is thrown onto the floor: floor shock ring, a wave of voxels erupts
--                   across the grid (inner -> outer), the grid lines flash, floor squares burst
--   "sweep"      -> the pages fly outward (radius kick) and spin faster
--   "error"      -> the sphere and its nodes flicker out, the title turns red "ERROR 404"
--   "fix"        -> finger tap: the sphere snaps back with a flash, title restored, voxel at the
--                   fingertip + hand sparks
-- Walk: "tile" R/L -> a glowing code tile is written under that foot (fades), foot sparks.
-- Every 6-9 s of gliding the VFX emits "pagefault" (a page glitches) -> the pose's pagefault
-- reaction taps it ("fix"). Reactions: "ascend" (jump) -> pillar flare + rain burst + floor
-- shock; "impact" (land) -> floor shock + grid flash + floor squares.
A.Architect = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
	local R = 8.5
	local S = V(0, c.groundY + R * 0.55, 0)
	-- the real ground under the levitating body: floor pieces ride this anchored part
	local gnd = Core.part(c, V(0.2, 0.2, 0.2), c.c1, SMOOTH, 1)
	local function meridian(k: number): (t: number) -> CFrame
		return function(t: number): CFrame
			return CF(S) * ANG(0, t * 0.15 + k * math.pi / 6, 0) * ANG(0, 0, math.pi / 2)
		end
	end
	type Ring = { beams: { Beam }, tr: number }
	local sphere: { Ring } = {}
	for k = 0, 5 do
		local cir = B.circle(c, { radius = R, color = c.c1, width = 0.1, tr = 0.3, n = 10, anchor = meridian(k) })
		table.insert(sphere, { beams = cir.beams, tr = 0.3 })
	end
	local par = { -3.6, -1.8, 0, 2.4, 4.8, 6.9 }
	for _, y in par do
		local cir = B.circle(c, {
			radius = math.sqrt(R * R - y * y),
			color = c.c1,
			width = 0.09,
			tr = 0.35,
			n = 10,
			at = CF(S + V(0, y, 0)),
		})
		table.insert(sphere, { beams = cir.beams, tr = 0.35 })
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
	local rays: { Beam } = {}
	local hit = Core.att(c, nil, CF(0, c.chestY, 0))
	for k = 1, 7 do
		skyAtts[k] = Core.att(c)
		rays[k] = Core.beam(c, skyAtts[k], hit, c.c1, 6, { w1 = 1.2, color2 = WHITE, tr = ns(0.9, 0.55), segs = 2 })
	end
	local pillar = B.pillar(c, { color = c.c1, color2 = WHITE, height = 110, width = 3.6, tr = 0.45, streams = 3, radius = 1.8 })
	local pillarW: { number } = {}
	for i, b in pillar do
		pillarW[i] = b.Width0
		for _, a in { b.Attachment0, b.Attachment1 } do
			if a and a.Parent == c.root then
				a.Parent = gnd
			end
		end
	end
	-- floor grid
	local g = c.groundY + 0.04
	local GR = 10
	local grid: { Beam } = {}
	for k = -4, 4 do
		local x = k * 2.4
		local half = math.sqrt(math.max(0, GR * GR - x * x))
		local a0 = Core.att(c, gnd, CF(x, g, -half))
		local a1 = Core.att(c, gnd, CF(x, g, half))
		table.insert(grid, Core.beam(c, a0, a1, c.c1, 0.07, { tr = ns(0.85, 0.3, 0.85), segs = 2 }))
		local b0 = Core.att(c, gnd, CF(-half, g, x))
		local b1 = Core.att(c, gnd, CF(half, g, x))
		table.insert(grid, Core.beam(c, b0, b1, c.c1, 0.07, { tr = ns(0.85, 0.3, 0.85), segs = 2 }))
	end
	B.ring(c, {
		n = 32,
		gap = 4,
		radius = GR,
		seg = V(0.18, 0.07, 0),
		color = c.c1,
		spin = 0.1,
		anchor = function()
			return CF(0, g + 0.01 - c.lift, 0)
		end,
	})
	local sig = B.sigil(c, { radius = GR + 1.2, color = c.c1, color2 = WHITE, rings = 2, glow = 0.92, pulse = 2 })
	for _, cir in sig.circles do
		for _, a in cir.atts do
			a.Parent = gnd
		end
	end
	-- voxels materialising on the floor: the world being written
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
	-- voxels typed in the air (root space), and code tiles written under the walking feet (world)
	type Typed = { p: BasePart, pos: Vector3, t0: number, s: number }
	local typed: { Typed } = {}
	for i = 1, 8 do
		typed[i] = { p = Core.part(c, V(0.5, 0.5, 0.5), if i % 2 == 0 then WHITE else c.c1, NEON, 1), pos = Vector3.zero, t0 = -math.huge, s = 0.5 }
	end
	local typedN = 0
	type Tile = { p: BasePart, cf: CFrame, t0: number }
	local tiles: { Tile } = {}
	for i = 1, 4 do
		tiles[i] = { p = Core.part(c, V(1.7, 0.08, 1.7), c.c1, NEON, 1), cf = CFrame.identity, t0 = -math.huge }
	end
	local tileN = 0
	local cursor = Core.part(c, V(0.3, 0.55, 0.06), WHITE)
	local TITLE = "404 // PAGE NOT FOUND"
	local _, title = B.glyph(c, TITLE, c.c1, V2(5.4, 0.6), F.tech, CF(0, c.topY + 2.3, 0), Color3.fromRGB(0, 40, 20))
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
	local floorVol = Core.part(c, V(18, 0.1, 18), c.c1, SMOOTH, 1)
	local floorSq = Core.emit(floorVol, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.3, 0),
		transp = ns(0.1, 1),
		rate = 30,
		life = nr(1.6, 2.6),
		speed = nr(1.5, 3),
		rot = nr(0, 0),
		shape = BOX,
	})
	Core.emit(Core.att(c, gnd, CF(0, c.groundY + 0.1, 0)), {
		tex = T.shock,
		color = cs(c.c1),
		size = ns(3, 22),
		transp = ns(0.45, 1),
		rate = 0.45,
		life = nr(2, 2),
		speed = nr(0.01, 0.01),
		orient = PERP,
	})
	local floorShock = Core.emit(Core.att(c, gnd, CF(0, c.groundY + 0.14, 0)), {
		tex = T.shock,
		color = cs(WHITE, c.c1),
		size = ns(1, 28),
		transp = ns(0.05, 1),
		rate = 0,
		life = nr(1, 1),
		speed = nr(0.01, 0.01),
		orient = PERP,
		bright = 3,
	})
	local rain = Core.volume(c, V(18, 1, 18), CF(0, c.topY + 12, 0))
	local rainE = Core.emit(rain, {
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
	-- hand / foot sparks (ride the animated limbs)
	local pops: { [string]: ParticleEmitter } = {}
	local TIPS: { [string]: string } = { R = "rhand", L = "lhand", FR = "rfoot", FL = "lfoot" }
	for key, tip in TIPS do
		local att = Core.tip(c, tip)
		if att then
			pops[key] = Core.emit(att, {
				tex = T.spark,
				color = cs(WHITE, c.c1),
				size = ns(0.5, 0),
				rate = 0,
				life = nr(0.3, 0.6),
				speed = nr(4, 9),
				spread = V2(60, 60),
				dir = Enum.NormalId.Bottom,
				drag = 3,
				bright = 2.5,
			})
		end
	end
	local rhandTip = Core.tip(c, "rhand")
	local light = B.rootLight(c, c.c1, 3.2, 24)

	-- marker reactions (handlers only set state / emit; positions are placed in the updater)
	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	local function pop(key: string, n: number)
		local e = pops[key]
		if e then
			e:Emit(n)
		end
	end
	local pendingTyped: { string } = {}
	local pendingTile: { string } = {}
	local fixAtTip = false
	local waveT = -math.huge
	local broken = false -- "error" until "fix"
	local faultPage = 0 -- page glitched by a pagefault (0 = none)
	on("key", function(side: any)
		local s = if side == "L" then "L" else "R"
		table.insert(pendingTyped, s)
		pop(s, 8)
	end)
	on("enter", function()
		pop("R", 18)
		floorSq:Emit(20)
	end)
	on("build", function()
		waveT = os.clock()
		floorShock:Emit(1)
		floorSq:Emit(60)
		pop("R", 20)
	end)
	on("error", function()
		broken = true
	end)
	on("fix", function()
		broken = false
		faultPage = 0
		fixAtTip = true
		pop("R", 24)
	end)
	on("tile", function(side: any)
		local s = if side == "L" then "L" else "R"
		table.insert(pendingTile, s)
		pop(if s == "L" then "FL" else "FR", 10)
	end)
	on("ascend", function()
		floorShock:Emit(1)
		rainE:Emit(60)
	end)
	on("impact", function()
		floorShock:Emit(1)
		floorSq:Emit(40)
	end)

	local faultT = 0
	local lastBroken = false
	local sphereK = 0
	Core.on(c, function(t, dt, root)
		local ground = root * CF(0, -c.lift, 0)
		Core.put(gnd, ground)
		Core.put(floorVol, ground * CF(0, c.groundY + 0.1, 0))
		if sig.disc then
			Core.put(sig.disc, ground * CF(0, c.groundY + 0.015, 0) * ANG(0, 0, math.pi / 2))
		end
		local eKey = Sync.env(bus, "key", 9)
		local eEnter = Sync.env(bus, "enter", 4)
		local eComp = Sync.env(bus, "compile", 1.4)
		local eBuild = Sync.env(bus, "build", 2.5)
		local eSweep = Sync.env(bus, "sweep", 1.6)
		local eFix = Sync.env(bus, "fix", 5)
		local eAsc = Sync.env(bus, "ascend", 2.5)
		local eImp = Sync.env(bus, "impact", 3)
		-- gliding: pages fault now and then, the body's pagefault reaction patches them
		if Sync.get(bus, "move") > 0.6 and Sync.get(bus, "air") < 0.5 then
			faultT -= dt
			if faultT <= 0 then
				faultT = 6 + rng:NextNumber() * 3
				faultPage = rng:NextInteger(1, #pages)
				Sync.emit(bus, "pagefault")
			end
		elseif faultT < 2 then
			faultT = 2
		end
		-- the wireframe sphere: glows on compile / fix, flickers out while broken
		local flick = broken and rng:NextNumber() < 0.6
		local glow = math.max(eComp * 0.6, eFix * 0.8, eEnter * 0.3)
		local sk = if flick then -1 else math.floor(glow * 40 + 0.5) / 40
		if sk ~= sphereK then -- only touch the 120 beams when the look changes
			sphereK = sk
			for _, ring in sphere do
				B.setBeamsTransparency(ring.beams, if flick then 1 else ring.tr * (1 - sk))
			end
		end
		local rot = t * 0.15
		for i, n in nodes do
			local k = (i - 1) % 12
			local y = nodeY[if i <= 12 then 1 else 2]
			local rr = math.sqrt(R * R - y * y)
			local a = rot + k * math.pi / 6
			Core.put(n, root * CF(S + V(math.cos(a) * rr, y, -math.sin(a) * rr)) * ANG(t, t * 0.7, 0))
			n.Transparency = if broken and rng:NextNumber() < 0.5 then 1 else 0
		end
		-- pages: radius kick + spin on the sweep, flash on enter, a faulted page glitches
		local kick = eSweep * 2.6
		local pageTr = 0.5 - eEnter * 0.4 - eFix * 0.2
		for i, pg in pages do
			local a = pg.a + t * 0.18 + eSweep * 0.9
			local jit = if i == faultPage then CF(jitter(rng, 0.25)) else CFrame.identity
			local cf = root
				* outward(a, pg.r + kick, pg.y + math.sin(t * 0.8 + i) * 0.35)
				* ANG(0, math.sin(t * 0.5 + i) * 0.5, math.sin(t * 0.6 + i) * 0.08)
				* jit
			Core.put(pg.p, cf)
			Core.put(pg.bar, cf * CF(0, 1.1, 0))
			pg.p.Transparency = if i == faultPage and rng:NextNumber() < 0.4 then 1 else pageTr
		end
		-- god-rays + pillar flare on compile / ascend
		local rayK = math.max(eComp, eAsc * 0.7)
		for k, a in skyAtts do
			local ang = (k - 1) / 7 * TAU + t * 0.08
			a.Position = V(math.cos(ang) * 12 * (1 - rayK * 0.4), 70, math.sin(ang) * 12 * (1 - rayK * 0.4))
			rays[k].Width0 = 6 * (1 + rayK * 0.8)
			rays[k].Brightness = 2 + rayK * 4
		end
		for i, b in pillar do
			local w = pillarW[i] * (1 + rayK * 0.9)
			b.Width0 = w
			b.Width1 = w
		end
		rainE.Rate = 40 + eComp * 80
		-- floor grid flashes on build / impact
		local gk = math.max(eBuild, eImp * 0.7)
		local gw = 0.07 * (1 + gk * 3)
		for _, b in grid do
			b.Width0 = gw
			b.Width1 = gw
		end
		-- floor voxels (+ the build wave: every voxel respawns on an expanding ring)
		local waveAge = os.clock() - waveT
		for i, v in voxels do
			local age = t - v.t0
			if waveAge >= 0 and waveAge < 0.05 then
				-- schedule: voxel i erupts when the wave front reaches its radius
				v.t0 = t + (i - 1) / #voxels * 0.5
				v.life = 1.4
				v.s = 0.7 + rng:NextNumber() * 0.9
				local a = rng:NextNumber() * TAU
				local r = 2.5 + (i - 1) / #voxels * 7
				v.pos = V(math.cos(a) * r, c.groundY + v.s / 2, math.sin(a) * r)
				age = t - v.t0
			elseif age > v.life then
				v.t0 = t
				v.life = 1.2 + rng:NextNumber() * 0.8
				v.s = 0.5 + rng:NextNumber() * 0.8
				local a = rng:NextNumber() * TAU
				local r = 2.5 + rng:NextNumber() * 6.5
				v.pos = V(math.cos(a) * r, c.groundY + v.s / 2, math.sin(a) * r)
				age = 0
			end
			if age < 0 then
				v.p.Transparency = 1
				continue
			end
			local f = age / math.max(v.life, 0.01)
			local grow = smooth01(f / 0.2)
			v.p.Size = V(v.s, math.max(v.s * grow, 0.02), v.s)
			v.p.Transparency = 0.15 + 0.85 * smooth01((f - 0.6) / 0.4)
			Core.put(v.p, ground * CF(v.pos + V(0, v.s * (grow - 1) / 2 + f * 0.6, 0)))
		end
		-- typed voxels: spawned in front of the typing hand, drift up and fade; enter bursts them
		while #pendingTyped > 0 do
			local s = table.remove(pendingTyped, 1) :: string
			typedN = typedN % #typed + 1
			local ty = typed[typedN]
			ty.t0 = t
			ty.s = 0.35 + rng:NextNumber() * 0.3
			local sx = if s == "L" then -1 else 1
			ty.pos = V(sx * (0.6 + rng:NextNumber() * 1.6), c.chestY + 0.3 + rng:NextNumber() * 1.4, -2.2 - rng:NextNumber())
		end
		if fixAtTip and rhandTip then
			fixAtTip = false
			typedN = typedN % #typed + 1
			local ty = typed[typedN]
			ty.t0 = t
			ty.s = 0.7
			ty.pos = root:PointToObjectSpace(rhandTip.WorldPosition)
		end
		local sEnter = Sync.since(bus, "enter")
		for _, ty in typed do
			local age = t - ty.t0
			if age > 2.2 then
				if ty.p.Transparency < 1 then
					ty.p.Transparency = 1
				end
				continue
			end
			local burst = if sEnter < age then smooth01(sEnter / 0.35) else 0
			local s = ty.s * smooth01(age / 0.12) * (1 + burst * 1.5)
			ty.p.Size = V(s, s, s)
			ty.p.Transparency = math.clamp(0.1 + age / 2.2 * 0.9 + burst, 0, 1)
			Core.put(ty.p, root * CF(ty.pos + V(0, age * 0.5 + burst * 1.5, 0)) * ANG(age * 2, age * 3, 0))
		end
		-- code tiles under the air-walking feet (world space, stay where they were written)
		while #pendingTile > 0 do
			local s = table.remove(pendingTile, 1) :: string
			local foot = Core.bodyPart(c.char, if s == "L" then "Left Leg" else "Right Leg", if s == "L" then "LeftFoot" else "RightFoot")
			if foot then
				tileN = tileN % #tiles + 1
				local tl = tiles[tileN]
				tl.t0 = t
				local fp = foot.CFrame * V(0, -foot.Size.Y / 2 - 0.08, 0)
				tl.cf = CF(fp) * root.Rotation
			end
		end
		for _, tl in tiles do
			local age = t - tl.t0
			if age > 0.7 then
				if tl.p.Transparency < 1 then
					tl.p.Transparency = 1
				end
				continue
			end
			local k = smooth01(age / 0.08)
			tl.p.Size = V(1.7 * (0.6 + 0.4 * k), 0.08, 1.7 * (0.6 + 0.4 * k))
			tl.p.Transparency = 0.15 + 0.85 * (age / 0.7)
			Core.put(tl.p, tl.cf)
		end
		-- cursor + title
		Core.put(cursor, root * CF(2.95, c.topY + 2.3, 0))
		cursor.Transparency = if eKey > 0.2 or eFix > 0.2 or (t % 1) < 0.5 then 0 else 1
		if broken ~= lastBroken then
			lastBroken = broken
			title.Text = if broken then "ERROR 404 // REALITY NOT FOUND" else TITLE
			title.TextColor3 = if broken then Color3.fromRGB(255, 60, 60) else c.c1
		end
		local sE = Sync.since(bus, "enter")
		title.TextTransparency = if broken
			then (if rng:NextNumber() < 0.3 then 0.8 else 0)
			elseif sE < 0.15 then (if rng:NextNumber() < 0.5 then 0.9 else 0)
			elseif rng:NextNumber() < 0.03 then 0.7
			else 0
		light.Brightness = 3.2 + Core.pulse(t, 2) * 1.5 + eComp * 4 + eBuild * 3 + eFix * 2 + eKey * 0.6
		light.Range = 24 + eComp * 10
	end)
end

-- black censor bars orbiting, red classified stamps, reality tearing
-- parts ~70, emitters 6
-- [REDACTED]: Synced to the Blender animation (tools/blender/anim/auras/Redacted.py, levitating
-- set, lift 2 studs). Idle markers (6 s loop): snap L/R/C (head snaps -> face bar flash, censor
-- reshuffle), stamp R/L (CLASSIFIED stamp slams in at that hand + hand sparks + seal flash),
-- cut x4 (frame cuts -> clone shove + glitch burst), grab (red seam between the hands), tear
-- (every reality tear rips open + chest shockwave + hand bursts), seal (tears snap shut, every
-- stamp slams [REDACTED], ground shock). Walk: blink R/L (afterimage left behind). Reactions:
-- launch (jump), slam (land), breach (emitted HERE every 3.5-6 s while moving) -> twitch x3.
-- The floor seal / disc / ring / smoke / tears live on the real ground under the hovering body.
A.Redacted = function(c: Ctx)
	local rng = c.rng
	local bus = c.bus
	local red = c.c2
	local ink = Color3.fromRGB(4, 4, 4)
	local real = c.realRoot
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
	local hsz = Core.headSize(c.head)
	local hw = hsz.X * 1.15
	local faceBar = Core.part(c, V(hw, 0.28, 0.06), ink, SMOOTH)
	local faceEdge = Core.part(c, V(hw, 0.03, 0.07), red)
	-- giant censor bar hanging in the sky, turned to the camera
	local skyBar = Core.part(c, V(9, 1.5, 0.12), ink, SMOOTH)
	local skyEdge = Core.part(c, V(9.3, 1.8, 0.08), red)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Core.surface(skyBar, face, 30)
		Core.label(sg, "[ REDACTED ]", red, F.tech, UDim2.fromScale(0.05, 0.15), UDim2.fromScale(0.9, 0.7))
	end
	type Stamp = { att: Attachment, gui: BillboardGui, lbl: TextLabel, stroke: UIStroke, t0: number, big: number }
	local stamps: { Stamp } = {}
	local words = { "CLASSIFIED", "[REDACTED]", "TOP SECRET", "EYES ONLY", "DENIED", "LEVEL 5" }
	local function relocate(s: Stamp, t: number)
		s.t0 = t
		s.big = 1
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
		local s: Stamp = { att = att, gui = gui, lbl = lbl, stroke = stroke, t0 = 0, big = 1 }
		relocate(s, os.clock() - i * 0.7)
		stamps[i] = s
	end
	-- the oldest stamp is re-used for a synced slam (at a hand, or around the body)
	local function slamStamp(pos: Vector3, word: string, big: number)
		local best = stamps[1]
		for _, s in stamps do
			if s.t0 < best.t0 then
				best = s
			end
		end
		best.t0 = os.clock()
		best.big = big
		best.att.Position = pos
		best.lbl.Text = word
		best.lbl.Rotation = (rng:NextNumber() - 0.5) * 24
	end
	-- reality tears: black core polyline over a wider red glowing edge (on the real ground)
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
			edge = B.poly(c, pts, red, w, { segs = 1, bright = 3 }, real),
			core = B.poly(c, pts, BLACK, w * 0.6, { segs = 1, light = 0, zoff = 0.05 }, real),
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
			return CF(0, g + 0.06 - c.lift, 0)
		end,
	})
	-- floor seal (B.sigil layout, but on the real root so it stays on the ground)
	local seal: { B.Circle } = {}
	local sealTr = { 0.05, 0.3, 0.3 }
	for k = 1, 3 do
		local f = 1 - (k - 1) / 2 * 0.55
		seal[k] = B.circle(c, {
			radius = 8.8 * f,
			color = red,
			width = if k == 1 then 0.19 else 0.11,
			at = CF(0, g + 0.04 + k * 0.004, 0),
			tr = sealTr[k],
			n = if 8.8 * f > 4 then 10 else 8,
			parent = real,
		})
	end
	-- ground shock ring (slam / seal / launch) and chest shockwave shell (tear), re-used
	local shock = Core.part(c, V(0.05, 2, 2), red, NEON, 1, CYL)
	local shell = Core.part(c, V(2, 2, 2), red, FF, 1, BALL)
	local ox, oz, burstUntil = 0, 0, 0
	local shoveAmp, shoveSign = 0.4, 1
	B.clones(c, {
		set = "lite",
		color = BLACK,
		mat = NEON,
		tr = 0.45,
		scale = 1.02,
		map = function(cf, root)
			if ox == 0 and oz == 0 then
				return cf
			end
			return root * CF(ox, 0, oz) * root:ToObjectSpace(cf)
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
	local sparks = Core.emit(torso, {
		tex = T.fireSpark,
		color = cs(red, WHITE),
		size = ns(0.4, 0),
		rate = 24,
		life = nr(0.6, 1.2),
		speed = nr(3, 7),
		spread = V2(180, 180),
		bright = 2.5,
	})
	local vortex = Core.emit(torso, {
		tex = T.vortex,
		color = cs(red),
		size = ns(8, 12),
		transp = ns(0.72, 1),
		rate = 1.5,
		life = nr(1, 1.4),
		rotSpeed = nr(100, 160),
		locked = true,
	})
	local smokeVol = Core.volume(c, V(14, 0.1, 14), CF(0, g + 0.1, 0), real)
	local smoke = Core.emit(smokeVol, {
		tex = T.smoke,
		color = cs(BLACK),
		size = ns(3, 7),
		transp = ns(0.4, 1),
		rate = 8,
		life = nr(2, 3),
		speed = nr(0.5, 1.2),
		light = 0,
		rotSpeed = nr(-30, 30),
		shape = BOX,
	})
	local glitchVol = Core.volume(c, V(12, 9, 12), CF(0, c.chestY + 1.5, 0))
	local glitch = Core.emit(glitchVol, {
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
	-- body-bound pieces: hand spark bursts + the red seam torn open between the hands
	local hands: { [string]: Attachment } = {}
	local handFx: { [string]: ParticleEmitter } = {}
	local tipOf: { [string]: string } = { R = "rhand", L = "lhand" }
	for side: string, tip: string in tipOf do
		local att = Core.tip(c, tip) or Core.att(c, c.torso)
		hands[side] = att
		handFx[side] = Core.emit(att, {
			tex = T.fireSpark,
			color = cs(WHITE, red),
			size = ns(0.5, 0),
			rate = 0,
			life = nr(0.3, 0.7),
			speed = nr(8, 16),
			spread = V2(180, 180),
			drag = 4,
			bright = 4,
		})
	end
	local seam = Core.beam(c, hands.R, hands.L, red, 0, { color2 = WHITE, segs = 6, bright = 4 })
	local seamCore = Core.beam(c, hands.R, hands.L, BLACK, 0, { segs = 6, light = 0, zoff = 0.05 })
	local light = B.rootLight(c, red, 3, 22)

	local nextC = 0
	local function on(ev: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, ev, fn))
	end
	local function shove(amp: number, dur: number)
		burstUntil = os.clock() + dur
		shoveAmp = amp
		shoveSign = if rng:NextNumber() < 0.5 then -1 else 1
		ox = shoveSign * amp
		oz = 0
	end
	on("snap", function()
		nextC = 0 -- censor frames reshuffle on every head snap
		glitch:Emit(10)
	end)
	on("stamp", function(side: any)
		local att = hands[if side == "L" then "L" else "R"]
		local p = c.root.CFrame:PointToObjectSpace(att.WorldPosition)
		slamStamp(p + V(0, 0.3, 0), if side == "L" then "TOP SECRET" else "CLASSIFIED", 1.4)
		handFx[if side == "L" then "L" else "R"]:Emit(36)
		glitch:Emit(16)
	end)
	on("cut", function()
		shove(0.9, 0.09)
		glitch:Emit(30)
	end)
	on("tear", function()
		sparks:Emit(70)
		vortex:Emit(3)
		handFx.R:Emit(50)
		handFx.L:Emit(50)
		glitch:Emit(40)
		shove(0.5, 0.12)
	end)
	on("seal", function()
		for i, s in stamps do
			local a = (i - 1) / #stamps * TAU + rng:NextNumber() * 0.5
			s.t0 = os.clock() - (i - 1) * 0.03 -- tiny cascade
			s.big = 1.2
			s.att.Position = V(math.cos(a) * 3.6, c.chestY + (i % 2) * 1.4 - 0.4, math.sin(a) * 3.6)
			s.lbl.Text = "[REDACTED]"
			s.lbl.Rotation = (rng:NextNumber() - 0.5) * 24
		end
		smoke:Emit(6)
	end)
	on("blink", function(side: any)
		oz = if side == "L" then 0.5 else 0.9
		ox = 0
		burstUntil = os.clock() + 0.1
		glitch:Emit(18)
	end)
	on("twitch", function()
		shove(1.1, 0.1)
		glitch:Emit(26)
		nextC = 0
	end)
	on("launch", function()
		glitch:Emit(20)
		smoke:Emit(4)
	end)
	on("slam", function()
		slamStamp(V(0, c.chestY - 1.5, -2.6), "DENIED", 1.6)
		smoke:Emit(8)
		sparks:Emit(30)
	end)
	local nextBreach = os.clock() + 3

	Core.on(c, function(t, _, root)
		-- breach: containment fails every 3.5-6 s while moving -> the body's breach reaction
		if Sync.get(bus, "move") > 0.5 and Sync.get(bus, "air") < 0.5 then
			if t >= nextBreach then
				nextBreach = t + 3.5 + rng:NextNumber() * 2.5
				Sync.emit(bus, "breach")
			end
		elseif nextBreach - t < 1.5 then
			nextBreach = t + 1.5
		end
		if rng:NextNumber() < 0.006 then
			shove(0.4, 0.12) -- rare ambient flicker between the synced cuts
		end
		if t >= burstUntil then
			ox, oz = 0, 0
		elseif oz == 0 then
			ox = shoveSign * shoveAmp * (0.6 + rng:NextNumber() * 0.6) -- frame-cut afterimage judder
		end
		local eSnap = math.max(Sync.env(bus, "snap", 9), Sync.env(bus, "blink", 12), Sync.env(bus, "twitch", 10))
		local eStamp = Sync.env(bus, "stamp", 5)
		local eTear = Sync.env(bus, "tear", 3)
		local eSeal = Sync.env(bus, "seal", 4)
		local eGround = math.max(Sync.env(bus, "slam", 4), eSeal, Sync.env(bus, "launch", 6) * 0.6)
		local sTear, sSeal = Sync.since(bus, "tear"), Sync.since(bus, "seal")
		-- open while the hands hold reality apart (tear -> seal), snapped shut on the seal
		local torn = if sTear < sSeal and sTear < 3 then math.clamp(sTear / 0.12, 0, 1)
			else math.exp(-sSeal * 16)
		local sGrab = Sync.since(bus, "grab")
		local seamOn = if sGrab < sTear and sGrab < 1.2 then math.clamp(sGrab / 0.2, 0, 1) else 0
		for i, b in bars do
			if rng:NextNumber() < 0.003 then
				b.y = barY()
			end
			local a = b.a + t * b.w * (1 + eTear * 3)
			local cf = root
				* outward(a, b.r + eTear * 2.5, b.y + math.sin(t * 1.3 + i) * 0.25)
				* ANG(0, 0, b.tilt + math.sin(t * 0.7 + i) * 0.1)
			Core.put(b.p, cf)
			Core.put(b.edge, cf * CF(0, -0.31, 0))
		end
		local hcf = c.head.CFrame * CF(0, 0.1, -hsz.Z / 2 - 0.04)
		if eSnap > 0.02 then
			hcf *= CF(jitter(rng, eSnap * 0.12))
		end
		faceBar.Size = V(hw * (1 + eSnap * 0.6 + eSeal * 0.3), 0.28 * (1 + eSnap * 1.3 + eSeal * 0.8), 0.06)
		faceEdge.Size = V(faceBar.Size.X, 0.03 + eSnap * 0.05, 0.07)
		Core.put(faceBar, hcf)
		Core.put(faceEdge, hcf * CF(0, -faceBar.Size.Y / 2 - 0.015, 0))
		local skyPos = (root * CF(0, c.topY + 5 + math.sin(t * 0.7) * 0.3, 0)).Position
		local cam = camPos()
		local flatCam = V(cam.X, skyPos.Y, cam.Z)
		local scf = if (flatCam - skyPos).Magnitude > 0.1 then CFrame.lookAt(skyPos, flatCam) else CF(skyPos)
		local shake = (if t < burstUntil then 0.6 else 0) + eTear * 0.8 + eStamp * 0.25
		scf *= ANG(0, 0, math.sin(t * 0.9) * 0.06) * CF(jitter(rng, shake))
		Core.put(skyBar, scf)
		Core.put(skyEdge, scf) -- thinner than the bar: only the rim shows, on both faces
		for _, s in stamps do
			local age = t - s.t0
			if age > 2.6 then
				relocate(s, t)
				age = 0
			end
			local sc = (if age < 0.12 then 2.2 - age / 0.12 * 1.2 else 1) * s.big
			local fade = math.clamp((age - 2.2) / 0.4, 0, 1)
			local appear = math.clamp(age / 0.12, 0, 1)
			s.gui.Size = UDim2.new(3.2 * sc, 0, 0.8 * sc, 0)
			local tr = math.max(1 - appear, fade)
			s.lbl.TextTransparency = tr
			s.stroke.Transparency = tr
		end
		for _, tr in tears do
			local ph = ((t + tr.off) % 4) / 4
			local open = math.max(0.55 * math.sin(math.clamp(ph / 0.7, 0, 1) * math.pi), torn)
			if (ph > 0.95 and rng:NextNumber() < 0.2) or (torn > 0.5 and rng:NextNumber() < 0.15) then
				local amp = 0.7 + torn * 0.6
				for j = 2, #tr.base - 1 do
					local jit = V((rng:NextNumber() - 0.5) * amp, 0, (rng:NextNumber() - 0.5) * amp)
					tr.core.atts[j].Position = tr.base[j] + jit
					tr.edge.atts[j].Position = tr.base[j] + jit
				end
			end
			for j, bm in tr.core.beams do
				local env = math.sin((j - 0.5) / #tr.core.beams * math.pi)
				local wc = tr.w * 0.6 * open * env * (1 + eTear * 0.5)
				bm.Width0 = wc
				bm.Width1 = wc
				local eb = tr.edge.beams[j]
				eb.Width0 = (wc + tr.w * 0.35) * (if open > 0.02 then 1 else 0)
				eb.Width1 = eb.Width0
			end
		end
		-- the seam the hands dig into (grab -> tear), flickering; flashes wide on the tear
		local seamW = seamOn * (0.25 + rng:NextNumber() * 0.2) + eTear * 1.4 * math.exp(-sTear * 6)
		seam.Width0, seam.Width1 = seamW, seamW
		seamCore.Width0, seamCore.Width1 = seamW * 0.45, seamW * 0.45
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
		local ground = root * CF(0, g - c.lift, 0)
		Core.put(disc, ground * CF(0, 0.02, 0) * FLAT)
		Core.put(stampFloor, ground * CF(0, 0.06, 0) * ANG(0, t * 0.2, 0))
		local floorFlash = math.max(eStamp, eGround)
		fl.TextTransparency = 0.2 - 0.2 * floorFlash
		local pulse = Core.pulse(t, 1.1)
		for k, cir in seal do
			B.setBeamsTransparency(cir.beams, sealTr[k] + pulse * 0.35 * (1 - floorFlash) - floorFlash * 0.3)
		end
		-- ground shock ring: expands from the seal on slam / seal / launch
		local sG = math.min(Sync.since(bus, "slam"), sSeal, Sync.since(bus, "launch"))
		if sG < 0.5 then
			local k = sG / 0.5
			local d = 2 + smooth01(k) * 16
			shock.Size = V(0.05, d, d)
			shock.Transparency = 0.1 + k * 0.9
			Core.put(shock, ground * CF(0, 0.1, 0) * FLAT)
		elseif shock.Transparency < 1 then
			shock.Transparency = 1
		end
		-- chest shockwave shell on the tear
		if sTear < 0.55 then
			local k = sTear / 0.55
			local d = 2 + smooth01(k) * 14
			shell.Size = V(d, d, d)
			shell.Transparency = 0.2 + k * 0.8
			Core.put(shell, c.torso.CFrame)
		elseif shell.Transparency < 1 then
			shell.Transparency = 1
		end
		local base = if t < burstUntil then 7 else 2.6 + math.noise(t * 3, 2) * 1.4
		light.Brightness = base + eTear * 7 + eStamp * 3 + eGround * 3
	end)
end

return A
