--!strict
-- AuraFX/Poses: plays each aura's BLENDER-authored animation set (idle loop + walk stride +
-- one-shot reactions) on the character and keeps it in sync with the aura's VFX.
--
--   Poses.has(auraId) -> boolean
--   Poses.lift(auraId) -> number                 (levitation in studs, 0 = stays grounded)
--   Poses.start(character, auraId, onLift?, bus?) -> stop()
--
-- The motion itself is never written here: it is keyframed in Blender (art/anims/*.blend,
-- tools/blender/anim/) and baked into AuraFX/Anims/<AuraId>.lua (read through AuraFX/Clips).
--
-- Every frame in RunService.Stepped the runner evaluates the IDLE clip (timed from the attach
-- moment, so the VFX can share its beat through AuraFX/Sync) and the WALK clip (one stride,
-- timed by a speed-matched gait phase), cross-fades them by how fast the character moves
-- (~0.3 s) and composes the result onto the Motor6Ds:
--     Transform = (C0rot^-1 * offset * C0rot) * animTransform:Lerp(identity, override)
-- Blender clips own the body completely (override 1); the stock jump / fall / climb / sit
-- animations take over again while airborne or seated.
--
-- Sync (the aura's AuraFX/Sync bus, shared with its VFX builder):
--   * Blender markers "fx:<event>[:<arg>]" are emitted on the bus when playback crosses them
--     (idle markers while standing, walk markers while walking, one-shot markers always);
--   * a clip with `trigger = "<event>"` is a one-shot reaction played whenever the VFX (or
--     anything else) emits that event;
--   * the runner publishes move / spd / ph / air / lift values and step / jump / land events.
-- Walk clip convention: frame 0 = right foot contact, half way = left foot contact; the bus
-- "step" events fire on exactly those phases ("R" at 0, "L" at pi).
--
-- Levitating sets (lift > 0) raise the body through the root joint only; the HumanoidRootPart
-- is never moved (the lift is reported through onLift so root-anchored effects follow it).
-- Switching auras cross-fades between the two sets; joints are handed back to the animation
-- untouched on stop, death, respawn and character removal.

local RunService = game:GetService("RunService")
local Config = require(script.Parent.Parent.Config)
local Clips = require(script.Parent.Clips)
local Sync = require(script.Parent.Sync)

local Anims = script.Parent:FindFirstChild("Anims")

local Poses = {}

local CF = CFrame.new
local ID = CFrame.identity
local TAU = math.pi * 2
local PI = math.pi
local abs, clamp, exp, floor, min, max = math.abs, math.clamp, math.exp, math.floor, math.min, math.max

local BLEND_IN = 0.6 -- seconds, aura equipped
local BLEND_OUT = 0.4 -- seconds, aura removed
local MOVE_RATE = 9 -- 1/s exponential rate of the idle <-> walk blend (~0.3 s)
local AIR_RATE = 10 -- 1/s fade while jumping / falling
local STRIDE_HZ = 1.4 -- gait cycles per second at WalkSpeed 16 (the walk clip is one cycle)
local AIR_KEEP = 0.2 -- weight grounded poses keep while airborne

-- Logical joints. R6 names first, R15 names second.
local JOINT_NAMES: { [string]: string } = {
	RootJoint = "root",
	Root = "root",
	Neck = "neck",
	["Left Shoulder"] = "ls",
	LeftShoulder = "ls",
	["Right Shoulder"] = "rs",
	RightShoulder = "rs",
	["Left Hip"] = "lh",
	LeftHip = "lh",
	["Right Hip"] = "rh",
	RightHip = "rh",
}
local KEYS = { "root", "neck", "ls", "rs", "lh", "rh" }

-- One frame of pose output (offsets at full strength, parent space).
export type Out = {
	root: CFrame,
	neck: CFrame,
	ls: CFrame,
	rs: CFrame,
	lh: CFrame,
	rh: CFrame,
	ov: { [string]: number }, -- per joint: 0 = add on top of the animation, 1 = replace it
	lift: number, -- studs the body is raised (levitating sets only)
	snap: CFrame, -- extra root offset, parent space of the root
}

-- Per-frame motion context handed to every set.
export type S = {
	t: number, -- seconds (os.clock)
	dt: number,
	ph: number, -- gait phase in radians, advances with ground speed
	spd: number, -- ground speed / 16 (smoothed)
	move: number, -- 0 idle .. 1 walking (smoothed)
	turn: number, -- yaw rate in rad/s, + = turning left (smoothed)
	rng: Random,
	mem: { [string]: any }, -- per layer scratch state
	bus: Sync.Bus?, -- the layer's aura bus
}

type Fn = (o: Out, s: S) -> ()

type Spec = {
	lift: number, -- > 0 = levitating (also keeps the pose while airborne)
	air: number?, -- weight kept while airborne (grounded sets, default AIR_KEEP)
	tick: (s: S) -> (), -- once per frame before idle / walk: markers, one-shot triggers
	idle: Fn,
	walk: Fn,
}

local function smooth01(x: number): number
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

---------------------------------------------------------------- Blender clip sets

local SPECS: { [string]: Spec } = {}

local function idleTime(s: S): number
	return Sync.age(s.bus)
end

local function walkTime(s: S, clip: Clips.Clip): number
	return (s.ph / TAU) * clip.len
end

local function fire(s: S)
	return function(e: Clips.Event)
		Sync.emit(s.bus, e.name, e.arg)
	end
end

local function makeSpec(set: Clips.Set): Spec
	local float = set.lift > 0
	local tmp: { [string]: any } = {}

	-- clip pose into o (levitating sets: the root's height becomes the reported lift)
	local function apply(o: Out, clip: Clips.Clip, t: number)
		Clips.pose(clip, t, tmp)
		local root = tmp.root :: CFrame
		if float then
			local p = root.Position
			o.lift = max(0, p.Y)
			root = CF(p.X, p.Y - o.lift, p.Z) * root.Rotation
		end
		o.root, o.neck, o.rs, o.ls, o.rh, o.lh = root, tmp.neck, tmp.rs, tmp.ls, tmp.rh, tmp.lh
		local ov = o.ov
		ov.root, ov.neck, ov.rs, ov.ls, ov.rh, ov.lh = 1, 1, 1, 1, 1, 1
	end

	-- active one-shots blended over the base clip
	local function overlay(o: Out, s: S)
		local active = s.mem.once :: { [Clips.Clip]: number }?
		if not active then
			return
		end
		local oa = o :: any
		for clip, t0 in active do
			local lt = s.t - t0
			local w = min(1, lt / max(clip.blendIn, 1e-3), (clip.len - lt) / max(clip.blendOut, 1e-3))
			w = clamp(w, 0, 1)
			w = w * w * (3 - 2 * w)
			if w <= 0 then
				continue
			end
			for _, k in KEYS do
				local x = Clips.sample(clip, k, lt)
				if x then
					if clip.mode == "add" then
						oa[k] = (oa[k] :: CFrame) * ID:Lerp(x, w)
					else
						oa[k] = (oa[k] :: CFrame):Lerp(x, w)
					end
				end
			end
		end
	end

	return {
		lift = set.lift,
		air = set.air,
		tick = function(s: S)
			local mem = s.mem
			local f = fire(s)
			-- base clip markers: the clip that dominates right now
			local idle, walk = set.idle, set.walk
			local it = idleTime(s)
			if idle and s.move < 0.5 and mem.it then
				Clips.cross(idle, mem.it, it, f)
			end
			mem.it = it
			if walk then
				local wt = walkTime(s, walk)
				if s.move >= 0.5 and mem.wt and wt > mem.wt then
					Clips.cross(walk, mem.wt, wt, f)
				end
				mem.wt = wt
			end
			-- one-shot reactions: start on a new trigger event, fire their markers, expire
			local active = mem.once :: { [Clips.Clip]: number }?
			for _, clip in set.once do
				local trig = clip.trigger :: string
				local n = Sync.count(s.bus, trig)
				local key = "n_" .. clip.name
				local seen = mem[key] :: number?
				mem[key] = n
				if seen and n > seen then
					if not active then
						active = {}
						mem.once = active
					end
					(active :: any)[clip] = s.t
					mem["ot_" .. clip.name] = -1e-3
				end
			end
			if active then
				for clip, t0 in active do
					local lt = s.t - t0
					local key = "ot_" .. clip.name
					local last = mem[key] :: number?
					if last and lt > last then
						Clips.cross(clip, last, min(lt, clip.len), f)
					end
					mem[key] = lt
					if lt >= clip.len then
						active[clip] = nil
					end
				end
			end
		end,
		idle = function(o: Out, s: S)
			local clip = set.idle or set.walk
			if clip then
				apply(o, clip, if clip == set.idle then idleTime(s) else 0)
			end
			overlay(o, s)
		end,
		walk = function(o: Out, s: S)
			local clip = set.walk or set.idle
			if clip then
				apply(o, clip, if clip == set.walk then walkTime(s, clip) else idleTime(s))
			end
			overlay(o, s)
		end,
	}
end

for _, a in Config.Auras do
	local set = Clips.load(Anims, a.id)
	if set and (set.idle or set.walk) then
		SPECS[a.id] = makeSpec(set)
	end
end

---------------------------------------------------------------- runner

type Joint = {
	m: Motor6D,
	r0: CFrame,
	r0i: CFrame,
	base: CFrame, -- last animation transform seen
	out: CFrame?, -- last transform we wrote
	new: CFrame, -- transform computed this frame (before the foot solver)
}

-- Motor chain HumanoidRootPart -> foot part (R6: leg, R15: foot), for the foot solver.
type Chain = {
	motors: { Motor6D },
	part: BasePart,
	corners: { Vector3 }, -- bottom corners in part space
}

type Layer = {
	id: string,
	spec: Spec,
	w: number,
	target: number,
	rng: Random,
	mem: { [string]: any },
	onLift: ((number) -> ())?,
	bus: Sync.Bus?,
	I: Out,
	W: Out,
}

type Run = {
	char: Model,
	joints: { [string]: Joint },
	found: number,
	nextScan: number,
	scanUntil: number,
	hum: Humanoid?,
	root: BasePart?,
	layers: { Layer },
	move: number, -- 0 idle .. 1 walking (smoothed)
	ph: number,
	spd: number,
	turn: number,
	look: Vector3?,
	air: number, -- 0..1 airborne (smoothed)
	block: number, -- 0..1 seated / climbing / swimming (smoothed)
	wasAir: boolean,
	airAt: number,
	stepN: number, -- index of the last foot contact (floor(ph / pi))
	s: S,
	acc: { [string]: CFrame },
	accOv: { [string]: number },
	accJ: { [string]: CFrame },
	feet: { Chain }?,
	restLow: number, -- lowest sole point (root space) in the rest pose
	byMotor: { [Motor6D]: Joint },
}

local runs: { [Model]: Run } = {}
local conn: RBXScriptConnection? = nil
local buildFeet: (r: Run) -> ()

local BLOCK_STATES: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Physics] = true,
}

local function newOut(): Out
	return {
		root = ID,
		neck = ID,
		ls = ID,
		rs = ID,
		lh = ID,
		rh = ID,
		ov = { root = 0, neck = 0, ls = 0, rs = 0, lh = 0, rh = 0 },
		lift = 0,
		snap = ID,
	}
end

local function resetOut(o: Out)
	o.root, o.neck, o.ls, o.rs, o.lh, o.rh = ID, ID, ID, ID, ID, ID
	local ov = o.ov
	ov.root, ov.neck, ov.ls, ov.rs, ov.lh, ov.rh = 0, 0, 0, 0, 0, 0
	o.lift, o.snap = 0, ID
end

-- tolerant CFrame equality (property round-trips may lose the last bits)
local function same(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 1e-4
		and (a.XVector - b.XVector).Magnitude < 1e-4
		and (a.YVector - b.YVector).Magnitude < 1e-4
end

-- lowest sole point in root space, with the joints we drive at `use` (nil = rest pose) and
-- every other joint at its current animation transform
local function lowest(r: Run, rest: boolean): number
	local low = math.huge
	for _, c in r.feet :: { Chain } do
		local cf = ID
		for _, m in c.motors do
			local T: CFrame
			if rest then
				T = ID
			else
				local j = r.byMotor[m]
				T = if j then j.new else m.Transform
			end
			cf = cf * m.C0 * T * m.C1:Inverse()
		end
		for _, k in c.corners do
			local y = (cf * k).Y
			if y < low then
				low = y
			end
		end
	end
	return low
end

local FOOT_PARTS = { { "Left Leg", "Right Leg" }, { "LeftFoot", "RightFoot" } }

buildFeet = function(r: Run)
	local root = r.root
	if not root then
		return
	end
	local into: { [BasePart]: Motor6D } = {}
	for _, d in r.char:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 then
			into[d.Part1] = d
		end
	end
	for _, names in FOOT_PARTS do
		local feet: { Chain } = {}
		for _, n in names do
			local part = r.char:FindFirstChild(n)
			if part and part:IsA("BasePart") then
				local motors: { Motor6D } = {}
				local p: BasePart? = part
				for _ = 1, 8 do
					local m = if p then into[p] else nil
					if not m then
						break
					end
					table.insert(motors, 1, m)
					p = m.Part0
					if p == root then
						break
					end
				end
				if p == root and #motors > 0 then
					local h = part.Size / 2
					table.insert(feet, {
						motors = motors,
						part = part,
						corners = {
							Vector3.new(h.X, -h.Y, h.Z),
							Vector3.new(-h.X, -h.Y, h.Z),
							Vector3.new(h.X, -h.Y, -h.Z),
							Vector3.new(-h.X, -h.Y, -h.Z),
						},
					})
				end
			end
		end
		if #feet == 2 then
			r.feet = feet
			r.restLow = lowest(r, true)
			return
		end
	end
end

local function scan(r: Run)
	for _, d in r.char:GetDescendants() do
		if d:IsA("Motor6D") then
			local key = JOINT_NAMES[d.Name]
			if key and not r.joints[key] then
				local rot = d.C0.Rotation
				local j: Joint = { m = d, r0 = rot, r0i = rot:Inverse(), base = d.Transform, out = nil, new = ID }
				r.joints[key] = j
				r.byMotor[d] = j
				r.found += 1
			end
		end
	end
	r.hum = r.char:FindFirstChildOfClass("Humanoid")
	local root = r.char:FindFirstChild("HumanoidRootPart")
	r.root = if root and root:IsA("BasePart") then root else nil
	if r.found >= 6 and not r.feet and r.root then
		buildFeet(r)
	end
end

-- hand every joint back to the animation (only where nobody overwrote our last value)
local function restore(r: Run)
	for _, j in r.joints do
		if j.m.Parent and j.out and same(j.m.Transform, j.out) then
			j.m.Transform = j.base
		end
		j.out = nil
	end
	for _, L in r.layers do
		local f = L.onLift
		if f then
			L.onLift = nil
			pcall(f, 0)
		end
	end
end

local function step(r: Run, t: number, dt: number): boolean
	local char = r.char
	if char.Parent == nil then
		restore(r)
		return false
	end
	if r.found < 6 and t >= r.nextScan and t < r.scanUntil then
		r.nextScan = t + 0.5
		scan(r)
	end
	local hum, root = r.hum, r.root
	local state: Enum.HumanoidStateType? = nil
	if hum and hum.Parent then
		state = hum:GetState()
		if hum.Health <= 0 or state == Enum.HumanoidStateType.Dead then
			restore(r)
			return false
		end
	end

	-- layer weights (blend in / out), drop finished layers
	local layers = r.layers
	for i = #layers, 1, -1 do
		local L = layers[i]
		if L.target > L.w then
			L.w = min(L.target, L.w + dt / BLEND_IN)
		else
			L.w = max(L.target, L.w - dt / BLEND_OUT)
		end
		if L.target <= 0 and L.w <= 0 then
			table.remove(layers, i)
		end
	end
	if #layers == 0 then
		restore(r)
		return false
	end

	-- locomotion: MoveDirection for the local player, velocity for everyone else
	local moving, speed, vy = 0, 0, 0
	if hum and hum.Parent then
		moving = if hum.MoveDirection.Magnitude > 0.1 then 1 else 0
	end
	if root and root.Parent then
		local v = root.AssemblyLinearVelocity
		speed = Vector3.new(v.X, 0, v.Z).Magnitude
		vy = v.Y
		moving = max(moving, clamp((speed - 1.5) / 4, 0, 1))
		local lv = root.CFrame.LookVector
		local flat = Vector3.new(lv.X, 0, lv.Z)
		if flat.Magnitude > 1e-3 then
			flat = flat.Unit
			local old = r.look
			if old and dt > 0 then
				local yaw = math.atan2(old:Cross(flat).Y, old:Dot(flat))
				r.turn += (clamp(yaw / dt, -6, 6) - r.turn) * (1 - exp(-6 * dt))
			end
			r.look = flat
		end
	end
	r.move += (moving - r.move) * (1 - exp(-MOVE_RATE * dt))
	r.spd += (speed / 16 - r.spd) * (1 - exp(-8 * dt))
	if r.move > 0.01 then
		r.ph = (r.ph + dt * TAU * STRIDE_HZ * clamp(speed / 16, 0.35, 1.9)) % (TAU * 40)
	end
	local airborne = state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.Jumping
		or abs(vy) > 10
	-- bus events shared by every layer: foot contacts, take-off, landing
	local stepN = floor(r.ph / PI)
	local stepSide: string? = nil
	if stepN ~= r.stepN then
		if r.move > 0.5 and not airborne then
			stepSide = if stepN % 2 == 0 then "R" else "L"
		end
		r.stepN = stepN
	end
	local airEvent: string? = nil
	if airborne ~= r.wasAir then
		airEvent = if airborne then "jump" else "land"
		r.wasAir = airborne
		if airborne then
			r.airAt = t
		end
	end
	r.air += ((if airborne then 1 else 0) - r.air) * (1 - exp(-AIR_RATE * dt))
	local blocked = (hum ~= nil and hum.Sit) or (state ~= nil and BLOCK_STATES[state] == true)
	r.block += ((if blocked then 1 else 0) - r.block) * (1 - exp(-AIR_RATE * dt))

	-- evaluate and combine layers
	local s = r.s
	s.t, s.dt, s.ph, s.spd, s.turn, s.move = t, dt, r.ph, r.spd, r.turn, r.move
	local acc, accOv, accJ = r.acc, r.accOv, r.accJ
	for _, k in KEYS do
		acc[k] = ID
		accJ[k] = ID
		accOv[k] = 0
	end
	local lift, snap = 0, ID
	local m = r.move
	local useI, useW = m < 0.998, m > 0.002
	for _, L in layers do
		local spec = L.spec
		local ease = smooth01(L.w)
		local keep = if spec.lift > 0 then 1 else (spec.air or AIR_KEEP)
		local lw = ease * (1 - r.air * (1 - keep)) * (1 - r.block)
		s.rng, s.mem, s.bus = L.rng, L.mem, L.bus
		local bus = L.bus
		if bus then
			Sync.set(bus, "move", r.move)
			Sync.set(bus, "spd", r.spd)
			Sync.set(bus, "ph", r.ph)
			Sync.set(bus, "air", r.air)
			if stepSide then
				Sync.emit(bus, "step", stepSide)
			end
			if airEvent then
				Sync.emit(bus, airEvent, if airEvent == "land" then t - r.airAt else nil)
			end
		end
		if L.target > 0 then
			spec.tick(s)
		end
		local I, W = L.I, L.W
		if useI then
			resetOut(I)
			spec.idle(I, s)
		end
		if useW then
			resetOut(W)
			spec.walk(W, s)
		end
		local Ia, Wa = I :: any, W :: any
		for _, k in KEYS do
			local x: CFrame
			local ov: number
			if useI and useW then
				x = (Ia[k] :: CFrame):Lerp(Wa[k] :: CFrame, m)
				ov = lerp(I.ov[k], W.ov[k], m)
			elseif useW then
				x, ov = Wa[k], W.ov[k]
			else
				x, ov = Ia[k], I.ov[k]
			end
			if lw < 0.999 then
				x = ID:Lerp(x, lw)
			end
			acc[k] = acc[k] * x
			ov *= lw
			if ov > accOv[k] then
				accOv[k] = ov
			end
		end
		local lf = if useI and useW then lerp(I.lift, W.lift, m) elseif useW then W.lift else I.lift
		lift += lf * ease * (1 - r.block)
		local sn = if useI and useW then I.snap:Lerp(W.snap, m) elseif useW then W.snap else I.snap
		if sn ~= ID then
			snap = snap * ID:Lerp(sn, ease)
		end
	end
	for _, L in layers do
		local f = L.onLift
		if f then
			f(lift)
		end
		Sync.set(L.bus, "lift", lift)
	end

	-- compose this frame's transforms
	local alive = true
	for key, j in r.joints do
		local mo = j.m
		if mo.Parent == nil then
			alive = false
			continue
		end
		local cur = mo.Transform
		-- if nothing overwrote our last value, the animation underneath did not change
		local base = if j.out and same(cur, j.out) then j.base else cur
		j.base = base
		local x = acc[key]
		if key == "root" then
			x = CF(0, lift, 0) * snap * x
		end
		local ov = accOv[key]
		local b = if ov > 0.001 then base:Lerp(ID, min(ov, 1)) else base
		j.new = accJ[key] * j.r0i * x * j.r0 * b
	end
	-- foot solver: whatever the pose does, the soles never end up below the rest-pose floor
	-- (raising the root joint by d moves the whole body up by exactly d in root space)
	local rj = r.joints.root
	if rj and alive and r.feet then
		local sink = r.restLow - lowest(r, false) - 0.03
		if sink > 0 then
			rj.new = rj.r0i * CF(0, min(sink, 1.5), 0) * rj.r0 * rj.new
		end
	end
	for _, j in r.joints do
		if j.m.Parent then
			j.m.Transform = j.new
			j.out = j.new
		end
	end
	return true
end

local function onStepped(_time: number, dt: number)
	local t = os.clock()
	for char, r in runs do
		local ok, keep = pcall(step, r, t, dt)
		if not ok then
			warn("[AuraFX/Poses] " .. tostring(keep))
			pcall(restore, r)
			keep = false
		end
		if not keep and runs[char] == r then
			runs[char] = nil
		end
	end
	if next(runs) == nil and conn then
		conn:Disconnect()
		conn = nil
	end
end

function Poses.has(auraId: string): boolean
	return SPECS[auraId] ~= nil
end

function Poses.lift(auraId: string): number
	local d = SPECS[auraId]
	return if d then d.lift else 0
end

-- Starts the aura's animation set on the character. Any set already running there blends out
-- while this one blends in (re-attaching the same aura continues seamlessly).
-- Returns a stop function: blends out, then hands the joints back to the animation.
function Poses.start(char: Model, auraId: string, onLift: ((number) -> ())?, bus: Sync.Bus?): () -> ()
	local spec = SPECS[auraId]
	if not spec or typeof(char) ~= "Instance" then
		return function() end
	end
	local now = os.clock()
	local r = runs[char]
	if not r then
		local nr: Run = {
			char = char,
			joints = {},
			found = 0,
			nextScan = now + 0.5,
			scanUntil = now + 8,
			hum = nil,
			root = nil,
			layers = {},
			move = 0,
			ph = 0,
			spd = 0,
			turn = 0,
			look = nil,
			air = 0,
			block = 0,
			wasAir = false,
			airAt = now,
			stepN = 0,
			s = { t = now, dt = 0, ph = 0, spd = 0, move = 0, turn = 0, rng = Random.new(), mem = {}, bus = nil },
			acc = {},
			accOv = {},
			accJ = {},
			feet = nil,
			restLow = 0,
			byMotor = {},
		}
		scan(nr)
		runs[char] = nr
		r = nr
	end
	local w0 = 0
	local layers = r.layers
	for i = #layers, 1, -1 do
		local L = layers[i]
		if L.id == auraId and L.target > 0 then
			-- same aura re-attached (e.g. a rig change re-applies everything): take over its weight
			w0 = max(w0, L.w)
			table.remove(layers, i)
		else
			L.target = 0
			L.onLift = nil
		end
	end
	while #layers >= 3 do
		table.remove(layers, 1)
	end
	local L: Layer = {
		id = auraId,
		spec = spec,
		w = w0,
		target = 1,
		rng = Random.new(),
		mem = {},
		onLift = onLift,
		bus = bus,
		I = newOut(),
		W = newOut(),
	}
	table.insert(layers, L)
	if not conn then
		conn = RunService.Stepped:Connect(onStepped)
	end
	return function()
		L.target = 0
		local f = L.onLift
		L.onLift = nil
		if f then
			pcall(f, 0)
		end
	end
end

return Poses
