--!strict
-- AuraFX/Sync: the link between an aura's body animation (AuraFX/Poses, Blender clips) and its VFX
-- (Auras*.lua builders). One Bus per attached aura: both sides read and write it, so a pose
-- gesture can fire a particle burst from the hand, and a VFX pulse can make the body flinch.
--
-- Shared clock: everything uses os.clock(). `bus.t0` is the moment the aura was attached, so
-- Sync.phase(bus, period) gives BOTH sides the very same beat (0..1) without talking.
--
-- Timing inside one frame: VFX run in RenderStepped, poses in Stepped (later in the frame).
--   VFX -> pose events arrive the same frame, pose -> VFX events one frame later (~16 ms).
--
-- Values the pose runner publishes automatically every frame (Sync.get(bus, name)):
--   "move"  0..1   idle -> walking blend
--   "spd"   ground speed / 16 (smoothed)
--   "ph"    gait phase in radians (one stride = 2*pi)
--   "air"   0..1   airborne blend
--   "lift"  studs  current levitation
-- Events the runner emits automatically:
--   "step"  payload "L" | "R"   a foot lands (twice per stride, only while walking on the ground)
--   "jump"                      the character leaves the ground
--   "land"  payload number      back on the ground (payload = seconds spent in the air)
-- Aura-specific events / values: any name, documented next to the aura's pose and builder.

local Sync = {}

-- Global per-event counters (debug / tests only).
Sync.stats = {} :: { [string]: number }

export type Bus = {
	t0: number,
	vals: { [string]: number },
	last: { [string]: number },
	data: { [string]: any },
	subs: { [string]: { (any) -> () } },
	count: { [string]: number },
}

function Sync.new(): Bus
	return { t0 = os.clock(), vals = {}, last = {}, data = {}, subs = {}, count = {} }
end

-- Fire an event: remembers when (and with what payload) it last happened and calls listeners.
function Sync.emit(bus: Bus?, name: string, payload: any?)
	if not bus then
		return
	end
	bus.last[name] = os.clock()
	bus.data[name] = payload
	bus.count[name] = (bus.count[name] or 0) + 1
	Sync.stats[name] = (Sync.stats[name] or 0) + 1
	local list = bus.subs[name]
	if list then
		for _, fn in list do
			local ok, err = pcall(function()
				fn(payload)
			end)
			if not ok then
				warn("[AuraFX/Sync] " .. name .. ": " .. tostring(err))
			end
		end
	end
end

-- Listen to an event. Returns a function that removes the listener.
function Sync.on(bus: Bus?, name: string, fn: (any) -> ()): () -> ()
	if not bus then
		return function() end
	end
	local list = bus.subs[name]
	if not list then
		list = {}
		bus.subs[name] = list
	end
	table.insert(list, fn)
	return function()
		local i = table.find(list, fn)
		if i then
			table.remove(list, i)
		end
	end
end

-- Seconds since the event last fired (math.huge if never).
function Sync.since(bus: Bus?, name: string): number
	if not bus then
		return math.huge
	end
	local t = bus.last[name]
	return if t then os.clock() - t else math.huge
end

-- Payload of the last occurrence of the event (nil if never fired).
function Sync.payload(bus: Bus?, name: string): any?
	return if bus then bus.data[name] else nil
end

-- How many times the event has fired (handy to detect "a new one happened since I looked").
function Sync.count(bus: Bus?, name: string): number
	return if bus then bus.count[name] or 0 else 0
end

-- Continuous shared value.
function Sync.set(bus: Bus?, name: string, v: number)
	if bus then
		bus.vals[name] = v
	end
end

function Sync.get(bus: Bus?, name: string, default: number?): number
	local v = if bus then bus.vals[name] else nil
	return v or default or 0
end

-- Seconds since the aura was attached (the shared beat origin).
function Sync.age(bus: Bus?): number
	return if bus then os.clock() - bus.t0 else os.clock()
end

-- Shared beat phase 0..1 with the given period (seconds), counted from the attach moment.
function Sync.phase(bus: Bus?, period: number, offset: number?): number
	return ((Sync.age(bus) / period) + (offset or 0)) % 1
end

-- Envelope: 1 at the moment the event fired, decaying exponentially with `rate` (1/s).
function Sync.env(bus: Bus?, name: string, rate: number): number
	local s = Sync.since(bus, name)
	return if s == math.huge then 0 else math.exp(-s * rate)
end

-- Envelope over a fixed window: progress 0..1 while within `dur` seconds of the event, -1 after.
function Sync.window(bus: Bus?, name: string, dur: number): number
	local s = Sync.since(bus, name)
	if s > dur then
		return -1
	end
	return s / dur
end

return Sync
