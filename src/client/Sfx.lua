--!strict
-- Plays UI and cutscene sounds by name; volume follows the player's SFX setting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sounds"))

local Sfx = {}

Sfx.Volume = 1

local pool: { [string]: Sound } = {}

local function get(name: string): Sound?
	local id = Sounds[name]
	if not id or id == "" then
		return nil
	end
	local cached = pool[name]
	if cached then
		return cached
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = if id:find("://") then id else "rbxassetid://" .. id
	s.Parent = SoundService
	pool[name] = s
	return s
end

export type Opts = { volume: number?, pitch: number?, overlap: boolean? }

function Sfx.Play(name: string, o: Opts?)
	local base = get(name)
	if not base or Sfx.Volume <= 0 then
		return
	end
	local s = base
	if not (o and o.overlap == false) then
		s = base:Clone()
		s.Parent = SoundService
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
	s.Volume = (o and o.volume or 0.6) * Sfx.Volume
	s.PlaybackSpeed = o and o.pitch or 1
	s:Play()
end

return Sfx
