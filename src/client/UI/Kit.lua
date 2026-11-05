--!strict
-- UI kit: theme, element helpers, panels with corner brackets, buttons with feedback, windows.
-- All screens build through this so the look stays consistent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent.Parent.Sfx)

local Kit = {}

local P = Config.Palette
Kit.P = P
Kit.Mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)
Kit.MonoBold = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
Kit.Title = Font.new("rbxasset://fonts/families/Michroma.json")
Kit.Pixel = Font.new("rbxasset://fonts/families/PressStart2P.json")

local player = Players.LocalPlayer
Kit.Gui = Instance.new("ScreenGui")
Kit.Gui.Name = "GlitchUI"
Kit.Gui.ResetOnSpawn = false
Kit.Gui.IgnoreGuiInset = true
Kit.Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Kit.Gui.Parent = player:WaitForChild("PlayerGui")

-- Topmost layer for cutscenes and toasts.
Kit.Top = Instance.new("ScreenGui")
Kit.Top.Name = "GlitchTop"
Kit.Top.ResetOnSpawn = false
Kit.Top.IgnoreGuiInset = true
Kit.Top.DisplayOrder = 50
Kit.Top.Parent = player.PlayerGui

-- Phone / tablet layout: touch without keyboard, or a short screen. The player attribute
-- "ForceMobile" turns it on for testing on PC.
function Kit.IsMobile(): boolean
	if player:GetAttribute("ForceMobile") then
		return true
	end
	local UIS = game:GetService("UserInputService")
	local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	return (UIS.TouchEnabled and not UIS.KeyboardEnabled) or (v.Y > 10 and v.Y < 520)
end

-- Scale the whole UI (HUD layer and top layer) down on small screens.
local scale = Instance.new("UIScale")
scale.Parent = Kit.Gui
local topScale = Instance.new("UIScale")
topScale.Parent = Kit.Top
Kit.Scale = scale
Kit.TopScale = topScale

local layoutFns: { (mobile: boolean) -> () } = {}
local lastMobile: boolean? = nil

-- Size of the screen in unscaled UI units (what offsets inside Kit.Gui / Kit.Top are measured in).
function Kit.Screen(): Vector2
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return v / math.max(scale.Scale, 0.01)
end

-- Height of the Roblox top bar (menu / chat buttons) in unscaled UI units.
function Kit.Inset(): number
	local GuiService = game:GetService("GuiService")
	local ok, tl = pcall(function()
		return (GuiService:GetGuiInset())
	end)
	local px = if ok and typeof(tl) == "Vector2" and tl.Y > 0 then tl.Y else 58
	return px / math.max(scale.Scale, 0.01)
end

local function rescale()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local k = math.clamp(math.min(v.X / 1600, v.Y / 900), 0.5, 1.15)
	local mobile = Kit.IsMobile()
	if mobile then
		-- Phones are held close: a bit bigger than the pure ratio, so text stays readable.
		k = math.clamp(k * 1.15, 0.5, 0.9)
	end
	scale.Scale = k
	topScale.Scale = k
	lastMobile = mobile
	for _, fn in layoutFns do
		task.spawn(fn, mobile)
	end
end

-- Registers a layout function: runs now and again whenever the screen size or mobile mode changes.
function Kit.OnLayout(fn: (mobile: boolean) -> ())
	table.insert(layoutFns, fn)
	fn(if lastMobile == nil then Kit.IsMobile() else lastMobile)
end

rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
player:GetAttributeChangedSignal("ForceMobile"):Connect(rescale)

-- True when the latest input came from a finger: hover effects are skipped (no mouse to leave).
local UIS = game:GetService("UserInputService")
function Kit.IsTouch(): boolean
	return UIS:GetLastInputType() == Enum.UserInputType.Touch
end

export type Feedback = {
	hover: (() -> ())?,
	idle: () -> (),
	press: () -> (),
	release: (() -> ())?, -- mouse released while still over the button (default: hover)
}

-- Hover / press / release states that work for mouse, touch and gamepad selection. A touch never
-- gets stuck in the hover state: when the finger lifts (or slides off and is cancelled) the button
-- returns to idle.
function Kit.feedback(b: GuiButton, fx: Feedback)
	local touching = false
	b.MouseEnter:Connect(function()
		if touching or Kit.IsTouch() then
			return
		end
		if fx.hover then
			fx.hover()
		end
	end)
	b.MouseLeave:Connect(function()
		if not touching then
			fx.idle()
		end
	end)
	b.SelectionGained:Connect(function()
		if fx.hover then
			fx.hover()
		end
	end)
	b.SelectionLost:Connect(function()
		fx.idle()
	end)
	b.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 then
			fx.press()
		elseif t == Enum.UserInputType.Touch then
			touching = true
			fx.press()
			local conn: RBXScriptConnection
			conn = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
				local st = input.UserInputState
				if st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then
					conn:Disconnect()
					touching = false
					fx.idle()
				end
			end)
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if fx.release then
				fx.release()
			elseif fx.hover then
				fx.hover()
			end
		end
	end)
end

function Kit.new<T>(class: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(class :: any)
	if props then
		local parent = props.Parent
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
		if children then
			for _, c in children do
				c.Parent = inst
			end
		end
		if parent then
			inst.Parent = parent
		end
	end
	return inst
end

function Kit.tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

function Kit.corner(parent: Instance, r: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, r or 4), Parent = parent })
end

function Kit.stroke(parent: Instance, color: Color3?, thick: number?, trans: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or P.Line,
		Thickness = thick or 1.5,
		Transparency = trans or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Kit.label(parent: Instance?, text: string, size: number, props: { [string]: any }?): TextLabel
	local l = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		FontFace = Kit.Mono,
		TextColor3 = P.Text,
		Size = UDim2.new(1, 0, 0, size + 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	return l
end

-- Little L-shaped brackets in the four corners: the signature panel decoration.
function Kit.brackets(parent: GuiObject, color: Color3?, len: number?, z: number?)
	local c = color or P.Cyan
	local L = len or 12
	local zi = z or (parent.ZIndex + 2)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local pos = UDim2.new(corner.X, if corner.X == 0 then -2 else 2, corner.Y, if corner.Y == 0 then -2 else 2)
		local anchor = corner
		Kit.new("Frame", {
			Name = "Bracket",
			BackgroundColor3 = c,
			BorderSizePixel = 0,
			AnchorPoint = anchor,
			Position = pos,
			Size = UDim2.fromOffset(L, 2),
			ZIndex = zi,
			Parent = parent,
		})
		Kit.new("Frame", {
			Name = "Bracket",
			BackgroundColor3 = c,
			BorderSizePixel = 0,
			AnchorPoint = anchor,
			Position = pos,
			Size = UDim2.fromOffset(2, L),
			ZIndex = zi,
			Parent = parent,
		})
	end
end

-- Dark glass panel with a gradient stroke and corner brackets.
function Kit.panel(parent: Instance?, props: { [string]: any }?, accent: Color3?): Frame
	local f = Kit.new("Frame", {
		BackgroundColor3 = P.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(f :: any)[k] = v
		end
	end
	Kit.corner(f, 3)
	Kit.new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 155, 175)),
		Rotation = 90,
		Parent = f,
	})
	local st = Kit.stroke(f, Color3.new(1, 1, 1), 1.5, 0.1)
	Kit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent or P.Cyan),
			ColorSequenceKeypoint.new(0.5, P.Line),
			ColorSequenceKeypoint.new(1, accent and accent:Lerp(P.Magenta, 0.5) or P.Magenta),
		}),
		Rotation = 35,
		Parent = st,
	})
	Kit.brackets(f, accent or P.Cyan)
	return f
end

export type ButtonOpts = {
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	textSize: number?,
	font: Font?,
	icon: string?, -- short glyph shown before text
	sound: string?,
	parent: Instance?,
	z: number?,
}

-- Button with hover glow, press squash, click sound. Returns the button and a setter for the text.
function Kit.button(o: ButtonOpts, onClick: (() -> ())?): TextButton
	local color = o.color or P.Cyan
	local b = Kit.new("TextButton", {
		AutoButtonColor = false,
		Text = "",
		Size = o.size,
		Position = o.position or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		BackgroundColor3 = P.PanelHi,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = o.z or 1,
		Parent = o.parent,
	})
	Kit.corner(b, 3)
	local st = Kit.stroke(b, color, 1.5, 0.35)
	local fill = Kit.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = b.ZIndex,
		Parent = b,
	})
	Kit.corner(fill, 3)
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new(0.2, 1),
		Rotation = 90,
		Parent = fill,
	})
	local text = Kit.label(b, (o.icon and (o.icon .. "  ") or "") .. o.text, o.textSize or 16, {
		Name = "Label",
		FontFace = o.font or Kit.MonoBold,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = P.Text,
		ZIndex = b.ZIndex + 1,
	})
	local uiScale = Kit.new("UIScale", { Parent = b })
	local hoverText = color:Lerp(Color3.new(1, 1, 1), 0.6)
	Kit.feedback(b, {
		hover = function()
			Sfx.Play("Hover", { volume = 0.35 })
			Kit.tween(st, 0.15, { Transparency = 0 })
			Kit.tween(fill, 0.15, { BackgroundTransparency = 0.7 })
			Kit.tween(uiScale, 0.15, { Scale = 1.04 })
			Kit.tween(text, 0.15, { TextColor3 = hoverText })
		end,
		idle = function()
			Kit.tween(st, 0.2, { Transparency = 0.35 })
			Kit.tween(fill, 0.2, { BackgroundTransparency = 0.88 })
			Kit.tween(uiScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			Kit.tween(text, 0.2, { TextColor3 = P.Text })
		end,
		press = function()
			-- Fingers cover the button, so the press state is bright as well as squashed.
			Kit.tween(st, 0.06, { Transparency = 0 })
			Kit.tween(fill, 0.06, { BackgroundTransparency = 0.55 })
			Kit.tween(uiScale, 0.06, { Scale = 0.94 })
			Kit.tween(text, 0.06, { TextColor3 = hoverText })
		end,
		release = function()
			Kit.tween(fill, 0.2, { BackgroundTransparency = 0.7 })
			Kit.tween(uiScale, 0.25, { Scale = 1.04 }, Enum.EasingStyle.Back)
		end,
	})
	if onClick then
		b.Activated:Connect(function()
			Sfx.Play(o.sound or "Click")
			onClick()
		end)
	end
	return b
end

function Kit.setButtonText(b: TextButton, text: string)
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l then
		l.Text = text
	end
end

-- Briefly shakes a gui object sideways with RGB-split copies of a label (glitch hit).
function Kit.glitch(label: TextLabel, duration: number?)
	local d = duration or 0.35
	local copies = {}
	for i, col in { P.Cyan, P.Magenta } do
		local c = label:Clone()
		for _, ch in c:GetChildren() do
			if not ch:IsA("UIStroke") then
				ch:Destroy()
			end
		end
		c.Name = "GlitchCopy"
		c.TextColor3 = col
		c.TextTransparency = 0.35
		c.ZIndex = label.ZIndex - 1
		c.Parent = label.Parent
		copies[i] = c
	end
	local base = label.Position
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > d then
			conn:Disconnect()
			label.Position = base
			for _, c in copies do
				c:Destroy()
			end
			return
		end
		local k = 1 - t / d
		local j = math.random(-6, 6) * k
		label.Position = base + UDim2.fromOffset(math.random(-3, 3) * k, 0)
		copies[1].Position = base + UDim2.fromOffset(-4 * k + j, math.random(-2, 2))
		copies[2].Position = base + UDim2.fromOffset(4 * k - j, math.random(-2, 2))
	end)
end

-- Typewriter text.
function Kit.type(label: TextLabel, text: string, cps: number?, onChar: (() -> ())?)
	label.Text = text
	label.MaxVisibleGraphemes = 0
	local n = utf8.len(text) or #text
	local rate = cps or 40
	for i = 1, n do
		label.MaxVisibleGraphemes = i
		if onChar and i % 2 == 0 then
			onChar()
		end
		task.wait(1 / rate)
	end
	label.MaxVisibleGraphemes = -1
end

export type Window = {
	frame: Frame,
	body: Frame,
	open: boolean,
	Open: (self: Window) -> (),
	Close: (self: Window) -> (),
	Toggle: (self: Window) -> (),
	onOpen: (() -> ())?,
}

local openWindow: Window? = nil

-- Centered modal window with title bar, close button and open/close animation.
-- Only one window is open at a time.
function Kit.window(title: string, subtitle: string, size: Vector2, accent: Color3?): Window
	local acc = accent or P.Cyan
	local frame = Kit.panel(Kit.Gui, {
		Name = "Window_" .. title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		ZIndex = 10,
		BackgroundTransparency = 0.06,
	}, acc)
	local sc = Kit.new("UIScale", { Parent = frame })
	-- Title bar
	local bar = Kit.new("Frame", {
		BackgroundColor3 = acc,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 54),
		ZIndex = 11,
		Parent = frame,
	})
	Kit.new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = bar })
	local t = Kit.label(bar, title, 24, {
		FontFace = Kit.Title,
		TextColor3 = acc,
		Position = UDim2.fromOffset(20, 8),
		Size = UDim2.new(1, -90, 0, 26),
		ZIndex = 12,
	})
	Kit.label(bar, subtitle, 12, {
		TextColor3 = P.Dim,
		Position = UDim2.fromOffset(21, 34),
		Size = UDim2.new(1, -90, 0, 14),
		ZIndex = 12,
	})
	Kit.new("Frame", {
		BackgroundColor3 = acc,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 0.4,
		ZIndex = 11,
		Parent = frame,
	})
	local body = Kit.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 66),
		Size = UDim2.new(1, -32, 1, -82),
		ZIndex = 11,
		Parent = frame,
	})

	local w: Window = {
		frame = frame,
		body = body,
		open = false,
	} :: any

	local close = Kit.button({
		text = "X",
		size = UDim2.fromOffset(36, 36),
		position = UDim2.new(1, -46, 0, 9),
		color = P.Red,
		parent = frame,
		z = 13,
	}, function()
		w:Close()
	end)
	close.Name = "Close"

	-- Bigger, invisible hit area around the close button, so it is easy to tap on phones.
	local closeHit = Kit.new("TextButton", {
		Name = "CloseHit",
		Text = "",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(110, 74),
		Visible = false,
		ZIndex = 14,
		Parent = frame,
	})
	closeHit.Activated:Connect(function()
		Sfx.Play("Click")
		w:Close()
	end)

	-- Fit: the window keeps its designed layout and is scaled as a whole so it always fits the screen
	-- (92% x 88% of the viewport on phones, 96% x 94% elsewhere). Never enlarged on desktop.
	local fit = 1
	local function computeFit(mobile: boolean)
		local scr = Kit.Screen()
		local fw, fh = if mobile then 0.92 else 0.96, if mobile then 0.88 else 0.94
		local f = math.min(scr.X * fw / size.X, scr.Y * fh / size.Y)
		fit = math.clamp(f, 0.4, if mobile then 1.12 else 1)
		closeHit.Visible = mobile
		close.Size = if mobile then UDim2.fromOffset(46, 42) else UDim2.fromOffset(36, 36)
		close.Position = if mobile then UDim2.new(1, -54, 0, 6) else UDim2.new(1, -46, 0, 9)
		if w.open then
			sc.Scale = fit
		end
	end
	Kit.OnLayout(computeFit)

	function w.Open(self: Window)
		if self.open then
			return
		end
		if openWindow and openWindow ~= self then
			openWindow:Close()
		end
		openWindow = self
		self.open = true
		Sfx.Play("Open")
		frame.Visible = true
		sc.Scale = 0.85 * fit
		frame.Position = UDim2.fromScale(0.5, 0.53)
		Kit.tween(sc, 0.35, { Scale = fit }, Enum.EasingStyle.Back)
		Kit.tween(frame, 0.35, { Position = UDim2.fromScale(0.5, 0.5) })
		Kit.glitch(t, 0.4)
		if self.onOpen then
			self.onOpen()
		end
	end
	function w.Close(self: Window)
		if not self.open then
			return
		end
		self.open = false
		if openWindow == self then
			openWindow = nil
		end
		Sfx.Play("Close")
		Kit.tween(sc, 0.18, { Scale = 0.9 * fit }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.16, function()
			if not self.open then
				frame.Visible = false
			end
		end)
	end
	function w.Toggle(self: Window)
		if self.open then
			self:Close()
		else
			self:Open()
		end
	end
	return w
end

function Kit.closeAll()
	if openWindow then
		openWindow:Close()
	end
end

-- Scrolling grid helper.
function Kit.scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local s = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = if Kit.IsMobile() then 8 else 4,
		ScrollBarImageColor3 = P.Cyan,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(s :: any)[k] = v
		end
	end
	return s
end

return Kit
