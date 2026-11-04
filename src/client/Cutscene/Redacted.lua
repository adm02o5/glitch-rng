--!strict
-- Cutscene/Redacted: the [REDACTED] cutscene (1 in 1,000,000,000), ~29 seconds in five acts.
--
--   I    INTERFERENCE   (0-4.4s)   the game censors itself: black bars strike through the real HUD, one
--                                  element at a time, then swipe across the world; the feed is classified
--   II   THE FILE       (4.4-10.4) a classified paper dossier with the player's photo; every field is
--                                  redacted as it is typed (except the odds), CLASSIFIED / TOP SECRET /
--                                  [REDACTED] stamps, the page is blacked out and torn in half
--   III  FROM ABOVE     (10.4-17)  satellite feed high over the city while the map itself is redacted
--                                  building by building with black boxes; the feed closes
--   IV   ACCESS         (17-21.6)  ACCESS DENIED spam, then total silence, one line of authorization,
--                                  ACCESS GRANTED
--   V    REVEAL         (21.6-29)  red detonation: the boxes blow away, a red shockwave crosses the whole
--                                  map, the camera circles the player, the name assembles from censor bars
--                                  and is declassified letter by letter
--
-- Sound names RedactedDrone/Stamp/Riser/Hit/Tear/Heartbeat/Denied/Granted/Choir are layered over the
-- stock sounds; they stay silent until ids are added to Sounds.lua.

local Players = game:GetService("Players")

local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local U = require(script.Parent.Util)
local Fx = require(script.Parent.Fx)
local RNG = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RNG"))

local WHITE, BLACK = U.WHITE, U.BLACK
local clamp01, lerp, seg = U.clamp01, U.lerp, U.seg
local outCubic, inCubic, inOutCubic, outQuart, outBack, bump =
	U.outCubic, U.inCubic, U.inOutCubic, U.outQuart, U.outBack, U.bump
local player = Players.LocalPlayer

local RED = Color3.fromRGB(255, 31, 61)
local PAPER = Color3.fromRGB(232, 226, 210)
local INK = Color3.fromRGB(24, 22, 20)

local function mono(S: any, size: number, props: { [string]: any }, stroke: boolean?): TextLabel
	local p: { [string]: any } = { FontFace = Kit.MonoBold, TextSize = math.floor(size * S.vs + 0.5) }
	for k, v in props do
		p[k] = v
	end
	local l = S:text(p)
	if stroke ~= false then
		Kit.new("UIStroke", { Thickness = 1.5, Color = BLACK, Transparency = 0.4, Parent = l })
	end
	return l
end

-- A censor bar that swipes in from one side over a pixel rect. Returns the bar; grows over `dur`.
local function censor(S: any, x: number, y: number, w: number, h: number, z: number, dur: number, parent: Instance?, label: boolean?): Frame
	local fromRight = S.rng:NextNumber() < 0.35
	local bar = S:frame({
		Name = "Censor",
		BackgroundColor3 = BLACK,
		AnchorPoint = Vector2.new(if fromRight then 1 else 0, 0),
		Position = UDim2.fromOffset(if fromRight then x + w else x, y),
		Size = UDim2.fromOffset(0, h),
		ZIndex = z,
		Parent = parent,
	})
	Kit.new("UIStroke", { Color = RED, Thickness = 1, Transparency = 0.55, Parent = bar })
	if label and h > 14 then
		mono(S, math.clamp(h / S.vs * 0.42, 9, 16), {
			Text = "[REDACTED]",
			TextColor3 = RED,
			TextTransparency = 0.2,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -8, 1, 0),
			ZIndex = z + 1,
			Parent = bar,
		}, false)
	end
	local t0 = os.clock()
	S:loop(function(now: number)
		local k = clamp01((now - t0) / dur)
		bar.Size = UDim2.fromOffset(w * outCubic(k), h)
		return k >= 1
	end)
	return bar
end

-- Visible HUD elements worth striking out (outermost first, no element inside another picked one).
local function hudTargets(S: any): { Rect }
	local out: { Rect } = {}
	local sz = S.gui.AbsoluteSize
	if not Kit.Gui.Enabled then
		return out
	end
	local cands = {}
	for _, d in Kit.Gui:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("ImageButton") or d:IsA("ImageLabel") then
			local g = d :: GuiObject
			local vis = true
			local cur: Instance? = g
			while cur and cur ~= Kit.Gui do
				if cur:IsA("GuiObject") and not cur.Visible then
					vis = false
					break
				end
				cur = cur.Parent
			end
			local p, s = g.AbsolutePosition, g.AbsoluteSize
			if vis and s.X > 18 and s.Y > 10 and p.X < sz.X and p.Y < sz.Y and p.X + s.X > 0 and p.Y + s.Y > 0 then
				if s.X * s.Y < sz.X * sz.Y * 0.2 then
					table.insert(cands, Rect.new(p, p + s))
				end
			end
		end
	end
	table.sort(cands, function(a, b)
		return a.Width * a.Height > b.Width * b.Height
	end)
	for _, r in cands do
		local inside = false
		for _, o in out do
			if r.Min.X >= o.Min.X - 2 and r.Min.Y >= o.Min.Y - 2 and r.Max.X <= o.Max.X + 2 and r.Max.Y <= o.Max.Y + 2 then
				inside = true
				break
			end
		end
		if not inside then
			table.insert(out, r)
			if #out >= 26 then
				break
			end
		end
	end
	table.sort(out, function(a, b)
		return a.Min.Y + a.Min.X * 0.2 < b.Min.Y + b.Min.X * 0.2
	end)
	return out
end

-- Big map parts near the player to black out from above (largest first, then ordered by distance).
local function mapTargets(S: any, center: Vector3): { BasePart }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex: { Instance } = {}
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	if S.world then
		table.insert(ex, S.world)
	end
	params.FilterDescendantsInstances = ex
	params.MaxParts = 5000
	local ok, found = pcall(function()
		return workspace:GetPartBoundsInRadius(center, 240, params)
	end)
	local list = {}
	if ok and found then
		for _, p in found do
			local m = p.Size.Magnitude
			local neon = p.Material == Enum.Material.Neon
			if p.Transparency < 0.8 and (m > 9 or (neon and m > 4)) and m < 420 and not p:IsA("Terrain") then
				local d = (p.Position - center) * Vector3.new(1, 0, 1)
				local model = p:FindFirstAncestorOfClass("Model")
				local isChar = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
				-- Keep a clear space around the player so the subject stays visible from above.
				if not isChar and d.Magnitude > m * 0.5 + 10 then
					table.insert(list, p)
				end
			end
		end
	end
	-- Prefer what reads from above: glowing (neon / bright) parts first, then sheer size.
	local score: { [BasePart]: number } = {}
	for _, p in list do
		local c = p.Color
		local glow = (if p.Material == Enum.Material.Neon then 3 else 1) * (0.4 + math.max(c.R, c.G, c.B))
		score[p] = p.Size.Magnitude * glow
	end
	table.sort(list, function(a, b)
		return score[a] > score[b]
	end)
	local pick = {}
	for i = 1, math.min(140, #list) do
		pick[i] = list[i]
	end
	table.sort(pick, function(a, b)
		return (a.Position - center).Magnitude < (b.Position - center).Magnitude
	end)
	return pick
end

local function scene(S: any)
	local a = S.aura
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	local cc = S:cc()
	local blur = S:blur()
	local gl = S:glitchLayer(120, { RED, BLACK, WHITE, Color3.fromRGB(90, 0, 15) })

	------------------------------------------------------------------------------------------------
	-- ACT I: INTERFERENCE
	------------------------------------------------------------------------------------------------
	S:frontShot({ dur = 4.6, d0 = 12, d1 = 9, h0 = 2, h1 = 1.5, fov0 = 56, fov1 = 50, blend = 0.8 })
	S:sfx("RedactedDrone", 0.7, 1)
	S:sfx("Glitch", 0.45, 0.45)
	S:sfx("Riser", 0.35, 0.4)
	local banner = S:frame({
		Name = "Banner",
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.15,
		Position = UDim2.fromScale(0, -0.08),
		Size = UDim2.new(1, 0, 0, math.floor(34 * S.vs)),
		ZIndex = 110,
	})
	Kit.new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = RED,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		Parent = banner,
	})
	local bannerL = mono(S, 15, {
		Text = "",
		TextColor3 = RED,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 111,
		Parent = banner,
	})
	local targets = hudTargets(S)
	if #targets == 0 then
		for _ = 1, 10 do
			local x, y = rng:NextNumber(0.05, 0.75) * sz.X, rng:NextNumber(0.1, 0.9) * sz.Y
			table.insert(targets, Rect.new(x, y, x + rng:NextNumber(80, 300) * S.vs, y + rng:NextNumber(18, 40) * S.vs))
		end
	end
	local hudLayer = S:frame({ Name = "HudCensor", BackgroundTransparency = 1, ZIndex = 100 })
	local worldLayer = S:frame({ Name = "WorldCensor", BackgroundTransparency = 1, ZIndex = 90 })
	local struck = 0
	local nextStrike = 0.45
	local nextWorld = 2.5
	S:phase(4.2, function(k: number, e: number)
		banner.Position = UDim2.fromScale(0, lerp(-0.08, 0, outCubic(seg(e, 0.2, 0.6))))
		bannerL.Text = (if U.blink(e, 1.5) > 0 then "(REC)  " else "       ") .. "THIS FEED HAS BEEN CLASSIFIED  //  CLEARANCE INSUFFICIENT"
		if e >= nextStrike and struck < #targets then
			struck += 1
			local r = targets[struck]
			censor(S, r.Min.X - 4, r.Min.Y - 2, r.Width + 8, math.min(r.Height + 4, 64 * S.vs), 100, 0.12, hudLayer)
			S:sfx("RedactedStamp", 0.5, 1)
			S:sfx("Tick", 0.45, 0.45 + rng:NextNumber() * 0.15)
			S.shake = 0.18
			S:after(0.05, function()
				S.shake = 0
			end)
			nextStrike = e + lerp(0.2, 0.05, clamp01(struck / #targets))
		end
		if e >= nextWorld then
			local h = rng:NextNumber(0.025, 0.11) * sz.Y
			local w = rng:NextNumber(0.25, 0.85) * sz.X
			censor(S, rng:NextNumber(-0.1, 0.9) * sz.X - w * 0.3, rng:NextNumber(0.05, 0.95) * sz.Y, w, h, 90, 0.16, worldLayer, true)
			S:sfx("RedactedStamp", 0.35, 0.8)
			S:sfx("Tick", 0.3, 0.6)
			nextWorld = e + lerp(0.22, 0.06, seg(e, 2.5, 4.2))
		end
		if e > 2.5 and e - 2.5 < 1 / 50 then
			S:sfx("RedactedRiser", 0.6, 1)
			S:sfx("Riser", 0.4, 0.7)
		end
		cc.Saturation = -0.75 * k
		cc.Contrast = 0.3 * k
		cc.TintColor = WHITE:Lerp(RED, 0.08 * k)
		gl.k = 0.03 + (if rng:NextNumber() < 0.04 + 0.08 * k then 0.5 else 0)
		S:duck(1 - 0.7 * k)
	end)
	-- Everything goes black.
	local black = S:fill(BLACK, 80, 1)
	S:phase(0.2, function(k: number)
		black.BackgroundTransparency = 1 - inCubic(k)
	end)
	S:sfx("RedactedHit", 0.8, 1)
	S:sfx("Boom", 0.7, 0.45)
	S:hideHud()
	hudLayer:Destroy()
	worldLayer:Destroy()
	banner:Destroy()
	gl.k = 0

	------------------------------------------------------------------------------------------------
	-- ACT II: THE FILE
	------------------------------------------------------------------------------------------------
	S:duck(0.25)
	local grainLines = S:scanlines(81, RED, 5, 0.94)
	local page = S:frame({ Name = "Page", BackgroundTransparency = 1, ZIndex = 85 })
	local W, H = math.floor(sz.Y * 1.02), math.floor(sz.Y * 0.8)
	local paper = S:frame({
		Name = "Paper",
		BackgroundColor3 = PAPER,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.7),
		Size = UDim2.fromOffset(W, H),
		Rotation = -2,
		ZIndex = 85,
		Parent = page,
	})
	Kit.corner(paper, 4)
	Kit.new("UIStroke", { Color = Color3.fromRGB(140, 130, 110), Thickness = 2, Parent = paper })
	Kit.new("UIGradient", {
		Color = ColorSequence.new(WHITE, Color3.fromRGB(205, 198, 180)),
		Rotation = 70,
		Parent = paper,
	})
	local pz = 86
	local function ink(size: number, props: { [string]: any }): TextLabel
		local p: { [string]: any } = { TextColor3 = INK, ZIndex = pz, Parent = paper }
		for k, v in props do
			p[k] = v
		end
		return mono(S, size, p, false)
	end
	local pad = math.floor(26 * S.vs)
	ink(13, {
		Text = "DEPARTMENT OF PROBABILITY  -  INTERNAL AFFAIRS  -  ANOMALY DIVISION",
		Position = UDim2.fromOffset(pad, pad * 0.6),
		Size = UDim2.new(1, -pad * 2, 0, 18),
	})
	ink(13, {
		Text = "FILE NO. 000-000-001",
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(pad, pad * 0.6),
		Size = UDim2.new(1, -pad * 2, 0, 18),
	})
	Kit.new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = INK,
		Position = UDim2.fromOffset(pad, pad * 0.6 + 24 * S.vs),
		Size = UDim2.new(1, -pad * 2, 0, 2),
		ZIndex = pz,
		Parent = paper,
	})
	ink(30, {
		Text = "SUBJECT DOSSIER",
		FontFace = Kit.Title,
		Position = UDim2.fromOffset(pad, pad * 0.6 + 34 * S.vs),
		Size = UDim2.new(1, -pad * 2, 0, 40 * S.vs),
	})
	local photoBox = S:frame({
		BackgroundColor3 = Color3.fromRGB(40, 40, 42),
		Position = UDim2.fromOffset(pad, pad * 0.6 + 86 * S.vs),
		Size = UDim2.new(0.32, 0, 0.52, 0),
		ZIndex = pz,
		Parent = paper,
	})
	Kit.new("UIStroke", { Color = INK, Thickness = 3, Parent = photoBox })
	local photo = S:charView({
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = Color3.fromRGB(225, 220, 210),
		ZIndex = pz + 1,
		Parent = photoBox,
	}, { dist = 8, height = 1.5, lookY = 1, fov = 30, ambient = Color3.fromRGB(150, 150, 150), light = Color3.fromRGB(210, 210, 210) })
	ink(11, {
		Text = "FIG. 1  -  SUBJECT AT TIME OF ROLL",
		Position = UDim2.new(0, pad, 0.52, pad * 0.6 + 92 * S.vs),
		Size = UDim2.new(0.32, 0, 0, 14),
	})
	local fieldsX = 0.38
	local fields: { { any } } = {
		{ "SUBJECT", string.upper(player.DisplayName), true },
		{ "ORIGIN", "SECTOR " .. S.biomeName, true },
		{ "PROBABILITY", "1 IN " .. U.commas(a.chance), false },
		{ "STATUS", "UNCONTAINED", true },
		{ "THREAT LEVEL", "BEYOND SCALE", true },
	}
	local vals: { TextLabel } = {}
	local fy0 = pad * 0.6 + 90 * S.vs
	local fh = 34 * S.vs
	for i, f in fields do
		ink(14, {
			Text = f[1] .. ":",
			TextColor3 = Color3.fromRGB(90, 85, 75),
			Position = UDim2.new(fieldsX, 0, 0, fy0 + (i - 1) * fh),
			Size = UDim2.new(0.2, 0, 0, fh),
		})
		vals[i] = ink(19, {
			Text = f[2],
			TextColor3 = if f[3] then INK else RED,
			Position = UDim2.new(fieldsX + 0.2, 0, 0, fy0 + (i - 1) * fh),
			Size = UDim2.new(0.4, 0, 0, fh),
			MaxVisibleGraphemes = 0,
		})
	end
	local body = {
		"On the night of the roll the subject obtained a signature that",
		"cannot exist. All instruments recording the event were lost.",
		"Witnesses report that the world itself refused to render it.",
		"Every copy of this record must be destroyed immediately.",
		"Do not attempt to observe, quantify or name the anomaly.",
	}
	local bodyY = pad * 0.6 + 96 * S.vs + H * 0.52
	local bodyLabels: { TextLabel } = {}
	for i, t in body do
		bodyLabels[i] = ink(13, {
			Text = t,
			Position = UDim2.new(0, pad, 0, bodyY + (i - 1) * 20 * S.vs),
			Size = UDim2.new(1, -pad * 2, 0, 18 * S.vs),
		})
	end
	-- 1) The file slides in.
	S:sfx("Whoosh", 0.6, 0.7)
	S:sfx("Open", 0.5, 0.6)
	S:phase(0.6, function(k: number)
		paper.Position = UDim2.fromScale(0.5, lerp(1.7, 0.5, outBack(k)))
		paper.Rotation = lerp(8, -2, outCubic(k))
	end)
	-- 2) Fields are typed... and redacted as soon as they appear (all but the odds).
	local function barOver(l: TextLabel, full: boolean?)
		local tb = l.TextBounds
		local w = if full then l.AbsoluteSize.X else math.max(30, tb.X + 10)
		-- Paper is rotated; place in paper space using unrotated offsets.
		local px = l.Position.X.Scale * W + l.Position.X.Offset - 4
		local py = l.Position.Y.Scale * H + l.Position.Y.Offset + (l.AbsoluteSize.Y - tb.Y) * 0.5 - 2
		return censor(S, px, py, w, tb.Y + 4, pz + 3, 0.1, paper)
	end
	for i = 1, #fields do
		S:typeInto(vals[i], fields[i][2], 34, 0.25)
		S:phase(0.38, function(_: number, e: number)
			photo.set(math.sin(e * 3 + i) * 0.25, 8, 1.5, 1)
		end)
		if fields[i][3] then
			barOver(vals[i])
			S:sfx("RedactedStamp", 0.55, 1)
			S:sfx("Click", 0.5, 0.7)
		else
			Kit.glitch(vals[i], 0.25)
			S:sfx("Type", 0.6, 0.6)
		end
	end
	-- Body text gets bars over random words.
	for _, l in bodyLabels do
		local tb = l.TextBounds
		local cw = tb.X / math.max(1, #l.Text)
		local n = rng:NextInteger(1, 3)
		for _ = 1, n do
			local start = rng:NextInteger(0, math.max(0, #l.Text - 12))
			local len = rng:NextInteger(5, 14)
			local px = l.Position.X.Offset + start * cw
			local py = l.Position.Y.Offset
			censor(S, px, py, len * cw, l.AbsoluteSize.Y, pz + 3, 0.08, paper)
		end
	end
	S:sfx("RedactedStamp", 0.4, 1.2)
	S:phase(0.3)
	-- 3) Stamps.
	local stamps: { { any } } = {
		{ "CLASSIFIED", UDim2.fromScale(0.68, 0.36), -14, 62 },
		{ "TOP SECRET", UDim2.fromScale(0.22, 0.84), 9, 40 },
		{ "[REDACTED]", UDim2.fromScale(0.5, 0.55), -6, 84 },
	}
	for i, st in stamps do
		S:stamp(st[1], RED, st[2], st[3], st[4], pz + 6, paper)
		S:sfx("RedactedHit", 0.6 + i * 0.1, 1)
		S:sfx("Boom", 0.5 + i * 0.12, 0.7 - i * 0.05)
		S:sfx("Click", 0.7, 0.4)
		S.shake = 0.35 + i * 0.2
		S:phase(if i == 3 then 0.55 else 0.42, function(k: number)
			S.shake = (0.35 + i * 0.2) * (1 - k) ^ 2
			paper.Rotation = -2 + (if i % 2 == 0 then 1 else -1) * 1.2 * bump(seg(k, 0, 0.3))
		end)
	end
	-- 4) Bars swallow the whole page.
	local lastTick = 0
	S:phase(1.0, function(k: number, e: number)
		local want = math.floor(8 + 55 * k * k)
		for _ = 1, math.max(0, math.floor(want / 20)) do
			local h = rng:NextNumber(0.03, 0.09) * H
			censor(S, rng:NextNumber(-0.1, 0.8) * W, rng:NextNumber(0, 1) * H - h * 0.5, rng:NextNumber(0.25, 0.7) * W, h, pz + 8, 0.08, paper)
		end
		if e - lastTick > lerp(0.09, 0.025, k) then
			lastTick = e
			S:sfx("Tick", 0.35, 0.5 + k)
		end
		S.shake = 0.2 * k
	end)
	-- Behind the black, the camera is already waiting high above the city.
	local center = S:focusPos()
	local lv = S:focusLook()
	local ang0 = math.atan2(lv.Z, lv.X) + math.pi
	S:shot(function(e: number, c: Vector3)
		local k = clamp01(e / 7.2)
		local ang = ang0 + math.rad(110) * inOutCubic(k)
		local h = lerp(70, 135, outCubic(k))
		local R = lerp(95, 150, outCubic(k))
		local pos = c + Vector3.new(math.cos(ang) * R, h, math.sin(ang) * R)
		return CFrame.lookAt(pos, c), lerp(58, 46, k)
	end, 0)
	-- 5) The page tears in half and falls away, revealing the city from above.
	S:sfx("RedactedTear", 0.8, 1)
	S:sfx("Glitch", 0.8, 0.45)
	S:sfx("Whoosh", 0.8, 0.6)
	local halves = {}
	for i = 0, 1 do
		local cg = Instance.new("CanvasGroup")
		cg.Name = "Half"
		cg.BackgroundTransparency = 1
		cg.BorderSizePixel = 0
		cg.AnchorPoint = Vector2.new(0.5, 0.5)
		cg.Position = UDim2.fromScale(0.25 + i * 0.5, 0.5)
		cg.Size = UDim2.fromScale(0.5, 1)
		cg.ZIndex = 95
		local clone = page:Clone()
		clone.Position = UDim2.fromScale(-i, 0)
		clone.Size = UDim2.fromScale(2, 1)
		Fx.fixClone(clone)
		clone.Parent = cg
		cg.Parent = S.gui
		halves[i + 1] = cg
	end
	page:Destroy()
	local tearLine = S:branches(96, { { sz.X * 0.5, -4, math.pi / 2 } }, {
		color = WHITE,
		core = WHITE,
		steps = 12,
		len = sz.Y / 12 / S.vs,
		jitter = 0.5,
		branch = 0.1,
		thick = 3,
		bias = math.pi / 2,
	})
	tearLine.set(1)
	S:phase(1.0, function(k: number)
		local q = inCubic(k)
		for i, cg in halves do
			local dir = if i == 1 then -1 else 1
			cg.Position = UDim2.fromScale(0.25 + (i - 1) * 0.5 + dir * 0.3 * outCubic(k), 0.5 + 0.5 * q)
			cg.Rotation = dir * 22 * outCubic(k)
			cg.GroupTransparency = seg(k, 0.4, 1)
		end
		tearLine.setT(k)
		black.BackgroundTransparency = outCubic(seg(k, 0.15, 0.8))
		grainLines.Visible = k < 0.5
	end)
	for _, cg in halves do
		cg:Destroy()
	end
	tearLine.holder:Destroy()
	grainLines:Destroy()

	------------------------------------------------------------------------------------------------
	-- ACT III: BLACKOUT FROM ABOVE
	------------------------------------------------------------------------------------------------
	local parts = mapTargets(S, center)
	local boxes = {}
	if #parts == 0 then
		for i = 1, 40 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local r = 20 + i * 4
			local size = Vector3.new(rng:NextNumber(8, 30), rng:NextNumber(4, 40), rng:NextNumber(8, 30))
			table.insert(boxes, {
				cf = CFrame.new(center + Vector3.new(math.cos(ang) * r, size.Y / 2 - 3, math.sin(ang) * r)),
				size = size,
			})
		end
	else
		for _, p in parts do
			table.insert(boxes, { cf = p.CFrame, size = p.Size })
		end
	end
	for i, b in boxes do
		local box = S:part({
			Name = "Redaction",
			Color = BLACK,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 1,
			Size = b.size + Vector3.new(0.6, 0.6, 0.6),
			CFrame = b.cf,
		})
		local sel = Kit.new("SelectionBox", {
			Adornee = box,
			Color3 = RED,
			LineThickness = 0.45 + b.size.Magnitude * 0.006,
			SurfaceTransparency = 1,
			Transparency = 1,
			Parent = box,
		})
		b.box = box
		b.sel = sel
		b.t = 0.15 + 5.0 * ((i - 1) / math.max(1, #boxes)) ^ 0.75
		b.shown = false
	end
	local lb = S:letterbox(60, "SATELLITE FEED  //  ORBIT 7  //  SECTOR " .. string.rep("#", #S.biomeName), "C L A S S I F I E D", RED)
	local ret = S:frame({ Name = "Reticle", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(110, 110), ZIndex = 62 })
	local retC = S:circle(62, RED, 1, 2, ret)
	retC.SizeConstraint = Enum.SizeConstraint.RelativeXY
	for i = 0, 3 do
		local horiz = i % 2 == 0
		S:frame({
			BackgroundColor3 = RED,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(if horiz then (if i == 0 then -0.15 else 1.15) else 0.5, if horiz then 0.5 else (if i == 1 then -0.15 else 1.15)),
			Size = if horiz then UDim2.new(0.4, 0, 0, 2) else UDim2.new(0, 2, 0.4, 0),
			ZIndex = 62,
			Parent = ret,
		})
	end
	local retL = mono(S, 13, {
		Text = "SUBJECT",
		TextColor3 = RED,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(1, 6, 0, 0),
		Size = UDim2.fromOffset(200, 16),
		ZIndex = 62,
		Parent = ret,
	})
	local hud = mono(S, 14, {
		TextColor3 = RED:Lerp(WHITE, 0.3),
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.new(0, 28, 0.13, 0),
		Size = UDim2.fromOffset(420, 80),
		LineHeight = 1.25,
		ZIndex = 62,
	})
	local feedLines = S:scanlines(58, BLACK, 4, 0.82)
	local shownN = 0
	local closeTop = S:frame({ BackgroundColor3 = BLACK, Size = UDim2.fromScale(1, 0), ZIndex = 70 })
	local closeBot = S:frame({ BackgroundColor3 = BLACK, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), ZIndex = 70 })
	S:sfx("RedactedDrone", 0.6, 0.8)
	S:sfx("Whoosh", 0.5, 0.4)
	local beats = { 4.9, 5.5, 5.95 }
	local beatI = 1
	S:phase(6.6, function(k: number, e: number)
		lb.k = outCubic(seg(e, 0, 0.5))
		for _, b in boxes do
			if not b.shown and e >= b.t then
				b.shown = true
				shownN += 1
				-- Matching censor flash on screen, sized to the building's projected size.
				local sp, on = S:toScreen(b.cf.Position)
				if on then
					local dist = (S.cam.CFrame.Position - b.cf.Position).Magnitude
					local focal = sz.Y / (2 * math.tan(math.rad(S.cam.FieldOfView) / 2))
					local px = math.clamp(b.size.Magnitude / math.max(1, dist) * focal, 14, sz.Y * 0.4)
					local mark = S:frame({
						Name = "Mark",
						BackgroundColor3 = RED,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromOffset(sp.X, sp.Y),
						Size = UDim2.fromOffset(px, math.max(8, px * 0.32)),
						Rotation = rng:NextNumber(-12, 12),
						ZIndex = 59,
					})
					local st = Kit.new("UIStroke", { Color = RED, Thickness = 2, Parent = mark })
					local m0 = os.clock()
					S:loop(function(now: number)
						local t = now - m0
						mark.BackgroundColor3 = RED:Lerp(BLACK, seg(t, 0, 0.18))
						mark.BackgroundTransparency = seg(t, 0.35, 0.9)
						st.Transparency = seg(t, 0.2, 0.9)
						if t > 0.9 then
							mark:Destroy()
							return true
						end
						return false
					end)
				end
				if shownN % 2 == 1 then
					S:sfx("Tick", 0.35, 0.5 + 0.8 * (shownN / #boxes))
				end
				if shownN % 9 == 0 then
					S:sfx("RedactedStamp", 0.4, 0.9)
				end
			end
			if b.shown then
				local t = clamp01((e - b.t) / 0.14)
				-- Pops in as a red-hot block and cools to pure black.
				local cool = seg(e - b.t, 0.05, 0.45)
				b.box.Transparency = 1 - outCubic(t)
				b.box.Color = RED:Lerp(BLACK, cool)
				b.box.Material = if cool < 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
				b.box.Size = (b.size + Vector3.new(0.6, 0.6, 0.6)) * lerp(1.25, 1, outCubic(t))
				b.box.CFrame = b.cf
				b.sel.Transparency = lerp(0, 0.3, seg(e - b.t, 0.1, 0.6))
			end
		end
		local hp, on = S:toScreen(S:focusPos())
		ret.Visible = on
		ret.Position = UDim2.fromOffset(hp.X, hp.Y)
		ret.Rotation = math.sin(e * 1.5) * 6
		retL.Text = "SUBJECT  //  " .. (if U.blink(e, 2) > 0 then "TRACKING" else "")
		hud.Text = string.format(
			"LAT  %s.%s\nLON  %s.%s\nALT  %d m\nTARGETS REDACTED  %d / %d",
			"5" .. tostring(rng:NextInteger(0, 9)),
			string.rep("#", 4),
			"-0" .. tostring(rng:NextInteger(0, 9)),
			string.rep("#", 4),
			math.floor(lerp(70, 135, outCubic(k)) * 3.2),
			shownN,
			#boxes
		)
		cc.Saturation = lerp(-0.75, -0.9, k)
		cc.Contrast = 0.3 + 0.1 * k
		cc.Brightness = -0.28 * k
		cc.TintColor = WHITE:Lerp(RED, 0.1 + 0.08 * k)
		gl.k = if rng:NextNumber() < 0.03 then 0.4 else 0.02
		if beatI <= #beats and e >= beats[beatI] then
			beatI += 1
			S:sfx("RedactedHeartbeat", 0.8, 1)
		end
		if e > 3.6 and e - 3.6 < 1 / 50 then
			S:sfx("RedactedRiser", 0.7, 1)
			S:sfx("Riser", 0.45, 0.6)
		end
		local close = inCubic(seg(e, 6.0, 6.6))
		closeTop.Size = UDim2.fromScale(1, 0.5 * close)
		closeBot.Size = UDim2.fromScale(1, 0.5 * close)
		S:duck(lerp(0.25, 0.1, k))
	end)
	S:sfx("RedactedHit", 0.9, 1)
	S:sfx("Boom", 0.6, 0.5)

	------------------------------------------------------------------------------------------------
	-- ACT IV: ACCESS
	------------------------------------------------------------------------------------------------
	black.BackgroundTransparency = 0
	black.ZIndex = 72
	ret.Visible = false
	hud.Visible = false
	feedLines.Visible = false
	lb.k = 0
	local denied: { Frame } = {}
	local function deniedBox(big: boolean)
		local fs = math.floor((if big then rng:NextNumber(34, 60) else rng:NextNumber(14, 26)) * S.vs + 0.5)
		local f = S:frame({
			Name = "Denied",
			BackgroundColor3 = Color3.fromRGB(16, 0, 4),
			BackgroundTransparency = 0.05,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(0.08, 0.92), rng:NextNumber(0.08, 0.92)),
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			Rotation = rng:NextNumber(-4, 4),
			ZIndex = 75 + #denied % 20,
		})
		Kit.new("UIStroke", { Color = RED, Thickness = math.max(2, fs * 0.08), Parent = f })
		Kit.new("UIPadding", {
			PaddingLeft = UDim.new(0, fs * 0.5),
			PaddingRight = UDim.new(0, fs * 0.5),
			PaddingTop = UDim.new(0, fs * 0.2),
			PaddingBottom = UDim.new(0, fs * 0.2),
			Parent = f,
		})
		S:text({
			Text = "ACCESS DENIED",
			FontFace = Kit.Title,
			TextSize = fs,
			TextColor3 = RED,
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			ZIndex = f.ZIndex,
			Parent = f,
		})
		local sc = Kit.new("UIScale", { Scale = 1.6, Parent = f })
		Kit.tween(sc, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
		table.insert(denied, f)
	end
	local nextDen = 0
	S:phase(2.2, function(k: number, e: number)
		if e >= nextDen then
			nextDen = e + lerp(0.26, 0.025, k ^ 0.7)
			deniedBox(rng:NextNumber() < 0.15 + 0.2 * k)
			S:sfx("Error", 0.35 + 0.3 * k, 0.8 + rng:NextNumber() * 0.4)
			S:sfx("RedactedDenied", 0.5, 1)
		end
		gl.k = 0.1 + 0.9 * k ^ 2
		S.shake = 0.1 + 0.9 * k ^ 2
		blur.Size = 0
	end)
	-- Total silence.
	for _, f in denied do
		f:Destroy()
	end
	gl.k = 0
	S.shake = 0
	S:duck(0)
	local cursor = mono(S, 22, {
		Text = "_",
		TextColor3 = WHITE,
		Position = UDim2.new(0.18, 0, 0.5, -14),
		Size = UDim2.new(0.7, 0, 0, 30),
		ZIndex = 80,
	})
	S:timeline(1.1, {
		{
			at = 0.45,
			fn = function()
				S:sfx("RedactedHeartbeat", 0.9, 1)
			end,
		},
		{
			at = 0.85,
			fn = function()
				S:sfx("RedactedHeartbeat", 0.9, 1)
			end,
		},
	}, function(_: number, e: number)
		cursor.TextTransparency = if U.blink(e, 1.8) > 0 then 0 else 1
	end)
	local auth = "> AUTHORIZATION:  1 IN " .. U.commas(a.chance)
	cursor.TextTransparency = 0
	S:typeInto(cursor, auth, 34, 0.25, true)
	S:phase(#auth / 34 + 0.45)
	cursor:Destroy()
	local granted = S:text({
		Text = "ACCESS GRANTED",
		FontFace = Kit.Title,
		TextSize = math.floor(64 * S.vs + 0.5),
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 80),
		ZIndex = 80,
	})
	local under = S:frame({
		BackgroundColor3 = RED,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, math.floor(48 * S.vs)),
		Size = UDim2.new(0, 0, 0, 3),
		ZIndex = 80,
	})
	S:sfx("RedactedGranted", 0.9, 1)
	S:sfx("Reveal5", 0.45, 0.6)
	S:sfx("Click", 0.8, 0.5)
	S:phase(0.6, function(k: number)
		under.Size = UDim2.new(0.5 * outCubic(k), 0, 0, 3)
		granted.TextTransparency = 0
		local sc = 1 + 0.04 * k
		granted.TextSize = math.floor(64 * S.vs * sc + 0.5)
	end)

	------------------------------------------------------------------------------------------------
	-- ACT V: REVEAL
	------------------------------------------------------------------------------------------------
	granted:Destroy()
	under:Destroy()
	closeTop:Destroy()
	closeBot:Destroy()
	S:sfx("RedactedHit", 1, 1)
	S:sfx("RedactedChoir", 0.9, 1)
	S:sfx("Boom", 1, 0.45)
	S:sfx("Whoosh", 0.9, 0.6)
	S:duck(0.35)
	S:burst(3.5)
	S:worldFlash(RED, 1.2)
	S:flash(WHITE, 1, 0.25, 125)
	S:flash(RED, 0.8, 0.9, 124)
	S:orbitShot({ dur = 7.5, deg = 200, r0 = 9.5, r1 = 7.5, h0 = 0.4, h1 = 1.6, look = 1.6, fov0 = 64, fov1 = 48, roll = 2.5, blend = 0, ease = function(t: number): number
		return t
	end })
	-- Boxes blow away from the player.
	local c = S:focusPos()
	for _, b in boxes do
		local d = (b.cf.Position - c) * Vector3.new(1, 0, 1)
		local dir = if d.Magnitude > 0.1 then d.Unit else Vector3.new(1, 0, 0)
		b.vel = dir * rng:NextNumber(60, 140) + Vector3.new(0, rng:NextNumber(40, 110), 0)
		b.spin = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3))
		b.delay = d.Magnitude / 400
		b.box.Transparency = if b.shown then 0 else 1
	end
	-- Red shockwave across the whole map.
	local ring: { BasePart } = {}
	local ringW: { BasePart } = {}
	local nSeg = 64
	for i = 1, nSeg do
		ring[i] = S:part({ Name = "Shock", Color = RED, Transparency = 0.1, Size = Vector3.new(1, 6, 1.5) })
		ringW[i] = S:part({ Name = "ShockCore", Color = Color3.fromRGB(255, 200, 205), Transparency = 0.3, Size = Vector3.new(1, 3, 0.8) })
	end
	local groundY = c.Y - 3
	local function shock(list: { BasePart }, r: number, h: number, t: number)
		local cfs = {}
		local segLen = 2 * math.pi * r / nSeg * 1.08
		for i, p in list do
			local ang = (i - 0.5) / nSeg * math.pi * 2
			cfs[i] = CFrame.new(c.X + math.cos(ang) * r, groundY + h * 0.5, c.Z + math.sin(ang) * r) * CFrame.Angles(0, -ang + math.pi / 2, 0)
			p.Size = Vector3.new(math.max(0.2, segLen), h, p.Size.Z)
			p.Transparency = t
		end
		workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	local embers = S:particles(30, {
		colors = { RED, Color3.fromRGB(255, 120, 130), BLACK },
		size = { 3, 9 },
		speed = { 40, 140 },
		angle = { -math.pi * 0.7, -math.pi * 0.3 },
		life = { 1.5, 3 },
		spin = { -200, 200 },
		from = function()
			return rng:NextNumber(0, sz.X), sz.Y + 8
		end,
	})
	local function blowBoxes(e: number)
		local list, cfs = {}, {}
		for _, b in boxes do
			local t = math.max(0, e - b.delay)
			local pos = b.cf.Position + b.vel * t + Vector3.new(0, -60 * t * t, 0)
			local rot = CFrame.Angles(b.spin.X * t, b.spin.Y * t, b.spin.Z * t)
			table.insert(list, b.box)
			table.insert(cfs, CFrame.new(pos) * (b.cf - b.cf.Position) * rot)
			if b.shown then
				b.box.Transparency = seg(t, 0.3, 1.4)
				b.sel.Transparency = seg(t, 0, 0.6)
			end
		end
		workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- Name card behind censor bars.
	local card = S:nameCard({
		z = 40,
		y = 0.42,
		c1 = WHITE,
		c2 = Color3.fromRGB(255, 190, 196),
		splitA = RED,
		splitB = Color3.fromRGB(120, 0, 20),
		stroke = BLACK,
		maxText = 140,
	})
	card.setVisible(-1)
	card.setT(1)
	S:phase(0.35, function(_: number, e: number)
		black.BackgroundTransparency = outCubic(clamp01(e / 0.3))
		blowBoxes(e)
		shock(ring, 4 + 900 * outQuart(clamp01(e / 3.6)), 6, 0.1)
		shock(ringW, 2 + 900 * outQuart(clamp01((e - 0.12) / 3.6)), 3, 0.3)
		cc.TintColor = WHITE:Lerp(RED, 0.5)
		cc.Saturation = -0.3
		cc.Contrast = 0.35
		cc.Brightness = 0.05
	end)
	black:Destroy()
	-- Bars fly in from everywhere and lock over the name.
	local tb = card.main.TextBounds
	local nameW = math.max(tb.X, sz.X * 0.3)
	local nameH = math.max(tb.Y, sz.Y * 0.08)
	local nx0, ny0 = sz.X * 0.5 - nameW * 0.5 - 10, sz.Y * 0.42 - nameH * 0.5 - 6
	local nCols = math.max(4, card.n)
	local rows = 3
	local bars = {}
	for col = 1, nCols do
		for row = 1, rows do
			local tx = nx0 + (col - 1) * (nameW + 20) / nCols
			local ty = ny0 + (row - 1) * (nameH + 12) / rows
			local w = (nameW + 20) / nCols + 2
			local h = (nameH + 12) / rows + 2
			local ang = rng:NextNumber(0, math.pi * 2)
			local f = S:frame({
				Name = "NameBar",
				BackgroundColor3 = BLACK,
				Position = UDim2.fromOffset(sz.X * 0.5 + math.cos(ang) * sz.X, sz.Y * 0.5 + math.sin(ang) * sz.X),
				Size = UDim2.fromOffset(w, h),
				ZIndex = 52,
			})
			Kit.new("UIStroke", { Color = RED, Thickness = 1, Transparency = 0.4, Parent = f })
			table.insert(bars, { f = f, tx = tx, ty = ty, fx = f.Position.X.Offset, fy = f.Position.Y.Offset, col = col, row = row, delay = rng:NextNumber(0, 0.6), landed = false, rot = rng:NextNumber(-180, 180) })
		end
	end
	local t0 = 0.35
	S:phase(1.35, function(_: number, e: number)
		local ee = e + t0
		blowBoxes(ee)
		shock(ring, 4 + 900 * outQuart(clamp01(ee / 3.6)), lerp(6, 1, clamp01(ee / 3.6)), lerp(0.1, 1, clamp01((ee - 1.5) / 2.1)))
		shock(ringW, 2 + 900 * outQuart(clamp01((ee - 0.12) / 3.6)), lerp(3, 0.5, clamp01(ee / 3.6)), lerp(0.3, 1, clamp01((ee - 1.2) / 2.2)))
		embers.rate = 30
		cc.TintColor = WHITE:Lerp(RED, lerp(0.5, 0.18, clamp01(e / 1)))
		for _, b in bars do
			local t = clamp01((e - b.delay) / 0.45)
			local q = outCubic(t)
			b.f.Position = UDim2.fromOffset(lerp(b.fx, b.tx, q), lerp(b.fy, b.ty, q))
			b.f.Rotation = b.rot * (1 - q)
			if t >= 1 and not b.landed then
				b.landed = true
				S:sfx("Tick", 0.3, 0.6 + rng:NextNumber() * 0.4)
			end
		end
		if card.band then
			card.band.BackgroundTransparency = 1 - outCubic(clamp01(e / 0.6))
		end
	end)
	card.setT(0)
	if S.info.first then
		S:sfx("Announce", 0.6, 0.8)
		S:typeInto(card.newL, "> NEW SIGNATURE DISCOVERED <", 50, 0.25)
	end
	-- Declassified column by column.
	local per = 1.4 / nCols
	local revealed = 0
	S:phase(per * nCols + 0.1, function(_: number, e: number)
		local ee = e + t0 + 1.35
		blowBoxes(ee)
		shock(ring, 4 + 900 * outQuart(clamp01(ee / 3.6)), 1, 1)
		local cnum = math.min(nCols, math.floor(e / per) + 1)
		if cnum ~= revealed then
			revealed = cnum
			card.popAt = os.clock()
			S:sfx("Type", 0.6, 0.7 + cnum / nCols * 0.6)
			S:sfx("RedactedStamp", 0.45, 1.1)
			S:sfx("Glitch", 0.2, 1.5)
		end
		for _, b in bars do
			if b.col <= revealed then
				local t = clamp01((e - (b.col - 1) * per) / 0.3)
				local dir = if b.row == 1 then -1 elseif b.row == rows then 1 else (if b.col % 2 == 0 then -1 else 1)
				b.f.Position = UDim2.fromOffset(b.tx, b.ty + dir * sz.Y * 0.25 * inCubic(t))
				b.f.BackgroundTransparency = t
				local st = b.f:FindFirstChildOfClass("UIStroke")
				if st then
					st.Transparency = lerp(0.4, 1, t)
				end
			end
		end
	end)
	for _, b in bars do
		b.f:Destroy()
	end
	-- The full name: the big hit.
	card.popAt = os.clock()
	S:sfx("RedactedHit", 1, 0.9)
	S:sfx("Boom", 1, 0.6)
	S:sfx("Reveal5", 0.7, 0.8)
	S:burst(3.5)
	S:worldFlash(RED, 1)
	S:flash(WHITE, 0.6, 0.35, 125)
	S:ring(46, WHITE, 1.1, 2.4, 6, UDim2.fromScale(0.5, 0.42))
	S:ring(46, RED, 1.5, 2, 3, UDim2.fromScale(0.5, 0.42))
	embers.emit(40)
	-- Second shockwave.
	local w0 = os.clock()
	S:loop(function(now: number)
		local e = now - w0
		shock(ring, 4 + 900 * outQuart(clamp01(e / 3)), lerp(8, 1, clamp01(e / 3)), lerp(0, 1, clamp01((e - 1) / 2)))
		return e > 3
	end)
	S:timeline(1.8, {
		{
			at = 0.85,
			fn = function()
				S:stamp("DECLASSIFIED", RED, UDim2.fromScale(0.5, 0.64), -7, 42, 60)
				S:sfx("RedactedStamp", 0.8, 0.9)
				S:sfx("Boom", 0.6, 0.8)
				S.shake = 0.5
				S:after(0.25, function()
					S.shake = 0
				end)
			end,
		},
	}, function(_: number, e: number)
		card.jitter = lerp(1, 0.25, clamp01(e / 0.8))
		local subText = "[ " .. S.tier.name .. " ]   " .. RNG.ChanceText(a.chance) .. "   //   THE RAREST SIGNATURE IN EXISTENCE"
		local cN = math.min(#subText, math.floor(seg(e, 0.15, 0.8) * #subText))
		card.sub.Text = subText:sub(1, cN)
		if cN % 3 == 0 and cN > 0 and cN < #subText then
			S:sfx("Type", 0.22, 1.2)
		end
		cc.TintColor = WHITE:Lerp(RED, 0.15)
		cc.Contrast = 0.25
		cc.Saturation = -0.2
	end)
	-- Hold, then the final white-out.
	S:phase(1.2, function(_: number, e: number)
		card.jitter = 0.25 + 0.1 * math.sin(e * 6)
	end)
	S:sfx("RedactedRiser", 0.7, 1.3)
	S:sfx("Riser", 0.5, 1.8)
	local fin = os.clock()
	S:loop(function(now: number)
		local k = clamp01((now - fin) / 0.6)
		card.jitter = 0.25 + 2 * k
		card.scale = 1 + 0.2 * k
		return k >= 1
	end)
	S:outro(WHITE, 0.6, 0.9)
end

return { Redacted = scene }
