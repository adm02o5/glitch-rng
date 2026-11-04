--!strict
-- Roll algorithm and number formatting shared by server and client.
-- Rolls check auras from rarest to most common: each one hits with probability luck / chance.
-- The first hit wins; if nothing hits, the most common aura is the result.

local Config = require(script.Parent.Config)

local RNG = {}

export type Stats = { luck: number, speed: number }

function RNG.Roll(luck: number, biome: string, rng: Random): Config.Aura
	local auras = Config.Auras
	for i = #auras, 2, -1 do
		local a = auras[i]
		if a.biome == nil or a.biome == biome then
			if rng:NextNumber() < luck / a.chance then
				return a
			end
		end
	end
	return auras[1]
end

-- Rollable auras in the given biome (for the reel animation and odds table).
function RNG.Pool(biome: string): { Config.Aura }
	local out = {}
	for _, a in Config.Auras do
		if a.biome == nil or a.biome == biome then
			table.insert(out, a)
		end
	end
	return out
end

local SUFFIX = { "", "K", "M", "B", "T", "Qd" }

-- 1234 -> "1,234"
function RNG.Commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

-- 1250000 -> "1.25M"
function RNG.Short(n: number): string
	local i = 1
	while n >= 1000 and i < #SUFFIX do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	local str = string.format(n >= 100 and "%.0f" or n >= 10 and "%.1f" or "%.2f", n)
	str = str:gsub("%.?0+$", "")
	return str .. SUFFIX[i]
end

function RNG.ChanceText(chance: number): string
	return "1 in " .. RNG.Commas(chance)
end

function RNG.Time(sec: number): string
	sec = math.max(0, math.floor(sec))
	local m = sec // 60
	local s = sec % 60
	if m >= 60 then
		return string.format("%d:%02d:%02d", m // 60, m % 60, s)
	end
	return string.format("%d:%02d", m, s)
end

return RNG
