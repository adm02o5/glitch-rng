--!strict
-- Boot screen (ReplicatedFirst, runs before anything else replicates):
--   1. PHOTOSENSITIVITY WARNING card (must be acknowledged; offers REDUCE FLASHING),
--   2. the GLITCH//OS loading screen: horizon grid, code rain, RGB-split glitch logo, a boot
--      terminal that reports the real loading stages, segmented progress bar, rotating tips,
--   3. ENTER THE GRID prompt -> glitch transition into the game.
--
-- Talks to the rest of the client through LocalPlayer attributes (no requires, Shared may not
-- exist yet when this starts):
--   Booting    true while this screen is up (music, tutorial wait for it)
--   CalmPick   the reduced-flashing choice made on the warning card (Main.client saves it)
--   CalmSaved  set by Main.client: the saved setting (pre-selects the switch)
--   SkipBoot   set by tests: close immediately
--   BootAck / BootEnter   set by tests: press I UNDERSTAND / ENTER

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local player = Players.LocalPlayer
player:SetAttribute("Booting", true)
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------- theme (mirrors Config.Palette)

local rgb = Color3.fromRGB
local BG = rgb(6, 7, 12)
local PANEL = rgb(12, 14, 22)
local LINE = rgb(38, 44, 66)
local TEXT = rgb(230, 236, 255)
local DIM = rgb(120, 130, 160)
local CYAN = rgb(0, 240, 255)
local MAGENTA = rgb(255, 43, 214)
local LIME = rgb(80, 255, 140)
local AMBER = rgb(255, 176, 32)
local RED = rgb(255, 31, 61)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)
local MONO_B = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local TITLE = Font.new("rbxasset://fonts/families/Michroma.json")
local PIXEL = Font.new("rbxasset://fonts/families/PressStart2P.json")

local rng = Random.new()
local clamp, floor, sin, cos, abs, max, min = math.clamp, math.floor, math.sin, math.cos, math.abs, math.max, math.min

local function new(class: string, props: { [string]: any }): any
	local inst = Instance.new(class)
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function label(parent: Instance, text: string, size: number, props: { [string]: any }?): TextLabel
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		FontFace = MONO,
		TextColor3 = TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, size + 4),
		Parent = parent,
	})
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	return l
end

local function corner(parent: Instance, r: number)
	new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end

local function stroke(parent: Instance, color: Color3, th: number, tr: number?): UIStroke
	return new("UIStroke", {
		Color = color,
		Thickness = th,
		Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- L-shaped corner brackets around a frame
local function brackets(parent: GuiObject, color: Color3, len: number, th: number?, inset: number?)
	local t, i = th or 2, inset or -6
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local sx, sy = c[1], c[2]
		local px = if sx == 0 then i else -i
		local py = if sy == 0 then i else -i
		new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(sx, sy),
			Position = UDim2.new(sx, px, sy, py),
			Size = UDim2.fromOffset(len, t),
			ZIndex = parent.ZIndex + 1,
			Parent = parent,
		})
		new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(sx, sy),
			Position = UDim2.new(sx, px, sy, py),
			Size = UDim2.fromOffset(t, len),
			ZIndex = parent.ZIndex + 1,
			Parent = parent,
		})
	end
end

---------------------------------------------------------------- state

local calm = false -- reduced flashing (warning card / saved setting)
local calmTouched = false
local warned = false -- warning acknowledged
local ready = false -- everything loaded (or skipped)
local entering = false
local closed = false
local t0 = os.clock()

local sounds: { [string]: string } = {} -- filled once Shared/Sounds replicates
local music: Sound? = nil

local function sfx(name: string, vol: number, pitch: number?)
	local id = sounds[name]
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = vol
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(8, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

---------------------------------------------------------------- root layers

local gui = new("ScreenGui", {
	Name = "GlitchBoot",
	DisplayOrder = 1000,
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})
pcall(function()
	gui.ScreenInsets = Enum.ScreenInsets.None
end)

-- everything lives in `root` so the exit transition can turn it into one CanvasGroup
local root = new("Frame", { Name = "Root", BackgroundColor3 = BG, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = gui })

-- full-screen effects (unscaled)
local bg = new("Frame", { Name = "Bg", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = root })
-- UI drawn on a 1600x900-ish canvas scaled to the screen
local ui = new("Frame", { Name = "UI", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = root })
local uiScale = new("UIScale", { Parent = ui })
local canvas = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = ui })

local function viewport(): Vector2
	local cam = workspace.CurrentCamera
	local v = if cam then cam.ViewportSize else Vector2.new(1600, 900)
	if v.X < 10 then
		v = Vector2.new(1600, 900)
	end
	return v
end

local function rescale()
	local v = viewport()
	local k = clamp(min(v.X / 1600, v.Y / 900), 0.45, 1.3)
	uiScale.Scale = k
	canvas.Size = UDim2.fromScale(1 / k, 1 / k)
end
rescale()

---------------------------------------------------------------- background: sky glow + horizon grid

local HORIZON = 0.58 -- horizon height (fraction of the screen)
local sky = new("Frame", {
	Name = "Sky",
	BorderSizePixel = 0,
	BackgroundColor3 = WHITE,
	Size = UDim2.fromScale(1, HORIZON),
	ZIndex = 1,
	Parent = bg,
})
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, BG),
		ColorSequenceKeypoint.new(0.62, rgb(16, 10, 34)),
		ColorSequenceKeypoint.new(1, rgb(58, 14, 70)),
	}),
	Parent = sky,
})
local ground = new("Frame", {
	Name = "Ground",
	BorderSizePixel = 0,
	BackgroundColor3 = WHITE,
	Position = UDim2.fromScale(0, HORIZON),
	Size = UDim2.fromScale(1, 1 - HORIZON),
	ZIndex = 1,
	Parent = bg,
})
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(30, 6, 40)),
		ColorSequenceKeypoint.new(0.35, rgb(10, 6, 20)),
		ColorSequenceKeypoint.new(1, BG),
	}),
	Parent = ground,
})
-- horizon glow line + haze
local horizonLine = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = CYAN,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0, HORIZON),
	Size = UDim2.new(1, 0, 0, 2),
	ZIndex = 4,
	Parent = bg,
})
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.2),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = horizonLine,
})
local haze = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = MAGENTA,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0, HORIZON),
	Size = UDim2.new(1, 0, 0.16, 0),
	ZIndex = 2,
	Parent = bg,
})
new("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = haze,
})

-- data "sun": a striped half-disc sinking into the horizon behind the logo
local sun = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, HORIZON),
	Size = UDim2.fromScale(0.26, 0.26),
	ZIndex = 2,
	Parent = bg,
})
new("UIAspectRatioConstraint", { AspectRatio = 2, Parent = sun })
local sunDisc = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = WHITE,
	Size = UDim2.fromScale(1, 2),
	ZIndex = 2,
	Parent = sun,
})
corner(sunDisc, 9999)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 210, 90)),
		ColorSequenceKeypoint.new(0.3, MAGENTA),
		ColorSequenceKeypoint.new(0.5, rgb(90, 20, 160)),
		ColorSequenceKeypoint.new(1, rgb(90, 20, 160)),
	}),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 0.55),
	}),
	Parent = sunDisc,
})
sun.ClipsDescendants = true
local sunCuts: { Frame } = {}
for i = 1, 6 do
	local f = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = rgb(20, 8, 34),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.42 + i * 0.09),
		Size = UDim2.new(1, 0, 0, 2 + i),
		ZIndex = 3,
		Parent = sun,
	})
	sunCuts[i] = f
end

-- perspective grid: horizontal lines scroll toward the viewer, verticals fan out from the
-- vanishing point
local GRID_H = 16
local hLines: { Frame } = {}
for i = 1, GRID_H do
	hLines[i] = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = MAGENTA,
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 3,
		Parent = bg,
	})
end
local vHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = bg })
local function buildVerticals()
	vHolder:ClearAllChildren()
	local size = bg.AbsoluteSize
	if size.X < 10 then
		return
	end
	local vx, vy = size.X / 2, size.Y * HORIZON
	local by = size.Y
	for j = -14, 14 do
		local bx = vx + j * size.X * 0.09
		local dx, dy = bx - vx, by - vy
		local len = math.sqrt(dx * dx + dy * dy)
		local f = new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = MAGENTA,
			BackgroundTransparency = 0.45 + abs(j) * 0.025,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((vx + bx) / 2, (vy + by) / 2),
			Size = UDim2.fromOffset(len, if j == 0 then 2 else 1),
			Rotation = math.deg(math.atan2(dy, dx)),
			ZIndex = 3,
			Parent = vHolder,
		})
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.3),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Parent = f,
		})
	end
end
bg:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	buildVerticals()
	rescale()
end)
task.defer(buildVerticals)

---------------------------------------------------------------- background: code rain + motes

local GLYPHS = "01ABCDEF#$%&*+<>/\\|=?!アイウエオカキクケコサシスセソ"
local glyphList: { string } = {}
for _, c in utf8.codes(GLYPHS) do
	table.insert(glyphList, utf8.char(c))
end
local function glyph(): string
	return glyphList[rng:NextInteger(1, #glyphList)]
end

type Drop = { l: TextLabel, chars: { string }, y: number, speed: number, n: number }
local drops: { Drop } = {}
local RAIN_COLS = 30
for i = 1, RAIN_COLS do
	local n = rng:NextInteger(14, 30)
	local chars = table.create(n) :: { string }
	for k = 1, n do
		chars[k] = glyph()
	end
	local l = label(bg, table.concat(chars, "\n"), rng:NextInteger(12, 17), {
		FontFace = MONO_B,
		TextColor3 = if rng:NextNumber() < 0.7 then CYAN else LIME,
		TextTransparency = rng:NextNumber(0.78, 0.92),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale((i - 0.5) / RAIN_COLS + rng:NextNumber(-0.008, 0.008), -1),
		Size = UDim2.new(0, 20, 1.2, 0),
		ZIndex = 2,
	})
	l.LineHeight = 1.05
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.75, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = l,
	})
	drops[i] = { l = l, chars = chars, y = rng:NextNumber(-1.2, 1), speed = rng:NextNumber(0.07, 0.2), n = n }
end

type Mote = { f: Frame, x: number, y: number, vy: number, ph: number }
local motes: { Mote } = {}
for i = 1, 26 do
	local s = rng:NextInteger(2, 5)
	local f = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = if i % 3 == 0 then MAGENTA else CYAN,
		BackgroundTransparency = 0.4,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(s, s),
		ZIndex = 5,
		Parent = bg,
	})
	motes[i] = { f = f, x = rng:NextNumber(), y = rng:NextNumber(), vy = rng:NextNumber(0.01, 0.04), ph = rng:NextNumber(0, 6.28) }
end

-- CRT scanlines, a slow scan bar and a vignette over everything in the background
local scan = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = root })
for i = 0, 119 do
	new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.82,
		Position = UDim2.fromScale(0, i / 120),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 8,
		Parent = scan,
	})
end
local scanBar = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = CYAN,
	Size = UDim2.new(1, 0, 0.12, 0),
	ZIndex = 8,
	Parent = root,
})
new("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.85, 0.94),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = scanBar,
})
for _, d in { { 0, 0.5, 90 }, { 1, 0.5, 270 }, { 0.5, 0, 180 }, { 0.5, 1, 0 } } do
	local vert = d[3] == 0 or d[3] == 180
	local f = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = BLACK,
		AnchorPoint = Vector2.new(d[1], d[2]),
		Position = UDim2.fromScale(d[1], d[2]),
		Size = if vert then UDim2.fromScale(1, 0.28) else UDim2.fromScale(0.22, 1),
		ZIndex = 9,
		Parent = root,
	})
	new("UIGradient", {
		Rotation = d[3] :: number,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) }),
		Parent = f,
	})
end

---------------------------------------------------------------- HUD corners

local function cornerBlock(ax: number, ay: number, lines: { string }, color: Color3): { TextLabel }
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(ax, ay),
		Position = UDim2.new(ax, if ax == 0 then 34 else -34, ay, if ay == 0 then 26 else -26),
		Size = UDim2.fromOffset(420, #lines * 20),
		ZIndex = 12,
		Parent = canvas,
	})
	local out = {}
	for i, s in lines do
		out[i] = label(holder, s, if i == 1 then 15 else 13, {
			FontFace = if i == 1 then MONO_B else MONO,
			TextColor3 = if i == 1 then color else DIM,
			TextXAlignment = if ax == 0 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(0, (i - 1) * 20),
			Size = UDim2.new(1, 0, 0, 18),
			ZIndex = 12,
		})
	end
	return out
end

local tl = cornerBlock(0, 0, { "GLITCH//OS  v2.6", "kernel 6.6.6-rng · x64", "secure boot: COMPROMISED" }, CYAN)
local tr = cornerBlock(1, 0, { "00:00:00", "node ----", "uplink ···" }, MAGENTA)
local br = cornerBlock(1, 1, { "USER  " .. string.upper(player.DisplayName), "@" .. player.Name, "session " .. string.format("%04X", rng:NextInteger(0, 65535)) }, LIME)
tl[3].TextColor3 = RED
-- screen-corner brackets
for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
	local f = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(c[1], c[2]),
		Position = UDim2.new(c[1], if c[1] == 0 then 14 else -14, c[2], if c[2] == 0 then 12 else -12),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 12,
		Parent = canvas,
	})
	new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = CYAN,
		BackgroundTransparency = 0.3,
		AnchorPoint = Vector2.new(c[1], c[2]),
		Position = UDim2.fromScale(c[1], c[2]),
		Size = UDim2.fromOffset(40, 2),
		ZIndex = 12,
		Parent = f,
	})
	new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = CYAN,
		BackgroundTransparency = 0.3,
		AnchorPoint = Vector2.new(c[1], c[2]),
		Position = UDim2.fromScale(c[1], c[2]),
		Size = UDim2.fromOffset(2, 40),
		ZIndex = 12,
		Parent = f,
	})
end

---------------------------------------------------------------- logo (sliced, RGB split)

local LOGO_W, LOGO_H = 1100, 170
local logo = new("Frame", {
	Name = "Logo",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.33),
	Size = UDim2.fromOffset(LOGO_W, LOGO_H),
	ZIndex = 20,
	Parent = canvas,
})
local logoScale = new("UIScale", { Parent = logo })
local LOGO_TEXT = 'GLITCH<font color="#FF2BD6"> RNG</font>'
local SLICES = 9
type Slice = { f: Frame, inner: Frame, white: TextLabel, cy: TextLabel, mg: TextLabel, off: number }
local slices: { Slice } = {}
for i = 1, SLICES do
	local h = LOGO_H / SLICES
	local f = new("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, (i - 1) * h),
		Size = UDim2.new(1, 0, 0, math.ceil(h) + 1),
		ZIndex = 20,
		Parent = logo,
	})
	local inner = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, -(i - 1) * h),
		Size = UDim2.fromOffset(LOGO_W, LOGO_H),
		ZIndex = 20,
		Parent = f,
	})
	local function layer(color: Color3, tr: number, z: number): TextLabel
		return label(inner, LOGO_TEXT, 118, {
			FontFace = TITLE,
			RichText = true,
			TextColor3 = color,
			TextTransparency = tr,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = z,
		})
	end
	local cy = layer(CYAN, 0.25, 21)
	local mg = layer(MAGENTA, 0.25, 21)
	mg.Text = "GLITCH RNG"
	cy.Text = "GLITCH RNG"
	local white = layer(WHITE, 0, 22)
	slices[i] = { f = f, inner = inner, white = white, cy = cy, mg = mg, off = 0 }
end
-- underline sweep + tagline
local underline = new("Frame", {
	BorderSizePixel = 0,
	BackgroundColor3 = CYAN,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 2),
	Size = UDim2.new(0.82, 0, 0, 3),
	ZIndex = 20,
	Parent = logo,
})
local ulGrad = new("UIGradient", {
	Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, CYAN), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, MAGENTA) }),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 0.1),
		NumberSequenceKeypoint.new(0.6, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),
	Parent = underline,
})
local tagline = label(canvas, "", 20, {
	FontFace = MONO_B,
	TextColor3 = DIM,
	TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.33, LOGO_H / 2 + 20),
	Size = UDim2.fromOffset(900, 26),
	ZIndex = 20,
})
local TAGLINE = "// ROLL THE CORRUPTED CODE"

---------------------------------------------------------------- progress panel

local panel = new("Frame", {
	Name = "Progress",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.62),
	Size = UDim2.fromOffset(760, 120),
	ZIndex = 20,
	Parent = canvas,
})
local status = label(panel, "INITIALISING", 18, {
	FontFace = MONO_B,
	TextColor3 = CYAN,
	Position = UDim2.fromOffset(46, 4),
	Size = UDim2.new(1, -180, 0, 22),
	ZIndex = 21,
})
local pct = label(panel, "000%", 34, {
	FontFace = PIXEL,
	TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, -4),
	Size = UDim2.fromOffset(200, 36),
	ZIndex = 21,
})
-- hex spinner
local spinner = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(16, 15),
	Size = UDim2.fromOffset(30, 30),
	ZIndex = 21,
	Parent = panel,
})
local spinSegs: { Frame } = {}
for i = 0, 5 do
	local a = i / 6 * math.pi * 2
	spinSegs[i + 1] = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = CYAN,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, cos(a) * 12, 0.5, sin(a) * 12),
		Size = UDim2.fromOffset(9, 3),
		Rotation = math.deg(a) + 90,
		ZIndex = 21,
		Parent = spinner,
	})
end
-- segmented bar
local SEGS = 48
local barBox = new("Frame", {
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 40),
	Size = UDim2.new(1, 0, 0, 26),
	ZIndex = 20,
	Parent = panel,
})
stroke(barBox, LINE, 1)
brackets(barBox, CYAN, 12, 2, -5)
local segFrames: { Frame } = {}
for i = 1, SEGS do
	segFrames[i] = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = LINE,
		Position = UDim2.new((i - 1) / SEGS, 3, 0, 5),
		Size = UDim2.new(1 / SEGS, -3, 1, -10),
		ZIndex = 21,
		Parent = barBox,
	})
end
local detail = label(panel, "", 14, {
	TextColor3 = DIM,
	Position = UDim2.fromOffset(0, 74),
	Size = UDim2.new(0.7, 0, 0, 18),
	ZIndex = 21,
})
local count = label(panel, "", 14, {
	TextColor3 = DIM,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 74),
	Size = UDim2.new(0.3, 0, 0, 18),
	ZIndex = 21,
})

-- ENTER prompt (replaces the bar once everything is ready)
local enterBtn = new("TextButton", {
	Name = "Enter",
	AutoButtonColor = false,
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	Text = "",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.62, 18),
	Size = UDim2.fromOffset(460, 76),
	Visible = false,
	ZIndex = 30,
	Parent = canvas,
})
local enterStroke = stroke(enterBtn, CYAN, 2)
brackets(enterBtn, MAGENTA, 18, 3, -8)
local enterText = label(enterBtn, "▶  ENTER THE GRID", 28, {
	FontFace = TITLE,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 31,
})
local enterHint = label(canvas, "", 15, {
	TextColor3 = DIM,
	TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.62, 104),
	Size = UDim2.fromOffset(600, 18),
	Visible = false,
	ZIndex = 30,
})
local enterScale = new("UIScale", { Parent = enterBtn })

-- SKIP (appears if loading drags on)
local skipBtn = new("TextButton", {
	Name = "Skip",
	AutoButtonColor = false,
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	Text = "SKIP  ▶▶",
	TextColor3 = DIM,
	TextSize = 15,
	FontFace = MONO_B,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -34, 1, -96),
	Size = UDim2.fromOffset(130, 36),
	Visible = false,
	ZIndex = 30,
	Parent = canvas,
})
stroke(skipBtn, LINE, 1)

---------------------------------------------------------------- boot terminal

local term = new("Frame", {
	Name = "Terminal",
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 34, 1, -34),
	Size = UDim2.fromOffset(470, 196),
	ZIndex = 15,
	Parent = canvas,
})
stroke(term, LINE, 1)
local termHead = new("Frame", { BackgroundColor3 = LINE, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 22), ZIndex = 16, Parent = term })
label(termHead, "  boot.log — glitch://localhost", 12, {
	FontFace = MONO_B,
	TextColor3 = TEXT,
	Size = UDim2.fromScale(1, 1),
	TextYAlignment = Enum.TextYAlignment.Center,
	ZIndex = 17,
})
for i, c in { RED, AMBER, LIME } do
	local d = new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = c,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10 - (i - 1) * 16, 0.5, 0),
		Size = UDim2.fromOffset(9, 9),
		ZIndex = 17,
		Parent = termHead,
	})
	corner(d, 5)
end
local TERM_LINES = 8
local termLabels: { TextLabel } = {}
for i = 1, TERM_LINES do
	termLabels[i] = label(term, "", 13, {
		RichText = true,
		Position = UDim2.fromOffset(10, 26 + (i - 1) * 20),
		Size = UDim2.new(1, -20, 0, 18),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 16,
	})
end
type TLine = { text: string, shown: number, color: string }
local tlines: { TLine } = {}
local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", floor(c.R * 255), floor(c.G * 255), floor(c.B * 255))
end
-- adds a line; returns its index so it can be rewritten in place (progress counters)
local function log(tag: string, text: string, color: Color3?): number
	local tc = color or LIME
	table.insert(tlines, { text = string.format('<font color="%s">[%s]</font> %s', hex(tc), tag, text), shown = 0, color = hex(tc) })
	sfx("Type", 0.05, rng:NextNumber(0.95, 1.1))
	return #tlines
end
local function relog(i: number, tag: string, text: string, color: Color3?)
	local l = tlines[i]
	if l then
		l.text = string.format('<font color="%s">[%s]</font> %s', hex(color or LIME), tag, text)
		l.shown = math.huge
	end
end
local function renderTerm(dt: number)
	local first = max(1, #tlines - TERM_LINES + 1)
	for i = 1, TERM_LINES do
		local l = tlines[first + i - 1]
		local lab = termLabels[i]
		if l then
			-- type in: reveal the plain part progressively (rich tags count as a block)
			l.shown += dt * 90
			local plain = l.text:gsub("<[^>]+>", "")
			local n = utf8.len(plain) or #plain
			if l.shown >= n then
				lab.Text = l.text
			else
				local cut = utf8.offset(plain, floor(l.shown) + 1) or (#plain + 1)
				lab.Text = string.sub(plain, 1, cut - 1) .. "█"
			end
		else
			lab.Text = ""
		end
	end
end

---------------------------------------------------------------- tips

local tipBox = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -40),
	Size = UDim2.fromOffset(820, 44),
	ZIndex = 20,
	Parent = canvas,
})
local tipTag = label(tipBox, "TIP", 13, {
	FontFace = PIXEL,
	TextColor3 = BG,
	BackgroundColor3 = AMBER,
	BackgroundTransparency = 0,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(54, 18),
	ZIndex = 21,
})
local tipText = label(tipBox, "", 17, {
	TextColor3 = TEXT,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextWrapped = true,
	Position = UDim2.fromOffset(0, 22),
	Size = UDim2.new(1, 0, 0, 22),
	ZIndex = 21,
})
local tips = {
	"Biomes rewrite the odds. Some auras only exist while a biome is running.",
	"Duplicate auras are not wasted: compile them into RIGS at the Forge.",
	"Brew boost SCRIPTS in the Lab — Luck, Speed, Breach and stronger ones.",
	"NULL runs a stall in the city. Finish his contracts for BITS and scripts.",
	"Every roll pays BITS. Spend them at NULL's stall.",
	"Rarer auras get longer, wilder cutscenes. The rarest ones are unforgettable.",
	"Press TAB to see who is online and what they are wearing.",
	"Settings → REDUCE FLASHING tones down flashes and strobes at any time.",
	"Too many auras on screen? Hide other players' auras in Settings for more FPS.",
	"Big rolls are announced to everyone on the server. Make them jealous.",
}
local tipI = rng:NextInteger(1, #tips)
local tipNext = 0

---------------------------------------------------------------- photosensitivity warning card

local warnLayer = new("Frame", {
	Name = "Warning",
	BackgroundColor3 = BLACK,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 50,
	Parent = canvas,
})
local card = new("Frame", {
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(900, 560),
	ZIndex = 51,
	Parent = warnLayer,
})
local cardScale = new("UIScale", { Scale = 0.94, Parent = card })
stroke(card, AMBER, 2, 0.2)
brackets(card, AMBER, 26, 3, -10)
-- hazard stripes along the top
local stripes = new("Frame", {
	BackgroundColor3 = AMBER,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Size = UDim2.new(1, 0, 0, 14),
	ZIndex = 52,
	Parent = card,
})
for i = 0, 40 do
	new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = BG,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, i * 26, 0.5, 0),
		Size = UDim2.fromOffset(10, 40),
		Rotation = 40,
		ZIndex = 53,
		Parent = stripes,
	})
end
-- warning sign: a diamond with "!"
local sign = new("Frame", {
	BackgroundColor3 = AMBER,
	BackgroundTransparency = 0.85,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(78, 92),
	Size = UDim2.fromOffset(62, 62),
	Rotation = 45,
	ZIndex = 52,
	Parent = card,
})
stroke(sign, AMBER, 3)
label(card, "!", 46, {
	FontFace = TITLE,
	TextColor3 = AMBER,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(78, 94),
	Size = UDim2.fromOffset(60, 60),
	ZIndex = 53,
})
label(card, "PHOTOSENSITIVITY WARNING", 32, {
	FontFace = TITLE,
	TextColor3 = AMBER,
	Position = UDim2.fromOffset(140, 58),
	Size = UDim2.new(1, -170, 0, 40),
	ZIndex = 52,
})
label(card, "EPILEPSY & SEIZURE NOTICE", 15, {
	FontFace = MONO_B,
	TextColor3 = DIM,
	Position = UDim2.fromOffset(142, 104),
	Size = UDim2.new(1, -170, 0, 18),
	ZIndex = 52,
})
label(
	card,
	"This game contains <b>flashing lights, strobe effects, rapid glitch patterns and screen shake</b>, especially during rare aura cutscenes and server events.\n\n"
		.. "A very small percentage of people may experience seizures when exposed to certain light patterns or flashing images. "
		.. "Even people with no history of epilepsy may have an undiagnosed condition.\n\n"
		.. "If you or anyone in your family has epilepsy, talk to a doctor before playing. <b>Stop playing immediately</b> if you feel dizziness, "
		.. "altered vision, eye or muscle twitching, disorientation, loss of awareness or any involuntary movement.",
	17,
	{
		RichText = true,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
		TextColor3 = TEXT,
		Position = UDim2.fromOffset(46, 150),
		Size = UDim2.new(1, -92, 0, 236),
		ZIndex = 52,
	}
)
-- reduced flashing switch
local calmRow = new("TextButton", {
	AutoButtonColor = false,
	BackgroundColor3 = BG,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Text = "",
	Position = UDim2.fromOffset(46, 398),
	Size = UDim2.new(1, -92, 0, 58),
	ZIndex = 52,
	Parent = card,
})
corner(calmRow, 6)
local calmStroke = stroke(calmRow, LINE, 1)
label(calmRow, "REDUCE FLASHING", 18, {
	FontFace = MONO_B,
	Position = UDim2.fromOffset(16, 9),
	Size = UDim2.new(1, -120, 0, 22),
	ZIndex = 53,
})
label(calmRow, "softer flashes, no fast strobes, calmer lightning · change it any time in Settings", 13, {
	TextColor3 = DIM,
	Position = UDim2.fromOffset(16, 32),
	Size = UDim2.new(1, -120, 0, 16),
	ZIndex = 53,
})
local pill = new("Frame", {
	BackgroundColor3 = LINE,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(64, 30),
	ZIndex = 53,
	Parent = calmRow,
})
corner(pill, 15)
local knob = new("Frame", {
	BackgroundColor3 = TEXT,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 3, 0.5, 0),
	Size = UDim2.fromOffset(24, 24),
	ZIndex = 54,
	Parent = pill,
})
corner(knob, 12)
local function showCalm(animated: boolean)
	local t = if animated then 0.18 else 0
	tween(pill, t, { BackgroundColor3 = if calm then LIME else LINE })
	tween(knob, t, { Position = if calm then UDim2.new(1, -27, 0.5, 0) else UDim2.new(0, 3, 0.5, 0) }, Enum.EasingStyle.Back)
	tween(calmStroke, t, { Color = if calm then LIME else LINE })
end
showCalm(false)
calmRow.Activated:Connect(function()
	calm = not calm
	calmTouched = true
	player:SetAttribute("CalmPick", calm)
	showCalm(true)
	sfx("Click", 0.5)
end)
player:GetAttributeChangedSignal("CalmSaved"):Connect(function()
	if not calmTouched then
		calm = player:GetAttribute("CalmSaved") == true
		showCalm(true)
	end
end)

local okBtn = new("TextButton", {
	Name = "Understand",
	AutoButtonColor = false,
	BackgroundColor3 = AMBER,
	BackgroundTransparency = 0.75,
	BorderSizePixel = 0,
	Text = "",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -26),
	Size = UDim2.fromOffset(340, 56),
	ZIndex = 52,
	Parent = card,
})
corner(okBtn, 6)
local okStroke = stroke(okBtn, AMBER, 2, 0.5)
local okText = label(okBtn, "I UNDERSTAND  (3)", 20, {
	FontFace = TITLE,
	TextColor3 = AMBER,
	TextTransparency = 0.4,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 53,
})
local WARN_MIN = 3 -- seconds the warning must stay readable before it can be dismissed
local okEnabled = false

-- card entrance
warnLayer.BackgroundTransparency = 1
card.Position = UDim2.new(0.5, 0, 0.5, 30)
tween(warnLayer, 0.5, { BackgroundTransparency = 0.25 })
tween(card, 0.6, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
tween(cardScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Quint)

---------------------------------------------------------------- loading stages

local W_HANDSHAKE, W_SHARED, W_ASSETS, W_PROFILE, W_AVATAR = 0.12, 0.08, 0.5, 0.18, 0.12
local progress = { handshake = 0, shared = 0, assets = 0, profile = 0, avatar = 0 }
local shown = 0 -- displayed fraction (smoothed, monotonic)
local stageText = "INITIALISING"
local detailText = ""
local countText = ""

local function target(): number
	return progress.handshake * W_HANDSHAKE
		+ progress.shared * W_SHARED
		+ progress.assets * W_ASSETS
		+ progress.profile * W_PROFILE
		+ progress.avatar * W_AVATAR
end

local function shortNum(n: number): string
	if n >= 1e9 then
		return string.format("%gB", floor(n / 1e8) / 10)
	elseif n >= 1e6 then
		return string.format("%gM", floor(n / 1e5) / 10)
	elseif n >= 1e3 then
		return string.format("%gK", floor(n / 1e2) / 10)
	end
	return tostring(n)
end

task.spawn(function()
	log(" .. ", "power on self test", DIM)
	task.wait(0.25)
	log(" OK ", "memory 4096K · display " .. floor(viewport().X) .. "x" .. floor(viewport().Y))
	local hs = log(" .. ", "linking to server node", DIM)
	stageText = "HANDSHAKE"
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	progress.handshake = 1
	local job = if game.JobId ~= "" then string.sub(game.JobId, 1, 8) else "local"
	relog(hs, " OK ", "link established · node " .. job)
	tr[2].Text = "node " .. string.upper(job)

	stageText = "MOUNTING /SHARED"
	local sl = log(" .. ", "mounting /shared", DIM)
	local shared = ReplicatedStorage:WaitForChild("Shared", 60)
	local okS, snd = pcall(function()
		local mod: any = (shared :: Instance):WaitForChild("Sounds", 30)
		return (require :: any)(mod)
	end)
	if okS and type(snd) == "table" then
		sounds = snd :: any
	end
	local okC, cfg = pcall(function()
		local mod: any = (shared :: Instance):WaitForChild("Config", 30)
		return (require :: any)(mod)
	end)
	local nAuras, nBiomes, rarest = 0, 0, 0
	if okC and type(cfg) == "table" then
		local c = cfg :: any
		for _, a in c.Auras or {} do
			nAuras += 1
			rarest = max(rarest, a.chance or 0)
		end
		local bestLuck, bestName = 1, ""
		for _, b in c.Biomes or {} do
			nBiomes += 1
			if (b.luck or 1) > bestLuck then
				bestLuck, bestName = b.luck, b.name
			end
		end
		table.insert(tips, string.format("There are %d auras. The rarest one is 1 in %s.", nAuras, shortNum(rarest)))
		if bestName ~= "" then
			table.insert(tips, string.format("During %s every roll gets x%g luck.", bestName, bestLuck))
		end
	end
	progress.shared = 1
	relog(sl, " OK ", string.format("/shared mounted · %d auras · %d biomes", nAuras, nBiomes))

	-- boot theme
	local mid = sounds.MusicMain
	if mid and mid ~= "" then
		local m = Instance.new("Sound")
		m.Name = "BootTheme"
		m.SoundId = "rbxassetid://" .. mid
		m.Looped = true
		m.Volume = 0
		m.Parent = SoundService
		m:Play()
		tween(m, 3, { Volume = 0.42 }, Enum.EasingStyle.Linear)
		music = m
	end

	-- assets: every sound of the game
	stageText = "FETCHING ASSETS"
	local ids: { string } = {}
	local names: { [string]: string } = {}
	for name, id in sounds do
		if id ~= "" then
			local cid = "rbxassetid://" .. id
			table.insert(ids, cid)
			names[cid] = name
		end
	end
	table.sort(ids)
	local total, done, failed = #ids, 0, 0
	local al = log(" .. ", string.format("fetching assets 0/%d", total), DIM)
	local ta = os.clock()
	countText = string.format("0 / %d", total)
	if total == 0 then
		progress.assets = 1
	else
		-- small batches so the bar moves steadily and the current file can be shown
		local BATCH = 6
		for i = 1, total, BATCH do
			if closed then
				break
			end
			local batch = {}
			for k = i, min(total, i + BATCH - 1) do
				table.insert(batch, ids[k])
			end
			detailText = "audio://" .. string.lower(names[batch[1]] or "?") .. ".ogg"
			pcall(function()
				ContentProvider:PreloadAsync(batch, function(_cid: string, st: Enum.AssetFetchStatus)
					done += 1
					if st ~= Enum.AssetFetchStatus.Success then
						failed += 1
					end
					progress.assets = done / total
					countText = string.format("%d / %d", done, total)
				end)
			end)
			relog(al, " .. ", string.format("fetching assets %d/%d", done, total), DIM)
		end
		progress.assets = 1
	end
	relog(al, " OK ", string.format("%d assets cached in %.1fs", total - failed, os.clock() - ta))
	if failed > 0 then
		log("WARN", string.format("%d assets will stream later", failed), AMBER)
	end
	detailText = ""
end)

task.spawn(function()
	-- profile (the server sets Loaded once the DataStore profile is in)
	repeat
		task.wait(0.2)
	until player:GetAttribute("Loaded") or closed
	progress.profile = 1
	local ls = player:FindFirstChild("leaderstats")
	local rolls = ls and ls:FindFirstChild("Rolls")
	local n = if rolls and rolls:IsA("IntValue") then rolls.Value else 0
	log(" OK ", string.format("profile synced · %s rolls on record", shortNum(n)))
end)

task.spawn(function()
	local char = player.Character or player.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", 30)
	progress.avatar = 1
	local hum = char:FindFirstChildOfClass("Humanoid")
	log(" OK ", "avatar compiled · " .. (if hum and hum.RigType == Enum.HumanoidRigType.R6 then "R6" else "R15") .. " rig")
end)

---------------------------------------------------------------- glitch events

local glitchUntil, nextGlitch = 0, 2.5
local function glitch(strength: number)
	if calm or entering then
		return
	end
	glitchUntil = os.clock() + 0.07 + 0.1 * strength
	for _, s in slices do
		s.off = if rng:NextNumber() < 0.55 then rng:NextNumber(-28, 28) * strength else 0
	end
	if strength > 0.6 then
		sfx("Glitch", 0.1, rng:NextNumber(0.9, 1.3))
	end
end

---------------------------------------------------------------- enter / close

local function finish()
	if closed then
		return
	end
	closed = true
	player:SetAttribute("Booting", false)
	local m = music
	if m then
		tween(m, 1.2, { Volume = 0 }, Enum.EasingStyle.Linear)
		task.delay(1.3, function()
			m:Destroy()
		end)
	end
	task.delay(0.1, function()
		gui:Destroy()
	end)
end

local function enter()
	if entering or closed or not warned then
		return
	end
	entering = true
	sfx("Click", 0.6)
	sfx("Whoosh", 0.5)
	if not calm then
		sfx("Glitch", 0.4, 0.8)
	end
	-- turn the whole screen into one CanvasGroup so it can fade as a single image
	local group = new("CanvasGroup", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = gui,
	})
	root.Parent = group
	-- tear bars sweeping across while the logo punches in
	local tears: { Frame } = {}
	if not calm then
		for i = 1, 10 do
			local f = new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = if i % 2 == 0 then CYAN else MAGENTA,
				BackgroundTransparency = 0.2,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(if i % 2 == 0 then -1 else 1, 0, rng:NextNumber(0.05, 0.95), 0),
				Size = UDim2.new(1, 0, 0, rng:NextInteger(2, 10)),
				ZIndex = 5,
				Parent = gui,
			})
			tears[i] = f
			tween(f, rng:NextNumber(0.35, 0.6), { Position = UDim2.new(if i % 2 == 0 then 1 else -1, 0, f.Position.Y.Scale, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		end
		local flash = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = gui })
		tween(flash, 0.45, { BackgroundTransparency = 1 })
	end
	tween(logoScale, 0.7, { Scale = 1.35 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	tween(enterScale, 0.25, { Scale = 0.9 })
	task.wait(if calm then 0.2 else 0.35)
	tween(group, if calm then 0.9 else 0.6, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(if calm then 0.95 else 0.65)
	finish()
end

local function showEnter()
	if ready then
		return
	end
	ready = true
	sfx("Riser", 0.25, 1.2)
	log(" OK ", "all systems nominal · welcome back, " .. player.DisplayName, CYAN)
	tween(panel, 0.3, { Position = UDim2.new(0.5, 0, 0.62, 12) })
	for _, d in panel:GetDescendants() do
		if d:IsA("TextLabel") then
			tween(d, 0.3, { TextTransparency = 1 })
		elseif d:IsA("Frame") then
			tween(d, 0.3, { BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, 0.3, { Transparency = 1 })
		end
	end
	task.delay(0.3, function()
		panel.Visible = false
		skipBtn.Visible = false
		enterBtn.Visible = true
		enterHint.Visible = true
		enterHint.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
			then "tap to connect"
			else "click or press any key to connect"
		enterScale.Scale = 0.6
		tween(enterScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

local function acknowledge()
	if not okEnabled or warned then
		return
	end
	warned = true
	if calmTouched then -- only an explicit choice overrides the saved setting
		player:SetAttribute("CalmPick", calm)
	end
	sfx("Click", 0.6)
	tween(cardScale, 0.3, { Scale = 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(warnLayer, 0.4, { BackgroundTransparency = 1 })
	for _, d in warnLayer:GetDescendants() do
		if d:IsA("TextLabel") then
			tween(d, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
		elseif d:IsA("Frame") or d:IsA("TextButton") then
			tween(d, 0.3, { BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, 0.3, { Transparency = 1 })
		end
	end
	task.delay(0.45, function()
		warnLayer:Destroy()
	end)
	glitch(1)
end
okBtn.Activated:Connect(acknowledge)
okBtn.MouseEnter:Connect(function()
	if okEnabled then
		sfx("Hover", 0.3)
		tween(okBtn, 0.12, { BackgroundTransparency = 0.55 })
	end
end)
okBtn.MouseLeave:Connect(function()
	tween(okBtn, 0.12, { BackgroundTransparency = if okEnabled then 0.7 else 0.75 })
end)
enterBtn.Activated:Connect(function()
	task.spawn(enter)
end)
enterBtn.MouseEnter:Connect(function()
	sfx("Hover", 0.3)
	tween(enterBtn, 0.12, { BackgroundColor3 = rgb(22, 26, 42) })
	tween(enterText, 0.12, { TextColor3 = CYAN })
end)
enterBtn.MouseLeave:Connect(function()
	tween(enterBtn, 0.12, { BackgroundColor3 = PANEL })
	tween(enterText, 0.12, { TextColor3 = TEXT })
end)
skipBtn.Activated:Connect(function()
	sfx("Click", 0.5)
	log("SKIP", "skipping ahead · assets keep streaming", AMBER)
	showEnter()
end)
UserInputService.InputBegan:Connect(function(input: InputObject)
	local t = input.UserInputType
	local key = t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.Gamepad1
	if not key and t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
		return
	end
	if not warned then
		if okEnabled and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA) then
			acknowledge()
		end
		return
	end
	if ready and not entering then
		task.spawn(enter)
	end
end)

---------------------------------------------------------------- frame loop

local frameConn: RBXScriptConnection
local mutateT = 0
frameConn = RunService.RenderStepped:Connect(function(dt: number)
	if closed or not gui.Parent then
		frameConn:Disconnect()
		return
	end
	local now = os.clock()
	local t = now - t0

	-- test hooks
	if player:GetAttribute("BootAck") and not warned and okEnabled then
		acknowledge()
	end
	if player:GetAttribute("BootEnter") and ready and not entering then
		task.spawn(enter)
	end
	if player:GetAttribute("SkipBoot") then
		warned = true
		finish()
		return
	end

	-- grid: lines march toward the viewer
	local speed = if entering then 3 else 0.55
	for i, f in hLines do
		local z = ((i - 1) / GRID_H - t * speed * 0.12) % 1 -- 0 = near, 1 = far
		local zz = 1 + z * 14
		local y = HORIZON + (1 - HORIZON) * (1 / zz) * 1.05
		f.Position = UDim2.fromScale(0, y)
		f.Size = UDim2.new(1, 0, 0, if z < 0.15 then 2 else 1)
		f.BackgroundTransparency = clamp(0.15 + z * 0.9, 0, 1)
	end
	for i, c in sunCuts do
		local y = 0.42 + ((i * 0.09 + t * 0.03) % 0.58)
		c.Position = UDim2.fromScale(0, y)
		c.Size = UDim2.new(1, 0, 0, 1 + (y - 0.42) * 14)
	end
	haze.BackgroundTransparency = 0.3 + sin(t * 0.8) * 0.08

	-- rain
	mutateT += dt
	local mutate = mutateT > 0.09
	if mutate then
		mutateT = 0
	end
	for _, d in drops do
		d.y += d.speed * dt
		if d.y > 1.05 then
			d.y = -1.25
		end
		d.l.Position = UDim2.new(d.l.Position.X.Scale, 0, d.y, 0)
		if mutate and rng:NextNumber() < 0.35 then
			d.chars[rng:NextInteger(1, d.n)] = glyph()
			d.l.Text = table.concat(d.chars, "\n")
		end
	end
	for _, m in motes do
		m.y -= m.vy * dt
		if m.y < -0.02 then
			m.y, m.x = 1.02, rng:NextNumber()
		end
		m.f.Position = UDim2.fromScale(m.x + sin(t * 0.7 + m.ph) * 0.01, m.y)
		m.f.BackgroundTransparency = 0.35 + 0.4 * (0.5 + 0.5 * sin(t * 2 + m.ph))
	end
	scanBar.Position = UDim2.fromScale(0, ((t * 0.18) % 1.3) - 0.15)

	-- logo: idle RGB drift, occasional glitch slices (never in reduced-flashing mode)
	if warned and not entering and t > nextGlitch then
		nextGlitch = t + rng:NextNumber(1.6, 4.2)
		glitch(rng:NextNumber(0.4, 1))
	end
	local active = now < glitchUntil
	local split = 3 + sin(t * 1.7) * 1.5 + (if active then 9 else 0)
	for i, s in slices do
		local off = if active then s.off else s.off * 0.6
		s.off = off
		local wob = sin(t * 2.3 + i * 0.7) * 0.6
		s.inner.Position = UDim2.fromOffset(off + wob, s.inner.Position.Y.Offset)
		s.cy.Position = UDim2.fromOffset(-split, 0)
		s.mg.Position = UDim2.fromOffset(split, 0)
	end
	logoScale.Scale = if entering then logoScale.Scale else 1 + sin(t * 1.1) * 0.008
	ulGrad.Offset = Vector2.new(((t * 0.35) % 2) - 1, 0)
	-- tagline types in after the warning
	if warned then
		local n = clamp(floor((t - 0.5) * 22), 0, #TAGLINE)
		tagline.Text = string.sub(TAGLINE, 1, n) .. (if floor(t * 2) % 2 == 0 then "_" else " ")
	end

	-- progress
	local want = target()
	shown = max(shown, shown + (want - shown) * min(1, dt * 4))
	if want >= 0.999 and shown > 0.995 then
		shown = 1
	end
	local p = shown
	pct.Text = string.format("%03d%%", floor(p * 100 + 0.5))
	status.Text = if p >= 1 then "READY" else stageText .. string.rep(".", floor(t * 3) % 4)
	detail.Text = detailText
	count.Text = countText
	local lit = p * SEGS
	for i, f in segFrames do
		if i <= lit then
			f.BackgroundColor3 = CYAN:Lerp(MAGENTA, (i - 1) / (SEGS - 1))
			f.BackgroundTransparency = 0
		elseif i - 1 < lit then
			f.BackgroundColor3 = WHITE
			f.BackgroundTransparency = 0.2 + 0.5 * (0.5 + 0.5 * sin(t * 12))
		else
			f.BackgroundColor3 = LINE
			f.BackgroundTransparency = 0.3
		end
	end
	spinner.Rotation = (t * 160) % 360
	for i, sgm in spinSegs do
		local a = ((i - 1) / 6 - t * 0.45) % 1
		sgm.BackgroundTransparency = a * 0.85
		sgm.BackgroundColor3 = if p >= 1 then LIME else CYAN
	end

	-- warning countdown
	if not warned then
		local left = WARN_MIN - t
		if left > 0 then
			okText.Text = string.format("I UNDERSTAND  (%d)", math.ceil(left))
		elseif not okEnabled then
			okEnabled = true
			okText.Text = "I UNDERSTAND"
			tween(okText, 0.25, { TextTransparency = 0 })
			tween(okStroke, 0.25, { Transparency = 0 })
			tween(okBtn, 0.25, { BackgroundTransparency = 0.7 })
		end
		if okEnabled then
			okStroke.Thickness = 2 + (0.5 + 0.5 * sin(t * 4)) * 1.5
		end
	end

	-- ready -> ENTER prompt (only after the warning is acknowledged)
	if warned and p >= 1 and not ready then
		showEnter()
	end
	if warned and not ready and t > 12 and not skipBtn.Visible then
		skipBtn.Visible = true
		skipBtn.TextTransparency = 1
		tween(skipBtn, 0.4, { TextTransparency = 0 })
	end
	if ready and not entering then
		local pulse = 0.5 + 0.5 * sin(t * 3)
		enterStroke.Color = CYAN:Lerp(MAGENTA, pulse)
		enterStroke.Thickness = 2 + pulse * 1.5
		enterHint.TextTransparency = 0.2 + 0.5 * (1 - pulse)
	end

	-- terminal, tips, corners
	renderTerm(dt)
	if t > tipNext then
		tipNext = t + 5.5
		tipI = tipI % #tips + 1
		local text = tips[tipI]
		tween(tipText, 0.25, { TextTransparency = 1 })
		task.delay(0.25, function()
			tipText.Text = text
			tween(tipText, 0.35, { TextTransparency = 0 })
		end)
	end
	tipTag.BackgroundTransparency = 0.1 + 0.15 * sin(t * 3)
	tr[1].Text = os.date("%H:%M:%S") :: string
	tr[3].Text = "uplink " .. string.rep("▮", 1 + floor(t * 2) % 5) .. string.rep("▯", 4 - floor(t * 2) % 5)
	br[3].TextTransparency = 0.3
end)

-- never trap anyone: if something stalls badly, offer SKIP early and auto-enter much later
task.delay(90, function()
	if not closed and warned and not ready then
		showEnter()
	end
end)
