--!strict
-- Server-wide biome cycle. State lives in ReplicatedStorage attributes:
--   Biome (id), BiomeEnds (workspace:GetServerTimeNow() when it ends, 0 for Normal),
--   BiomeNext (server time of the next biome check while Normal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Biome = {}

local rng = Random.new()
local current = "Normal"
local token = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

function Biome.Current(): string
	return current
end

function Biome.Get(): Config.Biome
	return Config.BiomeById[current]
end

function Biome.Set(id: string)
	local b = Config.BiomeById[id]
	if not b then
		return
	end
	token += 1
	local my = token
	current = id
	ReplicatedStorage:SetAttribute("Biome", id)
	if id == "Normal" then
		ReplicatedStorage:SetAttribute("BiomeEnds", 0)
		ReplicatedStorage:SetAttribute("BiomeNext", now() + Config.BiomeCheckEvery)
		return
	end
	ReplicatedStorage:SetAttribute("BiomeEnds", now() + b.duration)
	task.delay(b.duration, function()
		if token == my then
			Biome.Set("Normal")
		end
	end)
end

-- Roll every biome from rarest to most common; first hit starts.
local function check()
	local list = table.clone(Config.Biomes)
	table.sort(list, function(a, b)
		return a.chance > b.chance
	end)
	for _, b in list do
		if b.id ~= "Normal" and b.chance > 0 and rng:NextInteger(1, b.chance) == 1 then
			Biome.Set(b.id)
			return
		end
	end
	ReplicatedStorage:SetAttribute("BiomeNext", now() + Config.BiomeCheckEvery)
end

function Biome.Init()
	Biome.Set("Normal")
	task.spawn(function()
		while true do
			task.wait(1)
			local nextAt = ReplicatedStorage:GetAttribute("BiomeNext")
			if current == "Normal" and typeof(nextAt) == "number" and now() >= nextAt then
				check()
			end
		end
	end)
end

return Biome
