--!strict
-- Custom player list (replaces Roblox's): avatar, name, equipped aura in its tier colour, rolls.
-- Tab toggles it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)

local Kit = require(script.Parent.Kit)

local P = Kit.P
local new = Kit.new

local PlayerList = {}

local ROW_H = 40
local WIDTH = 330

local panel: Frame
local list: Frame
local countL: TextLabel
local rows: { [Player]: Frame } = {}
local shown = true
local dirty = true

local function rolls(plr: Player): number
	local ls = plr:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("Rolls") :: IntValue?
	return v and v.Value or 0
end

local function makeRow(plr: Player): Frame
	local row = new("Frame", {
		Name = plr.Name,
		BackgroundColor3 = P.PanelHi,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ROW_H),
		Parent = list,
	})
	Kit.corner(row, 3)
	new("Frame", {
		Name = "Accent",
		BackgroundColor3 = P.Line,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, -10),
		Position = UDim2.fromOffset(0, 5),
		Parent = row,
	})
	local head = new("ImageLabel", {
		BackgroundColor3 = P.Bg,
		Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", plr.UserId),
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(9, 5),
		Parent = row,
	})
	Kit.corner(head, 15)
	Kit.stroke(head, P.Line, 1)
	Kit.label(row, plr.DisplayName, 14, {
		Name = "PlayerName",
		FontFace = Kit.MonoBold,
		Position = UDim2.fromOffset(48, 3),
		Size = UDim2.new(1, -130, 0, 17),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = if plr == Players.LocalPlayer then P.Cyan else P.Text,
	})
	Kit.label(row, "", 12, {
		Name = "Aura",
		FontFace = Kit.MonoBold,
		Position = UDim2.fromOffset(48, 21),
		Size = UDim2.new(1, -130, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Kit.label(row, "0", 15, {
		Name = "Rolls",
		FontFace = Kit.MonoBold,
		TextColor3 = P.Dim,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 11),
		Size = UDim2.fromOffset(78, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	return row
end

local function refresh()
	dirty = false
	local all = Players:GetPlayers()
	table.sort(all, function(a, b)
		return rolls(a) > rolls(b)
	end)
	for i, plr in all do
		local row = rows[plr]
		if not row then
			row = makeRow(plr)
			rows[plr] = row
		end
		row.LayoutOrder = i
		local auraL = row:FindFirstChild("Aura") :: TextLabel
		local accent = row:FindFirstChild("Accent") :: Frame
		local id = plr:GetAttribute("Aura")
		local a = typeof(id) == "string" and Config.AuraById[id] or nil
		if a then
			local tier = Config.TierOf(a.chance)
			auraL.Text = string.format("%s  ·  1/%s", a.name, RNG.Short(a.chance))
			auraL.TextColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.2)
			accent.BackgroundColor3 = tier.color
		else
			auraL.Text = "no aura"
			auraL.TextColor3 = P.Dim
			accent.BackgroundColor3 = P.Line
		end
		(row:FindFirstChild("Rolls") :: TextLabel).Text = RNG.Short(rolls(plr))
	end
	countL.Text = string.format("%d / %d ONLINE", #all, Players.MaxPlayers)
end

local function watch(plr: Player)
	plr:GetAttributeChangedSignal("Aura"):Connect(function()
		dirty = true
	end)
	plr.ChildAdded:Connect(function(c)
		if c.Name == "leaderstats" then
			local v = c:WaitForChild("Rolls", 5) :: IntValue?
			if v then
				v.Changed:Connect(function()
					dirty = true
				end)
			end
			dirty = true
		end
	end)
	local ls = plr:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("Rolls") :: IntValue?
	if v then
		v.Changed:Connect(function()
			dirty = true
		end)
	end
	dirty = true
end

local function setShown(v: boolean)
	shown = v
	Kit.tween(panel, 0.3, {
		Position = if v then UDim2.new(1, -20, 0, 96) else UDim2.new(1, WIDTH + 40, 0, 96),
	})
end

function PlayerList.Start()
	-- Roblox's list can only be hidden after CoreGui is ready; retry a few times.
	task.spawn(function()
		for _ = 1, 20 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false) then
				break
			end
			task.wait(0.5)
		end
	end)

	panel = Kit.panel(Kit.Gui, {
		Name = "PlayerList",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 96),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.18,
	})
	local body = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = panel,
	})
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10),
		Parent = body,
	})
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0, Parent = body })
	Kit.label(header, "// NETWORK", 12, { FontFace = Kit.MonoBold, TextColor3 = P.Cyan, Size = UDim2.fromScale(0.5, 1) })
	countL = Kit.label(header, "", 12, {
		TextColor3 = P.Dim,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local cols = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 1, Parent = body })
	Kit.label(cols, "USER / AURA", 10, { TextColor3 = P.Dim, Position = UDim2.fromOffset(48, 0), Size = UDim2.fromOffset(150, 12) })
	Kit.label(cols, "ROLLS", 10, { TextColor3 = P.Dim, Size = UDim2.new(1, -10, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
	list = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = body,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	for _, plr in Players:GetPlayers() do
		watch(plr)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(plr)
		local row = rows[plr]
		if row then
			row:Destroy()
			rows[plr] = nil
		end
		dirty = true
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Tab then
			setShown(not shown)
		end
	end)
	-- Hidden by default on small (phone) screens.
	if workspace.CurrentCamera.ViewportSize.X < 900 then
		setShown(false)
	end

	task.spawn(function()
		while true do
			if dirty then
				refresh()
			end
			task.wait(0.5)
		end
	end)
end

return PlayerList
