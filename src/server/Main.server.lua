--!strict
-- Server entry: remotes, rolling, crafting, boosts, announcements, leaderstats.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)

local Data = require(script.Parent.Data)
local Biome = require(script.Parent.Biome)
local Map = require(script.Parent.Map)
local Board = require(script.Parent.Board)
local NPC = require(script.Parent.NPC)

-- Remotes ------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local Request = Instance.new("RemoteFunction")
Request.Name = "Request"
Request.Parent = remotes
local Push = Instance.new("RemoteEvent")
Push.Name = "Push"
Push.Parent = remotes
remotes.Parent = ReplicatedStorage

local rng = Random.new()
local lastRoll: { [Player]: number } = {}
local rate: { [Player]: { t: number, n: number } } = {}

-- Stats ----------------------------------------------------------------------
type Stats = { luck: number, speed: number, rigLuck: number, scriptLuck: number, biomeLuck: number }

local function stats(p: Data.Profile): Stats
	local rig = p.Rig and Config.RigById[p.Rig]
	local rigLuck = 1 + (rig and rig.luck or 0)
	local speed = 1 + (rig and rig.speed or 0)
	local scriptLuck = 1
	for id, left in p.Active do
		local s = Config.ScriptById[id]
		if s and left > 0 then
			scriptLuck *= s.luck
			speed *= s.speed
		end
	end
	local b = Biome.Get()
	speed *= b.speed
	return {
		luck = rigLuck * scriptLuck * b.luck,
		speed = speed,
		rigLuck = rigLuck,
		scriptLuck = scriptLuck,
		biomeLuck = b.luck,
	}
end

local function view(p: Data.Profile)
	local s = stats(p)
	return {
		Rolls = p.Rolls,
		Inv = p.Inv,
		Found = p.Found,
		Aura = p.Aura,
		Rig = p.Rig,
		Rigs = p.Rigs,
		Scripts = p.Scripts,
		Active = p.Active,
		Breach = p.Breach,
		NextRolls = p.NextRolls,
		Best = p.Best,
		Settings = p.Settings,
		Bits = p.Bits,
		Quest = p.Quest,
		Luck = s.luck,
		Speed = s.speed,
		NextBoot = Config.Roll.BonusEvery - (p.Rolls % Config.Roll.BonusEvery),
	}
end

local function send(plr: Player)
	local p = Data.Get(plr)
	if p then
		Push:FireClient(plr, "Data", view(p))
	end
end

local function rarestText(p: Data.Profile): string
	local a = p.Best and Config.AuraById[p.Best]
	return a and ("1/" .. RNG.Short(a.chance)) or "-"
end

local function applyLook(plr: Player, p: Data.Profile)
	plr:SetAttribute("Aura", p.Aura or "")
	plr:SetAttribute("Rig", p.Rig or "")
	local ls = plr:FindFirstChild("leaderstats")
	if ls then
		(ls:FindFirstChild("Rolls") :: IntValue).Value = p.Rolls;
		(ls:FindFirstChild("Rarest") :: StringValue).Value = rarestText(p)
	end
end

-- Announcements -------------------------------------------------------------
local TOPIC = "GlitchRNG_Announce"

local function announce(name: string, auraId: string, global: boolean)
	Push:FireAllClients("Announce", { name = name, aura = auraId, global = global })
end

task.spawn(function()
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(msg)
			local d = msg.Data
			if typeof(d) == "table" and d.job ~= game.JobId and Config.AuraById[d.aura] then
				announce(tostring(d.name), d.aura, true)
			end
		end)
	end)
end)

-- Quests -------------------------------------------------------------------------
-- Advances the active quest when an event matches its goal. Progress is capped at the goal.
local function questEvent(p: Data.Profile, kind: string, tierIdx: number?, inBiome: boolean?)
	local q = Config.QuestAt(p.Quest.i)
	local g = q.goal
	if g.kind ~= kind or p.Quest.n >= g.n then
		return
	end
	if g.tier and (tierIdx or 0) < g.tier then
		return
	end
	if g.biome and not inBiome then
		return
	end
	p.Quest.n += 1
end

-- Actions --------------------------------------------------------------------
local Actions: { [string]: (Player, Data.Profile, any) -> any } = {}

function Actions.Roll(plr, p)
	local s = stats(p)
	local cd = Config.Roll.Cooldown / s.speed
	local t = os.clock()
	if t - (lastRoll[plr] or 0) < cd * 0.85 then
		return { ok = false }
	end
	lastRoll[plr] = t

	p.Rolls += 1
	local luck = s.luck
	local boot = p.Rolls % Config.Roll.BonusEvery == 0
	if boot then
		luck *= Config.Roll.BonusLuck
	end
	-- Old saves kept breach.exe in its own counter.
	if p.Breach > 0 then
		p.NextRolls.Breach = (p.NextRolls.Breach or 0) + p.Breach
		p.Breach = 0
	end
	-- Use the strongest armed one-shot script.
	local breach = false
	local bestId: string? = nil
	for id, n in p.NextRolls do
		local sc = Config.ScriptById[id]
		if sc and n > 0 and (not bestId or sc.luck > Config.ScriptById[bestId].luck) then
			bestId = id
		end
	end
	if bestId then
		p.NextRolls[bestId] -= 1
		if p.NextRolls[bestId] <= 0 then
			p.NextRolls[bestId] = nil
		end
		luck *= Config.ScriptById[bestId].luck
		breach = true
	end

	local aura = RNG.Roll(luck, Biome.Current(), rng)
	p.Inv[aura.id] = (p.Inv[aura.id] or 0) + 1
	local tier = Config.TierOf(aura.chance)
	local bits = Config.RollBits[tier.id] or 1
	p.Bits += bits
	questEvent(p, "roll", Config.TierIndex(aura.chance), Biome.Current() ~= "Normal")
	local first = p.Found[aura.id] == nil
	if first then
		p.Found[aura.id] = os.time()
	end
	local best = p.Best and Config.AuraById[p.Best]
	if not best or aura.chance > best.chance then
		p.Best = aura.id
	end
	if not p.Aura then
		p.Aura = aura.id
	end
	applyLook(plr, p)

	if aura.chance >= Config.Roll.ServerAnnounce then
		-- Let the roller's cutscene play before everyone else sees it.
		local delay = if aura.chance >= Config.Roll.GlobalAnnounce then 7 else 3
		task.delay(delay, function()
			announce(plr.DisplayName, aura.id, false)
			if aura.chance >= Config.Roll.GlobalAnnounce then
				pcall(function()
					MessagingService:PublishAsync(TOPIC, { job = game.JobId, name = plr.DisplayName, aura = aura.id })
				end)
			end
		end)
	end
	Board.Bump(plr, p.Rolls)
	send(plr)
	return { ok = true, aura = aura.id, boot = boot, breach = breach, boost = bestId, first = first, luck = luck, cd = cd, bits = bits }
end

function Actions.Equip(plr, p, id)
	if typeof(id) ~= "string" or (p.Inv[id] or 0) <= 0 then
		return false
	end
	p.Aura = id
	questEvent(p, "equip")
	applyLook(plr, p)
	send(plr)
	return true
end

local function hasRecipe(p: Data.Profile, recipe: Config.Recipe): boolean
	for id, n in recipe do
		if (p.Inv[id] or 0) < n then
			return false
		end
	end
	return true
end

local function consume(p: Data.Profile, recipe: Config.Recipe)
	for id, n in recipe do
		p.Inv[id] -= n
		if p.Inv[id] <= 0 then
			p.Inv[id] = nil
			if p.Aura == id then
				p.Aura = nil
			end
		end
	end
end

function Actions.CraftRig(plr, p, id)
	local rig = if typeof(id) == "string" then Config.RigById[id] else nil
	if not rig or p.Rigs[rig.id] or not hasRecipe(p, rig.recipe) then
		return false
	end
	consume(p, rig.recipe)
	p.Rigs[rig.id] = true
	p.Rig = rig.id
	questEvent(p, "craftRig")
	applyLook(plr, p)
	send(plr)
	return true
end

function Actions.EquipRig(plr, p, id)
	if id == nil or id == "" then
		p.Rig = nil
	elseif typeof(id) == "string" and p.Rigs[id] then
		p.Rig = id
	else
		return false
	end
	applyLook(plr, p)
	send(plr)
	return true
end

function Actions.CraftScript(plr, p, args)
	if typeof(args) ~= "table" then
		return false
	end
	local s = if typeof(args.id) == "string" then Config.ScriptById[args.id] else nil
	local amount = math.clamp(math.floor(tonumber(args.n) or 1), 1, 100)
	if not s then
		return false
	end
	local made = 0
	for _ = 1, amount do
		if not hasRecipe(p, s.recipe) then
			break
		end
		consume(p, s.recipe)
		made += 1
	end
	if made == 0 then
		return false
	end
	p.Scripts[s.id] = (p.Scripts[s.id] or 0) + made
	applyLook(plr, p)
	send(plr)
	return made
end

function Actions.UseScript(plr, p, id)
	local s = if typeof(id) == "string" then Config.ScriptById[id] else nil
	if not s or (p.Scripts[s.id] or 0) <= 0 then
		return false
	end
	-- storm.exe only works while no biome is running.
	if s.biome and Biome.Current() ~= "Normal" then
		return false
	end
	p.Scripts[s.id] -= 1
	if p.Scripts[s.id] <= 0 then
		p.Scripts[s.id] = nil
	end
	if s.biome then
		-- Random biome, weighted by how common it normally is.
		local total = 0
		for _, b in Config.Biomes do
			if b.chance > 0 then
				total += 1 / b.chance
			end
		end
		local r = rng:NextNumber() * total
		for _, b in Config.Biomes do
			if b.chance > 0 then
				r -= 1 / b.chance
				if r <= 0 then
					Biome.Set(b.id)
					break
				end
			end
		end
	elseif s.duration > 0 then
		p.Active[s.id] = (p.Active[s.id] or 0) + s.duration
	else
		p.NextRolls[s.id] = (p.NextRolls[s.id] or 0) + 1
	end
	questEvent(p, "useScript")
	send(plr)
	return true
end

local SETTINGS = { Skip = "number", Sfx = "number", Music = "number", Others = "boolean", Quick = "boolean" }

function Actions.Setting(plr, p, args)
	if typeof(args) ~= "table" or SETTINGS[args.k] == nil or typeof(args.v) ~= SETTINGS[args.k] then
		return false
	end
	local v = args.v
	if typeof(v) == "number" then
		v = math.clamp(v, 0, 10)
	end
	p.Settings[args.k] = v
	return true
end

function Actions.QuestClaim(plr, p)
	local q = Config.QuestAt(p.Quest.i)
	if p.Quest.n < q.goal.n then
		return false
	end
	p.Bits += q.bits
	for id, n in (q.scripts or {}) :: { [string]: number } do
		p.Scripts[id] = (p.Scripts[id] or 0) + n
	end
	p.Quest = { i = p.Quest.i + 1, n = 0 }
	send(plr)
	return { bits = q.bits, scripts = q.scripts }
end

function Actions.ShopBuy(plr, p, id)
	local item = nil
	for _, it in Config.Shop do
		if it.id == id then
			item = it
		end
	end
	if not item or p.Bits < item.price then
		return false
	end
	p.Bits -= item.price
	p.Scripts[item.id] = (p.Scripts[item.id] or 0) + 1
	send(plr)
	return true
end

function Actions.Hello(plr, p)
	return view(p)
end

-- Admin panel (server-checked by UserId).
local function isAdmin(plr: Player): boolean
	return Config.Admins[plr.UserId] == true
end

-- Wear any aura for show without owning it; "" goes back to the saved one.
function Actions.AdminWear(plr, p, id)
	if not isAdmin(plr) then
		return false
	end
	if id == nil or id == "" then
		plr:SetAttribute("Aura", p.Aura or "")
		return true
	end
	if typeof(id) ~= "string" or not Config.AuraById[id] then
		return false
	end
	plr:SetAttribute("Aura", id)
	return true
end

function Actions.AdminBiome(plr, _p, id)
	if not isAdmin(plr) or typeof(id) ~= "string" or not Config.BiomeById[id] then
		return false
	end
	Biome.Set(id)
	return true
end

function Actions.AdminGive(plr, p, args)
	if not isAdmin(plr) or typeof(args) ~= "table" or typeof(args.id) ~= "string" or not Config.AuraById[args.id] then
		return false
	end
	local n = math.clamp(math.floor(tonumber(args.n) or 1), 1, 1000)
	p.Inv[args.id] = (p.Inv[args.id] or 0) + n
	p.Found[args.id] = p.Found[args.id] or os.time()
	send(plr)
	return true
end

-- Studio-only test helpers.
if RunService:IsStudio() then
	function Actions.DebugBiome(_plr, _p, id)
		Biome.Set(tostring(id))
		return true
	end
	function Actions.DebugGive(plr, p, args)
		if typeof(args) == "table" and Config.AuraById[args.id] then
			p.Inv[args.id] = (p.Inv[args.id] or 0) + (tonumber(args.n) or 1)
			p.Found[args.id] = p.Found[args.id] or os.time()
			send(plr)
		end
		return true
	end
end

Request.OnServerInvoke = function(plr: Player, action: any, args: any)
	local t = os.clock()
	local r = rate[plr]
	if r == nil or t - r.t > 1 then
		r = { t = t, n = 0 }
		rate[plr] = r
	end
	local rr = r :: { t: number, n: number }
	rr.n += 1
	if rr.n > 20 then
		return nil
	end
	local p = Data.Get(plr)
	local fn = if typeof(action) == "string" then Actions[action] else nil
	if not (p and fn) then
		return nil
	end
	local ok, res = pcall(fn, plr, p, args)
	if not ok then
		warn("[Request]", action, res)
		return nil
	end
	return res
end

-- Players ----------------------------------------------------------------------
local function setupStats(plr: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local rolls = Instance.new("IntValue")
	rolls.Name = "Rolls"
	rolls.Parent = ls
	local rarest = Instance.new("StringValue")
	rarest.Name = "Rarest"
	rarest.Value = "-"
	rarest.Parent = ls
	ls.Parent = plr
end

Players.PlayerAdded:Connect(setupStats)
for _, plr in Players:GetPlayers() do
	setupStats(plr)
end

Data.Loaded.Event:Connect(function(plr: Player)
	local p = Data.Get(plr)
	if not p then
		return
	end
	applyLook(plr, p)
	plr:SetAttribute("Admin", isAdmin(plr))
	plr:SetAttribute("Loaded", true)
	send(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
	lastRoll[plr] = nil
	rate[plr] = nil
end)

-- Boost timers tick only while the player is online.
task.spawn(function()
	while true do
		task.wait(1)
		for _, plr in Players:GetPlayers() do
			local p = Data.Get(plr)
			if p and next(p.Active) then
				local expired = false
				for id, left in p.Active do
					left -= 1
					if left > 0 then
						p.Active[id] = left
					else
						p.Active[id] = nil
						expired = true
					end
				end
				-- Clients count down on their own; only resync when a boost ends.
				if expired then
					send(plr)
				end
			end
		end
	end
end)

-- Clients compute luck from biome too, so push data when it changes.
ReplicatedStorage:GetAttributeChangedSignal("Biome"):Connect(function()
	for _, plr in Players:GetPlayers() do
		send(plr)
	end
end)

-- Player data first: a failure while building the world must never block loading players.
Data.Init()
Biome.Init()
local ok, err = pcall(function()
	Map.Build()
end)
if not ok then
	warn("[Map] build failed:", err)
end
Board.Init()
task.spawn(NPC.Build)
