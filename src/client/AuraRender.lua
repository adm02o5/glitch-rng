--!strict
-- Builds every player's equipped aura and rig locally from the "Aura" / "Rig" player attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AuraFX = require(Shared:WaitForChild("AuraFX"))
local Config = require(Shared:WaitForChild("Config"))
local RNG = require(Shared:WaitForChild("RNG"))
local Ctx = require(script.Parent.Ctx)

local TITLE = Font.new("rbxasset://fonts/families/Michroma.json")
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

-- Aura name + chance floating over the head. Sized in studs so it shrinks with distance.
local function makeTag(char: Model, auraId: string, displayName: string): BillboardGui?
	local a = Config.AuraById[auraId]
	local head = char:FindFirstChild("Head") :: BasePart?
	if not (a and head) then
		return nil
	end
	local tier = Config.TierOf(a.chance)
	local bb = Instance.new("BillboardGui")
	bb.Name = "AuraTag"
	bb.Size = UDim2.fromScale(9, 2.5)
	bb.StudsOffset = Vector3.new(0, 2.3 + math.min(tier.cutscene, 4) * 0.25, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Adornee = head
	local who = Instance.new("TextLabel")
	who.BackgroundTransparency = 1
	who.Size = UDim2.fromScale(1, 0.22)
	who.Text = displayName
	who.TextScaled = true
	who.FontFace = MONO
	who.TextColor3 = Color3.fromRGB(230, 236, 255)
	who.Parent = bb
	local ws = Instance.new("UIStroke")
	ws.Thickness = 1.5
	ws.Transparency = 0.3
	ws.Parent = who
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0, 0.22)
	name.Size = UDim2.fromScale(1, 0.5)
	name.Text = a.name
	name.TextScaled = true
	name.FontFace = TITLE
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Parent = bb
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, a.color:Lerp(Color3.new(1, 1, 1), 0.2)),
		ColorSequenceKeypoint.new(0.5, a.color2:Lerp(a.color, 0.35)),
		ColorSequenceKeypoint.new(1, a.color:Lerp(Color3.new(1, 1, 1), 0.2)),
	})
	grad.Parent = name
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = if a.color.R + a.color.G + a.color.B < 0.3 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
	stroke.Transparency = 0.2
	stroke.Parent = name
	local chance = Instance.new("TextLabel")
	chance.BackgroundTransparency = 1
	chance.Position = UDim2.fromScale(0, 0.72)
	chance.Size = UDim2.fromScale(1, 0.28)
	chance.Text = RNG.ChanceText(a.chance)
	chance.TextScaled = true
	chance.FontFace = MONO
	chance.TextColor3 = tier.color:Lerp(Color3.new(1, 1, 1), 0.35)
	chance.Parent = bb
	local cs = Instance.new("UIStroke")
	cs.Thickness = 1.5
	cs.Transparency = 0.3
	cs.Parent = chance
	-- Rare+ names shimmer.
	if tier.cutscene >= 1 then
		local conn = RunService.RenderStepped:Connect(function()
			grad.Offset = Vector2.new(math.sin(os.clock() * 1.4) * 0.6, 0)
		end)
		bb.Destroying:Connect(function()
			conn:Disconnect()
		end)
	end
	bb.Parent = char
	return bb
end

local AuraRender = {}

type Handle = { Destroy: (self: any) -> () }
local handles: { [Player]: { aura: Handle?, rig: Handle?, tag: BillboardGui? } } = {}
local local_ = Players.LocalPlayer

-- Performance LOD: other players' auras are only built while they are near the camera.
-- Hysteresis (build < NEAR, remove > FAR) avoids rebuilding at the edge.
local NEAR, FAR = 140, 180
local far: { [Player]: boolean } = {}

local function camDistance(plr: Player): number
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = workspace.CurrentCamera
	if not (root and cam) then
		return 0
	end
	return (root.Position - cam.CFrame.Position).Magnitude
end

local function showOthers(): boolean
	local s = Ctx.Data.Settings
	return s == nil or s.Others ~= false
end

local function clear(plr: Player)
	local h = handles[plr]
	if h then
		if h.aura then
			h.aura:Destroy()
		end
		if h.rig then
			h.rig:Destroy()
		end
		if h.tag then
			h.tag:Destroy()
		end
	end
	handles[plr] = nil
end

local function apply(plr: Player)
	clear(plr)
	local char = plr.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	-- Our tag shows the player name, so hide Roblox's default one.
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	if plr ~= local_ and (not showOthers() or far[plr]) then
		return
	end
	local h = {}
	local aura = plr:GetAttribute("Aura")
	if typeof(aura) == "string" and aura ~= "" then
		h.aura = AuraFX.Attach(char, aura)
		h.tag = makeTag(char, aura, plr.DisplayName)
	end
	local rig = plr:GetAttribute("Rig")
	if typeof(rig) == "string" and rig ~= "" then
		h.rig = AuraFX.AttachRig(char, rig)
	end
	handles[plr] = h
end

local function watch(plr: Player)
	plr:GetAttributeChangedSignal("Aura"):Connect(function()
		apply(plr)
	end)
	plr:GetAttributeChangedSignal("Rig"):Connect(function()
		apply(plr)
	end)
	plr.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.2) -- let the avatar finish loading accessories
		apply(plr)
	end)
	if plr.Character then
		task.spawn(apply, plr)
	end
end

function AuraRender.Start()
	for _, plr in Players:GetPlayers() do
		watch(plr)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(plr)
		clear(plr)
		far[plr] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, plr in Players:GetPlayers() do
				if plr ~= local_ then
					local d = camDistance(plr)
					if far[plr] and d < NEAR then
						far[plr] = nil
						apply(plr)
					elseif not far[plr] and d > FAR then
						far[plr] = true
						clear(plr)
					end
				end
			end
		end
	end)
	local last = showOthers()
	Ctx.Changed.Event:Connect(function()
		local now = showOthers()
		if now ~= last then
			last = now
			for _, plr in Players:GetPlayers() do
				if plr ~= local_ then
					apply(plr)
				end
			end
		end
	end)
end

-- Re-apply the local player's aura (used after cutscenes that hide it).
function AuraRender.Refresh()
	apply(local_)
end

return AuraRender
