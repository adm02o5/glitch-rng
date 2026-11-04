--!strict
-- Builds every player's equipped aura and rig locally from the "Aura" / "Rig" player attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AuraFX = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AuraFX"))
local Ctx = require(script.Parent.Ctx)

local AuraRender = {}

type Handle = { Destroy: (self: any) -> () }
local handles: { [Player]: { aura: Handle?, rig: Handle? } } = {}
local local_ = Players.LocalPlayer

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
	end
	handles[plr] = nil
end

local function apply(plr: Player)
	clear(plr)
	local char = plr.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	if plr ~= local_ and not showOthers() then
		return
	end
	local h = {}
	local aura = plr:GetAttribute("Aura")
	if typeof(aura) == "string" and aura ~= "" then
		h.aura = AuraFX.Attach(char, aura)
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
	Players.PlayerRemoving:Connect(clear)
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
