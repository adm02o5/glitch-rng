--!strict
-- Client entry: builds HUD, windows, roll flow, aura rendering, world effects and music.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Push = Remotes:WaitForChild("Push") :: RemoteEvent

local Ctx = require(script.Parent.Ctx)
local Sfx = require(script.Parent.Sfx)
local Kit = require(script.Parent.UI.Kit)
local Hud = require(script.Parent.UI.Hud)
local Roller = require(script.Parent.Roller)
local AuraRender = require(script.Parent.AuraRender)
local Prompts = require(script.Parent.Prompts)
local Announce = require(script.Parent.Announce)
local WorldFX = require(script.Parent.WorldFX)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

Hud.Start()

-- Every module in UI/Windows returns a function that builds and returns a Kit window.
for _, m in script.Parent.UI.Windows:GetChildren() do
	if m:IsA("ModuleScript") then
		local ok, res = pcall(function()
			return (require(m) :: any)()
		end)
		if ok and res then
			Ctx.Windows[m.Name] = res
		else
			warn("[UI] window failed:", m.Name, res)
		end
	end
end

Push.OnClientEvent:Connect(function(kind: string, payload: any)
	if kind == "Data" then
		Ctx.Set(payload)
	elseif kind == "Announce" then
		Announce.Show(payload)
	end
end)

Ctx.Changed.Event:Connect(function(d)
	local s = d.Settings
	if s then
		Sfx.Volume = tonumber(s.Sfx) or 1
	end
end)

Roller.Start()
AuraRender.Start()
Prompts.Start()
WorldFX.Start()

-- Music: one track per biome mood, crossfaded.
local tracks: { [string]: Sound } = {}
local function track(name: string): Sound?
	local id = Sounds[name]
	if not id or id == "" then
		return nil
	end
	if not tracks[name] then
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = "rbxassetid://" .. id
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		tracks[name] = s
	end
	return tracks[name]
end

local function musicFor(biome: string): string
	if biome == "KernelPanic" or biome == "Blackout" then
		return "MusicPanic"
	elseif biome == "DataStorm" or biome == "Overclock" then
		return "MusicStorm"
	end
	return "MusicMain"
end

local function updateMusic()
	local want = musicFor(ReplicatedStorage:GetAttribute("Biome") or "Normal")
	local vol = 0.6 * (tonumber(Ctx.Data.Settings and Ctx.Data.Settings.Music) or 0.6)
	for name, s in tracks do
		if name ~= want then
			Kit.tween(s, 2, { Volume = 0 }, Enum.EasingStyle.Linear)
		end
	end
	local t = track(want)
	if t then
		if not t.IsPlaying then
			t:Play()
		end
		Kit.tween(t, 2, { Volume = vol }, Enum.EasingStyle.Linear)
	end
end
ReplicatedStorage:GetAttributeChangedSignal("Biome"):Connect(updateMusic)
Ctx.Changed.Event:Connect(updateMusic)

local first = Ctx.Request("Hello")
if first then
	Ctx.Set(first)
end
updateMusic()
