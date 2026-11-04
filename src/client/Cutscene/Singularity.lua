--!strict
-- Cutscene/Singularity: themed ~12s scenes for the SINGULARITY tier (except [REDACTED], see Redacted.lua).
--
--   Singularity   data fragments everywhere, all of it collapses into one point, silence, big bang with a
--                 galaxy spiral, light beams, the camera rises into the sky and dives back, the name
--   Architect     the world is rewritten: green wireframe grid floor, floating code pages, a giant wireframe
--                 sphere is built around the city with god-rays, 404 PAGE NOT FOUND, a rewrite wave, the name

local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local U = require(script.Parent.Util)
local Fx = require(script.Parent.Fx)

local WHITE, BLACK = U.WHITE, U.BLACK
local clamp01, lerp, seg = U.clamp01, U.lerp, U.seg
local outCubic, inCubic, outQuart, inQuart = U.outCubic, U.inCubic, U.outQuart, U.inQuart
local setT, setLine = Fx.setT, Fx.setLine

local Scenes = {}

local function mono(S: any, size: number, props: { [string]: any }): TextLabel
	local p: { [string]: any } = { FontFace = Kit.MonoBold, TextSize = math.floor(size * S.vs + 0.5) }
	for k, v in props do
		p[k] = v
	end
	local l = S:text(p)
	Kit.new("UIStroke", { Thickness = 1.5, Color = BLACK, Transparency = 0.4, Parent = l })
	return l
end

-- Final act shared by both scenes: hero camera, the name spelled out, subtitle, the big hit, white-out.
local function finale(S: any, accent: Color3, extraHit: (() -> ())?)
	local card = S:nameCard({ z = 40 })
	card.spell(1.5)
	S:sfx("Boom", 1, 0.8)
	S:sfx("Reveal5", 0.6, 1)
	S:burst(3.2)
	S:worldFlash(accent, 0.9)
	S:ring(46, WHITE, 1.1, 2.2, 5)
	S:ring(46, accent, 1.5, 1.8, 3)
	if extraHit then
		extraHit()
	end
	S:flash(WHITE, 0.45, 0.35, 45)
	card.subtitle(1.3)
	S:sfx("Riser", 0.4, 1.8)
	local t0 = os.clock()
	S:loop(function(now: number)
		local k = clamp01((now - t0) / 0.5)
		card.jitter = 0.25 + 1.5 * k
		card.scale = 1 + 0.15 * k
		return k >= 1
	end)
	S:outro(WHITE, 0.5, 0.7)
end

--------------------------------------------------------------------------------------------------------
-- SINGULARITY: all data collapses into one point
--------------------------------------------------------------------------------------------------------

function Scenes.Singularity(S: any)
	local a = S.aura
	local acol = U.glowColor(a)
	local cyan = a.color2
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	local cx, cy = sz.X * 0.5, sz.Y * 0.5
	S:hideHud()
	local cc = S:cc()
	local blur = S:blur()
	local black = S:fill(BLACK, 20, 1)
	local vig = S:edges(BLACK, 0.45, 15)
	setT(vig, 1)

	-- 1) Data fragments drift everywhere.
	local frags = {}
	for i = 1, 46 do
		local isPanel = i % 4 == 0
		local f: GuiObject
		if isPanel then
			f = S:frame({
				BackgroundColor3 = if i % 8 == 0 then cyan else WHITE,
				BackgroundTransparency = 0.75,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(rng:NextNumber(30, 110) * S.vs, rng:NextNumber(14, 50) * S.vs),
				ZIndex = 24,
			})
			Kit.new("UIStroke", { Color = WHITE, Thickness = 1, Transparency = 0.4, Parent = f })
		else
			local word = if rng:NextNumber() < 0.5 then U.codeWord(rng) else "0x" .. U.hex(rng, rng:NextInteger(2, 6))
			f = mono(S, rng:NextInteger(12, 22), {
				Text = word,
				TextColor3 = if i % 3 == 0 then cyan else WHITE,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(160, 24),
				ZIndex = 24,
			})
		end
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.25, 0.75) * sz.Magnitude * 0.5
		table.insert(frags, {
			f = f,
			x = cx + math.cos(ang) * r,
			y = cy + math.sin(ang) * r,
			vx = rng:NextNumber(-25, 25),
			vy = rng:NextNumber(-25, 25),
			vr = rng:NextNumber(-30, 30),
			panel = isPanel,
		})
	end
	local function setFragT(t: number)
		for _, fr in frags do
			if fr.panel then
				(fr.f :: Frame).BackgroundTransparency = lerp(0.75, 1, t)
			else
				(fr.f :: TextLabel).TextTransparency = t
			end
		end
	end
	setFragT(1)
	S:frontShot({ dur = 4.4, d0 = 13, d1 = 9, h0 = 2, h1 = 1.4, fov0 = 56, fov1 = 50, blend = 0.6 })
	S:sfx("Riser", 0.4, 0.6)
	S:sfx("Glitch", 0.3, 0.5)
	S:phase(2.0, function(k: number, e: number)
		setFragT(1 - 0.8 * seg(e, 0, 0.6))
		black.BackgroundTransparency = 1 - 0.35 * k
		cc.Saturation = -0.4 * k
		for _, fr in frags do
			fr.x += fr.vx / 60
			fr.y += fr.vy / 60
			fr.f.Position = UDim2.fromOffset(fr.x, fr.y)
			fr.f.Rotation += fr.vr / 60
		end
		if rng:NextNumber() < 0.08 then
			S:sfx("Type", 0.15, 1.5 + rng:NextNumber() * 0.5)
		end
	end)
	-- 2) Everything collapses into the centre.
	local streaks = S:streaks(22, 46, acol)
	S:sfx("Riser", 0.7, 0.9)
	S:sfx("Whoosh", 0.6, 0.5)
	S:phase(2.2, function(k: number, e: number)
		local q = inCubic(k)
		for _, fr in frags do
			local dx, dy = cx - fr.x, cy - fr.y
			local d = math.sqrt(dx * dx + dy * dy)
			local pull = (60 + 2400 * q) / 60
			if d > 2 then
				fr.x += dx / d * math.min(d, pull) + (-dy / d) * pull * 0.35
				fr.y += dy / d * math.min(d, pull) + (dx / d) * pull * 0.35
			end
			fr.f.Position = UDim2.fromOffset(fr.x, fr.y)
			fr.f.Rotation += (fr.vr + 400 * q) / 60
			local s = math.clamp(d / (sz.Y * 0.3), 0.05, 1)
			fr.f.Size = UDim2.fromOffset(fr.f.Size.X.Offset * (0.985 + 0.015 * s), fr.f.Size.Y.Offset * (0.985 + 0.015 * s))
			if d < 12 then
				fr.f.Visible = false
			end
		end
		streaks.k = 0.2 + 0.8 * k
		black.BackgroundTransparency = 1 - (0.35 + 0.65 * inQuart(k))
		setT(vig, 1 - 0.8 * k)
		S:duck(1 - k)
		S.fovPunch = -10 * q
		S.shake = 0.5 * q
		cc.Contrast = 0.3 * k
		if math.floor(e * 8) ~= math.floor((e - 1 / 60) * 8) then
			S:sfx("Tick", 0.2 + 0.2 * k, 0.5 + k)
		end
	end)
	for _, fr in frags do
		fr.f:Destroy()
	end
	streaks.k = 0
	black.BackgroundTransparency = 0
	S.fovPunch = 0
	S.shake = 0

	-- 3) Silence; one white point.
	local mode = "front"
	local m0 = os.clock()
	local lv = S:focusLook()
	local riseTop = 320
	local function skyCF(c: Vector3, h: number, spin: number, k: number): CFrame
		local dir = (CFrame.fromAxisAngle(Vector3.yAxis, spin) * CFrame.new(lv)).Position
		local pos = c + dir * lerp(10, 3, k) + Vector3.new(0, h, 0)
		local up = Vector3.yAxis:Lerp(-dir, clamp01(k * 1.4))
		if up.Magnitude < 0.01 then
			up = -dir
		end
		return CFrame.lookAt(pos, c, up.Unit)
	end
	S:shot(function(_: number, c: Vector3)
		local e = os.clock() - m0
		if mode == "front" then
			local look = c + Vector3.new(0, 1.5, 0)
			return CFrame.lookAt(S:safe(look, c + lv * 10 + Vector3.new(0, 1.2, 0)), look), 60
		elseif mode == "rise" then
			local k = clamp01(e / 2)
			return skyCF(c, lerp(2, riseTop, outQuart(k)), math.rad(140) * outCubic(k), outCubic(k)), lerp(60, 72, k)
		elseif mode == "dive" then
			local k = clamp01(e / 1.1)
			return skyCF(c, lerp(riseTop, 9, inCubic(k)), math.rad(140) + math.rad(220) * inCubic(k), 1), lerp(72, 112, inQuart(k))
		end
		local k = clamp01(e / 4)
		local look = c + Vector3.new(0, 1.5, 0)
		local rv = lv:Cross(Vector3.yAxis)
		local pos = S:safe(look, c + lv * lerp(8.5, 6.2, outCubic(k)) + rv * lerp(1.6, -0.8, k) + Vector3.new(0, 1.2, 0))
		return CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, math.rad(lerp(3, 0, outCubic(k)))), lerp(48, 44, k)
	end, 0)
	S:phase(0.6)
	local point = S:circle(30, WHITE, 0)
	local halo = S:circle(29, acol, 0)
	halo.BackgroundTransparency = 0.7
	S:sfx("Tick", 0.6, 0.4)
	S:phase(0.9, function(k: number, e: number)
		local fl = 1 + math.noise(e * 14, 2.2) * 0.3
		local s = (0.006 + 0.012 * k) * fl
		point.Size = UDim2.fromScale(s, s)
		halo.Size = UDim2.fromScale(s * 5, s * 5)
		if math.floor(e * 2.5) ~= math.floor((e - 1 / 60) * 2.5) then
			S:ring(28, acol, 1.2, 0.5, 2)
		end
	end)

	-- 4) Big bang: galaxy spiral, rings, light beams; the camera rises into the sky.
	S:sfx("Boom", 1, 0.5)
	S:sfx("Whoosh", 0.9, 0.7)
	S:sfx("Reveal5", 0.4, 0.6)
	S:flash(WHITE, 1, 0.8, 60)
	S:ring(31, WHITE, 1, 2.6, 7)
	S:ring(31, acol, 1.4, 2.2, 4)
	S:ring(31, cyan, 1.8, 1.8, 2)
	S:burst(3)
	S:worldFlash(acol, 1)
	S:duck(0.4)
	local galaxy = S:frame({ Name = "Galaxy", BackgroundTransparency = 1, ZIndex = 26 })
	local stars = {}
	for i = 1, 150 do
		local arm = i % 3
		local t = rng:NextNumber() ^ 0.7
		local f = S:frame({
			BackgroundColor3 = if rng:NextNumber() < 0.3 then cyan else WHITE:Lerp(acol, rng:NextNumber()),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(3, 3),
			ZIndex = 26,
			Parent = galaxy,
		})
		Kit.corner(f, 2)
		stars[i] = { f = f, t = t, arm = arm, jit = rng:NextNumber(-0.25, 0.25), s = rng:NextNumber(2, 5) }
	end
	local c0 = S:focusPos()
	for i = 1, 8 do
		local ang = i / 8 * math.pi * 2
		local p = S:part({
			Name = "LightBeam",
			Color = if i % 2 == 0 then cyan else WHITE,
			Transparency = 0.35,
			Size = Vector3.new(0.6, 500, 0.6),
			CFrame = CFrame.new(c0 + Vector3.new(math.cos(ang) * 14, 250, math.sin(ang) * 14)),
		})
		Kit.new("PointLight", { Color = p.Color, Brightness = 2, Range = 18, Parent = p })
	end
	mode = "rise"
	m0 = os.clock()
	point:Destroy()
	halo:Destroy()
	S:phase(2.0, function(k: number, e: number)
		black.BackgroundTransparency = outCubic(seg(e, 0, 0.6))
		local grow = outCubic(seg(k, 0, 0.7))
		local fade = seg(k, 0.55, 1)
		for _, st in stars do
			local r = st.t * sz.Y * 0.62 * grow
			local ang = st.arm * (math.pi * 2 / 3) + st.t * 5.2 + st.jit - e * 1.2
			st.f.Position = UDim2.fromOffset(cx + math.cos(ang) * r, cy + math.sin(ang) * r * 0.62)
			st.f.Size = UDim2.fromOffset(st.s, st.s)
			st.f.BackgroundTransparency = lerp(0.1, 1, fade)
		end
		galaxy.Rotation = e * 8
		setT(vig, 1 - 0.6 * clamp01(e / 0.6))
		cc.Saturation = lerp(-1, -0.2, clamp01(e / 0.6))
		cc.Contrast = 0.2
		cc.TintColor = WHITE:Lerp(acol, 0.12)
	end)
	galaxy:Destroy()

	-- 5) Dive back down with speed lines.
	mode = "dive"
	m0 = os.clock()
	streaks.mode = "out"
	S:sfx("Whoosh", 0.9, 1.2)
	S:sfx("Riser", 0.5, 1.4)
	S:phase(1.1, function(k: number)
		streaks.k = inCubic(k)
		S.shake = 0.5 * inCubic(k)
		blur.Size = 6 * inCubic(k)
	end)
	mode = "hero"
	m0 = os.clock()
	streaks.k = 0
	S.shake = 0
	S:sfx("Boom", 0.85, 0.7)
	S:burst(1.5)
	S:phase(0.25, function(k: number)
		blur.Size = lerp(6, 14, outCubic(k))
		cc.Brightness = -0.12 * k
		cc.Saturation = lerp(-0.2, -0.5, k)
	end)
	-- 6) The name.
	finale(S, acol)
end

--------------------------------------------------------------------------------------------------------
-- THE ARCHITECT: wrote the world, page not found
--------------------------------------------------------------------------------------------------------

local function buildSphere(S: any, color: Color3): any
	local segs = {}
	local nLon, nLat, steps = 12, 7, 20
	local function add(a: Vector3, b: Vector3, order: number)
		local p = S:part({
			Name = "Wire",
			Color = color,
			Transparency = 1,
			Size = Vector3.new(0.35, 0.35, 1),
		})
		table.insert(segs, { p = p, a = a, b = b, order = order })
	end
	for j = 0, nLon - 1 do
		local phi = j / nLon * math.pi * 2
		for i = 0, steps - 1 do
			local t1, t2 = i / steps * math.pi, (i + 1) / steps * math.pi
			add(
				Vector3.new(math.sin(t1) * math.cos(phi), math.cos(t1), math.sin(t1) * math.sin(phi)),
				Vector3.new(math.sin(t2) * math.cos(phi), math.cos(t2), math.sin(t2) * math.sin(phi)),
				i / steps
			)
		end
	end
	for i = 1, nLat do
		local th = i / (nLat + 1) * math.pi
		for s = 0, steps - 1 do
			local p1, p2 = s / steps * math.pi * 2, (s + 1) / steps * math.pi * 2
			add(
				Vector3.new(math.sin(th) * math.cos(p1), math.cos(th), math.sin(th) * math.sin(p1)),
				Vector3.new(math.sin(th) * math.cos(p2), math.cos(th), math.sin(th) * math.sin(p2)),
				(i - 1) / nLat
			)
		end
	end
	local Sp: any = { segs = segs }
	-- Places the sphere; reveal 0..1 shows wires in build order.
	function Sp.update(center: Vector3, radius: number, spin: number, reveal: number, transparency: number)
		local parts, cfs = {}, {}
		local rot = CFrame.Angles(0, spin, 0)
		for _, sgm in segs do
			local A = center + rot:VectorToWorldSpace(sgm.a * radius)
			local B = center + rot:VectorToWorldSpace(sgm.b * radius)
			local len = (B - A).Magnitude
			sgm.p.Size = Vector3.new(0.35 + radius * 0.004, 0.35 + radius * 0.004, math.max(0.05, len))
			table.insert(parts, sgm.p)
			table.insert(cfs, CFrame.lookAt((A + B) / 2, B))
			sgm.p.Transparency = if sgm.order <= reveal then transparency else 1
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	return Sp
end

function Scenes.Architect(S: any)
	local a = S.aura
	local green = a.color
	local rng = S.rng
	local sz = S.gui.AbsoluteSize
	S:hideHud()
	local cc = S:cc()
	local rays = S:sunRays()
	local tint = S:fill(Color3.fromRGB(0, 20, 12), 8, 1)

	-- 1) Terminal command + perspective grid floor + floating code pages.
	local term = mono(S, 17, {
		TextColor3 = green,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(30, 30),
		Size = UDim2.fromOffset(600, 120),
		LineHeight = 1.2,
		ZIndex = 30,
	})
	local hz = sz.Y * 0.52
	local vx = sz.X * 0.5
	local grid = S:frame({ Name = "Grid", BackgroundTransparency = 1, ZIndex = 10, ClipsDescendants = true })
	local vLines = {}
	for i = -12, 12 do
		local l = S:line(vx, hz, vx, hz, 2, green, 10, grid)
		l.BackgroundTransparency = 0.45
		table.insert(vLines, { f = l, x = vx + i * sz.X * 0.16 })
	end
	local hLines = {}
	for i = 1, 14 do
		local l = S:frame({
			BackgroundColor3 = green,
			BackgroundTransparency = 0.45,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 0, 0, 2),
			ZIndex = 10,
			Parent = grid,
		})
		hLines[i] = { f = l, z = i }
	end
	local horizon = S:frame({
		BackgroundColor3 = green,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(vx, hz),
		Size = UDim2.new(0, 0, 0, 3),
		ZIndex = 11,
		Parent = grid,
	})
	local pages = {}
	for i = 1, 7 do
		local pg = Kit.panel(S.gui, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(0.08, 0.92), rng:NextNumber(0.6, 1.2)),
			Size = UDim2.fromOffset(math.floor(170 * S.vs), math.floor(220 * S.vs)),
			Rotation = rng:NextNumber(-12, 12),
			BackgroundTransparency = 0.25,
			ZIndex = 18,
		}, green)
		local lines = {}
		for _ = 1, 12 do
			table.insert(lines, string.rep(" ", rng:NextInteger(0, 3)) .. U.codeWord(rng) .. " " .. U.codeWord(rng) .. " " .. U.hex(rng, 4))
		end
		mono(S, 10, {
			Text = "world.rbxl :: p." .. i .. "\n" .. table.concat(lines, "\n"),
			TextColor3 = green:Lerp(WHITE, 0.3),
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.new(1, -20, 1, -16),
			ZIndex = 19,
			Parent = pg,
		})
		local sc = Kit.new("UIScale", { Scale = 0, Parent = pg })
		pages[i] = { pg = pg, sc = sc, vy = rng:NextNumber(0.03, 0.07), delay = i * 0.12, vr = rng:NextNumber(-6, 6) }
	end
	S:frontShot({ dur = 3, d0 = 12, d1 = 10, h0 = 2.5, h1 = 2, fov0 = 56, fov1 = 52, blend = 0.6 })
	S:sfx("Type", 0.5, 0.7)
	S:sfx("Riser", 0.4, 0.6)
	S:typeInto(term, "architect@world:~$ sudo rewrite world.rbxl --from-scratch\n[ok] loading blueprint ...\n[ok] unlocking geometry ...", 50, 0.2)
	S:phase(2.4, function(k: number, e: number)
		local q = outCubic(seg(k, 0, 0.7))
		tint.BackgroundTransparency = 1 - 0.35 * q
		cc.Saturation = -0.85 * q
		cc.Contrast = 0.35 * q
		cc.TintColor = WHITE:Lerp(green, 0.35 * q)
		horizon.Size = UDim2.new(q, 0, 0, 3)
		for _, v in vLines do
			local tx = v.x + (v.x - vx) * 3
			setLine(v.f, vx, hz, lerp(vx, tx, q), lerp(hz, sz.Y * 1.5, q), 2)
		end
		for _, h in hLines do
			local z = ((h.z - e * 1.6) % 14) + 0.6
			local y = hz + (sz.Y - hz) * (1.2 / z)
			h.f.Position = UDim2.fromOffset(vx, y)
			h.f.Size = UDim2.new(q * 1.4, 0, 0, 2)
			h.f.BackgroundTransparency = lerp(0.9, 0.35, clamp01(1.4 / z)) + (1 - q) * 0.5
		end
		for _, pg in pages do
			local t = clamp01((e - pg.delay) / 0.5)
			pg.sc.Scale = U.outBack(t) * S.vs
			pg.pg.Position += UDim2.fromScale(0, -pg.vy / 60)
			pg.pg.Rotation += pg.vr / 60
		end
	end)

	-- 2) The wireframe sphere is built around the city; god-rays fall.
	local sphere = buildSphere(S, green)
	local god = {}
	local c0 = S:focusPos()
	for i = 1, 10 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(15, 90)
		local p = S:part({
			Name = "GodRay",
			Color = green:Lerp(WHITE, 0.3),
			Transparency = 1,
			Size = Vector3.new(rng:NextNumber(1.5, 4), 600, rng:NextNumber(1.5, 4)),
			CFrame = CFrame.new(c0 + Vector3.new(math.cos(ang) * r, 300, math.sin(ang) * r)) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8))),
		})
		god[i] = { p = p, delay = rng:NextNumber(0, 1.6) }
	end
	S:skyShot({ dur = 3.6, h0 = 3, h1 = 95, r0 = 12, r1 = 130, spin = 120, fov0 = 60, fov1 = 70, look = 15, blend = 0.6 })
	S:sfx("Riser", 0.6, 0.8)
	S:sfx("Whoosh", 0.6, 0.5)
	local lastClick = 0
	S:phase(3.6, function(k: number, e: number)
		local fade = seg(e, 0, 0.5)
		grid.Visible = fade < 1
		for _, v in vLines do
			v.f.BackgroundTransparency = lerp(0.45, 1, fade)
		end
		for _, h in hLines do
			h.f.BackgroundTransparency = lerp(h.f.BackgroundTransparency, 1, fade)
		end
		horizon.BackgroundTransparency = fade
		for _, pg in pages do
			pg.pg.Position += UDim2.fromScale(0, -pg.vy * 2 / 60)
		end
		local reveal = outCubic(seg(k, 0, 0.8))
		sphere.update(S:focusPos(), 75, e * 0.15, reveal, 0.15)
		for _, g in god do
			g.p.Transparency = lerp(1, 0.55, seg(e, g.delay, g.delay + 0.4))
		end
		rays.Intensity = 0.2 * k
		if e - lastClick > 0.09 and reveal < 1 then
			lastClick = e
			S:sfx("Click", 0.2, 0.8 + reveal)
		end
		term.TextTransparency = fade
	end)
	for _, pg in pages do
		pg.pg:Destroy()
	end

	-- 3) 404: the world flickers, a rewrite wave sweeps the screen.
	local big = S:text({
		Text = "404",
		FontFace = Kit.Title,
		TextSize = math.floor(170 * S.vs + 0.5),
		TextColor3 = green,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, 0, 0, 180),
		ZIndex = 35,
	})
	Kit.new("UIStroke", { Thickness = 4, Color = BLACK, Transparency = 0.2, Parent = big })
	local nf = mono(S, 22, {
		Text = "PAGE NOT FOUND  //  THE WORLD IS BEING REWRITTEN",
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, math.floor(95 * S.vs)),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 35,
	})
	local gl = S:glitchLayer(32, { green, WHITE, BLACK, Color3.fromRGB(0, 120, 70) })
	local wave = S:frame({
		BackgroundColor3 = green:Lerp(WHITE, 0.4),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, 0, 0, math.floor(30 * S.vs)),
		ZIndex = 33,
		Position = UDim2.fromScale(0, -0.1),
	})
	Kit.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.6, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = wave,
	})
	S:frontShot({ dur = 5, d0 = 10, d1 = 7, h0 = 0.5, h1 = 1, fov0 = 58, fov1 = 48, roll0 = 4, roll1 = 0, blend = 0 })
	S:sfx("Error", 0.8, 0.6)
	S:sfx("Glitch", 0.8, 0.5)
	S:flash(WHITE, 0.7, 0.3, 50)
	S:phase(1.5, function(k: number, e: number)
		big.TextTransparency = if S.rng:NextNumber() < 0.12 then 0.7 else 0
		big.Position = UDim2.new(0.5, rng:NextNumber(-6, 6) * (1 - k), 0.45, 0)
		gl.k = 0.5 * (1 - k) + (if rng:NextNumber() < 0.08 then 0.5 else 0)
		local wy = seg(k, 0.3, 1)
		wave.Position = UDim2.fromScale(0, lerp(-0.1, 1.1, wy))
		cc.Saturation = lerp(-0.85, -0.1, wy)
		cc.TintColor = WHITE:Lerp(green, lerp(0.35, 0.1, wy))
		cc.Contrast = lerp(0.35, 0.15, wy)
		tint.BackgroundTransparency = lerp(0.65, 1, wy)
		sphere.update(S:focusPos(), lerp(75, 40, inCubic(k)), 1.8 + e * 0.6, 1, lerp(0.15, 0.5, k))
		if math.floor(e * 4) ~= math.floor((e - 1 / 60) * 4) then
			S:sfx("Glitch", 0.3, 1.2)
		end
	end)
	big:Destroy()
	nf:Destroy()
	wave:Destroy()
	gl.k = 0
	-- Sphere collapses into the player.
	S:sfx("Whoosh", 0.8, 1.1)
	S:phase(0.5, function(k: number, e: number)
		sphere.update(S:focusPos() + Vector3.new(0, 1, 0), lerp(40, 1, inCubic(k)), 2.7 + e * 3, 1, lerp(0.5, 0.1, k))
	end)
	for _, sgm in sphere.segs do
		sgm.p.Transparency = 1
	end

	-- 4) The name.
	finale(S, green, function()
		for _, g in god do
			g.p.Transparency = 0.4
		end
	end)
end

return Scenes
