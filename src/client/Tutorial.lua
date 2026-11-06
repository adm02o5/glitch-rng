--!strict
-- First-time tutorial: a guided tour with HUD spotlights (the screen is dimmed around one element),
-- an action step that waits for the first roll, and cinematic camera zooms to every place on the map.
--
-- Tutorial.Auto() starts it ~2 s after data loads for players without Settings.Tut; Tutorial.Start()
-- replays it (SETTINGS). Skipping or finishing marks Settings.Tut = true. Everything it touches
-- (camera, HUD, controls, prompts, Ctx.Busy) is restored in one cleanup, even on error.
--
-- HUD elements are located by name/text at runtime and their rects are read every frame, so the tour
-- follows the HUD wherever the layout (desktop or mobile) puts it.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RNG = require(Shared:WaitForChild("RNG"))

local Kit = require(script.Parent.UI.Kit)
local Hud = require(script.Parent.UI.Hud)
local Ctx = require(script.Parent.Ctx)
local Sfx = require(script.Parent.Sfx)

local P = Kit.P
local new = Kit.new
local player = Players.LocalPlayer

local Tutorial = {}
Tutorial.Running = false
Tutorial.Step = 0 -- index of the step on screen (for tests)

local CAM_KEY = "GlitchTutorialCam"
local CANCEL = { "tutorial cancelled" } -- error sentinel thrown by every wait when the tour is skipped

---------------------------------------------------------------------------------------------------
-- Small math helpers
---------------------------------------------------------------------------------------------------

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function inOutCubic(t: number): number
	return if t < 0.5 then 4 * t * t * t else 1 - (-2 * t + 2) ^ 3 / 2
end

local function outCubic(t: number): number
	return 1 - (1 - t) ^ 3
end

local function inOutSine(t: number): number
	return -(math.cos(math.pi * t) - 1) / 2
end

local function bezier(a: Vector3, c: Vector3, b: Vector3, t: number): Vector3
	local u = 1 - t
	return a * (u * u) + c * (2 * u * t) + b * (t * t)
end

-- Frame-rate independent smoothing factor.
local function damp(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function paint(text: string, c: Color3): string
	return string.format('<font color="%s">%s</font>', hex(c), text)
end

local function bold(text: string, c: Color3): string
	return string.format('<b><font color="%s">%s</font></b>', hex(c), text)
end

---------------------------------------------------------------------------------------------------
-- Run state (reset by every Start)
---------------------------------------------------------------------------------------------------

type RectFn = () -> (Vector2?, Vector2?)

local cancelled = false
local ownBusy = false -- we hold Ctx.Busy so no roll can start in the middle of a step
local nextPressed = false
local typingSkip = false
local skipArmedAt = 0

local gui: ScreenGui? = nil
local renderConn: RBXScriptConnection? = nil
local inputConn: RBXScriptConnection? = nil

-- UI pieces (created in build()).
local dims: { TextButton } = {}
local outline: Frame
local outlineStroke: UIStroke
local scan: Frame
local brackets: { Frame } = {}
local lockLabel: TextLabel
local arrow: TextLabel
local arrowHint: TextLabel
local barTop: Frame
local barBottom: Frame
local fade: Frame
local cap: Frame
local capScale: UIScale
local capTag: TextLabel
local capTitle: TextLabel
local capLine: Frame
local capBody: TextLabel
local capButtons: Frame
local nextBtn: TextButton
local skipBtn: TextButton
local pips: { Frame } = {}
local titleHolder: Frame

-- Animated state, driven by the render loop.
local mode: "none" | "ui" | "world" = "none"
local rectFn: RectFn? = nil
local holePos = Vector2.zero
local holeSize = Vector2.zero
local holeKnown = false
local dimAlpha = 0 -- 0 = no dim, 1 = full dim
local dimWant = 0
local reticle = 0 -- brackets/outline visibility 0..1
local reticleWant = 0
local letterbox = 0
local letterboxWant = 0
local accent = P.Cyan
local arrowOn = false
local arrowColor = P.Cyan
local capOn = false
local capPop = 1
local capCenter: Vector2? = nil
local prefer: { string } = { "above", "below", "right", "left" }
local arrowSide = "above"

-- Camera flight.
type Flight = {
	p0: Vector3,
	pc: Vector3,
	p1: Vector3,
	f0: Vector3,
	f1: Vector3,
	fov0: number,
	fov1: number,
	t0: number,
	dur: number,
	drift: number,
	ease: (number) -> number,
}
local flight: Flight? = nil
local camOn = false
local lastPos = Vector3.zero
local lastFocus = Vector3.zero
local saved = { fov = 70, hud = true, prompts = true }

---------------------------------------------------------------------------------------------------
-- Waiting (every wait throws CANCEL when the tour is skipped)
---------------------------------------------------------------------------------------------------

local function check()
	if cancelled then
		error(CANCEL, 0)
	end
end

-- A roll or cutscene that is not ours is on screen: the tour hides and waits.
local function extBusy(): boolean
	return Ctx.Busy and not ownBusy
end

local function sleep(t: number)
	local left = t
	while left > 0 do
		local dt = task.wait()
		check()
		if not extBusy() then
			left -= dt
		end
	end
end

local function takeBusy()
	while extBusy() do
		task.wait()
		check()
	end
	Ctx.Busy = true
	ownBusy = true
end

local function releaseBusy()
	if ownBusy then
		ownBusy = false
		Ctx.Busy = false
	end
end

local function waitNext()
	nextPressed = false
	while not nextPressed do
		task.wait()
		check()
	end
	nextPressed = false
	Sfx.Play("Click", { volume = 0.5 })
end

---------------------------------------------------------------------------------------------------
-- Finding HUD elements at runtime
---------------------------------------------------------------------------------------------------

local function hudRoot(): Instance?
	return Kit.Gui:FindFirstChild("Hud")
end

local function shown(g: GuiObject): boolean
	if not g.Parent then
		return false
	end
	local cur: Instance? = g
	while cur and cur:IsA("GuiObject") do
		if not cur.Visible then
			return false
		end
		cur = cur.Parent
	end
	return g.AbsoluteSize.X > 2 and g.AbsoluteSize.Y > 2
end

local function byName(name: string): () -> GuiObject?
	local cache: GuiObject? = nil
	return function()
		if cache and cache:IsDescendantOf(Kit.Gui) then
			return cache
		end
		local root = hudRoot()
		local f = root and root:FindFirstChild(name, true)
		cache = if f and f:IsA("GuiObject") then f else nil
		return cache
	end
end

-- A button whose label starts with `prefix` (ROLL, AUTO, QUICK...).
local function buttonByText(prefix: string): () -> GuiObject?
	local cache: GuiObject? = nil
	return function()
		if cache and cache:IsDescendantOf(Kit.Gui) then
			return cache
		end
		cache = nil
		local root = hudRoot()
		if not root then
			return nil
		end
		for _, d in root:GetDescendants() do
			if d:IsA("TextButton") then
				local l = d:FindFirstChild("Label")
				if l and l:IsA("TextLabel") and l.Text:sub(1, #prefix) == prefix then
					cache = d
					break
				end
			end
		end
		return cache
	end
end

-- A text label whose text matches a pattern; returns the label (or its parent with `up`).
local function labelByText(pattern: string, up: boolean?): () -> GuiObject?
	local cache: GuiObject? = nil
	return function()
		if cache and cache:IsDescendantOf(Kit.Gui) then
			return cache
		end
		cache = nil
		local root = hudRoot()
		if not root then
			return nil
		end
		for _, d in root:GetDescendants() do
			if d:IsA("TextLabel") and d.Text:find(pattern) then
				local target = if up then d.Parent else d
				if target and target:IsA("GuiObject") then
					cache = target
				end
				break
			end
		end
		return cache
	end
end

local findRoll = function(): GuiObject?
	local b = Hud.RollButton
	if b and b:IsDescendantOf(Kit.Gui) then
		return b
	end
	return buttonByText("ROLL")()
end
local findAuto = buttonByText("AUTO")
local findQuick = buttonByText("QUICK")
local findMeter = labelByText("BOOT ROLL", true) -- "BOOT ROLL IN n" / "NEXT ROLL: BOOT ROLL" -> the meter frame
local findMenu = byName("Menu")
local findBiome = byName("Biome")
local findStats = byName("Stats")
local findBits = labelByText("BITS$")
local findRolls = labelByText("ROLLS$")

-- Union rect of every visible element the finders return.
local function rectOf(finders: { () -> GuiObject? }): RectFn
	return function()
		local lo: Vector2? = nil
		local hi: Vector2? = nil
		for _, f in finders do
			local g = f()
			if g and shown(g) then
				local a, b = g.AbsolutePosition, g.AbsolutePosition + g.AbsoluteSize
				lo = if lo then lo:Min(a) else a
				hi = if hi then hi:Max(b) else b
			end
		end
		if lo and hi then
			return lo, hi - lo
		end
		return nil, nil
	end
end

---------------------------------------------------------------------------------------------------
-- World targets
---------------------------------------------------------------------------------------------------

local function mapModel(name: string): Model?
	local map = workspace:FindFirstChild("Map")
	local m = map and map:FindFirstChild(name, true)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function rootPart(): BasePart?
	local ch = player.Character
	local r = ch and ch:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function headPos(): Vector3
	local ch = player.Character
	local h = ch and ch:FindFirstChild("Head")
	if h and h:IsA("BasePart") then
		return h.Position
	end
	local r = rootPart()
	return if r then r.Position + Vector3.new(0, 1.5, 0) else Vector3.new(0, 5, 0)
end

-- Pulls the camera in front of anything between it and the focus (the target itself is ignored).
local function unblock(pos: Vector3, focus: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(ignore)
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(list, plr.Character)
		end
	end
	params.FilterDescendantsInstances = list
	-- The first third of the ray is skipped: parts right around the subject (a screen that lives in
	-- another model, a counter) are part of the shot, not obstacles.
	local d = pos - focus
	local start = focus + d * 0.35
	local hit = workspace:Raycast(start, d * 0.65, params)
	if hit then
		local keep = math.max((hit.Position - focus).Magnitude - 1.5, d.Magnitude * 0.35)
		return focus + d.Unit * keep
	end
	return pos
end

-- Bounding box, with very tall models (the Core's sky beam) cut down to their lower, wide part.
local function trimmedBox(m: Model): (CFrame, Vector3)
	local cf, size = m:GetBoundingBox()
	local h = math.min(size.Y, math.max(size.X, size.Z) * 1.1)
	if h < size.Y then
		local c = cf.Position
		return CFrame.new(c.X, c.Y - size.Y / 2 + h / 2, c.Z), Vector3.new(size.X, h, size.Z)
	end
	return cf, size
end

-- A nice 3/4 shot of a model: camera on the plaza side, a little above, the whole box in frame.
local function frame(m: Model, fov: number, focusOverride: Vector3?, radiusOverride: number?): (Vector3, Vector3)
	local cf, size = trimmedBox(m)
	local c = cf.Position
	local flat = Vector3.new(-c.X, 0, -c.Z) -- toward the plaza centre
	if flat.Magnitude < 1 then
		local r = rootPart()
		flat = if r then Vector3.new(r.Position.X - c.X, 0, r.Position.Z - c.Z) else Vector3.new(0, 0, 1)
		if flat.Magnitude < 1 then
			flat = Vector3.new(0, 0, 1)
		end
	end
	local dir = CFrame.Angles(0, math.rad(24), 0):VectorToWorldSpace(flat.Unit)
	local radius = radiusOverride or math.max(size.X, size.Z, size.Y * 1.2) * 0.5
	local vp = workspace.CurrentCamera.ViewportSize
	local aspect = if vp.Y > 0 then vp.X / vp.Y else 16 / 9
	local dist = radius / math.tan(math.rad(fov) / 2) * 1.25
	dist *= math.max(1, 1.5 / aspect) -- narrow / portrait screens need to back off
	dist = math.clamp(dist, 14, 140)
	-- Aim a little below the centre so the subject sits above the caption and letterbox.
	local focus = focusOverride or (c + Vector3.new(0, -size.Y * 0.2, 0))
	local pos = focus + dir * dist + Vector3.new(0, math.clamp(size.Y * 0.3, 5, 26), 0)
	return unblock(pos, focus, { m }), focus
end

-- Screen rect of a model's bounding box (for the target-lock brackets).
local function modelRect(m: Model): RectFn
	return function()
		if not m.Parent then
			return nil, nil
		end
		local cam = workspace.CurrentCamera
		local cf, size = trimmedBox(m)
		local h = size / 2
		local lo: Vector2? = nil
		local hi: Vector2? = nil
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local w = cf:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
					local v = cam:WorldToViewportPoint(w)
					if v.Z <= 0 then
						return nil, nil
					end
					local p = Vector2.new(v.X, v.Y)
					lo = if lo then lo:Min(p) else p
					hi = if hi then hi:Max(p) else p
				end
			end
		end
		if not (lo and hi) then
			return nil, nil
		end
		-- The box corners overshoot the silhouette: tighten around the centre and cap the size.
		local vp = cam.ViewportSize
		local mid = (lo + hi) / 2
		local half = ((hi - lo) / 2 * 0.72):Min(vp * 0.3)
		local a = (mid - half):Max(Vector2.new(24, 24))
		local b = (mid + half):Min(vp - Vector2.new(24, 24))
		if b.X - a.X < 20 or b.Y - a.Y < 20 then
			return nil, nil
		end
		return a, b - a
	end
end

---------------------------------------------------------------------------------------------------
-- Camera
---------------------------------------------------------------------------------------------------

local function camStep()
	if not camOn or extBusy() then
		return
	end
	local fl = flight
	if not fl then
		return
	end
	local cam = workspace.CurrentCamera
	local now = os.clock()
	local e = clamp01((now - fl.t0) / fl.dur)
	local b = fl.ease(e)
	local pos = bezier(fl.p0, fl.pc, fl.p1, b)
	local focus = fl.f0:Lerp(fl.f1, outCubic(e)) -- the eye turns first, then the body follows
	if fl.drift ~= 0 then
		-- slow orbit so a held shot never looks frozen
		local ang = (now - fl.t0) * fl.drift * b
		pos = focus + CFrame.Angles(0, ang, 0):VectorToWorldSpace(pos - focus)
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(pos, focus)
	cam.FieldOfView = lerp(fl.fov0, fl.fov1, b)
	lastPos, lastFocus = pos, focus
end

local function takeCamera()
	local cam = workspace.CurrentCamera
	if not camOn then
		lastPos = cam.CFrame.Position
		lastFocus = cam.CFrame.Position + cam.CFrame.LookVector * 14
		camOn = true
		cam.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep(CAM_KEY, Enum.RenderPriority.Camera.Value + 2, camStep)
	end
end

local function restoreCamera()
	if camOn then
		camOn = false
		pcall(function()
			RunService:UnbindFromRenderStep(CAM_KEY)
		end)
	end
	flight = nil
	pcall(function()
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Custom
		local ch = player.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
		cam.FieldOfView = saved.fov
	end)
end

type FlyOpts = { dur: number?, fov: number?, drift: number?, arc: number?, ease: ((number) -> number)?, wait: boolean? }

-- Flies from wherever the camera is to (pos, focus) along an arc; waits for arrival unless wait=false.
local function fly(pos: Vector3, focus: Vector3, o: FlyOpts?)
	local opts: FlyOpts = o or {}
	takeCamera()
	local cam = workspace.CurrentCamera
	local dist = (pos - lastPos).Magnitude
	local dur = opts.dur or math.clamp(1.2 + dist / 260, 1.2, 1.8)
	local arc = opts.arc or math.clamp(dist * 0.18, 0, 36)
	local mid = (lastPos + pos) / 2 + Vector3.new(0, arc, 0)
	flight = {
		p0 = lastPos,
		pc = mid,
		p1 = pos,
		f0 = lastFocus,
		f1 = focus,
		fov0 = cam.FieldOfView,
		fov1 = opts.fov or 62,
		t0 = os.clock(),
		dur = dur,
		drift = opts.drift or 0.03,
		ease = opts.ease or inOutCubic,
	}
	if dist > 6 then
		Sfx.Play("Whoosh", { volume = 0.45, pitch = 0.9 + math.random() * 0.2 })
	end
	if opts.wait ~= false then
		sleep(dur)
	end
end

-- Camera spot right behind the player, close to where the default camera sits.
local function behindPlayer(): (Vector3, Vector3)
	local r = rootPart()
	if not r then
		return lastPos, lastFocus
	end
	local f = headPos() + Vector3.new(0, 0.6, 0)
	local p = r.CFrame:PointToWorldSpace(Vector3.new(0, 4.5, 13))
	return unblock(p, f, {}), f
end

-- Close-up of the player's face (and the aura tag above it).
local function facePlayer(dist: number, up: number): (Vector3, Vector3)
	local r = rootPart()
	if not r then
		return lastPos, lastFocus
	end
	-- The focus sits below the head so the face lands in the upper half, clear of the caption.
	local f = headPos() + Vector3.new(0, up - 1.4, 0)
	local p = r.Position + r.CFrame.LookVector * dist + r.CFrame.RightVector * (dist * 0.12) + Vector3.new(0, 1.8 + up * 0.5, 0)
	return unblock(p, f, {}), f
end

-- Black glitch cut: hides camera snaps when control goes back to the default camera.
local function cut(fn: () -> ())
	Kit.tween(fade, 0.18, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
	task.wait(0.2)
	fn()
	task.wait(0.08)
	Kit.tween(fade, 0.35, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
end

---------------------------------------------------------------------------------------------------
-- Building the overlay
---------------------------------------------------------------------------------------------------

local function sizes()
	local m = Kit.IsMobile()
	return {
		mobile = m,
		w = if m then 600 else 480,
		title = if m then 28 else 22,
		body = if m then 22 else 16,
		tag = if m then 15 else 11,
		btnH = if m then 70 else 44,
		nextW = if m then 200 else 140,
		skipW = if m then 150 else 100,
	}
end

local function uiK(): number
	return Kit.Scale.Scale
end

local function build()
	local g = new("ScreenGui", {
		Name = "GlitchTutorial",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 55, -- above the HUD and toasts, below roll cutscenes
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	gui = g

	-- Four dark panes around the hole. Buttons, so clicks outside the highlight are swallowed.
	dims = {}
	for i = 1, 4 do
		dims[i] = new("TextButton", {
			Name = "Dim",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(2, 3, 8),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 1,
			Parent = g,
		})
	end

	outline = new("Frame", {
		Name = "Outline",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = g,
	})
	Kit.corner(outline, 4)
	outlineStroke = Kit.stroke(outline, P.Cyan, 2, 0.3)
	scan = new("Frame", {
		Name = "Scan",
		BorderSizePixel = 0,
		BackgroundColor3 = P.Cyan,
		BackgroundTransparency = 0.6,
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 3,
		Parent = outline,
	})
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = scan,
	})

	brackets = {}
	for i = 1, 8 do
		brackets[i] = new("Frame", {
			Name = "Bracket",
			BorderSizePixel = 0,
			BackgroundColor3 = P.Cyan,
			ZIndex = 4,
			Parent = g,
		})
	end

	lockLabel = Kit.label(g, "", 12, {
		Name = "Lock",
		FontFace = Kit.MonoBold,
		TextColor3 = P.Cyan,
		Size = UDim2.fromOffset(420, 16),
		ZIndex = 4,
	})
	new("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.3, Parent = lockLabel })

	arrow = Kit.label(g, "▼", 34, {
		Name = "Arrow",
		FontFace = Kit.MonoBold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(48, 48),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 4,
		Visible = false,
	})
	new("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.2, Parent = arrow })
	arrowHint = Kit.label(g, "", 14, {
		Name = "ArrowHint",
		FontFace = Kit.MonoBold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(240, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Visible = false,
	})
	new("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.2, Parent = arrowHint })

	-- Cinematic bars for world shots.
	barTop = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 6, Parent = g })
	barBottom = new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 6,
		Parent = g,
	})
	for _, b in { barTop, barBottom } do
		new("Frame", {
			Name = "Edge",
			BackgroundColor3 = P.Cyan,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, if b == barTop then 0 else 1),
			Position = UDim2.fromScale(0, if b == barTop then 1 else 0),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 6,
			Parent = b,
		})
	end

	-- Intro title.
	titleHolder = new("Frame", {
		Name = "Title",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(1000, 200),
		ZIndex = 7,
		Visible = false,
		Parent = g,
	})
	new("UIScale", { Name = "K", Parent = titleHolder })

	-- Caption panel.
	local s = sizes()
	cap = Kit.panel(g, {
		Name = "Caption",
		Size = UDim2.fromOffset(s.w, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.04,
		ZIndex = 10,
		Visible = false,
	})
	capScale = new("UIScale", { Parent = cap })
	local body = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 10,
		Parent = cap,
	})
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
		Parent = body,
	})
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	capTag = Kit.label(body, "", s.tag, { Name = "Tag", TextColor3 = P.Dim, FontFace = Kit.MonoBold, LayoutOrder = 1, ZIndex = 11 })
	-- The title sits in its own frame: Kit.glitch adds sibling copies, which must not join the list layout.
	local titleBox = new("Frame", {
		Name = "TitleBox",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, s.title + 8),
		LayoutOrder = 2,
		ZIndex = 11,
		Parent = body,
	})
	capTitle = Kit.label(titleBox, "", s.title, {
		Name = "Title",
		FontFace = Kit.Title,
		Size = UDim2.fromScale(1, 1),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 12,
	})
	capLine = new("Frame", {
		Name = "Line",
		BorderSizePixel = 0,
		BackgroundColor3 = P.Cyan,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 3,
		ZIndex = 11,
		Parent = body,
	})
	new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = capLine })
	capBody = Kit.label(body, "", s.body, {
		Name = "Body",
		RichText = true,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.12,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, s.body + 4),
		LayoutOrder = 4,
		ZIndex = 11,
	})
	capButtons = new("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, s.btnH + 6),
		LayoutOrder = 5,
		ZIndex = 11,
		Parent = body,
	})
	skipBtn = Kit.button({
		text = "SKIP",
		size = UDim2.fromOffset(s.skipW, s.btnH),
		position = UDim2.new(0, 0, 1, 0),
		anchor = Vector2.new(0, 1),
		color = P.Dim,
		textSize = if s.mobile then 20 else 13,
		parent = capButtons,
		z = 12,
	}, function()
		-- Two presses: the first arms it, so a stray tap doesn't throw the whole tour away.
		if os.clock() - skipArmedAt < 2.5 then
			cancelled = true
		else
			skipArmedAt = os.clock()
			Kit.setButtonText(skipBtn, "SURE?")
			task.delay(2.5, function()
				if skipBtn.Parent and os.clock() - skipArmedAt >= 2.4 then
					Kit.setButtonText(skipBtn, "SKIP")
				end
			end)
		end
	end)
	nextBtn = Kit.button({
		text = "NEXT  ▶",
		size = UDim2.fromOffset(s.nextW, s.btnH),
		position = UDim2.new(1, 0, 1, 0),
		anchor = Vector2.new(1, 1),
		color = P.Cyan,
		textSize = if s.mobile then 22 else 15,
		sound = "Hover",
		parent = capButtons,
		z = 12,
	}, function()
		if capBody.MaxVisibleGraphemes ~= -1 then
			typingSkip = true -- first press finishes the line
		else
			nextPressed = true
		end
	end)
	local pipRow = new("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, (s.skipW - s.nextW) / 2, 0.5, 3),
		Size = UDim2.new(1, -(s.skipW + s.nextW + 20), 0, 8),
		ZIndex = 11,
		Parent = capButtons,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
		Parent = pipRow,
	})
	pips = {}

	fade = new("Frame", {
		Name = "Fade",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = g,
	})
end

local function setPips(count: number, cur: number)
	local row = capButtons:FindFirstChild("Pips")
	if not (row and row:IsA("Frame")) then
		return
	end
	local mobile = Kit.IsMobile()
	local w = math.clamp(math.floor((row.AbsoluteSize.X / math.max(capScale.Scale, 0.01)) / count) - 3, 4, if mobile then 12 else 9)
	while #pips < count do
		local p = new("Frame", { BorderSizePixel = 0, ZIndex = 12, Parent = row })
		Kit.corner(p, 1)
		table.insert(pips, p)
	end
	for i, p in pips do
		p.Visible = i <= count
		p.LayoutOrder = i
		local on = i == cur
		p.Size = UDim2.fromOffset(if on then w * 2 else w, if mobile then 8 else 6)
		p.BackgroundColor3 = if i < cur then accent:Lerp(P.Line, 0.45) elseif on then accent else P.Line
	end
end

---------------------------------------------------------------------------------------------------
-- Render loop: hole, dims, brackets, arrow, caption placement, letterbox
---------------------------------------------------------------------------------------------------

-- Where the caption goes next to a highlighted rect; returns its centre and the side used.
local function placeCaption(hp: Vector2, hs: Vector2, cs: Vector2, scr: Vector2, gap: number): (Vector2, string)
	local m = 16
	local space: { [string]: number } = {
		above = hp.Y - gap - m,
		below = scr.Y - (hp.Y + hs.Y) - gap - m,
		left = hp.X - gap - m,
		right = scr.X - (hp.X + hs.X) - gap - m,
	}
	local function fits(side: string): boolean
		if side == "above" or side == "below" then
			return space[side] >= cs.Y
		end
		return space[side] >= cs.X
	end
	local side: string? = nil
	for _, sd in prefer do
		if fits(sd) then
			side = sd
			break
		end
	end
	if not side then
		local best, bestK = "above", -math.huge
		for _, sd in { "above", "below", "left", "right" } do
			local k = if sd == "above" or sd == "below" then space[sd] / cs.Y else space[sd] / cs.X
			if k > bestK then
				best, bestK = sd, k
			end
		end
		side = best
	end
	local cx, cy = hp.X + hs.X / 2, hp.Y + hs.Y / 2
	if side == "above" then
		cy = hp.Y - gap - cs.Y / 2
	elseif side == "below" then
		cy = hp.Y + hs.Y + gap + cs.Y / 2
	elseif side == "left" then
		cx = hp.X - gap - cs.X / 2
	else
		cx = hp.X + hs.X + gap + cs.X / 2
	end
	cx = math.clamp(cx, m + cs.X / 2, math.max(m + cs.X / 2, scr.X - m - cs.X / 2))
	cy = math.clamp(cy, m + cs.Y / 2, math.max(m + cs.Y / 2, scr.Y - m - cs.Y / 2))
	return Vector2.new(cx, cy), side :: string
end

local function render(dt: number)
	local g = gui
	if not g then
		return
	end
	-- Someone else's roll or cutscene: get out of the way completely.
	g.Enabled = not extBusy()
	if not g.Enabled then
		return
	end
	local scr = g.AbsoluteSize
	local now = os.clock()
	local k = uiK()

	-- Hole target.
	local tp: Vector2?, ts: Vector2? = nil, nil
	if rectFn then
		local ok, a, b = pcall(rectFn)
		if ok then
			tp, ts = a, b
		end
	end
	local pad = if mode == "ui" then 8 else 0
	if tp and ts then
		if mode == "ui" then
			-- GUI rects are reported below the top-bar inset; this layer's offsets start at the very top.
			tp -= fade.AbsolutePosition
		end
		tp -= Vector2.new(pad, pad)
		ts += Vector2.new(pad * 2, pad * 2)
		if not holeKnown then
			-- First sighting: start from a big frame around it, then close in (a "zoom" onto the element).
			holePos = tp - Vector2.new(120, 80)
			holeSize = ts + Vector2.new(240, 160)
			holeKnown = true
		end
		local a = damp(11, dt)
		holePos = holePos:Lerp(tp, a)
		holeSize = holeSize:Lerp(ts, a)
	end
	local hasHole = holeKnown and tp ~= nil

	-- Dim panes.
	dimAlpha = lerp(dimAlpha, dimWant, damp(8, dt))
	local tr = 1 - 0.68 * dimAlpha
	if hasHole or mode == "ui" then
		local x0, y0 = holePos.X, holePos.Y
		local x1, y1 = holePos.X + holeSize.X, holePos.Y + holeSize.Y
		if not hasHole then
			x0, y0, x1, y1 = scr.X / 2, scr.Y / 2, scr.X / 2, scr.Y / 2
		end
		local r = {
			{ 0, 0, scr.X, y0 },
			{ 0, y1, scr.X, scr.Y - y1 },
			{ 0, y0, x0, y1 - y0 },
			{ x1, y0, scr.X - x1, y1 - y0 },
		}
		for i, d in dims do
			local q = r[i]
			d.Position = UDim2.fromOffset(q[1], q[2])
			d.Size = UDim2.fromOffset(math.max(q[3], 0), math.max(q[4], 0))
			d.BackgroundTransparency = tr
			d.Visible = dimAlpha > 0.01
		end
	else
		for i, d in dims do
			d.Position = UDim2.fromOffset(0, if i == 1 then 0 else scr.Y)
			d.Size = if i == 1 then UDim2.fromOffset(scr.X, scr.Y) else UDim2.fromOffset(0, 0)
			d.BackgroundTransparency = tr
			d.Visible = dimAlpha > 0.01
		end
	end

	-- Outline, scanline and pulsing brackets.
	reticle = lerp(reticle, if hasHole then reticleWant else 0, damp(10, dt))
	local vis = reticle > 0.02
	outline.Visible = vis
	lockLabel.Visible = vis and lockLabel.Text ~= ""
	for _, b in brackets do
		b.Visible = vis
	end
	if vis then
		outline.Position = UDim2.fromOffset(holePos.X, holePos.Y)
		outline.Size = UDim2.fromOffset(holeSize.X, holeSize.Y)
		outlineStroke.Color = accent
		outlineStroke.Transparency = 1 - reticle * (0.55 + 0.25 * math.sin(now * 5))
		scan.BackgroundColor3 = accent
		scan.Position = UDim2.fromScale(0, (now * 0.6) % 1)
		scan.BackgroundTransparency = 1 - reticle * 0.45
		local pulse = 5 + (math.sin(now * 4.2) + 1) * 4
		local L = math.clamp(math.min(holeSize.X, holeSize.Y) * 0.3, 10, 26)
		local th = 3
		local a = holePos - Vector2.new(pulse, pulse)
		local b = holePos + holeSize + Vector2.new(pulse, pulse)
		local corners = { Vector2.new(a.X, a.Y), Vector2.new(b.X, a.Y), Vector2.new(a.X, b.Y), Vector2.new(b.X, b.Y) }
		for i, c in corners do
			local sx = if i % 2 == 1 then 0 else 1
			local sy = if i <= 2 then 0 else 1
			local h = brackets[i * 2 - 1]
			local v = brackets[i * 2]
			h.AnchorPoint = Vector2.new(sx, sy)
			v.AnchorPoint = Vector2.new(sx, sy)
			h.Position = UDim2.fromOffset(c.X, c.Y)
			v.Position = UDim2.fromOffset(c.X, c.Y)
			h.Size = UDim2.fromOffset(L, th)
			v.Size = UDim2.fromOffset(th, L)
			h.BackgroundColor3 = accent
			v.BackgroundColor3 = accent
			h.BackgroundTransparency = 1 - reticle
			v.BackgroundTransparency = 1 - reticle
		end
		lockLabel.TextSize = math.max(math.floor(12 * math.max(k, 0.8)), 10)
		lockLabel.Size = UDim2.fromOffset(420, lockLabel.TextSize + 4)
		lockLabel.TextColor3 = accent
		lockLabel.TextTransparency = 1 - reticle
		local ly = a.Y - lockLabel.TextSize - 8
		if ly < 6 then
			ly = b.Y + 6
		end
		lockLabel.Position = UDim2.fromOffset(math.clamp(a.X, 6, math.max(6, scr.X - 200)), ly)
	end

	-- Letterbox.
	letterbox = lerp(letterbox, letterboxWant, damp(7, dt))
	local barH = math.floor(scr.Y * 0.085 * letterbox + 0.5)
	barTop.Size = UDim2.fromOffset(scr.X, barH)
	barBottom.Position = UDim2.fromOffset(0, scr.Y)
	barBottom.Size = UDim2.fromOffset(scr.X, barH)
	barTop.Visible = barH > 0
	barBottom.Visible = barH > 0

	-- Caption.
	capPop = lerp(capPop, 1, damp(14, dt))
	capScale.Scale = k * capPop
	cap.Visible = capOn
	local cs = cap.AbsoluteSize / math.max(capPop, 0.01)
	local want: Vector2
	local side = "none"
	local gap = 30 * math.max(k, 0.75)
	if mode == "ui" and hasHole then
		want, side = placeCaption(holePos, holeSize, cs, scr, gap + (if arrowOn then 26 * k else 0))
	elseif mode == "world" then
		want = Vector2.new(scr.X / 2, scr.Y - barH - 14 - cs.Y / 2)
		if want.Y - cs.Y / 2 < 12 then
			want = Vector2.new(scr.X / 2, scr.Y / 2)
		end
	else
		want = Vector2.new(scr.X / 2, math.max(scr.Y * 0.72, cs.Y / 2 + 16))
		want = Vector2.new(want.X, math.min(want.Y, scr.Y - 16 - cs.Y / 2))
	end
	local prev = capCenter
	local cc: Vector2 = if prev and cap.Visible then prev:Lerp(want, damp(12, dt)) else want
	capCenter = cc
	local rs = cap.AbsoluteSize
	cap.Position = UDim2.fromOffset(math.floor(cc.X - rs.X / 2 + 0.5), math.floor(cc.Y - rs.Y / 2 + 0.5))

	-- Arrow on the caption side of the hole, pointing at it.
	if side ~= "none" then
		arrowSide = side
	end
	local showArrow = arrowOn and hasHole and mode == "ui" and capOn
	arrow.Visible = showArrow
	arrowHint.Visible = showArrow and arrowHint.Text ~= ""
	if showArrow then
		local bob = (math.sin(now * 6) + 1) * 5 * math.max(k, 0.7)
		local off = 22 * math.max(k, 0.7) + bob
		local c = holePos + holeSize / 2
		local pos, rot = c, 0
		if arrowSide == "above" then
			pos, rot = Vector2.new(c.X, holePos.Y - off), 0
		elseif arrowSide == "below" then
			pos, rot = Vector2.new(c.X, holePos.Y + holeSize.Y + off), 180
		elseif arrowSide == "left" then
			pos, rot = Vector2.new(holePos.X - off, c.Y), -90
		else
			pos, rot = Vector2.new(holePos.X + holeSize.X + off, c.Y), 90
		end
		arrow.Position = UDim2.fromOffset(pos.X, pos.Y)
		arrow.Rotation = rot
		arrow.TextSize = math.floor(34 * math.max(k, 0.75))
		arrow.TextColor3 = arrowColor
		arrow.TextTransparency = 0.1 + 0.25 * (math.sin(now * 6) + 1) / 2
		arrowHint.TextSize = math.floor(14 * math.max(k, 0.8))
		arrowHint.TextColor3 = arrowColor
		local hintOff = if arrowSide == "above"
			then Vector2.new(0, -28 * math.max(k, 0.75))
			elseif arrowSide == "below" then Vector2.new(0, 28 * math.max(k, 0.75))
			elseif arrowSide == "left" then Vector2.new(-80, -24)
			else Vector2.new(80, -24)
		arrowHint.Position = UDim2.fromOffset(pos.X + hintOff.X, pos.Y + hintOff.Y)
	end

	-- Intro title follows the UI scale.
	local tk = titleHolder:FindFirstChild("K")
	if tk and tk:IsA("UIScale") then
		tk.Scale = math.max(k, 0.55)
	end
end

---------------------------------------------------------------------------------------------------
-- Caption
---------------------------------------------------------------------------------------------------

local TOTAL = 0 -- filled once the step list is built

local function applySizes()
	local s = sizes()
	cap.Size = UDim2.fromOffset(s.w, 0)
	capTag.TextSize = s.tag
	capTag.Size = UDim2.new(1, 0, 0, s.tag + 4)
	capTitle.TextSize = s.title
	local tb = capTitle.Parent :: Frame
	tb.Size = UDim2.new(1, 0, 0, s.title + 8)
	capBody.TextSize = s.body
	capButtons.Size = UDim2.new(1, 0, 0, s.btnH + 6)
	skipBtn.Size = UDim2.fromOffset(s.skipW, s.btnH)
	nextBtn.Size = UDim2.fromOffset(s.nextW, s.btnH)
	for _, b in { skipBtn, nextBtn } do
		local l = b:FindFirstChild("Label")
		if l and l:IsA("TextLabel") then
			l.TextSize = if s.mobile then (if b == nextBtn then 22 else 20) else (if b == nextBtn then 15 else 13)
		end
	end
	local row = capButtons:FindFirstChild("Pips")
	if row and row:IsA("Frame") then
		row.Position = UDim2.new(0.5, (s.skipW - s.nextW) / 2, 0.5, 3)
		row.Size = UDim2.new(1, -(s.skipW + s.nextW + 20), 0, 8)
	end
end

type SayOpts = { next: boolean?, nextText: string?, sound: string? }

-- Shows the caption and types the text; returns once the text is fully on screen.
local function say(step: number, tag: string, title: string, text: string, col: Color3, o: SayOpts?)
	local opts: SayOpts = o or {}
	applySizes()
	accent = col
	local wasOn = capOn
	capOn = true
	capTag.Text = string.format("// TUTORIAL  %02d / %02d   ·   %s", step, TOTAL, tag)
	capTitle.Text = title
	capTitle.TextColor3 = col
	capLine.BackgroundColor3 = col
	for _, br in cap:GetChildren() do
		if br.Name == "Bracket" and br:IsA("Frame") then
			br.BackgroundColor3 = col
		end
	end
	local st = nextBtn:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = col
	end
	local fill = nextBtn:FindFirstChild("Fill")
	if fill and fill:IsA("Frame") then
		fill.BackgroundColor3 = col
	end
	nextBtn.Visible = opts.next ~= false
	Kit.setButtonText(nextBtn, opts.nextText or "NEXT  ▶")
	setPips(TOTAL, step)
	if not wasOn then
		capPop = 0.85
	else
		capPop = 0.97
	end
	Sfx.Play(opts.sound or "Open", { volume = 0.4 })
	Kit.glitch(capTitle, 0.3)

	-- Typewriter (NEXT during typing completes the text instead of advancing).
	capBody.Text = text
	local plain = text:gsub("<[^>]+>", "")
	local n = utf8.len(plain) or #plain
	typingSkip = false
	capBody.MaxVisibleGraphemes = 0
	local shownN = 0
	local acc = 0
	local cps = 62
	while shownN < n do
		local dt = task.wait()
		check()
		if typingSkip then
			break
		end
		if not extBusy() then
			acc += dt * cps
			local add = math.floor(acc)
			if add > 0 then
				acc -= add
				local before = shownN
				shownN = math.min(n, shownN + add)
				capBody.MaxVisibleGraphemes = shownN
				if math.floor(before / 4) ~= math.floor(shownN / 4) then
					Sfx.Play("Type", { volume = 0.18, pitch = 0.95 + math.random() * 0.15 })
				end
			end
		end
	end
	capBody.MaxVisibleGraphemes = -1
	typingSkip = false
	nextPressed = false
end

local function hideCaption()
	capOn = false
	arrowOn = false
	capCenter = nil
end

---------------------------------------------------------------------------------------------------
-- Step kinds
---------------------------------------------------------------------------------------------------

-- Moves the overlay into HUD-spotlight mode (camera back on the player, HUD visible).
local function enterUi()
	if mode ~= "ui" then
		if camOn then
			local p, f = behindPlayer()
			fly(p, f, { dur = 1.1, fov = saved.fov, drift = 0, arc = 2 })
			cut(function()
				restoreCamera()
				Kit.Gui.Enabled = true
				letterboxWant = 0
			end)
		end
		Kit.Gui.Enabled = true
		letterboxWant = 0
		mode = "ui"
		dimWant = 1
	end
end

local function enterWorld()
	if mode ~= "world" then
		hideCaption()
		mode = "world"
		dimWant = 0
		rectFn = nil
		holeKnown = false
		Kit.closeAll()
		Kit.Gui.Enabled = false
		letterboxWant = 1
	end
end

local function spotlight(fn: RectFn, side: { string }?)
	rectFn = fn
	holeKnown = false
	reticleWant = 1
	prefer = side or { "above", "below", "right", "left" }
end

type UiStep = {
	tag: string,
	title: string,
	text: string,
	accent: Color3,
	rect: RectFn,
	side: { string }?,
}

local function uiStep(n: number, s: UiStep)
	enterUi()
	local a, _ = s.rect()
	if not a then
		return -- element isn't on this layout: skip the step
	end
	Kit.closeAll()
	spotlight(s.rect, s.side)
	lockLabel.Text = "◢ " .. s.tag
	sleep(0.25)
	say(n, s.tag, s.title, s.text, s.accent)
	waitNext()
end

type WorldStep = {
	tag: string,
	title: string,
	text: string,
	accent: Color3,
	model: string,
	focus: ((Model) -> Vector3?)?,
	radius: number?,
	fov: number?,
	sound: string?,
}

local function worldStep(n: number, s: WorldStep)
	local m = mapModel(s.model)
	if not m then
		return
	end
	enterWorld()
	hideCaption()
	reticleWant = 0
	local fov = s.fov or 58
	local focusAt = if s.focus then s.focus(m) else nil
	local pos, focus = frame(m, fov, focusAt, s.radius)
	fly(pos, focus, { fov = fov, drift = 0.025 })
	rectFn = modelRect(m)
	holeKnown = false
	reticleWant = 1
	local cf = m:GetBoundingBox()
	lockLabel.Text = string.format("◢ TARGET LOCK // %s   [%d, %d]", s.tag, math.floor(cf.Position.X), math.floor(cf.Position.Z))
	say(n, s.tag, s.title, s.text, s.accent, { sound = s.sound })
	waitNext()
	reticleWant = 0
end

---------------------------------------------------------------------------------------------------
-- Intro title
---------------------------------------------------------------------------------------------------

local function showTitle(): () -> ()
	for _, c in titleHolder:GetChildren() do
		if not c:IsA("UIScale") then
			c:Destroy()
		end
	end
	titleHolder.Visible = true
	local top = Kit.label(titleHolder, "WELCOME TO", 22, {
		FontFace = Kit.MonoBold,
		TextColor3 = P.Dim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 26),
		TextTransparency = 1,
		ZIndex = 8,
	})
	local big = Kit.label(titleHolder, "GLITCH RNG", 92, {
		FontFace = Kit.Title,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 100),
		TextTransparency = 1,
		ZIndex = 9,
	})
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, P.Cyan),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, P.Magenta),
		}),
		Parent = big,
	})
	local bigStroke = new("UIStroke", { Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 1, Parent = big })
	local sub = Kit.label(titleHolder, "// SIGNAL ACQUIRED: " .. player.DisplayName:upper(), 16, {
		FontFace = Kit.MonoBold,
		TextColor3 = P.Cyan,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 156),
		Size = UDim2.new(1, 0, 0, 20),
		TextTransparency = 1,
		ZIndex = 8,
	})
	Kit.tween(top, 0.6, { TextTransparency = 0 })
	task.delay(0.35, function()
		Kit.tween(big, 0.5, { TextTransparency = 0 })
		Kit.tween(bigStroke, 0.5, { Transparency = 0.2 })
		if big.Parent then
			Kit.glitch(big, 0.7)
		end
		Sfx.Play("Whoosh", { volume = 0.5, pitch = 0.7 })
	end)
	task.delay(0.9, function()
		if sub.Parent then
			Kit.tween(sub, 0.4, { TextTransparency = 0 })
			Kit.type(sub, sub.Text, 45)
		end
	end)
	-- occasional glitch hits while it's up
	local alive = true
	task.spawn(function()
		while alive and big.Parent do
			task.wait(1.1 + math.random() * 0.9)
			if alive and big.Parent then
				Kit.glitch(big, 0.25)
			end
		end
	end)
	return function()
		alive = false
		for _, l in { top, big, sub } do
			Kit.tween(l, 0.4, { TextTransparency = 1 })
		end
		Kit.tween(bigStroke, 0.4, { Transparency = 1 })
		task.delay(0.45, function()
			titleHolder.Visible = false
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- The tour
---------------------------------------------------------------------------------------------------

local function biomeAuraCount(): number
	local n = 0
	for _, a in Config.Auras do
		if a.biome then
			n += 1
		end
	end
	return n
end

local function input(): string
	return if Kit.IsMobile() then "Tap" else "Click"
end

local function steps(): { (number) -> () }
	local list: { (number) -> () } = {}
	local mobile = Kit.IsMobile()
	local common = Config.Auras[1]
	local rarest = Config.Auras[1]
	for _, a in Config.Auras do
		if not a.biome and a.chance > rarest.chance then
			rarest = a
		end
	end
	local name = player.DisplayName:upper()

	-- 1. Flyover above the plaza, then down to the player.
	table.insert(list, function(n)
		mode = "world"
		Kit.closeAll()
		Kit.Gui.Enabled = false
		letterboxWant = 1
		takeCamera()
		-- start high over one corner, then glide across the skyline
		lastPos = Vector3.new(-120, 135, 150)
		lastFocus = Vector3.new(0, 8, -10)
		local cam = workspace.CurrentCamera
		cam.CFrame = CFrame.lookAt(lastPos, lastFocus)
		Kit.tween(fade, 0.8, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		fly(Vector3.new(110, 105, 120), Vector3.new(0, 6, -20), { dur = 7.5, fov = 64, arc = 25, drift = 0, ease = inOutSine, wait = false })
		local closeTitle = showTitle()
		sleep(3.2)
		closeTitle()
		sleep(0.5)
		say(n, "BOOT SEQUENCE", "WELCOME, " .. name,
			"This city runs on a broken random number generator. Every roll pulls an "
				.. bold("aura", P.Cyan) .. " out of the noise: some are common static, some show up "
				.. bold("once in a billion", P.Magenta) .. " rolls.",
			P.Cyan)
		waitNext()
		hideCaption()
		local p, f = facePlayer(9, 0.4)
		fly(p, f, { dur = 1.8, fov = 50, drift = 0.02, arc = 30 })
		say(n, "OPERATOR", "THIS IS YOU",
			"Right now you're running on nothing but default code. Let's change that: "
				.. "a quick tour of the system, then the noise is all yours.",
			P.Lime)
		waitNext()
		hideCaption()
	end)

	-- 2. ROLL + odds.
	table.insert(list, function(n)
		uiStep(n, {
			tag = "ROLL",
			title = "THE ROLL",
			accent = P.Cyan,
			rect = rectOf({ findRoll }),
			side = { "above", "right", "left", "below" },
			text = "Each roll pulls one random aura. Odds are written as " .. bold("1 in N", P.Cyan) .. ": "
				.. paint(common.name, common.color) .. " is 1 in " .. RNG.Commas(common.chance) .. ", while "
				.. paint(rarest.name, Config.TierOf(rarest.chance).color) .. " is 1 in " .. RNG.Commas(rarest.chance)
				.. ". Rarer auras play a cutscene when they land.",
		})
	end)

	-- 3. Action: roll once.
	table.insert(list, function(n)
		enterUi()
		local rect = rectOf({ findRoll })
		if not rect() then
			return
		end
		Kit.closeAll()
		spotlight(rect, { "above", "right", "left", "below" })
		lockLabel.Text = "◢ ROLL"
		arrowOn = true
		arrowColor = P.Lime
		arrowHint.Text = if mobile then "TAP" else "CLICK  /  [ R ]"
		local before = tonumber(Ctx.Data.Rolls) or 0
		say(n, "YOUR TURN", "ROLL ONCE",
			if mobile then "Go on. " .. bold("Tap ROLL", P.Lime) .. " and see what the system gives you."
			else "Go on. " .. bold("Press ROLL", P.Lime) .. " or hit " .. bold("[R]", P.Lime) .. " and see what the system gives you.",
			P.Lime, { next = false })
		-- Let the roll through: drop our hold on Ctx.Busy until the roll has fully played out.
		releaseBusy()
		while (tonumber(Ctx.Data.Rolls) or 0) <= before or Ctx.Busy do
			task.wait()
			check()
		end
		takeBusy()
		arrowOn = false
		Sfx.Play("QuestDone", { volume = 0.5 })
		say(n, "YOUR TURN", "SIGNAL RECEIVED",
			"That's the loop. Every aura you roll is saved to your storage forever, and every roll also pays out a few "
				.. bold(Config.Currency, P.Lime) .. ". Rarer pulls pay more.",
			P.Lime)
		waitNext()
	end)

	-- 4. Boot roll meter.
	table.insert(list, function(n)
		uiStep(n, {
			tag = "BOOT ROLL",
			title = "BOOT ROLL",
			accent = P.Magenta,
			rect = rectOf({ findMeter }),
			text = "These pips fill up as you roll. Every " .. bold(tostring(Config.Roll.BonusEvery) .. "th", P.Magenta)
				.. " roll is a " .. bold("BOOT ROLL", P.Magenta) .. " with " .. bold("x" .. tostring(Config.Roll.BonusLuck) .. " luck", P.Magenta)
				.. ". The label lights up right before one hits.",
		})
	end)

	-- 5. QUICK.
	table.insert(list, function(n)
		uiStep(n, {
			tag = "QUICK",
			title = "QUICK ROLL",
			accent = P.Amber,
			rect = rectOf({ findQuick }),
			side = { "above", "left", "right", "below" },
			text = bold("QUICK", P.Amber) .. " skips the spinning reel for common results, so grinding goes faster. "
				.. "Anything rare still gets its full reveal.",
		})
	end)

	-- 6. AUTO.
	table.insert(list, function(n)
		uiStep(n, {
			tag = "AUTO",
			title = "AUTO ROLL",
			accent = P.Magenta,
			rect = rectOf({ findAuto }),
			side = { "above", "right", "left", "below" },
			text = bold("AUTO", P.Magenta) .. " keeps rolling for you, back to back, as fast as your roll speed allows. "
				.. input() .. " it again to stop.",
		})
	end)

	-- 7. Menu.
	table.insert(list, function(n)
		uiStep(n, {
			tag = "MENU",
			title = "YOUR MENUS",
			accent = P.Cyan,
			rect = rectOf({ findMenu }),
			side = { "right", "below", "above", "left" },
			text = bold("AURAS", P.Cyan) .. ": your storage. Equip one to wear it.\n"
				.. bold("INDEX", P.Magenta) .. ": every aura in the system, found or not.\n"
				.. bold("SCRIPTS", P.Lime) .. ": boosts you own. Run them for luck or speed.\n"
				.. bold("SETTINGS", P.Dim) .. ": volume, cutscene skipping, and this tour.",
		})
	end)

	-- 8. Biome.
	table.insert(list, function(n)
		local ids = {}
		for _, b in Config.Biomes do
			if b.id ~= "Normal" then
				table.insert(ids, paint(b.name, b.color))
			end
		end
		uiStep(n, {
			tag = "BIOME",
			title = "BIOMES",
			accent = P.Amber,
			rect = rectOf({ findBiome }),
			side = { "below", "left", "right", "above" },
			text = "Every so often the system scans for an event: " .. table.concat(ids, ", ")
				.. ". Biomes change luck and speed, and " .. bold(tostring(biomeAuraCount()) .. " auras", P.Amber)
				.. " can ONLY drop during their biome. Watch the timer.",
		})
	end)

	-- 9. Stats.
	table.insert(list, function(n)
		uiStep(n, {
			tag = "STATUS",
			title = "LUCK & SPEED",
			accent = P.Lime,
			rect = rectOf({ findStats }),
			side = { "above", "right", "below", "left" },
			text = bold("LUCK", P.Lime) .. " divides the odds: x2 luck turns 1 in 1,000 into 1 in 500. "
				.. bold("ROLL SPEED", P.Amber) .. " shortens the cooldown. Rigs, scripts and biomes stack on both, "
				.. "and running boosts count down here.",
		})
	end)

	-- 10. Bits + roll counter.
	table.insert(list, function(n)
		uiStep(n, {
			tag = Config.Currency,
			title = Config.Currency,
			accent = P.Lime,
			rect = rectOf({ findBits, findRolls }),
			side = { "below", "left", "above", "right" },
			text = bold(Config.Currency, P.Lime) .. " are the street currency. You earn them from rolls and from NULL's jobs, "
				.. "and spend them at his stall. Below: your lifetime roll count.",
		})
	end)

	-- 11-16. World tour.
	table.insert(list, function(n)
		worldStep(n, {
			tag = "RIG FORGE",
			title = "RIG FORGE",
			accent = P.Amber,
			model = "ForgeTerminal",
			text = "Melt down auras you own into " .. bold("RIGS", P.Amber)
				.. ": hand gear with permanent luck and speed. Better rigs need rarer auras. Walk up and use the terminal.",
		})
	end)
	table.insert(list, function(n)
		worldStep(n, {
			tag = "SCRIPT LAB",
			title = "SCRIPT LAB",
			accent = P.Lime,
			model = "LabTerminal",
			text = "Compile auras into " .. bold("SCRIPTS", P.Lime) .. ": one-shot boosts like "
				.. paint("luck.exe", P.Lime) .. " or " .. paint("breach.exe", P.Red)
				.. ". Run them from the SCRIPTS menu when you need an edge.",
		})
	end)
	table.insert(list, function(n)
		worldStep(n, {
			tag = "AURA INDEX",
			title = "AURA INDEX",
			accent = P.Magenta,
			model = "IndexTerminal",
			text = "The full catalogue: " .. bold(tostring(#Config.Auras) .. " auras", P.Magenta)
				.. ", their odds, and which biome hides them. Anything you haven't found yet stays redacted.",
		})
	end)
	table.insert(list, function(n)
		worldStep(n, {
			tag = "NULL",
			title = "NULL'S STALL",
			accent = P.Red,
			model = "ElliotStall",
			sound = "NpcTalk",
			fov = 50,
			focus = function(m: Model): Vector3?
				local e = m:FindFirstChild("Elliot", true)
				local head = e and e:FindFirstChild("Head", true)
				if head and head:IsA("BasePart") then
					local cf = m:GetBoundingBox()
					return cf.Position:Lerp(head.Position, 0.65)
				end
				return nil
			end,
			text = "A hacker who calls himself " .. bold("NULL", P.Red) .. ". He hands out " .. bold("jobs", P.Red)
				.. " that pay " .. Config.Currency .. " and scripts, and his market sells scripts for "
				.. Config.Currency .. ". Talk to him early.",
		})
	end)
	table.insert(list, function(n)
		worldStep(n, {
			tag = "TOP ROLLERS",
			title = "TOP ROLLERS",
			accent = P.Cyan,
			model = "LeaderboardWall",
			text = "The players with the most rolls, worldwide. Every roll you make counts toward a spot on this wall.",
		})
	end)
	table.insert(list, function(n)
		worldStep(n, {
			tag = "THE CORE",
			title = "THE CORE",
			accent = P.Magenta,
			model = "Core",
			-- The Core's box reaches up to its sky beam; frame the dais and the floating core instead.
			radius = 30,
			focus = function(m: Model): Vector3?
				local dais: BasePart? = nil
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") and (not dais or d.Size.X * d.Size.Z > dais.Size.X * dais.Size.Z) then
						dais = d
					end
				end
				return if dais then dais.Position + Vector3.new(0, 11, 0) else nil
			end,
			text = "The broken heart of the system. Every roll on the server passes through it, and when someone pulls "
				.. "something truly rare, the whole city hears about it.",
		})
	end)

	-- 17. Close-up of the player, aura tag and all.
	table.insert(list, function(n)
		enterWorld()
		local p, f = facePlayer(12, 0.9)
		fly(p, f, { fov = 48, drift = 0.03, arc = 40 })
		say(n, "END OF LINE", "GOOD LUCK, " .. name,
			"The system is yours: roll, collect, forge, and climb the wall. And if something "
				.. bold("REDACTED", P.Red) .. " ever finds you... don't blink.\n"
				.. paint("Replay this tour anytime from SETTINGS.", P.Dim),
			P.Cyan, { nextText = "FINISH  ✓", sound = "QuestDone" })
		waitNext()
		hideCaption()
		local bp, bf = behindPlayer()
		fly(bp, bf, { dur = 1.2, fov = saved.fov, drift = 0, arc = 3 })
	end)

	return list
end

---------------------------------------------------------------------------------------------------
-- Start / cleanup
---------------------------------------------------------------------------------------------------

local function controls(on: boolean)
	pcall(function()
		local ps = player:FindFirstChild("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		if pm and pm:IsA("ModuleScript") then
			local c = (require :: any)(pm):GetControls()
			if on then
				c:Enable()
			else
				c:Disable()
			end
		end
	end)
end

local function cleanup()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if inputConn then
		inputConn:Disconnect()
		inputConn = nil
	end
	restoreCamera()
	pcall(function()
		Kit.Gui.Enabled = saved.hud
	end)
	pcall(function()
		ProximityPromptService.Enabled = saved.prompts
	end)
	controls(true)
	releaseBusy()
	if gui then
		local g = gui
		gui = nil
		g:Destroy()
	end
	mode = "none"
	rectFn = nil
	capOn = false
	arrowOn = false
	Tutorial.Running = false
end

function Tutorial.Start()
	if Tutorial.Running then
		return
	end
	Tutorial.Running = true
	task.spawn(function()
		cancelled = false
		nextPressed = false
		skipArmedAt = 0
		mode = "none"
		rectFn = nil
		holeKnown = false
		dimAlpha, dimWant = 0, 0
		reticle, reticleWant = 0, 0
		letterbox, letterboxWant = 0, 0
		capOn, capCenter, arrowOn = false, nil, false

		local ok, err = pcall(function()
			-- Wait for any roll in progress, then hold Ctx.Busy so nothing rolls mid-step.
			takeBusy()
			if Hud.Auto then
				Hud.Auto = false
				Hud.OnAuto:Fire(false)
				if Hud.AutoButton then
					Kit.setButtonText(Hud.AutoButton, "AUTO: OFF")
					local st = Hud.AutoButton:FindFirstChildOfClass("UIStroke")
					if st then
						st.Thickness = 1.5
					end
				end
			end
			Kit.closeAll()
			saved.fov = workspace.CurrentCamera.FieldOfView
			saved.hud = true
			pcall(function()
				saved.prompts = ProximityPromptService.Enabled
				ProximityPromptService.Enabled = false
			end)
			controls(false)
			build()
			fade.BackgroundTransparency = 0
			renderConn = RunService.RenderStepped:Connect(render)
			inputConn = UserInputService.InputBegan:Connect(function(io, processed)
				if processed and io.UserInputType ~= Enum.UserInputType.Gamepad1 then
					return
				end
				local kc = io.KeyCode
				if kc == Enum.KeyCode.Return or kc == Enum.KeyCode.KeypadEnter or kc == Enum.KeyCode.ButtonA then
					if capOn and nextBtn.Visible then
						if capBody.MaxVisibleGraphemes ~= -1 then
							typingSkip = true
						else
							nextPressed = true
						end
					end
				end
			end)

			local list = steps()
			TOTAL = #list
			for i, fn in list do
				check()
				Tutorial.Step = i
				fn(i)
			end
		end)

		local skipped = not ok and err == CANCEL
		if not ok and not skipped then
			warn("[Tutorial] failed:", err)
		end
		-- Graceful exit: fade to black, give everything back, fade in.
		if gui then
			hideCaption()
			Kit.tween(fade, 0.25, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
			task.wait(0.27)
		end
		local wasShown = gui ~= nil
		cleanup()
		if wasShown then
			-- The overlay is gone; fade back in from black on a throwaway layer (hides the camera snap).
			local fg = new("ScreenGui", {
				Name = "GlitchTutorialFade",
				IgnoreGuiInset = true,
				DisplayOrder = 55,
				ResetOnSpawn = false,
				Parent = player:WaitForChild("PlayerGui"),
			})
			local f = new("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Parent = fg,
			})
			Kit.tween(f, 0.5, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
			task.delay(0.55, function()
				fg:Destroy()
			end)
		end
		Ctx.Setting("Tut", true)
		if skipped then
			Ctx.Toast("Tutorial skipped. Replay it from SETTINGS.", P.Dim)
		elseif ok then
			Ctx.Toast("<b>TUTORIAL COMPLETE</b>  ·  good luck out there", P.Lime)
		end
	end)
end

-- Test / external hooks: advance the caption, or skip the whole tour.
function Tutorial.Next()
	if capOn and nextBtn and nextBtn.Visible then
		if capBody.MaxVisibleGraphemes ~= -1 then
			typingSkip = true
		else
			nextPressed = true
		end
	end
end

function Tutorial.Skip()
	if Tutorial.Running then
		cancelled = true
	end
end

-- Starts the tour for first-time players once their data has loaded.
function Tutorial.Auto()
	task.spawn(function()
		local t0 = os.clock()
		while not (player:GetAttribute("Loaded") and Ctx.Data.Settings) or player:GetAttribute("Booting") == true do
			if os.clock() - t0 > 900 then
				return
			end
			task.wait(0.25)
		end
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(2)
		local s = Ctx.Data.Settings
		if s and s.Tut ~= true then
			Tutorial.Start()
		end
	end)
end

return Tutorial
