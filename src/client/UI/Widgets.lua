--!strict
-- Reusable pieces for windows: aura tiles, tier tags, recipe rows, tabs, sliders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)

local Kit = require(script.Parent.Kit)
local Sfx = require(script.Parent.Parent.Sfx)

local P = Kit.P
local new = Kit.new

local W = {}

-- Animated gradient "chip" showing an aura's colours.
function W.swatch(parent: Instance, a: Config.Aura, size: UDim2, pos: UDim2?): Frame
	local f = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = size,
		Position = pos or UDim2.new(),
		Parent = parent,
	})
	Kit.corner(f, 3)
	local g = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, a.color),
			ColorSequenceKeypoint.new(0.5, a.color2),
			ColorSequenceKeypoint.new(1, a.color),
		}),
		Rotation = 45,
		Parent = f,
	})
	local tier = Config.TierOf(a.chance)
	if tier.cutscene >= 2 then
		-- Higher tiers shimmer.
		local conn = RunService.RenderStepped:Connect(function()
			g.Offset = Vector2.new(math.sin(os.clock() * 1.5) * 0.5, 0)
		end)
		f.Destroying:Connect(function()
			conn:Disconnect()
		end)
	end
	-- Pixel grid overlay for texture.
	for i = 1, 3 do
		new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			Position = UDim2.new(i / 4, 0, 0, 0),
			Size = UDim2.new(0, 1, 1, 0),
			Parent = f,
		})
		new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, i / 4, 0),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = f,
		})
	end
	return f
end

function W.tierTag(parent: Instance, tier: Config.Tier, pos: UDim2, size: UDim2?): TextLabel
	local l = Kit.label(parent, tier.name, 11, {
		FontFace = Kit.MonoBold,
		TextColor3 = tier.color,
		BackgroundColor3 = tier.color,
		BackgroundTransparency = 0.85,
		Position = pos,
		Size = size or UDim2.fromOffset(96, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Kit.corner(l, 2)
	Kit.stroke(l, tier.color, 1, 0.5)
	return l
end

-- Square tile for an aura (inventory / index grids).
function W.auraTile(parent: Instance, a: Config.Aura, count: number?, known: boolean, onClick: () -> ()): TextButton
	local tier = Config.TierOf(a.chance)
	local b = new("TextButton", {
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = P.PanelHi,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		LayoutOrder = a.chance,
		Parent = parent,
	})
	Kit.corner(b, 3)
	local st = Kit.stroke(b, tier.color, 1.5, 0.55)
	if known then
		W.swatch(b, a, UDim2.new(1, -16, 0, 46), UDim2.fromOffset(8, 8))
	else
		local q = new("Frame", {
			BackgroundColor3 = P.Bg,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -16, 0, 46),
			Position = UDim2.fromOffset(8, 8),
			Parent = b,
		})
		Kit.corner(q, 3)
		Kit.label(q, "? ? ?", 18, {
			FontFace = Kit.Pixel,
			TextColor3 = P.Line,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	Kit.label(b, if known then a.name else "UNKNOWN", 13, {
		FontFace = Kit.MonoBold,
		TextColor3 = if known then tier.color:Lerp(Color3.new(1, 1, 1), 0.35) else P.Dim,
		Position = UDim2.fromOffset(8, 58),
		Size = UDim2.new(1, -16, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Kit.label(b, "1/" .. RNG.Short(a.chance), 11, {
		TextColor3 = P.Dim,
		Position = UDim2.fromOffset(8, 76),
		Size = UDim2.new(1, -16, 0, 13),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	if count and count > 0 then
		local c = Kit.label(b, "x" .. RNG.Short(count), 11, {
			FontFace = Kit.MonoBold,
			TextColor3 = P.Bg,
			BackgroundColor3 = tier.color,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(34, 15),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
		})
		Kit.corner(c, 2)
	end
	if a.biome then
		local bm = Config.BiomeById[a.biome]
		new("Frame", {
			BackgroundColor3 = bm.color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(6, 6),
			ZIndex = 3,
			Parent = b,
		})
	end
	local sc = new("UIScale", { Parent = b })
	Kit.feedback(b, {
		hover = function()
			Kit.tween(st, 0.12, { Transparency = 0 })
			Kit.tween(sc, 0.12, { Scale = 1.05 })
			Sfx.Play("Hover", { volume = 0.25 })
		end,
		idle = function()
			Kit.tween(st, 0.15, { Transparency = 0.55 })
			Kit.tween(sc, 0.2, { Scale = 1 })
		end,
		press = function()
			Kit.tween(st, 0.06, { Transparency = 0 })
			Kit.tween(sc, 0.06, { Scale = 0.95 })
		end,
	})
	b.Activated:Connect(function()
		Sfx.Play("Click")
		onClick()
	end)
	return b
end

function W.grid(parent: Instance, cell: Vector2): ScrollingFrame
	local s = Kit.scroll(parent)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = s,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = s,
	})
	return s
end

function W.clear(parent: Instance)
	for _, c in parent:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- Tab strip; returns a function to select a tab by name.
function W.tabs(parent: Instance, names: { string }, onSelect: (string) -> ()): (string) -> ()
	local bar = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = parent,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		Parent = bar,
	})
	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for n, b in buttons do
			local on = n == name
			local st = b:FindFirstChildOfClass("UIStroke")
			if st then
				st.Thickness = if on then 2.5 else 1.5
				st.Transparency = if on then 0 else 0.35
			end
			local l = b:FindFirstChild("Label") :: TextLabel
			l.TextColor3 = if on then P.Cyan else P.Dim
		end
		onSelect(name)
	end
	for _, n in names do
		buttons[n] = Kit.button({
			text = string.upper(n),
			size = UDim2.fromOffset(130, 32),
			textSize = 13,
			parent = bar,
		}, function()
			select(n)
		end)
	end
	return select
end

-- Recipe row list: "Pixel 3/10" with red/green state. Returns true if all are met.
function W.recipe(parent: Instance, recipe: Config.Recipe, inv: { [string]: number }): boolean
	local ok = true
	local items = {}
	for id, n in recipe do
		table.insert(items, { a = Config.AuraById[id], n = n })
	end
	table.sort(items, function(x, y)
		return x.a.chance < y.a.chance
	end)
	for i, it in items do
		local have = inv[it.a.id] or 0
		local met = have >= it.n
		ok = ok and met
		local row = new("Frame", {
			BackgroundColor3 = P.PanelHi,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = i,
			Parent = parent,
		})
		Kit.corner(row, 3)
		W.swatch(row, it.a, UDim2.fromOffset(24, 24), UDim2.fromOffset(6, 5))
		Kit.label(row, it.a.name, 14, {
			FontFace = Kit.MonoBold,
			TextColor3 = Config.TierOf(it.a.chance).color:Lerp(Color3.new(1, 1, 1), 0.3),
			Position = UDim2.fromOffset(40, 8),
			Size = UDim2.new(0.6, -40, 0, 18),
		})
		Kit.label(row, string.format("%s / %s", RNG.Commas(have), RNG.Commas(it.n)), 14, {
			FontFace = Kit.MonoBold,
			TextColor3 = if met then P.Lime else P.Red,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 8),
			Size = UDim2.new(0.4, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	return ok
end

-- Horizontal slider 0..1.
function W.slider(parent: Instance, value: number, color: Color3, onChange: (number) -> ()): Frame
	local track = new("Frame", {
		BackgroundColor3 = P.Bg,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 10),
		Parent = parent,
	})
	Kit.corner(track, 5)
	Kit.stroke(track, P.Line, 1)
	local fill = new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(value, 1),
		Parent = track,
	})
	Kit.corner(fill, 5)
	local knob = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value, 0.5),
		Size = UDim2.fromOffset(18, 18),
		Parent = track,
	})
	Kit.corner(knob, 9)
	Kit.stroke(knob, color, 2)
	local dragging = false
	local function set(x: number)
		local k = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		k = math.floor(k * 20 + 0.5) / 20
		fill.Size = UDim2.fromScale(k, 1)
		knob.Position = UDim2.fromScale(k, 0.5)
		onChange(k)
	end
	local hit = new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		-- Taller hit strip on phones so the slider is easy to grab with a thumb.
		Size = UDim2.new(1, 0, 0, if Kit.IsMobile() then 50 else 30),
		Position = UDim2.fromOffset(0, if Kit.IsMobile() then -20 else -10),
		Parent = track,
	})
	hit.MouseButton1Down:Connect(function(x)
		dragging = true
		set(x)
	end)
	UserInputService.InputChanged:Connect(function(input)
		local t = input.UserInputType
		if dragging and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
			set(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	return track
end

return W
