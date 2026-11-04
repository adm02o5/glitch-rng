--!strict
-- AuraFX/Burst: one-shot reveal explosion in the aura colours (shockwave rings, particle
-- burst, light flash, and for higher tiers shards, a light pillar and radial spikes).
-- Self-cleans after ~3 s.

local Workspace = game:GetService("Workspace")

local Core = require(script.Parent.Core)

local T = Core.TEX
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local ns, nr, cs = Core.ns, Core.nr, Core.cs
local TAU = Core.TAU
local WHITE = Color3.new(1, 1, 1)
local NEON = Enum.Material.Neon

local Burst = {}

local DURATION = 3

function Burst.play(position: Vector3, c1: Color3, c2: Color3, tier: number, scale: number)
	local s = scale * (0.75 + tier * 0.12)
	local model = Instance.new("Model")
	model.Name = "AuraFXBurst"
	model.Parent = Workspace

	local hub = Core.newPart(model, V(0.2, 0.2, 0.2), WHITE, NEON, 1)
	hub.CFrame = CF(position)
	local att = Instance.new("Attachment")
	att.Parent = hub

	local function emitOnce(spec: Core.EmitSpec, count: number)
		local e = Core.emit(att, spec)
		e.Enabled = false
		e:Emit(count)
	end

	if tier >= 4 then
		emitOnce({
			tex = T.implode,
			color = cs(c2, c1),
			size = ns(9 * s, 0),
			transp = ns(0.3, 0),
			rate = 0,
			life = nr(0.3),
			rot = nr(0, 360),
		}, 1)
	end
	emitOnce({
		tex = T.core,
		color = cs(WHITE, c1, c2),
		size = ns(2 * s, 7 * s),
		transp = ns(0, 1),
		rate = 0,
		life = nr(0.45, 0.55),
		rot = nr(0, 360),
		bright = 3,
	}, 2)
	emitOnce({
		tex = T.shock,
		color = cs(c1, c2),
		size = ns(1, 14 * s),
		transp = ns(0.15, 1),
		rate = 0,
		life = nr(0.6),
		speed = nr(0.01),
		orient = Enum.ParticleOrientation.VelocityPerpendicular,
	}, 1)
	emitOnce({
		tex = T.spark,
		color = cs(WHITE, c1, c2),
		size = ns(0.5 * s, 0),
		rate = 0,
		life = nr(0.8, 1.6),
		speed = nr(12 * s, 26 * s),
		spread = Vector2.new(180, 180),
		drag = 3,
		bright = 3,
	}, 30 + tier * 15)
	emitOnce({
		tex = T.square,
		color = cs(c1, c2),
		size = ns(0.28 * s, 0),
		rate = 0,
		life = nr(0.5, 1.2),
		speed = nr(8 * s, 18 * s),
		spread = Vector2.new(180, 180),
		drag = 2,
		rot = nr(0, 0),
		rotSpeed = nr(-200, 200),
	}, 20 + tier * 10)
	if tier >= 6 then
		emitOnce({
			tex = T.vortex,
			color = cs(c2, WHITE),
			size = ns(4 * s, 12 * s),
			transp = ns(0.2, 1),
			rate = 0,
			life = nr(1),
			rotSpeed = nr(120, 200),
		}, 1)
	end

	local light = Core.light(att, c1, 12, 30 * s)

	-- expanding shockwave rings
	type Ring = { parts: { BasePart }, tilt: CFrame, delay: number, reach: number }
	local rings: { Ring } = {}
	local function addRing(n: number, tilt: CFrame, delay: number, reach: number, col: Color3)
		local list = {}
		for i = 1, n do
			list[i] =
				Core.newPart(model, V(0.12 * s, 0.14 * s, 0.6 * s), if i % 2 == 0 then col else WHITE:Lerp(col, 0.4))
		end
		table.insert(rings, { parts = list, tilt = tilt, delay = delay, reach = reach })
	end
	addRing(20, CFrame.identity, 0, 9 * s, c1)
	if tier >= 3 then
		addRing(16, ANG(math.pi / 2, math.random() * TAU, 0), 0.06, 7 * s, c2)
	end
	if tier >= 5 then
		addRing(16, ANG(0.6, 0, 0.4), 0.12, 11 * s, c1)
	end

	-- flying shards
	type Shard = { p: BasePart, v: Vector3, w: Vector3 }
	local shards: { Shard } = {}
	if tier >= 4 then
		for i = 1, 10 do
			local u = Random.new():NextUnitVector()
			shards[i] = {
				p = Core.newPart(model, V(0.25, 0.25, 0.25) * s, if i % 2 == 0 then c1 else c2),
				v = (u + V(0, 0.8, 0)) * (10 * s),
				w = Random.new():NextUnitVector() * 8,
			}
		end
	end

	-- light pillar
	local pillar: BasePart? = nil
	if tier >= 5 then
		pillar = Core.newPart(model, V(80, 1.6 * s, 1.6 * s), WHITE:Lerp(c1, 0.3), NEON, 0, Enum.PartType.Cylinder)
	end

	-- radial spikes (beams)
	local spikes: { { a: Attachment, dir: Vector3, beam: Beam } } = {}
	if tier >= 6 then
		for i = 1, 8 do
			local a1 = Instance.new("Attachment")
			a1.Parent = hub
			local b = Instance.new("Beam")
			b.Attachment0 = att
			b.Attachment1 = a1
			b.Color = ColorSequence.new(WHITE, c2)
			b.Width0 = 0.6 * s
			b.Width1 = 0
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Brightness = 3
			b.FaceCamera = true
			b.Transparency = ns(0, 1)
			b.Parent = model
			local ang = (i - 1) / 8 * TAU
			table.insert(
				spikes,
				{ a = a1, dir = V(math.cos(ang), math.sin(ang * 2) * 0.3, math.sin(ang)).Unit, beam = b }
			)
		end
	end

	local t0 = os.clock()
	local done = false
	local function finish()
		if not done then
			done = true
			model:Destroy()
		end
	end
	Core.addJob(function(t: number): boolean
		if done then
			return false
		end
		local age = t - t0
		if age > DURATION then
			finish()
			return false
		end
		local base = CF(position)
		for _, r in rings do
			local f = math.clamp((age - r.delay) / 0.75, 0, 1)
			local e = 1 - (1 - f) ^ 3
			local rad = 0.4 + e * r.reach
			for i, p in r.parts do
				local a = (i - 1) / #r.parts * TAU + age * 0.6
				Core.put(p, base * r.tilt * ANG(0, -a, 0) * CF(rad, 0, 0))
				p.Transparency = if f <= 0 then 1 else f ^ 0.8
			end
		end
		for _, sh in shards do
			local pos = position + sh.v * age + V(0, -9 * age * age, 0)
			Core.put(sh.p, CF(pos) * ANG(sh.w.X * age, sh.w.Y * age, sh.w.Z * age))
			sh.p.Transparency = math.clamp((age - 1.2) / 1, 0, 1)
		end
		local pl = pillar
		if pl then
			local f = math.clamp(age / 1.2, 0, 1)
			local w = 1.6 * s * (1 - f) + 0.01
			pl.Size = V(80, w, w)
			Core.put(pl, base * CF(0, 38, 0) * ANG(0, 0, math.pi / 2))
			pl.Transparency = f
		end
		for _, sp in spikes do
			local f = math.clamp(age / 0.5, 0, 1)
			sp.a.Position = sp.dir * (12 * s * (1 - (1 - f) ^ 2))
			sp.beam.Transparency = NumberSequence.new(math.clamp(age / 1.2, 0, 1), 1)
		end
		light.Brightness = 12 * math.max(0, 1 - age / 1.2)
		return true
	end)
	task.delay(DURATION + 0.5, finish)
end

return Burst
