--!strict
-- AuraFX/Poses: per-aura character animation sets (idle stance + walk gait) for every aura.
-- Auras of 1 in 1,000 and rarer are defined here; the subtler sets for common auras come from
-- PosesLow (joint-space offsets, wrapped into specs with joint = true below).
--
--   Poses.has(auraId) -> boolean
--   Poses.lift(auraId) -> number                 (max levitation in studs, 0 = stays grounded)
--   Poses.start(character, auraId, onLift?) -> stop()
--
-- Every frame in RunService.Stepped (after the Animator wrote this frame's joint transforms)
-- each aura spec builds two poses, IDLE and WALK, which are blended by how fast the character
-- moves (~0.3 s cross-fade). A pose is one offset per logical joint, expressed in the parent
-- part's axes (+X right, +Y up, -Z forward) about the joint pivot, identical for R6 and R15:
--     Transform = (C0rot^-1 * offset * C0rot) * animTransform:Lerp(identity, override)
-- `override` (per joint, 0..1) suppresses the default animation underneath, which is how gaits
-- replace the stock walk cycle (hover-glide legs, robotic march...) instead of adding to it.
--
-- Sign cheat-sheet (parent space):  hips/shoulders ANG(+x) = limb swings FORWARD,
--   right limb ANG(0,0,+z) = outwards (left limb: -z),  root ANG(-x) = torso leans forward,
--   root ANG(0,0,+z) = leans left,  neck ANG(+x) = looks up, neck ANG(0,+y) = looks left.
--
-- Levitation raises the body through the root joint only; the HumanoidRootPart is never moved
-- (the lift is reported through onLift so root-anchored aura effects can follow it).
-- Switching auras cross-fades between the two animation sets; joints are handed back to the
-- animation untouched on stop, death, respawn and character removal.

local RunService = game:GetService("RunService")
local Config = require(script.Parent.Parent.Config)
local PosesLow = require(script.Parent.PosesLow)

local Poses = {}

local CF, ANG = CFrame.new, CFrame.Angles
local ID = CFrame.identity
local TAU = math.pi * 2
local PI = math.pi
local sin, cos, abs, clamp, exp, floor, min, max = math.sin, math.cos, math.abs, math.clamp, math.exp, math.floor, math.min, math.max

local MIN_CHANCE = 1000 -- auras rarer than (or equal to) 1 in this get an animation set
local BLEND_IN = 0.6 -- seconds, aura equipped
local BLEND_OUT = 0.4 -- seconds, aura removed
local MOVE_RATE = 9 -- 1/s exponential rate of the idle <-> walk blend (~0.3 s)
local AIR_RATE = 10 -- 1/s fade while jumping / falling
local STRIDE_HZ = 1.4 -- gait cycles per second at WalkSpeed 16
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
local LIMBS = { "ls", "rs", "lh", "rh" }

-- One frame of pose output (offsets at full strength, parent space).
export type Out = {
	root: CFrame,
	neck: CFrame,
	ls: CFrame,
	rs: CFrame,
	lh: CFrame,
	rh: CFrame,
	ov: { [string]: number }, -- per joint: 0 = add on top of the animation, 1 = replace it
	lift: number, -- studs the body is raised (levitating auras only)
	snap: CFrame, -- extra root offset (teleport / micro-jump glitches), parent space of the root
}

-- Per-frame motion context handed to every pose function.
export type S = {
	t: number, -- seconds (os.clock)
	dt: number,
	ph: number, -- gait phase in radians, advances with ground speed
	spd: number, -- ground speed / 16 (smoothed)
	turn: number, -- yaw rate in rad/s, + = turning left (smoothed)
	rng: Random,
	mem: { [string]: any }, -- per layer scratch state (timers, smoothed values)
}

type Fn = (o: Out, s: S) -> ()

type Spec = {
	lift: number, -- > 0 = levitating (also keeps the pose while airborne)
	joint: boolean?, -- true: offsets are Motor6D-space (PosesLow), multiplied straight onto the animation
	air: number?, -- weight kept while airborne (grounded poses, default AIR_KEEP)
	idle: Fn,
	walk: Fn,
}

---------------------------------------------------------------- motion helpers

local function smooth01(x: number): number
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- 0 -> 1 -> 0 envelope over p in 0..1 with a fast attack and a slower release
local function bell(p: number): number
	p = clamp(p, 0, 1)
	return sin(PI * p ^ 0.55)
end

-- squash a sine toward a square wave (k < 1): robotic, snappy motion
local function sq(x: number, k: number): number
	return if x >= 0 then x ^ k else -((-x) ^ k)
end

local function quant(x: number, step: number): number
	return floor(x / step + 0.5) * step
end

local function rnd(rng: Random, a: number): number
	return (rng:NextNumber() - 0.5) * 2 * a
end

local function rndAng(rng: Random, a: number): CFrame
	return ANG(rnd(rng, a), rnd(rng, a), rnd(rng, a))
end

-- smooth pseudo-noise in -1..1
local function wob(t: number, f: number, seed: number): number
	return sin(t * f + seed) * 0.62 + sin(t * f * 2.37 + seed * 1.9) * 0.38
end

-- beat envelope: 1 right on the beat, decaying until the next one
local function beat(t: number, bpm: number, sharp: number): number
	local p = (t * bpm / 60) % 1
	return exp(-p * sharp)
end

-- exponential follow of a remembered value
local function follow(s: S, key: string, target: number, rate: number): number
	local v = (s.mem[key] :: number?) or target
	v += (target - v) * (1 - exp(-rate * s.dt))
	s.mem[key] = v
	return v
end

-- linear "servo" follow (constant angular speed, stops dead): robots
local function servo(s: S, key: string, target: number, speed: number): number
	local v = (s.mem[key] :: number?) or target
	v += clamp(target - v, -speed * s.dt, speed * s.dt)
	s.mem[key] = v
	return v
end

-- Timed random event. Returns progress 0..1 while active (-1 otherwise) and the event table;
-- `e.fresh` is true on the first frame of an occurrence (store random payload in `e` then:
-- only the first caller of the frame sees it, later callers read the payload).
local function ev(s: S, key: string, g0: number, g1: number, d0: number, d1: number): (number, { [string]: any })
	local t = s.t
	local e = s.mem[key]
	if not e then
		e = { n = t + g0 * 0.5 + s.rng:NextNumber() * (g1 - g0), s = 0, u = 0, fresh = false }
		s.mem[key] = e
	end
	e.fresh = false
	if t >= e.n then
		e.s = t
		e.u = t + d0 + s.rng:NextNumber() * (d1 - d0)
		e.n = e.u + g0 + s.rng:NextNumber() * (g1 - g0)
		e.fresh = true
	end
	if t < e.u then
		return (t - e.s) / max(e.u - e.s, 1e-3), e
	end
	return -1, e
end

local function limbs(o: Out, v: number)
	for _, k in LIMBS do
		o.ov[k] = v
	end
end

local function allOv(o: Out, v: number)
	for _, k in KEYS do
		o.ov[k] = v
	end
end

-- arms spread sideways by `a` rad (0 = hanging, pi/2 = T-pose), pitched forward by `fwd`
local function armsOut(o: Out, a: number, fwd: number?)
	local f = fwd or 0
	o.rs = ANG(0, 0, a) * ANG(f, 0, 0)
	o.ls = ANG(0, 0, -a) * ANG(f, 0, 0)
end

-- relaxed dangling legs for levitation (slightly apart, one a bit forward)
local function dangle(o: Out, t: number, amt: number)
	local s = sin(t * 0.9) * 0.05 * amt
	o.rh = ANG(0.12 * amt + s, 0, 0.06 * amt)
	o.lh = ANG(-0.06 * amt - s, 0, -0.06 * amt)
end

-- torso pitched forward by `a` about its centre with the legs kept vertical and the feet on
-- the ground (the hips rise by 1 - cos a when the torso tips, so the root drops by that much)
local function hunch(o: Out, a: number, yaw: number?, roll: number?)
	local r = roll or 0
	o.root = CF(0, -(1 - cos(a)), 0) * ANG(-a, yaw or 0, r)
	o.rh = ANG(a, 0, -r)
	o.lh = ANG(a, 0, -r)
end

-- Procedural gait that replaces the stock walk cycle. Without knees (R6) the body may only
-- drop while the legs are spread: a 1-stud-thick leg swung by q gets 2(1 - cos q) shorter but
-- its heel corner dips by 0.5 sin q, so `bob` is clamped to that clearance (the runner's foot
-- solver catches anything left over).
type Gait = {
	leg: number, -- hip swing amplitude (rad)
	arm: number, -- shoulder swing amplitude (rad)
	armOut: number?, -- arms spread
	armFwd: number?, -- arm rest pitch relative to gravity (negative = swept back)
	lean: number?, -- torso forward lean (negative = leaning back, chest out)
	bob: number?, -- max body drop at full stride
	twist: number?, -- shoulder yaw counter-swing
	roll: number?, -- hip/torso roll per step
	chin: number?, -- extra head pitch (+ = up)
	legOut: number?, -- stance width
	sq: number?, -- square-wave shaping (robotic)
	k: number?, -- cadence multiplier
	steps: number?, -- quantise the cycle into N discrete poses (stop-motion)
	ovr: number?, -- override weight of the stock walk on the legs (default 1)
	armOvr: number?, -- override on the arms (default = ovr)
}

local function gait(o: Out, s: S, p: Gait, phase: number?): number
	local ph = phase or s.ph * (p.k or 1)
	if p.steps then
		ph = quant(ph, TAU / p.steps)
	end
	local x = sin(ph)
	if p.sq then
		x = sq(x, p.sq)
	end
	local a = clamp(s.spd, 0.55, 1.25)
	local leg, arm = p.leg * a, p.arm * a
	local lean = p.lean or 0
	local q = leg * abs(x)
	local drop = min((p.bob or 0) * x * x, max(0, 2 * (1 - cos(q)) - 0.5 * sin(q)))
	local tw, rl = (p.twist or 0) * x, (p.roll or 0) * x
	o.root = CF(0, -(1 - cos(lean)) - drop, 0) * ANG(-lean, tw, rl)
	local lo = p.legOut or 0
	o.rh = ANG(0, -tw, 0) * ANG(lean + leg * x, 0, lo - rl)
	o.lh = ANG(0, -tw, 0) * ANG(lean - leg * x, 0, -lo - rl)
	local ao, af = p.armOut or 0.06, (p.armFwd or 0) + lean
	o.rs = ANG(0, 0, ao) * ANG(af - arm * x, 0, 0)
	o.ls = ANG(0, 0, -ao) * ANG(af + arm * x, 0, 0)
	o.neck = ANG(lean * 0.85 + (p.chin or 0), -tw * 0.85, -rl * 0.5)
	local ov = p.ovr or 1
	local aov = p.armOvr or ov
	o.ov.rh, o.ov.lh, o.ov.rs, o.ov.ls = ov, ov, aov, aov
	return x
end

-- Hover-glide for levitating auras: no leg swing at all (stock walk fully overridden), legs
-- together trailing behind, body leaning into the motion and banking into turns.
type Hover = {
	lift: number,
	lean: number,
	trail: number?, -- legs swept back (rad)
	armOut: number?,
	armBack: number?, -- arms swept back (rad, relative to the torso)
	bob: number?,
	bobRate: number?,
	bank: number?, -- roll per rad/s of turning
	chin: number?,
	flap: number?, -- slow arm wave amplitude
}

local function hover(o: Out, s: S, p: Hover)
	local t = s.t
	o.lift = p.lift + sin(t * (p.bobRate or 1.5)) * (p.bob or 0.12)
	local bank = clamp(s.turn * (p.bank or 0.12), -0.45, 0.45)
	local lean = p.lean
	o.root = ANG(-lean, 0, bank)
	local f = sin(t * 2.2) * 0.04
	local tr = p.trail or 0.2
	o.rh = ANG(-tr + f, 0, 0.025)
	o.lh = ANG(-tr - f + 0.07, 0, -0.025)
	local ao, ab = p.armOut or 0.25, p.armBack or 0.35
	local fl = sin(t * 1.3) * (p.flap or 0.04)
	o.rs = ANG(0, 0, ao + fl) * ANG(-ab, 0, 0)
	o.ls = ANG(0, 0, -ao - fl) * ANG(-ab, 0, 0)
	o.neck = ANG(lean * 0.75 + (p.chin or 0), 0, -bank * 0.4)
	limbs(o, 1)
end

-- right arm raised so the fingers rest on the temple (head tilted into it)
local function templeArm(t: number): CFrame
	return ANG(0, 0, 0.42) * ANG(2.55 + sin(t * 1.4) * 0.04, 0, 0) * ANG(0, -0.4, 0)
end

-- arms crossed over the chest (right arm on top)
local function crossedArms(o: Out, breath: number)
	o.rs = ANG(0, 0.62, 0) * ANG(1.36 + breath, 0, 0)
	o.ls = ANG(0, -0.6, 0) * ANG(1.2 + breath, 0, 0)
end

---------------------------------------------------------------- animation sets
-- Rare tier: subtle and stylish. Each tier up gets bigger, more elaborate motion; Mythic and
-- above levitate (except the grounded "crash" auras), Singularity tier is fully dramatic.

local SPECS: { [string]: Spec } = {}

---------------------------------------------------------------- RARE (1 in 1,000+)

-- Glitch: reality tears around you. Idle: relaxed stance broken by single-frame limb snaps
-- and RGB-split micro-teleports. Walk: glitch-step, the stride stutters (phase freezes) and
-- the body micro-teleports forward.
local G_GLITCH: Gait = { leg = 0.55, arm = 0.45, bob = 0.12, roll = 0.03 }
SPECS.Glitch = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		o.root = ANG(0, sin(t * 0.37) * 0.05, sin(t * 0.8) * 0.025)
		o.neck = ANG(-0.03 + sin(t * 0.5) * 0.03, sin(t * 0.29) * 0.14, 0)
		o.rs = ANG(0, 0, 0.07) * ANG(0.04, 0, 0)
		o.ls = ANG(0, 0, -0.07) * ANG(0.04, 0, 0)
		local p, e = ev(s, "tw", 0.35, 1.2, 0.05, 0.13)
		if e.fresh then
			e.k = KEYS[s.rng:NextInteger(2, #KEYS)]
			e.cf = rndAng(s.rng, 0.42)
			e.sn = CF(rnd(s.rng, 0.16), 0, rnd(s.rng, 0.12))
		end
		if p >= 0 then
			local o2 = o :: any
			o2[e.k] = e.cf * o2[e.k]
			o.snap = e.sn
		end
	end,
	walk = function(o, s)
		local p, e = ev(s, "stutter", 0.45, 1.3, 0.07, 0.15)
		if e.fresh then
			e.ph = s.ph
		end
		gait(o, s, G_GLITCH, if p >= 0 then e.ph else nil)
		local q, j = ev(s, "jump", 0.3, 0.8, 0.04, 0.08)
		if j.fresh then
			j.sn = CF(rnd(s.rng, 0.22), 0, -0.15 - s.rng:NextNumber() * 0.3)
			j.k = LIMBS[s.rng:NextInteger(1, #LIMBS)]
			j.cf = rndAng(s.rng, 0.3)
		end
		if q >= 0 then
			o.snap = j.sn
			local o2 = o :: any
			o2[j.k] = j.cf * o2[j.k]
		end
	end,
}

-- Trojan: the innocent gift. Idle: hands clasped behind the back, rocking on the heels,
-- slyly glancing around. Walk: sneaky low run with the arms swept back.
local G_TROJAN: Gait =
	{ leg = 0.72, arm = 0.22, armFwd = -0.75, armOut = 0.16, lean = 0.38, bob = 0.16, chin = 0.12, twist = 0.06, k = 1.1 }
SPECS.Trojan = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local rock = sin(t * 1.3) * 0.035
		hunch(o, rock)
		o.rs = ANG(0, 0, -0.12) * ANG(-0.36 - rock, 0, 0)
		o.ls = ANG(0, 0, 0.12) * ANG(-0.36 - rock, 0, 0)
		local _, e = ev(s, "look", 1.8, 3.6, 0, 0)
		if e.fresh then
			e.y = if s.rng:NextNumber() < 0.3 then 0 else rnd(s.rng, 0.65)
		end
		local y = follow(s, "ly", e.y or 0, 5)
		o.neck = ANG(-0.04, y, -y * 0.15 + 0.06)
		o.root = o.root * ANG(0, y * 0.12, 0)
	end,
	walk = function(o, s)
		gait(o, s, G_TROJAN)
		local y = follow(s, "wy", sin(s.t * 0.7) * 0.25, 3)
		o.neck = o.neck * ANG(0, y, 0)
	end,
}

-- Phantom Ping: a notification from nobody. Idle: calm, until a "ping" makes the head snap
-- toward the sound with a startled shrug. Walk: light, floaty steps, glancing over a shoulder.
local G_PHANTOM: Gait = { leg = 0.45, arm = 0.3, bob = 0.06, k = 0.9, roll = 0.02 }
SPECS.PhantomPing = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local br = sin(t * 1.1)
		o.root = ANG(br * 0.012, 0, sin(t * 0.45) * 0.015)
		o.neck = ANG(br * 0.02, sin(t * 0.3) * 0.08, 0)
		o.rs = ANG(0, 0, 0.06) * ANG(0.03, 0, 0)
		o.ls = ANG(0, 0, -0.06) * ANG(0.03, 0, 0)
		local p, e = ev(s, "ping", 2.5, 4.5, 1.5, 1.9)
		if e.fresh then
			e.side = if s.rng:NextNumber() < 0.5 then -1 else 1
		end
		if p >= 0 then
			local b = bell(p)
			local side = e.side :: number
			o.neck = o.neck * ANG(0.12 * b, 0.8 * side * b, -0.1 * side * b)
			o.root = o.root * ANG(0.03 * b, 0.12 * side * b, 0)
			local shrug = 0.14 * bell(min(1, p * 2.5))
			o.rs = ANG(0, 0, 0.06 + shrug) * ANG(0.03, 0, 0)
			o.ls = ANG(0, 0, -0.06 - shrug) * ANG(0.03, 0, 0)
		end
	end,
	walk = function(o, s)
		gait(o, s, G_PHANTOM)
		local p, e = ev(s, "glance", 2.2, 4, 0.9, 1.2)
		if e.fresh then
			e.side = if s.rng:NextNumber() < 0.5 then -1 else 1
		end
		if p >= 0 then
			local b = bell(p)
			o.neck = o.neck * ANG(0, 0.95 * (e.side :: number) * b, 0)
			o.root = o.root * ANG(0, 0.12 * (e.side :: number) * b, 0)
		end
	end,
}

-- Neon Pulse: the city's heartbeat. Idle: lub-dub heartbeat thumps through the chest and
-- shoulders (72 bpm). Walk: springy beat-walk, every footfall lands like a pulse.
local G_NEON: Gait = { leg = 0.55, arm = 0.5, armFwd = 0.12, bob = 0.14, roll = 0.04 }
SPECS.NeonPulse = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local bp = (t * 72 / 60) % 1
		local h = exp(-((bp / 0.05) ^ 2)) + 0.7 * exp(-(((bp - 0.18) / 0.05) ^ 2))
		o.root = CF(0, h * 0.03, 0) * ANG(h * 0.035, sin(t * 0.4) * 0.05, 0)
		o.neck = ANG(-0.04 - h * 0.06, sin(t * 0.33) * 0.1, 0)
		local a = 0.14 + h * 0.07
		o.rs = ANG(0, 0, a) * ANG(0.08, 0, 0)
		o.ls = ANG(0, 0, -a) * ANG(0.08, 0, 0)
	end,
	walk = function(o, s)
		local x = gait(o, s, G_NEON)
		local pulse = (x * x) ^ 6
		o.neck = o.neck * ANG(-0.08 * pulse, 0, 0)
		o.rs = ANG(0, 0, 0.05 * pulse) * o.rs
		o.ls = ANG(0, 0, -0.05 * pulse) * o.ls
	end,
}

-- Botnet: ten thousand machines. Idle: robotic micro-twitches, the head and arms snap between
-- discrete angles in sync. Walk: stiff stop-motion march.
local G_BOTNET: Gait = { leg = 0.42, arm = 0.38, sq = 0.3, steps = 12, bob = 0.08, k = 0.95, armOut = 0.04 }
SPECS.Botnet = {
	lift = 0,
	idle = function(o, s)
		local _, e = ev(s, "tick", 0.45, 1.5, 0, 0)
		if e.fresh or not e.hy then
			e.hy = quant(rnd(s.rng, 0.5), 0.125)
			e.hp = quant(rnd(s.rng, 0.12), 0.06)
			e.ra = quant(rnd(s.rng, 0.15), 0.05)
			e.la = quant(rnd(s.rng, 0.15), 0.05)
		end
		local p = ev(s, "buzz", 1.6, 3.2, 0.1, 0.16)
		local buzz = if p >= 0 then (if floor(s.t * 40) % 2 == 0 then 0.05 else -0.05) else 0
		o.neck = ANG(e.hp + buzz, e.hy, 0)
		o.rs = ANG(0, 0, 0.1) * ANG(0.12 + e.ra + buzz, 0, 0)
		o.ls = ANG(0, 0, -0.1) * ANG(0.12 + e.la - buzz, 0, 0)
		o.root = ANG(0, quant(sin(s.t * 0.4) * 0.06, 0.03), 0)
	end,
	walk = function(o, s)
		gait(o, s, G_BOTNET)
		local _, e = ev(s, "wtick", 0.6, 1.4, 0, 0)
		if e.fresh or not e.hy then
			e.hy = quant(rnd(s.rng, 0.3), 0.15)
		end
		o.neck = ANG(0, e.hy, 0)
	end,
}

-- Cryptic: encrypted with a key no one has. Idle: hands weave slow cipher circles in front of
-- the chest, eyes on them. Walk: keeps weaving while walking.
local G_CRYPTIC: Gait = { leg = 0.5, arm = 0, bob = 0.08, roll = 0.02 }
local function weave(o: Out, t: number, amt: number)
	local a = t * 1.7
	o.rs = ANG(0, 0.35 + cos(a) * 0.14 * amt, 0) * ANG(0.95 + sin(a) * 0.16 * amt, 0, 0.05)
	o.ls = ANG(0, -0.35 + cos(a + PI) * 0.14 * amt, 0) * ANG(0.95 + sin(a + PI) * 0.16 * amt, 0, -0.05)
end
SPECS.Cryptic = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		weave(o, t, 1)
		o.neck = ANG(-0.2 + sin(t * 0.85) * 0.03, sin(t * 0.85) * 0.08, 0)
		o.root = ANG(0, sin(t * 0.85) * 0.05, sin(t * 0.6) * 0.015)
	end,
	walk = function(o, s)
		gait(o, s, G_CRYPTIC)
		weave(o, s.t, 0.6)
		o.neck = o.neck * ANG(-0.12, 0, 0)
	end,
}

-- Deepfake: your face, not your face. Idle: uncanny slow head tilt that snaps to a mirrored
-- angle, a hand sometimes adjusting the "mask". Walk: normal stride, the head lags turns and
-- stays oddly tilted.
local G_DEEP: Gait = { leg = 0.5, arm = 0.42, bob = 0.1, roll = 0.03 }
SPECS.Deepfake = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local _, sw = ev(s, "swap", 2.5, 5, 0, 0)
		if sw.fresh or not sw.side then
			sw.side = if sw.side == 1 then -1 else 1
		end
		local side = follow(s, "side", sw.side :: number, 22)
		o.neck = ANG(-0.04, side * 0.12 + sin(t * 0.4) * 0.05, side * (0.2 + sin(t * 0.7) * 0.04))
		o.root = ANG(0, 0, sin(t * 0.5) * 0.015)
		o.rs = ANG(0, 0, 0.05)
		o.ls = ANG(0, 0, -0.05)
		local p = ev(s, "touch", 4, 7, 1.7, 2.1)
		if p >= 0 then
			local b = bell(p)
			o.ls = ID:Lerp(ANG(0, 0, -0.38) * ANG(2.5, 0, 0) * ANG(0, 0.45, 0), b)
			o.neck = o.neck * ANG(0.06 * b, -0.15 * b, 0)
		end
	end,
	walk = function(o, s)
		gait(o, s, G_DEEP)
		local lag = follow(s, "lag", clamp(-s.turn * 0.22, -0.6, 0.6), 4)
		o.neck = o.neck * ANG(0, lag, 0.17)
	end,
}

-- Darkweb: not indexed, not safe. Idle: hooded lurker, hunched, hands in the hoodie pocket,
-- slow suspicious scans. Walk: sneaky low run with the arms back.
local G_DARK: Gait =
	{ leg = 0.66, arm = 0.18, armFwd = -0.85, armOut = 0.2, lean = 0.42, bob = 0.15, chin = 0.18, k = 1.08 }
SPECS.Darkweb = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local lean = 0.2 + sin(t * 0.9) * 0.015
		hunch(o, lean, sin(t * 0.25) * 0.05)
		o.rs = ANG(0, 0.3, 0) * ANG(0.42 + lean, 0, -0.12)
		o.ls = ANG(0, -0.3, 0) * ANG(0.42 + lean, 0, 0.12)
		local _, e = ev(s, "scan", 1.4, 3, 0, 0)
		if e.fresh or not e.y then
			e.y = rnd(s.rng, 0.45)
		end
		local y = follow(s, "y", e.y :: number, 2.5)
		o.neck = ANG(lean * 0.6 + 0.08, y, 0)
	end,
	walk = function(o, s)
		gait(o, s, G_DARK)
	end,
}

-- Virus: spreads by looking at it. Idle: sickly sway, lolling head, coughing convulsions.
-- Walk: lurching limp, the left leg drags.
SPECS.Virus = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local sway = sin(t * 0.7)
		o.root = ANG(-0.06 + sin(t * 0.5) * 0.02, 0, sway * 0.045)
		o.rh = ANG(0.06, 0, -sway * 0.045)
		o.lh = ANG(0.06, 0, -sway * 0.045)
		o.neck = ANG(-0.16 + sin(t * 0.6) * 0.05, sin(t * 0.35) * 0.1, sin(t * 0.55 + 1) * 0.22)
		o.rs = ANG(0, 0, 0.02 - sway * 0.04) * ANG(0.12, 0, 0)
		o.ls = ANG(0, 0, -0.02 - sway * 0.04) * ANG(0.12, 0, 0)
		local p = ev(s, "cough", 3, 6, 0.55, 0.7)
		if p >= 0 then
			local c = max(0, sin(p * PI * 2.6)) * (1 - p)
			o.root = o.root * ANG(-0.28 * c, 0, 0)
			o.neck = o.neck * ANG(-0.25 * c, 0, 0)
			o.rs = ANG(0.5 * c, 0, 0) * o.rs
			o.ls = ANG(0.35 * c, 0, 0) * o.ls
			o.rh = ANG(0.28 * c, 0, 0) * o.rh
			o.lh = ANG(0.28 * c, 0, 0) * o.lh
		end
	end,
	walk = function(o, s)
		local ph = s.ph * 0.9
		local x = sin(ph)
		local a = clamp(s.spd, 0.55, 1.2)
		local lean = 0.12
		local lurch = max(0, -x) -- weight on the bad leg
		local q = 0.58 * a * abs(x)
		local drop = min(0.16 * x * x, max(0, 2 * (1 - cos(q)) - 0.5 * sin(q)))
		o.root = CF(0, -(1 - cos(lean)) - drop, 0) * ANG(-lean, x * 0.06, lurch * 0.1 - 0.02)
		o.rh = ANG(lean + 0.58 * a * x, 0, -lurch * 0.1)
		o.lh = ANG(lean - 0.22 * a * x - 0.08, 0, -0.06 - lurch * 0.1)
		o.rs = ANG(0, 0, 0.06) * ANG(lean - 0.45 * a * x, 0, 0)
		o.ls = ANG(0, 0, -0.04 - lurch * 0.08) * ANG(lean + 0.18, 0, 0)
		o.neck = ANG(lean * 0.5 - 0.1, 0, sin(s.t * 0.9) * 0.18 - lurch * 0.1)
		limbs(o, 1)
	end,
}

-- Hacktivist: expect us. Idle: arms crossed, chin up, weight on one leg. Walk: confident
-- strut, chest out, shoulders rolling, big arm swing.
local G_HACK: Gait =
	{ leg = 0.56, arm = 0.62, armOut = 0.13, lean = -0.07, bob = 0.12, twist = 0.14, roll = 0.05, chin = 0.1, k = 0.95 }
SPECS.Hacktivist = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local br = sin(t * 1.25) * 0.02
		o.root = ANG(0.02 + br * 0.5, sin(t * 0.3) * 0.04, 0.03)
		o.rh = ANG(0, 0, -0.03)
		o.lh = ANG(0.07, -0.12, -0.13)
		crossedArms(o, br)
		local p = ev(s, "nod", 4, 7, 0.6, 0.8)
		local nod = if p >= 0 then -0.16 * bell(p) else 0
		o.neck = ANG(0.1 + nod, sin(t * 0.4) * 0.12, -0.03)
	end,
	walk = function(o, s)
		gait(o, s, G_HACK)
	end,
}

-- Synthwave: forever 1986. Idle: relaxed lean, hand on the hip, head bobbing and foot tapping
-- to a 100 bpm beat. Walk: grooving strut, bounce and shoulder sway on every step.
local G_SYNTH: Gait = { leg = 0.55, arm = 0.52, armOut = 0.1, bob = 0.15, roll = 0.08, twist = 0.1, k = 0.95 }
SPECS.Synthwave = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local b = beat(t, 100, 7)
		local groove = sin(t * PI * 100 / 60)
		o.root = ANG(0, 0.14 + groove * 0.02, -0.05)
		o.rh = ANG(0, -0.06, 0.05)
		o.lh = ANG(0.04 + b * 0.1, -0.1, -0.02)
		o.rs = ANG(0, 0, 0.5 + groove * 0.02) * ANG(-0.18, 0, 0)
		o.ls = ANG(0, 0, -0.08) * ANG(0.06 + groove * 0.06, 0, 0)
		o.neck = ANG(-0.1 * b + 0.02, -0.1, 0.06 + groove * 0.04)
	end,
	walk = function(o, s)
		local x = gait(o, s, G_SYNTH)
		o.neck = o.neck * ANG(-0.08 * (x * x) ^ 3, 0, 0)
	end,
}

---------------------------------------------------------------- EPIC (1 in 10,000+)

-- Rootkit: lives below the surface. Idle: hunched, crawling-from-below stance, claws
-- scratching. Walk: low ape-like prowl, arms hanging forward and swinging.
local G_ROOT: Gait =
	{ leg = 0.62, arm = 0.55, armFwd = 0.35, armOut = 0.1, lean = 0.5, bob = 0.16, chin = 0.3, twist = 0.08 }
SPECS.Rootkit = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local lean = 0.34 + sin(t * 1.1) * 0.03
		hunch(o, lean, sin(t * 0.4) * 0.06)
		o.neck = ANG(lean * 0.75 + 0.05, sin(t * 0.5) * 0.2, 0)
		local sc = sin(t * 7) * 0.06
		o.rs = ANG(0, 0, -0.12) * ANG(0.5 + lean + sin(t * 1.3) * 0.05 + max(0, sc), 0, 0)
		o.ls = ANG(0, 0, 0.12) * ANG(0.5 + lean + sin(t * 1.3 + 1) * 0.05 + max(0, -sc), 0, 0)
		o.rh = ANG(lean - 0.06, 0, 0.08)
		o.lh = ANG(lean + 0.12, 0, -0.08)
	end,
	walk = function(o, s)
		gait(o, s, G_ROOT)
	end,
}

-- Datastorm: born in the eye of the storm. Idle: arms raised, channelling the tornado in
-- slow circles, torso twisting with the wind. Walk: leaning into the gale, arms streaming back.
local G_STORM: Gait = { leg = 0.55, arm = 0, lean = 0.28, bob = 0.1, twist = 0.06 }
SPECS.Datastorm = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local a = t * 1.2
		o.root = ANG(0.04, sin(t * 0.9) * 0.28, sin(t * 0.45) * 0.03)
		o.rh = ANG(0, -sin(t * 0.9) * 0.2, 0.06)
		o.lh = ANG(0, -sin(t * 0.9) * 0.2, -0.06)
		o.rs = ANG(0, 0, 2.2 + sin(a) * 0.15) * ANG(cos(a) * 0.3, 0, 0)
		o.ls = ANG(0, 0, -2.2 + sin(a + PI) * 0.15) * ANG(cos(a + PI) * 0.3, 0, 0)
		o.neck = ANG(0.28, -sin(t * 0.9) * 0.15, 0)
	end,
	walk = function(o, s)
		gait(o, s, G_STORM)
		local t = s.t
		local f = wob(t, 7, 0) * 0.08
		o.rs = ANG(0, 0, 0.95 + f) * ANG(-0.45 + wob(t, 6, 1) * 0.08, 0, 0)
		o.ls = ANG(0, 0, -0.95 - f) * ANG(-0.45 + wob(t, 6, 2) * 0.08, 0, 0)
	end,
}

-- Hologram: a projection that learned to stand. Idle: projector flicker, scan-wobble of the
-- head, stop-motion idle sway. Walk: low-framerate stride with sideways signal flicker.
local G_HOLO: Gait = { leg = 0.5, arm = 0.4, bob = 0.08, steps = 8 }
SPECS.Hologram = {
	lift = 0,
	idle = function(o, s)
		local t = quant(s.t, 1 / 12)
		o.neck = ANG(0, sin(t * 0.6) * 0.1, 0)
		o.root = ANG(0, 0, sin(t * 0.9) * 0.025)
		o.rs = ANG(0, 0, 0.08 + sin(t * 0.9) * 0.02)
		o.ls = ANG(0, 0, -0.08 + sin(t * 0.9) * 0.02)
		local p, e = ev(s, "flick", 0.25, 1.4, 0.03, 0.08)
		if e.fresh then
			e.sn = CF(rnd(s.rng, 0.22), rnd(s.rng, 0.05), 0)
		end
		if p >= 0 then
			o.snap = e.sn
		end
	end,
	walk = function(o, s)
		gait(o, s, G_HOLO)
		local p, e = ev(s, "wflick", 0.3, 1, 0.03, 0.07)
		if e.fresh then
			e.sn = CF(rnd(s.rng, 0.3), 0, 0)
		end
		if p >= 0 then
			o.snap = e.sn
		end
	end,
}

-- Zero Day: no patch, no warning. Idle: impatient foot tapping, raising the wrist to check
-- the countdown. Walk: brisk purposeful walk, glancing at the wrist.
local G_ZERO: Gait = { leg = 0.6, arm = 0.55, lean = 0.14, bob = 0.12, k = 1.15 }
local WRIST = ANG(0, -0.7, 0) * ANG(1.3, 0, 0.1)
local WRIST_LOOK = ANG(-0.38, 0.22, 0.05)
SPECS.ZeroDay = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		o.root = ANG(0, -0.1, sin(t * 0.6) * 0.015)
		o.neck = ANG(-0.03, sin(t * 0.35) * 0.1, 0)
		o.rs = ANG(0, 0, 0.06)
		o.ls = ANG(0, 0, -0.06)
		local tap = max(0, sin(t * TAU * 2.2))
		o.rh = ANG(0.06 + tap * 0.09, 0, 0.04)
		local p = ev(s, "watch", 1.5, 3.2, 2, 2.6)
		if p >= 0 then
			local c = smooth01(min(p * 4, (1 - p) * 4))
			local tick = if (t % 1) < 0.08 then 0.04 else 0
			o.ls = ID:Lerp(WRIST * ANG(tick, 0, 0), c)
			o.neck = o.neck:Lerp(WRIST_LOOK, c)
		end
	end,
	walk = function(o, s)
		gait(o, s, G_ZERO)
		local p = ev(s, "wwatch", 2.5, 4.5, 1.1, 1.4)
		if p >= 0 then
			local c = smooth01(min(p * 4, (1 - p) * 4))
			o.ls = o.ls:Lerp(WRIST, c)
			o.neck = o.neck:Lerp(WRIST_LOOK, c * 0.8)
		end
	end,
}

-- Blackout: when the grid dies, it wakes. Idle: hunched in the dark, arms wrapped around
-- itself, shivering breath, now and then snapping up into a dead stare. Walk: slow
-- menacing stalk, head low, arms limp.
local G_BLACK: Gait =
	{ leg = 0.45, arm = 0.12, armFwd = 0.12, lean = 0.3, bob = 0.1, k = 0.75, roll = 0.07, chin = -0.25 }
SPECS.Blackout = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local br = sin(t * 0.9)
		local p = ev(s, "wake", 4, 8, 1.4, 1.8)
		local up = if p >= 0 then smooth01(min(p * 7, (1 - p) * 3)) else 0
		local lean = lerp(0.3 + br * 0.025, 0.08, up)
		hunch(o, lean)
		local shiver = wob(t, 23, 0) * 0.012 * (1 - up)
		local hug = ANG(0, 0.72, 0) * ANG(0.85 + lean + br * 0.03 + shiver, 0, 0)
		o.rs = hug:Lerp(ANG(0, 0, 0.05) * ANG(0.15, 0, 0), up)
		o.ls = (ANG(0, -0.72, 0) * ANG(0.8 + lean + br * 0.03 - shiver, 0, 0)):Lerp(ANG(0, 0, -0.05) * ANG(0.15, 0, 0), up)
		o.neck = ANG(lerp(-0.32 + shiver, 0.12, up), 0, 0)
	end,
	walk = function(o, s)
		gait(o, s, G_BLACK)
		o.rs = o.rs * ANG(0, 0, -0.04)
	end,
}

-- Chromatic: every colour at once. Idle: slow colour-dance, figure-eight hip sway with arms
-- flowing in waves. Walk: dance-walk, swaying hips and the flowing arms carry on.
local G_CHROMA: Gait = { leg = 0.5, arm = 0, roll = 0.1, twist = 0.16, bob = 0.13 }
local function flowArms(o: Out, t: number, amt: number)
	local a = t * 1.15
	o.rs = ANG(0, 0, 0.35 + sin(a) * 0.3 * amt) * ANG(0.25 + sin(a + 1.2) * 0.35 * amt, 0, 0)
	o.ls = ANG(0, 0, -0.35 - sin(a + PI) * 0.3 * amt) * ANG(0.25 + sin(a + PI + 1.2) * 0.35 * amt, 0, 0)
end
SPECS.Chromatic = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local r = sin(t * 1.15) * 0.07
		o.root = CF(0, -abs(sin(t * 1.15)) * 0.03, 0) * ANG(0, sin(t * 0.575) * 0.16, r)
		o.rh = ANG(0, -sin(t * 0.575) * 0.1, -r)
		o.lh = ANG(0, -sin(t * 0.575) * 0.1, -r)
		flowArms(o, t, 1)
		o.neck = ANG(0.05, -sin(t * 0.575) * 0.1, -r * 1.4)
	end,
	walk = function(o, s)
		gait(o, s, G_CHROMA)
		flowArms(o, s.t * 1.4, 0.7)
	end,
}

---------------------------------------------------------------- LEGENDARY (1 in 100,000+)

-- Mainframe: the machine that runs the machines. Idle: stiff robot, servo head scans that stop
-- dead, the torso following late, processing ticks. Walk: rigid stop-motion robot march.
local G_MAIN: Gait = { leg = 0.5, arm = 0.42, sq = 0.2, steps = 10, bob = 0.12, k = 0.85, armOut = 0.08 }
local SCAN = { -0.7, -0.35, 0, 0, 0.35, 0.7 }
SPECS.Mainframe = {
	lift = 0,
	idle = function(o, s)
		local _, e = ev(s, "scan", 1.1, 2.4, 0, 0)
		if e.fresh or not e.y then
			e.y = SCAN[s.rng:NextInteger(1, #SCAN)]
		end
		local hy = servo(s, "hy", e.y :: number, 1.7)
		local ty = servo(s, "ty", hy * 0.35, 0.45)
		local p = ev(s, "tick", 0.7, 1.1, 0.06, 0.08)
		local tick = if p >= 0 then 0.05 else 0
		o.root = ANG(0, ty, 0)
		o.rh = ANG(0, -ty, 0.03)
		o.lh = ANG(0, -ty, -0.03)
		o.neck = ANG(-tick * 0.6, hy - ty, 0)
		o.rs = ANG(0, 0, 0.12) * ANG(0.32 + tick, 0, 0)
		o.ls = ANG(0, 0, -0.12) * ANG(0.32 + tick, 0, 0)
		limbs(o, 0.85)
	end,
	walk = function(o, s)
		gait(o, s, G_MAIN)
		local _, e = ev(s, "wscan", 1.2, 2.5, 0, 0)
		if e.fresh or not e.y then
			e.y = SCAN[s.rng:NextInteger(2, #SCAN - 1)] * 0.6
		end
		o.neck = ANG(0, servo(s, "why", e.y :: number, 2), 0)
	end,
}

-- Quantum: both rolled and not rolled. Idle: low superposition float with phase-jumps.
-- Walk: hover-glide that keeps tunnelling ahead along the path.
local H_QUANT: Hover = { lift = 0.55, lean = 0.28, trail = 0.18, armOut = 0.32, armBack = 0.3, bob = 0.1, bank = 0.12 }
SPECS.Quantum = {
	lift = 0.65,
	idle = function(o, s)
		local t = s.t
		o.lift = 0.65 + sin(t * 1.2) * 0.14
		armsOut(o, 0.22 + sin(t * 0.8) * 0.05, 0.08)
		dangle(o, t, 0.7)
		o.neck = ANG(0.06, sin(t * 0.4) * 0.1, 0)
		o.root = ANG(0, sin(t * 0.3) * 0.1, 0)
		local p, e = ev(s, "phase", 1.6, 3.6, 0.05, 0.07)
		if e.fresh then
			e.sn = CF(rnd(s.rng, 0.4), 0, rnd(s.rng, 0.4)) * ANG(0, rnd(s.rng, 0.4), 0)
		end
		if p >= 0 then
			o.snap = e.sn
		end
	end,
	walk = function(o, s)
		hover(o, s, H_QUANT)
		local p, e = ev(s, "tunnel", 0.5, 1.3, 0.05, 0.08)
		if e.fresh then
			e.sn = CF(rnd(s.rng, 0.2), 0, -0.5 - s.rng:NextNumber() * 0.6)
		end
		if p >= 0 then
			o.snap = e.sn
		end
	end,
}

-- Overclocked: running at 300 %. Idle: wide pumped stance, fists clenched, fine vibration
-- that surges. Walk: hyper sprint, huge pumping arms, vibrating.
local G_OVER: Gait = { leg = 0.85, arm = 0.9, armFwd = 0.25, lean = 0.32, bob = 0.2, k = 1.55, twist = 0.12, armOut = 0.1 }
SPECS.Overclocked = {
	lift = 0,
	idle = function(o, s)
		local t, rng = s.t, s.rng
		local k = 0.5 + 0.5 * max(0, sin(t * 0.9)) ^ 4
		local a = 0.03 * (0.6 + k)
		o.root = CF(rnd(rng, 0.035 * k), rnd(rng, 0.02), rnd(rng, 0.035 * k)) * rndAng(rng, a * 0.5)
		o.neck = ANG(-0.05, 0, 0) * rndAng(rng, a * 1.4)
		o.rs = ANG(0, 0, 0.2) * ANG(0.25, 0, 0) * rndAng(rng, a)
		o.ls = ANG(0, 0, -0.2) * ANG(0.25, 0, 0) * rndAng(rng, a)
		o.rh = ANG(0, 0, 0.1)
		o.lh = ANG(0, 0, -0.1)
	end,
	walk = function(o, s)
		gait(o, s, G_OVER)
		local rng = s.rng
		o.root = o.root * rndAng(rng, 0.02)
		o.neck = o.neck * rndAng(rng, 0.03)
	end,
}

-- Neural Link: mind, meet machine. Idle: fingers to the temple, head tilted, "receiving"
-- twitches. Walk: hand stays at the temple, other arm swings, processing stumbles.
local G_NEURAL: Gait = { leg = 0.5, arm = 0.45, bob = 0.09 }
SPECS.NeuralLink = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local p = ev(s, "rx", 2, 4.5, 0.25, 0.3)
		local twitch = if p >= 0 then sin(p * 40) * 0.06 * (1 - p) else 0
		o.neck = ANG(-0.1 + twitch, 0.12, 0.26 + sin(t * 0.7) * 0.04)
		o.rs = templeArm(t)
		o.ls = ANG(0, 0, -0.08) * ANG(0.1, 0, 0)
		o.root = ANG(0, 0, -0.04)
	end,
	walk = function(o, s)
		gait(o, s, G_NEURAL)
		o.rs = templeArm(s.t)
		o.neck = o.neck * ANG(-0.06, 0.1, 0.22)
		local p = ev(s, "wrx", 2.5, 5, 0.3, 0.35)
		if p >= 0 then
			local b = bell(p)
			o.root = o.root * ANG(0.06 * b, 0, -0.08 * b)
			o.neck = o.neck * ANG(sin(p * 40) * 0.08, 0, 0)
		end
	end,
}

-- Sentinel: the firewall's last guardian. Idle: wide guard stance, forearms up like a shield.
-- Walk: shielded advance, guard kept up, heavy deliberate steps.
local G_SENT: Gait = { leg = 0.42, arm = 0, lean = 0.12, bob = 0.14, k = 0.85, legOut = 0.1 }
local function guard(o: Out, br: number)
	o.rs = ANG(0, 0, -0.32) * ANG(1.05 + br, 0, 0)
	o.ls = ANG(0, 0, 0.18) * ANG(1.3 + br, 0, 0)
end
SPECS.Sentinel = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local br = sin(t * 1.6) * 0.03
		o.root = CF(0, -0.04 + br * 0.5, 0) * ANG(-0.06, 0.18, 0)
		o.neck = ANG(0.02, -0.18 + sin(t * 0.3) * 0.08, 0)
		guard(o, br)
		o.rh = ANG(0.06, -0.18, 0.22)
		o.lh = ANG(-0.1, -0.18, -0.22)
	end,
	walk = function(o, s)
		gait(o, s, G_SENT)
		guard(o, 0)
		o.root = o.root * ANG(0, 0.15, 0)
		o.neck = o.neck * ANG(0, -0.15, 0)
	end,
}

---------------------------------------------------------------- MYTHIC (1 in 1,000,000+)

-- Kernel: ring zero, absolute control. Idle: levitating, arms out commanding the rings, with
-- a periodic pointing command. Walk: commanding hover-glide.
local H_KERNEL: Hover = { lift = 1.15, lean = 0.32, trail = 0.25, armOut = 0.62, armBack = 0.35, bob = 0.14, bank = 0.15 }
SPECS.Kernel = {
	lift = 1.3,
	idle = function(o, s)
		local t = s.t
		o.lift = 1.3 + sin(t * 1.1) * 0.18
		armsOut(o, 0.42 + sin(t * 0.9) * 0.05, 0.12)
		dangle(o, t, 1)
		o.neck = ANG(-0.05, 0, 0)
		o.root = ANG(0.04, sin(t * 0.3) * 0.12, 0)
		local p = ev(s, "cmd", 3.5, 6, 1.6, 2)
		if p >= 0 then
			local c = smooth01(min(p * 5, (1 - p) * 3))
			o.rs = o.rs:Lerp(ANG(0, 0, 0.1) * ANG(1.55, 0, 0), c)
			o.neck = o.neck:Lerp(ANG(0.02, 0.1, 0), c)
		end
	end,
	walk = function(o, s)
		hover(o, s, H_KERNEL)
	end,
}

-- Ghost Protocol: disavowed, invisible. Idle: slow drifting float, head bowed. Walk: drops
-- low into a sneaky hover-dash, leaning hard, arms swept far back.
local H_GHOST: Hover = { lift = 0.5, lean = 0.55, trail = 0.32, armOut = 0.12, armBack = 1.05, bob = 0.08, bank = 0.2, chin = 0.12 }
SPECS.GhostProtocol = {
	lift = 1.1,
	idle = function(o, s)
		local t = s.t
		o.lift = 1.1 + sin(t * 0.6) * 0.28
		o.root = ANG(sin(t * 0.45) * 0.05, sin(t * 0.25) * 0.18, sin(t * 0.37) * 0.04)
		o.neck = ANG(-0.22, 0, sin(t * 0.3) * 0.05)
		armsOut(o, 0.14 + sin(t * 0.6) * 0.04, -0.12)
		o.rh = ANG(0.18, 0, 0.03)
		o.lh = ANG(0.1, 0, -0.03)
	end,
	walk = function(o, s)
		hover(o, s, H_GHOST)
	end,
}

-- Cyber Seraph: an angel compiled from light. Idle: high levitation, arms spread like wings
-- with a slow flap, chin up. Walk: wings-swept glide, body near-horizontal, banking.
local H_SERAPH: Hover =
	{ lift = 1.7, lean = 0.62, trail = 0.22, armOut = 1.25, armBack = 0.55, bob = 0.2, bank = 0.25, flap = 0.12, chin = 0.1 }
SPECS.CyberSeraph = {
	lift = 1.9,
	idle = function(o, s)
		local t = s.t
		local flap = sin(t * 1.5)
		o.lift = 1.9 + sin(t * 1.5 - 0.6) * 0.22
		armsOut(o, 1.2 + flap * 0.18, -0.25)
		o.neck = ANG(0.18, 0, 0)
		o.root = ANG(-0.06, 0, 0)
		o.rh = ANG(-0.1 + flap * 0.03, 0, 0.03)
		o.lh = ANG(-0.04 + flap * 0.03, 0, -0.03)
	end,
	walk = function(o, s)
		hover(o, s, H_SERAPH)
	end,
}

-- Blue Screen: your PC ran into a problem. Idle: confused head tilts, then a frozen jittering
-- T-pose. Walk: walks normally... and periodically slides along frozen in the T-pose.
local G_BSOD: Gait = { leg = 0.5, arm = 0.45, bob = 0.1 }
local function tpose(o: Out, s: S)
	allOv(o, 1)
	armsOut(o, PI / 2)
	o.neck = ID
	o.rh, o.lh = ID, ID
	local _, e = ev(s, "jit", 0.07, 0.11, 0, 0)
	if e.fresh or not e.q then
		e.q = CF(rnd(s.rng, 0.06), 0, 0) * ANG(0, rnd(s.rng, 0.05), 0)
	end
	o.root = e.q
end
SPECS.BlueScreen = {
	lift = 0,
	idle = function(o, s)
		local t = s.t
		local ph = t % 5.2
		if ph > 3.4 and ph < 4.7 then
			tpose(o, s)
		else
			o.neck = ANG(-0.08, 0, sin(t * 0.8) * 0.18)
			o.root = ANG(0, 0, sin(t * 0.8) * 0.02)
			o.rs = ANG(0, 0, 0.06)
			o.ls = ANG(0, 0, -0.06)
		end
	end,
	walk = function(o, s)
		local ph = s.t % 4.6
		if ph > 2.8 and ph < 3.7 then
			tpose(o, s)
		else
			gait(o, s, G_BSOD)
		end
	end,
}

---------------------------------------------------------------- CORRUPTED (1 in 10,000,000+)

-- Corruption: the save file is damaged. Idle: twisted, wrong-angled limbs that keep snapping.
-- Walk: heavy twisted stomp, the body slams down on every footfall.
local G_CORR: Gait = { leg = 0.52, arm = 0.25, k = 0.7, lean = 0.18, bob = 0.18, roll = 0.06 }
local function corrupted(s: S): { [string]: CFrame }
	local j = s.mem.j :: { [string]: CFrame }?
	if not j then
		local nj: { [string]: CFrame } = {}
		for _, k in KEYS do
			nj[k] = ID
		end
		s.mem.j = nj
		j = nj
	end
	assert(j)
	local _, e = ev(s, "snap", 0.08, 0.36, 0, 0)
	if e.fresh then
		j[KEYS[s.rng:NextInteger(2, #KEYS)]] = rndAng(s.rng, 0.18)
	end
	return j
end
SPECS.Corruption = {
	lift = 0,
	idle = function(o, s)
		local j = corrupted(s)
		o.root = ANG(0.05, 0.22, 0.09) * j.root
		o.neck = ANG(-0.1, -0.3, 0.38) * j.neck
		o.rs = ANG(0, 0, 0.3) * ANG(0.2, 0.7, 0) * j.rs
		o.ls = ANG(0, 0, -0.12) * ANG(-0.25, -0.3, 0) * j.ls
		o.rh = ANG(0.1, 0.2, -0.01) * j.rh
		o.lh = ANG(-0.06, -0.15, -0.14) * j.lh
	end,
	walk = function(o, s)
		local x = gait(o, s, G_CORR)
		local j = corrupted(s)
		local ax = abs(x)
		local prev = (s.mem.px :: number?) or ax
		s.mem.px = ax
		if prev < 0.97 and ax >= 0.97 then
			s.mem.imp = s.t
		end
		local imp = exp(-(s.t - ((s.mem.imp :: number?) or -10)) * 12)
		o.root = o.root * ANG(0, 0.2, 0.08) * j.root
		o.snap = CF(0, -0.05 * imp, 0) * rndAng(s.rng, 0.03 * imp)
		o.neck = o.neck * ANG(-0.15 * imp, -0.25, 0.3) * j.neck
		o.rs = o.rs * ANG(0, 0.5, 0.1) * j.rs
		o.ls = o.ls * j.ls
	end,
}

-- Kernel Panic: total system failure. Idle: violent full-body shaking. Walk: panicked,
-- jittering sprint with the arms flailing over the head.
local G_PANIC: Gait = { leg = 0.85, arm = 0, k = 1.7, lean = 0.18, bob = 0.2 }
local function shake(s: S, amt: number): { [string]: CFrame }
	local cur = s.mem.sh :: { [string]: CFrame }?
	local _, e = ev(s, "frame", 1 / 30, 1 / 30, 0, 0)
	if not cur or e.fresh then
		local rng = s.rng
		local k = (0.7 + 0.3 * sin(s.t * 2.3)) * amt
		local nc: { [string]: CFrame } = {
			root = CF(rnd(rng, 0.13 * k), rnd(rng, 0.06 * k), rnd(rng, 0.13 * k)) * rndAng(rng, 0.07 * k),
			neck = rndAng(rng, 0.28 * k),
			rs = rndAng(rng, 0.3 * k),
			ls = rndAng(rng, 0.3 * k),
			rh = rndAng(rng, 0.1 * k),
			lh = rndAng(rng, 0.1 * k),
		}
		s.mem.sh = nc
		cur = nc
	end
	assert(cur)
	return cur
end
SPECS.KernelPanic = {
	lift = 0,
	idle = function(o, s)
		local c = shake(s, 1)
		o.root = c.root
		o.neck = c.neck
		o.rs = ANG(0, 0, 0.35) * c.rs
		o.ls = ANG(0, 0, -0.35) * c.ls
		o.rh = c.rh
		o.lh = c.lh
	end,
	walk = function(o, s)
		gait(o, s, G_PANIC)
		local c = shake(s, 0.6)
		local t = s.t
		o.rs = ANG(0, 0, 2.5 + sin(t * 14) * 0.35) * ANG(sin(t * 11.3) * 0.45, 0, 0) * c.rs
		o.ls = ANG(0, 0, -2.5 + sin(t * 12.7 + 1) * 0.35) * ANG(sin(t * 10.1 + 2) * 0.45, 0, 0) * c.ls
		o.root = o.root * c.root:Lerp(ID, 0.4)
		o.neck = o.neck * c.neck
	end,
}

-- Event Horizon: nothing escapes. Idle: levitating, slowly turning, arms reaching out and
-- pulling gravity in. Walk: slow-motion float, limbs drifting as if in zero-g.
local H_HORIZON: Hover = { lift = 1.8, lean = 0.35, trail = 0.28, armOut = 0.5, armBack = 0.6, bob = 0.25, bobRate = 0.7, bank = 0.1 }
SPECS.EventHorizon = {
	lift = 2,
	idle = function(o, s)
		local t = s.t
		local pull = smooth01(0.5 + 0.5 * sin(t * TAU / 6))
		o.lift = 2 + sin(t * 0.9) * 0.2
		o.root = ANG(-0.08 * pull, sin(t * 0.32) * 0.5, sin(t * 0.21) * 0.03)
		o.rs = ANG(0, 0, lerp(1.05, 0.3, pull)) * ANG(lerp(0.2, 1.1, pull), lerp(0, 0.5, pull), 0)
		o.ls = ANG(0, 0, -lerp(1.05, 0.3, pull)) * ANG(lerp(0.2, 1.1, pull), -lerp(0, 0.5, pull), 0)
		dangle(o, t * 0.6, 1.2 + pull * 0.6)
		o.neck = ANG(-0.12 - pull * 0.15, -sin(t * 0.32) * 0.2, 0)
	end,
	walk = function(o, s)
		hover(o, s, H_HORIZON)
		local ph = s.ph * 0.35
		o.rh = o.rh * ANG(sin(ph) * 0.18, 0, 0)
		o.lh = o.lh * ANG(-sin(ph) * 0.18, 0, 0)
		o.rs = o.rs * ANG(sin(ph + 1) * 0.15, 0, 0)
		o.ls = o.ls * ANG(-sin(ph + 1) * 0.15, 0, 0)
		o.root = o.root * ANG(0, sin(s.t * 0.4) * 0.15, sin(s.t * 0.3) * 0.08)
	end,
}

-- Null Pointer: points at nothing. Idle: void-still levitation, one arm pointing into the
-- empty distance, the gaze slowly following; sometimes the whole pose "dereferences" to null.
-- Walk: rigid glide, still pointing ahead.
local H_NULL: Hover = { lift = 1.3, lean = 0.18, trail = 0.1, armOut = 0.05, armBack = 0.08, bob = 0.05, bank = 0.08 }
local function nullFlicker(o: Out, s: S, key: string)
	local p = ev(s, key, 2.5, 5, 0.1, 0.18)
	if p >= 0 then
		o.root, o.neck, o.rs, o.ls, o.rh, o.lh = ID, ID, ID, ID, ID, ID
		allOv(o, 1)
	end
end
SPECS.NullPointer = {
	lift = 1.4,
	idle = function(o, s)
		local t = s.t
		local yaw = sin(t * 0.23) * 0.55
		o.lift = 1.4 + sin(t * 0.5) * 0.06
		o.rs = ANG(0, yaw, 0) * ANG(1.52, 0, 0)
		o.ls = ANG(0, 0, -0.04)
		o.neck = ANG(0.02, yaw * 0.9, 0)
		o.root = ANG(0, yaw * 0.2, 0)
		o.rh = ANG(0.02, 0, 0.02)
		o.lh = ANG(0.02, 0, -0.02)
		nullFlicker(o, s, "null")
	end,
	walk = function(o, s)
		hover(o, s, H_NULL)
		o.rs = ANG(1.52 + H_NULL.lean, 0, 0)
		nullFlicker(o, s, "wnull")
	end,
}

---------------------------------------------------------------- SINGULARITY (1 in 100,000,000+)

-- Singularity: all data collapses into one point. Idle: high float, arms spread, then the
-- whole body collapses inward, trembles, and bursts open again (7.5 s cycle).
-- Walk: comet glide, arms trailing like a tail.
local H_SING: Hover = { lift = 2.2, lean = 0.5, trail = 0.35, armOut = 0.95, armBack = 0.75, bob = 0.2, bobRate = 0.9, bank = 0.2 }
SPECS.Singularity = {
	lift = 2.4,
	idle = function(o, s)
		local t = s.t
		local p = t % 7.5
		local c: number
		if p < 4.6 then
			c = 0
		elseif p < 5.6 then
			c = smooth01(p - 4.6)
		elseif p < 6 then
			c = 1 + wob(t, 30, 0) * 0.04
		elseif p < 6.25 then
			c = 1 - 1.5 * smooth01((p - 6) / 0.25)
		else
			c = -0.5 * (1 - smooth01((p - 6.25) / 1.25))
		end
		local sway = sin(t * 0.32) * 0.6 * (1 - max(c, 0))
		o.lift = 2.4 + sin(t * 0.9) * 0.2 - 0.35 * c
		o.root = ANG(-0.35 * c, sway, sin(t * 0.21) * 0.03)
		local a = lerp(1.15, 0.25, c)
		local f = lerp(-0.1, 1.3, c)
		o.rs = ANG(0, lerp(0, 0.55, max(c, 0)), 0) * ANG(0, 0, a + sin(t * 0.7) * 0.08) * ANG(f, 0, 0)
		o.ls = ANG(0, -lerp(0, 0.55, max(c, 0)), 0) * ANG(0, 0, -a - sin(t * 0.7) * 0.08) * ANG(f, 0, 0)
		local tuck = 0.6 * max(c, 0)
		o.rh = ANG(0.14 + tuck + sin(t * 0.9) * 0.05, 0, 0.07 - 0.05 * c)
		o.lh = ANG(-0.06 + tuck * 1.1 - sin(t * 0.9) * 0.05, 0, -0.07 + 0.05 * c)
		o.neck = ANG(0.2 - 0.55 * c, -sway * 0.4, 0)
		if c < -0.05 then
			o.snap = rndAng(s.rng, 0.03 * -c)
		end
	end,
	walk = function(o, s)
		hover(o, s, H_SING)
		local t = s.t
		o.root = o.root * ANG(0, 0, sin(t * 0.5) * 0.1)
		o.rs = o.rs * ANG(sin(t * 0.8) * 0.12, 0, 0)
		o.ls = o.ls * ANG(sin(t * 0.8 + PI) * 0.12, 0, 0)
	end,
}

-- The Architect: wrote the world. Idle: levitating high, arms composing - each hand in turn
-- reaches out and traces the grid in the air while the head surveys. Walk: calm overseer
-- glide, upright, hands clasped behind the back.
local H_ARCH: Hover = { lift = 2.3, lean = 0.12, trail = 0.12, armOut = 0.1, armBack = 0.2, bob = 0.15, bank = 0.1 }
SPECS.Architect = {
	lift = 2.5,
	idle = function(o, s)
		local t = s.t
		o.lift = 2.5 + sin(t * 0.9) * 0.2
		o.root = ANG(0.03, sin(t * 0.25) * 0.4, sin(t * 0.21) * 0.03)
		dangle(o, t, 1.1)
		-- the active hand alternates every 4 s; a soft blend hands over between them
		local side = smooth01(0.5 + 0.5 * sin(t * PI / 4) * 2.5)
		local a = t * 1.6
		local draw = ANG(0, 0, 0.35) * ANG(1.45 + sin(a) * 0.25, cos(a) * 0.3, 0)
		local rest = ANG(0, 0, 0.75) * ANG(0.35, 0, 0)
		o.rs = rest:Lerp(draw, side)
		local drawL = ANG(0, 0, -0.35) * ANG(1.45 + sin(a + 1) * 0.25, -cos(a + 1) * 0.3, 0)
		local restL = ANG(0, 0, -0.75) * ANG(0.35, 0, 0)
		o.ls = restL:Lerp(drawL, 1 - side)
		o.neck = ANG(0.05 + sin(a * 0.5) * 0.05, lerp(-0.2, 0.2, side) - sin(t * 0.25) * 0.2, 0)
	end,
	walk = function(o, s)
		hover(o, s, H_ARCH)
		o.rs = ANG(0, 0, -0.14) * ANG(-0.42, 0, 0)
		o.ls = ANG(0, 0, 0.14) * ANG(-0.42, 0, 0)
		o.neck = o.neck * ANG(0.05, sin(s.t * 0.4) * 0.2, 0)
	end,
}

-- [REDACTED]: ████ ██ ███████ ████. Idle: levitating, rigid arms with censored jitter, the
-- whole body teleport-glitching and the head snapping to redacted angles. Walk: hover-glide
-- that teleports ahead along the path.
local H_RED: Hover = { lift = 1.8, lean = 0.25, trail = 0.15, armOut = 0.08, armBack = 0.18, bob = 0.06, bank = 0.12 }
SPECS.Redacted = {
	lift = 2,
	idle = function(o, s)
		local t, rng = s.t, s.rng
		o.lift = 2 + sin(t * 0.8) * 0.18
		armsOut(o, 0.5, 0.1)
		dangle(o, t, 1)
		o.neck = ANG(-0.15, 0, 0)
		local p, e = ev(s, "tp", 1.8, 4.2, 0.07, 0.17)
		if e.fresh then
			local a = rng:NextNumber() * TAU
			local r = 0.6 + rng:NextNumber() * 0.9
			e.sn = CF(cos(a) * r, rnd(rng, 0.35), sin(a) * r) * ANG(0, rnd(rng, 0.8), 0)
		end
		if p >= 0 then
			o.snap = e.sn
		end
		local q, h = ev(s, "censor", 1.2, 3, 0.18, 0.3)
		if h.fresh then
			h.cf = ANG(rnd(rng, 0.5), rnd(rng, 1.1), rnd(rng, 0.6))
			h.k = LIMBS[rng:NextInteger(1, #LIMBS)]
			h.lc = rndAng(rng, 0.6)
		end
		if q >= 0 then
			o.neck = h.cf
			local o2 = o :: any
			o2[h.k] = h.lc * o2[h.k]
		end
		local j = wob(t, 19, 0) * 0.015
		o.rs = o.rs * ANG(j, 0, 0)
		o.ls = o.ls * ANG(-j, 0, 0)
	end,
	walk = function(o, s)
		hover(o, s, H_RED)
		local p, e = ev(s, "wtp", 0.7, 1.6, 0.06, 0.12)
		if e.fresh then
			e.sn = CF(rnd(s.rng, 0.4), rnd(s.rng, 0.2), -1 - s.rng:NextNumber() * 1.2)
		end
		if p >= 0 then
			o.snap = e.sn
		end
	end,
}

-- Common auras (below 1 in MIN_CHANCE) use PosesLow; rarer ones use the specs above.
local LOW_KEYS = { root = "RootJoint", neck = "Neck", ls = "LeftShoulder", rs = "RightShoulder", lh = "LeftHip", rh = "RightHip" }

local function lowSpec(id: string): Spec
	local function fill(o: Out, s: S, moving: number)
		local seed = s.mem.lowSeed
		if not seed then
			seed = s.rng:NextNumber() * 1000
			s.mem.lowSeed = seed
		end
		local off = PosesLow.Get(id, s.t, moving, seed)
		if not off then
			return
		end
		local oa, fa = o :: any, off :: any
		for k, name in LOW_KEYS do
			local v = fa[name]
			if v then
				oa[k] = v
			end
		end
	end
	return {
		lift = 0,
		joint = true,
		idle = function(o: Out, s: S)
			fill(o, s, 0)
		end,
		walk = function(o: Out, s: S)
			fill(o, s, 1)
		end,
	}
end

for _, a in Config.Auras do
	if a.chance < MIN_CHANCE then
		if PosesLow.Has(a.id) then
			SPECS[a.id] = lowSpec(a.id)
		else
			SPECS[a.id] = nil
		end
	end
	if not SPECS[a.id] then
		warn("[AuraFX/Poses] no animation set for " .. a.id)
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
	r.air += ((if airborne then 1 else 0) - r.air) * (1 - exp(-AIR_RATE * dt))
	local blocked = (hum ~= nil and hum.Sit) or (state ~= nil and BLOCK_STATES[state] == true)
	r.block += ((if blocked then 1 else 0) - r.block) * (1 - exp(-AIR_RATE * dt))

	-- evaluate and combine layers
	local s = r.s
	s.t, s.dt, s.ph, s.spd, s.turn = t, dt, r.ph, r.spd, r.turn
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
		s.rng, s.mem = L.rng, L.mem
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
			if spec.joint then
				accJ[k] = accJ[k] * x
			else
				acc[k] = acc[k] * x
			end
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
function Poses.start(char: Model, auraId: string, onLift: ((number) -> ())?): () -> ()
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
			s = { t = now, dt = 0, ph = 0, spd = 0, turn = 0, rng = Random.new(), mem = {} },
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
