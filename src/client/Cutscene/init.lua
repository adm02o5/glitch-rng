--!strict
-- Cutscenes, played by Roller after the name reel stops and before the result card.
--
-- Every EPIC+ aura has its own themed scene (Cutscene/Epic, Legendary, Mythic, Corrupted, Singularity,
-- Redacted); RARE auras and any aura without a scene use the generic tier sequence (Cutscene/Tiers).
-- Scenes are built from the shared toolkit (Cutscene/Session + Cutscene/Fx).
--
-- Rough lengths: Epic ~2.5s, Legendary ~5s, Mythic ~7.5s, Corrupted ~9.5s, Singularity ~12s, [REDACTED] ~28s.
--
-- Everything is driven by os.clock() on RenderStepped (no drifting wait chains). All instances, Lighting
-- effects, local 3D props, camera state, HUD state and ducked music are restored in cleanup, even if a
-- scene errors. Players can skip level >= 3 with a click/tap unless it is the first time they get the aura.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Session = require(script.Session)
local Fx = require(script.Fx)
local U = require(script.Util)
local Ctx = require(script.Parent.Ctx)
Fx.install(Session)

local Tiers = require(script.Tiers) :: { (any) -> () }

export type Info = Session.Info

local Cutscene = {}

-- aura id -> scene function. Each scene module returns { [auraId]: (S) -> () }.
local SCENES: { [string]: (any) -> () } = {}
for _, name in { "Epic", "Legendary", "Mythic", "Corrupted", "Singularity", "Redacted" } do
	local m = script:FindFirstChild(name)
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok and type(mod) == "table" then
			for id, fn in mod :: { [string]: any } do
				if type(fn) == "function" then
					SCENES[id] = fn
				end
			end
		else
			warn("[Cutscene] scene module " .. name .. " failed to load: " .. tostring(mod))
		end
	end
end

-- True when this aura plays its own themed scene instead of the generic tier one.
function Cutscene.HasScene(auraId: string): boolean
	return SCENES[auraId] ~= nil
end

local playing = false

-- Quick flash out used after a skip or an error: hides the cut, restores everything, fades away.
local function flashOut(S: any)
	-- reduced flashing: cut through black instead of a white flash
	local calm = Ctx.Calm()
	local white = S:frame({
		Name = "SkipFlash",
		BackgroundColor3 = if calm then Color3.new(0, 0, 0) else U.WHITE,
		BackgroundTransparency = 1,
		ZIndex = 200,
	})
	S:raw(0.08, function(k: number)
		white.BackgroundTransparency = 1 - k
	end)
	S:peakCut(white)
	S:raw(0.35, function(k: number)
		white.BackgroundTransparency = U.outCubic(k)
	end)
end

-- Plays the cutscene for `aura` and yields until it is over (camera, HUD, Lighting and music restored).
function Cutscene.Play(aura: Config.Aura, info: Info)
	if playing or not aura then
		return
	end
	local level = math.clamp(Config.TierOf(aura.chance).cutscene, 0, 5)
	if level <= 0 then
		return
	end
	local fn = (if level >= 2 then SCENES[aura.id] else nil) or Tiers[level]
	if not fn then
		return
	end
	playing = true
	local okNew, S = pcall(Session.new, aura, info or {}, level)
	if not okNew then
		warn("[Cutscene] could not start: " .. tostring(S))
		playing = false
		return
	end
	local ok, err = xpcall(function(): any
		fn(S)
		return nil
	end, function(e: any): any
		if e == Session.SKIP then
			return Session.SKIP
		end
		return debug.traceback(tostring(e), 2)
	end)
	if not ok then
		if err ~= Session.SKIP then
			warn("[Cutscene] " .. tostring(err))
		end
		pcall(flashOut, S)
	end
	pcall(S.cleanup, S)
	playing = false
end

return Cutscene
