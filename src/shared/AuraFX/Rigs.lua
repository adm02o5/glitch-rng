--!strict
-- AuraFX/Rigs: detailed right-hand gear for Config.Rigs. Pieces are anchored and pinned to
-- the forearm / hand every frame (R15: RightLowerArm + RightHand, R6: Right Arm).
-- Frame convention ("wrist frame"): origin at the wrist, +Y up the forearm, -Y towards the
-- fingers, +X = outer side / back of the hand, -Z = forward.

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
local SHELL = Color3.fromRGB(16, 18, 26)
local SHELL2 = Color3.fromRGB(28, 31, 44)

type Rig = {
	arm: BasePart,
	hand: BasePart,
	armOff: CFrame, -- wrist frame relative to arm part
	handOff: CFrame, -- wrist frame relative to hand part
	rw: number, -- forearm radius
	hl: number, -- hand length below the wrist
	pins: { { p: BasePart, cf: CFrame, hand: boolean } },
}

local function setup(c: Ctx): Rig?
	local arm = Core.bodyPart(c.char, "RightLowerArm", "Right Arm")
	local hand = Core.bodyPart(c.char, "RightHand", "Right Arm")
	if not arm or not hand then
		return nil
	end
	local r15 = arm.Name == "RightLowerArm"
	local rig: Rig = {
		arm = arm,
		hand = hand,
		armOff = if r15 then CF(0, -arm.Size.Y / 2, 0) else CF(0, -0.55, 0),
		handOff = if r15 then CF(0, hand.Size.Y / 2, 0) else CF(0, -0.55, 0),
		rw = math.max(arm.Size.X, arm.Size.Z) / 2,
		hl = if r15 then hand.Size.Y else 0.45,
		pins = {},
	}
	return rig
end

local function pin(rig: Rig, p: BasePart, cf: CFrame, onHand: boolean?)
	table.insert(rig.pins, { p = p, cf = cf, hand = onHand == true })
end

-- band of n plates around the forearm at height y
local function band(
	c: Ctx,
	rig: Rig,
	n: number,
	y: number,
	h: number,
	thick: number,
	color: Color3,
	mat: Enum.Material?,
	color2: Color3?
)
	local r = rig.rw + thick / 2 + 0.01
	local tang = TAU * r / n * 0.92
	for i = 1, n do
		local a = (i - 1) / n * TAU
		local col = if color2 and i % 2 == 0 then color2 else color
		local p = Core.part(c, V(thick, h, tang), col, mat or METAL)
		pin(rig, p, CF(0, y, 0) * ANG(0, -a, 0) * CF(r, 0, 0))
	end
end

-- thin glowing line around the forearm (static beams on the arm part)
local function seam(c: Ctx, rig: Rig, y: number, color: Color3, extra: number?)
	B.circle(c, {
		radius = rig.rw + (extra or 0.06),
		color = color,
		width = 0.035,
		n = 6,
		parent = rig.arm,
		at = rig.armOff * CF(0, y, 0),
	})
end

local function run(c: Ctx, rig: Rig, extra: ((t: number, W: CFrame, H: CFrame) -> ())?)
	Core.on(c, function(t)
		local W = rig.arm.CFrame * rig.armOff
		local H = rig.hand.CFrame * rig.handOff
		for _, pn in rig.pins do
			Core.put(pn.p, (if pn.hand then H else W) * pn.cf)
		end
		if extra then
			extra(t, W, H)
		end
	end)
end

local Rigs: { [string]: (Ctx) -> () } = {}

-- cheap smart band: strap, glowing screen, status LEDs
Rigs.Wristband = function(c: Ctx)
	local rig = setup(c)
	if not rig then
		return
	end
	local col = c.c1
	band(c, rig, 12, 0.22, 0.26, 0.07, SHELL, SMOOTH)
	seam(c, rig, 0.1, col)
	seam(c, rig, 0.34, col)
	local x = rig.rw + 0.09
	local bezel = Core.part(c, V(0.05, 0.36, 0.48), col)
	local screen = Core.part(c, V(0.06, 0.32, 0.44), Color3.fromRGB(4, 6, 10), SMOOTH)
	pin(rig, bezel, CF(x - 0.01, 0.22, 0))
	pin(rig, screen, CF(x, 0.22, 0))
	local sg = Core.surface(screen, Enum.NormalId.Right, 160)
	local clock = Core.label(sg, "12:07", col, F.pixel, UDim2.fromScale(0.08, 0.1), UDim2.fromScale(0.84, 0.42))
	local luck = Core.label(
		sg,
		"+10% LUCK",
		col:Lerp(WHITE, 0.4),
		F.mono,
		UDim2.fromScale(0.08, 0.6),
		UDim2.fromScale(0.84, 0.26)
	)
	local leds =
		{ Core.part(c, V(0.06, 0.06, 0.06), col), Core.part(c, V(0.06, 0.06, 0.06), Color3.fromRGB(80, 255, 140)) }
	pin(rig, leds[1], CF(-(rig.rw + 0.08), 0.28, -0.12))
	pin(rig, leds[2], CF(-(rig.rw + 0.08), 0.16, -0.12))
	local sa = Core.att(c, rig.arm, rig.armOff * CF(x + 0.05, 0.22, 0))
	Core.emit(sa, {
		tex = T.spark,
		color = cs(col),
		size = ns(0.12, 0),
		rate = 2,
		life = nr(0.4, 0.8),
		speed = nr(0.3, 0.6),
		spread = V2(60, 60),
		dir = Enum.NormalId.Right,
	})
	Core.light(sa, col, 0.6, 5)
	run(c, rig, function(t)
		local m = math.floor(t / 60) % 60
		clock.Text = string.format("%02d%s%02d", 12, if (t % 1) < 0.5 then ":" else " ", m)
		luck.TextTransparency = if (t % 4) < 0.15 then 0.8 else 0
		leds[1].Transparency = if math.sin(t * 4) > 0 then 0 else 0.85
		leds[2].Transparency = if math.sin(t * 1.3) > 0.7 then 0 else 0.6
	end)
end

-- bracer with side scanner, antenna and dish catching flying packets
Rigs.Sniffer = function(c: Ctx)
	local rig = setup(c)
	if not rig then
		return
	end
	local col = c.c1
	band(c, rig, 8, 0.38, 0.7, 0.09, SHELL, METAL, SHELL2)
	seam(c, rig, 0.03, col, 0.11)
	seam(c, rig, 0.73, col, 0.11)
	local x = rig.rw + 0.17
	local module = Core.part(c, V(0.16, 0.52, 0.38), SHELL2, METAL)
	pin(rig, module, CF(x, 0.38, 0))
	local screen = Core.part(c, V(0.02, 0.4, 0.3), Color3.fromRGB(2, 10, 10), SMOOTH)
	pin(rig, screen, CF(x + 0.08, 0.38, 0))
	pin(rig, Core.part(c, V(0.03, 0.52, 0.03), col), CF(x + 0.07, 0.38, 0.19))
	pin(rig, Core.part(c, V(0.03, 0.52, 0.03), col), CF(x + 0.07, 0.38, -0.19))
	local sg = Core.surface(screen, Enum.NormalId.Right, 200)
	local lines: { TextLabel } = {}
	for i = 1, 4 do
		lines[i] = Core.label(
			sg,
			"",
			col,
			F.mono,
			UDim2.fromScale(0.05, 0.05 + (i - 1) * 0.23),
			UDim2.fromScale(0.9, 0.2),
			Enum.TextXAlignment.Left
		)
	end
	local rodLen = 0.9
	local rodCF = CF(x, 0.64, 0.08) * ANG(0.35, 0, 0) * CF(0, rodLen / 2, 0)
	pin(rig, Core.part(c, V(rodLen, 0.04, 0.04), SHELL2, METAL, 0, CYL), rodCF * ANG(0, 0, math.pi / 2))
	local tip = Core.part(c, V(0.12, 0.12, 0.12), col, NEON, 0, BALL)
	local tipCF = rodCF * CF(0, rodLen / 2, 0)
	pin(rig, tip, tipCF)
	local dish = Core.part(c, V(0.03, 0.32, 0.32), col, NEON, 0.2, CYL)
	local dishBar = Core.part(c, V(0.04, 0.3, 0.03), WHITE)
	local tipAtt = Core.att(c, rig.arm, rig.armOff * tipCF)
	Core.emit(tipAtt, {
		tex = T.spark,
		color = cs(col, WHITE),
		size = ns(0.15, 0),
		rate = 3,
		life = nr(0.3, 0.6),
		speed = nr(0.5, 1),
		spread = V2(180, 180),
	})
	Core.light(tipAtt, col, 0.8, 6)
	type Pk = { p: BasePart, from: Vector3, t0: number }
	local pks: { Pk } = {}
	for i = 1, 3 do
		local p = Core.part(c, V(0.08, 0.08, 0.08), col)
		Core.trail(p, col, 0.06, 0.2)
		pks[i] = { p = p, from = c.rng:NextUnitVector() * 1.6, t0 = os.clock() - i * 0.4 }
	end
	local nextL = 0
	run(c, rig, function(t, W)
		if t >= nextL then
			nextL = t + 0.18
			for i = 1, 3 do
				lines[i].Text = lines[i + 1].Text
			end
			lines[4].Text = Core.hex(4, c.rng) .. " > " .. Core.hex(4, c.rng)
		end
		tip.Transparency = if (t % 0.8) < 0.15 then 0 else 0.5
		local dcf = W * rodCF * CF(0, -0.05, 0) * ANG(0, t * 2, 0)
		Core.put(dish, dcf * ANG(0, 0, math.pi / 2))
		Core.put(dishBar, dcf * CF(0, 0.02, 0) * ANG(0, 0, math.pi / 2))
		local tipW = (W * tipCF).Position
		for _, pk in pks do
			local f = (t - pk.t0) / 1.1
			if f >= 1 then
				pk.t0 = t
				pk.from = c.rng:NextUnitVector() * 1.6
				f = 0
			end
			local start = tipW + pk.from + V(0, 0.4, 0)
			local e = f * f
			Core.put(pk.p, CF(start:Lerp(tipW, e)) * ANG(t * 4, t * 3, 0))
			pk.p.Transparency = if f > 0.95 then 1 else 0
		end
	end)
end

-- liquid-cooled gauntlet: coolant tubes, radiator fins, spinning fan
Rigs.Overclocker = function(c: Ctx)
	local rig = setup(c)
	if not rig then
		return
	end
	local col = c.c1
	local hot = col:Lerp(Color3.fromRGB(255, 255, 140), 0.5)
	band(c, rig, 10, 0.42, 0.8, 0.09, SHELL, METAL, SHELL2)
	seam(c, rig, 0.04, col, 0.11)
	seam(c, rig, 0.8, col, 0.11)
	local tubes: { BasePart } = {}
	for _, z in { -1, 1 } do
		local zz = z * (rig.rw + 0.16)
		pin(rig, Core.part(c, V(0.95, 0.12, 0.12), col, NEON, 0.35, CYL), CF(0, 0.42, zz) * ANG(0, 0, math.pi / 2))
		local core = Core.part(c, V(0.97, 0.05, 0.05), hot, NEON, 0, CYL)
		pin(rig, core, CF(0, 0.42, zz) * ANG(0, 0, math.pi / 2))
		table.insert(tubes, core)
	end
	for i = 1, 5 do
		pin(
			rig,
			Core.part(c, V(0.22, 0.035, 0.42), if i % 2 == 0 then SHELL2 else col, if i % 2 == 0 then METAL else NEON),
			CF(rig.rw + 0.17, 0.18 + i * 0.11, 0)
		)
	end
	local fanC = CF(rig.rw * 0.6 + 0.12, -rig.hl * 0.5, 0)
	for i = 1, 6 do
		local a = (i - 1) / 6 * TAU
		pin(rig, Core.part(c, V(0.06, 0.06, 0.2), SHELL2, METAL), fanC * ANG(a, 0, 0) * CF(0, 0.26, 0), true)
	end
	local hub = Core.part(c, V(0.1, 0.12, 0.12), hot, NEON, 0, CYL)
	pin(rig, hub, fanC * CF(0.02, 0, 0), true)
	local blades: { BasePart } = {}
	for i = 1, 5 do
		blades[i] = Core.part(c, V(0.02, 0.2, 0.09), col, NEON, 0.1)
	end
	local coreGlow = Core.part(c, V(0.08, 0.18, 0.12), hot)
	pin(rig, coreGlow, CF(0, 0.12, -(rig.rw + 0.06)))
	local fa = Core.att(c, rig.hand, rig.handOff * fanC * CF(0.1, 0, 0))
	Core.emit(fa, {
		tex = T.fireSpark,
		color = cs(hot, col),
		size = ns(0.12, 0),
		rate = 8,
		life = nr(0.4, 0.8),
		speed = nr(1.5, 3),
		spread = V2(40, 40),
		dir = Enum.NormalId.Right,
		accel = V(0, 2, 0),
		bright = 2.5,
	})
	Core.emit(Core.att(c, rig.arm, rig.armOff * CF(rig.rw + 0.25, 0.45, 0)), {
		tex = T.smoke,
		color = cs(col),
		size = ns(0.3, 0.9),
		transp = ns(0.85, 1),
		rate = 4,
		life = nr(0.8, 1.2),
		speed = nr(0.5, 1),
		spread = V2(30, 30),
		dir = Enum.NormalId.Right,
		light = 0.4,
	})
	local light = Core.light(fa, col, 1, 7)
	run(c, rig, function(t, _, H)
		local f = H * fanC
		for i, b in blades do
			Core.put(b, f * CF(0.03, 0, 0) * ANG(t * 30 + (i - 1) / 5 * TAU, 0, 0) * CF(0, 0.13, 0) * ANG(0, 0.5, 0))
		end
		local k = Core.pulse(t, 0.7)
		for _, tb in tubes do
			tb.Color = col:Lerp(hot, k)
		end
		light.Brightness = 0.8 + k * 0.8
	end)
end

-- forearm deck with glowing key grid, holo screen and orbiting qubits
Rigs.QuantumDeck = function(c: Ctx)
	local rig = setup(c)
	if not rig then
		return
	end
	local col = c.c1
	band(c, rig, 8, 0.05, 0.16, 0.07, SHELL, METAL)
	seam(c, rig, 0.14, col)
	seam(c, rig, 0.98, col)
	local x = rig.rw + 0.07
	local deckC = CF(x, 0.55, 0)
	pin(rig, Core.part(c, V(0.12, 1, 0.74), Color3.fromRGB(14, 8, 24), SMOOTH), deckC)
	pin(rig, Core.part(c, V(0.13, 1, 0.04), col), deckC * CF(0, 0, 0.37))
	pin(rig, Core.part(c, V(0.13, 1, 0.04), col), deckC * CF(0, 0, -0.37))
	pin(rig, Core.part(c, V(0.13, 0.04, 0.74), col), deckC * CF(0, 0.5, 0))
	pin(rig, Core.part(c, V(0.13, 0.04, 0.74), col), deckC * CF(0, -0.5, 0))
	local keys: { BasePart } = {}
	for r = 0, 3 do
		for k = 0, 2 do
			local p = Core.part(c, V(0.04, 0.13, 0.15), col)
			pin(rig, p, deckC * CF(0.07, -0.33 + r * 0.19, -0.2 + k * 0.2))
			table.insert(keys, p)
		end
	end
	local holoC = deckC * CF(0.45, 0.1, 0) * ANG(0, 0, -0.35)
	local holo = Core.part(c, V(0.02, 0.6, 0.7), col, NEON, 0.78)
	pin(rig, holo, holoC)
	pin(rig, Core.part(c, V(0.03, 0.03, 0.7), WHITE), holoC * CF(0, 0.31, 0))
	local sg = Core.surface(holo, Enum.NormalId.Right, 180)
	Core.label(sg, "|0> + |1>", WHITE, F.tech, UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.3))
	local prob = Core.label(
		sg,
		"P(win)=0.75",
		col:Lerp(WHITE, 0.5),
		F.mono,
		UDim2.fromScale(0.05, 0.5),
		UDim2.fromScale(0.9, 0.2)
	)
	local bar = Core.frame(sg, col:Lerp(WHITE, 0.3), UDim2.fromScale(0.05, 0.78), UDim2.fromScale(0.5, 0.08))
	type Q = { a: BasePart, b: BasePart }
	local qs: { Q } = {}
	for i = 1, 3 do
		local a = Core.part(c, V(0.1, 0.1, 0.1), WHITE)
		Core.trail(a, col, 0.07, 0.25)
		qs[i] = { a = a, b = Core.part(c, V(0.1, 0.1, 0.1), col, NEON, 0.6) }
	end
	local da = Core.att(c, rig.arm, rig.armOff * deckC * CF(0.2, 0, 0))
	Core.emit(da, {
		tex = T.spark,
		color = cs(col, WHITE),
		size = ns(0, 0.16, 0),
		rate = 5,
		life = nr(0.5, 1),
		speed = nr(0.4, 0.9),
		spread = V2(70, 70),
		dir = Enum.NormalId.Right,
	})
	Core.light(da, col, 1, 7)
	local nextK = 0
	run(c, rig, function(t, W)
		if t >= nextK then
			nextK = t + 0.1
			for _, k in keys do
				if c.rng:NextNumber() < 0.25 then
					local r = c.rng:NextNumber()
					k.Color = if r < 0.15 then WHITE else col
					k.Transparency = if r > 0.7 then 0.75 else 0
				end
			end
			local p = 0.5 + math.noise(t * 0.5, 3) * 0.9
			p = math.clamp(p, 0.01, 0.99)
			prob.Text = string.format("P(win)=%.2f", p)
			bar.Size = UDim2.fromScale(0.9 * p, 0.08)
		end
		for i, q in qs do
			local a = t * 2.4 + (i - 1) / 3 * TAU
			local r = rig.rw + 0.42
			local cf = W * CF(0, 0.05 + math.sin(t * 3 + i) * 0.06, 0) * ANG(0, -a, 0) * CF(r, 0, 0)
			Core.put(q.a, cf * ANG(t * 3, t * 2, 0))
			Core.put(q.b, W * CF(0, 0.05, 0) * ANG(0, -(a + math.pi), 0) * CF(r, 0, 0) * ANG(t * 2, t * 3, 0))
			q.b.Transparency = if math.sin(t * 7 + i * 2) > 0.2 then 0.5 else 1
		end
	end)
end

-- ring-zero gauntlet: layered armour, claws, core orb with gyro rings
Rigs.KernelCore = function(c: Ctx)
	local rig = setup(c)
	if not rig then
		return
	end
	local col = c.c1
	local cyan = Color3.fromRGB(0, 240, 255)
	for i = 0, 2 do
		band(c, rig, 5, 0.18 + i * 0.32, 0.28, 0.1 + i * 0.015, SHELL, METAL)
		seam(c, rig, 0.04 + i * 0.32, col, 0.13 + i * 0.015)
	end
	band(c, rig, 8, 1.05, 0.14, 0.09, SHELL2, METAL, col)
	for k = -1, 1 do
		pin(rig, Core.part(c, V(0.04, 0.9, 0.05), col), CF(rig.rw + 0.17, 0.5, k * 0.15))
	end
	local hx = rig.rw * 0.55 + 0.1
	for k = 0, 3 do
		local z = -0.3 + k * 0.2
		pin(rig, Core.part(c, V(0.12, 0.12, 0.16), SHELL2, METAL), CF(hx - 0.05, -rig.hl - 0.04, z), true)
		pin(rig, Core.part(c, V(0.035, 0.5, 0.05), col), CF(hx * 0.4, -rig.hl - 0.32, z) * ANG(0, 0, -0.18), true)
	end
	local coreC = CF(hx + 0.05, -rig.hl * 0.45, 0)
	local core = Core.part(c, V(0.34, 0.34, 0.34), col, NEON, 0, BALL)
	pin(rig, core, coreC, true)
	local shell = Core.part(c, V(0.55, 0.55, 0.55), cyan, FF, 0, BALL)
	pin(rig, shell, coreC, true)
	for k = 1, 2 do
		B.circle(c, {
			radius = 0.36 + k * 0.08,
			color = if k == 1 then col else cyan,
			width = 0.025,
			n = 4,
			parent = rig.hand,
			anchor = function(t)
				return rig.handOff * coreC * ANG(t * (2 + k), t * 1.3 * k, 0)
			end,
		})
	end
	local ca = Core.att(c, rig.hand, rig.handOff * coreC)
	local elbow = Core.att(c, rig.arm, rig.armOff * CF(rig.rw + 0.12, 1.05, 0))
	Core.beam(c, ca, elbow, col, 0.05, { w1 = 0.02, c0 = 0.3, c1 = -0.3, tex = T.square, texLen = 0.2, texSpeed = 3 })
	Core.emit(ca, {
		tex = T.glow,
		color = cs(col, cyan),
		size = ns(0.6, 1),
		transp = ns(0.5, 1),
		rate = 5,
		life = nr(0.3, 0.5),
		locked = true,
	})
	Core.emit(ca, {
		tex = T.spark,
		color = cs(col, WHITE),
		size = ns(0.18, 0),
		rate = 6,
		life = nr(0.4, 0.8),
		speed = nr(1, 2),
		spread = V2(180, 180),
	})
	local light = Core.light(ca, col, 1.4, 8)
	run(c, rig, function(t)
		local k = Core.pulse(t, 1)
		local s = 0.5 + k * 0.1
		shell.Size = V(s, s, s)
		core.Color = col:Lerp(WHITE, k * 0.4)
		light.Brightness = 1 + k
	end)
end

-- full glove: articulated fingers, circuit lines, holo world-globe above the palm
Rigs.ArchitectGlove = function(c: Ctx)
	local rig = setup(c)
	if not rig then
		return
	end
	local col = c.c1
	band(c, rig, 10, 0.22, 0.36, 0.09, SHELL, METAL, SHELL2)
	seam(c, rig, 0.02, col, 0.11)
	seam(c, rig, 0.42, col, 0.11)
	for k = -1, 1, 2 do
		pin(rig, Core.part(c, V(0.03, 0.8, 0.04), col), CF(rig.rw + 0.12, 0.85, k * 0.14))
	end
	band(c, rig, 8, 1.1, 0.1, 0.08, SHELL2, METAL, col)
	local hx = rig.rw * 0.55 + 0.04
	local plateC = CF(hx, -rig.hl * 0.5, 0)
	pin(rig, Core.part(c, V(0.12, rig.hl + 0.1, 0.6), SHELL, METAL), plateC, true)
	for k = -1, 1 do
		pin(rig, Core.part(c, V(0.02, rig.hl * 0.8, 0.03), col), plateC * CF(0.065, 0, k * 0.16), true)
	end
	local tips: { BasePart } = {}
	local fingers: { { p: BasePart, z: number, j: number } } = {}
	for f = 0, 3 do
		local z = -0.27 + f * 0.18
		for j = 1, 2 do
			table.insert(
				fingers,
				{ p = Core.part(c, V(0.1, 0.24, 0.11), if j == 2 then SHELL2 else SHELL, METAL), z = z, j = j }
			)
		end
		table.insert(tips, Core.part(c, V(0.09, 0.09, 0.09), col, NEON, 0, BALL))
	end
	local thumb = { Core.part(c, V(0.1, 0.22, 0.11), SHELL, METAL), Core.part(c, V(0.1, 0.2, 0.11), SHELL2, METAL) }
	table.insert(tips, Core.part(c, V(0.09, 0.09, 0.09), col, NEON, 0, BALL))
	local globeC = CF(-0.15, -rig.hl - 0.15, -0.85)
	local globe = Core.part(c, V(0.2, 0.2, 0.2), col, NEON, 0, BALL)
	pin(rig, globe, globeC, true)
	for k = 0, 2 do
		B.circle(c, {
			radius = 0.36,
			color = col,
			width = 0.022,
			n = 4,
			parent = rig.hand,
			anchor = function(t)
				return rig.handOff * globeC * ANG(0, t * 0.8 + k * math.pi / 3, 0) * ANG(0, 0, math.pi / 2)
			end,
		})
	end
	B.circle(
		c,
		{ radius = 0.36, color = WHITE, width = 0.02, n = 4, parent = rig.hand, at = rig.handOff * globeC, tr = 0.3 }
	)
	local ga = Core.att(c, rig.hand, rig.handOff * globeC)
	local gtop = Core.att(c, rig.hand, rig.handOff * globeC * CF(0, 3, 0))
	Core.beam(c, ga, gtop, col, 0.35, { w1 = 0, color2 = WHITE, tr = ns(0.35, 1) })
	type Gl = { att: Attachment, lbl: TextLabel }
	local gls: { Gl } = {}
	local syms = { "0", "1", "{", "}", "<", ">" }
	for i = 1, 6 do
		local att = Core.att(c, rig.hand)
		local _, lbl = Core.glyph(c, att, syms[i], col, V2(0.18, 0.18), F.pixel)
		gls[i] = { att = att, lbl = lbl }
	end
	Core.emit(ga, {
		tex = T.spark,
		color = cs(col, WHITE),
		size = ns(0, 0.18, 0),
		rate = 8,
		life = nr(0.6, 1),
		speed = nr(0.4, 0.9),
		spread = V2(180, 180),
	})
	Core.emit(ga, {
		tex = T.glow,
		color = cs(col),
		size = ns(0.8, 1.2),
		transp = ns(0.6, 1),
		rate = 4,
		life = nr(0.4, 0.6),
		locked = true,
	})
	Core.emit(Core.att(c, rig.hand, rig.handOff * CF(0, -rig.hl - 0.3, 0)), {
		tex = T.square,
		color = cs(col, WHITE),
		size = ns(0.06, 0),
		rate = 7,
		life = nr(0.6, 1.1),
		speed = nr(0.5, 1),
		spread = V2(40, 40),
		dir = Enum.NormalId.Top,
		rot = nr(0, 0),
	})
	local light = Core.light(ga, col, 1.6, 9)
	run(c, rig, function(t, _, H)
		local curl = 0.25 + math.sin(t * 1.2) * 0.12
		for _, fg in fingers do
			local base = H * CF(0.02, -rig.hl, fg.z) * ANG(0, 0, -curl)
			if fg.j == 1 then
				Core.put(fg.p, base * CF(0, -0.12, 0))
			else
				Core.put(fg.p, base * CF(0, -0.24, 0) * ANG(0, 0, -curl) * CF(0, -0.12, 0))
			end
		end
		for f = 0, 3 do
			local base = H * CF(0.02, -rig.hl, -0.27 + f * 0.18) * ANG(0, 0, -curl) * CF(0, -0.24, 0) * ANG(0, 0, -curl)
			Core.put(tips[f + 1], base * CF(0, -0.26, 0))
		end
		local tb = H * CF(-0.05, -rig.hl * 0.4, -0.38) * ANG(0.6, 0, 0)
		Core.put(thumb[1], tb * CF(0, -0.11, 0))
		Core.put(thumb[2], tb * CF(0, -0.22, 0) * ANG(0.3, 0, 0) * CF(0, -0.1, 0))
		Core.put(tips[5], tb * CF(0, -0.22, 0) * ANG(0.3, 0, 0) * CF(0, -0.22, 0))
		for i, g in gls do
			local a = (i - 1) / 6 * TAU + t * 1.4
			g.att.CFrame = rig.handOff * globeC * CF(math.cos(a) * 0.55, math.sin(t * 2 + i) * 0.12, math.sin(a) * 0.55)
		end
		light.Brightness = 1.3 + Core.pulse(t, 1.4) * 0.8
	end)
end

return Rigs
