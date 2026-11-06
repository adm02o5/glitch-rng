--!strict
-- Cutscene/Epic: themed ~2.5s scenes for every EPIC aura (not skippable, level 2).
--
--   Rootkit    purple roots crawl up from below the screen while a kernel module hides itself
--   Datastorm  code rain thickens into a swirling storm with lightning until it swallows the screen
--   Hologram   projector boots, light cone, the avatar is projected line by line with scanlines
--   ZeroDay    red countdown races to 00:00.00, red lightning, exploit deployed
--   Blackout   the lights die column by column, silence, red emergency strobes
--   Chromatic  a white beam hits a prism, splits into a rainbow fan, the screen splits into R/G/B

local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local Ctx = require(Client.Ctx)
local U = require(script.Parent.Util)
local Fx = require(script.Parent.Fx)

local P = Kit.P
local WHITE, BLACK = U.WHITE, U.BLACK
local lerp, seg = U.lerp, U.seg
local outCubic, inCubic, inOutCubic, outBack, bump = U.outCubic, U.inCubic, U.inOutCubic, U.outBack, U.bump
local setT, setLine = Fx.setT, Fx.setLine

local Scenes = {}

local function screen(S: any): Vector2
	return S.gui.AbsoluteSize
end

local function mono(S: any, props: { [string]: any }): TextLabel
	local p: { [string]: any } = { FontFace = Kit.MonoBold, TextSize = math.floor(15 * S.vs + 0.5) }
	for k, v in props do
		p[k] = v
	end
	local l = S:text(p)
	Kit.new("UIStroke", { Thickness = 1.5, Color = BLACK, Transparency = 0.35, Parent = l })
	return l
end

--------------------------------------------------------------------------------------------------------
-- ROOTKIT: lives below the surface
--------------------------------------------------------------------------------------------------------

function Scenes.Rootkit(S: any)
	local a = S.aura
	local col = a.color
	local sz = screen(S)
	S:hideHud()
	local cc = S:cc()
	local vig = S:edges(BLACK, 0.5, 8)
	setT(vig, 1)
	-- Purple underglow rising from the bottom edge.
	local under = S:frame({
		Name = "Under",
		BackgroundColor3 = col,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		ZIndex = 9,
	})
	Kit.new("UIGradient", {
		Rotation = -90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = under,
	})
	local origins = {}
	for i = 1, 7 do
		local x = sz.X * ((i - 0.5) / 7 + S.rng:NextNumber(-0.04, 0.04))
		table.insert(origins, { x, sz.Y + 4, -math.pi / 2 + S.rng:NextNumber(-0.3, 0.3) })
	end
	local roots = S:branches(12, origins, {
		color = col,
		core = col:Lerp(WHITE, 0.55),
		steps = 15,
		len = sz.Y / 15 * 0.85 / S.vs,
		jitter = 0.5,
		branch = 0.32,
		thick = 4,
		taper = 0.93,
		bias = -math.pi / 2,
	})
	local gl = S:glitchLayer(20, { col, a.color2:Lerp(col, 0.4), BLACK, WHITE })
	local term = mono(S, {
		TextColor3 = col:Lerp(WHITE, 0.35),
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(28, 26),
		Size = UDim2.fromOffset(520, 120),
		ZIndex = 30,
		LineHeight = 1.15,
	})

	S:lowShot({ dur = 2.6, d0 = 10, d1 = 7, h = -1.8, a0 = 20, a1 = -6, roll0 = 6, roll1 = 2, fov0 = 62, fov1 = 54, blend = 0.35 })
	S:sfx("Glitch", 0.5, 0.6)
	S:sfx("Whoosh", 0.5, 0.7)
	S:typeInto(term, "$ insmod rootkit.ko\n[ok] hooked sys_call_table\n[ok] pid hidden from ps\nuid=0(root) gid=0(root)", 60, 0.2)
	local lastStep = -1
	S:phase(1.75, function(k: number, e: number)
		local q = inOutCubic(k)
		roots.set(q * 1.02)
		under.Size = UDim2.fromScale(1, 0.55 * outCubic(k))
		setT(vig, 1 - 0.8 * outCubic(k))
		cc.Brightness = -0.14 * outCubic(k)
		cc.Saturation = -0.3 * k
		cc.TintColor = WHITE:Lerp(col, 0.22 * k)
		gl.k = 0.12 + 0.25 * k + (if S.rng:NextNumber() < 0.06 then 0.4 else 0)
		S.shake = 0.15 + 0.35 * k
		local step = math.floor(q * 10)
		if step ~= lastStep then
			lastStep = step
			S:sfx("Tick", 0.3, 0.55 + q * 0.4)
		end
		if e > 0.9 then
			term.TextTransparency = 0.2 * math.sin(e * 30) ^ 2
		end
	end)
	-- Roots reach the top: purple surge.
	S:sfx("Boom", 0.65, 0.7)
	S:sfx("Glitch", 0.55, 0.5)
	S:burst(1.5)
	S:worldFlash(col, 0.6)
	S:flash(col:Lerp(WHITE, 0.3), 0.55, 0.35)
	roots.color(col:Lerp(WHITE, 0.4))
	S:phase(0.45, function(k: number)
		gl.k = 0.9 * (1 - k)
		S.shake = 0.8 * (1 - k)
		S.fovPunch = -7 * bump(k)
		cc.Brightness = lerp(0.1, -0.1, k)
	end)
	S:outro(col:Lerp(WHITE, 0.6), 0.16, 0.45)
end

--------------------------------------------------------------------------------------------------------
-- DATASTORM: born in the eye of the storm
--------------------------------------------------------------------------------------------------------

function Scenes.Datastorm(S: any)
	local a = S.aura
	local col = a.color
	local sz = screen(S)
	S:hideHud()
	local cc = S:cc()
	local dark = S:fill(Color3.fromRGB(0, 14, 8), 8, 1)
	local rain = S:codeRain(12, col, 64)
	local rain2 = S:codeRain(14, col:Lerp(WHITE, 0.3), 26)
	local vig = S:edges(Color3.fromRGB(0, 30, 15), 0.45, 16)
	setT(vig, 1)
	local eye = S:circle(18, col, 0.0, 3)
	local eyeSt = eye:FindFirstChildOfClass("UIStroke") :: UIStroke
	local cap = mono(S, {
		TextColor3 = col:Lerp(WHITE, 0.4),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 30,
	})
	S:orbitShot({ dur = 2.6, deg = 170, r0 = 13, r1 = 8, h0 = 5, h1 = 2.5, fov0 = 58, fov1 = 66, roll = 4, blend = 0.4, ease = inCubic })
	S:sfx("Riser", 0.5, 1.2)
	S:sfx("Glitch", 0.4, 0.8)
	S:typeInto(cap, "> STORM CELL 0x" .. U.hex(S.rng, 4) .. " :: WIND 999 Gbps :: EYE LOCKED", 55, 0.18)
	local nextBolt = 0.35
	S:phase(1.9, function(k: number, e: number)
		local q = inCubic(k)
		rain.k = 0.15 + 0.85 * outCubic(k)
		rain2.k = 0.6 * k
		rain.speed = lerp(0.8, 3.4, q)
		rain2.speed = lerp(1.4, 4.4, q)
		rain.tilt = 30 * q * math.sin(e * 2.2)
		rain2.tilt = rain.tilt * 1.3
		dark.BackgroundTransparency = 1 - 0.45 * k
		setT(vig, 1 - 0.8 * k)
		cc.TintColor = WHITE:Lerp(col, 0.3 * k)
		cc.Saturation = -0.4 * k
		cc.Contrast = 0.25 * k
		S.shake = 0.2 + 0.6 * q
		local es = 0.08 + 0.1 * outCubic(k)
		eye.Size = UDim2.fromScale(es, es)
		eye.Rotation = e * 120
		eyeSt.Transparency = 1 - 0.7 * k
		if e >= nextBolt then
			nextBolt = e + lerp(0.5, 0.18, k)
			local x = sz.X * S.rng:NextNumber(0.1, 0.9)
			local bolt = S:branches(22, { { x, -4, math.pi / 2 + S.rng:NextNumber(-0.3, 0.3) } }, {
				color = col,
				core = WHITE,
				steps = 9,
				len = sz.Y / 9 * 0.8 / S.vs,
				jitter = 0.8,
				branch = 0.35,
				thick = 3,
				bias = math.pi / 2,
			})
			bolt.set(1)
			S:flash(WHITE, 0.25 + 0.2 * k, 0.18, 21)
			S:sfx("Boom", 0.25 + 0.2 * k, 1.4 + S.rng:NextNumber() * 0.3)
			S:after(0.12, function()
				bolt.holder:Destroy()
			end)
		end
	end)
	-- The storm swallows the screen.
	S:sfx("Whoosh", 0.8, 0.8)
	S:sfx("Boom", 0.6, 0.8)
	S:burst(1.6)
	S:worldFlash(col, 0.6)
	local swallow = S:fill(col, 24, 1)
	S:phase(0.35, function(k: number)
		rain.speed = 5
		rain.k = 1
		swallow.BackgroundTransparency = 1 - 0.75 * inCubic(k)
		S.fovPunch = 14 * inCubic(k)
	end)
	S:outro(col:Lerp(WHITE, 0.55), 0.12, 0.45)
end

--------------------------------------------------------------------------------------------------------
-- HOLOGRAM: a projection that learned to stand
--------------------------------------------------------------------------------------------------------

function Scenes.Hologram(S: any)
	local a = S.aura
	local col = a.color
	S:hideHud()
	local cc = S:cc()
	local back = S:fill(Color3.fromRGB(2, 10, 24), 8, 1)
	-- Projector cone: fan of light rays from the bottom centre.
	local cone = S:frame({ Name = "Cone", BackgroundTransparency = 1, ZIndex = 10 })
	local rays: { Frame } = {}
	local sz = screen(S)
	local ox, oy = sz.X * 0.5, sz.Y * 1.02
	for i = 1, 15 do
		local ang = math.rad(lerp(-112, -68, (i - 1) / 14))
		local len = sz.Y * 0.95
		local r = S:line(ox, oy, ox + math.cos(ang) * len, oy + math.sin(ang) * len, if i % 2 == 0 then 10 else 4, col, 10, cone)
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = r,
		})
		r.BackgroundTransparency = 1
		rays[i] = r
	end
	-- Projected avatar, built bottom-up inside a clipping frame.
	local hs = 0.72
	local hw, hh = sz.Y * hs * 0.62, sz.Y * hs
	local clip = S:frame({
		Name = "HoloClip",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromOffset(hw, 0),
		ZIndex = 12,
	})
	local view = S:charView({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(hw, hh),
		ImageColor3 = col:Lerp(WHITE, 0.15),
		ImageTransparency = 0.2,
		ZIndex = 12,
		Parent = clip,
	}, { dist = 11, height = 0.4, lookY = 0.1, ambient = WHITE, light = col })
	local lines = S:scanlines(13, col, 5, 0.75, clip)
	lines.AnchorPoint = Vector2.new(0, 1)
	lines.Position = UDim2.fromScale(0, 1)
	lines.Size = UDim2.fromOffset(hw, hh)
	local scanBar = S:frame({
		Name = "ScanBar",
		BackgroundColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.new(hs * 0.8, 0, 0, 3),
		ZIndex = 14,
	})
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = scanBar,
	})
	local pad = S:circle(11, col, 0.3, 3)
	pad.Position = UDim2.fromScale(0.5, 0.9)
	pad.Size = UDim2.new(0, 0, 0.05, 0)
	pad.SizeConstraint = Enum.SizeConstraint.RelativeXY
	local status = mono(S, {
		Text = "",
		TextColor3 = col,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 30,
	})
	Kit.brackets(clip, col, 22, 15)

	S:frontShot({ dur = 2.6, d0 = 11, d1 = 8.5, h0 = 1.5, h1 = 0.8, fov0 = 55, fov1 = 48, blend = 0.4 })
	S:sfx("Open", 0.6, 0.7)
	S:sfx("Glitch", 0.3, 1.3)
	-- 1) Projector boots with flicker.
	S:phase(0.5, function(k: number, e: number)
		local on = if k < 0.8 then (if S.rng:NextNumber() < 0.5 then 1 else 0.2) else 1
		back.BackgroundTransparency = 1 - 0.55 * outCubic(k)
		for i, r in rays do
			r.BackgroundTransparency = 1 - (0.35 + 0.25 * (i % 2)) * on * k
		end
		pad.Size = UDim2.new(0.22 * outBack(k), 0, 0.05, 0)
		status.Text = "PROJECTOR 01 :: WARMING UP" .. string.rep(".", math.floor(e * 8) % 4)
		cc.TintColor = WHITE:Lerp(col, 0.2 * k)
		cc.Saturation = -0.4 * k
	end)
	-- 2) Scan builds the avatar bottom-up.
	S:sfx("Riser", 0.4, 1.4)
	local lastPct = -1
	S:phase(1.35, function(k: number, e: number)
		local q = inOutCubic(k)
		clip.Size = UDim2.fromOffset(hw, hh * q)
		scanBar.Position = UDim2.new(0.5, 0, 0.9 - hs * q, 0)
		scanBar.BackgroundTransparency = 0.1 + 0.3 * math.sin(e * 40) ^ 2
		lines.Position = UDim2.new(0, 0, 1, (e * 30) % 5)
		view.set(math.rad(-25 + 50 * q))
		view.vp.ImageTransparency = 0.15 + (if S.rng:NextNumber() < 0.12 then 0.5 else 0)
		local pct = math.floor(q * 100)
		status.Text = "RENDERING PROJECTION  " .. pct .. "%"
		if math.floor(pct / 10) ~= lastPct then
			lastPct = math.floor(pct / 10)
			S:sfx("Tick", 0.3, 1 + q * 0.6)
		end
		for i, r in rays do
			r.BackgroundTransparency = 1 - (0.35 + 0.25 * (i % 2)) * (0.85 + 0.15 * math.sin(e * 25 + i))
		end
	end)
	status.Text = "PROJECTION STABLE"
	status.TextColor3 = WHITE
	Kit.glitch(status, 0.3)
	scanBar.Visible = false
	S:sfx("Reveal3", 0.4, 1.2)
	S:burst(1.4)
	S:ring(16, col, 0.6, 0.9, 3, UDim2.fromScale(0.5, 0.6))
	S:phase(0.4, function(_: number, e: number)
		view.set(math.rad(25 + e * 40))
		view.vp.ImageTransparency = 0.05 + 0.1 * math.sin(e * 30) ^ 2
	end)
	S:outro(col:Lerp(WHITE, 0.6), 0.14, 0.45)
end

--------------------------------------------------------------------------------------------------------
-- ZERO DAY: no patch, no warning
--------------------------------------------------------------------------------------------------------

function Scenes.ZeroDay(S: any)
	local col = P.Red
	local sz = screen(S)
	S:hideHud()
	local cc = S:cc()
	local dim = S:fill(BLACK, 8, 1)
	local vig = S:edges(col, 0.32, 9)
	setT(vig, 1)
	local gl = S:glitchLayer(24, { col, BLACK, WHITE, Color3.fromRGB(120, 0, 0) })
	local big = math.floor(130 * S.vs + 0.5)
	local timer = S:text({
		Text = "00:03.00",
		FontFace = Kit.Pixel,
		TextSize = big,
		TextColor3 = col,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.new(1, 0, 0, big + 10),
		TextTransparency = 1,
		ZIndex = 30,
	})
	local timerGhost = timer:Clone()
	timerGhost.TextColor3 = Color3.fromRGB(80, 0, 0)
	timerGhost.ZIndex = 29
	timerGhost.Parent = S.gui
	Kit.new("UIStroke", { Thickness = 4, Color = BLACK, Transparency = 0.2, Parent = timer })
	local cve = mono(S, {
		Text = "CVE-" .. os.date("%Y") .. "-" .. tostring(S.rng:NextInteger(10000, 99999)) .. "  ::  SEVERITY 10.0 CRITICAL",
		TextColor3 = col:Lerp(WHITE, 0.3),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.47, -big * 0.62),
		Size = UDim2.new(1, 0, 0, 22),
		TextTransparency = 1,
		ZIndex = 30,
	})
	local note = mono(S, {
		Text = "ZERO-DAY EXPLOIT  //  NO PATCH AVAILABLE  //  NO WARNING",
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.47, big * 0.62),
		Size = UDim2.new(1, 0, 0, 22),
		TextTransparency = 1,
		ZIndex = 30,
	})

	S:frontShot({ dur = 2.4, d0 = 12, d1 = 7, h0 = 2, h1 = 1, roll0 = 0, roll1 = -6, fov0 = 56, fov1 = 46, blend = 0.3 })
	S:sfx("Error", 0.55, 0.7)
	local total = 2.05
	local lastSec = 4
	local nextBolt = 0.4
	S:phase(total, function(k: number, e: number)
		-- Time accelerates: 3.00 seconds on the clock in ~2 real seconds, faster at the end.
		local left = math.max(0, 3 * (1 - (k ^ 1.25)))
		local secs = math.floor(left)
		local cs = math.floor((left - secs) * 100)
		timer.Text = string.format("00:%02d.%02d", secs, cs)
		timerGhost.Text = timer.Text
		local fade = seg(e, 0, 0.2)
		timer.TextTransparency = 1 - fade
		timerGhost.TextTransparency = 1 - fade * 0.6
		timerGhost.Position = UDim2.new(0.5, S.rng:NextNumber(-4, 4) * k, 0.47, S.rng:NextNumber(-2, 2))
		cve.TextTransparency = 1 - seg(e, 0.1, 0.3)
		note.TextTransparency = 1 - seg(e, 0.2, 0.4)
		dim.BackgroundTransparency = 1 - 0.45 * fade
		local beat = (left % 1)
		local pulse = beat ^ 6
		setT(vig, 1 - (0.25 + 0.6 * pulse) * fade)
		timer.TextColor3 = col:Lerp(WHITE, pulse * 0.6)
		cc.TintColor = WHITE:Lerp(col, 0.15 + 0.15 * pulse)
		cc.Saturation = -0.5 * fade
		cc.Contrast = 0.3 * fade
		gl.k = 0.05 + 0.4 * k ^ 2
		S.shake = 0.1 + 0.5 * k ^ 2
		if secs < lastSec then
			lastSec = secs
			S:sfx("Error", 0.45, 0.8 + (3 - secs) * 0.15)
		end
		if math.floor(e * (6 + 14 * k)) ~= math.floor((e - 1 / 60) * (6 + 14 * k)) then
			S:sfx("Tick", 0.25 + 0.2 * k, 1.2 + k * 0.6)
		end
		if e >= nextBolt then
			nextBolt = e + lerp(0.45, 0.12, k)
			local side = if S.rng:NextNumber() < 0.5 then 0 else sz.X
			local bolt = S:branches(26, { { side, sz.Y * S.rng:NextNumber(0.1, 0.9), if side == 0 then 0 else math.pi } }, {
				color = col,
				core = WHITE,
				steps = 8,
				len = sz.X / 8 * 0.45 / S.vs,
				jitter = 0.9,
				branch = 0.4,
				thick = 3,
			})
			bolt.set(1)
			S:after(0.1, function()
				bolt.holder:Destroy()
			end)
		end
	end)
	timer.Text = "00:00.00"
	timerGhost.Text = timer.Text
	-- 00:00 hit.
	note.Text = "EXPLOIT DEPLOYED"
	note.TextColor3 = col
	Kit.glitch(note, 0.3)
	S:sfx("Boom", 0.85, 0.6)
	S:sfx("Glitch", 0.6, 0.5)
	S:burst(1.6)
	S:worldFlash(col, 0.6)
	S:flash(WHITE, 0.8, 0.25, 40)
	S:phase(0.35, function(k: number)
		timer.TextColor3 = if (k * 8) % 1 < 0.5 then WHITE else col
		gl.k = 1 - k
		S.shake = 1 - k
		S.fovPunch = -10 * bump(k)
	end)
	S:outro(col, 0.12, 0.45)
end

--------------------------------------------------------------------------------------------------------
-- BLACKOUT: when the grid dies, it wakes
--------------------------------------------------------------------------------------------------------

function Scenes.Blackout(S: any)
	local col = S.aura.color
	S:hideHud()
	local cc = S:cc()
	local n = 8
	local cols: { Frame } = {}
	local lamps: { Frame } = {}
	for i = 1, n do
		cols[i] = S:frame({
			Name = "Column",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale((i - 1) / n, 0),
			Size = UDim2.new(1 / n, 1, 1, 0),
			ZIndex = 10,
		})
		local lamp = S:frame({
			Name = "Lamp",
			BackgroundColor3 = Color3.fromRGB(255, 240, 200),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new((i - 0.5) / n, 0, 0, 14),
			Size = UDim2.new(1 / n, -24, 0, math.floor(6 * S.vs + 0.5)),
			BackgroundTransparency = 0.15,
			ZIndex = 12,
		})
		Kit.corner(lamp, 3)
		Kit.new("UIStroke", { Color = Color3.fromRGB(255, 220, 150), Thickness = 2, Transparency = 0.5, Parent = lamp })
		lamps[i] = lamp
	end
	local order = {}
	for i = 1, n do
		order[i] = i
	end
	for i = n, 2, -1 do
		local j = S.rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local label = mono(S, {
		Text = "",
		TextColor3 = P.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -36),
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 30,
	})
	S:frontShot({ dur = 2, d0 = 9, d1 = 8, h0 = 1.4, h1 = 1.2, fov0 = 54, fov1 = 52, blend = 0.3 })
	S:sfx("Error", 0.3, 0.6)
	-- 1) Lights die one by one, each after a short flicker.
	local per = { 0.24, 0.22, 0.2, 0.18, 0.16, 0.14, 0.12, 0.1 }
	for idx, ci in ipairs(order) do
		local c, lamp = cols[ci], lamps[ci]
		local d = per[idx]
		S:phase(d, function(k: number)
			local fl = if k < 0.6 then (if S.rng:NextNumber() < 0.45 then 0.6 else 0) else 1
			c.BackgroundTransparency = 1 - 0.96 * fl
			lamp.BackgroundTransparency = if fl >= 1 then 0.92 else 0.15 + 0.7 * fl
			label.Text = string.format("GRID SECTOR %02d :: OFFLINE", idx)
		end)
		c.BackgroundTransparency = 0.03
		lamp.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
		lamp.BackgroundTransparency = 0.3
		cc.Brightness = -0.06 * idx
		S:sfx("Boom", 0.28, 0.45 + idx * 0.03)
		S:sfx("Tick", 0.4, 0.4)
		S.shake = 0.25
		S:after(0.06, function()
			S.shake = 0
		end)
	end
	label.Text = ""
	-- 2) Silence in the dark; the camera moves unseen.
	S:lowShot({ dur = 1.4, d0 = 8, d1 = 6.5, a0 = -30, a1 = -10, roll0 = -10, roll1 = -4, fov0 = 60, fov1 = 52 })
	S:duck(0.15)
	S:phase(0.3)
	-- 3) Red emergency strobes, alternating halves, revealing the hero shot.
	for _, c in cols do
		c.BackgroundTransparency = 0.15
	end
	local left = S:frame({ BackgroundColor3 = col, BackgroundTransparency = 1, Size = UDim2.fromScale(0.5, 1), ZIndex = 20 })
	local right = S:frame({
		BackgroundColor3 = col,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.5, 1),
		ZIndex = 20,
	})
	local warnL = S:text({
		Text = "EMERGENCY POWER",
		FontFace = Kit.Title,
		TextSize = math.floor(40 * S.vs + 0.5),
		TextColor3 = col,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.new(1, 0, 0, 50),
		TextTransparency = 1,
		ZIndex = 32,
	})
	cc.Brightness = -0.05
	cc.TintColor = WHITE:Lerp(col, 0.5)
	cc.Contrast = 0.4
	S:burst(1.5)
	local lastBeat = -1
	-- reduced flashing: slow (< 3 Hz), faint pulses instead of strobes
	local calm = Ctx.Calm()
	local period = if calm then 0.42 else 0.14
	local floorT = if calm then 0.75 else 0.35
	S:phase(0.85, function(_: number, e: number)
		local beat = math.floor(e / period)
		local ph = (e % period) / period
		local onL = beat % 2 == 0
		left.BackgroundTransparency = if onL then floorT + (1 - floorT) * ph else 1
		right.BackgroundTransparency = if not onL then floorT + (1 - floorT) * ph else 1
		for _, c in cols do
			c.BackgroundTransparency = lerp(0.15, 1, seg(e, 0, 0.5))
		end
		warnL.TextTransparency = if ph < 0.5 then 0 else 0.6
		if beat ~= lastBeat then
			lastBeat = beat
			S:sfx("Error", 0.35, if onL then 1 else 0.85)
		end
	end)
	S:sfx("Boom", 0.7, 0.6)
	S:worldFlash(col, 0.6)
	S:outro(BLACK, 0.12, 0.5)
end

--------------------------------------------------------------------------------------------------------
-- CHROMATIC: every colour at once
--------------------------------------------------------------------------------------------------------

function Scenes.Chromatic(S: any)
	local sz = screen(S)
	local cx, cy = sz.X * 0.5, sz.Y * 0.5
	S:hideHud()
	local cc = S:cc()
	local dim = S:fill(BLACK, 8, 1)
	local holder = S:frame({ Name = "Prism", BackgroundTransparency = 1, ZIndex = 12 })
	local beam = S:line(0, cy, 0, cy, 5, WHITE, 13, holder)
	local beamGlow = S:line(0, cy, 0, cy, 16, WHITE, 12, holder)
	beamGlow.BackgroundTransparency = 0.7
	-- Prism: triangle outline.
	local tr = sz.Y * 0.11
	local pts = {}
	for i = 0, 2 do
		local ang = math.rad(-90 + i * 120)
		pts[i + 1] = { cx + math.cos(ang) * tr, cy + math.sin(ang) * tr }
	end
	local edgesL: { Frame } = {}
	for i = 1, 3 do
		local p1, p2 = pts[i], pts[i % 3 + 1]
		edgesL[i] = S:line(p1[1], p1[2], p2[1], p2[2], 4, WHITE, 15, holder)
		edgesL[i].BackgroundTransparency = 1
	end
	local fill = S:circle(14, WHITE, 0.12)
	fill.BackgroundTransparency = 1
	-- Rainbow fan.
	local fan = {}
	for i = 1, 7 do
		local ang = math.rad(lerp(-16, 16, (i - 1) / 6))
		local c = U.hsv((i - 1) / 7, 0.85, 1)
		local f = S:line(cx, cy, cx, cy, 7, c, 13, holder)
		local g = S:line(cx, cy, cx, cy, 20, c, 12, holder)
		g.BackgroundTransparency = 0.75
		fan[i] = { f = f, g = g, ang = ang }
	end
	-- R/G/B split layers.
	local layers: { Frame } = {}
	for i, c in { Color3.new(1, 0, 0), Color3.new(0, 1, 0), Color3.new(0, 0, 1) } do
		layers[i] = S:fill(c, 18, 1)
	end
	local gl = S:glitchLayer(22, { Color3.new(1, 0, 0), Color3.new(0, 1, 1), Color3.new(0, 1, 0), Color3.new(1, 0, 1), WHITE })

	S:orbitShot({ dur = 2.6, deg = 110, r0 = 12, r1 = 9, h0 = 3, h1 = 2, fov0 = 56, fov1 = 50, blend = 0.4 })
	S:sfx("Whoosh", 0.5, 1.3)
	-- 1) White beam enters and strikes the prism.
	S:phase(0.5, function(k: number)
		dim.BackgroundTransparency = 1 - 0.55 * outCubic(k)
		local x = (cx - tr * 0.5) * outCubic(k)
		setLine(beam, 0, cy, x, cy, 5)
		setLine(beamGlow, 0, cy, x, cy, 16)
		for _, e in edgesL do
			e.BackgroundTransparency = 1 - k
		end
	end)
	S:sfx("Reveal2", 0.45, 1.2)
	S:sfx("Glitch", 0.3, 1.6)
	fill.BackgroundTransparency = 0.6
	-- 2) Rainbow fan spreads to the right edge.
	S:phase(0.55, function(k: number)
		local q = outCubic(k)
		for _, it in fan do
			local len = (sz.X - cx) * 1.2 * q
			local x2, y2 = cx + math.cos(it.ang) * len, cy + math.sin(it.ang) * len
			setLine(it.f, cx, cy, x2, y2, 7)
			setLine(it.g, cx, cy, x2, y2, 20)
		end
		fill.BackgroundTransparency = 0.6 + 0.3 * math.sin(k * 30) ^ 2
		cc.Saturation = 0.6 * k
	end)
	-- 3) The screen splits into R / G / B.
	S:sfx("Glitch", 0.6, 0.9)
	S:sfx("Riser", 0.4, 1.5)
	local lastT = 0
	S:phase(1.0, function(k: number, e: number)
		local off = sz.X * 0.03 * bump(k) * (1 + 0.4 * math.sin(e * 23))
		for i, l in layers do
			l.BackgroundTransparency = 1 - 0.18 * bump(k)
			l.Position = UDim2.fromOffset((i - 2) * off, (i - 2) * off * 0.15)
		end
		holder.Position = UDim2.fromOffset(math.sin(e * 40) * off * 0.3, 0)
		gl.k = 0.2 + 0.5 * bump(k)
		cc.TintColor = U.hsv(e * 1.6, 0.35, 1)
		cc.Saturation = 0.6 + 0.4 * k
		S.shake = 0.3 * bump(k)
		if e - lastT > 0.18 then
			lastT = e
			S:sfx("Tick", 0.3, 0.8 + k)
		end
	end)
	-- Recombine into white light.
	S:sfx("Boom", 0.6, 1.1)
	S:burst(1.6)
	S:worldFlash(WHITE, 0.5)
	S:outro(WHITE, 0.14, 0.45)
end

return Scenes
