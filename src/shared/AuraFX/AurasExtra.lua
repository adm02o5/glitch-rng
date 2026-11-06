--!strict
-- AuraFX/AurasExtra: the 18 extra small auras (BASIC / ENHANCED / RARE).
-- Same conventions and budgets as AurasLow / AurasMid:
--   Basic    ~2.5-3.5 stud radius, subtle but readable, root light + soft body glow.
--   Enhanced ~3-4.5 stud radius, one silhouette-breaking element + particles.
--   Rare     ~4-5 stud radius, layered: ground sigil, body element, sky/overhead element.

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
local GLASS = Enum.Material.Glass
local FLAT = ANG(0, 0, math.pi / 2) -- cylinder axis X -> vertical (disc lying flat)
local BOX = Enum.ParticleEmitterShape.Box
local VOLUME = Enum.ParticleEmitterShapeStyle.Volume
local FACE_X = ANG(0, math.pi / 2, 0) -- after lookAt: local +X faces the camera, Y up, Z screen-right

local function camPos(): Vector3
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

-- root-local frame on a horizontal circle whose -Z (Front face) points outward
local function outward(a: number, r: number, y: number): CFrame
	return ANG(0, -a, 0) * CF(r, y, 0) * ANG(0, -math.pi / 2, 0)
end

-- World CFrame at `pos` turned (around the vertical only) to face the camera with -Z.
local function faceCam(pos: Vector3): CFrame
	local cam = camPos()
	local flat = V(cam.X, pos.Y, cam.Z)
	if (flat - pos).Magnitude < 0.05 then
		return CF(pos)
	end
	return CFrame.lookAt(pos, flat)
end

-- Horizontal unit vectors (root-local): towards the camera, and to its right.
local function camAxes(root: CFrame): (Vector3, Vector3)
	local cl = root:PointToObjectSpace(camPos())
	local fl = V(cl.X, 0, cl.Z)
	local d = if fl.Magnitude > 1e-3 then fl.Unit else V(0, 0, -1)
	return d, V(-d.Z, 0, d.X)
end

local LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local function randChar(rng: Random, set: string): string
	local k = rng:NextInteger(1, #set)
	return string.sub(set, k, k)
end

local function smooth01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- overshooting 0..1 pop (for things appearing)
local function popIn(x: number): number
	if x <= 0 then
		return 0
	elseif x >= 1 then
		return 1
	end
	return 1 + 2.2 * (x - 1) ^ 3 + 1.2 * (x - 1) ^ 2
end

-- Coloured PointLight on the root (tints the character and the floor).
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

-- Anchored WedgePart (same flags as Core.part). Cross-section in local YZ is a right
-- triangle: (-h/2,-l/2) (-h/2,+l/2) (+h/2,+l/2).
local function wedge(c: Ctx, size: Vector3, color: Color3, mat: Enum.Material?, tr: number?): BasePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Material = mat or NEON
	p.Transparency = tr or 0
	p.CFrame = c.root.CFrame + V(0, -50, 0)
	p.Parent = c.folder
	return p
end

-- Flat isosceles triangle from two wedges, pointing +Y in the local YZ plane, centred on
-- its base midpoint. Returns the parts and their offsets for putTri.
type Tri = { a: BasePart, b: BasePart, oa: CFrame, ob: CFrame }
local function triangle(
	c: Ctx,
	base: number,
	height: number,
	thick: number,
	color: Color3,
	mat: Enum.Material?,
	tr: number?
): Tri
	local l = base / 2
	local a = wedge(c, V(thick, height, l), color, mat, tr)
	local b = wedge(c, V(thick, height, l), color, mat, tr)
	-- a: right half (vertical leg on the centre line), b: mirrored left half
	return {
		a = a,
		b = b,
		oa = CF(0, height / 2, -l / 2),
		ob = CF(0, height / 2, l / 2) * ANG(0, math.pi, 0),
	}
end

local function putTri(tri: Tri, cf: CFrame)
	Core.put(tri.a, cf * tri.oa)
	Core.put(tri.b, cf * tri.ob)
end

-- BillboardGui canvas for drawing small icons with frames.
local function canvas(c: Ctx, size: Vector2, at: CFrame?): (Attachment, BillboardGui, Frame)
	local a = Core.att(c, nil, at)
	local g = Instance.new("BillboardGui")
	g.Name = "Icon"
	g.Adornee = a
	g.Size = UDim2.new(size.X, 0, size.Y, 0)
	g.LightInfluence = 0
	g.Brightness = 2
	g.MaxDistance = 160
	g.ResetOnSpawn = false
	g.ClipsDescendants = false
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = g
	g.Parent = c.folder
	return a, g, f
end

local function round(inst: GuiObject, r: number?)
	local u = Instance.new("UICorner")
	u.CornerRadius = if r then UDim.new(r, 0) else UDim.new(1, 0)
	u.Parent = inst
end

local function stroke(inst: GuiObject, color: Color3, th: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = th
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

-- centred frame helper (position / size in scale units, rotation in degrees)
local function cframe(parent: Instance, color: Color3, x: number, y: number, w: number, h: number, rot: number?): Frame
	local f = Core.frame(parent, color, UDim2.fromScale(x, y), UDim2.fromScale(w, h))
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Rotation = rot or 0
	return f
end

-- Arc of beams in the XY plane of a (root-local) frame; place every frame with placeArc.
type Arc = { atts: { Attachment }, beams: { Beam } }
local function arc(c: Ctx, n: number, color: Color3, width: number, color2: Color3?): Arc
	local atts: { Attachment } = {}
	local beams: { Beam } = {}
	for i = 1, n + 1 do
		atts[i] = Core.att(c)
	end
	for i = 1, n do
		beams[i] = Core.beam(c, atts[i], atts[i + 1], color, width, { color2 = color2, segs = 8 })
	end
	return { atts = atts, beams = beams }
end

local function placeArc(a: Arc, base: CFrame, r: number, a0: number, a1: number)
	local n = #a.beams
	local step = (a1 - a0) / n
	local k = 4 / 3 * math.tan(step / 4) * r
	for i, att in a.atts do
		local ang = a0 + (i - 1) * step
		local cs_, sn = math.cos(ang), math.sin(ang)
		att.CFrame = base * CFrame.fromMatrix(V(cs_ * r, sn * r, 0), V(-sn, cs_, 0), V(0, 0, 1):Cross(V(-sn, cs_, 0)))
	end
	for _, b in a.beams do
		b.CurveSize0 = k
		b.CurveSize1 = k
	end
end

local A: { [string]: (Ctx) -> () } = {}

---------------------------------------------------------------- BASIC

-- little envelope icons bouncing around the body
-- 13 parts / 3 emitters / 7 icons
A.Spam = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local paper = c.c1:Lerp(WHITE, 0.55)
	type Env = {
		att: Attachment,
		gui: BillboardGui,
		body: Frame,
		badge: Frame,
		cnt: TextLabel,
		a: number,
		r: number,
		hop: number,
		ph: number,
		spd: number,
	}
	local envs: { Env } = {}
	for i = 1, 7 do
		local att, gui, cv = canvas(c, V2(0.95, 0.7))
		local body = cframe(cv, paper, 0.5, 0.5, 1, 0.72)
		stroke(body, c.c2, 2)
		round(body, 0.08)
		-- the flap: two dark strokes forming a V
		cframe(body, c.c2, 0.28, 0.27, 0.6, 0.07, 32)
		cframe(body, c.c2, 0.72, 0.27, 0.6, 0.07, -32)
		cframe(body, c.c2:Lerp(paper, 0.5), 0.5, 0.74, 0.7, 0.05)
		local badge = cframe(cv, Color3.fromRGB(255, 60, 70), 0.9, 0.12, 0.36, 0.36 * 0.95 / 0.7)
		round(badge)
		local cnt = Core.label(badge, "1", WHITE, F.tech, UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.8, 0.8))
		envs[i] = {
			att = att,
			gui = gui,
			body = body,
			badge = badge,
			cnt = cnt,
			a = (i - 1) / 7 * TAU,
			r = 2.1 + (i % 3) * 0.3,
			hop = 0.7 + (i % 2) * 0.35,
			ph = rng:NextNumber(),
			spd = 0.85 + rng:NextNumber() * 0.35,
		}
	end
	-- inbox tray on the floor: a ring of slots that light as mail "lands"
	local slots = B.ring(c, {
		n = 12,
		radius = 2.6,
		seg = V(0.42, 0.06, 0.3),
		color = paper,
		color2 = c.c2,
		spin = 0.2,
		anchor = function()
			return CF(0, g + 0.04, 0)
		end,
	})
	B.circle(c, { radius = 3, color = c.c1, width = 0.09, at = CF(0, g + 0.04, 0), tr = 0.45, n = 8 })
	local _, unread = B.glyph(c, "999+", c.c1, V2(1.6, 0.42), F.pixel, CF(0, c.topY + 0.9, 0), c.c2)
	local landA = Core.att(c, c.root, CF(0, g + 0.1, 0))
	local puff = Core.emit(landA, {
		tex = T.square,
		color = cs(paper, c.c1),
		size = ns(0.14, 0),
		rate = 0,
		life = nr(0.4, 0.7),
		speed = nr(1.5, 2.6),
		spread = V2(80, 80),
		accel = V(0, -4, 0),
		rot = nr(0, 90),
	})
	Core.emit(Core.volume(c, V(4.6, 0.1, 4.6), CF(0, g + 0.1, 0)), {
		tex = T.square,
		color = cs(paper, c.c1),
		size = ns(0.12, 0.1, 0),
		transp = ns(0.3, 0.6, 1),
		rate = 4,
		life = nr(1.6, 2.4),
		speed = nr(0.4, 0.8),
		rotSpeed = nr(-120, 120),
		shape = BOX,
	})
	bodyGlow(c, c.c1, 5, 0.92)
	local light = rootLight(c, c.c1, 1, 9, g + 1.2)
	local count = 999
	local nextC = 0
	local flash: { number } = table.create(12, 0)
	Core.on(c, function(t, dt)
		for i, e in envs do
			local u = t * e.spd + e.ph
			local hopPh = u % 1
			-- each hop lands on the floor ring, then bounces to the next spot
			if hopPh < (e.spd * 0.02) and u - hopPh > 0 then
				local k = (math.floor(e.a / TAU * 12 + 0.5) % 12) + 1
				flash[k] = t
			end
			e.a += dt * 0.15 * (1 + i % 2)
			local yy = g + 0.55 + math.sin(hopPh * math.pi) * e.hop * 1.6 + (i % 3) * 0.55
			e.att.Position = V(math.cos(e.a) * e.r, yy, math.sin(e.a) * e.r)
			-- squash on landing, stretch in the air
			local sq = 1 - math.max(0, 0.12 - hopPh) * 2.5 + math.sin(hopPh * math.pi) * 0.08
			e.gui.Size = UDim2.new(0.95 / sq, 0, 0.7 * sq, 0)
			e.body.Rotation = math.sin(u * TAU) * 9
			e.badge.Visible = math.floor(u) % 3 ~= 0
		end
		for k, p in slots do
			local f = math.clamp(1 - (t - flash[k]) * 2.5, 0, 1)
			p.Transparency = 0.55 - f * 0.55
		end
		if t >= nextC then
			nextC = t + 0.6 + rng:NextNumber() * 0.9
			count += rng:NextInteger(1, 3)
			unread.Text = if count > 999 then "999+" else tostring(count)
			puff:Emit(5)
			local e = envs[rng:NextInteger(1, #envs)]
			e.cnt.Text = tostring(rng:NextInteger(1, 9))
		end
		light.Brightness = 0.9 + Core.pulse(t, 2.2) * 0.5
	end)
end

-- white arrow cursors circling and clicking with tiny ripples
-- 26 parts / 2 emitters
A.Cursor = function(c: Ctx)
	-- Synced to the Blender animation (tools/blender/anim/auras/Cursor.py, idle 4.8 s): the
	-- right arm is the pointer. The clicks come from the body, not from a timer:
	--   click      the hand taps        -> ripple ring + spark puff at the fingertip, the nearest
	--                                     orbiting cursor presses in, light blip
	--   click "2"  the double click     -> bigger ripple/sparks, the floor selection handles flash
	--   warp       "No, here" head snap  -> every orbiting cursor teleports a step around the body,
	--                                     tooltip "No, here."
	--   step       (free) each footfall  -> a small flat ripple under that foot
	-- Idle orbit cursors still click on their own now and then; each such click emits "poke",
	-- which makes the head glance over the shoulder (the body's "glance" clip).
	local rng = c.rng
	local g = c.groundY
	local dark = c.c2
	type Cur = {
		fill: Tri,
		edge: Tri,
		stem: BasePart,
		stemE: BasePart,
		a: number,
		y: number,
		r: number,
		nextClick: number,
		click: number,
		warpFrom: number,
	}
	local curs: { Cur } = {}
	local S = 0.62
	for i = 1, 4 do
		curs[i] = {
			edge = triangle(c, S * 1.02, S * 1.2, 0.04, dark, SMOOTH),
			fill = triangle(c, S * 0.78, S * 0.98, 0.06, WHITE, NEON),
			stem = Core.part(c, V(0.06, S * 0.55, S * 0.16), WHITE),
			stemE = Core.part(c, V(0.04, S * 0.66, S * 0.3), dark, SMOOTH),
			a = (i - 1) / 4 * TAU,
			y = c.chestY - 0.4 + (i % 2) * 1.1,
			r = 2.3 + (i % 2) * 0.35,
			nextClick = os.clock() + 2 + i * 1.3,
			click = -10,
			warpFrom = 0,
		}
	end
	-- click ripples (beam circles), reused round-robin: hand clicks face the camera,
	-- footfall ripples lie flat on the floor
	type Rip = { circ: B.Circle, t0: number, at: CFrame, size: number }
	local rips: { Rip } = {}
	for k = 1, 5 do
		local rip: Rip = { circ = nil :: any, t0 = -10, at = CF(0, -50, 0), size = 1 }
		rip.circ = B.circle(c, {
			radius = 0.2,
			color = c.c1,
			width = 0.06,
			n = 6,
			anchor = function()
				return rip.at
			end,
			radiusFn = function(t)
				return (0.15 + math.min(1, (t - rip.t0) / 0.45) * 0.75) * rip.size
			end,
		})
		rips[k] = rip
	end
	local ripN = 0
	local lastRoot = c.root.CFrame
	local function ripple(at: CFrame, size: number)
		ripN = ripN % #rips + 1
		local rip = rips[ripN]
		rip.t0 = os.clock()
		rip.at = at
		rip.size = size
	end
	local function camRipple(wp: Vector3, size: number)
		ripple(lastRoot:ToObjectSpace(CFrame.lookAt(wp, camPos()) * ANG(math.pi / 2, 0, 0)), size)
	end
	-- marching-ants drag-selection box on the floor
	local corners: { Attachment } = {}
	for k = 1, 4 do
		corners[k] = Core.att(c)
	end
	local ants: { Beam } = {}
	for k = 1, 4 do
		ants[k] = Core.beam(c, corners[k], corners[k % 4 + 1], c.c1, 0.09, {
			tex = T.square,
			texLen = 0.45,
			texSpeed = 0.8,
			segs = 1,
		})
	end
	local handles: { BasePart } = {}
	for k = 1, 4 do
		handles[k] = Core.part(c, V(0.22, 0.06, 0.22), WHITE)
	end
	local _, tip, tipGui = B.glyph(c, "", dark, V2(1.9, 0.38), F.mono, CF(0, c.topY + 0.85, 0))
	tip.BackgroundColor3 = Color3.fromRGB(255, 255, 225)
	tip.BackgroundTransparency = 0.05
	tip.TextStrokeTransparency = 1
	stroke(tip, dark, 1.5)
	tipGui.Enabled = false
	local tipUntil = 0
	local tips = { "Click here", "Select all", "Drag me", "Double-click", "Right-click?" }
	local ca = Core.att(c, c.root, CF(0, c.chestY, 0))
	local spark: Core.EmitSpec = {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0.2, 0),
		rate = 0,
		life = nr(0.3, 0.5),
		speed = nr(1, 2),
		spread = V2(180, 180),
	}
	local sparks = Core.emit(ca, spark)
	-- the fingertip of the pointing arm: clicks spark right there
	local handTip = Core.tip(c, "rhand", CF(0, -0.15, 0))
	local handFx = if handTip then Core.emit(handTip, spark) else nil
	local feet = { R = Core.tip(c, "rfoot"), L = Core.tip(c, "lfoot") }
	bodyGlow(c, WHITE, 5, 0.93)
	local light = rootLight(c, WHITE, 0.9, 9, g + 1.4)
	local blip, handleFlash, warpT = -10, -10, -10
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("click", function(arg)
		local t = os.clock()
		local dbl = arg == "2"
		blip = t
		local wp = if handTip then handTip.WorldPosition else lastRoot.Position
		camRipple(wp, if dbl then 1.6 else 1)
		if handFx then
			handFx:Emit(if dbl then 14 else 6)
		end
		if dbl then
			handleFlash = t
		end
		-- the orbiting cursor nearest to the hand answers with its own press
		local lp = lastRoot:PointToObjectSpace(wp)
		local ha = math.atan2(lp.Z, lp.X)
		local best, bd = curs[1], math.huge
		for _, cu in curs do
			local d = math.abs(math.atan2(math.sin(cu.a - ha), math.cos(cu.a - ha)))
			if d < bd then
				best, bd = cu, d
			end
		end
		best.click = t
		best.nextClick = math.max(best.nextClick, t + 1.5)
	end)
	onEv("warp", function()
		local t = os.clock()
		warpT = t
		for _, cu in curs do
			cu.warpFrom = cu.a
			cu.a += (if rng:NextNumber() < 0.5 then 1 else -1) * (0.7 + rng:NextNumber() * 0.5)
		end
		tip.Text = "No, here."
		tipUntil = t + 1.3
		sparks:Emit(8)
	end)
	onEv("step", function(side)
		local ft = feet[side :: string]
		if not ft then
			return
		end
		local p = lastRoot:PointToObjectSpace(ft.WorldPosition)
		ripple(CF(p.X, g + 0.06, p.Z), 0.8)
	end)
	Core.on(c, function(t, _, root)
		lastRoot = root
		local cam = camPos()
		local moving = Sync.get(c.bus, "move") > 0.3
		for _, cu in curs do
			cu.a += 0.006
			local press = math.clamp(1 - (t - cu.click) / 0.18, 0, 1)
			if t >= cu.nextClick then
				-- a cursor clicks on its own (fewer than before: the body does most clicking)
				cu.nextClick = t + 2.6 + rng:NextNumber() * 2.4
				cu.click = t
				local lp = V(math.cos(cu.a) * (cu.r - 0.3), cu.y, math.sin(cu.a) * (cu.r - 0.3))
				camRipple(root:PointToWorldSpace(lp), 1)
				ca.Position = lp
				sparks:Emit(3)
				if not moving and Sync.since(c.bus, "click") > 0.8 then
					Sync.emit(c.bus, "poke")
				end
			end
			local r = cu.r - press * 0.3
			-- warp: the cursor flickers at its old spot for two frames, then is just elsewhere
			local wf = t - warpT
			local a = if wf < 0.07 then cu.warpFrom else cu.a
			local pos = root:PointToWorldSpace(
				V(math.cos(a) * r, cu.y + math.sin(t * 1.7 + cu.a) * 0.15, math.sin(a) * r)
			)
			local base = (if (cam - pos).Magnitude > 0.1 then CFrame.lookAt(pos, cam) else CF(pos)) * FACE_X
			-- classic pointer: tip up-left, tilted ~25 deg
			local cf = base * ANG(-0.42, 0, 0) * CF(0, -S * 0.5 - press * 0.08, 0)
			putTri(cu.edge, cf * CF(-0.03, -S * 0.1, 0))
			putTri(cu.fill, cf * CF(0, 0, 0))
			Core.put(cu.stem, cf * CF(0.01, -S * 0.2, 0))
			Core.put(cu.stemE, cf * CF(-0.02, -S * 0.22, 0))
			local hide = wf >= 0.07 and wf < 0.1
			cu.fill.a.Transparency = if hide then 1 else 0
			cu.fill.b.Transparency = cu.fill.a.Transparency
		end
		for _, rip in rips do
			local f = (t - rip.t0) / 0.45
			B.setBeamsTransparency(rip.circ.beams, if f > 1 then 1 else 0.1 + f * 0.9)
		end
		local hb = 2.2 + math.sin(t * 0.9) * 0.15
		local rot = t * 0.12
		local hf = math.clamp(1 - (t - handleFlash) / 0.5, 0, 1)
		for k, a in corners do
			local ang = rot + (k - 1) * math.pi / 2 + math.pi / 4
			local p = V(math.cos(ang) * hb * math.sqrt(2), g + 0.05, math.sin(ang) * hb * math.sqrt(2))
			a.Position = p
			local hs = 0.22 + hf * 0.18
			handles[k].Size = V(hs, 0.06 + hf * 0.06, hs)
			handles[k].Color = WHITE:Lerp(c.c1, hf)
			Core.put(handles[k], root * CF(p) * ANG(0, -ang, 0))
		end
		if t >= tipUntil + 3 and rng:NextNumber() < 0.01 then
			tipUntil = t + 1.4
			tip.Text = Core.pick(tips, rng)
		end
		tipGui.Enabled = t < tipUntil
		local bl = math.clamp(1 - (t - blip) / 0.25, 0, 1)
		light.Brightness = 0.8 + Core.pulse(t, 2.6) * 0.5 + bl * 1.2 + hf * 0.8
	end)
end

-- spinning loading-circle segments around the waist and a progress bar above head
-- 30 parts / 3 emitters
A.Loading = function(c: Ctx)
	-- Synced to the Blender animation (tools/blender/anim/auras/Loading.py, idle 4.0 s = one
	-- full load of the bar). While standing, the bar follows the shared idle phase, so the body
	-- and the loader always agree:
	--   tap   (f12/20/28/36) foot strikes -> the spinner ticks, squares puff at the LEFT FOOT,
	--                                        the bar jumps a chunk
	--   stall (f56) freeze-frame          -> bar stuck at 99 %, "ALMOST...", the spinner races
	--   done  (f86) fist pump             -> "DONE!", burst above the head + sparks from the
	--                                        RIGHT HAND, the spinner flashes white and stops
	--   reset (f100) slump                -> bar back to 0 %, new label
	--   lag   (walk) buffering stutter    -> the walking loader hiccups; step -> foot squares
	-- Without idle markers (walking, airborne, no clip) the old random loader takes over.
	local rng = c.rng
	local g = c.groundY
	local bus = c.bus
	local IDLE_F = 120 -- frames of the idle clip (4.0 s @ 30 fps)
	local y = -0.2
	local N = 12
	local spinHead = 0 -- leading segment (advanced in the updater, ticks on "tap")
	local spinFlash = 0 -- 0..1 white flash of the whole spinner on "done"
	B.ring(c, {
		n = N,
		radius = 2.4,
		seg = V(0.22, 0.42, 0.42),
		color = c.c1,
		anchor = function()
			return CF(0, y, 0)
		end,
		paint = function(k, _, p)
			local d = (spinHead % N - (k - 1)) % N
			p.Transparency = math.min(0.92, d / N * 1.1) * (1 - spinFlash)
			p.Size = V(0.22, 0.42 - d * 0.018 * (1 - spinFlash), 0.42)
			p.Color = c.c1:Lerp(WHITE, spinFlash)
		end,
	})
	B.circle(c, { radius = 2.4, color = c.c2, width = 0.05, at = CF(0, y, 0), tr = 0.3, n = 8 })
	-- floor: dotted ring turning the other way
	B.ring(c, {
		n = 16,
		radius = 2.9,
		seg = V(0.16, 0.05, 0.16),
		color = c.c1,
		color2 = c.c2,
		spin = -0.6,
		anchor = function()
			return CF(0, g + 0.04, 0)
		end,
	})
	-- progress bar over the head (frame + fill), turned to the camera
	local BW, BH = 2.2, 0.26
	local frame = {
		Core.part(c, V(BW + 0.08, 0.04, 0.04), c.c1),
		Core.part(c, V(BW + 0.08, 0.04, 0.04), c.c1),
		Core.part(c, V(0.04, BH, 0.04), c.c1),
		Core.part(c, V(0.04, BH, 0.04), c.c1),
	}
	local back = Core.part(c, V(BW, BH, 0.02), c.c2, SMOOTH, 0.35)
	local fill = Core.part(c, V(BW, BH - 0.08, 0.05), c.c1)
	local shine = Core.part(c, V(0.12, BH - 0.08, 0.06), WHITE, NEON, 0.2)
	local _, pct = B.glyph(c, "0%", c.c1, V2(1.6, 0.36), F.pixel, CF(0, c.topY + 1.35, 0), c.c2)
	local fa = Core.att(c, c.root, CF(0, c.topY + 0.8, 0))
	local done = Core.emit(fa, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0.3, 0),
		rate = 0,
		life = nr(0.5, 0.9),
		speed = nr(2, 4),
		spread = V2(180, 180),
		drag = 2,
	})
	local ra = Core.att(c, c.root, CF(0, y, 0))
	local shed = Core.emit(ra, {
		tex = T.square,
		color = cs(c.c1, WHITE),
		size = ns(0.12, 0),
		rate = 5,
		life = nr(0.5, 0.9),
		speed = nr(1.5, 2.5),
		spread = V2(180, 0),
		dir = Enum.NormalId.Front,
		rot = nr(0, 0),
	})
	-- body-driven emitters: the fist-pump hand and both feet
	local handTip = Core.tip(c, "rhand")
	local handFx = handTip
		and Core.emit(handTip, {
			tex = T.spark,
			color = cs(WHITE, c.c1),
			size = ns(0.24, 0),
			rate = 0,
			life = nr(0.3, 0.6),
			speed = nr(2.5, 5),
			spread = V2(40, 40),
			dir = Enum.NormalId.Bottom,
			drag = 3,
			bright = 2,
		})
	local footFx: { [string]: ParticleEmitter } = {}
	local feetTips: { [string]: string } = { R = "rfoot", L = "lfoot" }
	for side, which in feetTips do
		local tip = Core.tip(c, which)
		if tip then
			footFx[side] = Core.emit(tip, {
				tex = T.square,
				color = cs(c.c1, WHITE),
				size = ns(0.13, 0),
				rate = 0,
				life = nr(0.3, 0.6),
				speed = nr(1.2, 2.4),
				spread = V2(85, 85),
				dir = Enum.NormalId.Top,
				rot = nr(0, 0),
				drag = 2,
			})
		end
	end
	bodyGlow(c, c.c1, 5.5, 0.9)
	local light = rootLight(c, c.c1, 1.1, 10, y)
	local prog = 0
	local stall = 0
	local hold = 0
	local labels = { "LOADING", "BUFFERING", "PLEASE WAIT", "ALMOST..." }
	local lab = labels[1]
	-- idle bar curve: (frames since "reset" f100, progress). Creeps, then jumps on every foot tap
	-- (taps at f12/20/28/36 = 32/40/48/56 frames after the reset), stalls at 99 % on f56.
	local CURVE = {
		{ 0, 0 },
		{ 10, 0.22 },
		{ 32, 0.36 },
		{ 33, 0.5 },
		{ 40, 0.56 },
		{ 41, 0.67 },
		{ 48, 0.72 },
		{ 49, 0.83 },
		{ 56, 0.87 },
		{ 57, 0.95 },
		{ 76, 0.99 },
	}
	local function curve(s: number): number
		for i = 2, #CURVE do
			local a, b = CURVE[i - 1], CURVE[i]
			if s <= b[1] then
				return a[2] + (b[2] - a[2]) * (s - a[1]) / (b[1] - a[1])
			end
		end
		return 0.99
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, name, fn))
	end
	onEv("tap", function()
		spinHead += 1
		local fx = footFx.L
		if fx then
			fx:Emit(7)
		end
	end)
	onEv("done", function()
		done:Emit(22)
		if handFx then
			handFx:Emit(16)
		end
	end)
	onEv("reset", function()
		lab = labels[rng:NextInteger(1, 3)]
		shed:Emit(10)
	end)
	onEv("lag", function()
		stall = os.clock() + 0.28
	end)
	onEv("step", function(side)
		if Sync.get(bus, "move") < 0.4 then
			return
		end
		local fx = footFx[side :: string]
		if fx then
			fx:Emit(5)
		end
	end)
	Core.on(c, function(t, dt, root)
		local lastMark = math.min(
			Sync.since(bus, "tap"),
			Sync.since(bus, "stall"),
			Sync.since(bus, "done"),
			Sync.since(bus, "reset")
		)
		local synced = lastMark < 1.6 and Sync.get(bus, "move") < 0.4
		local spinSpeed = 9
		local isDone = false
		local label = lab
		if synced then
			-- the body's loop drives the bar
			local u = Sync.phase(bus, IDLE_F / 30) * IDLE_F
			hold = 0
			if u >= 86 and u < 100 then
				prog, isDone = 1, true
				spinSpeed = 0
			elseif u >= 56 and u < 86 then
				prog = 0.99
				label = "ALMOST..."
				spinSpeed = 22
			else
				prog = curve((u - 100) % IDLE_F)
			end
		else
			-- free-running loader: fast start, stalls at 99 %, then completes and restarts
			if hold > 0 then
				hold -= dt
				isDone = true
				spinSpeed = 0
				if hold <= 0 then
					prog = 0
					isDone = false
					lab = Core.pick(labels, rng)
				end
			elseif prog < 0.99 then
				local sp = if prog < 0.6 then 0.35 else 0.12
				if t < stall then
					sp = 0
					spinSpeed = 18
				elseif rng:NextNumber() < 0.01 then
					stall = t + 0.4 + rng:NextNumber() * 0.8
				end
				prog = math.min(0.99, prog + dt * sp * (0.5 + rng:NextNumber()))
			elseif rng:NextNumber() < 0.012 then
				prog = 1
				hold = 1.1
				isDone = true
				done:Emit(18)
			end
		end
		spinHead += dt * spinSpeed
		local doneE = Sync.env(bus, "done", 2.2)
		spinFlash = if isDone then math.max(0.35, doneE) else 0
		local pos = root:PointToWorldSpace(V(0, c.topY + 0.85 + math.sin(t * 1.4) * 0.06, 0))
		local base = faceCam(pos)
		Core.put(frame[1], base * CF(0, BH / 2 + 0.02, 0))
		Core.put(frame[2], base * CF(0, -BH / 2 - 0.02, 0))
		Core.put(frame[3], base * CF(BW / 2 + 0.02, 0, 0))
		Core.put(frame[4], base * CF(-BW / 2 - 0.02, 0, 0))
		Core.put(back, base * CF(0, 0, 0.03))
		local w = math.max(0.02, BW * prog)
		fill.Size = V(w, BH - 0.08, 0.05)
		Core.put(fill, base * CF(-BW / 2 + w / 2, 0, -0.01))
		fill.Color = if isDone then WHITE else c.c1
		local sx = ((t * 0.8) % 1) * w
		Core.put(shine, base * CF(-BW / 2 + sx, 0, -0.03))
		shine.Transparency = if w > 0.2 then 0.25 else 1
		if isDone then
			pct.Text = "DONE!"
		elseif prog >= 0.99 and math.sin(t * 9) < -0.3 then
			pct.Text = label -- the stuck 99 % blinks
		else
			pct.Text = string.format("%s %d%%", label, math.floor(prog * 100))
		end
		shed.Rate = if isDone then 0 else 5
		local tapE = Sync.env(bus, "tap", 10)
		light.Brightness = if isDone
			then 1.6 + doneE * 1.6
			else 0.9 + Core.pulse(t, 1.3) * 0.4 + tapE * 0.5 - (if prog >= 0.99 then 0.3 else 0)
	end)
end

-- wifi signal arcs pulsing outward from the head
-- 13 parts / 3 emitters
A.WiFi = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local hy = c.topY + 0.55
	local dot = Core.part(c, V(0.22, 0.22, 0.22), c.c1, NEON, 0, BALL)
	local arcs: { Arc } = {}
	for k = 1, 3 do
		arcs[k] = arc(c, 3, c.c1, 0.12 + k * 0.015, c.c1:Lerp(WHITE, 0.3))
	end
	-- horizontal broadcast rings leaving the head
	local waves: { B.Circle } = {}
	for k = 1, 2 do
		waves[k] = B.circle(c, {
			radius = 0.5,
			color = c.c1,
			width = 0.08,
			n = 8,
			anchor = function()
				return CF(0, c.headY + 0.1, 0)
			end,
			radiusFn = function(t)
				return 0.6 + (((t + k * 0.9) / 1.8) % 1) * 3
			end,
		})
	end
	-- signal-strength bars around the feet
	local bars: { BasePart } = {}
	for i = 1, 8 do
		bars[i] = Core.part(c, V(0.22, 0.4, 0.22), c.c1)
	end
	B.circle(c, { radius = 2.7, color = c.c2, width = 0.09, at = CF(0, g + 0.04, 0), tr = 0.35, n = 8 })
	local _, ssid = B.glyph(c, "", c.c1, V2(1.6, 0.34), F.mono, CF(0, hy + 1.15, 0), c.c2)
	local ha = Core.att(c, c.head)
	Core.emit(ha, {
		tex = T.spark,
		color = cs(c.c1, WHITE),
		size = ns(0, 0.22, 0),
		rate = 4,
		life = nr(0.8, 1.3),
		speed = nr(0.6, 1.2),
		spread = V2(70, 70),
	})
	Core.emit(Core.volume(c, V(4.4, 0.1, 4.4), CF(0, g + 0.1, 0)), {
		tex = T.glow,
		color = cs(c.c1),
		size = ns(0.2, 0.4),
		transp = ns(0.5, 1),
		rate = 5,
		life = nr(1, 1.6),
		speed = nr(0.5, 1),
		shape = BOX,
	})
	bodyGlow(c, c.c1, 5.5, 0.9)
	local light = rootLight(c, c.c1, 1, 10, c.headY)
	local weakUntil = 0
	local names = { "FREE_WIFI", "NET-5G", "linksys", "PRETTY FLY", "HIDDEN_NET" }
	local nextName = 0
	Core.on(c, function(t, _, root)
		local pos = root:PointToWorldSpace(V(0, hy + math.sin(t * 1.6) * 0.06, 0))
		local base = root:ToObjectSpace(faceCam(pos))
		if t >= weakUntil + 4 and rng:NextNumber() < 0.006 then
			weakUntil = t + 1.4
		end
		local weak = t < weakUntil
		-- bars fill 0..3 in sequence (or drop to one, flickering)
		local lvl = if weak then (if math.sin(t * 25) > 0 then 1 else 0) else math.floor((t * 2.2) % 4.6)
		Core.put(dot, root * base * CF(0, -0.08, 0))
		for k, a in arcs do
			placeArc(a, base * CF(0, -0.08, 0), 0.32 + k * 0.3, math.pi * 0.25, math.pi * 0.75)
			B.setBeamsTransparency(a.beams, if k <= lvl then 0.05 else 0.85)
		end
		for k, w in waves do
			B.setBeamsTransparency(w.beams, 0.2 + (((t + k * 0.9) / 1.8) % 1) * 0.8)
		end
		for i, b in bars do
			local a = (i - 1) / 8 * TAU + t * 0.3
			local h = 0.2 + ((i - 1) % 4 + 1) * 0.22 * (if weak then 0.3 else 0.75 + 0.25 * math.sin(t * 3 + i))
			b.Size = V(0.2, h, 0.2)
			Core.put(b, root * CF(math.cos(a) * 2.7, g + h / 2, math.sin(a) * 2.7) * ANG(0, -a, 0))
			b.Transparency = if weak and i % 4 > 1 then 0.8 else 0.15
		end
		if t >= nextName then
			nextName = t + 3.5
			ssid.Text = Core.pick(names, rng)
		end
		ssid.TextColor3 = if weak then Color3.fromRGB(255, 90, 90) else c.c1
		light.Brightness = (if weak then 0.4 else 0.9) + lvl * 0.2
	end)
end

-- 3x3 grid tiles orbiting, a checkmark popping in and out
-- 23 parts / 3 emitters
A.Captcha = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local blue = c.c1
	local y = c.chestY - 0.1
	local R = 2.5
	type Tile = { p: BasePart, edge: BasePart, sel: boolean, flip: number }
	local tiles: { Tile } = {}
	for i = 1, 9 do
		tiles[i] = {
			p = Core.part(c, V(0.62, 0.62, 0.05), blue:Lerp(BLACK, 0.4), SMOOTH, 0.15),
			edge = Core.part(c, V(0.7, 0.7, 0.03), WHITE, NEON, 0.6),
			sel = false,
			flip = -10,
		}
	end
	-- floor 3x3 grid under the feet
	local floor: { BasePart } = {}
	for i = 1, 9 do
		floor[i] = Core.part(c, V(0.9, 0.05, 0.9), blue, NEON, 0.7)
	end
	local check = {
		Core.part(c, V(0.14, 0.45, 0.08), WHITE),
		Core.part(c, V(0.14, 0.9, 0.08), WHITE),
	}
	local checkBack = Core.part(c, V(0.05, 1.15, 1.15), blue, NEON, 0.35, CYL)
	local _, robot = B.glyph(c, "I'M NOT A ROBOT", WHITE, V2(2.6, 0.32), F.mono, CF(0, c.topY + 1.75, 0), blue)
	B.circle(c, { radius = 3, color = blue, width = 0.1, at = CF(0, g + 0.04, 0), tr = 0.35, n = 8 })
	local ca = Core.att(c, c.root, CF(0, c.topY + 0.95, 0))
	local pop = Core.emit(ca, {
		tex = T.spark,
		color = cs(WHITE, blue),
		size = ns(0.3, 0),
		rate = 0,
		life = nr(0.4, 0.8),
		speed = nr(2, 3.5),
		spread = V2(180, 180),
		drag = 3,
	})
	Core.emit(Core.volume(c, V(4.4, 0.1, 4.4), CF(0, g + 0.1, 0)), {
		tex = T.square,
		color = cs(blue, WHITE),
		size = ns(0.14, 0),
		transp = ns(0.2, 1),
		rate = 5,
		life = nr(1.2, 1.8),
		speed = nr(0.6, 1.1),
		rot = nr(0, 0),
		shape = BOX,
	})
	bodyGlow(c, blue, 5.5, 0.9)
	local light = rootLight(c, blue, 1.1, 10, g + 1.4)
	-- Synced to the Blender animation (tools/blender/anim/auras/Captcha.py, idle 5.0 s = one round):
	--   select  each finger jab       -> the next tile flips + lights, sparks from the fingertip,
	--                                    its floor tile flashes
	--   verify  the VERIFY push       -> checkmark pops + spark burst + light surge; 1 in 5 the
	--                                    answer is rejected: tiles flash red, "TRY AGAIN", and the
	--                                    bus gets "denied" (the body's head-shake clip)
	--   beep    robot head snaps      -> the label glitches to BEEP / BOOP / 0101, binary sparks
	--                                    burst from the head
	--   step    (free) walking        -> every footfall selects a tile, after four the next verifies
	-- If nothing drives it for a while (airborne, no clip) the old 0.6 s timer takes over.
	local handTip = Core.tip(c, "rhand", CF(0, -0.15, 0))
	local headTip = Core.tip(c, "head")
	local handFx = handTip
		and Core.emit(handTip, {
			tex = T.square,
			color = cs(WHITE, blue),
			size = ns(0.14, 0),
			rate = 0,
			life = nr(0.25, 0.45),
			speed = nr(2, 4),
			drag = 3,
			spread = V2(60, 60),
			rot = nr(0, 0),
			bright = 2,
		})
	local headFx = headTip
		and Core.emit(headTip, {
			tex = T.square,
			color = cs(Color3.fromRGB(120, 255, 160), WHITE),
			size = ns(0.16, 0.05),
			rate = 0,
			life = nr(0.3, 0.6),
			speed = nr(2.5, 4.5),
			drag = 2,
			spread = V2(180, 180),
			rot = nr(0, 0),
			bright = 2,
		})
	local order = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
	local selN = 0
	local verifyT, failed, pendingReset = -10, false, false
	local VERIFY = 1.5
	local lastDrive = os.clock()
	local beepT, beepK = -10, 0
	local beeps = { "BEEP.", "BOOP.", "0101", "NOT A ROBOT" }
	local function reset()
		for i = 9, 2, -1 do
			local j = rng:NextInteger(1, i)
			order[i], order[j] = order[j], order[i]
		end
		for _, tl in tiles do
			tl.sel = false
		end
		selN = 0
	end
	reset()
	local function selectNext()
		local t = os.clock()
		lastDrive = t
		if t - verifyT < VERIFY then
			return
		end
		if selN >= 4 then
			reset()
		end
		selN += 1
		local tl = tiles[order[selN]]
		tl.sel = true
		tl.flip = t
		if handFx then
			handFx:Emit(8)
		end
	end
	local function verify()
		local t = os.clock()
		lastDrive = t
		verifyT = t
		pendingReset = true
		failed = rng:NextNumber() < 0.2
		if failed then
			pop:Emit(6)
			Sync.emit(c.bus, "denied")
		else
			pop:Emit(18)
		end
		if handFx then
			handFx:Emit(14)
		end
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("select", selectNext)
	onEv("verify", verify)
	onEv("beep", function()
		beepT = os.clock()
		beepK = beepK % #beeps + 1
		if headFx then
			headFx:Emit(10)
		end
	end)
	onEv("step", function()
		if selN >= 4 and os.clock() - verifyT > VERIFY then
			verify()
		else
			selectNext()
		end
	end)
	local RED = Color3.fromRGB(255, 80, 90)
	Core.on(c, function(t, _, root)
		-- fallback driver: nobody pokes the grid (airborne / no clip) -> select on a timer
		if t - lastDrive > 3.5 then
			if selN >= 4 then
				verify()
			else
				selectNext()
			end
			lastDrive = t - 2.9 -- next fallback tick in 0.6 s
		end
		local vt = t - verifyT
		local verified = vt < VERIFY and not failed
		local denied = vt < VERIFY and failed
		if pendingReset and vt >= VERIFY then
			pendingReset = false
			reset()
		end
		-- the 3x3 panel orbits the body, tilting gently; tiles breathe apart a little
		local panel = root * outward(t * 0.45, R, y + math.sin(t * 0.9) * 0.15) * ANG(math.sin(t * 0.7) * 0.12, 0, 0)
		local gap = 0.72 + 0.04 * math.sin(t * 2) + (if denied then 0.05 * math.sin(t * 60) else 0)
		for i, tl in tiles do
			local col = (i - 1) % 3
			local row = math.floor((i - 1) / 3)
			local fl = math.clamp((t - tl.flip) / 0.3, 0, 1)
			local cf = panel * CF((col - 1) * gap, (1 - row) * gap, 0) * ANG(fl * math.pi, 0, 0)
			Core.put(tl.p, cf)
			Core.put(tl.edge, cf * CF(0, 0, 0.03))
			tl.p.Color = if denied and tl.sel then RED elseif tl.sel then blue else blue:Lerp(BLACK, 0.55)
			tl.edge.Transparency = if tl.sel then (if verified then 0 else 0.15) else 0.75
			-- floor grid mirrors the selection (fresh picks flash bright)
			local fx, fz = (col - 1) * 0.95, (row - 1) * 0.95
			Core.put(floor[i], root * CF(fx, g + 0.03, fz))
			local fresh = math.clamp(1 - (t - tl.flip) / 0.35, 0, 1)
			floor[i].Transparency = if tl.sel then 0.2 - fresh * 0.2 else 0.78
			floor[i].Color = if denied and tl.sel then RED
				elseif (verified and tl.sel) or fresh > 0 then WHITE
				else blue
		end
		-- check mark pops in with an overshoot, then shrinks away
		local cs_ = if verified then popIn(vt / 0.35) * (1 - smooth01((vt - 1.2) / 0.3)) else 0
		local pos = root:PointToWorldSpace(V(0, c.topY + 0.95, 0))
		local base = faceCam(pos)
		local s = math.max(0.01, cs_)
		check[1].Size = V(0.14 * s, 0.45 * s, 0.08)
		check[2].Size = V(0.14 * s, 0.9 * s, 0.08)
		Core.put(check[1], base * CF(-0.2 * s, -0.08 * s, -0.05) * ANG(0, 0, math.rad(45)))
		Core.put(check[2], base * CF(0.13 * s, 0.08 * s, -0.05) * ANG(0, 0, math.rad(-35)))
		check[1].Transparency = if s > 0.05 then 0 else 1
		check[2].Transparency = check[1].Transparency
		checkBack.Size = V(0.05, 1.15 * s, 1.15 * s)
		Core.put(checkBack, base * FACE_X)
		checkBack.Transparency = if s > 0.05 then 0.35 else 1
		local beeping = t - beepT < 0.22
		robot.Text = if beeping then beeps[beepK]
			elseif verified then "VERIFIED"
			elseif denied then "TRY AGAIN"
			else "I'M NOT A ROBOT"
		robot.TextColor3 = if beeping then (if beepK % 2 == 0 then blue else Color3.fromRGB(120, 255, 160))
			elseif verified then Color3.fromRGB(120, 255, 160)
			elseif denied then RED
			else WHITE
		light.Color = if denied then RED else blue
		light.Brightness = (if verified then 2 elseif denied then 1.6 else 0.9)
			+ Core.pulse(t, 2) * 0.3
			+ math.clamp(1 - (t - lastDrive) / 0.2, 0, 1) * 0.5
	end)
end

-- small window popups appearing and closing around the player
-- 18 parts / 3 emitters / 6 windows
A.Popup = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local pink = c.c1
	local plum = c.c2
	type Win = {
		att: Attachment,
		gui: BillboardGui,
		title: TextLabel,
		msg: TextLabel,
		btn: Frame,
		t0: number,
		life: number,
	}
	local wins: { Win } = {}
	local msgs = {
		"YOU WON!",
		"CLAIM PRIZE",
		"1 NEW MSG",
		"UPDATE NOW",
		"ALLOW?",
		"ERROR 404",
		"ARE YOU SURE?",
		"FREE BITS!!",
		"CLICK OK",
	}
	local titles = { "alert.exe", "winner!!", "notice", "system", "prize.exe", "warning" }
	local function relocate(w: Win, t: number)
		w.t0 = t
		w.life = 1.6 + rng:NextNumber() * 1.6
		local a = rng:NextNumber() * TAU
		local r = 1.7 + rng:NextNumber() * 1.2
		w.att.Position =
			V(math.cos(a) * r, c.groundY + 1 + rng:NextNumber() * (c.topY - c.groundY + 0.6), math.sin(a) * r)
		w.msg.Text = Core.pick(msgs, rng)
		w.title.Text = Core.pick(titles, rng)
	end
	for i = 1, 6 do
		local att, gui, cv = canvas(c, V2(1.5, 1))
		local win = cframe(cv, Color3.fromRGB(245, 240, 250), 0.5, 0.5, 1, 1)
		stroke(win, plum, 2)
		local bar = Core.frame(win, pink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.26))
		local title = Core.label(
			bar,
			"alert",
			WHITE,
			F.mono,
			UDim2.fromScale(0.05, 0.12),
			UDim2.fromScale(0.7, 0.76),
			Enum.TextXAlignment.Left
		)
		local x = Core.frame(bar, Color3.fromRGB(255, 70, 90), UDim2.fromScale(0.82, 0.14), UDim2.fromScale(0.14, 0.72))
		Core.label(x, "x", WHITE, F.tech, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		local msg = Core.label(win, "", plum, F.tech, UDim2.fromScale(0.06, 0.34), UDim2.fromScale(0.88, 0.32))
		local btn = Core.frame(win, pink, UDim2.fromScale(0.32, 0.72), UDim2.fromScale(0.36, 0.2))
		round(btn, 0.3)
		Core.label(btn, "OK", WHITE, F.tech, UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.8, 0.8))
		local w: Win = { att = att, gui = gui, title = title, msg = msg, btn = btn, t0 = 0, life = 1 }
		relocate(w, os.clock() - i * 0.55)
		wins[i] = w
	end
	-- marquee "taskbar" ring on the floor
	local ring = B.ring(c, {
		n = 18,
		radius = 2.7,
		seg = V(0.3, 0.06, 0),
		color = pink,
		color2 = WHITE,
		spin = 0.15,
		anchor = function()
			return CF(0, g + 0.04, 0)
		end,
	})
	B.circle(c, { radius = 3.05, color = plum:Lerp(pink, 0.5), width = 0.08, at = CF(0, g + 0.04, 0), tr = 0.4, n = 8 })
	local burstA = Core.att(c, c.root, CF(0, c.chestY, 0))
	local confetti = Core.emit(burstA, {
		tex = T.square,
		color = cs(pink, WHITE, Color3.fromRGB(255, 220, 90)),
		size = ns(0.16, 0.1),
		transp = ns(0, 1),
		rate = 0,
		life = nr(0.7, 1.1),
		speed = nr(2, 4),
		spread = V2(180, 180),
		accel = V(0, -6, 0),
		rotSpeed = nr(-200, 200),
	})
	Core.emit(Core.volume(c, V(4.4, 0.1, 4.4), CF(0, g + 0.1, 0)), {
		tex = T.spark,
		color = cs(pink, WHITE),
		size = ns(0, 0.22, 0),
		rate = 4,
		life = nr(0.8, 1.3),
		speed = nr(0.8, 1.4),
		shape = BOX,
	})
	bodyGlow(c, pink, 5.5, 0.9)
	local light = rootLight(c, pink, 1, 10, g + 1.4)
	Core.on(c, function(t)
		local opened = 0
		for _, w in wins do
			local age = t - w.t0
			if age > w.life then
				burstA.Position = w.att.Position
				confetti:Emit(6)
				relocate(w, t)
				age = 0
			end
			-- open: pop in; close: collapse to the title bar, then vanish
			local sx, sy = 1, 1
			if age < 0.22 then
				sx = popIn(age / 0.22)
				sy = sx
			elseif age > w.life - 0.25 then
				local f = (age - (w.life - 0.25)) / 0.25
				sy = math.max(0.02, 1 - f * 1.4)
				sx = 1 - f * 0.4
			else
				opened += 1
			end
			w.gui.Size = UDim2.new(1.5 * sx, 0, 1 * sy, 0)
			w.btn.BackgroundColor3 = if (age % 0.5) < 0.25 then pink else plum
			w.att.Position += V(0, math.sin(t * 2 + w.t0) * 0.002, 0)
		end
		for k, p in ring do
			p.Transparency = if ((k + math.floor(t * 8)) % 3) == 0 then 0 else 0.6
		end
		light.Brightness = 0.7 + opened * 0.12 + Core.pulse(t, 1.6) * 0.3
	end)
end

-- yellow smiley faces floating up and fading
-- 12 parts / 3 emitters / 8 faces
A.Emoji = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local sun = c.c1
	local warm = c.c2
	local ink = Color3.fromRGB(70, 40, 10)
	local span = c.topY - g + 2
	type Face = {
		att: Attachment,
		gui: BillboardGui,
		face: Frame,
		mouth: TextLabel,
		eyes: { Frame },
		a: number,
		r: number,
		per: number,
		ph: number,
		spin: number,
		cyc: number,
	}
	local faces: { Face } = {}
	local mouths = { ")", "D", ")", "o", "3", "D" }
	local ready = false -- no "love" events while building
	local function mood(f: Face)
		local m = Core.pick(mouths, rng)
		f.mouth.Text = m
		f.mouth.Rotation = 90
		-- winking / heart-eyed variants
		local wink = rng:NextNumber() < 0.25
		f.eyes[2].Size = if wink then UDim2.fromScale(0.2, 0.05) else UDim2.fromScale(0.12, 0.2)
		local love = not wink and rng:NextNumber() < 0.2
		for _, e in f.eyes do
			e.BackgroundColor3 = if love then Color3.fromRGB(255, 60, 110) else ink
		end
		-- a heart-eyed face makes the body go "awww" (Emoji.py "aww" clip), at most every ~6 s
		if love and ready and Sync.since(c.bus, "love") > 6 then
			Sync.emit(c.bus, "love")
		end
	end
	local function makeFace(i: number, n: number): Face
		local att, gui, cv = canvas(c, V2(0.8, 0.8))
		local face = cframe(cv, sun, 0.5, 0.5, 1, 1)
		round(face)
		stroke(face, warm, 2)
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(sun:Lerp(WHITE, 0.25), sun:Lerp(warm, 0.35))
		grad.Rotation = 90
		grad.Parent = face
		local e1 = cframe(face, ink, 0.34, 0.37, 0.12, 0.2)
		local e2 = cframe(face, ink, 0.66, 0.37, 0.12, 0.2)
		round(e1)
		round(e2)
		local mouth = Core.label(face, ")", ink, F.tech, UDim2.fromScale(0.25, 0.42), UDim2.fromScale(0.5, 0.5))
		return {
			att = att,
			gui = gui,
			face = face,
			mouth = mouth,
			eyes = { e1, e2 },
			a = rng:NextNumber() * TAU,
			r = 1.6 + rng:NextNumber() * 1.2,
			per = 3.2 + rng:NextNumber() * 1.4,
			ph = i / n,
			spin = (rng:NextNumber() - 0.5) * 60,
			cyc = -1,
		}
	end
	local function fadeFace(f: Face, fade: number)
		f.face.BackgroundTransparency = fade
		f.mouth.TextTransparency = fade
		for _, e in f.eyes do
			e.BackgroundTransparency = fade
		end
		local st = f.face:FindFirstChildWhichIsA("UIStroke")
		if st then
			st.Transparency = fade
		end
	end
	for i = 1, 8 do
		faces[i] = makeFace(i, 8)
		mood(faces[i])
	end
	-- pop faces: launched OUT OF THE WAVING HAND (Blender "wave" markers)
	type Pop = { f: Face, t0: number, from: Vector3, drift: Vector3, live: boolean }
	local pops: { Pop } = {}
	for i = 1, 3 do
		local f = makeFace(i, 3)
		f.mouth.Text = "D"
		f.mouth.Rotation = 90
		fadeFace(f, 1)
		pops[i] = { f = f, t0 = 0, from = Vector3.zero, drift = Vector3.zero, live = false }
	end
	local popNext = 1
	-- warm bubbles orbiting the waist (tiny 3D presence)
	local bubbles = B.orbiters(c, {
		n = 6,
		radius = 2.3,
		y = -0.3,
		color = sun,
		color2 = warm,
		size = 0.26,
		speed = 0.9,
		bob = 0.25,
		trail = 0.14,
		life = 0.35,
	})
	local ringA = B.circle(c, { radius = 2.8, color = sun, width = 0.1, at = CF(0, g + 0.04, 0), tr = 0.35, n = 8 })
	local ringB = B.circle(c, { radius = 2.4, color = warm, width = 0.05, at = CF(0, g + 0.04, 0), tr = 0.55, n = 8 })
	local glow = Core.part(c, V(0.04, 5.2, 5.2), sun, NEON, 0.93, CYL)
	local floorSp = Core.emit(Core.volume(c, V(4, 0.1, 4), CF(0, g + 0.1, 0)), {
		tex = T.spark,
		color = cs(sun, WHITE),
		size = ns(0, 0.26, 0),
		rate = 6,
		life = nr(1.2, 1.8),
		speed = nr(0.8, 1.4),
		shape = BOX,
	})
	local ha = Core.att(c, c.head)
	local headGlow = Core.emit(ha, {
		tex = T.glow,
		color = cs(sun),
		size = ns(0.3, 0.5),
		transp = ns(0.4, 1),
		rate = 3,
		life = nr(0.8, 1.2),
		speed = nr(0.6, 1),
		spread = V2(60, 60),
	})
	bodyGlow(c, sun, 5.5, 0.9)
	local light = rootLight(c, sun, 1.2, 10, g + 1.4)

	-- Synced to the Blender animation (tools/blender/anim/auras/Emoji.py, idle 4.0 s):
	--   wave   (f30, f38) the waving hand sweeps -> a smiley pops OUT OF THE RIGHT HAND and floats
	--                                              up, a sparkle puff from the palm
	--   pop    (f70) star-jump landing           -> both floor rings flash, a spark ring bursts off the
	--                                              floor, every floating face does a "boing" bounce
	--   shrug  (f88) palms up                    -> "¯\_(ツ)_/¯" pops above the head, faces go ":/"
	--   giggle (f103) the giggle                 -> warm puffs from the head, waist bubbles jiggle
	--   skip   (walk apex)                       -> a puff off the head
	--   step / land (free)                       -> a sparkle at that foot / faces boing
	-- And back: a heart-eyed face emits "love" -> the "aww" reaction clip.
	local handTip = Core.tip(c, "rhand")
	local sparkle: Core.EmitSpec = {
		tex = T.spark,
		color = cs(WHITE, sun),
		size = ns(0.3, 0),
		rate = 0,
		life = nr(0.35, 0.7),
		speed = nr(2, 4),
		spread = V2(180, 180),
		drag = 4,
		bright = 2,
	}
	local handFx = if handTip then Core.emit(handTip, sparkle) else nil
	local footFx: { [string]: ParticleEmitter } = {}
	local feetTips: { [string]: string } = { R = "rfoot", L = "lfoot" }
	for side, which in feetTips do
		local tip = Core.tip(c, which)
		if tip then
			footFx[side] = Core.emit(tip, {
				tex = T.spark,
				color = cs(WHITE, sun, warm),
				size = ns(0.24, 0),
				rate = 0,
				life = nr(0.3, 0.55),
				speed = nr(1.5, 3),
				spread = V2(70, 70),
				dir = Enum.NormalId.Top,
				drag = 3,
			})
		end
	end
	local shrugAtt, shrugTag, shrugGui = B.glyph(c, "¯\\_(ツ)_/¯", sun, V2(2.6, 0.55), F.tech, CF(0, c.topY + 1.1, 0), ink)
	shrugGui.Enabled = false
	local shrugOn = false
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("wave", function()
		local p = pops[popNext]
		popNext = popNext % #pops + 1
		local root = c.root.CFrame
		local from = if handTip then root:PointToObjectSpace(handTip.WorldPosition) else V(1.6, c.chestY + 1, 0)
		p.t0 = os.clock()
		p.from = from
		p.drift = V(0.6 + rng:NextNumber() * 0.5, 2.6 + rng:NextNumber() * 0.6, (rng:NextNumber() - 0.5) * 0.8)
		p.live = true
		p.f.mouth.Text = Core.pick({ "D", ")", "3" }, rng)
		if handFx then
			handFx:Emit(10)
		end
	end)
	onEv("pop", function()
		floorSp:Emit(24)
		headGlow:Emit(3)
	end)
	onEv("giggle", function()
		headGlow:Emit(7)
	end)
	onEv("skip", function()
		headGlow:Emit(2)
	end)
	onEv("step", function(side)
		local fx = footFx[side :: string]
		if fx then
			fx:Emit(5)
		end
	end)
	ready = true

	Core.on(c, function(t, _, root)
		local bus = c.bus
		-- "boing": landing of the star jump (or a real jump) squashes then springs every face
		local popE = math.max(Sync.env(bus, "pop", 5), Sync.env(bus, "land", 6) * 0.7)
		local boing = 1 + popE * 0.5 * math.cos((1 - popE) * 14)
		local shrugW = Sync.window(bus, "shrug", 1.4)
		local shrugging = shrugW >= 0
		if shrugging ~= shrugOn then
			shrugOn = shrugging
			shrugGui.Enabled = shrugging
			if not shrugging then
				for _, f in faces do
					mood(f)
				end
			end
		end
		if shrugging then
			local s = popIn(math.min(1, shrugW * 5))
			shrugGui.Size = UDim2.new(2.6 * s, 0, 0.55 * s, 0)
			shrugTag.TextTransparency = smooth01((shrugW - 0.75) / 0.25)
			shrugAtt.Position = V(0, c.topY + 1.1 + shrugW * 0.4, 0)
		end
		for _, f in faces do
			local u = t / f.per + f.ph
			local ph = u % 1
			if math.floor(u) ~= f.cyc then
				f.cyc = math.floor(u)
				mood(f)
				f.a = rng:NextNumber() * TAU
			end
			if shrugging then
				f.mouth.Text = "/"
			end
			local a = f.a + ph * 1.3
			f.att.Position = V(math.cos(a) * f.r, g + 0.4 + ph * span, math.sin(a) * f.r)
			local s = (0.45 + smooth01(ph * 4) * 0.55 + math.sin(ph * math.pi * 6) * 0.04) * boing
			f.gui.Size = UDim2.new(0.8 * s, 0, 0.8 * s, 0)
			fadeFace(f, smooth01((ph - 0.7) / 0.3))
			f.face.Rotation = math.sin(t * 2 + f.ph * 9) * 12 + f.spin * ph
		end
		-- pop faces launched from the hand: rise + drift outward, pop in, fade out
		for _, p in pops do
			if p.live then
				local k = (t - p.t0) / 1.4
				if k >= 1 then
					p.live = false
					fadeFace(p.f, 1)
				else
					local e = 1 - (1 - k) * (1 - k)
					p.f.att.Position = p.from + p.drift * e + V(0, 0, math.sin(k * 9) * 0.15)
					local s = popIn(math.min(1, k * 4)) * (1 - k * 0.25) * boing
					p.f.gui.Size = UDim2.new(0.75 * s, 0, 0.75 * s, 0)
					fadeFace(p.f, smooth01((k - 0.6) / 0.4))
					p.f.face.Rotation = math.sin(k * 12) * 18
				end
			end
		end
		local gig = Sync.env(bus, "giggle", 2.5)
		for i, b in bubbles do
			b.Transparency = 0.1 + 0.4 * Core.pulse(t, 1.4, i * 0.17) * (1 - gig)
			local s = 0.26 * (1 + gig * 0.45 * math.abs(math.sin(t * 22 + i)) + popE * 0.4)
			b.Size = V(s, s, s)
		end
		B.setBeamsTransparency(ringA.beams, 0.35 - popE * 0.35)
		B.setBeamsTransparency(ringB.beams, 0.55 - popE * 0.5)
		Core.put(glow, root * CF(0, g + 0.02, 0) * FLAT)
		glow.Transparency = 0.93 - popE * 0.35
		light.Brightness = 1 + Core.pulse(t, 2.4) * 0.5 + popE * 1.4 + gig * 0.5
	end)
end

-- a faint fake copy flickering behind the player with mismatched colors
-- ~16 parts (R6) / 3 emitters
A.Spoof = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local side = 1
	local swapT = 0
	local offs = CF(0.9, 0, 1.25)
	local fake = B.clones(c, {
		set = "lite",
		color = c.c1,
		mat = FF,
		delay = 0.18,
		scale = 1.03,
		map = B.offsetMap(function()
			return offs
		end),
	})
	-- mismatched colours: alternate limbs in the second colour
	for i, p in fake do
		if i % 2 == 0 then
			p.Color = c.c2
		end
	end
	-- a solid-coloured inner copy that flickers in and out
	local inner = B.clones(c, {
		set = "core",
		color = c.c2,
		mat = NEON,
		tr = 0.75,
		delay = 0.18,
		scale = 0.9,
		map = B.offsetMap(function()
			return offs
		end),
	})
	local tagAtt, tag = B.glyph(c, "", c.c2, V2(1.8, 0.34), F.mono, nil, BLACK)
	B.circle(c, { radius = 2.6, color = c.c1, width = 0.09, at = CF(0, g + 0.04, 0), tr = 0.35, n = 8 })
	local fakeRing = B.circle(c, {
		radius = 1.4,
		color = c.c2,
		width = 0.08,
		n = 6,
		anchor = function()
			return CF(offs.Position.X, g + 0.05, offs.Position.Z)
		end,
	})
	local scan = Core.part(c, V(2.4, 0.05, 2.4), c.c1, NEON, 0.6, CYL)
	local wisp = Core.att(c, c.torso)
	Core.emit(Core.att(c, c.root, CF(0, 0, 0)), {
		tex = T.smoke,
		color = cs(c.c1, c.c2),
		size = ns(0.8, 1.8),
		transp = ns(0.85, 1),
		rate = 3,
		life = nr(1.2, 1.8),
		speed = nr(0.2, 0.5),
		spread = V2(180, 180),
		light = 0.5,
	})
	local glitch = Core.emit(wisp, {
		tex = T.square,
		color = cs(c.c1, c.c2),
		size = ns(0.16, 0),
		rate = 0,
		life = nr(0.2, 0.4),
		speed = nr(2, 4),
		spread = V2(180, 180),
		rot = nr(0, 0),
	})
	bodyGlow(c, c.c1, 5, 0.92)
	local light = rootLight(c, c.c2, 0.9, 9, g + 1.4)
	local flickUntil = 0
	local names = { "Player2", "Pl4yer", "P1ayer", "you?", "REAL_ME", "player_copy" }
	Core.on(c, function(t, _, root)
		-- the fake hops to the other side every few seconds
		if t >= swapT then
			swapT = t + 3 + rng:NextNumber() * 3
			side = -side
			glitch:Emit(10)
			tag.Text = Core.pick(names, rng)
			flickUntil = t + 0.3
		end
		local sx = side * (0.9 + math.sin(t * 0.8) * 0.15)
		offs = CF(sx, math.sin(t * 1.3) * 0.08, 1.25 + math.sin(t * 0.6) * 0.15)
		if t < flickUntil then
			offs *= CF((rng:NextNumber() - 0.5) * 0.5, 0, 0)
		end
		local on = if t < flickUntil then rng:NextNumber() < 0.5 else math.noise(t * 3, 4.1) > -0.35
		local base = 0.45 + 0.2 * Core.pulse(t, 2.2)
		for _, p in fake do
			p.Transparency = if on then base else 0.92
		end
		for _, p in inner do
			p.Transparency = if on and math.sin(t * 9) > 0.2 then 0.72 else 1
		end
		B.setBeamsTransparency(fakeRing.beams, if on then 0.3 else 0.8)
		tagAtt.Position = V(offs.Position.X, c.topY + 0.75, offs.Position.Z)
		tag.TextTransparency = if on then 0.1 else 0.7
		-- identity scan sweeping the real body
		local sy = g + ((t * 0.9) % 1) * (c.topY - g + 0.4)
		Core.put(scan, root * CF(0, sy, 0) * FLAT)
		scan.Transparency = 0.55 + ((t * 0.9) % 1) * 0.4
		light.Brightness = (if on then 0.9 else 0.5) + Core.pulse(t, 2.2) * 0.3
	end)
end

---------------------------------------------------------------- ENHANCED

-- bandage strips of code wrapping the body, green plus signs
-- 44 parts / 4 emitters
A.Patch = function(c: Ctx)
	-- Synced to the Blender animation (tools/blender/anim/auras/Patch.py, idle 4.8 s = two 2.4 s
	-- heal cycles; the heal ring leaves the floor on the shared phase, f0 and f72):
	--   apply "lhand" (f24, f96) slaps   -> heal burst + plus sparks FROM THE LEFT HAND, the
	--                                       bandage strips flare white, "+3 FIXED" / "PATCHED"
	--   bug   "lhand" (f50) twitch       -> glitch squares from the left hand, strips flicker
	--                                       blue, "+7 BUGS", the light stutters
	--   heal  (f72) redeploy breath      -> the floor cross flashes, chest heal burst, "v1.0.N"
	--   step (free)                      -> plus sparks at the stiff right foot, tape at the left
	-- While walking the VFX sometimes sparks a fresh bug and emits "bugzap" -> the body's "zap"
	-- reaction clip. Without markers (no clip) the change-log ticks on its own timer as before.
	local rng = c.rng
	local g = c.groundY
	local bus = c.bus
	local green = c.c1
	local blue = c.c2
	local red = Color3.fromRGB(255, 70, 90)
	local tape = green:Lerp(WHITE, 0.55)
	local h = c.topY - g
	local HEAL = 2.4 -- heal ring period = half the idle clip
	-- two helical bandage strips winding up the body (plates follow the helix tangent)
	local STRIP = 13
	type Plate = { p: BasePart, k: number, s: number, col: Color3 }
	local plates: { Plate } = {}
	for s = 1, 2 do
		for k = 1, STRIP do
			local col = if k % 4 == 0 then blue else (if k % 2 == 0 then green else tape)
			table.insert(plates, { p = Core.part(c, V(0.05, 0.3, 0.62), col, NEON, 0.25), k = k, s = s, col = col })
		end
	end
	-- floating plus signs
	type Plus = { a: BasePart, b: BasePart, ang: number, r: number, per: number, ph: number }
	local pluses: { Plus } = {}
	for i = 1, 6 do
		local col = if i % 3 == 0 then blue else green
		pluses[i] = {
			a = Core.part(c, V(0.5, 0.15, 0.15), col),
			b = Core.part(c, V(0.15, 0.5, 0.15), col),
			ang = rng:NextNumber() * TAU,
			r = 2.2 + rng:NextNumber() * 1.2,
			per = 2.6 + rng:NextNumber() * 1.2,
			ph = i / 6,
		}
	end
	-- medic cross sigil on the floor (two crossed bars) + rings
	local crossA = Core.part(c, V(3.2, 0.05, 0.7), green, NEON, 0.55)
	local crossB = Core.part(c, V(0.7, 0.05, 3.2), green, NEON, 0.55)
	B.circle(c, { radius = 3.4, color = green, width = 0.12, at = CF(0, g + 0.04, 0), tr = 0.2 })
	B.circle(c, { radius = 3.75, color = blue, width = 0.06, at = CF(0, g + 0.04, 0), tr = 0.45 })
	local heal = B.circle(c, {
		radius = 1,
		color = green,
		color2 = WHITE,
		width = 0.12,
		anchor = function()
			return CF(0, g + Sync.phase(bus, HEAL) * (h + 0.6), 0)
		end,
		radiusFn = function()
			return 1.9 - Sync.phase(bus, HEAL) * 0.5
		end,
	})
	local _, notes = B.glyph(c, "", green, V2(2.4, 0.38), F.mono, CF(0, c.topY + 1, 0), Color3.fromRGB(0, 40, 10))
	local logs = { "+3 FIXED", "-7 BUGS", "v1.0.%d", "PATCHED", "+1 FEATURE", "CHANGELOG" }
	Core.emit(Core.volume(c, V(5, 0.1, 5), CF(0, g + 0.1, 0)), {
		tex = T.square,
		color = cs(green, tape),
		size = ns(0.16, 0.12, 0),
		transp = ns(0.2, 1),
		rate = 10,
		life = nr(1.4, 2.2),
		speed = nr(0.8, 1.6),
		rot = nr(0, 0),
		shape = BOX,
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(WHITE, green),
		size = ns(0, 0.3, 0),
		rate = 6,
		life = nr(0.8, 1.3),
		speed = nr(0.5, 1),
		spread = V2(180, 180),
	})
	local healA = Core.att(c, c.root, CF(0, 0, 0))
	local healBurst = Core.emit(healA, {
		tex = T.glow,
		color = cs(green, WHITE),
		size = ns(0.4, 1.2),
		transp = ns(0.3, 1),
		rate = 0,
		life = nr(0.5, 0.8),
		speed = nr(1, 2),
		spread = V2(180, 180),
	})
	-- body-driven emitters: the patching (left) hand and both feet
	local handTip = Core.tip(c, "lhand")
	local handHeal = handTip
		and Core.emit(handTip, {
			tex = T.glow,
			color = cs(WHITE, green),
			size = ns(0.5, 0.9, 0),
			transp = ns(0.2, 1),
			rate = 0,
			life = nr(0.3, 0.55),
			speed = nr(1.5, 3),
			spread = V2(180, 180),
			drag = 3,
			bright = 2,
		})
	local handPlus = handTip
		and Core.emit(handTip, {
			tex = T.spark,
			color = cs(WHITE, green),
			size = ns(0.28, 0),
			rate = 0,
			life = nr(0.35, 0.7),
			speed = nr(2.5, 5),
			spread = V2(180, 180),
			drag = 4,
			bright = 2,
		})
	local handBug = handTip
		and Core.emit(handTip, {
			tex = T.square,
			color = cs(blue, red),
			size = ns(0.18, 0),
			rate = 0,
			life = nr(0.25, 0.5),
			speed = nr(3, 6),
			spread = V2(180, 180),
			rot = nr(0, 0),
			drag = 5,
		})
	local footFx: { [string]: ParticleEmitter } = {}
	local feetTips: { [string]: string } = { R = "rfoot", L = "lfoot" }
	for side, which in feetTips do
		local tip = Core.tip(c, which)
		if tip then
			footFx[side] = Core.emit(tip, {
				tex = if side == "R" then T.spark else T.square,
				color = if side == "R" then cs(WHITE, green) else cs(tape, green),
				size = ns(if side == "R" then 0.26 else 0.14, 0),
				rate = 0,
				life = nr(0.3, 0.6),
				speed = nr(1.2, 2.6),
				spread = V2(80, 80),
				dir = Enum.NormalId.Top,
				rot = nr(0, 0),
				drag = 2,
			})
		end
	end
	bodyGlow(c, green, 6.5, 0.88)
	local light = rootLight(c, green, 1.4, 12)
	local nextNote = 0
	local ver = 1
	local lastMark = -math.huge
	local nextZap = os.clock() + 4
	local noteCol = green
	local function note(s: string, col: Color3)
		notes.Text = s
		noteCol = col
		lastMark = os.clock()
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, name, fn))
	end
	local applyN = 0
	onEv("apply", function()
		applyN += 1
		if handHeal then
			handHeal:Emit(8)
		end
		if handPlus then
			handPlus:Emit(14)
		end
		note(if applyN % 2 == 1 then "+3 FIXED" else "PATCHED", green)
	end)
	onEv("bug", function()
		if handBug then
			handBug:Emit(16)
		end
		note("+7 BUGS", red)
	end)
	onEv("bugzap", function()
		if handBug then
			handBug:Emit(9)
		end
		note("+1 BUG", red)
	end)
	onEv("heal", function()
		ver += 1
		healBurst:Emit(14)
		note(string.format("v1.0.%d", ver), WHITE)
	end)
	onEv("step", function(side)
		if Sync.get(bus, "move") < 0.4 then
			return
		end
		local fx = footFx[side :: string]
		if fx then
			fx:Emit(if side == "R" then 6 else 4)
		end
	end)
	Core.on(c, function(t, _, root)
		local applyE = Sync.env(bus, "apply", 4)
		local bugW = math.max(Sync.window(bus, "bug", 0.5), Sync.window(bus, "bugzap", 0.35))
		local bugOn = bugW >= 0 and math.sin(t * 60) > 0 -- strips flicker while the bug lasts
		local wind = t * 0.35 -- strips crawl upward as if being wrapped
		for _, pl in plates do
			local f = ((pl.k - 1) / STRIP + wind) % 1
			local turns = 2.2
			local a = f * turns * TAU + (pl.s - 1) * math.pi + t * 0.3 * (if pl.s == 1 then 1 else -1)
			local y = g + 0.35 + f * (h - 0.2)
			local r = 1.25 + math.sin(f * math.pi) * 0.25 + applyE * 0.18
			-- tangent of the helix sets the plate's tilt
			local tilt = math.atan2(h / turns, TAU * r) * (if pl.s == 1 then 1 else -1)
			local jit = if bugOn then (rng:NextNumber() - 0.5) * 0.3 else 0
			Core.put(pl.p, root * ANG(0, -a, 0) * CF(r + jit, y, 0) * ANG(tilt, 0, 0))
			local edge = math.min(f, 1 - f) * 8
			pl.p.Transparency = 1 - math.min(1, edge) * (0.8 + applyE * 0.2)
			pl.p.Color = if bugOn then blue else pl.col:Lerp(WHITE, applyE * 0.7)
		end
		for _, p in pluses do
			local u = t / p.per + p.ph
			local ph = u % 1
			local cf = root
				* CF(math.cos(p.ang + ph) * p.r, g + 0.6 + ph * (h + 1.2), math.sin(p.ang + ph) * p.r)
				* ANG(0, t * 2 + p.ph * 6, 0)
			Core.put(p.a, cf)
			Core.put(p.b, cf)
			local tr = 1 - math.sin(ph * math.pi) * 0.95
			p.a.Transparency = tr
			p.b.Transparency = tr
			if ph > 0.985 then
				p.ang = rng:NextNumber() * TAU
			end
		end
		local hp = Sync.phase(bus, HEAL)
		local healE = Sync.env(bus, "heal", 3)
		local fcf = root * CF(0, g + 0.03, 0) * ANG(0, t * 0.2, 0)
		Core.put(crossA, fcf)
		Core.put(crossB, fcf)
		local beat = math.max(math.exp(-hp * HEAL * 2.5), healE)
		crossA.Transparency = math.max(0.05, 0.7 - beat * 0.3 - healE * 0.4)
		crossB.Transparency = crossA.Transparency
		crossA.Color = green:Lerp(WHITE, healE * 0.8)
		crossB.Color = crossA.Color
		B.setBeamsTransparency(heal.beams, 0.15 + hp * 0.8)
		-- free-running change-log when the body is not driving it (walking / no clip)
		if t - lastMark > 3 and t >= nextNote then
			nextNote = t + 1.4
			local s = Core.pick(logs, rng)
			if string.find(s, "%%d") then
				ver += 1
				s = string.format(s, ver)
			end
			notes.Text = s
			noteCol = green
			healBurst:Emit(6)
		end
		notes.TextColor3 = noteCol
		-- a fresh bug sparks now and then while walking -> body "zap" reaction
		if Sync.get(bus, "move") > 0.5 and t >= nextZap then
			nextZap = t + 4 + rng:NextNumber() * 3
			Sync.emit(bus, "bugzap")
		elseif Sync.get(bus, "move") < 0.2 then
			nextZap = math.max(nextZap, t + 2)
		end
		local stutter = if bugW >= 0 then (if math.sin(t * 45) > 0 then -0.9 else 0.6) else 0
		light.Color = if bugW >= 0 then blue else green
		light.Brightness = 1.2 + beat * 1 + applyE * 0.8 + stutter
	end)
end

-- red breakpoint dots and yellow step arrows tracing around the body
-- 33 parts / 3 emitters
A.Debug = function(c: Ctx)
	local g = c.groundY
	local yel = c.c1
	local red = c.c2
	local h = c.topY - g
	local R = 2.2
	-- the execution path: a helix around the body, 24 "lines" from feet to head
	local LINES = 24
	local function pathCF(i: number, t: number): CFrame
		local f = (i - 1) / (LINES - 1)
		local a = f * TAU * 2 + t * 0.25
		return outward(a, R, g + 0.4 + f * (h - 0.1))
	end
	-- faint gutter dashes marking every line
	local dashes: { BasePart } = {}
	for i = 1, LINES do
		dashes[i] = Core.part(c, V(0.24, 0.05, 0.05), yel, NEON, 0.7)
	end
	-- breakpoints sit on a few of the lines
	local bpLines = { 4, 9, 14, 19, 23 }
	local bps: { BasePart } = {}
	local bpRings: { BasePart } = {}
	for k = 1, #bpLines do
		bps[k] = Core.part(c, V(0.32, 0.32, 0.32), red, NEON, 0, BALL)
		bpRings[k] = Core.part(c, V(0.04, 0.5, 0.5), red, NEON, 0.4, CYL)
	end
	-- step arrows: chevrons made of two bars
	type Arrow = { a: BasePart, b: BasePart, line: number, nextStep: number, trail: Trail }
	local arrows: { Arrow } = {}
	for k = 1, 2 do
		local pa = Core.part(c, V(0.36, 0.1, 0.08), yel)
		arrows[k] = {
			a = pa,
			b = Core.part(c, V(0.36, 0.1, 0.08), yel),
			line = 1 + (k - 1) * 12,
			nextStep = 0,
			trail = Core.trail(pa, yel, 0.1, 0.25, red),
		}
	end
	B.circle(c, { radius = 3.2, color = yel, width = 0.1, at = CF(0, g + 0.04, 0), tr = 0.3 })
	local ringSpin = 0
	B.ring(c, {
		n = 20,
		radius = 3.55,
		gap = 4,
		seg = V(0.12, 0.05, 0),
		color = red,
		spin = 0,
		anchor = function()
			return CF(0, g + 0.04, 0) * ANG(0, ringSpin, 0)
		end,
	})
	local _, status, statusGui = B.glyph(c, "", red, V2(2.8, 0.4), F.mono, CF(0, c.topY + 1, 0), BLACK)
	statusGui.Enabled = false
	local _, lineNo = B.glyph(c, "", yel, V2(1.6, 0.3), F.mono, CF(0, c.topY + 0.6, 0))
	local hitA = Core.att(c, c.root)
	local hit = Core.emit(hitA, {
		tex = T.spark,
		color = cs(WHITE, red),
		size = ns(0.3, 0),
		rate = 0,
		life = nr(0.3, 0.6),
		speed = nr(2, 4),
		spread = V2(180, 180),
		drag = 3,
	})
	Core.emit(Core.volume(c, V(4.6, 0.1, 4.6), CF(0, g + 0.1, 0)), {
		tex = T.square,
		color = cs(yel, red),
		size = ns(0.12, 0),
		transp = ns(0.2, 1),
		rate = 6,
		life = nr(1, 1.6),
		speed = nr(0.6, 1.2),
		rot = nr(0, 0),
		shape = BOX,
	})
	bodyGlow(c, yel, 6, 0.9)
	local light = rootLight(c, yel, 1.2, 11)
	local pauseUntil = 0
	local hitBp = 0
	local isBp: { [number]: number } = {}
	for k, ln in bpLines do
		isBp[ln] = k
	end

	-- Synced to the Blender animation (tools/blender/anim/auras/Debug.py, idle 4.4 s). The body
	-- drives the debugger:
	--   stepover (f8/16/24) air taps      -> both arrows step one line, spark from THE RIGHT HAND
	--   run      (f34) continue flick     -> the arrows race along the helix (trails flare)
	--   break    (f46) freeze jolt        -> arrow #1 lands on the next breakpoint: swell, red hit
	--                                        burst, "BREAK @ line", red light, floor ring halts
	--   watch    (f66/78/90) inspect      -> a watch value pops next to the magnifier hand
	--   fix      (f100) aha point-up      -> breakpoint flashes white, hand sparks, "RESUMED"
	--   step (free, walking)              -> one step-over per footfall, squares puff at the foot
	-- Without idle markers (no clip / airborne) the arrows step on their own as before, and a
	-- self-hit breakpoint emits "bphit" -> the body's "startle" reaction clip.
	local bus = c.bus
	local handTip = Core.tip(c, "rhand")
	local handFx = handTip
		and Core.emit(handTip, {
			tex = T.spark,
			color = cs(WHITE, yel),
			size = ns(0.26, 0),
			rate = 0,
			life = nr(0.25, 0.5),
			speed = nr(2.5, 5),
			spread = V2(50, 50),
			dir = Enum.NormalId.Bottom,
			drag = 4,
			bright = 2,
		})
	local footFx: { [string]: ParticleEmitter } = {}
	local feetTips: { [string]: string } = { R = "rfoot", L = "lfoot" }
	for side, which in feetTips do
		local tip = Core.tip(c, which)
		if tip then
			footFx[side] = Core.emit(tip, {
				tex = T.square,
				color = cs(yel, red),
				size = ns(0.14, 0),
				rate = 0,
				life = nr(0.3, 0.6),
				speed = nr(1, 2.2),
				spread = V2(80, 80),
				dir = Enum.NormalId.Top,
				rot = nr(0, 0),
				drag = 2,
			})
		end
	end
	local watchAtt, watchLbl, watchGui = B.glyph(c, "", yel, V2(1.7, 0.32), F.mono, nil, BLACK)
	watchGui.Enabled = false
	local watches = { "x = nil", "hp = -1", "i = 2^31", "ok = false", "aura = ???", "luck = NaN", "rolls = 0", "self = self" }
	local watchN = 0
	local running, runNext = false, 0
	local lastIdleMark = -math.huge
	local statusMsg, statusUntil = "", 0
	local function advance(ar: Arrow, n: number): number?
		ar.line = (ar.line - 1 + n) % LINES + 1
		return isBp[ar.line]
	end
	local function breakAt(ar: Arrow, k: number, t: number, dur: number)
		pauseUntil = t + dur
		hitBp = k
		hitA.Position = (pathCF(ar.line, t) * CF(0, 0, -0.25)).Position
		hit:Emit(14)
		statusMsg = string.format("BREAK @ line %d", 40 + ar.line)
		statusUntil = pauseUntil
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, name, function(arg)
			fn(arg)
		end))
	end
	local function mark()
		lastIdleMark = os.clock()
	end
	onEv("stepover", function()
		mark()
		running = false
		for _, ar in arrows do
			advance(ar, 1)
		end
		if handFx then
			handFx:Emit(8)
		end
	end)
	onEv("run", function()
		mark()
		running = true
		pauseUntil = 0
		if handFx then
			handFx:Emit(14)
		end
	end)
	onEv("break", function()
		mark()
		running = false
		local t = os.clock()
		-- arrow #1 lands on the next breakpoint ahead of it
		local ar = arrows[1]
		for _ = 1, LINES do
			if advance(ar, 1) then
				break
			end
		end
		breakAt(ar, isBp[ar.line] or 1, t, 1.9)
	end)
	onEv("watch", function()
		mark()
		watchN = watchN % #watches + 1
		watchLbl.Text = watches[watchN]
		watchGui.Enabled = true
	end)
	onEv("fix", function()
		mark()
		pauseUntil = 0
		statusMsg = "RESUMED"
		statusUntil = os.clock() + 0.7
		if handFx then
			handFx:Emit(20)
		end
		hit:Emit(8)
	end)
	onEv("step", function(side)
		if Sync.get(bus, "move") < 0.4 then
			return
		end
		local t = os.clock()
		local fx = footFx[side :: string]
		if fx then
			fx:Emit(6)
		end
		for k, ar in arrows do
			local b = advance(ar, 2)
			if b and k == 1 and t >= pauseUntil then
				breakAt(ar, b, t, 0.45)
				if Sync.since(bus, "bphit") > 3 then
					Sync.emit(bus, "bphit")
				end
			end
		end
	end)

	Core.on(c, function(t, dt, root)
		local paused = t < pauseUntil
		local walking = Sync.get(bus, "move") > 0.4
		local auto = not walking and (t - lastIdleMark) > 2.5
		for i, d in dashes do
			Core.put(d, root * pathCF(i, t))
		end
		local fixE = Sync.env(bus, "fix", 5)
		for k, ln in bpLines do
			local cf = root * pathCF(ln, t) * CF(0, 0, -0.25)
			Core.put(bps[k], cf)
			local hot = paused and hitBp == k
			local s = if hot then 0.5 + 0.15 * math.sin(t * 20) else 0.32 + (if hitBp == k then fixE * 0.3 else 0)
			bps[k].Size = V(s, s, s)
			bps[k].Color = if hitBp == k and fixE > 0.05 then red:Lerp(WHITE, fixE) else red
			Core.put(bpRings[k], cf * ANG(0, math.pi / 2, 0) * ANG(t * 3, 0, 0))
			bpRings[k].Transparency = if hot then 0 else 0.55 - (if hitBp == k then fixE * 0.55 else 0)
		end
		if running and not paused and t >= runNext then
			-- "continue": race along, ignoring breakpoints until the body's "break"
			runNext = t + 0.05
			for _, ar in arrows do
				advance(ar, 1)
			end
		end
		for _, ar in arrows do
			if auto and not paused and t >= ar.nextStep then
				-- free-running: hop one line, pausing on breakpoints
				ar.nextStep = t + 0.16
				local k = advance(ar, 1)
				if k then
					breakAt(ar, k, t, 0.9)
					paused = true
					if Sync.since(bus, "bphit") > 3 then
						Sync.emit(bus, "bphit")
					end
				end
			end
			local cf = root * pathCF(ar.line, t) * CF(0, 0, -0.42)
			local wob = if paused then math.sin(t * 16) * 0.05 else 0
			-- chevron ">" pointing along the path
			Core.put(ar.a, cf * CF(wob, 0.09, 0) * ANG(0, 0, -0.65))
			Core.put(ar.b, cf * CF(wob, -0.09, 0) * ANG(0, 0, 0.65))
			ar.trail.Lifetime = if running then 0.6 else 0.25
		end
		for i, d in dashes do
			local near = false
			for _, ar in arrows do
				if ar.line == i then
					near = true
				end
			end
			d.Transparency = if near then 0 else 0.7
			d.Color = if near then WHITE else yel
		end
		-- watch value riding beside the magnifier hand
		local ww = Sync.window(bus, "watch", 0.5)
		if ww < 0 then
			watchGui.Enabled = false
		elseif handTip then
			local p = root:PointToObjectSpace(handTip.WorldPosition)
			watchAtt.Position = p + V(0, 0.55 + ww * 0.25, 0)
			watchLbl.TextTransparency = smooth01((ww - 0.7) / 0.3)
			local s = popIn(math.min(1, ww * 6))
			watchGui.Size = UDim2.new(1.7 * s, 0, 0.32 * s, 0)
		end
		local showStatus = t < statusUntil
		status.Text = statusMsg
		statusGui.Enabled = showStatus and (statusMsg == "RESUMED" or math.sin(t * 14) > -0.5)
		status.TextColor3 = if statusMsg == "RESUMED" then yel else red
		lineNo.Text = string.format("ln %02d  col %02d", 40 + arrows[1].line, (arrows[1].line * 7) % 80 + 1)
		-- the red floor ring turns with the program and halts on a break
		if not paused then
			ringSpin -= dt * (if running then 1.6 else 0.3)
		end
		light.Color = if paused then red else yel
		light.Brightness = if paused then 2.2 else 1 + Core.pulse(t, 0.6) * 0.3 + fixE * 1.5
	end)
end

-- orange flames shaped like wrench icons, hot sparks
-- 31 parts / 5 emitters
A.Hotfix = function(c: Ctx)
	-- Synced to the Blender animation (tools/blender/anim/auras/Hotfix.py, idle 6.0 s = one
	-- deploy = 3 builds, the old 2 s / 3rd-build rhythm):
	--   tap    (f5/10/15/20) foot taps  -> spark puffs at THE RIGHT FOOT
	--   watch  (f34) watch check        -> the label shows the clock "FRI 17:5x"
	--   hit    "rhand" (f58/72/86)      -> build +1 "HOTFIX v1.0.N", spark shower FROM THE RIGHT
	--                                      HAND, the wrench flames flare
	--   deploy (f114) both-fist slam    -> "DEPLOYED (FRI 17:59)", floor spark burst, fire surge
	--   flare  (f134) flinch            -> fireball puff from the floor, light spike
	--   step (free)                     -> sparks + flame lick at the landing foot
	-- While walking (no idle markers) builds/deploys tick on the old 2 s timer, and a deploy
	-- spark storm emits "burn" -> the body's burn reaction (hand jerks away and shakes).
	local g = c.groundY
	local bus = c.bus
	local hot = c.c1
	local white = c.c2
	local h = c.topY - g
	-- wrench = handle + head block + two jaw prongs + a hot core strip
	type Wrench = { parts: { BasePart }, offs: { CFrame }, a: number, ph: number, per: number, r: number }
	local wrenches: { Wrench } = {}
	local W = 1
	local function makeWrench(i: number): Wrench
		local parts = {
			Core.part(c, V(0.16, 1.1, 0.08) * W, hot),
			Core.part(c, V(0.42, 0.24, 0.1) * W, hot),
			Core.part(c, V(0.12, 0.26, 0.1) * W, hot),
			Core.part(c, V(0.12, 0.26, 0.1) * W, hot),
			Core.part(c, V(0.06, 0.8, 0.1) * W, white),
		}
		local offs = {
			CF(0, -0.25, 0),
			CF(0, 0.38, 0),
			CF(-0.15, 0.6, 0) * ANG(0, 0, 0.12),
			CF(0.15, 0.6, 0) * ANG(0, 0, -0.12),
			CF(0, -0.25, -0.02),
		}
		return { parts = parts, offs = offs, a = (i - 1) / 4 * TAU, ph = i / 4, per = 2.6 + i * 0.2, r = 2 }
	end
	for i = 1, 4 do
		wrenches[i] = makeWrench(i)
	end
	-- each wrench drags real fire behind it (emitter on the moving head part)
	for _, w in wrenches do
		Core.emit(w.parts[2], {
			tex = T.fire,
			color = cs(white, hot, hot:Lerp(Color3.new(0.4, 0, 0), 0.6)),
			size = ns(0.5, 0.25, 0),
			transp = ns(0.3, 1),
			rate = 14,
			life = nr(0.35, 0.6),
			speed = nr(0.3, 0.8),
			spread = V2(30, 30),
			accel = V(0, 3, 0),
			rotSpeed = nr(-90, 90),
			bright = 2.5,
		})
	end
	-- floor flames and a heat ring
	local FR = 2.8
	Core.emit(Core.volume(c, V(FR * 1.6, 0.1, FR * 1.6), CF(0, g + 0.15, 0)), {
		tex = T.fire,
		color = cs(white, hot, Color3.fromRGB(150, 30, 0)),
		size = ns(0.9, 0.5, 0),
		transp = ns(0.35, 1),
		rate = 22,
		life = nr(0.5, 0.9),
		speed = nr(1, 2),
		spread = V2(10, 10),
		accel = V(0, 2, 0),
		rotSpeed = nr(-60, 60),
		shape = BOX,
		bright = 2,
	})
	local sparks = Core.emit(Core.volume(c, V(4, 0.1, 4), CF(0, g + 0.2, 0)), {
		tex = T.fireSpark,
		color = cs(white, hot),
		size = ns(0.2, 0),
		rate = 12,
		life = nr(0.8, 1.4),
		speed = nr(3, 6),
		spread = V2(25, 25),
		accel = V(0, -4, 0),
		bright = 3,
		shape = BOX,
	})
	B.ring(c, {
		n = 18,
		radius = FR + 0.3,
		seg = V(0.2, 0.06, 0),
		color = hot,
		color2 = white,
		spin = 0.8,
		wave = 0.06,
		waveFreq = 6,
		waveSpeed = 8,
		anchor = function()
			return CF(0, g + 0.06, 0)
		end,
	})
	B.circle(c, { radius = FR + 0.7, color = hot, width = 0.08, at = CF(0, g + 0.04, 0), tr = 0.4 })
	local _, ver = B.glyph(c, "", white, V2(2.4, 0.4), F.pixel, CF(0, c.topY + 1.1, 0), Color3.fromRGB(80, 20, 0))
	Core.emit(Core.att(c, c.root, CF(0, c.chestY, 0)), {
		tex = T.smoke,
		color = cs(hot),
		size = ns(1.5, 3),
		transp = ns(0.88, 1),
		rate = 3,
		life = nr(1.4, 2),
		speed = nr(1, 2),
		spread = V2(20, 20),
		light = 0.3,
	})
	-- body-driven emitters: the hammering hand, both feet, and a floor fireball for "flare"
	local handTip = Core.tip(c, "rhand")
	local handFx = handTip
		and Core.emit(handTip, {
			tex = T.fireSpark,
			color = cs(WHITE, white, hot),
			size = ns(0.22, 0),
			rate = 0,
			life = nr(0.35, 0.7),
			speed = nr(5, 9),
			spread = V2(70, 70),
			dir = Enum.NormalId.Bottom,
			accel = V(0, -10, 0),
			drag = 1,
			bright = 3,
		})
	local footFx: { [string]: ParticleEmitter } = {}
	local feetTips: { [string]: string } = { R = "rfoot", L = "lfoot" }
	for side, which in feetTips do
		local tip = Core.tip(c, which)
		if tip then
			footFx[side] = Core.emit(tip, {
				tex = T.fire,
				color = cs(white, hot, hot:Lerp(Color3.new(0.4, 0, 0), 0.6)),
				size = ns(0.45, 0.2, 0),
				transp = ns(0.3, 1),
				rate = 0,
				life = nr(0.25, 0.45),
				speed = nr(1.5, 3),
				spread = V2(60, 60),
				dir = Enum.NormalId.Top,
				accel = V(0, 3, 0),
				bright = 2.5,
			})
		end
	end
	local ballA = Core.att(c, c.root, CF(0, g + 0.4, -1.2))
	local fireball = Core.emit(ballA, {
		tex = T.fire,
		color = cs(white, hot, Color3.fromRGB(150, 30, 0)),
		size = ns(1.4, 2.6, 0),
		transp = ns(0.2, 1),
		rate = 0,
		life = nr(0.4, 0.7),
		speed = nr(3, 6),
		spread = V2(35, 35),
		dir = Enum.NormalId.Top,
		accel = V(0, 4, 0),
		rotSpeed = nr(-120, 120),
		bright = 3,
	})
	bodyGlow(c, hot, 6.5, 0.88)
	local light = rootLight(c, hot, 1.6, 12, g + 1.2)
	local nextV = 0
	local build = 0
	local deployUntil = 0
	local lastMark = -math.huge
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, name, function(arg)
			lastMark = os.clock()
			fn(arg)
		end))
	end
	onEv("tap", function()
		local fx = footFx.R
		if fx then
			fx:Emit(3)
		end
		sparks:Emit(2)
	end)
	onEv("watch", function()
		ver.Text = string.format("FRI 17:5%d", 7 + build % 3)
	end)
	onEv("hit", function()
		build += 1
		ver.Text = string.format("HOTFIX v1.0.%d", build)
		if handFx then
			handFx:Emit(18)
		end
	end)
	onEv("deploy", function()
		deployUntil = os.clock() + 1.2
		ver.Text = "DEPLOYED (FRI 17:59)"
		sparks:Emit(36)
	end)
	onEv("flare", function()
		fireball:Emit(10)
		ver.Text = "PROD IS ON FIRE"
	end)
	table.insert(c.cleanups, Sync.on(bus, "step", function(side)
		if Sync.get(bus, "move") < 0.4 then
			return
		end
		local fx = footFx[side :: string]
		if fx then
			fx:Emit(4)
		end
	end))
	Core.on(c, function(t, _, root)
		local deploy = t < deployUntil
		local hitE = Sync.env(bus, "hit", 6)
		local flareE = Sync.env(bus, "flare", 3)
		for i, w in wrenches do
			-- wrenches rise like flame tongues, spinning, then drop back in
			local u = t / w.per + w.ph
			local ph = u % 1
			local a = w.a + t * 0.6
			local y = g + 0.6 + ph * (h + 0.4)
			local sway = math.sin(t * 3 + i) * 0.25
			local cf = root * outward(a, w.r - ph * 0.5, y) * ANG(0, 0, sway + ph * math.pi * 1.5)
			local s = math.sin(ph * math.pi)
			for k, p in w.parts do
				Core.put(p, cf * w.offs[k])
				p.Transparency = 1 - s * (if k == 5 then 0.8 else 0.95)
				p.Color = (if k == 5 then white else hot):Lerp(WHITE, hitE * 0.6)
			end
		end
		-- free-running build timer when the body is not driving it (walking / no clip)
		if t - lastMark > 2.5 and t >= nextV then
			nextV = t + 2
			build += 1
			ver.Text = string.format("HOTFIX v1.0.%d", build)
			if build % 3 == 0 then
				deployUntil = t + 0.8
				ver.Text = "DEPLOYED (FRI 17:59)"
				sparks:Emit(30)
				if Sync.get(bus, "move") > 0.5 then
					Sync.emit(bus, "burn") -- the spark storm singes the hand
					if handFx then
						handFx:Emit(10)
					end
				end
			end
		end
		sparks.Rate = if deploy then 40 else 12
		light.Brightness = 1.3
			+ math.noise(t * 6, 2.2) * 0.8
			+ (if deploy then 1.2 else 0)
			+ hitE * 0.9
			+ flareE * 2
	end)
end

-- rotating letter wheels with shifting glyphs (a cryptex around the body)
-- 39 parts / 3 emitters / 30 glyphs
A.Cipher = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local lav = c.c1
	local deep = c.c2
	local h = c.topY - g
	local R = 2.5
	local WORD = { "K", "E", "Y" }
	type Wheel = {
		y: number,
		glyphs: { TextLabel },
		atts: { Attachment },
		off: number,
		target: number,
		shift: number,
		rim: { BasePart },
	}
	local wheels: { Wheel } = {}
	local N = 10
	for k = 1, 3 do
		local yy = g + 0.6 + (k - 1) * (h - 0.6) / 2.2
		local wh: Wheel = { y = yy, glyphs = {}, atts = {}, off = 0, target = 0, shift = 0, rim = {} }
		for i = 1, N do
			local att, lbl = B.glyph(c, "A", lav, V2(0.58, 0.58), F.tech, nil, deep)
			wh.atts[i] = att
			wh.glyphs[i] = lbl
		end
		-- the wheel itself: ten glassy segment plates (a ribbed cryptex ring)
		for i = 1, N do
			wh.rim[i] = Core.part(c, V(0.06, 0.58, TAU * R / N * 0.8), deep:Lerp(lav, 0.3), GLASS, 0.45)
		end
		B.circle(c, { radius = R + 0.05, color = lav, width = 0.04, at = CF(0, yy + 0.32, 0), tr = 0.3, n = 8 })
		B.circle(c, { radius = R + 0.05, color = lav, width = 0.04, at = CF(0, yy - 0.32, 0), tr = 0.3, n = 8 })
		wheels[k] = wh
	end
	-- alignment bar: where the code is read
	local bar = Core.part(c, V(0.08, h - 0.2, 0.08), WHITE, NEON, 0.2)
	local barCaps = { Core.part(c, V(0.3, 0.06, 0.3), lav), Core.part(c, V(0.3, 0.06, 0.3), lav) }
	-- floor: rotating Caesar disc (outer plain / inner shifted alphabet ticks)
	B.circle(c, { radius = 3.6, color = lav, width = 0.12, at = CF(0, g + 0.04, 0), tr = 0.2 })
	B.circle(c, { radius = 3.0, color = deep:Lerp(lav, 0.5), width = 0.07, at = CF(0, g + 0.04, 0), tr = 0.35 })
	local ticks = B.ring(c, {
		n = 13,
		radius = 3.3,
		seg = V(0.4, 0.05, 0.08),
		color = lav,
		spin = 0.25,
		anchor = function()
			return CF(0, g + 0.04, 0)
		end,
	})
	local _, rot = B.glyph(c, "ROT13", lav, V2(1.8, 0.4), F.pixel, CF(0, c.topY + 1.05, 0), deep)
	local clickA = Core.att(c, c.root)
	local click = Core.emit(clickA, {
		tex = T.square,
		color = cs(WHITE, lav),
		size = ns(0.12, 0),
		rate = 0,
		life = nr(0.25, 0.45),
		speed = nr(1.5, 3),
		spread = V2(60, 60),
		dir = Enum.NormalId.Front,
		rot = nr(0, 0),
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(lav, WHITE),
		size = ns(0, 0.3, 0),
		rate = 6,
		life = nr(0.8, 1.4),
		speed = nr(0.6, 1.2),
		spread = V2(180, 180),
	})
	Core.emit(Core.volume(c, V(5, 0.1, 5), CF(0, g + 0.1, 0)), {
		tex = T.glow,
		color = cs(lav),
		size = ns(0.2, 0.5),
		transp = ns(0.5, 1),
		rate = 6,
		life = nr(1.2, 2),
		speed = nr(0.6, 1.2),
		shape = BOX,
	})
	bodyGlow(c, lav, 6.5, 0.88)
	local light = rootLight(c, lav, 1.3, 12)
	-- Synced to the Blender animation (tools/blender/anim/auras/Cipher.py, idle 4.4 s). The
	-- safecracker's hands turn the wheels; nothing turns on a timer while a clip drives it:
	--   turn "1"/"2"/"3"  each click-stop of a hand -> that wheel jumps one notch (mechanical snap),
	--                     its front glyph flips, click-sparks from the turning hand, the bar blinks
	--   solve             arms burst open            -> K-E-Y on the bar, DECRYPTED, light surge,
	--                     sparks from both hands, the floor ticks all flash
	--   scramble          the wrist flick            -> every wheel spins away, glyphs re-randomize,
	--                     spark spray from the right hand, the solve ends
	--   step (free)       walking                    -> each footfall turns the next wheel; after six
	--                     the code cracks by itself and "cracked" makes the body fist-pump
	-- Fallback: with no hand turning for 2.5 s (airborne, no clip) the old 0.55 s timer runs.
	local hands: { [string]: Attachment? } =
		{ R = Core.tip(c, "rhand", CF(0, -0.1, 0)), L = Core.tip(c, "lhand", CF(0, -0.1, 0)) }
	local handSpec: Core.EmitSpec = {
		tex = T.square,
		color = cs(WHITE, lav),
		size = ns(0.12, 0),
		rate = 0,
		life = nr(0.25, 0.5),
		speed = nr(1.5, 3.5),
		drag = 2,
		spread = V2(70, 70),
		rot = nr(0, 0),
		bright = 2,
	}
	local handFx: { [string]: ParticleEmitter } = {}
	for side, att in hands do
		if att then
			handFx[side] = Core.emit(att, handSpec)
		end
	end
	local function handEmit(side: string, n: number)
		local e = handFx[side]
		if e then
			e:Emit(n)
		end
	end
	local solvedUntil = 0
	local turnK = 1
	local lastTurn = os.clock()
	local barBlink, solveT, scrambleT = -10, -10, -10
	local walkTurns = 0
	local function turn(k: number, side: string?)
		local t = os.clock()
		lastTurn = t
		barBlink = t
		local wh = wheels[k]
		wh.shift = rng:NextInteger(1, 25)
		wh.target = math.floor(wh.target + 0.5) + (if k == 2 then -1 else 1)
		click:Emit(5)
		if side then
			handEmit(side, 7)
		end
	end
	local function solve()
		local t = os.clock()
		lastTurn = t
		solveT = t
		solvedUntil = t + 1.5
		for _, wh in wheels do
			wh.target = math.floor(wh.target + 0.5)
		end
		handEmit("R", 16)
		handEmit("L", 16)
		click:Emit(14)
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("turn", function(arg)
		local k = math.clamp(tonumber(arg) or 1, 1, 3)
		turn(k, if k == 1 then "L" else "R")
	end)
	onEv("solve", solve)
	onEv("scramble", function()
		local t = os.clock()
		lastTurn = t
		scrambleT = t
		solvedUntil = 0
		for _, wh in wheels do
			wh.shift = rng:NextInteger(1, 25)
			wh.target += (if rng:NextNumber() < 0.5 then 1 else -1) * rng:NextInteger(4, 8)
			for _, lbl in wh.glyphs do
				lbl.Text = randChar(rng, LETTERS)
				lbl.TextColor3 = lav
			end
		end
		handEmit("R", 20)
		click:Emit(10)
	end)
	onEv("step", function(side)
		if os.clock() < solvedUntil then
			return
		end
		turn(turnK, side)
		turnK = turnK % 3 + 1
		walkTurns += 1
		if walkTurns >= 6 then
			walkTurns = 0
			solve()
			Sync.emit(c.bus, "cracked")
		end
	end)
	Core.on(c, function(t, dt, root)
		local camDir = camAxes(root)
		local readA = math.atan2(camDir.Z, camDir.X) -- angle facing the camera
		local solved = t < solvedUntil
		if t - lastTurn > 2.5 and not solved then
			-- fallback: nobody's hands on the wheels -> turn one every 0.55 s
			turn(turnK, nil)
			turnK = turnK % 3 + 1
			lastTurn = t - 2.5 + 0.55
			if turnK == 1 and rng:NextNumber() < 0.35 then
				solve()
				lastTurn = t - 2.5 + 1.8
			end
		end
		local scr = math.clamp(1 - (t - scrambleT) / 0.5, 0, 1)
		for k, wh in wheels do
			-- snap toward the target notch with a tiny overshoot (mechanical click)
			local d = wh.target - wh.off
			wh.off += d * math.min(1, dt * (12 + scr * 10))
			local drift = t * 0.25 * (if k == 2 then -1 else 1)
			local base = (wh.off + drift) / N * TAU
			for i, att in wh.atts do
				local a = readA + base + (i - 1) / N * TAU
				att.Position = V(math.cos(a) * (R + 0.12), wh.y, math.sin(a) * (R + 0.12))
				local lbl = wh.glyphs[i]
				local front = math.cos(a - readA) > 0.95
				if front then
					lbl.Text = if solved then WORD[k] else string.char(65 + ((i * 7 + wh.shift) % 26))
					lbl.TextColor3 = if solved then WHITE else lav:Lerp(WHITE, 0.5)
				elseif rng:NextNumber() < 0.02 then
					lbl.Text = randChar(rng, LETTERS)
					lbl.TextColor3 = lav
				end
			end
			for i, p in wh.rim do
				local a = readA + base + (i - 0.5) / N * TAU
				Core.put(p, root * ANG(0, -a, 0) * CF(R - 0.05, wh.y, 0))
			end
		end
		local bpos = V(math.cos(readA) * (R + 0.35), g + h / 2 + 0.25, math.sin(readA) * (R + 0.35))
		Core.put(bar, root * CF(bpos))
		Core.put(barCaps[1], root * CF(bpos + V(0, (h - 0.2) / 2, 0)))
		Core.put(barCaps[2], root * CF(bpos - V(0, (h - 0.2) / 2, 0)))
		clickA.Position = bpos
		local blink = math.clamp(1 - (t - barBlink) / 0.15, 0, 1)
		local flash = math.clamp(1 - (t - solveT) / 0.6, 0, 1)
		bar.Color = if solved then Color3.fromRGB(140, 255, 170) else WHITE:Lerp(lav, blink)
		bar.Transparency = 0.2 - blink * 0.2
		for i, p in ticks do
			p.Transparency = if flash > 0 then 0.45 * (1 - flash)
				elseif (i + math.floor(t * 4)) % 13 == 0 then 0
				else 0.45
		end
		rot.Text = if solved then "DECRYPTED" else string.format("ROT%d", wheels[1].shift)
		light.Brightness = (if solved then 2.6 else 1.1 + Core.pulse(t, 1.1) * 0.4) + blink * 0.5 + flash * 1.5
	end)
end

-- two padlocks orbiting and chained together with beams
-- 30 parts / 3 emitters
A.Deadlock = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local steel = c.c1
	local red = c.c2
	local dark = steel:Lerp(BLACK, 0.6)
	local y = c.chestY + 0.2
	local R = 2.6
	type Lock = { parts: { BasePart }, offs: { CFrame }, hole: BasePart, a: number, cf: CFrame }
	local function makeLock(): Lock
		local parts = {
			Core.part(c, V(0.82, 0.68, 0.32), dark, METAL), -- body
			Core.part(c, V(0.86, 0.06, 0.34), steel), -- top trim
			Core.part(c, V(0.86, 0.06, 0.34), steel), -- bottom trim
			Core.part(c, V(0.1, 0.42, 0.1), steel, METAL), -- shackle left
			Core.part(c, V(0.1, 0.42, 0.1), steel, METAL), -- shackle right
			Core.part(c, V(0.52, 0.1, 0.1), steel, METAL), -- shackle top
		}
		local hole = Core.part(c, V(0.1, 0.22, 0.34), red)
		table.insert(parts, hole)
		local offs = {
			CF(0, 0, 0),
			CF(0, 0.34, 0),
			CF(0, -0.34, 0),
			CF(-0.26, 0.55, 0),
			CF(0.26, 0.55, 0),
			CF(0, 0.76, 0),
			CF(0, -0.05, -0.01),
		}
		return { parts = parts, offs = offs, hole = hole, a = 0, cf = CF() }
	end
	local locks = { makeLock(), makeLock() }
	-- the chain: links along a sagging curve between the shackles
	local LINKS = 9
	local links: { BasePart } = {}
	for i = 1, LINKS do
		links[i] = Core.part(c, V(0.06, 0.16, 0.26), if i % 2 == 0 then steel else steel:Lerp(WHITE, 0.3), METAL)
	end
	local ca = Core.att(c)
	local cb = Core.att(c)
	local glowChain = Core.beam(c, ca, cb, red, 0.18, {
		w1 = 0.18,
		c0 = 0,
		c1 = 0,
		segs = 12,
		tex = T.square,
		texLen = 0.5,
		texSpeed = 1.5,
		tr = NumberSequence.new(0.35),
	})
	B.circle(c, { radius = 3.2, color = steel, width = 0.1, at = CF(0, g + 0.04, 0), tr = 0.3 })
	local ringAng = 0
	B.ring(c, {
		n = 2,
		radius = 3.2,
		seg = V(0.34, 0.08, 0.8),
		color = red,
		spin = 0,
		anchor = function()
			return CF(0, g + 0.05, 0) * ANG(0, -ringAng, 0)
		end,
	})
	local waits: { TextLabel } = {}
	local waitAtts: { Attachment } = {}
	for k = 1, 2 do
		local att, lbl = B.glyph(c, "", red, V2(1.8, 0.3), F.mono, nil, BLACK)
		waits[k] = lbl
		waitAtts[k] = att
	end
	local midA = Core.att(c)
	local strain = Core.emit(midA, {
		tex = T.spark,
		color = cs(WHITE, red),
		size = ns(0.25, 0),
		rate = 2,
		life = nr(0.3, 0.6),
		speed = nr(1.5, 3),
		spread = V2(180, 180),
		accel = V(0, -6, 0),
	})
	local smoke = Core.emit(Core.volume(c, V(4.6, 0.1, 4.6), CF(0, g + 0.1, 0)), {
		tex = T.smoke,
		color = cs(steel),
		size = ns(0.8, 1.6),
		transp = ns(0.85, 1),
		rate = 3,
		life = nr(1.5, 2.2),
		speed = nr(0.3, 0.6),
		shape = BOX,
		light = 0.3,
	})
	bodyGlow(c, steel, 6, 0.9)
	local light = rootLight(c, red, 1, 11)

	-- Synced to the Blender animation (tools/blender/anim/auras/Deadlock.py, idle 5.0 s): the
	-- shackled wrists ARE the chain between the two padlocks.
	--   look "L"/"R" (f12, f24)  eyes on a lock      -> that lock's WAITING tag + keyhole flash
	--   tug "L"/"R"  (f36, f62)  the lunge           -> both locks are dragged toward that side,
	--                                                  chain pulls taut
	--   yank         (f40, f66)  snapped back        -> locks recoil with a wobble, clink sparks
	--   strain       (f84)       the standoff        -> 0.8 s full strain (taut glowing chain, white
	--                                                  keyholes, sparks, red surge, the clock ring stops)
	--   slump        (f108)      gives up            -> chain sags extra, light dims, smoke puff
	--   tap          (f124/132)  foot taps           -> dust at the right foot + the clock ring ticks
	--   clink (walk contacts), step (free)           -> chain clink sparks / dust at that foot
	-- Without idle markers for a while (walking, no clip) the locks strain on a random timer and
	-- emit "jolt" -> the body's "jolt" reaction clip.
	local bus = c.bus
	local dust: Core.EmitSpec = {
		tex = T.smoke,
		color = cs(steel:Lerp(WHITE, 0.3), steel),
		size = ns(0.25, 0.7),
		transp = ns(0.55, 1),
		rate = 0,
		life = nr(0.4, 0.7),
		speed = nr(0.8, 1.6),
		spread = V2(80, 80),
		dir = Enum.NormalId.Top,
		drag = 3,
		light = 0.3,
	}
	local footFx: { [string]: ParticleEmitter } = {}
	local feetTips: { [string]: string } = { R = "rfoot", L = "lfoot" }
	for side, which in feetTips do
		local tip = Core.tip(c, which)
		if tip then
			footFx[side] = Core.emit(tip, dust)
		end
	end
	local strainUntil = 0
	local nextStrain = 0
	local lastIdleMark = -math.huge
	local tugDir, tugT, yankT = 0, -math.huge, -math.huge
	local shift = 0
	local lookT = { -math.huge, -math.huge }
	local tick, tickShown, nextTick = 0, 0, 0
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(bus, name, fn))
	end
	local function idleMark()
		lastIdleMark = os.clock()
		nextStrain = os.clock() + 4
	end
	onEv("look", function(side)
		idleMark()
		-- flash the lock that is on that side of the body right now (root space: -X = left)
		local root = c.root.CFrame
		local x1 = root:PointToObjectSpace(locks[1].cf.Position).X
		local x2 = root:PointToObjectSpace(locks[2].cf.Position).X
		local leftK = if x1 < x2 then 1 else 2
		lookT[if side == "L" then leftK else 3 - leftK] = os.clock()
	end)
	onEv("tug", function(side)
		idleMark()
		tugDir = if side == "L" then -1 else 1 -- root-space X of the pull
		tugT = os.clock()
	end)
	onEv("yank", function()
		idleMark()
		yankT = os.clock()
		strain:Emit(10)
	end)
	onEv("strain", function()
		idleMark()
		strainUntil = os.clock() + 0.8
		strain:Emit(22)
	end)
	onEv("slump", function()
		idleMark()
		smoke:Emit(4)
	end)
	onEv("tap", function()
		idleMark()
		tick += 1
		if footFx.R then
			footFx.R:Emit(6)
		end
	end)
	onEv("clink", function()
		strain:Emit(6)
	end)
	onEv("step", function(side)
		local fx = footFx[side :: string]
		if fx then
			fx:Emit(3)
		end
	end)

	Core.on(c, function(t, dt, root)
		-- free-running strain only when the body is not driving it (walking / no idle clip)
		if t - lastIdleMark > 4 and t >= nextStrain then
			nextStrain = t + 2.2 + rng:NextNumber() * 1.5
			strainUntil = t + 0.7
			strain:Emit(16)
			Sync.emit(bus, "jolt")
		end
		local straining = t < strainUntil
		local base = t * 0.5
		local tug = if straining then math.sin((strainUntil - t) * 28) * 0.08 else 0
		local pull = if straining then 0.25 * math.sin(math.clamp(1 - (strainUntil - t) / 0.8, 0, 1) * math.pi) else 0
		-- tug / yank: the pair is dragged sideways, then snaps back past centre with a wobble
		local target
		if yankT > tugT then
			local s = t - yankT
			target = -tugDir * 0.55 * math.exp(-s * 5) * math.cos(s * 13)
		else
			target = tugDir * 0.9 * (1 - math.exp(-(t - tugT) * 18)) * math.exp(-math.max(0, t - tugT - 0.6) * 4)
		end
		shift += (target - shift) * math.min(1, dt * 30)
		local yankE = Sync.env(bus, "yank", 7)
		local slumpE = Sync.env(bus, "slump", 1.6)
		local taut = math.max(if straining then 1 else 0, math.abs(shift) / 0.9, yankE)
		for k, lk in ipairs(locks) do
			local dir = if k == 1 then 1 else -1
			lk.a = base + (k - 1) * math.pi + dir * pull + tug
			local yy = y + math.sin(t * 1.3 + k * 2) * 0.2 - slumpE * 0.35
			local rattle = yankE * math.sin(t * 50 + k) * 0.12
			lk.cf = root
				* CF(shift, 0, 0)
				* outward(lk.a, R, yy)
				* ANG(0, math.pi, math.sin(t * 2 + k) * 0.15 + tug + rattle)
			for i, p in lk.parts do
				Core.put(p, lk.cf * lk.offs[i])
			end
			local look = math.exp(-(t - lookT[k]) * 3)
			local blink = look > 0.05 and math.sin(t * 30) > 0
			lk.hole.Color = if straining or yankE > 0.4 or blink then WHITE else red
			waitAtts[k].Position = root:PointToObjectSpace((lk.cf * CF(0, 1.25 + look * 0.2, 0)).Position)
			waits[k].Text = string.format("WAITING FOR #%d", 3 - k)
			waits[k].TextTransparency = if look > 0.05 then 0 else (if (t * 2 + k) % 2 < 1.4 then 0 else 0.7)
			waits[k].TextColor3 = if look > 0.05 then red:Lerp(WHITE, look) else red
		end
		-- chain sags under the body between the two shackles (taut while pulled)
		local pa = (locks[1].cf * CF(0, 0.76, 0)).Position
		local pb = (locks[2].cf * CF(0, 0.76, 0)).Position
		local sag = 1.2 - 0.8 * math.clamp(taut, 0, 1) + slumpE * 0.6
		local mid = (pa + pb) / 2 - root.UpVector * sag
		for i, l in links do
			local f = i / (LINKS + 1)
			local p = (1 - f) * (1 - f) * pa + 2 * (1 - f) * f * mid + f * f * pb
			local f2 = math.min(1, f + 0.02)
			local q = (1 - f2) * (1 - f2) * pa + 2 * (1 - f2) * f2 * mid + f2 * f2 * pb
			local look = if (q - p).Magnitude > 1e-3 then CFrame.lookAt(p, q) else CF(p)
			Core.put(l, look * ANG(0, 0, if i % 2 == 0 then math.pi / 2 else 0))
		end
		-- attachment X axes point down so the beam's curve sags like the links
		local down, side = V(0, -1, 0), V(1, 0, 0)
		ca.CFrame = CFrame.fromMatrix(root:PointToObjectSpace(pa), down, side)
		cb.CFrame = CFrame.fromMatrix(root:PointToObjectSpace(pb), down, side)
		midA.Position = root:PointToObjectSpace(mid)
		glowChain.CurveSize0 = sag
		glowChain.CurveSize1 = -sag
		glowChain.Transparency = NumberSequence.new(if straining then 0.05 else 0.6 - 0.45 * math.clamp(taut, 0, 1))
		-- the red clock ring ticks once a second (and on every foot tap); a strain stops time
		if not straining and t >= nextTick then
			nextTick = t + 1
			tick += 1
		end
		tickShown += (tick - tickShown) * math.min(1, dt * 14)
		ringAng = tickShown * (TAU / 12)
		light.Brightness = (if straining then 2.4 else 0.9 + Core.pulse(t, 2) * 0.3) + yankE * 1.2 - slumpE * 0.6
		light.Color = if straining or yankE > 0.3 then red else steel
	end)
end

---------------------------------------------------------------- RARE

-- a mask-like head hologram drifting off the head, face-scan grid
-- ~34 parts / 4 emitters
A.Deepfake = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local skin = c.c1
	local cyan = c.c2
	local hs = Core.headSize(c.head)
	-- three face masks: one peels off the real head, two orbit as "candidates"
	type Mask = { p: BasePart, eyes: { BasePart }, col: Color3 }
	local masks: { Mask } = {}
	for k = 1, 3 do
		local col = if k == 2 then cyan else skin
		local p = Core.cloneShape(c, c.head, col, FF, 0, 1.12)
		local eyes = {
			Core.part(c, V(0.2, 0.06, 0.04), if k == 2 then skin else cyan),
			Core.part(c, V(0.2, 0.06, 0.04), if k == 2 then skin else cyan),
		}
		masks[k] = { p = p, eyes = eyes, col = col }
	end
	-- scan brackets around the real face (4 L corners = 8 bars)
	local brackets: { BasePart } = {}
	for i = 1, 8 do
		brackets[i] = Core.part(c, V(0.05, 0.3, 0.05), cyan)
	end
	local scanLine = Core.part(c, V(hs.X * 1.3, 0.04, 0.02), cyan, NEON, 0.1)
	-- face-scan grid: a camera-facing lattice of beams over the head
	local GRID = 4
	local gridA: { Attachment } = {}
	local gridB: { Attachment } = {}
	for i = 1, GRID * 2 do
		gridA[i] = Core.att(c)
		gridB[i] = Core.att(c)
		Core.beam(c, gridA[i], gridB[i], cyan, 0.025, { segs = 1, tr = NumberSequence.new(0.45) })
	end
	-- face landmarks: tracking dots
	local dots: { BasePart } = {}
	local dotOff = { V(-0.24, 0.12), V(0.24, 0.12), V(0, -0.05), V(-0.2, -0.25), V(0.2, -0.25), V(0, -0.3) }
	for i = 1, #dotOff do
		dots[i] = Core.part(c, V(0.07, 0.07, 0.07), WHITE, NEON, 0, BALL)
	end
	-- ground: identity sigil with a turning recognition grid
	B.sigil(c, {
		radius = 4.4,
		color = skin,
		color2 = cyan,
		rings = 3,
		ticks = 16,
		spokes = 6,
		spin = 0.3,
		glow = 0.9,
		glowColor = cyan,
		pulse = 3,
	})
	local _, match = B.glyph(c, "", cyan, V2(2.6, 0.42), F.mono, CF(0, c.topY + 1.3, 0), BLACK)
	local ha = Core.att(c, c.head)
	Core.emit(ha, {
		tex = T.square,
		color = cs(skin, cyan),
		size = ns(0.12, 0),
		transp = ns(0.1, 1),
		rate = 10,
		life = nr(0.5, 1),
		speed = nr(0.6, 1.4),
		spread = V2(180, 180),
		rot = nr(0, 0),
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.glow,
		color = cs(skin, cyan),
		size = ns(0.6, 1.4),
		transp = ns(0.6, 1),
		rate = 4,
		life = nr(1, 1.6),
		speed = nr(0.4, 0.9),
		spread = V2(180, 180),
	})
	Core.emit(Core.volume(c, V(7, 0.1, 7), CF(0, g + 0.1, 0)), {
		tex = T.square,
		color = cs(cyan, skin),
		size = ns(0.18, 0),
		transp = ns(0.2, 1),
		rate = 10,
		life = nr(1.4, 2.2),
		speed = nr(0.8, 1.5),
		rot = nr(0, 0),
		shape = BOX,
	})
	bodyGlow(c, skin, 7, 0.86)
	local light = B.rootLight(c, skin, 1.8, 14, { y = c.headY, pulse = 2.4, amp = 0.8 })
	local swapUntil = 0
	local nextSwap = 0
	local pct = 97.3

	-- Synced to the Blender animation (tools/blender/anim/auras/Deepfake.py). The 5.0 s idle IS
	-- the peel cycle (Sync.phase on the bus clock): the mask leaves the face on "peel" (f8), the
	-- body turns to stare at it, the head glitches between mirrored identities ("swap" f56/f62),
	-- the hand feels the bare face ("touch" f88), grabs the mask ("grab" f112; it then rides the
	-- right hand) and slaps it back on ("lock" f132). Walk: "flick" = a mirrored-head flicker.
	-- The VFX answers back: a random tracker MISMATCH emits "mismatch" -> the doubletake clip.
	local IDLE = 5.0
	local PEEL0, GRAB0, LOCK0 = 8 / 150, 112 / 150, 132 / 150
	local handTip = Core.tip(c, "rhand")
	local feet: { [string]: Attachment? } = { R = Core.tip(c, "rfoot"), L = Core.tip(c, "lfoot") }
	local squareBurst: Core.EmitSpec = {
		tex = T.square,
		color = cs(skin, cyan),
		size = ns(0.2, 0),
		transp = ns(0, 1),
		rate = 0,
		life = nr(0.35, 0.8),
		speed = nr(2.5, 6),
		drag = 4,
		spread = V2(180, 180),
		rot = nr(0, 0),
		bright = 2.5,
	}
	local headBurst = Core.emit(ha, squareBurst)
	local handBurst = handTip and Core.emit(handTip, squareBurst)
	local handSpark = handTip
		and Core.emit(handTip, {
			tex = T.spark,
			color = cs(WHITE, cyan),
			size = ns(0, 0.35, 0),
			rate = 0,
			life = nr(0.2, 0.4),
			speed = nr(3, 6),
			drag = 5,
			spread = V2(180, 180),
			bright = 3,
		})
	local footFx: { [string]: ParticleEmitter } = {}
	for side, a in feet do
		if a then
			footFx[side] = Core.emit(a, {
				tex = T.square,
				color = cs(cyan, skin),
				size = ns(0.16, 0),
				transp = ns(0.1, 1),
				rate = 0,
				life = nr(0.5, 0.9),
				speed = nr(0.8, 1.8),
				spread = V2(70, 70),
				rot = nr(0, 0),
			})
		end
	end
	local candFlip = 0 -- candidate masks jump half an orbit on every identity swap
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("peel", function()
		headBurst:Emit(16)
	end)
	onEv("swap", function()
		swapUntil = math.max(swapUntil, os.clock() + 0.12)
		candFlip += math.pi
		headBurst:Emit(10)
	end)
	onEv("flick", function()
		swapUntil = math.max(swapUntil, os.clock() + 0.08)
		headBurst:Emit(5)
	end)
	onEv("touch", function()
		if handBurst then
			handBurst:Emit(24)
		end
	end)
	onEv("grab", function()
		if handSpark then
			handSpark:Emit(14)
		end
	end)
	onEv("lock", function()
		swapUntil = 0
		pct = 99.9
		headBurst:Emit(40)
		if handSpark then
			handSpark:Emit(20)
		end
	end)
	onEv("step", function(side)
		local e = footFx[side :: string]
		if e then
			e:Emit(5)
		end
	end)

	Core.on(c, function(t, _, root)
		local hcf = c.head.CFrame
		-- peel cycle on the idle clock: lifts off at "peel", floats beside the head (turned to
		-- stare back at the body), rides the hand from "grab", snaps on at "lock"
		local cyc = Sync.phase(c.bus, IDLE)
		local move = Sync.get(c.bus, "move")
		local peel = if cyc >= LOCK0 then 0 else smooth01((cyc - PEEL0) / 0.22)
		local headRest = root * CF(0, c.headY, 0)
		local floatCF = headRest
			* CF(0.9, 0.55 + math.sin(t * 1.3) * 0.06, -0.6)
			* ANG(0.25, 0.9 + math.sin(t * 0.8) * 0.08, 0.2)
		local m1 = hcf:Lerp(floatCF, peel)
		if handTip and cyc >= GRAB0 and cyc < LOCK0 then
			local hold = smooth01((cyc - GRAB0) / 0.03) * (1 - move)
			local face = smooth01((cyc - 0.8) / (LOCK0 - 0.8))
			local hp = handTip.WorldPosition + root:VectorToWorldSpace(V(0, 0, -0.25))
			m1 = m1:Lerp(CF(hp) * floatCF.Rotation:Lerp(hcf.Rotation, face), hold)
		end
		local lockE = Sync.env(c.bus, "lock", 5)
		local mcfs = { m1, m1, m1 }
		Core.put(masks[1].p, m1)
		masks[1].p.Transparency = math.max(0.05, 0.15 + (1 - peel) * 0.6 - lockE * 0.6)
		-- candidates orbit the head
		for k = 2, 3 do
			local a = t * 0.9 + (k - 2) * math.pi + candFlip
			local cf = root
				* CF(0, c.headY + 0.15 + math.sin(t * 1.4 + k) * 0.12, 0)
				* ANG(0, -a, 0)
				* CF(1.6, 0, 0)
				* ANG(0, -math.pi / 2 + math.sin(t * 2 + k) * 0.3, 0)
			mcfs[k] = cf
			Core.put(masks[k].p, cf)
			masks[k].p.Transparency = 0.35 + 0.25 * Core.pulse(t, 1.7, k * 0.3)
		end
		for k, m in masks do
			local front = mcfs[k] * CF(0, hs.Y * 0.08, -hs.Z * 0.56)
			Core.put(m.eyes[1], front * CF(-hs.X * 0.18, 0, 0))
			Core.put(m.eyes[2], front * CF(hs.X * 0.18, 0, 0))
		end
		-- brackets + scan line over the real face
		local face = hcf * CF(0, 0, -hs.Z * 0.62)
		-- brackets bloom when the mask peels away and punch in onto the face on the slap
		local bs = 1 + Sync.env(c.bus, "peel", 3) * 0.35 + lockE * 0.6
		local bw, bh = hs.X * 0.7 * bs, hs.Y * 0.62 * bs
		local k = 0
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				local corner = face * CF(sx * bw, sy * bh, 0)
				k += 1
				Core.put(brackets[k], corner * CF(0, -sy * 0.13, 0))
				k += 1
				Core.put(brackets[k], corner * CF(-sx * 0.13, 0, 0) * ANG(0, 0, math.pi / 2))
			end
		end
		local sweep = math.sin(t * 2.2)
		local pw = Sync.window(c.bus, "peel", 0.5)
		if pw >= 0 then
			sweep = 1 - 2 * pw -- one fast top-to-bottom scan as the mask leaves
		end
		Core.put(scanLine, face * CF(0, sweep * bh, -0.02))
		-- landmark dots jitter as the tracker re-locks (scatter when the hand touches the face)
		local touchE = Sync.env(c.bus, "touch", 3)
		for i, d in dots do
			local o = dotOff[i]
			local j = (if t < swapUntil then 0.05 else 0.01) + touchE * 0.2
			Core.put(
				d,
				face * CF(o.X * hs.X + (rng:NextNumber() - 0.5) * j, o.Y * hs.Y + (rng:NextNumber() - 0.5) * j, -0.03)
			)
		end
		-- grid lattice facing the camera, centred on the face
		local gpos = (hcf * CF(0, 0, -hs.Z * 0.5)).Position
		local gl = root:ToObjectSpace(faceCam(gpos)) * CF(0, 0, -0.35)
		local S = hs.X * 0.85
		for i = 1, GRID do
			local f = (i - 1) / (GRID - 1) * 2 - 1
			gridA[i].CFrame = gl * CF(f * S, -S, 0)
			gridB[i].CFrame = gl * CF(f * S, S, 0)
			gridA[GRID + i].CFrame = gl * CF(-S, f * S, 0)
			gridB[GRID + i].CFrame = gl * CF(S, f * S, 0)
		end
		if t >= nextSwap then
			nextSwap = t + 0.25
			pct = math.clamp(pct + (rng:NextNumber() - 0.5) * 3, 82, 99.9)
			-- the tracker randomly loses the face -> the body does a doubletake (not while the
			-- hand is busy grabbing / slapping the mask back on)
			if rng:NextNumber() < 0.03 and t >= swapUntil + 2 and (cyc < GRAB0 - 0.05 or cyc > LOCK0 + 0.08) then
				swapUntil = t + 0.6
				Sync.emit(c.bus, "mismatch")
			end
		end
		if lockE > 0.12 then
			match.Text = "MATCH 100.0%"
			match.TextColor3 = WHITE
		elseif t < swapUntil then
			match.Text = "MISMATCH"
			match.TextColor3 = Color3.fromRGB(255, 70, 70)
		else
			match.Text = string.format("MATCH %.1f%%", pct)
			match.TextColor3 = cyan
		end
		scanLine.Color = if t < swapUntil then Color3.fromRGB(255, 70, 70) else cyan:Lerp(WHITE, lockE)
		light.Color = skin:Lerp(cyan, Core.pulse(t, 5)):Lerp(WHITE, lockE * 0.7)
		light.Brightness += lockE * 2.5 + Sync.env(c.bus, "touch", 4) * 1
	end)
end

-- purple spider-web lines spanning around the player, onion rings
-- ~22 parts / 4 emitters / ~60 beams
A.Darkweb = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local purple = c.c1
	local void = c.c2
	local h = c.topY - g
	-- web disc behind the player (always opposite the camera), radial spokes + spiral rings
	local SPOKES = 10
	local RINGS = 4
	local WR = 3.4
	local hub = Core.att(c)
	local spokeEnds: { Attachment } = {}
	local spokeBeams: { Beam } = {}
	for i = 1, SPOKES do
		spokeEnds[i] = Core.att(c)
		spokeBeams[i] =
			Core.beam(c, hub, spokeEnds[i], purple, 0.05, { w1 = 0.025, segs = 1, tr = NumberSequence.new(0.1, 0.5) })
	end
	local ringAtts: { { Attachment } } = {}
	for r = 1, RINGS do
		ringAtts[r] = {}
		for i = 1, SPOKES do
			ringAtts[r][i] = Core.att(c)
		end
		for i = 1, SPOKES do
			Core.beam(c, ringAtts[r][i], ringAtts[r][i % SPOKES + 1], purple, 0.035, {
				segs = 4,
				tr = NumberSequence.new(0.25 + r * 0.08),
				c0 = 0,
				c1 = 0,
			})
		end
	end
	-- tent strands from the shoulders down to anchor points on the floor
	local strandTop = { Core.att(c, c.torso, CF(0.9, 0.9, 0)), Core.att(c, c.torso, CF(-0.9, 0.9, 0)) }
	local strandEnds: { Attachment } = {}
	local strandBeams: { Beam } = {}
	for i = 1, 6 do
		local a = (i - 1) / 6 * TAU + 0.3
		strandEnds[i] = Core.att(c, nil, CF(math.cos(a) * 3.8, g + 0.05, math.sin(a) * 3.8))
		strandBeams[i] = Core.beam(c, strandTop[(i % 2) + 1], strandEnds[i], purple, 0.03, {
			w1 = 0.05,
			segs = 6,
			tr = NumberSequence.new(0.3, 0.7),
			c0 = 0.6,
			c1 = -0.4,
		})
	end
	-- onion layers: three tilted, counter-rotating rings around the chest
	local onions: { B.Circle } = {}
	for k = 1, 3 do
		local rad = 1.6 + k * 0.45
		local tilt = (k - 2) * 0.55
		local sp = (if k % 2 == 0 then -1 else 1) * (0.4 + k * 0.1)
		onions[k] = B.circle(c, {
			radius = rad,
			color = purple:Lerp(WHITE, 0.15 * k),
			width = 0.1,
			n = 8,
			anchor = function(t)
				return CF(0, c.chestY + 0.2, 0) * ANG(0, t * sp, 0) * ANG(tilt, 0, 0.3 * math.sin(t * 0.4 + k))
			end,
		})
	end
	-- the spider: abdomen + head + 8 leg bars, crawling along the spokes
	local abdomen = Core.part(c, V(0.42, 0.36, 0.5), void, SMOOTH, 0, BALL)
	local cephal = Core.part(c, V(0.26, 0.22, 0.26), void, SMOOTH, 0, BALL)
	local mark = Core.part(c, V(0.12, 0.2, 0.04), purple)
	local legs: { BasePart } = {}
	for i = 1, 8 do
		legs[i] = Core.part(c, V(0.46, 0.04, 0.04), void, SMOOTH)
	end
	local thread = Core.att(c)
	local spiderAtt = Core.att(c)
	Core.beam(c, thread, spiderAtt, WHITE, 0.02, { segs = 1, tr = NumberSequence.new(0.4) })
	-- dark floor: smoke + onion sigil
	B.sigil(c, {
		radius = 4.6,
		color = purple,
		color2 = void:Lerp(purple, 0.4),
		rings = 4,
		ticks = 0,
		spokes = 8,
		spin = 0.15,
		glow = 0.85,
		glowColor = void:Lerp(purple, 0.25),
	})
	local _, onionLbl = B.glyph(c, "", purple, V2(2.6, 0.4), F.mono, CF(0, c.topY + 1.3, 0), BLACK)
	local urls = { "xk3j9d2a.onion", "UNINDEXED", "NO_LOGS", "TOR://hidden", "403 // GO BACK", "q7v...onion" }
	Core.emit(Core.volume(c, V(7, 0.1, 7), CF(0, g + 0.1, 0)), {
		tex = T.smoke,
		color = cs(void, purple:Lerp(void, 0.5)),
		size = ns(1.5, 3.2),
		transp = ns(0.4, 1),
		rate = 7,
		life = nr(2, 3),
		speed = nr(0.2, 0.5),
		rotSpeed = nr(-20, 20),
		light = 0,
		shape = BOX,
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(purple, WHITE),
		size = ns(0, 0.3, 0),
		rate = 6,
		life = nr(0.8, 1.4),
		speed = nr(0.5, 1),
		spread = V2(180, 180),
	})
	Core.emit(Core.volume(c, V(5, h, 5), CF(0, g + h / 2, 0)), {
		tex = T.square,
		color = cs(purple),
		size = ns(0.08, 0),
		transp = ns(0.2, 1),
		rate = 8,
		life = nr(1, 2),
		speed = nr(0.1, 0.3),
		rot = nr(0, 0),
		shape = BOX,
		shapeStyle = VOLUME,
	})
	bodyGlow(c, purple, 7, 0.85)
	local light = B.rootLight(c, purple, 1.6, 14, { pulse = 3, amp = 0.8 })

	-- Synced to the Blender animation (tools/blender/anim/auras/Darkweb.py). The 4.8 s idle is the
	-- spider's hunting cycle (Sync.phase on the bus clock): it crawls out along a spoke while the
	-- lurker checks over both shoulders ("glance" f22 L / f40 R: the .onion address switches and
	-- flickers, the web shudders, onion rings flash), freezes whenever a finger taps the hidden
	-- terminal ("tap" f70/76/82: the strands pluck, purple data squares spark from the right hand)
	-- and sprints back to the hub when the arms fling out like spider legs ("spread" f96: the web
	-- flares, floor strands pulse, sparks from both hands, a smoke puff, "403 // GO BACK").
	-- Walking: every footfall ("step") puffs smoke from that foot and twitches the floor strands.
	local IDLE = 4.8
	local RETURN0 = 96 / 144 -- "spread": the spider heads home
	local tips: { [string]: Attachment? } = {
		R = Core.tip(c, "rhand"),
		L = Core.tip(c, "lhand"),
		RF = Core.tip(c, "rfoot"),
		LF = Core.tip(c, "lfoot"),
	}
	local handFx: { [string]: ParticleEmitter } = {}
	for _, side in { "R", "L" } do
		local a = tips[side]
		if a then
			handFx[side] = Core.emit(a, {
				tex = T.square,
				color = cs(purple:Lerp(WHITE, 0.35), purple),
				size = ns(0.14, 0),
				transp = ns(0, 1),
				rate = 0,
				life = nr(0.35, 0.7),
				speed = nr(1.5, 4),
				drag = 4,
				spread = V2(180, 180),
				rot = nr(0, 0),
				bright = 2.5,
			})
		end
	end
	local footFx: { [string]: { ParticleEmitter } } = {}
	for _, side in { "R", "L" } do
		local a = tips[side .. "F"]
		if a then
			footFx[side] = {
				Core.emit(a, {
					tex = T.smoke,
					color = cs(void, purple:Lerp(void, 0.4)),
					size = ns(0.5, 1.4),
					transp = ns(0.35, 1),
					rate = 0,
					life = nr(0.6, 1),
					speed = nr(0.6, 1.2),
					spread = V2(80, 80),
					rotSpeed = nr(-40, 40),
					light = 0,
				}),
				Core.emit(a, {
					tex = T.spark,
					color = cs(purple, WHITE),
					size = ns(0, 0.18, 0),
					rate = 0,
					life = nr(0.3, 0.6),
					speed = nr(1.5, 3),
					spread = V2(70, 70),
					drag = 3,
				}),
			}
		end
	end
	local puff = Core.emit(Core.att(c, c.torso), {
		tex = T.smoke,
		color = cs(void, purple),
		size = ns(1, 3.4),
		transp = ns(0.3, 1),
		rate = 0,
		life = nr(0.7, 1.2),
		speed = nr(3, 6),
		drag = 4,
		spread = V2(180, 180),
		rotSpeed = nr(-60, 60),
		light = 0.2,
	})
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	local nextUrl = 0
	local holdUrl = 0 -- an event just set the label: keep it this long
	onEv("glance", function()
		onionLbl.Text = Core.pick(urls, rng)
		holdUrl = 2.2
	end)
	onEv("tap", function()
		local e = handFx.R
		if e then
			e:Emit(10)
		end
	end)
	onEv("spread", function()
		for _, e in handFx do
			e:Emit(18)
		end
		puff:Emit(14)
		onionLbl.Text = "403 // GO BACK"
		holdUrl = 2.6
	end)
	onEv("step", function(side)
		local list = footFx[side :: string]
		if list then
			list[1]:Emit(3)
			list[2]:Emit(5)
		end
	end)

	local spokeK = 1
	local reach = 0 -- 0 = at the hub .. 1 = at the end of its spoke
	local lastCyc = 0
	local gait = 0
	local strandT = NumberSequence.new(0.3, 0.7)
	Core.on(c, function(t, dt, root)
		local camDir, camRight = camAxes(root)
		local cyc = Sync.phase(c.bus, IDLE)
		local glanceE = Sync.env(c.bus, "glance", 6)
		local tapE = Sync.env(c.bus, "tap", 7)
		local spreadE = Sync.env(c.bus, "spread", 2.2)
		local stepE = Sync.env(c.bus, "step", 8)
		-- web plane behind the player, slowly turning around its own hub; it shudders on a
		-- glance and flares out when the arms spread
		local center = -camDir * 1.5 + V(0, c.chestY + 0.6, 0)
		local shudder = math.sin(t * 47) * 0.06 * glanceE
		local frame = CFrame.fromMatrix(center, camRight, Vector3.yAxis) * ANG(0, 0, t * 0.08 + shudder)
		hub.CFrame = frame
		local breathe = (1 + math.sin(t * 0.8) * 0.04) * (1 + 0.28 * spreadE)
		for i, e in spokeEnds do
			local a = (i - 1) / SPOKES * TAU
			e.Position = (frame * CF(math.cos(a) * WR * breathe, math.sin(a) * WR * breathe, 0)).Position
			spokeBeams[i].Width0 = 0.05 + 0.1 * spreadE
		end
		-- a tap plucks the strands: a ripple runs from the hub outwards
		local pluckS = Sync.since(c.bus, "tap")
		for r, ring in ringAtts do
			local pluck = tapE * 0.1 * math.sin(pluckS * 30 - r * 1.3)
			local rr = WR * breathe * (r / (RINGS + 0.5)) * (1 + 0.04 * math.sin(t * 2 + r) + pluck)
			for i, att in ring do
				local a = (i - 1) / SPOKES * TAU
				-- strands sag slightly between spokes (alternating radius)
				local rad = rr * (if i % 2 == 0 then 0.96 else 1)
				att.Position = (frame * CF(math.cos(a) * rad, math.sin(a) * rad, 0)).Position
			end
		end
		-- the spider hunts on the idle clock: crawls out until "spread", then sprints home; it
		-- freezes dead still for a moment on every glance and every tap
		if cyc < lastCyc and reach < 0.1 then
			spokeK = rng:NextInteger(1, SPOKES)
		end
		lastCyc = cyc
		local homing = cyc >= RETURN0
		local frozen = Sync.since(c.bus, "tap") < 0.3 or Sync.since(c.bus, "glance") < 0.35
		local target = if homing then 0 else 1
		local speed = if frozen then 0 elseif homing then 3.2 else 0.42
		local prev = reach
		if reach < target then
			reach = math.min(target, reach + dt * speed)
		else
			reach = math.max(target, reach - dt * speed)
		end
		local vel = if dt > 0 then math.abs(reach - prev) / dt else 0
		gait += dt * (6 + vel * 30) * math.min(1, vel * 6)
		local f = smooth01(reach)
		local sa = (spokeK - 1) / SPOKES * TAU
		local lp = frame * CF(math.cos(sa) * WR * 0.85 * breathe * f, math.sin(sa) * WR * 0.85 * breathe * f, -0.08)
		local scf = root * lp * ANG(0, 0, sa - math.pi / 2 + (if homing then math.pi else 0))
		Core.put(abdomen, scf * CF(0, -0.28, 0))
		Core.put(cephal, scf * CF(0, 0.05, 0))
		Core.put(mark, scf * CF(0, -0.28, -0.2))
		for i, leg in legs do
			local sx = if i <= 4 then 1 else -1
			local j = (i - 1) % 4
			local step = math.sin(gait * 2.3 + i * 1.7) * 0.18 * math.min(1, vel * 6)
			-- legs splay wide while frozen (listening to the strands)
			local ang = (j - 1.5) * (0.45 + (if frozen then 0.18 else 0)) + step
			Core.put(leg, scf * CF(sx * 0.1, -0.05, 0) * ANG(0, 0, sx * ang) * CF(sx * 0.23, 0, 0))
		end
		spiderAtt.Position = lp.Position
		thread.Position = hub.Position
		for k, o in onions do
			local flash = math.max(glanceE, spreadE * 0.8)
			B.setBeamsTransparency(o.beams, (0.2 + 0.35 * Core.pulse(t, 2.4, k * 0.33)) * (1 - flash))
		end
		-- floor strands: pulse with the spread, twitch on each footfall
		for i, b in strandBeams do
			b.Width0 = 0.03 + 0.07 * spreadE
			b.Width1 = 0.05 + 0.1 * spreadE
			local tw = stepE * 0.5 * math.sin(t * 40 + i * 2.1)
			b.CurveSize0 = 0.6 + tw
			b.CurveSize1 = -0.4 - tw
			b.Transparency = if spreadE > 0.05 then NumberSequence.new(0.3 * (1 - spreadE), 0.7 * (1 - spreadE * 0.6))
				else strandT
		end
		if holdUrl > 0 then
			nextUrl = t + holdUrl
			holdUrl = 0
		elseif t >= nextUrl then
			nextUrl = t + 2
			onionLbl.Text = Core.pick(urls, rng)
		end
		local flick = Sync.window(c.bus, "glance", 0.35) >= 0 and math.sin(t * 90) > 0
		onionLbl.TextTransparency = if flick or math.noise(t * 4, 7.7) > 0.35 then 0.6 else 0
		onionLbl.TextColor3 = purple:Lerp(Color3.fromRGB(255, 60, 90), spreadE)
		light.Brightness += spreadE * 2.4 + glanceE * 0.8
	end)
end

-- spiky virus orbs replicating and splitting around the body
-- 40 parts / 11 emitters (body-synced: see the Sync block)
A.Virus = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local green = c.c1
	local pink = c.c2
	type Orb = { core: BasePart, shell: BasePart, spikes: { BasePart }, rot: Vector3 }
	local function makeOrb(): Orb
		local core = Core.part(c, V(0.5, 0.5, 0.5), green, NEON, 0, BALL)
		local shell = Core.part(c, V(0.72, 0.72, 0.72), pink, FF, 0, BALL)
		local spikes: { BasePart } = {}
		for k = 1, 3 do
			spikes[k] = Core.part(c, V(1.05, 0.07, 0.07), green:Lerp(WHITE, 0.25))
		end
		return { core = core, shell = shell, spikes = spikes, rot = rng:NextUnitVector() }
	end
	-- 4 lineages, each a mother + a daughter that buds off and splits away. Divisions are driven
	-- by the body (see the Sync block below); `born` = when the daughter re-budded inside the
	-- mother, `split` = when the current division started, `pinch` = when the cell started to wobble.
	type Line = {
		a: Orb,
		b: Orb,
		ang: number,
		y: number,
		r: number,
		born: number,
		split: number?,
		pinch: number?,
		last: number,
	}
	local lines: { Line } = {}
	local now0 = os.clock()
	for i = 1, 4 do
		lines[i] = {
			a = makeOrb(),
			b = makeOrb(),
			ang = (i - 1) / 4 * TAU,
			y = c.chestY - 0.8 + (i % 2) * 1.4,
			r = 2.9,
			born = now0 - i * 0.6,
			split = nil,
			pinch = nil,
			last = now0 - i * 0.9,
		}
	end
	local SPIKE_ROT = { CFrame.identity, ANG(0, 0, math.pi / 2), ANG(0, math.pi / 2, 0) }
	local function putOrb(o: Orb, cf: CFrame, s: number, t: number, tr: number)
		local spin = cf * CFrame.fromAxisAngle(o.rot, t * 1.4)
		o.core.Size = V(0.5, 0.5, 0.5) * s
		o.shell.Size = V(0.74, 0.74, 0.74) * s * (1 + 0.06 * math.sin(t * 6))
		Core.put(o.core, spin)
		Core.put(o.shell, spin)
		for k, sp in o.spikes do
			sp.Size = V(1.05 * s, 0.07 * s, 0.07 * s)
			Core.put(sp, spin * SPIKE_ROT[k])
			sp.Transparency = tr
		end
		o.core.Transparency = tr
		o.shell.Transparency = math.max(tr, 0.15)
	end
	-- infection membrane between the halves while splitting
	local bridges: { Beam } = {}
	local bA: { Attachment } = {}
	local bB: { Attachment } = {}
	for i = 1, 4 do
		bA[i] = Core.att(c)
		bB[i] = Core.att(c)
		bridges[i] = Core.beam(c, bA[i], bB[i], pink, 0.35, { w1 = 0.35, segs = 1, color2 = green })
	end
	-- floor: spreading infection sigil
	B.sigil(c, {
		radius = 4.4,
		color = green,
		color2 = pink,
		rings = 3,
		ticks = 12,
		tickSize = V(0.3, 0.06, 0.3),
		spin = -0.4,
		glow = 0.88,
		pulse = 1.6,
	})
	-- the infection ring: restarted by the body (coughs, divisions, footfalls), from wherever the
	-- infection came from; it also keeps spreading on its own when nothing happens
	local ringT0 = now0
	local ringDur = 1.6
	local ringMax = 4.2
	local ringAt = V(0, 0, 0) -- root-space floor point
	local spread = B.circle(c, {
		radius = 1,
		color = pink,
		width = 0.14,
		n = 8,
		anchor = function()
			return CF(ringAt.X, g + 0.06, ringAt.Z)
		end,
		radiusFn = function(t)
			return 0.4 + smooth01((t - ringT0) / ringDur) * ringMax
		end,
	})
	local _, inf = B.glyph(c, "", green, V2(2.6, 0.42), F.pixel, CF(0, c.topY + 1.3, 0), Color3.fromRGB(60, 0, 20))
	local splitA = Core.att(c)
	local spores = Core.emit(splitA, {
		tex = T.spark,
		color = cs(green, pink),
		size = ns(0.35, 0),
		rate = 0,
		life = nr(0.4, 0.8),
		speed = nr(2, 4),
		spread = V2(180, 180),
		drag = 2,
	})
	Core.emit(Core.volume(c, V(6.5, 0.1, 6.5), CF(0, g + 0.1, 0)), {
		tex = T.glow,
		color = cs(green, pink),
		size = ns(0.3, 0.6),
		transp = ns(0.3, 1),
		rate = 10,
		life = nr(1.4, 2.2),
		speed = nr(0.6, 1.2),
		shape = BOX,
	})
	local miasma = Core.emit(Core.att(c, c.torso), {
		tex = T.smoke,
		color = cs(green),
		size = ns(1.2, 2.6),
		transp = ns(0.88, 1),
		rate = 3,
		life = nr(1.5, 2.2),
		speed = nr(0.4, 0.8),
		spread = V2(180, 180),
		light = 0.5,
	})
	bodyGlow(c, green, 7, 0.85)
	local light = B.rootLight(c, green, 1.7, 14, { pulse = 1.6, amp = 1 })

	-- Synced to the Blender animation (tools/blender/anim/auras/Virus.py). The 4.0 s idle is the
	-- infection cycle: the host convulses ("twitch" f26/f31: the INFECTED counter glitches into
	-- garbage, every orb jitters, green specks fly off the head), doubles over coughing ("cough"
	-- f48/f54: a spore spray from the mouth, a fresh infection ring from the feet, lineages 2 and 4
	-- divide on the coughs), cups the virus in both hands ("pinch" f72: lineages 1 and 3 start
	-- wobbling) and rips the hands apart ("split" f84: those two divide on that frame, spark bursts
	-- from both hands, the light flares). Walking: each footfall ("step") leaves an infected
	-- footprint (specks + a small ring under that foot), the dragged left foot scrapes spores
	-- ("drag"), and a mid-stride head twitch glitches the counter. Lineages that the body has not
	-- divided for a while (walking, jumping) divide on their own, so the swarm never stalls.
	local tips: { [string]: Attachment? } = {
		mouth = Core.tip(c, "head", CF(0, -0.95, -0.55)),
		head = Core.tip(c, "head"),
		R = Core.tip(c, "rhand"),
		L = Core.tip(c, "lhand"),
		RF = Core.tip(c, "rfoot"),
		LF = Core.tip(c, "lfoot"),
	}
	local function tipEmit(key: string, spec: Core.EmitSpec): ParticleEmitter?
		local a = tips[key]
		return if a then Core.emit(a, spec) else nil
	end
	local cough = tipEmit("mouth", {
		tex = T.glow,
		color = cs(green:Lerp(WHITE, 0.2), pink),
		size = ns(0.3, 0.9),
		transp = ns(0.1, 1),
		rate = 0,
		life = nr(0.5, 0.9),
		speed = nr(6, 11),
		spread = V2(28, 28),
		drag = 5,
		accel = V(0, -2, 0),
		dir = Enum.NormalId.Front,
	})
	local coughSpecks = tipEmit("mouth", {
		tex = T.spark,
		color = cs(green, pink),
		size = ns(0.22, 0),
		rate = 0,
		life = nr(0.4, 0.8),
		speed = nr(7, 13),
		spread = V2(35, 35),
		drag = 4,
		dir = Enum.NormalId.Front,
	})
	local headSpecks = tipEmit("head", {
		tex = T.square,
		color = cs(green, pink),
		size = ns(0.16, 0),
		transp = ns(0, 1),
		rate = 0,
		life = nr(0.3, 0.6),
		speed = nr(2, 5),
		spread = V2(180, 180),
		drag = 4,
		rot = nr(0, 0),
		bright = 2.5,
	})
	local handFx: { [string]: ParticleEmitter } = {}
	for _, side in { "R", "L" } do
		local e = tipEmit(side, {
			tex = T.spark,
			color = cs(green:Lerp(WHITE, 0.3), pink),
			size = ns(0.3, 0),
			rate = 0,
			life = nr(0.35, 0.7),
			speed = nr(3, 7),
			spread = V2(180, 180),
			drag = 4,
			bright = 2.5,
		})
		if e then
			handFx[side] = e
		end
	end
	local footFx: { [string]: ParticleEmitter } = {}
	for _, side in { "R", "L" } do
		local e = tipEmit(side .. "F", {
			tex = T.glow,
			color = cs(green, pink),
			size = ns(0.25, 0.6),
			transp = ns(0.2, 1),
			rate = 0,
			life = nr(0.5, 0.9),
			speed = nr(0.8, 2),
			spread = V2(70, 70),
			drag = 3,
		})
		if e then
			footFx[side] = e
		end
	end

	local now = now0
	local hosts = 1
	local function divide(i: number)
		local ln = lines[i]
		if ln.split == nil then
			ln.split = now
			ln.pinch = nil
		end
	end
	local function restartRing(at: Vector3, max: number, dur: number)
		ringT0 = now
		ringAt = V(at.X, 0, at.Z)
		ringMax = max
		ringDur = dur
	end
	local function footAt(key: string): Vector3
		local a = tips[key]
		if not a then
			return Vector3.zero
		end
		return c.root.CFrame:PointToObjectSpace(a.WorldPosition)
	end
	local glitchUntil = 0
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("twitch", function()
		glitchUntil = now + 0.28
		if headSpecks then
			headSpecks:Emit(8)
		end
	end)
	onEv("cough", function()
		if cough then
			cough:Emit(16)
		end
		if coughSpecks then
			coughSpecks:Emit(14)
		end
		miasma:Emit(3)
		restartRing(Vector3.zero, 4.4, 1.3)
		-- the coughs infect lineages 2 and 4 in turn
		divide(if Sync.count(c.bus, "cough") % 2 == 1 then 2 else 4)
	end)
	onEv("pinch", function()
		for _, i in { 1, 3 } do
			if lines[i].split == nil then
				lines[i].pinch = now
			end
		end
	end)
	onEv("split", function()
		divide(1)
		divide(3)
		for _, e in handFx do
			e:Emit(16)
		end
		restartRing(Vector3.zero, 4.8, 1.1)
	end)
	onEv("drag", function()
		local e = footFx.L
		if e then
			e:Emit(4)
		end
	end)
	onEv("step", function(side)
		local key = if side == "L" then "L" else "R"
		local e = footFx[key]
		if e then
			e:Emit(6)
		end
		restartRing(footAt(key .. "F"), 1.6, 0.6)
	end)

	local glitchSet = "#$%&@!?01XZ"
	Core.on(c, function(t, _, root)
		now = os.clock()
		local twitchE = Sync.env(c.bus, "twitch", 9)
		local splitE = Sync.env(c.bus, "split", 3)
		local coughE = Sync.env(c.bus, "cough", 5)
		for i, ln in lines do
			-- autonomous fallback: a lineage the body has not divided for a while pinches, then splits
			if ln.split == nil then
				local idleFor = now - ln.last
				if idleFor > 4.6 + i * 0.35 and ln.pinch == nil then
					ln.pinch = now
				end
				local p = ln.pinch
				if p and now - p > 0.45 and idleFor > 4.6 + i * 0.35 then
					divide(i)
				end
			end
			local a = ln.ang + t * 0.35
			local yy = ln.y + math.sin(t * 1.1 + i) * 0.25
			local center = root * CF(math.cos(a) * ln.r, yy, math.sin(a) * ln.r)
			if twitchE > 0.05 then
				-- the convulsion shakes the whole swarm
				center += V(rng:NextNumber() - 0.5, rng:NextNumber() - 0.5, rng:NextNumber() - 0.5) * 0.5 * twitchE
			end
			-- tangent direction for splitting
			local tang = root:VectorToWorldSpace(V(-math.sin(a), 0, math.cos(a)))
			local grow = 0.65 + smooth01((now - ln.born) / 2.2) * 0.45
			local sep, fadeB = 0, 0
			local s = ln.split
			if s then
				local e = now - s
				sep = smooth01(e / 0.35) * 1.1 -- torn apart fast, like the hands
				fadeB = smooth01((e - 0.75) / 0.5)
				if e >= 0.06 and ln.last < s then
					-- the moment of division
					ln.last = now
					splitA.Position = root:PointToObjectSpace(center.Position)
					spores:Emit(12)
					hosts *= 2
					if hosts > 9999999 then
						hosts = 1
					end
				end
				if e > 1.25 then
					ln.split = nil
					ln.born = now -- the daughter re-buds inside the mother
					sep, fadeB = 0, 0
				end
			end
			-- wobble before splitting (cell pinching)
			local pinch = 0
			local pc = ln.pinch
			if pc and ln.split == nil then
				pinch = math.sin(t * 34) * 0.07 * math.min(1, (now - pc) * 4)
			end
			local sz = grow * (1 - sep * 0.15)
			putOrb(ln.a, center - tang * (sep * 0.5 + pinch), sz, t, 0)
			putOrb(ln.b, center + tang * (sep * 0.5 + pinch), sz * (1 - fadeB * 0.6), t + 1, fadeB)
			local splitting = sep > 0.02 and sep < 1.1 and fadeB < 0.9
			bA[i].Position = root:PointToObjectSpace(center.Position - tang * sep * 0.5)
			bB[i].Position = root:PointToObjectSpace(center.Position + tang * sep * 0.5)
			bridges[i].Enabled = splitting
			bridges[i].Width0 = 0.35 * (1 - math.min(1, sep / 1.1))
			bridges[i].Width1 = bridges[i].Width0
		end
		-- the ring keeps spreading by itself when the body gives it nothing
		if now - ringT0 > ringDur + 0.5 then
			restartRing(Vector3.zero, 4.2, 1.6)
		end
		local rp = math.clamp((now - ringT0) / ringDur, 0, 1)
		B.setBeamsTransparency(spread.beams, 0.1 + rp * 0.9)
		if now < glitchUntil then
			local s = ""
			for _ = 1, 9 do
				s ..= randChar(rng, glitchSet)
			end
			inf.Text = s
			inf.TextColor3 = if rng:NextNumber() > 0.5 then pink else WHITE
			inf.Rotation = (rng:NextNumber() - 0.5) * 10
		else
			inf.Text = string.format("INFECTED: %d", hosts)
			inf.TextColor3 = if splitE > 0.3 or math.sin(t * 6) > 0.6 then pink else green
			inf.Rotation = 0
		end
		light.Brightness += splitE * 2.2 + coughE * 0.8 + twitchE * 0.6
	end)
end

-- floating masks, falling red code, protest-sign style glitch banners
-- ~38 parts / 4 emitters / 6 code columns
A.Hacktivist = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local ivory = c.c1
	local red = c.c2
	local ink = Color3.fromRGB(15, 15, 18)
	local h = c.topY - g
	-- three blank theatre masks orbiting at head height, turned outward
	type Mask = { face: BasePart, eyes: { BasePart }, brows: { BasePart }, smile: BasePart, a: number }
	local masks: { Mask } = {}
	for k = 1, 3 do
		local face = Core.ellipsoid(c, V(0.95, 1.2, 0.35), ivory, SMOOTH)
		masks[k] = {
			face = face,
			eyes = { Core.part(c, V(0.2, 0.08, 0.06), ink, SMOOTH), Core.part(c, V(0.2, 0.08, 0.06), ink, SMOOTH) },
			brows = { Core.part(c, V(0.26, 0.04, 0.05), ink, SMOOTH), Core.part(c, V(0.26, 0.04, 0.05), ink, SMOOTH) },
			smile = Core.part(c, V(0.42, 0.04, 0.05), red),
			a = (k - 1) / 3 * TAU,
		}
	end
	-- banners: a board on a pole, with an RGB-split glitch copy
	type Banner = { board: BasePart, pole: BasePart, ghostR: BasePart, ghostC: BasePart, lbl: TextLabel, side: number }
	local banners: { Banner } = {}
	local slogans = { "EXPECT US", "FREE THE DATA", "NO MORE LIES", "WE SEE YOU", "OPEN SOURCE", "ACCESS DENIED?" }
	for k = 1, 2 do
		local board = Core.part(c, V(2, 1, 0.08), ivory, SMOOTH)
		local pole = Core.part(c, V(0.08, 2.2, 0.08), ink, METAL)
		local ghostR = Core.part(c, V(2, 1, 0.02), red, NEON, 0.55)
		local ghostC = Core.part(c, V(2, 1, 0.02), Color3.fromRGB(0, 230, 255), NEON, 0.6)
		local function face(n: Enum.NormalId): TextLabel
			local sg = Core.surface(board, n, 60)
			Core.frame(sg, red, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.1))
			Core.frame(sg, red, UDim2.fromScale(0, 0.9), UDim2.fromScale(1, 0.1))
			return Core.label(sg, slogans[k], ink, F.tech, UDim2.fromScale(0.06, 0.2), UDim2.fromScale(0.88, 0.6))
		end
		local lbl = face(Enum.NormalId.Front)
		face(Enum.NormalId.Back)
		banners[k] = {
			board = board,
			pole = pole,
			ghostR = ghostR,
			ghostC = ghostC,
			lbl = lbl,
			side = if k == 1 then 1 else -1,
		}
	end
	-- falling red code columns (billboards) around the player
	type Col = { att: Attachment, lbl: TextLabel, a: number, r: number, ph: number, spd: number }
	local cols: { Col } = {}
	for i = 1, 6 do
		local att, lbl = B.glyph(c, "", red, V2(0.35, 2.4), F.mono)
		lbl.TextWrapped = true
		lbl.LineHeight = 0.8
		cols[i] = {
			att = att,
			lbl = lbl,
			a = (i - 1) / 6 * TAU + 0.3,
			r = 3.4 + (i % 2) * 0.5,
			ph = rng:NextNumber(),
			spd = 0.35 + rng:NextNumber() * 0.25,
		}
	end
	B.sigil(c, {
		radius = 4.4,
		color = red,
		color2 = ivory,
		rings = 3,
		ticks = 10,
		spokes = 5,
		spin = 0.35,
		glow = 0.9,
	})
	-- red code rain from above (particles) and a megaphone-style shout glyph
	Core.emit(Core.volume(c, V(7, 0.2, 7), CF(0, c.topY + 3.5, 0)), {
		tex = T.square,
		color = cs(red, red:Lerp(WHITE, 0.3)),
		size = ns(0.12, 0.1),
		squash = ns(-1.4),
		transp = ns(0.1, 0.3, 1),
		rate = 22,
		life = nr(0.9, 1.3),
		speed = nr(6, 8),
		dir = Enum.NormalId.Bottom,
		rot = nr(0, 0),
		shape = BOX,
	})
	local _, shout = B.glyph(c, "", WHITE, V2(3, 0.48), F.tech, CF(0, c.topY + 1.4, 0), red)
	local shouts = { "EXPECT US", "WE ARE MANY", "#OPEN", "NO MASTERS", "RESIST.EXE" }
	Core.emit(Core.att(c, c.torso), {
		tex = T.spark,
		color = cs(WHITE, red),
		size = ns(0, 0.3, 0),
		rate = 7,
		life = nr(0.8, 1.3),
		speed = nr(0.6, 1.2),
		spread = V2(180, 180),
	})
	Core.emit(Core.volume(c, V(6, 0.1, 6), CF(0, g + 0.1, 0)), {
		tex = T.smoke,
		color = cs(ink:Lerp(red, 0.3)),
		size = ns(1.4, 2.8),
		transp = ns(0.6, 1),
		rate = 5,
		life = nr(1.8, 2.6),
		speed = nr(0.3, 0.6),
		light = 0.1,
		shape = BOX,
	})
	bodyGlow(c, red, 7, 0.87)
	local light = B.rootLight(c, red, 1.8, 14, { pulse = 1.2, amp = 0.9 })

	-- Synced to the Blender animation (tools/blender/anim/auras/Hacktivist.py, idle 5.2 s). The
	-- slogans change on the body's gestures instead of a timer: the raised FIST ("fist" f30, two
	-- "pump"s f38/f46) and the megaphone SHOUT ("shout" f86, a sound ring blasts from the mouth).
	-- "point" f62: the masks swing round in front of the body and stare where it points until the
	-- arms snap across the chest again ("cross" f110); "nod" f126: the masks nod with the head.
	-- Walking: "march" (the fist pump of each stride) bobs the banners, every 3rd one changes the
	-- slogan; "step" kicks red squares up from that foot.
	local tips: { [string]: Attachment? } = {
		hand = Core.tip(c, "rhand"),
		mouth = Core.tip(c, "head", CF(0, -0.8, -0.65)),
		chest = Core.tip(c, "chest", CF(0, 0, -0.55)),
		R = Core.tip(c, "rfoot"),
		L = Core.tip(c, "lfoot"),
	}
	local function tipEmit(name: string, spec: Core.EmitSpec): ParticleEmitter?
		local a = tips[name]
		return if a then Core.emit(a, spec) else nil
	end
	local handSpark = tipEmit("hand", {
		tex = T.spark,
		color = cs(WHITE, red),
		size = ns(0, 0.45, 0),
		rate = 0,
		life = nr(0.25, 0.5),
		speed = nr(4, 8),
		drag = 5,
		spread = V2(180, 180),
		bright = 3,
	})
	local handCode = tipEmit("hand", {
		tex = T.square,
		color = cs(red, red:Lerp(WHITE, 0.4)),
		size = ns(0.16, 0),
		squash = ns(-1.2),
		transp = ns(0, 1),
		rate = 0,
		life = nr(0.35, 0.7),
		speed = nr(5, 9),
		drag = 3,
		spread = V2(12, 12),
		rot = nr(0, 0),
		bright = 2.5,
	})
	local mouthFx = tipEmit("mouth", {
		tex = T.square,
		color = cs(WHITE, red),
		size = ns(0.2, 0),
		transp = ns(0, 1),
		rate = 0,
		life = nr(0.3, 0.6),
		speed = nr(6, 11),
		drag = 4,
		spread = V2(25, 25),
		rot = nr(0, 0),
		bright = 3,
	})
	local chestFx = tipEmit("chest", {
		tex = T.spark,
		color = cs(WHITE, ivory),
		size = ns(0, 0.3, 0),
		rate = 0,
		life = nr(0.2, 0.45),
		speed = nr(3, 5),
		drag = 4,
		spread = V2(180, 180),
	})
	local footFx: { [string]: ParticleEmitter? } = {}
	for _, side in { "R", "L" } do
		footFx[side] = tipEmit(side, {
			tex = T.square,
			color = cs(red, ink:Lerp(red, 0.5)),
			size = ns(0.15, 0),
			transp = ns(0.1, 1),
			rate = 0,
			life = nr(0.4, 0.8),
			speed = nr(1.2, 2.4),
			spread = V2(70, 70),
			rot = nr(0, 0),
		})
	end
	-- megaphone blast: two rings that fly out from the mouth on "shout"
	local blast: { B.Circle } = {}
	for k = 1, 2 do
		blast[k] = B.circle(c, {
			radius = 0.3,
			color = WHITE,
			color2 = red,
			width = 0.12,
			n = 8,
			tr = 1,
			anchor = function()
				local p = Sync.window(c.bus, "shout", 0.7)
				local q = if p < 0 then 1 else math.clamp(p * 1.25 - (k - 1) * 0.2, 0, 1)
				return CF(0, c.headY - 0.15, -0.9 - q * 3.2) * ANG(math.pi / 2, 0, 0)
			end,
			radiusFn = function()
				local p = Sync.window(c.bus, "shout", 0.7)
				local q = if p < 0 then 1 else math.clamp(p * 1.25 - (k - 1) * 0.2, 0, 1)
				return 0.35 + q * (1.8 - k * 0.3)
			end,
		})
	end
	local glitchKick = 0 -- seconds of banner glitch requested by an event (applied on the clock)
	local newSlogan = false
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("fist", function()
		newSlogan = true
		glitchKick = math.max(glitchKick, 0.3)
		if handSpark then
			handSpark:Emit(22)
		end
	end)
	onEv("pump", function()
		glitchKick = math.max(glitchKick, 0.12)
		if handSpark then
			handSpark:Emit(8)
		end
	end)
	onEv("point", function()
		if handCode then
			handCode:Emit(26)
		end
	end)
	onEv("shout", function()
		newSlogan = true
		glitchKick = math.max(glitchKick, 0.45)
		if mouthFx then
			mouthFx:Emit(30)
		end
	end)
	onEv("cross", function()
		if chestFx then
			chestFx:Emit(18)
		end
	end)
	onEv("march", function()
		if Sync.count(c.bus, "march") % 3 == 0 then
			newSlogan = true
			glitchKick = math.max(glitchKick, 0.2)
		end
	end)
	onEv("step", function(side)
		local e = footFx[side :: string]
		if e then
			e:Emit(5)
		end
	end)
	local nextShout = 0
	local glitchUntil = 0
	local nextCode = 0
	Core.on(c, function(t, _, root)
		local fistE = Sync.env(c.bus, "fist", 4)
		local pumpE = Sync.env(c.bus, "pump", 7)
		local shoutE = Sync.env(c.bus, "shout", 4)
		local marchE = Sync.env(c.bus, "march", 8)
		local nodE = Sync.env(c.bus, "nod", 3)
		-- stare: the masks line up in front of the body from "point" until "cross"
		local sp, sc = Sync.since(c.bus, "point"), Sync.since(c.bus, "cross")
		local stare = if sp < sc then smooth01(sp / 0.18) elseif sc < 0.7 then 1 - smooth01(sc / 0.7) else 0
		for k, m in masks do
			local a = m.a + t * 0.5
			local orbit = root
				* outward(a, 2.1, c.headY + 0.25 + math.sin(t * 1.3 + k * 2) * 0.18)
				* ANG(math.sin(t * 0.9 + k) * 0.12, math.sin(t * 0.7 + k) * 0.25, math.sin(t * 1.1 + k) * 0.1)
			local cf = orbit
			if stare > 0 then
				local d = k - 2
				local front = root
					* CF(d * 1.35, c.headY + 0.55 - math.abs(d) * 0.2 + math.sin(t * 2 + k) * 0.05, -2.2 + math.abs(d) * 0.4)
					* ANG(0, -d * 0.25, 0)
				cf = orbit:Lerp(front, stare)
			end
			cf *= ANG(-0.35 * nodE * math.sin(math.min(1, Sync.since(c.bus, "nod") * 2.5) * math.pi), 0, 0)
			Core.put(m.face, cf)
			local fr = cf * CF(0, 0, -0.17)
			Core.put(m.eyes[1], fr * CF(-0.2, 0.15, 0) * ANG(0, 0, -0.18))
			Core.put(m.eyes[2], fr * CF(0.2, 0.15, 0) * ANG(0, 0, 0.18))
			Core.put(m.brows[1], fr * CF(-0.2, 0.3, 0) * ANG(0, 0, 0.3))
			Core.put(m.brows[2], fr * CF(0.2, 0.3, 0) * ANG(0, 0, -0.3))
			Core.put(m.smile, fr * CF(0, -0.27, 0.01))
		end
		if glitchKick > 0 then
			glitchUntil = math.max(glitchUntil, t + glitchKick)
			glitchKick = 0
		elseif t >= glitchUntil + 1 and rng:NextNumber() < 0.02 then
			glitchUntil = t + 0.25
		end
		local glitch = t < glitchUntil
		local camDir, camRight = camAxes(root)
		for k, b in banners do
			-- held up behind the player like a march, swaying in rhythm
			-- they jump with the fist / shout, bob on each pump and each march step
			local jump = (fistE + shoutE) * 0.55 + pumpE * 0.25 + marchE * 0.18
			local sway = math.sin(t * 2.2 + k * 1.5) * 0.12 + b.side * shoutE * 0.15
			local p = -camDir * 1.4
				+ camRight * (b.side * 1.5)
				+ V(0, c.topY + 1 + math.abs(math.sin(t * 2.2 + k)) * 0.2 + jump, 0)
			local look = CFrame.lookAt(p, p + camDir) * ANG(0, 0, sway)
			local cf = root * look
			Core.put(b.board, cf)
			Core.put(b.pole, cf * CF(0, -1.4, 0.06))
			local j = if glitch then 0.18 else 0.04
			Core.put(b.ghostR, cf * CF(-j - rng:NextNumber() * j, rng:NextNumber() * 0.03, 0.05))
			Core.put(b.ghostC, cf * CF(j + rng:NextNumber() * j, -rng:NextNumber() * 0.03, 0.06))
			b.ghostR.Transparency = if glitch then 0.25 else 0.75
			b.ghostC.Transparency = if glitch then 0.3 else 0.8
		end
		if t >= nextCode then
			nextCode = t + 0.08
			for _, col in cols do
				local s = table.create(9)
				for i = 1, 9 do
					s[i] = if rng:NextNumber() < 0.5 then "1" else "0"
				end
				col.lbl.Text = table.concat(s, "\n")
			end
		end
		-- code columns flash white on the pumps and the fist
		local flash = math.max(pumpE, fistE * 0.8)
		for _, col in cols do
			local f = (t * col.spd + col.ph) % 1
			local a = col.a + t * 0.1
			col.att.Position = V(math.cos(a) * col.r, c.topY + 2.4 - f * (h + 3), math.sin(a) * col.r)
			col.lbl.TextTransparency = math.max(0, 1 - math.sin(f * math.pi) * 1.4 - flash)
			col.lbl.TextColor3 = red:Lerp(WHITE, flash)
		end
		-- slogans change on the gestures; the timer is only a fallback (airborne, reactions...)
		if newSlogan or t >= nextShout then
			newSlogan = false
			nextShout = t + 6
			shout.Text = Core.pick(shouts, rng)
			for _, b in banners do
				b.lbl.Text = Core.pick(slogans, rng)
			end
			glitchUntil = math.max(glitchUntil, t + 0.3)
		end
		local p = Sync.window(c.bus, "shout", 0.7)
		for _, ring in blast do
			B.setBeamsTransparency(ring.beams, if p < 0 then 1 else 0.1 + p * 0.9)
		end
		shout.TextTransparency = if glitch and math.sin(t * 50) > 0 then 0.6 else 0
		shout.TextColor3 = WHITE:Lerp(red, shoutE * 0.6)
		shout.Rotation = (rng:NextNumber() - 0.5) * 8 * shoutE
		light.Color = if glitch or shoutE > 0.5 then WHITE else red
		light.Brightness += (fistE + shoutE) * 2.2 + nodE * 1.2 + pumpE * 0.6
	end)
end

-- retro sun disc behind the player with stripes, neon grid floor, palm silhouettes
-- ~33 parts / 9 emitters / 1 sun SurfaceGui (body-synced at 120 BPM: see the Sync block)
A.Synthwave = function(c: Ctx)
	local g = c.groundY
	local pink = c.c1
	local cyan = c.c2
	local sunTop = Color3.fromRGB(255, 230, 90)
	local night = Color3.fromRGB(25, 6, 40)
	-- the sun: an invisible panel carrying a SurfaceGui of horizontal bars (chord widths)
	local SR = 2.4
	local panel = Core.part(c, V(SR * 2, SR * 2, 0.02), BLACK, SMOOTH, 1)
	local sg = Core.surface(panel, Enum.NormalId.Front, 40)
	sg.Brightness = 2.6
	local BARS = 26
	local bars: { Frame } = {}
	for i = 1, BARS do
		local f = Core.frame(sg, sunTop, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1 / BARS))
		bars[i] = f
	end
	local halo = Core.part(c, V(0.04, SR * 2.6, SR * 2.6), pink, NEON, 0.88, CYL)
	local horizon = Core.part(c, V(SR * 3.6, 0.07, 0.07), cyan)
	-- palms: curved trunk (3 segments) + 6 drooping fronds, dark silhouettes with a pink rim
	local PALM_SEG = 1.15
	type Palm = { trunk: { BasePart }, fronds: { BasePart }, side: number }
	local palms: { Palm } = {}
	for k = 1, 2 do
		local trunk: { BasePart } = {}
		for i = 1, 3 do
			trunk[i] = Core.part(c, V(0.2 - i * 0.03, PALM_SEG, 0.2 - i * 0.03), night, SMOOTH)
		end
		local fronds: { BasePart } = {}
		for i = 1, 6 do
			fronds[i] = Core.part(c, V(1.1, 0.06, 0.2), night, SMOOTH)
		end
		palms[k] = { trunk = trunk, fronds = fronds, side = if k == 1 then -1 else 1 }
	end
	-- neon grid floor scrolling towards the camera (beams)
	local GN = 7
	local GS = 1.2
	local gx: { { Attachment } } = {}
	local gz: { { Attachment } } = {}
	local gridBeams: { Beam } = {}
	local fade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.15),
		NumberSequenceKeypoint.new(0.75, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	for i = 1, GN do
		gx[i] = { Core.att(c), Core.att(c) }
		gz[i] = { Core.att(c), Core.att(c) }
		table.insert(gridBeams, Core.beam(c, gx[i][1], gx[i][2], pink, 0.07, { segs = 1, tr = fade }))
		table.insert(gridBeams, Core.beam(c, gz[i][1], gz[i][2], cyan, 0.07, { segs = 1, tr = fade }))
	end
	B.circle(c, { radius = 4.4, color = pink, width = 0.12, at = CF(0, g + 0.04, 0), tr = 0.25 })
	B.circle(c, { radius = 4.8, color = cyan, width = 0.06, at = CF(0, g + 0.04, 0), tr = 0.45 })
	local floorGlow = Core.part(c, V(0.04, 8.8, 8.8), night:Lerp(pink, 0.35), NEON, 0.86, CYL)
	-- chrome "1986" lettering over the head
	local _, year, yearGui = B.glyph(c, "1986", sunTop, V2(2.2, 0.6), F.pixel, CF(0, c.topY + 1.25, 0), pink)
	local yearSize = yearGui.Size
	Core.emit(Core.volume(c, V(8, 0.1, 8), CF(0, g + 0.1, 0)), {
		tex = T.spark,
		color = cs(pink, cyan),
		size = ns(0, 0.3, 0),
		rate = 10,
		life = nr(1.4, 2.2),
		speed = nr(0.6, 1.2),
		shape = BOX,
	})
	Core.emit(Core.att(c, c.torso), {
		tex = T.glow,
		color = cs(pink, cyan),
		size = ns(0.5, 1.2),
		transp = ns(0.6, 1),
		rate = 4,
		life = nr(1, 1.6),
		speed = nr(0.4, 0.9),
		spread = V2(180, 180),
	})
	local starsVol = Core.volume(c, V(9, 3, 1), CF(0, c.topY + 3, 2.5))
	local stars = Core.emit(starsVol, {
		tex = T.spark,
		color = cs(WHITE, cyan),
		size = ns(0, 0.18, 0),
		rate = 6,
		life = nr(1.5, 2.5),
		speed = nr(0),
		shape = BOX,
		shapeStyle = VOLUME,
	})
	bodyGlow(c, pink, 7, 0.86)
	local LIGHT = 1.8
	local light = B.rootLight(c, pink, LIGHT, 15)

	-- Synced to the Blender animation (tools/blender/anim/auras/Synthwave.py). The track runs at
	-- 120 BPM on the bus clock: one beat = 0.5 s (Sync.phase(bus, 0.5)), the idle is one 8-beat
	-- phrase of 4.0 s (Sync.phase(bus, 4)). On every head nod ("beat") the "1986" chrome pops, the
	-- sun halo throbs and the grid flashes; every bar downbeat the left foot taps ("tap") and a
	-- neon ring ripples out from it. The finger gun ("point" f45) fires a cyan laser streak from
	-- the right hand, the horizon sweep (f60-75, ends on "sweep") trails sparkles from the hand and
	-- the sun swells and flares when it lands (palms rustle, stars sparkle), the shades push
	-- ("shades" f90) glints a star on the face and shimmers the chrome. Walking: a beat on every
	-- footfall and a small ripple under that foot ("step").
	local BEAT = 0.5
	local PHRASE = 4.0
	local SWEEP0, SWEEP1 = 60 / 120, 75 / 120 -- the horizon sweep inside the phrase
	local tips: { [string]: Attachment? } = {
		R = Core.tip(c, "rhand"),
		RF = Core.tip(c, "rfoot"),
		LF = Core.tip(c, "lfoot"),
		face = Core.tip(c, "head", CF(0.28, -0.42, -0.62)),
	}
	local laser: ParticleEmitter? = nil
	local trail: ParticleEmitter? = nil
	local handA = tips.R
	if handA then
		-- the hand tip's -Y runs along the arm, so "Bottom" shoots where the finger points
		laser = Core.emit(handA, {
			tex = T.spark,
			color = cs(WHITE, cyan),
			size = ns(0.45, 0.1),
			rate = 0,
			life = nr(0.25, 0.4),
			speed = nr(26, 34),
			spread = V2(3, 3),
			squash = ns(-1.4),
			orient = Enum.ParticleOrientation.VelocityParallel,
			bright = 3,
			dir = Enum.NormalId.Bottom,
		})
		trail = Core.emit(handA, {
			tex = T.spark,
			color = cs(sunTop, pink),
			size = ns(0.32, 0),
			rate = 0,
			life = nr(0.4, 0.8),
			speed = nr(0.3, 1),
			spread = V2(180, 180),
			drag = 2,
			bright = 2.5,
		})
	end
	local handBurst = if handA
		then Core.emit(handA, {
			tex = T.glow,
			color = cs(cyan, WHITE),
			size = ns(0.6, 0),
			rate = 0,
			life = nr(0.2, 0.35),
			speed = nr(2, 5),
			spread = V2(180, 180),
			drag = 5,
			bright = 3,
		})
		else nil
	local faceA = tips.face
	local glint = if faceA
		then Core.emit(faceA, {
			tex = T.spark,
			color = cs(WHITE),
			size = ns(0, 1.5, 0),
			rate = 0,
			life = nr(0.45, 0.45),
			speed = nr(0),
			rot = nr(0, 0),
			rotSpeed = nr(140, 140),
			bright = 4,
			zoff = 1,
		})
		else nil
	-- floor ripple: restarted from the tapping / stepping foot
	local ringT0 = -math.huge
	local ringMax = 2.6
	local ringDur = 0.7
	local ringAt = Vector3.zero
	local lastRoot = CFrame.identity
	local ripple = B.circle(c, {
		radius = 0.3,
		color = cyan,
		color2 = pink,
		width = 0.1,
		n = 8,
		anchor = function()
			return CF(ringAt.X, g + 0.07, ringAt.Z)
		end,
		radiusFn = function()
			return 0.3 + smooth01((os.clock() - ringT0) / ringDur) * ringMax
		end,
	})
	B.setBeamsTransparency(ripple.beams, 1)
	local function rippleFrom(key: string, max: number, dur: number)
		local a = tips[key]
		local p = if a then lastRoot:PointToObjectSpace(a.WorldPosition) else Vector3.zero
		ringAt = V(p.X, 0, p.Z)
		ringT0 = os.clock()
		ringMax = max
		ringDur = dur
	end
	local function onEv(name: string, fn: (any) -> ())
		table.insert(c.cleanups, Sync.on(c.bus, name, fn))
	end
	onEv("tap", function()
		rippleFrom("LF", 2.8, 0.75)
	end)
	onEv("step", function(side)
		rippleFrom(if side == "L" then "LF" else "RF", 1.5, 0.45)
	end)
	onEv("point", function()
		if laser then
			laser:Emit(10)
		end
		if handBurst then
			handBurst:Emit(8)
		end
	end)
	onEv("sweep", function()
		if trail then
			trail:Emit(14)
		end
		stars:Emit(12)
	end)
	onEv("shades", function()
		if glint then
			glint:Emit(1)
		end
	end)

	local function beatEnv(): number
		-- the head nod: sharp attack on the beat, decays through the half beat (bus clock)
		local walking = Sync.get(c.bus, "move") > 0.5
		if walking then
			return Sync.env(c.bus, "beat", 6)
		end
		local p = Sync.phase(c.bus, BEAT)
		return math.exp(-p * BEAT * 6)
	end
	Core.on(c, function(t, _, root)
		lastRoot = root
		local camDir, camRight = camAxes(root)
		local beat = beatEnv()
		local phrase = Sync.phase(c.bus, PHRASE)
		local sweepE = Sync.env(c.bus, "sweep", 2.2)
		local pointE = Sync.env(c.bus, "point", 7)
		local shadesE = Sync.env(c.bus, "shades", 4)
		local sweeping = phrase >= SWEEP0 and phrase < SWEEP1 and Sync.get(c.bus, "move") < 0.5
		if trail then
			trail.Rate = if sweeping then 45 else 0
		end
		-- sun sits behind the player, facing the camera; it swells when the sweep unveils it
		local swell = 1 + 0.16 * sweepE + 0.035 * beat
		local sc = -camDir * 2.6 + V(0, c.chestY + 1.3 + math.sin(t * 0.4) * 0.1 + 0.25 * sweepE, 0)
		local sunCF = CFrame.lookAt(sc, sc + camDir)
		panel.Size = V(SR * 2 * swell, SR * 2 * swell, 0.02)
		Core.put(panel, root * sunCF)
		halo.Size = V(0.04, SR * 2.6 * swell * (1 + 0.06 * beat), SR * 2.6 * swell * (1 + 0.06 * beat))
		Core.put(halo, root * sunCF * CF(0, 0, 0.05) * FACE_X)
		halo.Transparency = 0.9 - 0.08 * beat - 0.3 * sweepE
		sg.Brightness = 2.6 + 1.6 * sweepE + 0.4 * beat
		-- bars: full chords on top, lower half sliced by gaps that scroll downward
		local scroll = (t * 0.25) % 1
		for i, f in bars do
			local v = (i - 0.5) / BARS -- 0 top .. 1 bottom
			local yy = 1 - 2 * v
			local w = math.sqrt(math.max(0, 1 - yy * yy))
			local show = true
			local hgt = 1 / BARS
			if v > 0.45 then
				-- gaps grow toward the bottom and drift down
				local band = ((v - 0.45) * 7 - scroll) % 1
				local gap = 0.2 + (v - 0.45) * 1.1
				show = band > gap
			end
			f.Visible = show and w > 0.02
			f.Size = UDim2.fromScale(w, hgt * 1.02)
			f.Position = UDim2.fromScale((1 - w) / 2, (i - 1) / BARS)
			f.BackgroundColor3 = sunTop:Lerp(pink, smooth01(v * 1.15)):Lerp(WHITE, sweepE * 0.35)
		end
		Core.put(horizon, root * sunCF * CF(0, -SR * 0.95 * swell, -0.1))
		horizon.Color = cyan:Lerp(WHITE, sweepE * 0.6 + beat * 0.2)
		-- palms flank the sun; they rustle when the sweep lands
		local gust = sweepE * 0.12
		for _, pm in palms do
			-- rooted on the floor beside the sun, leaning outward, swaying gently
			local base = root * sunCF * CF(pm.side * (SR * swell + 0.7), g - sc.Y, -0.3)
			local bend = pm.side * (0.12 + 0.025 * math.sin(t * 0.9 + pm.side) + gust * math.sin(t * 9))
			local cf = base
			for _, seg in pm.trunk do
				cf = cf * ANG(0, 0, -bend) * CF(0, PALM_SEG / 2, 0)
				Core.put(seg, cf)
				cf = cf * CF(0, PALM_SEG / 2, 0)
			end
			local crown = cf
			for i, fr in pm.fronds do
				local a = (i - 1) / 6 * TAU
				local droop = 0.55 + 0.08 * math.sin(t * 1.4 + i) + gust * 1.5 * math.sin(t * 13 + i)
				Core.put(fr, crown * ANG(0, a, 0) * ANG(0, 0, -droop) * CF(0.5, 0, 0))
			end
		end
		-- grid: lines along camRight scroll toward the camera, flashing on the beat
		local half = (GN - 1) / 2 * GS
		local s = (t * 1.2) % GS
		for i = 1, GN do
			local d = (i - 1) * GS - half
			local depth = d + s - GS / 2
			local p0 = camDir * depth + camRight * -half + V(0, g + 0.06, 0)
			local p1 = camDir * depth + camRight * half + V(0, g + 0.06, 0)
			gx[i][1].Position = p0
			gx[i][2].Position = p1
			gz[i][1].Position = camRight * d + camDir * -half + V(0, g + 0.06, 0)
			gz[i][2].Position = camRight * d + camDir * half + V(0, g + 0.06, 0)
		end
		local gw = 0.07 + 0.05 * beat + 0.05 * sweepE
		for _, b in gridBeams do
			b.Width0 = gw
			b.Width1 = gw
		end
		Core.put(floorGlow, root * CF(0, g + 0.02, 0) * FLAT)
		floorGlow.Transparency = 0.86 - 0.06 * beat
		-- floor ripple from the tapping / stepping foot
		local rp = (os.clock() - ringT0) / ringDur
		B.setBeamsTransparency(ripple.beams, if rp < 1 then 0.15 + 0.85 * smooth01(rp) else 1)
		-- beat-synced chrome text: pops on the nod, kicks on the finger gun, shimmers on the shades
		local pop = 1 + 0.14 * beat + 0.25 * pointE
		yearGui.Size = UDim2.new(yearSize.X.Scale * pop, 0, yearSize.Y.Scale * pop, 0)
		local shimmer = shadesE * (0.5 + 0.5 * math.sin(t * 30))
		year.TextColor3 = sunTop:Lerp(WHITE, beat * 0.6):Lerp(cyan, shimmer * 0.7)
		year.Rotation = math.sin(t * 1.3) * 3 + pointE * 8
		light.Brightness = LIGHT + 0.6 * beat + 1.6 * sweepE + 0.8 * pointE
	end)
end

return A
