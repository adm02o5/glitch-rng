--!strict
-- Cutscene/Fx: the shared overlay + camera toolkit, installed as methods on Session.
--
--   overlays   edges, fill, flash, scanlines, glitchLayer, letterbox, terminal/typeLine, typeInto,
--              errorPopup, ring, circle, line, streaks, codeRain, branches, particles, stamp, crashScreen,
--              cracks, shatter, charView (live clone of the player's avatar in a ViewportFrame), nameCard
--   cameras    orbitShot, frontShot, skyShot, lookUpShot, lowShot (all blend in from the current view)
--   endings    outro (fade to a colour, peak cut, fade back to the restored world)

local Players = game:GetService("Players")

local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local U = require(script.Parent.Util)
local RNG = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RNG"))

local P = Kit.P
local WHITE, BLACK = U.WHITE, U.BLACK
local clamp01, lerp, seg = U.clamp01, U.lerp, U.seg
local outCubic, inCubic, outQuart, inOutSine, outBack, outExpo = U.outCubic, U.inCubic, U.outQuart, U.inOutSine, U.outBack, U.outExpo
local player = Players.LocalPlayer

local Fx = {}

function Fx.setT(list: { Frame }, t: number)
	local v = clamp01(t)
	for _, f in list do
		f.BackgroundTransparency = v
	end
end

function Fx.setC(list: { Frame }, c: Color3)
	for _, f in list do
		f.BackgroundColor3 = c
	end
end

-- Places a frame (AnchorPoint 0.5) as a line between two pixel points.
function Fx.setLine(f: Frame, x1: number, y1: number, x2: number, y2: number, thick: number?)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	f.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
	f.Size = UDim2.fromOffset(len, thick or f.Size.Y.Offset)
	f.Rotation = math.deg(math.atan2(dy, dx))
end

-- Clone() keeps ViewportFrame.CurrentCamera pointing at the original camera; re-point it at the copy.
function Fx.fixClone(root: Instance)
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, d in all do
		if d:IsA("ViewportFrame") then
			local cam = d:FindFirstChildOfClass("Camera")
			if cam then
				d.CurrentCamera = cam
			end
		end
	end
end

local function round(f: GuiObject, r: number?)
	Kit.new("UICorner", { CornerRadius = if r then UDim.new(0, r) else UDim.new(0.5, 0), Parent = f })
end

function Fx.install(Session: any)
	------------------------------------------------------------------------------------------------
	-- Basic overlays
	------------------------------------------------------------------------------------------------

	-- Four gradient strips hugging the screen edges (edge glow or vignette). Fade with Fx.setT.
	function Session.edges(S: any, color: Color3, depth: number, z: number): { Frame }
		local list = {}
		local sq = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.4, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		local specs = {
			{ size = UDim2.fromScale(1, depth), pos = UDim2.fromScale(0, 0), anchor = Vector2.new(0, 0), rot = 90 },
			{ size = UDim2.fromScale(1, depth), pos = UDim2.fromScale(0, 1), anchor = Vector2.new(0, 1), rot = -90 },
			{ size = UDim2.fromScale(depth * 0.62, 1), pos = UDim2.fromScale(0, 0), anchor = Vector2.new(0, 0), rot = 0 },
			{ size = UDim2.fromScale(depth * 0.62, 1), pos = UDim2.fromScale(1, 0), anchor = Vector2.new(1, 0), rot = 180 },
		}
		for _, sp in specs do
			local f = S:frame({
				Name = "Edge",
				BackgroundColor3 = color,
				BackgroundTransparency = 1,
				Size = sp.size,
				Position = sp.pos,
				AnchorPoint = sp.anchor,
				ZIndex = z,
			})
			Kit.new("UIGradient", { Transparency = sq, Rotation = sp.rot, Parent = f })
			table.insert(list, f)
		end
		return list
	end

	-- Full-screen solid layer.
	function Session.fill(S: any, color: Color3, z: number, transparency: number?, parent: Instance?): Frame
		return S:frame({
			Name = "Fill",
			BackgroundColor3 = color,
			BackgroundTransparency = transparency or 1,
			ZIndex = z,
			Parent = parent,
		})
	end

	-- Non-blocking flash: snaps to `peak` opacity, fades out over `dur`, removes itself.
	function Session.flash(S: any, color: Color3, peak: number, dur: number, z: number?)
		local f = S:fill(color, z or 170, 1 - peak)
		local t0 = os.clock()
		S:loop(function(now: number)
			local k = clamp01((now - t0) / dur)
			f.BackgroundTransparency = 1 - peak * (1 - outCubic(k))
			if k >= 1 then
				f:Destroy()
				return true
			end
			return false
		end)
	end

	-- Horizontal scanlines (a CRT feel). Returns the holder; fade with holder visibility/transparency.
	function Session.scanlines(S: any, z: number, color: Color3?, spacing: number?, transparency: number?, parent: Instance?): Frame
		local holder = S:frame({ Name = "Scanlines", BackgroundTransparency = 1, ZIndex = z, Parent = parent })
		local abs = S.gui.AbsoluteSize
		local sp = spacing or 4
		local n = math.min(260, math.floor(abs.Y / sp))
		for i = 0, n do
			Kit.new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = color or BLACK,
				BackgroundTransparency = transparency or 0.8,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromScale(0, i / n),
				ZIndex = z,
				Parent = holder,
			})
		end
		return holder
	end

	-- Thin straight line between two pixel points.
	function Session.line(S: any, x1: number, y1: number, x2: number, y2: number, thick: number, color: Color3, z: number, parent: Instance?): Frame
		local f = S:frame({
			Name = "Line",
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = z,
			Parent = parent,
		})
		Session.setLine(f, x1, y1, x2, y2, thick)
		return f
	end

	Session.setLine = Fx.setLine

	-- Circle outline (stroke) or disc (filled) centred at a scale/offset position. Size relative to height.
	function Session.circle(S: any, z: number, color: Color3, size: number, thick: number?, parent: Instance?): Frame
		local f = S:frame({
			Name = "Circle",
			BackgroundColor3 = color,
			BackgroundTransparency = if thick then 1 else 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Size = UDim2.fromScale(size, size),
			ZIndex = z,
			Parent = parent,
		})
		round(f)
		if thick then
			Kit.new("UIStroke", { Color = color, Thickness = thick, Parent = f })
		end
		return f
	end

	-- Expanding ring that removes itself.
	function Session.ring(S: any, z: number, color: Color3, dur: number, maxSize: number, thick: number, pos: UDim2?)
		local r = S:circle(z, color, 0, thick)
		if pos then
			r.Position = pos
		end
		local st = r:FindFirstChildOfClass("UIStroke") :: UIStroke
		local t0 = os.clock()
		S:loop(function(now: number)
			local k = clamp01((now - t0) / dur)
			local s = maxSize * outQuart(k)
			r.Size = UDim2.fromScale(s, s)
			st.Transparency = k ^ 1.4
			st.Thickness = thick * (1 - k * 0.7)
			if k >= 1 then
				r:Destroy()
				return true
			end
			return false
		end)
	end

	------------------------------------------------------------------------------------------------
	-- Glitch layer
	------------------------------------------------------------------------------------------------

	-- Full-screen digital glitch: paired RGB-split bars, block noise and black tear strips. Drive g.k (0..1+).
	function Session.glitchLayer(S: any, z: number, palette: { Color3 }?): any
		local holder = S:frame({ Name = "Glitch", BackgroundTransparency = 1, ZIndex = z, Visible = false })
		local g: any = { k = 0, nextTick = 0, holder = holder }
		local pal = palette or { P.Cyan, P.Magenta, P.Red, WHITE, S.tier.color, S.aura.color, S.aura.color2 }
		local splitA = pal[1] or P.Cyan
		local splitB = pal[2] or P.Magenta
		local bars: { Frame } = {}
		local blocks: { Frame } = {}
		local tears: { Frame } = {}
		for i = 1, 32 do
			bars[i] = Kit.new("Frame", { BorderSizePixel = 0, Visible = false, ZIndex = 2 + i % 2, Parent = holder })
		end
		for i = 1, 44 do
			blocks[i] = Kit.new("Frame", { BorderSizePixel = 0, Visible = false, ZIndex = 4, Parent = holder })
		end
		for i = 1, 5 do
			tears[i] = Kit.new("Frame", {
				BorderSizePixel = 0,
				Visible = false,
				BackgroundColor3 = BLACK,
				Size = UDim2.fromScale(1, 0.01),
				ZIndex = 1,
				Parent = holder,
			})
		end
		S:loop(function(now: number)
			local k = g.k
			holder.Visible = k > 0.01
			if k <= 0.01 or now < g.nextTick then
				return
			end
			local rng = S.rng
			g.nextTick = now + rng:NextNumber(0.025, 0.06) / (0.6 + k * 0.6)
			local kk = math.min(k, 1.4)
			for i = 1, #bars, 2 do
				local a, b = bars[i], bars[i + 1]
				if rng:NextNumber() < kk * 0.8 then
					local y = rng:NextNumber(-0.02, 1)
					local h = 0.002 + rng:NextNumber() ^ 2.2 * 0.07 * kk
					local w = rng:NextNumber(0.25, 1.3)
					local x = rng:NextNumber(-0.3, 1) * (1 - w * 0.5)
					local split = rng:NextNumber(0.003, 0.02) * (0.5 + kk)
					local tr = 1 - rng:NextNumber(0.2, 0.65) * math.min(1, kk + 0.25)
					local c = pal[rng:NextInteger(1, #pal)]
					a.Visible = true
					b.Visible = true
					a.Position = UDim2.fromScale(x - split, y)
					b.Position = UDim2.fromScale(x + split, y + rng:NextNumber(-0.002, 0.002))
					a.Size = UDim2.fromScale(w, h)
					b.Size = UDim2.fromScale(w * rng:NextNumber(0.85, 1.1), h)
					a.BackgroundColor3 = splitA:Lerp(c, 0.35)
					b.BackgroundColor3 = splitB:Lerp(c, 0.25)
					a.BackgroundTransparency = tr
					b.BackgroundTransparency = math.min(1, tr + 0.08)
				else
					a.Visible = false
					b.Visible = false
				end
			end
			for _, bl in blocks do
				if rng:NextNumber() < kk * 0.55 then
					bl.Visible = true
					local w = rng:NextNumber(0.008, 0.03 + 0.1 * kk)
					local h = rng:NextNumber(0.006, 0.02 + 0.05 * kk)
					bl.Size = UDim2.fromScale(w, h)
					bl.Position = UDim2.fromScale(rng:NextNumber(-0.02, 1), rng:NextNumber(-0.02, 1))
					local dark = rng:NextNumber() < 0.3
					bl.BackgroundColor3 = if dark then BLACK else pal[rng:NextInteger(1, #pal)]
					bl.BackgroundTransparency = if dark then rng:NextNumber(0.05, 0.4) else rng:NextNumber(0.3, 0.8)
				else
					bl.Visible = false
				end
			end
			for _, t in tears do
				if rng:NextNumber() < kk * 0.35 then
					t.Visible = true
					t.Position = UDim2.fromScale(0, rng:NextNumber())
					t.Size = UDim2.fromScale(1, rng:NextNumber(0.003, 0.025) * kk)
					t.BackgroundTransparency = rng:NextNumber(0.1, 0.5)
				else
					t.Visible = false
				end
			end
			return false
		end)
		return g
	end

	------------------------------------------------------------------------------------------------
	-- Letterbox + terminal
	------------------------------------------------------------------------------------------------

	-- Cinematic bars with a live ticker on top and a spaced caption on the bottom. Drive with L.k.
	function Session.letterbox(S: any, z: number, topText: string, bottomText: string, accent: Color3): any
		local H = 0.105
		local fs = math.floor(13 * S.vs + 0.5)
		local top = S:frame({ Name = "LetterTop", Size = UDim2.fromScale(1, H), Position = UDim2.fromScale(0, -H), ZIndex = z })
		local bot = S:frame({
			Name = "LetterBottom",
			Size = UDim2.fromScale(1, H),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1 + H),
			ZIndex = z,
		})
		for _, f in { top, bot } do
			local ln = Kit.new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = accent,
				Size = UDim2.new(1, 0, 0, 2),
				AnchorPoint = Vector2.new(0, if f == top then 1 else 0),
				Position = UDim2.fromScale(0, if f == top then 1 else 0),
				Parent = f,
			})
			Kit.new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.2, 0.2),
					NumberSequenceKeypoint.new(0.8, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Parent = ln,
			})
		end
		local topL = S:text({
			Text = topText,
			FontFace = Kit.MonoBold,
			TextSize = fs,
			TextColor3 = accent:Lerp(WHITE, 0.3),
			Position = UDim2.new(0, 28, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(0.7, 0, 0, fs + 4),
			Parent = top,
		})
		local rec = S:text({
			FontFace = Kit.MonoBold,
			TextSize = fs,
			TextColor3 = P.Red,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -28, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.new(0.3, 0, 0, fs + 4),
			Parent = top,
		})
		local botL = S:text({
			Text = bottomText,
			FontFace = Kit.Title,
			TextSize = math.floor(16 * S.vs + 0.5),
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 24),
			Parent = bot,
		})
		local L: any = { k = 0, top = top, bot = bot, topL = topL, botL = botL }
		S:loop(function(now: number)
			local k = L.k
			top.Position = UDim2.fromScale(0, -H * (1 - k))
			bot.Position = UDim2.fromScale(0, 1 + H * (1 - k))
			local blink = (now * 2) % 1 < 0.6
			rec.Text = (if blink then "REC  " else "     ") .. string.format("T+%05.2f", now - S.start)
			return false
		end)
		return L
	end

	-- Hacker terminal panel. T.add(text, color) adds a line; progress bar at the bottom.
	function Session.terminal(S: any, nLines: number, z: number, title: string?, accent: Color3?): any
		local tc = accent or S.tier.color
		local lineH = 26
		local w = 620
		local h = 48 + nLines * lineH + 58
		local panel = Kit.panel(S.gui, {
			Name = "Terminal",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.045, 0.55),
			Size = UDim2.fromOffset(w, h),
			ZIndex = z,
			BackgroundTransparency = 0.08,
		}, tc)
		local sc = Kit.new("UIScale", { Scale = S.vs * 0.92, Parent = panel })
		local header = Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = tc,
			BackgroundTransparency = 0.82,
			Size = UDim2.new(1, 0, 0, 32),
			Parent = panel,
		})
		Kit.new("UIGradient", { Transparency = NumberSequence.new(0, 0.9), Parent = header })
		for i, col in { P.Red, P.Amber, P.Lime } do
			local dot = Kit.new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = col,
				Size = UDim2.fromOffset(9, 9),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12 + (i - 1) * 15, 0.5, 0),
				Parent = header,
			})
			Kit.corner(dot, 5)
		end
		S:text({
			Text = title or "root@fate:~# ./trace --signature --deep",
			FontFace = Kit.MonoBold,
			TextSize = 14,
			TextColor3 = P.Text,
			Position = UDim2.new(0, 62, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(1, -150, 0, 18),
			Parent = header,
		})
		local live = S:text({
			Text = "LIVE",
			FontFace = Kit.MonoBold,
			TextSize = 13,
			TextColor3 = P.Red,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -14, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(80, 18),
			Parent = header,
		})
		local body = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(18, 44),
			Size = UDim2.new(1, -36, 0, nLines * lineH),
			ClipsDescendants = true,
			Parent = panel,
		})
		for i = 0, math.floor(h / 4) do
			Kit.new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = BLACK,
				BackgroundTransparency = 0.82,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromOffset(0, i * 4),
				ZIndex = 3,
				Parent = panel,
			})
		end
		local track = Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = P.Line,
			Position = UDim2.new(0, 18, 1, -30),
			Size = UDim2.new(1, -100, 0, 10),
			Parent = panel,
		})
		Kit.corner(track, 2)
		local fill = Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = WHITE,
			Size = UDim2.fromScale(0, 1),
			Parent = track,
		})
		Kit.corner(fill, 2)
		Kit.new("UIGradient", {
			Color = ColorSequence.new(tc, S.aura.color:Lerp(WHITE, 0.2)),
			Parent = fill,
		})
		local pctL = S:text({
			Text = "0%",
			FontFace = Kit.MonoBold,
			TextSize = 15,
			TextColor3 = tc,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -18, 1, -25),
			Size = UDim2.fromOffset(70, 18),
			Parent = panel,
		})
		local T: any = { panel = panel, scale = sc, n = 0, fill = fill, pctL = pctL }
		function T.add(text: string, color: Color3?): TextLabel
			T.n += 1
			return S:text({
				Text = text,
				FontFace = Kit.MonoBold,
				TextSize = 17,
				TextColor3 = color or P.Text,
				Position = UDim2.fromOffset(0, (T.n - 1) * lineH),
				Size = UDim2.new(1, 0, 0, lineH),
				Parent = body,
			})
		end
		function T.progress(p: number)
			fill.Size = UDim2.fromScale(clamp01(p), 1)
			pctL.Text = math.floor(clamp01(p) * 100) .. "%"
		end
		S:loop(function(now: number)
			live.TextTransparency = if (now * 1.6) % 1 < 0.55 then 0 else 0.75
			return false
		end)
		return T
	end

	-- Types a terminal line with a blinking cursor, optional animated trailing dots while holding. Blocking.
	function Session.typeLine(S: any, term: any, text: string, color: Color3?, cps: number, hold: number, dots: boolean?)
		local l = term.add("", color)
		local n = #text
		local last = 0
		local typeT = n / cps
		S:phase(typeT + hold, function(_: number, e: number)
			local c = math.min(n, math.floor(e * cps))
			local cursor = if (e * 3) % 1 < 0.5 then "_" else " "
			if c < n then
				l.Text = text:sub(1, c) .. cursor
			elseif dots then
				l.Text = text .. string.rep(".", 1 + math.floor((e - typeT) * 7) % 3)
			else
				l.Text = text .. (if e - typeT < hold * 0.8 then cursor else "")
			end
			if c ~= last then
				if c % 2 == 0 then
					S:sfx("Type", 0.22, 0.9 + S.rng:NextNumber() * 0.25)
				end
				last = c
			end
		end)
		l.Text = if dots then text .. "..." else text
		return l
	end

	-- Non-blocking typewriter into any label. Returns a handle with .done.
	function Session.typeInto(S: any, label: TextLabel, text: string, cps: number, volume: number?, cursor: boolean?): any
		local h: any = { done = false }
		local n = utf8.len(text) or #text
		local t0 = os.clock()
		local last = 0
		label.Text = text
		label.MaxVisibleGraphemes = 0
		S:loop(function(now: number)
			local c = math.min(n, math.floor((now - t0) * cps))
			if c ~= last then
				label.MaxVisibleGraphemes = c
				if volume and volume > 0 and c % 2 == 0 then
					S:sfx("Type", volume, 0.9 + S.rng:NextNumber() * 0.3)
				end
				last = c
			end
			if c >= n then
				label.MaxVisibleGraphemes = -1
				if cursor then
					label.Text = text .. "_"
				end
				h.done = true
				return true
			end
			return false
		end)
		return h
	end

	-- Small "not responding" error popup.
	function Session.errorPopup(S: any, z: number, msg: string, corrupted: boolean, title: string?, pos: UDim2?): Frame
		local rng = S.rng
		local accent = if corrupted then P.Red else P.Magenta
		local w = Kit.panel(S.gui, {
			Name = "ErrorPopup",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos or UDim2.fromScale(rng:NextNumber(0.14, 0.86), rng:NextNumber(0.16, 0.84)),
			Size = UDim2.fromOffset(330, 104),
			ZIndex = z,
			BackgroundTransparency = 0.04,
		}, accent)
		local sc = Kit.new("UIScale", { Scale = S.vs * 0.3, Parent = w })
		Kit.tween(sc, 0.22, { Scale = S.vs * 0.85 }, Enum.EasingStyle.Back)
		local bar = Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.55,
			Size = UDim2.new(1, 0, 0, 26),
			Parent = w,
		})
		S:text({
			Text = title or (if corrupted then U.corrupt(rng, "FATE.EXE - FATAL", 0.3) else "FATE.EXE - Not Responding"),
			FontFace = Kit.MonoBold,
			TextSize = 13,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -40, 1, 0),
			Parent = bar,
		})
		S:text({
			Text = "X",
			FontFace = Kit.MonoBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 0),
			Size = UDim2.fromOffset(24, 26),
			Parent = bar,
		})
		S:text({
			Text = "/!\\",
			FontFace = Kit.Pixel,
			TextSize = 16,
			TextColor3 = if corrupted then P.Red else P.Amber,
			Position = UDim2.fromOffset(14, 44),
			Size = UDim2.fromOffset(52, 28),
			Parent = w,
		})
		S:text({
			Text = msg,
			FontFace = Kit.Mono,
			TextSize = 14,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(74, 38),
			Size = UDim2.new(1, -86, 0, 56),
			Parent = w,
		})
		return w
	end

	-- Rubber stamp that slams onto the screen (big -> 1 with overshoot). Returns the frame.
	function Session.stamp(S: any, text: string, color: Color3, pos: UDim2, rot: number, size: number, z: number, parent: Instance?): Frame
		local fs = math.floor(size * S.vs + 0.5)
		local f = S:frame({
			Name = "Stamp",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Rotation = rot,
			ZIndex = z,
			Parent = parent,
		})
		Kit.new("UIPadding", {
			PaddingLeft = UDim.new(0, fs * 0.45),
			PaddingRight = UDim.new(0, fs * 0.45),
			PaddingTop = UDim.new(0, fs * 0.15),
			PaddingBottom = UDim.new(0, fs * 0.15),
			Parent = f,
		})
		Kit.new("UIStroke", {
			Color = color,
			Thickness = math.max(3, fs * 0.09),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = f,
		})
		Kit.corner(f, math.floor(fs * 0.12))
		local l = S:text({
			Text = text,
			FontFace = Kit.Title,
			TextSize = fs,
			TextColor3 = color,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			ZIndex = z,
			Parent = f,
		})
		local sc = Kit.new("UIScale", { Scale = 3.2, Parent = f })
		local t0 = os.clock()
		S:loop(function(now: number)
			local k = clamp01((now - t0) / 0.2)
			sc.Scale = lerp(3.2, 1, outBack(k))
			l.TextTransparency = 1 - math.min(1, k * 2.5)
			local st = f:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = l.TextTransparency
			end
			return k >= 1
		end)
		return f
	end

	------------------------------------------------------------------------------------------------
	-- Streaks, code rain, branches, particles
	------------------------------------------------------------------------------------------------

	-- Radial streak lines: mode "in" (sucked to the centre) or "out" (speed lines). Drive with st.k.
	function Session.streaks(S: any, z: number, count: number, color: Color3): any
		local holder = S:frame({ Name = "Streaks", BackgroundTransparency = 1, ZIndex = z })
		local st: any = { k = 0, mode = "in", holder = holder, cx = 0.5, cy = 0.5 }
		local items = {}
		for i = 1, count do
			local f = Kit.new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = if i % 3 == 0 then color else WHITE,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(60, 2),
				Parent = holder,
			})
			Kit.new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = f })
			items[i] = {
				f = f,
				ang = S.rng:NextNumber(0, math.pi * 2),
				ph = S.rng:NextNumber(),
				sp = S.rng:NextNumber(0.6, 1.4),
				len = S.rng:NextNumber(0.6, 1.4),
			}
		end
		local t0 = os.clock()
		S:loop(function(now: number)
			local k = st.k
			holder.Visible = k > 0.01
			if k <= 0.01 then
				return false
			end
			local abs = S.gui.AbsoluteSize
			local maxR = abs.Magnitude * 0.55
			local e = now - t0
			for _, it in items do
				local frac = (e * it.sp * (0.5 + k) + it.ph) % 1
				local r, tr, len
				if st.mode == "in" then
					r = (1 - frac) * maxR
					tr = 1 - k * frac * 0.85
					len = (40 + 160 * (1 - frac)) * it.len * (0.5 + k)
				else
					r = (0.15 + frac * 0.95) * maxR
					tr = 1 - k * (1 - frac) * 0.9
					len = (80 + 420 * frac) * it.len * k
				end
				local cx, cy = math.cos(it.ang), math.sin(it.ang)
				local f = it.f
				f.Position = UDim2.new(st.cx, cx * r, st.cy, cy * r)
				f.Size = UDim2.fromOffset(len, if st.mode == "in" then 2 else 3)
				f.Rotation = math.deg(it.ang) + (if st.mode == "in" then 0 else 180)
				f.BackgroundTransparency = tr
			end
			return false
		end)
		return st
	end

	-- Matrix-style code rain. Drive R.k (opacity/density 0..1), R.speed, R.tilt (degrees, storm swirl).
	function Session.codeRain(S: any, z: number, color: Color3, columns: number, parent: Instance?): any
		local holder = S:frame({
			Name = "CodeRain",
			BackgroundTransparency = 1,
			ZIndex = z,
			ClipsDescendants = true,
			Parent = parent,
		})
		local rng = S.rng
		local fs = math.floor(16 * S.vs + 0.5)
		local R: any = { k = 0, speed = 1, tilt = 0, holder = holder, color = color }
		local cols = {}
		local function chars(n: number): string
			local t = table.create(n)
			for i = 1, n do
				local r = rng:NextInteger(1, 3)
				t[i] = if r == 1
					then string.char(rng:NextInteger(48, 49))
					elseif r == 2 then string.format("%X", rng:NextInteger(0, 15))
					else string.char(rng:NextInteger(65, 90))
			end
			return table.concat(t, "\n")
		end
		for i = 1, columns do
			local n = rng:NextInteger(8, 22)
			local col = Kit.new("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 1),
				Size = UDim2.fromOffset(fs, n * fs),
				ZIndex = z,
				Parent = holder,
			})
			local trail = S:text({
				Text = chars(n),
				FontFace = Kit.MonoBold,
				TextSize = fs,
				LineHeight = 1,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				Parent = col,
			})
			Kit.new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.75, 0.35),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Parent = trail,
			})
			local head = S:text({
				Text = string.char(rng:NextInteger(65, 90)),
				FontFace = Kit.MonoBold,
				TextSize = fs,
				TextColor3 = WHITE,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.fromOffset(fs, fs),
				ZIndex = z + 1,
				Parent = col,
			})
			cols[i] = {
				col = col,
				trail = trail,
				head = head,
				n = n,
				x = (i - 0.5) / columns + rng:NextNumber(-0.3, 0.3) / columns,
				y = rng:NextNumber(-0.2, 1.4),
				v = rng:NextNumber(0.35, 1.0),
				thr = rng:NextNumber(),
				nextSwap = 0,
			}
		end
		S:loop(function(now: number, dt: number)
			local k = R.k
			holder.Visible = k > 0.01
			if k <= 0.01 then
				return false
			end
			for _, c in cols do
				c.y += c.v * R.speed * dt
				local hpx = c.n * fs
				local hs = hpx / math.max(1, S.gui.AbsoluteSize.Y)
				if c.y > 1 + hs + 0.05 then
					c.y = -0.05
					c.x = rng:NextNumber(0, 1)
				end
				local on = c.thr < k
				c.col.Visible = on
				if on then
					c.col.Position = UDim2.fromScale(c.x, c.y)
					c.col.Rotation = R.tilt
					local a = 1 - math.min(1, (k - c.thr) * 3)
					c.trail.TextTransparency = a
					c.head.TextTransparency = a
					c.trail.TextColor3 = R.color
					if now >= c.nextSwap then
						c.nextSwap = now + rng:NextNumber(0.05, 0.16)
						c.head.Text = string.char(rng:NextInteger(33, 90))
						if rng:NextNumber() < 0.25 then
							c.trail.Text = chars(c.n)
						end
					end
				end
			end
			return false
		end)
		return R
	end

	-- Branching growth (roots, lightning, neurons, cracks). origins = { {x, y, angleRad} } in pixels.
	-- B.set(k) reveals segments in growth order; B.setT(t) fades all.
	function Session.branches(S: any, z: number, origins: { { number } }, o: { [string]: any }): any
		local rng = S.rng
		local holder = S:frame({ Name = "Branches", BackgroundTransparency = 1, ZIndex = z, Parent = o.parent })
		local color: Color3 = o.color or WHITE
		local steps: number = o.steps or 14
		local stepLen: number = (o.len or 34) * S.vs
		local jitter: number = o.jitter or 0.45
		local chance: number = o.branch or 0.18
		local thick: number = o.thick or 3
		local glow: boolean = o.glow ~= false
		local segs = {}
		local function walk(x: number, y: number, a: number, step0: number, n: number, th: number, depth: number)
			for i = 1, n do
				a += rng:NextNumber(-jitter, jitter)
				if o.bias then
					a = a + (o.bias - a) * 0.12
				end
				local l = stepLen * rng:NextNumber(0.6, 1.25)
				local x2, y2 = x + math.cos(a) * l, y + math.sin(a) * l
				local t = (step0 + i - 1) / steps
				local core = S:frame({
					Name = "Seg",
					BackgroundColor3 = if o.core then o.core else color:Lerp(WHITE, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					ZIndex = z + 1,
					Parent = holder,
				})
				local halo: Frame? = nil
				if glow then
					halo = S:frame({
						Name = "Glow",
						BackgroundColor3 = color,
						BackgroundTransparency = 0.6,
						AnchorPoint = Vector2.new(0.5, 0.5),
						ZIndex = z,
						Parent = holder,
					})
				end
				table.insert(segs, { core = core, halo = halo, x1 = x, y1 = y, x2 = x2, y2 = y2, t = t, th = th })
				Session.setLine(core, x, y, x, y, th)
				if halo then
					Session.setLine(halo, x, y, x, y, th * 3)
				end
				if depth < 3 and rng:NextNumber() < chance and i < n - 1 then
					local side = if rng:NextNumber() < 0.5 then -1 else 1
					walk(x2, y2, a + side * rng:NextNumber(0.5, 1.1), step0 + i, math.floor((n - i) * rng:NextNumber(0.4, 0.8)), math.max(1, th * 0.6), depth + 1)
				end
				x, y = x2, y2
				th = math.max(1, th * (o.taper or 0.95))
			end
		end
		for _, og in origins do
			walk(og[1], og[2], og[3], 0, steps, thick, 0)
		end
		local B: any = { holder = holder, segs = segs }
		local dt = 1 / steps
		function B.set(k: number)
			for _, s in segs do
				local kk = clamp01((k - s.t) / dt)
				local x2 = s.x1 + (s.x2 - s.x1) * kk
				local y2 = s.y1 + (s.y2 - s.y1) * kk
				s.core.Visible = kk > 0
				Session.setLine(s.core, s.x1, s.y1, x2, y2, s.th)
				if s.halo then
					s.halo.Visible = kk > 0
					Session.setLine(s.halo, s.x1, s.y1, x2, y2, s.th * 3)
				end
			end
		end
		function B.setT(t: number)
			for _, s in segs do
				s.core.BackgroundTransparency = t
				if s.halo then
					s.halo.BackgroundTransparency = lerp(0.6, 1, t)
				end
			end
		end
		function B.color(c: Color3)
			for _, s in segs do
				if s.halo then
					s.halo.BackgroundColor3 = c
				end
			end
		end
		B.set(0)
		return B
	end

	-- Simple 2D particle system. o: colors, size {a,b}, speed {a,b} (px/s), angle {a,b} (rad), gravity (px/s^2),
	-- life {a,b}, spin, from(): (x, y) spawn point in pixels, round (bool), drag.
	-- E.rate = particles per second; E.emit(n) bursts.
	function Session.particles(S: any, z: number, o: { [string]: any }): any
		local rng = S.rng
		local holder = S:frame({ Name = "Particles", BackgroundTransparency = 1, ZIndex = z, Parent = o.parent })
		local live = {}
		local E: any = { rate = 0, acc = 0, holder = holder }
		local colors: { Color3 } = o.colors or { WHITE }
		local function r2(t: { number }?, d: number): number
			if not t then
				return d
			end
			return rng:NextNumber(t[1], t[2])
		end
		function E.emit(n: number)
			for _ = 1, n do
				local x, y = o.from()
				local s = r2(o.size, 6) * S.vs
				local f = Kit.new("Frame", {
					BorderSizePixel = 0,
					BackgroundColor3 = colors[rng:NextInteger(1, #colors)],
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(x, y),
					Size = UDim2.fromOffset(s, s * (o.aspect or 1)),
					ZIndex = z,
					Parent = holder,
				})
				if o.round then
					round(f)
				end
				local ang = r2(o.angle, -math.pi / 2)
				local sp = r2(o.speed, 100) * S.vs
				table.insert(live, {
					f = f,
					x = x,
					y = y,
					vx = math.cos(ang) * sp,
					vy = math.sin(ang) * sp,
					vr = r2(o.spin, 0),
					life = r2(o.life, 1.2),
					age = 0,
					a0 = o.alpha or 0,
				})
			end
		end
		S:loop(function(_: number, dt: number)
			if E.rate > 0 then
				E.acc += E.rate * dt
				local n = math.floor(E.acc)
				if n > 0 then
					E.acc -= n
					E.emit(math.min(n, 30))
				end
			end
			local g = o.gravity or 0
			local drag = o.drag or 0
			for i = #live, 1, -1 do
				local p = live[i]
				p.age += dt
				if p.age >= p.life then
					p.f:Destroy()
					table.remove(live, i)
				else
					if o.pull then
						local px, py = o.pull()
						local dx, dy = px - p.x, py - p.y
						local d = math.max(8, math.sqrt(dx * dx + dy * dy))
						local acc = (o.pullStrength or 1800) * S.vs
						p.vx += dx / d * acc * dt + (-dy / d) * (o.swirl or 0) * dt
						p.vy += dy / d * acc * dt + (dx / d) * (o.swirl or 0) * dt
						if d < 14 then
							p.age = p.life
						end
					end
					p.vy += g * dt
					p.vx *= 1 - drag * dt
					p.vy *= 1 - drag * dt
					p.x += p.vx * dt
					p.y += p.vy * dt
					p.f.Position = UDim2.fromOffset(p.x, p.y)
					p.f.Rotation += p.vr * dt
					local k = p.age / p.life
					p.f.BackgroundTransparency = lerp(p.a0, 1, k ^ 2)
				end
			end
			return false
		end)
		return E
	end

	------------------------------------------------------------------------------------------------
	-- Crash screen, cracks, shatter
	------------------------------------------------------------------------------------------------

	function Session.crashScreen(S: any, corrupted: boolean, z: number): any
		local rng = S.rng
		local tc = S.tier.color
		local vs = S.vs
		local abs = S.gui.AbsoluteSize
		local fg = if corrupted then P.Red else WHITE
		local accent = if corrupted then P.Red:Lerp(WHITE, 0.25) else tc:Lerp(WHITE, 0.35)

		local root = S:frame({
			Name = "Crash",
			BackgroundColor3 = if corrupted then Color3.fromRGB(4, 0, 2) else Color3.fromRGB(18, 46, 150),
			ZIndex = z,
		})
		Kit.new("UIGradient", {
			Color = if corrupted
				then ColorSequence.new(Color3.fromRGB(40, 0, 8), Color3.fromRGB(0, 0, 0))
				else ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 130, 190)),
			Rotation = 90,
			Parent = root,
		})
		for i = 0, 90 do
			Kit.new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = if corrupted then P.Red else BLACK,
				BackgroundTransparency = if corrupted then 0.94 else 0.9,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromScale(0, i / 90),
				ZIndex = 1,
				Parent = root,
			})
		end
		local labels: { { l: TextLabel, text: string } } = {}
		local function add(text: string, size: number, x: number, y: number, props: { [string]: any }?): TextLabel
			local p: { [string]: any } = {
				Text = text,
				TextSize = math.floor(size * vs + 0.5),
				TextColor3 = fg,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.new(0.11, x, y, 0),
				Size = UDim2.new(0.74, -x, 0, math.floor((size + 6) * vs * 2 + 0.5)),
				ZIndex = 3,
				Parent = root,
			}
			if props then
				for k, v in props do
					p[k] = v
				end
			end
			local l = S:text(p)
			table.insert(labels, { l = l, text = text })
			return l
		end

		if corrupted then
			local rows = {}
			for _ = 1, 34 do
				local parts = { "0x" .. U.hex(rng, 6) .. " " }
				for _ = 1, 8 do
					table.insert(parts, U.hex(rng, 2))
				end
				table.insert(rows, table.concat(parts, " "))
			end
			local dump = add(table.concat(rows, "\n"), 13, 0, 0.04, {
				Position = UDim2.fromScale(0.62, 0.04),
				Size = UDim2.fromScale(0.36, 0.92),
				TextColor3 = P.Red,
				TextTransparency = 0.72,
				ZIndex = 2,
			})
			dump.TextWrapped = false
			local banner = add("!! KERNEL MEMORY CORRUPTED !! INTEGRITY 0% !! DO NOT POWER OFF REALITY !!", 15, 0, 0.045, {
				FontFace = Kit.MonoBold,
				TextColor3 = P.Red,
			})
			banner.TextWrapped = false
		end

		local glyphText = if corrupted then "X(" else ":("
		local glyphSize = math.floor(150 * vs + 0.5)
		local glyph = add(glyphText, 150, 0, 0.12, {
			FontFace = Kit.Title,
			TextSize = glyphSize,
			Size = UDim2.fromOffset(glyphSize * 2, glyphSize + 20),
			TextWrapped = false,
			ZIndex = 5,
		})
		local glyphA = glyph:Clone()
		glyphA.TextColor3 = P.Cyan
		glyphA.TextTransparency = 0.45
		glyphA.ZIndex = 4
		glyphA.Parent = root
		local glyphB = glyph:Clone()
		glyphB.TextColor3 = P.Magenta
		glyphB.TextTransparency = 0.45
		glyphB.ZIndex = 4
		glyphB.Parent = root

		add("FATE.EXE has encountered a critical anomaly and needs to restart.", 30, 0, 0.38, { FontFace = Kit.Mono })
		add(
			if corrupted
				then "Your reality ran into a problem it cannot recover from. We are collecting what is left of it."
				else "We're just collecting some anomaly info, and then we'll restart reality for you.",
			19,
			0,
			0.49,
			{ TextColor3 = fg:Lerp(BLACK, 0.12) }
		)
		local pctL = add("0% complete", 24, 0, 0.585, { FontFace = Kit.MonoBold })
		pctL.TextWrapped = false
		local track = S:frame({
			BackgroundColor3 = if corrupted then Color3.fromRGB(60, 0, 10) else Color3.fromRGB(10, 26, 100),
			Position = UDim2.fromScale(0.11, 0.655),
			Size = UDim2.new(0.42, 0, 0, math.max(4, math.floor(6 * vs))),
			ZIndex = 3,
			Parent = root,
		})
		local fill = S:frame({ BackgroundColor3 = accent, Size = UDim2.fromScale(0, 1), ZIndex = 4, Parent = track })

		-- Fake QR code (row runs merged into single frames to keep the instance count low).
		local qrPx = math.floor(abs.Y * 0.15)
		local cells = 11
		local cell = qrPx / cells
		local qr = S:frame({
			Name = "QR",
			BackgroundColor3 = if corrupted then BLACK else WHITE,
			Position = UDim2.new(0.11, 0, 0.71, 0),
			Size = UDim2.fromOffset(qrPx + 8, qrPx + 8),
			ZIndex = 3,
			Parent = root,
		})
		local qrInk = if corrupted then P.Red else Color3.fromRGB(18, 46, 150)
		for r = 0, cells - 1 do
			local c = 0
			while c < cells do
				local finder = (r < 3 and (c < 3 or c >= cells - 3)) or (r >= cells - 3 and c < 3)
				local on = finder or rng:NextNumber() < 0.5
				if on then
					local start = c
					while c < cells do
						local f2 = (r < 3 and (c < 3 or c >= cells - 3)) or (r >= cells - 3 and c < 3)
						if not (f2 or rng:NextNumber() < 0.55) then
							break
						end
						c += 1
					end
					S:frame({
						BackgroundColor3 = qrInk,
						Position = UDim2.fromOffset(4 + start * cell, 4 + r * cell),
						Size = UDim2.fromOffset(math.max(1, (c - start) * cell), math.ceil(cell)),
						ZIndex = 4,
						Parent = qr,
					})
				end
				c += 1
			end
		end

		local infoX = qrPx + 30
		local stop = S.tier.id:upper() .. "_SIGNATURE_OVERFLOW"
		local failed = if S.exclusive then (S.biome and S.biome.id:lower() or "biome") .. ".sys" else "fate_core.sys"
		add("For more information about this anomaly, visit https://glitch.rng/stopcode", 15, infoX, 0.712)
		add("If you call support, give them this info:", 15, infoX, 0.752)
		local stopL = add("Stop code: " .. stop, 17, infoX, 0.792, { FontFace = Kit.MonoBold, TextColor3 = accent })
		add("What failed: " .. failed, 17, infoX, 0.832, { FontFace = Kit.MonoBold, TextColor3 = accent })
		if S.exclusive then
			add("Anomaly source: " .. S.biomeName .. " (biome-exclusive signal)", 15, infoX, 0.872, {
				TextColor3 = S.biomeColor:Lerp(WHITE, 0.3),
			})
		end
		local newL: TextLabel? = nil
		if S.info.first then
			newL = add("> NEW SIGNATURE DISCOVERED", 20, 0, 0.29, { FontFace = Kit.MonoBold, TextColor3 = P.Lime })
			;(newL :: TextLabel).Visible = false
		end

		local C: any = { root = root, pct = 0, stopL = stopL, glyph = glyph }
		local glyphBase = glyph.Position
		local nextCorrupt = 0
		function C.update(now: number, e: number, pct: number)
			C.pct = pct
			pctL.Text = pct .. "% complete"
			fill.Size = UDim2.fromScale(pct / 100, 1)
			local j = (if corrupted then 7 else 3) * vs
			glyphA.Position = glyphBase + UDim2.fromOffset(-j + rng:NextNumber(-j, j) * 0.5, rng:NextNumber(-1, 1))
			glyphB.Position = glyphBase + UDim2.fromOffset(j + rng:NextNumber(-j, j) * 0.5, rng:NextNumber(-1, 1))
			if newL and e > 0.6 and not newL.Visible then
				newL.Visible = true
				S:sfx("Type", 0.5, 1.2)
			end
			if corrupted and now >= nextCorrupt then
				nextCorrupt = now + 1 / 16
				local amt = 0.04 + 0.22 * (pct / 100) ^ 1.5
				for _, it in labels do
					if it.l ~= pctL then
						it.l.Text = U.corrupt(rng, it.text, amt)
					end
				end
				root.BackgroundTransparency = if rng:NextNumber() < 0.08 then 0.15 else 0
			end
		end
		return C
	end

	-- Crack rays spreading from an impact point (cx, cy in 0..1); C.set(k) grows them.
	function Session.cracks(S: any, z: number, color: Color3?, cxs: number?, cys: number?): any
		local rng = S.rng
		local holder = S:frame({ Name = "Cracks", BackgroundTransparency = 1, ZIndex = z })
		local abs = S.gui.AbsoluteSize
		local cx = abs.X * (cxs or (0.5 + rng:NextNumber(-0.05, 0.05)))
		local cy = abs.Y * (cys or (0.48 + rng:NextNumber(-0.05, 0.05)))
		local col = color or WHITE
		local rays = {}
		local function ray(x: number, y: number, ang: number, len: number, thick: number, delay: number)
			local f = Kit.new("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = col,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = math.deg(ang),
				Size = UDim2.fromOffset(0, thick),
				Parent = holder,
			})
			Kit.new("UIStroke", { Color = BLACK, Thickness = 1, Transparency = 0.5, Parent = f })
			table.insert(rays, { f = f, x = x, y = y, ang = ang, len = len, delay = delay })
		end
		local n = 12
		for i = 1, n do
			local ang = (i / n) * math.pi * 2 + rng:NextNumber(-0.22, 0.22)
			local len = abs.Magnitude * rng:NextNumber(0.25, 0.6)
			ray(cx, cy, ang, len, rng:NextNumber(2, 4), 0)
			for _ = 1, rng:NextInteger(1, 2) do
				local at = rng:NextNumber(0.25, 0.7)
				local bx, by = cx + math.cos(ang) * len * at, cy + math.sin(ang) * len * at
				ray(bx, by, ang + rng:NextNumber(-0.7, 0.7), len * rng:NextNumber(0.2, 0.45), 1.5, at)
			end
		end
		local ring = Kit.new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(0, 0),
			Parent = holder,
		})
		round(ring)
		Kit.new("UIStroke", { Color = col, Thickness = 3, Parent = ring })
		local C: any = { holder = holder, cx = cx / abs.X, cy = cy / abs.Y }
		function C.set(k: number)
			for _, r in rays do
				local kk = clamp01((k - r.delay * 0.6) / (1 - r.delay * 0.6))
				local L = r.len * outExpo(kk)
				r.f.Size = UDim2.fromOffset(L, r.f.Size.Y.Offset)
				r.f.Position = UDim2.fromOffset(r.x + math.cos(r.ang) * L / 2, r.y + math.sin(r.ang) * L / 2)
			end
			local rs = 30 + 90 * outCubic(k)
			ring.Size = UDim2.fromOffset(rs, rs)
		end
		return C
	end

	-- Splits a full-screen frame into CanvasGroup shards and blows them outward from (cx, cy).
	function Session.shatter(S: any, source: Frame, cols: number, rows: number, z: number, cx: number, cy: number, gravity: number?)
		local rng = S.rng
		local shards = {}
		for r = 0, rows - 1 do
			for c = 0, cols - 1 do
				local x0 = (c + 0.5) / cols
				local y0 = (r + 0.5) / rows
				local cg = Instance.new("CanvasGroup")
				cg.Name = "Shard"
				cg.BackgroundTransparency = 1
				cg.BorderSizePixel = 0
				cg.AnchorPoint = Vector2.new(0.5, 0.5)
				cg.Position = UDim2.fromScale(x0, y0)
				cg.Size = UDim2.fromScale(1 / cols, 1 / rows)
				cg.ZIndex = z
				local clone = source:Clone()
				clone.AnchorPoint = Vector2.zero
				clone.Position = UDim2.fromScale(-c, -r)
				clone.Size = UDim2.fromScale(cols, rows)
				clone.Rotation = 0
				clone.Visible = true
				Fx.fixClone(clone)
				clone.Parent = cg
				Kit.new("UIStroke", {
					Color = WHITE,
					Thickness = 1.5,
					Transparency = 0.35,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Parent = cg,
				})
				cg.Parent = S.gui
				local dx, dy = x0 - cx, (y0 - cy) * 0.75
				local d = math.max(0.05, math.sqrt(dx * dx + dy * dy))
				local speed = rng:NextNumber(0.55, 1.25) * (0.55 + d * 1.6)
				table.insert(shards, {
					cg = cg,
					x0 = x0,
					y0 = y0,
					vx = dx / d * speed + rng:NextNumber(-0.12, 0.12),
					vy = dy / d * speed - rng:NextNumber(0.15, 0.55),
					vr = rng:NextNumber(120, 520) * (if rng:NextNumber() < 0.5 then -1 else 1),
					w = 1 / cols,
					h = 1 / rows,
					delay = d * 0.12,
				})
			end
		end
		source.Visible = false

		local palette = { WHITE, S.tier.color, S.aura.color, S.aura.color2, source.BackgroundColor3 }
		local debris = {}
		for i = 1, 70 do
			local s = rng:NextNumber(4, 16) * S.vs
			local f = Kit.new("Frame", {
				Name = "Debris",
				BorderSizePixel = 0,
				BackgroundColor3 = palette[(i % #palette) + 1],
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(cx, cy),
				Size = UDim2.fromOffset(s, s * rng:NextNumber(0.4, 1)),
				ZIndex = z + 1,
				Parent = S.gui,
			})
			local ang = rng:NextNumber(0, math.pi * 2)
			local sp = rng:NextNumber(0.4, 1.6)
			table.insert(debris, {
				f = f,
				vx = math.cos(ang) * sp,
				vy = math.sin(ang) * sp * 0.75 - 0.3,
				vr = rng:NextNumber(-900, 900),
			})
		end

		local t0 = os.clock()
		local G = gravity or 1.9
		S:loop(function(now: number)
			local e = now - t0
			for _, sh in shards do
				local t = math.max(0, e - sh.delay)
				local x = sh.x0 + sh.vx * t
				local y = sh.y0 + sh.vy * t + 0.5 * G * t * t
				local k = clamp01(t / 1.4)
				sh.cg.Position = UDim2.fromScale(x, y)
				sh.cg.Rotation = sh.vr * t
				local s = 1 - 0.35 * k
				sh.cg.Size = UDim2.fromScale(sh.w * s, sh.h * s)
				sh.cg.GroupTransparency = seg(t, 0.45, 1.35)
			end
			for _, d in debris do
				local x = cx + d.vx * e
				local y = cy + d.vy * e + 0.5 * G * e * e
				d.f.Position = UDim2.fromScale(x, y)
				d.f.Rotation = d.vr * e
				d.f.BackgroundTransparency = seg(e, 0.3, 1.1)
			end
			if e > 1.8 then
				for _, sh in shards do
					sh.cg:Destroy()
				end
				for _, d in debris do
					d.f:Destroy()
				end
				return true
			end
			return false
		end)
	end

	------------------------------------------------------------------------------------------------
	-- Avatar clone in a ViewportFrame
	------------------------------------------------------------------------------------------------

	local BODY = {
		Head = true,
		Torso = true,
		["Left Arm"] = true,
		["Right Arm"] = true,
		["Left Leg"] = true,
		["Right Leg"] = true,
		HumanoidRootPart = true,
	}
	local STRIP = {
		"LuaSourceContainer", "ParticleEmitter", "Beam", "Trail", "Light", "Sound", "BillboardGui", "SurfaceGui",
		"Highlight", "Fire", "Smoke", "Sparkles", "ForceField", "SelectionBox",
	}

	local function cloneAvatar(silhouette: Color3?): Model?
		local ch = player.Character
		if not ch then
			return nil
		end
		local was = ch.Archivable
		ch.Archivable = true
		local ok, c = pcall(function()
			return ch:Clone()
		end)
		ch.Archivable = was
		if not ok or not c then
			return nil
		end
		local m = c :: Model
		for _, child in m:GetChildren() do
			local keep = BODY[child.Name]
				or child:IsA("Accessory")
				or child:IsA("Clothing")
				or child:IsA("ShirtGraphic")
				or child:IsA("CharacterMesh")
				or child:IsA("Humanoid")
				or (child:IsA("BodyColors") and not silhouette)
			if not keep then
				child:Destroy()
			end
		end
		for _, d in m:GetDescendants() do
			if not d.Parent then
				continue
			end
			local strip = false
			for _, cls in STRIP do
				if d:IsA(cls) then
					strip = true
					break
				end
			end
			if not strip and d:IsA("BasePart") and not BODY[d.Name] and not d:FindFirstAncestorOfClass("Accessory") then
				strip = true
			end
			if strip then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				if silhouette then
					d.Color = silhouette
					d.Material = Enum.Material.SmoothPlastic
					if d:IsA("MeshPart") then
						pcall(function()
							(d :: any).TextureID = ""
						end)
					end
				end
			elseif silhouette and (d:IsA("Decal") or d:IsA("Texture") or d:IsA("Clothing") or d:IsA("ShirtGraphic")) then
				d:Destroy()
			elseif silhouette and d:IsA("SpecialMesh") then
				d.TextureId = ""
			elseif d:IsA("Humanoid") then
				d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
		local root = m:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			m.PrimaryPart = root
			pcall(function()
				m:PivotTo(CFrame.new())
			end)
		end
		return m
	end

	-- A live-looking copy of the player's avatar. V.set(yaw, dist?, height?, lookY?) moves the camera.
	function Session.charView(S: any, props: { [string]: any }, o: { [string]: any }?): any
		local opts: { [string]: any } = o or {}
		local p: { [string]: any } = {
			Name = "CharView",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Ambient = opts.ambient or Color3.fromRGB(200, 200, 210),
			LightColor = opts.light or Color3.fromRGB(230, 230, 240),
			LightDirection = Vector3.new(-0.6, -1, -0.8),
		}
		for k, v in props do
			p[k] = v
		end
		if p.Parent == nil then
			p.Parent = S.gui
		end
		local vp = Kit.new("ViewportFrame", p)
		local vcam = Instance.new("Camera")
		vcam.FieldOfView = opts.fov or 28
		vcam.Parent = vp
		vp.CurrentCamera = vcam
		local model = cloneAvatar(opts.silhouette)
		if model then
			model.Parent = vp
		end
		local V: any = { vp = vp, cam = vcam, model = model }
		function V.set(yaw: number, dist: number?, height: number?, lookY: number?)
			local d = dist or 11
			local h = height or 0.6
			local pos = Vector3.new(math.sin(yaw) * d, h, -math.cos(yaw) * d)
			vcam.CFrame = CFrame.lookAt(pos, Vector3.new(0, lookY or 0.2, 0))
		end
		V.set(0, opts.dist, opts.height, opts.lookY)
		return V
	end

	------------------------------------------------------------------------------------------------
	-- Name card (big RGB-split title spelled letter by letter)
	------------------------------------------------------------------------------------------------

	-- o: z, y (0..1 centre), band (Color3? dark band behind), main (gradient colours), sub (subtitle text).
	function Session.nameCard(S: any, o: { [string]: any }?): any
		local opts: { [string]: any } = o or {}
		local a = S.aura
		local z = opts.z or 40
		local y = opts.y or 0.5
		local band: Frame? = nil
		if opts.band ~= false then
			band = S:frame({
				Name = "Band",
				BackgroundColor3 = opts.bandColor or BLACK,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, y),
				Size = UDim2.fromScale(1, 0.42),
				BackgroundTransparency = 1,
				ZIndex = z,
			})
			Kit.new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.3),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
				Parent = band,
			})
		end
		local name = string.upper(a.name)
		local n = utf8.len(name) or #name
		local maxText = math.floor((opts.maxText or 150) * S.vs + 0.5)
		local function nameLabel(color: Color3, tr: number, zz: number): TextLabel
			local l = S:text({
				Text = name,
				FontFace = Kit.Title,
				TextScaled = true,
				TextColor3 = color,
				TextTransparency = tr,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, y),
				Size = UDim2.fromScale(0.9, 0.2),
				MaxVisibleGraphemes = 0,
				ZIndex = zz,
			})
			Kit.new("UITextSizeConstraint", { MaxTextSize = maxText, Parent = l })
			Kit.new("UIScale", { Parent = l })
			return l
		end
		local cyanL = nameLabel(opts.splitA or P.Cyan, 0.35, z + 4)
		local magL = nameLabel(opts.splitB or P.Magenta, 0.35, z + 4)
		local mainL = nameLabel(WHITE, 0, z + 6)
		local c1: Color3 = opts.c1 or a.color:Lerp(WHITE, 0.45)
		local c2: Color3 = opts.c2 or a.color2:Lerp(WHITE, 0.2)
		Kit.new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = 90, Parent = mainL })
		Kit.new("UIStroke", {
			Thickness = 3,
			Color = opts.stroke or (if U.brightness(c1) < 0.6 then WHITE else BLACK),
			Transparency = 0.25,
			Parent = mainL,
		})
		local sub = S:text({
			FontFace = Kit.MonoBold,
			TextSize = math.floor(20 * S.vs + 0.5),
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, y + 0.115),
			Size = UDim2.new(1, 0, 0, 26),
			ZIndex = z + 6,
		})
		local newL = S:text({
			FontFace = Kit.MonoBold,
			TextSize = math.floor(18 * S.vs + 0.5),
			TextColor3 = P.Lime,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, y - 0.115),
			Size = UDim2.new(1, 0, 0, 24),
			ZIndex = z + 6,
		})
		for _, l in { sub, newL } do
			Kit.new("UIStroke", { Thickness = 2, Color = BLACK, Transparency = 0.3, Parent = l })
		end

		local Card: any = { labels = { mainL, cyanL, magL }, main = mainL, sub = sub, newL = newL, band = band, jitter = 1, popAt = -10, scale = 1, n = n }
		S:loop(function(now: number)
			local pop = (1 + 0.22 * math.exp(-11 * (now - Card.popAt))) * Card.scale
			local j = 6 * S.vs * Card.jitter
			for i, l in Card.labels do
				local sc = l:FindFirstChildOfClass("UIScale")
				if sc then
					sc.Scale = pop
				end
				if i == 2 then
					l.Position = UDim2.new(0.5, -j - S.rng:NextNumber(0, 6) * Card.jitter, y, S.rng:NextNumber(-2, 2) * Card.jitter)
				elseif i == 3 then
					l.Position = UDim2.new(0.5, j + S.rng:NextNumber(0, 6) * Card.jitter, y, S.rng:NextNumber(-2, 2) * Card.jitter)
				end
			end
			return false
		end)

		function Card.setVisible(c: number)
			for _, l in Card.labels do
				l.MaxVisibleGraphemes = c
			end
		end
		function Card.setT(t: number)
			for i, l in Card.labels do
				l.TextTransparency = if i == 1 then t else lerp(0.35, 1, t)
			end
		end

		-- Blocking: "> NEW SIGNATURE DISCOVERED <" (first time only), then the name letter by letter.
		function Card.spell(total: number?)
			if band then
				band.BackgroundTransparency = 0
			end
			if S.info.first then
				local txt = "> NEW SIGNATURE DISCOVERED <"
				local last = 0
				S:sfx("Announce", 0.6, 1)
				S:phase(0.7, function(_: number, e: number)
					local c = math.min(#txt, math.floor(e * 55))
					newL.Text = txt:sub(1, c)
					if c ~= last and c % 2 == 0 then
						S:sfx("Type", 0.3, 1.1)
					end
					last = c
				end)
				newL.Text = txt
			end
			local per = math.clamp((total or 1.5) / n, 0.06, 0.17)
			local shown = 0
			S:phase(per * n + 0.08, function(_: number, e: number)
				local c = math.min(n, math.floor(e / per) + 1)
				if c ~= shown then
					shown = c
					Card.setVisible(c)
					Card.popAt = os.clock()
					S:sfx("Type", 0.6, 0.8 + (c / n) * 0.6)
					S:sfx("Glitch", 0.2, 1.4)
				end
			end)
			Card.setVisible(-1)
			Card.popAt = os.clock()
		end

		-- Blocking: typed "[ TIER ]   1 in N" subtitle while the jitter settles.
		function Card.subtitle(dur: number, text: string?)
			local subText = text
				or ("[ " .. S.tier.name .. " ]   " .. RNG.ChanceText(a.chance) .. (if S.exclusive
					then "   //   " .. S.biomeName .. " EXCLUSIVE"
					else ""))
			local lastC = 0
			S:phase(dur, function(_: number, e: number)
				Card.jitter = lerp(1, 0.25, clamp01(e / 0.8))
				local c = math.min(#subText, math.floor(seg(e, 0.25, math.min(dur, 0.9)) * #subText))
				sub.Text = subText:sub(1, c)
				if c ~= lastC and c % 3 == 0 then
					S:sfx("Type", 0.25, 1.2)
				end
				lastC = c
			end)
			sub.Text = subText
		end
		return Card
	end

	------------------------------------------------------------------------------------------------
	-- Endings
	------------------------------------------------------------------------------------------------

	-- Fade to `color`, cut everything back underneath, fade out over the restored world.
	function Session.outro(S: any, color: Color3, inDur: number, outDur: number, onPeak: (() -> ())?)
		local f = S:fill(color, 185, 1)
		S:phase(inDur, function(k: number)
			f.BackgroundTransparency = 1 - inCubic(k)
		end)
		S:peakCut(f)
		if onPeak then
			onPeak()
		end
		local ducked = S.ducked ~= nil
		S:raw(outDur, function(k: number)
			f.BackgroundTransparency = outCubic(k)
			if ducked then
				S:duck(k)
			end
		end)
	end

	------------------------------------------------------------------------------------------------
	-- Cameras (each blends in from wherever the camera currently is)
	------------------------------------------------------------------------------------------------

	-- Orbit around the character. o: dur, deg, r0, r1, h0, h1, fov0, fov1, look, roll, dir, blend, ease.
	function Session.orbitShot(S: any, o: { [string]: any })
		local c0 = S:focusPos()
		local off = S.lastCF.Position - c0
		local ang0 = if o.ang0 then o.ang0 else math.atan2(off.Z, off.X)
		local dir = o.dir or (if S.rng:NextNumber() < 0.5 then 1 else -1)
		local dur = o.dur or 4
		local ease: (number) -> number = o.ease or inOutSine
		S:shot(function(e: number, c: Vector3)
			local k = clamp01(e / dur)
			local q = ease(k)
			local ang = ang0 + dir * math.rad(o.deg or 80) * q
			local R = lerp(o.r0 or 13, o.r1 or 9, outCubic(k))
			local h = lerp(o.h0 or 4.5, o.h1 or 2.2, outCubic(k))
			local look = c + Vector3.new(0, o.look or 1.3, 0)
			local pos = S:safe(look, c + Vector3.new(math.cos(ang) * R, h, math.sin(ang) * R))
			local roll = (o.roll or 2) * math.sin(e * 0.9)
			return CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, math.rad(roll)), lerp(o.fov0 or 55, o.fov1 or 52, k)
		end, o.blend or 0.8)
	end

	-- In front of the character (facing it). o: dur, d0, d1, side0, side1, h0, h1, fov0, fov1, look, roll0, roll1, yaw.
	function Session.frontShot(S: any, o: { [string]: any })
		local lv = S:focusLook()
		if o.yaw then
			lv = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(o.yaw)) * CFrame.new(lv)).Position
		end
		local rv = lv:Cross(Vector3.yAxis)
		local dur = o.dur or 3
		S:shot(function(e: number, c: Vector3)
			local k = clamp01(e / dur)
			local q = outCubic(k)
			local look = c + Vector3.new(0, o.look or 1.5, 0)
			local want = c + lv * lerp(o.d0 or 10, o.d1 or 8, q) + rv * lerp(o.side0 or 0, o.side1 or 0, inOutSine(k))
				+ Vector3.new(0, lerp(o.h0 or 1.2, o.h1 or 1.2, q), 0)
			local pos = S:safe(look, want)
			local roll = lerp(o.roll0 or 0, o.roll1 or 0, q)
			return CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, math.rad(roll)), lerp(o.fov0 or 55, o.fov1 or 50, k)
		end, o.blend or 0.6)
	end

	-- High above the character looking down. o: dur, h0, h1, r0, r1, spin (deg), fov0, fov1, ease.
	function Session.skyShot(S: any, o: { [string]: any })
		local lv = S:focusLook()
		local dur = o.dur or 3
		local ease: (number) -> number = o.ease or outQuart
		S:shot(function(e: number, c: Vector3)
			local k = clamp01(e / dur)
			local q = ease(k)
			local spin = math.rad(o.spin0 or 0) + math.rad(o.spin or 90) * q
			local dir = (CFrame.fromAxisAngle(Vector3.yAxis, spin) * CFrame.new(lv)).Position
			local h = lerp(o.h0 or 3, o.h1 or 120, q)
			local horiz = lerp(o.r0 or 10, o.r1 or 30, q)
			local pos = c + dir * horiz + Vector3.new(0, h, 0)
			local look = c + Vector3.new(0, o.look or 0, 0)
			local up = Vector3.yAxis
			if (pos - look).Unit:Dot(Vector3.yAxis) > 0.97 then
				up = -dir
			end
			return CFrame.lookAt(pos, look, up), lerp(o.fov0 or 60, o.fov1 or 70, k)
		end, o.blend or 0.5)
	end

	-- Low beside the character looking up into the sky. o: dur, pitch0, pitch1 (deg), d, fov0, fov1, spin.
	function Session.lookUpShot(S: any, o: { [string]: any })
		local lv = S:focusLook()
		local dur = o.dur or 2
		S:shot(function(e: number, c: Vector3)
			local k = clamp01(e / dur)
			local q = inOutSine(k)
			local yaw = math.rad(o.spin or 20) * q
			local fwd = (CFrame.fromAxisAngle(Vector3.yAxis, yaw) * CFrame.new(lv)).Position
			local base = c + Vector3.new(0, o.h or 0.5, 0) - fwd * (o.d or 7)
			local pitch = math.rad(lerp(o.pitch0 or 10, o.pitch1 or 70, q))
			local look = base + fwd * math.cos(pitch) * 20 + Vector3.new(0, math.sin(pitch) * 20, 0)
			local pos = S:safe(c + Vector3.new(0, 1.5, 0), base)
			return CFrame.lookAt(pos, look), lerp(o.fov0 or 60, o.fov1 or 72, k)
		end, o.blend or 0.5)
	end

	-- Dramatic low-angle hero shot, slight dutch tilt, slow push in.
	function Session.lowShot(S: any, o: { [string]: any }?)
		local opts: { [string]: any } = o or {}
		local lv = S:focusLook()
		local rv = lv:Cross(Vector3.yAxis)
		local dur = opts.dur or 4
		S:shot(function(e: number, c: Vector3)
			local k = clamp01(e / dur)
			local d = lerp(opts.d0 or 9.5, opts.d1 or 6.2, outCubic(k))
			local ang = math.rad(lerp(opts.a0 or -24, opts.a1 or 10, inOutSine(k)))
			local dir = lv * math.cos(ang) + rv * math.sin(ang)
			local look = c + Vector3.new(0, 1.7, 0)
			local pos = S:safe(look, c + dir * d + Vector3.new(0, opts.h or -2.1, 0))
			local cf = CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, math.rad(lerp(opts.roll0 or -8, opts.roll1 or -2.5, outCubic(k))))
			return cf, lerp(opts.fov0 or 64, opts.fov1 or 50, outCubic(k))
		end, opts.blend or 0)
	end

	-- Backwards-compatible names used by the tier scenes.
	function Session.orbitCamera(S: any, dur: number)
		S:orbitShot({ dur = dur })
	end
	function Session.lowAngleCamera(S: any)
		S:lowShot()
	end

end

return Fx
