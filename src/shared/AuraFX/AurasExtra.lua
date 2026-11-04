--!strict
-- AuraFX/AurasExtra: the 18 extra small auras (BASIC / ENHANCED / RARE).
-- Same conventions and budgets as AurasLow / AurasMid:
--   Basic    ~2.5-3.5 stud radius, subtle but readable, root light + soft body glow.
--   Enhanced ~3-4.5 stud radius, one silhouette-breaking element + particles.
--   Rare     ~4-5 stud radius, layered: ground sigil, body element, sky/overhead element.

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
			nextClick = os.clock() + i * 0.7,
			click = -10,
		}
	end
	-- click ripples (camera-facing beam circles), reused round-robin
	type Rip = { circ: B.Circle, t0: number, at: CFrame }
	local rips: { Rip } = {}
	for k = 1, 3 do
		local rip: Rip = { circ = nil :: any, t0 = -10, at = CF(0, -50, 0) }
		rip.circ = B.circle(c, {
			radius = 0.2,
			color = c.c1,
			width = 0.06,
			n = 6,
			anchor = function()
				return rip.at
			end,
			radiusFn = function(t)
				return 0.15 + math.min(1, (t - rip.t0) / 0.45) * 0.75
			end,
		})
		rips[k] = rip
	end
	local ripN = 0
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
	local sparks = Core.emit(ca, {
		tex = T.spark,
		color = cs(WHITE, c.c1),
		size = ns(0.2, 0),
		rate = 0,
		life = nr(0.3, 0.5),
		speed = nr(1, 2),
		spread = V2(180, 180),
	})
	bodyGlow(c, WHITE, 5, 0.93)
	local light = rootLight(c, WHITE, 0.9, 9, g + 1.4)
	Core.on(c, function(t, _, root)
		local cam = camPos()
		for _, cu in curs do
			cu.a += 0.006
			local press = math.clamp(1 - (t - cu.click) / 0.18, 0, 1)
			if t >= cu.nextClick then
				cu.nextClick = t + 1.6 + rng:NextNumber() * 1.8
				cu.click = t
				ripN = ripN % #rips + 1
				local rip = rips[ripN]
				rip.t0 = t
				local lp = V(math.cos(cu.a) * (cu.r - 0.3), cu.y, math.sin(cu.a) * (cu.r - 0.3))
				local wp = root:PointToWorldSpace(lp)
				rip.at = root:ToObjectSpace(CFrame.lookAt(wp, cam) * ANG(math.pi / 2, 0, 0))
				ca.Position = lp
				sparks:Emit(3)
			end
			local r = cu.r - press * 0.3
			local pos = root:PointToWorldSpace(
				V(math.cos(cu.a) * r, cu.y + math.sin(t * 1.7 + cu.a) * 0.15, math.sin(cu.a) * r)
			)
			local base = (if (cam - pos).Magnitude > 0.1 then CFrame.lookAt(pos, cam) else CF(pos)) * FACE_X
			-- classic pointer: tip up-left, tilted ~25 deg
			local cf = base * ANG(-0.42, 0, 0) * CF(0, -S * 0.5 - press * 0.08, 0)
			putTri(cu.edge, cf * CF(-0.03, -S * 0.1, 0))
			putTri(cu.fill, cf * CF(0, 0, 0))
			Core.put(cu.stem, cf * CF(0.01, -S * 0.2, 0))
			Core.put(cu.stemE, cf * CF(-0.02, -S * 0.22, 0))
		end
		for _, rip in rips do
			local f = (t - rip.t0) / 0.45
			B.setBeamsTransparency(rip.circ.beams, if f > 1 then 1 else 0.1 + f * 0.9)
		end
		local hb = 2.2 + math.sin(t * 0.9) * 0.15
		local rot = t * 0.12
		for k, a in corners do
			local ang = rot + (k - 1) * math.pi / 2 + math.pi / 4
			local p = V(math.cos(ang) * hb * math.sqrt(2), g + 0.05, math.sin(ang) * hb * math.sqrt(2))
			a.Position = p
			Core.put(handles[k], root * CF(p) * ANG(0, -ang, 0))
		end
		if t >= tipUntil + 3 and rng:NextNumber() < 0.01 then
			tipUntil = t + 1.4
			tip.Text = Core.pick(tips, rng)
		end
		tipGui.Enabled = t < tipUntil
		light.Brightness = 0.8 + Core.pulse(t, 2.6) * 0.5
	end)
end

-- spinning loading-circle segments around the waist and a progress bar above head
-- 30 parts / 3 emitters
A.Loading = function(c: Ctx)
	local rng = c.rng
	local g = c.groundY
	local y = -0.2
	local N = 12
	B.ring(c, {
		n = N,
		radius = 2.4,
		seg = V(0.22, 0.42, 0.42),
		color = c.c1,
		anchor = function()
			return CF(0, y, 0)
		end,
		paint = function(k, t, p)
			local head = (t * 9) % N
			local d = (head - (k - 1)) % N
			p.Transparency = math.min(0.92, d / N * 1.1)
			p.Size = V(0.22, 0.42 - d * 0.018, 0.42)
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
	bodyGlow(c, c.c1, 5.5, 0.9)
	local light = rootLight(c, c.c1, 1.1, 10, y)
	local prog = 0
	local stall = 0
	local hold = 0
	local labels = { "LOADING", "BUFFERING", "PLEASE WAIT", "ALMOST..." }
	local lab = labels[1]
	Core.on(c, function(t, dt, root)
		-- progress: fast start, stalls at 99 %, then completes and restarts
		if hold > 0 then
			hold -= dt
			if hold <= 0 then
				prog = 0
				lab = Core.pick(labels, rng)
			end
		elseif prog < 0.99 then
			local sp = if prog < 0.6 then 0.35 else 0.12
			if t < stall then
				sp = 0
			elseif rng:NextNumber() < 0.01 then
				stall = t + 0.4 + rng:NextNumber() * 0.8
			end
			prog = math.min(0.99, prog + dt * sp * (0.5 + rng:NextNumber()))
		elseif rng:NextNumber() < 0.012 then
			prog = 1
			hold = 1.1
			done:Emit(18)
		end
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
		fill.Color = if prog >= 1 then WHITE else c.c1
		local sx = ((t * 0.8) % 1) * w
		Core.put(shine, base * CF(-BW / 2 + sx, 0, -0.03))
		shine.Transparency = if w > 0.2 then 0.25 else 1
		pct.Text = if prog >= 1 then "DONE!" else string.format("%s %d%%", lab, math.floor(prog * 100))
		shed.Rate = if prog >= 1 then 0 else 5
		light.Brightness = if prog >= 1 then 2.4 else 0.9 + Core.pulse(t, 1.3) * 0.4
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
	local CYCLE = 5
	local lastCyc = -1
	local lastStep = -1
	local popped = -1
	local order = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
	Core.on(c, function(t, _, root)
		local cyc = math.floor(t / CYCLE)
		local ph = t % CYCLE
		if cyc ~= lastCyc then
			lastCyc = cyc
			for i = 9, 2, -1 do
				local j = rng:NextInteger(1, i)
				order[i], order[j] = order[j], order[i]
			end
			for _, tl in tiles do
				tl.sel = false
			end
			lastStep = -1
		end
		-- select 3-4 tiles one by one, then verify
		local step = math.floor(ph / 0.6)
		if step ~= lastStep and step >= 1 and step <= 4 then
			lastStep = step
			local tl = tiles[order[step]]
			tl.sel = true
			tl.flip = t
		end
		local verified = ph > 3.1 and ph < 4.6
		-- the 3x3 panel orbits the body, tilting gently; tiles breathe apart a little
		local panel = root * outward(t * 0.45, R, y + math.sin(t * 0.9) * 0.15) * ANG(math.sin(t * 0.7) * 0.12, 0, 0)
		local gap = 0.72 + 0.04 * math.sin(t * 2)
		for i, tl in tiles do
			local col = (i - 1) % 3
			local row = math.floor((i - 1) / 3)
			local fl = math.clamp((t - tl.flip) / 0.3, 0, 1)
			local cf = panel * CF((col - 1) * gap, (1 - row) * gap, 0) * ANG(fl * math.pi, 0, 0)
			Core.put(tl.p, cf)
			Core.put(tl.edge, cf * CF(0, 0, 0.03))
			tl.p.Color = if tl.sel then blue else blue:Lerp(BLACK, 0.55)
			tl.edge.Transparency = if tl.sel then (if verified then 0 else 0.15) else 0.75
			-- floor grid mirrors the selection
			local fx, fz = (col - 1) * 0.95, (row - 1) * 0.95
			Core.put(floor[i], root * CF(fx, g + 0.03, fz))
			floor[i].Transparency = if tl.sel then 0.2 else 0.78
			floor[i].Color = if verified and tl.sel then WHITE else blue
		end
		-- check mark pops in with an overshoot, then shrinks away
		local cs_ = if verified then popIn((ph - 3.1) / 0.35) * (1 - smooth01((ph - 4.3) / 0.3)) else 0
		if verified and popped ~= cyc then
			popped = cyc
			pop:Emit(16)
		end
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
		robot.Text = if verified then "VERIFIED" else "I'M NOT A ROBOT"
		robot.TextColor3 = if verified then Color3.fromRGB(120, 255, 160) else WHITE
		light.Brightness = (if verified then 2 else 0.9) + Core.pulse(t, 2) * 0.3
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
	end
	for i = 1, 8 do
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
		local f: Face = {
			att = att,
			gui = gui,
			face = face,
			mouth = mouth,
			eyes = { e1, e2 },
			a = rng:NextNumber() * TAU,
			r = 1.6 + rng:NextNumber() * 1.2,
			per = 3.2 + rng:NextNumber() * 1.4,
			ph = i / 8,
			spin = (rng:NextNumber() - 0.5) * 60,
			cyc = -1,
		}
		mood(f)
		faces[i] = f
	end
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
	B.circle(c, { radius = 2.8, color = sun, width = 0.1, at = CF(0, g + 0.04, 0), tr = 0.35, n = 8 })
	B.circle(c, { radius = 2.4, color = warm, width = 0.05, at = CF(0, g + 0.04, 0), tr = 0.55, n = 8 })
	local glow = Core.part(c, V(0.04, 5.2, 5.2), sun, NEON, 0.93, CYL)
	Core.emit(Core.volume(c, V(4, 0.1, 4), CF(0, g + 0.1, 0)), {
		tex = T.spark,
		color = cs(sun, WHITE),
		size = ns(0, 0.26, 0),
		rate = 6,
		life = nr(1.2, 1.8),
		speed = nr(0.8, 1.4),
		shape = BOX,
	})
	local ha = Core.att(c, c.head)
	Core.emit(ha, {
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
	Core.on(c, function(t, _, root)
		for _, f in faces do
			local u = t / f.per + f.ph
			local ph = u % 1
			if math.floor(u) ~= f.cyc then
				f.cyc = math.floor(u)
				mood(f)
				f.a = rng:NextNumber() * TAU
			end
			local a = f.a + ph * 1.3
			f.att.Position = V(math.cos(a) * f.r, g + 0.4 + ph * span, math.sin(a) * f.r)
			local s = 0.45 + smooth01(ph * 4) * 0.55 + math.sin(ph * math.pi * 6) * 0.04
			f.gui.Size = UDim2.new(0.8 * s, 0, 0.8 * s, 0)
			local fade = smooth01((ph - 0.7) / 0.3)
			f.face.BackgroundTransparency = fade
			f.mouth.TextTransparency = fade
			for _, e in f.eyes do
				e.BackgroundTransparency = fade
			end
			f.face.Rotation = math.sin(t * 2 + f.ph * 9) * 12 + f.spin * ph
		end
		for i, b in bubbles do
			b.Transparency = 0.1 + 0.4 * Core.pulse(t, 1.4, i * 0.17)
		end
		Core.put(glow, root * CF(0, g + 0.02, 0) * FLAT)
		light.Brightness = 1 + Core.pulse(t, 2.4) * 0.5
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
	local rng = c.rng
	local g = c.groundY
	local green = c.c1
	local blue = c.c2
	local tape = green:Lerp(WHITE, 0.55)
	local h = c.topY - g
	-- two helical bandage strips winding up the body (plates follow the helix tangent)
	local STRIP = 13
	type Plate = { p: BasePart, k: number, s: number }
	local plates: { Plate } = {}
	for s = 1, 2 do
		for k = 1, STRIP do
			local col = if k % 4 == 0 then blue else (if k % 2 == 0 then green else tape)
			table.insert(plates, { p = Core.part(c, V(0.05, 0.3, 0.62), col, NEON, 0.25), k = k, s = s })
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
		anchor = function(t)
			return CF(0, g + ((t / 2.4) % 1) * (h + 0.6), 0)
		end,
		radiusFn = function(t)
			return 1.9 - ((t / 2.4) % 1) * 0.5
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
	bodyGlow(c, green, 6.5, 0.88)
	local light = rootLight(c, green, 1.4, 12)
	local nextNote = 0
	local ver = 1
	Core.on(c, function(t, _, root)
		local wind = t * 0.35 -- strips crawl upward as if being wrapped
		for _, pl in plates do
			local f = ((pl.k - 1) / STRIP + wind) % 1
			local turns = 2.2
			local a = f * turns * TAU + (pl.s - 1) * math.pi + t * 0.3 * (if pl.s == 1 then 1 else -1)
			local y = g + 0.35 + f * (h - 0.2)
			local r = 1.25 + math.sin(f * math.pi) * 0.25
			-- tangent of the helix sets the plate's tilt
			local tilt = math.atan2(h / turns, TAU * r) * (if pl.s == 1 then 1 else -1)
			Core.put(pl.p, root * ANG(0, -a, 0) * CF(r, y, 0) * ANG(tilt, 0, 0))
			local edge = math.min(f, 1 - f) * 8
			pl.p.Transparency = 1 - math.min(1, edge) * 0.8
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
		local fcf = root * CF(0, g + 0.03, 0) * ANG(0, t * 0.2, 0)
		Core.put(crossA, fcf)
		Core.put(crossB, fcf)
		local beat = Core.pulse(t, 2.4)
		crossA.Transparency = 0.7 - beat * 0.3
		crossB.Transparency = crossA.Transparency
		B.setBeamsTransparency(heal.beams, 0.15 + ((t / 2.4) % 1) * 0.8)
		if t >= nextNote then
			nextNote = t + 1.4
			local s = Core.pick(logs, rng)
			if string.find(s, "%%d") then
				ver += 1
				s = string.format(s, ver)
			end
			notes.Text = s
			healBurst:Emit(6)
		end
		light.Brightness = 1.2 + beat * 1
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
	type Arrow = { a: BasePart, b: BasePart, line: number, nextStep: number }
	local arrows: { Arrow } = {}
	for k = 1, 2 do
		arrows[k] = {
			a = Core.part(c, V(0.36, 0.1, 0.08), yel),
			b = Core.part(c, V(0.36, 0.1, 0.08), yel),
			line = 1 + (k - 1) * 12,
			nextStep = 0,
		}
		Core.trail(arrows[k].a, yel, 0.1, 0.25, red)
	end
	B.circle(c, { radius = 3.2, color = yel, width = 0.1, at = CF(0, g + 0.04, 0), tr = 0.3 })
	B.ring(c, {
		n = 20,
		radius = 3.55,
		gap = 4,
		seg = V(0.12, 0.05, 0),
		color = red,
		spin = -0.3,
		anchor = function()
			return CF(0, g + 0.04, 0)
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
	Core.on(c, function(t, _, root)
		local paused = t < pauseUntil
		for i, d in dashes do
			Core.put(d, root * pathCF(i, t))
		end
		for k, ln in bpLines do
			local cf = root * pathCF(ln, t) * CF(0, 0, -0.25)
			Core.put(bps[k], cf)
			local hot = paused and hitBp == k
			local s = if hot then 0.5 + 0.15 * math.sin(t * 20) else 0.32
			bps[k].Size = V(s, s, s)
			Core.put(bpRings[k], cf * ANG(0, math.pi / 2, 0) * ANG(t * 3, 0, 0))
			bpRings[k].Transparency = if hot then 0 else 0.55
		end
		for _, ar in arrows do
			if not paused and t >= ar.nextStep then
				-- step over: hop one line, pausing on breakpoints
				ar.nextStep = t + 0.16
				ar.line = ar.line % LINES + 1
				local k = isBp[ar.line]
				if k then
					pauseUntil = t + 0.9
					hitBp = k
					hitA.Position = (pathCF(ar.line, t) * CF(0, 0, -0.25)).Position
					hit:Emit(14)
					status.Text = string.format("BREAK @ line %d", 40 + ar.line)
				end
			end
			local cf = root * pathCF(ar.line, t) * CF(0, 0, -0.42)
			local wob = if paused then math.sin(t * 16) * 0.05 else 0
			-- chevron ">" pointing along the path
			Core.put(ar.a, cf * CF(wob, 0.09, 0) * ANG(0, 0, -0.65))
			Core.put(ar.b, cf * CF(wob, -0.09, 0) * ANG(0, 0, 0.65))
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
		statusGui.Enabled = paused and math.sin(t * 14) > -0.5
		lineNo.Text = string.format("ln %02d  col %02d", 40 + arrows[1].line, (arrows[1].line * 7) % 80 + 1)
		light.Color = if paused then red else yel
		light.Brightness = if paused then 2.2 else 1 + Core.pulse(t, 0.6) * 0.3
	end)
end

-- orange flames shaped like wrench icons, hot sparks
-- 31 parts / 5 emitters
A.Hotfix = function(c: Ctx)
	local g = c.groundY
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
	bodyGlow(c, hot, 6.5, 0.88)
	local light = rootLight(c, hot, 1.6, 12, g + 1.2)
	local nextV = 0
	local build = 0
	local deployUntil = 0
	Core.on(c, function(t, _, root)
		local deploy = t < deployUntil
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
			end
		end
		if t >= nextV then
			nextV = t + 2
			build += 1
			ver.Text = string.format("HOTFIX v1.0.%d", build)
			if build % 3 == 0 then
				deployUntil = t + 0.8
				ver.Text = "DEPLOYED (FRI 17:59)"
				sparks:Emit(30)
			end
		end
		sparks.Rate = if deploy then 40 else 12
		light.Brightness = 1.3 + math.noise(t * 6, 2.2) * 0.8 + (if deploy then 1.2 else 0)
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
	local nextTurn = 0
	local solvedUntil = 0
	local turnK = 1
	Core.on(c, function(t, dt, root)
		local camDir = camAxes(root)
		local readA = math.atan2(camDir.Z, camDir.X) -- angle facing the camera
		local solved = t < solvedUntil
		if t >= nextTurn then
			-- turn one wheel by a few clicks (a new shift)
			local wh = wheels[turnK]
			wh.shift = rng:NextInteger(1, 25)
			wh.target = wh.target + (if rng:NextNumber() < 0.5 then 1 else -1) * rng:NextInteger(2, 4)
			turnK = turnK % 3 + 1
			nextTurn = t + 0.55
			if turnK == 1 and rng:NextNumber() < 0.35 then
				solvedUntil = t + 1.6
				nextTurn = t + 1.8
			end
			click:Emit(5)
		end
		for k, wh in wheels do
			-- snap toward the target notch with a tiny overshoot (mechanical click)
			local d = wh.target - wh.off
			wh.off += d * math.min(1, dt * 12)
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
		bar.Color = if solved then Color3.fromRGB(140, 255, 170) else WHITE
		for i, p in ticks do
			p.Transparency = if (i + math.floor(t * 4)) % 13 == 0 then 0 else 0.45
		end
		rot.Text = if solved then "DECRYPTED" else string.format("ROT%d", wheels[1].shift)
		light.Brightness = if solved then 2.6 else 1.1 + Core.pulse(t, 1.1) * 0.4
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
	B.ring(c, {
		n = 2,
		radius = 3.2,
		seg = V(0.34, 0.08, 0.8),
		color = red,
		spin = 0.5,
		anchor = function()
			return CF(0, g + 0.05, 0)
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
	Core.emit(Core.volume(c, V(4.6, 0.1, 4.6), CF(0, g + 0.1, 0)), {
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
	local strainUntil = 0
	local nextStrain = 0
	Core.on(c, function(t, _, root)
		-- both locks try to move toward each other's slot and get yanked back (deadlock)
		if t >= nextStrain then
			nextStrain = t + 2.2 + rng:NextNumber() * 1.5
			strainUntil = t + 0.7
			strain:Emit(16)
		end
		local straining = t < strainUntil
		local base = t * 0.5
		local tug = if straining then math.sin((strainUntil - t) * 28) * 0.08 else 0
		local pull = if straining then 0.25 * math.sin((1 - (strainUntil - t) / 0.7) * math.pi) else 0
		for k, lk in ipairs(locks) do
			local dir = if k == 1 then 1 else -1
			lk.a = base + (k - 1) * math.pi + dir * pull + tug
			local yy = y + math.sin(t * 1.3 + k * 2) * 0.2
			lk.cf = root * outward(lk.a, R, yy) * ANG(0, math.pi, math.sin(t * 2 + k) * 0.15 + tug)
			for i, p in lk.parts do
				Core.put(p, lk.cf * lk.offs[i])
			end
			lk.hole.Color = if straining then WHITE else red
			waitAtts[k].Position = root:PointToObjectSpace((lk.cf * CF(0, 1.25, 0)).Position)
			waits[k].Text = string.format("WAITING FOR #%d", 3 - k)
			waits[k].TextTransparency = if (t * 2 + k) % 2 < 1.4 then 0 else 0.7
		end
		-- chain sags under the body between the two shackles
		local pa = (locks[1].cf * CF(0, 0.76, 0)).Position
		local pb = (locks[2].cf * CF(0, 0.76, 0)).Position
		local sag = if straining then 0.4 else 1.2
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
		glowChain.Transparency = NumberSequence.new(if straining then 0.05 else 0.6)
		light.Brightness = if straining then 2.4 else 0.9 + Core.pulse(t, 2) * 0.3
		light.Color = if straining then red else steel
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
	Core.on(c, function(t, _, root)
		local hcf = c.head.CFrame
		-- peel cycle: the mask lifts off the face, drifts aside and turns, then snaps back
		local cyc = (t % 5) / 5
		local peel = smooth01(cyc / 0.35) * (1 - smooth01((cyc - 0.8) / 0.2))
		local m1 = hcf * CF(peel * 0.9, peel * 0.55, -peel * 0.6) * ANG(peel * 0.25, peel * 0.9, peel * 0.2)
		local mcfs = { m1, m1, m1 }
		Core.put(masks[1].p, m1)
		masks[1].p.Transparency = 0.15 + (1 - peel) * 0.6
		-- candidates orbit the head
		for k = 2, 3 do
			local a = t * 0.9 + (k - 2) * math.pi
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
		local bw, bh = hs.X * 0.7, hs.Y * 0.62
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
		Core.put(scanLine, face * CF(0, sweep * bh, -0.02))
		-- landmark dots jitter as the tracker re-locks
		for i, d in dots do
			local o = dotOff[i]
			local j = if t < swapUntil then 0.05 else 0.01
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
			if rng:NextNumber() < 0.06 then
				swapUntil = t + 0.6
			end
		end
		if t < swapUntil then
			match.Text = "MISMATCH"
			match.TextColor3 = Color3.fromRGB(255, 70, 70)
		else
			match.Text = string.format("MATCH %.1f%%", pct)
			match.TextColor3 = cyan
		end
		scanLine.Color = if t < swapUntil then Color3.fromRGB(255, 70, 70) else cyan
		light.Color = skin:Lerp(cyan, Core.pulse(t, 5))
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
	for i = 1, SPOKES do
		spokeEnds[i] = Core.att(c)
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
	for i = 1, 6 do
		local a = (i - 1) / 6 * TAU + 0.3
		strandEnds[i] = Core.att(c, nil, CF(math.cos(a) * 3.8, g + 0.05, math.sin(a) * 3.8))
		Core.beam(c, strandTop[(i % 2) + 1], strandEnds[i], purple, 0.03, {
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
	B.rootLight(c, purple, 1.6, 14, { pulse = 3, amp = 0.8 })
	local spokeK = 1
	local crawl = 0
	local nextUrl = 0
	Core.on(c, function(t, dt, root)
		local camDir, camRight = camAxes(root)
		-- web plane behind the player, slowly turning around its own hub
		local center = -camDir * 1.5 + V(0, c.chestY + 0.6, 0)
		local frame = CFrame.fromMatrix(center, camRight, Vector3.yAxis) * ANG(0, 0, t * 0.08)
		hub.CFrame = frame
		local breathe = 1 + math.sin(t * 0.8) * 0.04
		for i, e in spokeEnds do
			local a = (i - 1) / SPOKES * TAU
			e.Position = (frame * CF(math.cos(a) * WR * breathe, math.sin(a) * WR * breathe, 0)).Position
		end
		for r, ring in ringAtts do
			local rr = WR * breathe * (r / (RINGS + 0.5)) * (1 + 0.04 * math.sin(t * 2 + r))
			for i, att in ring do
				local a = (i - 1) / SPOKES * TAU
				-- strands sag slightly between spokes (alternating radius)
				local rad = rr * (if i % 2 == 0 then 0.96 else 1)
				att.Position = (frame * CF(math.cos(a) * rad, math.sin(a) * rad, 0)).Position
			end
		end
		-- spider crawls out along a spoke, pauses, returns to the hub, picks another
		crawl += dt * 0.35
		if crawl >= 2 then
			crawl = 0
			spokeK = rng:NextInteger(1, SPOKES)
		end
		local f = if crawl < 1 then smooth01(crawl) else 1 - smooth01(crawl - 1)
		local sa = (spokeK - 1) / SPOKES * TAU
		local lp = frame * CF(math.cos(sa) * WR * 0.85 * f, math.sin(sa) * WR * 0.85 * f, -0.08)
		local scf = root * lp * ANG(0, 0, sa - math.pi / 2 + (if crawl < 1 then 0 else math.pi))
		Core.put(abdomen, scf * CF(0, -0.28, 0))
		Core.put(cephal, scf * CF(0, 0.05, 0))
		Core.put(mark, scf * CF(0, -0.28, -0.2))
		for i, leg in legs do
			local sx = if i <= 4 then 1 else -1
			local j = (i - 1) % 4
			local step = math.sin(t * 14 + i * 1.7) * 0.18 * (if crawl % 1 < 0.95 then 1 else 0)
			local ang = (j - 1.5) * 0.45 + step
			Core.put(leg, scf * CF(sx * 0.1, -0.05, 0) * ANG(0, 0, sx * ang) * CF(sx * 0.23, 0, 0))
		end
		spiderAtt.Position = lp.Position
		thread.Position = hub.Position
		for k, o in onions do
			B.setBeamsTransparency(o.beams, 0.2 + 0.35 * Core.pulse(t, 2.4, k * 0.33))
		end
		if t >= nextUrl then
			nextUrl = t + 2
			onionLbl.Text = Core.pick(urls, rng)
		end
		onionLbl.TextTransparency = if math.noise(t * 4, 7.7) > 0.35 then 0.6 else 0
	end)
end

-- spiky virus orbs replicating and splitting around the body
-- 40 parts / 4 emitters
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
	-- 4 lineages, each a mother + a daughter that buds off and splits away
	type Line = { a: Orb, b: Orb, ang: number, y: number, per: number, ph: number, r: number }
	local lines: { Line } = {}
	for i = 1, 4 do
		lines[i] = {
			a = makeOrb(),
			b = makeOrb(),
			ang = (i - 1) / 4 * TAU,
			y = c.chestY - 0.8 + (i % 2) * 1.4,
			per = 3.4 + i * 0.35,
			ph = i * 0.23,
			r = 2.9,
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
	local spread = B.circle(c, {
		radius = 1,
		color = pink,
		width = 0.14,
		n = 8,
		anchor = function()
			return CF(0, g + 0.06, 0)
		end,
		radiusFn = function(t)
			return 0.6 + ((t / 1.6) % 1) * 4.2
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
	Core.emit(Core.att(c, c.torso), {
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
	B.rootLight(c, green, 1.7, 14, { pulse = 1.6, amp = 1 })
	local hosts = 1
	local lastPhase: { number } = table.create(4, 0)
	Core.on(c, function(t, _, root)
		for i, ln in lines do
			local u = t / ln.per + ln.ph
			local ph = u % 1
			local a = ln.ang + t * 0.35
			local yy = ln.y + math.sin(t * 1.1 + i) * 0.25
			local center = root * CF(math.cos(a) * ln.r, yy, math.sin(a) * ln.r)
			-- tangent direction for splitting
			local tang = root:VectorToWorldSpace(V(-math.sin(a), 0, math.cos(a)))
			local grow = 0.65 + smooth01(ph / 0.45) * 0.45
			local sep = smooth01((ph - 0.45) / 0.3) * 1.1
			local fadeB = smooth01((ph - 0.8) / 0.2)
			-- wobble before splitting (cell pinching)
			local pinch = if ph > 0.35 and ph < 0.5 then math.sin(t * 30) * 0.05 else 0
			putOrb(ln.a, center - tang * (sep * 0.5 + pinch), grow * (1 - sep * 0.15), t, 0)
			putOrb(ln.b, center + tang * (sep * 0.5 + pinch), grow * (1 - sep * 0.15) * (1 - fadeB * 0.6), t + 1, fadeB)
			local splitting = sep > 0.02 and sep < 1
			bA[i].Position = root:PointToObjectSpace(center.Position - tang * sep * 0.5)
			bB[i].Position = root:PointToObjectSpace(center.Position + tang * sep * 0.5)
			bridges[i].Enabled = splitting
			bridges[i].Width0 = 0.35 * (1 - sep / 1.1)
			bridges[i].Width1 = bridges[i].Width0
			if ph >= 0.75 and lastPhase[i] < 0.75 then
				splitA.Position = root:PointToObjectSpace(center.Position)
				spores:Emit(12)
				hosts = hosts * 2
				if hosts > 9999999 then
					hosts = 1
				end
			end
			lastPhase[i] = ph
		end
		B.setBeamsTransparency(spread.beams, 0.1 + ((t / 1.6) % 1) * 0.9)
		inf.Text = string.format("INFECTED: %d", hosts)
		inf.TextColor3 = if math.sin(t * 6) > 0.6 then pink else green
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
	local nextShout = 0
	local glitchUntil = 0
	local nextCode = 0
	Core.on(c, function(t, _, root)
		for k, m in masks do
			local a = m.a + t * 0.5
			local cf = root
				* outward(a, 2.1, c.headY + 0.25 + math.sin(t * 1.3 + k * 2) * 0.18)
				* ANG(math.sin(t * 0.9 + k) * 0.12, math.sin(t * 0.7 + k) * 0.25, math.sin(t * 1.1 + k) * 0.1)
			Core.put(m.face, cf)
			local fr = cf * CF(0, 0, -0.17)
			Core.put(m.eyes[1], fr * CF(-0.2, 0.15, 0) * ANG(0, 0, -0.18))
			Core.put(m.eyes[2], fr * CF(0.2, 0.15, 0) * ANG(0, 0, 0.18))
			Core.put(m.brows[1], fr * CF(-0.2, 0.3, 0) * ANG(0, 0, 0.3))
			Core.put(m.brows[2], fr * CF(0.2, 0.3, 0) * ANG(0, 0, -0.3))
			Core.put(m.smile, fr * CF(0, -0.27, 0.01))
		end
		if t >= glitchUntil + 1 and rng:NextNumber() < 0.02 then
			glitchUntil = t + 0.25
		end
		local glitch = t < glitchUntil
		local camDir, camRight = camAxes(root)
		for k, b in banners do
			-- held up behind the player like a march, swaying in rhythm
			local sway = math.sin(t * 2.2 + k * 1.5) * 0.12
			local p = -camDir * 1.4
				+ camRight * (b.side * 1.5)
				+ V(0, c.topY + 1 + math.abs(math.sin(t * 2.2 + k)) * 0.2, 0)
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
		for _, col in cols do
			local f = (t * col.spd + col.ph) % 1
			local a = col.a + t * 0.1
			col.att.Position = V(math.cos(a) * col.r, c.topY + 2.4 - f * (h + 3), math.sin(a) * col.r)
			col.lbl.TextTransparency = math.max(0, 1 - math.sin(f * math.pi) * 1.4)
		end
		if t >= nextShout then
			nextShout = t + 2.6
			shout.Text = Core.pick(shouts, rng)
			for _, b in banners do
				b.lbl.Text = Core.pick(slogans, rng)
			end
			glitchUntil = t + 0.3
		end
		shout.TextTransparency = if glitch and math.sin(t * 50) > 0 then 0.6 else 0
		light.Color = if glitch then WHITE else red
	end)
end

-- retro sun disc behind the player with stripes, neon grid floor, palm silhouettes
-- ~33 parts / 3 emitters / 1 sun SurfaceGui
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
	local fade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.15),
		NumberSequenceKeypoint.new(0.75, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	for i = 1, GN do
		gx[i] = { Core.att(c), Core.att(c) }
		gz[i] = { Core.att(c), Core.att(c) }
		Core.beam(c, gx[i][1], gx[i][2], pink, 0.07, { segs = 1, tr = fade })
		Core.beam(c, gz[i][1], gz[i][2], cyan, 0.07, { segs = 1, tr = fade })
	end
	B.circle(c, { radius = 4.4, color = pink, width = 0.12, at = CF(0, g + 0.04, 0), tr = 0.25 })
	B.circle(c, { radius = 4.8, color = cyan, width = 0.06, at = CF(0, g + 0.04, 0), tr = 0.45 })
	local floorGlow = Core.part(c, V(0.04, 8.8, 8.8), night:Lerp(pink, 0.35), NEON, 0.86, CYL)
	-- chrome "1986" lettering over the head
	local _, year = B.glyph(c, "1986", sunTop, V2(2.2, 0.6), F.pixel, CF(0, c.topY + 1.25, 0), pink)
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
	Core.emit(starsVol, {
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
	B.rootLight(c, pink, 1.8, 15, { pulse = 60 / 118 * 2, amp = 0.6 })
	local BPM = 118
	Core.on(c, function(t, _, root)
		local camDir, camRight = camAxes(root)
		-- sun sits behind the player, facing the camera
		local sc = -camDir * 2.6 + V(0, c.chestY + 1.3 + math.sin(t * 0.4) * 0.1, 0)
		local sunCF = CFrame.lookAt(sc, sc + camDir)
		Core.put(panel, root * sunCF)
		Core.put(halo, root * sunCF * CF(0, 0, 0.05) * FACE_X)
		halo.Transparency = 0.86 + 0.06 * Core.pulse(t, 60 / BPM * 2)
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
			f.BackgroundColor3 = sunTop:Lerp(pink, smooth01(v * 1.15))
		end
		Core.put(horizon, root * sunCF * CF(0, -SR * 0.95, -0.1))
		-- palms flank the sun
		for _, pm in palms do
			-- rooted on the floor beside the sun, leaning outward, swaying gently
			local base = root * sunCF * CF(pm.side * (SR + 0.7), g - sc.Y, -0.3)
			local bend = pm.side * (0.12 + 0.025 * math.sin(t * 0.9 + pm.side))
			local cf = base
			for _, seg in pm.trunk do
				cf = cf * ANG(0, 0, -bend) * CF(0, PALM_SEG / 2, 0)
				Core.put(seg, cf)
				cf = cf * CF(0, PALM_SEG / 2, 0)
			end
			local crown = cf
			for i, fr in pm.fronds do
				local a = (i - 1) / 6 * TAU
				local droop = 0.55 + 0.08 * math.sin(t * 1.4 + i)
				Core.put(fr, crown * ANG(0, a, 0) * ANG(0, 0, -droop) * CF(0.5, 0, 0))
			end
		end
		-- grid: lines along camRight scroll toward the camera
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
		Core.put(floorGlow, root * CF(0, g + 0.02, 0) * FLAT)
		-- beat-synced chrome text
		local beat = Core.pulse(t, 60 / BPM)
		year.TextColor3 = sunTop:Lerp(WHITE, beat * 0.6)
		year.Rotation = math.sin(t * 1.3) * 3
	end)
end

return A
