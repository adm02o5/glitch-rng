--!strict
-- Global "most rolls" leaderboard drawn on the map's LeaderboardScreen.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RNG = require(ReplicatedStorage.Shared.RNG)

local Board = {}

local P = Config.Palette
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)
local TITLE = Font.new("rbxasset://fonts/families/Michroma.json")

local store: OrderedDataStore? = nil
pcall(function()
	store = DataStoreService:GetOrderedDataStore("GlitchRNG_Rolls_v1")
end)

local pending: { [number]: number } = {}
local rows: { Frame } = {}

function Board.Bump(plr: Player, rolls: number)
	pending[plr.UserId] = rolls
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = P.Text
	l.FontFace = MONO
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function build(): boolean
	local map = workspace:FindFirstChild("Map")
	local screen = map and map:FindFirstChild("LeaderboardScreen", true)
	local gui = screen and screen:FindFirstChild("Board")
	if not gui then
		return false
	end
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = P.Bg
	root.BackgroundTransparency = 0.05
	root.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(10, 12, 24), Color3.fromRGB(2, 2, 6))
	grad.Rotation = 90
	grad.Parent = root
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.03, 0)
	pad.Parent = root

	label(root, {
		Text = "TOP ROLLERS",
		FontFace = TITLE,
		TextColor3 = P.Cyan,
		Size = UDim2.fromScale(1, 0.1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	label(root, {
		Text = "// GLOBAL NETWORK RANKING · UPDATES EVERY MINUTE",
		TextColor3 = P.Dim,
		Size = UDim2.fromScale(1, 0.04),
		Position = UDim2.fromScale(0, 0.105),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = P.Magenta
	line.Size = UDim2.new(1, 0, 0, 3)
	line.Position = UDim2.fromScale(0, 0.16)
	line.Parent = root

	for i = 1, 10 do
		local row = Instance.new("Frame")
		row.Size = UDim2.fromScale(1, 0.074)
		row.Position = UDim2.fromScale(0, 0.18 + (i - 1) * 0.08)
		row.BackgroundColor3 = if i % 2 == 0 then P.PanelHi else P.Panel
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.Parent = root
		local accent = Instance.new("Frame")
		accent.BorderSizePixel = 0
		accent.Size = UDim2.new(0, 6, 1, 0)
		accent.BackgroundColor3 = if i == 1 then P.Amber elseif i == 2 then P.Text elseif i == 3 then P.Red else P.Line
		accent.Parent = row
		label(row, {
			Name = "Rank",
			Text = string.format("#%02d", i),
			TextColor3 = accent.BackgroundColor3,
			Size = UDim2.fromScale(0.1, 0.7),
			Position = UDim2.fromScale(0.025, 0.15),
		})
		local img = Instance.new("ImageLabel")
		img.Name = "Head"
		img.BackgroundColor3 = P.Bg
		img.Size = UDim2.fromScale(0.07, 0.9)
		img.Position = UDim2.fromScale(0.13, 0.05)
		img.SizeConstraint = Enum.SizeConstraint.RelativeYY
		img.Parent = row
		label(row, { Name = "PlayerName", Text = "---", Size = UDim2.fromScale(0.5, 0.6), Position = UDim2.fromScale(0.22, 0.2) })
		label(row, {
			Name = "Value",
			Text = "",
			TextColor3 = P.Cyan,
			Size = UDim2.fromScale(0.25, 0.6),
			Position = UDim2.fromScale(0.73, 0.2),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		rows[i] = row
	end
	return true
end

local nameCache: { [number]: string } = {}

local function nameOf(id: number): string
	if nameCache[id] then
		return nameCache[id]
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, id)
	local name = if ok then n else ("User" .. id)
	nameCache[id] = name
	return name
end

local function refresh()
	if not store then
		return
	end
	local s = store :: OrderedDataStore
	for id, rolls in pending do
		pcall(s.SetAsync, s, tostring(id), rolls)
	end
	table.clear(pending)
	local ok, pages = pcall(s.GetSortedAsync, s, false, 10)
	if not ok then
		return
	end
	local list = (pages :: DataStorePages):GetCurrentPage()
	for i, row in rows do
		local entry = list[i]
		local nameL = row:FindFirstChild("PlayerName") :: TextLabel
		local valL = row:FindFirstChild("Value") :: TextLabel
		local head = row:FindFirstChild("Head") :: ImageLabel
		if entry then
			local uid = tonumber(entry.key) or 0
			nameL.Text = nameOf(uid)
			valL.Text = RNG.Commas(entry.value)
			head.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", uid)
		else
			nameL.Text = "---"
			valL.Text = ""
			head.Image = ""
		end
	end
end

function Board.Init()
	if not build() then
		warn("[Board] LeaderboardScreen not found")
		return
	end
	task.spawn(function()
		while true do
			refresh()
			task.wait(60)
		end
	end)
end

return Board
