--!strict
-- Tier cutscenes, played by Roller after the name reel stops and before the result card.
--
--   1 RARE        edge flash, vignette pulse, FOV punch, small burst
--   2 EPIC        glitch overlay (RGB-split bars + block noise), shake, colour-correction pulse, burst
--   3 LEGENDARY   letterbox, orbit camera, dimmed world, hacker terminal trace, glitch spike, white-out
--   4 MYTHIC /    escalating glitch + error popups, full "system crash" screen (BSOD / corrupted),
--     CORRUPTED   counter to 100%, cracks, screen shatters into flying shards, low-angle hero shot
--   5 SINGULARITY fade to black + silence, a white point grows with rings, camera rises into the sky and
--                 dives back, the aura name is spelled out huge with RGB split, final white-out
--
-- Everything is driven by os.clock() on RenderStepped (no drifting wait chains). All instances, Lighting
-- effects, camera state, HUD state and ducked music are restored in cleanup, even if a step errors.
-- Players can skip level >= 3 with a click/tap unless it is the first time they get the aura.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local RNG = require(Shared.RNG)

local Kit = require(script.Parent.UI.Kit)
local Sfx = require(script.Parent.Sfx)

local P = Kit.P
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local player = Players.LocalPlayer

local CAM_KEY = "GlitchCutsceneCam"
local UNSHAKE_KEY = "GlitchCutsceneUnshake"
local SKIP = { "skip" } -- unique error value used to unwind a level when the player skips

export type Info = { first: boolean?, boot: boolean?, breach: boolean? }

local Cutscene = {}

--------------------------------------------------------------------------------------------------------
-- Math helpers
--------------------------------------------------------------------------------------------------------

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
local function seg(x: number, a: number, b: number): number
	return clamp01((x - a) / (b - a))
end
local function outCubic(t: number): number
	return 1 - (1 - t) ^ 3
end
local function inCubic(t: number): number
	return t ^ 3
end
local function inOutCubic(t: number): number
	return if t < 0.5 then 4 * t ^ 3 else 1 - (-2 * t + 2) ^ 3 / 2
end
local function outQuart(t: number): number
	return 1 - (1 - t) ^ 4
end
local function inQuart(t: number): number
	return t ^ 4
end
local function inOutSine(t: number): number
	return -(math.cos(math.pi * t) - 1) / 2
end
local function outBack(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
local function outExpo(t: number): number
	return if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
end
local function bump(t: number): number
	return math.sin(math.pi * clamp01(t))
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return f.Unit
end

local function brightness(c: Color3): number
	return c.R + c.G + c.B
end

-- A colour that reads as light on black (dark auras fall back to their second colour or white).
local function glowColor(a: Config.Aura): Color3
	if brightness(a.color) > 0.7 then
		return a.color
	elseif brightness(a.color2) > 0.7 then
		return a.color2
	end
	return WHITE
end

local function spaced(s: string): string
	local out = {}
	for _, cp in utf8.codes(s) do
		table.insert(out, utf8.char(cp))
	end
	return table.concat(out, " ")
end

local GARBAGE = {
	"#", "$", "%", "&", "@", "!", "?", "/", "\\", "|", "<", ">", "{", "}", "[", "]",
	"=", "+", "*", "^", "~", "0", "1", "X", "Z", "_", ";", ":",
}

local function corrupt(rng: Random, s: string, amount: number): string
	if amount <= 0 then
		return s
	end
	local out = {}
	for _, cp in utf8.codes(s) do
		local ch = utf8.char(cp)
		if ch ~= " " and rng:NextNumber() < amount then
			table.insert(out, GARBAGE[rng:NextInteger(1, #GARBAGE)])
		else
			table.insert(out, ch)
		end
	end
	return table.concat(out)
end

local function hex(rng: Random, digits: number): string
	local t = {}
	for i = 1, digits do
		t[i] = string.format("%X", rng:NextInteger(0, 15))
	end
	return table.concat(t)
end

local function uiScale(): number
	local cam = workspace.CurrentCamera
	local v = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
	return math.clamp(math.min(v.X / 1600, v.Y / 900), 0.55, 1.15)
end

local function lazyModule(parent: Instance, name: string): any
	local m = parent:FindFirstChild(name)
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok then
			return mod
		end
	end
	return nil
end

--------------------------------------------------------------------------------------------------------
-- Session: one running cutscene with everything it owns
--------------------------------------------------------------------------------------------------------

local Session = {}
Session.__index = Session

local function newSession(aura: Config.Aura, info: Info, level: number): any
	local S: any = setmetatable({}, Session)
	S.aura = aura
	S.info = info
	S.level = level
	S.tier = Config.TierOf(aura.chance)
	S.rng = Random.new()
	S.start = os.clock()
	S.cursor = S.start
	S.skipped = false
	S.canSkip = level >= 3 and not info.first
	S.conns = {} :: { RBXScriptConnection }
	S.loops = {} :: { [number]: (number, number) -> boolean? }
	S.loopId = 0
	S.effects = {} :: { Instance }
	S.shake = 0
	S.fovPunch = 0
	S.vs = uiScale()

	local cam = workspace.CurrentCamera
	S.cam = cam
	S.saved = {
		type = cam.CameraType,
		subject = cam.CameraSubject,
		cf = cam.CFrame,
		fov = cam.FieldOfView,
	}
	S.lastFocus = cam.Focus.Position

	-- Biome context: exclusive auras name their own biome, everything else names the active one.
	local biomeId: string = aura.biome or (ReplicatedStorage:GetAttribute("Biome") :: string?) or "Normal"
	local biome = Config.BiomeById[biomeId] or Config.BiomeById.Normal
	S.biome = biome
	S.biomeName = if biome then biome.name else "NORMAL"
	S.biomeColor = if biome then biome.color else P.Cyan
	S.exclusive = aura.biome ~= nil

	local gui = Instance.new("ScreenGui")
	gui.Name = "GlitchCutscene"
	gui.DisplayOrder = 60
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	S.gui = gui

	-- Master per-frame loop for every effect updater.
	table.insert(
		S.conns,
		RunService.RenderStepped:Connect(function(dt)
			local now = os.clock()
			for id, fn in S.loops do
				local ok, res = pcall(fn, now, dt)
				if not ok then
					S.loops[id] = nil
					warn("[Cutscene] effect loop error: " .. tostring(res))
				elseif res == true then
					S.loops[id] = nil
				end
			end
		end)
	)

	-- Camera driver: scripted camera, FOV punch and shake (shake is undone before the default camera
	-- script runs next frame, so rotational shake never accumulates into the player's camera).
	RunService:BindToRenderStep(UNSHAKE_KEY, Enum.RenderPriority.First.Value, function()
		if S.preShake then
			S.cam.CFrame = S.preShake
			S.preShake = nil
		end
	end)
	RunService:BindToRenderStep(CAM_KEY, Enum.RenderPriority.Camera.Value + 1, function()
		local c = S.cam
		local now = os.clock()
		if S.camFn then
			local ok, cf, fov = pcall(S.camFn, now)
			if ok then
				if cf then
					c.CFrame = cf
				end
				if fov then
					c.FieldOfView = fov
				end
			end
		else
			c.FieldOfView = S.saved.fov + S.fovPunch
		end
		local s = S.shake
		if s > 0.001 then
			local rx = math.noise(now * 19, 1.7) * s * 1.8
			local ry = math.noise(now * 21, 5.3) * s * 1.8
			local rz = math.noise(now * 15, 9.1) * s * 2.6
			local tx = math.noise(now * 23, 3.3) * s * 0.35
			local ty = math.noise(now * 25, 7.7) * s * 0.35
			S.preShake = c.CFrame
			c.CFrame = c.CFrame * CFrame.new(tx, ty, 0) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
		end
	end)

	-- Skip input + hint.
	if S.canSkip then
		table.insert(
			S.conns,
			UserInputService.InputBegan:Connect(function(input)
				if not S.canSkip or os.clock() - S.start < 0.4 then
					return
				end
				local t = input.UserInputType
				if
					t == Enum.UserInputType.MouseButton1
					or t == Enum.UserInputType.Touch
					or input.KeyCode == Enum.KeyCode.ButtonA
				then
					S.skipped = true
				end
			end)
		)
		local hint = S:text({
			Name = "SkipHint",
			Text = "CLICK TO SKIP  >>",
			FontFace = Kit.MonoBold,
			TextSize = math.floor(13 * S.vs + 0.5),
			TextColor3 = P.Dim,
			TextTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -18),
			Size = UDim2.fromOffset(260, 20),
			ZIndex = 190,
		})
		Kit.new("UIStroke", { Thickness = 1.5, Color = BLACK, Transparency = 0.4, Parent = hint })
		S.hint = hint
		S:loop(function(now: number)
			local e = now - S.start
			hint.TextTransparency = 1 - seg(e, 0.5, 1.1) * (0.45 + 0.2 * math.sin(now * 4))
		end)
	end

	return S
end

-- Generic per-frame updater. Return true from fn to remove it.
function Session.loop(S: any, fn: (number, number) -> boolean?): number
	S.loopId += 1
	S.loops[S.loopId] = fn
	return S.loopId
end

function Session.unloop(S: any, id: number)
	S.loops[id] = nil
end

-- Timeline step: runs fn(alpha, elapsed) every frame for dur seconds. Phases are chained on an absolute
-- cursor, so a slow frame never pushes the rest of the cutscene back. Skipping unwinds the level.
function Session.phase(S: any, dur: number, fn: ((number, number) -> ())?)
	local t0 = S.cursor
	local t1 = t0 + dur
	S.cursor = t1
	while true do
		if S.skipped then
			error(SKIP, 0)
		end
		local now = os.clock()
		local e = math.min(now - t0, dur)
		if fn then
			fn(if dur > 0 then clamp01(e / dur) else 1, e)
		end
		if now >= t1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

-- Real-time step that ignores skipping (used for outros after the cut).
function Session.raw(_S: any, dur: number, fn: (number, number) -> ())
	local t0 = os.clock()
	while true do
		local e = math.min(os.clock() - t0, dur)
		fn(clamp01(e / dur), e)
		if e >= dur then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

function Session.frame(S: any, props: { [string]: any }): any
	local p: { [string]: any } = {
		BorderSizePixel = 0,
		BackgroundColor3 = BLACK,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		p[k] = v
	end
	if p.Parent == nil then
		p.Parent = S.gui
	end
	return Kit.new("Frame", p)
end

function Session.text(S: any, props: { [string]: any }): any
	local p: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = Kit.Mono,
		TextColor3 = P.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}
	for k, v in props do
		p[k] = v
	end
	if p.Parent == nil then
		p.Parent = S.gui
	end
	return Kit.new("TextLabel", p)
end

function Session.sfx(S: any, name: string, volume: number?, pitch: number?)
	if S.skipped then
		return
	end
	pcall(Sfx.Play, name, { volume = volume or 0.6, pitch = pitch or 1 })
end

function Session.focusPos(S: any): Vector3
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		S.lastFocus = root.Position
		S.lastLook = root.CFrame.LookVector
	end
	return S.lastFocus
end

function Session.focusLook(S: any): Vector3
	S:focusPos()
	return flat(S.lastLook or S.saved.cf.LookVector * -1)
end

-- Keeps the camera on the near side of walls between the target and the wanted position.
function Session.safe(S: any, target: Vector3, desired: Vector3): Vector3
	local dir = desired - target
	if dir.Magnitude < 0.05 then
		return desired
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex: { Instance } = { S.gui }
	if player.Character then
		table.insert(ex, player.Character)
	end
	params.FilterDescendantsInstances = ex
	params.IgnoreWater = true
	local hit = workspace:Raycast(target, dir, params)
	if hit then
		return hit.Position - dir.Unit * 0.7
	end
	return desired
end

function Session.burst(S: any, scale: number?)
	if S.skipped then
		return
	end
	local pos = S:focusPos()
	local id = S.aura.id
	task.spawn(function()
		local fx = lazyModule(Shared, "AuraFX")
		if fx and type(fx.Burst) == "function" then
			local ok, err = pcall(fx.Burst, pos, id, scale)
			if not ok then
				warn("[Cutscene] AuraFX.Burst failed: " .. tostring(err))
			end
		end
	end)
end

function Session.worldFlash(S: any, color: Color3, duration: number)
	if S.skipped then
		return
	end
	local parent = script.Parent
	task.spawn(function()
		local fx = if parent then lazyModule(parent, "WorldFX") else nil
		if fx and type(fx.Flash) == "function" then
			local ok, err = pcall(fx.Flash, color, duration)
			if not ok then
				warn("[Cutscene] WorldFX.Flash failed: " .. tostring(err))
			end
		end
	end)
end

function Session.cc(S: any): ColorCorrectionEffect
	local c = Instance.new("ColorCorrectionEffect")
	c.Name = "GlitchCutsceneCC"
	c.Parent = Lighting
	table.insert(S.effects, c)
	return c
end

function Session.blur(S: any): BlurEffect
	local b = Instance.new("BlurEffect")
	b.Name = "GlitchCutsceneBlur"
	b.Size = 0
	b.Parent = Lighting
	table.insert(S.effects, b)
	return b
end

function Session.clearEffects(S: any)
	for _, e in S.effects do
		pcall(function()
			e:Destroy()
		end)
	end
	S.effects = {}
end

function Session.hideHud(S: any)
	if S.hudSaved == nil then
		S.hudSaved = Kit.Gui.Enabled
		Kit.Gui.Enabled = false
	end
end

function Session.restoreHud(S: any)
	if S.hudSaved ~= nil then
		Kit.Gui.Enabled = S.hudSaved
		S.hudSaved = nil
	end
end

-- Takes over the camera; fn(now) -> (CFrame?, fov?) runs right after the default camera every frame.
function Session.takeCamera(S: any, fn: (number) -> (CFrame?, number?))
	S.cam.CameraType = Enum.CameraType.Scriptable
	S.camFn = fn
end

function Session.restoreCamera(S: any)
	if S.cameraRestored then
		return
	end
	S.cameraRestored = true
	S.camFn = nil
	S.shake = 0
	S.fovPunch = 0
	pcall(function()
		RunService:UnbindFromRenderStep(CAM_KEY)
	end)
	pcall(function()
		RunService:UnbindFromRenderStep(UNSHAKE_KEY)
	end)
	local c = S.cam
	local sv = S.saved
	pcall(function()
		if S.preShake then
			c.CFrame = S.preShake
			S.preShake = nil
		end
		c.CameraType = sv.type
		local subject = sv.subject
		if not (subject and subject.Parent) then
			local ch = player.Character
			subject = ch and ch:FindFirstChildOfClass("Humanoid")
		end
		if subject then
			c.CameraSubject = subject
		end
		c.CFrame = sv.cf
		c.FieldOfView = sv.fov
	end)
end

-- Music silence: scales every looping sound in SoundService by k (originals restored in cleanup).
function Session.duck(S: any, k: number)
	if not S.ducked then
		S.ducked = {}
		for _, d in SoundService:GetDescendants() do
			if d:IsA("Sound") and d.Looped and d.IsPlaying then
				S.ducked[d] = d.Volume
			end
		end
	end
	for s, v in S.ducked do
		if s.Parent then
			s.Volume = v * k
		end
	end
end

function Session.unduck(S: any)
	if S.ducked then
		for s, v in S.ducked do
			pcall(function()
				s.Volume = v
			end)
		end
		S.ducked = nil
	end
end

-- At a full-screen white peak: drop every overlay but `keep`, restore world/camera/HUD underneath.
function Session.peakCut(S: any, keep: Instance?)
	S.canSkip = false
	for _, ch in S.gui:GetChildren() do
		if ch ~= keep then
			ch:Destroy()
		end
	end
	S.loops = {}
	S:clearEffects()
	S:restoreCamera()
	S:restoreHud()
end

function Session.cleanup(S: any)
	S.canSkip = false
	for _, c in S.conns do
		pcall(function()
			c:Disconnect()
		end)
	end
	S.conns = {}
	S.loops = {}
	S:restoreCamera()
	S:restoreHud()
	S:clearEffects()
	S:unduck()
	pcall(function()
		S.gui:Destroy()
	end)
end

--------------------------------------------------------------------------------------------------------
-- Overlay building blocks
--------------------------------------------------------------------------------------------------------

-- Four gradient strips hugging the screen edges (edge glow or vignette). Fade with setT.
function Session.edges(S: any, color: Color3, depth: number, z: number): { Frame }
	local list = {}
	local seq = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	local specs = {
		{ size = UDim2.fromScale(1, depth), pos = UDim2.fromScale(0, 0), anchor = Vector2.new(0, 0), rot = 90 },
		{ size = UDim2.fromScale(1, depth), pos = UDim2.fromScale(0, 1), anchor = Vector2.new(0, 1), rot = -90 },
		{ size = UDim2.fromScale(depth * 0.62, 1), pos = UDim2.fromScale(0, 0), anchor = Vector2.new(0, 0), rot = 0 },
		{ size = UDim2.fromScale(depth * 0.62, 1), pos = UDim2.fromScale(1, 0), anchor = Vector2.new(1, 0), rot = 180 },
	}
	for _, sp in specs do
		local f = S:frame({
			Name = "Edge",
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			Size = sp.size,
			Position = sp.pos,
			AnchorPoint = sp.anchor,
			ZIndex = z,
		})
		Kit.new("UIGradient", { Transparency = seq, Rotation = sp.rot, Parent = f })
		table.insert(list, f)
	end
	return list
end

local function setT(list: { Frame }, t: number)
	local v = clamp01(t)
	for _, f in list do
		f.BackgroundTransparency = v
	end
end

local function setC(list: { Frame }, c: Color3)
	for _, f in list do
		f.BackgroundColor3 = c
	end
end

-- Full-screen digital glitch: paired RGB-split bars, block noise and black tear strips. Drive with g.k (0..1+).
function Session.glitchLayer(S: any, z: number): any
	local holder = S:frame({ Name = "Glitch", BackgroundTransparency = 1, ZIndex = z, Visible = false })
	local g: any = { k = 0, nextTick = 0, holder = holder }
	local palette = { P.Cyan, P.Magenta, P.Red, WHITE, S.tier.color, S.aura.color, S.aura.color2 }
	local bars: { Frame } = {}
	local blocks: { Frame } = {}
	local tears: { Frame } = {}
	for i = 1, 32 do
		bars[i] = Kit.new("Frame", { BorderSizePixel = 0, Visible = false, ZIndex = 2 + i % 2, Parent = holder })
	end
	for i = 1, 44 do
		blocks[i] = Kit.new("Frame", { BorderSizePixel = 0, Visible = false, ZIndex = 4, Parent = holder })
	end
	for i = 1, 5 do
		tears[i] = Kit.new("Frame", {
			BorderSizePixel = 0,
			Visible = false,
			BackgroundColor3 = BLACK,
			Size = UDim2.fromScale(1, 0.01),
			ZIndex = 1,
			Parent = holder,
		})
	end
	S:loop(function(now: number)
		local k = g.k
		holder.Visible = k > 0.01
		if k <= 0.01 or now < g.nextTick then
			return
		end
		local rng = S.rng
		g.nextTick = now + rng:NextNumber(0.025, 0.06) / (0.6 + k * 0.6)
		local kk = math.min(k, 1.4)
		for i = 1, #bars, 2 do
			local a, b = bars[i], bars[i + 1]
			if rng:NextNumber() < kk * 0.8 then
				local y = rng:NextNumber(-0.02, 1)
				local h = 0.002 + rng:NextNumber() ^ 2.2 * 0.07 * kk
				local w = rng:NextNumber(0.25, 1.3)
				local x = rng:NextNumber(-0.3, 1) * (1 - w * 0.5)
				local split = rng:NextNumber(0.003, 0.02) * (0.5 + kk)
				local tr = 1 - rng:NextNumber(0.2, 0.65) * math.min(1, kk + 0.25)
				local c = palette[rng:NextInteger(1, #palette)]
				a.Visible = true
				b.Visible = true
				a.Position = UDim2.fromScale(x - split, y)
				b.Position = UDim2.fromScale(x + split, y + rng:NextNumber(-0.002, 0.002))
				a.Size = UDim2.fromScale(w, h)
				b.Size = UDim2.fromScale(w * rng:NextNumber(0.85, 1.1), h)
				a.BackgroundColor3 = P.Cyan:Lerp(c, 0.35)
				b.BackgroundColor3 = P.Magenta:Lerp(c, 0.25)
				a.BackgroundTransparency = tr
				b.BackgroundTransparency = math.min(1, tr + 0.08)
			else
				a.Visible = false
				b.Visible = false
			end
		end
		for _, bl in blocks do
			if rng:NextNumber() < kk * 0.55 then
				bl.Visible = true
				local w = rng:NextNumber(0.008, 0.03 + 0.1 * kk)
				local h = rng:NextNumber(0.006, 0.02 + 0.05 * kk)
				bl.Size = UDim2.fromScale(w, h)
				bl.Position = UDim2.fromScale(rng:NextNumber(-0.02, 1), rng:NextNumber(-0.02, 1))
				local dark = rng:NextNumber() < 0.3
				bl.BackgroundColor3 = if dark then BLACK else palette[rng:NextInteger(1, #palette)]
				bl.BackgroundTransparency = if dark then rng:NextNumber(0.05, 0.4) else rng:NextNumber(0.3, 0.8)
			else
				bl.Visible = false
			end
		end
		for _, t in tears do
			if rng:NextNumber() < kk * 0.35 then
				t.Visible = true
				t.Position = UDim2.fromScale(0, rng:NextNumber())
				t.Size = UDim2.fromScale(1, rng:NextNumber(0.003, 0.025) * kk)
				t.BackgroundTransparency = rng:NextNumber(0.1, 0.5)
			else
				t.Visible = false
			end
		end
		return false
	end)
	return g
end

-- Cinematic bars with a live ticker on top and the tier name spelled on the bottom. Drive with L.k.
function Session.letterbox(S: any, z: number, topText: string, bottomText: string, accent: Color3): any
	local H = 0.105
	local fs = math.floor(13 * S.vs + 0.5)
	local top = S:frame({ Name = "LetterTop", Size = UDim2.fromScale(1, H), Position = UDim2.fromScale(0, -H), ZIndex = z })
	local bot = S:frame({
		Name = "LetterBottom",
		Size = UDim2.fromScale(1, H),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1 + H),
		ZIndex = z,
	})
	for _, f in { top, bot } do
		local line = Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = accent,
			Size = UDim2.new(1, 0, 0, 2),
			AnchorPoint = Vector2.new(0, if f == top then 1 else 0),
			Position = UDim2.fromScale(0, if f == top then 1 else 0),
			Parent = f,
		})
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.2),
				NumberSequenceKeypoint.new(0.8, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = line,
		})
	end
	S:text({
		Text = topText,
		FontFace = Kit.MonoBold,
		TextSize = fs,
		TextColor3 = accent:Lerp(WHITE, 0.3),
		Position = UDim2.new(0, 28, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(0.7, 0, 0, fs + 4),
		Parent = top,
	})
	local rec = S:text({
		Text = "",
		FontFace = Kit.MonoBold,
		TextSize = fs,
		TextColor3 = P.Red,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -28, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.new(0.3, 0, 0, fs + 4),
		Parent = top,
	})
	S:text({
		Text = bottomText,
		FontFace = Kit.Title,
		TextSize = math.floor(16 * S.vs + 0.5),
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = bot,
	})
	local L: any = { k = 0, top = top, bot = bot }
	S:loop(function(now: number)
		local k = L.k
		top.Position = UDim2.fromScale(0, -H * (1 - k))
		bot.Position = UDim2.fromScale(0, 1 + H * (1 - k))
		local blink = (now * 2) % 1 < 0.6
		rec.Text = (if blink then "REC  " else "     ") .. string.format("T+%05.2f", now - S.start)
		return false
	end)
	return L
end

-- Hacker terminal panel. T.add(text, color) adds a line; progress bar at the bottom.
function Session.terminal(S: any, nLines: number, z: number): any
	local tc = S.tier.color
	local lineH = 26
	local w = 620
	local h = 48 + nLines * lineH + 58
	local panel = Kit.panel(S.gui, {
		Name = "Terminal",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.045, 0.55),
		Size = UDim2.fromOffset(w, h),
		ZIndex = z,
		BackgroundTransparency = 0.08,
	}, tc)
	local sc = Kit.new("UIScale", { Scale = S.vs * 0.92, Parent = panel })
	local header = Kit.new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = tc,
		BackgroundTransparency = 0.82,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = panel,
	})
	Kit.new("UIGradient", { Transparency = NumberSequence.new(0, 0.9), Parent = header })
	for i, col in { P.Red, P.Amber, P.Lime } do
		local dot = Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = col,
			Size = UDim2.fromOffset(9, 9),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12 + (i - 1) * 15, 0.5, 0),
			Parent = header,
		})
		Kit.corner(dot, 5)
	end
	S:text({
		Text = "root@fate:~# ./trace --signature --deep",
		FontFace = Kit.MonoBold,
		TextSize = 14,
		TextColor3 = P.Text,
		Position = UDim2.new(0, 62, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -150, 0, 18),
		Parent = header,
	})
	local live = S:text({
		Text = "LIVE",
		FontFace = Kit.MonoBold,
		TextSize = 13,
		TextColor3 = P.Red,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(80, 18),
		Parent = header,
	})
	local body = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.new(1, -36, 0, nLines * lineH),
		ClipsDescendants = true,
		Parent = panel,
	})
	-- Faint scanlines over the panel body.
	for i = 0, math.floor(h / 4) do
		Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.82,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromOffset(0, i * 4),
			ZIndex = 3,
			Parent = panel,
		})
	end
	local track = Kit.new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = P.Line,
		Position = UDim2.new(0, 18, 1, -30),
		Size = UDim2.new(1, -100, 0, 10),
		Parent = panel,
	})
	Kit.corner(track, 2)
	local fill = Kit.new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = WHITE,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})
	Kit.corner(fill, 2)
	Kit.new("UIGradient", {
		Color = ColorSequence.new(tc, S.aura.color:Lerp(WHITE, 0.2)),
		Parent = fill,
	})
	local pctL = S:text({
		Text = "0%",
		FontFace = Kit.MonoBold,
		TextSize = 15,
		TextColor3 = tc,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 1, -25),
		Size = UDim2.fromOffset(70, 18),
		Parent = panel,
	})
	local T: any = { panel = panel, scale = sc, n = 0, fill = fill, pctL = pctL }
	function T.add(text: string, color: Color3?): TextLabel
		T.n += 1
		return S:text({
			Text = text,
			FontFace = Kit.MonoBold,
			TextSize = 17,
			TextColor3 = color or P.Text,
			Position = UDim2.fromOffset(0, (T.n - 1) * lineH),
			Size = UDim2.new(1, 0, 0, lineH),
			Parent = body,
		})
	end
	function T.progress(p: number)
		fill.Size = UDim2.fromScale(clamp01(p), 1)
		pctL.Text = math.floor(clamp01(p) * 100) .. "%"
	end
	S:loop(function(now: number)
		live.TextTransparency = if (now * 1.6) % 1 < 0.55 then 0 else 0.75
		return false
	end)
	return T
end

-- Types a terminal line with a blinking cursor, optional animated trailing dots while holding.
function Session.typeLine(S: any, term: any, text: string, color: Color3?, cps: number, hold: number, dots: boolean?)
	local l = term.add("", color)
	local n = #text
	local last = 0
	local typeT = n / cps
	S:phase(typeT + hold, function(_: number, e: number)
		local c = math.min(n, math.floor(e * cps))
		local cursor = if (e * 3) % 1 < 0.5 then "_" else " "
		if c < n then
			l.Text = text:sub(1, c) .. cursor
		elseif dots then
			l.Text = text .. string.rep(".", 1 + math.floor((e - typeT) * 7) % 3)
		else
			l.Text = text .. (if e - typeT < hold * 0.8 then cursor else "")
		end
		if c ~= last then
			if c % 2 == 0 then
				S:sfx("Type", 0.22, 0.9 + S.rng:NextNumber() * 0.25)
			end
			last = c
		end
	end)
	l.Text = if dots then text .. "..." else text
	return l
end

-- Small "not responding" error popup used during the crash escalation.
function Session.errorPopup(S: any, z: number, msg: string, corrupted: boolean): Frame
	local rng = S.rng
	local accent = if corrupted then P.Red else P.Magenta
	local w = Kit.panel(S.gui, {
		Name = "ErrorPopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(rng:NextNumber(0.14, 0.86), rng:NextNumber(0.16, 0.84)),
		Size = UDim2.fromOffset(330, 104),
		ZIndex = z,
		BackgroundTransparency = 0.04,
	}, accent)
	local sc = Kit.new("UIScale", { Scale = S.vs * 0.3, Parent = w })
	Kit.tween(sc, 0.22, { Scale = S.vs * 0.85 }, Enum.EasingStyle.Back)
	local bar = Kit.new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.55,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = w,
	})
	S:text({
		Text = if corrupted then corrupt(rng, "FATE.EXE - FATAL", 0.3) else "FATE.EXE - Not Responding",
		FontFace = Kit.MonoBold,
		TextSize = 13,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Parent = bar,
	})
	S:text({
		Text = "X",
		FontFace = Kit.MonoBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 0),
		Size = UDim2.fromOffset(24, 26),
		Parent = bar,
	})
	S:text({
		Text = "/!\\",
		FontFace = Kit.Pixel,
		TextSize = 16,
		TextColor3 = if corrupted then P.Red else P.Amber,
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.fromOffset(52, 28),
		Parent = w,
	})
	S:text({
		Text = msg,
		FontFace = Kit.Mono,
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(74, 38),
		Size = UDim2.new(1, -86, 0, 56),
		Parent = w,
	})
	return w
end

-- Expanding ring that removes itself.
function Session.ring(S: any, z: number, color: Color3, dur: number, maxSize: number, thick: number)
	local r = S:frame({
		Name = "Ring",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.fromScale(0, 0),
		ZIndex = z,
	})
	Kit.corner(r, 0)
	;(r:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(0.5, 0)
	local st = Kit.new("UIStroke", { Color = color, Thickness = thick, Parent = r })
	local t0 = os.clock()
	S:loop(function(now: number)
		local k = clamp01((now - t0) / dur)
		local s = maxSize * outQuart(k)
		r.Size = UDim2.fromScale(s, s)
		st.Transparency = k ^ 1.4
		st.Thickness = thick * (1 - k * 0.7)
		if k >= 1 then
			r:Destroy()
			return true
		end
		return false
	end)
end

-- Radial streak lines: mode "in" (sucked to the centre) or "out" (speed lines). Drive with st.k.
function Session.streaks(S: any, z: number, count: number, color: Color3): any
	local holder = S:frame({ Name = "Streaks", BackgroundTransparency = 1, ZIndex = z })
	local st: any = { k = 0, mode = "in", holder = holder }
	local items = {}
	for i = 1, count do
		local f = Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = if i % 3 == 0 then color else WHITE,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(60, 2),
			Parent = holder,
		})
		Kit.new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = f })
		items[i] = {
			f = f,
			ang = S.rng:NextNumber(0, math.pi * 2),
			ph = S.rng:NextNumber(),
			sp = S.rng:NextNumber(0.6, 1.4),
			len = S.rng:NextNumber(0.6, 1.4),
		}
	end
	local t0 = os.clock()
	S:loop(function(now: number)
		local k = st.k
		holder.Visible = k > 0.01
		if k <= 0.01 then
			return false
		end
		local abs = S.gui.AbsoluteSize
		local maxR = abs.Magnitude * 0.55
		local e = now - t0
		for _, it in items do
			local frac = (e * it.sp * (0.5 + k) + it.ph) % 1
			local r, tr, len
			if st.mode == "in" then
				r = (1 - frac) * maxR
				tr = 1 - k * frac * 0.85
				len = (40 + 160 * (1 - frac)) * it.len * (0.5 + k)
			else
				r = (0.15 + frac * 0.95) * maxR
				tr = 1 - k * (1 - frac) * 0.9
				len = (80 + 420 * frac) * it.len * k
			end
			local cx, cy = math.cos(it.ang), math.sin(it.ang)
			local f = it.f
			f.Position = UDim2.new(0.5, cx * r, 0.5, cy * r)
			f.Size = UDim2.fromOffset(len, if st.mode == "in" then 2 else 3)
			-- Gradient fades towards the centre for "in", away from it for "out".
			f.Rotation = math.deg(it.ang) + (if st.mode == "in" then 0 else 180)
			f.BackgroundTransparency = tr
		end
		return false
	end)
	return st
end

--------------------------------------------------------------------------------------------------------
-- Crash screen (level 4)
--------------------------------------------------------------------------------------------------------

function Session.crashScreen(S: any, corrupted: boolean, z: number): any
	local rng = S.rng
	local tc = S.tier.color
	local vs = S.vs
	local abs = S.gui.AbsoluteSize
	local fg = if corrupted then P.Red else WHITE
	local accent = if corrupted then P.Red:Lerp(WHITE, 0.25) else tc:Lerp(WHITE, 0.35)

	local root = S:frame({
		Name = "Crash",
		BackgroundColor3 = if corrupted then Color3.fromRGB(4, 0, 2) else Color3.fromRGB(18, 46, 150),
		ZIndex = z,
	})
	Kit.new("UIGradient", {
		Color = if corrupted
			then ColorSequence.new(Color3.fromRGB(40, 0, 8), Color3.fromRGB(0, 0, 0))
			else ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 130, 190)),
		Rotation = 90,
		Parent = root,
	})
	-- Scanlines.
	for i = 0, 90 do
		Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = if corrupted then P.Red else BLACK,
			BackgroundTransparency = if corrupted then 0.94 else 0.9,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, i / 90),
			ZIndex = 1,
			Parent = root,
		})
	end
	local labels: { { l: TextLabel, text: string } } = {}
	local function add(text: string, size: number, x: number, y: number, props: { [string]: any }?): TextLabel
		local p: { [string]: any } = {
			Text = text,
			TextSize = math.floor(size * vs + 0.5),
			TextColor3 = fg,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(0.11, x, y, 0),
			Size = UDim2.new(0.74, -x, 0, math.floor((size + 6) * vs * 2 + 0.5)),
			ZIndex = 3,
			Parent = root,
		}
		if props then
			for k, v in props do
				p[k] = v
			end
		end
		local l = S:text(p)
		table.insert(labels, { l = l, text = text })
		return l
	end

	-- Hex dump bleeding through the corrupted variant.
	if corrupted then
		local rows = {}
		for _ = 1, 34 do
			local parts = { "0x" .. hex(rng, 6) .. " " }
			for _ = 1, 8 do
				table.insert(parts, hex(rng, 2))
			end
			table.insert(rows, table.concat(parts, " "))
		end
		local dump = add(table.concat(rows, "\n"), 13, 0, 0.04, {
			Position = UDim2.fromScale(0.62, 0.04),
			Size = UDim2.fromScale(0.36, 0.92),
			TextColor3 = P.Red,
			TextTransparency = 0.72,
			ZIndex = 2,
		})
		dump.TextWrapped = false
		local banner = add("!! KERNEL MEMORY CORRUPTED !! INTEGRITY 0% !! DO NOT POWER OFF REALITY !!", 15, 0, 0.045, {
			FontFace = Kit.MonoBold,
			TextColor3 = P.Red,
		})
		banner.TextWrapped = false
	end

	local glyphText = if corrupted then "X(" else ":("
	local glyphSize = math.floor(150 * vs + 0.5)
	local glyph = add(glyphText, 150, 0, 0.12, {
		FontFace = Kit.Title,
		TextSize = glyphSize,
		Size = UDim2.fromOffset(glyphSize * 2, glyphSize + 20),
		TextWrapped = false,
		ZIndex = 5,
	})
	local glyphA = glyph:Clone()
	glyphA.TextColor3 = P.Cyan
	glyphA.TextTransparency = 0.45
	glyphA.ZIndex = 4
	glyphA.Parent = root
	local glyphB = glyph:Clone()
	glyphB.TextColor3 = P.Magenta
	glyphB.TextTransparency = 0.45
	glyphB.ZIndex = 4
	glyphB.Parent = root

	add("FATE.EXE has encountered a critical anomaly and needs to restart.", 30, 0, 0.38, {
		FontFace = Kit.Mono,
	})
	add(
		if corrupted
			then "Your reality ran into a problem it cannot recover from. We are collecting what is left of it."
			else "We're just collecting some anomaly info, and then we'll restart reality for you.",
		19,
		0,
		0.49,
		{ TextColor3 = fg:Lerp(BLACK, 0.12) }
	)
	local pctL = add("0% complete", 24, 0, 0.585, { FontFace = Kit.MonoBold })
	pctL.TextWrapped = false
	local track = S:frame({
		BackgroundColor3 = if corrupted then Color3.fromRGB(60, 0, 10) else Color3.fromRGB(10, 26, 100),
		Position = UDim2.fromScale(0.11, 0.655),
		Size = UDim2.new(0.42, 0, 0, math.max(4, math.floor(6 * vs))),
		ZIndex = 3,
		Parent = root,
	})
	local fill = S:frame({
		BackgroundColor3 = accent,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 4,
		Parent = track,
	})

	-- Fake QR code (row runs merged into single frames to keep the instance count low).
	local qrPx = math.floor(abs.Y * 0.15)
	local cells = 11
	local cell = qrPx / cells
	local qr = S:frame({
		Name = "QR",
		BackgroundColor3 = if corrupted then BLACK else WHITE,
		Position = UDim2.new(0.11, 0, 0.71, 0),
		Size = UDim2.fromOffset(qrPx + 8, qrPx + 8),
		ZIndex = 3,
		Parent = root,
	})
	local qrInk = if corrupted then P.Red else Color3.fromRGB(18, 46, 150)
	for r = 0, cells - 1 do
		local c = 0
		while c < cells do
			local finder = (r < 3 and (c < 3 or c >= cells - 3)) or (r >= cells - 3 and c < 3)
			local on = finder or rng:NextNumber() < 0.5
			if on then
				local start = c
				while c < cells do
					local f2 = (r < 3 and (c < 3 or c >= cells - 3)) or (r >= cells - 3 and c < 3)
					if not (f2 or rng:NextNumber() < 0.55) then
						break
					end
					c += 1
				end
				S:frame({
					BackgroundColor3 = qrInk,
					Position = UDim2.fromOffset(4 + start * cell, 4 + r * cell),
					Size = UDim2.fromOffset(math.max(1, (c - start) * cell), math.ceil(cell)),
					ZIndex = 4,
					Parent = qr,
				})
			end
			c += 1
		end
	end

	local infoX = qrPx + 30
	local stop = S.tier.id:upper() .. "_SIGNATURE_OVERFLOW"
	local failed = if S.exclusive then (S.biome and S.biome.id:lower() or "biome") .. ".sys" else "fate_core.sys"
	add("For more information about this anomaly, visit https://glitch.rng/stopcode", 15, infoX, 0.712)
	add("If you call support, give them this info:", 15, infoX, 0.752)
	add("Stop code: " .. stop, 17, infoX, 0.792, { FontFace = Kit.MonoBold, TextColor3 = accent })
	add("What failed: " .. failed, 17, infoX, 0.832, { FontFace = Kit.MonoBold, TextColor3 = accent })
	if S.exclusive then
		add("Anomaly source: " .. S.biomeName .. " (biome-exclusive signal)", 15, infoX, 0.872, {
			TextColor3 = S.biomeColor:Lerp(WHITE, 0.3),
		})
	end
	local newL: TextLabel? = nil
	if S.info.first then
		newL = add("> NEW SIGNATURE DISCOVERED", 20, 0, 0.29, { FontFace = Kit.MonoBold, TextColor3 = P.Lime })
		;(newL :: TextLabel).Visible = false
	end

	local C: any = { root = root, pct = 0 }
	local glyphBase = glyph.Position
	local nextCorrupt = 0
	function C.update(now: number, e: number, pct: number)
		C.pct = pct
		pctL.Text = pct .. "% complete"
		fill.Size = UDim2.fromScale(pct / 100, 1)
		-- Glyph RGB split jitter, stronger on corrupted.
		local j = (if corrupted then 7 else 3) * vs
		glyphA.Position = glyphBase + UDim2.fromOffset(-j + rng:NextNumber(-j, j) * 0.5, rng:NextNumber(-1, 1))
		glyphB.Position = glyphBase + UDim2.fromOffset(j + rng:NextNumber(-j, j) * 0.5, rng:NextNumber(-1, 1))
		if newL and e > 0.6 and not newL.Visible then
			newL.Visible = true
			S:sfx("Type", 0.5, 1.2)
		end
		if corrupted and now >= nextCorrupt then
			nextCorrupt = now + 1 / 16
			local amt = 0.04 + 0.22 * (pct / 100) ^ 1.5
			for _, it in labels do
				if it.l ~= pctL then
					it.l.Text = corrupt(rng, it.text, amt)
				end
			end
			root.BackgroundTransparency = if rng:NextNumber() < 0.08 then 0.15 else 0
		end
	end
	return C
end

-- Crack rays spreading from an impact point; C.set(k) grows them.
function Session.cracks(S: any, z: number): any
	local rng = S.rng
	local holder = S:frame({ Name = "Cracks", BackgroundTransparency = 1, ZIndex = z })
	local abs = S.gui.AbsoluteSize
	local cx = abs.X * (0.5 + rng:NextNumber(-0.05, 0.05))
	local cy = abs.Y * (0.48 + rng:NextNumber(-0.05, 0.05))
	local rays = {}
	local function ray(x: number, y: number, ang: number, len: number, thick: number, delay: number)
		local f = Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = WHITE,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = math.deg(ang),
			Size = UDim2.fromOffset(0, thick),
			Parent = holder,
		})
		Kit.new("UIStroke", { Color = BLACK, Thickness = 1, Transparency = 0.5, Parent = f })
		table.insert(rays, { f = f, x = x, y = y, ang = ang, len = len, delay = delay })
	end
	local n = 12
	for i = 1, n do
		local ang = (i / n) * math.pi * 2 + rng:NextNumber(-0.22, 0.22)
		local len = abs.Magnitude * rng:NextNumber(0.25, 0.6)
		ray(cx, cy, ang, len, rng:NextNumber(2, 4), 0)
		for _ = 1, rng:NextInteger(1, 2) do
			local at = rng:NextNumber(0.25, 0.7)
			local bx, by = cx + math.cos(ang) * len * at, cy + math.sin(ang) * len * at
			ray(bx, by, ang + rng:NextNumber(-0.7, 0.7), len * rng:NextNumber(0.2, 0.45), 1.5, at)
		end
	end
	-- Impact ring.
	local ring = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(0, 0),
		Parent = holder,
	})
	Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = ring })
	Kit.new("UIStroke", { Color = WHITE, Thickness = 3, Parent = ring })
	local C: any = { holder = holder, cx = cx / abs.X, cy = cy / abs.Y }
	function C.set(k: number)
		for _, r in rays do
			local kk = clamp01((k - r.delay * 0.6) / (1 - r.delay * 0.6))
			local L = r.len * outExpo(kk)
			r.f.Size = UDim2.fromOffset(L, r.f.Size.Y.Offset)
			r.f.Position = UDim2.fromOffset(r.x + math.cos(r.ang) * L / 2, r.y + math.sin(r.ang) * L / 2)
		end
		local rs = 30 + 90 * outCubic(k)
		ring.Size = UDim2.fromOffset(rs, rs)
	end
	return C
end

-- Splits a full-screen frame into CanvasGroup shards (each holding a clone of the source) and blows them
-- outward from (cx, cy) with spin, gravity and fade, plus a spray of debris.
function Session.shatter(S: any, source: Frame, cols: number, rows: number, z: number, cx: number, cy: number)
	local rng = S.rng
	local shards = {}
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local x0 = (c + 0.5) / cols
			local y0 = (r + 0.5) / rows
			local cg = Instance.new("CanvasGroup")
			cg.Name = "Shard"
			cg.BackgroundTransparency = 1
			cg.BorderSizePixel = 0
			cg.AnchorPoint = Vector2.new(0.5, 0.5)
			cg.Position = UDim2.fromScale(x0, y0)
			cg.Size = UDim2.fromScale(1 / cols, 1 / rows)
			cg.ZIndex = z
			local clone = source:Clone()
			clone.AnchorPoint = Vector2.zero
			clone.Position = UDim2.fromScale(-c, -r)
			clone.Size = UDim2.fromScale(cols, rows)
			clone.Visible = true
			clone.Parent = cg
			Kit.new("UIStroke", {
				Color = WHITE,
				Thickness = 1.5,
				Transparency = 0.35,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = cg,
			})
			cg.Parent = S.gui
			local dx, dy = x0 - cx, (y0 - cy) * 0.75
			local d = math.max(0.05, math.sqrt(dx * dx + dy * dy))
			local speed = rng:NextNumber(0.55, 1.25) * (0.55 + d * 1.6)
			table.insert(shards, {
				cg = cg,
				x0 = x0,
				y0 = y0,
				vx = dx / d * speed + rng:NextNumber(-0.12, 0.12),
				vy = dy / d * speed - rng:NextNumber(0.15, 0.55),
				vr = rng:NextNumber(120, 520) * (if rng:NextNumber() < 0.5 then -1 else 1),
				w = 1 / cols,
				h = 1 / rows,
				delay = d * 0.12,
			})
		end
	end
	source.Visible = false

	local palette = { WHITE, S.tier.color, S.aura.color, S.aura.color2, source.BackgroundColor3 }
	local debris = {}
	for i = 1, 70 do
		local s = rng:NextNumber(4, 16) * S.vs
		local f = Kit.new("Frame", {
			Name = "Debris",
			BorderSizePixel = 0,
			BackgroundColor3 = palette[(i % #palette) + 1],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(cx, cy),
			Size = UDim2.fromOffset(s, s * rng:NextNumber(0.4, 1)),
			ZIndex = z + 1,
			Parent = S.gui,
		})
		local ang = rng:NextNumber(0, math.pi * 2)
		local sp = rng:NextNumber(0.4, 1.6)
		table.insert(debris, {
			f = f,
			vx = math.cos(ang) * sp,
			vy = math.sin(ang) * sp * 0.75 - 0.3,
			vr = rng:NextNumber(-900, 900),
		})
	end

	local t0 = os.clock()
	local G = 1.9
	S:loop(function(now: number)
		local e = now - t0
		for _, sh in shards do
			local t = math.max(0, e - sh.delay)
			local x = sh.x0 + sh.vx * t
			local y = sh.y0 + sh.vy * t + 0.5 * G * t * t
			local k = clamp01(t / 1.4)
			sh.cg.Position = UDim2.fromScale(x, y)
			sh.cg.Rotation = sh.vr * t
			local s = 1 - 0.35 * k
			sh.cg.Size = UDim2.fromScale(sh.w * s, sh.h * s)
			sh.cg.GroupTransparency = seg(t, 0.45, 1.35)
		end
		for _, d in debris do
			local x = cx + d.vx * e
			local y = cy + d.vy * e + 0.5 * G * e * e
			d.f.Position = UDim2.fromScale(x, y)
			d.f.Rotation = d.vr * e
			d.f.BackgroundTransparency = seg(e, 0.3, 1.1)
		end
		if e > 1.8 then
			for _, sh in shards do
				sh.cg:Destroy()
			end
			for _, d in debris do
				d.f:Destroy()
			end
			return true
		end
		return false
	end)
end

--------------------------------------------------------------------------------------------------------
-- Cameras
--------------------------------------------------------------------------------------------------------

-- Slow orbit around the character, blended in from the player's current view.
function Session.orbitCamera(S: any, dur: number)
	local c0 = S:focusPos()
	local off = S.saved.cf.Position - c0
	local ang0 = math.atan2(off.Z, off.X)
	local dir = if S.rng:NextNumber() < 0.5 then 1 else -1
	local t0 = os.clock()
	local fromCF: CFrame = S.saved.cf
	local fromFov: number = S.saved.fov
	S:takeCamera(function(now: number)
		local e = now - t0
		local c = S:focusPos()
		local k = clamp01(e / dur)
		local ang = ang0 + dir * math.rad(80) * inOutSine(k)
		local R = lerp(13, 9, outCubic(k))
		local h = lerp(4.5, 2.2, outCubic(k))
		local look = c + Vector3.new(0, 1.3, 0)
		local pos = S:safe(look, c + Vector3.new(math.cos(ang) * R, h, math.sin(ang) * R))
		local cf = CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, math.rad(math.sin(e * 0.9) * 2))
		local b = inOutCubic(clamp01(e / 0.8))
		if b < 1 then
			cf = fromCF:Lerp(cf, b)
		end
		return cf, lerp(fromFov, 52, b)
	end)
end

-- Dramatic low-angle hero shot, slight dutch tilt, slow push in.
function Session.lowAngleCamera(S: any)
	local lv = S:focusLook()
	local rv = lv:Cross(Vector3.yAxis)
	local t0 = os.clock()
	S:takeCamera(function(now: number)
		local e = now - t0
		local c = S:focusPos()
		local k = clamp01(e / 4)
		local d = lerp(9.5, 6.2, outCubic(k))
		local ang = math.rad(lerp(-24, 10, inOutSine(k)))
		local dir = lv * math.cos(ang) + rv * math.sin(ang)
		local look = c + Vector3.new(0, 1.7, 0)
		local pos = S:safe(look, c + dir * d + Vector3.new(0, -2.1, 0))
		local cf = CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, math.rad(lerp(-8, -2.5, outCubic(k))))
		return cf, lerp(64, 50, outCubic(k))
	end)
end

--------------------------------------------------------------------------------------------------------
-- LEVEL 1: RARE (~0.9s)
--------------------------------------------------------------------------------------------------------

local function level1(S: any)
	local tc = S.tier.color
	local edge = S:edges(tc:Lerp(S.aura.color, 0.35), 0.24, 10)
	local vig = S:edges(BLACK, 0.4, 9)
	setT(edge, 1)
	setT(vig, 1)
	-- A thin scanline that sweeps down the screen with the flash.
	local scan = S:frame({
		Name = "Scan",
		BackgroundColor3 = tc:Lerp(WHITE, 0.4),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 3),
		ZIndex = 12,
	})
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = scan,
	})
	S:sfx("Whoosh", 0.55, 1.15)
	S:sfx("Glitch", 0.25, 1.5)
	S:burst(1)
	S:phase(0.9, function(a: number)
		local flash = if a < 0.1 then outCubic(a / 0.1) else 1 - outCubic(seg(a, 0.1, 1))
		setT(edge, 1 - flash * 0.85)
		setT(vig, 1 - bump(a) * 0.6)
		scan.Position = UDim2.fromScale(0, outCubic(seg(a, 0, 0.6)))
		scan.BackgroundTransparency = 1 - bump(seg(a, 0, 0.6)) * 0.6
		-- Kick in, then spring back with a small overshoot.
		S.fovPunch = if a < 0.13 then -9 * outCubic(a / 0.13) else -9 * (1 - outBack(seg(a, 0.13, 1)))
	end)
	S.fovPunch = 0
end

--------------------------------------------------------------------------------------------------------
-- LEVEL 2: EPIC (~1.8s)
--------------------------------------------------------------------------------------------------------

local function level2(S: any)
	local tc, a = S.tier.color, S.aura
	local gl = S:glitchLayer(20)
	local edgeL = S:edges(P.Cyan, 0.16, 10)
	local edgeR = S:edges(P.Magenta, 0.16, 10)
	local edgeT = S:edges(tc:Lerp(a.color, 0.4), 0.26, 11)
	local vig = S:edges(BLACK, 0.42, 9)
	for _, l in { edgeL, edgeR, edgeT, vig } do
		setT(l, 1)
	end
	local cc = S:cc()
	local rng = S.rng
	local fired = false
	S:sfx("Glitch", 0.55, 1)
	S:sfx("Whoosh", 0.4, 0.8)
	S:phase(1.8, function(_: number, e: number)
		-- Envelope: fast attack, a spike at the burst, long decay.
		local env = if e < 0.25 then outCubic(e / 0.25) else 1 - inOutCubic(seg(e, 0.6, 1.8))
		local spike = if rng:NextNumber() < 0.12 then rng:NextNumber(0.2, 0.5) else 0
		gl.k = clamp01(env * 0.85 + spike * env)
		S.shake = env * 0.75
		S.fovPunch = -6 * bump(seg(e, 0.5, 1.2))
		-- Chromatic edges offset left/right.
		local flick = 0.6 + 0.4 * math.sin(e * 40)
		edgeL[3].BackgroundTransparency = 1 - env * 0.55 * flick
		edgeR[4].BackgroundTransparency = 1 - env * 0.55 * (1.6 - flick)
		setT(edgeT, 1 - bump(seg(e, 0.45, 1.3)) * 0.8)
		setT(vig, 1 - env * 0.7)
		cc.Contrast = 0.35 * env
		cc.Saturation = 0.35 * env
		cc.Brightness = 0.08 * bump(seg(e, 0.5, 0.8))
		cc.TintColor = WHITE:Lerp(a.color:Lerp(tc, 0.5), 0.25 * env)
		if not fired and e >= 0.55 then
			fired = true
			S:burst(1.4)
			S:sfx("Boom", 0.5, 1.1)
			S:sfx("Glitch", 0.45, 0.75)
		end
	end)
	S.shake = 0
	S.fovPunch = 0
end

--------------------------------------------------------------------------------------------------------
-- LEVEL 3: LEGENDARY (~4.5s)
--------------------------------------------------------------------------------------------------------

local function level3(S: any)
	local tc, a = S.tier.color, S.aura
	local info = S.info

	local lines: { { text: string, color: Color3?, hold: number, dots: boolean?, progress: boolean?, sound: string? } } = {}
	table.insert(lines, { text = "> ANOMALY DETECTED", color = P.Red, hold = 0.22, sound = "Error" })
	if S.exclusive then
		table.insert(lines, {
			text = "> SECTOR LOCK: " .. S.biomeName .. "  // EXCLUSIVE SIGNAL",
			color = S.biomeColor:Lerp(WHITE, 0.2),
			hold = 0.15,
		})
	else
		table.insert(lines, { text = "> SECTOR: " .. S.biomeName, color = P.Dim, hold = 0.1 })
	end
	if info.breach then
		table.insert(lines, { text = "> BREACH PROTOCOL ENGAGED", color = P.Red, hold = 0.12 })
	elseif info.boot then
		table.insert(lines, { text = "> BOOT SEQUENCE OVERRIDE", color = P.Magenta, hold = 0.12 })
	end
	table.insert(lines, { text = "> TRACING SIGNATURE", color = P.Text, hold = 0.35, dots = true })
	table.insert(lines, { text = "", progress = true, hold = 0 })
	table.insert(lines, {
		text = "> CLASS: " .. S.tier.name .. "  //  " .. RNG.ChanceText(a.chance),
		color = tc,
		hold = 0.25,
	})
	if info.first then
		table.insert(lines, { text = "> NEW SIGNATURE DISCOVERED", color = P.Lime, hold = 0.45, sound = "Announce" })
	end

	local gl = S:glitchLayer(30)
	local vig = S:edges(BLACK, 0.46, 8)
	local edge = S:edges(tc, 0.2, 9)
	setT(vig, 1)
	setT(edge, 1)
	local lb = S:letterbox(
		40,
		"// SIGNAL INTERCEPT  ::  TRACE 0x" .. hex(S.rng, 4) .. "  ::  SECTOR " .. S.biomeName,
		spaced(S.tier.name) .. "     S I G N A T U R E",
		tc
	)
	local cc = S:cc()
	local white = S:frame({ Name = "White", BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 150 })

	-- Intro: glitch spike in, HUD away, bars in, world dims, orbit starts.
	S:sfx("Glitch", 0.6, 0.9)
	S:sfx("Riser", 0.45, 1)
	S:hideHud()
	S:orbitCamera(4.6)
	S:phase(0.5, function(k: number)
		gl.k = bump(k) * 0.9
		lb.k = outCubic(k)
		setT(vig, 1 - 0.75 * k)
		setT(edge, 1 - 0.55 * bump(k))
		cc.Brightness = -0.12 * k
		cc.Saturation = -0.45 * k
		cc.Contrast = 0.15 * k
		cc.TintColor = WHITE:Lerp(tc, 0.12 * k)
		S.shake = 0.5 * (1 - k)
	end)
	S.shake = 0

	local term = S:terminal(#lines, 50)
	local panel: Frame = term.panel
	local target = panel.Position
	panel.Position = target - UDim2.fromScale(0.08, 0)
	term.scale.Scale = S.vs * 0.6
	Kit.tween(panel, 0.35, { Position = target })
	Kit.tween(term.scale, 0.35, { Scale = S.vs * 0.92 }, Enum.EasingStyle.Back)
	S:phase(0.25, function(k: number)
		gl.k = 0.25 * (1 - k)
	end)

	-- Breathing edge glow while the trace runs.
	S:loop(function(now: number)
		setT(edge, 1 - (0.25 + 0.12 * math.sin(now * 5)))
		return false
	end)

	for _, ln in lines do
		if ln.sound then
			S:sfx(ln.sound, 0.5, 1)
		end
		if ln.progress then
			local l = term.add("", tc:Lerp(WHITE, 0.25))
			local lastTen = -1
			S:phase(0.9, function(k: number)
				local p = clamp01(inOutCubic(k) + math.sin(k * 29) * 0.025 * (1 - k))
				if k >= 1 then
					p = 1
				end
				local n = 20
				local filled = math.floor(p * n + 0.5)
				local pct = math.floor(p * 100)
				l.Text = "> DECRYPTING [" .. string.rep("#", filled) .. string.rep("-", n - filled) .. "] " .. pct .. "%"
				term.progress(p)
				local ten = math.floor(pct / 10)
				if ten ~= lastTen then
					lastTen = ten
					S:sfx("Tick", 0.35, 0.9 + p * 0.6)
				end
			end)
			l.TextColor3 = P.Lime
			Kit.glitch(l, 0.2)
		else
			local l = S:typeLine(term, ln.text, ln.color, 75, ln.hold, ln.dots)
			if ln.text:find("ANOMALY") or ln.text:find("NEW SIGNATURE") then
				Kit.glitch(l, 0.3)
			end
		end
	end

	-- Glitch spike, building to the white-out.
	S:sfx("Glitch", 0.75, 1.25)
	S:sfx("Riser", 0.35, 1.6)
	S:phase(0.45, function(k: number)
		gl.k = 0.3 + 0.9 * inCubic(k)
		S.shake = 0.9 * k
		white.BackgroundTransparency = 1 - 0.3 * inQuart(k)
		setC(edge, tc:Lerp(WHITE, k))
		setT(edge, 1 - 0.9 * k)
		cc.Brightness = lerp(-0.12, 0.25, inCubic(k))
	end)
	S:phase(0.12, function(k: number)
		white.BackgroundTransparency = 0.7 * (1 - k)
	end)
	S:sfx("Boom", 0.7, 1)
	S:peakCut(white)
	S:burst(1.7)
	S:raw(0.55, function(k: number)
		white.BackgroundTransparency = outCubic(k)
	end)
end

--------------------------------------------------------------------------------------------------------
-- LEVEL 4: MYTHIC / CORRUPTED (~7s)
--------------------------------------------------------------------------------------------------------

local MYTHIC_ERRORS = {
	"FATE.EXE is not responding.",
	"The memory at 0x0000DEAD could not be read.",
	"Probability overflow in luck.dll",
	"Reality buffer exceeded (4096/4096).",
	"Signature checksum mismatch.",
	"Unhandled exception in roll_core.sys",
	"Stack overflow in destiny.bin",
}
local CORRUPT_ERRORS = {
	"C0RRUPT10N SPR34D1NG",
	"Kernel heap overwritten by unknown entity.",
	"Integrity check: 0% (FAILED)",
	"SEGFAULT in fate_core.sys",
	"Do not turn off your reality.",
	"Unknown process is rewriting you.",
	"ERR 0xBADF00D :: memory is screaming",
}

local function level4(S: any)
	local corrupted = S.tier.id == "Corrupted"
	local tc, a = S.tier.color, S.aura
	local rng = S.rng
	local hue = if corrupted then P.Red else tc

	local gl = S:glitchLayer(30)
	local edge = S:edges(hue, 0.22, 9)
	local vig = S:edges(BLACK, 0.48, 8)
	setT(edge, 1)
	setT(vig, 1)
	local cc = S:cc()
	local white = S:frame({ Name = "White", BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 150 })

	local errs = if corrupted then CORRUPT_ERRORS else MYTHIC_ERRORS
	local biomeErr = "Unhandled anomaly in sector " .. S.biomeName
	local pops: { Frame } = {}
	local nextPop, nextGl = 0.35, 0

	-- 1) Escalation: the screen glitches harder and harder.
	S:sfx("Riser", 0.55, 0.85)
	S:sfx("Glitch", 0.5, 0.8)
	S:phase(2.3, function(k: number, e: number)
		local esc = k ^ 1.5
		local spike = if rng:NextNumber() < 0.1 then 0.45 else 0
		gl.k = 0.08 + 0.95 * esc + spike * esc
		S.shake = 0.12 + 0.95 * esc
		S.fovPunch = -8 * inOutCubic(k)
		setT(edge, 1 - (0.2 + 0.65 * esc) * (0.65 + 0.35 * math.sin(e * 32)))
		setT(vig, 1 - 0.85 * esc)
		cc.Saturation = -0.7 * esc + (if spike > 0 then 0.6 else 0)
		cc.Contrast = 0.45 * esc
		cc.Brightness = if spike > 0 then 0.12 else -0.05 * esc
		cc.TintColor = WHITE:Lerp(hue, 0.28 * esc)
		if e >= nextPop then
			local msg = if S.exclusive and #pops == 2 then biomeErr else errs[rng:NextInteger(1, #errs)]
			table.insert(pops, S:errorPopup(45, msg, corrupted))
			S:sfx("Error", 0.45, 0.9 + esc * 0.5)
			nextPop = e + lerp(0.5, 0.1, esc)
		end
		if e >= nextGl then
			S:sfx("Glitch", 0.3 + 0.4 * esc, 0.75 + esc * 0.9)
			nextGl = e + lerp(0.55, 0.16, esc)
		end
	end)

	-- 2) Crash screen. Behind it, the camera moves to a low angle on the character.
	S:hideHud()
	for _, p in pops do
		p:Destroy()
	end
	S.shake = 0
	S.fovPunch = 0
	setT(edge, 1)
	setT(vig, 1)
	cc.Saturation = 0.15
	cc.Contrast = 0.2
	cc.Brightness = 0
	cc.TintColor = WHITE:Lerp(a.color, 0.08)
	local crash = S:crashScreen(corrupted, 60)
	gl.holder.ZIndex = 62
	S:sfx("Error", 0.85, 0.7)
	S:sfx("Boom", 0.55, 0.55)
	S:lowAngleCamera()
	local crashDur = if S.info.first then 2.5 else 2.1
	local lastStep = -1
	S:phase(crashDur, function(k: number, e: number)
		-- Glitched cut-in for the first moments, then a subtle flicker.
		gl.k = if e < 0.18 then 1 - e / 0.18 else (if corrupted then 0.12 else 0.03)
		-- Counter races to 100 with little stalls.
		local q = seg(k, 0.06, 0.86)
		local stepped = math.floor((q ^ 1.7) * 100)
		if q > 0.4 and q < 0.48 then
			stepped = math.floor((0.4 ^ 1.7) * 100)
		end
		local pct = math.clamp(stepped, 0, 100)
		crash.update(os.clock(), e, pct)
		local step = math.floor(pct / 5)
		if step ~= lastStep then
			lastStep = step
			S:sfx("Tick", 0.3, 0.8 + pct / 100 * 0.8)
		end
	end)
	crash.update(os.clock(), crashDur, 100)

	-- 3) Cracks spread...
	gl.k = 0
	S:sfx("Glitch", 0.9, 0.55)
	local cr = S:cracks(70)
	S:phase(0.3, function(k: number)
		cr.set(k)
		S.shake = 0.35 * k
	end)

	-- 4) ...and the screen shatters into the hero shot.
	S:sfx("Boom", 0.95, 0.85)
	S:sfx("Whoosh", 0.75, 0.9)
	local lb = S:letterbox(
		40,
		"// SYSTEM FAILURE  ::  " .. (if corrupted then "CORRUPTION" else "ANOMALY") .. " CONTAINED  ::  SECTOR " .. S.biomeName,
		spaced(S.tier.name) .. "     S I G N A T U R E",
		hue
	)
	S:shatter(crash.root, 7, 4, 65, cr.cx, cr.cy)
	cr.holder:Destroy()
	S:burst(2.6)
	S:worldFlash(glowColor(a), 0.7)
	local edgeG = S:edges(glowColor(a), 0.25, 9)
	S:phase(1.5, function(k: number, e: number)
		white.BackgroundTransparency = 0.4 + 0.6 * outCubic(clamp01(e / 0.3))
		S.shake = 0.75 * (1 - k) ^ 2
		lb.k = outCubic(clamp01(e / 0.45))
		setT(edgeG, 0.2 + 0.8 * outCubic(k))
		cc.Brightness = 0.15 * (1 - outCubic(clamp01(e / 0.5)))
	end)

	-- 5) White-out and cut back.
	S:phase(0.22, function(k: number)
		white.BackgroundTransparency = 1 - inCubic(k)
	end)
	S:peakCut(white)
	S:raw(0.5, function(k: number)
		white.BackgroundTransparency = outCubic(k)
	end)
end

--------------------------------------------------------------------------------------------------------
-- LEVEL 5: SINGULARITY (~10.5s)
--------------------------------------------------------------------------------------------------------

local function level5(S: any)
	local a = S.aura
	local acol = glowColor(a)
	local info = S.info

	local black = S:frame({ Name = "Black", BackgroundTransparency = 1, ZIndex = 20 })
	local vig = S:edges(BLACK, 0.45, 15)
	setT(vig, 1)
	local cc = S:cc()
	local blur = S:blur()
	local white = S:frame({ Name = "White", BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 150 })

	-- 1) Fade to black, music dies.
	S:sfx("Glitch", 0.3, 0.45)
	S:phase(1.0, function(k: number)
		local q = inOutCubic(k)
		black.BackgroundTransparency = 1 - q
		S:duck(1 - q)
		cc.Saturation = -q
		S.fovPunch = -5 * q
	end)
	S:hideHud()
	S.fovPunch = 0

	-- Camera timeline (one closure, mode switched by the phases below).
	local lv = S:focusLook()
	local rv = lv:Cross(Vector3.yAxis)
	local mode = "front"
	local m0 = os.clock()
	local riseTop = 380
	local function frontCF(c: Vector3, dist: number, side: number): CFrame
		local look = c + Vector3.new(0, 1.5, 0)
		local pos = S:safe(look, c + lv * dist + rv * side + Vector3.new(0, 1.2, 0))
		return CFrame.lookAt(pos, look)
	end
	local function skyCF(c: Vector3, h: number, spin: number, k: number): CFrame
		local dir = (CFrame.fromAxisAngle(Vector3.yAxis, spin) * CFrame.new(lv)).Position
		local horiz = lerp(10, 3, k)
		local pos = c + dir * horiz + Vector3.new(0, h, 0)
		local up = Vector3.yAxis:Lerp(-dir, clamp01(k * 1.4))
		if up.Magnitude < 0.01 then
			up = -dir
		end
		return CFrame.lookAt(pos, c, up.Unit)
	end
	S:takeCamera(function(now: number)
		local c = S:focusPos()
		local e = now - m0
		if mode == "front" then
			return frontCF(c, 10, 0), 60
		elseif mode == "rise" then
			local k = clamp01(e / 2.3)
			local h = lerp(2, riseTop, outQuart(k))
			return skyCF(c, h, math.rad(120) * outCubic(k), outCubic(k)), lerp(60, 70, k)
		elseif mode == "dive" then
			local k = clamp01(e / 1.1)
			local h = lerp(riseTop, 9, inCubic(k))
			local spin = math.rad(120) + math.rad(200) * inCubic(k)
			return skyCF(c, h, spin, 1), lerp(70, 112, inQuart(k))
		else -- "hero"
			local k = clamp01(e / 3)
			return frontCF(c, lerp(8.5, 6.2, outCubic(k)), lerp(1.6, -0.8, inOutSine(k)))
				* CFrame.Angles(0, 0, math.rad(lerp(3, 0, outCubic(k)))),
				lerp(48, 44, k)
		end
	end)

	-- 2) Silence.
	S:phase(0.5)

	-- 3) A single white point appears and grows; rings ripple out; light is sucked in.
	local point = S:frame({
		Name = "Point",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.fromScale(0, 0),
		ZIndex = 30,
	})
	local glows: { Frame } = {}
	for i, spec in { { 8, 0.95 }, { 4, 0.88 }, { 2.2, 0.65 }, { 1, 0 } } do
		local g = Kit.new("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = if i == 4 then WHITE else acol:Lerp(WHITE, (i - 1) * 0.25),
			BackgroundTransparency = spec[2],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(spec[1], spec[1]),
			ZIndex = i,
			Parent = point,
		})
		Kit.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = g })
		glows[i] = g
	end
	local flare = Kit.new("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = acol:Lerp(WHITE, 0.5),
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(40, 0.07),
		ZIndex = 5,
		Parent = point,
	})
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = flare,
	})
	local streaks = S:streaks(25, 44, acol)
	S:sfx("Riser", 0.75, 0.75)
	local nextRing = 0.15
	S:phase(2.0, function(k: number, e: number)
		local appear = outBack(clamp01(e / 0.3))
		local flicker = 1 + math.noise(e * 14, 2.2) * 0.25
		local s = (0.006 + 0.05 * inCubic(k)) * appear * flicker
		point.Size = UDim2.fromScale(s, s)
		flare.BackgroundTransparency = 0.6 - 0.45 * k
		streaks.k = 0.2 + 0.8 * k
		streaks.mode = "in"
		if e >= nextRing then
			S:ring(28, if math.floor(e * 10) % 2 == 0 then acol else WHITE, 1.4, 1.6, 2)
			S:sfx("Tick", 0.25, 0.5 + k)
			nextRing = e + lerp(0.6, 0.2, k)
		end
	end)
	-- Ring burst.
	S:ring(28, WHITE, 0.9, 2.4, 6)
	S:ring(28, acol, 1.3, 2.0, 3)
	S:sfx("Boom", 0.55, 0.6)
	S:sfx("Whoosh", 0.8, 0.8)

	-- 4) The world returns; the camera pulls far up into the sky.
	mode = "rise"
	m0 = os.clock()
	streaks.k = 0
	S:phase(2.3, function(_: number, e: number)
		black.BackgroundTransparency = outCubic(clamp01(e / 0.6))
		local s = lerp(0.056, 0.008, outCubic(clamp01(e / 0.5)))
		point.Size = UDim2.fromScale(s, s)
		local fade = seg(e, 1.2, 2.1)
		for i, g in glows do
			g.BackgroundTransparency = lerp(({ 0.95, 0.88, 0.65, 0 })[i], 1, fade)
		end
		flare.BackgroundTransparency = lerp(0.15, 1, fade)
		setT(vig, 1 - 0.65 * clamp01(e / 0.6))
		cc.Saturation = lerp(-1, -0.25, clamp01(e / 0.6))
		cc.Contrast = 0.18
		cc.TintColor = WHITE:Lerp(acol, 0.12)
	end)
	point:Destroy()

	-- 5) Dive back down with speed lines.
	mode = "dive"
	m0 = os.clock()
	streaks.mode = "out"
	S:sfx("Whoosh", 0.9, 1.2)
	S:sfx("Riser", 0.5, 1.4)
	S:phase(1.1, function(k: number)
		streaks.k = inCubic(k)
		S.shake = 0.5 * inCubic(k)
		cc.Contrast = 0.18 + 0.2 * k
		setT(vig, 1 - (0.65 + 0.25 * k))
	end)

	-- Impact: flash, cut to the hero shot.
	mode = "hero"
	m0 = os.clock()
	streaks.k = 0
	S.shake = 0
	S:sfx("Boom", 0.85, 0.7)
	S:burst(1.5)
	S:phase(0.25, function(k: number)
		white.BackgroundTransparency = 0.05 + 0.95 * outCubic(k)
		blur.Size = 14 * outCubic(k)
		cc.Brightness = -0.12 * k
		cc.Saturation = lerp(-0.25, -0.5, k)
	end)

	-- 6) The name, letter by letter, huge, with RGB split.
	local band = S:frame({
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.42),
		BackgroundTransparency = 0,
		ZIndex = 40,
	})
	Kit.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
		Parent = band,
	})
	local name = string.upper(a.name)
	local n = utf8.len(name) or #name
	local maxText = math.floor(150 * S.vs + 0.5)
	local function nameLabel(color: Color3, tr: number, z: number): TextLabel
		local l = S:text({
			Text = name,
			FontFace = Kit.Title,
			TextScaled = true,
			TextColor3 = color,
			TextTransparency = tr,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.2),
			MaxVisibleGraphemes = 0,
			ZIndex = z,
		})
		Kit.new("UITextSizeConstraint", { MaxTextSize = maxText, Parent = l })
		Kit.new("UIScale", { Parent = l })
		return l
	end
	local cyanL = nameLabel(P.Cyan, 0.35, 44)
	local magL = nameLabel(P.Magenta, 0.35, 44)
	local mainL = nameLabel(WHITE, 0, 46)
	Kit.new("UIGradient", {
		Color = ColorSequence.new(a.color:Lerp(WHITE, 0.45), a.color2:Lerp(WHITE, 0.2)),
		Rotation = 90,
		Parent = mainL,
	})
	Kit.new("UIStroke", {
		Thickness = 3,
		Color = if brightness(a.color) < 0.4 then WHITE else BLACK,
		Transparency = 0.25,
		Parent = mainL,
	})
	local sub = S:text({
		Text = "",
		FontFace = Kit.MonoBold,
		TextSize = math.floor(20 * S.vs + 0.5),
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.615),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 46,
	})
	local newL = S:text({
		Text = "",
		FontFace = Kit.MonoBold,
		TextSize = math.floor(18 * S.vs + 0.5),
		TextColor3 = P.Lime,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.385),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 46,
	})
	for _, l in { sub, newL } do
		Kit.new("UIStroke", { Thickness = 2, Color = BLACK, Transparency = 0.3, Parent = l })
	end

	local labels = { mainL, cyanL, magL }
	local popAt = -10
	local jitter = 1
	S:loop(function(now: number)
		local pop = 1 + 0.22 * math.exp(-11 * (now - popAt))
		local j = 6 * S.vs * jitter
		for i, l in labels do
			local sc = l:FindFirstChildOfClass("UIScale")
			if sc then
				sc.Scale = pop
			end
			if i == 2 then
				l.Position = UDim2.new(0.5, -j - S.rng:NextNumber(0, 6) * jitter, 0.5, S.rng:NextNumber(-2, 2) * jitter)
			elseif i == 3 then
				l.Position = UDim2.new(0.5, j + S.rng:NextNumber(0, 6) * jitter, 0.5, S.rng:NextNumber(-2, 2) * jitter)
			end
		end
		return false
	end)

	if info.first then
		local txt = "> NEW SIGNATURE DISCOVERED <"
		local last = 0
		S:sfx("Announce", 0.6, 1)
		S:phase(0.7, function(_: number, e: number)
			local c = math.min(#txt, math.floor(e * 55))
			newL.Text = txt:sub(1, c)
			if c ~= last and c % 2 == 0 then
				S:sfx("Type", 0.3, 1.1)
			end
			last = c
		end)
		newL.Text = txt
	end

	local per = math.clamp(1.5 / n, 0.08, 0.17)
	local shown = 0
	S:phase(per * n + 0.08, function(_: number, e: number)
		local c = math.min(n, math.floor(e / per) + 1)
		if c ~= shown then
			shown = c
			for _, l in labels do
				l.MaxVisibleGraphemes = c
			end
			popAt = os.clock()
			S:sfx("Type", 0.6, 0.8 + (c / n) * 0.6)
			S:sfx("Glitch", 0.2, 1.4)
		end
	end)
	for _, l in labels do
		l.MaxVisibleGraphemes = -1
	end

	-- Name complete: the big hit.
	popAt = os.clock()
	S:sfx("Boom", 1, 0.8)
	S:sfx("Reveal5", 0.6, 1)
	S:burst(3.2)
	S:worldFlash(acol, 0.9)
	S:ring(42, WHITE, 1.1, 2.2, 5)
	S:ring(42, acol, 1.5, 1.8, 3)
	local subText = "[ "
		.. S.tier.name
		.. " ]   "
		.. RNG.ChanceText(a.chance)
		.. (if S.exclusive then "   //   " .. S.biomeName .. " EXCLUSIVE" else "")
	local lastC = 0
	S:phase(1.3, function(_: number, e: number)
		white.BackgroundTransparency = 0.55 + 0.45 * outCubic(clamp01(e / 0.3))
		jitter = lerp(1, 0.25, clamp01(e / 0.8))
		local c = math.min(#subText, math.floor(seg(e, 0.25, 0.9) * #subText))
		sub.Text = subText:sub(1, c)
		if c ~= lastC and c % 3 == 0 then
			S:sfx("Type", 0.25, 1.2)
		end
		lastC = c
	end)
	sub.Text = subText

	-- 7) Final white-out into the reveal.
	S:sfx("Riser", 0.4, 1.8)
	S:phase(0.5, function(k: number)
		white.BackgroundTransparency = 1 - inCubic(k)
		jitter = 0.25 + 1.5 * k
		for _, l in labels do
			local sc = l:FindFirstChildOfClass("UIScale")
			if sc then
				sc.Scale = 1 + 0.15 * k
			end
		end
	end)
	S:peakCut(white)
	S:raw(0.7, function(k: number)
		white.BackgroundTransparency = outCubic(k)
		S:duck(k)
	end)
end

--------------------------------------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------------------------------------

local LEVELS: { (any) -> () } = { level1, level2, level3, level4, level5 }
local playing = false

-- Quick flash out used after a skip or an error: hides the cut, restores everything, fades away.
local function flashOut(S: any)
	local white = S:frame({ Name = "SkipFlash", BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 200 })
	S:raw(0.08, function(k: number)
		white.BackgroundTransparency = 1 - k
	end)
	S:peakCut(white)
	S:raw(0.35, function(k: number)
		white.BackgroundTransparency = outCubic(k)
	end)
end

function Cutscene.Play(aura: Config.Aura, info: Info)
	if playing or not aura then
		return
	end
	local level = math.clamp(Config.TierOf(aura.chance).cutscene, 0, 5)
	local fn = LEVELS[level]
	if not fn then
		return
	end
	playing = true
	local okNew, S = pcall(newSession, aura, info or {}, level)
	if not okNew then
		warn("[Cutscene] could not start: " .. tostring(S))
		playing = false
		return
	end
	local ok, err = xpcall(function(): any
		fn(S)
		return nil
	end, function(e: any): any
		if e == SKIP then
			return SKIP
		end
		return debug.traceback(tostring(e), 2)
	end)
	if not ok then
		if err ~= SKIP then
			warn("[Cutscene] " .. tostring(err))
		end
		pcall(flashOut, S)
	end
	pcall(S.cleanup, S)
	playing = false
end

return Cutscene
