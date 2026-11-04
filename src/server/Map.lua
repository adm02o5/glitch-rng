--!strict
-- Map: builds the whole Glitch RNG night plaza at runtime into workspace.Map.
-- Parts / WedgeParts / cylinder Parts only (no meshes, no asset ids). Layout is seeded (Random.new(1337)).
--
-- Tags consumed by the client (WorldFX):
--   Spin      Model/BasePart, attrs Speed (deg/s), Axis "X"|"Y"|"Z"
--   Bob       Model/BasePart, attrs Amplitude (studs), Speed (rad/s), Phase (rad), Rot (deg/s, optional)
--   Blink     BasePart, attrs Rate (Hz), Phase (0..1), Duty (0..1)
--   Scroll    Frame holding a TextLabel "Code", attrs Speed (px/s), BlockHeight (px)
--   BiomeNeon BasePart, attr BaseColor (Color3)
--   CityLight BasePart (lit skyscraper/facade windows; WorldFX turns most off in Blackout)

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Positions = {
	Forge: Vector3,
	Lab: Vector3,
	Index: Vector3,
	Leaderboard: Vector3,
	Core: Vector3,
}

local Map = {}
Map.Positions = {
	Forge = Vector3.zero,
	Lab = Vector3.zero,
	Index = Vector3.zero,
	Leaderboard = Vector3.zero,
	Core = Vector3.zero,
} :: Positions

---------------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------------

local PI = math.pi
local HALF = 132 -- playable half extent (invisible walls sit just inside this)

local CORE_POS = Vector3.new(0, 0, -62)
local FORGE_POS = Vector3.new(-80, 0, 2)
local LAB_POS = Vector3.new(80, 0, 2)
local INDEX_POS = Vector3.new(-62, 0, 70)
local BOARD_CENTER = Vector3.new(0, 23, 131.4)

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local Pal = Config.Palette
local CYAN = Pal.Cyan
local MAG = Pal.Magenta
local RED = Pal.Red
local LIME = Pal.Lime
local AMBER = Pal.Amber

local DARK = rgb(9, 10, 15)
local PANEL = rgb(16, 18, 27)
local METAL = rgb(24, 26, 36)
local METAL2 = rgb(36, 39, 52)
local METAL3 = rgb(54, 58, 74)
local RUBBER = rgb(12, 12, 16)
local SCREEN_BLACK = rgb(3, 4, 8)

local SMOOTH = Enum.Material.SmoothPlastic
local METALM = Enum.Material.Metal
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local CONCRETE = Enum.Material.Concrete
local DIAMOND = Enum.Material.DiamondPlate
local ASPHALT = Enum.Material.Asphalt

local FONT_MONO = Font.new("rbxasset://fonts/families/RobotoMono.json")
local FONT_MONO_B = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local FONT_HEAD = Font.new("rbxasset://fonts/families/Michroma.json")
local FONT_PIX = Font.new("rbxasset://fonts/families/PressStart2P.json")

local TEX = "rbxasset://textures/particles/"

local rng = Random.new(1337)

local function rr(a: number, b: number): number
	return rng:NextNumber(a, b)
end

local function ri(a: number, b: number): number
	return rng:NextInteger(a, b)
end

local function chance(p: number): boolean
	return rng:NextNumber() < p
end

local function pick<T>(t: { T }): T
	return t[rng:NextInteger(1, #t)]
end

local function scaleColor(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

---------------------------------------------------------------------------------------------------
-- Part helpers
---------------------------------------------------------------------------------------------------

local function setup(p: BasePart, parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Parent = parent
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Structural part (collides, casts shadow).
local function box(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	setup(p, parent, size, cf, color, mat or SMOOTH)
	return p
end

local function makeDecor(p: BasePart)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
end

-- Small decor (no collision, no shadow).
local function deco(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = box(parent, size, cf, color, mat)
	makeDecor(p)
	return p
end

local function tagBiome(p: BasePart)
	p:AddTag("BiomeNeon")
	p:SetAttribute("BaseColor", p.Color)
end

local function neon(parent: Instance, size: Vector3, cf: CFrame, color: Color3, biome: boolean?): Part
	local p = deco(parent, size, cf, color, NEON)
	if biome then
		tagBiome(p)
	end
	return p
end

local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): WedgePart
	local p = Instance.new("WedgePart")
	setup(p, parent, size, cf, color, mat or SMOOTH)
	return p
end

-- Cylinder whose axis is the CFrame's X axis.
local function cyl(parent: Instance, length: number, diameter: number, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = box(parent, Vector3.new(length, diameter, diameter), cf, color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, PI / 2)

-- Cylinder standing upright (axis along the CFrame's Y axis).
local function cylY(parent: Instance, height: number, diameter: number, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	return cyl(parent, height, diameter, cf * UPRIGHT, color, mat)
end

local function ball(parent: Instance, d: number, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = deco(parent, Vector3.new(d, d, d), cf, color, mat)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Straight bar from a to b.
local function seg(parent: Instance, a: Vector3, b: Vector3, th: number, color: Color3, mat: Enum.Material?): Part
	local len = (b - a).Magnitude
	return deco(parent, Vector3.new(th, th, math.max(len, 0.05)), CFrame.lookAt((a + b) / 2, b), color, mat)
end

-- Hanging cable (catenary-ish parabola) made of small segments.
local function cable(parent: Instance, a: Vector3, b: Vector3, sag: number, th: number, color: Color3, glow: boolean?)
	local dist = (b - a).Magnitude
	local n = math.clamp(math.floor(dist / 1.6), 6, 36)
	local prev = a
	for i = 1, n do
		local t = i / n
		local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		seg(parent, prev, p, th, color, if glow then NEON else SMOOTH)
		prev = p
	end
end

local function pointLight(p: BasePart, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
	return l
end

local function surfaceLight(p: BasePart, face: Enum.NormalId, color: Color3, range: number, brightness: number): SurfaceLight
	local l = Instance.new("SurfaceLight")
	l.Face = face
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Angle = 120
	l.Shadows = false
	l.Parent = p
	return l
end

local function spin(inst: Instance, speed: number, axis: string)
	inst:AddTag("Spin")
	inst:SetAttribute("Speed", speed)
	inst:SetAttribute("Axis", axis)
	if inst:IsA("Model") then
		inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
end

local function bob(inst: Instance, amp: number, speed: number, rot: number?)
	inst:AddTag("Bob")
	inst:SetAttribute("Amplitude", amp)
	inst:SetAttribute("Speed", speed)
	inst:SetAttribute("Phase", rr(0, PI * 2))
	if rot then
		inst:SetAttribute("Rot", rot)
	end
	if inst:IsA("Model") then
		inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
end

local function blink(p: BasePart, rate: number, duty: number?)
	p:AddTag("Blink")
	p:SetAttribute("Rate", rate)
	p:SetAttribute("Phase", rr(0, 1))
	p:SetAttribute("Duty", duty or 0.5)
end

local LED_COLS = { LIME, LIME, CYAN, CYAN, AMBER, RED, MAG }

local function led(parent: Instance, cf: CFrame, color: Color3?, size: number?): Part
	local s = size or 0.18
	local p = neon(parent, Vector3.new(s, s, 0.08), cf, color or pick(LED_COLS))
	blink(p, rr(0.3, 5), rr(0.25, 0.85))
	return p
end

-- Model with an invisible hub part as PrimaryPart (pivot = cf), for Spin/Bob models.
local function hubModel(parent: Instance, name: string, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = name
	local hub = deco(m, Vector3.new(0.2, 0.2, 0.2), cf, DARK)
	hub.Name = "Hub"
	hub.Transparency = 1
	m.PrimaryPart = hub
	m.Parent = parent
	return m
end

-- Segmented ring lying in the XZ plane of `center`.
local function ring(
	parent: Instance,
	name: string,
	center: CFrame,
	radius: number,
	thick: number,
	width: number,
	segs: number,
	color: Color3,
	biome: boolean,
	gapEvery: number?,
	altColor: Color3?
): Model
	local m = hubModel(parent, name, center)
	local segLen = 2 * radius * math.tan(PI / segs) + 0.04
	for i = 0, segs - 1 do
		if gapEvery and i % gapEvery == 0 then
			continue
		end
		local a = i / segs * PI * 2
		local cf = center * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		if altColor and i % 2 == 1 then
			deco(m, Vector3.new(segLen, thick * 1.4, width * 1.1), cf, altColor, METALM)
		else
			neon(m, Vector3.new(segLen, thick, width), cf, color, biome)
		end
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- GUI helpers
---------------------------------------------------------------------------------------------------

local function surfaceGui(p: BasePart, face: Enum.NormalId, pps: number, name: string): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Name = name
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.MaxDistance = 320
	g.ClipsDescendants = true
	g.ResetOnSpawn = false
	g.Parent = p
	return g
end

local function frame(parent: Instance, pos: UDim2, size: UDim2, color: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.Parent = parent
	return f
end

local function label(parent: Instance, str: string, font: Font, size: number, color: Color3, pos: UDim2, sz: UDim2, xAlign: Enum.TextXAlignment?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.FontFace = font
	t.TextSize = size
	t.TextColor3 = color
	t.Text = str
	t.Position = pos
	t.Size = sz
	t.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.Parent = parent
	return t
end

local function hexColor(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local HEXCH = "0123456789ABCDEF"
local function hex(n: number): string
	local out = table.create(n) :: { string }
	for i = 1, n do
		local k = ri(1, 16)
		out[i] = string.sub(HEXCH, k, k)
	end
	return table.concat(out)
end

local WORDS = { "aura", "kernel", "rng", "node", "proxy", "cache", "packet", "shard", "seed", "luck", "glitch", "rig", "core", "sector" }

local CODE_GEN: { () -> string } = {
	function()
		return string.format("0x%s  %s %s %s %s  %s", hex(6), hex(2), hex(2), hex(2), hex(2), hex(8))
	end,
	function()
		return string.format("mov   r%d, 0x%s", ri(0, 15), hex(4))
	end,
	function()
		return string.format("jmp   0x%s    ; %s.%s", hex(6), pick(WORDS), pick(WORDS))
	end,
	function()
		return string.format("%s.roll(luck=%.2f) -> 1/%d", pick(WORDS), rr(1, 9), ri(2, 999999))
	end,
	function()
		return string.format("inject [payload:%s] ......... %d%%", hex(4), ri(0, 100))
	end,
	function()
		return string.format(">> handshake %d.%d.%d.%d OK", ri(10, 255), ri(0, 255), ri(0, 255), ri(1, 254))
	end,
	function()
		return string.format("if rng() == 0x%s then breach() end", hex(3))
	end,
	function()
		return string.format("sys.%s[%d] = 0x%s", pick(WORDS), ri(0, 512), hex(8))
	end,
	function()
		return string.format("[WARN] sector %s unstable", hex(4))
	end,
	function()
		return string.format("decrypt(%s) => %s", hex(6), hex(10))
	end,
	function()
		return string.format("ping %d.%d.%d.%d  %dms", ri(10, 255), ri(0, 255), ri(0, 255), ri(1, 254), ri(1, 300))
	end,
	function()
		return string.format("### NODE_%s ONLINE ###", hex(3))
	end,
	function()
		return string.format("while true do %s.%s() end", pick(WORDS), pick(WORDS))
	end,
	function()
		return string.format("%s :: %s :: %s", hex(4), hex(4), hex(4))
	end,
}

local function codeLine(hi: Color3, alt: Color3): string
	local line = pick(CODE_GEN)()
	local r = rng:NextNumber()
	if r < 0.12 then
		return string.format('<font color="%s">%s</font>', hexColor(alt), line)
	elseif r < 0.3 then
		return string.format('<font color="%s">%s</font>', hexColor(hi), line)
	end
	return line
end

-- Holographic code feed on a part face. Returns the tagged "Scroll" frame.
local function codeScreen(p: BasePart, faceW: number, faceH: number, color: Color3, header: string?, pps: number?): Frame
	local ppsU = pps or math.clamp(math.floor(560 / faceW), 10, 60)
	local g = surfaceGui(p, Enum.NormalId.Front, ppsU, "Holo")
	local W, H = faceW * ppsU, faceH * ppsU
	local bg = frame(g, UDim2.new(), UDim2.fromScale(1, 1), SCREEN_BLACK, 0.05)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(scaleColor(color, 0.16), rgb(0, 0, 0))
	grad.Parent = bg

	local headerH = 0
	if header then
		headerH = math.max(18, math.floor(H * 0.11))
		local bar = frame(bg, UDim2.new(), UDim2.new(1, 0, 0, headerH), scaleColor(color, 0.28), 0)
		frame(bar, UDim2.new(0, 0, 1, -2), UDim2.new(1, 0, 0, 2), color, 0)
		label(bar, header, FONT_PIX, math.floor(headerH * 0.45), color, UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0))
		label(bar, "LIVE", FONT_PIX, math.floor(headerH * 0.35), MAG, UDim2.fromOffset(0, 0), UDim2.new(1, -8, 1, 0), Enum.TextXAlignment.Right)
	end

	local view = frame(bg, UDim2.fromOffset(8, headerH + 4), UDim2.new(1, -16, 1, -headerH - 8), SCREEN_BLACK, 1)
	view.Name = "Scroll"
	view.ClipsDescendants = true
	local viewH = H - headerH - 8
	local textSize = math.clamp(math.floor(W / 34), 9, 22)
	local lines = math.max(4, math.floor(viewH / textSize) + 1)
	local block = table.create(lines) :: { string }
	local alt = if color == MAG then CYAN else MAG
	for i = 1, lines do
		block[i] = codeLine(Color3.new(1, 1, 1), alt)
	end
	local s = table.concat(block, "\n")
	local lbl = label(view, s .. "\n" .. s, FONT_MONO, textSize, color, UDim2.new(), UDim2.new(1, 0, 0, lines * textSize * 2))
	lbl.Name = "Code"
	lbl.RichText = true
	lbl.LineHeight = 1
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	lbl.TextTransparency = 0.05
	view:SetAttribute("BlockHeight", lines * textSize)
	view:SetAttribute("Speed", rr(14, 38))
	view:AddTag("Scroll")

	-- scanlines + corner brackets
	local step = math.max(6, math.floor(H / 24))
	for y = 0, H, step do
		frame(bg, UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 1), rgb(0, 0, 0), 0.55)
	end
	local bl = math.floor(math.min(W, H) * 0.08)
	for _, c in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local fx = frame(bg, UDim2.new(c.X, if c.X == 1 then -bl - 3 else 3, c.Y, if c.Y == 1 then -5 else 3), UDim2.fromOffset(bl, 2), color, 0)
		fx.ZIndex = 3
		local fy = frame(bg, UDim2.new(c.X, if c.X == 1 then -5 else 3, c.Y, if c.Y == 1 then -bl - 3 else 3), UDim2.fromOffset(2, bl), color, 0)
		fy.ZIndex = 3
	end
	return view
end

---------------------------------------------------------------------------------------------------
-- Glyphs / signs (abstract symbols only, no readable words)
---------------------------------------------------------------------------------------------------

-- {x, y, w, h} in a unit cell centred on 0.
local GLYPH_STROKES: { { number } } = {
	{ 0, 0.4, 1, 0.13 },
	{ 0, 0, 1, 0.13 },
	{ 0, -0.4, 1, 0.13 },
	{ -0.25, 0.4, 0.5, 0.13 },
	{ 0.25, -0.4, 0.5, 0.13 },
	{ 0.25, 0, 0.5, 0.13 },
	{ -0.25, 0, 0.5, 0.13 },
	{ 0, 0.2, 0.7, 0.13 },
	{ -0.4, 0, 0.13, 1 },
	{ 0, 0, 0.13, 1 },
	{ 0.4, 0, 0.13, 1 },
	{ 0, 0.25, 0.13, 0.5 },
	{ -0.4, -0.25, 0.13, 0.5 },
	{ 0.4, 0.25, 0.13, 0.5 },
	{ 0.2, -0.2, 0.13, 0.6 },
	{ 0.28, 0.28, 0.17, 0.17 },
	{ -0.28, -0.28, 0.17, 0.17 },
}

local function glyph(parent: Instance, cf: CFrame, size: number, color: Color3, biome: boolean)
	local used = {} :: { [number]: boolean }
	local n = ri(3, 5)
	local hasV, hasH = false, false
	local tries = 0
	while (n > 0 or not (hasV and hasH)) and tries < 20 do
		tries += 1
		local k = ri(1, #GLYPH_STROKES)
		if used[k] then
			continue
		end
		used[k] = true
		local s = GLYPH_STROKES[k]
		if s[4] > s[3] then
			hasV = true
		else
			hasH = true
		end
		neon(parent, Vector3.new(s[3] * size, s[4] * size, 0.14), cf * CFrame.new(s[1] * size, s[2] * size, 0), color, biome)
		n -= 1
	end
end

-- Vertical neon sign; cf = centre, glyphs face cf.LookVector (and the back).
local function verticalSign(parent: Instance, cf: CFrame, cells: number, cellSize: number, color: Color3, frameColor: Color3): Model
	local m = model(parent, "VSign")
	local w = cellSize * 1.55
	local h = cells * cellSize * 1.3 + cellSize * 0.5
	local depth = 0.7
	box(m, Vector3.new(w, h, depth), cf, rgb(8, 8, 12), SMOOTH).CastShadow = false
	-- double outline on both faces
	for _, side in { -1, 1 } do
		local z = side * (depth / 2 + 0.06)
		neon(m, Vector3.new(w + 0.1, 0.16, 0.12), cf * CFrame.new(0, h / 2, z), frameColor, true)
		neon(m, Vector3.new(w + 0.1, 0.16, 0.12), cf * CFrame.new(0, -h / 2, z), frameColor, true)
		neon(m, Vector3.new(0.16, h, 0.12), cf * CFrame.new(w / 2, 0, z), frameColor, true)
		neon(m, Vector3.new(0.16, h, 0.12), cf * CFrame.new(-w / 2, 0, z), frameColor, true)
		local inset = cellSize * 0.12
		deco(m, Vector3.new(w - inset * 2, 0.06, 0.06), cf * CFrame.new(0, h / 2 - inset, z), scaleColor(frameColor, 0.45), NEON)
		deco(m, Vector3.new(w - inset * 2, 0.06, 0.06), cf * CFrame.new(0, -h / 2 + inset, z), scaleColor(frameColor, 0.45), NEON)
		local faceCF = if side < 0 then cf else cf * CFrame.Angles(0, PI, 0)
		for i = 1, cells do
			local y = h / 2 - cellSize * 0.25 - (i - 0.5) * cellSize * 1.3
			glyph(m, faceCF * CFrame.new(0, y, -(depth / 2 + 0.08)), cellSize * 0.82, color, false)
			if i < cells then
				deco(m, Vector3.new(cellSize * 0.2, 0.06, 0.06), faceCF * CFrame.new(0, y - cellSize * 0.65, -(depth / 2 + 0.06)), scaleColor(color, 0.5), NEON)
			end
		end
	end
	-- caps + mounting
	deco(m, Vector3.new(w + 0.4, 0.3, depth + 0.3), cf * CFrame.new(0, h / 2 + 0.15, 0), METAL2, METALM)
	deco(m, Vector3.new(w + 0.4, 0.3, depth + 0.3), cf * CFrame.new(0, -h / 2 - 0.15, 0), METAL2, METALM)
	local glow = deco(m, Vector3.new(0.2, 0.2, 0.2), cf, color)
	glow.Transparency = 1
	pointLight(glow, color, math.min(4 + h, 22), 1.4)
	return m
end

---------------------------------------------------------------------------------------------------
-- Props
---------------------------------------------------------------------------------------------------

local function fan(parent: Instance, cf: CFrame, d: number, speed: number)
	local m = hubModel(parent, "Fan", cf)
	cylY(m, 0.3, d * 0.22, cf, METAL3, METALM).CanCollide = false
	local blades = 5
	for i = 1, blades do
		local a = i / blades * PI * 2
		local b = deco(m, Vector3.new(d * 0.4, 0.06, d * 0.14), cf * CFrame.Angles(0, a, 0) * CFrame.new(d * 0.24, 0, 0) * CFrame.Angles(0.35, 0, 0), METAL2, METALM)
		b.Name = "Blade"
	end
	spin(m, speed, "Y")
end

local function acUnit(parent: Instance, cf: CFrame)
	local m = model(parent, "ACUnit")
	local body = box(m, Vector3.new(4, 2.6, 3), cf * CFrame.new(0, 1.5, 0), rgb(46, 49, 62), METALM)
	body.CastShadow = false
	for i = 0, 6 do
		deco(m, Vector3.new(3.5, 0.1, 0.12), cf * CFrame.new(0, 0.55 + i * 0.3, -1.52), rgb(20, 21, 28), METALM)
	end
	-- top fan well
	local well = cylY(m, 0.2, 2.5, cf * CFrame.new(0.5, 2.82, 0.2), RUBBER, METALM)
	makeDecor(well)
	ring(m, "FanRim", cf * CFrame.new(0.5, 2.94, 0.2), 1.25, 0.12, 0.14, 20, METAL3, false)
	fan(m, cf * CFrame.new(0.5, 3.0, 0.2), 2.3, rr(260, 520))
	-- feet, pipes, status LED
	deco(m, Vector3.new(0.4, 0.2, 3.2), cf * CFrame.new(-1.6, 0.1, 0), RUBBER)
	deco(m, Vector3.new(0.4, 0.2, 3.2), cf * CFrame.new(1.6, 0.1, 0), RUBBER)
	cyl(m, 1.4, 0.25, cf * CFrame.new(2.6, 1.2, 0.6), rgb(90, 80, 70), METALM).CanCollide = false
	cyl(m, 1.4, 0.25, cf * CFrame.new(2.6, 0.8, 0.9), rgb(90, 80, 70), METALM).CanCollide = false
	led(m, cf * CFrame.new(-1.6, 2.4, -1.54), LIME, 0.16)
	deco(m, Vector3.new(0.9, 0.35, 0.06), cf * CFrame.new(-1.1, 2.4, -1.53), rgb(14, 14, 18))
end

local function antenna(parent: Instance, base: Vector3, h: number)
	local m = model(parent, "Antenna")
	local cf = CFrame.new(base)
	cylY(m, h, 0.28, cf * CFrame.new(0, h / 2, 0), METAL3, METALM).CastShadow = false
	cylY(m, 0.5, 1, cf * CFrame.new(0, 0.25, 0), METAL2, METALM)
	for k = 1, ri(2, 4) do
		local y = h * (0.35 + k * 0.15)
		local len = rr(1, 2.6)
		local rot = CFrame.Angles(0, rr(0, PI), 0)
		deco(m, Vector3.new(len, 0.1, 0.1), cf * CFrame.new(0, y, 0) * rot, METAL3, METALM)
		deco(m, Vector3.new(0.1, 0.5, 0.1), cf * CFrame.new(0, y, 0) * rot * CFrame.new(len / 2, 0.2, 0), METAL3, METALM)
	end
	for i = 0, 2 do
		local a = i / 3 * PI * 2
		seg(m, base + Vector3.new(0, h * 0.7, 0), base + Vector3.new(math.cos(a) * h * 0.3, 0.1, math.sin(a) * h * 0.3), 0.05, METAL2)
	end
	local tip = ball(m, 0.45, cf * CFrame.new(0, h + 0.2, 0), RED, NEON)
	blink(tip, rr(0.6, 1.1), 0.25)
end

local function dish(parent: Instance, cf: CFrame, d: number)
	local m = model(parent, "Dish")
	cylY(m, 1.6, 0.9, cf * CFrame.new(0, 0.8, 0), METAL2, METALM)
	box(m, Vector3.new(1.4, 0.5, 1.4), cf * CFrame.new(0, 0.25, 0), METAL, METALM)
	local yoke = cf * CFrame.new(0, 1.8 + d * 0.15, 0)
	deco(m, Vector3.new(0.3, d * 0.3, 0.3), yoke * CFrame.new(-0.5, 0, 0), METAL3, METALM)
	deco(m, Vector3.new(0.3, d * 0.3, 0.3), yoke * CFrame.new(0.5, 0, 0), METAL3, METALM)
	local dcf = yoke * CFrame.new(0, d * 0.15, 0) * CFrame.Angles(math.rad(rr(30, 55)), 0, 0)
	local discCF = dcf * CFrame.Angles(0, PI / 2, 0)
	cyl(m, 0.25, d, discCF, rgb(150, 155, 170), SMOOTH).CastShadow = false
	cyl(m, 0.22, d * 0.72, discCF * CFrame.new(0.12, 0, 0), rgb(120, 124, 138), SMOOTH).CanCollide = false
	cyl(m, 0.2, d * 0.4, discCF * CFrame.new(0.2, 0, 0), rgb(100, 104, 118), SMOOTH).CanCollide = false
	ring(m, "Rim", dcf * CFrame.Angles(PI / 2, 0, 0), d / 2, 0.18, 0.2, 28, METAL3, false)
	local focal = (dcf * CFrame.new(0, 0, -d * 0.5)).Position
	for i = 0, 2 do
		local a = i / 3 * PI * 2
		local rimP = (dcf * CFrame.new(math.cos(a) * d * 0.45, math.sin(a) * d * 0.45, -0.1)).Position
		seg(m, rimP, focal, 0.1, METAL3, METALM)
	end
	deco(m, Vector3.new(0.5, 0.5, 0.7), CFrame.lookAt(focal, dcf.Position), METAL2, METALM)
	led(m, CFrame.lookAt(focal, dcf.Position) * CFrame.new(0, 0.3, 0), RED, 0.15)
end

local function streetLamp(parent: Instance, pos: Vector3, facing: Vector3, color: Color3)
	local m = model(parent, "StreetLamp")
	local cf = CFrame.lookAt(pos, pos + Vector3.new(facing.X, 0, facing.Z))
	cylY(m, 0.8, 1.6, cf * CFrame.new(0, 0.4, 0), METAL, METALM)
	ring(m, "BaseGlow", cf * CFrame.new(0, 0.84, 0), 0.75, 0.06, 0.12, 16, color, true)
	cylY(m, 14, 0.5, cf * CFrame.new(0, 7.8, 0), METAL2, METALM)
	cylY(m, 0.4, 0.75, cf * CFrame.new(0, 4, 0), METAL3, METALM).CanCollide = false
	cylY(m, 0.4, 0.75, cf * CFrame.new(0, 10, 0), METAL3, METALM).CanCollide = false
	-- vertical accent strip on the pole
	neon(m, Vector3.new(0.12, 5.5, 0.12), cf * CFrame.new(0, 7, -0.27), color, true)
	-- arm + head
	deco(m, Vector3.new(0.35, 0.35, 4.2), cf * CFrame.new(0, 14.6, -2), METAL2, METALM)
	seg(m, (cf * CFrame.new(0, 13, 0)).Position, (cf * CFrame.new(0, 14.5, -2.4)).Position, 0.18, METAL2, METALM)
	local head = deco(m, Vector3.new(1.6, 0.55, 3.2), cf * CFrame.new(0, 14.6, -4.4), METAL, METALM)
	local under = neon(m, Vector3.new(1.3, 0.12, 2.8), cf * CFrame.new(0, 14.28, -4.4), color, true)
	neon(m, Vector3.new(1.65, 0.1, 0.1), cf * CFrame.new(0, 14.9, -6.0), color, true)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Color = color
	spot.Range = 30
	spot.Angle = 110
	spot.Brightness = 2.2
	spot.Shadows = false
	spot.Parent = under
	makeDecor(head)
	-- little camera box on the pole
	deco(m, Vector3.new(0.5, 0.45, 0.9), cf * CFrame.new(0.4, 12, -0.3), METAL3, METALM)
	led(m, cf * CFrame.new(0.4, 12.1, -0.76), RED, 0.1)
end

local function bench(parent: Instance, cf: CFrame, accent: Color3)
	local m = model(parent, "Bench")
	for _, sx in { -2.4, 2.4 } do
		box(m, Vector3.new(0.4, 1.6, 2.2), cf * CFrame.new(sx, 0.8, 0), METAL2, METALM)
		deco(m, Vector3.new(0.4, 2.4, 0.3), cf * CFrame.new(sx, 2.0, 0.95) * CFrame.Angles(-0.2, 0, 0), METAL2, METALM)
	end
	for i = 0, 4 do
		deco(m, Vector3.new(5.4, 0.15, 0.36), cf * CFrame.new(0, 1.65, -0.8 + i * 0.4), rgb(28, 30, 40), METALM)
	end
	for i = 0, 2 do
		deco(m, Vector3.new(5.4, 0.36, 0.12), cf * CFrame.new(0, 2.2 + i * 0.45, 0.95 + i * 0.09) * CFrame.Angles(-0.2, 0, 0), rgb(28, 30, 40), METALM)
	end
	-- Two invisible seats so two players can sit (sitter faces cf.LookVector, back to the backrest).
	for _, sx in { -1.3, 1.3 } do
		local seat = Instance.new("Seat")
		setup(seat, m, Vector3.new(2.4, 0.2, 1.8), cf * CFrame.new(sx, 1.55, 0), rgb(18, 19, 26), METALM)
		seat.Transparency = 1
	end
	neon(m, Vector3.new(4.6, 0.08, 0.08), cf * CFrame.new(0, 1.38, -0.9), accent, true)
	deco(m, Vector3.new(4.6, 0.04, 1.6), cf * CFrame.new(0, 0.03, 0), scaleColor(accent, 0.12), NEON)
end

local PRODUCT_COLS = { CYAN, MAG, RED, LIME, AMBER, rgb(120, 140, 255), rgb(255, 255, 255) }

local function vendingMachine(parent: Instance, cf: CFrame, accent: Color3)
	local m = model(parent, "Vending")
	box(m, Vector3.new(3.4, 7.2, 2.6), cf * CFrame.new(0, 3.6, 0), rgb(18, 19, 28), METALM)
	-- display window
	local glassCF = cf * CFrame.new(-0.35, 4.1, -1.32)
	local glass = deco(m, Vector3.new(2.3, 4.6, 0.1), glassCF, rgb(20, 30, 45), GLASS)
	glass.Transparency = 0.55
	glass.Reflectance = 0.2
	deco(m, Vector3.new(2.2, 4.5, 0.05), cf * CFrame.new(-0.35, 4.1, -1.2), rgb(6, 8, 14), SMOOTH)
	for row = 0, 4 do
		local y = 2.2 + row * 0.92
		deco(m, Vector3.new(2.2, 0.06, 0.5), cf * CFrame.new(-0.35, y - 0.32, -1.0), METAL3, METALM)
		for col = 0, 3 do
			local c = pick(PRODUCT_COLS)
			local p = deco(m, Vector3.new(0.34, 0.55, 0.3), cf * CFrame.new(-1.15 + col * 0.53, y, -1.05), c, if chance(0.4) then NEON else SMOOTH)
			if p.Material == NEON then
				p.Color = scaleColor(c, 0.55)
			end
		end
	end
	-- frame glow
	neon(m, Vector3.new(2.5, 0.12, 0.14), cf * CFrame.new(-0.35, 6.45, -1.32), accent, true)
	neon(m, Vector3.new(2.5, 0.12, 0.14), cf * CFrame.new(-0.35, 1.75, -1.32), accent, true)
	neon(m, Vector3.new(0.12, 4.8, 0.14), cf * CFrame.new(-1.55, 4.1, -1.32), accent, true)
	neon(m, Vector3.new(0.12, 4.8, 0.14), cf * CFrame.new(0.85, 4.1, -1.32), accent, true)
	-- control column
	deco(m, Vector3.new(0.7, 1.0, 0.08), cf * CFrame.new(1.25, 5.4, -1.32), rgb(5, 10, 14), SMOOTH)
	neon(m, Vector3.new(0.6, 0.18, 0.06), cf * CFrame.new(1.25, 5.65, -1.36), scaleColor(LIME, 0.7))
	for i = 0, 3 do
		for j = 0, 1 do
			deco(m, Vector3.new(0.18, 0.18, 0.1), cf * CFrame.new(1.12 + j * 0.26, 4.6 - i * 0.28, -1.34), METAL3, METALM)
		end
	end
	led(m, cf * CFrame.new(1.25, 3.4, -1.34), RED, 0.12)
	deco(m, Vector3.new(0.4, 0.12, 0.08), cf * CFrame.new(1.25, 3.1, -1.34), rgb(0, 0, 0))
	-- pickup bay
	deco(m, Vector3.new(2.3, 0.9, 0.1), cf * CFrame.new(-0.35, 1.0, -1.32), rgb(4, 4, 6))
	deco(m, Vector3.new(2.4, 0.12, 0.2), cf * CFrame.new(-0.35, 1.5, -1.38), METAL3, METALM)
	-- top light box with glyph strip
	local topBox = deco(m, Vector3.new(3.4, 0.9, 0.2), cf * CFrame.new(0, 6.95, -1.38), scaleColor(accent, 0.25), NEON)
	topBox.Name = "TopBox"
	for i = 0, 3 do
		glyph(m, cf * CFrame.new(-1.2 + i * 0.8, 6.95, -1.5), 0.6, rgb(240, 240, 255), false)
	end
	local l = pointLight(topBox, accent, 10, 1.3)
	l.Shadows = false
	-- feet
	deco(m, Vector3.new(3.5, 0.15, 2.7), cf * CFrame.new(0, 0.07, 0), RUBBER)
end

local function crate(parent: Instance, cf: CFrame, s: Vector3, color: Color3)
	local m = model(parent, "Crate")
	box(m, s, cf, color, METALM)
	local e = 0.18
	local hx, hy, hz = s.X / 2, s.Y / 2, s.Z / 2
	local edgeCol = METAL3
	for _, y in { -hy, hy } do
		for _, z in { -hz, hz } do
			deco(m, Vector3.new(s.X + e, e, e), cf * CFrame.new(0, y, z), edgeCol, METALM)
		end
		for _, x in { -hx, hx } do
			deco(m, Vector3.new(e, e, s.Z + e), cf * CFrame.new(x, y, 0), edgeCol, METALM)
		end
	end
	for _, x in { -hx, hx } do
		for _, z in { -hz, hz } do
			deco(m, Vector3.new(e, s.Y + e, e), cf * CFrame.new(x, 0, z), edgeCol, METALM)
		end
	end
	-- stencil stripe + id tag
	deco(m, Vector3.new(s.X * 0.6, 0.12, 0.05), cf * CFrame.new(0, hy * 0.4, -hz - 0.03), AMBER, SMOOTH)
	neon(m, Vector3.new(s.X * 0.3, 0.1, 0.05), cf * CFrame.new(-s.X * 0.15, -hy * 0.3, -hz - 0.03), pick({ CYAN, MAG, RED }))
end

local function crateStack(parent: Instance, base: CFrame)
	local cols = { rgb(28, 30, 40), rgb(34, 30, 38), rgb(22, 28, 34) }
	local n = ri(2, 5)
	for i = 1, n do
		local s = Vector3.new(rr(2.6, 4), rr(2, 3.2), rr(2.6, 4))
		local y = s.Y / 2
		local cf = base * CFrame.new(rr(-2.5, 2.5), y, rr(-2.5, 2.5)) * CFrame.Angles(0, rr(-0.3, 0.3), 0)
		crate(parent, cf, s, pick(cols))
		if i <= 2 and chance(0.6) then
			local s2 = Vector3.new(s.X * 0.8, rr(1.6, 2.4), s.Z * 0.8)
			crate(parent, cf * CFrame.new(0, s.Y / 2 + s2.Y / 2, 0) * CFrame.Angles(0, rr(-0.4, 0.4), 0), s2, pick(cols))
		end
	end
end

local function barrier(parent: Instance, cf: CFrame)
	local m = model(parent, "Barrier")
	local col = rgb(40, 42, 50)
	box(m, Vector3.new(6, 0.9, 2.2), cf * CFrame.new(0, 0.45, 0), col, CONCRETE)
	wedge(m, Vector3.new(6, 1.4, 0.7), cf * CFrame.new(0, 1.6, -0.55), col, CONCRETE)
	wedge(m, Vector3.new(6, 1.4, 0.7), cf * CFrame.new(0, 1.6, 0.55) * CFrame.Angles(0, PI, 0), col, CONCRETE)
	box(m, Vector3.new(6, 1.4, 0.4), cf * CFrame.new(0, 1.6, 0), col, CONCRETE)
	-- hazard stripes
	for i = -2, 2 do
		deco(m, Vector3.new(0.5, 0.75, 0.05), cf * CFrame.new(i * 1.2, 0.5, -1.13) * CFrame.Angles(0, 0, 0.6), AMBER, SMOOTH)
	end
	neon(m, Vector3.new(5.8, 0.12, 0.1), cf * CFrame.new(0, 2.32, 0), RED, true)
	local beacon = deco(m, Vector3.new(0.4, 0.35, 0.4), cf * CFrame.new(2.4, 2.5, 0), RED, NEON)
	blink(beacon, rr(0.8, 1.4), 0.35)
end

local function pipeRun(parent: Instance, a: Vector3, b: Vector3, d: number, color: Color3)
	local m = model(parent, "Pipe")
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, PI / 2, 0)
	cyl(m, len, d, cf, color, METALM).CastShadow = false
	local n = math.floor(len / 6)
	for i = 0, n do
		local t = if n == 0 then 0.5 else i / n
		local p = a:Lerp(b, t)
		local fcf = CFrame.lookAt(p, b) * CFrame.Angles(0, PI / 2, 0)
		cyl(m, 0.3, d * 1.35, fcf, METAL3, METALM).CanCollide = false
	end
	if len > 10 and chance(0.6) then
		local p = a:Lerp(b, rr(0.25, 0.75))
		local vcf = CFrame.lookAt(p, b)
		ring(m, "Valve", vcf * CFrame.new(0, d * 0.5 + 0.6, 0) * CFrame.Angles(0, 0, PI / 2) * CFrame.Angles(0, 0, 0), 0.5, 0.12, 0.12, 12, RED, false)
		deco(m, Vector3.new(0.15, 0.6, 0.15), vcf * CFrame.new(0, d * 0.5 + 0.3, 0), METAL3, METALM)
	end
end

local function vent(parent: Instance, cf: CFrame, w: number, h: number)
	local m = model(parent, "Vent")
	deco(m, Vector3.new(w + 0.3, h + 0.3, 0.15), cf, METAL3, METALM)
	local slats = math.max(3, math.floor(h / 0.35))
	for i = 0, slats - 1 do
		local y = -h / 2 + (i + 0.5) * h / slats
		deco(m, Vector3.new(w, 0.08, 0.2), cf * CFrame.new(0, y, -0.1) * CFrame.Angles(0.5, 0, 0), RUBBER, METALM)
	end
end

local function steamVent(parent: Instance, cf: CFrame)
	local m = model(parent, "FloorVent")
	local p = deco(m, Vector3.new(2.6, 0.08, 2.6), cf * CFrame.new(0, 0.04, 0), METAL2, METALM)
	for i = -2, 2 do
		deco(m, Vector3.new(2.3, 0.06, 0.18), cf * CFrame.new(0, 0.1, i * 0.45), RUBBER, METALM)
	end
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = TEX .. "smoke_main.dds"
	pe.Rate = 4
	pe.Lifetime = NumberRange.new(3, 5)
	pe.Speed = NumberRange.new(2, 4)
	pe.SpreadAngle = Vector2.new(12, 12)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.86), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(rgb(120, 110, 150))
	pe.RotSpeed = NumberRange.new(-20, 20)
	pe.Rotation = NumberRange.new(0, 360)
	pe.Drag = 1
	pe.Acceleration = Vector3.new(0.6, 0.4, 0)
	pe.LightInfluence = 0.6
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Parent = p
end

local function cyberTree(parent: Instance, cf: CFrame, color: Color3)
	local m = model(parent, "Planter")
	box(m, Vector3.new(4.2, 1.4, 4.2), cf * CFrame.new(0, 0.7, 0), METAL, CONCRETE)
	deco(m, Vector3.new(3.6, 0.1, 3.6), cf * CFrame.new(0, 1.42, 0), rgb(10, 14, 12), SMOOTH)
	neon(m, Vector3.new(4.25, 0.1, 4.25), cf * CFrame.new(0, 1.2, 0), color, true).Transparency = 0.2
	cylY(m, 5.5, 0.4, cf * CFrame.new(0, 4.2, 0), rgb(30, 28, 34), METALM)
	-- light-fibre branches
	for i = 1, 9 do
		local a = i / 9 * PI * 2 + rr(-0.2, 0.2)
		local top = (cf * CFrame.new(0, 6.6, 0)).Position
		local tip = top + Vector3.new(math.cos(a) * rr(1.6, 2.8), rr(0.6, 2.2), math.sin(a) * rr(1.6, 2.8))
		seg(m, top, tip, 0.08, scaleColor(color, rr(0.5, 1)), NEON)
		ball(m, 0.3, CFrame.new(tip), color, NEON)
	end
	local glow = ball(m, 0.6, cf * CFrame.new(0, 6.7, 0), color, NEON)
	pointLight(glow, color, 10, 1)
end

local function bollard(parent: Instance, cf: CFrame, color: Color3)
	local m = model(parent, "Bollard")
	cylY(m, 1.6, 0.6, cf * CFrame.new(0, 0.8, 0), METAL2, METALM)
	local band = cylY(m, 0.22, 0.64, cf * CFrame.new(0, 1.3, 0), color, NEON)
	makeDecor(band)
	tagBiome(band)
	cylY(m, 0.15, 0.7, cf * CFrame.new(0, 1.65, 0), METAL3, METALM).CanCollide = false
end

local function holoBoard(parent: Instance, cf: CFrame, w: number, h: number, color: Color3, header: string?): Model
	local m = model(parent, "HoloBoard")
	box(m, Vector3.new(w + 1.2, h + 1.2, 0.8), cf * CFrame.new(0, 0, 0.5), METAL, METALM).CastShadow = false
	local screen = deco(m, Vector3.new(w, h, 0.2), cf, SCREEN_BLACK, SMOOTH)
	screen.Name = "Screen"
	neon(m, Vector3.new(w + 1.3, 0.22, 0.3), cf * CFrame.new(0, h / 2 + 0.55, -0.05), color, true)
	neon(m, Vector3.new(w + 1.3, 0.22, 0.3), cf * CFrame.new(0, -h / 2 - 0.55, -0.05), color, true)
	neon(m, Vector3.new(0.22, h + 1.3, 0.3), cf * CFrame.new(w / 2 + 0.55, 0, -0.05), color, true)
	neon(m, Vector3.new(0.22, h + 1.3, 0.3), cf * CFrame.new(-w / 2 - 0.55, 0, -0.05), color, true)
	-- corner brackets
	local alt = if color == MAG then CYAN else MAG
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			local c = cf * CFrame.new(sx * (w / 2 + 0.9), sy * (h / 2 + 0.9), -0.2)
			deco(m, Vector3.new(1.6, 0.3, 0.3), c * CFrame.new(-sx * 0.65, 0, 0), alt, NEON)
			deco(m, Vector3.new(0.3, 1.6, 0.3), c * CFrame.new(0, -sy * 0.65, 0), alt, NEON)
		end
	end
	codeScreen(screen, w, h, color, header)
	surfaceLight(screen, Enum.NormalId.Front, color, math.min(10 + w * 0.5, 24), 0.9)
	return m
end

local function freeBoard(parent: Instance, base: CFrame, w: number, h: number, color: Color3, header: string)
	local m = model(parent, "BillboardPost")
	local postH = 12
	for _, sx in { -w * 0.3, w * 0.3 } do
		box(m, Vector3.new(0.9, postH, 0.9), base * CFrame.new(sx, postH / 2, 0.6), METAL2, METALM)
		box(m, Vector3.new(2, 0.6, 2), base * CFrame.new(sx, 0.3, 0.6), METAL, CONCRETE)
		neon(m, Vector3.new(0.12, postH - 2, 0.12), base * CFrame.new(sx, postH / 2, 0.14), color, true)
	end
	-- catwalk under the board
	deco(m, Vector3.new(w + 2, 0.2, 1.8), base * CFrame.new(0, postH - 0.2, -0.6), METAL2, DIAMOND)
	for i = 0, 6 do
		local x = -w / 2 - 1 + i * (w + 2) / 6
		deco(m, Vector3.new(0.1, 1.2, 0.1), base * CFrame.new(x, postH + 0.4, -1.45), METAL3, METALM)
	end
	deco(m, Vector3.new(w + 2, 0.1, 0.1), base * CFrame.new(0, postH + 1, -1.45), METAL3, METALM)
	holoBoard(m, base * CFrame.new(0, postH + h / 2 + 0.8, 0), w, h, color, header)
	-- spot lights aimed at board
	for _, sx in { -w * 0.35, w * 0.35 } do
		local lp = deco(m, Vector3.new(0.6, 0.6, 0.9), base * CFrame.new(sx, postH, -1.3) * CFrame.Angles(math.rad(50), 0, 0), METAL3, METALM)
		neon(m, Vector3.new(0.45, 0.45, 0.06), lp.CFrame * CFrame.new(0, 0, -0.46), rgb(220, 230, 255))
	end
	-- cable bundle down a post
	cable(m, (base * CFrame.new(w * 0.3, postH, 1.2)).Position, (base * CFrame.new(w * 0.3 + 3, 0.1, 3)).Position, 1.2, 0.18, RUBBER)
	cable(m, (base * CFrame.new(w * 0.3 - 0.3, postH, 1.2)).Position, (base * CFrame.new(w * 0.3 + 2.4, 0.1, 3.5)).Position, 1.5, 0.12, scaleColor(MAG, 0.6), true)
end

---------------------------------------------------------------------------------------------------
-- Server rack
---------------------------------------------------------------------------------------------------

local function serverRack(parent: Instance, cf: CFrame, accent: Color3)
	local m = model(parent, "ServerRack")
	box(m, Vector3.new(4, 9, 3), cf * CFrame.new(0, 4.6, 0), rgb(14, 15, 22), METALM)
	box(m, Vector3.new(4.3, 0.2, 3.3), cf * CFrame.new(0, 0.1, 0), RUBBER, METALM)
	for _, x in { -2.02, 2.02 } do
		for _, z in { -1.52, 1.52 } do
			deco(m, Vector3.new(0.25, 9.3, 0.25), cf * CFrame.new(x, 4.65, z), METAL2, METALM)
		end
	end
	-- blades
	for i = 0, 7 do
		local y = 0.9 + i * 1.04
		local bcf = cf * CFrame.new(0, y, -1.55)
		deco(m, Vector3.new(3.5, 0.9, 0.12), bcf, if i % 3 == 0 then rgb(30, 32, 44) else rgb(22, 24, 34), METALM)
		local kind = i % 4
		if kind == 0 then
			for k = 0, 5 do
				deco(m, Vector3.new(0.45, 0.6, 0.06), bcf * CFrame.new(-1.45 + k * 0.5, 0, -0.08), rgb(10, 10, 14), SMOOTH)
				led(m, bcf * CFrame.new(-1.45 + k * 0.5, -0.22, -0.13), nil, 0.08)
			end
		elseif kind == 1 then
			for k = 0, 7 do
				deco(m, Vector3.new(0.06, 0.6, 0.06), bcf * CFrame.new(-0.6 + k * 0.17, 0, -0.08), rgb(6, 6, 8), SMOOTH)
			end
			for k = 0, 3 do
				led(m, bcf * CFrame.new(-1.5 + k * 0.22, 0.2, -0.1))
			end
			led(m, bcf * CFrame.new(1.4, 0.2, -0.1), LIME, 0.14)
		elseif kind == 2 then
			deco(m, Vector3.new(1.6, 0.5, 0.05), bcf * CFrame.new(-0.6, 0, -0.08), rgb(4, 8, 10), SMOOTH)
			neon(m, Vector3.new(rr(0.3, 1.5), 0.12, 0.04), bcf * CFrame.new(-1.2, 0.08, -0.12), scaleColor(accent, 0.8)).Name = "Meter"
			for k = 0, 2 do
				led(m, bcf * CFrame.new(0.7 + k * 0.3, 0, -0.1), nil, 0.14)
			end
		else
			for k = 0, 11 do
				local p = led(m, bcf * CFrame.new(-1.55 + k * 0.28, -0.15, -0.1), nil, 0.12)
				p:SetAttribute("Rate", rr(2, 9))
			end
			deco(m, Vector3.new(3.2, 0.06, 0.04), bcf * CFrame.new(0, 0.2, -0.08), METAL3, METALM)
		end
	end
	-- side vents
	for _, sx in { -2.05, 2.05 } do
		for k = 0, 9 do
			deco(m, Vector3.new(0.05, 0.12, 2.2), cf * CFrame.new(sx, 2 + k * 0.6, 0), RUBBER, METALM)
		end
	end
	-- top status bar + crown
	neon(m, Vector3.new(4.05, 0.14, 0.14), cf * CFrame.new(0, 9.12, -1.52), accent, true)
	deco(m, Vector3.new(4, 0.3, 3), cf * CFrame.new(0, 9.3, 0), METAL2, METALM)
	fan(m, cf * CFrame.new(-0.9, 9.5, 0.4), 1.2, rr(400, 700))
	fan(m, cf * CFrame.new(0.9, 9.5, 0.4), 1.2, rr(400, 700))
	-- rear cables dropping to the floor
	for k = 0, 2 do
		local a = (cf * CFrame.new(-1 + k, 8.5, 1.6)).Position
		local b = (cf * CFrame.new(-1.2 + k * 1.2, 0.1, 3.4 + k * 0.3)).Position
		cable(m, a, b, 0.8, 0.12, if k == 1 then scaleColor(accent, 0.7) else RUBBER, k == 1)
	end
	local g = deco(m, Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, 5, -2.4), accent)
	g.Transparency = 1
	pointLight(g, accent, 8, 0.8)
end

local function cableTray(parent: Instance, a: Vector3, b: Vector3)
	local m = model(parent, "CableTray")
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	deco(m, Vector3.new(2, 0.12, len), cf, METAL3, METALM)
	deco(m, Vector3.new(0.12, 0.5, len), cf * CFrame.new(-1, 0.25, 0), METAL3, METALM)
	deco(m, Vector3.new(0.12, 0.5, len), cf * CFrame.new(1, 0.25, 0), METAL3, METALM)
	for k = 0, 4 do
		deco(m, Vector3.new(0.3, 0.3, len), cf * CFrame.new(-0.7 + k * 0.35, 0.21, 0), if k == 2 then scaleColor(CYAN, 0.6) else RUBBER, if k == 2 then NEON else SMOOTH)
	end
	for i = 0, math.floor(len / 6) do
		local p = cf * CFrame.new(0, 0, -len / 2 + i * 6)
		deco(m, Vector3.new(2.3, 0.15, 0.25), p * CFrame.new(0, -0.1, 0), METAL2, METALM)
	end
end

---------------------------------------------------------------------------------------------------
-- Floor
---------------------------------------------------------------------------------------------------

local function chevron(parent: Instance, cf: CFrame, size: number, color: Color3)
	-- ">" pointing along cf.LookVector, flat on the floor
	for _, s in { -1, 1 } do
		local arm = cf * CFrame.Angles(0, s * math.rad(40), 0) * CFrame.new(0, 0, size * 0.35)
		neon(parent, Vector3.new(size * 0.16, 0.04, size * 0.75), arm, color, true)
	end
end

local function pathMarkings(parent: Instance, from: Vector3, to: Vector3, color: Color3)
	local m = model(parent, "PathMarks")
	local dir = (to - from) * Vector3.new(1, 0, 1)
	local len = dir.Magnitude
	local base = CFrame.lookAt(from, from + dir)
	local d = 8
	while d < len - 14 do
		chevron(m, base * CFrame.new(0, 0.03, -d), 2.4, color)
		d += 7
	end
	for _, sx in { -3.2, 3.2 } do
		local t = 6
		while t < len - 12 do
			deco(m, Vector3.new(0.18, 0.03, 2.2), base * CFrame.new(sx, 0.03, -t), scaleColor(color, 0.45), NEON)
			t += 4
		end
	end
end

local function buildFloor(root: Instance)
	local m = model(root, "Floor")
	-- outer ground (streets beyond the plaza)
	box(m, Vector3.new(1400, 2, 1400), CFrame.new(0, -1.05, 0), rgb(8, 8, 11), ASPHALT)

	-- plaza slabs
	local tile = 12
	local n = math.floor(HALF * 2 / tile)
	local fm = model(m, "Slabs")
	for ix = 0, n - 1 do
		for iz = 0, n - 1 do
			local x = -HALF + tile / 2 + ix * tile
			local z = -HALF + tile / 2 + iz * tile
			local g = rr(11, 19)
			local col = Color3.fromRGB(g, g + rr(0, 2), g + rr(3, 8))
			local isConcrete = chance(0.35)
			local p = box(fm, Vector3.new(tile - 0.16, 1, tile - 0.16), CFrame.new(x, -0.5, z), col, if isConcrete then CONCRETE else SMOOTH)
			p.Reflectance = if isConcrete then 0.02 else rr(0.06, 0.14)
			p.CastShadow = false
		end
	end
	-- grout / gaps underlay
	box(m, Vector3.new(HALF * 2, 1, HALF * 2), CFrame.new(0, -0.56, 0), rgb(3, 3, 5), SMOOTH).CastShadow = false

	-- neon grid every 24 studs
	local gm = model(m, "Grid")
	local gridCol = rgb(0, 70, 92)
	for k = -HALF + 24, HALF - 24, 24 do
		neon(gm, Vector3.new(HALF * 2 - 16, 0.03, 0.14), CFrame.new(0, 0.015, k), gridCol, true)
		neon(gm, Vector3.new(0.14, 0.03, HALF * 2 - 16), CFrame.new(k, 0.015, 0), gridCol, true)
	end
	-- grid node studs
	for x = -HALF + 24, HALF - 24, 24 do
		for z = -HALF + 24, HALF - 24, 24 do
			deco(gm, Vector3.new(0.7, 0.05, 0.7), CFrame.new(x, 0.03, z), scaleColor(CYAN, 0.5), NEON)
		end
	end

	-- raised sidewalk band with kerb + drains along the perimeter
	local sm = model(m, "Sidewalk")
	local sw = 8
	for side = 0, 3 do
		local R = CFrame.Angles(0, side * PI / 2, 0)
		local c = R * CFrame.new(0, 0.2, -(HALF - sw / 2))
		local p = box(sm, Vector3.new(HALF * 2, 0.4, sw), c, rgb(20, 21, 28), CONCRETE)
		p.CastShadow = false
		-- kerb edge + glow
		deco(sm, Vector3.new(HALF * 2 - sw * 2, 0.5, 0.4), R * CFrame.new(0, 0.22, -(HALF - sw) + 0.2), METAL2, METALM)
		neon(sm, Vector3.new(HALF * 2 - sw * 2, 0.06, 0.08), R * CFrame.new(0, 0.48, -(HALF - sw) + 0.02), MAG, true)
		-- paving joints
		for x = -HALF + 4, HALF - 4, 4 do
			deco(sm, Vector3.new(0.08, 0.02, sw), R * CFrame.new(x, 0.41, -(HALF - sw / 2)), rgb(10, 10, 14))
		end
		-- drains along the kerb
		for x = -HALF + 20, HALF - 20, 18 do
			local dcf = R * CFrame.new(x, 0.02, -(HALF - sw) + 1.2)
			deco(sm, Vector3.new(3.2, 0.04, 1.2), dcf, rgb(4, 4, 6))
			for k = -5, 5 do
				deco(sm, Vector3.new(0.12, 0.05, 1.1), dcf * CFrame.new(k * 0.28, 0.02, 0), METAL3, METALM)
			end
		end
		-- railing on top of the sidewalk, right in front of the facades
		for x = -HALF + 10, HALF - 10, 5 do
			deco(sm, Vector3.new(0.18, 2.4, 0.18), R * CFrame.new(x, 1.6, -(HALF - 1.2)), METAL3, METALM)
		end
		deco(sm, Vector3.new(HALF * 2 - 20, 0.16, 0.16), R * CFrame.new(0, 2.8, -(HALF - 1.2)), METAL3, METALM)
		neon(sm, Vector3.new(HALF * 2 - 20, 0.08, 0.08), R * CFrame.new(0, 2.95, -(HALF - 1.2)), CYAN, true)
	end

	-- puddles (high reflectance discs)
	local pm = model(m, "Puddles")
	for _ = 1, 34 do
		local pos = Vector3.new(rr(-118, 118), 0.012, rr(-118, 118))
		local d = rr(3, 9)
		local p = cylY(pm, 0.02, d, CFrame.new(pos) * CFrame.Angles(0, rr(0, PI), 0), rgb(6, 7, 12), GLASS)
		p.Size = Vector3.new(0.02, d, d * rr(0.6, 1))
		p.Reflectance = 0.45
		p.Transparency = 0.15
		makeDecor(p)
	end

	-- manholes
	for _ = 1, 8 do
		local pos = Vector3.new(rr(-110, 110), 0.02, rr(-110, 110))
		local mh = cylY(m, 0.05, 3, CFrame.new(pos), rgb(28, 28, 34), METALM)
		makeDecor(mh)
		for k = -3, 3 do
			deco(m, Vector3.new(2.4 - math.abs(k) * 0.25, 0.06, 0.12), CFrame.new(pos) * CFrame.new(0, 0.03, k * 0.35), METAL3, METALM)
		end
	end

	-- floor vents with steam
	for _ = 1, 10 do
		local a = rr(0, PI * 2)
		local r = rr(28, 50)
		steamVent(m, CFrame.new(CORE_POS + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)) * CFrame.Angles(0, rr(0, PI), 0))
	end
	for _ = 1, 6 do
		steamVent(m, CFrame.new(rr(-115, 115), 0, rr(40, 115)))
	end
end

---------------------------------------------------------------------------------------------------
-- Spawn
---------------------------------------------------------------------------------------------------

local function buildSpawn(root: Instance)
	local m = model(root, "Spawn")
	local sp = Instance.new("SpawnLocation")
	sp.Name = "SpawnLocation"
	sp.Anchored = true
	sp.Size = Vector3.new(12, 1, 12)
	sp.CFrame = CFrame.new(0, 0.5, 0)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.CanQuery = false
	sp.Neutral = true
	sp.Duration = 0
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Parent = m
	for _, c in sp:GetChildren() do
		if c:IsA("Decal") then
			c:Destroy()
		end
	end

	local c = CFrame.new(0, 0.02, 0)
	local disc = cylY(m, 0.04, 17, c, rgb(6, 8, 14), SMOOTH)
	disc.Reflectance = 0.2
	makeDecor(disc)
	ring(m, "SpawnRingOuter", c * CFrame.new(0, 0.04, 0), 8.4, 0.05, 0.35, 64, CYAN, true)
	ring(m, "SpawnRingMid", c * CFrame.new(0, 0.05, 0), 7.2, 0.05, 0.12, 48, MAG, true, 3)
	local spinner = ring(m, "SpawnSpinner", c * CFrame.new(0, 0.07, 0), 5.6, 0.05, 0.5, 24, CYAN, true, 4)
	spin(spinner, 18, "Y")
	ring(m, "SpawnCore", c * CFrame.new(0, 0.05, 0), 2.2, 0.05, 0.2, 24, rgb(220, 240, 255), false)
	-- hex ticks
	for i = 0, 23 do
		local a = i / 24 * PI * 2
		deco(m, Vector3.new(0.12, 0.05, if i % 6 == 0 then 1.6 else 0.7), c * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.05, -9.6), scaleColor(CYAN, 0.6), NEON)
	end
	-- corner bollards
	for i = 0, 3 do
		local a = i / 4 * PI * 2 + PI / 4
		bollard(m, CFrame.new(math.cos(a) * 10.5, 0, math.sin(a) * 10.5), if i % 2 == 0 then CYAN else MAG)
	end
end

---------------------------------------------------------------------------------------------------
-- Core monument
---------------------------------------------------------------------------------------------------

local function dataCube(parent: Instance, cf: CFrame, s: number, color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "DataCube"
	local core = deco(m, Vector3.new(s * 0.86, s * 0.86, s * 0.86), cf, rgb(8, 10, 16), GLASS)
	core.Reflectance = 0.3
	core.Transparency = 0.1
	m.PrimaryPart = core
	local inner = deco(m, Vector3.new(s * 0.35, s * 0.35, s * 0.35), cf * CFrame.Angles(0.6, 0.6, 0), color, NEON)
	inner.Transparency = 0.2
	local e = s * 0.08
	local h = s / 2
	for _, a in { -h, h } do
		for _, b in { -h, h } do
			neon(m, Vector3.new(s + e, e, e), cf * CFrame.new(0, a, b), color)
			neon(m, Vector3.new(e, s + e, e), cf * CFrame.new(a, 0, b), color)
			neon(m, Vector3.new(e, e, s + e), cf * CFrame.new(a, b, 0), color)
		end
	end
	m.Parent = parent
	return m
end

local function buildCore(root: Instance): Vector3
	local m = model(root, "Core")
	local base = CFrame.new(CORE_POS)

	-- stepped dais
	local tiers = { 46, 38, 30 }
	for i, dd in tiers do
		local y = (i - 1) * 1.0
		local t = cylY(m, 1, dd, base * CFrame.new(0, y + 0.5, 0), if i % 2 == 1 then METAL else rgb(18, 19, 27), if i == 1 then CONCRETE else DIAMOND)
		t.CastShadow = false
		ring(m, "DaisEdge" .. i, base * CFrame.new(0, y + 1.02, 0), dd / 2 - 0.5, 0.06, 0.3, 72, if i == 2 then MAG else CYAN, true)
		-- step lights on the riser
		for k = 0, 31 do
			local a = k / 32 * PI * 2
			deco(m, Vector3.new(0.6, 0.18, 0.1), base * CFrame.Angles(0, a, 0) * CFrame.new(0, y + 0.55, -dd / 2 - 0.02), scaleColor(CYAN, 0.55), NEON)
		end
	end
	-- dais bollards
	for k = 0, 15 do
		local a = k / 16 * PI * 2 + PI / 16
		bollard(m, base * CFrame.Angles(0, a, 0) * CFrame.new(0, 1, -17.2), if k % 2 == 0 then CYAN else MAG)
	end

	-- base block
	local y0 = 3
	box(m, Vector3.new(14, 6, 14), base * CFrame.new(0, y0 + 3, 0), METAL, METALM)
	box(m, Vector3.new(15, 0.6, 15), base * CFrame.new(0, y0 + 0.3, 0), METAL2, METALM)
	box(m, Vector3.new(12, 0.6, 12), base * CFrame.new(0, y0 + 6.3, 0), METAL2, METALM)
	for f = 0, 3 do
		local fcf = base * CFrame.Angles(0, f * PI / 2, 0)
		for k = -2, 2 do
			neon(m, Vector3.new(0.22, 3.6, 0.1), fcf * CFrame.new(k * 1.6, y0 + 3, -7.02), if k == 0 then MAG else CYAN, true)
		end
		vent(m, fcf * CFrame.new(-4.8, y0 + 1.6, -7.1), 2.4, 1.6)
		vent(m, fcf * CFrame.new(4.8, y0 + 1.6, -7.1), 2.4, 1.6)
		-- buttress fin
		wedge(m, Vector3.new(1.2, 12, 5), fcf * CFrame.new(0, y0 + 12, -6), METAL2, METALM)
		seg(m, (fcf * CFrame.new(0, y0 + 18, -3.6)).Position, (fcf * CFrame.new(0, y0 + 6, -8.6)).Position, 0.2, CYAN, NEON)
	end
	for _, sx in { -7.02, 7.02 } do
		for _, sz in { -7.02, 7.02 } do
			neon(m, Vector3.new(0.3, 6, 0.3), base * CFrame.new(sx, y0 + 3, sz), MAG, true)
		end
	end

	-- shaft
	local sh0 = y0 + 6.6
	local shaftH = 42
	local shaft = box(m, Vector3.new(7, shaftH, 7), base * CFrame.new(0, sh0 + shaftH / 2, 0), rgb(11, 12, 19), SMOOTH)
	shaft.Reflectance = 0.12
	for _, sx in { -3.5, 3.5 } do
		for _, sz in { -3.5, 3.5 } do
			neon(m, Vector3.new(0.34, shaftH, 0.34), base * CFrame.new(sx, sh0 + shaftH / 2, sz), CYAN, true)
		end
	end
	for f = 0, 3 do
		local fcf = base * CFrame.Angles(0, f * PI / 2, 0)
		local y = sh0 + 1
		while y < sh0 + shaftH - 3 do
			local ph = rr(3.6, 5.6)
			deco(m, Vector3.new(5.6, ph - 0.35, 0.25), fcf * CFrame.new(0, y + ph / 2, -3.6), METAL2, METALM)
			if chance(0.5) then
				neon(m, Vector3.new(0.12, ph - 1.2, 0.08), fcf * CFrame.new(rr(-2, 2), y + ph / 2, -3.76), MAG, true)
			else
				for k = 0, 2 do
					led(m, fcf * CFrame.new(-2.2 + k * 0.4, y + ph - 0.7, -3.75), nil, 0.16)
				end
			end
			y += ph
		end
	end
	for y = sh0 + 6, sh0 + shaftH - 2, 6 do
		neon(m, Vector3.new(7.3, 0.18, 7.3), base * CFrame.new(0, y, 0), CYAN, true)
	end

	-- capital + cage
	local top = sh0 + shaftH
	box(m, Vector3.new(9.5, 1.6, 9.5), base * CFrame.new(0, top + 0.8, 0), METAL2, METALM)
	box(m, Vector3.new(7.5, 0.8, 7.5), base * CFrame.new(0, top + 2, 0), METAL, METALM)
	neon(m, Vector3.new(9.7, 0.2, 9.7), base * CFrame.new(0, top + 0.4, 0), MAG, true)
	local orbY = top + 11
	local orbCF = base * CFrame.new(0, orbY, 0)
	for k = 0, 3 do
		local a = k / 4 * PI * 2 + PI / 4
		local function P(r: number, y: number): Vector3
			return (base * CFrame.new(math.cos(a) * r, y, math.sin(a) * r)).Position
		end
		local pts = { P(4.6, top + 1.6), P(7.8, top + 5), P(9.2, top + 9), P(8.6, top + 13.5), P(6, top + 17), P(2.6, top + 19.2) }
		for i = 1, #pts - 1 do
			seg(m, pts[i], pts[i + 1], 0.9, METAL2, METALM)
			local off = (base.Position - pts[i]).Unit * 0.05
			seg(m, pts[i] + off, pts[i + 1] + off, 0.3, MAG, NEON)
		end
		ball(m, 0.8, CFrame.new(pts[#pts]), CYAN, NEON)
	end
	local orb = ball(m, 8, orbCF, CYAN, NEON)
	orb.Name = "CoreOrb"
	tagBiome(orb)
	local shell = ball(m, 11, orbCF, CYAN, Enum.Material.ForceField)
	shell.Name = "CoreShell"
	tagBiome(shell)
	pointLight(orb, CYAN, 60, 3.5)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = TEX .. "sparkles_main.dds"
	pe.Rate = 18
	pe.Lifetime = NumberRange.new(1.5, 3)
	pe.Speed = NumberRange.new(3, 7)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(CYAN, MAG)
	pe.LightEmission = 1
	pe.Drag = 2
	pe.Parent = orb

	-- rings around the orb
	local r1 = ring(m, "OrbRing1", orbCF, 7.2, 0.3, 0.5, 48, CYAN, true, nil, METAL2)
	spin(r1, 42, "X")
	local r2 = ring(m, "OrbRing2", orbCF * CFrame.Angles(0, 0, PI / 2), 8.6, 0.25, 0.4, 48, MAG, true, 6)
	spin(r2, -34, "Z")
	local r3 = ring(m, "OrbRing3", orbCF * CFrame.Angles(math.rad(22), 0, 0), 10.5, 0.2, 0.7, 56, CYAN, true, 4)
	spin(r3, 24, "Y")
	local r4 = ring(m, "OrbRing4", orbCF * CFrame.new(0, -1, 0), 13.5, 0.15, 0.25, 64, rgb(220, 240, 255), false, 3)
	spin(r4, -12, "Y")
	-- halo around the shaft with hanging plates
	local haloCF = base * CFrame.new(0, sh0 + 18, 0)
	local halo = ring(m, "ShaftHalo", haloCF, 11, 0.4, 1.2, 64, MAG, true, 8, METAL)
	for k = 0, 7 do
		local a = k / 8 * PI * 2
		local pcf = haloCF * CFrame.Angles(0, a, 0) * CFrame.new(0, -1.6, -11)
		local plate = deco(halo, Vector3.new(2.2, 2.6, 0.1), pcf, SCREEN_BLACK, SMOOTH)
		neon(halo, Vector3.new(2.3, 0.1, 0.14), pcf * CFrame.new(0, 1.3, 0), MAG, true)
		glyph(halo, pcf * CFrame.new(0, -0.1, -0.08), 1.4, CYAN, false)
		glyph(halo, pcf * CFrame.Angles(0, PI, 0) * CFrame.new(0, -0.1, -0.08), 1.4, CYAN, false)
		deco(halo, Vector3.new(0.06, 0.7, 0.06), pcf * CFrame.new(0, 1.6, 0), METAL3, METALM)
		plate.Name = "Plate"
	end
	spin(halo, 9, "Y")

	-- floating data cubes
	for k = 0, 13 do
		local a = k / 14 * PI * 2 + rr(-0.15, 0.15)
		local r = rr(15, 21)
		local y = rr(8, 44)
		local s = rr(1.2, 2.6)
		local cube = dataCube(m, base * CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(rr(0, PI), rr(0, PI), 0), s, if k % 3 == 0 then MAG else CYAN)
		bob(cube, rr(0.8, 2), rr(0.6, 1.4), rr(-40, 40))
	end

	-- uplink beam into the sky
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 4, 0)
	a0.Parent = orb
	local skyP = deco(m, Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, 420, 0), CYAN)
	skyP.Transparency = 1
	local a1 = Instance.new("Attachment")
	a1.Parent = skyP
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 2.2
	beam.Width1 = 0.4
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(CYAN, MAG)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.6, 0.75), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = orb

	-- radial cables from base to floor junctions
	for k = 0, 7 do
		local a = k / 8 * PI * 2 + PI / 8
		local from = (base * CFrame.new(math.cos(a) * 7.2, y0 + 1.5, math.sin(a) * 7.2)).Position
		local to = (base * CFrame.new(math.cos(a) * 21.5, 0.4, math.sin(a) * 21.5)).Position
		cable(m, from, to + Vector3.new(0, 0.4, 0), 0.2, 0.32, if k % 2 == 0 then RUBBER else rgb(30, 18, 34))
		local jb = box(m, Vector3.new(1.6, 1, 1.2), CFrame.lookAt(to + Vector3.new(0, 0.5, 0), base.Position * Vector3.new(1, 0, 1) + Vector3.new(0, 0.5, 0)), METAL2, METALM)
		led(m, jb.CFrame * CFrame.new(-0.4, 0.2, -0.62), nil, 0.14)
		led(m, jb.CFrame * CFrame.new(0, 0.2, -0.62), nil, 0.14)
	end

	return orb.Position
end

---------------------------------------------------------------------------------------------------
-- Terminals
---------------------------------------------------------------------------------------------------

local function terminalScreen(screen: BasePart, w: number, h: number, title: string, accent: Color3, accent2: Color3, lines: { string })
	local pps = 60
	local g = surfaceGui(screen, Enum.NormalId.Front, pps, "Screen")
	g.Brightness = 2
	local H = h * pps
	local bg = frame(g, UDim2.new(), UDim2.fromScale(1, 1), rgb(2, 4, 8), 0)
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(scaleColor(accent, 0.18), rgb(0, 0, 0))
	grad.Parent = bg
	local header = frame(bg, UDim2.new(), UDim2.new(1, 0, 0, 30), scaleColor(accent, 0.3), 0)
	frame(header, UDim2.new(0, 0, 1, -2), UDim2.new(1, 0, 0, 2), accent, 0)
	label(header, title, FONT_PIX, 13, accent, UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0))
	label(header, "v4.04", FONT_MONO_B, 12, accent2, UDim2.new(), UDim2.new(1, -10, 1, 0), Enum.TextXAlignment.Right)
	for i, s in lines do
		label(bg, s, FONT_MONO, 13, if i == 1 then Pal.Text else Pal.Dim, UDim2.fromOffset(12, 34 + (i - 1) * 18), UDim2.new(1, -24, 0, 18))
	end
	-- progress bars
	local by = 34 + #lines * 18 + 6
	for i = 0, 2 do
		local bgBar = frame(bg, UDim2.fromOffset(12, by + i * 16), UDim2.new(1, -90, 0, 8), rgb(20, 24, 36), 0)
		frame(bgBar, UDim2.new(), UDim2.fromScale(rr(0.25, 0.95), 1), if i == 1 then accent2 else accent, 0)
		label(bg, string.format("%02d%%", ri(10, 99)), FONT_MONO_B, 11, accent, UDim2.new(1, -72, 0, by + i * 16 - 4), UDim2.fromOffset(60, 16), Enum.TextXAlignment.Right)
	end
	-- footer
	local foot = frame(bg, UDim2.new(0, 0, 1, -26), UDim2.new(1, 0, 0, 26), rgb(0, 0, 0), 0.3)
	frame(foot, UDim2.new(), UDim2.new(1, 0, 0, 1), accent, 0.4)
	label(foot, "[E] OPEN", FONT_PIX, 11, accent2, UDim2.fromOffset(10, 0), UDim2.new(0.5, 0, 1, 0))
	label(foot, "SECURE LINK", FONT_HEAD, 10, LIME, UDim2.new(0.5, 0, 0, 0), UDim2.new(0.5, -10, 1, 0), Enum.TextXAlignment.Right)
	-- scanlines + vignette frame
	for y = 0, H, 6 do
		frame(bg, UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, 1), rgb(0, 0, 0), 0.65).ZIndex = 4
	end
	local border = Instance.new("UIStroke")
	border.Color = accent
	border.Thickness = 2
	border.Transparency = 0.3
	border.Parent = bg
end

-- Forge: anvil + hammer hologram; Lab: flask; Index: card stack.
local function hologramIcon(parent: Instance, kind: string, cf: CFrame, accent: Color3): Model
	local m = hubModel(parent, "HoloIcon", cf)
	local function holo(size: Vector3, c: CFrame, shape: Enum.PartType?): Part
		local p = deco(m, size, cf * c, accent, NEON)
		p.Transparency = 0.25
		if shape then
			p.Shape = shape
		end
		return p
	end
	if kind == "Forge" then
		holo(Vector3.new(1.8, 0.4, 1), CFrame.new(0, -0.9, 0))
		holo(Vector3.new(0.9, 0.7, 0.7), CFrame.new(0, -0.35, 0))
		holo(Vector3.new(2.6, 0.55, 1.1), CFrame.new(0.2, 0.2, 0))
		local horn = Instance.new("WedgePart")
		setup(horn, m, Vector3.new(1.1, 0.55, 1.2), cf * CFrame.new(-1.65, 0.2, 0) * CFrame.Angles(0, -PI / 2, 0), accent, NEON)
		makeDecor(horn)
		horn.Transparency = 0.25
		local hcf = CFrame.new(0.6, 1.5, 0) * CFrame.Angles(0, 0, math.rad(35))
		holo(Vector3.new(0.2, 1.8, 0.2), hcf)
		holo(Vector3.new(1, 0.5, 0.5), hcf * CFrame.new(0, 0.9, 0))
	elseif kind == "Lab" then
		holo(Vector3.new(1.9, 1.9, 1.9), CFrame.new(0, -0.5, 0), Enum.PartType.Ball)
		holo(Vector3.new(1.2, 0.55, 0.55), CFrame.new(0, 0.85, 0) * UPRIGHT, Enum.PartType.Cylinder)
		holo(Vector3.new(0.2, 0.85, 0.85), CFrame.new(0, 1.5, 0) * UPRIGHT, Enum.PartType.Cylinder)
		local liquid = deco(m, Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(0, -0.65, 0), rgb(255, 255, 255), NEON)
		liquid.Shape = Enum.PartType.Ball
		liquid.Transparency = 0.5
	else
		for i = 0, 3 do
			holo(Vector3.new(2, 0.12, 1.4), CFrame.new(0, -0.6 + i * 0.45, 0) * CFrame.Angles(0, math.rad(i * 14), math.rad(4)))
		end
		holo(Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 1.4, 0) * CFrame.Angles(PI / 4, 0, PI / 4))
	end
	bob(m, 0.35, 1.6, 45)
	return m
end

local function buildTerminal(root: Instance, kind: string, objectText: string, title: string, pos: Vector3, accent: Color3, accent2: Color3, lines: { string }): BasePart
	local m = model(root, kind .. "Terminal")
	local o = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
	local function L(x: number, y: number, z: number): CFrame
		return o * CFrame.new(x, y, z)
	end

	-- floor pad
	local pad = cylY(m, 0.24, 21, L(0, 0.12, 0), rgb(16, 17, 24), DIAMOND)
	pad.CastShadow = false
	ring(m, "PadRing", L(0, 0.25, 0), 10.1, 0.06, 0.45, 72, accent, true)
	ring(m, "PadRingDash", L(0, 0.26, 0), 8.8, 0.05, 0.16, 48, accent2, true, 3)
	for i = -3, 3 do
		deco(m, Vector3.new(0.45, 0.04, 2), L(i * 1.2, 0.26, -7.4) * CFrame.Angles(0, math.rad(40), 0), AMBER, SMOOTH)
	end
	deco(m, Vector3.new(9, 0.05, 0.15), L(0, 0.27, -6.2), AMBER, SMOOTH)
	deco(m, Vector3.new(9, 0.05, 0.15), L(0, 0.27, -8.6), AMBER, SMOOTH)

	-- plinth
	box(m, Vector3.new(10, 1.2, 7), L(0, 0.84, 0.6), METAL, DIAMOND)
	neon(m, Vector3.new(10.05, 0.14, 0.14), L(0, 1.4, -2.92), accent, true)
	for i = -4, 4 do
		deco(m, Vector3.new(0.5, 0.6, 0.06), L(i * 1.05, 0.84, -2.93), RUBBER)
	end

	-- main body
	local body0 = 1.44
	local main = box(m, Vector3.new(7, 8.6, 4), L(0, body0 + 4.3, 1.2), PANEL, METALM)
	main.Name = "Main"
	main:SetAttribute("Kind", kind)
	for _, sx in { -1, 1 } do
		local fin = wedge(m, Vector3.new(0.8, 8.6, 5), L(sx * 3.9, body0 + 4.3, 1.2), METAL2, METALM)
		fin.CastShadow = true
		seg(m, (L(sx * 4.32, body0 + 8.6, 3.7)).Position, (L(sx * 4.32, body0 + 0.1, -1.3)).Position, 0.14, accent, NEON)
		-- side vents and panel lines
		vent(m, L(sx * 3.52, body0 + 6.5, 2.4) * CFrame.Angles(0, sx * PI / 2, 0), 1.4, 2)
	end
	-- panel seams on the front face
	for i = 0, 2 do
		deco(m, Vector3.new(6.6, 0.06, 0.06), L(0, body0 + 1 + i * 1.2, -0.82), rgb(6, 6, 9))
	end

	-- console desk with keyboard
	box(m, Vector3.new(6, 2.6, 1.6), L(0, body0 + 1.3, -1.6), METAL2, METALM)
	local desk = wedge(m, Vector3.new(6.4, 0.9, 2.2), L(0, body0 + 3.05, -1.8), METAL, METALM)
	desk.CastShadow = false
	local slope = math.atan(0.9 / 2.2)
	for row = 0, 2 do
		for col = 0, 9 do
			local t = (row + 0.6) / 3.4
			local zz = -2.9 + t * 2.2
			local yy = body0 + 2.6 + t * 0.9
			local kcf = L(-2.5 + col * 0.55, yy, zz) * CFrame.Angles(-slope, 0, 0) * CFrame.new(0, 0.06, 0)
			if chance(0.12) then
				neon(m, Vector3.new(0.44, 0.1, 0.4), kcf, accent2)
			else
				deco(m, Vector3.new(0.44, 0.1, 0.4), kcf, METAL3, SMOOTH)
			end
		end
	end
	neon(m, Vector3.new(6.4, 0.1, 0.1), L(0, body0 + 2.62, -2.92), accent, true)

	-- main screen
	local tilt = math.rad(8)
	local scf = L(0, body0 + 6.1, -0.95) * CFrame.Angles(tilt, 0, 0)
	deco(m, Vector3.new(6.3, 4.3, 0.4), scf, METAL2, METALM)
	local screen = deco(m, Vector3.new(5.7, 3.7, 0.1), scf * CFrame.new(0, 0, -0.24), SCREEN_BLACK, SMOOTH)
	screen.Name = "Screen"
	terminalScreen(screen, 5.7, 3.7, title, accent, accent2, lines)
	surfaceLight(screen, Enum.NormalId.Front, accent, 10, 1.1)
	neon(m, Vector3.new(5.9, 0.1, 0.12), scf * CFrame.new(0, -2.2, -0.2), accent, true)
	for _, sx in { -1, 1 } do
		deco(m, Vector3.new(0.3, 3.4, 0.3), scf * CFrame.new(sx * 3.25, 0, -0.1), METAL3, METALM)
	end

	-- top header block
	local headY = body0 + 8.6 + 0.8
	box(m, Vector3.new(7.8, 1.6, 4.8), L(0, headY, 1.2), METAL2, METALM)
	neon(m, Vector3.new(7.9, 0.22, 4.9), L(0, headY, 1.2), accent, true)
	for i = 0, 7 do
		led(m, L(-2.8 + i * 0.8, headY - 0.5, -1.22), if i % 2 == 0 then accent else nil, 0.18)
	end
	-- vent grille on the header front
	vent(m, L(0, headY + 0.42, -1.25), 4.5, 0.6)

	-- hologram emitter + icon + rings
	local emY = headY + 0.9
	cylY(m, 0.2, 3.4, L(0, emY, 1.2), METAL3, METALM).CanCollide = false
	local em = cylY(m, 0.12, 2.6, L(0, emY + 0.12, 1.2), accent, NEON)
	makeDecor(em)
	local iconCF = L(0, emY + 3.4, 1.2)
	hologramIcon(m, kind, iconCF, accent)
	local hr1 = ring(m, "HoloRing1", iconCF, 2.6, 0.08, 0.16, 32, accent, false, 4)
	spin(hr1, 40, "Y")
	local hr2 = ring(m, "HoloRing2", iconCF * CFrame.Angles(math.rad(70), 0, 0), 3.1, 0.06, 0.12, 36, accent2, false, 5)
	spin(hr2, -30, "X")
	local ea0 = Instance.new("Attachment")
	ea0.Position = Vector3.new(0.1, 0, 0)
	ea0.Parent = em
	local iconAnchor = deco(m, Vector3.new(0.2, 0.2, 0.2), iconCF * CFrame.new(0, -0.6, 0), accent)
	iconAnchor.Transparency = 1
	local ea1 = Instance.new("Attachment")
	ea1.Parent = iconAnchor
	local cone = Instance.new("Beam")
	cone.Attachment0 = ea0
	cone.Attachment1 = ea1
	cone.Width0 = 2.4
	cone.Width1 = 3.6
	cone.FaceCamera = true
	cone.LightEmission = 1
	cone.LightInfluence = 0
	cone.Color = ColorSequence.new(accent)
	cone.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.95) })
	cone.Parent = em
	pointLight(iconAnchor, accent, 14, 1.6)

	-- side code screens on posts
	for _, sx in { -1, 1 } do
		local base = L(sx * 6.2, 0, -1.2)
		box(m, Vector3.new(0.7, 5.2, 0.7), base * CFrame.new(0, 2.6, 0), METAL2, METALM)
		box(m, Vector3.new(1.4, 0.4, 1.4), base * CFrame.new(0, 0.2, 0), METAL, METALM)
		local panelCF = base * CFrame.new(0, 6.4, 0) * CFrame.Angles(0, -sx * math.rad(25), 0)
		deco(m, Vector3.new(3, 3.8, 0.35), panelCF, METAL, METALM)
		local side = deco(m, Vector3.new(2.6, 3.4, 0.1), panelCF * CFrame.new(0, 0, -0.22), SCREEN_BLACK)
		codeScreen(side, 2.6, 3.4, accent, nil, 60)
		neon(m, Vector3.new(3.05, 0.1, 0.1), panelCF * CFrame.new(0, 1.95, -0.2), accent2, true)
		neon(m, Vector3.new(3.05, 0.1, 0.1), panelCF * CFrame.new(0, -1.95, -0.2), accent2, true)
	end

	-- rear junction box + cables
	local jb = box(m, Vector3.new(3.2, 1.4, 1.8), L(0, 0.7, 7.5), METAL2, METALM)
	for i = 0, 4 do
		led(m, jb.CFrame * CFrame.new(-1 + i * 0.5, 0.35, -0.92), nil, 0.14)
	end
	for i = 0, 4 do
		local a = (L(-1.6 + i * 0.8, body0 + 2 + (i % 3) * 2, 3.25)).Position
		local b = (L(-1.2 + i * 0.6, 1.3, 6.6)).Position
		cable(m, a, b, 0.7 + i * 0.12, if i == 2 then 0.16 else 0.22, if i == 2 then accent else RUBBER, i == 2)
	end
	pipeRun(m, (L(2.6, body0 + 7.5, 3.4)).Position, (L(2.6, 0.3, 3.4)).Position, 0.45, rgb(50, 52, 64))
	pointLight(main, accent, 16, 1.2)

	-- kind-specific props
	if kind == "Forge" then
		-- robotic arm
		local ab = L(-7.5, 0, 3.5)
		cylY(m, 1, 2.2, ab * CFrame.new(0, 0.5, 0), METAL2, METALM)
		ring(m, "ArmBase", ab * CFrame.new(0, 1.02, 0), 1.05, 0.06, 0.12, 20, accent, true)
		local p0 = (ab * CFrame.new(0, 1, 0)).Position
		local p1 = (ab * CFrame.new(0.6, 5.2, -0.8)).Position
		local p2 = (ab * CFrame.new(2.2, 7, -3)).Position
		local p3 = (ab * CFrame.new(3, 5.4, -4.2)).Position
		seg(m, p0, p1, 0.9, rgb(70, 72, 86), METALM)
		seg(m, p1, p2, 0.75, rgb(70, 72, 86), METALM)
		seg(m, p2, p3, 0.5, rgb(70, 72, 86), METALM)
		for _, p in { p1, p2 } do
			ball(m, 1.1, CFrame.new(p), METAL, METALM)
			ball(m, 0.5, CFrame.new(p) * CFrame.new(0, 0, -0.35), accent, NEON)
		end
		seg(m, p0 + Vector3.new(0.4, 0, 0), p1 + Vector3.new(0.4, 0, 0), 0.08, AMBER, NEON)
		local claw = CFrame.lookAt(p3, p3 + (p3 - p2).Unit)
		deco(m, Vector3.new(0.6, 0.6, 0.6), claw, METAL3, METALM)
		deco(m, Vector3.new(0.12, 0.12, 0.8), claw * CFrame.new(0.22, 0, -0.5) * CFrame.Angles(0, 0.4, 0), METAL3, METALM)
		deco(m, Vector3.new(0.12, 0.12, 0.8), claw * CFrame.new(-0.22, 0, -0.5) * CFrame.Angles(0, -0.4, 0), METAL3, METALM)
		-- workbench with parts
		local wb = L(7.6, 0, 3)
		box(m, Vector3.new(4, 0.3, 2.4), wb * CFrame.new(0, 3, 0), METAL2, DIAMOND)
		for _, sx in { -1.8, 1.8 } do
			for _, sz in { -1, 1 } do
				deco(m, Vector3.new(0.25, 3, 0.25), wb * CFrame.new(sx, 1.5, sz), METAL3, METALM)
			end
		end
		for i = 0, 2 do
			local gcf = wb * CFrame.new(-1.2 + i * 1.2, 3.25, 0.2) * CFrame.Angles(0, rr(0, PI), 0)
			cylY(m, 0.18, 0.8, gcf, METAL3, METALM).CanCollide = false
			for t = 0, 7 do
				deco(m, Vector3.new(0.14, 0.18, 0.2), gcf * CFrame.Angles(0, t / 8 * PI * 2, 0) * CFrame.new(0, 0, -0.45), METAL3, METALM)
			end
		end
		ring(m, "RigBand", wb * CFrame.new(0.4, 3.6, -0.6) * CFrame.Angles(PI / 2.4, 0, 0), 0.45, 0.12, 0.25, 16, accent2, false)
		local sp = deco(m, Vector3.new(0.3, 0.3, 0.3), wb * CFrame.new(0, 3.4, 0), AMBER)
		sp.Transparency = 1
		local spark = Instance.new("ParticleEmitter")
		spark.Texture = TEX .. "fire_sparks_main.dds"
		spark.Rate = 6
		spark.Lifetime = NumberRange.new(0.4, 0.9)
		spark.Speed = NumberRange.new(4, 9)
		spark.SpreadAngle = Vector2.new(50, 50)
		spark.Acceleration = Vector3.new(0, -30, 0)
		spark.Size = NumberSequence.new(0.25, 0)
		spark.Color = ColorSequence.new(rgb(255, 210, 120), AMBER)
		spark.LightEmission = 1
		spark.Parent = sp
	elseif kind == "Lab" then
		for _, sx in { -1, 1 } do
			local tb = L(sx * 7.4, 0, 3)
			cylY(m, 0.8, 3.2, tb * CFrame.new(0, 0.4, 0), METAL2, METALM)
			ring(m, "TankBase", tb * CFrame.new(0, 0.82, 0), 1.5, 0.06, 0.14, 24, accent, true)
			local glassT = cylY(m, 6.6, 2.6, tb * CFrame.new(0, 4.1, 0), rgb(160, 200, 220), GLASS)
			glassT.Transparency = 0.7
			glassT.Reflectance = 0.15
			local liquid = cylY(m, 5.2, 2.1, tb * CFrame.new(0, 3.5, 0), if sx < 0 then accent else accent2, NEON)
			liquid.Transparency = 0.35
			makeDecor(liquid)
			cylY(m, 0.7, 3, tb * CFrame.new(0, 7.75, 0), METAL2, METALM)
			ring(m, "TankCap", tb * CFrame.new(0, 7.4, 0), 1.45, 0.06, 0.12, 24, accent, true)
			for _ = 1, 5 do
				local bub = ball(m, rr(0.18, 0.35), tb * CFrame.new(rr(-0.6, 0.6), rr(1.5, 5.5), rr(-0.6, 0.6)), rgb(230, 255, 255), NEON)
				bob(bub, rr(0.4, 1), rr(1, 2.4))
			end
			-- feed pipe to the body
			pipeRun(m, (tb * CFrame.new(0, 7.7, 0)).Position, (L(sx * 3.6, body0 + 7.6, 2.4)).Position, 0.35, METAL3)
			pointLight(liquid, if sx < 0 then accent else accent2, 10, 1.2)
		end
		-- vial rack
		local shelf = L(-4.2, 0, 4.6)
		box(m, Vector3.new(2.6, 0.2, 1), shelf * CFrame.new(0, 3, 0), METAL2, METALM)
		deco(m, Vector3.new(0.2, 3, 0.2), shelf * CFrame.new(-1.2, 1.5, 0), METAL3, METALM)
		deco(m, Vector3.new(0.2, 3, 0.2), shelf * CFrame.new(1.2, 1.5, 0), METAL3, METALM)
		for i = 0, 5 do
			local c = pick(PRODUCT_COLS)
			local v = cylY(m, 0.7, 0.28, shelf * CFrame.new(-1 + i * 0.4, 3.45, 0), c, NEON)
			v.Transparency = 0.2
			makeDecor(v)
		end
	else
		-- archive shelves with glowing cartridges in tier colours
		for _, sx in { -1, 1 } do
			local sh = L(sx * 7.6, 0, 2.6) * CFrame.Angles(0, -sx * math.rad(20), 0)
			box(m, Vector3.new(3, 9, 1.6), sh * CFrame.new(0, 4.5, 0.4), METAL, METALM)
			neon(m, Vector3.new(3.05, 0.12, 0.12), sh * CFrame.new(0, 9, -0.42), accent, true)
			for row = 0, 7 do
				deco(m, Vector3.new(2.7, 0.08, 0.6), sh * CFrame.new(0, 0.9 + row * 1.0, -0.2), METAL3, METALM)
				for col = 0, 5 do
					local tier = Config.Tiers[ri(1, #Config.Tiers)]
					local cart = deco(m, Vector3.new(0.32, 0.75, 0.45), sh * CFrame.new(-1.1 + col * 0.44, 1.32 + row * 1.0, -0.25), if chance(0.6) then scaleColor(tier.color, 0.7) else METAL2, if chance(0.6) then NEON else METALM)
					cart.Name = "Cartridge"
				end
			end
		end
		-- orbit of floating data cards above the header
		local orbit = hubModel(m, "CardOrbit", L(0, emY + 3.4, 1.2))
		for i = 0, 9 do
			local a = i / 10 * PI * 2
			local ccf = L(0, emY + 3.4, 1.2) * CFrame.Angles(0, a, 0) * CFrame.new(0, math.sin(a * 2) * 0.6, -4.6)
			local card = deco(orbit, Vector3.new(1.2, 1.6, 0.06), ccf, SCREEN_BLACK, SMOOTH)
			card.Name = "Card"
			local tc = Config.Tiers[(i % #Config.Tiers) + 1].color
			neon(orbit, Vector3.new(1.25, 0.08, 0.08), ccf * CFrame.new(0, 0.8, 0), tc)
			neon(orbit, Vector3.new(1.25, 0.08, 0.08), ccf * CFrame.new(0, -0.8, 0), tc)
			neon(orbit, Vector3.new(0.5, 0.5, 0.04), ccf * CFrame.new(0, 0.15, -0.04) * CFrame.Angles(0, 0, PI / 4), scaleColor(tc, 0.8))
		end
		spin(orbit, 14, "Y")
	end

	-- flanking vertical signs (abstract glyph strips, no words)
	for _, sx in { -1, 1 } do
		local poleBase = L(sx * 10.6, 0, 4.5)
		box(m, Vector3.new(0.8, 22, 0.8), poleBase * CFrame.new(0, 11, 0.6), METAL2, METALM)
		box(m, Vector3.new(1.8, 0.6, 1.8), poleBase * CFrame.new(0, 0.3, 0.6), METAL, METALM)
		verticalSign(m, poleBase * CFrame.new(0, 15.5, -0.2), 5, 1.7, if sx < 0 then accent else accent2, if sx < 0 then accent2 else accent)
		cable(m, (poleBase * CFrame.new(0, 21.5, 0.6)).Position, (L(0, headY + 0.5, 3.4)).Position, 2.2, 0.14, RUBBER)
	end

	-- the prompt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "OpenPrompt"
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.ActionText = "Open"
	pp.ObjectText = objectText
	pp:SetAttribute("Kind", kind)
	pp.Parent = main

	return main
end

---------------------------------------------------------------------------------------------------
-- Leaderboard wall
---------------------------------------------------------------------------------------------------

local function buildLeaderboard(root: Instance): BasePart
	local m = model(root, "LeaderboardWall")
	local W, H = 44, 24
	local cf = CFrame.lookAt(BOARD_CENTER, BOARD_CENTER - Vector3.new(0, 0, 1)) -- front faces the plaza (-Z)
	local function L(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local gy = -BOARD_CENTER.Y -- local y of the ground

	-- tower behind the screen
	box(m, Vector3.new(60, 46, 10), L(0, gy + 23, 6), rgb(14, 15, 22), CONCRETE)
	box(m, Vector3.new(62, 1.2, 11), L(0, gy + 46.6, 6), METAL2, METALM)
	neon(m, Vector3.new(60.4, 0.25, 10.4), L(0, gy + 44.5, 6), MAG, true)
	-- bezel
	box(m, Vector3.new(W + 3, H + 3, 1.6), L(0, 0, 1.2), METAL, METALM)
	for _, sy in { -1, 1 } do
		neon(m, Vector3.new(W + 3.2, 0.3, 0.3), L(0, sy * (H / 2 + 1.5), 0.25), CYAN, true)
		deco(m, Vector3.new(W + 1, 0.12, 0.12), L(0, sy * (H / 2 + 0.75), 0.3), scaleColor(MAG, 0.8), NEON)
	end
	for _, sx in { -1, 1 } do
		neon(m, Vector3.new(0.3, H + 3.2, 0.3), L(sx * (W / 2 + 1.5), 0, 0.25), CYAN, true)
		-- side speaker stacks
		local spk = L(sx * (W / 2 + 5), -4, 0.6)
		box(m, Vector3.new(4, 14, 2.6), spk, METAL, METALM)
		for k = 0, 3 do
			local scf = spk * CFrame.new(0, -5 + k * 3.3, -1.32)
			cyl(m, 0.12, 2.6, scf * CFrame.Angles(0, PI / 2, 0), RUBBER, SMOOTH).CanCollide = false
			cyl(m, 0.16, 1, scf * CFrame.new(0, 0, -0.05) * CFrame.Angles(0, PI / 2, 0), METAL3, METALM).CanCollide = false
			ring(m, "SpkRim", scf * CFrame.Angles(PI / 2, 0, 0), 1.32, 0.08, 0.1, 20, MAG, true)
		end
		-- glyph signs on the tower flanks
		verticalSign(m, L(sx * 27.5, gy + 36, -0.6), 7, 2, if sx < 0 then MAG else CYAN, if sx < 0 then CYAN else MAG)
	end
	-- screen
	local screen = box(root, Vector3.new(W, H, 1), cf, SCREEN_BLACK, SMOOTH)
	screen.Name = "LeaderboardScreen"
	screen.CastShadow = false
	local g = Instance.new("SurfaceGui")
	g.Name = "Board"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.LightInfluence = 0
	g.Brightness = 1.5
	g.ResetOnSpawn = false
	g.Parent = screen
	surfaceLight(screen, Enum.NormalId.Front, CYAN, 26, 0.8)

	-- top crown: spot rig + antennas + red lights
	deco(m, Vector3.new(W + 4, 0.6, 2.4), L(0, H / 2 + 2.6, -1.4), METAL2, DIAMOND)
	for i = -3, 3 do
		local lcf = L(i * 6.5, H / 2 + 3.2, -1.8) * CFrame.Angles(math.rad(-35), 0, 0)
		deco(m, Vector3.new(0.9, 0.9, 1.3), lcf, METAL3, METALM)
		neon(m, Vector3.new(0.7, 0.7, 0.06), lcf * CFrame.new(0, 0, -0.67), rgb(220, 235, 255))
	end
	for _, sx in { -24, -8, 8, 24 } do
		antenna(m, (L(sx, gy + 47.2, 6)).Position, rr(5, 10))
	end
	dish(m, L(-14, gy + 47.2, 8) * CFrame.Angles(0, PI, 0), 4)
	acUnit(m, L(14, gy + 47.2, 8) * CFrame.Angles(0, PI, 0))
	-- base stage with steps
	box(m, Vector3.new(W + 6, 1.2, 6), L(0, gy + 0.6, -1.5), METAL, DIAMOND)
	box(m, Vector3.new(W + 4, 0.6, 2), L(0, gy + 0.3, -5), METAL2, DIAMOND)
	neon(m, Vector3.new(W + 6.1, 0.12, 0.12), L(0, gy + 1.2, -4.5), CYAN, true)
	-- support legs
	local legH = (-H / 2 - 1.5) - (gy + 1.2)
	for _, sx in { -18, 0, 18 } do
		box(m, Vector3.new(1.4, legH, 1.4), L(sx, gy + 1.2 + legH / 2, 1.6), METAL2, METALM)
	end
	-- cable bundles from tower to the ground
	for k = 0, 4 do
		local a = (L(-W / 2 - 2 + k * 0.6, H / 2 + 1, 2)).Position
		local b = (L(-W / 2 - 7 + k * 0.8, gy + 0.2, -2)).Position
		cable(m, a, b, 2 + k * 0.4, 0.2, if k == 2 then CYAN else RUBBER, k == 2)
	end
	return screen
end

---------------------------------------------------------------------------------------------------
-- Facades (low buildings lining the plaza)
---------------------------------------------------------------------------------------------------

local FACADE_COLS = { rgb(16, 17, 24), rgb(20, 20, 28), rgb(14, 16, 22), rgb(24, 22, 30), rgb(18, 20, 27) }
local WINDOW_COLS = { rgb(70, 90, 130), rgb(90, 110, 150), rgb(40, 110, 130), rgb(120, 60, 120), rgb(150, 120, 80), rgb(60, 70, 100), rgb(180, 210, 255), rgb(150, 40, 110) }

-- faceCF: bottom-centre of a face, -Z points out of the face.
local function windowGrid(parent: Instance, faceCF: CFrame, faceW: number, faceH: number, pLit: number, startY: number, step: number, colW: number?)
	local cw = colW or 3.2
	local cols = math.max(1, math.floor(faceW / cw))
	local w = faceW / cols
	local y = startY
	while y < faceH - 2.5 do
		local runStart = 0
		local runColor = WINDOW_COLS[1]
		local rowP = pLit * rr(0.2, 1.7)
		for c = 1, cols + 1 do
			local lit = c <= cols and chance(rowP)
			if lit and runStart == 0 then
				runStart = c
				runColor = pick(WINDOW_COLS)
			elseif (not lit) and runStart > 0 then
				local x0 = (runStart - 1) * w
				local x1 = (c - 1) * w
				local p = neon(parent, Vector3.new(x1 - x0 - 0.7, math.min(1.8, step * 0.45), 0.2), faceCF * CFrame.new(-faceW / 2 + (x0 + x1) / 2, y, -0.06), runColor)
				p:AddTag("CityLight")
				runStart = 0
			end
		end
		y += step
	end
end

local function facadeBlock(parent: Instance, cf: CFrame, w: number, h: number, d: number): Vector3
	local m = model(parent, "Facade")
	local col = pick(FACADE_COLS)
	box(m, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), col, CONCRETE)
	local fz = -d / 2
	local function F(x: number, y: number, out: number): CFrame
		return cf * CFrame.new(x, y, fz - out)
	end
	local accent = pick({ CYAN, MAG, RED, CYAN, MAG })
	local storeW = w - 2.4

	if chance(0.62) then
		-- glass storefront with a shallow display box
		local depth = 1
		deco(m, Vector3.new(storeW + 0.8, 0.8, depth + 0.2), F(0, 7.0, depth / 2), METAL2, METALM)
		for _, sx in { -1, 1 } do
			deco(m, Vector3.new(0.4, 6.6, depth + 0.2), F(sx * (storeW / 2 + 0.2), 3.3, depth / 2), METAL2, METALM)
		end
		local glass = deco(m, Vector3.new(storeW, 6.2, 0.12), F(0, 3.5, depth), rgb(10, 14, 24), GLASS)
		glass.Transparency = 0.45
		glass.Reflectance = 0.25
		neon(m, Vector3.new(storeW - 0.2, 0.18, 0.18), F(0, 6.4, depth * 0.5), accent)
		local inner = deco(m, Vector3.new(0.2, 0.2, 0.2), F(0, 4, 0.5), accent)
		inner.Transparency = 1
		pointLight(inner, accent, 12, 0.9)
		for x = -storeW / 2 + 1, storeW / 2 - 1, 1.3 do
			if chance(0.6) then
				local sh = rr(0.6, 2.4)
				deco(m, Vector3.new(0.9, sh, 0.5), F(x, 0.6 + sh / 2, 0.35), pick(PRODUCT_COLS), if chance(0.3) then NEON else SMOOTH).Transparency = 0.1
			end
		end
		deco(m, Vector3.new(storeW, 0.1, 0.8), F(0, 2.4, 0.45), METAL3, METALM)
		local mx = -storeW / 2 + 3
		while mx < storeW / 2 - 1 do
			deco(m, Vector3.new(0.15, 6.2, 0.2), F(mx, 3.5, depth + 0.05), METAL3, METALM)
			mx += 3.2
		end
	else
		-- rolling shutter with abstract neon tag
		deco(m, Vector3.new(storeW, 6.4, 0.25), F(0, 3.2, 0.12), rgb(40, 42, 52), METALM)
		for y = 0.3, 6.2, 0.45 do
			deco(m, Vector3.new(storeW, 0.08, 0.1), F(0, y, 0.28), rgb(28, 30, 38), METALM)
		end
		deco(m, Vector3.new(storeW + 0.5, 0.9, 0.9), F(0, 6.85, 0.45), METAL2, METALM)
		local tagC = pick({ CYAN, MAG, LIME })
		local p = Vector3.new(rr(-storeW / 3, storeW / 3), rr(2, 4), 0)
		for _ = 1, ri(4, 7) do
			local q = p + Vector3.new(rr(-1.6, 1.6), rr(-1, 1), 0)
			q = Vector3.new(math.clamp(q.X, -storeW / 2 + 0.5, storeW / 2 - 0.5), math.clamp(q.Y, 1, 5.6), 0)
			seg(m, F(p.X, p.Y, 0.36).Position, F(q.X, q.Y, 0.36).Position, 0.12, tagC, NEON)
			p = q
		end
	end

	-- canopy
	deco(m, Vector3.new(storeW + 1, 0.35, 2.6), F(0, 7.7, 1.3), METAL2, METALM)
	neon(m, Vector3.new(storeW + 1, 0.14, 0.14), F(0, 7.5, 2.58), accent, true)
	for _, sx in { -1, 1 } do
		seg(m, F(sx * storeW / 2, 7.85, 2.5).Position, F(sx * storeW / 2, 10.5, 0).Position, 0.1, METAL3, METALM)
	end

	-- upper floors
	windowGrid(m, cf * CFrame.new(0, 0, fz), w - 2, h, 0.32, 10.5, 3.6)
	for ly = 12.3, h - 2, 7.2 do
		deco(m, Vector3.new(w + 0.3, 0.3, 0.4), F(0, ly, 0.15), METAL, CONCRETE)
	end

	-- cornice + neon band
	box(m, Vector3.new(w + 0.6, 0.8, d + 0.6), cf * CFrame.new(0, h + 0.4, 0), METAL2, METALM)
	if chance(0.7) then
		neon(m, Vector3.new(w + 0.25, 0.22, d + 0.25), cf * CFrame.new(0, h - 1.0, 0), accent, true)
	end

	-- wall-mounted AC units with drip pipes
	for _ = 1, ri(0, 2) do
		local x = rr(-w / 2 + 2, w / 2 - 2)
		local y = rr(10, math.max(11, h - 3))
		local acf = F(x, y, 0.75)
		deco(m, Vector3.new(2.2, 1.4, 1.4), acf, rgb(52, 54, 66), METALM)
		cyl(m, 0.12, 1.1, acf * CFrame.new(0.3, 0, -0.72) * CFrame.Angles(0, PI / 2, 0), RUBBER).CanCollide = false
		ring(m, "Grill", acf * CFrame.new(0.3, 0, -0.74) * CFrame.Angles(PI / 2, 0, 0), 0.55, 0.06, 0.06, 14, METAL3, false)
		seg(m, (acf * CFrame.new(-0.9, -0.7, 0)).Position, Vector3.new((acf * CFrame.new(-0.9, 0, 0)).Position.X, 0.5, (acf * CFrame.new(-0.9, 0, 0)).Position.Z), 0.1, METAL3, METALM)
	end

	-- vertical pipe up a corner
	local px = if chance(0.5) then -w / 2 + 0.5 else w / 2 - 0.5
	cylY(m, h, 0.5, F(px, h / 2, 0.35), rgb(60, 58, 64), METALM).CanCollide = false
	for y = 2, h - 1, 4 do
		deco(m, Vector3.new(0.7, 0.2, 0.6), F(px, y, 0.3), METAL3, METALM)
	end

	-- projecting glyph sign
	if chance(0.45) and h > 14 then
		local sx = if px < 0 then 1 else -1
		local scf = F(sx * (w / 2 - 1.4), math.min(h - 5, 12 + rr(0, 4)), 2.4) * CFrame.Angles(0, PI / 2, 0)
		verticalSign(m, scf, ri(4, 6), 1.8, pick({ CYAN, MAG, RED, LIME }), pick({ CYAN, MAG }))
		deco(m, Vector3.new(0.3, 0.3, 2.6), F(sx * (w / 2 - 1.4), math.min(h - 5, 12) + 3, 1.2), METAL3, METALM)
	end

	-- roof clutter
	local roofY = h + 0.8
	local function R(x: number, z: number): CFrame
		return cf * CFrame.new(x, roofY, z)
	end
	-- parapet lip
	for _, sz in { -d / 2 + 0.2, d / 2 - 0.2 } do
		deco(m, Vector3.new(w, 0.8, 0.3), R(0, sz) * CFrame.new(0, 0.4, 0), col, CONCRETE)
	end
	if chance(0.7) then
		acUnit(m, R(rr(-w / 2 + 3, w / 2 - 3), rr(-1, 2)) * CFrame.Angles(0, PI * ri(0, 1), 0))
	end
	local r = rng:NextNumber()
	if r < 0.35 then
		antenna(m, R(rr(-w / 2 + 2, w / 2 - 2), 2).Position, rr(5, 12))
	elseif r < 0.6 then
		dish(m, R(rr(-w / 2 + 3, w / 2 - 3), 1.5) * CFrame.Angles(0, rr(-0.6, 0.6), 0), rr(2.6, 4.2))
	elseif r < 0.8 then
		-- water tank on legs
		local tcf = R(rr(-w / 2 + 3, w / 2 - 3), 1.5)
		for _, lx in { -1, 1 } do
			for _, lz in { -1, 1 } do
				deco(m, Vector3.new(0.25, 3, 0.25), tcf * CFrame.new(lx * 1.1, 1.5, lz * 1.1), METAL3, METALM)
			end
		end
		cylY(m, 3, 3.2, tcf * CFrame.new(0, 4.5, 0), rgb(40, 36, 40), METALM).CastShadow = false
		ring(m, "TankBand", tcf * CFrame.new(0, 4.5, 0), 1.65, 0.12, 0.2, 20, METAL3, false)
	end
	-- roof access box
	if chance(0.5) then
		box(m, Vector3.new(3, 2.6, 3), R(rr(-w / 2 + 2, w / 2 - 2), 2.5) * CFrame.new(0, 1.3, 0), col, CONCRETE).CastShadow = false
	end
	return (cf * CFrame.new(rr(-w / 3, w / 3), h + 0.8, fz)).Position
end

local function buildFacades(root: Instance)
	local m = model(root, "Facades")
	local anchors: { { Vector3 } } = {}
	for side = 0, 3 do
		local R = CFrame.Angles(0, side * PI / 2, 0)
		local x = -126
		local sideAnchors: { Vector3 } = {}
		while x < 126 do
			local w = math.min(rr(16, 28), 126 - x)
			if w < 7 then
				break
			end
			local d = 10
			local lo, hi = x, x + w
			if side == 2 and hi > -31 and lo < 31 then
				-- leave the leaderboard gap (south)
				x = 31
				continue
			end
			local h = rr(18, 32)
			local cfB = R * CFrame.new(x + w / 2, 0, -(HALF + d / 2)) * CFrame.Angles(0, PI, 0)
			table.insert(sideAnchors, facadeBlock(m, cfB, w, h, d))
			x += w
			if chance(0.22) then
				-- alley: gap + dumpster + crossing cable
				local gap = rr(4, 6)
				local acf = R * CFrame.new(x + gap / 2, 0, -(HALF + 6)) * CFrame.Angles(0, PI, 0)
				box(m, Vector3.new(3.4, 2.2, 2), acf * CFrame.new(0, 1.1, 0), rgb(30, 50, 40), METALM).CastShadow = false
				deco(m, Vector3.new(3.6, 0.2, 2.2), acf * CFrame.new(0, 2.3, 0) * CFrame.Angles(0.15, 0, 0), rgb(24, 40, 32), METALM)
				x += gap
			end
		end
		table.insert(anchors, sideAnchors)
	end
	-- corner towers
	for i = 0, 3 do
		local a = i * PI / 2 + PI / 4
		local p = Vector3.new(math.cos(a) * 138 * math.sqrt(2), 0, math.sin(a) * 138 * math.sqrt(2))
		facadeBlock(m, CFrame.lookAt(p, Vector3.zero), 12, rr(30, 38), 12)
	end
	-- cables between neighbouring rooftops + across the corners
	local cm = model(root, "Cables")
	for _, list in anchors do
		for i = 1, #list - 1 do
			if chance(0.75) then
				local a, b = list[i], list[i + 1]
				cable(cm, a + Vector3.new(0, -1.5, 0), b + Vector3.new(0, -2, 0), rr(1.5, 4), 0.14, RUBBER)
				if chance(0.4) then
					cable(cm, a + Vector3.new(0, -2.5, 0), b + Vector3.new(0, -3, 0), rr(2.5, 5), 0.1, pick({ CYAN, MAG }), true)
				end
			end
		end
	end
	for i = 1, 4 do
		local A = anchors[i]
		local B = anchors[(i % 4) + 1]
		if #A > 0 and #B > 0 then
			local a, b = A[#A], B[1]
			cable(cm, a, b, rr(6, 10), 0.16, RUBBER)
			cable(cm, a + Vector3.new(0, -1, 0), b + Vector3.new(0, -1, 0), rr(8, 12), 0.1, pick({ CYAN, MAG }), true)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Skyline
---------------------------------------------------------------------------------------------------

local TOWER_COLS = { rgb(10, 11, 17), rgb(13, 14, 21), rgb(9, 10, 14), rgb(15, 13, 20), rgb(11, 13, 18) }

local function skyscraper(parent: Instance, cf: CFrame, w: number, d: number, h: number, sideWindows: boolean, step: number)
	local m = model(parent, "Tower")
	local col = pick(TOWER_COLS)
	local mat = if chance(0.5) then CONCRETE else SMOOTH
	local accent = pick({ CYAN, MAG, CYAN, MAG, RED })
	local twoTier = h > 100 and chance(0.65)
	local h1 = if twoTier then h * rr(0.55, 0.72) else h

	local function tier(tw: number, td: number, y0: number, th: number)
		local body = box(m, Vector3.new(tw, th, td), cf * CFrame.new(0, y0 + th / 2, 0), col, mat)
		body.CastShadow = false
		body.Reflectance = if mat == SMOOTH then 0.1 else 0
		windowGrid(m, cf * CFrame.new(0, y0, -td / 2), tw - 2, th, rr(0.16, 0.36), 4, step, if step > 4 then 4.2 else 3.2)
		if sideWindows then
			windowGrid(m, cf * CFrame.new(-tw / 2, y0, 0) * CFrame.Angles(0, PI / 2, 0), td - 2, th, rr(0.08, 0.2), 4, step)
			windowGrid(m, cf * CFrame.new(tw / 2, y0, 0) * CFrame.Angles(0, -PI / 2, 0), td - 2, th, rr(0.08, 0.2), 4, step)
		end
		for ly = y0 + 4 * step - step / 2, y0 + th - 3, 4 * step do
			deco(m, Vector3.new(tw + 0.5, 0.45, td + 0.5), cf * CFrame.new(0, ly, 0), METAL, METALM)
		end
		box(m, Vector3.new(tw + 0.4, 1.2, td + 0.4), cf * CFrame.new(0, y0 + th + 0.6, 0), METAL2, METALM).CastShadow = false
		if chance(0.6) then
			neon(m, Vector3.new(tw + 0.3, 0.35, td + 0.3), cf * CFrame.new(0, y0 + th - 1.5, 0), accent, true)
		end
		if chance(0.45) then
			for _, sx in { -1, 1 } do
				neon(m, Vector3.new(0.4, th, 0.4), cf * CFrame.new(sx * tw / 2, y0 + th / 2, -td / 2), accent, true)
			end
		end
		-- aircraft lights on corners
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				if chance(0.6) then
					local l = neon(m, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(sx * (tw / 2 - 0.4), y0 + th + 1.5, sz * (td / 2 - 0.4)), RED)
					blink(l, rr(0.4, 0.7), 0.18)
				end
			end
		end
	end

	tier(w, d, 0, h1)
	local topY = h1 + 1.2
	local topW, topD = w, d
	if twoTier then
		topW, topD = w * rr(0.55, 0.8), d * rr(0.55, 0.8)
		tier(topW, topD, topY, h - h1)
		topY = h + 1.2
	end

	-- roof machinery
	box(m, Vector3.new(topW * 0.4, 4, topD * 0.4), cf * CFrame.new(rr(-topW * 0.2, topW * 0.2), topY + 2, rr(-topD * 0.2, topD * 0.2)), col, CONCRETE).CastShadow = false
	if chance(0.75) then
		local ah = rr(12, 30)
		local mast = cylY(m, ah, 0.7, cf * CFrame.new(0, topY + ah / 2, 0), METAL3, METALM)
		mast.CastShadow = false
		for k = 1, 3 do
			deco(m, Vector3.new(rr(2, 4), 0.25, 0.25), cf * CFrame.new(0, topY + ah * k / 4, 0) * CFrame.Angles(0, rr(0, PI), 0), METAL3, METALM)
		end
		local tip = neon(m, Vector3.new(1, 1, 1), cf * CFrame.new(0, topY + ah + 0.5, 0), RED)
		tip.Shape = Enum.PartType.Ball
		blink(tip, rr(0.5, 0.9), 0.2)
	end
	if chance(0.3) then
		dish(m, cf * CFrame.new(topW * 0.3, topY, topD * 0.25) * CFrame.Angles(0, PI + rr(-0.5, 0.5), 0), rr(4, 7))
	end

	-- giant glyph sign on the front
	local cells = ri(6, 10)
	local cs = 4.5
	local sh = cells * cs * 1.3
	if chance(0.32) and h1 > sh + 22 then
		local y = rr(sh / 2 + 10, h1 - sh / 2 - 6)
		verticalSign(m, cf * CFrame.new(rr(-w / 3, w / 3), y, -d / 2 - 1.6), cells, cs, pick({ CYAN, MAG, RED, LIME, AMBER }), pick({ CYAN, MAG }))
	elseif chance(0.25) and h1 > 50 then
		local bw = math.min(w - 4, 30)
		local bh = bw * 0.5
		holoBoard(m, cf * CFrame.new(0, rr(bh + 10, h1 - bh / 2 - 4), -d / 2 - 1.2), bw, bh, pick({ CYAN, MAG }), nil)
	end
end

local function buildSkyline(root: Instance)
	local m = model(root, "Skyline")
	local function row(dist: number, hMin: number, hMax: number, sideWin: boolean, step: number)
		for side = 0, 3 do
			local R = CFrame.Angles(0, side * PI / 2, 0)
			local x = -dist + rr(0, 6)
			while x < dist - 10 do
				local w = rr(20, 38)
				local d = rr(20, 34)
				local h = rr(hMin, hMax)
				local off = rr(0, 10)
				skyscraper(m, R * CFrame.new(x + w / 2, 0, -(dist + off + d / 2)) * CFrame.Angles(0, PI, 0), w, d, h, sideWin, step)
				x += w + rr(3, 10)
			end
		end
	end
	row(152, 55, 130, true, 4)
	row(215, 110, 200, false, 6)
	-- corner towers between the rows
	for i = 0, 3 do
		local a = i * PI / 2 + PI / 4
		for _, r in { 182 * math.sqrt(2), 250 * math.sqrt(2) } do
			local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			skyscraper(m, CFrame.lookAt(p, Vector3.zero), rr(28, 40), rr(28, 40), rr(120, 210), false, 6)
		end
	end
	-- far horizon silhouettes (no windows, just trims + red lights)
	local fm = model(root, "Horizon")
	for i = 0, 41 do
		local a = i / 42 * PI * 2 + rr(-0.03, 0.03)
		local r = rr(320, 380)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local w = rr(30, 60)
		local h = rr(140, 280)
		local cf = CFrame.lookAt(p, Vector3.zero)
		box(fm, Vector3.new(w, h, w * 0.8), cf * CFrame.new(0, h / 2, 0), rgb(7, 7, 11), SMOOTH).CastShadow = false
		if chance(0.6) then
			neon(fm, Vector3.new(0.8, h * rr(0.4, 0.9), 0.8), cf * CFrame.new(rr(-w / 2, w / 2), h * 0.45, -w * 0.4), scaleColor(pick({ CYAN, MAG }), 0.6), true)
		end
		local l = neon(fm, Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(0, h + 1, 0), RED)
		blink(l, rr(0.3, 0.6), 0.2)
	end
end

---------------------------------------------------------------------------------------------------
-- Districts: server yards, lounge, lamps, billboards, barriers
---------------------------------------------------------------------------------------------------

local function buildYards(root: Instance)
	-- NW server yard
	local nw = model(root, "ServerYardNW")
	local o = CFrame.new(-100, 0, -100)
	local floor = box(nw, Vector3.new(34, 0.3, 30), o * CFrame.new(0, 0.15, 0), rgb(18, 19, 26), DIAMOND)
	floor.CastShadow = false
	neon(nw, Vector3.new(34.1, 0.08, 0.15), o * CFrame.new(0, 0.32, 15), CYAN, true)
	neon(nw, Vector3.new(0.15, 0.08, 30.1), o * CFrame.new(17, 0.32, 0), CYAN, true)
	for row = 0, 1 do
		for i = 0, 5 do
			local cf = o * CFrame.new(-12.5 + i * 5, 0.3, -7 + row * 12) * CFrame.Angles(0, if row == 0 then PI else 0, 0)
			serverRack(nw, cf, if (i + row) % 3 == 0 then MAG else CYAN)
		end
	end
	cableTray(nw, (o * CFrame.new(-15, 11, -1)).Position, (o * CFrame.new(15, 11, -1)).Position)
	for _, x in { -15, 0, 15 } do
		deco(nw, Vector3.new(0.4, 11, 0.4), o * CFrame.new(x, 5.6, -1), METAL3, METALM)
	end
	for i = 0, 5 do
		cable(nw, (o * CFrame.new(-12.5 + i * 5, 9.6, -7)).Position, (o * CFrame.new(-12.5 + i * 5, 10.9, -1.5)).Position, 0.6, 0.16, RUBBER)
		cable(nw, (o * CFrame.new(-12.5 + i * 5, 9.6, 5)).Position, (o * CFrame.new(-12.5 + i * 5, 10.9, -0.5)).Position, 0.6, 0.16, RUBBER)
	end
	for _ = 1, 3 do
		acUnit(nw, o * CFrame.new(rr(-14, 14), 0.3, 12.5) * CFrame.Angles(0, PI, 0))
	end
	crateStack(nw, o * CFrame.new(-21, 0, 10))
	for i = 0, 4 do
		barrier(nw, o * CFrame.new(20, 0, -12 + i * 6.4) * CFrame.Angles(0, PI / 2, 0))
	end

	-- NE: raised comms platform with dishes + racks
	local ne = model(root, "CommsYardNE")
	local p = CFrame.new(100, 0, -100)
	box(ne, Vector3.new(32, 2, 30), p * CFrame.new(0, 1, 0), METAL, DIAMOND)
	neon(ne, Vector3.new(32.1, 0.12, 0.12), p * CFrame.new(0, 2, 15), MAG, true)
	neon(ne, Vector3.new(0.12, 0.12, 30.1), p * CFrame.new(-16, 2, 0), MAG, true)
	-- steps
	for k = 0, 3 do
		box(ne, Vector3.new(8, 0.5, 1.2), p * CFrame.new(-6, 0.25 + k * 0.5, 15.6 + (3 - k) * 1.2), METAL2, DIAMOND)
	end
	-- railing
	for x = -15, 15, 2.5 do
		deco(ne, Vector3.new(0.15, 2, 0.15), p * CFrame.new(x, 3, 14.6), METAL3, METALM)
	end
	deco(ne, Vector3.new(30, 0.15, 0.15), p * CFrame.new(0, 4, 14.6), METAL3, METALM)
	dish(ne, p * CFrame.new(-8, 2, -6) * CFrame.Angles(0, PI * 0.85, 0), 8)
	dish(ne, p * CFrame.new(6, 2, -8) * CFrame.Angles(0, PI * 1.2, 0), 6)
	dish(ne, p * CFrame.new(10, 2, 4) * CFrame.Angles(0, PI * 1.5, 0), 4.5)
	antenna(ne, (p * CFrame.new(-12, 2, 8)).Position, 18)
	antenna(ne, (p * CFrame.new(13, 2, -12)).Position, 14)
	for i = 0, 3 do
		serverRack(ne, p * CFrame.new(-4 + i * 4.4, 2, 9) * CFrame.Angles(0, 0, 0), if i % 2 == 0 then MAG else CYAN)
	end
	acUnit(ne, p * CFrame.new(-12, 2, -12))
	acUnit(ne, p * CFrame.new(-7, 2, -12.5))
	pipeRun(ne, (p * CFrame.new(-16, 3, -14)).Position, (p * CFrame.new(16, 3, -14)).Position, 0.8, rgb(60, 58, 70))
	pipeRun(ne, (p * CFrame.new(-16, 4.2, -14)).Position, (p * CFrame.new(16, 4.2, -14)).Position, 0.5, rgb(80, 40, 60))

	-- SE lounge: vending row, benches, planters, crates
	local se = model(root, "LoungeSE")
	for i = 0, 4 do
		vendingMachine(se, CFrame.new(126.5, 0.4, 70 + i * 4) * CFrame.Angles(0, PI / 2, 0), pick({ CYAN, MAG, RED, LIME }))
	end
	for i = 0, 2 do
		vendingMachine(se, CFrame.new(-126.5, 0.4, -20 - i * 4) * CFrame.Angles(0, -PI / 2, 0), pick({ CYAN, MAG, RED }))
	end
	for i = 0, 3 do
		bench(se, CFrame.new(98, 0, 62 + i * 10) * CFrame.Angles(0, -PI / 2, 0), if i % 2 == 0 then CYAN else MAG)
	end
	for i = 0, 2 do
		cyberTree(se, CFrame.new(108, 0, 66 + i * 12), pick({ CYAN, MAG, LIME }))
	end
	crateStack(se, CFrame.new(110, 0, 112))
	crateStack(se, CFrame.new(-112, 0, 112))
	crateStack(se, CFrame.new(118, 0, -50))
	-- benches around the plaza, only in the sectors between the walkways
	-- (walkways run from spawn to Lab 0°, Leaderboard 90°, Index ~132°, Forge 180°, Core 270°)
	for i, deg in { 40, 62, 222, 246, 296, 320 } do
		local a = math.rad(deg)
		local pos = Vector3.new(math.cos(a) * 38, 0, math.sin(a) * 38)
		bench(se, CFrame.lookAt(pos, Vector3.zero), if i % 2 == 0 then CYAN else MAG)
	end
	for _, pos in { Vector3.new(-34, 0, 34), Vector3.new(34, 0, 34), Vector3.new(-40, 0, -24), Vector3.new(40, 0, -24) } do
		cyberTree(se, CFrame.new(pos), pick({ CYAN, MAG }))
	end
	-- barrier lines
	for i = 0, 3 do
		barrier(se, CFrame.new(-40 + i * 6.4, 0, 112) * CFrame.Angles(0, 0, 0))
	end
	for i = 0, 3 do
		barrier(se, CFrame.new(40 + i * 6.4, 0, 112))
	end

	-- pipes along every facade base
	local pm = model(root, "FacadePipes")
	for side = 0, 3 do
		local R = CFrame.Angles(0, side * PI / 2, 0)
		for _, seg2 in { { -124, -40 }, { 40, 124 } } do
			pipeRun(pm, (R * CFrame.new(seg2[1], 1.2, -(HALF - 0.6))).Position, (R * CFrame.new(seg2[2], 1.2, -(HALF - 0.6))).Position, 0.7, rgb(56, 54, 62))
			pipeRun(pm, (R * CFrame.new(seg2[1], 2.0, -(HALF - 0.5))).Position, (R * CFrame.new(seg2[2], 2.0, -(HALF - 0.5))).Position, 0.4, rgb(70, 40, 56))
		end
	end
end

local function buildLamps(root: Instance)
	local m = model(root, "Lamps")
	local spots = {
		Vector3.new(-24, 0, 14), Vector3.new(24, 0, 14), Vector3.new(-24, 0, -22), Vector3.new(24, 0, -22),
		Vector3.new(-56, 0, -40), Vector3.new(56, 0, -40), Vector3.new(-56, 0, 40), Vector3.new(56, 0, 40),
		Vector3.new(-110, 0, -40), Vector3.new(110, 0, -40), Vector3.new(-110, 0, 40), Vector3.new(110, 0, 40),
		Vector3.new(-30, 0, 104), Vector3.new(30, 0, 104), Vector3.new(-30, 0, -112), Vector3.new(30, 0, -112),
		Vector3.new(-90, 0, 110), Vector3.new(90, 0, 112), Vector3.new(-120, 0, 0), Vector3.new(120, 0, 0),
	}
	for i, p in spots do
		local toC = (Vector3.zero - p)
		streetLamp(m, p, toC, if i % 3 == 0 then MAG else CYAN)
	end
	-- long cables across the plaza from lamps to facades
	local cm = model(root, "SkyCables")
	for _, p in spots do
		if math.max(math.abs(p.X), math.abs(p.Z)) > 80 then
			local edge = if math.abs(p.X) > math.abs(p.Z)
				then Vector3.new(math.sign(p.X) * (HALF + 0.5), 0, p.Z + rr(-12, 12))
				else Vector3.new(p.X + rr(-12, 12), 0, math.sign(p.Z) * (HALF + 0.5))
			local head = p + (Vector3.zero - p).Unit * 4.4 + Vector3.new(0, 15, 0)
			cable(cm, head, edge + Vector3.new(0, rr(16, 20), 0), rr(2, 4), 0.12, RUBBER)
			if chance(0.5) then
				cable(cm, head + Vector3.new(0, -0.4, 0), edge + Vector3.new(0, rr(14, 16), 0), rr(3, 5), 0.08, pick({ CYAN, MAG }), true)
			end
		end
	end
end

local function buildBillboards(root: Instance)
	local m = model(root, "Billboards")
	-- flanking the core
	freeBoard(m, CFrame.lookAt(Vector3.new(-36, 0, -86), Vector3.new(0, 0, 0)), 18, 10, CYAN, "SYS://FEED_07")
	freeBoard(m, CFrame.lookAt(Vector3.new(36, 0, -86), Vector3.new(0, 0, 0)), 18, 10, MAG, "KERNEL.LOG")
	-- on facade fronts (mounted high, facing the plaza)
	type Mount = { cf: CFrame, color: Color3, header: string }
	local mounts: { Mount } = {
		{ cf = CFrame.Angles(0, PI / 2, 0) * CFrame.new(-60, 13, -(HALF - 1.2)), color = CYAN, header = "NODE.MONITOR" },
		{ cf = CFrame.Angles(0, -PI / 2, 0) * CFrame.new(50, 13, -(HALF - 1.2)), color = MAG, header = "TRACE_ROUTE" },
		{ cf = CFrame.Angles(0, -PI / 2, 0) * CFrame.new(-55, 13, -(HALF - 1.2)), color = CYAN, header = "RNG.SEED" },
		{ cf = CFrame.Angles(0, PI / 2, 0) * CFrame.new(70, 13, -(HALF - 1.2)), color = RED, header = "WARN.STACK" },
	}
	for _, mt in mounts do
		-- turn around so the screen faces the plaza
		local cf = mt.cf * CFrame.Angles(0, PI, 0)
		holoBoard(m, cf, 16, 9, mt.color, mt.header)
		for _, sx in { -5, 5 } do
			deco(m, Vector3.new(0.4, 0.4, 2), cf * CFrame.new(sx, 0, 1.2), METAL3, METALM)
		end
	end
	-- vertical glyph signs above the attractions' approach
	for _, p in { Vector3.new(-46, 0, -64), Vector3.new(46, 0, -64), Vector3.new(-100, 0, 22), Vector3.new(100, 0, 22), Vector3.new(-40, 0, 92) } do
		local base = CFrame.lookAt(p, Vector3.new(0, 0, 0))
		box(m, Vector3.new(1, 20, 1), base * CFrame.new(0, 10, 0.8), METAL2, METALM)
		box(m, Vector3.new(2.2, 0.6, 2.2), base * CFrame.new(0, 0.3, 0.8), METAL, METALM)
		verticalSign(m, base * CFrame.new(0, 14, 0), ri(5, 7), 1.9, pick({ CYAN, MAG, RED, LIME }), pick({ CYAN, MAG }))
	end
end

local function buildWalls(root: Instance)
	local f = Instance.new("Folder")
	f.Name = "InvisibleWalls"
	f.Parent = root
	for side = 0, 3 do
		local R = CFrame.Angles(0, side * PI / 2, 0)
		local p = box(f, Vector3.new(HALF * 2 + 4, 400, 2), R * CFrame.new(0, 200, -(HALF - 0.5)), DARK)
		p.Transparency = 1
		p.CastShadow = false
		p.CanQuery = false
		p.Name = "Wall"
	end
	local ceiling = box(f, Vector3.new(HALF * 2, 2, HALF * 2), CFrame.new(0, 300, 0), DARK)
	ceiling.Transparency = 1
	ceiling.CastShadow = false
	ceiling.CanQuery = false
end

---------------------------------------------------------------------------------------------------
-- Lighting
---------------------------------------------------------------------------------------------------

local function setupLighting()
	-- Technology (Future) is set in default.project.json; scripts are not allowed to change it.
	Lighting.ClockTime = 0.2
	Lighting.GlobalShadows = true

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.36
	atmo.Offset = 0.22
	atmo.Color = rgb(58, 32, 92)
	atmo.Decay = rgb(24, 12, 44)
	atmo.Glare = 0.15
	atmo.Haze = 1.8
	atmo.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 1
	bloom.Size = 32
	bloom.Threshold = 0.9
	bloom.Parent = Lighting

	local cc = Lighting:FindFirstChild("BiomeCC") :: ColorCorrectionEffect?
	if not cc then
		local c = Instance.new("ColorCorrectionEffect")
		c.Name = "BiomeCC"
		cc = c
	end
	assert(cc)
	cc.Brightness = 0
	cc.Contrast = 0.08
	cc.Saturation = 0.1
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Parent = Lighting

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Enabled = false
	rays.Parent = Lighting

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 3000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting
end

---------------------------------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------------------------------

local built = false

function Map.Build()
	if built then
		return
	end
	built = true
	setupLighting()

	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Map"

	buildFloor(root)
	buildSpawn(root)
	Map.Positions.Core = buildCore(root)

	local forge = buildTerminal(root, "Forge", "RIG FORGE", "RIG_FORGE.EXE", FORGE_POS, MAG, AMBER, {
		">> ACCESS GRANTED",
		"rig.blueprints ...... 06",
		"thermal ok / arm ready",
		"feed auras -> build rig",
	})
	Map.Positions.Forge = forge.Position
	local lab = buildTerminal(root, "Lab", "SCRIPT LAB", "SCRIPT_LAB.EXE", LAB_POS, LIME, CYAN, {
		">> COMPILER ONLINE",
		"luck.exe  speed.exe",
		"breach.exe [UNSTABLE]",
		"mix auras -> compile",
	})
	Map.Positions.Lab = lab.Position
	local index = buildTerminal(root, "Index", "AURA INDEX", "AURA_INDEX.DB", INDEX_POS, CYAN, MAG, {
		">> ARCHIVE MOUNTED",
		string.format("entries ...... %d", #Config.Auras),
		"tiers BASIC..SINGULARITY",
		"browse discovered auras",
	})
	Map.Positions.Index = index.Position

	-- approach markings from spawn to each terminal and the core
	local marks = model(root, "Markings")
	pathMarkings(marks, Vector3.zero, FORGE_POS, MAG)
	pathMarkings(marks, Vector3.zero, LAB_POS, LIME)
	pathMarkings(marks, Vector3.zero, INDEX_POS, CYAN)
	pathMarkings(marks, Vector3.zero, CORE_POS + Vector3.new(0, 0, 14), CYAN)

	local screen = buildLeaderboard(root)
	Map.Positions.Leaderboard = screen.Position

	buildFacades(root)
	buildSkyline(root)
	buildYards(root)
	buildLamps(root)
	buildBillboards(root)
	buildWalls(root)

	root.Parent = workspace

	local count = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	print(string.format("[Map] built %d parts", count))
end

return Map
