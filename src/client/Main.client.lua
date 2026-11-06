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
local PlayerList = require(script.Parent.UI.PlayerList)
local Roller = require(script.Parent.Roller)
local AuraRender = require(script.Parent.AuraRender)
local Prompts = require(script.Parent.Prompts)
local Announce = require(script.Parent.Announce)
local WorldFX = require(script.Parent.WorldFX)
local Tutorial = require(script.Parent.Tutorial)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

Hud.Start()
PlayerList.Start()

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

-- The local player's equipped Legendary+ aura plays its own theme; otherwise the biome track.
local function musicFor(biome: string): string
	local aura = game:GetService("Players").LocalPlayer:GetAttribute("Aura")
	if typeof(aura) == "string" and Sounds["Theme_" .. aura] and Sounds["Theme_" .. aura] ~= "" then
		return "Theme_" .. aura
	end
	if Sounds["Music" .. biome] and Sounds["Music" .. biome] ~= "" then
		return "Music" .. biome
	end
	return "MusicNormal"
end

local function updateMusic()
	local want = musicFor(ReplicatedStorage:GetAttribute("Biome") or "Normal")
	local vol = 0.6 * (tonumber(Ctx.Data.Settings and Ctx.Data.Settings.Music) or 0.6)
	for name, s in tracks do
		if name ~= want and name:sub(1, 3) ~= "Amb" then -- ambience is handled separately
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
-- Ambience under the music: city hum always, digital rain during Data Storm.
local function ambience()
	local vol = tonumber(Ctx.Data.Settings and Ctx.Data.Settings.Music) or 0.6
	local biome = (ReplicatedStorage:GetAttribute("Biome") or "Normal") :: string
	local levels: { [string]: number } = { AmbCity = 0.35, AmbStorm = if biome == "DataStorm" then 0.45 else 0 }
	for name, want in levels do
		local t = track(name)
		if t then
			if not t.IsPlaying then
				t:Play()
			end
			Kit.tween(t, 2, { Volume = want * vol }, Enum.EasingStyle.Linear)
		end
	end
end
local first = Ctx.Request("Hello")
if first then
	Ctx.Set(first)
end

-- The boot screen (ReplicatedFirst/LoadingScreen) asks about reduced flashing before the profile
-- arrives: save that choice, and tell the boot screen what is already saved.
local me = game:GetService("Players").LocalPlayer
local function syncCalm()
	local pick = me:GetAttribute("CalmPick")
	local s = Ctx.Data.Settings
	if s and typeof(pick) == "boolean" and (s.Calm == true) ~= pick then
		Ctx.Setting("Calm", pick)
	end
end
if Ctx.Data.Settings then
	me:SetAttribute("CalmSaved", Ctx.Data.Settings.Calm == true)
end
syncCalm()
me:GetAttributeChangedSignal("CalmPick"):Connect(syncCalm)

-- Music and ambience start once the boot screen (which plays its own theme) is gone.
task.spawn(function()
	while me:GetAttribute("Booting") == true do
		task.wait(0.1)
	end
	ReplicatedStorage:GetAttributeChangedSignal("Biome"):Connect(ambience)
	Ctx.Changed.Event:Connect(ambience)
	ReplicatedStorage:GetAttributeChangedSignal("Biome"):Connect(updateMusic)
	me:GetAttributeChangedSignal("Aura"):Connect(updateMusic)
	Ctx.Changed.Event:Connect(updateMusic)
	ambience()
	updateMusic()
end)

-- First-time players get the guided tour once their data has loaded.
Tutorial.Auto()
