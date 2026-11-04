--!strict
-- Cutscene/Session: one running cutscene and everything it owns (gui, per-frame loops, camera driver,
-- Lighting effects, local 3D parts, HUD state, ducked music). Every scene builds on these methods plus the
-- overlay toolkit in Cutscene/Fx. All of it is undone by cleanup(), even when a scene errors halfway.
--
-- Timeline model: S:phase(dur, fn) runs fn(alpha, elapsed) every frame for dur seconds on an absolute
-- cursor (a slow frame never pushes the rest back). Skipping raises SKIP out of the next phase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local Sfx = require(Client.Sfx)
local U = require(script.Parent.Util)

local P = Kit.P
local BLACK = U.BLACK
local clamp01, lerp, seg, inOutCubic = U.clamp01, U.lerp, U.seg, U.inOutCubic
local player = Players.LocalPlayer

local CAM_KEY = "GlitchCutsceneCam"
local UNSHAKE_KEY = "GlitchCutsceneUnshake"

export type Info = { first: boolean?, boot: boolean?, breach: boolean? }

local Session = {}
Session.__index = Session
Session.SKIP = { "skip" } -- unique error value used to unwind a scene when the player skips

local function uiScale(): number
	local cam = workspace.CurrentCamera
	local v = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
	return math.clamp(math.min(v.X / 1600, v.Y / 900), 0.55, 1.15)
end

local function lazyModule(parent: Instance?, name: string): any
	local m = parent and parent:FindFirstChild(name)
	if m and m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if ok then
			return mod
		end
	end
	return nil
end

function Session.new(aura: Config.Aura, info: Info, level: number): any
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
	S.lastCF = cam.CFrame
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
					c.FieldOfView = math.clamp(fov + S.fovPunch, 1, 120)
				end
			end
		else
			c.FieldOfView = S.saved.fov + S.fovPunch
		end
		S.lastCF = c.CFrame
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

--------------------------------------------------------------------------------------------------------
-- Timeline
--------------------------------------------------------------------------------------------------------

-- Generic per-frame updater. Return true from fn to remove it.
function Session.loop(S: any, fn: (number, number) -> boolean?): number
	S.loopId += 1
	S.loops[S.loopId] = fn
	return S.loopId
end

function Session.unloop(S: any, id: number)
	S.loops[id] = nil
end

-- Runs fn once after `delay` seconds (dropped at the peak cut / cleanup with the other loops).
function Session.after(S: any, delay: number, fn: () -> ())
	local at = os.clock() + delay
	S:loop(function(now: number)
		if now >= at then
			fn()
			return true
		end
		return false
	end)
end

-- Timeline step: runs fn(alpha, elapsed) every frame for dur seconds. Phases are chained on an absolute
-- cursor, so a slow frame never pushes the rest of the cutscene back. Skipping unwinds the scene.
function Session.phase(S: any, dur: number, fn: ((number, number) -> ())?)
	local t0 = S.cursor
	local t1 = t0 + dur
	S.cursor = t1
	while true do
		if S.skipped then
			error(Session.SKIP, 0)
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

-- Phase with timed cues: cues = { {at = seconds, fn = callback}, ... } fire once when elapsed passes `at`.
function Session.timeline(S: any, dur: number, cues: { { at: number, fn: () -> () } }, fn: ((number, number) -> ())?)
	local fired: { [number]: boolean } = {}
	S:phase(dur, function(k: number, e: number)
		for i, c in cues do
			if not fired[i] and e >= c.at then
				fired[i] = true
				c.fn()
			end
		end
		if fn then
			fn(k, e)
		end
	end)
	for i, c in cues do
		if not fired[i] then
			c.fn()
		end
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

--------------------------------------------------------------------------------------------------------
-- Instances
--------------------------------------------------------------------------------------------------------

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

-- Folder for local-only 3D props (beams, shockwaves, boxes). Destroyed at the peak cut and in cleanup.
function Session.worldFolder(S: any): Folder
	if not (S.world and S.world.Parent) then
		local f = Instance.new("Folder")
		f.Name = "GlitchCutsceneWorld"
		f.Parent = workspace
		S.world = f
	end
	return S.world
end

function Session.part(S: any, props: { [string]: any }, class: string?): any
	local p: { [string]: any } = {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}
	for k, v in props do
		p[k] = v
	end
	if p.Parent == nil then
		p.Parent = S:worldFolder()
	end
	return Kit.new(class or "Part", p)
end

function Session.clearWorld(S: any)
	if S.world then
		pcall(function()
			S.world:Destroy()
		end)
		S.world = nil
	end
end

--------------------------------------------------------------------------------------------------------
-- World context
--------------------------------------------------------------------------------------------------------

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
	return U.flat(S.lastLook or S.saved.cf.LookVector * -1)
end

function Session.headPos(S: any): Vector3
	local ch = player.Character
	local head = ch and ch:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return S:focusPos() + Vector3.new(0, 1.5, 0)
end

-- World point -> screen pixel position (gui ignores the inset, so viewport space == gui space).
function Session.toScreen(S: any, pos: Vector3): (Vector2, boolean)
	local v, on = S.cam:WorldToViewportPoint(pos)
	return Vector2.new(v.X, v.Y), on and v.Z > 0
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
	if S.world then
		table.insert(ex, S.world)
	end
	params.FilterDescendantsInstances = ex
	params.IgnoreWater = true
	local hit = workspace:Raycast(target, dir, params)
	if hit then
		return hit.Position - dir.Unit * 0.7
	end
	return desired
end

function Session.burst(S: any, scale: number?, pos: Vector3?)
	if S.skipped then
		return
	end
	local at = pos or S:focusPos()
	local id = S.aura.id
	task.spawn(function()
		local fx = lazyModule(Shared, "AuraFX")
		if fx and type(fx.Burst) == "function" then
			local ok, err = pcall(fx.Burst, at, id, scale)
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
	task.spawn(function()
		local fx = lazyModule(Client, "WorldFX")
		if fx and type(fx.Flash) == "function" then
			local ok, err = pcall(fx.Flash, color, duration)
			if not ok then
				warn("[Cutscene] WorldFX.Flash failed: " .. tostring(err))
			end
		end
	end)
end

--------------------------------------------------------------------------------------------------------
-- Lighting effects (owned, destroyed at the peak cut / cleanup)
--------------------------------------------------------------------------------------------------------

local function effect(S: any, class: string, props: { [string]: any }): any
	local e = Instance.new(class)
	e.Name = "GlitchCutscene" .. class
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = Lighting
	table.insert(S.effects, e)
	return e
end

function Session.cc(S: any): ColorCorrectionEffect
	return effect(S, "ColorCorrectionEffect", {})
end

function Session.blur(S: any): BlurEffect
	return effect(S, "BlurEffect", { Size = 0 })
end

function Session.bloom(S: any): BloomEffect
	return effect(S, "BloomEffect", { Intensity = 0, Size = 24, Threshold = 0.9 })
end

function Session.sunRays(S: any): SunRaysEffect
	return effect(S, "SunRaysEffect", { Intensity = 0, Spread = 0.6 })
end

function Session.clearEffects(S: any)
	for _, e in S.effects do
		pcall(function()
			e:Destroy()
		end)
	end
	S.effects = {}
end

--------------------------------------------------------------------------------------------------------
-- HUD, camera, music
--------------------------------------------------------------------------------------------------------

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

-- A camera shot: fn(elapsed, focus) -> (CFrame, fov?). Blends from wherever the camera is now.
function Session.shot(S: any, fn: (number, Vector3) -> (CFrame, number?), blend: number?)
	local fromCF: CFrame = S.lastCF
	local fromFov: number = S.cam.FieldOfView - S.fovPunch
	local t0 = os.clock()
	local bl = blend or 0
	S:takeCamera(function(now: number)
		local e = now - t0
		local cf, fov = fn(e, S:focusPos())
		local f = fov or fromFov
		if bl > 0 and e < bl then
			local b = inOutCubic(clamp01(e / bl))
			cf = fromCF:Lerp(cf, b)
			f = lerp(fromFov, f, b)
		end
		return cf, f
	end)
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

-- At a full-screen peak: drop every overlay but `keep`, restore world/camera/HUD underneath.
function Session.peakCut(S: any, keep: Instance?)
	S.canSkip = false
	for _, ch in S.gui:GetChildren() do
		if ch ~= keep then
			ch:Destroy()
		end
	end
	S.loops = {}
	S:clearEffects()
	S:clearWorld()
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
	S:clearWorld()
	S:unduck()
	pcall(function()
		S.gui:Destroy()
	end)
end

return Session
