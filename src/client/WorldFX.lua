--!strict
-- WorldFX: client-side world animation + biome visuals for the Glitch RNG plaza.
--
-- Animates tags placed by server/Map.lua: Spin, Bob, Blink, Scroll (one render loop, 400-stud culling).
-- Biomes: reads ReplicatedStorage attribute "Biome" (Config biome id), tweens Lighting / BiomeCC / Bloom /
-- Atmosphere, recolours "BiomeNeon" parts and runs per-biome weather in a Folder under the camera.
--
-- API:
--   WorldFX.Start()                          -- call once
--   WorldFX.SetBiome(id: string)              -- force a biome (also driven by the attribute)
--   WorldFX.Flash(color: Color3, duration)    -- brief world flash through BiomeCC (cutscenes)

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ctx = require(script.Parent.Ctx)

local WorldFX = {}

---------------------------------------------------------------------------------------------------
-- Constants / utils
---------------------------------------------------------------------------------------------------

local TEX = "rbxasset://textures/particles/"
local CULL = 400
local NEON_FX_RANGE = 260
local TRANSITION = 2.6
local PI = math.pi

local FONT_MONO_B = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local FONT_PIX = Font.new("rbxasset://fonts/families/PressStart2P.json")

local rng = Random.new()

local function rr(a: number, b: number): number
	return rng:NextNumber(a, b)
end

local function ri(a: number, b: number): number
	return rng:NextInteger(a, b)
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function scaleColor(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function normalized(c: Color3): Color3
	local m = math.max(c.R, c.G, c.B, 1e-3)
	return Color3.new(c.R / m, c.G / m, c.B / m)
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function ns(...: number): NumberSequence
	local args = { ... }
	if #args == 1 then
		return NumberSequence.new(args[1])
	end
	local kps = {}
	for i = 1, #args, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(kps)
end

local function biomeColor(id: string, fallback: Color3): Color3
	local b = Config.BiomeById[id]
	return if b then b.color else fallback
end

---------------------------------------------------------------------------------------------------
-- Biome looks
---------------------------------------------------------------------------------------------------

type Look = {
	ambient: Color3,
	outdoor: Color3,
	brightness: number,
	exposure: number,
	atmoDensity: number,
	atmoOffset: number,
	atmoColor: Color3,
	atmoDecay: Color3,
	atmoGlare: number,
	atmoHaze: number,
	ccTint: Color3,
	ccContrast: number,
	ccSat: number,
	ccBright: number,
	bloomInt: number,
	bloomSize: number,
	bloomThr: number,
	neon: Color3?, -- nil = BaseColor
	neonMul: number,
	neonMix: number,
}

local LOOKS: { [string]: Look } = {
	Normal = {
		ambient = rgb(34, 32, 54),
		outdoor = rgb(72, 64, 112),
		brightness = 1.2,
		exposure = 0.1,
		atmoDensity = 0.36,
		atmoOffset = 0.22,
		atmoColor = rgb(58, 32, 92),
		atmoDecay = rgb(24, 12, 44),
		atmoGlare = 0.15,
		atmoHaze = 1.8,
		ccTint = Color3.new(1, 1, 1),
		ccContrast = 0.08,
		ccSat = 0.1,
		ccBright = 0,
		bloomInt = 1,
		bloomSize = 32,
		bloomThr = 0.9,
		neon = nil,
		neonMul = 1,
		neonMix = 0,
	},
	DataStorm = {
		ambient = rgb(18, 46, 32),
		outdoor = rgb(42, 104, 72),
		brightness = 1.0,
		exposure = 0.05,
		atmoDensity = 0.5,
		atmoOffset = 0.15,
		atmoColor = rgb(40, 120, 72),
		atmoDecay = rgb(8, 50, 26),
		atmoGlare = 0.1,
		atmoHaze = 3,
		ccTint = rgb(205, 255, 220),
		ccContrast = 0.16,
		ccSat = 0.05,
		ccBright = -0.02,
		bloomInt = 1.2,
		bloomSize = 36,
		bloomThr = 0.85,
		neon = normalized(biomeColor("DataStorm", rgb(60, 255, 160))),
		neonMul = 1,
		neonMix = 0.85,
	},
	Overclock = {
		ambient = rgb(50, 30, 14),
		outdoor = rgb(112, 66, 30),
		brightness = 1.6,
		exposure = 0.18,
		atmoDensity = 0.42,
		atmoOffset = 0.3,
		atmoColor = rgb(150, 74, 22),
		atmoDecay = rgb(90, 30, 5),
		atmoGlare = 0.5,
		atmoHaze = 2.6,
		ccTint = rgb(255, 226, 196),
		ccContrast = 0.12,
		ccSat = 0.25,
		ccBright = 0.02,
		bloomInt = 1.4,
		bloomSize = 40,
		bloomThr = 0.8,
		neon = normalized(biomeColor("Overclock", rgb(255, 140, 0))),
		neonMul = 1,
		neonMix = 0.85,
	},
	Blackout = {
		ambient = rgb(12, 7, 12),
		outdoor = rgb(24, 13, 22),
		brightness = 0.3,
		exposure = -0.1,
		atmoDensity = 0.55,
		atmoOffset = 0.1,
		atmoColor = rgb(22, 8, 12),
		atmoDecay = rgb(10, 2, 4),
		atmoGlare = 0,
		atmoHaze = 1,
		ccTint = rgb(232, 205, 210),
		ccContrast = 0.22,
		ccSat = -0.25,
		ccBright = -0.05,
		bloomInt = 1.3,
		bloomSize = 30,
		bloomThr = 0.85,
		neon = normalized(biomeColor("Blackout", rgb(255, 30, 30))),
		neonMul = 0.06,
		neonMix = 1,
	},
	KernelPanic = {
		ambient = rgb(46, 10, 14),
		outdoor = rgb(98, 20, 28),
		brightness = 1.0,
		exposure = 0.1,
		atmoDensity = 0.5,
		atmoOffset = 0.2,
		atmoColor = rgb(120, 10, 22),
		atmoDecay = rgb(60, 0, 10),
		atmoGlare = 0.3,
		atmoHaze = 2.5,
		ccTint = rgb(255, 188, 188),
		ccContrast = 0.3,
		ccSat = 0.12,
		ccBright = 0,
		bloomInt = 1.5,
		bloomSize = 40,
		bloomThr = 0.8,
		neon = normalized(biomeColor("KernelPanic", rgb(255, 0, 60))),
		neonMul = 1.1,
		neonMix = 0.9,
	},
}

local function lerpLook(a: Look, b: Look, t: number): Look
	local function n(x: number, y: number): number
		return x + (y - x) * t
	end
	return {
		ambient = a.ambient:Lerp(b.ambient, t),
		outdoor = a.outdoor:Lerp(b.outdoor, t),
		brightness = n(a.brightness, b.brightness),
		exposure = n(a.exposure, b.exposure),
		atmoDensity = n(a.atmoDensity, b.atmoDensity),
		atmoOffset = n(a.atmoOffset, b.atmoOffset),
		atmoColor = a.atmoColor:Lerp(b.atmoColor, t),
		atmoDecay = a.atmoDecay:Lerp(b.atmoDecay, t),
		atmoGlare = n(a.atmoGlare, b.atmoGlare),
		atmoHaze = n(a.atmoHaze, b.atmoHaze),
		ccTint = a.ccTint:Lerp(b.ccTint, t),
		ccContrast = n(a.ccContrast, b.ccContrast),
		ccSat = n(a.ccSat, b.ccSat),
		ccBright = n(a.ccBright, b.ccBright),
		bloomInt = n(a.bloomInt, b.bloomInt),
		bloomSize = n(a.bloomSize, b.bloomSize),
		bloomThr = n(a.bloomThr, b.bloomThr),
		neon = b.neon,
		neonMul = b.neonMul,
		neonMix = b.neonMix,
	}
end

---------------------------------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------------------------------

local started = false
local currentBiome = "Normal"
local fromLook: Look = LOOKS.Normal
local toLook: Look = LOOKS.Normal
local lastLook: Look = LOOKS.Normal
local lookT0 = -math.huge
local epoch = 0

local atmo: Atmosphere? = nil
local bloom: BloomEffect? = nil
local cc: ColorCorrectionEffect? = nil

type Flash = { color: Color3, t0: number, dur: number, strength: number }
local flashes: { Flash } = {}

-- per-frame additive tweaks written by the weather
local extra = { ccBright = 0, brightMul = 1 }

local shakeUntil = 0
local shakeMag = 0

---------------------------------------------------------------------------------------------------
-- Tag registries
---------------------------------------------------------------------------------------------------

type MoveEntry = {
	inst: Instance,
	kind: string, -- "Spin" | "Bob"
	parts: { BasePart },
	offsets: { CFrame },
	base: CFrame,
	pos: Vector3,
	speed: number,
	axis: string,
	amp: number,
	phase: number,
	rot: number,
	conn: RBXScriptConnection?,
}

type BlinkEntry = {
	part: BasePart,
	rate: number,
	phase: number,
	duty: number,
	pos: Vector3,
	on: boolean,
	onT: number,
}

type ScrollEntry = {
	label: TextLabel,
	speed: number,
	block: number,
	pos: Vector3,
	phase: number,
}

type NeonEntry = {
	part: BasePart,
	base: Color3,
	lum: number,
	pos: Vector3,
	from: Color3,
	to: Color3,
}

local moving: { [Instance]: MoveEntry } = {}
local animatedParts: { [BasePart]: boolean } = {}
local blinks: { [BasePart]: BlinkEntry } = {}
local scrolls: { [Instance]: ScrollEntry } = {}
local neonList: { NeonEntry } = {}
local neonIndex: { [BasePart]: number } = {}
local cityLights: { BasePart } = {}
local cityIndex: { [BasePart]: number } = {}

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}

local function numAttr(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if typeof(v) == "number" then v else default
end

local function addMovePart(e: MoveEntry, p: BasePart)
	if animatedParts[p] then
		return
	end
	table.insert(e.parts, p)
	table.insert(e.offsets, e.base:ToObjectSpace(p.CFrame))
	animatedParts[p] = true
end

local function removeMove(inst: Instance)
	local e = moving[inst]
	if not e then
		return
	end
	moving[inst] = nil
	if e.conn then
		e.conn:Disconnect()
	end
	for _, p in e.parts do
		animatedParts[p] = nil
	end
end

local function addMove(inst: Instance, kind: string)
	if moving[inst] then
		return
	end
	local base: CFrame
	if inst:IsA("Model") then
		base = inst:GetPivot()
	elseif inst:IsA("BasePart") then
		base = inst.CFrame
	else
		return
	end
	local axisAttr = inst:GetAttribute("Axis")
	local e: MoveEntry = {
		inst = inst,
		kind = kind,
		parts = {},
		offsets = {},
		base = base,
		pos = base.Position,
		speed = numAttr(inst, "Speed", if kind == "Spin" then 30 else 1.5),
		axis = if typeof(axisAttr) == "string" then axisAttr else "Y",
		amp = numAttr(inst, "Amplitude", 0.6),
		phase = numAttr(inst, "Phase", rr(0, PI * 2)),
		rot = numAttr(inst, "Rot", 0),
		conn = nil,
	}
	if inst:IsA("BasePart") then
		addMovePart(e, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			addMovePart(e, d)
		end
	end
	e.conn = inst.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("BasePart") then
			addMovePart(e, d)
		end
	end)
	moving[inst] = e
end

local function addBlink(inst: Instance)
	if not inst:IsA("BasePart") or blinks[inst] then
		return
	end
	local p = inst :: BasePart
	blinks[p] = {
		part = p,
		rate = numAttr(p, "Rate", 1),
		phase = numAttr(p, "Phase", rr(0, 1)),
		duty = numAttr(p, "Duty", 0.5),
		pos = p.Position,
		on = true,
		onT = p.Transparency,
	}
end

local function addScroll(inst: Instance)
	if scrolls[inst] then
		return
	end
	local lbl = inst:FindFirstChild("Code")
	if not (lbl and lbl:IsA("TextLabel")) then
		lbl = inst:FindFirstChildWhichIsA("TextLabel")
	end
	if not lbl then
		return
	end
	local holder = inst:FindFirstAncestorWhichIsA("BasePart")
	scrolls[inst] = {
		label = lbl :: TextLabel,
		speed = numAttr(inst, "Speed", 24),
		block = numAttr(inst, "BlockHeight", 0),
		pos = if holder then holder.Position else Vector3.zero,
		phase = rr(0, 1000),
	}
end

local function neonTarget(e: NeonEntry, look: Look): Color3
	local acc = look.neon
	if not acc then
		return e.base
	end
	local k = e.lum * look.neonMul
	return e.base:Lerp(Color3.new(math.min(acc.R * k, 1), math.min(acc.G * k, 1), math.min(acc.B * k, 1)), look.neonMix)
end

local function addNeon(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local p = inst :: BasePart
	if neonIndex[p] then
		return
	end
	local attr = p:GetAttribute("BaseColor")
	local base: Color3 = if typeof(attr) == "Color3" then attr else p.Color
	local e: NeonEntry = {
		part = p,
		base = base,
		lum = math.max(base.R, base.G, base.B),
		pos = p.Position,
		from = base,
		to = base,
	}
	e.to = neonTarget(e, toLook)
	e.from = e.to
	p.Color = e.to
	table.insert(neonList, e)
	neonIndex[p] = #neonList
end

local function removeNeon(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local p = inst :: BasePart
	local i = neonIndex[p]
	if not i then
		return
	end
	local last = neonList[#neonList]
	neonList[i] = last
	neonIndex[last.part] = i
	neonList[#neonList] = nil
	neonIndex[p] = nil
end

local function addCity(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local p = inst :: BasePart
	if cityIndex[p] then
		return
	end
	table.insert(cityLights, p)
	cityIndex[p] = #cityLights
end

local function removeCity(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local p = inst :: BasePart
	local i = cityIndex[p]
	if not i then
		return
	end
	local last = cityLights[#cityLights]
	cityLights[i] = last
	cityIndex[last] = i
	cityLights[#cityLights] = nil
	cityIndex[p] = nil
end

local function watchTag(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

---------------------------------------------------------------------------------------------------
-- Weather scaffolding
---------------------------------------------------------------------------------------------------

type Weather = {
	update: (dt: number, now: number, camPos: Vector3) -> (),
	cleanup: (() -> ())?,
	neonMod: ((e: NeonEntry, now: number) -> number)?,
}

type Follower = { part: Part, offset: Vector3 }

local weatherFolder: Folder = Instance.new("Folder")
weatherFolder.Name = "WorldFX_Weather"
local followers: { Follower } = {}
local weather: Weather? = nil

local function fxPart(name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = weatherFolder
	return p
end

local function fxNeon(parent: Instance, size: Vector3, cf: CFrame, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function follower(name: string, size: Vector3, offset: Vector3): Part
	local p = fxPart(name, size, CFrame.new(offset))
	table.insert(followers, { part = p, offset = offset })
	return p
end

type EmitterSpec = {
	texture: string,
	rate: number,
	life: NumberRange,
	speed: NumberRange,
	size: NumberSequence,
	transparency: NumberSequence,
	color: ColorSequence,
	light: number?,
	lightInfluence: number?,
	accel: Vector3?,
	drag: number?,
	spread: Vector2?,
	dir: Enum.NormalId?,
	rot: NumberRange?,
	rotSpeed: NumberRange?,
	squash: NumberSequence?,
	orient: Enum.ParticleOrientation?,
	brightness: number?,
}

local function emitter(parent: BasePart, s: EmitterSpec): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = TEX .. s.texture
	pe.Rate = s.rate
	pe.Lifetime = s.life
	pe.Speed = s.speed
	pe.Size = s.size
	pe.Transparency = s.transparency
	pe.Color = s.color
	pe.LightEmission = s.light or 1
	pe.LightInfluence = s.lightInfluence or 0
	pe.Acceleration = s.accel or Vector3.zero
	pe.Drag = s.drag or 0
	pe.SpreadAngle = s.spread or Vector2.zero
	pe.EmissionDirection = s.dir or Enum.NormalId.Top
	pe.Rotation = s.rot or NumberRange.new(0)
	pe.RotSpeed = s.rotSpeed or NumberRange.new(0)
	if s.squash then
		pe.Squash = s.squash
	end
	pe.Orientation = s.orient or Enum.ParticleOrientation.FacingCamera
	pe.Brightness = s.brightness or 1
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pe.Parent = parent
	return pe
end

local function addFlash(color: Color3, dur: number, strength: number)
	local s = Ctx.Data.Settings
	if s and s.Calm == true then -- reduced flashing (photosensitivity option)
		strength *= 0.3
		dur *= 1.5
	end
	table.insert(flashes, { color = color, t0 = os.clock(), dur = math.max(dur, 0.05), strength = strength })
end

-- Lightning bolt somewhere around the camera.
local function strike(color: Color3, camPos: Vector3, minD: number, maxD: number, flashStrength: number)
	local myEpoch = epoch
	local bolt = Instance.new("Folder")
	bolt.Name = "Bolt"
	bolt.Parent = weatherFolder
	local ang = rr(0, PI * 2)
	local dist = rr(minD, maxD)
	local ground = Vector3.new(camPos.X + math.cos(ang) * dist, rr(20, 90), camPos.Z + math.sin(ang) * dist)
	local top = ground + Vector3.new(rr(-30, 30), rr(160, 240), rr(-30, 30))
	local core: { BasePart } = {}
	local glow: { BasePart } = {}
	local function segment(a: Vector3, b: Vector3, w: number)
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		table.insert(core, fxNeon(bolt, Vector3.new(w, w, len + w), cf, Color3.new(1, 1, 1):Lerp(color, 0.35), 0))
		table.insert(glow, fxNeon(bolt, Vector3.new(w * 4, w * 4, len + w), cf, color, 0.78))
	end
	local pts = { top }
	local n = ri(9, 14)
	for i = 1, n - 1 do
		local t = i / n
		local jit = 16 * (1 - t * 0.5)
		table.insert(pts, top:Lerp(ground, t) + Vector3.new(rr(-1, 1) * jit, rr(-0.3, 0.3) * jit, rr(-1, 1) * jit))
	end
	table.insert(pts, ground)
	for i = 1, #pts - 1 do
		segment(pts[i], pts[i + 1], 0.9 - i / #pts * 0.4)
	end
	for _ = 1, ri(1, 3) do
		local k = ri(2, math.max(2, #pts - 3))
		local p = pts[k]
		local dir = Vector3.new(rr(-1, 1), rr(-1.2, -0.4), rr(-1, 1)).Unit
		for _ = 1, ri(3, 5) do
			local q = p + dir * rr(10, 20) + Vector3.new(rr(-5, 5), 0, rr(-5, 5))
			segment(p, q, 0.35)
			p = q
		end
	end
	local lightP = fxPart("BoltLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(top:Lerp(ground, 0.6)))
	lightP.Parent = bolt
	local pl = Instance.new("PointLight")
	pl.Color = color
	pl.Range = 60
	pl.Brightness = 10
	pl.Shadows = false
	pl.Parent = lightP
	addFlash(color, 0.35, flashStrength)

	task.spawn(function()
		local function setVis(v: boolean)
			for _, p in core do
				p.Transparency = if v then 0 else 1
			end
			for _, p in glow do
				p.Transparency = if v then 0.78 else 1
			end
			pl.Enabled = v
		end
		task.wait(0.07)
		setVis(false)
		task.wait(0.05)
		if epoch ~= myEpoch then
			bolt:Destroy()
			return
		end
		setVis(true)
		task.wait(0.06)
		for i = 1, 6 do
			local t = i / 6
			for _, p in core do
				p.Transparency = t
			end
			for _, p in glow do
				p.Transparency = 0.78 + 0.22 * t
			end
			pl.Brightness = 10 * (1 - t)
			task.wait(0.035)
		end
		bolt:Destroy()
	end)
end

type Glyph = { att: Attachment, label: TextLabel, vel: number, nextSwap: number, base: number }

-- Floating/falling billboard glyphs around the camera.
local function glyphRain(
	count: number,
	chars: { string },
	colors: { Color3 },
	font: Font,
	sizeMin: number,
	sizeMax: number,
	vMin: number,
	vMax: number,
	radius: number
): (dt: number, now: number, camPos: Vector3) -> ()
	local anchor = fxPart("GlyphAnchor", Vector3.new(0.2, 0.2, 0.2), CFrame.identity)
	local list: { Glyph } = {}
	local function spawnPos(camPos: Vector3, anywhere: boolean): Vector3
		local a = rr(0, PI * 2)
		local r = math.sqrt(rr(0.02, 1)) * radius
		local y = if anywhere then rr(-15, 55) else rr(30, 60)
		return Vector3.new(camPos.X + math.cos(a) * r, camPos.Y + y, camPos.Z + math.sin(a) * r)
	end
	local cam = workspace.CurrentCamera
	local startPos = if cam then cam.CFrame.Position else Vector3.zero
	for _ = 1, count do
		local att = Instance.new("Attachment")
		att.Position = spawnPos(startPos, true)
		att.Parent = anchor
		local s = rr(sizeMin, sizeMax)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.new(s, 0, s, 0)
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.AlwaysOnTop = false
		gui.MaxDistance = 260
		gui.Adornee = att
		gui.ResetOnSpawn = false
		gui.Parent = att
		local color = colors[ri(1, #colors)]
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.TextScaled = true
		lbl.FontFace = font
		lbl.Text = chars[ri(1, #chars)]
		lbl.TextColor3 = color
		lbl.TextStrokeColor3 = scaleColor(color, 0.3)
		lbl.TextStrokeTransparency = 0.4
		local baseT = rr(0, 0.35)
		lbl.TextTransparency = baseT
		lbl.Parent = gui
		table.insert(list, { att = att, label = lbl, vel = rr(vMin, vMax), nextSwap = os.clock() + rr(0.05, 0.4), base = baseT })
	end
	return function(dt: number, now: number, camPos: Vector3)
		for _, g in list do
			local p = g.att.Position - Vector3.new(0, g.vel * dt, 0)
			local flat = Vector3.new(p.X - camPos.X, 0, p.Z - camPos.Z)
			if p.Y < camPos.Y - 25 or flat.Magnitude > radius * 1.35 then
				p = spawnPos(camPos, false)
			end
			g.att.Position = p
			if now > g.nextSwap then
				g.nextSwap = now + rr(0.06, 0.45)
				g.label.Text = chars[ri(1, #chars)]
				g.label.TextTransparency = if rng:NextNumber() < 0.15 then 0.85 else g.base
			end
		end
	end
end

local function glitchedChars(set: string): { string }
	local t = {}
	for i = 1, #set do
		table.insert(t, string.sub(set, i, i))
	end
	return t
end

---------------------------------------------------------------------------------------------------
-- Blackout power cut
---------------------------------------------------------------------------------------------------

type CitySave = { color: Color3, material: Enum.Material }
local savedLights: { [Light]: boolean } = {}
local savedGuis: { [SurfaceGui]: boolean } = {}
local savedCity: { [BasePart]: CitySave } = {}

local function powerCut()
	local map = workspace:FindFirstChild("Map")
	local myEpoch = epoch
	local buckets: { { () -> () } } = {}
	for i = 1, 12 do
		buckets[i] = {}
	end
	local function queue(fn: () -> ())
		table.insert(buckets[ri(1, 12)], fn)
	end
	if map then
		for _, d in map:GetDescendants() do
			if d:IsA("Light") then
				local l = d :: Light
				queue(function()
					if savedLights[l] == nil then
						savedLights[l] = l.Enabled
					end
					l.Enabled = false
				end)
			elseif d:IsA("SurfaceGui") then
				local g = d :: SurfaceGui
				if g.Name ~= "Board" and g.Name ~= "Screen" and rng:NextNumber() < 0.8 then
					queue(function()
						if savedGuis[g] == nil then
							savedGuis[g] = g.Enabled
						end
						g.Enabled = false
					end)
				end
			end
		end
	end
	for _, p in cityLights do
		if rng:NextNumber() < 0.88 then
			queue(function()
				if not savedCity[p] then
					savedCity[p] = { color = p.Color, material = p.Material }
				end
				p.Color = rgb(6, 6, 9)
				p.Material = Enum.Material.SmoothPlastic
			end)
		end
	end
	for i, list in buckets do
		task.delay(0.15 + (i - 1) * 0.11, function()
			if epoch ~= myEpoch then
				return
			end
			for _, fn in list do
				fn()
			end
		end)
	end
end

local function powerRestore()
	for l, en in savedLights do
		if l.Parent then
			l.Enabled = en
		end
	end
	for g, en in savedGuis do
		if g.Parent then
			g.Enabled = en
		end
	end
	for p, s in savedCity do
		if p.Parent then
			p.Color = s.color
			p.Material = s.material
		end
	end
	table.clear(savedLights)
	table.clear(savedGuis)
	table.clear(savedCity)
end

---------------------------------------------------------------------------------------------------
-- Shared weather bits
---------------------------------------------------------------------------------------------------

local flickering: { [BasePart]: boolean } = {}

local function flickerPart(p: BasePart, times: number)
	if flickering[p] then
		return
	end
	flickering[p] = true
	local orig = p.Transparency
	task.spawn(function()
		for _ = 1, times do
			p.Transparency = 0.92
			task.wait(rr(0.03, 0.1))
			p.Transparency = orig
			task.wait(rr(0.03, 0.16))
		end
		p.Transparency = orig
		flickering[p] = nil
	end)
end

local function randomNeonNear(camPos: Vector3, maxD: number, minD: number?): NeonEntry?
	if #neonList == 0 then
		return nil
	end
	for _ = 1, 12 do
		local e = neonList[ri(1, #neonList)]
		local d = (e.pos - camPos).Magnitude
		if d < maxD and d >= (minD or 0) and not animatedParts[e.part] then
			return e
		end
	end
	return nil
end

local function mapPositions(): { Vector3 }
	local out: { Vector3 } = {}
	local map = workspace:FindFirstChild("Map")
	if not map then
		return out
	end
	for _, d in map:GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("Kind") ~= nil then
			local parent = d.Parent
			if parent and parent:IsA("BasePart") then
				table.insert(out, parent.Position)
			end
		end
	end
	local board = map:FindFirstChild("LeaderboardScreen")
	if board and board:IsA("BasePart") then
		table.insert(out, board.Position)
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Weather per biome
---------------------------------------------------------------------------------------------------

local WEATHER: { [string]: () -> Weather } = {}

WEATHER.Normal = function(): Weather
	local dust = follower("Dust", Vector3.new(90, 30, 90), Vector3.new(0, 4, 0))
	emitter(dust, {
		texture = "SquareParticle.png",
		rate = 50,
		life = NumberRange.new(6, 10),
		speed = NumberRange.new(0.2, 0.8),
		size = ns(0, 0, 0.15, 0.12, 0.85, 0.1, 1, 0),
		transparency = ns(0, 1, 0.2, 0.35, 0.8, 0.45, 1, 1),
		color = ColorSequence.new(rgb(140, 250, 255), rgb(255, 120, 230)),
		accel = Vector3.new(0.25, 0.12, 0.1),
		drag = 0.4,
		spread = Vector2.new(180, 180),
		rotSpeed = NumberRange.new(-60, 60),
	})
	emitter(dust, {
		texture = "sparkles_main.dds",
		rate = 6,
		life = NumberRange.new(2, 4),
		speed = NumberRange.new(0.1, 0.4),
		size = ns(0, 0, 0.5, 0.35, 1, 0),
		transparency = ns(0, 1, 0.3, 0.4, 1, 1),
		color = ColorSequence.new(rgb(200, 250, 255)),
		spread = Vector2.new(180, 180),
	})
	local nextFlicker = os.clock() + rr(3, 7)
	return {
		update = function(_dt: number, now: number, camPos: Vector3)
			if now > nextFlicker then
				nextFlicker = now + rr(4, 11)
				for _ = 1, ri(1, 3) do
					if #cityLights > 0 and rng:NextNumber() < 0.7 then
						local p = cityLights[ri(1, #cityLights)]
						if (p.Position - camPos).Magnitude > 60 then
							flickerPart(p, ri(3, 8))
						end
					else
						local e = randomNeonNear(camPos, 400, 60)
						if e then
							flickerPart(e.part, ri(2, 6))
						end
					end
				end
			end
		end,
	}
end

WEATHER.DataStorm = function(): Weather
	local green = biomeColor("DataStorm", rgb(60, 255, 160))
	local rain = follower("CodeRain", Vector3.new(150, 1, 150), Vector3.new(0, 55, 0))
	emitter(rain, {
		texture = "SquareParticle.png",
		rate = 900,
		life = NumberRange.new(1.1, 1.6),
		speed = NumberRange.new(60, 90),
		size = ns(0.14),
		transparency = ns(0, 0.6, 0.15, 0.15, 1, 0.7),
		color = ColorSequence.new(rgb(120, 255, 170), rgb(20, 160, 80)),
		accel = Vector3.new(0, -40, 0),
		dir = Enum.NormalId.Bottom,
		spread = Vector2.new(2, 2),
		squash = ns(2.6),
		orient = Enum.ParticleOrientation.VelocityParallel,
	})
	emitter(rain, {
		texture = "SquareParticle.png",
		rate = 140,
		life = NumberRange.new(1.1, 1.6),
		speed = NumberRange.new(55, 80),
		size = ns(0.32),
		transparency = ns(0, 0.3, 1, 0.6),
		color = ColorSequence.new(rgb(220, 255, 230), green),
		accel = Vector3.new(0, -40, 0),
		dir = Enum.NormalId.Bottom,
		squash = ns(1.2),
		orient = Enum.ParticleOrientation.VelocityParallel,
		brightness = 2,
	})
	local mist = follower("GreenMist", Vector3.new(110, 10, 110), Vector3.new(0, -2, 0))
	emitter(mist, {
		texture = "smoke_main.dds",
		rate = 7,
		life = NumberRange.new(6, 9),
		speed = NumberRange.new(0.5, 2),
		size = ns(0, 10, 1, 22),
		transparency = ns(0, 1, 0.3, 0.86, 1, 1),
		color = ColorSequence.new(rgb(40, 160, 90)),
		light = 0.25,
		lightInfluence = 0.4,
		spread = Vector2.new(180, 20),
		rot = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-10, 10),
	})
	local splash = follower("Splash", Vector3.new(60, 1, 60), Vector3.new(0, -4, 0))
	emitter(splash, {
		texture = "sparkles_main.dds",
		rate = 40,
		life = NumberRange.new(0.2, 0.4),
		speed = NumberRange.new(2, 5),
		size = ns(0, 0.4, 1, 0),
		transparency = ns(0, 0.3, 1, 1),
		color = ColorSequence.new(green),
		spread = Vector2.new(60, 60),
	})
	local glyphs = glyphRain(
		38,
		glitchedChars("01ABCDEF#$%&*+=/\\|?:;0101"),
		{ rgb(120, 255, 170), green, rgb(200, 255, 220), rgb(30, 200, 110) },
		FONT_MONO_B,
		1.2,
		2.8,
		6,
		15,
		70
	)
	local nextStrike = os.clock() + rr(1, 3)
	return {
		update = function(dt: number, now: number, camPos: Vector3)
			glyphs(dt, now, camPos)
			if now > nextStrike then
				nextStrike = now + rr(1.5, 4.5)
				strike(green, camPos, 140, 300, 0.35)
			end
		end,
		neonMod = function(e: NeonEntry, now: number): number
			return 0.8 + 0.2 * math.sin(now * 3 + e.pos.Z * 0.08)
		end,
	}
end

WEATHER.Overclock = function(): Weather
	local orange = biomeColor("Overclock", rgb(255, 140, 0))
	local haze = follower("Heat", Vector3.new(80, 6, 80), Vector3.new(0, -1, 0))
	emitter(haze, {
		texture = "forcefield_glow_main.dds",
		rate = 22,
		life = NumberRange.new(3, 5),
		speed = NumberRange.new(1, 3),
		size = ns(0, 5, 1, 11),
		transparency = ns(0, 1, 0.4, 0.9, 1, 1),
		color = ColorSequence.new(rgb(255, 150, 60), rgb(255, 80, 20)),
		light = 0.6,
		spread = Vector2.new(20, 20),
		rot = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-25, 25),
	})
	emitter(haze, {
		texture = "smoke_main.dds",
		rate = 6,
		life = NumberRange.new(5, 8),
		speed = NumberRange.new(2, 4),
		size = ns(0, 6, 1, 18),
		transparency = ns(0, 1, 0.3, 0.88, 1, 1),
		color = ColorSequence.new(rgb(180, 90, 40)),
		light = 0.2,
		lightInfluence = 0.5,
		spread = Vector2.new(15, 15),
		rot = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-8, 8),
	})
	local sparks = follower("SparkRain", Vector3.new(110, 1, 110), Vector3.new(0, 40, 0))
	emitter(sparks, {
		texture = "fire_sparks_main.dds",
		rate = 170,
		life = NumberRange.new(1.5, 2.5),
		speed = NumberRange.new(8, 20),
		size = ns(0, 0.45, 1, 0),
		transparency = ns(0, 0, 0.8, 0.2, 1, 1),
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 250, 200)),
			ColorSequenceKeypoint.new(0.4, rgb(255, 170, 40)),
			ColorSequenceKeypoint.new(1, rgb(255, 50, 10)),
		}),
		accel = Vector3.new(0, -50, 0),
		dir = Enum.NormalId.Bottom,
		spread = Vector2.new(25, 25),
		squash = ns(1.4),
		orient = Enum.ParticleOrientation.VelocityParallel,
		brightness = 2,
	})
	local embers = follower("Embers", Vector3.new(70, 12, 70), Vector3.new(0, 2, 0))
	emitter(embers, {
		texture = "SquareParticle.png",
		rate = 45,
		life = NumberRange.new(3, 6),
		speed = NumberRange.new(1, 3),
		size = ns(0, 0.12, 1, 0),
		transparency = ns(0, 0, 1, 1),
		color = ColorSequence.new(rgb(255, 200, 80), rgb(255, 60, 0)),
		accel = Vector3.new(0.4, 1.5, 0),
		spread = Vector2.new(40, 40),
		rotSpeed = NumberRange.new(-120, 120),
	})
	local nextBurst = os.clock() + rr(0.5, 1.5)
	local function burst(camPos: Vector3)
		local pos: Vector3
		local e = randomNeonNear(camPos, 90, 12)
		if e then
			pos = e.pos
		else
			local a = rr(0, PI * 2)
			local r = rr(15, 60)
			pos = Vector3.new(camPos.X + math.cos(a) * r, rr(6, 22), camPos.Z + math.sin(a) * r)
		end
		local p = fxPart("Burst", Vector3.new(0.4, 0.4, 0.4), CFrame.new(pos))
		local pe = emitter(p, {
			texture = "fire_sparks_main.dds",
			rate = 0,
			life = NumberRange.new(0.4, 1.1),
			speed = NumberRange.new(10, 26),
			size = ns(0, 0.35, 1, 0),
			transparency = ns(0, 0, 1, 1),
			color = ColorSequence.new(rgb(255, 240, 180), orange),
			accel = Vector3.new(0, -60, 0),
			spread = Vector2.new(180, 180),
			squash = ns(1.5),
			orient = Enum.ParticleOrientation.VelocityParallel,
			brightness = 3,
		})
		pe.Shape = Enum.ParticleEmitterShape.Sphere
		pe:Emit(ri(25, 45))
		local pl = Instance.new("PointLight")
		pl.Color = orange
		pl.Range = 18
		pl.Brightness = 6
		pl.Shadows = false
		pl.Parent = p
		task.delay(0.12, function()
			pl.Enabled = false
		end)
		task.delay(2, function()
			p:Destroy()
		end)
	end
	return {
		update = function(_dt: number, now: number, camPos: Vector3)
			if now > nextBurst then
				nextBurst = now + rr(0.5, 1.6)
				burst(camPos)
			end
			-- slight overheated brightness wobble
			extra.brightMul = 1 + 0.06 * math.sin(now * 11)
		end,
		neonMod = function(e: NeonEntry, now: number): number
			return 0.55 + 0.45 * math.sin(now * 9 + (e.pos.X + e.pos.Z) * 0.04)
		end,
	}
end

type Beacon = { head: Part, dome: Part, light: PointLight, top: Vector3, phase: number }

WEATHER.Blackout = function(): Weather
	local red = biomeColor("Blackout", rgb(255, 30, 30))
	powerCut()
	addFlash(rgb(0, 0, 0), 0.8, 0.6)

	-- emergency beacons
	local spots: { Vector3 } = {}
	for _, p in mapPositions() do
		local flat = Vector3.new(p.X, 0, p.Z)
		local toC = if flat.Magnitude > 1 then -flat.Unit else Vector3.zAxis
		local side = toC:Cross(Vector3.yAxis)
		table.insert(spots, flat + toC * 9 + side * 7)
		table.insert(spots, flat + toC * 9 - side * 7)
	end
	for _, c in { Vector3.new(-100, 0, -100), Vector3.new(100, 0, -100), Vector3.new(-100, 0, 100), Vector3.new(100, 0, 100), Vector3.new(0, 0, -36), Vector3.new(-24, 0, -62), Vector3.new(24, 0, -62) } do
		table.insert(spots, c)
	end
	local beacons: { Beacon } = {}
	for _, s in spots do
		local stand = fxNeon(weatherFolder, Vector3.new(0.4, 3.2, 0.4), CFrame.new(s + Vector3.new(0, 1.6, 0)), rgb(20, 20, 26), 0)
		stand.Material = Enum.Material.Metal
		local base = fxNeon(weatherFolder, Vector3.new(1.6, 0.3, 1.6), CFrame.new(s + Vector3.new(0, 0.15, 0)), rgb(30, 30, 36), 0)
		base.Material = Enum.Material.Metal
		local top = s + Vector3.new(0, 3.75, 0)
		local dome = fxNeon(weatherFolder, Vector3.new(1.1, 1.1, 1.1), CFrame.new(top), red, 0)
		dome.Shape = Enum.PartType.Ball
		local cap = fxNeon(weatherFolder, Vector3.new(1.45, 1.45, 1.45), CFrame.new(top), red, 0.7)
		cap.Shape = Enum.PartType.Ball
		cap.Material = Enum.Material.Glass
		local head = fxPart("BeaconHead", Vector3.new(0.3, 0.3, 0.3), CFrame.new(top))
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local sl = Instance.new("SpotLight")
			sl.Face = face
			sl.Color = red
			sl.Range = 48
			sl.Angle = 40
			sl.Brightness = 8
			sl.Shadows = false
			sl.Parent = head
		end
		local pl = Instance.new("PointLight")
		pl.Color = red
		pl.Range = 14
		pl.Brightness = 2
		pl.Shadows = false
		pl.Parent = dome
		table.insert(beacons, { head = head, dome = dome, light = pl, top = top, phase = rr(0, PI * 2) })
	end

	local smoke = follower("DarkSmoke", Vector3.new(100, 8, 100), Vector3.new(0, -1, 0))
	emitter(smoke, {
		texture = "smoke_main.dds",
		rate = 14,
		life = NumberRange.new(7, 10),
		speed = NumberRange.new(0.8, 2),
		size = ns(0, 12, 1, 26),
		transparency = ns(0, 1, 0.3, 0.6, 1, 1),
		color = ColorSequence.new(rgb(22, 12, 14)),
		light = 0,
		lightInfluence = 1,
		spread = Vector2.new(180, 25),
		rot = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-8, 8),
	})
	local ash = follower("Ash", Vector3.new(80, 20, 80), Vector3.new(0, 8, 0))
	emitter(ash, {
		texture = "SquareParticle.png",
		rate = 30,
		life = NumberRange.new(5, 8),
		speed = NumberRange.new(0.3, 1),
		size = ns(0, 0.1, 1, 0.05),
		transparency = ns(0, 1, 0.2, 0.3, 1, 1),
		color = ColorSequence.new(rgb(255, 60, 60), rgb(120, 10, 10)),
		accel = Vector3.new(0.3, -0.5, 0),
		spread = Vector2.new(180, 180),
		rotSpeed = NumberRange.new(-90, 90),
	})
	local nextPulse = os.clock() + rr(5, 9)
	return {
		update = function(_dt: number, now: number, camPos: Vector3)
			for _, b in beacons do
				if (b.top - camPos).Magnitude > CULL then
					continue
				end
				local a = now * 4.2 + b.phase
				b.head.CFrame = CFrame.new(b.top) * CFrame.Angles(0, a, 0)
				local s = 0.5 + 0.5 * math.sin(a * 2)
				b.dome.Color = scaleColor(red, 0.45 + 0.55 * s)
				b.light.Brightness = 0.8 + 2.4 * s
			end
			if now > nextPulse then
				nextPulse = now + rr(6, 12)
				addFlash(red, 0.5, 0.25)
			end
		end,
		cleanup = function()
			powerRestore()
		end,
		neonMod = function(e: NeonEntry, now: number): number
			return 0.7 + 0.3 * math.sin(now * 2 + e.pos.X * 0.02)
		end,
	}
end

WEATHER.KernelPanic = function(): Weather
	local red = biomeColor("KernelPanic", rgb(255, 0, 60))
	local glyphs = glyphRain(
		30,
		{ "!", "!", "!!", "!", "ERR", "0x0", "!", "/!\\", "??", "!" },
		{ red, rgb(255, 60, 60), rgb(255, 255, 255), rgb(255, 120, 120) },
		FONT_PIX,
		1.4,
		3.2,
		7,
		16,
		70
	)
	local rain = follower("RedStatic", Vector3.new(130, 1, 130), Vector3.new(0, 50, 0))
	emitter(rain, {
		texture = "SquareParticle.png",
		rate = 260,
		life = NumberRange.new(1.2, 1.8),
		speed = NumberRange.new(45, 70),
		size = ns(0.13),
		transparency = ns(0, 0.5, 0.2, 0.2, 1, 0.8),
		color = ColorSequence.new(rgb(255, 80, 90), rgb(160, 0, 20)),
		accel = Vector3.new(0, -30, 0),
		dir = Enum.NormalId.Bottom,
		spread = Vector2.new(4, 4),
		squash = ns(2.2),
		orient = Enum.ParticleOrientation.VelocityParallel,
	})
	local haze = follower("RedHaze", Vector3.new(100, 8, 100), Vector3.new(0, -1, 0))
	emitter(haze, {
		texture = "smoke_main.dds",
		rate = 8,
		life = NumberRange.new(5, 8),
		speed = NumberRange.new(1, 2.5),
		size = ns(0, 10, 1, 22),
		transparency = ns(0, 1, 0.3, 0.8, 1, 1),
		color = ColorSequence.new(rgb(140, 10, 20)),
		light = 0.3,
		lightInfluence = 0.5,
		spread = Vector2.new(180, 20),
		rot = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-15, 15),
	})
	local shards = follower("Shards", Vector3.new(60, 20, 60), Vector3.new(0, 6, 0))
	emitter(shards, {
		texture = "SquareParticle.png",
		rate = 18,
		life = NumberRange.new(0.15, 0.4),
		speed = NumberRange.new(0, 0.5),
		size = ns(0, 0.6, 1, 0.9),
		transparency = ns(0, 0.2, 1, 1),
		color = ColorSequence.new(rgb(255, 255, 255), red),
		squash = ns(-2),
		brightness = 2,
	})

	local glitched: { [BasePart]: CFrame } = {}
	local nextStrike = os.clock() + rr(0.5, 1.5)
	local nextGlitch = os.clock()
	local nextShake = os.clock() + rr(1.5, 3)
	local flickTick = 0
	local globalFlick = 1
	local flickBright = 0
	return {
		update = function(_dt: number, now: number, camPos: Vector3)
			glyphs(_dt, now, camPos)
			if now > nextStrike then
				nextStrike = now + rr(0.8, 2.6)
				strike(red, camPos, 80, 260, 0.45)
			end
			if now > nextGlitch then
				nextGlitch = now + rr(0.12, 0.55)
				for _ = 1, ri(1, 4) do
					local e = randomNeonNear(camPos, 160)
					if e and not glitched[e.part] then
						local p = e.part
						local orig = p.CFrame
						glitched[p] = orig
						p.CFrame = orig * CFrame.new(rr(-1.6, 1.6), rr(-0.8, 0.8), rr(-1.6, 1.6))
						p.Color = Color3.new(1, 1, 1)
						task.delay(rr(0.06, 0.2), function()
							if glitched[p] then
								p.CFrame = glitched[p]
								glitched[p] = nil
							end
						end)
					end
				end
			end
			if now > nextShake then
				nextShake = now + rr(2, 5)
				shakeUntil = now + rr(0.3, 0.5)
				shakeMag = rr(0.6, 1.2)
				addFlash(red, 0.25, 0.3)
			end
			-- violent light flicker
			if now > flickTick then
				flickTick = now + 0.05
				if rng:NextNumber() < 0.22 then
					globalFlick = rr(0.1, 0.9)
					flickBright = rr(-0.22, 0.06)
				else
					globalFlick = 1
					flickBright = 0
				end
			end
			extra.ccBright = flickBright
			extra.brightMul = 0.6 + 0.4 * globalFlick
		end,
		cleanup = function()
			for p, cf in glitched do
				p.CFrame = cf
			end
			table.clear(glitched)
		end,
		neonMod = function(_e: NeonEntry, _now: number): number
			if rng:NextNumber() < 0.05 then
				return 0.08
			end
			return globalFlick
		end,
	}
end

---------------------------------------------------------------------------------------------------
-- Biome switching
---------------------------------------------------------------------------------------------------

local function now(): number
	return os.clock()
end

local function buildWeather(id: string)
	local maker = WEATHER[id] or WEATHER.Normal
	weather = maker()
end

local function teardownWeather()
	epoch += 1
	local w = weather
	weather = nil
	if w and w.cleanup then
		w.cleanup()
	end
	table.clear(followers)
	weatherFolder:ClearAllChildren()
	extra.ccBright = 0
	extra.brightMul = 1
	shakeUntil = 0
end

function WorldFX.SetBiome(id: string)
	if not LOOKS[id] then
		id = "Normal"
	end
	if id == currentBiome and weather ~= nil then
		return
	end
	local t = now()
	fromLook = lastLook
	toLook = LOOKS[id]
	lookT0 = t
	for _, e in neonList do
		e.from = e.part.Color
		e.to = neonTarget(e, toLook)
	end
	currentBiome = id
	if started then
		teardownWeather()
		buildWeather(id)
	end
end

function WorldFX.Flash(color: Color3, duration: number)
	addFlash(color, duration, 1)
end

---------------------------------------------------------------------------------------------------
-- Render loop
---------------------------------------------------------------------------------------------------

local neonTick = 0
local neonTransitioning = false

local function applyLighting(L: Look, t: number)
	local tint, contrast, sat, bright = L.ccTint, L.ccContrast, L.ccSat, L.ccBright + extra.ccBright
	for i = #flashes, 1, -1 do
		local f = flashes[i]
		local a = 1 - (t - f.t0) / f.dur
		if a <= 0 then
			table.remove(flashes, i)
		else
			a = a * a * f.strength
			tint = tint:Lerp(f.color, math.min(1, a * 0.9))
			local lum = math.max(f.color.R, f.color.G, f.color.B)
			bright += a * 0.45 * (if lum < 0.05 then -1.2 else 1)
			contrast += a * 0.15
		end
	end
	Lighting.Ambient = L.ambient
	Lighting.OutdoorAmbient = L.outdoor
	Lighting.Brightness = L.brightness * extra.brightMul
	Lighting.ExposureCompensation = L.exposure
	local a = atmo
	if a then
		a.Density = L.atmoDensity
		a.Offset = L.atmoOffset
		a.Color = L.atmoColor
		a.Decay = L.atmoDecay
		a.Glare = L.atmoGlare
		a.Haze = L.atmoHaze
	end
	local c = cc
	if c then
		c.TintColor = tint
		c.Contrast = contrast
		c.Saturation = sat
		c.Brightness = bright
	end
	local b = bloom
	if b then
		b.Intensity = L.bloomInt
		b.Size = L.bloomSize
		b.Threshold = L.bloomThr
	end
end

local function step(dt: number)
	local t = now()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if weatherFolder.Parent ~= camera then
		weatherFolder.Parent = camera
	end
	local camPos = camera.CFrame.Position

	-- Spin / Bob (single BulkMoveTo)
	table.clear(moveParts)
	table.clear(moveCFrames)
	local n = 0
	for _, e in moving do
		if (e.pos - camPos).Magnitude > CULL then
			continue
		end
		local cf: CFrame
		if e.kind == "Spin" then
			local ang = math.rad(e.speed * t)
			if e.axis == "X" then
				cf = e.base * CFrame.Angles(ang, 0, 0)
			elseif e.axis == "Z" then
				cf = e.base * CFrame.Angles(0, 0, ang)
			else
				cf = e.base * CFrame.Angles(0, ang, 0)
			end
		else
			cf = e.base * CFrame.new(0, math.sin(t * e.speed + e.phase) * e.amp, 0) * CFrame.Angles(0, math.rad(e.rot * t), 0)
		end
		local offs = e.offsets
		for i, p in e.parts do
			n += 1
			moveParts[n] = p
			moveCFrames[n] = cf * offs[i]
		end
	end
	if n > 0 then
		workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- Blink
	for p, e in blinks do
		if (e.pos - camPos).Magnitude > CULL then
			continue
		end
		local on = ((t * e.rate + e.phase) % 1) < e.duty
		if on ~= e.on then
			e.on = on
			p.Transparency = if on then e.onT else 0.9
		end
	end

	-- Scroll
	for _, s in scrolls do
		if (s.pos - camPos).Magnitude > CULL then
			continue
		end
		local block = s.block
		if block <= 0 then
			block = s.label.AbsoluteSize.Y / 2
			if block <= 0 then
				continue
			end
		end
		s.label.Position = UDim2.fromOffset(0, -((t * s.speed + s.phase) % block))
	end

	-- Weather
	for _, f in followers do
		f.part.CFrame = CFrame.new(camPos + f.offset)
	end
	extra.ccBright = 0
	extra.brightMul = 1
	local w = weather
	if w then
		w.update(dt, t, camPos)
	end

	-- Neon colours
	local alpha = smooth((t - lookT0) / TRANSITION)
	if alpha < 1 then
		neonTransitioning = true
		for _, e in neonList do
			e.part.Color = e.from:Lerp(e.to, alpha)
		end
	elseif neonTransitioning then
		neonTransitioning = false
		for _, e in neonList do
			e.part.Color = e.to
		end
	elseif w and w.neonMod and t > neonTick then
		neonTick = t + 1 / 30
		local mod = w.neonMod
		for _, e in neonList do
			if (e.pos - camPos).Magnitude < NEON_FX_RANGE then
				e.part.Color = scaleColor(e.to, mod(e, t))
			end
		end
	end

	-- Lighting
	local L = if alpha < 1 then lerpLook(fromLook, toLook, alpha) else toLook
	lastLook = L
	applyLighting(L, t)

	-- Camera micro-shake (runs after the camera scripts)
	if t < shakeUntil then
		local m = shakeMag * ((shakeUntil - t) / 0.5)
		camera.CFrame = camera.CFrame
			* CFrame.new(rr(-1, 1) * 0.08 * m, rr(-1, 1) * 0.08 * m, 0)
			* CFrame.Angles(rr(-1, 1) * 0.006 * m, rr(-1, 1) * 0.006 * m, rr(-1, 1) * 0.01 * m)
	end
end

---------------------------------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------------------------------

local function bindLighting()
	atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local found = Lighting:FindFirstChild("BiomeCC")
	if found and found:IsA("ColorCorrectionEffect") then
		cc = found
	end
end

function WorldFX.Start()
	if started then
		return
	end
	started = true

	bindLighting()
	Lighting.ChildAdded:Connect(function()
		bindLighting()
	end)
	if not cc then
		task.delay(5, function()
			if not cc then
				local c = Instance.new("ColorCorrectionEffect")
				c.Name = "BiomeCC"
				c.Parent = Lighting
				cc = c
			end
		end)
	end

	watchTag("Spin", function(inst: Instance)
		addMove(inst, "Spin")
	end, removeMove)
	watchTag("Bob", function(inst: Instance)
		addMove(inst, "Bob")
	end, removeMove)
	watchTag("Blink", addBlink, function(inst: Instance)
		if inst:IsA("BasePart") then
			blinks[inst] = nil
		end
	end)
	watchTag("Scroll", addScroll, function(inst: Instance)
		scrolls[inst] = nil
	end)
	watchTag("BiomeNeon", addNeon, removeNeon)
	watchTag("CityLight", addCity, removeCity)

	local camera = workspace.CurrentCamera
	weatherFolder.Parent = camera

	-- initial biome
	local attr = ReplicatedStorage:GetAttribute("Biome")
	local initial = if typeof(attr) == "string" and LOOKS[attr] then attr else currentBiome
	currentBiome = ""
	WorldFX.SetBiome(initial)
	ReplicatedStorage:GetAttributeChangedSignal("Biome"):Connect(function()
		local v = ReplicatedStorage:GetAttribute("Biome")
		WorldFX.SetBiome(if typeof(v) == "string" then v else "Normal")
	end)

	RunService:BindToRenderStep("WorldFX", Enum.RenderPriority.Camera.Value + 1, step)
end

return WorldFX
