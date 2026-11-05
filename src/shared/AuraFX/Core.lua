--!strict
-- AuraFX/Core: one shared RenderStepped loop, the per-character context, pose history
-- and the low-level instance factories every aura / rig / burst is built from.
--
-- Convention: every "anchor" or position inside an aura is expressed in HumanoidRootPart
-- space (root-local). Anchored parts are moved once per frame through Core.put, which is
-- flushed with a single Workspace:BulkMoveTo for all characters.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Sync = require(script.Parent.Sync)

local Core = {}

local V3 = Vector3.new

Core.TAU = math.pi * 2

Core.TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	square = "rbxasset://textures/particles/SquareParticle.png",
	fire = "rbxasset://textures/particles/fire_main.dds",
	fireSpark = "rbxasset://textures/particles/fire_sparks_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	shock = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	implode = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	core = "rbxasset://textures/particles/explosion01_core_main.dds",
}

Core.FONT = {
	mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
	tech = Font.new("rbxasset://fonts/families/Michroma.json"),
	pixel = Font.new("rbxasset://fonts/families/PressStart2P.json"),
}

export type Updater = (t: number, dt: number, root: CFrame) -> ()

export type History = {
	times: { number },
	poses: { { CFrame } },
	head: number,
	count: number,
	last: number,
}

export type Ctx = {
	char: Model,
	folder: Folder,
	root: BasePart, -- HumanoidRootPart, or the LiftRoot proxy for levitating auras
	realRoot: BasePart, -- the actual HumanoidRootPart
	lift: number, -- current levitation (root-space Y) applied by AuraFX/Poses
	proxy: BasePart?, -- anchored LiftRoot following realRoot * (0, lift, 0)
	torso: BasePart,
	lower: BasePart,
	head: BasePart,
	humanoid: Humanoid?,
	r15: boolean,
	groundY: number, -- root-space Y of the soles
	chestY: number, -- root-space Y of the (upper) torso centre
	headY: number, -- root-space Y of the head centre
	topY: number, -- root-space Y of the top of the head
	c1: Color3,
	c2: Color3,
	tier: number,
	rng: Random,
	phase: number,
	alive: boolean,
	body: { BasePart }, -- ordered limb parts (R15: 15, R6: 6)
	updaters: { Updater },
	extras: { Instance }, -- instances living outside the folder (attachments on body parts)
	cleanups: { () -> () },
	conns: { RBXScriptConnection },
	history: History?,
	bus: Sync.Bus, -- shared with the aura's pose (AuraFX/Sync): events + values both ways
}

---------------------------------------------------------------- small helpers

function Core.ns(...: number): NumberSequence
	local v = { ... }
	if #v == 1 then
		return NumberSequence.new(v[1])
	end
	local kps = table.create(#v)
	for i, x in v do
		kps[i] = NumberSequenceKeypoint.new((i - 1) / (#v - 1), x)
	end
	return NumberSequence.new(kps)
end

function Core.cs(...: Color3): ColorSequence
	local v = { ... }
	if #v == 1 then
		return ColorSequence.new(v[1])
	end
	local kps = table.create(#v)
	for i, x in v do
		kps[i] = ColorSequenceKeypoint.new((i - 1) / (#v - 1), x)
	end
	return ColorSequence.new(kps)
end

function Core.nr(a: number, b: number?): NumberRange
	return NumberRange.new(a, b or a)
end

function Core.rainbow(n: number, sat: number?, val: number?): ColorSequence
	local kps = table.create(n)
	for i = 1, n do
		local f = (i - 1) / (n - 1)
		kps[i] = ColorSequenceKeypoint.new(f, Color3.fromHSV(f * 0.85, sat or 0.85, val or 1))
	end
	return ColorSequence.new(kps)
end

local HEXCH = "0123456789ABCDEF"

function Core.bits(n: number, rng: Random): string
	local s = table.create(n)
	for i = 1, n do
		s[i] = if rng:NextNumber() < 0.5 then "0" else "1"
	end
	return table.concat(s)
end

function Core.hex(n: number, rng: Random): string
	local s = table.create(n)
	for i = 1, n do
		local k = rng:NextInteger(1, 16)
		s[i] = string.sub(HEXCH, k, k)
	end
	return table.concat(s)
end

function Core.pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

-- smooth 0..1..0 pulse with period p at time t
function Core.pulse(t: number, p: number, offset: number?): number
	return 0.5 - 0.5 * math.cos((t / p + (offset or 0)) * Core.TAU)
end

---------------------------------------------------------------- render loop

type Job = (t: number, dt: number) -> boolean

local jobs: { [Job]: boolean } = {}
local conn: RBXScriptConnection? = nil
local bufP: { BasePart } = {}
local bufC: { CFrame } = {}
local nbuf = 0

-- Queue an anchored part move for this frame (flushed with one BulkMoveTo).
function Core.put(p: BasePart, cf: CFrame)
	nbuf += 1
	bufP[nbuf] = p
	bufC[nbuf] = cf
end

local function onFrame(dt: number)
	local t = os.clock()
	nbuf = 0
	table.clear(bufP)
	table.clear(bufC)
	for job in jobs do
		local ok, keep = pcall(job, t, dt)
		if not ok then
			warn("[AuraFX] " .. tostring(keep))
			jobs[job] = nil
		elseif not keep then
			jobs[job] = nil
		end
	end
	if nbuf > 0 then
		Workspace:BulkMoveTo(bufP, bufC, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if next(jobs) == nil and conn then
		conn:Disconnect()
		conn = nil
	end
end

function Core.addJob(job: Job)
	jobs[job] = true
	if not conn then
		conn = RunService.RenderStepped:Connect(onFrame)
	end
end

---------------------------------------------------------------- context

local R15_FULL: { string } = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}
local R6_FULL: { string } = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function nameSet(list: { string }): { [string]: boolean }
	local s = {}
	for _, n in list do
		s[n] = true
	end
	return s
end

-- Named subsets of the body used by clone effects.
Core.SETS = {
	full = nameSet(R15_FULL),
	lite = nameSet({
		"Head",
		"UpperTorso",
		"LowerTorso",
		"LeftUpperArm",
		"LeftLowerArm",
		"RightUpperArm",
		"RightLowerArm",
		"LeftUpperLeg",
		"LeftLowerLeg",
		"RightUpperLeg",
		"RightLowerLeg",
		"Torso",
		"Left Arm",
		"Right Arm",
		"Left Leg",
		"Right Leg",
	}),
	core = nameSet({ "Head", "UpperTorso", "LowerTorso", "Torso" }),
} :: { [string]: { [string]: boolean } }
for _, n in R6_FULL do
	Core.SETS.full[n] = true
end

function Core.bodyPart(char: Model, ...: string): BasePart?
	for _, n in { ... } do
		local p = char:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

-- Attachment at the tip of a limb, riding the animated body part (so particles / beams follow
-- every pose exactly):  "rhand" | "lhand" | "rfoot" | "lfoot" | "head" (crown) | "chest".
-- `off` is an extra offset in that part's space. Works on R6 and R15.
local TIPS: { [string]: { r6: string, r15: string, y6: number, y15: number } } = {
	rhand = { r6 = "Right Arm", r15 = "RightHand", y6 = -1.05, y15 = -0.2 },
	lhand = { r6 = "Left Arm", r15 = "LeftHand", y6 = -1.05, y15 = -0.2 },
	rfoot = { r6 = "Right Leg", r15 = "RightFoot", y6 = -1, y15 = -0.2 },
	lfoot = { r6 = "Left Leg", r15 = "LeftFoot", y6 = -1, y15 = -0.2 },
	head = { r6 = "Head", r15 = "Head", y6 = 0.6, y15 = 0.6 },
	chest = { r6 = "Torso", r15 = "UpperTorso", y6 = 0.3, y15 = 0.1 },
}

function Core.tip(c: Ctx, which: string, off: CFrame?): Attachment?
	local d = TIPS[which]
	if not d then
		return nil
	end
	local part = Core.bodyPart(c.char, if c.r15 then d.r15 else d.r6, d.r6, d.r15)
	if not part then
		return nil
	end
	local y = if c.r15 then d.y15 else d.y6
	return Core.att(c, part, CFrame.new(0, y, 0) * (off or CFrame.identity))
end

-- Visual size of the head (R6 heads are 2x1x1 parts drawn by a 1.25-scale head mesh).
function Core.headSize(head: BasePart): Vector3
	local m = head:FindFirstChildWhichIsA("SpecialMesh")
	if m and m.MeshType == Enum.MeshType.Head then
		local s = head.Size.Y
		return V3(m.Scale.X * s, m.Scale.Y * s, m.Scale.Z * s)
	end
	return head.Size
end

-- `float`: the aura's pose levitates the body, so everything built on c.root rides an
-- anchored proxy ("LiftRoot") that follows the HumanoidRootPart raised by c.lift.
function Core.newCtx(char: Model, name: string, c1: Color3, c2: Color3, tier: number, float: boolean?): Ctx?
	local root = Core.bodyPart(char, "HumanoidRootPart")
	local head = Core.bodyPart(char, "Head")
	if not root or not head then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local r15 = if hum then hum.RigType == Enum.HumanoidRigType.R15 else char:FindFirstChild("UpperTorso") ~= nil
	local torso = Core.bodyPart(char, "UpperTorso", "Torso") or root
	local lower = Core.bodyPart(char, "LowerTorso", "Torso") or torso

	local existing = char:FindFirstChild("AuraFX")
	local holder: Instance
	if existing then
		holder = existing
	else
		local f = Instance.new("Folder")
		f.Name = "AuraFX"
		f.Parent = char
		holder = f
	end
	local old = holder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = holder

	local rcf = root.CFrame
	local headY = rcf:PointToObjectSpace(head.Position).Y
	local chestY = rcf:PointToObjectSpace(torso.Position).Y
	local groundY
	if r15 and hum then
		groundY = -(hum.HipHeight + root.Size.Y / 2)
	else
		groundY = -(root.Size.Y / 2 + 2)
	end
	-- sanity for odd rigs / mid-animation spawns
	if headY < 0.5 or headY > 6 then
		headY = 1.5
	end
	if groundY > -1 or groundY < -8 then
		groundY = -3
	end

	local body = {}
	local names: { string } = if r15 then R15_FULL else R6_FULL
	for _, n in names do
		local p = Core.bodyPart(char, n)
		if p then
			table.insert(body, p)
		end
	end

	local proxy: BasePart? = nil
	if float then
		local p = Instance.new("Part")
		p.Name = "LiftRoot"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Locked = true
		p.Transparency = 1
		p.Size = root.Size
		p.CFrame = root.CFrame
		p.Parent = folder
		proxy = p
	end

	local c: Ctx = {
		char = char,
		folder = folder,
		root = proxy or root,
		realRoot = root,
		lift = 0,
		proxy = proxy,
		torso = torso,
		lower = lower,
		head = head,
		humanoid = hum,
		r15 = r15,
		groundY = groundY,
		chestY = chestY,
		headY = headY,
		topY = headY + Core.headSize(head).Y / 2,
		c1 = c1,
		c2 = c2,
		tier = tier,
		rng = Random.new(),
		phase = math.random(0, 7),
		alive = true,
		body = body,
		updaters = {},
		extras = {},
		cleanups = {},
		conns = {},
		history = nil,
		bus = Sync.new(),
	}
	table.insert(
		c.conns,
		char.AncestryChanged:Connect(function()
			if not char:IsDescendantOf(game) then
				Core.destroy(c)
			end
		end)
	)
	return c
end

function Core.on(c: Ctx, fn: Updater)
	table.insert(c.updaters, fn)
end

function Core.start(c: Ctx)
	local frameN = 0
	local function job(t: number, dt: number): boolean
		if not c.alive then
			return false
		end
		local root = c.realRoot
		if root.Parent == nil or c.char.Parent == nil then
			Core.destroy(c)
			return false
		end
		frameN += 1
		local rcf = root.CFrame
		local proxy = c.proxy
		if proxy then
			rcf *= CFrame.new(0, c.lift, 0)
			proxy.CFrame = rcf
		end
		local cam = Workspace.CurrentCamera
		if cam and (cam.CFrame.Position - rcf.Position).Magnitude > 280 and (frameN + c.phase) % 8 ~= 0 then
			return true -- far away: refresh rarely
		end
		local ok, err = pcall(function()
			for _, u in c.updaters do
				u(t, dt, rcf)
			end
		end)
		if not ok then
			warn("[AuraFX] " .. c.folder.Name .. ": " .. tostring(err))
			Core.destroy(c)
			return false
		end
		return true
	end
	Core.addJob(job)
end

function Core.destroy(c: Ctx)
	if not c.alive then
		return
	end
	c.alive = false
	for _, fn in c.cleanups do
		pcall(fn)
	end
	for _, cn in c.conns do
		cn:Disconnect()
	end
	for _, inst in c.extras do
		inst:Destroy()
	end
	local holder = c.folder.Parent
	c.folder:Destroy()
	if holder and holder.Name == "AuraFX" and #holder:GetChildren() == 0 then
		holder:Destroy()
	end
end

-- Temporarily override a property on a character instance; restored on destroy.
function Core.override(c: Ctx, inst: Instance, prop: string, value: any)
	local okGet, before = pcall(function()
		return (inst :: any)[prop]
	end)
	if not okGet then
		return
	end
	pcall(function()
		(inst :: any)[prop] = value
	end)
	table.insert(c.cleanups, function()
		if inst.Parent then
			(inst :: any)[prop] = before
		end
	end)
end

---------------------------------------------------------------- pose history

local HIST = 48
local HIST_DT = 1 / 60

function Core.useHistory(c: Ctx)
	if c.history then
		return
	end
	local h: History = { times = {}, poses = {}, head = 0, count = 0, last = -1 }
	c.history = h
	table.insert(c.updaters, 1, function(t: number)
		if t - h.last < HIST_DT then
			return
		end
		h.last = t
		h.head = h.head % HIST + 1
		local pose = h.poses[h.head]
		if not pose then
			pose = table.create(#c.body)
			h.poses[h.head] = pose
		end
		for i, p in c.body do
			pose[i] = p.CFrame
		end
		h.times[h.head] = t
		h.count = math.min(h.count + 1, HIST)
	end)
end

-- Newest recorded pose taken at or before time `at` (oldest available if none).
function Core.sample(c: Ctx, at: number): { CFrame }?
	local h = c.history
	if not h or h.count == 0 then
		return nil
	end
	local idx = h.head
	for _ = 1, h.count do
		if h.times[idx] <= at then
			return h.poses[idx]
		end
		local prev = idx - 1
		if prev < 1 then
			prev = HIST
		end
		if h.times[prev] == nil then
			break
		end
		idx = prev
	end
	return h.poses[idx]
end

---------------------------------------------------------------- factories

local FAR = CFrame.new(0, -2000, 0)

function Core.newPart(
	parent: Instance,
	size: Vector3,
	color: Color3,
	mat: Enum.Material?,
	tr: number?,
	shape: Enum.PartType?
): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Locked = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.Neon
	p.Transparency = tr or 0
	p.CFrame = FAR
	p.Parent = parent
	return p
end

-- Anchored FX part inside the context folder (move it with Core.put).
function Core.part(
	c: Ctx,
	size: Vector3,
	color: Color3,
	mat: Enum.Material?,
	tr: number?,
	shape: Enum.PartType?
): BasePart
	local p = Core.newPart(c.folder, size, color, mat, tr, shape)
	p.CFrame = c.root.CFrame + Vector3.new(0, -50, 0)
	return p
end

-- Ellipsoid (built-in sphere mesh, no asset id).
function Core.ellipsoid(c: Ctx, size: Vector3, color: Color3, mat: Enum.Material?, tr: number?): (BasePart, SpecialMesh)
	local p = Core.part(c, size, color, mat, tr)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p, m
end

-- Invisible welded part used as an emission volume for box/sphere particle shapes.
function Core.volume(c: Ctx, size: Vector3, offset: CFrame, body: BasePart?): BasePart
	local b = body or c.root
	local p = Core.newPart(c.folder, size, Color3.new(), Enum.Material.SmoothPlastic, 1)
	p.Anchored = false
	p.CFrame = b.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = b
	w.Part1 = p
	w.Parent = p
	return p
end

-- Attachment on a body part (root by default); tracked and removed on destroy.
function Core.att(c: Ctx, parent: BasePart?, cf: CFrame?): Attachment
	local a = Instance.new("Attachment")
	a.Name = "AuraFX"
	a.CFrame = cf or CFrame.identity
	a.Parent = parent or c.root
	table.insert(c.extras, a)
	return a
end

export type EmitSpec = {
	tex: string,
	color: ColorSequence,
	size: NumberSequence,
	transp: NumberSequence?,
	rate: number,
	life: NumberRange,
	speed: NumberRange?,
	spread: Vector2?,
	accel: Vector3?,
	drag: number?,
	rot: NumberRange?,
	rotSpeed: NumberRange?,
	light: number?,
	bright: number?,
	zoff: number?,
	locked: boolean?,
	dir: Enum.NormalId?,
	squash: NumberSequence?,
	orient: Enum.ParticleOrientation?,
	shape: Enum.ParticleEmitterShape?,
	shapeStyle: Enum.ParticleEmitterShapeStyle?,
	inout: Enum.ParticleEmitterShapeInOut?,
	inherit: number?,
	timeScale: number?,
}

function Core.emit(parent: Instance, s: EmitSpec): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = s.tex
	e.Color = s.color
	e.Size = s.size
	e.Transparency = s.transp or NumberSequence.new(0)
	e.Rate = s.rate
	e.Lifetime = s.life
	e.Speed = s.speed or NumberRange.new(0)
	e.SpreadAngle = s.spread or Vector2.zero
	e.Acceleration = s.accel or Vector3.zero
	e.Drag = s.drag or 0
	e.Rotation = s.rot or NumberRange.new(0, 360)
	e.RotSpeed = s.rotSpeed or NumberRange.new(0)
	e.LightEmission = s.light or 1
	e.LightInfluence = 0
	e.Brightness = s.bright or 1.5
	e.ZOffset = s.zoff or 0
	e.LockedToPart = s.locked or false
	e.EmissionDirection = s.dir or Enum.NormalId.Top
	if s.squash then
		e.Squash = s.squash
	end
	if s.orient then
		e.Orientation = s.orient
	end
	if s.shape then
		e.Shape = s.shape
	end
	if s.shapeStyle then
		e.ShapeStyle = s.shapeStyle
	end
	if s.inout then
		e.ShapeInOut = s.inout
	end
	e.VelocityInheritance = s.inherit or 0
	if s.timeScale then
		e.TimeScale = s.timeScale
	end
	e.Parent = parent
	return e
end

function Core.light(parent: Instance, color: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

export type BeamOpts = {
	color2: Color3?,
	w1: number?,
	tr: NumberSequence?,
	light: number?,
	c0: number?,
	c1: number?,
	segs: number?,
	face: boolean?,
	tex: string?,
	texLen: number?,
	texSpeed: number?,
	bright: number?,
	zoff: number?,
}

function Core.beam(c: Ctx, a0: Attachment, a1: Attachment, color: Color3, w0: number, opts: BeamOpts?): Beam
	local o: BeamOpts = opts or {}
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = if o.color2 then ColorSequence.new(color, o.color2) else ColorSequence.new(color)
	b.Width0 = w0
	b.Width1 = o.w1 or w0
	b.Transparency = o.tr or NumberSequence.new(0)
	b.LightEmission = o.light or 1
	b.LightInfluence = 0
	b.Brightness = o.bright or 2
	b.FaceCamera = if o.face == nil then true else o.face
	b.Segments = o.segs or 10
	b.CurveSize0 = o.c0 or 0
	b.CurveSize1 = o.c1 or 0
	b.ZOffset = o.zoff or 0
	if o.tex then
		b.Texture = o.tex
		b.TextureLength = o.texLen or 1
		b.TextureSpeed = o.texSpeed or 0
		b.TextureMode = Enum.TextureMode.Wrap
	end
	b.Parent = c.folder
	return b
end

function Core.trail(part: BasePart, color: Color3, width: number, life: number, color2: Color3?): Trail
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = part
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = if color2 then ColorSequence.new(color, color2) else ColorSequence.new(color)
	tr.Transparency = Core.ns(0.2, 1)
	tr.Lifetime = life
	tr.LightEmission = 1
	tr.LightInfluence = 0
	tr.FaceCamera = true
	tr.WidthScale = Core.ns(1, 0)
	tr.Parent = part
	return tr
end

-- Floating text (BillboardGui adorned to an attachment or part).
function Core.glyph(
	c: Ctx,
	adornee: Instance,
	text: string,
	color: Color3,
	size: Vector2,
	font: Font?,
	stroke: Color3?
): (BillboardGui, TextLabel)
	local g = Instance.new("BillboardGui")
	g.Name = "Glyph"
	g.Adornee = adornee
	g.Size = UDim2.new(size.X, 0, size.Y, 0)
	g.LightInfluence = 0
	g.Brightness = 2
	g.MaxDistance = 160
	g.AlwaysOnTop = false
	g.ClipsDescendants = false
	g.ResetOnSpawn = false
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.TextScaled = true
	l.FontFace = font or Core.FONT.mono
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeColor3 = stroke or Color3.new(0, 0, 0)
	l.TextStrokeTransparency = if stroke then 0.2 else 0.55
	l.Parent = g
	g.Parent = c.folder
	return g, l
end

-- SurfaceGui on a part face, emissive, sized in pixels-per-stud.
function Core.surface(part: BasePart, face: Enum.NormalId, pps: number?): SurfaceGui
	local s = Instance.new("SurfaceGui")
	s.Face = face
	s.LightInfluence = 0
	s.Brightness = 2.2
	s.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	s.PixelsPerStud = pps or 100
	s.AlwaysOnTop = false
	s.MaxDistance = 140
	s.ResetOnSpawn = false
	s.Parent = part
	return s
end

function Core.label(
	parent: Instance,
	text: string,
	color: Color3,
	font: Font,
	pos: UDim2,
	size: UDim2,
	xAlign: Enum.TextXAlignment?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.TextScaled = true
	l.FontFace = font
	l.Text = text
	l.TextColor3 = color
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

function Core.frame(parent: Instance, color: Color3, pos: UDim2, size: UDim2, tr: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = tr or 0
	f.Position = pos
	f.Size = size
	f.Parent = parent
	return f
end

-- Visual clone of a body part (mesh kept, textures/decals/joints stripped).
function Core.cloneShape(
	c: Ctx,
	src: BasePart,
	color: Color3,
	mat: Enum.Material?,
	tr: number?,
	scale: number?
): BasePart
	local arch = src.Archivable
	src.Archivable = true
	local ok, cl = pcall(function()
		return src:Clone()
	end)
	src.Archivable = arch
	local p: BasePart
	if ok and cl then
		p = cl :: BasePart
		for _, ch in p:GetChildren() do
			if not ch:IsA("DataModelMesh") then
				ch:Destroy()
			end
		end
		if p:IsA("MeshPart") then
			pcall(function()
				(p :: MeshPart).TextureID = ""
			end)
		end
		local sm = p:FindFirstChildWhichIsA("SpecialMesh")
		if sm then
			sm.TextureId = ""
		end
	else
		p = Instance.new("Part")
		p.Size = src.Size
	end
	p.Name = "Clone"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Locked = true
	p.Color = color
	p.Material = mat or Enum.Material.ForceField
	p.Transparency = tr or 0
	p.Size = src.Size * (scale or 1)
	p.CFrame = src.CFrame
	p.Parent = c.folder
	return p
end

return Core
