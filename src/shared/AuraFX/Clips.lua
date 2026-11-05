--!strict
-- AuraFX/Clips: plays the aura animations authored in BLENDER.
--
-- Source of truth: art/anims/<AuraId>.blend (built by tools/blender/anim/auras/<AuraId>.py).
-- tools/blender/anim/lib.py bakes every action into src/shared/AuraFX/Anims/<AuraId>.lua:
--
--   return {
--     lift = 0,            -- > 0: levitating set (root Y of the clips is reported as lift)
--     air = 0.2?,          -- weight kept while jumping / falling (grounded sets)
--     clips = {
--       idle = Clip,       -- looping, timed from the moment the aura was attached (Sync.age)
--       walk = Clip,       -- looping, ONE stride, timed by the gait phase (speed-matched)
--       <name> = Clip,     -- one-shot reactions: trigger = "<bus event>", plays when it fires
--     },
--   }
--   Clip = { fps, n, len, loop, trigger?, mode? ("replace" | "add"), blendIn?, blendOut?,
--            root = { q = {x,y,z,w,...}, p = {x,y,z,...} }, neck = { q }, rs, ls, rh, lh,
--            ev = { { time, name, arg? }, ... } }       -- Blender markers "fx:name[:arg]"
--
-- Rotations are quaternions in the PARENT part's axes about the joint pivot (Roblox axes:
-- +X right, +Y up, -Z forward), i.e. exactly what AuraFX/Poses composes onto the Motor6Ds.
-- Markers are fired on the aura's AuraFX/Sync bus when playback crosses them, so the VFX
-- builder can react on the exact frame the animator chose.

local Clips = {}

local CF = CFrame.new
local ID = CFrame.identity
local floor, clamp = math.floor, math.clamp

export type Event = { t: number, name: string, arg: string? }

export type Clip = {
	name: string,
	fps: number,
	n: number,
	len: number,
	loop: boolean,
	trigger: string?,
	mode: string, -- "replace" | "add"
	blendIn: number,
	blendOut: number,
	frames: { [string]: { CFrame } }, -- per logical joint, n CFrames (absent = not animated)
	ev: { Event },
}

export type Set = {
	id: string,
	lift: number,
	air: number?,
	idle: Clip?,
	walk: Clip?,
	once: { Clip }, -- one-shots with a trigger
}

local JOINTS = { "root", "neck", "rs", "ls", "rh", "lh" }
Clips.JOINTS = JOINTS

local function bake(name: string, raw: any): Clip
	local n = raw.n :: number
	local frames: { [string]: { CFrame } } = {}
	for _, k in JOINTS do
		local jd = raw[k]
		if jd then
			local q = jd.q :: { number }?
			local p = jd.p :: { number }?
			local list = table.create(n) :: { CFrame }
			for i = 1, n do
				local qx, qy, qz, qw = 0, 0, 0, 1
				if q then
					local b = (i - 1) * 4
					qx, qy, qz, qw = q[b + 1], q[b + 2], q[b + 3], q[b + 4]
				end
				local px, py, pz = 0, 0, 0
				if p then
					local b = (i - 1) * 3
					px, py, pz = p[b + 1], p[b + 2], p[b + 3]
				end
				list[i] = CF(px, py, pz, qx, qy, qz, qw)
			end
			frames[k] = list
		end
	end
	local ev: { Event } = {}
	for _, e in (raw.ev or {}) :: { any } do
		table.insert(ev, { t = e[1], name = e[2], arg = e[3] })
	end
	table.sort(ev, function(a, b)
		return a.t < b.t
	end)
	return {
		name = name,
		fps = raw.fps or 30,
		n = n,
		len = raw.len or n / (raw.fps or 30),
		loop = raw.loop ~= false,
		trigger = raw.trigger,
		mode = raw.mode or "replace",
		blendIn = raw.blendIn or 0.08,
		blendOut = raw.blendOut or 0.18,
		frames = frames,
		ev = ev,
	}
end

local cache: { [string]: Set } = {}
local missing: { [string]: boolean } = {}

-- Loads (and caches) the baked set of an aura; nil when the aura has no Blender animation.
function Clips.load(folder: Instance?, id: string): Set?
	if missing[id] then
		return nil
	end
	local c = cache[id]
	if c then
		return c
	end
	local mod = folder and folder:FindFirstChild(id)
	if not mod or not mod:IsA("ModuleScript") then
		missing[id] = true
		return nil
	end
	local ok, raw = pcall(require, mod)
	if not ok or type(raw) ~= "table" or type(raw.clips) ~= "table" then
		warn("[AuraFX/Clips] bad animation module " .. id .. ": " .. tostring(raw))
		missing[id] = true
		return nil
	end
	local set: Set = { id = id, lift = raw.lift or 0, air = raw.air, idle = nil, walk = nil, once = {} }
	for name, cr in raw.clips do
		local clip = bake(name, cr)
		if name == "idle" then
			set.idle = clip
		elseif name == "walk" then
			set.walk = clip
		elseif clip.trigger then
			clip.loop = false
			table.insert(set.once, clip)
		end
	end
	cache[id] = set
	return set
end

-- Local time inside the clip (wrapped or clamped).
function Clips.wrap(clip: Clip, t: number): number
	if clip.loop then
		return t % clip.len
	end
	return clamp(t, 0, clip.len)
end

-- Pose of one joint at clip time `t` (seconds); nil when the clip does not animate it.
function Clips.sample(clip: Clip, key: string, t: number): CFrame?
	local list = clip.frames[key]
	if not list then
		return nil
	end
	local n = clip.n
	local f = Clips.wrap(clip, t) * clip.fps
	local i0 = floor(f)
	local a = f - i0
	local i1 = i0 + 1
	if clip.loop then
		i0 = i0 % n
		i1 = i1 % n
	else
		i0 = clamp(i0, 0, n - 1)
		i1 = clamp(i1, 0, n - 1)
	end
	local c0 = list[i0 + 1]
	if a < 1e-4 then
		return c0
	end
	return c0:Lerp(list[i1 + 1], a)
end

-- Every joint of the clip at time t into `out[key]` (missing joints -> identity).
function Clips.pose(clip: Clip, t: number, out: { [string]: any })
	for _, k in JOINTS do
		out[k] = Clips.sample(clip, k, t) or ID
	end
end

-- Calls fire(event) for every marker crossed going from time a to b (clip-local, b >= a may
-- wrap around the loop point).
function Clips.cross(clip: Clip, a: number, b: number, fire: (Event) -> ())
	if #clip.ev == 0 or b <= a then
		return
	end
	local len = clip.len
	if b - a >= len then
		for _, e in clip.ev do
			fire(e)
		end
		return
	end
	local la, lb = Clips.wrap(clip, a), Clips.wrap(clip, b)
	for _, e in clip.ev do
		local hit
		if lb >= la then
			hit = e.t > la and e.t <= lb
		else -- wrapped around the loop point
			hit = e.t > la or e.t <= lb
		end
		if hit then
			fire(e)
		end
	end
end

return Clips
