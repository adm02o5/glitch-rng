--!strict
-- Glitch RNG: single source of game data (auras, tiers, biomes, gear, scripts).
-- Chances are "1 in N". Biome auras can only be rolled while their biome is active.

local Config = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Palette used by UI, world and VFX.
Config.Palette = {
	Bg = rgb(6, 7, 12),
	Panel = rgb(12, 14, 22),
	PanelHi = rgb(20, 23, 36),
	Line = rgb(38, 44, 66),
	Text = rgb(230, 236, 255),
	Dim = rgb(120, 130, 160),
	Cyan = rgb(0, 240, 255),
	Magenta = rgb(255, 43, 214),
	Red = rgb(255, 31, 61),
	Lime = rgb(80, 255, 140),
	Amber = rgb(255, 176, 32),
}

export type Tier = {
	id: string,
	name: string,
	min: number, -- tier starts at this "1 in N"
	color: Color3,
	cutscene: number, -- 0 none, 1 flash, 2 glitch, 3 breach, 4 crash, 5 singularity
}

-- Ordered from lowest to highest.
Config.Tiers = {
	{ id = "Basic", name = "BASIC", min = 1, color = rgb(170, 180, 200), cutscene = 0 },
	{ id = "Enhanced", name = "ENHANCED", min = 100, color = rgb(80, 255, 140), cutscene = 0 },
	{ id = "Rare", name = "RARE", min = 1000, color = rgb(0, 200, 255), cutscene = 1 },
	{ id = "Epic", name = "EPIC", min = 10000, color = rgb(170, 90, 255), cutscene = 2 },
	{ id = "Legendary", name = "LEGENDARY", min = 100000, color = rgb(255, 176, 32), cutscene = 3 },
	{ id = "Mythic", name = "MYTHIC", min = 1000000, color = rgb(255, 43, 214), cutscene = 4 },
	{ id = "Corrupted", name = "CORRUPTED", min = 10000000, color = rgb(255, 31, 61), cutscene = 4 },
	{ id = "Singularity", name = "SINGULARITY", min = 100000000, color = rgb(255, 255, 255), cutscene = 5 },
} :: { Tier }

export type Aura = {
	id: string,
	name: string,
	chance: number,
	color: Color3,
	color2: Color3,
	biome: string?, -- only rollable in this biome
	desc: string, -- flavour text shown in the index
	look: string, -- visual concept for AuraFX
}

-- Ordered from most common to rarest.
Config.Auras = {
	-- BASIC
	{ id = "Pixel", name = "Pixel", chance = 2, color = rgb(200, 210, 230), color2 = rgb(120, 130, 160),
		desc = "A single lit pixel. Everyone starts somewhere.", look = "few slow white square pixels drifting up" },
	{ id = "Static", name = "Static", chance = 4, color = rgb(160, 170, 190), color2 = rgb(90, 95, 110),
		desc = "TV noise that never quite tunes in.", look = "grey flickering noise specks around the body" },
	{ id = "Byte", name = "Byte", chance = 7, color = rgb(90, 200, 255), color2 = rgb(40, 90, 160),
		desc = "Eight bits of pure ambition.", look = "8 tiny cyan cubes orbiting the waist" },
	{ id = "Ping", name = "Ping", chance = 12, color = rgb(80, 255, 140), color2 = rgb(20, 120, 60),
		desc = "Pong.", look = "green radar pulse ring expanding from feet every 2s" },
	{ id = "Cookie", name = "Cookie", chance = 20, color = rgb(255, 196, 120), color2 = rgb(150, 90, 40),
		desc = "Tracks you across every server.", look = "warm crumbs and small hex icons orbiting" },
	{ id = "Cache", name = "Cache", chance = 32, color = rgb(120, 160, 255), color2 = rgb(50, 60, 160),
		desc = "Remembers things it shouldn't.", look = "stacked blue translucent panels floating behind back" },
	{ id = "Firewall", name = "Firewall", chance = 50, color = rgb(255, 120, 40), color2 = rgb(160, 30, 10),
		desc = "Burns anything that knocks.", look = "low orange digital flames at the feet with hex sparks" },
	{ id = "Lag", name = "Lag", chance = 75, color = rgb(190, 120, 255), color2 = rgb(80, 40, 140),
		desc = "Always a few frames behind.", look = "purple afterimage ghosts trailing the body" },

	-- ENHANCED
	{ id = "Packet", name = "Packet", chance = 128, color = rgb(0, 255, 200), color2 = rgb(0, 110, 120),
		desc = "Delivered. Eventually.", look = "teal data packets streaming in arcs over the head" },
	{ id = "Proxy", name = "Proxy", chance = 200, color = rgb(255, 230, 90), color2 = rgb(140, 100, 20),
		desc = "Not really here. Somewhere else.", look = "yellow mirrored silhouette offset beside the player" },
	{ id = "Bitrate", name = "Bitrate", chance = 333, color = rgb(80, 180, 255), color2 = rgb(255, 80, 200),
		desc = "Quality: auto.", look = "equalizer bars pulsing in a ring on the ground" },
	{ id = "Overflow", name = "Overflow", chance = 500, color = rgb(255, 70, 90), color2 = rgb(255, 200, 60),
		desc = "Too much. Way too much.", look = "red numbers spilling upward like a fountain" },
	{ id = "Malware", name = "Malware", chance = 750, color = rgb(120, 255, 60), color2 = rgb(20, 60, 10),
		desc = "Clicked the link.", look = "toxic green drips and skull-like hex glyphs" },

	-- RARE
	{ id = "Glitch", name = "Glitch", chance = 1000, color = rgb(0, 240, 255), color2 = rgb(255, 43, 214),
		desc = "The signature of the game. Reality tears.", look = "cyan/magenta RGB-split shards jittering around the body" },
	{ id = "Trojan", name = "Trojan", chance = 1500, color = rgb(255, 60, 60), color2 = rgb(40, 0, 0),
		desc = "A gift you should not have opened.", look = "red horse-head glyph hologram above, red sparks" },
	{ id = "PhantomPing", name = "Phantom Ping", chance = 2500, color = rgb(170, 255, 255), color2 = rgb(60, 120, 200),
		desc = "Notification from nobody.", look = "ghostly pale rings and floating notification badges" },
	{ id = "NeonPulse", name = "Neon Pulse", chance = 4000, color = rgb(255, 60, 220), color2 = rgb(80, 200, 255),
		desc = "The city's heartbeat.", look = "magenta neon tubes spiralling up the body, pulsing" },
	{ id = "Botnet", name = "Botnet", chance = 6500, color = rgb(120, 255, 120), color2 = rgb(20, 80, 20),
		desc = "Ten thousand machines say hi.", look = "swarm of small drones linked with beams" },
	{ id = "Cryptic", name = "Cryptic", chance = 8888, color = rgb(255, 215, 0), color2 = rgb(90, 60, 0),
		desc = "Encrypted with a key no one has.", look = "golden rotating cipher rings with symbols" },

	-- EPIC
	{ id = "Rootkit", name = "Rootkit", chance = 12500, color = rgb(170, 90, 255), color2 = rgb(30, 0, 60),
		desc = "Lives below the surface.", look = "purple roots of light crawling up from the ground" },
	{ id = "Datastorm", name = "Datastorm", chance = 20000, color = rgb(60, 255, 160), color2 = rgb(0, 80, 60),
		biome = "DataStorm", desc = "Born in the eye of the storm.", look = "green code rain swirling as a tornado" },
	{ id = "Hologram", name = "Hologram", chance = 30000, color = rgb(100, 220, 255), color2 = rgb(255, 255, 255),
		desc = "A projection that learned to stand.", look = "scanlines sweeping the body, blue projector cone from below" },
	{ id = "ZeroDay", name = "Zero Day", chance = 50000, color = rgb(255, 40, 40), color2 = rgb(0, 0, 0),
		desc = "No patch. No warning.", look = "black-red countdown digits orbiting, red lightning" },
	{ id = "Blackout", name = "Blackout", chance = 66666, color = rgb(255, 30, 30), color2 = rgb(10, 0, 0),
		biome = "Blackout", desc = "When the grid dies, it wakes.", look = "dark smoke aura with red emergency strobes" },
	{ id = "Chromatic", name = "Chromatic", chance = 85000, color = rgb(255, 0, 80), color2 = rgb(0, 160, 255),
		desc = "Every colour at once.", look = "rainbow-cycling prism rings and colour-split ghosts" },

	-- LEGENDARY
	{ id = "Mainframe", name = "Mainframe", chance = 125000, color = rgb(0, 200, 255), color2 = rgb(0, 40, 80),
		desc = "The machine that runs the machines.", look = "server-rack panels with blinking LEDs orbiting, cable beams" },
	{ id = "Quantum", name = "Quantum", chance = 250000, color = rgb(160, 120, 255), color2 = rgb(255, 255, 255),
		desc = "Both rolled and not rolled.", look = "electron orbit rings and superposition ghosts phasing" },
	{ id = "Overclocked", name = "Overclocked", chance = 400000, color = rgb(255, 140, 0), color2 = rgb(255, 255, 120),
		biome = "Overclock", desc = "Running at 300%. Smells like burning.", look = "orange heat haze, lightning arcs, fan-blade halo spinning fast" },
	{ id = "NeuralLink", name = "Neural Link", chance = 600000, color = rgb(255, 100, 200), color2 = rgb(100, 255, 255),
		desc = "Mind, meet machine.", look = "glowing neuron web around head with synapse sparks" },
	{ id = "Sentinel", name = "Sentinel", chance = 888888, color = rgb(255, 230, 140), color2 = rgb(0, 200, 255),
		desc = "The firewall's last guardian.", look = "hexagon shield plates orbiting, golden eye above" },

	-- MYTHIC
	{ id = "Kernel", name = "Kernel", chance = 1250000, color = rgb(255, 43, 214), color2 = rgb(0, 240, 255),
		desc = "Ring zero. Absolute control.", look = "concentric rings 0..3 around the body, core orb at chest" },
	{ id = "GhostProtocol", name = "Ghost Protocol", chance = 2500000, color = rgb(220, 240, 255), color2 = rgb(80, 100, 140),
		desc = "Disavowed. Invisible. Everywhere.", look = "body semi-transparent, white wisps, cloak of fading pixels" },
	{ id = "CyberSeraph", name = "Cyber Seraph", chance = 4444444, color = rgb(255, 255, 255), color2 = rgb(0, 240, 255),
		desc = "An angel compiled from light.", look = "six neon wings, halo of code, feather pixels falling" },
	{ id = "BlueScreen", name = "Blue Screen", chance = 7000000, color = rgb(30, 90, 255), color2 = rgb(255, 255, 255),
		desc = ":( Your PC ran into a problem.", look = "blue panels with sad face text orbiting, error popups" },

	-- CORRUPTED
	{ id = "Corruption", name = "Corruption", chance = 12000000, color = rgb(255, 31, 61), color2 = rgb(30, 0, 10),
		desc = "The save file is damaged. So are you.", look = "black-red tearing shards, ground cracks, inverted ghosts" },
	{ id = "KernelPanic", name = "Kernel Panic", chance = 25000000, color = rgb(255, 0, 0), color2 = rgb(255, 255, 255),
		biome = "KernelPanic", desc = "Only during total system failure.", look = "violent red glitch storm, warning triangles, shaking light" },
	{ id = "EventHorizon", name = "Event Horizon", chance = 50000000, color = rgb(255, 150, 40), color2 = rgb(0, 0, 0),
		desc = "Nothing escapes. Not even light.", look = "black hole orb above with accretion disc, particles sucked in" },
	{ id = "NullPointer", name = "Null Pointer", chance = 77777777, color = rgb(0, 0, 0), color2 = rgb(255, 255, 255),
		desc = "Points at nothing. Nothing points back.", look = "pure black void silhouette with white outline and inverted pixels" },

	-- SINGULARITY
	{ id = "Singularity", name = "Singularity", chance = 150000000, color = rgb(255, 255, 255), color2 = rgb(0, 240, 255),
		desc = "All data collapses into one point.", look = "white core star, galaxy spiral, gravitational rings, light beams" },
	{ id = "Architect", name = "The Architect", chance = 404000000, color = rgb(0, 255, 160), color2 = rgb(255, 255, 255),
		desc = "Wrote the world. Page not found.", look = "giant wireframe grid sphere, floating code pages, green god-rays" },
	{ id = "Redacted", name = "[REDACTED]", chance = 1000000000, color = rgb(0, 0, 0), color2 = rgb(255, 31, 61),
		desc = "████ ██ ███████ ████.", look = "black censor bars orbiting, red classified stamps, reality tearing" },
} :: { Aura }

Config.AuraById = {} :: { [string]: Aura }
for _, a in Config.Auras do
	Config.AuraById[a.id] = a
end

export type Biome = {
	id: string,
	name: string,
	chance: number, -- 1 in N per check (Normal is the fallback)
	duration: number, -- seconds
	luck: number, -- luck multiplier
	speed: number, -- roll speed multiplier
	color: Color3,
	desc: string,
}

Config.Biomes = {
	{ id = "Normal", name = "NORMAL", chance = 0, duration = 0, luck = 1, speed = 1, color = rgb(0, 240, 255),
		desc = "The city hums. Nothing unusual." },
	{ id = "DataStorm", name = "DATA STORM", chance = 6, duration = 240, luck = 1.25, speed = 1, color = rgb(60, 255, 160),
		desc = "Raw code rains from the sky." },
	{ id = "Overclock", name = "OVERCLOCK", chance = 8, duration = 180, luck = 1, speed = 1.5, color = rgb(255, 140, 0),
		desc = "Every machine runs hot. Rolls are faster." },
	{ id = "Blackout", name = "BLACKOUT", chance = 12, duration = 200, luck = 1.5, speed = 1, color = rgb(255, 30, 30),
		desc = "The grid is down. Luck grows in the dark." },
	{ id = "KernelPanic", name = "KERNEL PANIC", chance = 60, duration = 150, luck = 3, speed = 1.25, color = rgb(255, 0, 60),
		desc = "Total system failure. Reality is unstable." },
} :: { Biome }

Config.BiomeById = {} :: { [string]: Biome }
for _, b in Config.Biomes do
	Config.BiomeById[b.id] = b
end
Config.BiomeCheckEvery = 90 -- seconds between biome rolls while Normal

-- Rigs: hand gear. One equipped at a time.
export type Recipe = { [string]: number } -- auraId -> count consumed
export type Rig = {
	id: string,
	name: string,
	luck: number, -- additive (+0.25 = +25%)
	speed: number, -- additive
	color: Color3,
	recipe: Recipe,
	desc: string,
}

Config.Rigs = {
	{ id = "Wristband", name = "Wrist Band", luck = 0.1, speed = 0, color = rgb(0, 240, 255),
		recipe = { Pixel = 10, Static = 5, Byte = 3 }, desc = "A cheap smart band. +10% luck." },
	{ id = "Sniffer", name = "Packet Sniffer", luck = 0.25, speed = 0.1, color = rgb(0, 255, 200),
		recipe = { Packet = 2, Cache = 5, Ping = 8 }, desc = "Reads the odds as they fly by." },
	{ id = "Overclocker", name = "Overclocker", luck = 0.1, speed = 0.35, color = rgb(255, 140, 0),
		recipe = { Firewall = 6, Bitrate = 2, Overflow = 1 }, desc = "Liquid cooled. Rolls 35% faster." },
	{ id = "QuantumDeck", name = "Quantum Deck", luck = 0.75, speed = 0.15, color = rgb(160, 120, 255),
		recipe = { Glitch = 2, Trojan = 1, Malware = 3, Proxy = 4 }, desc = "Computes every outcome at once." },
	{ id = "KernelCore", name = "Kernel Core", luck = 1.5, speed = 0.25, color = rgb(255, 43, 214),
		recipe = { Rootkit = 1, Cryptic = 1, NeonPulse = 2, Botnet = 2 }, desc = "Ring-zero access to fate." },
	{ id = "ArchitectGlove", name = "Architect's Hand", luck = 3, speed = 0.4, color = rgb(0, 255, 160),
		recipe = { Mainframe = 1, ZeroDay = 1, Chromatic = 1, Hologram = 2 }, desc = "Rewrite the dice." },
} :: { Rig }

Config.RigById = {} :: { [string]: Rig }
for _, r in Config.Rigs do
	Config.RigById[r.id] = r
end

-- Scripts: consumable boosts.
export type Script = {
	id: string,
	name: string,
	luck: number, -- multiplier while active (1 = none)
	speed: number,
	duration: number, -- seconds; 0 = next roll only
	color: Color3,
	recipe: Recipe,
	desc: string,
}

Config.Scripts = {
	{ id = "Luck", name = "luck.exe", luck = 2, speed = 1, duration = 300, color = rgb(80, 255, 140),
		recipe = { Pixel = 6, Static = 4, Byte = 2 }, desc = "x2 luck for 5 minutes." },
	{ id = "Speed", name = "speed.exe", luck = 1, speed = 1.5, duration = 300, color = rgb(255, 176, 32),
		recipe = { Static = 6, Ping = 3, Cookie = 1 }, desc = "+50% roll speed for 5 minutes." },
	{ id = "Breach", name = "breach.exe", luck = 20, speed = 1, duration = 0, color = rgb(255, 31, 61),
		recipe = { Glitch = 1, Packet = 3, Lag = 4, Firewall = 4 }, desc = "Your next roll gets x20 luck." },
} :: { Script }

Config.ScriptById = {} :: { [string]: Script }
for _, s in Config.Scripts do
	Config.ScriptById[s.id] = s
end

-- Rolling.
Config.Roll = {
	Cooldown = 2.4, -- base seconds per roll (divided by speed)
	BonusEvery = 10, -- every Nth roll is a Boot Roll
	BonusLuck = 2,
	ServerAnnounce = 10000, -- chat message in this server at 1 in N or rarer
	GlobalAnnounce = 1000000, -- cross-server message at 1 in N or rarer
}

function Config.TierOf(chance: number): Tier
	local best = Config.Tiers[1]
	for _, t in Config.Tiers do
		if chance >= t.min then
			best = t
		end
	end
	return best
end

return Config
