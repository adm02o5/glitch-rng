--!strict
-- AuraFX: client-side aura / rig / reveal-burst visual library for Glitch RNG.
--
--   AuraFX.Attach(character, auraId)   -> handle   (unique VFX per aura, scales with tier)
--   AuraFX.AttachRig(character, rigId) -> handle   (detailed hand gear, glowing in rig.color)
--   AuraFX.Burst(position, auraId, scale?)         (one-shot reveal explosion, ~3 s)
--   AuraFX.Has(auraId) -> boolean
--
-- Every aura also animates the body (AuraFX/Poses: Blender-authored idle / walk / reaction clips,
-- baked into AuraFX/Anims); levitating sets lift every root-anchored effect.
-- Pose and VFX of one aura share an AuraFX/Sync bus (c.bus): gestures fire effects, effects
-- make the body react, and both run on the same beat.
--
-- Everything lives in a Folder "AuraFX" inside the character (one sub-folder per handle).
-- Anchored parts are driven from one shared RenderStepped loop with Workspace:BulkMoveTo.

local Config = require(script.Parent.Config)
local Core = require(script.Core)
local AurasLow = require(script.AurasLow)
local AurasMid = require(script.AurasMid)
local AurasHigh = require(script.AurasHigh)
local Rigs = require(script.Rigs)
local Burst = require(script.Burst)
local AurasExtra = require(script.AurasExtra)
local Poses = require(script.Poses)

export type Handle = { Destroy: (self: Handle) -> () }

local AuraFX = {}

local builders: { [string]: (Core.Ctx) -> () } = {}
for _, src in { AurasLow, AurasMid, AurasHigh, AurasExtra } do
	for id, fn in src do
		builders[id] = fn
	end
end

local function tierIndex(chance: number): number
	local best = 1
	for i, t in Config.Tiers do
		if chance >= t.min then
			best = i
		end
	end
	return best
end

local function emptyHandle(): Handle
	return {
		Destroy = function(_self: Handle) end,
	}
end

-- Builds when the character has its root/head (waits briefly if they are still loading).
local function attachWith(
	character: Model,
	name: string,
	c1: Color3,
	c2: Color3,
	tier: number,
	build: (Core.Ctx) -> (),
	poseId: string?
): Handle
	local ctx: Core.Ctx? = nil
	local dead = false
	local stopPose: (() -> ())? = nil
	local float = poseId ~= nil and Poses.lift(poseId) > 0

	local function make()
		if dead or ctx then
			return
		end
		local c = Core.newCtx(character, name, c1, c2, tier, float)
		if not c then
			return
		end
		ctx = c
		if poseId and Poses.has(poseId) then
			stopPose = Poses.start(character, poseId, function(h: number)
				c.lift = h
			end, c.bus)
		end
		local ok, err = pcall(function()
			build(c)
		end)
		if not ok then
			warn("[AuraFX] failed to build " .. name .. ": " .. tostring(err))
		end
		Core.start(c)
	end

	if character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Head") then
		make()
	else
		task.spawn(function()
			local root = character:WaitForChild("HumanoidRootPart", 10)
			local head = character:WaitForChild("Head", 5)
			if root and head and character.Parent then
				make()
			end
		end)
	end

	return {
		Destroy = function(_self: Handle)
			dead = true
			local sp = stopPose
			if sp then
				stopPose = nil
				sp()
			end
			local c = ctx
			if c then
				Core.destroy(c)
			end
		end,
	}
end

function AuraFX.Has(auraId: string): boolean
	return builders[auraId] ~= nil and Config.AuraById[auraId] ~= nil
end

function AuraFX.Attach(character: Model, auraId: string): Handle
	local aura = Config.AuraById[auraId]
	local build = builders[auraId]
	if not aura or not build or typeof(character) ~= "Instance" then
		return emptyHandle()
	end
	return attachWith(character, "Aura_" .. auraId, aura.color, aura.color2, tierIndex(aura.chance), build, auraId)
end

function AuraFX.AttachRig(character: Model, rigId: string): Handle
	local rig = Config.RigById[rigId]
	local build = Rigs[rigId]
	if not rig or not build or typeof(character) ~= "Instance" then
		return emptyHandle()
	end
	local idx = 1
	for i, r in Config.Rigs do
		if r.id == rigId then
			idx = i
		end
	end
	local h, s, v = rig.color:ToHSV()
	local dark = Color3.fromHSV(h, s, v * 0.35)
	return attachWith(character, "Rig_" .. rigId, rig.color, dark, idx, build)
end

function AuraFX.Burst(position: Vector3, auraId: string, scale: number?)
	local aura = Config.AuraById[auraId]
	if not aura then
		return
	end
	Burst.play(position, aura.color, aura.color2, tierIndex(aura.chance), scale or 1)
end

return AuraFX
