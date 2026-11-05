--!strict
-- Player save data: load with retries, session lock, autosave, save on leave and shutdown.
-- In Studio without API access the game still runs, it just doesn't save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Data = {}

export type Profile = {
	Rolls: number,
	Inv: { [string]: number }, -- aura id -> count
	Found: { [string]: number }, -- aura id -> first found (os.time)
	Aura: string?,
	Rig: string?,
	Rigs: { [string]: boolean },
	Scripts: { [string]: number }, -- script id -> owned count
	Active: { [string]: number }, -- script id -> seconds left
	Breach: number, -- pending x20 rolls
	Bits: number,
	NextRolls: { [string]: number }, -- one-shot scripts armed for the next rolls (script id -> count)
	Quest: { i: number, n: number }, -- questline index, progress
	Best: string?, -- rarest aura id
	Settings: { [string]: any },
	Lock: { job: string, t: number }?,
}

local function default(): Profile
	return {
		Rolls = 0,
		Inv = {},
		Found = {},
		Aura = nil,
		Rig = nil,
		Rigs = {},
		Scripts = {},
		Active = {},
		Breach = 0,
		Bits = 0,
		NextRolls = {},
		Quest = { i = 1, n = 0 },
		Best = nil,
		Settings = { Skip = 0, Sfx = 1, Music = 0.6, Others = true, Quick = false, Tut = false },
		Lock = nil,
	}
end

local STORE_NAME = "GlitchRNG_v1"
local LOCK_TIMEOUT = 300

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)

local profiles: { [Player]: Profile } = {}
local canSave: { [Player]: boolean } = {}

Data.Loaded = Instance.new("BindableEvent")

local function key(plr: Player): string
	return "p_" .. plr.UserId
end

-- Fill missing fields after schema changes.
local function reconcile(p: any): Profile
	local d = default() :: any
	for k, v in d do
		if p[k] == nil then
			p[k] = v
		end
	end
	for k, v in d.Settings do
		if p.Settings[k] == nil then
			p.Settings[k] = v
		end
	end
	return p
end

function Data.Load(plr: Player)
	local result: Profile? = nil
	local ok = false
	if store then
		for attempt = 1, 5 do
			local success, err = pcall(function()
				(store :: DataStore):UpdateAsync(key(plr), function(old: any)
					old = old or default()
					local lock = old.Lock
					if lock and lock.job ~= game.JobId and os.time() - lock.t < LOCK_TIMEOUT and attempt < 4 then
						return nil -- another server still holds it; retry
					end
					old.Lock = { job = game.JobId, t = os.time() }
					result = old
					return old
				end)
			end)
			if success and result then
				ok = true
				break
			end
			if not success then
				warn("[Data] load failed:", err)
			end
			task.wait(attempt)
		end
	end
	if not plr.Parent then
		return
	end
	profiles[plr] = reconcile(result or default())
	canSave[plr] = ok
	if not ok then
		warn("[Data] running without saving for", plr.Name)
	end
	Data.Loaded:Fire(plr)
end

function Data.Get(plr: Player): Profile?
	return profiles[plr]
end

function Data.Save(plr: Player, release: boolean)
	local p = profiles[plr]
	if not (p and store and canSave[plr]) then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(plr), function(old: any)
			if old and old.Lock and old.Lock.job ~= game.JobId then
				return nil -- someone else took over; never overwrite their data
			end
			p.Lock = if release then nil else { job = game.JobId, t = os.time() }
			return p
		end)
	end)
	if not ok then
		warn("[Data] save failed:", err)
	end
end

function Data.Init()
	Players.PlayerAdded:Connect(function(plr)
		Data.Load(plr)
	end)
	for _, plr in Players:GetPlayers() do
		task.spawn(Data.Load, plr)
	end
	Players.PlayerRemoving:Connect(function(plr)
		Data.Save(plr, true)
		profiles[plr] = nil
		canSave[plr] = nil
	end)
	game:BindToClose(function()
		local list = Players:GetPlayers()
		local left = #list
		for _, plr in list do
			task.spawn(function()
				Data.Save(plr, true)
				left -= 1
			end)
		end
		local t0 = os.clock()
		while left > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for plr in profiles do
				task.spawn(Data.Save, plr, false)
			end
		end
	end)
end

return Data
