--!strict
-- AuraFX/PosesLow: subtle procedural body language for BASIC and ENHANCED auras (chance < 1000).
--
--   PosesLow.Has(auraId) -> boolean
--   PosesLow.Get(auraId, t, moving, seed) -> Offsets?   (nil if the aura has no pose)
--
-- Pure math: no instances, no RunService. The caller multiplies each returned offset onto the
-- Animator's transform of that R6 Motor6D, so the default idle / walk animations keep playing.
--
-- Every aura defines two little "performances" in semantic units (radians / studs):
--   idle(c, p)  -- moving = 0
--   walk(c, p)  -- moving = 1
-- Both write into a Pose record; the records are blended numerically by `moving`, the root and
-- neck part is scaled by the tier (Enhanced reads a bit stronger than Basic), limbs are clamped
-- so arms never cross the torso, and the hips automatically counter the root lean so the feet
-- stay planted. Only then are the CFrames built (see build()).
--
-- Semantic conventions used by every definition below:
--   root  ru  up shift (studs, tiny)      rb  backward shift (studs, tiny)
--         rp  lean forward (+)            rr  lean right (+)           ry  turn right (+)
--   neck  np  look down (+)               nt  tilt right (+)           ny  look right (+)
--   arms  ls_f / rs_f  swing forward (+)  ls_o / rs_o  outward (+), inward (-)
--         ls_y / rs_y  yaw of the arm toward the character's right (+), matters when raised
--   legs  lh_f / rh_f  swing forward (+)  lh_o / rh_o  outward (+)

local PosesLow = {}

export type Offsets = {
	RootJoint: CFrame?,
	Neck: CFrame?,
	LeftShoulder: CFrame?,
	RightShoulder: CFrame?,
	LeftHip: CFrame?,
	RightHip: CFrame?,
}

type Pose = {
	ru: number,
	rb: number,
	rp: number,
	rr: number,
	ry: number,
	np: number,
	nt: number,
	ny: number,
	ls_f: number,
	ls_o: number,
	ls_y: number,
	rs_f: number,
	rs_o: number,
	rs_y: number,
	lh_f: number,
	lh_o: number,
	rh_f: number,
	rh_o: number,
}

-- Per-call context handed to every definition.
type Ctx = {
	t: number, -- desynced time (os.clock + per-character offset)
	r: number, -- noise seed (per character)
	g: number, -- generic gait phase (radians), ~1.3 strides per second
	b: number, -- |sin(g)|: step bounce 0..1 (two bounces per stride)
}

type PoseFn = (c: Ctx, p: Pose) -> ()
type Def = { tier: number, idle: PoseFn, walk: PoseFn }

local FIELDS = {
	"ru", "rb", "rp", "rr", "ry",
	"np", "nt", "ny",
	"ls_f", "ls_o", "ls_y", "rs_f", "rs_o", "rs_y",
	"lh_f", "lh_o", "rh_f", "rh_o",
}

local CF, ANG = CFrame.new, CFrame.Angles
local PI, TAU = math.pi, math.pi * 2
local sin, cos, abs, floor, max, min = math.sin, math.cos, math.abs, math.floor, math.max, math.min
local clamp = math.clamp

local GAIT_HZ = 1.3
local TIER_SCALE = { 1.0, 1.15 } -- Basic, Enhanced (root + neck amplitude)

-- Limits (radians): arms may be raised for the few "gesture" auras, but never folded across.
local ARM_FWD_MIN, ARM_FWD_MAX = -0.9, 2.75
local ARM_IN_MAX = 0.4 -- most inward (out >= -0.4)
local ARM_OUT_MAX = 0.6
local ARM_YAW_IN_MAX = 0.35
local LEG_MAX = 0.35
local SHIFT_MAX = 0.14 -- studs, root translation

---------------------------------------------------------------------------------------------
-- Shared helpers
---------------------------------------------------------------------------------------------

local function clamp01(x: number): number
	return clamp(x, 0, 1)
end

-- Smoothstep ease 0..1.
local function smooth(x: number): number
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- Coherent noise in roughly -1..1.
local function noise(t: number, freq: number, seed: number): number
	return clamp(math.noise(t * freq + 0.123, seed * 0.917 + 0.31, 0.37) * 2.2, -1, 1)
end

-- Sine wave at `hz` with a phase in cycles.
local function wave(t: number, hz: number, phase: number?): number
	return sin((t * hz + (phase or 0)) * TAU)
end

-- Quantize a value to `steps` levels per unit (8-bit look).
local function quant(x: number, steps: number): number
	return floor(x * steps + 0.5) / steps
end

-- Stepped time: holds each value for 1/fps seconds (freeze-frame / pixel feel).
local function stepped(t: number, fps: number): number
	return floor(t * fps) / fps
end

-- Deterministic 0..1 hash of a number.
local function hash(n: number): number
	local x = sin(n * 12.9898 + 78.233) * 43758.5453
	return x - floor(x)
end

-- Sharp-attack / exponential-decay envelope repeating at `hz` (beats, clicks).
local function beat(t: number, hz: number): number
	local u = (t * hz) % 1
	if u < 0.07 then
		return smooth(u / 0.07)
	end
	return math.exp(-(u - 0.07) * 7)
end

-- Fast-attack, slow-release shape for a 0..1 phase (flinches, tugs).
local function hit(v: number, attack: number?): number
	local a = attack or 0.12
	if v < a then
		return smooth(v / a)
	end
	return 1 - smooth((v - a) / (1 - a))
end

-- Occasional event: each `period` window fires with probability `prob` at a random offset and
-- lasts `dur` seconds. Returns the event's phase 0..1 (or nil) and the window index.
local function event(t: number, period: number, dur: number, prob: number, salt: number): (number?, number)
	local i = floor(t / period)
	if hash(i * 1.71 + salt) > prob then
		return nil, i
	end
	local start = hash(i * 3.13 + salt + 5.5) * max(period - dur, 0)
	local v = (t - i * period - start) / dur
	if v < 0 or v > 1 then
		return nil, i
	end
	return v, i
end

-- Bell 0..1..0 over an optional event phase.
local function bell(v: number?): number
	if v == nil then
		return 0
	end
	return sin(v * PI)
end

-- Holds a list of targets, easing to the next one at the start of every period (robotic moves).
local function holdCycle(t: number, period: number, targets: { number }, moveTime: number): number
	local n = #targets
	local i = floor(t / period)
	local u = t - i * period
	local cur = targets[(i % n) + 1]
	local prev = targets[((i - 1) % n) + 1]
	return lerp(prev, cur, smooth(u / moveTime))
end

-- Raised-then-lowered window inside a repeating cycle (0..1, eased both ways).
local function window(t: number, period: number, from: number, to: number, ease: number): number
	local u = t % period
	return smooth((u - from) / ease) * (1 - smooth((u - to) / ease))
end

---------------------------------------------------------------------------------------------
-- Aura definitions
---------------------------------------------------------------------------------------------

local BASIC, ENHANCED = 1, 2

local DEFS: { [string]: Def } = {}

-- PIXEL: everything moves on an 8-bit grid: quantized values, stepped at a low frame rate.
DEFS.Pixel = {
	tier = BASIC,
	idle = function(c, p)
		local st = stepped(c.t, 6)
		p.np = quant(wave(st, 0.5), 2) * 0.05
		p.ru = quant(wave(st, 0.25), 2) * 0.02
		p.nt = quant(wave(st, 0.17), 1) * 0.04
		local arm = quant(wave(st, 0.25, 0.25), 2) * 0.025
		p.ls_o = 0.04 + arm
		p.rs_o = 0.04 + arm
	end,
	walk = function(c, p)
		local st = stepped(c.t, 8)
		p.ru = quant(abs(sin(st * GAIT_HZ * TAU)), 2) * 0.07
		p.np = quant(wave(st, GAIT_HZ * 2), 1) * 0.04
		p.ny = quant(wave(st, 0.3), 2) * 0.06
		p.rp = 0.03
	end,
}

-- SPAM: hands on hips, impatient foot taps, glances down at the 999+ unread inbox; bouncy walk.
DEFS.Spam = {
	tier = BASIC,
	idle = function(c, p)
		p.ls_o, p.rs_o = 0.3, 0.3
		p.ls_f, p.rs_f = -0.12, -0.12
		local v = event(c.t, 3.2, 1.5, 0.85, 1)
		if v then
			local tap = max(0, sin(c.t * TAU * 3.5)) ^ 2 * sin(v * PI)
			p.rh_f = 0.14 * tap
			p.rh_o = 0.04 * sin(v * PI)
			p.nt = 0.06 * sin(v * PI)
		end
		local inbox = bell((event(c.t, 4.7, 1.1, 0.6, 2)))
		p.np += 0.2 * inbox
		p.ny += 0.08 * inbox
		p.ny += 0.06 * noise(c.t, 0.4, c.r)
	end,
	walk = function(c, p)
		p.ru = c.b ^ 1.5 * 0.09
		p.rp = 0.04
		p.np = -0.04 * c.b
		p.nt = 0.05 * sin(c.g)
		p.ls_o = 0.06 + 0.08 * c.b
		p.rs_o = 0.06 + 0.08 * c.b
	end,
}

-- STATIC: nearly still with a constant faint hum, broken by short bursts of stepped jitter.
local function staticJitter(c: Ctx, p: Pose, amp: number)
	local sn = stepped(c.t, 24)
	p.ny += 0.07 * amp * noise(sn, 31, c.r)
	p.np += 0.05 * amp * noise(sn, 29, c.r + 1)
	p.rr += 0.03 * amp * noise(sn, 27, c.r + 2)
	p.rs_f += 0.09 * amp * noise(sn, 33, c.r + 3)
	p.ls_f += 0.09 * amp * noise(sn, 35, c.r + 4)
	p.rb += 0.02 * amp * noise(sn, 25, c.r + 5)
end

DEFS.Static = {
	tier = BASIC,
	idle = function(c, p)
		staticJitter(c, p, 0.15)
		local v = event(c.t, 2.3, 0.35, 0.75, 3)
		if v then
			staticJitter(c, p, 1 - v * 0.6)
		end
	end,
	walk = function(c, p)
		p.np = 0.04
		staticJitter(c, p, 0.25)
		local v = event(c.t, 1.4, 0.3, 0.8, 4)
		if v then
			staticJitter(c, p, 1 - v * 0.5)
		end
	end,
}

-- CURSOR: right arm points at an invisible target that drifts around, with little click dips
-- (sometimes a double-click). The head follows the pointer. Walk: pointer arm leads the way.
local function cursorClick(t: number): number
	local v = event(t, 1.6, 0.36, 0.8, 5)
	if v == nil then
		return 0
	end
	-- two clicks per event when the second half of the window fires (double click)
	local u = v * 2
	if u < 1 then
		return sin(u * PI)
	end
	return hash(floor(t / 1.6)) > 0.5 and sin((u - 1) * PI) or 0
end

DEFS.Cursor = {
	tier = BASIC,
	idle = function(c, p)
		local tx = noise(c.t, 0.25, c.r)
		local ty = noise(c.t, 0.21, c.r + 3)
		p.rs_f = 1.25 + 0.15 * ty - 0.09 * cursorClick(c.t)
		p.rs_y = -0.05 + 0.22 * tx
		p.ls_o = 0.04
		p.ny = 0.12 + 0.2 * tx
		p.np = 0.03 - 0.08 * ty
		p.ry = 0.06 + 0.04 * tx
	end,
	walk = function(c, p)
		local tx = noise(c.t, 0.3, c.r)
		p.rs_f = 0.95 - 0.07 * cursorClick(c.t)
		p.rs_y = 0.12 * tx
		p.ny = 0.1 * tx
		p.ry = 0.04
	end,
}

-- BYTE: precise robotic head turns that snap and hold; stiff arms. Walk: upright stepped march.
local BYTE_YAW = { 0, 0.38, 0, -0.38, 0, 0.2, -0.2 }
local BYTE_PITCH = { 0, 0.06, -0.04, 0 }
local BYTE_MARCH = { 0, 0.2, 0, -0.2 }

DEFS.Byte = {
	tier = BASIC,
	idle = function(c, p)
		p.ny = holdCycle(c.t, 1.4, BYTE_YAW, 0.16)
		p.np = holdCycle(c.t, 2.1, BYTE_PITCH, 0.14)
		p.ry = holdCycle(c.t - 0.12, 1.4, BYTE_YAW, 0.22) * 0.18
		p.ls_o, p.rs_o = 0.06, 0.06
	end,
	walk = function(c, p)
		p.rp = -0.02
		p.ny = holdCycle(c.t, 1.0, BYTE_MARCH, 0.1) * 0.6
		local sq = quant(sin(c.g), 1)
		p.rs_f = 0.12 * sq
		p.ls_f = -0.12 * sq
	end,
}

-- LOADING: the head slowly circles like a buffering spinner whose speed hiccups.
DEFS.Loading = {
	tier = BASIC,
	idle = function(c, p)
		local a = TAU * (c.t / 2.6 + 0.15 * sin(c.t * 0.4))
		p.np = 0.02 + 0.07 * sin(a)
		p.nt = 0.08 * cos(a)
		p.rp = 0.015 * sin(a + PI)
		p.rr = 0.015 * cos(a + PI)
		p.ls_f, p.rs_f = -0.03, -0.03
	end,
	walk = function(c, p)
		local a = TAU * (c.t / 1.8)
		p.np = 0.03 + 0.04 * sin(a)
		p.nt = 0.045 * cos(a)
		p.rp = -0.03
		p.ls_f, p.rs_f = -0.08, -0.08
	end,
}

-- PING: every 2 s (in time with the radar pulse) the head turns and tilts an ear to one side,
-- alternating, as if listening for the pong. Walk: slow scanning with small blips.
DEFS.Ping = {
	tier = BASIC,
	idle = function(c, p)
		local u = (c.t % 2) / 2
		local side = (floor(c.t / 2) % 2 == 0) and 1 or -1
		local env
		if u < 0.1 then
			env = smooth(u / 0.1)
		elseif u < 0.55 then
			env = 1
		else
			env = 1 - smooth((u - 0.55) / 0.35)
		end
		p.ny = side * 0.3 * env
		p.nt = side * 0.1 * env
		p.np = -0.04 * beat(c.t, 0.5)
		p.rr = side * 0.02 * env
	end,
	walk = function(c, p)
		p.ny = 0.22 * sin(TAU * c.t / 4)
		p.np = -0.03 * beat(c.t, 0.5)
		p.rp = 0.03
	end,
}

-- WI-FI: phone in hand; every few seconds the arm goes up hunting for a signal, sweeping around
-- while the head looks up at it, then comes back down to read the screen.
DEFS.WiFi = {
	tier = BASIC,
	idle = function(c, p)
		local r = window(c.t, 6.5, 0.4, 4.6, 0.7)
		p.rs_f = lerp(1.0, 2.3, r)
		p.rs_o = 0.25 * r + 0.12 * sin(c.t * 1.7) * r
		p.rs_y = 0.2 * sin(c.t * 1.1) * r
		p.np = lerp(0.16, -0.2, r)
		p.ny = 0.12 * r + 0.1 * sin(c.t * 1.1) * r
		p.nt = 0.05 * r
		p.rr = -0.03 * r
	end,
	walk = function(c, p)
		p.rs_f = 1.0 + 0.04 * c.b
		p.rs_o = -0.05
		p.np = 0.18
		p.ny = 0.04
	end,
}

-- COOKIE: takes a bite (left hand to mouth), then a burst of happy chewing nods.
DEFS.Cookie = {
	tier = BASIC,
	idle = function(c, p)
		p.rr = 0.02 * sin(c.t * 0.7)
		p.nt = 0.05 * sin(c.t * 0.7 + 1)
		p.np = 0.02
		local v = event(c.t, 4, 2.4, 0.9, 6)
		if v then
			-- bite: first 30 % of the event
			local bite = v < 0.3 and sin(v / 0.3 * PI) or 0
			p.ls_f = 1.3 * bite
			p.ls_o = -0.25 * bite
			p.np += 0.06 * bite
			-- chew: the rest
			local chew = v > 0.25 and sin((v - 0.25) / 0.75 * PI) or 0
			p.np += 0.035 * sin(c.t * TAU * 3.2) * chew
		end
	end,
	walk = function(c, p)
		p.np = 0.03 + 0.04 * sin(c.g * 2)
		p.ls_f = 0.7
		p.ls_o = -0.2
	end,
}

-- CAPTCHA: thinking pose, hand to chin, head tilted over the 3x3 grid; taps the chin and has a
-- small "aha" now and then. Walk: hand stays near the chin, head sways between the squares.
DEFS.Captcha = {
	tier = BASIC,
	idle = function(c, p)
		local tapping = bell((event(c.t, 3.0, 1.0, 0.7, 7)))
		local aha = event(c.t, 5.5, 0.9, 0.6, 8)
		local ah = aha and hit(aha, 0.15) or 0
		p.rs_f = 2.0 + 0.05 * sin(c.t * 0.9) + 0.05 * sin(c.t * TAU * 4) * tapping - 0.5 * ah
		p.rs_o = -0.3
		p.rs_y = -0.1
		p.ls_f = 0.35
		p.ls_o = -0.15
		p.np = 0.06 - 0.14 * ah
		p.nt = 0.12 + 0.05 * sin(c.t * 0.5) - 0.12 * ah
		p.ny = 0.15 * noise(c.t, 0.3, c.r)
	end,
	walk = function(c, p)
		p.rs_f = 1.1
		p.rs_o = -0.2
		p.ny = 0.2 * sin(c.t * 0.8)
		p.np = 0.08
		p.nt = 0.06
	end,
}

-- CACHE: hands in pockets, laid back, slowly shifting weight from leg to leg.
DEFS.Cache = {
	tier = BASIC,
	idle = function(c, p)
		local ws = sin(c.t * TAU / 7)
		p.ls_f, p.rs_f = -0.1, -0.1
		p.ls_o, p.rs_o = -0.08, -0.08
		p.rp = -0.03
		p.rr = 0.05 * ws
		p.lh_o = 0.06 * max(0, ws)
		p.rh_o = 0.06 * max(0, -ws)
		p.nt = -0.06 * ws
		p.ny = 0.1 * noise(c.t, 0.2, c.r)
	end,
	walk = function(c, p)
		p.ls_f, p.rs_f = -0.1, -0.1
		p.ls_o, p.rs_o = -0.06, -0.06
		p.rr = 0.04 * sin(c.g)
		p.rp = -0.02
		p.nt = -0.04 * sin(c.g)
	end,
}

-- POPUP: random startled flinches toward the side where a window just "popped up".
local function popupFlinch(c: Ctx, p: Pose, period: number, amp: number)
	local v, i = event(c.t, period, 0.7, 0.7, 9)
	if v == nil then
		return
	end
	local side = hash(i + 0.5) > 0.5 and 1 or -1
	local f = hit(v, 0.08) * amp
	p.ny += side * 0.4 * f
	p.np -= 0.12 * f
	p.rp -= 0.07 * f
	p.rb += 0.06 * f
	p.rr -= side * 0.04 * f
	p.ls_f += 0.5 * f
	p.rs_f += 0.5 * f
	p.ls_o += 0.15 * f
	p.rs_o += 0.15 * f
end

DEFS.Popup = {
	tier = BASIC,
	idle = function(c, p)
		p.ny = 0.08 * noise(c.t, 0.6, c.r)
		popupFlinch(c, p, 3.0, 1)
	end,
	walk = function(c, p)
		p.ny = 0.1 * noise(c.t, 0.8, c.r)
		popupFlinch(c, p, 1.8, 0.6)
	end,
}

-- FIREWALL: warming the hands over the low flames: hands together in front, rubbing; hunched.
DEFS.Firewall = {
	tier = BASIC,
	idle = function(c, p)
		local rub = sin(c.t * TAU * 2.6)
		p.ls_f = 0.95 + 0.07 * rub
		p.rs_f = 0.95 - 0.07 * rub
		p.ls_o = -0.28 + 0.03 * rub
		p.rs_o = -0.28 - 0.03 * rub
		p.np = 0.1
		p.rp = 0.04
		p.rr = 0.01 * noise(c.t, 9, c.r)
	end,
	walk = function(c, p)
		local rub = sin(c.t * TAU * 2.2)
		p.ls_f = 0.6 + 0.05 * rub
		p.rs_f = 0.6 - 0.05 * rub
		p.ls_o, p.rs_o = -0.2, -0.2
		p.rp = 0.07
		p.np = 0.08
	end,
}

-- EMOJI: :) happy little bounces, head swaying side to side, arms flapping out. Walk: a skip.
DEFS.Emoji = {
	tier = BASIC,
	idle = function(c, p)
		local hop = abs(sin(c.t * TAU * 0.9))
		p.ru = 0.07 * hop ^ 1.4
		p.nt = 0.12 * wave(c.t, 0.45)
		p.rr = 0.03 * wave(c.t, 0.45)
		p.np = -0.05
		p.ls_o = 0.12 + 0.1 * hop
		p.rs_o = 0.12 + 0.1 * hop
		p.ls_f, p.rs_f = 0.1, 0.1
	end,
	walk = function(c, p)
		p.ru = 0.1 * c.b ^ 1.3
		p.ls_o = 0.08 + 0.15 * c.b
		p.rs_o = 0.08 + 0.15 * c.b
		p.nt = 0.08 * sin(c.g)
		p.np = -0.04
	end,
}

-- LAG: a gentle sway that keeps dropping into freeze-frames and low-fps stutter. Walk: the
-- upper body rubber-bands behind and snaps back, yaw jitters.
local function lagTime(t: number, seg: number, chance: number): (number, boolean)
	local i = floor(t / seg)
	if hash(i + 9.3) < chance then
		return stepped(t, 2.5 + hash(i) * 4), true
	end
	return t, false
end

DEFS.Lag = {
	tier = BASIC,
	idle = function(c, p)
		local tl = lagTime(c.t, 1.2, 0.55)
		p.ny = 0.18 * sin(tl * 0.9)
		p.np = 0.05 * sin(tl * 1.3)
		p.rr = 0.03 * sin(tl * 0.7)
		p.ls_f = 0.12 * sin(tl * 1.1)
		p.rs_f = -0.12 * sin(tl * 1.1 + 0.6)
	end,
	walk = function(c, p)
		local tl, laggy = lagTime(c.t, 0.9, 0.6)
		if laggy then
			local u = (c.t % 0.9) / 0.9
			p.rb = 0.09 * u
		end
		p.ry = 0.05 * noise(stepped(tl, 6), 3, c.r)
		p.ny = 0.06 * sin(tl * 1.5)
	end,
}

-- SPOOF: a mirrored idle. Hand on one hip, lean and head tilt to that side; every few seconds it
-- flips to the mirror image with a short flicker between the two versions.
local function spoofSide(t: number, period: number): number
	local seg = floor(t / period)
	local sd = (seg % 2 == 0) and 1 or -1
	local u = t - seg * period
	if u < 0.18 and floor(u * 40) % 2 == 0 then
		sd = -sd
	end
	return sd
end

DEFS.Spoof = {
	tier = BASIC,
	idle = function(c, p)
		local sd = spoofSide(c.t, 3.2)
		if sd > 0 then
			p.rs_o, p.rs_f = 0.35, -0.15
			p.ls_o = 0.04
			p.lh_o = 0.05
		else
			p.ls_o, p.ls_f = 0.35, -0.15
			p.rs_o = 0.04
			p.rh_o = 0.05
		end
		p.rr = 0.05 * sd
		p.nt = -0.08 * sd
		p.ny = 0.12 * sd
	end,
	walk = function(c, p)
		local sd = spoofSide(c.t, 2.4)
		p.rr = 0.04 * sd + 0.02 * sin(c.g)
		p.nt = -0.05 * sd
		p.ny = 0.06 * sd
	end,
}

-- PACKET: carrying a parcel in both arms; hefts it, checks the label, glances over a shoulder.
-- Walk: brisk courier pace, the parcel jostling with each step.
DEFS.Packet = {
	tier = ENHANCED,
	idle = function(c, p)
		local heft = 0.04 * sin(c.t * 1.3)
		p.ls_f, p.rs_f = 0.95 + heft, 0.95 + heft
		p.ls_o, p.rs_o = -0.24, -0.24
		p.rp = -0.03
		local label = bell((event(c.t, 4.2, 1.4, 0.6, 10)))
		p.np = 0.03 + 0.2 * label
		p.ny = 0.1 * label
		local gv, gi = event(c.t, 5.1, 1.2, 0.55, 11)
		if gv then
			local side = hash(gi) > 0.5 and 1 or -1
			p.ny += side * 0.5 * hit(gv, 0.25)
			p.ry += side * 0.06 * hit(gv, 0.25)
		end
	end,
	walk = function(c, p)
		p.ls_f = 0.9 + 0.06 * c.b
		p.rs_f = 0.9 + 0.06 * c.b
		p.ls_o, p.rs_o = -0.22, -0.22
		p.ru = 0.05 * c.b
		p.rp = 0.05
		p.np = 0.04
	end,
}

-- PATCH: "fixed 3 bugs, added 7": hand on the head, the other on a hip, scratching now and then.
DEFS.Patch = {
	tier = ENHANCED,
	idle = function(c, p)
		local scratch = bell((event(c.t, 2.8, 1.1, 0.75, 12))) * sin(c.t * TAU * 5)
		p.rs_f = 2.5 + 0.07 * scratch
		p.rs_o = -0.32 + 0.05 * scratch
		p.ls_o, p.ls_f = 0.32, -0.12
		p.nt = -0.12 + 0.03 * sin(c.t * 0.6)
		p.np = 0.06 + 0.04 * sin(c.t * TAU / 4.5)
		p.rp = 0.02 * sin(c.t * TAU / 4.5)
	end,
	walk = function(c, p)
		p.rs_f = 2.15
		p.rs_o = -0.3
		p.np = 0.09
		p.nt = -0.07
		p.rp = 0.03
	end,
}

-- PROXY: shifty side-glances, arms tucked behind the back; on the move it checks over its
-- shoulder as if being followed.
DEFS.Proxy = {
	tier = ENHANCED,
	idle = function(c, p)
		p.ls_f, p.rs_f = -0.28, -0.28
		p.ls_o, p.rs_o = -0.16, -0.16
		local v, i = event(c.t, 2.2, 1.1, 0.8, 13)
		if v then
			local side = hash(i + 2.2) > 0.5 and 1 or -1
			local g = v < 0.15 and smooth(v / 0.15) or (v < 0.7 and 1 or 1 - smooth((v - 0.7) / 0.3))
			p.ny = side * 0.5 * g
			p.nt = -side * 0.04 * g
			p.ry = -side * 0.03 * g
		end
		p.np = 0.03
	end,
	walk = function(c, p)
		p.ls_f, p.rs_f = -0.15, -0.15
		local v, i = event(c.t, 3.0, 1.0, 0.7, 14)
		if v then
			local side = hash(i + 4.4) > 0.5 and 1 or -1
			p.ny = side * 0.6 * hit(v, 0.25)
			p.ry = side * 0.07 * hit(v, 0.25)
		end
	end,
}

-- DEBUG: magnifier held out in the right hand, stepping through the scene breakpoint by
-- breakpoint (move, hold, move), leaning in to inspect. Walk: hunched search sweeping the floor.
local DEBUG_SCAN = { -0.25, -0.08, 0.1, 0.25, 0.05, -0.15 }

DEFS.Debug = {
	tier = ENHANCED,
	idle = function(c, p)
		local scan = holdCycle(c.t, 1.1, DEBUG_SCAN, 0.25)
		local zoom = bell((event(c.t, 3.6, 1.4, 0.7, 15)))
		p.rs_f = 1.45 + 0.12 * zoom
		p.rs_o = -0.12
		p.rs_y = scan
		p.ls_f, p.ls_o = 0.25, -0.05
		p.ny = scan * 1.1
		p.np = 0.2 + 0.06 * zoom
		p.rp = 0.08 + 0.05 * zoom
	end,
	walk = function(c, p)
		local scan = holdCycle(c.t, 0.8, DEBUG_SCAN, 0.2)
		p.rs_f = 1.0
		p.rs_y = scan * 0.6
		p.ny = scan * 0.6
		p.np = 0.24
		p.rp = 0.1
	end,
}

-- BITRATE: nodding to a 118 bpm track, foot tapping on the beat, with a bigger head-bang on
-- every 8th beat (the drop). Walk: grooving sway.
local BPM_HZ = 118 / 60

DEFS.Bitrate = {
	tier = ENHANCED,
	idle = function(c, p)
		local b = beat(c.t, BPM_HZ)
		local drop = (floor(c.t * BPM_HZ) % 8 == 0) and 1.6 or 1
		p.np = 0.13 * b * drop - 0.03
		p.ru = -0.03 * b
		p.rr = 0.04 * sin(c.t * BPM_HZ * PI)
		p.rh_f = 0.1 * b
		p.ls_f, p.rs_f = 0.06 * b, 0.06 * b
		p.ls_o, p.rs_o = 0.05, 0.05
	end,
	walk = function(c, p)
		local b = beat(c.t, BPM_HZ)
		p.np = 0.1 * b - 0.02
		p.rr = 0.05 * sin(c.t * BPM_HZ * PI)
		p.ry = 0.05 * sin(c.t * BPM_HZ * PI + 0.8)
	end,
}

-- HOTFIX: deployed on a Friday. Idle: fast foot tapping, keeps checking the watch.
-- Walk: a hurried, forward-leaning run with pumping arms.
DEFS.Hotfix = {
	tier = ENHANCED,
	idle = function(c, p)
		local w = bell((event(c.t, 3.5, 1.2, 0.85, 16)))
		p.ls_f = 1.25 * w
		p.ls_o = -0.3 * w
		p.np = 0.2 * w
		p.ny = -0.15 * w + 0.15 * noise(c.t, 0.9, c.r) * (1 - w)
		p.rh_f = 0.1 * max(0, sin(c.t * TAU * 4))
		p.rp = 0.03
	end,
	walk = function(c, p)
		p.rp = 0.17
		p.np = -0.1
		p.ls_f, p.rs_f = 0.22, 0.22
		p.ls_o, p.rs_o = 0.1, 0.1
		p.ru = 0.06 * abs(sin(c.g * 1.5))
	end,
}

-- OVERFLOW: too much input. Surges build up into clutching the head and shaking it ("no no no"),
-- then calm down to a faint tremble. Walk: staggering, arms flailing.
DEFS.Overflow = {
	tier = ENHANCED,
	idle = function(c, p)
		local s = window(c.t, 5.2, 0.6, 3.2, 0.8)
		p.ls_f, p.rs_f = 2.3 * s, 2.3 * s
		p.ls_o, p.rs_o = -0.35 * s, -0.35 * s
		p.ny = 0.18 * sin(c.t * TAU * 5) * s
		p.rr = 0.06 * noise(c.t, 14, c.r) * s + 0.01 * noise(c.t, 9, c.r + 1)
		p.np = 0.05 + 0.08 * s
		p.rp = 0.04 * s
	end,
	walk = function(c, p)
		p.rr = 0.07 * noise(c.t, 1.2, c.r)
		p.ry = 0.05 * noise(c.t, 1.0, c.r + 1)
		p.np = 0.06 * noise(c.t, 3, c.r + 2)
		p.nt = 0.06 * noise(c.t, 2.5, c.r + 3)
		p.ls_o = 0.2 + 0.1 * noise(c.t, 2, c.r + 4)
		p.rs_o = 0.2 + 0.1 * noise(c.t, 2, c.r + 5)
	end,
}

-- CIPHER: both hands weave slow opposed circles in front of the chest like turning letter
-- wheels; focused gaze. Walk: one hand keeps weaving.
DEFS.Cipher = {
	tier = ENHANCED,
	idle = function(c, p)
		local a = c.t * TAU * 0.55
		p.ls_f = 0.95 + 0.22 * sin(a)
		p.ls_o = -0.18 + 0.14 * cos(a)
		p.rs_f = 0.95 + 0.22 * sin(a + PI)
		p.rs_o = -0.18 + 0.14 * cos(a + PI)
		p.np = 0.1
		p.nt = 0.07 * sin(a * 0.5)
		p.ry = 0.04 * sin(a * 0.5)
	end,
	walk = function(c, p)
		local a = c.t * TAU * 0.7
		p.rs_f = 0.8 + 0.15 * sin(a)
		p.rs_o = -0.15 + 0.1 * cos(a)
		p.np = 0.06
	end,
}

-- MALWARE: clicked the link. Hunched and sneaky, peering up, claws twitching, with sudden
-- darting looks. Walk: a crouched tiptoe creep.
DEFS.Malware = {
	tier = ENHANCED,
	idle = function(c, p)
		p.rp = 0.2
		p.ru = -0.04
		p.np = -0.16
		local dv, di = event(c.t, 2.6, 0.6, 0.6, 17)
		local dart = 0
		if dv then
			dart = (hash(di + 7.7) > 0.5 and 1 or -1) * hit(dv, 0.1)
		end
		p.ny = 0.3 * noise(c.t, 0.3, c.r) + 0.35 * dart
		p.rr = 0.03 * sin(c.t * 0.8)
		p.ls_f = 0.35 + 0.04 * noise(c.t, 6, c.r + 1)
		p.rs_f = 0.35 + 0.04 * noise(c.t, 6, c.r + 2)
		p.ls_o, p.rs_o = 0.1, 0.1
	end,
	walk = function(c, p)
		p.rp = 0.24
		p.ru = -0.03 + 0.03 * c.b
		p.np = -0.18
		p.ny = 0.3 * noise(c.t, 0.5, c.r)
		p.ls_f = 0.45 + 0.05 * c.b
		p.rs_f = 0.45 + 0.05 * c.b
		p.ls_o, p.rs_o = 0.08, 0.08
	end,
}

-- DEADLOCK: wrists chained behind the back. Frozen still, then a straining tug to one side that
-- gets nowhere. Walk: leaning into it, yanked back on every snag.
local function tugEvent(c: Ctx, period: number): (number, number)
	local v, i = event(c.t, period, 0.9, 0.85, 18)
	if v == nil then
		return 0, 1
	end
	return hit(v, 0.15), hash(i + 1.3) > 0.5 and 1 or -1
end

DEFS.Deadlock = {
	tier = ENHANCED,
	idle = function(c, p)
		local tug, side = tugEvent(c, 2.2)
		p.ls_f, p.rs_f = -0.35 - 0.06 * tug, -0.35 - 0.06 * tug
		p.ls_o, p.rs_o = -0.12, -0.12
		p.rp = 0.07 * tug
		p.rr = side * 0.04 * tug
		p.ry = side * 0.08 * tug
		p.np = 0.08 - 0.08 * tug
		p.nt = 0.02 * noise(c.t, 12, c.r) * tug
		p.rr += 0.015 * noise(c.t, 15, c.r + 1) * tug
	end,
	walk = function(c, p)
		local tug = tugEvent(c, 1.6)
		p.rp = 0.12 - 0.12 * tug
		p.rb = 0.08 * tug
		p.ls_f, p.rs_f = -0.4, -0.4
		p.ls_o, p.rs_o = -0.1, -0.1
		p.np = 0.06
	end,
}

---------------------------------------------------------------------------------------------
-- Evaluation
---------------------------------------------------------------------------------------------

local function newPose(): Pose
	return {
		ru = 0, rb = 0, rp = 0, rr = 0, ry = 0,
		np = 0, nt = 0, ny = 0,
		ls_f = 0, ls_o = 0, ls_y = 0, rs_f = 0, rs_o = 0, rs_y = 0,
		lh_f = 0, lh_o = 0, rh_f = 0, rh_o = 0,
	}
end

-- Scratch records (Get is synchronous, so reusing them is safe).
local IDLE, WALK = newPose(), newPose()

local function reset(p: Pose)
	local q = p :: any
	for _, k in FIELDS do
		q[k] = 0
	end
end

-- R6 joint axes (see header): shoulders/hips swing about Z (right +, left -), abduct about X
-- (outward = negative on both sides), yaw about Y (toward the right = negative raw).
local function arm(side: number, fwd: number, out: number, yaw: number): CFrame
	fwd = clamp(fwd, ARM_FWD_MIN, ARM_FWD_MAX)
	out = clamp(out, -ARM_IN_MAX, ARM_OUT_MAX)
	-- inward yaw: right arm toward the left (-), left arm toward the right (+)
	if side > 0 then
		yaw = max(yaw, -ARM_YAW_IN_MAX)
	else
		yaw = min(yaw, ARM_YAW_IN_MAX)
	end
	return ANG(0, -yaw, 0) * ANG(-out, 0, 0) * ANG(0, 0, side * fwd)
end

local function leg(side: number, fwd: number, out: number, yaw: number): CFrame
	fwd = clamp(fwd, -LEG_MAX, LEG_MAX)
	out = clamp(out, -0.15, LEG_MAX)
	return ANG(0, yaw, 0) * ANG(-out, 0, 0) * ANG(0, 0, side * fwd)
end

local function build(p: Pose, k: number): Offsets
	local rp, rr, ry = p.rp * k, p.rr * k, p.ry * k
	local ru = clamp(p.ru * k, -SHIFT_MAX, SHIFT_MAX)
	local rb = clamp(p.rb * k, -SHIFT_MAX, SHIFT_MAX)
	-- RootJoint: X = pitch, -Y = roll, -Z = yaw; translation (joint Y = back, joint Z = up).
	local root = CF(0, rb, ru) * ANG(rp, -rr, -ry)
	-- Neck: X = pitch (down +), -Y = tilt, -Z = yaw.
	local neck = ANG(p.np * k, -p.nt * k, -p.ny * k)
	-- Hips counter the root lean / roll / turn so the feet stay planted.
	return {
		RootJoint = root,
		Neck = neck,
		LeftShoulder = arm(-1, p.ls_f, p.ls_o, p.ls_y),
		RightShoulder = arm(1, p.rs_f, p.rs_o, p.rs_y),
		LeftHip = leg(-1, p.lh_f + rp, p.lh_o - rr, ry * 0.8),
		RightHip = leg(1, p.rh_f + rp, p.rh_o + rr, ry * 0.8),
	}
end

function PosesLow.Has(auraId: string): boolean
	return DEFS[auraId] ~= nil
end

function PosesLow.Get(auraId: string, t: number, moving: number, seed: number): Offsets?
	local def = DEFS[auraId]
	if def == nil then
		return nil
	end
	local m = clamp01(moving)
	local tt = t + (seed % 997) * 1.337
	local g = tt * GAIT_HZ * TAU
	local c: Ctx = { t = tt, r = seed % 101, g = g, b = abs(sin(g)) }

	local out: Pose
	if m <= 0.001 then
		reset(IDLE)
		def.idle(c, IDLE)
		out = IDLE
	elseif m >= 0.999 then
		reset(WALK)
		def.walk(c, WALK)
		out = WALK
	else
		reset(IDLE)
		reset(WALK)
		def.idle(c, IDLE)
		def.walk(c, WALK)
		local e = smooth(m)
		local a, b = IDLE :: any, WALK :: any
		for _, key in FIELDS do
			a[key] = lerp(a[key], b[key], e)
		end
		out = IDLE
	end
	return build(out, TIER_SCALE[def.tier])
end

return PosesLow
