--!strict
-- AuraFX/Poses: procedural body poses for equipped auras (levitation, twitches, stances).
--
--   Poses.has(auraId) -> boolean
--   Poses.lift(auraId) -> number                 (max levitation in studs, 0 = stays grounded)
--   Poses.start(character, auraId, onLift?) -> stop()
--
-- Every frame in RunService.Stepped (after the Animator wrote this frame's joint transforms)
-- the pose builds one offset per logical joint and multiplies it ON TOP of the animation:
--     Transform = (C0rot^-1 * offset * C0rot) * animTransform
-- so walking / idle animations keep playing underneath. Offsets are expressed in the parent
-- part's axes (+X right, +Y up, -Z forward) about the joint pivot, identical for R6 and R15.
-- Poses blend in / out smoothly and weaken while the character walks. Levitation raises the
-- body through the root joint only; the HumanoidRootPart itself is never moved.

local RunService = game:GetService("RunService")

local Poses = {}

local CF, ANG = CFrame.new, CFrame.Angles
local ID = CFrame.identity
local TAU = math.pi * 2

local BLEND_IN = 0.7 -- seconds
local BLEND_OUT = 0.45

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

-- One frame of pose output (all offsets in parent space, full strength).
export type Out = {
	root: CFrame,
	neck: CFrame,
	ls: CFrame,
	rs: CFrame,
	lh: CFrame,
	rh: CFrame,
	lift: number, -- studs the body is raised (smoothly weighted by the runner)
	hard: number, -- 0..1: how much the animation underneath is suppressed (T-pose glitch)
	freeze: boolean, -- hold the last written transforms (stutter)
	snap: CFrame, -- extra root offset applied at full strength, not lift-tracked (teleport glitch)
}

type PoseFn = (t: number, dt: number, o: Out) -> ()

type Def = {
	lift: number,
	walk: number?, -- weight removed at full walking speed (default 0.6)
	make: (rng: Random) -> PoseFn,
}

type Joint = {
	m: Motor6D,
	r0: CFrame,
	r0i: CFrame,
	base: CFrame, -- last animation transform seen
	out: CFrame?, -- last transform we wrote
	frz: CFrame?,
}

type Run = {
	char: Model,
	id: string,
	def: Def,
	fn: PoseFn,
	joints: { [string]: Joint },
	found: number,
	nextScan: number,
	scanUntil: number,
	hum: Humanoid?,
	root: BasePart?,
	w: number,
	target: number,
	move: number,
	frozen: boolean,
	out: Out,
	onLift: ((number) -> ())?,
	dead: boolean,
}

---------------------------------------------------------------- helpers

local function smooth01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- arms spread sideways by `a` rad (0 = hanging, pi/2 = T-pose)
local function armsOut(o: Out, a: number, fwd: number?)
	local f = fwd or 0
	o.rs = ANG(0, 0, a) * ANG(f, 0, 0)
	o.ls = ANG(0, 0, -a) * ANG(f, 0, 0)
end

-- relaxed dangling legs for levitation (slightly apart, one knee-ish forward)
local function dangle(o: Out, t: number, amt: number)
	local s = math.sin(t * 0.9) * 0.05 * amt
	o.rh = ANG(0.12 * amt + s, 0, 0.06 * amt)
	o.lh = ANG(-0.06 * amt - s, 0, -0.06 * amt)
end

local function rnd(rng: Random, a: number): number
	return (rng:NextNumber() - 0.5) * 2 * a
end

-- tolerant CFrame equality (property round-trips may lose the last bits)
local function same(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 1e-4
		and (a.XVector - b.XVector).Magnitude < 1e-4
		and (a.YVector - b.YVector).Magnitude < 1e-4
end

local function rndAng(rng: Random, a: number): CFrame
	return ANG(rnd(rng, a), rnd(rng, a), rnd(rng, a))
end

---------------------------------------------------------------- pose library

local DEFS: { [string]: Def } = {}

-- random twitches: one limb snaps to a wrong angle for a few frames
DEFS.Glitch = {
	lift = 0,
	walk = 0.4,
	make = function(rng)
		local nextT, untilT = 0, 0
		local key = "neck"
		local off = ID
		local body = ID
		return function(t, _, o)
			if t >= nextT then
				nextT = t + 0.18 + rng:NextNumber() * 0.55
				untilT = t + 0.05 + rng:NextNumber() * 0.09
				key = KEYS[rng:NextInteger(1, #KEYS)]
				off = rndAng(rng, if key == "root" then 0.12 else 0.45)
				body = CF(rnd(rng, 0.14), rnd(rng, 0.05), rnd(rng, 0.14))
			end
			if t < untilT then
				(o :: any)[key] = off
				o.snap = body
			end
		end
	end,
}

-- stutter: the whole body freezes for a moment, then rubber-bands
DEFS.Lag = {
	lift = 0,
	walk = 0.2,
	make = function(rng)
		local nextT, untilT, bandUntil = 0, 0, 0
		local band = ID
		return function(t, _, o)
			if t >= nextT then
				nextT = t + 1.1 + rng:NextNumber() * 1.6
				untilT = t + 0.12 + rng:NextNumber() * 0.22
				bandUntil = untilT + 0.06
				band = CF(rnd(rng, 0.12), 0, 0.12 + rng:NextNumber() * 0.12)
			end
			if t < untilT then
				o.freeze = true
			elseif t < bandUntil then
				o.snap = band
			end
		end
	end,
}

-- projector flicker: tiny sideways offsets and a scan-wobble of the head
DEFS.Hologram = {
	lift = 0,
	walk = 0.5,
	make = function(rng)
		local nextT, untilT = 0, 0
		local off = ID
		return function(t, _, o)
			o.neck = ANG(0, math.sin(t * 0.6) * 0.08, 0)
			o.root = ANG(0, 0, math.sin(t * 0.9) * 0.02)
			if t >= nextT then
				nextT = t + 0.25 + rng:NextNumber() * 1.4
				untilT = t + 0.03 + rng:NextNumber() * 0.05
				off = CF(rnd(rng, 0.18), rnd(rng, 0.04), 0)
			end
			if t < untilT then
				o.snap = off
			end
		end
	end,
}

-- hunched, crawling-from-below stance
DEFS.Rootkit = {
	lift = 0,
	walk = 0.5,
	make = function()
		return function(t, _, o)
			local lean = 0.32 + math.sin(t * 1.1) * 0.03
			o.root = CF(0, -0.07, 0) * ANG(-lean, 0, 0)
			o.neck = ANG(lean * 0.75, math.sin(t * 0.5) * 0.15, 0)
			o.rs = ANG(0, 0, -0.12) * ANG(0.45 + math.sin(t * 1.3) * 0.05, 0, 0)
			o.ls = ANG(0, 0, 0.12) * ANG(0.45 + math.sin(t * 1.3 + 1) * 0.05, 0, 0)
			o.rh = ANG(lean - 0.05, 0, 0.06)
			o.lh = ANG(lean + 0.1, 0, -0.06)
		end
	end,
}

-- gentle superposition float with brief phase-jumps
DEFS.Quantum = {
	lift = 0.65,
	make = function(rng)
		local nextT, untilT = 0, 0
		local jump = ID
		return function(t, _, o)
			o.lift = 0.65 + math.sin(t * 1.2) * 0.14
			armsOut(o, 0.22 + math.sin(t * 0.8) * 0.05, 0.08)
			dangle(o, t, 0.7)
			o.neck = ANG(0.06, math.sin(t * 0.4) * 0.1, 0)
			if t >= nextT then
				nextT = t + 1.6 + rng:NextNumber() * 2.4
				untilT = t + 0.05
				jump = CF(rnd(rng, 0.35), 0, rnd(rng, 0.35))
			end
			if t < untilT then
				o.snap = jump
			end
		end
	end,
}

-- vibrating at 300 %: fine high-frequency shake that surges
DEFS.Overclocked = {
	lift = 0,
	walk = 0.3,
	make = function(rng)
		return function(t, _, o)
			local k = 0.5 + 0.5 * math.max(0, math.sin(t * 0.9)) ^ 4
			local a = 0.03 * (0.6 + k)
			o.root = CF(rnd(rng, 0.035 * k), rnd(rng, 0.02), rnd(rng, 0.035 * k)) * rndAng(rng, a * 0.5)
			o.neck = rndAng(rng, a * 1.4)
			o.rs = ANG(0, 0, 0.12) * rndAng(rng, a)
			o.ls = ANG(0, 0, -0.12) * rndAng(rng, a)
		end
	end,
}

-- head tilted, right hand raised to the temple, "receiving" twitches
DEFS.NeuralLink = {
	lift = 0,
	walk = 0.6,
	make = function(rng)
		local nextT, untilT = 0, 0
		return function(t, _, o)
			local twitch = 0
			if t >= nextT then
				nextT = t + 2 + rng:NextNumber() * 2.5
				untilT = t + 0.25
			end
			if t < untilT then
				twitch = math.sin((untilT - t) * 60) * 0.06
			end
			o.neck = ANG(-0.1 + twitch, 0.12, 0.26 + math.sin(t * 0.7) * 0.04)
			o.rs = ANG(0, 0, 0.42) * ANG(2.55 + math.sin(t * 1.4) * 0.04, 0, 0) * ANG(0, -0.4, 0)
			o.ls = ANG(0, 0, -0.08) * ANG(0.1, 0, 0)
			o.root = ANG(0, 0, -0.04)
		end
	end,
}

-- guard stance: wide feet, lowered, forearms up like a shield
DEFS.Sentinel = {
	lift = 0,
	walk = 0.7,
	make = function()
		return function(t, _, o)
			local br = math.sin(t * 1.6) * 0.03
			o.root = CF(0, -0.1 + br, 0) * ANG(-0.06, 0.18, 0)
			o.neck = ANG(0.02, -0.18, 0)
			o.rs = ANG(0, 0, -0.32) * ANG(1.05 + br, 0, 0)
			o.ls = ANG(0, 0, 0.18) * ANG(1.3 + br, 0, 0)
			o.rh = ANG(0.06, 0, 0.22)
			o.lh = ANG(-0.1, 0, -0.22)
		end
	end,
}

-- levitating with arms slightly out
DEFS.Kernel = {
	lift = 1.3,
	make = function()
		return function(t, _, o)
			o.lift = 1.3 + math.sin(t * 1.1) * 0.18
			armsOut(o, 0.42 + math.sin(t * 0.9) * 0.05, 0.12)
			dangle(o, t, 1)
			o.neck = ANG(-0.05, 0, 0)
			o.root = ANG(0.04, math.sin(t * 0.3) * 0.12, 0)
		end
	end,
}

-- slow, drifting float, head bowed
DEFS.GhostProtocol = {
	lift = 1.1,
	make = function()
		return function(t, _, o)
			o.lift = 1.1 + math.sin(t * 0.6) * 0.28
			o.root = ANG(math.sin(t * 0.45) * 0.05, math.sin(t * 0.25) * 0.18, math.sin(t * 0.37) * 0.04)
			o.neck = ANG(-0.22, 0, math.sin(t * 0.3) * 0.05)
			armsOut(o, 0.14 + math.sin(t * 0.6) * 0.04, -0.12)
			o.rh = ANG(0.18, 0, 0.03)
			o.lh = ANG(0.1, 0, -0.03)
		end
	end,
}

-- high levitation, arms spread like wings with a slow flap, chin up
DEFS.CyberSeraph = {
	lift = 1.9,
	make = function()
		return function(t, _, o)
			local flap = math.sin(t * 1.5)
			o.lift = 1.9 + math.sin(t * 1.5 - 0.6) * 0.22
			armsOut(o, 1.2 + flap * 0.18, -0.25)
			o.neck = ANG(0.18, 0, 0)
			o.root = ANG(-0.06, 0, 0)
			o.rh = ANG(-0.1, 0, 0.03)
			o.lh = ANG(-0.04, 0, -0.03)
		end
	end,
}

-- frozen T-pose glitch every few seconds (animation suppressed while frozen)
DEFS.BlueScreen = {
	lift = 0,
	walk = 0.35,
	make = function(rng)
		local cycle = 5.2
		local q = ID
		local nextQ = 0
		return function(t, _, o)
			local ph = t % cycle
			if ph > 3.4 and ph < 4.7 then
				o.hard = 1
				armsOut(o, math.pi / 2)
				o.lift = 0
				if t >= nextQ then
					nextQ = t + 0.09
					q = CF(rnd(rng, 0.06), 0, 0) * ANG(0, rnd(rng, 0.05), 0)
				end
				o.root = q
			else
				o.neck = ANG(-0.08, 0, 0)
			end
		end
	end,
}

-- twisted, wrong-angled limbs that keep snapping
DEFS.Corruption = {
	lift = 0,
	walk = 0.45,
	make = function(rng)
		local nextT = 0
		local j: { [string]: CFrame } = {}
		for _, k in KEYS do
			j[k] = ID
		end
		return function(t, _, o)
			if t >= nextT then
				nextT = t + 0.08 + rng:NextNumber() * 0.28
				local k = KEYS[rng:NextInteger(2, #KEYS)]
				j[k] = rndAng(rng, 0.18)
			end
			o.root = ANG(0.05, 0.22, 0.09) * j.root
			o.neck = ANG(-0.1, -0.3, 0.38) * j.neck
			o.rs = ANG(0, 0, 0.3) * ANG(0.2, 0.7, 0) * j.rs
			o.ls = ANG(0, 0, -0.12) * ANG(-0.25, -0.3, 0) * j.ls
			o.rh = ANG(0.1, 0.2, 0.08) * j.rh
			o.lh = ANG(-0.06, -0.15, -0.05) * j.lh
		end
	end,
}

-- violent full-body shaking
DEFS.KernelPanic = {
	lift = 0,
	walk = 0.3,
	make = function(rng)
		local nextT = 0
		local cur: { [string]: CFrame } = {}
		local sh = ID
		return function(t, _, o)
			if t >= nextT then
				nextT = t + 1 / 30
				local k = 0.7 + 0.3 * math.sin(t * 2.3)
				sh = CF(rnd(rng, 0.13 * k), rnd(rng, 0.06 * k), rnd(rng, 0.13 * k)) * rndAng(rng, 0.07 * k)
				cur.neck = rndAng(rng, 0.28 * k)
				cur.rs = ANG(0, 0, 0.35) * rndAng(rng, 0.3 * k)
				cur.ls = ANG(0, 0, -0.35) * rndAng(rng, 0.3 * k)
				cur.rh = rndAng(rng, 0.1 * k)
				cur.lh = rndAng(rng, 0.1 * k)
			end
			o.root = sh
			o.neck = cur.neck or ID
			o.rs = cur.rs or ID
			o.ls = cur.ls or ID
			o.rh = cur.rh or ID
			o.lh = cur.lh or ID
		end
	end,
}

-- shared "ascended" levitation: arms out, slow torso sway around the vertical axis
local function ascend(height: number, arms: number, fwd: number, sway: number, chin: number): Def
	return {
		lift = height,
		make = function()
			return function(t, _, o)
				o.lift = height + math.sin(t * 0.9) * 0.2
				o.root = ANG(0, math.sin(t * 0.32) * sway, math.sin(t * 0.21) * 0.03)
				armsOut(o, arms + math.sin(t * 0.7) * 0.08, fwd + math.sin(t * 0.5) * 0.06)
				dangle(o, t, 1.2)
				o.neck = ANG(chin, -math.sin(t * 0.32) * sway * 0.4, 0)
			end
		end,
	}
end

DEFS.EventHorizon = ascend(2, 0.6, 0.35, 0.5, -0.12)
DEFS.Singularity = ascend(2.4, 1.15, -0.1, 0.6, 0.2)
DEFS.Architect = ascend(2.5, 0.85, 0.3, 0.45, 0.05)

-- levitating, with occasional teleport-glitch jumps of the whole body
DEFS.Redacted = {
	lift = 2,
	make = function(rng)
		local nextT, untilT = 0, 0
		local jump = ID
		return function(t, _, o)
			o.lift = 2 + math.sin(t * 0.8) * 0.18
			armsOut(o, 0.5, 0.1)
			dangle(o, t, 1)
			o.neck = ANG(-0.15, 0, 0)
			if t >= nextT then
				nextT = t + 1.8 + rng:NextNumber() * 2.4
				untilT = t + 0.07 + rng:NextNumber() * 0.1
				local a = rng:NextNumber() * TAU
				local r = 0.6 + rng:NextNumber() * 0.9
				jump = CF(math.cos(a) * r, rnd(rng, 0.35), math.sin(a) * r) * ANG(0, rnd(rng, 0.8), 0)
			end
			if t < untilT then
				o.snap = jump
			end
		end
	end,
}

---------------------------------------------------------------- runner

local runs: { [Model]: Run } = {}
local conn: RBXScriptConnection? = nil

local function scan(r: Run)
	for _, d in r.char:GetDescendants() do
		if d:IsA("Motor6D") then
			local key = JOINT_NAMES[d.Name]
			if key and not r.joints[key] then
				local rot = d.C0.Rotation
				r.joints[key] = { m = d, r0 = rot, r0i = rot:Inverse(), base = d.Transform, out = nil, frz = nil }
				r.found += 1
			end
		end
	end
	r.hum = r.char:FindFirstChildOfClass("Humanoid")
	local root = r.char:FindFirstChild("HumanoidRootPart")
	r.root = if root and root:IsA("BasePart") then root else nil
end

local function restore(r: Run)
	for _, j in r.joints do
		if j.m.Parent and j.out and same(j.m.Transform, j.out) then
			j.m.Transform = j.base
		end
	end
	if r.onLift then
		pcall(r.onLift, 0)
	end
end

local function newOut(): Out
	return { root = ID, neck = ID, ls = ID, rs = ID, lh = ID, rh = ID, lift = 0, hard = 0, freeze = false, snap = ID }
end

local function resetOut(o: Out)
	o.root, o.neck, o.ls, o.rs, o.lh, o.rh = ID, ID, ID, ID, ID, ID
	o.lift, o.hard, o.freeze, o.snap = 0, 0, false, ID
end

local function step(r: Run, t: number, dt: number): boolean
	if r.dead or r.char.Parent == nil then
		return false
	end
	if r.found < 6 and t >= r.nextScan and t < r.scanUntil then
		r.nextScan = t + 0.5
		scan(r)
	end
	-- blend weight (linear ramp, eased)
	if r.target > r.w then
		r.w = math.min(r.target, r.w + dt / BLEND_IN)
	else
		r.w = math.max(r.target, r.w - dt / BLEND_OUT)
	end
	if r.target == 0 and r.w <= 0 then
		restore(r)
		return false
	end
	-- walking factor (MoveDirection for the local player, velocity for everyone else)
	local moving = 0
	local hum = r.hum
	if hum and hum.Parent then
		moving = math.clamp(hum.MoveDirection.Magnitude, 0, 1)
	end
	local root = r.root
	if root and root.Parent then
		local v = root.AssemblyLinearVelocity
		moving = math.max(moving, math.clamp((Vector3.new(v.X, 0, v.Z).Magnitude - 1) / 8, 0, 1))
	end
	r.move += (moving - r.move) * (1 - math.exp(-dt * 6))

	local o = r.out
	resetOut(o)
	r.fn(t, dt, o)

	local ease = smooth01(r.w)
	local w = ease * (1 - r.move * (r.def.walk or 0.6))
	local lift = o.lift * ease * (1 - r.move * 0.45)
	if r.onLift then
		r.onLift(lift)
	end

	if o.freeze and not r.frozen then
		r.frozen = true
		for _, j in r.joints do
			j.frz = j.out or j.m.Transform
		end
	elseif not o.freeze then
		r.frozen = false
	end

	local hard = o.hard * w
	local snap = if o.snap == ID then ID else ID:Lerp(o.snap, math.min(1, ease * 1.5))
	for key, j in r.joints do
		local m = j.m
		if m.Parent == nil then
			continue
		end
		local cur = m.Transform
		-- if nothing overwrote our last value, the animation underneath did not change
		local base = if j.out and same(cur, j.out) then j.base else cur
		j.base = base
		local out: CFrame
		if r.frozen and j.frz then
			out = j.frz
		else
			local x = (o :: any)[key] :: CFrame
			local xw = ID:Lerp(x, w)
			if key == "root" then
				xw = CF(0, lift, 0) * snap * xw
			end
			local b = if hard > 0 then base:Lerp(ID, hard) else base
			out = j.r0i * xw * j.r0 * b
		end
		m.Transform = out
		j.out = out
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
		if not keep then
			r.dead = true
			if runs[char] == r then
				runs[char] = nil
			end
		end
	end
	if next(runs) == nil and conn then
		conn:Disconnect()
		conn = nil
	end
end

function Poses.has(auraId: string): boolean
	return DEFS[auraId] ~= nil
end

function Poses.lift(auraId: string): number
	local d = DEFS[auraId]
	return if d then d.lift else 0
end

-- Starts the aura's pose on the character (replacing any pose already running there).
-- Returns a stop function: blends out, then hands the joints back to the animation.
function Poses.start(char: Model, auraId: string, onLift: ((number) -> ())?): () -> ()
	local def = DEFS[auraId]
	if not def or typeof(char) ~= "Instance" then
		return function() end
	end
	local old = runs[char]
	local w0 = 0
	if old then
		-- re-attaching the same aura (e.g. a rig change re-applies everything): continue
		-- seamlessly from the old weight instead of dropping and blending in again
		if old.id == auraId then
			w0 = old.w
		end
		old.dead = true
		restore(old)
		runs[char] = nil
	end
	local now = os.clock()
	local r: Run = {
		char = char,
		id = auraId,
		def = def,
		fn = def.make(Random.new()),
		joints = {},
		found = 0,
		nextScan = now + 0.5,
		scanUntil = now + 8,
		hum = nil,
		root = nil,
		w = w0,
		target = 1,
		move = 0,
		frozen = false,
		out = newOut(),
		onLift = onLift,
		dead = false,
	}
	scan(r)
	runs[char] = r
	if not conn then
		conn = RunService.Stepped:Connect(onStepped)
	end
	return function()
		r.onLift = nil
		r.target = 0
		if r.w <= 0 and runs[char] == r then
			r.dead = true
			restore(r)
			runs[char] = nil
		end
	end
end

return Poses
